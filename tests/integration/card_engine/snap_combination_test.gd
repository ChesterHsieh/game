## Integration tests for CardEngine snap, combination handshake, and push-away — Story 003.
##
## Covers QA test cases from story-003-snap-combination-pushaway.md:
##   AC-1: combination_attempted fires after snap tween completes
##   AC-2: Push-away ends at a new position, not the drag origin; state → IDLE
##   AC-3: Only one combination in-flight at a time (_combination_in_flight guard)
##   AC-4: Snap tween cancelled when target card fires card_removing mid-animation
##   AC-5: drag_started during SNAPPING cancels snap; card → DRAGGED
##
## ── FLAGGED DIVERGENCES ───────────────────────────────────────────────────────
##
## 1. combination_failed / combination_succeeded signals:
##    Story spec: CardEngine connects to EventBus.combination_failed and
##      EventBus.combination_succeeded in _ready() and listens for them.
##    Implementation: on_combination_failed() and on_combination_succeeded() are
##      direct public methods called by ITF — no EventBus connections.
##    Tests call these methods directly. EventBus-based ACs cannot be verified.
##
## 2. card_removing during snap:
##    Story spec: EventBus.card_removing listener kills snap tween and transitions
##      card to IDLE.
##    Implementation: No card_removing listener exists. The snap tween's completion
##      callback checks if the target node is null via _get_node() — if the target
##      was freed, _on_snap_complete transitions to IDLE instead of EXECUTING.
##    Tests exercise this path by removing the target node from _test_nodes before
##      the snap-complete callback fires.
##
## 3. Tween durations:
##    Tweens play asynchronously. Tests verify state transitions by calling
##    _on_snap_complete() and _begin_push_away() directly (internal methods),
##    bypassing Tween timing. This is the same pattern used across the test suite.
##
## All tests use a subclass that overrides _get_node() to avoid CardSpawning.
extends GdUnitTestSuite

const CardEngineScript := preload("res://src/gameplay/card_engine.gd")

var _engine_class: GDScript = null


# ── Subclass factory ──────────────────────────────────────────────────────────

func _setup_engine_class() -> GDScript:
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


func _make_engine() -> Node:
	var cls := _setup_engine_class()
	var engine: Node = cls.new()
	add_child(engine)
	return engine


func _register_node(engine: Node, instance_id: String, pos: Vector2) -> Node2D:
	var node := Node2D.new()
	node.position = pos
	node.z_index = 0
	add_child(node)
	engine._test_nodes[instance_id] = node
	engine._set_state(instance_id, engine.State.IDLE)
	return node


# ── AC-1: combination_attempted fires after snap tween completes ──────────────

func test_snap_combination_attempted_fires_when_snap_complete() -> void:
	# Arrange
	var engine: Node = _make_engine()
	_register_node(engine, "card-a_0", Vector2(100.0, 100.0))
	_register_node(engine, "card-b_0", Vector2(200.0, 200.0))

	engine._set_state("card-a_0", engine.State.SNAPPING)
	engine._combination_in_flight = false

	var attempted := {"a": "", "b": "", "called": false}
	var handler := func(id_a: String, id_b: String) -> void:
		attempted["a"] = id_a
		attempted["b"] = id_b
		attempted["called"] = true
	engine.combination_attempted.connect(handler)

	# Act: call the snap-complete callback directly (bypasses Tween timing)
	engine._on_snap_complete("card-a_0", "card-b_0")

	# Assert
	assert_bool(attempted["called"]) \
		.override_failure_message("combination_attempted must fire after snap completes") \
		.is_true()
	assert_str(attempted["a"]) \
		.override_failure_message("combination_attempted must carry correct id_a") \
		.is_equal("card-a_0")
	assert_str(attempted["b"]) \
		.override_failure_message("combination_attempted must carry correct id_b") \
		.is_equal("card-b_0")

	engine.free()


func test_snap_combination_in_flight_set_true_after_snap_complete() -> void:
	# Arrange
	var engine: Node = _make_engine()
	_register_node(engine, "card-a_0", Vector2(100.0, 100.0))
	_register_node(engine, "card-b_0", Vector2(200.0, 200.0))
	engine._set_state("card-a_0", engine.State.SNAPPING)
	engine._combination_in_flight = false

	# Act
	engine._on_snap_complete("card-a_0", "card-b_0")

	# Assert
	assert_bool(engine._combination_in_flight) \
		.override_failure_message("_combination_in_flight must be true after snap_complete") \
		.is_true()

	engine.free()


func test_snap_card_transitions_to_executing_after_snap_complete() -> void:
	# Arrange
	var engine: Node = _make_engine()
	_register_node(engine, "card-a_0", Vector2(100.0, 100.0))
	_register_node(engine, "card-b_0", Vector2(200.0, 200.0))
	engine._combination_in_flight = false

	# Act
	engine._on_snap_complete("card-a_0", "card-b_0")

	# Assert
	assert_int(engine._get_state("card-a_0") as int) \
		.override_failure_message("Card must be in EXECUTING state after snap_complete") \
		.is_equal(engine.State.EXECUTING)

	engine.free()


