## Unit tests for StatusBarSystem configure API and state machine — Story 001.
##
## Covers all 5 acceptance criteria from story-001-configure-state.md:
##   AC-1: SBS initializes in Dormant state; _process is a no-op while Dormant
##   AC-2: configure() transitions Dormant → Active; initializes bar values
##   AC-3: configure() called again while Active resets and reinitializes
##   AC-4: After win_condition_met emitted: Complete state; decay stops; values frozen
##   AC-5: reset() restores Dormant state; all bar state cleared
##
## The actual implementation stores bars as flat Dictionaries:
##   _values:      { bar_id: float }
##   _decay_rates: { bar_id: float }
##   _status:      StatusBarSystem.Status enum (DORMANT=0, ACTIVE=1, COMPLETE=2)
##
## Tests drive _process(delta) directly to advance simulated time — no real clock.
extends GdUnitTestSuite

const SBSScript := preload("res://src/gameplay/status_bar_system.gd")


# ── helpers ───────────────────────────────────────────────────────────────────

## Builds a minimal scene_bar_config dictionary matching the configure() API.
## Optional overrides: max_value, bars array, win_condition dict.
func _make_config(overrides: Dictionary = {}) -> Dictionary:
	return {
		"max_value": overrides.get("max_value", 100.0),
		"bars": overrides.get("bars", [
			{ "id": "warmth", "initial_value": 50.0, "decay_rate_per_sec": 0.0 },
		]),
		"win_condition": overrides.get("win_condition", {
			"threshold": 60.0,
			"duration_sec": 30.0,
		}),
	}


## Creates a fresh StatusBarSystem without adding it to the scene tree.
## This avoids _ready() which tries to load bar-effects.json and connect ITF.
## Tests call configure() manually to enter Active state.
func _make_sbs() -> Node:
	var sbs: Node = SBSScript.new()
	# Prevent _ready() side effects: pre-populate _bar_effects so the JSON
	# load does not error in headless, and skip ITF signal connection by
	# not adding to tree until after configure() when needed.
	return sbs


# ── AC-1: Dormant on init — _process is a no-op ───────────────────────────────

func test_configure_state_initial_status_is_dormant() -> void:
	# Arrange
	var sbs: Node = _make_sbs()

	# Assert: freshly created node is in Dormant status (enum value 0)
	assert_int(sbs._status as int).is_equal(SBSScript.Status.DORMANT)
	sbs.free()


func test_configure_state_process_while_dormant_does_not_change_values() -> void:
	# Arrange: SBS in Dormant, manually set a value to confirm it stays unchanged
	var sbs: Node = _make_sbs()
	sbs._values["warmth"] = 80.0
	sbs._decay_rates["warmth"] = 5.0
	# Status remains DORMANT — _process guard should fire

	# Act: simulate two frames
	sbs._process(0.016)
	sbs._process(0.016)

	# Assert: value unchanged because _process exits early while Dormant
	assert_float(sbs._values["warmth"]).is_equal(80.0)
	sbs.free()


func test_configure_state_process_while_dormant_does_not_emit_bar_values_changed() -> void:
	# Arrange
	var sbs: Node = _make_sbs()
	var emitted: bool = false
	sbs.bar_values_changed.connect(func(_v: Dictionary) -> void: emitted = true)

	# Act
	sbs._process(0.016)

	# Assert: signal not fired in Dormant state
	assert_bool(emitted).is_false()
	sbs.free()


# ── AC-2: configure() → Active; bar values initialized ───────────────────────

func test_configure_state_configure_transitions_to_active() -> void:
	# Arrange
	var sbs: Node = _make_sbs()

	# Act
	sbs.configure(_make_config())

	# Assert
	assert_int(sbs._status as int).is_equal(SBSScript.Status.ACTIVE)
	sbs.free()


func test_configure_state_configure_sets_initial_bar_value() -> void:
	# Arrange
	var sbs: Node = _make_sbs()
	var config: Dictionary = _make_config({
		"bars": [{ "id": "warmth", "initial_value": 42.0, "decay_rate_per_sec": 0.0 }],
	})

	# Act
	sbs.configure(config)

	# Assert: bar value matches authored initial_value
	assert_float(sbs._values.get("warmth", -1.0)).is_equal(42.0)
	sbs.free()


func test_configure_state_configure_registers_decay_rate() -> void:
	# Arrange
	var sbs: Node = _make_sbs()
	var config: Dictionary = _make_config({
		"bars": [{ "id": "warmth", "initial_value": 50.0, "decay_rate_per_sec": 3.5 }],
	})

	# Act
	sbs.configure(config)

	# Assert: decay rate stored correctly
	assert_float(sbs._decay_rates.get("warmth", -1.0)).is_equal(3.5)
	sbs.free()


