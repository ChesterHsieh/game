## Integration tests for InteractionTemplateFramework Merge template — Story 004.
##
## Covers all ACs from story-004-merge-template.md:
##   AC-1: Merge: combination_succeeded emitted then, after merge_animation_complete,
##         remove_card × 2, spawn result, combination_executed emitted
##   AC-2: Source card removed mid-animation cancels merge (no spawn, no exec signal)
##   AC-3: merge_animation_complete from a different pair is ignored
##
## Strategy:
##   The Merge template is Integration-type because it spans an async handshake:
##   ITF emits combination_succeeded → Card Engine animates → emits merge_animation_complete.
##
##   In the actual implementation:
##   - combination_succeeded is delivered via CardEngine.on_combination_succeeded() call
##   - merge_animation_complete is received via CardEngine.merge_complete signal
##   - The ITF stores pending merges in _pending_merges dict, resolved by _on_merge_complete
##
##   The integration tests call _execute_merge() directly to set up the pending state,
##   then fire _on_merge_complete() directly to simulate Card Engine's signal, allowing
##   deterministic verification without a live CardEngine scene.
##
##   card_removing / merge-cancel path: the implementation checks _pending_merges in
##   _on_combination_attempted; the GDD edge case (cancel on card_removing) is
##   described but not yet implemented in the current code. Tests mark that path
##   with a flag comment and verify the observable merge state.
##
## NOTE — Implementation/story mismatch (flag only):
##   Story 004 expects merge cancellation when card_removing fires mid-animation.
##   Implementation has no _on_card_removing handler at this time — the merge-cancel
##   path is not implemented. Test AC-2 documents this gap.
##   Story 004 expects merge_animation_complete via EventBus; implementation
##   connects to CardEngine.merge_complete directly in _ready().
extends GdUnitTestSuite

const ITFScript := preload("res://src/gameplay/interaction_template_framework.gd")


# ── helpers ───────────────────────────────────────────────────────────────────

func _make_itf() -> Node:
	var itf: Node = auto_free(ITFScript.new())
	add_child(itf)
	return itf


func _make_merge_recipe(
		recipe_id: String = "chester-ju",
		result_card: String = "memory") -> Dictionary:
	return {
		"id": recipe_id,
		"card_a": "chester",
		"card_b": "ju",
		"template": "Merge",
		"config": {"result_card": result_card},
	}


# ── AC-1: pending merge is registered after _execute_merge ───────────────────

func test_merge_pending_entry_created_after_execute_merge() -> void:
	# Arrange
	var itf: Node = _make_itf()
	var recipe := _make_merge_recipe()

	# Act: set up the pending merge
	itf._execute_merge(recipe, "chester_0", "ju_0", recipe["config"])

	# Assert: entry stored under instance_id_a
	assert_bool(itf._pending_merges.has("chester_0")).is_true()

	itf.queue_free()


func test_merge_pending_entry_contains_instance_id_b() -> void:
	# Arrange
	var itf: Node = _make_itf()
	var recipe := _make_merge_recipe()

	itf._execute_merge(recipe, "chester_0", "ju_0", recipe["config"])

	# Assert: pending entry records id_b
	var pending: Dictionary = itf._pending_merges["chester_0"]
	assert_str(pending["instance_id_b"]).is_equal("ju_0")

	itf.queue_free()


func test_merge_pending_entry_contains_recipe() -> void:
	# Arrange
	var itf: Node = _make_itf()
	var recipe := _make_merge_recipe("chester-ju", "memory")

	itf._execute_merge(recipe, "chester_0", "ju_0", recipe["config"])

	# Assert: pending entry stores the recipe dict
	var pending: Dictionary = itf._pending_merges["chester_0"]
	assert_str(pending["recipe"]["id"]).is_equal("chester-ju")

	itf.queue_free()


# ── AC-1: merge_complete resolves the pending entry ────────────────────────────

func test_merge_on_merge_complete_clears_pending_entry() -> void:
	# Arrange: set up pending merge then resolve it
	var itf: Node = _make_itf()
	var recipe := _make_merge_recipe()
	itf._execute_merge(recipe, "chester_0", "ju_0", recipe["config"])

	# Act: simulate Card Engine firing merge_complete
	itf._on_merge_complete("chester_0", "ju_0", Vector2(100.0, 100.0))

	# Assert: pending entry removed
	assert_bool(itf._pending_merges.has("chester_0")).is_false()

	itf.queue_free()


func test_merge_combination_executed_emitted_after_merge_complete() -> void:
	# Arrange
	var itf: Node = _make_itf()
	var recipe := _make_merge_recipe("chester-ju")
	itf._execute_merge(recipe, "chester_0", "ju_0", recipe["config"])

	var captured := {"recipe_id": "", "template": ""}
	itf.combination_executed.connect(
		func(rid: String, tmpl: String, _ia: String, _ib: String) -> void:
			captured["recipe_id"] = rid
			captured["template"] = tmpl
	)

	# Act
	itf._on_merge_complete("chester_0", "ju_0", Vector2(100.0, 100.0))

	# Assert
	assert_str(captured["recipe_id"]).is_equal("chester-ju")
	assert_str(captured["template"]).is_equal("Merge")

	itf.queue_free()


