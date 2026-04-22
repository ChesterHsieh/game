## Unit tests for StatusBarSystem passive decay + sustain win condition — Story 003.
##
## Covers all 5 acceptance criteria from story-003-decay-sustain.md:
##   AC-1: Each bar ticks down by decay_rate_per_sec * delta each frame; clamped at 0
##   AC-2: Bar values at 0 with decay still running stay at 0 (no negative values)
##   AC-3: _sustained_time increments while all bars >= threshold; resets if any bar drops
##   AC-4: win_condition_met() emitted exactly once when _sustained_time >= duration_sec
##   AC-5: Dormant and Complete states: _process is a no-op (no decay, no monitoring)
##
## GDD Formulas verified:
##   Decay:   new_value = clamp(current_value - (decay_rate_per_sec * delta_time), 0, max_value)
##   Sustain: sustained_time += delta  when all bars >= threshold; else sustained_time = 0
##   Win:     if sustained_time >= duration_sec → emit win_condition_met(); enter Complete
##
## All time advancement uses direct _process(delta) calls — no real clock or await.
extends GdUnitTestSuite

const SBSScript := preload("res://src/gameplay/status_bar_system.gd")


# ── helpers ───────────────────────────────────────────────────────────────────

## Creates an Active SBS with the given bar configurations and win condition.
## bar_configs: Array of { id, initial_value, decay_rate_per_sec }
## win_threshold, win_duration_sec control the sustain win condition.
## Node is NOT added to the scene tree (avoids _ready() side effects).
func _make_active_sbs(
	bar_configs: Array,
	win_threshold: float = 60.0,
	win_duration_sec: float = 30.0,
	max_value: float = 100.0
) -> Node:
	var sbs: Node = SBSScript.new()
	# Inject empty bar effects so no recipe look-ups fire during _process
	sbs._bar_effects = {}
	var config: Dictionary = {
		"max_value": max_value,
		"bars": bar_configs,
		"win_condition": {
			"threshold": win_threshold,
			"duration_sec": win_duration_sec,
		},
	}
	sbs.configure(config)
	return sbs


## Shorthand: single bar with given value and decay rate.
func _single_bar(bar_id: String, initial: float, decay: float) -> Array:
	return [{ "id": bar_id, "initial_value": initial, "decay_rate_per_sec": decay }]


## Two bars, each with the same initial value and decay rate.
func _two_bars(
	initial_a: float, decay_a: float,
	initial_b: float = -1.0, decay_b: float = -1.0
) -> Array:
	if initial_b < 0.0:
		initial_b = initial_a
	if decay_b < 0.0:
		decay_b = decay_a
	return [
		{ "id": "chester", "initial_value": initial_a, "decay_rate_per_sec": decay_a },
		{ "id": "ju",      "initial_value": initial_b, "decay_rate_per_sec": decay_b },
	]


# ── AC-1: Decay reduces bar value each frame ──────────────────────────────────

func test_decay_single_frame_reduces_bar_value() -> void:
	# Arrange: warmth=50, decay=10/s
	# Formula: new = clamp(50 - 10*0.1, 0, 100) = 49.0
	var sbs: Node = _make_active_sbs(_single_bar("warmth", 50.0, 10.0))

	# Act
	sbs._process(0.1)

	# Assert
	assert_float(sbs._values["warmth"]).is_equal(49.0)
	sbs.free()


func test_decay_multiple_frames_accumulate_correctly() -> void:
	# Arrange: warmth=50, decay=10/s, 3 frames of 0.1s each
	# After 3 frames: clamp(50 - 10*0.1, 0,100)=49, then 48, then 47
	var sbs: Node = _make_active_sbs(_single_bar("warmth", 50.0, 10.0))

	# Act
	sbs._process(0.1)
	sbs._process(0.1)
	sbs._process(0.1)

	# Assert: 50 - 3.0 = 47.0
	assert_float(sbs._values["warmth"]).is_equal(47.0)
	sbs.free()


func test_decay_large_delta_applies_proportional_reduction() -> void:
	# Arrange: bar=80, decay=5/s, delta=2.0s
	# Formula: clamp(80 - 5*2.0, 0, 100) = clamp(70, 0, 100) = 70.0
	var sbs: Node = _make_active_sbs(_single_bar("warmth", 80.0, 5.0))

	# Act
	sbs._process(2.0)

	# Assert
	assert_float(sbs._values["warmth"]).is_equal(70.0)
	sbs.free()


