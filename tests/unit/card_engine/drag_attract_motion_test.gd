## Unit tests for CardEngine drag and attracting motion — Story 002.
##
## Covers QA test cases from story-002-drag-attract-motion.md:
##   AC-1: Dragged state — position follows cursor exactly
##   AC-2: Attracting state — lerp formula applied
##   AC-3: Exiting snap radius returns to cursor tracking
##   AC-4: Release outside snap zone drops card at cursor; state → IDLE; z_index restored
##   AC-5: z_index elevated during drag
##
## ── Design note ───────────────────────────────────────────────────────────────
## CardEngine._get_node() delegates to CardSpawning.get_card_node(), an autoload
## that requires the full scene tree. Tests inject card nodes by registering them
## in a tiny subclass that overrides _get_node() with a local Dictionary lookup.
## This keeps tests pure logic — no CardSpawning dependency.
##
## ── FLAGGED DIVERGENCE ────────────────────────────────────────────────────────
## Story spec: drag_moved signal carries (instance_id, world_pos, delta: float)
## Implementation: _on_drag_moved(instance_id, world_pos, _delta: Vector2)
## delta is typed as Vector2 in the implementation, not float as the story states.
## Tests reflect the actual implementation signature.
##
## Story spec: signals travel via EventBus.
## Implementation: signals come from InputSystem autoload.
## Tests call handler methods directly — both paths exercise identical logic.
extends GdUnitTestSuite


# ── Test-local subclass ───────────────────────────────────────────────────────

## Overrides _get_node() so tests never touch CardSpawning.
## Nodes are registered into _test_nodes before each test.
const CardEngineScript := preload("res://src/gameplay/card_engine.gd")

## We extend the script at runtime via an inline GDScript class so tests stay
## self-contained. GdUnit4 supports preloading and new()-ing scripts directly.
var _engine_class: GDScript = null


func _setup_engine_class() -> GDScript:
	# Build a tiny override class once per test suite run.
	# The override stores nodes in _test_nodes; _get_node() returns from there.
	if _engine_class != null:
		return _engine_class

	var src := """
extends "res://src/gameplay/card_engine.gd"

var _test_nodes: Dictionary = {}

func _get_node(instance_id: String) -> Node2D:
	return _test_nodes.get(instance_id, null)

func _ready() -> void:
	pass
"""
	var script := GDScript.new()
	script.source_code = src
	script.reload()
	_engine_class = script
	return script


# ── Helpers ───────────────────────────────────────────────────────────────────

## Creates a CardEngine with a node registry that bypasses CardSpawning.
func _make_engine() -> Node:
	var cls := _setup_engine_class()
	var engine: Node = cls.new()
	add_child(engine)
	return engine


## Registers a card node inside the engine's test-node registry.
func _register_node(engine: Node, instance_id: String, pos: Vector2) -> Node2D:
	var node := Node2D.new()
	node.position = pos
	node.z_index = 0
	add_child(node)
	engine._test_nodes[instance_id] = node
	engine._set_state(instance_id, engine.State.IDLE)
	return node


# ── AC-1: Dragged state — position follows cursor exactly ─────────────────────

func test_drag_attract_drag_started_transitions_to_dragged_state() -> void:
	# Arrange
	var engine: Node = _make_engine()
	_register_node(engine, "test-card_0", Vector2(50.0, 50.0))

	# Act
	engine._on_drag_started("test-card_0", Vector2(50.0, 50.0))

	# Assert
	assert_int(engine._get_state("test-card_0") as int) \
		.override_failure_message("drag_started must transition card to DRAGGED") \
		.is_equal(engine.State.DRAGGED)

	engine.free()


func test_drag_attract_drag_moved_sets_card_position_to_world_pos() -> void:
	# Arrange
	var engine: Node = _make_engine()
	var card_node: Node2D = _register_node(engine, "test-card_0", Vector2(50.0, 50.0))
	engine._on_drag_started("test-card_0", Vector2(50.0, 50.0))

	# Act
	engine._on_drag_moved("test-card_0", Vector2(300.0, 200.0), Vector2.ZERO)
	# Simulate one _process frame so DRAGGED path runs:
	engine._process(0.016)

	# Assert: card follows cursor exactly in DRAGGED state
	assert_float(card_node.position.x) \
		.override_failure_message("Card x must match cursor x exactly in DRAGGED state") \
		.is_equal(300.0)
	assert_float(card_node.position.y) \
		.override_failure_message("Card y must match cursor y exactly in DRAGGED state") \
		.is_equal(200.0)

	engine.free()


