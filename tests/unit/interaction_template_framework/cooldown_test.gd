## Unit tests for InteractionTemplateFramework cooldown state machine — Story 002.
##
## Covers all ACs from story-002-cooldown-state-machine.md:
##   AC-1: _is_on_cooldown returns false when recipe has never fired (Available)
##   AC-2: _is_on_cooldown returns true immediately after _fire_executed (Cooling)
##   AC-3: _is_on_cooldown returns false once COMBINATION_COOLDOWN_SEC elapses
##   AC-4: COMBINATION_COOLDOWN_SEC constant defaults to 30.0
##   AC-5: Per-recipe independence — one recipe cooling does not affect another
##   AC-6: reset_cooldowns() clears all cooldown state
##
## Timing strategy (no real timers):
##   _last_fired is a Dictionary keyed by recipe_id → float (seconds from
##   Time.get_ticks_msec()/1000.0). Tests manipulate _last_fired directly to
##   simulate elapsed time without sleeping, matching the AudioManager pattern.
##
## NOTE — Implementation/story mismatch (flag only):
##   Story 002 names the dict _last_fired_msec (int msec); implementation uses
##   _last_fired (float seconds). Tests target the actual implementation field name.
##   Story 002 says combination_succeeded is emitted; implementation calls
##   CardEngine.on_combination_succeeded() directly. Cooldown logic is tested
##   by inspecting _last_fired state rather than intercepting CardEngine calls.
extends GdUnitTestSuite

const ITFScript := preload("res://src/gameplay/interaction_template_framework.gd")

const COOLDOWN_SEC: float = 30.0  # mirrors ITFScript.COMBINATION_COOLDOWN_SEC


# ── helpers ───────────────────────────────────────────────────────────────────

func _make_itf() -> Node:
	var itf: Node = ITFScript.new()
	add_child(itf)
	return itf


# ── AC-4: constant value ───────────────────────────────────────────────────────

func test_cooldown_constant_defaults_to_30_seconds() -> void:
	# Arrange / Act
	var value: float = ITFScript.COMBINATION_COOLDOWN_SEC

	# Assert
	assert_float(value).is_equal(30.0)


# ── AC-1 / AC-6: Available state — never fired ────────────────────────────────

func test_cooldown_is_on_cooldown_returns_false_when_recipe_never_fired() -> void:
	# Arrange: fresh ITF; no _last_fired entry for recipe
	var itf: Node = _make_itf()

	# Act
	var result: bool = itf._is_on_cooldown("test-recipe")

	# Assert: Available (no entry → not on cooldown)
	assert_bool(result).is_false()

	itf.queue_free()


func test_cooldown_is_on_cooldown_returns_false_for_unknown_recipe_id() -> void:
	# Arrange: _last_fired has another recipe but NOT this one
	var itf: Node = _make_itf()
	var now: float = Time.get_ticks_msec() / 1000.0
	itf._last_fired["other-recipe"] = now

	# Act
	var result: bool = itf._is_on_cooldown("test-recipe")

	# Assert: missing key → Available
	assert_bool(result).is_false()

	itf.queue_free()


# ── AC-2: Cooling state — fired recently ──────────────────────────────────────

func test_cooldown_is_on_cooldown_returns_true_immediately_after_fire() -> void:
	# Arrange: set _last_fired to right now
	var itf: Node = _make_itf()
	var now: float = Time.get_ticks_msec() / 1000.0
	itf._last_fired["chester-ju"] = now

	# Act: check immediately (elapsed ≈ 0 < 30.0)
	var result: bool = itf._is_on_cooldown("chester-ju")

	# Assert: Cooling
	assert_bool(result).is_true()

	itf.queue_free()


func test_cooldown_is_on_cooldown_returns_true_at_29_seconds_elapsed() -> void:
	# Arrange: simulate 29 seconds elapsed by backdating _last_fired
	var itf: Node = _make_itf()
	var now: float = Time.get_ticks_msec() / 1000.0
	itf._last_fired["chester-ju"] = now - 29.0

	# Act
	var result: bool = itf._is_on_cooldown("chester-ju")

	# Assert: 29 < 30 → still Cooling
	assert_bool(result).is_true()

	itf.queue_free()


# ── AC-3: Expiry — Available again after cooldown_sec elapses ─────────────────

func test_cooldown_is_on_cooldown_returns_false_at_exactly_30_seconds_elapsed() -> void:
	# Arrange: simulate exactly 30.0 seconds elapsed
	var itf: Node = _make_itf()
	var now: float = Time.get_ticks_msec() / 1000.0
	itf._last_fired["chester-ju"] = now - 30.0

	# Act
	var result: bool = itf._is_on_cooldown("chester-ju")

	# Assert: elapsed >= COMBINATION_COOLDOWN_SEC → Available
	assert_bool(result).is_false()

	itf.queue_free()


