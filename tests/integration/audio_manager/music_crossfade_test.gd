## Integration tests for AudioManager music crossfade state machine — Story 006.
##
## Covers the 7 QA acceptance criteria from the story:
##   AC-1: _ready() creates exactly 2 AudioStreamPlayer children on the Music bus
##   AC-2: STOPPED → PLAYING on first scene (no crossfade, no tween)
##   AC-3: PLAYING → CROSSFADING when scene changes to a different track
##   AC-4: same track on consecutive scenes — no crossfade, playback uninterrupted
##   AC-5: scene with no registered track — music stops, state = STOPPED
##   AC-6: mid-crossfade interrupt — tween killed, fresh crossfade starts
##   AC-7: silent mode — _play_music_for_scene is a no-op, state stays STOPPED
##
## Pattern: AudioManager omits class_name because the autoload name occupies the
## global identifier. Preload the script and add_child() to trigger _ready().
## The same AudioManagerMusicProxy pattern is used here as sfx_pool_test for
## observable internal state without live audio hardware.
extends GdUnitTestSuite

const AudioManagerScript := preload("res://src/core/audio_manager.gd")


# ── Test proxy ────────────────────────────────────────────────────────────────
#
# Overrides _start_first_play and _start_crossfade to intercept calls without
# loading real audio streams in headless mode. Records call arguments for
# assertion. Also overrides _get_music_track to return deterministic values
# from an injected dictionary.

class AudioManagerMusicProxy extends AudioManagerScript:
	## Injected scene → track mapping. Used instead of _config.music_tracks.
	var mock_tracks: Dictionary = {}

	## Number of times _start_first_play was called.
	var first_play_calls: int = 0
	## Track path passed to the last _start_first_play call.
	var last_first_play_path: String = ""

	## Number of times _start_crossfade was called.
	var crossfade_calls: int = 0
	## Track path passed to the last _start_crossfade call.
	var last_crossfade_path: String = ""

	## Number of times _stop_music was called.
	var stop_music_calls: int = 0

	func _get_music_track(scene_id: String) -> String:
		return mock_tracks.get(scene_id, "") as String

	func _start_first_play(track_path: String) -> void:
		first_play_calls += 1
		last_first_play_path = track_path
		# Update FSM state and tracking fields so subsequent logic is consistent.
		_active_music = _music_a
		_current_track_path = track_path
		_music_state = MusicState.PLAYING

	func _start_crossfade(new_track_path: String) -> void:
		crossfade_calls += 1
		last_crossfade_path = new_track_path
		# Simulate FSM transition so same-track guard works for follow-up calls.
		_current_track_path = new_track_path
		_music_state = MusicState.CROSSFADING

	func _stop_music() -> void:
		stop_music_calls += 1
		_active_music = null
		_current_track_path = ""
		_music_state = MusicState.STOPPED


# ── helpers ──────────────────────────────────────────────────────────────────

## Creates a proxy with _silent_mode = false and a two-entry mock track table.
## Caller must free() after each test.
func _make_proxy_with_tracks() -> AudioManagerMusicProxy:
	var proxy := AudioManagerMusicProxy.new()
	proxy.mock_tracks = {
		"scene-01": "res://assets/audio/music/ambient_a.ogg",
		"scene-02": "res://assets/audio/music/ambient_b.ogg",
		"scene-03": "res://assets/audio/music/ambient_c.ogg",
	}
	# Force not-silent so _play_music_for_scene executes.
	proxy._silent_mode = false
	# Inject a minimal config so _config != null for duration reads.
	var cfg := AudioConfig.new()
	cfg.crossfade_duration = 2.0
	proxy._config = cfg
	add_child(proxy)
	return proxy


# ── AC-1: two music players on the Music bus ─────────────────────────────────

func test_music_ready_creates_two_music_players() -> void:
	# Arrange + Act
	var manager: Node = AudioManagerScript.new()
	add_child(manager)

	# Count AudioStreamPlayer children that are on the Music bus.
	var count: int = 0
	for child: Node in manager.get_children():
		if child is AudioStreamPlayer:
			var player: AudioStreamPlayer = child as AudioStreamPlayer
			if String(player.bus) == "Music":
				count += 1

	# Assert
	assert_int(count).is_equal(2)
	manager.free()