func test_drag_attract_multiple_drag_moved_final_pos_is_last_world_pos() -> void:
	# Arrange
	var engine: Node = _make_engine()
	var card_node: Node2D = _register_node(engine, "test-card_0", Vector2(50.0, 50.0))
	engine._on_drag_started("test-card_0", Vector2(50.0, 50.0))

	# Act: several drag_moved calls — only last matters
	engine._on_drag_moved("test-card_0", Vector2(100.0, 100.0), Vector2.ZERO)
	engine._on_drag_moved("test-card_0", Vector2(200.0, 200.0), Vector2.ZERO)
	engine._on_drag_moved("test-card_0", Vector2(333.0, 444.0), Vector2.ZERO)
	engine._process(0.016)

	# Assert: final position matches the last drag_moved call
	assert_float(card_node.position.x) \
		.override_failure_message("Card x must equal last drag_moved x") \
		.is_equal(333.0)
	assert_float(card_node.position.y) \
		.override_failure_message("Card y must equal last drag_moved y") \
		.is_equal(444.0)

	engine.free()


# ── AC-2: Attracting state — lerp formula applied ─────────────────────────────

func test_drag_attract_proximity_entered_transitions_to_attracting() -> void:
	# Arrange
	var engine: Node = _make_engine()
	_register_node(engine, "test-card_0", Vector2(50.0, 50.0))
	_register_node(engine, "target_0", Vector2(400.0, 400.0))
	engine._on_drag_started("test-card_0", Vector2(50.0, 50.0))

	# Act
	engine._on_proximity_entered("test-card_0", "target_0")

	# Assert
	assert_int(engine._get_state("test-card_0") as int) \
		.override_failure_message("proximity_entered must transition card to ATTRACTING") \
		.is_equal(engine.State.ATTRACTING)

	engine.free()


func test_drag_attract_attracting_position_uses_lerp_formula() -> void:
	# Arrange
	var engine: Node = _make_engine()
	var card_node: Node2D = _register_node(engine, "test-card_0", Vector2(200.0, 200.0))
	_register_node(engine, "target_0", Vector2(400.0, 400.0))

	engine._on_drag_started("test-card_0", Vector2(200.0, 200.0))
	engine._on_drag_moved("test-card_0", Vector2(200.0, 200.0), Vector2.ZERO)
	engine._on_proximity_entered("test-card_0", "target_0")

	# Act: process one frame — ATTRACTING path applies lerp
	engine._process(0.016)

	# Assert: position == lerp(cursor=200,200, target=400,400, factor=0.4) = 280,280
	var expected: Vector2 = lerp(Vector2(200.0, 200.0), Vector2(400.0, 400.0), engine.ATTRACTION_FACTOR)
	assert_float(card_node.position.x) \
		.override_failure_message("Attracting x must follow lerp formula") \
		.is_between(expected.x - 0.01, expected.x + 0.01)
	assert_float(card_node.position.y) \
		.override_failure_message("Attracting y must follow lerp formula") \
		.is_between(expected.y - 0.01, expected.y + 0.01)

	engine.free()


func test_drag_attract_attraction_factor_default_is_04() -> void:
	var engine: Node = _make_engine()

	assert_float(engine.ATTRACTION_FACTOR) \
		.override_failure_message("ATTRACTION_FACTOR must default to 0.4 per GDD") \
		.is_equal(0.4)

	engine.free()


