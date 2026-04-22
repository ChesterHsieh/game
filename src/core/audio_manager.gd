## AudioManager — autoload #5. Foundation-layer singleton that owns all audio
## playback for Moments. Loads config at startup and enters silent-fallback mode
## if the config is missing or wrong type — no crash, game runs without audio.
##
## Load order: after EventBus (autoload #1). EventBus must be ready before
## AudioManager connects to its signals (Story 005).
##
## Story 002: SFX pool allocation
## Story 003: pitch + volume randomization
## Story 004: per-event cooldowns
## Story 005: EventBus signal wiring
## Story 006: music crossfade state machine
## Story 007: public API (set_bus_volume, fade_out_all)
## Story 008: seeds audio_config.tres
##
## NOTE: class_name is intentionally omitted. Godot 4 does not allow a script
## registered as an autoload singleton to also declare a class_name matching
## its autoload name — the engine reports "Class hides an autoload singleton".
## The autoload is accessed globally via the name assigned in project.godot.
extends Node

## Emitted by fade_out_all() once the tween reaches −80 dB on all buses.
## FES listens to this to know when it is safe to proceed after the audio fade.
signal fade_out_completed

## Path to the typed AudioConfig resource. Missing file triggers silent mode.
const CONFIG_PATH := "res://assets/data/audio_config.tres"

## Fixed pool size for SFX voices. Never changes at runtime (ADR — no dynamic
## allocation). Downstream stories always allocate exactly this many nodes.
const SFX_POOL_SIZE := 8

## Loaded AudioConfig resource. Null when in silent mode.
var _config: AudioConfig = null

## True when config is missing or wrong type. All downstream stories check this
## before playing audio. EventBus connections are still established in Story 005
## so cooldowns and state transitions work even when silent. (TR-019)
var _silent_mode: bool = false

## Fixed-size array of pre-allocated AudioStreamPlayer nodes on the SFX bus.
## Index maps 1-to-1 with _sfx_pool_state. Never resized after _init_sfx_pool().
var _sfx_pool: Array[AudioStreamPlayer] = []

## Parallel state array. true = PLAYING, false = IDLE.
## Reset to false by _on_sfx_finished() when the player's finished signal fires.
var _sfx_pool_state: Array[bool] = []

## Per-event last-play timestamp (msec from Time.get_ticks_msec()).
## Initialised on first play — absence means the event has never played
## (treated as last=0, which always passes the cooldown check).
var _last_play_time: Dictionary = {}

## True once win_condition_met has been dispatched this scene.
## Reset to false by _on_scene_completed(). Controls the once-per-scene gate.
var _win_played_this_scene: bool = false

## Injectable clock function. Returns int milliseconds. Defaults to
## Time.get_ticks_msec. Override in tests for deterministic timing.
var _clock_fn: Callable = func() -> int: return Time.get_ticks_msec()

# ── Story 006: music crossfade state machine ─────────────────────────────────

## Three-state music FSM. STOPPED = no track loaded, PLAYING = one player
## active at target volume, CROSSFADING = outgoing fading out / incoming fading in.
enum MusicState { STOPPED, PLAYING, CROSSFADING }

## Current FSM state. Read-only from outside the manager.
var _music_state: MusicState = MusicState.STOPPED

## Double-buffer music players. Both live on the Music bus.
var _music_a: AudioStreamPlayer = null
var _music_b: AudioStreamPlayer = null

## The player that is currently the "canonical" foreground track.
## Points to _music_a or _music_b. Null when STOPPED.
var _active_music: AudioStreamPlayer = null

## res:// path of the track that _active_music is (or will be) playing.
## Empty string means STOPPED or no track for the current scene.
var _current_track_path: String = ""

## In-flight crossfade Tween. Killed on mid-crossfade interrupts.
var _crossfade_tween: Tween = null

# ── Story 007: public API state ───────────────────────────────────────────────

## One-shot guard for fade_out_all. Once true, subsequent calls are no-ops.
var _fade_out_completed: bool = false

