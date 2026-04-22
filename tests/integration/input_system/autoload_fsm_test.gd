## Integration test for InputSystem autoload — Story 001.
##
## Covers the 5 QA test cases from the story:
##   AC-1: InputSystem is autoload #4 in project.godot (after RecipeDatabase)
##   AC-2: process_mode is PROCESS_MODE_ALWAYS
##   AC-3: default FSM state is State.IDLE
##   AC-4: _screen_to_world() — no camera returns screen_pos; with camera applies transform
##   AC-5: right-click leaves state IDLE, emits no signals on EventBus
extends GdUnitTestSuite

# InputSystem's autoload name occupies the global identifier, so the script
# does not declare a class_name. Preload the script to instantiate test copies.
const InputSystemScript := preload("res://src/core/input_system.gd")


# ── AC-1: Autoload position #4 ────────────────────────────────────────────────

func test_input_system_is_fourth_autoload_in_project_godot() -> void:
	# Arrange
	var file := FileAccess.open("res://project.godot", FileAccess.READ)
	assert_that(file).is_not_null()
	var content := file.get_as_text()
	file.close()

	# Act — collect all autoload keys in order
	var in_autoload := false
	var autoload_keys: Array[String] = []
	for line: String in content.split("\n"):
		if line.strip_edges() == "[autoload]":
			in_autoload = true
			continue
		if in_autoload and line.begins_with("["):
			break
		if in_autoload and "=" in line and not line.strip_edges().is_empty():
			autoload_keys.append(line.split("=")[0].strip_edges())

	# Assert — must have at least 4 entries and index 3 must be InputSystem
	assert_int(autoload_keys.size()) \
		.override_failure_message("project.godot has fewer than 4 autoload entries") \
		.is_greater_equal(4)
	assert_str(autoload_keys[3]) \
		.override_failure_message(
			"Expected InputSystem at position #4, got: %s" % autoload_keys[3]
		) \
		.is_equal("InputSystem")


func test_input_system_is_after_recipe_database_in_autoload_list() -> void:
	# Arrange
	var file := FileAccess.open("res://project.godot", FileAccess.READ)
	var content := file.get_as_text()
	file.close()

	var in_autoload := false
	var autoload_keys: Array[String] = []
	for line: String in content.split("\n"):
		if line.strip_edges() == "[autoload]":
			in_autoload = true
			continue
		if in_autoload and line.begins_with("["):
			break
		if in_autoload and "=" in line and not line.strip_edges().is_empty():
			autoload_keys.append(line.split("=")[0].strip_edges())

	# Act
	var recipe_idx: int = autoload_keys.find("RecipeDatabase")
	var input_idx: int = autoload_keys.find("InputSystem")

	# Assert
	assert_int(recipe_idx) \
		.override_failure_message("RecipeDatabase not found in autoload list") \
		.is_not_equal(-1)
	assert_int(input_idx) \
		.override_failure_message("InputSystem not found in autoload list") \
		.is_not_equal(-1)
	assert_bool(input_idx == recipe_idx + 1) \
		.override_failure_message(
			"InputSystem (%d) must immediately follow RecipeDatabase (%d)" % [input_idx, recipe_idx]
		) \
		.is_true()


# ── AC-2: process_mode ────────────────────────────────────────────────────────

func test_input_system_process_mode_is_always() -> void:
	# Act / Assert
	assert_int(InputSystem.process_mode) \
		.override_failure_message("InputSystem.process_mode must be PROCESS_MODE_ALWAYS") \
		.is_equal(Node.PROCESS_MODE_ALWAYS)


func test_input_system_is_accessible_at_root() -> void:
	# Act
	var node := get_node_or_null("/root/InputSystem")

	# Assert
	assert_that(node).is_not_null()
	assert_bool(node == InputSystem).is_true()


# ── AC-3: Default state is IDLE ───────────────────────────────────────────────

