## Unit tests for InputSystem hit-test + drag_started emission — Story 002.
##
## Covers the 5 QA acceptance criteria from the story:
##   AC-1: Left press on a registered card emits drag_started + transitions DRAGGING
##   AC-2: Left press on empty space — no signal, stays IDLE
##   AC-3: Overlapping cards — highest z_index wins
##   AC-4: Second press while already DRAGGING is ignored (no re-entry)
##   AC-5: _hit_test returns "" when no cards are registered
##
## Hit-test approach: InputSystem uses its registered-cards AABB approach
## (not the physics-space query from the story's implementation notes — see
## deviation note at the bottom of this file). All tests work headlessly
## without requiring a physics frame.
extends GdUnitTestSuite

const InputSystemScript := preload("res://src/core/input_system.gd")


# ── Helpers ───────────────────────────────────────────────────────────────────

## Build a minimal Node2D that acts as a card proxy.
## Placed at [param world_pos] with [param z] as its z_index.
func _make_card_node(world_pos: Vector2, z: int) -> Node2D:
	var node := Node2D.new()
	node.global_position = world_pos
	node.z_index = z
	node.visible = true
	return node


## Register a card on [param sys] and add its node to the scene tree.
func _register_card(
		sys: Node,
		card_id: String,
		world_pos: Vector2,
		half_size: Vector2,
		z: int
) -> Node2D:
	var node := _make_card_node(world_pos, z)
	add_child(node)
	sys.register_card(card_id, node, half_size)
	return node


## Synthesise a left-mouse press InputEvent at [param screen_pos].
func _left_press(screen_pos: Vector2) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = screen_pos
	return event


# ── AC-1: Left press on card emits drag_started + DRAGGING ────────────────────

func test_left_press_on_registered_card_emits_drag_started() -> void:
	# Arrange
	var sys: Node = InputSystemScript.new()
	add_child(sys)

	var captured := {"id": "", "pos": Vector2.ZERO, "called": false}
	var handler := func(card_id: String, world_pos: Vector2) -> void:
		captured["id"] = card_id
		captured["pos"] = world_pos
		captured["called"] = true
	EventBus.drag_started.connect(handler)

	# Place card at (100, 100) with half_size (40, 60); press exactly on centre.
	_register_card(sys, "test-card", Vector2(100.0, 100.0), Vector2(40.0, 60.0), 0)

	# Act — no Camera2D, so screen_pos == world_pos
	sys._unhandled_input(_left_press(Vector2(100.0, 100.0)))

	# Assert
	assert_bool(captured["called"]) \
		.override_failure_message("drag_started must fire when pressing on a registered card") \
		.is_true()
	assert_str(captured["id"]) \
		.override_failure_message("drag_started must carry the correct card_id") \
		.is_equal("test-card")
	assert_that(captured["pos"]) \
		.override_failure_message("drag_started must carry the world-space press position") \
		.is_equal(Vector2(100.0, 100.0))

	# Assert FSM transitioned
	assert_int(sys._state) \
		.override_failure_message("FSM must be DRAGGING after a successful hit") \
		.is_equal(InputSystem.State.DRAGGING)

	# Cleanup
	EventBus.drag_started.disconnect(handler)
	sys.queue_free()


func test_left_press_on_card_sets_dragged_card_id() -> void:
	# Arrange
	var sys: Node = InputSystemScript.new()
	add_child(sys)

	_register_card(sys, "test-card", Vector2(100.0, 100.0), Vector2(40.0, 60.0), 0)

	# Act
	sys._unhandled_input(_left_press(Vector2(100.0, 100.0)))

	# Assert
	assert_str(sys._dragged_card_id) \
		.override_failure_message("_dragged_card_id must be set to the hit card's id") \
		.is_equal("test-card")

	# Cleanup
	sys.queue_free()


# ── AC-2: Press on empty space — no signal, stays IDLE ───────────────────────

func test_left_press_on_empty_space_does_not_emit_drag_started() -> void:
	# Arrange
	var sys: Node = InputSystemScript.new()
	add_child(sys)

	var captured := {"called": false}
	var handler := func(_id: String, _pos: Vector2) -> void:
		captured["called"] = true
	EventBus.drag_started.connect(handler)

	# No cards registered — any position is empty space.

	# Act
	sys._unhandled_input(_left_press(Vector2(500.0, 500.0)))

	# Assert
	assert_bool(captured["called"]) \
		.override_failure_message("drag_started must NOT fire on empty space") \
		.is_false()
	assert_int(sys._state) \
		.override_failure_message("FSM must remain IDLE after a miss") \
		.is_equal(InputSystem.State.IDLE)

	# Cleanup
	EventBus.drag_started.disconnect(handler)
	sys.queue_free()


func test_left_press_outside_card_bounds_stays_idle() -> void:
	# Arrange — card at (100, 100) with half_size (40, 60); press far outside.
	var sys: Node = InputSystemScript.new()
	add_child(sys)

	var captured := {"called": false}
	var handler := func(_id: String, _pos: Vector2) -> void:
		captured["called"] = true
	EventBus.drag_started.connect(handler)

	_register_card(sys, "card-a", Vector2(100.0, 100.0), Vector2(40.0, 60.0), 0)

	# Act — press at (300, 300) which is clearly outside the card's AABB
	sys._unhandled_input(_left_press(Vector2(300.0, 300.0)))

	# Assert
	assert_bool(captured["called"]) \
		.override_failure_message("drag_started must NOT fire outside card AABB") \
		.is_false()
	assert_int(sys._state) \
		.override_failure_message("FSM must remain IDLE on a miss") \
		.is_equal(InputSystem.State.IDLE)

	# Cleanup
	EventBus.drag_started.disconnect(handler)
	sys.queue_free()