## In-flight fade_out_all Tween reference (kept to allow future cancel if needed).
var _fade_out_tween: Tween = null


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	var raw: Resource = ResourceLoader.load(CONFIG_PATH)
	var config: AudioConfig = raw as AudioConfig
	if config == null:
		push_error(
			"AudioManager: %s is missing or not an AudioConfig — entering silent mode"
			% CONFIG_PATH
		)
		_silent_mode = true
	else:
		_config = config
	# Pool always initializes regardless of silent mode (TR-019): state
	# transitions run even without audio. Streams are not assigned here —
	# Story 003 assigns them at play time.
	_init_sfx_pool()
	# Music players always initialize regardless of silent mode (TR-019):
	# FSM state transitions run even without audio.
	_init_music_players()
	_connect_signals()


## Returns true if AudioManager is in silent-fallback mode (no config loaded).
## Downstream stories check this before performing any playback operations.
##
## Example:
##   if AudioManager.is_silent():
##       return
func is_silent() -> bool:
	return _silent_mode


## Returns the loaded AudioConfig, or null when in silent mode.
## Story 002 uses this to read sfx_pool_size. Story 006 uses crossfade_duration.
##
## Example:
##   var cfg: AudioConfig = AudioManager.get_config()
##   if cfg == null: return
func get_config() -> AudioConfig:
	return _config


## Allocates SFX_POOL_SIZE AudioStreamPlayer nodes as children of this node,
## all wired to the "SFX" bus. Called once from _ready(). Forbidden to call
## again at runtime (Control Manifest: no dynamic allocation).
##
## Example:
##   # Called automatically from _ready() — do not call manually.
func _init_sfx_pool() -> void:
	for i: int in SFX_POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = &"SFX"
		player.finished.connect(_on_sfx_finished.bind(i))
		add_child(player)
		_sfx_pool.append(player)
		_sfx_pool_state.append(false)


## Claims the first IDLE pool node and returns its index. If no IDLE node
## exists and is_win is false, returns -1 (non-win events are silently
## dropped when the pool is exhausted). If is_win is true and the pool is
## full, stops the node nearest to finishing and returns its index.
##
## Example:
##   var idx: int = _claim_sfx_node(false)
##   if idx == -1:
##       return  # pool full, non-win event dropped
##   _sfx_pool[idx].stream = my_stream
##   _sfx_pool[idx].play()
##   _sfx_pool_state[idx] = true
func _claim_sfx_node(is_win: bool) -> int:
	# Pass 1: first IDLE node wins.
	for i: int in SFX_POOL_SIZE:
		if not _sfx_pool_state[i]:
			return i
	# Pool is full.
	if not is_win:
		return -1  # silently drop non-win event
	# Win priority: steal the node with least remaining playback time.
	var best_i: int = 0
	var least_remaining: float = INF
	for i: int in SFX_POOL_SIZE:
		var player: AudioStreamPlayer = _sfx_pool[i]
		var remaining: float = _get_remaining_time(i)
		if remaining < least_remaining:
			least_remaining = remaining
			best_i = i
	_sfx_pool[best_i].stop()
	_sfx_pool_state[best_i] = false
	return best_i


## Returns the remaining playback time in seconds for pool node at index.
## Extracted so tests can verify behavior without live audio playback.
## Returns 0.0 when the stream is null (silent mode / unassigned slot).
##
## Example:
##   var t: float = _get_remaining_time(3)
func _get_remaining_time(index: int) -> float:
	var player: AudioStreamPlayer = _sfx_pool[index]
	if player.stream == null:
		return 0.0
	return player.stream.get_length() - player.get_playback_position()


