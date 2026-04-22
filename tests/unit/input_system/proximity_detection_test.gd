## Unit tests for InputSystem proximity detection — Story 004.
##
## Covers the 7 QA acceptance criteria from the story:
##   AC-1: proximity_entered fires when dragged card enters snap_radius
##   AC-2: proximity_exited fires when dragged card exits snap_radius
##   AC-3: dragged_id == target_id is never passed to proximity signals
##   AC-4: multiple targets can be in proximity simultaneously
##   AC-5: proximity cleanup emits proximity_exited for all active targets on drag end
##   AC-6: snap_radius defaults to 80.0
##   AC-7: no proximity signals emitted when FSM is Idle
##
## All tests run headlessly (no Camera2D — screen_pos == world_pos identity).
## Proximity checks are driven by calling _check_proximity() directly so tests
## do not depend on _process() timing.
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


## Put [param sys] into DRAGGING state for [param card_id] at [param world_pos].
## Uses register_card + direct state mutation so tests are independent of
## _unhandled_input implementation details.
func _enter_drag(sys: Node, card_id: String, world_pos: Vector2) -> Node2D:
	var node := _register_card(sys, card_id, world_pos)
	sys._state = InputSystem.State.DRAGGING
	sys._dragged_card_id = card_id
	sys._last_world_pos = world_pos
	return node


# ── AC-1: proximity_entered fires on enter ────────────────────────────────────

func test_proximity_entered_fires_when_card_enters_snap_radius() -> void:
	# Arrange — card-b at (200, 200); snap_radius = 80; drag card-a to (150, 200)
	# distance = 50, which is <= 80 → should fire proximity_entered
	var sys: Node = InputSystemScript.new()
	add_child(sys)
	sys.snap_radius = 80.0

	_enter_drag(sys, "card-a", Vector2(0.0, 0.0))
	_register_card(sys, "card-b", Vector2(200.0, 200.0))

	var entered := {"dragged": "", "target": "", "called": false}
	var handler := func(dragged_id: String, target_id: String) -> void:
		entered["dragged"] = dragged_id
		entered["target"] = target_id
		entered["called"] = true
	EventBus.proximity_entered.connect(handler)

	# Act — move dragged card center to (150, 200), distance to card-b = 50 < 80
	sys._last_world_pos = Vector2(150.0, 200.0)
	sys._check_proximity(Vector2(150.0, 200.0))

	# Assert
	assert_bool(entered["called"]) \
		.override_failure_message("proximity_entered must fire when distance <= snap_radius") \
		.is_true()
	assert_str(entered["dragged"]) \
		.override_failure_message("proximity_entered dragged_id must be 'card-a'") \
		.is_equal("card-a")
	assert_str(entered["target"]) \
		.override_failure_message("proximity_entered target_id must be 'card-b'") \
		.is_equal("card-b")

	# Cleanup
	EventBus.proximity_entered.disconnect(handler)
	sys.queue_free()


# ── AC-2: proximity_exited fires on exit ──────────────────────────────────────

func test_proximity_exited_fires_when_card_exits_snap_radius() -> void:
	# Arrange — seed card-b as already in proximity, then move away
	var sys: Node = InputSystemScript.new()
	add_child(sys)
	sys.snap_radius = 80.0

	_enter_drag(sys, "card-a", Vector2(150.0, 200.0))
	_register_card(sys, "card-b", Vector2(200.0, 200.0))

	# First check to put card-b into _proximity_active
	sys._check_proximity(Vector2(150.0, 200.0))

	var exited := {"dragged": "", "target": "", "called": false}
	var handler := func(dragged_id: String, target_id: String) -> void:
		exited["dragged"] = dragged_id
		exited["target"] = target_id
		exited["called"] = true
	EventBus.proximity_exited.connect(handler)

	# Act — move far away so distance > 80
	sys._check_proximity(Vector2(400.0, 400.0))

	# Assert
	assert_bool(exited["called"]) \
		.override_failure_message("proximity_exited must fire when card leaves snap_radius") \
		.is_true()
	assert_str(exited["dragged"]) \
		.override_failure_message("proximity_exited dragged_id must be 'card-a'") \
		.is_equal("card-a")
	assert_str(exited["target"]) \
		.override_failure_message("proximity_exited target_id must be 'card-b'") \
		.is_equal("card-b")

	# Cleanup
	EventBus.proximity_exited.disconnect(handler)
	sys.queue_free()


