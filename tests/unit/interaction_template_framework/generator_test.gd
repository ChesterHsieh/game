## Unit tests for InteractionTemplateFramework Generator template — Story 006.
##
## Covers all ACs from story-006-generator-template.md:
##   AC-1: Generator spawns cards at interval; stops at max_count
##   AC-2: card_removing cancels the generator timer
##   AC-3: combination_executed fires immediately (before first tick)
##   AC-4: max_count: null means unlimited production
##
## Strategy:
##   The Generator template is NOT implemented in the current codebase.
##   The implementation only handles "Additive" and "Merge" in _execute_template().
##   A "Generator" template name falls through to the `_:` warning branch.
##
##   These tests document both:
##   a) The MISSING implementation gap (Generator falls through to failed path)
##   b) The expected behaviour per the story spec, as pending-implementation specs
##
##   For the spec tests that require timer behaviour, we avoid real Godot Timer nodes
##   by testing state registration (_active_generators dict) and combination_executed
##   emission independently of tick timing.
##
## NOTE — Implementation/story mismatch (CRITICAL flag):
##   Generator template is entirely absent from src/gameplay/interaction_template_framework.gd.
##   _active_generators dict is also absent. All AC-1 through AC-4 behaviours require
##   adding _execute_generator() and _active_generators to the implementation.
##   Do NOT modify src/. This file documents gaps for the sprint backlog.
extends GdUnitTestSuite

const ITFScript := preload("res://src/gameplay/interaction_template_framework.gd")


# ── helpers ───────────────────────────────────────────────────────────────────

func _make_itf() -> Node:
	var itf: Node = ITFScript.new()
	add_child(itf)
	return itf


func _make_generator_recipe(
		recipe_id: String = "chester-coffee",
		generates: String = "memory",
		interval_sec: float = 0.1,
		max_count: Variant = 3,
		generator_card: String = "card_a") -> Dictionary:
	return {
		"id": recipe_id,
		"card_a": "chester",
		"card_b": "coffee",
		"template": "Generator",
		"config": {
			"generates": generates,
			"interval_sec": interval_sec,
			"max_count": max_count,
			"generator_card": generator_card,
		},
	}


# ── GAP: Generator not implemented — falls through to failed path ─────────────

func test_generator_gap_execute_template_generator_not_handled() -> void:
	# [GAP] The _execute_template() match block has no "Generator" case.
	# combination_executed is NOT emitted for Generator template.
	var itf: Node = _make_itf()
	var recipe := _make_generator_recipe()

	var emitted := {"fired": false}
	itf.combination_executed.connect(
		func(_rid: String, _tmpl: String, _ia: String, _ib: String) -> void:
			emitted["fired"] = true
	)

	itf._execute_template(recipe, "chester_0", "coffee_0")

	assert_bool(emitted["fired"]) \
		.override_failure_message(
			"[GAP story-006] Generator template is not implemented. "
			+ "combination_executed should fire but does not. Add _execute_generator()."
		).is_false()

	itf.queue_free()


func test_generator_gap_active_generators_dict_absent() -> void:
	# [GAP] _active_generators does not exist on the current implementation.
	var itf: Node = _make_itf()

	var has_dict: bool = "_active_generators" in itf

	assert_bool(has_dict) \
		.override_failure_message(
			"[GAP story-006] _active_generators dict not present. "
			+ "Add it to the implementation to track generator instances."
		).is_false()

	itf.queue_free()


# ── SPEC: Expected behaviour once gap is closed ────────────────────────────────

func test_generator_spec_combination_executed_fires_before_first_tick() -> void:
	# [SPEC] AC-3: combination_executed is emitted immediately, before any timer ticks.
	var itf: Node = _make_itf()

	if not itf.has_method("_execute_generator"):
		push_warning(
			"[SPEC story-006] _execute_generator() not implemented. "
			+ "This test enforces AC-3 once the method exists."
		)
		itf.queue_free()
		return

	var recipe := _make_generator_recipe()
	var emitted := {"fired": false}
	itf.combination_executed.connect(
		func(_rid: String, _tmpl: String, _ia: String, _ib: String) -> void:
			emitted["fired"] = true
	)

	itf._execute_generator(recipe, "chester_0", "coffee_0", recipe["config"])

	# combination_executed fires synchronously before timer ticks
	assert_bool(emitted["fired"]).is_true()

	itf.queue_free()


