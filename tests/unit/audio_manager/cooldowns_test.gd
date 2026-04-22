## Unit tests for AudioManager per-event cooldowns — Story 004.
##
## Covers all 6 QA acceptance criteria from the story:
##   AC-1: request at T+150ms with cooldown_ms=200 is blocked
##   AC-2: request at T+200ms with cooldown_ms=200 is allowed
##   AC-3: first play of any event is always allowed (last=0)
##   AC-4: win_condition_met fires once then blocks until scene_completed resets
##   AC-5: _on_scene_completed resets _win_played_this_scene to false
##   AC-6: cooldowns tick correctly (elapsed >= cooldown_ms) even when muted
##
## Timing is injected via _clock_fn to make tests deterministic.
## No live audio nodes are required — pure logic verification.
extends GdUnitTestSuite

const AudioManagerScript := preload("res://src/core/audio_manager.gd")


# ── helpers ──────────────────────────────────────────────────────────────────

## Creates a fresh AudioManager with a fake clock that returns current_time_msec.
## The clock value is mutable via the returned Dictionary so tests can advance it.
func _make_manager_with_clock() -> Array:
	var manager: Node = AudioManagerScript.new()
	var clock_state: Dictionary = {"time": 0}
	manager._clock_fn = func() -> int: return clock_state["time"]
	add_child(manager)
	return [manager, clock_state]


# ── AC-1: cooldown blocks rapid re-play ──────────────────────────────────────

func test_cooldown_is_cooldown_ready_blocks_within_cooldown_window() -> void:
	# Arrange
	var result: Array = _make_manager_with_clock()
	var manager: Node = result[0]
	var clock_state: Dictionary = result[1]

	clock_state["time"] = 1000
	manager._last_play_time["card_snap"] = 1000  # played at T=1000

	# Act: check at T+150ms (within 200ms cooldown)
	clock_state["time"] = 1150
	var ready: bool = manager._is_cooldown_ready("card_snap", 200)

	# Assert: still within cooldown window — must block
	assert_bool(ready).is_false()
	manager.free()


# ── AC-2: cooldown allows after expiry ───────────────────────────────────────

func test_cooldown_is_cooldown_ready_allows_at_exact_cooldown_boundary() -> void:
	# Arrange
	var result: Array = _make_manager_with_clock()
	var manager: Node = result[0]
	var clock_state: Dictionary = result[1]

	clock_state["time"] = 1000
	manager._last_play_time["card_snap"] = 1000

	# Act: check at T+200ms (exactly at boundary — allowed per spec)
	clock_state["time"] = 1200
	var ready: bool = manager._is_cooldown_ready("card_snap", 200)

	# Assert: elapsed == cooldown_ms → allowed
	assert_bool(ready).is_true()
	manager.free()


func test_cooldown_is_cooldown_ready_allows_beyond_cooldown_window() -> void:
	# Arrange
	var result: Array = _make_manager_with_clock()
	var manager: Node = result[0]
	var clock_state: Dictionary = result[1]

	clock_state["time"] = 1000
	manager._last_play_time["card_snap"] = 1000

	# Act: check at T+500ms (well past 200ms cooldown)
	clock_state["time"] = 1500
	var ready: bool = manager._is_cooldown_ready("card_snap", 200)

	# Assert
	assert_bool(ready).is_true()
	manager.free()


# ── AC-3: first play always allowed ──────────────────────────────────────────

func test_cooldown_is_cooldown_ready_first_play_always_allowed() -> void:
	# Arrange: event has never been played — absent from _last_play_time
	var result: Array = _make_manager_with_clock()
	var manager: Node = result[0]
	var clock_state: Dictionary = result[1]

	clock_state["time"] = 500  # any current time

	# Act: event not in dictionary — defaults to last=0; 500-0 >= 200 → true
	var ready: bool = manager._is_cooldown_ready("card_snap", 200)

	# Assert
	assert_bool(ready).is_true()
	manager.free()


func test_cooldown_record_play_writes_timestamp() -> void:
	# Arrange
	var result: Array = _make_manager_with_clock()
	var manager: Node = result[0]
	var clock_state: Dictionary = result[1]

	clock_state["time"] = 999

	# Act
	manager._record_play("card_snap")

	# Assert: timestamp recorded matches current clock
	assert_int(manager._last_play_time.get("card_snap", -1) as int).is_equal(999)
	manager.free()


