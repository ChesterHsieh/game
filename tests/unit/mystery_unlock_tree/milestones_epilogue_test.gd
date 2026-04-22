## Unit tests for MysteryUnlockTree — Story 002: milestones + epilogue conditions.
## Covers AC-1 through AC-6 from story-002-milestones-epilogue.md.
##
## Strategy: thresholds and epilogue IDs are injected directly into the MUT
## instance fields to decouple tests from file I/O. Signals are captured via
## lambda connections on EventBus before calling handlers.
extends GdUnitTestSuite

const MUTScript := preload("res://src/core/mystery_unlock_tree.gd")

# Known recipes from RecipeDatabase (present in assets/data/recipes.tres).
const RECIPE_A := "chester-rainy-afternoon"
const RECIPE_B := "ju-our-cafe"
const RECIPE_C := "that-argument-safe"
const RECIPE_D := "that-park-nervous"
const RECIPE_E := "handmade-gift-ju"


# ── Helpers ───────────────────────────────────────────────────────────────────

## Returns an ACTIVE MUT with preset thresholds and epilogue IDs.
## [param thresholds]: pre-resolved int thresholds (skips _resolve_milestones).
## [param epilogue_ids]: epilogue-required recipe_ids.
## [param partial_threshold]: fraction for epilogue_conditions_met (default 1.0).
func _make_mut_with_config(
		thresholds: Array[int],
		epilogue_ids: Array[String],
		partial_threshold: float = 1.0) -> Node:

	var mut: Node = MUTScript.new()
	mut._state = 1  # ACTIVE
	mut._active_scene_id = "scene-test"
	mut._scene_discoveries["scene-test"] = Array([], TYPE_STRING, "", null)

	mut._milestone_thresholds = thresholds.duplicate()
	mut._fired_milestones.resize(thresholds.size())
	mut._fired_milestones.fill(false)

	mut._epilogue_required_ids = epilogue_ids.duplicate()
	mut._partial_threshold = partial_threshold
	return mut


## Triggers a discovery for [param recipe_id] on [param mut].
func _discover(mut: Node, recipe_id: String) -> void:
	# Use generic safe card ids; recipe validation still hits RecipeDatabase.
	mut._on_combination_executed(recipe_id, "merge", "iid_a", "iid_b", "card-a", "card-b")


# ── AC-1: Milestone fires exactly at threshold ────────────────────────────────

func test_milestones_milestone_fires_at_threshold() -> void:
	# Arrange
	var thresholds: Array[int] = [1]
	var mut: Node = _make_mut_with_config(thresholds, [])
	var fired_milestone: String = ""
	var fired_count: int = -1
	EventBus.discovery_milestone_reached.connect(func(mid, cnt): fired_milestone = mid; fired_count = cnt)

	# Act — discover the threshold recipe
	_discover(mut, RECIPE_A)

	# Assert
	assert_str(fired_milestone).is_equal("milestone_0")
	assert_int(fired_count).is_equal(1)
	EventBus.discovery_milestone_reached.disconnect_all()
	mut.free()


func test_milestones_milestone_does_not_refire_after_threshold() -> void:
	# Arrange
	var thresholds: Array[int] = [1]
	var mut: Node = _make_mut_with_config(thresholds, [])
	var fire_count: int = 0
	EventBus.discovery_milestone_reached.connect(func(_mid, _cnt): fire_count += 1)

	# Act — cross the threshold, then discover a second recipe
	_discover(mut, RECIPE_A)
	_discover(mut, RECIPE_B)

	# Assert — milestone fired exactly once
	assert_int(fire_count).is_equal(1)
	EventBus.discovery_milestone_reached.disconnect_all()
	mut.free()


