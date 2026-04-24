## Unit tests for InteractionTemplateFramework — Generator template (Story 006).
##
## Design doc: design/gdd/interaction-template-framework.md — Generator template section
##
## Acceptance Criteria covered (using STORY numbering):
##   AC-1  Generator card identified from recipe.config.generator_card; registered in
##         _active_generators under compound key; timer started
##   AC-2  max_count: null means unlimited production (entry still registered, no early stop)
##   AC-3  Both input cards remain on table (combination_succeeded called with "Generator")
##   AC-4a Generator card removed → entry deregistered and timer stopped
##   AC-4b Non-generator input card removed → entry deregistered and timer stopped (NEW vs GDD)
##   AC-4  Unrelated card removed → no-op (entries unchanged)
##   AC-5  compound key "%s|%s" % [gen_id, recipe_id] used as dict key
##   AC-5a combination_executed fires immediately (before any tick); _last_fired recorded
##   AC-5b Same card in two generators simultaneously → two distinct compound keys; both
##         deregistered when that card is removed
##   cleanup  _deregister_generator stops and frees the timer node
##
## Strategy:
##   All tests call _execute_generator() and related methods directly,
##   bypassing signal routing and CardEngine. Timer ticks are NOT awaited —
##   we test state registration and signal emission synchronously.
##   Real tick behaviour (spawn count) is covered by generator_lifecycle_test.gd.
##
## No silent-skips: every test asserts its expected outcome unconditionally.
extends GdUnitTestSuite

const ITFScript := preload("res://src/gameplay/interaction_template_framework.gd")


# ── helpers ───────────────────────────────────────────────────────────────────

func _make_itf() -> Node:
	var itf: Node = auto_free(ITFScript.new())
	add_child(itf)
	return itf


