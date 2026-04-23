## Integration tests for StatusBarSystem bar effects + combination_executed handler — Story 002.
##
## Covers all 6 acceptance criteria from story-002-bar-effects.md:
##   AC-1: combination_executed fires bar_values_changed with correct updated values
##   AC-2: delta clamped at max_value (no overflow above max)
##   AC-3: delta clamped at 0 (no underflow below 0)
##   AC-4: Dormant SBS ignores combination_executed — no bar updates, no signal
##   AC-5: Unknown recipe_id has no effect (silent — not an error)
##   AC-6: Unknown bar_id in effect entry skipped; valid bar_ids still applied
##
## Integration boundary: tests drive _on_combination_executed() directly,
## bypassing ITF signal wiring, and inject _bar_effects as an in-memory
## Dictionary (matching the implementation's loaded JSON structure) to avoid
## filesystem dependency.
##
## Implementation shape (status_bar_system.gd):
##   _values: Dictionary       { bar_id: float }
##   _decay_rates: Dictionary  { bar_id: float }
##   _bar_effects: Dictionary  { recipe_id: { bar_id: delta_float } }
##   _max_value: float
##   _status: Status enum
extends GdUnitTestSuite

const SBSScript := preload("res://src/gameplay/status_bar_system.gd")


# ── helpers ───────────────────────────────────────────────────────────────────

## Returns a configured SBS with injected bar effects and optionally pre-set
## bar values. The node is NOT added to the scene tree; _ready() is skipped.
## Callers must free() after each test.
func _make_active_sbs(
	bar_effects: Dictionary,
	initial_values: Dictionary = { "warmth": 50.0 },
	max_value: float = 100.0
) -> Node:
	var sbs: Node = auto_free(SBSScript.new())

	# Inject bar effects directly so no filesystem read is required
	sbs._bar_effects = bar_effects

	# Build and apply a config matching the actual configure() API
	var bars: Array = []
	for bar_id: String in initial_values:
		bars.append({ "id": bar_id, "initial_value": initial_values[bar_id], "decay_rate_per_sec": 0.0 })

	var config: Dictionary = {
		"max_value": max_value,
		"bars": bars,
		"win_condition": { "threshold": 999.0, "duration_sec": 9999.0 },
	}
	sbs.configure(config)  # transitions to Active
	return sbs


## Fires the combination_executed handler directly with all 6 required params
## (Godot 4.3 arity-strict per ADR-003). Returns void.
func _fire_combination(sbs: Node, recipe_id: String) -> void:
	sbs._on_combination_executed(recipe_id, "additive", "inst-a", "inst-b", "card-a", "card-b")


# ── AC-1: bar_values_changed fires with correct updated values ─────────────────

func test_bar_effects_combination_updates_bar_value() -> void:
	# Arrange: warmth starts at 50; effect adds 20
	var sbs: Node = _make_active_sbs(
		{ "morning-light": { "warmth": 20.0 } },
		{ "warmth": 50.0 }
	)

	# Act
	_fire_combination(sbs, "morning-light")

	# Assert: warmth is now 70
	assert_float(sbs._values["warmth"]).is_equal(70.0)
	sbs.free()


func test_bar_effects_combination_emits_bar_values_changed_signal() -> void:
	# Arrange
	var sbs: Node = _make_active_sbs(
		{ "morning-light": { "warmth": 10.0 } },
		{ "warmth": 50.0 }
	)
	var received: Dictionary = {}
	sbs.bar_values_changed.connect(func(v: Dictionary) -> void: received = v)

	# Act
	_fire_combination(sbs, "morning-light")

	# Assert: signal fired with updated snapshot
	assert_bool(received.has("warmth")).is_true()
	assert_float(received["warmth"]).is_equal(60.0)
	sbs.free()


func test_bar_effects_combination_updates_multiple_bars() -> void:
	# Arrange: recipe affects both chester and ju independently
	var sbs: Node = _make_active_sbs(
		{ "chester-ju": { "chester": 15.0, "ju": 5.0 } },
		{ "chester": 30.0, "ju": 40.0 }
	)

	# Act
	_fire_combination(sbs, "chester-ju")

	# Assert
	assert_float(sbs._values["chester"]).is_equal(45.0)
	assert_float(sbs._values["ju"]).is_equal(45.0)
	sbs.free()