# ── AC-3: dragged_id == target_id guard ───────────────────────────────────────

func test_proximity_never_fires_with_dragged_id_equal_to_target_id() -> void:
	# Arrange — card-a is both the dragged card AND a registered card node
	# The dragged card's own node sits at _last_world_pos, distance = 0
	var sys: Node = InputSystemScript.new()
	add_child(sys)
	sys.snap_radius = 80.0

	_enter_drag(sys, "card-a", Vector2(100.0, 100.0))
	# card-a's node is already registered by _enter_drag; no separate card needed

	var entered_ids: Array[String] = []
	var exited_ids: Array[String] = []
	var entered_handler := func(_dragged: String, target: String) -> void:
		entered_ids.append(target)
	var exited_handler := func(_dragged: String, target: String) -> void:
		exited_ids.append(target)
	EventBus.proximity_entered.connect(entered_handler)
	EventBus.proximity_exited.connect(exited_handler)

	# Act — run proximity check with dragged card at its own registered position
	sys._check_proximity(Vector2(100.0, 100.0))

	# Assert — neither signal should carry "card-a" as target
	assert_bool(entered_ids.has("card-a")) \
		.override_failure_message("proximity_entered must NOT fire with target_id == dragged_id") \
		.is_false()
	assert_bool(exited_ids.has("card-a")) \
		.override_failure_message("proximity_exited must NOT fire with target_id == dragged_id") \
		.is_false()

	# Cleanup
	EventBus.proximity_entered.disconnect(entered_handler)
	EventBus.proximity_exited.disconnect(exited_handler)
	sys.queue_free()


# ── AC-4: multiple targets can be in proximity simultaneously ─────────────────

func test_proximity_entered_fires_for_all_cards_within_snap_radius() -> void:
	# Arrange — card-b at distance 50, card-c at distance 60 (both <= 80)
	var sys: Node = InputSystemScript.new()
	add_child(sys)
	sys.snap_radius = 80.0

	_enter_drag(sys, "card-a", Vector2(0.0, 0.0))
	_register_card(sys, "card-b", Vector2(50.0, 0.0))
	_register_card(sys, "card-c", Vector2(60.0, 0.0))

	var entered_targets: Array[String] = []
	var handler := func(_dragged: String, target: String) -> void:
		entered_targets.append(target)
	EventBus.proximity_entered.connect(handler)

	# Act
	sys._check_proximity(Vector2(0.0, 0.0))

	# Assert — both card-b and card-c received proximity_entered
	assert_bool(entered_targets.has("card-b")) \
		.override_failure_message("proximity_entered must fire for card-b (distance 50 <= 80)") \
		.is_true()
	assert_bool(entered_targets.has("card-c")) \
		.override_failure_message("proximity_entered must fire for card-c (distance 60 <= 80)") \
		.is_true()
	assert_int(entered_targets.size()) \
		.override_failure_message("Exactly 2 proximity_entered signals should fire") \
		.is_equal(2)

	# Cleanup
	EventBus.proximity_entered.disconnect(handler)
	sys.queue_free()


# ── AC-5: proximity cleanup on drag end (via _handle_left_release path) ───────