## Applies pitch and volume randomization from event_config to the pool node at
## index, then plays it. Called after _claim_sfx_node() returns a valid index.
## Silent mode callers must guard before calling this (TR-019).
##
## event_config keys (all optional — missing keys fall back to safe defaults):
##   path: String           — res:// path to the AudioStream resource
##   pitch_range: float     — semitone variance; 0 disables randomization
##   base_volume_db: float  — base volume in dB
##   volume_variance: float — dB variance; 0 disables randomization
##
## Example:
##   var idx: int = _claim_sfx_node(false)
##   if idx == -1:
##       return
##   _play_on_node(idx, {"path": "res://assets/audio/sfx/click.wav",
##                        "pitch_range": 2.0, "base_volume_db": -6.0,
##                        "volume_variance": 3.0})
func _play_on_node(index: int, event_config: Dictionary) -> void:
	var player: AudioStreamPlayer = _sfx_pool[index]
	var path: String = event_config.get("path", "")
	if not path.is_empty():
		player.stream = load(path)
	player.pitch_scale = _randomize_pitch(event_config.get("pitch_range", 0.0))
	player.volume_db = _randomize_volume(
		event_config.get("base_volume_db", 0.0),
		event_config.get("volume_variance", 0.0)
	)
	_sfx_pool_state[index] = true
	player.play()


## Returns a pitch_scale multiplier by drawing a uniform semitone offset from
## [−pitch_range, +pitch_range] and applying the equal-temperament formula:
##   pitch_scale = 2^(offset / 12)
##
## When pitch_range <= 0 returns 1.0 (no randomization).
##
## Example:
##   var scale: float = _randomize_pitch(2.0)  # ≈ [0.891, 1.122]
static func _randomize_pitch(pitch_range: float) -> float:
	if pitch_range <= 0.0:
		return 1.0
	var offset: float = randf_range(-pitch_range, pitch_range)
	return pow(2.0, offset / 12.0)


## Returns a final volume in dB by adding a uniform offset drawn from
## [−variance, +variance] to base_db, then clamping to [−80, 0] dB.
##   final_volume_db = clamp(base_db + uniform(−variance, +variance), −80, 0)
##
## When variance <= 0 returns base_db clamped to [−80, 0] (no randomization).
##
## Example:
##   var db: float = _randomize_volume(-6.0, 3.0)  # ∈ [−9.0, −3.0]
static func _randomize_volume(base_db: float, variance: float) -> float:
	if variance <= 0.0:
		return clampf(base_db, -80.0, 0.0)
	var offset: float = randf_range(-variance, variance)
	return clampf(base_db + offset, -80.0, 0.0)


## Resets pool slot at index to IDLE when its AudioStreamPlayer emits finished.
## Bound at pool construction time — one closure per slot index.
func _on_sfx_finished(index: int) -> void:
	_sfx_pool_state[index] = false


# ── Story 006: Music crossfade state machine ──────────────────────────────────

## Creates the two double-buffer AudioStreamPlayer nodes on the Music bus.
## Called once from _ready(). Both nodes are always created — silent mode only
## skips stream loading and playback (TR-019).
##
## Example:
##   # Called automatically from _ready() — do not call manually.
func _init_music_players() -> void:
	_music_a = AudioStreamPlayer.new()
	_music_a.bus = &"Music"
	add_child(_music_a)
	_music_b = AudioStreamPlayer.new()
	_music_b.bus = &"Music"
	add_child(_music_b)


## Returns the music track path registered for scene_id, or an empty String
## when no entry exists in config.music_tracks or config is null.
##
## Example:
##   var path: String = _get_music_track("scene-01")  # "res://...ambient.ogg"
func _get_music_track(scene_id: String) -> String:
	if _config == null:
		return ""
	return _config.music_tracks.get(scene_id, "") as String