func test_music_ready_music_players_assigned_to_music_bus() -> void:
	# Arrange + Act
	var manager: Node = AudioManagerScript.new()
	add_child(manager)

	var music_players: Array[AudioStreamPlayer] = []
	for child: Node in manager.get_children():
		if child is AudioStreamPlayer:
			var player: AudioStreamPlayer = child as AudioStreamPlayer
			if String(player.bus) == "Music":
				music_players.append(player)

	# Assert both music nodes are on Music bus.
	assert_int(music_players.size()).is_equal(2)
	for player: AudioStreamPlayer in music_players:
		assert_str(String(player.bus)).is_equal("Music")

	manager.free()


func test_music_ready_initial_state_is_stopped() -> void:
	# Arrange + Act
	var manager: Node = AudioManagerScript.new()
	add_child(manager)

	# Assert initial FSM state.
	assert_int(manager._music_state).is_equal(0)  # MusicState.STOPPED == 0
	manager.free()


# ── AC-2: STOPPED → PLAYING on first scene (no crossfade) ────────────────────

func test_music_first_scene_calls_start_first_play_not_crossfade() -> void:
	# Arrange
	var proxy: AudioManagerMusicProxy = _make_proxy_with_tracks()
	assert_int(proxy._music_state).is_equal(0)  # pre-condition: STOPPED

	# Act
	proxy._play_music_for_scene("scene-01")

	# Assert: first-play path taken, crossfade NOT called.
	assert_int(proxy.first_play_calls).is_equal(1)
	assert_int(proxy.crossfade_calls).is_equal(0)
	assert_str(proxy.last_first_play_path).is_equal(
		"res://assets/audio/music/ambient_a.ogg"
	)
	proxy.free()


func test_music_first_scene_transitions_to_playing_state() -> void:
	# Arrange
	var proxy: AudioManagerMusicProxy = _make_proxy_with_tracks()

	# Act
	proxy._play_music_for_scene("scene-01")

	# Assert FSM is now PLAYING (value == 1).
	assert_int(proxy._music_state).is_equal(1)  # MusicState.PLAYING == 1
	proxy.free()


# ── AC-3: PLAYING → CROSSFADING when track differs ───────────────────────────

func test_music_different_track_triggers_crossfade() -> void:
	# Arrange: establish PLAYING with "ambient_a"
	var proxy: AudioManagerMusicProxy = _make_proxy_with_tracks()
	proxy._play_music_for_scene("scene-01")
	assert_int(proxy._music_state).is_equal(1)  # PLAYING

	# Act: different track on scene-02
	proxy._play_music_for_scene("scene-02")

	# Assert: crossfade was triggered.
	assert_int(proxy.crossfade_calls).is_equal(1)
	assert_str(proxy.last_crossfade_path).is_equal(
		"res://assets/audio/music/ambient_b.ogg"
	)
	proxy.free()


func test_music_different_track_transitions_to_crossfading_state() -> void:
	# Arrange
	var proxy: AudioManagerMusicProxy = _make_proxy_with_tracks()
	proxy._play_music_for_scene("scene-01")

	# Act
	proxy._play_music_for_scene("scene-02")

	# Assert FSM is CROSSFADING (value == 2).
	assert_int(proxy._music_state).is_equal(2)  # MusicState.CROSSFADING == 2
	proxy.free()


# ── AC-4: same track → no crossfade, no interruption ─────────────────────────

func test_music_same_track_does_not_trigger_crossfade() -> void:
	# Arrange
	var proxy: AudioManagerMusicProxy = _make_proxy_with_tracks()
	proxy._play_music_for_scene("scene-01")
	assert_int(proxy.first_play_calls).is_equal(1)  # pre-condition

	# Act: same scene-01 again
	proxy._play_music_for_scene("scene-01")

	# Assert: neither first_play nor crossfade called a second time.
	assert_int(proxy.first_play_calls).is_equal(1)
	assert_int(proxy.crossfade_calls).is_equal(0)
	proxy.free()


func test_music_same_track_leaves_state_unchanged() -> void:
	# Arrange
	var proxy: AudioManagerMusicProxy = _make_proxy_with_tracks()
	proxy._play_music_for_scene("scene-01")

	# Act
	proxy._play_music_for_scene("scene-01")

	# Assert: state remains PLAYING, not bumped to CROSSFADING.
	assert_int(proxy._music_state).is_equal(1)  # PLAYING
	proxy.free()


# ── AC-5: scene with no registered track → STOPPED ───────────────────────────

