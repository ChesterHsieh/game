## Unit tests for HintSystem stagnation timer + hint_level_changed — Story 002.
##
## Covers all 6 acceptance criteria from the story:
##   AC-1: While Watching, _timer increments by delta each frame
##   AC-2: _timer >= stagnation_sec → hint_level_changed(1), enter Hint1
##   AC-3: _timer >= stagnation_sec * 2 → hint_level_changed(2), enter Hint2
##   AC-4: combination_executed while Watching/Hint1/Hint2 → level_changed(0), timer=0, Watching
##   AC-5: hint_level_changed(0) emitted even if already at level 0 (idempotent)
##   AC-6: combination_executed handler ignores payload (6-param contract)
##
## Time is advanced by calling _process(delta) directly — no real await/timer.
## Signal capture uses a local Array to record every emitted level.
extends GdUnitTestSuite

const HintSystemScript := preload("res://src/gameplay/hint_system.gd")


# ── Helpers ───────────────────────────────────────────────────────────────────

## Returns a fresh HintSystem in WATCHING state with a small stagnation_sec
## so tests can cross the threshold without large delta values.
func _make_watching_hs(stagnation_sec: float = 10.0) -> Node:
	var hs: Node = HintSystemScript.new()
	add_child(hs)
	hs._state            = HintSystemScript.HintState.WATCHING
	hs._stagnation_timer = 0.0
	hs._hint_level       = 0
	# Override the production constant so tests run with small deltas.
	# HintSystem uses STAGNATION_SEC const; we reach it via the timer threshold
	# comparison in _process by injecting a large-enough delta directly.
	# We store the intended sec as a property the test controls externally.
	hs.set_meta("_test_stagnation_sec", stagnation_sec)
	return hs


## Advance time by calling _process with a total delta split into steps.
## NOTE: HintSystem._process() uses STAGNATION_SEC (const 300.0), so to test
## threshold crossings we directly set _stagnation_timer and call _process(0).
func _set_timer_and_tick(hs: Node, timer_value: float) -> void:
	hs._stagnation_timer = timer_value
	hs._process(0.0)


## Collect hint_level_changed emissions into an Array during a block.
func _capture_levels(hs: Node, action: Callable) -> Array[int]:
	var levels: Array[int] = []
	var handler := func(level: int) -> void:
		levels.append(level)
	hs.hint_level_changed.connect(handler)
	action.call()
	hs.hint_level_changed.disconnect(handler)
	return levels


# ── AC-1: Timer increments by delta while Watching ───────────────────────────

func test_stagnation_timer_increments_by_delta_while_watching() -> void:
	# Arrange
	var hs: Node = _make_watching_hs()
	hs._stagnation_timer = 0.0

	# Act: inject a known delta — small enough not to cross STAGNATION_SEC
	hs._process(5.0)

	# Assert: timer advanced by exactly 5.0
	assert_float(hs._stagnation_timer) \
		.override_failure_message("_stagnation_timer must advance by delta each tick") \
		.is_equal(5.0)

	hs.free()


func test_stagnation_timer_accumulates_across_multiple_frames() -> void:
	# Arrange
	var hs: Node = _make_watching_hs()
	hs._stagnation_timer = 0.0

	# Act: simulate three frames totalling 3.0 seconds
	hs._process(1.0)
	hs._process(1.0)
	hs._process(1.0)

	# Assert: 3.0 total (well below STAGNATION_SEC — no state change)
	assert_float(hs._stagnation_timer) \
		.override_failure_message("Timer must accumulate across frames") \
		.is_equal(3.0)

	hs.free()


func test_stagnation_timer_does_not_tick_while_hint2() -> void:
	# Arrange: Hint2 is the terminal hint state — timer still ticks in HINT1 but
	# the _process guard only runs for WATCHING and HINT1.
	var hs: Node = _make_watching_hs()
	hs._state            = HintSystemScript.HintState.HINT2
	hs._stagnation_timer = 999.0

	# Act: tick
	hs._process(5.0)

	# Assert: HINT2 is not in the tick guard — timer should NOT advance
	assert_float(hs._stagnation_timer) \
		.override_failure_message("Timer must NOT advance while in HINT2") \
		.is_equal(999.0)

	hs.free()


# ── AC-2: Crossing STAGNATION_SEC → Hint1 + level 1 ─────────────────────────

func test_stagnation_timer_crossing_threshold_emits_level_1() -> void:
	# Arrange
	var hs: Node = _make_watching_hs()
	hs._state            = HintSystemScript.HintState.WATCHING
	hs._stagnation_timer = 0.0

	var levels: Array[int] = _capture_levels(hs, func() -> void:
		# Set timer just below threshold then cross it in one tick
		hs._stagnation_timer = HintSystemScript.STAGNATION_SEC - 0.1
		hs._process(0.2)  # crosses STAGNATION_SEC
	)

	# Assert
	assert_bool(1 in levels) \
		.override_failure_message("hint_level_changed(1) must fire at STAGNATION_SEC") \
		.is_true()
	assert_int(hs._state) \
		.override_failure_message("State must be HINT1 after crossing stagnation_sec") \
		.is_equal(HintSystemScript.HintState.HINT1)

	hs.free()


