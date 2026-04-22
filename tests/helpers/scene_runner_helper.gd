## Utilities for scene-based integration tests.
## Wraps gdUnit4 GdUnitTestSuite with Moments-specific patterns.
##
## Subclass this instead of GdUnitTestSuite for tests that need autoloads
## or the gameplay scene tree.
class_name SceneRunnerHelper
extends GdUnitTestSuite


# --- Lifecycle ----------------------------------------------------------------

var _spawned_nodes: Array[Node] = []


func after_test() -> void:
	for node: Node in _spawned_nodes:
		if is_instance_valid(node) and node.is_inside_tree():
			node.queue_free()
	_spawned_nodes.clear()


# --- Node Management ---------------------------------------------------------

func add_test_node(node: Node) -> Node:
	add_child(node)
	_spawned_nodes.append(node)
	return node


func add_test_card(card_id: String = "test-card-001", position: Vector2 = Vector2.ZERO) -> Node2D:
	var card := GameFactory.make_card_node(card_id, position)
	return add_test_node(card) as Node2D


# --- Scene Loading ------------------------------------------------------------

func load_scene_and_wait(scene_path: String) -> Node:
	var packed: PackedScene = load(scene_path) as PackedScene
	assert(packed != null, "Failed to load scene: %s" % scene_path)
	var instance: Node = packed.instantiate()
	add_child(instance)
	_spawned_nodes.append(instance)
	await get_tree().process_frame
	return instance


# --- Signal Waiting -----------------------------------------------------------

func wait_for_signal_on(
	source: Object,
	signal_name: String,
	timeout_sec: float = 2.0
) -> Array:
	var result: Array = []
	var received := false

	var handler := func(a = null, b = null, c = null, d = null, e = null, f = null) -> void:
		result = [a, b, c, d, e, f].filter(func(v): return v != null)
		received = true

	source.connect(signal_name, handler, CONNECT_ONE_SHOT)

	var elapsed := 0.0
	while not received and elapsed < timeout_sec:
		await get_tree().process_frame
		elapsed += get_process_delta_time()

	assert(received, "Timed out (%.1fs) waiting for signal '%s'" % [timeout_sec, signal_name])
	return result


# --- Card Interaction Simulation ----------------------------------------------

func simulate_drag_start(card_node: Node2D) -> void:
	var card_id: String = card_node.get_meta("card_id", "unknown")
	EventBus.drag_started.emit(card_id, card_node.position)
	await get_tree().process_frame


func simulate_drag_move(card_node: Node2D, target_pos: Vector2) -> void:
	var card_id: String = card_node.get_meta("card_id", "unknown")
	var delta := target_pos - card_node.position
	card_node.position = target_pos
	EventBus.drag_moved.emit(card_id, target_pos, delta)
	await get_tree().process_frame


func simulate_drag_release(card_node: Node2D) -> void:
	var card_id: String = card_node.get_meta("card_id", "unknown")
	EventBus.drag_released.emit(card_id, card_node.position)
	await get_tree().process_frame


func simulate_snap(card_a: Node2D, card_b: Node2D) -> void:
	var id_a: String = card_a.get_meta("card_id", "unknown")
	var id_b: String = card_b.get_meta("card_id", "unknown")
	await simulate_drag_start(card_a)
	await simulate_drag_move(card_a, card_b.position)
	EventBus.proximity_entered.emit(id_a, id_b)
	await get_tree().process_frame
	await simulate_drag_release(card_a)


# --- Combination Simulation ---------------------------------------------------

func simulate_combination_executed(
	recipe_id: String,
	template: String = "Additive",
	instance_a: String = "inst_a",
	instance_b: String = "inst_b",
	card_id_a: String = "test-card-001",
	card_id_b: String = "test-card-002"
) -> void:
	EventBus.combination_executed.emit(
		recipe_id, template, instance_a, instance_b, card_id_a, card_id_b
	)
	await get_tree().process_frame


# --- Frame Helpers ------------------------------------------------------------

func advance_frames(count: int = 1) -> void:
	for i: int in range(count):
		await get_tree().process_frame


func advance_seconds(seconds: float) -> void:
	var frames := int(seconds * 60.0)
	for i: int in range(frames):
		await get_tree().process_frame