func test_bar_effects_negative_delta_decreases_bar_value() -> void:
	# Arrange: recipe with negative delta (creates tension)
	var sbs: Node = _make_active_sbs(
		{ "rainy-afternoon": { "warmth": -15.0 } },
		{ "warmth": 60.0 }
	)

	# Act
	_fire_combination(sbs, "rainy-afternoon")

	# Assert
	assert_float(sbs._values["warmth"]).is_equal(45.0)
	sbs.free()


# ── AC-2: delta clamped at max_value (no overflow) ────────────────────────────

func test_bar_effects_positive_delta_clamped_at_max_value() -> void:
	# Arrange: bar at 90, effect +20, max=100 → clamp to 100
	var sbs: Node = _make_active_sbs(
		{ "morning-light": { "warmth": 20.0 } },
		{ "warmth": 90.0 },
		100.0
	)

	# Act
	_fire_combination(sbs, "morning-light")

	# Assert: clamped to max_value, not 110
	assert_float(sbs._values["warmth"]).is_equal(100.0)
	sbs.free()


func test_bar_effects_bar_at_max_with_positive_delta_stays_at_max() -> void:
	# Arrange: bar already at max; effect tries to exceed it
	var sbs: Node = _make_active_sbs(
		{ "overflow-recipe": { "warmth": 50.0 } },
		{ "warmth": 100.0 },
		100.0
	)

	# Act
	_fire_combination(sbs, "overflow-recipe")

	# Assert: stays at 100, never exceeds max
	assert_float(sbs._values["warmth"]).is_equal(100.0)
	sbs.free()


# ── AC-3: delta clamped at 0 (no underflow) ───────────────────────────────────

func test_bar_effects_negative_delta_clamped_at_zero() -> void:
	# Arrange: bar at 10, effect -30 → clamp to 0
	var sbs: Node = _make_active_sbs(
		{ "drain-recipe": { "warmth": -30.0 } },
		{ "warmth": 10.0 }
	)

	# Act
	_fire_combination(sbs, "drain-recipe")

	# Assert: clamped to 0, not negative
	assert_float(sbs._values["warmth"]).is_equal(0.0)
	sbs.free()


func test_bar_effects_bar_at_zero_with_negative_delta_stays_at_zero() -> void:
	# Arrange: bar already at 0; negative delta cannot go below
	var sbs: Node = _make_active_sbs(
		{ "drain-recipe": { "warmth": -10.0 } },
		{ "warmth": 0.0 }
	)

	# Act
	_fire_combination(sbs, "drain-recipe")

	# Assert: stays at 0
	assert_float(sbs._values["warmth"]).is_equal(0.0)
	sbs.free()


# ── AC-4: Dormant SBS ignores combination_executed ────────────────────────────

func test_bar_effects_dormant_sbs_ignores_combination_executed() -> void:
	# Arrange: SBS freshly created (Dormant), bar effects injected, but NOT configured
	var sbs: Node = auto_free(SBSScript.new())
	sbs._bar_effects = { "morning-light": { "warmth": 20.0 } }
	# _status is DORMANT; _values is empty

	# Act: fire combination — handler should return early
	_fire_combination(sbs, "morning-light")

	# Assert: no values changed (still empty)
	assert_int(sbs._values.size()).is_equal(0)
	sbs.free()


func test_bar_effects_dormant_sbs_does_not_emit_bar_values_changed() -> void:
	# Arrange
	var sbs: Node = auto_free(SBSScript.new())
	sbs._bar_effects = { "morning-light": { "warmth": 20.0 } }
	var emitted: bool = false
	sbs.bar_values_changed.connect(func(_v: Dictionary) -> void: emitted = true)

	# Act
	_fire_combination(sbs, "morning-light")

	# Assert
	assert_bool(emitted).is_false()
	sbs.free()