func test_decay_zero_rate_bar_does_not_change() -> void:
	# Arrange: warmth=75, decay=0 (no decay authored)
	var sbs: Node = _make_active_sbs(_single_bar("warmth", 75.0, 0.0))

	# Act: many frames
	sbs._process(1.0)
	sbs._process(1.0)
	sbs._process(1.0)

	# Assert: value frozen
	assert_float(sbs._values["warmth"]).is_equal(75.0)
	sbs.free()


func test_decay_emits_bar_values_changed_when_value_changes() -> void:
	# Arrange
	var sbs: Node = _make_active_sbs(_single_bar("warmth", 50.0, 5.0))
	var emitted: bool = false
	sbs.bar_values_changed.connect(func(_v: Dictionary) -> void: emitted = true)

	# Act
	sbs._process(0.1)

	# Assert: signal fired because value changed
	assert_bool(emitted).is_true()
	sbs.free()


func test_decay_zero_rate_bar_does_not_emit_bar_values_changed() -> void:
	# Arrange: no decay → no change → no signal emission from decay path
	var sbs: Node = _make_active_sbs(
		_single_bar("warmth", 75.0, 0.0),
		999.0,  # threshold unreachable — suppress win check side effects
		9999.0
	)
	var emit_count: int = 0
	sbs.bar_values_changed.connect(func(_v: Dictionary) -> void: emit_count += 1)

	# Act
	sbs._process(1.0)

	# Assert: no emission (value did not change)
	assert_int(emit_count).is_equal(0)
	sbs.free()


func test_decay_independent_rates_applied_per_bar() -> void:
	# Arrange: chester decays at 10/s, ju decays at 2/s; delta=0.5s
	# chester: clamp(60 - 10*0.5, 0,100) = 55.0
	# ju:      clamp(60 - 2*0.5,  0,100) = 59.0
	var sbs: Node = _make_active_sbs(
		_two_bars(60.0, 10.0, 60.0, 2.0),
		999.0, 9999.0
	)

	# Act
	sbs._process(0.5)

	# Assert: each bar decayed at its own rate
	assert_float(sbs._values["chester"]).is_equal(55.0)
	assert_float(sbs._values["ju"]).is_equal(59.0)
	sbs.free()


# ── AC-2: Decay clamped at 0 — no negative values ─────────────────────────────

func test_decay_clamped_at_zero_when_rate_exceeds_remaining_value() -> void:
	# Arrange: warmth=0.5, decay=10/s, delta=0.1s → 0.5 - 1.0 = -0.5 → clamp to 0
	var sbs: Node = _make_active_sbs(_single_bar("warmth", 0.5, 10.0))

	# Act
	sbs._process(0.1)

	# Assert: clamped to 0, not negative
	assert_float(sbs._values["warmth"]).is_equal(0.0)
	sbs.free()


func test_decay_bar_at_zero_stays_at_zero_with_continued_decay() -> void:
	# Arrange: warmth starts at 0; decay rate is non-zero
	var sbs: Node = _make_active_sbs(_single_bar("warmth", 0.0, 5.0))

	# Act: multiple frames of decay on an already-zero bar
	sbs._process(1.0)
	sbs._process(1.0)
	sbs._process(1.0)

	# Assert: never goes negative
	assert_float(sbs._values["warmth"]).is_equal(0.0)
	sbs.free()


func test_decay_bar_value_never_negative_across_ten_frames() -> void:
	# Arrange: bar starts near zero; heavy decay
	var sbs: Node = _make_active_sbs(_single_bar("warmth", 2.0, 100.0))

	# Act: 10 frames of ~1ms each — decay overwhelms in frame 1
	for _i: int in range(10):
		sbs._process(0.016)

	# Assert: floor is 0.0, never below
	assert_float(sbs._values["warmth"]).is_greater_equal(0.0)
	sbs.free()


# ── AC-3: _sustained_time increments / resets correctly ───────────────────────

