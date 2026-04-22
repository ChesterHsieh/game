## Unit tests for InputSystem cancel_drag() + signal-only discipline — Story 005.
##
## Covers the 5 QA acceptance criteria from the story:
##   AC-1: cancel_drag from Dragging emits drag_released at _last_world_pos
##         and transitions FSM to Idle
##   AC-2: cancel_drag cleans up proximity — proximity_exited fires for all
##         active targets BEFORE drag_released is emitted
##   AC-3: cancel_drag from Idle is a safe no-op (no signals, no error)
##   AC-4: signal-only discipline — no direct calls to gameplay systems
##         (verified structurally: InputSystem has no local signals; all
##         EventBus emits are the only cross-system calls)
##   AC-5: all 5 signals flow through EventBus, not local signals on InputSystem
##
## All tests run headlessly (no Camera2D — screen_pos == world_pos identity).
extends GdUnitTestSuite

const InputSystemScript := preload("res://src/core/input_system.gd")


# ── Helpers ───────────────────────────────────────────────────────────────────

## Build a minimal Node2D at [param world_pos] acting as a card proxy.
func _make_card_node(world_pos: Vector2) -> Node2D:
	var node := Node2D.new()
	node.global_position = world_pos
	node.visible = true
	return node


## Register a card on [param sys] and add its node to the scene tree.
func _register_card(sys: Node, card_id: String, world_pos: Vector2) -> Node2D:
	var node := _make_card_node(world_pos)
	add_child(node)
	sys.register_card(card_id, node, Vector2(40.0, 60.0))
	return node


## Put [param sys] into DRAGGING state for [param card_id] at [param world_pos]
## using direct state mutation to stay independent of _unhandled_input.
func _enter_drag(sys: Node, card_id: String, world_pos: Vector2) -> Node2D:
	var node := _register_card(sys, card_id, world_pos)
	sys._state = InputSystem.State.DRAGGING
	sys._dragged_card_id = card_id
	sys._last_world_pos = world_pos
	return node


# ── AC-1: cancel_drag from Dragging emits drag_released + transitions Idle ────

func test_cancel_drag_from_dragging_emits_drag_released_at_last_known_pos() -> void:
	# Arrange
	var sys: Node = InputSystemScript.new()
	add_child(sys)

	_enter_drag(sys, "card-a", Vector2(100.0, 200.0))

	var released := {"called": false, "id": "", "pos": Vector2.ZERO}
	var handler := func(card_id: String, world_pos: Vector2) -> void:
		released["called"] = true
		released["id"] = card_id
		released["pos"] = world_pos
	EventBus.drag_released.connect(handler)

	# Act
	sys.cancel_drag()

	# Assert — drag_released fires with last known position
	assert_bool(released["called"]) \
		.override_failure_message("cancel_drag must emit drag_released when DRAGGING") \
		.is_true()
	assert_str(released["id"]) \
		.override_failure_message("drag_released card_id must be 'card-a'") \
		.is_equal("card-a")
	assert_that(released["pos"]) \
		.override_failure_message("drag_released world_pos must equal _last_world_pos") \
		.is_equal(Vector2(100.0, 200.0))

	# Cleanup
	EventBus.drag_released.disconnect(handler)
	sys.queue_free()


func test_cancel_drag_transitions_fsm_to_idle_and_clears_dragged_card_id() -> void:
	# Arrange
	var sys: Node = InputSystemScript.new()
	add_child(sys)

	_enter_drag(sys, "card-a", Vector2(100.0, 200.0))

	# Suppress drag_released emission side-effects for this focused assertion
	var _suppress := func(_id: String, _pos: Vector2) -> void: pass
	EventBus.drag_released.connect(_suppress)

	# Act
	sys.cancel_drag()

	# Assert
	assert_int(sys._state) \
		.override_failure_message("FSM must be Idle after cancel_drag") \
		.is_equal(InputSystem.State.IDLE)
	assert_str(sys._dragged_card_id) \
		.override_failure_message("_dragged_card_id must be empty after cancel_drag") \
		.is_equal("")

	# Cleanup
	EventBus.drag_released.disconnect(_suppress)
	sys.queue_free()


# ── AC-2: cancel_drag emits proximity_exited BEFORE drag_released ─────────────

func test_cancel_drag_emits_proximity_exited_before_drag_released() -> void:
	# Arrange — card-b and card-c in proximity
	var sys: Node = InputSystemScript.new()
	add_child(sys)
	sys.snap_radius = 80.0

	_enter_drag(sys, "card-a", Vector2(0.0, 0.0))
	_register_card(sys, "card-b", Vector2(50.0, 0.0))
	_register_card(sys, "card-c", Vector2(60.0, 0.0))

	# Seed both into _proximity_active
	sys._check_proximity(Vector2(0.0, 0.0))

	var signal_order: Array[String] = []
	var exited_handler := func(_dragged: String, target: String) -> void:
		signal_order.append("exited:" + target)
	var released_handler := func(_id: String, _pos: Vector2) -> void:
		signal_order.append("released")
	EventBus.proximity_exited.connect(exited_handler)
	EventBus.drag_released.connect(released_handler)

	# Act
	sys.cancel_drag()

	# Assert — all exited signals come before released
	assert_int(signal_order.size()) \
		.override_failure_message("Must have 3 signals total: 2 exited + 1 released") \
		.is_equal(3)

	var released_index: int = signal_order.find("released")
	assert_int(released_index) \
		.override_failure_message("'released' must be the last signal in the sequence") \
		.is_equal(2)

	assert_bool(signal_order.has("exited:card-b")) \
		.override_failure_message("proximity_exited must fire for card-b") \
		.is_true()
	assert_bool(signal_order.has("exited:card-c")) \
		.override_failure_message("proximity_exited must fire for card-c") \
		.is_true()

	assert_bool(sys._proximity_active.is_empty()) \
		.override_failure_message("_proximity_active must be empty after cancel_drag") \
		.is_true()

	# Cleanup
	EventBus.proximity_exited.disconnect(exited_handler)
	EventBus.drag_released.disconnect(released_handler)
	sys.queue_free()


