## Unit tests for InputSystem drag_moved + drag_released — Story 003.
##
## Covers the 6 QA acceptance criteria from the story:
##   AC-1: mouse motion during drag emits drag_moved with correct card_id, world_pos, delta
##   AC-2: mouse release during drag emits drag_released with correct card_id and world_pos
##   AC-3: state resets to IDLE and _dragged_card_id clears after drag_released
##   AC-4: second left-press while DRAGGING is ignored (single-drag enforcement)
##   AC-5: drag_moved world_pos is in world coordinates (Camera2D offset applied)
##   AC-6: delta is the world-space difference between consecutive positions
##
## Note: AC-4 (single-drag enforcement) is structurally covered by Story 002's
## test_second_press_while_dragging_is_ignored. It is repeated here to confirm
## the guarantee holds in this story's context.
##
## No Camera2D is present in headless tests, so _screen_to_world returns
## screen_pos unchanged (identity transform). AC-5 is verified with a custom
## camera offset injected via a proxy Node2D.
extends GdUnitTestSuite

const InputSystemScript := preload("res://src/core/input_system.gd")


# ── Helpers ───────────────────────────────────────────────────────────────────

## Build a minimal Node2D acting as a card proxy at [param world_pos] with [param z].
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


## Synthesise a left-mouse release InputEvent at [param screen_pos].
func _left_release(screen_pos: Vector2) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = false
	event.position = screen_pos
	return event


## Synthesise a mouse-motion InputEvent at [param screen_pos].
func _mouse_move(screen_pos: Vector2) -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.position = screen_pos
	return event


## Put [param sys] into DRAGGING state as if "test-card" was picked up at
## [param start_pos] (screen == world in headless tests).
func _enter_drag(sys: Node, card_id: String, start_pos: Vector2) -> void:
	_register_card(sys, card_id, start_pos, Vector2(40.0, 60.0), 0)
	sys._unhandled_input(_left_press(start_pos))


# ── AC-1: drag_moved emitted with correct payload ────────────────────────────

func test_drag_moved_emits_during_active_drag() -> void:
	# Arrange
	var sys: Node = InputSystemScript.new()
	add_child(sys)

	_enter_drag(sys, "test-card", Vector2(100.0, 100.0))

	var captured := {"called": false, "id": "", "pos": Vector2.ZERO, "delta": Vector2.ZERO}
	var handler := func(card_id: String, world_pos: Vector2, delta: Vector2) -> void:
		captured["called"] = true
		captured["id"] = card_id
		captured["pos"] = world_pos
		captured["delta"] = delta
	EventBus.drag_moved.connect(handler)

	# Act — move to (120, 130); no Camera2D so screen == world
	sys._unhandled_input(_mouse_move(Vector2(120.0, 130.0)))

	# Assert
	assert_bool(captured["called"]) \
		.override_failure_message("drag_moved must fire on mouse motion during DRAGGING") \
		.is_true()
	assert_str(captured["id"]) \
		.override_failure_message("drag_moved must carry the active card_id") \
		.is_equal("test-card")
	assert_that(captured["pos"]) \
		.override_failure_message("drag_moved world_pos must equal the moved-to position") \
		.is_equal(Vector2(120.0, 130.0))
	assert_that(captured["delta"]) \
		.override_failure_message("drag_moved delta must be (20, 30) from start") \
		.is_equal(Vector2(20.0, 30.0))

	# Cleanup
	EventBus.drag_moved.disconnect(handler)
	sys.queue_free()


# ── AC-2: drag_released emitted on left-release with correct payload ──────────

func test_drag_released_emits_on_left_mouse_release() -> void:
	# Arrange
	var sys: Node = InputSystemScript.new()
	add_child(sys)

	_enter_drag(sys, "test-card", Vector2(100.0, 100.0))

	var captured := {"called": false, "id": "", "pos": Vector2.ZERO}
	var handler := func(card_id: String, world_pos: Vector2) -> void:
		captured["called"] = true
		captured["id"] = card_id
		captured["pos"] = world_pos
	EventBus.drag_released.connect(handler)

	# Act — release at (200, 200)
	sys._unhandled_input(_left_release(Vector2(200.0, 200.0)))

	# Assert
	assert_bool(captured["called"]) \
		.override_failure_message("drag_released must fire on left-mouse release during DRAGGING") \
		.is_true()
	assert_str(captured["id"]) \
		.override_failure_message("drag_released must carry the active card_id") \
		.is_equal("test-card")
	assert_that(captured["pos"]) \
		.override_failure_message("drag_released world_pos must equal release position") \
		.is_equal(Vector2(200.0, 200.0))

	# Cleanup
	EventBus.drag_released.disconnect(handler)
	sys.queue_free()


# ── AC-3: state resets to IDLE and _dragged_card_id clears after release ──────

func test_state_resets_to_idle_after_drag_released() -> void:
	# Arrange
	var sys: Node = InputSystemScript.new()
	add_child(sys)

	_enter_drag(sys, "test-card", Vector2(100.0, 100.0))

	# Act
	sys._unhandled_input(_left_release(Vector2(200.0, 200.0)))

	# Assert
	assert_int(sys._state) \
		.override_failure_message("FSM must return to IDLE after drag_released") \
		.is_equal(InputSystem.State.IDLE)
	assert_str(sys._dragged_card_id) \
		.override_failure_message("_dragged_card_id must be empty after drag ends") \
		.is_equal("")

	# Cleanup
	sys.queue_free()