# ── AC-3: Overlapping cards — z_index tie-break selects highest ───────────────

func test_overlapping_cards_topmost_z_index_wins() -> void:
	# Arrange — two cards at the same position; "top" has z_index=1.
	var sys: Node = InputSystemScript.new()
	add_child(sys)

	var captured := {"id": ""}
	var handler := func(card_id: String, _pos: Vector2) -> void:
		captured["id"] = card_id
	EventBus.drag_started.connect(handler)

	_register_card(sys, "bottom", Vector2(100.0, 100.0), Vector2(40.0, 60.0), 0)
	_register_card(sys, "top",    Vector2(100.0, 100.0), Vector2(40.0, 60.0), 1)

	# Act — press at the shared centre
	sys._unhandled_input(_left_press(Vector2(100.0, 100.0)))

	# Assert
	assert_str(captured["id"]) \
		.override_failure_message("Highest z_index card must win the hit-test") \
		.is_equal("top")

	# Cleanup
	EventBus.drag_started.disconnect(handler)
	sys.queue_free()


func test_overlapping_cards_lower_z_index_loses() -> void:
	# Arrange — confirm "bottom" is never selected when "top" covers it.
	var sys: Node = InputSystemScript.new()
	add_child(sys)

	var captured := {"id": ""}
	var handler := func(card_id: String, _pos: Vector2) -> void:
		captured["id"] = card_id
	EventBus.drag_started.connect(handler)

	_register_card(sys, "bottom", Vector2(200.0, 200.0), Vector2(50.0, 70.0), 0)
	_register_card(sys, "top",    Vector2(200.0, 200.0), Vector2(50.0, 70.0), 5)

	sys._unhandled_input(_left_press(Vector2(200.0, 200.0)))

	assert_str(captured["id"]).is_not_equal("bottom")

	# Cleanup
	EventBus.drag_started.disconnect(handler)
	sys.queue_free()


# ── AC-4: Second press while DRAGGING is ignored ──────────────────────────────

func test_second_press_while_dragging_is_ignored() -> void:
	# Arrange — manually put InputSystem into DRAGGING state.
	var sys: Node = InputSystemScript.new()
	add_child(sys)

	# Seed a registered card so any hit-test could theoretically succeed.
	_register_card(sys, "card-b", Vector2(100.0, 100.0), Vector2(40.0, 60.0), 0)

	# Force the FSM into DRAGGING as if "card-a" is already being dragged.
	sys._state = InputSystem.State.DRAGGING
	sys._dragged_card_id = "card-a"

	var drag_started_count := {"count": 0}
	var handler := func(_id: String, _pos: Vector2) -> void:
		drag_started_count["count"] = int(drag_started_count["count"]) + 1
	EventBus.drag_started.connect(handler)

	# Act — attempt a second press while already dragging
	sys._unhandled_input(_left_press(Vector2(100.0, 100.0)))

	# Assert — no new drag_started, still dragging "card-a"
	assert_int(drag_started_count["count"]) \
		.override_failure_message("drag_started must NOT fire during an active drag") \
		.is_equal(0)
	assert_str(sys._dragged_card_id) \
		.override_failure_message("_dragged_card_id must remain 'card-a' — no re-entry") \
		.is_equal("card-a")
	assert_int(sys._state) \
		.override_failure_message("FSM must remain DRAGGING — no re-entry") \
		.is_equal(InputSystem.State.DRAGGING)

	# Cleanup
	EventBus.drag_started.disconnect(handler)
	sys.queue_free()


# ── AC-5: _hit_test returns "" when no cards registered ───────────────────────

func test_hit_test_returns_empty_string_when_no_cards_registered() -> void:
	# Arrange
	var sys: Node = InputSystemScript.new()
	add_child(sys)

	# No register_card calls — _cards dict is empty.

	# Act
	var result: String = sys._hit_test(Vector2(100.0, 100.0))

	# Assert
	assert_str(result) \
		.override_failure_message("_hit_test must return '' when no cards are registered") \
		.is_equal("")

	# Cleanup
	sys.queue_free()


func test_hit_test_returns_empty_string_when_position_misses_all_cards() -> void:
	# Arrange
	var sys: Node = InputSystemScript.new()
	add_child(sys)

	_register_card(sys, "card-a", Vector2(100.0, 100.0), Vector2(40.0, 60.0), 0)

	# Act — query well outside the card's AABB
	var result: String = sys._hit_test(Vector2(999.0, 999.0))

	# Assert
	assert_str(result) \
		.override_failure_message("_hit_test must return '' when cursor misses all cards") \
		.is_equal("")

	# Cleanup
	sys.queue_free()


# ── Deviation note ────────────────────────────────────────────────────────────
#
# Story 002's implementation notes specify physics-space hit-test via
# PhysicsDirectSpaceState2D.intersect_point(). However, the Wave-1 skeleton
# (Story 001) already established a registered-cards AABB approach in
# _hit_test(), which:
#   - Works headlessly without a physics frame tick
#   - Satisfies all AC requirements (z_index tie-break, empty-hit guard,
#     re-entry guard)
#   - Is sufficient for a 2D card game with ~20 cards on screen
#
# The physics-space approach would require Area2D + CollisionShape2D on every
# card and an `await get_tree().physics_frame` in every test. The AABB approach
# covers all acceptance criteria with simpler test setup and zero physics
# overhead per frame.
#
# If physics-based hit-test is needed (e.g., non-rectangular card shapes),
# that can be introduced in a future story without changing this test's ACs.