func test_milestones_second_threshold_fires_independently() -> void:
	# Arrange — two thresholds: 1 and 2
	var thresholds: Array[int] = [1, 2]
	var mut: Node = _make_mut_with_config(thresholds, [])
	var milestones_fired: Array[String] = []
	EventBus.discovery_milestone_reached.connect(func(mid, _cnt): milestones_fired.append(mid))

	# Act
	_discover(mut, RECIPE_A)  # hits milestone_0
	_discover(mut, RECIPE_B)  # hits milestone_1

	# Assert
	assert_int(milestones_fired.size()).is_equal(2)
	assert_bool("milestone_0" in milestones_fired).is_true()
	assert_bool("milestone_1" in milestones_fired).is_true()
	EventBus.discovery_milestone_reached.disconnect_all()
	mut.free()


# ── AC-2: Duplicate threshold dropped with warning ────────────────────────────

func test_milestones_resolve_drops_duplicate_threshold() -> void:
	# Arrange — very small R_authored so 0.01 and 0.02 both resolve to 1.
	# Inject manually: call _resolve_milestones on a MUT with pct = [0.01, 0.02]
	# and stub RecipeDatabase count by using a fresh MUT + patched pct.
	# Because we can't easily stub RecipeDatabase.get_recipe_count(), we test
	# the de-dup logic by injecting pre-built raw values directly.
	var mut: Node = MUTScript.new()
	# Simulate raw = [1, 1] by calling _resolve_milestones with R_authored=100
	# and pct values that produce the same integer after ceili.
	# ceil(0.001 * 100) = 1; ceil(0.005 * 100) = 1 → both resolve to 1.
	mut._milestone_pct = [0.001, 0.005]

	# Act
	mut._resolve_milestones()

	# Assert — only one threshold survives
	assert_int(mut._milestone_thresholds.size()).is_equal(1)
	assert_int(mut._milestone_thresholds[0]).is_equal(1)
	mut.free()


func test_milestones_resolve_surviving_thresholds_are_strictly_ascending() -> void:
	# Arrange
	var mut: Node = MUTScript.new()
	mut._milestone_pct = [0.10, 0.50, 0.80]

	# Act
	mut._resolve_milestones()

	# Assert — each threshold is strictly less than the next
	var t: Array[int] = mut._milestone_thresholds
	for i: int in range(t.size() - 1):
		assert_bool(t[i] < t[i + 1]).is_true()
	mut.free()


func test_milestones_fired_milestones_array_matches_threshold_count() -> void:
	# Arrange
	var mut: Node = MUTScript.new()
	mut._milestone_pct = [0.15, 0.50, 0.80]

	# Act
	mut._resolve_milestones()

	# Assert
	assert_int(mut._fired_milestones.size()).is_equal(mut._milestone_thresholds.size())
	mut.free()


# ── AC-3: epilogue_conditions_met emitted at partial_threshold ────────────────

func test_milestones_epilogue_conditions_met_at_partial_threshold() -> void:
	# Arrange — 3 required ids, partial_threshold = 0.67 → ceil(3*0.67) = 2
	var epilogue_ids: Array[String] = [RECIPE_A, RECIPE_B, RECIPE_C]
	var mut: Node = _make_mut_with_config([], epilogue_ids, 0.67)
	var emitted: bool = false
	EventBus.epilogue_conditions_met.connect(func(): emitted = true)

	# Act — discover 2 of the 3 required recipes
	_discover(mut, RECIPE_A)
	_discover(mut, RECIPE_B)

	# Assert
	assert_bool(emitted).is_true()
	assert_bool(mut._epilogue_conditions_emitted).is_true()
	EventBus.epilogue_conditions_met.disconnect_all()
	mut.free()


func test_milestones_epilogue_conditions_not_emitted_twice() -> void:
	# Arrange
	var epilogue_ids: Array[String] = [RECIPE_A, RECIPE_B]
	var mut: Node = _make_mut_with_config([], epilogue_ids, 0.5)
	var emit_count: int = 0
	EventBus.epilogue_conditions_met.connect(func(): emit_count += 1)

	# Act — cross threshold with first discovery, then add more
	_discover(mut, RECIPE_A)  # ceil(2*0.5)=1 → fires
	_discover(mut, RECIPE_B)  # already emitted; should not re-fire

	# Assert
	assert_int(emit_count).is_equal(1)
	EventBus.epilogue_conditions_met.disconnect_all()
	mut.free()