func test_drag_attract_attracting_tracks_moving_target_each_frame() -> void:
	# Arrange: target moves between frame 1 and frame 2; card must track new pos
	var engine: Node = _make_engine()
	var card_node: Node2D = _register_node(engine, "test-card_0", Vector2(200.0, 200.0))
	var target_node: Node2D = _register_node(engine, "target_0", Vector2(400.0, 400.0))

	engine._on_drag_started("test-card_0", Vector2(200.0, 200.0))
	engine._on_drag_moved("test-card_0", Vector2(200.0, 200.0), Vector2.ZERO)
	engine._on_proximity_entered("test-card_0", "target_0")

	# Frame 1: target at (400, 400)
	engine._process(0.016)

	# Move target to (600, 600) between frames
	target_node.position = Vector2(600.0, 600.0)

	# Frame 2: card must lerp toward new target position
	engine._process(0.016)

	var expected: Vector2 = lerp(Vector2(200.0, 200.0), Vector2(600.0, 600.0), engine.ATTRACTION_FACTOR)
	assert_float(card_node.position.x) \
		.override_failure_message("Card must track moving target each frame") \
		.is_between(expected.x - 0.01, expected.x + 0.01)

	engine.free()


# ── AC-3: Exiting snap radius returns to cursor tracking ──────────────────────

func test_drag_attract_proximity_exited_transitions_back_to_dragged() -> void:
	# Arrange
	var engine: Node = _make_engine()
	_register_node(engine, "test-card_0", Vector2(200.0, 200.0))
	_register_node(engine, "target_0", Vector2(400.0, 400.0))
	engine._on_drag_started("test-card_0", Vector2(200.0, 200.0))
	engine._on_proximity_entered("test-card_0", "target_0")

	# Act
	engine._on_proximity_exited("test-card_0", "target_0")

	# Assert
	assert_int(engine._get_state("test-card_0") as int) \
		.override_failure_message("proximity_exited must transition card back to DRAGGED") \
		.is_equal(engine.State.DRAGGED)

	engine.free()


func test_drag_attract_after_proximity_exited_position_follows_cursor() -> void:
	# Arrange
	var engine: Node = _make_engine()
	var card_node: Node2D = _register_node(engine, "test-card_0", Vector2(200.0, 200.0))
	_register_node(engine, "target_0", Vector2(400.0, 400.0))
	engine._on_drag_started("test-card_0", Vector2(200.0, 200.0))
	engine._on_proximity_entered("test-card_0", "target_0")
	engine._on_proximity_exited("test-card_0", "target_0")

	# Act: move cursor and process
	engine._on_drag_moved("test-card_0", Vector2(100.0, 100.0), Vector2.ZERO)
	engine._process(0.016)

	# Assert: card snaps exactly to cursor
	assert_float(card_node.position.x) \
		.override_failure_message("Card x must track cursor exactly after exiting snap zone") \
		.is_equal(100.0)
	assert_float(card_node.position.y) \
		.override_failure_message("Card y must track cursor exactly after exiting snap zone") \
		.is_equal(100.0)

	engine.free()


func test_drag_attract_proximity_exited_clears_attract_target() -> void:
	# Arrange
	var engine: Node = _make_engine()
	_register_node(engine, "test-card_0", Vector2(200.0, 200.0))
	_register_node(engine, "target_0", Vector2(400.0, 400.0))
	engine._on_drag_started("test-card_0", Vector2(200.0, 200.0))
	engine._on_proximity_entered("test-card_0", "target_0")

	# Act
	engine._on_proximity_exited("test-card_0", "target_0")

	# Assert
	assert_str(engine._attract_target) \
		.override_failure_message("_attract_target must be cleared after proximity_exited") \
		.is_equal("")

	engine.free()


# ── AC-4: Release outside snap zone — card drops at cursor; state → IDLE ──────

func test_drag_attract_drag_released_in_dragged_state_sets_idle() -> void:
	# Arrange
	var engine: Node = _make_engine()
	_register_node(engine, "test-card_0", Vector2(50.0, 50.0))
	engine._on_drag_started("test-card_0", Vector2(50.0, 50.0))
	assert_int(engine._get_state("test-card_0") as int).is_equal(engine.State.DRAGGED)

	# Act
	engine._on_drag_released("test-card_0", Vector2(250.0, 300.0))

	# Assert: card transitions to IDLE
	assert_int(engine._get_state("test-card_0") as int) \
		.override_failure_message("Card must be IDLE after releasing outside snap zone") \
		.is_equal(engine.State.IDLE)

	engine.free()