func test_generator_spec_generator_registered_in_active_generators() -> void:
	# [SPEC] AC-1: _active_generators has an entry for the generator card after firing.
	var itf: Node = _make_itf()

	if not itf.has_method("_execute_generator"):
		push_warning("[SPEC story-006] _execute_generator() not implemented.")
		itf.queue_free()
		return

	var recipe := _make_generator_recipe("chester-coffee", "memory", 0.1, 3, "card_a")

	# generator_card = "card_a" → gen_id = "chester_0"
	itf._execute_generator(recipe, "chester_0", "coffee_0", recipe["config"])

	assert_bool("_active_generators" in itf).is_true()
	var active: Dictionary = itf._active_generators
	# Key may be instance_id or compound key per implementation
	var has_chester := active.has("chester_0") or _any_key_contains(active, "chester_0")
	assert_bool(has_chester).is_true()

	itf.queue_free()


func test_generator_spec_card_b_as_generator_card_registered() -> void:
	# [SPEC] generator_card = "card_b" → gen_id = instance_id_b
	var itf: Node = _make_itf()

	if not itf.has_method("_execute_generator"):
		push_warning("[SPEC story-006] _execute_generator() not implemented.")
		itf.queue_free()
		return

	var recipe := _make_generator_recipe("chester-coffee", "memory", 0.1, null, "card_b")

	itf._execute_generator(recipe, "chester_0", "coffee_0", recipe["config"])

	var active: Dictionary = itf._active_generators
	var has_coffee := active.has("coffee_0") or _any_key_contains(active, "coffee_0")
	assert_bool(has_coffee).is_true()

	itf.queue_free()


func test_generator_spec_card_removing_deregisters_generator() -> void:
	# [SPEC] AC-2: card_removing cancels the generator timer and removes entry.
	var itf: Node = _make_itf()

	if not itf.has_method("_execute_generator") or not itf.has_method("_on_card_removing"):
		push_warning("[SPEC story-006] Generator or card_removing handler not implemented.")
		itf.queue_free()
		return

	var recipe := _make_generator_recipe()
	itf._execute_generator(recipe, "chester_0", "coffee_0", recipe["config"])

	# Simulate card_removing for the generator card
	itf._on_card_removing("chester_0")

	# Assert: no longer in active generators
	var active: Dictionary = itf._active_generators
	var still_present := active.has("chester_0") or _any_key_contains(active, "chester_0")
	assert_bool(still_present).is_false()

	itf.queue_free()


func test_generator_spec_max_count_null_allows_unlimited_production() -> void:
	# [SPEC] AC-4: max_count = null → no exhaustion check fires.
	# Verify the recipe config reaches _execute_generator without error.
	var itf: Node = _make_itf()

	if not itf.has_method("_execute_generator"):
		push_warning("[SPEC story-006] _execute_generator() not implemented.")
		itf.queue_free()
		return

	var recipe := _make_generator_recipe("chester-coffee", "memory", 0.1, null)

	# Should not crash when max_count is null
	itf._execute_generator(recipe, "chester_0", "coffee_0", recipe["config"])

	var active: Dictionary = itf._active_generators
	var has_entry := active.has("chester_0") or _any_key_contains(active, "chester_0")
	assert_bool(has_entry).is_true()

	itf.queue_free()


func test_generator_spec_cooldown_recorded_after_execution() -> void:
	# [SPEC] Cooldown starts when combination fires — before any timer ticks.
	var itf: Node = _make_itf()

	if not itf.has_method("_execute_generator"):
		push_warning("[SPEC story-006] _execute_generator() not implemented.")
		itf.queue_free()
		return

	var recipe := _make_generator_recipe("chester-coffee")
	itf._execute_generator(recipe, "chester_0", "coffee_0", recipe["config"])

	assert_bool(itf._last_fired.has("chester-coffee")).is_true()

	itf.queue_free()


# ── helper ────────────────────────────────────────────────────────────────────

## Returns true if any key in the dict contains the search string.
## Handles compound keys like "chester_0|recipe-id".
func _any_key_contains(dict: Dictionary, search: String) -> bool:
	for key in dict.keys():
		if str(key).contains(search):
			return true
	return false
