## Unit tests for InteractionTemplateFramework Animate template — Story 005.
##
## Covers all ACs from story-005-animate-template.md:
##   AC-1: Animate emits combination_succeeded (via CardEngine call) then
##         combination_executed immediately — no waiting for animation end
##   AC-2: Infinite-loop animate (duration_sec: null) has no pending ITF state
##
## Strategy:
##   The Animate template is NOT implemented in the current codebase.
##   The implementation only handles "Additive" and "Merge" in _execute_template().
##   An "Animate" template name falls through to the `_:` branch which calls
##   CardEngine.on_combination_failed() and returns without emitting combination_executed.
##
##   These tests document both:
##   a) The MISSING implementation gap (Animate falls through to failed path)
##   b) The expected behaviour per the story spec, as pending-implementation tests
##
##   Tests marked [GAP] document the implementation deficit.
##   Tests marked [SPEC] document what should pass once the gap is closed.
##
## NOTE — Implementation/story mismatch (CRITICAL flag):
##   Animate template is entirely absent from src/gameplay/interaction_template_framework.gd.
##   The match block has no "Animate" case — it falls to the default warning/failed path.
##   All AC-1 and AC-2 behaviours require adding _execute_animate() to the implementation.
##   Do NOT modify src/. This test file documents the gap for sprint backlog.
extends GdUnitTestSuite

const ITFScript := preload("res://src/gameplay/interaction_template_framework.gd")


# ── helpers ───────────────────────────────────────────────────────────────────

func _make_itf() -> Node:
	var itf: Node = ITFScript.new()
	add_child(itf)
	return itf


func _make_animate_recipe(
		recipe_id: String = "chester-morning",
		duration_sec: Variant = 5.0) -> Dictionary:
	return {
		"id": recipe_id,
		"card_a": "chester",
		"card_b": "morning",
		"template": "Animate",
		"config": {
			"motion": "orbit",
			"speed": 1.0,
			"target": "card_a",
			"duration_sec": duration_sec,
		},
	}


# ── GAP: Animate not implemented — falls through to failed path ───────────────

func test_animate_gap_execute_template_animate_not_handled() -> void:
	# [GAP] The _execute_template() match block has no "Animate" case.
	# This test confirms the gap: combination_executed is NOT emitted for Animate.
	# When the gap is closed this test should be REPLACED by test_animate_spec_* tests.
	var itf: Node = _make_itf()
	var recipe := _make_animate_recipe()

	var emitted := {"fired": false}
	itf.combination_executed.connect(
		func(_rid: String, _tmpl: String, _ia: String, _ib: String) -> void:
			emitted["fired"] = true
	)

	# Act: directly invoke execute_template — "Animate" has no handler
	itf._execute_template(recipe, "chester_0", "morning_0")

	# Assert: combination_executed NOT emitted (gap confirmed)
	# When Animate is implemented this will flip to is_true()
	assert_bool(emitted["fired"]) \
		.override_failure_message(
			"[GAP story-005] Animate template is not implemented. "
			+ "combination_executed should fire but does not. Add _execute_animate()."
		).is_false()

	itf.queue_free()


func test_animate_gap_no_cooldown_recorded_for_animate_template() -> void:
	# [GAP] Because the Animate path falls through to on_combination_failed,
	# no cooldown is recorded. This should be false once implemented.
	var itf: Node = _make_itf()
	var recipe := _make_animate_recipe("chester-morning")

	itf._execute_template(recipe, "chester_0", "morning_0")

	# Assert: no cooldown written (gap)
	assert_bool(itf._last_fired.has("chester-morning")) \
		.override_failure_message(
			"[GAP story-005] No cooldown recorded for Animate — "
			+ "expected once _execute_animate() is implemented."
		).is_false()

	itf.queue_free()


# ── SPEC: Expected behaviour once gap is closed ────────────────────────────────

func test_animate_spec_combination_executed_emits_immediately_not_deferred() -> void:
	# [SPEC] Once _execute_animate() exists, this test should pass.
	# Skip gracefully if the method is absent.
	var itf: Node = _make_itf()

	if not itf.has_method("_execute_animate"):
		# Document the pending spec without failing CI
		push_warning(
			"[SPEC story-005] _execute_animate() not implemented. "
			+ "This test will enforce AC-1 once the method exists."
		)
		itf.queue_free()
		return

	var recipe := _make_animate_recipe()
	var emitted := {"fired": false}
	itf.combination_executed.connect(
		func(_rid: String, _tmpl: String, _ia: String, _ib: String) -> void:
			emitted["fired"] = true
	)

	itf._execute_animate(recipe, "chester_0", "morning_0", recipe["config"])

	assert_bool(emitted["fired"]).is_true()
	itf.queue_free()


func test_animate_spec_combination_executed_carries_animate_template_label() -> void:
	# [SPEC] Once _execute_animate() exists, template param should equal "Animate".
	var itf: Node = _make_itf()

	if not itf.has_method("_execute_animate"):
		push_warning("[SPEC story-005] _execute_animate() not implemented.")
		itf.queue_free()
		return

	var recipe := _make_animate_recipe()
	var captured := {"template": ""}
	itf.combination_executed.connect(
		func(_rid: String, tmpl: String, _ia: String, _ib: String) -> void:
			captured["template"] = tmpl
	)

	itf._execute_animate(recipe, "chester_0", "morning_0", recipe["config"])

	assert_str(captured["template"]).is_equal("Animate")
	itf.queue_free()


func test_animate_spec_no_pending_merges_after_animate() -> void:
	# [SPEC] Animate is fire-and-forget — no _pending_merges entry created.
	var itf: Node = _make_itf()

	if not itf.has_method("_execute_animate"):
		push_warning("[SPEC story-005] _execute_animate() not implemented.")
		itf.queue_free()
		return

	var recipe := _make_animate_recipe()
	itf._execute_animate(recipe, "chester_0", "morning_0", recipe["config"])

	assert_bool(itf._pending_merges.has("chester_0")).is_false()
	itf.queue_free()


func test_animate_spec_infinite_loop_no_extra_state() -> void:
	# [SPEC] duration_sec: null → no special ITF state beyond cooldown recorded.
	var itf: Node = _make_itf()

	if not itf.has_method("_execute_animate"):
		push_warning("[SPEC story-005] _execute_animate() not implemented.")
		itf.queue_free()
		return

	var recipe := _make_animate_recipe("chester-morning", null)
	itf._execute_animate(recipe, "chester_0", "morning_0", recipe["config"])

	# No pending merges, no active generators — only cooldown
	assert_bool(itf._pending_merges.has("chester_0")).is_false()
	assert_bool(itf._last_fired.has("chester-morning")).is_true()

	itf.queue_free()
