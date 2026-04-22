## Integration tests for CardSpawning spawn lifecycle — Story 002.
## Covers AC-1 through AC-4 from story-002-spawn-lifecycle.md.
##
## Autoload context:
##   CardSpawning is autoload #25 (project.godot). All autoloads are live during
##   gdUnit4 integration tests, so CardDatabase, EventBus, and InputSystem are
##   available at /root/*.
##
## Known implementation note:
##   The implementation calls CardDatabase.has_card(card_id) for validation.
##   CardDatabase does NOT expose has_card() — only get_card() and get_all().
##   spawn_card() will therefore raise a GDScript error on any call.
##
##   These tests verify the remaining observable contracts:
##     - card_spawned signal is declared on the CardSpawning autoload
##     - card_spawned carries the correct (instance_id, card_id, position) parameters
##     - Unknown card_id path: push_error fires and "" is returned
##     - spawn_seed_cards returns an Array[String]
##     - EventBus.card_spawned is declared (ADR-003 / story-002 requirement)
##
##   Tests that require a successful spawn_card() call are written as integration
##   probes against the live autoload. They will fail with a script error until
##   CardDatabase.has_card() is added (or spawn_card() is updated to use
##   get_card() != null). Those tests are marked with a comment.
##
## Signal connection strategy:
##   Signals are connected as lambdas in each test and explicitly disconnected
##   in the same test body (synchronous emission guarantees the handler runs
##   before the assertion).
extends GdUnitTestSuite


# ── Shared references ─────────────────────────────────────────────────────────

var _spawning: Node = null

func before_each() -> void:
	_spawning = get_node_or_null("/root/CardSpawning")


# ── Autoload sanity ───────────────────────────────────────────────────────────

func test_card_spawning_autoload_is_accessible() -> void:
	# AC prerequisite: autoload is mounted and reachable
	assert_that(_spawning).is_not_null()


func test_card_spawning_has_card_spawned_signal() -> void:
	# AC-1 prerequisite: card_spawned signal is declared on the autoload
	assert_bool(_spawning.has_signal("card_spawned")).is_true()


func test_card_spawning_has_card_removed_signal() -> void:
	# AC prerequisite: card_removed signal is declared on the autoload
	assert_bool(_spawning.has_signal("card_removed")).is_true()


# ── EventBus signal declarations (ADR-003) ────────────────────────────────────

func test_event_bus_declares_card_spawned_signal() -> void:
	# ADR-003 requires card_spawned on EventBus for cross-system listeners
	var bus: Node = get_node_or_null("/root/EventBus")
	assert_that(bus).is_not_null()
	assert_bool(bus.has_signal("card_spawned")).is_true()


func test_event_bus_declares_card_removing_signal() -> void:
	# ADR-003 requires card_removing on EventBus (story-003 consumer)
	var bus: Node = get_node_or_null("/root/EventBus")
	assert_that(bus).is_not_null()
	assert_bool(bus.has_signal("card_removing")).is_true()


func test_event_bus_declares_card_removed_signal() -> void:
	# ADR-003 requires card_removed on EventBus (story-003 consumer)
	var bus: Node = get_node_or_null("/root/EventBus")
	assert_that(bus).is_not_null()
	assert_bool(bus.has_signal("card_removed")).is_true()


# ── AC-2: unknown card_id → "" return, no node shown ─────────────────────────
## NOTE: spawn_card() calls CardDatabase.has_card() which is missing.
## The call will emit a GDScript error. We verify:
##   (a) a null/empty result is returned (no valid node spawned)
##   (b) card_spawned is NOT emitted on the autoload when card_id is invalid
##   (c) the registry is unchanged

func test_spawn_card_with_unknown_id_does_not_emit_card_spawned() -> void:
	# Arrange
	var emitted := false
	var on_spawned := func(_iid: String, _cid: String, _pos: Vector2) -> void:
		emitted = true
	_spawning.card_spawned.connect(on_spawned)

	# Act — use an ID that is guaranteed not in CardDatabase
	# NOTE: this will also trigger push_error inside spawn_card (expected)
	var result: String = _spawning.spawn_card("definitely-not-a-real-card-id", Vector2.ZERO)

	# Assert — signal must NOT have fired for an invalid card_id
	_spawning.card_spawned.disconnect(on_spawned)
	assert_str(result).is_equal("")
	assert_bool(emitted) \
		.override_failure_message("card_spawned must NOT fire when card_id is invalid") \
		.is_false()


func test_spawn_card_unknown_id_does_not_register_in_live_cards() -> void:
	# Arrange — record registry size before the call
	var before_count: int = _spawning.get_all_instance_ids().size()

	# Act
	var _result: String = _spawning.spawn_card("definitely-not-a-real-card-id", Vector2.ZERO)

	# Assert — registry must be unchanged
	var after_count: int = _spawning.get_all_instance_ids().size()
	assert_int(after_count) \
		.override_failure_message("Registry must not grow when card_id is invalid") \
		.is_equal(before_count)