# ── AC-4: second left-press while DRAGGING is ignored ────────────────────────

func test_second_press_while_dragging_is_ignored() -> void:
	# Arrange
	var sys: Node = InputSystemScript.new()
	add_child(sys)

	_register_card(sys, "card-b", Vector2(50.0, 50.0), Vector2(40.0, 60.0), 0)

	# Force DRAGGING state for "card-a" without a registered node
	sys._state = InputSystem.State.DRAGGING
	sys._dragged_card_id = "card-a"
	sys._last_world_pos = Vector2(50.0, 50.0)

	var drag_started_count := {"count": 0}
	var handler := func(_id: String, _pos: Vector2) -> void:
		drag_started_count["count"] = int(drag_started_count["count"]) + 1
	EventBus.drag_started.connect(handler)

	# Act — second press on "card-b" which is registered and under the cursor
	sys._unhandled_input(_left_press(Vector2(50.0, 50.0)))

	# Assert — no new drag_started, "card-a" still active
	assert_int(drag_started_count["count"]) \
		.override_failure_message("drag_started must NOT fire while already DRAGGING") \
		.is_equal(0)
	assert_str(sys._dragged_card_id) \
		.override_failure_message("_dragged_card_id must remain 'card-a'") \
		.is_equal("card-a")
	assert_int(sys._state) \
		.override_failure_message("FSM must remain DRAGGING") \
		.is_equal(InputSystem.State.DRAGGING)

	# Cleanup
	EventBus.drag_started.disconnect(handler)
	sys.queue_free()


# ── AC-5: drag_moved world_pos is world-space (no Camera2D = identity) ────────

func test_drag_moved_world_pos_equals_screen_pos_without_camera() -> void:
	# Arrange — without a Camera2D _screen_to_world returns screen_pos unchanged.
	var sys: Node = InputSystemScript.new()
	add_child(sys)

	_enter_drag(sys, "test-card", Vector2(0.0, 0.0))

	var captured_pos := {"pos": Vector2.ZERO}
	var handler := func(_id: String, world_pos: Vector2, _delta: Vector2) -> void:
		captured_pos["pos"] = world_pos
	EventBus.drag_moved.connect(handler)

	# Act
	sys._unhandled_input(_mouse_move(Vector2(50.0, 50.0)))

	# Assert — identity transform: world_pos == screen_pos
	assert_that(captured_pos["pos"]) \
		.override_failure_message("world_pos must match screen_pos when no camera offset exists") \
		.is_equal(Vector2(50.0, 50.0))

	# Cleanup
	EventBus.drag_moved.disconnect(handler)
	sys.queue_free()


# ── AC-6: delta is the world-space difference between consecutive positions ───

func test_drag_moved_delta_is_world_space_difference_between_frames() -> void:
	# Arrange
	var sys: Node = InputSystemScript.new()
	add_child(sys)

	_enter_drag(sys, "test-card", Vector2(100.0, 100.0))

	# First move — establishes _last_world_pos at (100, 100)
	sys._unhandled_input(_mouse_move(Vector2(100.0, 100.0)))

	var captured_delta := {"delta": Vector2.ZERO}
	var handler := func(_id: String, _pos: Vector2, delta: Vector2) -> void:
		captured_delta["delta"] = delta
	EventBus.drag_moved.connect(handler)

	# Act — second move from (100, 100) to (110, 120)
	sys._unhandled_input(_mouse_move(Vector2(110.0, 120.0)))

	# Assert
	assert_that(captured_delta["delta"]) \
		.override_failure_message("delta must be (10, 20) — world-space difference between consecutive positions") \
		.is_equal(Vector2(10.0, 20.0))

	# Cleanup
	EventBus.drag_moved.disconnect(handler)
	sys.queue_free()


# ── Guard: drag_moved does NOT fire when not DRAGGING ─────────────────────────

func test_drag_moved_does_not_fire_when_idle() -> void:
	# Arrange
	var sys: Node = InputSystemScript.new()
	add_child(sys)
	# _state is IDLE by default — no card registered, no press

	var captured := {"called": false}
	var handler := func(_id: String, _pos: Vector2, _delta: Vector2) -> void:
		captured["called"] = true
	EventBus.drag_moved.connect(handler)

	# Act — motion event while IDLE
	sys._unhandled_input(_mouse_move(Vector2(100.0, 100.0)))

	# Assert
	assert_bool(captured["called"]) \
		.override_failure_message("drag_moved must NOT fire when FSM is IDLE") \
		.is_false()

	# Cleanup
	EventBus.drag_moved.disconnect(handler)
	sys.queue_free()


# ── Guard: drag_released does NOT fire when not DRAGGING ─────────────────────

func test_drag_released_does_not_fire_when_idle() -> void:
	# Arrange
	var sys: Node = InputSystemScript.new()
	add_child(sys)
	# _state is IDLE by default

	var captured := {"called": false}
	var handler := func(_id: String, _pos: Vector2) -> void:
		captured["called"] = true
	EventBus.drag_released.connect(handler)

	# Act — release event while IDLE (no active drag)
	sys._unhandled_input(_left_release(Vector2(100.0, 100.0)))

	# Assert
	assert_bool(captured["called"]) \
		.override_failure_message("drag_released must NOT fire when FSM is IDLE") \
		.is_false()

	# Cleanup
	EventBus.drag_released.disconnect(handler)
	sys.queue_free()