func test_sustain_timer_increments_when_all_bars_above_threshold() -> void:
	# Arrange: both bars at 80, threshold=60 → condition met each frame
	var sbs: Node = _make_active_sbs(_two_bars(80.0, 0.0), 60.0, 30.0)

	# Act: one frame
	sbs._process(0.5)

	# Assert: timer advanced by delta
	assert_float(sbs._sustain_timer).is_equal(0.5)
	sbs.free()


func test_sustain_timer_increments_across_multiple_frames() -> void:
	# Arrange: bars at 80, threshold=60, no decay
	var sbs: Node = _make_active_sbs(_two_bars(80.0, 0.0), 60.0, 9999.0)

	# Act: 5 frames × 0.2s = 1.0s total
	for _i: int in range(5):
		sbs._process(0.2)

	# Assert
	assert_float(sbs._sustain_timer).is_equal_approx(1.0, 0.0001)
	sbs.free()


func test_sustain_timer_resets_when_one_bar_drops_below_threshold() -> void:
	# Arrange: chester=75 (above 70 threshold), ju=65 (below threshold)
	var sbs: Node = _make_active_sbs(
		_two_bars(75.0, 0.0, 65.0, 0.0),
		70.0,
		30.0
	)
	sbs._sustain_timer = 5.0  # simulate partial progress

	# Act: _process detects ju < threshold → reset
	sbs._process(0.016)

	# Assert: timer reset to 0
	assert_float(sbs._sustain_timer).is_equal(0.0)
	sbs.free()


func test_sustain_timer_resets_exactly_at_threshold_boundary() -> void:
	# Arrange: bar value exactly at threshold — treated as >= (boundary inclusive)
	var sbs: Node = _make_active_sbs(
		_single_bar("warmth", 60.0, 0.0),
		60.0,
		9999.0
	)

	# Act
	sbs._process(0.1)

	# Assert: timer incremented (60 >= 60 → condition met)
	assert_float(sbs._sustain_timer).is_greater(0.0)
	sbs.free()


func test_sustain_timer_resets_when_decay_pushes_bar_below_threshold() -> void:
	# Arrange: bar starts above threshold but decay will push it below within one frame
	# warmth=61.0, decay=5/s, threshold=60, delta=0.5s
	# new_value = clamp(61 - 5*0.5, 0,100) = 58.5 < 60 → timer should reset
	var sbs: Node = _make_active_sbs(
		_single_bar("warmth", 61.0, 5.0),
		60.0,
		9999.0
	)
	sbs._sustain_timer = 2.0  # simulate progress

	# Act: after this frame, warmth = 58.5 (below threshold)
	sbs._process(0.5)

	# Assert: timer reset because the decayed value is below threshold
	assert_float(sbs._sustain_timer).is_equal(0.0)
	sbs.free()


# ── AC-4: win_condition_met() emitted exactly once ────────────────────────────

func test_sustain_win_condition_met_emitted_when_duration_reached() -> void:
	# Arrange: bars above threshold, duration=1.0s
	var sbs: Node = _make_active_sbs(_two_bars(80.0, 0.0), 60.0, 1.0)
	var win_count: int = 0
	sbs.win_condition_met.connect(func() -> void: win_count += 1)

	# Act: two ticks of 0.5s each = 1.0s total
	sbs._process(0.5)
	sbs._process(0.5)

	# Assert: emitted exactly once
	assert_int(win_count).is_equal(1)
	sbs.free()


func test_sustain_win_condition_met_emitted_exactly_once_not_twice() -> void:
	# Arrange: bars well above threshold, short duration
	var sbs: Node = _make_active_sbs(_two_bars(80.0, 0.0), 60.0, 0.5)
	var win_count: int = 0
	sbs.win_condition_met.connect(func() -> void: win_count += 1)

	# Act: three frames, each past the win threshold
	sbs._process(0.3)  # timer=0.3, not yet
	sbs._process(0.3)  # timer=0.6 → fires win on this frame
	sbs._process(0.3)  # Complete state — no second emission

	# Assert: only one emission total
	assert_int(win_count).is_equal(1)
	sbs.free()


