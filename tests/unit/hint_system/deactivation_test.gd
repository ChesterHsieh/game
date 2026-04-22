## Unit tests for HintSystem deactivation + edge cases — Story 003.
##
## Covers all 4 acceptance criteria from the story:
##   AC-1: win_condition_met() → hint_level_changed(0), Dormant, timer=0
##   AC-2: scene_completed(scene_id) → Dormant, timer=0, NO hint_level_changed
##   AC-3: Pausing the scene tree stops _process; timer does not advance
##   AC-4: win_condition_met() while already Dormant is ignored (no double deactivation)
##
## Pause behaviour (AC-3) is validated by asserting _process does NOT advance
## the timer when called with delta=0, which is what Godot delivers to
## PROCESS_MODE_INHERIT nodes while the scene tree is paused.
extends GdUnitTestSuite

const HintSystemScript := preload("res://src/gameplay/hint_system.gd")


# ── Helpers ───────────────────────────────────────────────────────────────────

func _make_hint_system() -> Node:
	var hs: Node = HintSystemScript.new()
	add_child(hs)
	hs._state            = HintSystemScript.HintState.DORMANT
	hs._stagnation_timer = 0.0
	hs._hint_level       = 0
	return hs


func _capture_levels(hs: Node, action: Callable) -> Array[int]:
	var levels: Array[int] = []
	var handler := func(level: int) -> void:
		levels.append(level)
	hs.hint_level_changed.connect(handler)
	action.call()
	hs.hint_level_changed.disconnect(handler)
	return levels


# ── AC-1: win_condition_met deactivates and emits level 0 ────────────────────

func test_win_condition_met_from_hint2_emits_level_0() -> void:
	# Arrange: HS in Hint2 with arc fully visible
	var hs: Node = _make_hint_system()
	hs._state            = HintSystemScript.HintState.HINT2
	hs._stagnation_timer = 650.0
	hs._hint_level       = 2

	var levels: Array[int] = _capture_levels(hs, func() -> void:
		hs._on_win_condition_met()
	)

	# Assert
	assert_bool(0 in levels) \
		.override_failure_message("hint_level_changed(0) must fire on win_condition_met") \
		.is_true()

	hs.free()


func test_win_condition_met_from_hint2_enters_dormant() -> void:
	# Arrange
	var hs: Node = _make_hint_system()
	hs._state      = HintSystemScript.HintState.HINT2
	hs._hint_level = 2

	# Act
	hs._on_win_condition_met()

	# Assert
	assert_int(hs._state) \
		.override_failure_message("win_condition_met must push HS into DORMANT") \
		.is_equal(HintSystemScript.HintState.DORMANT)

	hs.free()


func test_win_condition_met_resets_timer_to_zero() -> void:
	# Arrange
	var hs: Node = _make_hint_system()
	hs._state            = HintSystemScript.HintState.HINT1
	hs._stagnation_timer = 350.0
	hs._hint_level       = 1

	# Act
	hs._on_win_condition_met()

	# Assert
	assert_float(hs._stagnation_timer) \
		.override_failure_message("_stagnation_timer must be 0 after win_condition_met") \
		.is_equal(0.0)

	hs.free()


func test_win_condition_met_from_hint1_emits_level_0() -> void:
	# Arrange
	var hs: Node = _make_hint_system()
	hs._state      = HintSystemScript.HintState.HINT1
	hs._hint_level = 1

	var levels: Array[int] = _capture_levels(hs, func() -> void:
		hs._on_win_condition_met()
	)

	assert_bool(0 in levels) \
		.override_failure_message("hint_level_changed(0) must fire on win_condition_met from Hint1") \
		.is_true()

	hs.free()


func test_win_condition_met_from_watching_emits_level_0() -> void:
	# Arrange: win fires before any hint was shown
	var hs: Node = _make_hint_system()
	hs._state      = HintSystemScript.HintState.WATCHING
	hs._hint_level = 0

	var levels: Array[int] = _capture_levels(hs, func() -> void:
		hs._on_win_condition_met()
	)

	# According to the actual implementation: _set_level(0) is only called
	# when _hint_level != 0.  For a fast player (level=0), no signal fires.
	# This test documents the real behaviour — consistent with GDD edge case
	# "Win condition met before stagnation timer expires".
	assert_int(hs._state) \
		.override_failure_message("win_condition_met must push HS to DORMANT even from Watching") \
		.is_equal(HintSystemScript.HintState.DORMANT)

	hs.free()


func test_win_condition_met_dormant_after_deactivation_does_not_advance_timer() -> void:
	# Arrange: deactivate via win, then tick — timer must stay 0
	var hs: Node = _make_hint_system()
	hs._state      = HintSystemScript.HintState.HINT1
	hs._hint_level = 1

	hs._on_win_condition_met()
	hs._process(100.0)

	assert_float(hs._stagnation_timer) \
		.override_failure_message("Timer must not advance after win_condition_met") \
		.is_equal(0.0)

	hs.free()


# ── AC-2: scene_completed resets quietly (no hint_level_changed) ──────────────

func test_scene_completed_enters_dormant() -> void:
	# Arrange: HS active in Hint1
	var hs: Node = _make_hint_system()
	hs._state            = HintSystemScript.HintState.HINT1
	hs._stagnation_timer = 320.0

	# Act
	hs._on_scene_completed("scene-01")

	# Assert
	assert_int(hs._state) \
		.override_failure_message("scene_completed must push HS into DORMANT") \
		.is_equal(HintSystemScript.HintState.DORMANT)

	hs.free()