## Entry point for scene-based music changes. Called by _on_scene_started().
## Handles the STOPPED → PLAYING (no crossfade) and PLAYING → CROSSFADING
## transitions per the FSM spec (AC-AM-12, AC-AM-13).
##
## In silent mode this method is a no-op: FSM state and _current_track_path are
## NOT updated so the state machine stays STOPPED (nothing to reconcile without
## audio). TR-019 only requires that cooldown/pool state ticks — the music FSM
## itself has no cooldown side-effect.
##
## Example:
##   _play_music_for_scene("scene-02")
func _play_music_for_scene(scene_id: String) -> void:
	if _silent_mode:
		return
	var track_path: String = _get_music_track(scene_id)
	if track_path.is_empty():
		_stop_music()
		return
	if track_path == _current_track_path:
		return  # same track — no crossfade (AC-AM-13)
	if _music_state == MusicState.STOPPED:
		_start_first_play(track_path)
	else:
		_start_crossfade(track_path)


## STOPPED → PLAYING. No crossfade, no tween — stream starts immediately at
## target volume (default 0.0 dB, scaled by the Music bus).
## Sets _active_music, _current_track_path, and transitions FSM to PLAYING.
##
## Example:
##   _start_first_play("res://assets/audio/music/ambient_a.ogg")
func _start_first_play(track_path: String) -> void:
	_music_a.stream = load(track_path)
	_music_a.volume_db = 0.0
	_music_a.play()
	_active_music = _music_a
	_current_track_path = track_path
	_music_state = MusicState.PLAYING


## PLAYING / CROSSFADING → CROSSFADING. Kills any in-flight tween, then starts
## a new parallel tween: outgoing ramps from its current volume to −80 dB;
## incoming ramps from −80 dB to 0 dB. On completion the outgoing player is
## stopped and FSM moves to PLAYING.
##
## Mid-crossfade interrupt: the in-flight tween is killed (freezing the current
## outgoing at its instantaneous volume). The player that was incoming becomes
## the new outgoing at whatever dB it was frozen at. A fresh crossfade begins.
##
## Example:
##   _start_crossfade("res://assets/audio/music/ambient_b.ogg")
func _start_crossfade(new_track_path: String) -> void:
	if _crossfade_tween != null and _crossfade_tween.is_running():
		_crossfade_tween.kill()

	var outgoing: AudioStreamPlayer = _active_music
	var incoming: AudioStreamPlayer = _music_a if _active_music == _music_b else _music_b

	incoming.stream = load(new_track_path)
	incoming.volume_db = -80.0
	incoming.play()

	var duration: float = _config.crossfade_duration if _config != null else 2.0

	_crossfade_tween = create_tween()
	_crossfade_tween.set_parallel(true)
	if outgoing != null and outgoing.playing:
		_crossfade_tween.tween_property(outgoing, "volume_db", -80.0, duration)
	_crossfade_tween.tween_property(incoming, "volume_db", 0.0, duration)
	_crossfade_tween.chain().tween_callback(_on_crossfade_complete.bind(outgoing))

	_active_music = incoming
	_current_track_path = new_track_path
	_music_state = MusicState.CROSSFADING


## Stops music immediately. Kills any in-flight crossfade, stops both players,
## and resets FSM to STOPPED.
##
## Example:
##   _stop_music()
func _stop_music() -> void:
	if _crossfade_tween != null and _crossfade_tween.is_running():
		_crossfade_tween.kill()
	if _music_a != null:
		_music_a.stop()
	if _music_b != null:
		_music_b.stop()
	_active_music = null
	_current_track_path = ""
	_music_state = MusicState.STOPPED


## Callback fired by the crossfade tween chain after both ramps complete.
## Stops the outgoing player and transitions FSM to PLAYING.
func _on_crossfade_complete(outgoing: AudioStreamPlayer) -> void:
	if outgoing != null:
		outgoing.stop()
	_music_state = MusicState.PLAYING


# ── Story 007: Public API ─────────────────────────────────────────────────────