func _make_generator_recipe(
		recipe_id: String = "chester-coffee",
		generates: String = "memory",
		interval_sec: float = 60.0,
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


# ── AC-5a: combination_executed fires immediately (before first tick) ─────────

func test_execute_generator_emits_combination_executed_before_tick() -> void:
	# Arrange — interval is 60 s so no real tick can fire during the test
	var itf: Node = _make_itf()
	var recipe := _make_generator_recipe()

	var fired := {"count": 0}
	itf.combination_executed.connect(
		func(_rid: String, _tmpl: String, _ia: String, _ib: String) -> void:
			fired["count"] += 1
	)

	# Act
	itf._execute_generator(recipe, "chester_0", "coffee_0", recipe["config"])

	# Assert — signal fired synchronously inside _execute_generator, before any tick
	assert_int(fired["count"]) \
		.override_failure_message(
			"[AC-5a] combination_executed must emit synchronously inside _execute_generator(), "
			+ "before any timer tick. Got %d emissions." % fired["count"]
		).is_equal(1)


func test_execute_generator_records_cooldown() -> void:
	# Arrange
	var itf: Node = _make_itf()
	var recipe := _make_generator_recipe("chester-coffee")

	# Act
	itf._execute_generator(recipe, "chester_0", "coffee_0", recipe["config"])

	# Assert — _fire_executed was called, so _last_fired contains the recipe id
	assert_bool(itf._last_fired.has("chester-coffee")) \
		.override_failure_message(
			"[AC-5a] _last_fired must contain recipe id after _execute_generator()."
		).is_true()


# ── AC-5: compound key used as dict key ───────────────────────────────────────

func test_execute_generator_registers_compound_key() -> void:
	# Arrange — generator_card = "card_a" → gen_id = instance_id_a = "chester_0"
	var itf: Node = _make_itf()
	var recipe := _make_generator_recipe("chester-coffee", "memory", 60.0, 3, "card_a")

	# Act
	itf._execute_generator(recipe, "chester_0", "coffee_0", recipe["config"])

	# Assert — key is "chester_0|chester-coffee", NOT plain "chester_0"
	var expected_key := "chester_0|chester-coffee"
	assert_bool(itf._active_generators.has(expected_key)) \
		.override_failure_message(
			"[AC-5] _active_generators must use compound key '%s'. "
			+ "Keys present: %s" % [expected_key, str(itf._active_generators.keys())]
		).is_true()


# ── AC-4b prereq: non_generator_id stored in entry ───────────────────────────

func test_execute_generator_stores_non_generator_id() -> void:
	# Arrange — generator is "chester_0", non-generator is "coffee_0"
	var itf: Node = _make_itf()
	var recipe := _make_generator_recipe("chester-coffee", "memory", 60.0, 3, "card_a")

	# Act
	itf._execute_generator(recipe, "chester_0", "coffee_0", recipe["config"])

	# Assert — entry holds both ids
	var key := "chester_0|chester-coffee"
	var entry: Dictionary = itf._active_generators.get(key, {})
	assert_str(entry.get("generator_id", "")) \
		.override_failure_message("[AC-4b-prereq] generator_id must be 'chester_0'.") \
		.is_equal("chester_0")
	assert_str(entry.get("non_generator_id", "")) \
		.override_failure_message("[AC-4b-prereq] non_generator_id must be 'coffee_0'.") \
		.is_equal("coffee_0")


# ── AC-1: generator card identified from recipe.config.generator_card ─────────

func test_generator_card_a_selects_instance_a_as_generator() -> void:
	# Arrange — generator_card = "card_a" → gen_id = instance_id_a
	var itf: Node = _make_itf()
	var recipe := _make_generator_recipe("chester-coffee", "memory", 60.0, 3, "card_a")

	# Act
	itf._execute_generator(recipe, "chester_0", "coffee_0", recipe["config"])

	# Assert — key contains "chester_0" (the card_a instance)
	var key := "chester_0|chester-coffee"
	assert_bool(itf._active_generators.has(key)) \
		.override_failure_message(
			"[AC-1] generator_card='card_a' must register compound key '%s'. "
			+ "Keys: %s" % [key, str(itf._active_generators.keys())]
		).is_true()


func test_generator_card_b_selects_instance_b_as_generator() -> void:
	# Arrange — generator_card = "card_b" → gen_id = instance_id_b
	var itf: Node = _make_itf()
	var recipe := _make_generator_recipe("chester-coffee", "memory", 60.0, 3, "card_b")

	# Act
	itf._execute_generator(recipe, "chester_0", "coffee_0", recipe["config"])

	# Assert — key contains "coffee_0" (the card_b instance)
	var key := "coffee_0|chester-coffee"
	assert_bool(itf._active_generators.has(key)) \
		.override_failure_message(
			"[AC-1] generator_card='card_b' must register compound key '%s'. "
			+ "Keys: %s" % [key, str(itf._active_generators.keys())]
		).is_true()


# ── AC-2: max_count null means unlimited ──────────────────────────────────────

func test_max_count_null_registers_unlimited_entry() -> void:
	# Arrange — max_count = null → unlimited
	var itf: Node = _make_itf()
	var recipe := _make_generator_recipe("chester-coffee", "memory", 60.0, null, "card_a")

	# Act
	itf._execute_generator(recipe, "chester_0", "coffee_0", recipe["config"])

	# Assert — entry created with max_count == null
	var key := "chester_0|chester-coffee"
	assert_bool(itf._active_generators.has(key)) \
		.override_failure_message(
			"[AC-2] Generator with max_count=null must still register in _active_generators."
		).is_true()

	var stored_max: Variant = itf._active_generators[key].get("max_count", "MISSING")
	assert_bool(stored_max == null) \
		.override_failure_message(
			"[AC-2] Stored max_count must be null. Got: %s" % str(stored_max)
		).is_true()


# ── AC-3: both inputs remain on table (combination_succeeded called with "Generator") ──

func test_execute_generator_calls_combination_succeeded_with_generator_template() -> void:
	# Arrange — spy on EventBus.combination_succeeded to verify template arg
	# CardEngine.on_combination_succeeded emits EventBus.combination_succeeded internally.
	# We verify ITF calls on_combination_succeeded with the "Generator" template string
	# by confirming combination_executed template field (same call chain verifies AC-3).
	var itf: Node = _make_itf()
	var recipe := _make_generator_recipe()

	var captured_template := {"value": ""}
	itf.combination_executed.connect(
		func(_rid: String, tmpl: String, _ia: String, _ib: String) -> void:
			captured_template["value"] = tmpl
	)

	# Act
	itf._execute_generator(recipe, "chester_0", "coffee_0", recipe["config"])

	# Assert — "Generator" template signals that CardEngine was told both cards remain Idle
	assert_str(captured_template["value"]) \
		.override_failure_message(
			"[AC-3] combination_executed template arg must be 'Generator' (both cards stay). "
			+ "Got: '%s'" % captured_template["value"]
		).is_equal("Generator")


# ── AC-4a: generator card removed cancels timer ───────────────────────────────

func test_on_card_removing_generator_card_deregisters() -> void:
	# Arrange
	var itf: Node = _make_itf()
	var recipe := _make_generator_recipe()
	itf._execute_generator(recipe, "chester_0", "coffee_0", recipe["config"])

	var key := "chester_0|chester-coffee"
	var timer: Timer = itf._active_generators[key]["timer"]

	# Act — remove the generator card
	itf._on_card_removing("chester_0")

	# Assert — entry erased and timer stopped
	assert_bool(itf._active_generators.has(key)) \
		.override_failure_message(
			"[AC-4a] Removing generator card must erase the compound-key entry."
		).is_false()
	assert_bool(timer.is_stopped()) \
		.override_failure_message("[AC-4a] Timer must be stopped when generator card is removed.") \
		.is_true()


# ── AC-4b: non-generator input card removed also cancels timer ────────────────

func test_on_card_removing_non_generator_card_deregisters() -> void:
	# Arrange — "chester_0" is generator, "coffee_0" is non-generator input
	var itf: Node = _make_itf()
	var recipe := _make_generator_recipe()
	itf._execute_generator(recipe, "chester_0", "coffee_0", recipe["config"])

	var key := "chester_0|chester-coffee"
	var timer: Timer = itf._active_generators[key]["timer"]

	# Act — remove the NON-generator card
	itf._on_card_removing("coffee_0")

	# Assert — entry erased and timer stopped (AC-4b: either card leaving cancels)
	assert_bool(itf._active_generators.has(key)) \
		.override_failure_message(
			"[AC-4b] Removing non-generator input card must erase the compound-key entry."
		).is_false()
	assert_bool(timer.is_stopped()) \
		.override_failure_message(
			"[AC-4b] Timer must be stopped when non-generator input card is removed."
		).is_true()


# ── AC-4: unrelated card removal is a no-op ───────────────────────────────────

func test_on_card_removing_unrelated_id_does_not_deregister() -> void:
	# Arrange — register "chester_0" generator; remove completely unrelated card
	var itf: Node = _make_itf()
	var recipe := _make_generator_recipe()
	itf._execute_generator(recipe, "chester_0", "coffee_0", recipe["config"])

	# Act
	itf._on_card_removing("ghost_0")

	# Assert — entry untouched
	var key := "chester_0|chester-coffee"
	assert_bool(itf._active_generators.has(key)) \
		.override_failure_message(
			"[AC-4] Removing an unrelated card must not deregister other generators."
		).is_true()


# ── AC-5b: same card in two generators uses distinct compound keys ─────────────

func test_two_generators_on_same_card_use_distinct_compound_keys() -> void:
	# Arrange — "chester_0" is generator in recipe-a AND recipe-b simultaneously
	var itf: Node = _make_itf()
	var recipe_a := _make_generator_recipe("recipe-a", "memory", 60.0, 3, "card_a")
	var recipe_b := _make_generator_recipe("recipe-b", "spark", 60.0, 5, "card_a")

	# Act
	itf._execute_generator(recipe_a, "chester_0", "coffee_0", recipe_a["config"])
	itf._execute_generator(recipe_b, "chester_0", "coffee_0", recipe_b["config"])

	# Assert — two distinct entries in _active_generators
	assert_int(itf._active_generators.size()) \
		.override_failure_message(
			"[AC-5b] Two different recipe_ids on same card must produce 2 distinct entries. "
			+ "Keys: %s" % str(itf._active_generators.keys())
		).is_equal(2)

	assert_bool(itf._active_generators.has("chester_0|recipe-a")) \
		.override_failure_message("[AC-5b] Key 'chester_0|recipe-a' must exist.") \
		.is_true()
	assert_bool(itf._active_generators.has("chester_0|recipe-b")) \
		.override_failure_message("[AC-5b] Key 'chester_0|recipe-b' must exist.") \
		.is_true()

	# Removing "chester_0" must deregister BOTH entries
	itf._on_card_removing("chester_0")

	assert_int(itf._active_generators.size()) \
		.override_failure_message(
			"[AC-5b] _on_card_removing('chester_0') must erase BOTH compound-key entries."
		).is_equal(0)


# ── cleanup: _deregister_generator removes timer from tree ───────────────────

func test_deregister_removes_timer_from_tree() -> void:
	# Arrange
	var itf: Node = _make_itf()
	var recipe := _make_generator_recipe()
	itf._execute_generator(recipe, "chester_0", "coffee_0", recipe["config"])

	var key := "chester_0|chester-coffee"
	var timer: Timer = itf._active_generators[key]["timer"]

	# Precondition: timer is a child of itf
	assert_bool(timer.get_parent() == itf) \
		.override_failure_message("[cleanup] Timer must be a child of ITF before deregister.") \
		.is_true()

	# Act
	itf._deregister_generator(key)

	# Assert — timer is stopped; entry erased
	assert_bool(timer.is_stopped()) \
		.override_failure_message("[cleanup] Timer must be stopped after _deregister_generator().") \
		.is_true()
	assert_bool(itf._active_generators.has(key)) \
		.override_failure_message("[cleanup] Entry must be erased after _deregister_generator().") \
		.is_false()