func test_configure_state_configure_sets_max_value() -> void:
	# Arrange
	var sbs: Node = _make_sbs()
	var config: Dictionary = _make_config({ "max_value": 150.0 })

	# Act
	sbs.configure(config)

	# Assert
	assert_float(sbs._max_value).is_equal(150.0)
	sbs.free()


func test_configure_state_configure_sets_win_threshold() -> void:
	# Arrange
	var sbs: Node = _make_sbs()
	var config: Dictionary = _make_config({
		"win_condition": { "threshold": 75.0, "duration_sec": 20.0 },
	})

	# Act
	sbs.configure(config)

	# Assert
	assert_float(sbs._win_threshold).is_equal(75.0)
	sbs.free()


func test_configure_state_configure_sets_win_duration() -> void:
	# Arrange
	var sbs: Node = _make_sbs()
	var config: Dictionary = _make_config({
		"win_condition": { "threshold": 60.0, "duration_sec": 45.0 },
	})

	# Act
	sbs.configure(config)

	# Assert
	assert_float(sbs._win_duration).is_equal(45.0)
	sbs.free()


func test_configure_state_configure_supports_multiple_bars() -> void:
	# Arrange
	var sbs: Node = _make_sbs()
	var config: Dictionary = _make_config({
		"bars": [
			{ "id": "chester", "initial_value": 30.0, "decay_rate_per_sec": 1.0 },
			{ "id": "ju",      "initial_value": 55.0, "decay_rate_per_sec": 0.5 },
		],
	})

	# Act
	sbs.configure(config)

	# Assert both bars are registered
	assert_float(sbs._values.get("chester", -1.0)).is_equal(30.0)
	assert_float(sbs._values.get("ju", -1.0)).is_equal(55.0)
	sbs.free()


func test_configure_state_configure_emits_bar_values_changed_immediately() -> void:
	# Arrange
	var sbs: Node = _make_sbs()
	var received_values: Dictionary = {}
	sbs.bar_values_changed.connect(func(v: Dictionary) -> void: received_values = v)

	# Act
	sbs.configure(_make_config({
		"bars": [{ "id": "warmth", "initial_value": 50.0, "decay_rate_per_sec": 0.0 }],
	}))

	# Assert: signal fired with current bar snapshot
	assert_bool(received_values.has("warmth")).is_true()
	assert_float(received_values["warmth"]).is_equal(50.0)
	sbs.free()


# ── AC-3: configure() while Active resets and reinitializes ───────────────────

func test_configure_state_reconfigure_while_active_resets_bar_values() -> void:
	# Arrange: configure once, then inflate a bar manually to simulate progress
	var sbs: Node = _make_sbs()
	sbs.configure(_make_config({
		"bars": [{ "id": "warmth", "initial_value": 50.0, "decay_rate_per_sec": 0.0 }],
	}))
	sbs._values["warmth"] = 99.0  # simulate player progress

	# Act: reconfigure with a new scene
	sbs.configure(_make_config({
		"bars": [{ "id": "coldness", "initial_value": 20.0, "decay_rate_per_sec": 0.0 }],
	}))

	# Assert: old bar gone; new bar initialized
	assert_bool(sbs._values.has("warmth")).is_false()
	assert_float(sbs._values.get("coldness", -1.0)).is_equal(20.0)
	sbs.free()


func test_configure_state_reconfigure_while_active_resets_sustain_timer() -> void:
	# Arrange: SBS active with sustain timer partially built up
	var sbs: Node = _make_sbs()
	sbs.configure(_make_config())
	sbs._sustain_timer = 14.0  # simulate partial sustain progress

	# Act: reconfigure
	sbs.configure(_make_config())

	# Assert: sustain timer resets
	assert_float(sbs._sustain_timer).is_equal(0.0)
	sbs.free()


func test_configure_state_reconfigure_stays_active() -> void:
	# Arrange
	var sbs: Node = _make_sbs()
	sbs.configure(_make_config())

	# Act
	sbs.configure(_make_config({
		"bars": [{ "id": "warmth", "initial_value": 10.0, "decay_rate_per_sec": 0.0 }],
	}))

	# Assert: still Active, not dropped to Dormant
	assert_int(sbs._status as int).is_equal(SBSScript.Status.ACTIVE)
	sbs.free()


# ── AC-4: Complete state after win_condition_met — decay stops ────────────────