func test_input_system_default_state_is_idle() -> void:
	# Act / Assert
	assert_int(InputSystem._state) \
		.override_failure_message("InputSystem._state must default to State.IDLE (0)") \
		.is_equal(InputSystem.State.IDLE)


func test_input_system_state_idle_value_is_zero() -> void:
	# Confirm enum ordering: IDLE=0, DRAGGING=1 (guards against future reordering)
	assert_int(InputSystem.State.IDLE).is_equal(0)
	assert_int(InputSystem.State.DRAGGING).is_equal(1)


# ── AC-4: Screen→world coordinate conversion ──────────────────────────────────

func test_screen_to_world_returns_screen_pos_when_no_camera() -> void:
	# Arrange — create a bare InputSystem instance outside any scene tree
	# (no Camera2D will exist — get_viewport().get_camera_2d() returns null)
	var sys: Node = InputSystemScript.new()
	add_child(sys)

	# Act
	var input_pos := Vector2(300.0, 400.0)
	var result: Vector2 = sys._screen_to_world(input_pos)

	# Assert — no camera → passthrough
	assert_that(result).is_equal(input_pos)

	# Cleanup
	sys.queue_free()


func test_screen_to_world_applies_camera_transform() -> void:
	# Arrange — set up a sub-scene with a Camera2D
	var scene_root := Node2D.new()
	var camera := Camera2D.new()
	camera.position = Vector2(100.0, 200.0)
	scene_root.add_child(camera)
	camera.make_current()

	var sys: Node = InputSystemScript.new()
	scene_root.add_child(sys)
	add_child(scene_root)

	await get_tree().process_frame  # Let camera register with the viewport

	# Act
	var screen_pos := Vector2(100.0, 200.0)
	var result: Vector2 = sys._screen_to_world(screen_pos)

	# Assert — result must differ from screen_pos (camera offset was applied)
	# We do not assert the exact value because it depends on viewport size,
	# but we verify the transform was applied (result != screen_pos when camera
	# is offset and viewport is non-trivial).
	var active_camera: Camera2D = sys.get_viewport().get_camera_2d()
	assert_that(active_camera).is_not_null()

	# Verify by computing the expected value ourselves
	var expected: Vector2 = active_camera.get_global_transform().affine_inverse() * screen_pos
	assert_that(result).is_equal(expected)

	# Cleanup
	scene_root.queue_free()


# ── AC-5: Right-click ignored ─────────────────────────────────────────────────

func test_right_click_does_not_change_state_from_idle() -> void:
	# Arrange
	var sys: Node = InputSystemScript.new()
	add_child(sys)
	assert_int(sys._state).is_equal(InputSystem.State.IDLE)

	# Act — synthesise a right-click unhandled_input event
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = true
	sys._unhandled_input(event)

	# Assert — state unchanged
	assert_int(sys._state) \
		.override_failure_message("Right-click must not change FSM state from IDLE") \
		.is_equal(InputSystem.State.IDLE)

	# Cleanup
	sys.queue_free()


func test_right_click_does_not_emit_any_eventbus_signals() -> void:
	# Arrange
	var drag_started_called := false
	var drag_released_called := false

	var on_drag_started := func(_id: String, _pos: Vector2) -> void:
		drag_started_called = true
	var on_drag_released := func(_id: String, _pos: Vector2) -> void:
		drag_released_called = true

	EventBus.drag_started.connect(on_drag_started)
	EventBus.drag_released.connect(on_drag_released)

	var sys: Node = InputSystemScript.new()
	add_child(sys)

	# Act
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = true
	sys._unhandled_input(event)

	# Assert
	assert_bool(drag_started_called) \
		.override_failure_message("drag_started must not fire on right-click") \
		.is_false()
	assert_bool(drag_released_called) \
		.override_failure_message("drag_released must not fire on right-click") \
		.is_false()

	# Cleanup
	EventBus.drag_started.disconnect(on_drag_started)
	EventBus.drag_released.disconnect(on_drag_released)
	sys.queue_free()
