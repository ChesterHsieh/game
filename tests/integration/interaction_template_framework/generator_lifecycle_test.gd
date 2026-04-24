## Integration tests — Generator template lifecycle (Story 006).
##
## Design doc: design/gdd/interaction-template-framework.md — Generator template section
##
## These tests exercise the full Generator registration → tick → deregister
## lifecycle using direct method calls (no mocked signals, no real CardEngine).
## Timer ticks are simulated by calling _on_generator_tick() directly with the
## compound key.
##
## Acceptance Criteria validated end-to-end (STORY numbering):
##   AC-1  Generator stops after max_count spawns (timer deregistered)
##   AC-2  max_count null keeps generator alive past any spawn count
##   AC-3  combination_executed fires exactly once on registration (before ticks)
##   AC-4a Generator card removed mid-run tears down timer and entry
##   AC-4b Non-generator input card removed mid-run tears down timer and entry (NEW vs GDD)
##
## Isolation: each test constructs its own ITF node; auto_free handles cleanup.
## No shared mutable state between tests.
extends GdUnitTestSuite

const ITFScript := preload("res://src/gameplay/interaction_template_framework.gd")


# ── helpers ───────────────────────────────────────────────────────────────────

func _make_itf() -> Node:
	var itf: Node = auto_free(ITFScript.new())
	add_child(itf)
	return itf