## Sets the named audio bus volume immediately to volume_db, clamped to
## [−80, 0] dB. Uses PascalCase bus names: "Master", "Music", "SFX".
## Silently clamps out-of-range values — no error is raised.
## No-op for unknown bus names (push_warning logged).
##
## This is the only sanctioned path for gameplay or settings code to adjust
## bus volumes (ADR-003 — no direct AudioServer calls from gameplay systems).
##
## Example:
##   AudioManager.set_bus_volume("Music", -20.0)
func set_bus_volume(bus_name: String, volume_db: float) -> void:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx < 0:
		push_warning("AudioManager: unknown bus '%s'" % bus_name)
		return
	volume_db = clampf(volume_db, -80.0, 0.0)
	AudioServer.set_bus_volume_db(idx, volume_db)


## Returns the current volume in dB for the named audio bus.
## Returns 0.0 and logs a warning for unknown bus names.
##
## Example:
##   var vol: float = AudioManager.get_bus_volume("Music")
func get_bus_volume(bus_name: String) -> float:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx < 0:
		push_warning("AudioManager: unknown bus '%s'" % bus_name)
		return 0.0
	return AudioServer.get_bus_volume_db(idx)


## Resets all three buses (Master, Music, SFX) to 0.0 dB.
## Intended for test teardown and settings revert. Does not affect the
## one-shot _fade_out_completed guard — call only when appropriate.
##
## Example:
##   AudioManager.reset_bus_volumes()
func reset_bus_volumes() -> void:
	for bus_name: String in ["Master", "Music", "SFX"]:
		var idx: int = AudioServer.get_bus_index(bus_name)
		if idx < 0:
			continue
		AudioServer.set_bus_volume_db(idx, 0.0)


## Linearly ramps Master, Music, and SFX buses from their current dB to −80 dB
## over duration seconds, then emits the fade_out_completed signal.
##
## One-shot per session: a second call is a no-op and logs push_warning.
## Duration is clamped to [0.1, 10.0] seconds.
## Cancels any in-flight music crossfade (per AC-AM-17).
## In silent mode the method still executes: buses are at their current dB
## values and the tween will ramp them regardless.
##
## Example:
##   AudioManager.fade_out_all(2.0)
##   await AudioManager.fade_out_completed
func fade_out_all(duration: float) -> void:
	if _fade_out_completed:
		push_warning("AudioManager: fade_out_all already completed — no-op")
		return
	duration = clampf(duration, 0.1, 10.0)
	# Cancel in-flight crossfade so music does not fight the bus fade.
	if _crossfade_tween != null and _crossfade_tween.is_running():
		_crossfade_tween.kill()
	_fade_out_tween = create_tween()
	_fade_out_tween.set_parallel(true)
	for bus_name: String in ["Master", "Music", "SFX"]:
		var idx: int = AudioServer.get_bus_index(bus_name)
		if idx < 0:
			continue
		var current_db: float = AudioServer.get_bus_volume_db(idx)
		_fade_out_tween.tween_method(
			func(db: float) -> void: AudioServer.set_bus_volume_db(idx, db),
			current_db,
			-80.0,
			duration
		)
	_fade_out_tween.chain().tween_callback(
		func() -> void:
			_fade_out_completed = true
			fade_out_completed.emit()
	)


# ── Story 004: Per-event cooldowns ───────────────────────────────────────────

## Returns true when event_name is ready to play.
## For "win_condition_met": uses the once-per-scene boolean, ignoring cooldown_ms.
## For all other events: checks elapsed time since last play against cooldown_ms.
## First play (event absent from _last_play_time) is always allowed (last = 0).
##
## Example:
##   if _is_cooldown_ready("card_snap", 200):
##       _record_play("card_snap")
func _is_cooldown_ready(event_name: String, cooldown_ms: int) -> bool:
	if event_name == "win_condition_met":
		return not _win_played_this_scene
	var now: int = _clock_fn.call()
	var last: int = _last_play_time.get(event_name, 0)
	return (now - last) >= cooldown_ms


## Records a play for event_name, updating the timestamp and win flag.
## Must be called immediately after a successful cooldown check, before
## _play_on_node(), so the next request sees an accurate last-play time.
##
## Example:
##   _record_play("card_snap")
func _record_play(event_name: String) -> void:
	_last_play_time[event_name] = _clock_fn.call()
	if event_name == "win_condition_met":
		_win_played_this_scene = true