func test_stagnation_timer_at_exact_threshold_emits_level_1() -> void:
	# Arrange: timer lands exactly on STAGNATION_SEC
	var hs: Node = _make_watching_hs()
	hs._state            = HintSystemScript.HintState.WATCHING

	var levels: Array[int] = _capture_levels(hs, func() -> void:
		hs._stagnation_timer = HintSystemScript.STAGNATION_SEC
		hs._process(0.0)
	)

	# Assert: exact boundary is >=, so level 1 fires
	assert_bool(1 in levels) \
		.override_failure_message("hint_level_changed(1) must fire at exact STAGNATION_SEC boundary") \
		.is_true()

	hs.free()


func test_stagnation_timer_just_below_threshold_does_not_emit() -> void:
	# Arrange: stay just under STAGNATION_SEC — no signal expected
	var hs: Node = _make_watching_hs()
	hs._state            = HintSystemScript.HintState.WATCHING

	var levels: Array[int] = _capture_levels(hs, func() -> void:
		hs._stagnation_timer = HintSystemScript.STAGNATION_SEC - 1.0
		hs._process(0.0)
	)

	# Assert
	assert_bool(levels.is_empty()) \
		.override_failure_message("No signal must fire below STAGNATION_SEC") \
		.is_true()
	assert_int(hs._state) \
		.override_failure_message("State must remain WATCHING below threshold") \
		.is_equal(HintSystemScript.HintState.WATCHING)

	hs.free()


# ── AC-3: Crossing STAGNATION_SEC * 2 → Hint2 + level 2 ─────────────────────

func test_stagnation_timer_crossing_double_threshold_emits_level_2() -> void:
	# Arrange: start in HINT1 with timer just below double threshold
	var hs: Node = _make_watching_hs()
	hs._state            = HintSystemScript.HintState.HINT1
	hs._hint_level       = 1

	var levels: Array[int] = _capture_levels(hs, func() -> void:
		hs._stagnation_timer = HintSystemScript.STAGNATION_SEC * 2.0 - 0.1
		hs._process(0.2)  # crosses STAGNATION_SEC * 2
	)

	# Assert
	assert_bool(2 in levels) \
		.override_failure_message("hint_level_changed(2) must fire at STAGNATION_SEC * 2") \
		.is_true()
	assert_int(hs._state) \
		.override_failure_message("State must be HINT2 after crossing double threshold") \
		.is_equal(HintSystemScript.HintState.HINT2)

	hs.free()


func test_stagnation_timer_double_threshold_only_emits_level_2_once() -> void:
	# Arrange: confirm we only get exactly one level-2 emission per crossing
	var hs: Node = _make_watching_hs()
	hs._state            = HintSystemScript.HintState.HINT1
	hs._hint_level       = 1

	var levels: Array[int] = _capture_levels(hs, func() -> void:
		hs._stagnation_timer = HintSystemScript.STAGNATION_SEC * 2.0 - 0.1
		hs._process(0.2)  # first crossing
		hs._process(1.0)  # further ticks — must not re-emit
	)

	# Count level-2 emissions
	var level_2_count: int = 0
	for lvl: int in levels:
		if lvl == 2:
			level_2_count += 1

	assert_int(level_2_count) \
		.override_failure_message("hint_level_changed(2) must fire exactly once per crossing") \
		.is_equal(1)

	hs.free()


# ── AC-4: combination_executed resets timer + returns to Watching ─────────────

func test_combination_executed_from_hint2_resets_to_watching() -> void:
	# Arrange: HS in HINT2 with a non-zero timer
	var hs: Node = _make_watching_hs()
	hs._state            = HintSystemScript.HintState.HINT2
	hs._stagnation_timer = 650.0
	hs._hint_level       = 2

	var levels: Array[int] = _capture_levels(hs, func() -> void:
		hs._on_combination_executed("", "", "", "", "", "")
	)

	# Assert
	assert_bool(0 in levels) \
		.override_failure_message("hint_level_changed(0) must fire on combination_executed from Hint2") \
		.is_true()
	assert_float(hs._stagnation_timer) \
		.override_failure_message("_stagnation_timer must reset to 0 on combination_executed") \
		.is_equal(0.0)
	assert_int(hs._state) \
		.override_failure_message("State must return to WATCHING after combo") \
		.is_equal(HintSystemScript.HintState.WATCHING)

	hs.free()


