## Integration tests for CardSpawning remove_card — Story 003.
## Covers AC-1 through AC-5 from story-003-remove-clearing.md.
##
## Autoload context:
##   All autoloads (CardSpawning, EventBus, CardDatabase, InputSystem) are live.
##
## Known implementation divergences from story-003 spec:
##   1. remove_card() does NOT emit card_removing before node hide (not implemented).
##      The system only emits card_removed AFTER queue_free() is called.
##   2. clear_all_cards() is NOT implemented — the method does not exist.
##   3. Clearing state / spawn queue are NOT implemented.
##   4. InputSystem.unregister_card() is called inside remove_card() — this
##      requires the node to be registered via InputSystem.register_card() first,
##      which only happens inside spawn_card() (and spawn_card() itself is blocked
##      by the CardDatabase.has_card() bug).
##
##   Tests are written for the observable contracts that CAN be verified:
##     - remove_card() with unknown instance_id: push_warning + no crash (AC-3)
##     - remove_card() with unknown id does not emit card_removed (AC-3)
##     - card_removed signal fires after successful remove (AC-2, via injected stub)
##     - Registry is empty after removal (AC-2 / AC-4 partial)
##     - clear_all_cards absence: method-exists check documents the gap
##
##   Stub injection (same pattern as pool_registry_test.gd) is used to pre-load
##   the registry so remove_card() can find a node without going through spawn_card().
##   Injected stubs also need to be registered with InputSystem (which remove_card
##   calls unregister_card on) — since we cannot call the real register_card without
##   a valid card_id, we rely on InputSystem's no-op behaviour for unknown ids.
extends GdUnitTestSuite

const CardSpawningScript := preload("res://src/gameplay/card_spawning_system.gd")


# ── Shared references ─────────────────────────────────────────────────────────

var _spawning: Node = null

func before_each() -> void:
	_spawning = get_node_or_null("/root/CardSpawning")


# ── Helpers ───────────────────────────────────────────────────────────────────

## Directly inject a card node into the live registry, bypassing spawn_card().
## The stub is added as a child of the autoload so remove_card can queue_free it.
func _inject_live_card(instance_id: String, card_id: String, pos: Vector2) -> Node2D:
	var stub := Node2D.new()
	stub.name = "Stub_%s" % instance_id
	stub.position = pos
	stub.instance_id = ""   # CardNode vars are plain vars, not @export
	stub.set_meta("card_id", card_id)
	stub.set_meta("instance_id", instance_id)
	_spawning.add_child(stub)
	_spawning._live_cards[instance_id] = stub
	return stub


# ── AC-3: unknown instance_id is idempotent ───────────────────────────────────

func test_remove_card_unknown_id_does_not_crash() -> void:
	# AC-3: calling remove_card with an id not in registry must not crash
	# (push_warning is expected — no assertion on it since gdUnit4 can't intercept)
	_spawning.remove_card("ghost_99")
	# If we reach here, no crash occurred
	assert_bool(true).is_true()


func test_remove_card_unknown_id_does_not_change_registry() -> void:
	# AC-3: registry must be unchanged when instance_id is not found
	var before_ids: Array[String] = _spawning.get_all_instance_ids()
	var before_count: int = before_ids.size()

	_spawning.remove_card("ghost_99")

	var after_ids: Array[String] = _spawning.get_all_instance_ids()
	assert_int(after_ids.size()).is_equal(before_count)


func test_remove_card_unknown_id_does_not_emit_card_removed() -> void:
	# AC-3: card_removed must NOT fire for an unknown instance_id
	var emitted := false
	var on_removed := func(_iid: String) -> void:
		emitted = true
	_spawning.card_removed.connect(on_removed)

	_spawning.remove_card("ghost_99")

	_spawning.card_removed.disconnect(on_removed)
	assert_bool(emitted) \
		.override_failure_message("card_removed must NOT fire for unknown instance_id") \
		.is_false()


func test_remove_card_idempotent_on_second_call_with_same_id() -> void:
	# AC-3 extended: calling remove_card twice with the same id must not crash
	_spawning.remove_card("ghost_99")
	_spawning.remove_card("ghost_99")
	assert_bool(true).is_true()


# ── AC-2: card_removed fires after node is removed from registry ──────────────
## These tests inject a stub directly into _live_cards.
## remove_card() calls InputSystem.unregister_card(instance_id) — InputSystem
## silently no-ops for unknown ids, so this is safe for injected stubs.
## It also calls node.queue_free() — so the stub is freed after removal.