func test_music_no_track_scene_calls_stop_music() -> void:
	# Arrange: PLAYING state
	var proxy: AudioManagerMusicProxy = _make_proxy_with_tracks()
	proxy._play_music_for_scene("scene-01")

	# Act: "scene-no-music" has no entry in mock_tracks → empty path
	proxy._play_music_for_scene("scene-no-music")

	# Assert: _stop_music was called.
	assert_int(proxy.stop_music_calls).is_equal(1)
	proxy.free()


func test_music_no_track_scene_transitions_to_stopped_state() -> void:
	# Arrange
	var proxy: AudioManagerMusicProxy = _make_proxy_with_tracks()
	proxy._play_music_for_scene("scene-01")

	# Act
	proxy._play_music_for_scene("scene-no-music")

	# Assert: FSM is STOPPED (value == 0).
	assert_int(proxy._music_state).is_equal(0)  # STOPPED
	proxy.free()


# ── AC-6: mid-crossfade interrupt ────────────────────────────────────────────
#
# Verifies that a third track request while crossfading issues a second
# _start_crossfade call. The tween-kill part is exercised by the real
# _start_crossfade (not the proxy override); here we test the FSM routing only.

func test_music_mid_crossfade_interrupt_calls_crossfade_again() -> void:
	# Arrange: PLAYING → start first crossfade
	var proxy: AudioManagerMusicProxy = _make_proxy_with_tracks()
	proxy._play_music_for_scene("scene-01")
	proxy._play_music_for_scene("scene-02")
	assert_int(proxy._music_state).is_equal(2)  # CROSSFADING pre-condition

	# Act: third track request arrives while in CROSSFADING state
	proxy._play_music_for_scene("scene-03")

	# Assert: _start_crossfade called twice (once original, once interrupt).
	assert_int(proxy.crossfade_calls).is_equal(2)
	assert_str(proxy.last_crossfade_path).is_equal(
		"res://assets/audio/music/ambient_c.ogg"
	)
	proxy.free()


# ── AC-7: silent mode → _play_music_for_scene is a no-op ─────────────────────

func test_music_silent_mode_play_for_scene_does_not_call_first_play() -> void:
	# Arrange: silent mode set (config-missing path)
	var proxy: AudioManagerMusicProxy = _make_proxy_with_tracks()
	proxy._silent_mode = true

	# Act
	proxy._play_music_for_scene("scene-01")

	# Assert: no music methods invoked.
	assert_int(proxy.first_play_calls).is_equal(0)
	assert_int(proxy.crossfade_calls).is_equal(0)
	proxy.free()


func test_music_silent_mode_state_remains_stopped() -> void:
	# Arrange
	var proxy: AudioManagerMusicProxy = _make_proxy_with_tracks()
	proxy._silent_mode = true

	# Act
	proxy._play_music_for_scene("scene-01")

	# Assert: FSM stays STOPPED — no state transition without audio hardware.
	assert_int(proxy._music_state).is_equal(0)  # STOPPED
	proxy.free()


func test_music_silent_mode_current_track_path_unchanged() -> void:
	# Arrange
	var proxy: AudioManagerMusicProxy = _make_proxy_with_tracks()
	proxy._silent_mode = true

	# Act
	proxy._play_music_for_scene("scene-01")

	# Assert: no track path recorded in silent mode.
	assert_str(proxy._current_track_path).is_equal("")
	proxy.free()


# ── music players always created even in silent mode (TR-019) ─────────────────

func test_music_silent_mode_init_still_creates_music_players() -> void:
	# Arrange + Act: AudioManager without a valid config enters silent mode.
	var manager: Node = AudioManagerScript.new()
	add_child(manager)

	# Assert: even in silent mode the two Music bus players exist.
	var count: int = 0
	for child: Node in manager.get_children():
		if child is AudioStreamPlayer:
			var player: AudioStreamPlayer = child as AudioStreamPlayer
			if String(player.bus) == "Music":
				count += 1
	assert_int(count).is_equal(2)
	manager.free()


# ── scene_started signal triggers music selection ─────────────────────────────

func test_music_scene_started_signal_routes_to_play_for_scene() -> void:
	# Arrange: proxy connected to EventBus via _connect_signals() in _ready()
	var proxy: AudioManagerMusicProxy = _make_proxy_with_tracks()

	# Act: emit the scene_started signal as gameplay would
	EventBus.scene_started.emit("scene-01")

	# Assert: _start_first_play was called (STOPPED → PLAYING path)
	assert_int(proxy.first_play_calls).is_equal(1)
	proxy.free()