func test_proximity_exited_fires_for_all_active_targets_when_drag_released() -> void:
	# Arrange — put card-b and card-c in proximity, then release the drag
	var sys: Node = InputSystemScript.new()
	add_child(sys)
	sys.snap_radius = 80.0

	_enter_drag(sys, "card-a", Vector2(0.0, 0.0))
	_register_card(sys, "card-b", Vector2(50.0, 0.0))
	_register_card(sys, "card-c", Vector2(60.0, 0.0))

	# Seed both into _proximity_active
	sys._check_proximity(Vector2(0.0, 0.0))

	var exited_targets: Array[String] = []
	var handler := func(_dragged: String, target: String) -> void:
		exited_targets.append(target)
	EventBus.proximity_exited.connect(handler)

	# Act — simulate mouse release (no Camera2D → screen == world)
	var release_event := InputEventMouseButton.new()
	release_event.button_index = MOUSE_BUTTON_LEFT
	release_event.pressed = false
	release_event.position = Vector2(0.0, 0.0)
	sys._unhandled_input(release_event)

	# Assert
	assert_bool(exited_targets.has("card-b")) \
		.override_failure_message("proximity_exited must fire for card-b on drag release") \
		.is_true()
	assert_bool(exited_targets.has("card-c")) \
		.override_failure_message("proximity_exited must fire for card-c on drag release") \
		.is_true()
	assert_bool(sys._proximity_active.is_empty()) \
		.override_failure_message("_proximity_active must be empty after drag ends") \
		.is_true()

	# Cleanup
	EventBus.proximity_exited.disconnect(handler)
	sys.queue_free()


# ── AC-6: snap_radius defaults to 80 ─────────────────────────────────────────

func test_snap_radius_defaults_to_80() -> void:
	# Arrange
	var sys: Node = InputSystemScript.new()
	add_child(sys)

	# Assert
	assert_float(sys.snap_radius) \
		.override_failure_message("snap_radius must default to 80.0 (GDD TR-input-system-013)") \
		.is_equal(80.0)

	# Cleanup
	sys.queue_free()


# ── AC-7: no proximity signals when Idle ──────────────────────────────────────

func test_no_proximity_signals_emitted_when_fsm_is_idle() -> void:
	# Arrange
	var sys: Node = InputSystemScript.new()
	add_child(sys)
	sys.snap_radius = 80.0

	_register_card(sys, "card-b", Vector2(50.0, 0.0))
	# _state is IDLE by default — no drag entered

	var any_signal_fired := {"called": false}
	var entered_handler := func(_d: String, _t: String) -> void:
		any_signal_fired["called"] = true
	var exited_handler := func(_d: String, _t: String) -> void:
		any_signal_fired["called"] = true
	EventBus.proximity_entered.connect(entered_handler)
	EventBus.proximity_exited.connect(exited_handler)

	# Act — call _process manually (which guards on IDLE and returns early)
	sys._process(0.016)

	# Assert
	assert_bool(any_signal_fired["called"]) \
		.override_failure_message("No proximity signals must fire when FSM is Idle") \
		.is_false()

	# Cleanup
	EventBus.proximity_entered.disconnect(entered_handler)
	EventBus.proximity_exited.disconnect(exited_handler)
	sys.queue_free()


# ── Extra: proximity_entered does NOT re-fire on consecutive checks ───────────

func test_proximity_entered_does_not_refire_on_consecutive_checks_inside_radius() -> void:
	# Arrange
	var sys: Node = InputSystemScript.new()
	add_child(sys)
	sys.snap_radius = 80.0

	_enter_drag(sys, "card-a", Vector2(0.0, 0.0))
	_register_card(sys, "card-b", Vector2(50.0, 0.0))

	var entered_count := {"count": 0}
	var handler := func(_d: String, _t: String) -> void:
		entered_count["count"] = int(entered_count["count"]) + 1
	EventBus.proximity_entered.connect(handler)

	# Act — two consecutive checks while card-b remains inside radius
	sys._check_proximity(Vector2(0.0, 0.0))
	sys._check_proximity(Vector2(0.0, 0.0))

	# Assert — proximity_entered fires exactly once
	assert_int(entered_count["count"]) \
		.override_failure_message("proximity_entered must fire only once per enter crossing, not every frame") \
		.is_equal(1)

	# Cleanup
	EventBus.proximity_entered.disconnect(handler)
	sys.queue_free()