# ── AC-2: Push-away ends at new position; state → IDLE ────────────────────────

func test_snap_push_away_state_becomes_pushed_immediately() -> void:
	# Arrange
	var engine: Node = _make_engine()
	_register_node(engine, "card-a_0", Vector2(300.0, 300.0))
	_register_node(engine, "card-b_0", Vector2(300.0, 300.0))

	# Act: call on_combination_failed directly (public API used by ITF)
	engine.on_combination_failed("card-a_0", "card-b_0")

	# Assert: state transitions to PUSHED immediately (before tween completes)
	assert_int(engine._get_state("card-a_0") as int) \
		.override_failure_message("Card must enter PUSHED state when push-away begins") \
		.is_equal(engine.State.PUSHED)

	engine.free()


func test_snap_push_away_combination_in_flight_cleared() -> void:
	# Arrange
	var engine: Node = _make_engine()
	_register_node(engine, "card-a_0", Vector2(300.0, 300.0))
	_register_node(engine, "card-b_0", Vector2(300.0, 300.0))
	engine._combination_in_flight = true

	# Act
	engine.on_combination_failed("card-a_0", "card-b_0")

	# Assert: flag cleared when combination resolves
	assert_bool(engine._combination_in_flight) \
		.override_failure_message("_combination_in_flight must be false after on_combination_failed") \
		.is_false()

	engine.free()


func test_snap_push_distance_constant_is_60px() -> void:
	var engine: Node = _make_engine()

	assert_float(engine.PUSH_DISTANCE) \
		.override_failure_message("PUSH_DISTANCE must be 60.0 per GDD") \
		.is_equal(60.0)

	engine.free()


func test_snap_push_duration_constant_is_018s() -> void:
	var engine: Node = _make_engine()

	assert_float(engine.PUSH_DURATION_SEC) \
		.override_failure_message("PUSH_DURATION_SEC must be 0.18 per GDD") \
		.is_equal(0.18)

	engine.free()


func test_snap_duration_constant_is_012s() -> void:
	var engine: Node = _make_engine()

	assert_float(engine.SNAP_DURATION_SEC) \
		.override_failure_message("SNAP_DURATION_SEC must be 0.12 per GDD") \
		.is_equal(0.12)

	engine.free()


# ── AC-3: Only one combination in-flight at a time ────────────────────────────

func test_snap_combination_attempted_blocked_when_in_flight() -> void:
	# Arrange: _combination_in_flight is already true
	var engine: Node = _make_engine()
	_register_node(engine, "card-a_0", Vector2(100.0, 100.0))
	_register_node(engine, "card-b_0", Vector2(200.0, 200.0))
	engine._combination_in_flight = true

	var signal_fired := {"called": false}
	var handler := func(_a: String, _b: String) -> void:
		signal_fired["called"] = true
	engine.combination_attempted.connect(handler)

	# Act: attempt snap complete while another combination is in-flight
	engine._on_snap_complete("card-a_0", "card-b_0")

	# Assert: signal must NOT fire
	assert_bool(signal_fired["called"]) \
		.override_failure_message("combination_attempted must NOT fire when _combination_in_flight == true") \
		.is_false()

	engine.free()


func test_snap_begin_snap_transitions_to_idle_when_in_flight() -> void:
	# Arrange: combination already in-flight; a new card tries to snap
	var engine: Node = _make_engine()
	_register_node(engine, "card-a_0", Vector2(50.0, 50.0))
	_register_node(engine, "card-b_0", Vector2(200.0, 200.0))
	engine._combination_in_flight = true
	engine._set_state("card-a_0", engine.State.ATTRACTING)

	# Act: _begin_snap is called
	engine._begin_snap("card-a_0", "card-b_0")

	# Assert: card drops to IDLE instead of SNAPPING
	assert_int(engine._get_state("card-a_0") as int) \
		.override_failure_message("Card must transition to IDLE when combination already in-flight") \
		.is_equal(engine.State.IDLE)

	engine.free()


# ── AC-4: Snap tween cancelled when target fires card_removing mid-snap ────────
# Note: No card_removing EventBus listener. We exercise the equivalent path:
# _on_snap_complete checks if the target node is null. If the target is absent,
# the dragged card transitions to IDLE and combination_attempted does NOT fire.