func test_sustain_win_does_not_fire_if_sustained_time_resets_before_duration() -> void:
	# Arrange: one bar occasionally drops below threshold, resetting timer
	var sbs: Node = _make_active_sbs(
		_two_bars(80.0, 0.0),
		60.0,
		5.0
	)
	var win_count: int = 0
	sbs.win_condition_met.connect(func() -> void: win_count += 1)

	# Act: build partial sustain, then drop a bar below threshold, then rebuild
	sbs._process(2.0)                # timer=2.0
	sbs._values["chester"] = 50.0   # drop below threshold mid-test
	sbs._process(0.016)              # timer resets to 0
	sbs._values["chester"] = 80.0   # restore
	sbs._process(2.0)                # timer=2.0 again (< 5.0 duration)

	# Assert: win has NOT fired yet (timer was reset and hasn't recovered)
	assert_int(win_count).is_equal(0)
	sbs.free()


func test_sustain_win_fires_after_sustained_recovery() -> void:
	# Arrange: short duration so we can verify win fires after a full sustain
	var sbs: Node = _make_active_sbs(
		_two_bars(80.0, 0.0),
		60.0,
		1.0
	)
	var win_count: int = 0
	sbs.win_condition_met.connect(func() -> void: win_count += 1)

	# Act: drop bar (resets timer), then hold above threshold for full duration
	sbs._values["chester"] = 50.0  # below threshold
	sbs._process(0.5)               # timer resets to 0
	sbs._values["chester"] = 80.0  # restore above threshold
	sbs._process(0.6)               # timer = 0.6
	sbs._process(0.6)               # timer = 1.2 → fires win

	# Assert
	assert_int(win_count).is_equal(1)
	sbs.free()


# ── AC-5: Dormant and Complete states are no-ops in _process ──────────────────

func test_sustain_process_while_dormant_does_not_decay() -> void:
	# Arrange: manually set bar in Dormant state (no configure())
	var sbs: Node = SBSScript.new()
	sbs._bar_effects = {}
	sbs._values["warmth"] = 70.0
	sbs._decay_rates["warmth"] = 10.0
	# _status remains DORMANT

	# Act
	sbs._process(1.0)

	# Assert: value unchanged (Dormant guard fires)
	assert_float(sbs._values["warmth"]).is_equal(70.0)
	sbs.free()


func test_sustain_process_while_dormant_does_not_increment_timer() -> void:
	# Arrange: inject some pre-existing timer value in Dormant state
	var sbs: Node = SBSScript.new()
	sbs._bar_effects = {}
	sbs._sustain_timer = 0.0
	# Status: DORMANT

	# Act
	sbs._process(1.0)

	# Assert: timer stays 0
	assert_float(sbs._sustain_timer).is_equal(0.0)
	sbs.free()


func test_sustain_process_while_complete_does_not_decay() -> void:
	# Arrange: get to Complete state
	var sbs: Node = _make_active_sbs(_single_bar("warmth", 90.0, 0.0), 60.0, 0.5)
	sbs._process(0.6)  # → Complete
	assert_int(sbs._status as int).is_equal(SBSScript.Status.COMPLETE)
	var value_at_complete: float = sbs._values["warmth"]

	# Inject decay rate to verify Complete suppresses it
	sbs._decay_rates["warmth"] = 20.0

	# Act
	sbs._process(5.0)

	# Assert: value frozen at Complete
	assert_float(sbs._values["warmth"]).is_equal(value_at_complete)
	sbs.free()


func test_sustain_process_while_complete_does_not_emit_win_again() -> void:
	# Arrange: bars above threshold, reach Complete
	var sbs: Node = _make_active_sbs(_single_bar("warmth", 90.0, 0.0), 60.0, 0.5)
	var win_count: int = 0
	sbs.win_condition_met.connect(func() -> void: win_count += 1)

	sbs._process(0.6)  # fires win → Complete
	assert_int(win_count).is_equal(1)

	# Act: additional frames in Complete state
	sbs._process(1.0)
	sbs._process(1.0)

	# Assert: no second emission
	assert_int(win_count).is_equal(1)
	sbs.free()


func test_sustain_process_while_complete_does_not_increment_sustained_timer() -> void:
	# Arrange
	var sbs: Node = _make_active_sbs(_single_bar("warmth", 90.0, 0.0), 60.0, 0.5)
	sbs._process(0.6)  # → Complete
	var timer_at_complete: float = sbs._sustain_timer

	# Act
	sbs._process(5.0)

	# Assert: sustain timer frozen at win moment
	assert_float(sbs._sustain_timer).is_equal(timer_at_complete)
	sbs.free()