# ── AC-3: cancel_drag from Idle is a safe no-op ───────────────────────────────

func test_cancel_drag_from_idle_does_not_emit_any_signal() -> void:
	# Arrange — InputSystem starts in Idle by default
	var sys: Node = InputSystemScript.new()
	add_child(sys)

	var any_signal_fired := {"called": false}
	var released_handler := func(_id: String, _pos: Vector2) -> void:
		any_signal_fired["called"] = true
	var exited_handler := func(_d: String, _t: String) -> void:
		any_signal_fired["called"] = true
	EventBus.drag_released.connect(released_handler)
	EventBus.proximity_exited.connect(exited_handler)

	# Act — call cancel_drag while already Idle
	sys.cancel_drag()

	# Assert
	assert_bool(any_signal_fired["called"]) \
		.override_failure_message("cancel_drag must be a no-op when FSM is Idle — no signals emitted") \
		.is_false()
	assert_int(sys._state) \
		.override_failure_message("FSM must remain Idle after no-op cancel_drag") \
		.is_equal(InputSystem.State.IDLE)

	# Cleanup
	EventBus.drag_released.disconnect(released_handler)
	EventBus.proximity_exited.disconnect(exited_handler)
	sys.queue_free()


func test_cancel_drag_from_idle_does_not_crash_or_error() -> void:
	# Arrange
	var sys: Node = InputSystemScript.new()
	add_child(sys)

	# Act + Assert — simply must not raise an error
	# If cancel_drag() throws, the test will fail via the gdUnit4 error reporter.
	sys.cancel_drag()
	sys.cancel_drag()  # Double-call confirms idempotency

	assert_int(sys._state) \
		.override_failure_message("FSM must still be Idle after repeated no-op calls") \
		.is_equal(InputSystem.State.IDLE)

	# Cleanup
	sys.queue_free()


# ── AC-4 + AC-5: signal-only discipline and EventBus-only signal emissions ────

func test_input_system_declares_no_local_signals() -> void:
	# Verify that InputSystem itself exposes no user-defined signals.
	# All signals must live on EventBus (ADR-003 / Story 005 AC-5).
	# gdUnit4 note: GDScript signal_list() includes built-in Node signals;
	# we filter to user-defined signals only (those not on a plain Node).
	var sys: Node = InputSystemScript.new()
	add_child(sys)

	# Collect signal names declared on a plain Node (baseline built-ins)
	var baseline_node := Node.new()
	var builtin_signals: Array[String] = []
	for sig: Dictionary in baseline_node.get_signal_list():
		builtin_signals.append(sig["name"])
	baseline_node.free()

	# Collect user-defined signals on InputSystem
	var user_signals: Array[String] = []
	for sig: Dictionary in sys.get_signal_list():
		if not builtin_signals.has(sig["name"]):
			user_signals.append(sig["name"])

	assert_int(user_signals.size()) \
		.override_failure_message(
			"InputSystem must declare zero local signals — all signals belong to EventBus. Found: "
			+ str(user_signals)
		) \
		.is_equal(0)

	# Cleanup
	sys.queue_free()


func test_all_five_drag_and_proximity_signals_exist_on_event_bus() -> void:
	# Verify that EventBus declares all 5 signals InputSystem relies on.
	# This is a contract test — if EventBus removes one, this catches it.
	var expected: Array[String] = [
		"drag_started",
		"drag_moved",
		"drag_released",
		"proximity_entered",
		"proximity_exited",
	]

	var event_bus_signal_names: Array[String] = []
	for sig: Dictionary in EventBus.get_signal_list():
		event_bus_signal_names.append(sig["name"])

	for expected_signal: String in expected:
		assert_bool(event_bus_signal_names.has(expected_signal)) \
			.override_failure_message(
				"EventBus must declare signal '" + expected_signal + "' (ADR-003 / Story 005 AC-5)"
			) \
			.is_true()


# ── Edge case: cancel_drag with no proximity targets ─────────────────────────

func test_cancel_drag_with_empty_proximity_active_does_not_emit_proximity_exited() -> void:
	# Arrange — dragging, but no cards have entered proximity
	var sys: Node = InputSystemScript.new()
	add_child(sys)

	_enter_drag(sys, "card-a", Vector2(0.0, 0.0))
	# _proximity_active is empty — no proximity checks have run yet

	var exited_fired := {"called": false}
	var exited_handler := func(_d: String, _t: String) -> void:
		exited_fired["called"] = true
	var released_handler := func(_id: String, _pos: Vector2) -> void: pass
	EventBus.proximity_exited.connect(exited_handler)
	EventBus.drag_released.connect(released_handler)

	# Act
	sys.cancel_drag()

	# Assert — no proximity_exited since none were in range
	assert_bool(exited_fired["called"]) \
		.override_failure_message("proximity_exited must NOT fire when _proximity_active is empty") \
		.is_false()

	# Cleanup
	EventBus.proximity_exited.disconnect(exited_handler)
	EventBus.drag_released.disconnect(released_handler)
	sys.queue_free()