func _make_recipe(
		recipe_id: String = "gen-recipe",
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


## Simulate N timer ticks on a generator without waiting real time.
## key: compound key e.g. "chester_0|gen-recipe"
func _tick_n(itf: Node, key: String, n: int) -> void:
	for _i in range(n):
		itf._on_generator_tick(key)


# ── AC-3: combination_executed fires exactly once on registration ─────────────

func test_lifecycle_ac3_combination_executed_fires_once_on_register() -> void:
	# Arrange
	var itf: Node = _make_itf()
	var recipe := _make_recipe()
	var signal_count := {"value": 0}
	itf.combination_executed.connect(
		func(_rid, _tmpl, _ia, _ib) -> void:
			signal_count["value"] += 1
	)

	# Act — register; simulate 2 timer ticks manually (ticks must NOT emit combination_executed)
	itf._execute_generator(recipe, "chester_0", "coffee_0", recipe["config"])
	_tick_n(itf, "chester_0|gen-recipe", 2)

	# Assert — exactly 1 emission (from registration), not from ticks
	assert_int(signal_count["value"]) \
		.override_failure_message(
			"[AC-3] combination_executed must fire exactly once (at registration). "
			+ "Got: %d" % signal_count["value"]
		).is_equal(1)


# ── AC-1: generator stops after max_count ticks ───────────────────────────────

func test_lifecycle_ac1_generator_deregistered_after_max_count_ticks() -> void:
	# Arrange — max_count = 2
	var itf: Node = _make_itf()
	var recipe := _make_recipe("gen-recipe", "memory", 60.0, 2, "card_a")

	# Act
	itf._execute_generator(recipe, "chester_0", "coffee_0", recipe["config"])
	_tick_n(itf, "chester_0|gen-recipe", 2)  # tick 1 spawns, tick 2 spawns + deregisters

	# Assert — entry removed after max_count reached
	assert_bool(itf._active_generators.has("chester_0|gen-recipe")) \
		.override_failure_message(
			"[AC-1] Generator must be deregistered after max_count (2) ticks. "
			+ "_active_generators: %s" % str(itf._active_generators)
		).is_false()


func test_lifecycle_ac1_extra_ticks_after_deregister_are_no_ops() -> void:
	# Arrange — max_count = 1
	var itf: Node = _make_itf()
	var recipe := _make_recipe("gen-recipe", "memory", 60.0, 1, "card_a")

	# Act
	itf._execute_generator(recipe, "chester_0", "coffee_0", recipe["config"])
	_tick_n(itf, "chester_0|gen-recipe", 5)  # 4 ticks beyond max_count

	# Assert — still deregistered; no crash; no re-registration
	assert_bool(itf._active_generators.has("chester_0|gen-recipe")) \
		.override_failure_message(
			"[AC-1] Extra ticks past max_count must be no-ops; entry must stay absent."
		).is_false()


# ── AC-2: max_count null generator stays alive ────────────────────────────────

func test_lifecycle_ac2_unlimited_generator_stays_registered_after_many_ticks() -> void:
	# Arrange — max_count = null (unlimited)
	var itf: Node = _make_itf()
	var recipe := _make_recipe("gen-recipe", "memory", 60.0, null, "card_a")

	# Act
	itf._execute_generator(recipe, "chester_0", "coffee_0", recipe["config"])
	_tick_n(itf, "chester_0|gen-recipe", 100)  # 100 ticks — must not deregister

	# Assert — still registered
	assert_bool(itf._active_generators.has("chester_0|gen-recipe")) \
		.override_failure_message(
			"[AC-2] Generator with max_count=null must remain registered after 100 ticks."
		).is_true()


# ── AC-4a: generator card removed cancels production ─────────────────────────

func test_lifecycle_ac4a_generator_card_removing_stops_and_erases() -> void:
	# Arrange — register with max_count=10; fire 3 ticks; then remove the GENERATOR card
	var itf: Node = _make_itf()
	var recipe := _make_recipe("gen-recipe", "memory", 60.0, 10, "card_a")

	itf._execute_generator(recipe, "chester_0", "coffee_0", recipe["config"])
	_tick_n(itf, "chester_0|gen-recipe", 3)

	var key := "chester_0|gen-recipe"
	assert_bool(itf._active_generators.has(key)) \
		.override_failure_message("[AC-4a] Precondition: generator must be active after 3 ticks.") \
		.is_true()

	var timer: Timer = itf._active_generators[key]["timer"]

	# Act — remove the GENERATOR card ("chester_0")
	itf._on_card_removing("chester_0")

	# Assert — entry gone and timer stopped
	assert_bool(itf._active_generators.has(key)) \
		.override_failure_message(
			"[AC-4a] _on_card_removing(generator_id) mid-run must erase generator entry."
		).is_false()
	assert_bool(timer.is_stopped()) \
		.override_failure_message("[AC-4a] Timer must be stopped after generator card removed.") \
		.is_true()


func test_lifecycle_ac4a_ticks_after_generator_card_removing_are_no_ops() -> void:
	# Arrange — register, remove generator card, then simulate further ticks
	var itf: Node = _make_itf()
	var recipe := _make_recipe("gen-recipe", "memory", 60.0, 10, "card_a")

	itf._execute_generator(recipe, "chester_0", "coffee_0", recipe["config"])
	itf._on_card_removing("chester_0")

	# Act — ticks after removal must not crash or re-register
	_tick_n(itf, "chester_0|gen-recipe", 5)

	# Assert — stays absent
	assert_bool(itf._active_generators.has("chester_0|gen-recipe")) \
		.override_failure_message(
			"[AC-4a] Ticks after generator card_removing must be no-ops; entry must stay absent."
		).is_false()


# ── AC-4b: non-generator input card removed also cancels production ───────────

func test_lifecycle_ac4b_non_generator_card_removing_stops_and_erases() -> void:
	# Arrange — register with max_count=10; fire 3 ticks; then remove the NON-GENERATOR card
	var itf: Node = _make_itf()
	var recipe := _make_recipe("gen-recipe", "memory", 60.0, 10, "card_a")
	# "chester_0" is generator (card_a), "coffee_0" is non-generator input

	itf._execute_generator(recipe, "chester_0", "coffee_0", recipe["config"])
	_tick_n(itf, "chester_0|gen-recipe", 3)

	var key := "chester_0|gen-recipe"
	assert_bool(itf._active_generators.has(key)) \
		.override_failure_message("[AC-4b] Precondition: generator must be active after 3 ticks.") \
		.is_true()

	var timer: Timer = itf._active_generators[key]["timer"]

	# Act — remove the NON-GENERATOR card ("coffee_0")
	itf._on_card_removing("coffee_0")

	# Assert — entry gone and timer stopped (AC-4b: non-generator removal also cancels)
	assert_bool(itf._active_generators.has(key)) \
		.override_failure_message(
			"[AC-4b] _on_card_removing(non_generator_id) mid-run must erase generator entry."
		).is_false()
	assert_bool(timer.is_stopped()) \
		.override_failure_message(
			"[AC-4b] Timer must be stopped after non-generator input card removed."
		).is_true()


func test_lifecycle_ac4b_ticks_after_non_generator_card_removing_are_no_ops() -> void:
	# Arrange — register, remove non-generator card, then simulate further ticks
	var itf: Node = _make_itf()
	var recipe := _make_recipe("gen-recipe", "memory", 60.0, 10, "card_a")

	itf._execute_generator(recipe, "chester_0", "coffee_0", recipe["config"])
	itf._on_card_removing("coffee_0")

	# Act — ticks after non-generator removal must not crash or re-register
	_tick_n(itf, "chester_0|gen-recipe", 5)

	# Assert — stays absent
	assert_bool(itf._active_generators.has("chester_0|gen-recipe")) \
		.override_failure_message(
			"[AC-4b] Ticks after non-generator card_removing must be no-ops; entry must stay absent."
		).is_false()