func test_configure_state_complete_after_win_condition() -> void:
	# Arrange: bars well above threshold; short duration
	var sbs: Node = _make_sbs()
	sbs.configure(_make_config({
		"bars": [{ "id": "warmth", "initial_value": 90.0, "decay_rate_per_sec": 0.0 }],
		"win_condition": { "threshold": 60.0, "duration_sec": 1.0 },
	}))

	# Act: advance simulated time past duration_sec in one step
	sbs._process(1.1)

	# Assert: transitioned to Complete
	assert_int(sbs._status as int).is_equal(SBSScript.Status.COMPLETE)
	sbs.free()


func test_configure_state_decay_stops_after_complete() -> void:
	# Arrange: bar has decay but goes Complete immediately
	var sbs: Node = _make_sbs()
	sbs.configure(_make_config({
		"bars": [{ "id": "warmth", "initial_value": 90.0, "decay_rate_per_sec": 10.0 }],
		"win_condition": { "threshold": 60.0, "duration_sec": 1.0 },
	}))
	sbs._process(1.1)  # triggers win → Complete
	assert_int(sbs._status as int).is_equal(SBSScript.Status.COMPLETE)
	var frozen_value: float = sbs._values.get("warmth", -1.0)

	# Act: additional frames in Complete state
	sbs._process(5.0)
	sbs._process(5.0)

	# Assert: bar value has not changed (decay stopped)
	assert_float(sbs._values.get("warmth", -1.0)).is_equal(frozen_value)
	sbs.free()


func test_configure_state_win_condition_met_emitted_in_complete_transition() -> void:
	# Arrange
	var sbs: Node = _make_sbs()
	sbs.configure(_make_config({
		"bars": [{ "id": "warmth", "initial_value": 90.0, "decay_rate_per_sec": 0.0 }],
		"win_condition": { "threshold": 60.0, "duration_sec": 1.0 },
	}))
	var win_count: int = 0
	sbs.win_condition_met.connect(func() -> void: win_count += 1)

	# Act: cross the win threshold
	sbs._process(1.1)

	# Assert: emitted exactly once
	assert_int(win_count).is_equal(1)
	sbs.free()


# ── AC-5: reset() → Dormant; all bar state cleared ────────────────────────────

func test_configure_state_reset_transitions_to_dormant() -> void:
	# Arrange: SBS Active
	var sbs: Node = _make_sbs()
	sbs.configure(_make_config())

	# Act
	sbs.reset()

	# Assert
	assert_int(sbs._status as int).is_equal(SBSScript.Status.DORMANT)
	sbs.free()


func test_configure_state_reset_clears_values() -> void:
	# Arrange
	var sbs: Node = _make_sbs()
	sbs.configure(_make_config({
		"bars": [{ "id": "warmth", "initial_value": 80.0, "decay_rate_per_sec": 0.0 }],
	}))

	# Act
	sbs.reset()

	# Assert: no bar entries remain
	assert_int(sbs._values.size()).is_equal(0)
	sbs.free()


func test_configure_state_reset_clears_decay_rates() -> void:
	# Arrange
	var sbs: Node = _make_sbs()
	sbs.configure(_make_config({
		"bars": [{ "id": "warmth", "initial_value": 50.0, "decay_rate_per_sec": 2.0 }],
	}))

	# Act
	sbs.reset()

	# Assert
	assert_int(sbs._decay_rates.size()).is_equal(0)
	sbs.free()


func test_configure_state_reset_clears_sustain_timer() -> void:
	# Arrange
	var sbs: Node = _make_sbs()
	sbs.configure(_make_config())
	sbs._sustain_timer = 5.0

	# Act
	sbs.reset()

	# Assert
	assert_float(sbs._sustain_timer).is_equal(0.0)
	sbs.free()


func test_configure_state_process_after_reset_is_no_op() -> void:
	# Arrange: Active → reset → Dormant; manually inject values to detect leakage
	var sbs: Node = _make_sbs()
	sbs.configure(_make_config({
		"bars": [{ "id": "warmth", "initial_value": 50.0, "decay_rate_per_sec": 5.0 }],
	}))
	sbs.reset()
	# After reset, _values is empty; re-inject manually to detect if _process
	# would mutate state when it shouldn't
	sbs._values["warmth"] = 80.0
	sbs._decay_rates["warmth"] = 5.0
	# Status is DORMANT — _process guard must prevent mutation

	# Act
	sbs._process(1.0)

	# Assert: value unchanged (Dormant guard fired)
	assert_float(sbs._values["warmth"]).is_equal(80.0)
	sbs.free()