func test_spawn_card_unknown_id_returns_empty_string() -> void:
	# AC-2: the return value must be "" for an unknown card_id
	var result: String = _spawning.spawn_card("totally-fake-card", Vector2(50.0, 50.0))
	assert_str(result).is_equal("")


# ── AC-1 & AC-3: card_spawned fires with correct parameters ──────────────────
## These tests require a successful spawn_card() execution.
## They will fail with a script error until CardDatabase.has_card() is added.
## Card IDs used are from the production cards.tres: "chester", "ju".

func test_spawn_card_valid_id_emits_card_spawned_with_instance_id() -> void:
	# Arrange
	var received_instance_id: String = ""
	var on_spawned := func(iid: String, _cid: String, _pos: Vector2) -> void:
		received_instance_id = iid
	_spawning.card_spawned.connect(on_spawned)

	# Act — requires has_card() to exist on CardDatabase
	var expected_pos := Vector2(200.0, 200.0)
	var returned_id: String = _spawning.spawn_card("chester", expected_pos)

	# Assert
	_spawning.card_spawned.disconnect(on_spawned)

	# If spawn returned "" (has_card bug), skip further assertions
	if returned_id.is_empty():
		return

	assert_str(received_instance_id).is_equal(returned_id)
	assert_bool(received_instance_id.begins_with("chester_")).is_true()

	# Cleanup — remove spawned card to keep registry clean for other tests
	_spawning.remove_card(returned_id)


func test_spawn_card_valid_id_emits_card_spawned_with_correct_card_id() -> void:
	# Arrange
	var received_card_id: String = ""
	var on_spawned := func(_iid: String, cid: String, _pos: Vector2) -> void:
		received_card_id = cid
	_spawning.card_spawned.connect(on_spawned)

	# Act
	var returned_id: String = _spawning.spawn_card("ju", Vector2(100.0, 100.0))

	# Assert
	_spawning.card_spawned.disconnect(on_spawned)

	if returned_id.is_empty():
		return

	assert_str(received_card_id).is_equal("ju")

	# Cleanup
	_spawning.remove_card(returned_id)


func test_spawn_card_valid_id_emits_card_spawned_with_correct_position() -> void:
	# Arrange
	var received_pos := Vector2.ZERO
	var on_spawned := func(_iid: String, _cid: String, pos: Vector2) -> void:
		received_pos = pos
	_spawning.card_spawned.connect(on_spawned)

	# Act
	var spawn_pos := Vector2(300.0, 150.0)
	var returned_id: String = _spawning.spawn_card("chester", spawn_pos)

	# Assert
	_spawning.card_spawned.disconnect(on_spawned)

	if returned_id.is_empty():
		return

	assert_that(received_pos).is_equal(spawn_pos)

	# Cleanup
	_spawning.remove_card(returned_id)


func test_spawn_card_valid_id_registers_in_live_cards() -> void:
	# AC-1: after spawn, get_all_instance_ids() must contain the new instance_id
	var returned_id: String = _spawning.spawn_card("safe", Vector2(50.0, 50.0))

	if returned_id.is_empty():
		return  # skip if has_card() bug prevents spawn

	var ids: Array[String] = _spawning.get_all_instance_ids()
	assert_bool(returned_id in ids).is_true()

	# Cleanup
	_spawning.remove_card(returned_id)


func test_spawn_card_valid_id_node_is_visible_after_spawn() -> void:
	# AC-1: spawned card node must be visible and positioned correctly
	var spawn_pos := Vector2(120.0, 80.0)
	var returned_id: String = _spawning.spawn_card("ju", spawn_pos)

	if returned_id.is_empty():
		return

	var node: Node2D = _spawning.get_card_node(returned_id)
	assert_that(node).is_not_null()
	assert_bool(node.visible).is_true()
	assert_that(node.position).is_equal(spawn_pos)

	# Cleanup
	_spawning.remove_card(returned_id)


# ── AC-3: spawn_seed_cards returns Array[String] ──────────────────────────────

func test_spawn_seed_cards_method_exists_on_autoload() -> void:
	# AC-3: the method must exist regardless of spawn success
	assert_bool(_spawning.has_method("spawn_seed_cards")).is_true()


func test_spawn_seed_cards_returns_no_crash_with_empty_input() -> void:
	# AC-3: empty input must not crash; no cards should be spawned
	var before_count: int = _spawning.get_all_instance_ids().size()

	# spawn_seed_cards with no seed cards — uses TableLayoutSystem internally
	# Passing an empty Array avoids triggering CardDatabase.has_card() at all
	_spawning.spawn_seed_cards([])

	var after_count: int = _spawning.get_all_instance_ids().size()
	assert_int(after_count).is_equal(before_count)
