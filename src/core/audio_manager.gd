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
	# Story 005 adds EventBus connections here
	# Story 006 adds music player init here


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


## Resets pool slot at index to IDLE when its AudioStreamPlayer emits finished.
## Bound at pool construction time — one closure per slot index.
func _on_sfx_finished(index: int) -> void:
	_sfx_pool_state[index] = false