## Retrieves the event config Dictionary for event_name from _config.sfx_events.
## Returns an empty Dictionary when no config is loaded (silent mode) or the
## event name has no entry. The empty-dict return is the signal to log + drop.
##
## Example:
##   var cfg: Dictionary = _get_event_config("card_snap")
##   if cfg.is_empty(): push_warning(...)
func _get_event_config(event_name: String) -> Dictionary:
	if _config == null:
		return {}
	return _config.sfx_events.get(event_name, {}) as Dictionary


## Full SFX dispatch pipeline: config lookup → cooldown check → pool claim →
## record play → (guard silent mode) → randomization + play.
## Cooldowns and pool claims run even in silent mode (TR-019).
## Logs a warning and drops silently when event_name has no config entry (TR-020).
##
## Example:
##   _dispatch_sfx("card_drag_start")
func _dispatch_sfx(event_name: String) -> void:
	var event_config: Dictionary = _get_event_config(event_name)
	if event_config.is_empty():
		push_warning("AudioManager: no config for event '%s' — dropped" % event_name)
		return
	var cooldown_ms: int = event_config.get("cooldown_ms", 0) as int
	if not _is_cooldown_ready(event_name, cooldown_ms):
		return
	var is_win: bool = event_name == "win_condition_met"
	var node_idx: int = _claim_sfx_node(is_win)
	if node_idx < 0:
		return
	_record_play(event_name)
	if _silent_mode:
		return  # cooldown recorded, pool claimed, but no stream loaded
	_play_on_node(node_idx, event_config)


# ── Story 005: EventBus signal wiring ────────────────────────────────────────

## Connects all gameplay EventBus signals that AudioManager must respond to.
## Called once from _ready(), after _init_sfx_pool(). One-way flow only:
## AudioManager never emits back to EventBus or calls methods on gameplay systems.
##
## Example:
##   # Called automatically from _ready() — do not call manually.
func _connect_signals() -> void:
	EventBus.drag_started.connect(_on_drag_started)
	EventBus.drag_released.connect(_on_drag_released)
	EventBus.proximity_entered.connect(_on_proximity_entered)
	EventBus.combination_executed.connect(_on_combination_executed)
	EventBus.card_spawned.connect(_on_card_spawned)
	EventBus.win_condition_met.connect(_on_win_condition_met)
	EventBus.scene_completed.connect(_on_scene_completed)
	EventBus.scene_started.connect(_on_scene_started)


# ── Signal callbacks ──────────────────────────────────────────────────────────

func _on_drag_started(_card_id: String, _world_pos: Vector2) -> void:
	_dispatch_sfx("card_drag_start")


func _on_drag_released(_card_id: String, _world_pos: Vector2) -> void:
	_dispatch_sfx("card_drag_release")


func _on_proximity_entered(_dragged_id: String, _target_id: String) -> void:
	_dispatch_sfx("card_proximity_enter")


func _on_combination_executed(
	_recipe_id: String,
	_template: String,
	_instance_id_a: String,
	_instance_id_b: String,
	_card_id_a: String,
	_card_id_b: String
) -> void:
	_dispatch_sfx("combination_executed")


func _on_card_spawned(_instance_id: String, _card_id: String, _position: Vector2) -> void:
	_dispatch_sfx("card_spawned")


func _on_win_condition_met() -> void:
	_dispatch_sfx("win_condition_met")


## Resets the win once-per-scene gate. Music FSM is not reset here — music
## continues playing across scene boundaries until _on_scene_started picks a
## new track (or no-track scene triggers _stop_music).
func _on_scene_completed(_scene_id: String) -> void:
	_win_played_this_scene = false


## Triggers music track selection for the incoming scene. Delegates to
## _play_music_for_scene which handles all FSM transitions (Story 006).
func _on_scene_started(scene_id: String) -> void:
	_play_music_for_scene(scene_id)