func test_combination_executed_from_hint1_resets_to_watching() -> void:
	# Arrange: HS in HINT1
	var hs: Node = _make_watching_hs()
	hs._state            = HintSystemScript.HintState.HINT1
	hs._stagnation_timer = 320.0
	hs._hint_level       = 1

	var levels: Array[int] = _capture_levels(hs, func() -> void:
		hs._on_combination_executed("", "", "", "", "", "")
	)

	# Assert
	assert_bool(0 in levels) \
		.override_failure_message("hint_level_changed(0) must fire on combination_executed from Hint1") \
		.is_true()
	assert_float(hs._stagnation_timer) \
		.override_failure_message("Timer must reset to 0 after combo in Hint1") \
		.is_equal(0.0)
	assert_int(hs._state) \
		.override_failure_message("State must return to WATCHING after combo in Hint1") \
		.is_equal(HintSystemScript.HintState.WATCHING)

	hs.free()


func test_combination_executed_from_watching_resets_timer() -> void:
	# Arrange: HS Watching with partial timer
	var hs: Node = _make_watching_hs()
	hs._state            = HintSystemScript.HintState.WATCHING
	hs._stagnation_timer = 150.0
	hs._hint_level       = 0

	hs._on_combination_executed("", "", "", "", "", "")

	# Assert: timer reset, still Watching
	assert_float(hs._stagnation_timer) \
		.override_failure_message("Timer must reset to 0 on combo in Watching") \
		.is_equal(0.0)
	assert_int(hs._state) \
		.override_failure_message("State must remain WATCHING after combo in Watching") \
		.is_equal(HintSystemScript.HintState.WATCHING)

	hs.free()


func test_combination_executed_timer_resets_allow_level1_again() -> void:
	# Arrange: combo resets from Hint1; then no more combos → Level 1 re-appears
	var hs: Node = _make_watching_hs()
	hs._state            = HintSystemScript.HintState.HINT1
	hs._stagnation_timer = 320.0
	hs._hint_level       = 1

	# Combo fires — resets
	hs._on_combination_executed("", "", "", "", "", "")
	assert_float(hs._stagnation_timer).is_equal(0.0)
	assert_int(hs._state).is_equal(HintSystemScript.HintState.WATCHING)

	# Now advance past STAGNATION_SEC again
	var levels: Array[int] = _capture_levels(hs, func() -> void:
		hs._stagnation_timer = HintSystemScript.STAGNATION_SEC
		hs._process(0.0)
	)

	assert_bool(1 in levels) \
		.override_failure_message("Level 1 must re-appear after timer restarts post-combo") \
		.is_true()

	hs.free()


# ── AC-5: hint_level_changed(0) is idempotent ────────────────────────────────

func test_combination_executed_emits_level_0_even_when_already_at_level_0() -> void:
	# Arrange: HS Watching, no hint showing (level = 0)
	var hs: Node = _make_watching_hs()
	hs._state            = HintSystemScript.HintState.WATCHING
	hs._stagnation_timer = 5.0
	hs._hint_level       = 0

	var levels: Array[int] = _capture_levels(hs, func() -> void:
		hs._on_combination_executed("", "", "", "", "", "")
	)

	# Assert: level 0 MUST be emitted even though it was already 0
	assert_bool(0 in levels) \
		.override_failure_message(
			"hint_level_changed(0) must fire idempotently even when hint was already 0"
		) \
		.is_true()

	hs.free()


# ── AC-6: combination_executed handler accepts 6 params ──────────────────────

func test_combination_executed_handler_accepts_all_six_params() -> void:
	# Arrange: verify the 6-param arity contract from GDD + story implementation notes
	var hs: Node = _make_watching_hs()
	hs._state = HintSystemScript.HintState.WATCHING

	# Act: call with realistic 6-param values (recipe_id, template, a, b, ca, cb)
	# If arity were wrong this would raise a GDScript error.
	hs._on_combination_executed(
		"recipe-001",
		"Additive",
		"inst-a-001",
		"inst-b-002",
		"card-a",
		"card-b"
	)

	# Assert: handler ran without error; timer reset
	assert_float(hs._stagnation_timer) \
		.override_failure_message("6-param handler must run without error and reset timer") \
		.is_equal(0.0)

	hs.free()


func test_combination_executed_ignored_while_dormant() -> void:
	# Arrange: HS is Dormant — combination_executed must be a no-op
	var hs: Node = _make_watching_hs()
	hs._state            = HintSystemScript.HintState.DORMANT
	hs._stagnation_timer = 0.0

	var levels: Array[int] = _capture_levels(hs, func() -> void:
		hs._on_combination_executed("", "", "", "", "", "")
	)

	# Assert: no signal, no state change
	assert_bool(levels.is_empty()) \
		.override_failure_message("combination_executed must be ignored while Dormant") \
		.is_true()
	assert_int(hs._state) \
		.override_failure_message("State must remain DORMANT after combo while Dormant") \
		.is_equal(HintSystemScript.HintState.DORMANT)

	hs.free()