# ── AC-4: epilogue_conditions_met suppressed when partial_threshold == 0.0 ────

func test_milestones_epilogue_conditions_suppressed_when_threshold_zero() -> void:
	# Arrange
	var epilogue_ids: Array[String] = [RECIPE_A, RECIPE_B]
	var mut: Node = _make_mut_with_config([], epilogue_ids, 0.0)
	var emitted: bool = false
	EventBus.epilogue_conditions_met.connect(func(): emitted = true)

	# Act — discover all required recipes
	_discover(mut, RECIPE_A)
	_discover(mut, RECIPE_B)

	# Assert — signal suppressed mid-session
	assert_bool(emitted).is_false()
	EventBus.epilogue_conditions_met.disconnect_all()
	mut.free()


# ── AC-5: final_memory_ready fires on epilogue_started ───────────────────────

func test_milestones_final_memory_ready_fires_on_epilogue_started() -> void:
	# Arrange — all required recipes already discovered; partial_threshold = 0.80
	var epilogue_ids: Array[String] = [RECIPE_A, RECIPE_B]
	var mut: Node = _make_mut_with_config([], epilogue_ids, 0.80)
	# Seed discoveries directly to bypass active-state checks
	mut._discovered_recipes[RECIPE_A] = { "order": 1, "scene_id": "s", "template": "", "card_id_a": "", "card_id_b": "" }
	mut._discovered_recipes[RECIPE_B] = { "order": 2, "scene_id": "s", "template": "", "card_id_a": "", "card_id_b": "" }
	mut._discovery_order_counter = 2

	var emitted: bool = false
	EventBus.final_memory_ready.connect(func(): emitted = true)

	# Act
	mut._on_epilogue_started()

	# Assert
	assert_bool(emitted).is_true()
	assert_bool(mut._final_memory_earned).is_true()
	EventBus.final_memory_ready.disconnect_all()
	mut.free()


func test_milestones_final_memory_not_emitted_when_requirements_not_met() -> void:
	# Arrange — only 1 of 3 required discovered; threshold = ceil(3*0.80) = 3
	var epilogue_ids: Array[String] = [RECIPE_A, RECIPE_B, RECIPE_C]
	var mut: Node = _make_mut_with_config([], epilogue_ids, 0.80)
	mut._discovered_recipes[RECIPE_A] = { "order": 1, "scene_id": "s", "template": "", "card_id_a": "", "card_id_b": "" }
	mut._discovery_order_counter = 1

	var emitted: bool = false
	EventBus.final_memory_ready.connect(func(): emitted = true)

	# Act
	mut._on_epilogue_started()

	# Assert
	assert_bool(emitted).is_false()
	assert_bool(mut._final_memory_earned).is_false()
	EventBus.final_memory_ready.disconnect_all()
	mut.free()


func test_milestones_final_memory_not_emitted_when_epilogue_ids_empty() -> void:
	# Arrange — empty epilogue_required_ids suppresses final_memory_ready
	var mut: Node = _make_mut_with_config([], [], 0.80)
	var emitted: bool = false
	EventBus.final_memory_ready.connect(func(): emitted = true)

	# Act
	mut._on_epilogue_started()

	# Assert
	assert_bool(emitted).is_false()
	EventBus.final_memory_ready.disconnect_all()
	mut.free()


# ── AC-6: carry-forward returns only fully-qualified cards ────────────────────