# ── AC-4: win once-per-scene ─────────────────────────────────────────────────

func test_cooldown_win_fires_when_not_yet_played_this_scene() -> void:
	# Arrange
	var result: Array = _make_manager_with_clock()
	var manager: Node = result[0]

	manager._win_played_this_scene = false

	# Act
	var ready: bool = manager._is_cooldown_ready("win_condition_met", 0)

	# Assert: flag is false → allowed
	assert_bool(ready).is_true()
	manager.free()


func test_cooldown_win_blocks_after_record_play() -> void:
	# Arrange
	var result: Array = _make_manager_with_clock()
	var manager: Node = result[0]

	manager._win_played_this_scene = false
	assert_bool(manager._is_cooldown_ready("win_condition_met", 0)).is_true()

	# Act: record the win play
	manager._record_play("win_condition_met")

	# Assert: subsequent request is blocked
	var ready: bool = manager._is_cooldown_ready("win_condition_met", 0)
	assert_bool(ready).is_false()
	manager.free()


func test_cooldown_record_play_sets_win_played_flag() -> void:
	# Arrange
	var result: Array = _make_manager_with_clock()
	var manager: Node = result[0]

	manager._win_played_this_scene = false

	# Act
	manager._record_play("win_condition_met")

	# Assert
	assert_bool(manager._win_played_this_scene).is_true()
	manager.free()


# ── AC-5: win cooldown resets on scene_completed ─────────────────────────────

func test_cooldown_scene_completed_resets_win_played_flag() -> void:
	# Arrange: win was already played this scene
	var result: Array = _make_manager_with_clock()
	var manager: Node = result[0]

	manager._win_played_this_scene = true

	# Act
	manager._on_scene_completed("scene-01")

	# Assert: flag cleared — win is allowed again for next scene
	assert_bool(manager._win_played_this_scene).is_false()
	manager.free()


func test_cooldown_win_allowed_again_after_scene_completed() -> void:
	# Arrange: win already played, then scene resets
	var result: Array = _make_manager_with_clock()
	var manager: Node = result[0]

	manager._record_play("win_condition_met")
	assert_bool(manager._is_cooldown_ready("win_condition_met", 0)).is_false()

	# Act
	manager._on_scene_completed("scene-01")

	# Assert: next win check allowed
	var ready: bool = manager._is_cooldown_ready("win_condition_met", 0)
	assert_bool(ready).is_true()
	manager.free()


# ── AC-6: cooldowns tick even when muted ─────────────────────────────────────

func test_cooldown_ticks_correctly_regardless_of_silent_mode() -> void:
	# Arrange: silent mode active; event played at T=1000
	var result: Array = _make_manager_with_clock()
	var manager: Node = result[0]
	var clock_state: Dictionary = result[1]

	manager._silent_mode = true
	clock_state["time"] = 1000
	manager._record_play("card_snap")

	# Act: check at T+300ms (cooldown_ms=200 → should pass)
	clock_state["time"] = 1300
	var ready: bool = manager._is_cooldown_ready("card_snap", 200)

	# Assert: elapsed 300ms >= 200ms → allowed even in silent mode
	assert_bool(ready).is_true()
	manager.free()


func test_cooldown_blocks_in_silent_mode_within_window() -> void:
	# Arrange
	var result: Array = _make_manager_with_clock()
	var manager: Node = result[0]
	var clock_state: Dictionary = result[1]

	manager._silent_mode = true
	clock_state["time"] = 1000
	manager._record_play("card_snap")

	# Act: check at T+50ms (within 200ms cooldown)
	clock_state["time"] = 1050
	var ready: bool = manager._is_cooldown_ready("card_snap", 200)

	# Assert: still blocked in silent mode — cooldown does not skip muted state
	assert_bool(ready).is_false()
	manager.free()


# ── zero cooldown always allows ───────────────────────────────────────────────

func test_cooldown_zero_cooldown_ms_always_allows() -> void:
	# Arrange: event played at T=1000, cooldown_ms=0
	var result: Array = _make_manager_with_clock()
	var manager: Node = result[0]
	var clock_state: Dictionary = result[1]

	clock_state["time"] = 1000
	manager._record_play("card_snap")

	# Act: check immediately at T=1000 with zero cooldown
	var ready: bool = manager._is_cooldown_ready("card_snap", 0)

	# Assert: 0ms elapsed >= 0ms cooldown → allowed
	assert_bool(ready).is_true()
	manager.free()