func test_snap_snap_complete_sets_idle_when_target_no_longer_exists() -> void:
	# Arrange: card-a is snapping; card-b node has been removed from test registry
	var engine: Node = _make_engine()
	_register_node(engine, "card-a_0", Vector2(100.0, 100.0))
	# card-b_0 intentionally NOT registered — simulates node freed mid-snap
	engine._combination_in_flight = false

	var signal_fired := {"called": false}
	var handler := func(_a: String, _b: String) -> void:
		signal_fired["called"] = true
	engine.combination_attempted.connect(handler)

	# Act
	engine._on_snap_complete("card-a_0", "card-b_0")

	# Assert: card-a → IDLE; combination_attempted NOT fired
	assert_int(engine._get_state("card-a_0") as int) \
		.override_failure_message("Dragged card must go IDLE when target was removed mid-snap") \
		.is_equal(engine.State.IDLE)
	assert_bool(signal_fired["called"]) \
		.override_failure_message("combination_attempted must NOT fire when target was removed mid-snap") \
		.is_false()

	engine.free()


func test_snap_combination_in_flight_stays_false_when_target_removed_mid_snap() -> void:
	# Arrange
	var engine: Node = _make_engine()
	_register_node(engine, "card-a_0", Vector2(100.0, 100.0))
	engine._combination_in_flight = false

	# Act: target absent
	engine._on_snap_complete("card-a_0", "card-b_0")

	# Assert: guard flag was not raised
	assert_bool(engine._combination_in_flight) \
		.override_failure_message("_combination_in_flight must stay false when target was removed mid-snap") \
		.is_false()

	engine.free()


# ── AC-5: drag_started during SNAPPING cancels snap → DRAGGED ─────────────────
# Note: The snap tween itself cannot be killed without tween tracking per card.
# The implementation handles this via _begin_snap guard: if drag_started fires
# for a card currently SNAPPING, _on_drag_started overrides state to DRAGGED and
# sets _dragged_id. This is the path we verify.

func test_snap_drag_started_during_snapping_transitions_to_dragged() -> void:
	# Arrange: card-a is SNAPPING
	var engine: Node = _make_engine()
	_register_node(engine, "card-a_0", Vector2(100.0, 100.0))
	engine._set_state("card-a_0", engine.State.SNAPPING)

	# Act: drag_started fires for the same card
	engine._on_drag_started("card-a_0", Vector2(100.0, 100.0))

	# Assert: state overrides to DRAGGED
	assert_int(engine._get_state("card-a_0") as int) \
		.override_failure_message("drag_started during SNAPPING must transition card to DRAGGED") \
		.is_equal(engine.State.DRAGGED)

	engine.free()


func test_snap_drag_started_during_snapping_sets_dragged_id() -> void:
	# Arrange
	var engine: Node = _make_engine()
	_register_node(engine, "card-a_0", Vector2(100.0, 100.0))
	engine._set_state("card-a_0", engine.State.SNAPPING)

	# Act
	engine._on_drag_started("card-a_0", Vector2(100.0, 100.0))

	# Assert: _dragged_id is set to the card that received drag_started
	assert_str(engine._dragged_id) \
		.override_failure_message("_dragged_id must be set when drag_started fires during SNAPPING") \
		.is_equal("card-a_0")

	engine.free()


# ── Combination succeeded — Additive template resets both cards to IDLE ────────

func test_snap_combination_succeeded_additive_sets_both_cards_idle() -> void:
	# Arrange
	var engine: Node = _make_engine()
	var node_a: Node2D = _register_node(engine, "card-a_0", Vector2(100.0, 100.0))
	var node_b: Node2D = _register_node(engine, "card-b_0", Vector2(200.0, 200.0))
	node_a.z_index = 100
	node_b.z_index = 100
	engine._set_state("card-a_0", engine.State.EXECUTING)
	engine._set_state("card-b_0", engine.State.EXECUTING)
	engine._combination_in_flight = true

	# Act
	engine.on_combination_succeeded("card-a_0", "card-b_0", "Additive", {})

	# Assert
	assert_int(engine._get_state("card-a_0") as int) \
		.override_failure_message("card-a must be IDLE after Additive combination_succeeded") \
		.is_equal(engine.State.IDLE)
	assert_int(engine._get_state("card-b_0") as int) \
		.override_failure_message("card-b must be IDLE after Additive combination_succeeded") \
		.is_equal(engine.State.IDLE)
	assert_bool(engine._combination_in_flight) \
		.override_failure_message("_combination_in_flight must be false after succeeded") \
		.is_false()

	engine.free()


func test_snap_combination_succeeded_additive_restores_z_index() -> void:
	# Arrange
	var engine: Node = _make_engine()
	var node_a: Node2D = _register_node(engine, "card-a_0", Vector2(100.0, 100.0))
	var node_b: Node2D = _register_node(engine, "card-b_0", Vector2(200.0, 200.0))
	node_a.z_index = 100
	node_b.z_index = 100
	engine._combination_in_flight = true

	# Act
	engine.on_combination_succeeded("card-a_0", "card-b_0", "Additive", {})

	# Assert: z_index returned to 0 for both
	assert_int(node_a.z_index) \
		.override_failure_message("card-a z_index must be 0 after Additive combination_succeeded") \
		.is_equal(0)
	assert_int(node_b.z_index) \
		.override_failure_message("card-b z_index must be 0 after Additive combination_succeeded") \
		.is_equal(0)

	engine.free()