func test_bar_effects_complete_sbs_ignores_combination_executed() -> void:
	# Arrange: drive SBS to Complete state
	var sbs: Node = _make_active_sbs(
		{ "morning-light": { "warmth": 5.0 } },
		{ "warmth": 90.0 }
	)
	# Override win condition to trigger immediately
	sbs._win_threshold = 60.0
	sbs._win_duration = 0.5
	sbs._process(0.6)  # → Complete
	assert_int(sbs._status as int).is_equal(SBSScript.Status.COMPLETE)
	var frozen_value: float = sbs._values["warmth"]

	# Act: fire combination in Complete state
	_fire_combination(sbs, "morning-light")

	# Assert: bar value unchanged (Complete guard fired)
	assert_float(sbs._values["warmth"]).is_equal(frozen_value)
	sbs.free()


# ── AC-5: Unknown recipe_id has no effect ─────────────────────────────────────

func test_bar_effects_unknown_recipe_id_does_not_change_bar_values() -> void:
	# Arrange
	var sbs: Node = _make_active_sbs(
		{ "known-recipe": { "warmth": 10.0 } },
		{ "warmth": 50.0 }
	)

	# Act: fire a recipe that has no entry in bar_effects
	_fire_combination(sbs, "unknown-recipe-xyz")

	# Assert: warmth unchanged
	assert_float(sbs._values["warmth"]).is_equal(50.0)
	sbs.free()


func test_bar_effects_unknown_recipe_id_does_not_emit_bar_values_changed() -> void:
	# Arrange
	var sbs: Node = _make_active_sbs(
		{ "known-recipe": { "warmth": 10.0 } },
		{ "warmth": 50.0 }
	)
	# Reset signal — configure() emitted it; capture only new emissions
	var emit_count: int = 0
	sbs.bar_values_changed.connect(func(_v: Dictionary) -> void: emit_count += 1)

	# Act
	_fire_combination(sbs, "unknown-recipe-xyz")

	# Assert: no additional emission
	assert_int(emit_count).is_equal(0)
	sbs.free()


# ── AC-6: Unknown bar_id in effect skipped; valid bar_ids still applied ────────

func test_bar_effects_unknown_bar_id_in_effect_skipped() -> void:
	# Arrange: effect has a known bar and an unknown bar
	var sbs: Node = _make_active_sbs(
		{ "mixed-recipe": { "warmth": 10.0, "unknown_bar": 20.0 } },
		{ "warmth": 50.0 }
		# "unknown_bar" is not in _values
	)

	# Act
	_fire_combination(sbs, "mixed-recipe")

	# Assert: warmth updated; no crash; no "unknown_bar" key created
	assert_float(sbs._values["warmth"]).is_equal(60.0)
	assert_bool(sbs._values.has("unknown_bar")).is_false()
	sbs.free()


func test_bar_effects_unknown_bar_id_does_not_prevent_valid_bar_update() -> void:
	# Arrange: two valid bars plus one unknown bar in the effect
	var sbs: Node = _make_active_sbs(
		{ "complex-recipe": { "chester": 15.0, "unknown_bar": 99.0, "ju": 5.0 } },
		{ "chester": 30.0, "ju": 40.0 }
	)

	# Act
	_fire_combination(sbs, "complex-recipe")

	# Assert: both valid bars updated; unknown bar silently skipped
	assert_float(sbs._values["chester"]).is_equal(45.0)
	assert_float(sbs._values["ju"]).is_equal(45.0)
	sbs.free()


func test_bar_effects_bar_values_changed_emitted_when_partial_update_succeeds() -> void:
	# Arrange: one valid, one unknown — bar_values_changed should still fire for the valid update
	var sbs: Node = _make_active_sbs(
		{ "mixed-recipe": { "warmth": 10.0, "ghost": 5.0 } },
		{ "warmth": 50.0 }
	)
	var emitted: bool = false
	sbs.bar_values_changed.connect(func(_v: Dictionary) -> void: emitted = true)

	# Act
	_fire_combination(sbs, "mixed-recipe")

	# Assert: signal still fires despite partial skip
	assert_bool(emitted).is_true()
	sbs.free()