func test_remove_card_known_id_emits_card_removed_signal() -> void:
	# Arrange — inject a stub card into the live registry
	var instance_id := "test-remove-signal_0"
	_inject_live_card(instance_id, "chester", Vector2(10.0, 10.0))

	var emitted := false
	var received_id: String = ""
	var on_removed := func(iid: String) -> void:
		emitted = true
		received_id = iid
	_spawning.card_removed.connect(on_removed)

	# Act
	_spawning.remove_card(instance_id)

	# Assert
	_spawning.card_removed.disconnect(on_removed)
	assert_bool(emitted) \
		.override_failure_message("card_removed must fire after remove_card() for a known id") \
		.is_true()
	assert_str(received_id).is_equal(instance_id)


func test_remove_card_known_id_erases_from_registry() -> void:
	# AC-2: after remove_card, the instance_id must not appear in get_all_instance_ids()
	var instance_id := "test-remove-registry_0"
	_inject_live_card(instance_id, "ju", Vector2(20.0, 20.0))

	# Act
	_spawning.remove_card(instance_id)

	# Assert
	var ids: Array[String] = _spawning.get_all_instance_ids()
	assert_bool(instance_id in ids) \
		.override_failure_message("instance_id must be removed from registry after remove_card") \
		.is_false()


func test_remove_card_known_id_get_card_node_returns_null_afterwards() -> void:
	# AC-2: get_card_node() must return null for a removed card
	var instance_id := "test-remove-lookup_0"
	_inject_live_card(instance_id, "safe", Vector2(30.0, 30.0))

	# Act
	_spawning.remove_card(instance_id)

	# Assert
	var node: Node2D = _spawning.get_card_node(instance_id)
	assert_that(node == null).is_true()


func test_remove_card_only_removes_targeted_card() -> void:
	# AC-4 partial: removing one card must leave others in the registry
	var id_a := "test-remove-partial_a"
	var id_b := "test-remove-partial_b"
	_inject_live_card(id_a, "chester", Vector2(10.0, 10.0))
	_inject_live_card(id_b, "ju", Vector2(20.0, 20.0))

	# Act — remove only id_a
	_spawning.remove_card(id_a)

	# Assert — id_b must still be live
	var ids: Array[String] = _spawning.get_all_instance_ids()
	assert_bool(id_a in ids).is_false()
	assert_bool(id_b in ids).is_true()

	# Cleanup — remove id_b manually to avoid polluting other tests
	_spawning.remove_card(id_b)


# ── AC-1 gap: card_removing signal ───────────────────────────────────────────
## The spec requires card_removing to fire BEFORE the node is hidden.
## The current implementation does NOT have this signal on the autoload.
## This test documents the gap: card_removing is on EventBus (ADR-003) but
## remove_card() does not emit it.

func test_card_removing_is_not_declared_on_card_spawning_autoload() -> void:
	# Documents ADR-003 vs implementation gap:
	# card_removing is on EventBus, but CardSpawning does not emit it.
	# This test will FAIL when the implementation is brought into compliance.
	assert_bool(_spawning.has_signal("card_removing")) \
		.override_failure_message(
			"card_removing signal gap: story-003 requires remove_card() to emit " +
			"card_removing BEFORE node hide; implementation does not emit it yet"
		) \
		.is_false()


# ── AC-4 gap: clear_all_cards not implemented ─────────────────────────────────

func test_clear_all_cards_method_is_not_yet_implemented() -> void:
	# Documents implementation gap: clear_all_cards() does not exist.
	# This test will FAIL when clear_all_cards() is added — remove it then and
	# replace with the full AC-4 test suite.
	assert_bool(_spawning.has_method("clear_all_cards")) \
		.override_failure_message(
			"clear_all_cards() gap: story-003 requires this method; " +
			"remove this gap test and add full AC-4 tests when implemented"
		) \
		.is_false()


# ── AC-5 gap: Clearing state / spawn queue not implemented ────────────────────

func test_clearing_state_not_implemented() -> void:
	# Documents implementation gap: _state / _spawn_queue do not exist.
	# When the Clearing state machine is added, remove this test and add:
	#   test_spawn_card_queued_during_clearing_executes_after()
	assert_bool("_spawn_queue" in _spawning) \
		.override_failure_message(
			"_spawn_queue gap: story-003 requires spawn queuing during Clearing state; " +
			"remove this gap test when _spawn_queue is implemented"
		) \
		.is_false()