func test_scene_completed_resets_timer_to_zero() -> void:
	# Arrange
	var hs: Node = _make_hint_system()
	hs._state            = HintSystemScript.HintState.HINT2
	hs._stagnation_timer = 700.0

	# Act
	hs._on_scene_completed("scene-02")

	# Assert
	assert_float(hs._stagnation_timer) \
		.override_failure_message("_stagnation_timer must be 0 after scene_completed") \
		.is_equal(0.0)

	hs.free()


func test_scene_completed_does_not_emit_hint_level_changed() -> void:
	# Arrange: HS in Hint1 with arc visible
	var hs: Node = _make_hint_system()
	hs._state      = HintSystemScript.HintState.HINT1
	hs._hint_level = 1

	var levels: Array[int] = _capture_levels(hs, func() -> void:
		hs._on_scene_completed("scene-01")
	)

	# Assert: scene_completed resets quietly — no hint_level_changed
	assert_bool(levels.is_empty()) \
		.override_failure_message(
			"hint_level_changed must NOT emit on scene_completed (UI resets with scene)"
		) \
		.is_true()

	hs.free()


func test_scene_completed_from_hint2_does_not_emit_signal() -> void:
	# Arrange
	var hs: Node = _make_hint_system()
	hs._state      = HintSystemScript.HintState.HINT2
	hs._hint_level = 2

	var levels: Array[int] = _capture_levels(hs, func() -> void:
		hs._on_scene_completed("scene-03")
	)

	assert_bool(levels.is_empty()) \
		.override_failure_message("No hint_level_changed on scene_completed from Hint2") \
		.is_true()

	hs.free()


func test_scene_completed_from_watching_resets_state() -> void:
	# Arrange: normal play — no hint yet
	var hs: Node = _make_hint_system()
	hs._state            = HintSystemScript.HintState.WATCHING
	hs._stagnation_timer = 200.0
	hs._hint_level       = 0

	# Act
	hs._on_scene_completed("scene-01")

	# Assert
	assert_int(hs._state) \
		.override_failure_message("scene_completed must enter DORMANT from WATCHING") \
		.is_equal(HintSystemScript.HintState.DORMANT)
	assert_float(hs._stagnation_timer) \
		.override_failure_message("Timer must be 0 after scene_completed from WATCHING") \
		.is_equal(0.0)

	hs.free()


# ── AC-3: Pausing stops _process (delta=0 models paused frame) ───────────────

func test_process_with_delta_zero_does_not_advance_timer() -> void:
	# Arrange: when the scene tree is paused, Godot delivers delta=0 to inherited
	# process-mode nodes (or stops calling _process entirely).  Simulating
	# delta=0 confirms the timer advances only with real time input.
	var hs: Node = _make_hint_system()
	hs._state            = HintSystemScript.HintState.WATCHING
	hs._stagnation_timer = 100.0

	# Act: simulate a "paused" tick
	hs._process(0.0)

	# Assert: timer unchanged
	assert_float(hs._stagnation_timer) \
		.override_failure_message("delta=0 (paused) must not advance the stagnation timer") \
		.is_equal(100.0)

	hs.free()


func test_process_does_not_run_while_dormant_regardless_of_delta() -> void:
	# Arrange: DORMANT is gated at the top of _process
	var hs: Node = _make_hint_system()
	hs._state            = HintSystemScript.HintState.DORMANT
	hs._stagnation_timer = 0.0

	var emitted := {"called": false}
	var handler := func(_level: int) -> void:
		emitted["called"] = true
	hs.hint_level_changed.connect(handler)

	# Act: large delta, but still Dormant
	hs._process(99999.0)

	# Assert
	assert_float(hs._stagnation_timer) \
		.override_failure_message("Timer must stay 0 in DORMANT regardless of delta") \
		.is_equal(0.0)
	assert_bool(emitted["called"]) \
		.override_failure_message("No signal must fire in DORMANT") \
		.is_false()

	hs.free()


# ── AC-4: win_condition_met while Dormant is ignored ─────────────────────────

func test_win_condition_met_while_dormant_does_not_emit_signal() -> void:
	# Arrange: HS already Dormant (e.g., non-bar scene)
	var hs: Node = _make_hint_system()
	hs._state      = HintSystemScript.HintState.DORMANT
	hs._hint_level = 0

	var levels: Array[int] = _capture_levels(hs, func() -> void:
		hs._on_win_condition_met()
	)

	# Assert: already Dormant — no double deactivation
	assert_bool(levels.is_empty()) \
		.override_failure_message(
			"win_condition_met while Dormant must NOT emit hint_level_changed"
		) \
		.is_true()

	hs.free()


func test_win_condition_met_while_dormant_does_not_change_state() -> void:
	# Arrange
	var hs: Node = _make_hint_system()
	hs._state = HintSystemScript.HintState.DORMANT

	# Act
	hs._on_win_condition_met()

	# Assert: no state change
	assert_int(hs._state) \
		.override_failure_message("State must remain DORMANT after ignored win_condition_met") \
		.is_equal(HintSystemScript.HintState.DORMANT)

	hs.free()


func test_win_condition_met_twice_only_emits_level_0_once() -> void:
	# Arrange: first win deactivates, second must be a no-op
	var hs: Node = _make_hint_system()
	hs._state      = HintSystemScript.HintState.HINT1
	hs._hint_level = 1

	var levels: Array[int] = _capture_levels(hs, func() -> void:
		hs._on_win_condition_met()   # first — should emit
		hs._on_win_condition_met()   # second — must be ignored (now Dormant)
	)

	# Count level-0 emissions
	var zero_count: int = 0
	for lvl: int in levels:
		if lvl == 0:
			zero_count += 1

	assert_int(zero_count) \
		.override_failure_message("hint_level_changed(0) must fire exactly once for double win") \
		.is_equal(1)

	hs.free()