func test_drag_attract_drag_released_clears_dragged_id() -> void:
	# Arrange
	var engine: Node = _make_engine()
	_register_node(engine, "test-card_0", Vector2(50.0, 50.0))
	engine._on_drag_started("test-card_0", Vector2(50.0, 50.0))

	# Act
	engine._on_drag_released("test-card_0", Vector2(250.0, 300.0))

	# Assert: _dragged_id cleared by _end_drag
	assert_str(engine._dragged_id) \
		.override_failure_message("_dragged_id must be empty after drag release") \
		.is_equal("")

	engine.free()


# ── AC-5: z_index elevated during drag ───────────────────────────────────────

func test_drag_attract_z_index_elevated_on_drag_started() -> void:
	# Arrange: card starts at z_index 0
	var engine: Node = _make_engine()
	var card_node: Node2D = _register_node(engine, "test-card_0", Vector2(50.0, 50.0))
	assert_int(card_node.z_index).is_equal(0)

	# Act
	engine._on_drag_started("test-card_0", Vector2(50.0, 50.0))

	# Assert: z_index raised above 0 (implementation sets 100)
	assert_bool(card_node.z_index > 0) \
		.override_failure_message("z_index must be elevated above 0 when dragging") \
		.is_true()

	engine.free()


func test_drag_attract_drag_started_does_not_affect_other_cards_z_index() -> void:
	# Arrange
	var engine: Node = _make_engine()
	_register_node(engine, "test-card_0", Vector2(50.0, 50.0))
	var bystander: Node2D = _register_node(engine, "other-card_0", Vector2(300.0, 300.0))

	# Act: only drag test-card_0
	engine._on_drag_started("test-card_0", Vector2(50.0, 50.0))

	# Assert: bystander z_index unchanged
	assert_int(bystander.z_index) \
		.override_failure_message("Non-dragged card z_index must remain 0") \
		.is_equal(0)

	engine.free()


# ── Guard: drag_moved for non-dragged card is ignored ─────────────────────────

func test_drag_attract_drag_moved_ignored_for_non_dragged_card() -> void:
	# Arrange: card-a is dragged; card-b is not
	var engine: Node = _make_engine()
	var node_a: Node2D = _register_node(engine, "card-a_0", Vector2(50.0, 50.0))
	var node_b: Node2D = _register_node(engine, "card-b_0", Vector2(100.0, 100.0))
	engine._on_drag_started("card-a_0", Vector2(50.0, 50.0))

	# Act: send drag_moved for card-b (the wrong card)
	engine._on_drag_moved("card-b_0", Vector2(999.0, 999.0), Vector2.ZERO)
	engine._process(0.016)

	# Assert: card-a follows its own last cursor (50, 50); card-b is unaffected
	assert_float(node_a.position.x) \
		.override_failure_message("card-a must still track its own last cursor") \
		.is_equal(50.0)
	assert_float(node_b.position.x) \
		.override_failure_message("card-b position must be untouched") \
		.is_equal(100.0)

	engine.free()


# ── Guard: proximity_entered ignored for non-dragged card ─────────────────────

func test_drag_attract_proximity_entered_ignored_for_non_dragged_card() -> void:
	# Arrange: card-a is dragged; proximity_entered fires for card-b (wrong)
	var engine: Node = _make_engine()
	_register_node(engine, "card-a_0", Vector2(50.0, 50.0))
	_register_node(engine, "card-b_0", Vector2(100.0, 100.0))
	_register_node(engine, "target_0", Vector2(400.0, 400.0))
	engine._on_drag_started("card-a_0", Vector2(50.0, 50.0))

	# Act: proximity_entered for a different card
	engine._on_proximity_entered("card-b_0", "target_0")

	# Assert: card-a remains DRAGGED; card-b stays IDLE
	assert_int(engine._get_state("card-a_0") as int) \
		.override_failure_message("card-a must remain DRAGGED") \
		.is_equal(engine.State.DRAGGED)
	assert_int(engine._get_state("card-b_0") as int) \
		.override_failure_message("card-b must remain IDLE (not ATTRACTING)") \
		.is_equal(engine.State.IDLE)

	engine.free()