func test_cooldown_is_on_cooldown_returns_false_after_30_seconds_elapsed() -> void:
	# Arrange: 31 seconds elapsed
	var itf: Node = _make_itf()
	var now: float = Time.get_ticks_msec() / 1000.0
	itf._last_fired["chester-ju"] = now - 31.0

	# Act
	var result: bool = itf._is_on_cooldown("chester-ju")

	# Assert: Available
	assert_bool(result).is_false()

	itf.queue_free()


# ── AC-5: Per-recipe independence ─────────────────────────────────────────────

func test_cooldown_one_recipe_cooling_does_not_affect_another() -> void:
	# Arrange: "recipe-a" is Cooling; "recipe-b" has never fired
	var itf: Node = _make_itf()
	var now: float = Time.get_ticks_msec() / 1000.0
	itf._last_fired["recipe-a"] = now  # Cooling

	# Act
	var a_cooling: bool = itf._is_on_cooldown("recipe-a")
	var b_available: bool = itf._is_on_cooldown("recipe-b")

	# Assert
	assert_bool(a_cooling).is_true()
	assert_bool(b_available).is_false()

	itf.queue_free()


func test_cooldown_two_recipes_can_both_be_available_simultaneously() -> void:
	# Arrange: both expired
	var itf: Node = _make_itf()
	var now: float = Time.get_ticks_msec() / 1000.0
	itf._last_fired["recipe-a"] = now - 60.0
	itf._last_fired["recipe-b"] = now - 60.0

	# Act / Assert
	assert_bool(itf._is_on_cooldown("recipe-a")).is_false()
	assert_bool(itf._is_on_cooldown("recipe-b")).is_false()

	itf.queue_free()


# ── AC-6: reset_cooldowns clears all entries ──────────────────────────────────

func test_cooldown_reset_cooldowns_clears_last_fired_dictionary() -> void:
	# Arrange: populate some cooldown entries
	var itf: Node = _make_itf()
	var now: float = Time.get_ticks_msec() / 1000.0
	itf._last_fired["recipe-a"] = now
	itf._last_fired["recipe-b"] = now

	# Act
	itf.reset_cooldowns()

	# Assert: dictionary empty
	assert_int(itf._last_fired.size()).is_equal(0)

	itf.queue_free()


func test_cooldown_after_reset_recipe_is_available() -> void:
	# Arrange: set a recipe as Cooling, then reset
	var itf: Node = _make_itf()
	var now: float = Time.get_ticks_msec() / 1000.0
	itf._last_fired["chester-ju"] = now

	itf.reset_cooldowns()

	# Act
	var result: bool = itf._is_on_cooldown("chester-ju")

	# Assert: Available again
	assert_bool(result).is_false()

	itf.queue_free()


# ── _fire_executed records timestamp ──────────────────────────────────────────

func test_cooldown_fire_executed_writes_last_fired_entry() -> void:
	# _fire_executed is the internal method that records the timestamp.
	# Verify it writes to _last_fired and emits combination_executed.
	var itf: Node = _make_itf()
	assert_bool(itf._last_fired.has("my-recipe")).is_false()

	# Act: call _fire_executed directly
	itf._fire_executed("my-recipe", "Additive", "card_a_0", "card_b_0")

	# Assert: timestamp written
	assert_bool(itf._last_fired.has("my-recipe")).is_true()
	var ts: float = float(itf._last_fired["my-recipe"])
	assert_bool(ts > 0.0).is_true()

	itf.queue_free()


func test_cooldown_fire_executed_makes_recipe_immediately_cooling() -> void:
	# Arrange
	var itf: Node = _make_itf()
	itf._fire_executed("my-recipe", "Additive", "a_0", "b_0")

	# Act
	var result: bool = itf._is_on_cooldown("my-recipe")

	# Assert: immediately Cooling after fire
	assert_bool(result).is_true()

	itf.queue_free()


func test_cooldown_fire_executed_emits_combination_executed_signal() -> void:
	# Arrange
	var itf: Node = _make_itf()
	var captured := {"recipe": "", "template": ""}
	itf.combination_executed.connect(
		func(rid: String, tmpl: String, _ia: String, _ib: String) -> void:
			captured["recipe"] = rid
			captured["template"] = tmpl
	)

	# Act
	itf._fire_executed("chester-ju", "Additive", "chester_0", "ju_0")

	# Assert
	assert_str(captured["recipe"]).is_equal("chester-ju")
	assert_str(captured["template"]).is_equal("Additive")

	itf.queue_free()