func test_merge_combination_executed_carries_instance_ids() -> void:
	# Arrange
	var itf: Node = _make_itf()
	var recipe := _make_merge_recipe()
	itf._execute_merge(recipe, "chester_0", "ju_0", recipe["config"])

	var captured := {"ia": "", "ib": ""}
	itf.combination_executed.connect(
		func(_rid: String, _tmpl: String, ia: String, ib: String) -> void:
			captured["ia"] = ia
			captured["ib"] = ib
	)

	# Act
	itf._on_merge_complete("chester_0", "ju_0", Vector2.ZERO)

	# Assert
	assert_str(captured["ia"]).is_equal("chester_0")
	assert_str(captured["ib"]).is_equal("ju_0")

	itf.queue_free()


func test_merge_cooldown_recorded_after_merge_complete() -> void:
	# Arrange
	var itf: Node = _make_itf()
	var recipe := _make_merge_recipe("chester-ju")
	itf._execute_merge(recipe, "chester_0", "ju_0", recipe["config"])

	# Act
	itf._on_merge_complete("chester_0", "ju_0", Vector2.ZERO)

	# Assert: cooldown entry written
	assert_bool(itf._last_fired.has("chester-ju")).is_true()

	itf.queue_free()


# ── AC-3: merge_complete from a different pair is ignored ─────────────────────

func test_merge_on_merge_complete_from_different_pair_is_ignored() -> void:
	# Arrange: pending merge for chester_0/ju_0
	var itf: Node = _make_itf()
	var recipe := _make_merge_recipe()
	itf._execute_merge(recipe, "chester_0", "ju_0", recipe["config"])

	var emitted := {"fired": false}
	itf.combination_executed.connect(
		func(_rid: String, _tmpl: String, _ia: String, _ib: String) -> void:
			emitted["fired"] = true
	)

	# Act: fire merge_complete for a completely different pair
	itf._on_merge_complete("rain_0", "coffee_0", Vector2(50.0, 50.0))

	# Assert: pending entry for chester_0 still present; no signal emitted
	assert_bool(itf._pending_merges.has("chester_0")).is_true()
	assert_bool(emitted["fired"]).is_false()

	itf.queue_free()


func test_merge_on_merge_complete_different_pair_does_not_modify_pending() -> void:
	# Ensure the rogue merge_complete doesn't corrupt _pending_merges
	var itf: Node = _make_itf()
	var recipe := _make_merge_recipe()
	itf._execute_merge(recipe, "chester_0", "ju_0", recipe["config"])
	var count_before: int = itf._pending_merges.size()

	itf._on_merge_complete("rain_0", "coffee_0", Vector2.ZERO)

	assert_int(itf._pending_merges.size()).is_equal(count_before)

	itf.queue_free()


# ── AC-2: merge cancel — document gap in implementation ──────────────────────

func test_merge_cancel_gap_pending_merge_persists_without_card_removing_handler() -> void:
	# KNOWN GAP (story-004 AC-2): The GDD requires that when card_removing fires
	# for a merge source card, the merge is cancelled. The current implementation
	# has no _on_card_removing handler — the pending entry is never cleaned up
	# if a card is removed mid-animation by an external system.
	#
	# This test documents the gap: _pending_merges is NOT cleared by a card_removing
	# event because that handler is not implemented.
	var itf: Node = _make_itf()
	var recipe := _make_merge_recipe()
	itf._execute_merge(recipe, "chester_0", "ju_0", recipe["config"])

	# No _on_card_removing call — method does not exist yet.
	# Verify pending entry is still present (gap confirmation).
	assert_bool(itf._pending_merges.has("chester_0")).is_true()

	# The gap: a future implementation of _on_card_removing should
	# remove this entry. When that is added, this test should be replaced
	# with a proper cancellation assertion.
	itf.queue_free()


# ── Multiple concurrent merges ────────────────────────────────────────────────

func test_merge_two_concurrent_merges_independent() -> void:
	# Arrange: two separate merge recipes pending simultaneously
	var itf: Node = _make_itf()
	var recipe_a := _make_merge_recipe("recipe-a")
	var recipe_b := {
		"id": "recipe-b", "card_a": "rain", "card_b": "coffee",
		"template": "Merge", "config": {"result_card": "storm"},
	}

	itf._execute_merge(recipe_a, "chester_0", "ju_0", recipe_a["config"])
	itf._execute_merge(recipe_b, "rain_0", "coffee_0", recipe_b["config"])

	assert_int(itf._pending_merges.size()).is_equal(2)

	# Resolve only the first
	itf._on_merge_complete("chester_0", "ju_0", Vector2.ZERO)

	# Assert: only first resolved; second still pending
	assert_bool(itf._pending_merges.has("chester_0")).is_false()
	assert_bool(itf._pending_merges.has("rain_0")).is_true()

	itf.queue_free()