func test_milestones_carry_forward_returns_qualifying_card() -> void:
	# Arrange
	var mut: Node = MUTScript.new()
	mut._discovered_recipes[RECIPE_A] = { "order": 1, "scene_id": "s", "template": "", "card_id_a": "", "card_id_b": "" }

	var spec: Array = [
		{ "card_id": "old-photo", "requires_recipes": [RECIPE_A] },
		{ "card_id": "umbrella", "requires_recipes": [RECIPE_B] },
	]

	# Act
	var result: Array[String] = mut.get_carry_forward_cards(spec)

	# Assert — only old-photo qualifies
	assert_int(result.size()).is_equal(1)
	assert_str(result[0]).is_equal("old-photo")
	mut.free()


func test_milestones_carry_forward_excludes_partially_satisfied_card() -> void:
	# Arrange — "umbrella" requires both RECIPE_A and RECIPE_B; only A discovered
	var mut: Node = MUTScript.new()
	mut._discovered_recipes[RECIPE_A] = { "order": 1, "scene_id": "s", "template": "", "card_id_a": "", "card_id_b": "" }

	var spec: Array = [
		{ "card_id": "umbrella", "requires_recipes": [RECIPE_A, RECIPE_B] },
	]

	# Act
	var result: Array[String] = mut.get_carry_forward_cards(spec)

	# Assert
	assert_int(result.size()).is_equal(0)
	mut.free()


func test_milestones_carry_forward_vacuously_eligible_when_requires_empty() -> void:
	# Arrange — entry with empty requires_recipes is always eligible
	var mut: Node = MUTScript.new()

	var spec: Array = [
		{ "card_id": "freebie", "requires_recipes": [] },
	]

	# Act
	var result: Array[String] = mut.get_carry_forward_cards(spec)

	# Assert
	assert_int(result.size()).is_equal(1)
	assert_str(result[0]).is_equal("freebie")
	mut.free()


func test_milestones_carry_forward_returns_empty_when_inactive_and_no_discoveries() -> void:
	# Arrange — no discoveries (INACTIVE state, empty dict)
	var mut: Node = MUTScript.new()

	var spec: Array = [
		{ "card_id": "old-photo", "requires_recipes": [RECIPE_A] },
	]

	# Act
	var result: Array[String] = mut.get_carry_forward_cards(spec)

	# Assert
	assert_int(result.size()).is_equal(0)
	mut.free()


# ── R_authored == 0 edge case ─────────────────────────────────────────────────

func test_milestones_resolve_sets_empty_thresholds_when_no_recipes() -> void:
	# This edge case can't easily be triggered without mocking RecipeDatabase,
	# so we verify the guard directly by checking that when _milestone_thresholds
	# is empty, no milestone events fire after a discovery.
	var mut: Node = _make_mut_with_config([], [])
	var fired: bool = false
	EventBus.discovery_milestone_reached.connect(func(_mid, _cnt): fired = true)

	# Act — empty thresholds: no milestones should fire
	_discover(mut, RECIPE_A)

	# Assert
	assert_bool(fired).is_false()
	EventBus.discovery_milestone_reached.disconnect_all()
	mut.free()


# ── Suppress signals flag ─────────────────────────────────────────────────────

func test_milestones_suppress_signals_prevents_milestone_evaluation() -> void:
	# Arrange
	var thresholds: Array[int] = [1]
	var mut: Node = _make_mut_with_config(thresholds, [])
	mut._suppress_signals = true
	var fired: bool = false
	EventBus.discovery_milestone_reached.connect(func(_mid, _cnt): fired = true)

	# Act — directly call evaluate; should be skipped
	mut._discovery_order_counter = 1
	mut._evaluate_milestones()

	# Assert — milestones bypass not triggered because _suppress_signals blocks
	# the _evaluate_milestones call from _on_combination_executed, but calling
	# it directly still runs. Suppress is enforced at the call site in the handler.
	# Verify via handler path instead:
	mut._fired_milestones[0] = false
	# Reset counter and trigger via handler
	mut._discovery_order_counter = 0
	mut._suppress_signals = true
	_discover(mut, RECIPE_A)

	assert_bool(fired).is_false()
	EventBus.discovery_milestone_reached.disconnect_all()
	mut.free()
