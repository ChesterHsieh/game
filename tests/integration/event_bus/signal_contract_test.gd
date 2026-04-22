## Integration test for EventBus autoload (Story 001).
##
## Verifies all 5 acceptance criteria:
##   AC-1: All 30 signals declared with correct names
##   AC-2: process_mode is PROCESS_MODE_ALWAYS
##   AC-3: EventBus reachable as global autoload
##   AC-4: Emit/connect round-trip delivers payload
##   AC-5: No custom methods beyond _ready
extends GdUnitTestSuite


const EXPECTED_SIGNALS: Array[String] = [
	"drag_started", "drag_moved", "drag_released",
	"proximity_entered", "proximity_exited",
	"combination_attempted", "combination_succeeded", "combination_failed",
	"combination_executed", "merge_animation_complete", "animate_complete",
	"card_spawned", "card_removing", "card_removed",
	"bar_values_changed", "win_condition_met", "hint_level_changed",
	"seed_cards_ready", "scene_loading", "scene_started", "scene_completed",
	"epilogue_started",
	"recipe_discovered", "discovery_milestone_reached",
	"epilogue_conditions_met", "final_memory_ready",
	"epilogue_cover_ready",
	"game_start_requested",
	"save_written", "save_failed",
]

const EXPECTED_ARITY: Dictionary = {
	"drag_started": 2, "drag_moved": 3, "drag_released": 2,
	"proximity_entered": 2, "proximity_exited": 2,
	"combination_attempted": 2, "combination_succeeded": 4,
	"combination_failed": 2, "combination_executed": 6,
	"merge_animation_complete": 3, "animate_complete": 1,
	"card_spawned": 3, "card_removing": 1, "card_removed": 1,
	"bar_values_changed": 1, "win_condition_met": 0, "hint_level_changed": 1,
	"seed_cards_ready": 1, "scene_loading": 1, "scene_started": 1,
	"scene_completed": 1, "epilogue_started": 0,
	"recipe_discovered": 4, "discovery_milestone_reached": 2,
	"epilogue_conditions_met": 0, "final_memory_ready": 0,
	"epilogue_cover_ready": 0, "game_start_requested": 0,
	"save_written": 0, "save_failed": 1,
}


func _get_event_bus_own_signals() -> Array[String]:
	var node_signal_names: Array[String] = []
	var base_node := Node.new()
	for sig in base_node.get_signal_list():
		node_signal_names.append(sig["name"])
	base_node.free()

	var own: Array[String] = []
	for sig in EventBus.get_signal_list():
		if sig["name"] not in node_signal_names:
			own.append(sig["name"])
	return own


func _get_event_bus_own_methods() -> Array[String]:
	var node_method_names: Array[String] = []
	var base_node := Node.new()
	for m in base_node.get_method_list():
		node_method_names.append(m["name"])
	base_node.free()

	var own: Array[String] = []
	for m in EventBus.get_method_list():
		if m["name"] not in node_method_names:
			own.append(m["name"])
	return own


# ── AC-1: Signal count and names ──────────────────────────────────────────────

func test_signal_count_equals_30() -> void:
	# Arrange / Act
	var own_signals := _get_event_bus_own_signals()

	# Assert
	assert_int(own_signals.size()).is_equal(30)


func test_signal_names_match_adr003_contract() -> void:
	# Arrange / Act
	var own_signals := _get_event_bus_own_signals()

	# Assert — every expected name must be present
	for expected_name in EXPECTED_SIGNALS:
		assert_bool(expected_name in own_signals) \
			.override_failure_message("Missing signal: %s" % expected_name) \
			.is_true()

	# Assert — no unexpected extras
	for actual_name in own_signals:
		assert_bool(actual_name in EXPECTED_SIGNALS) \
			.override_failure_message("Unexpected signal declared: %s" % actual_name) \
			.is_true()


func test_signal_arity_matches_adr003_contract() -> void:
	# Arrange
	var node_signal_names: Array[String] = []
	var base_node := Node.new()
	for sig in base_node.get_signal_list():
		node_signal_names.append(sig["name"])
	base_node.free()

	# Act / Assert
	for sig in EventBus.get_signal_list():
		var sig_name: String = sig["name"]
		if sig_name in node_signal_names:
			continue
		var actual_arity: int = sig["args"].size()
		var expected: int = EXPECTED_ARITY.get(sig_name, -1)
		assert_int(expected) \
			.override_failure_message("Signal %s has no expected arity entry" % sig_name) \
			.is_not_equal(-1)
		assert_int(actual_arity) \
			.override_failure_message("Signal %s: expected arity %d, got %d" % [sig_name, expected, actual_arity]) \
			.is_equal(expected)


# ── AC-2: Process mode + autoload order ───────────────────────────────────────

func test_process_mode_is_always() -> void:
	# Act / Assert
	assert_int(EventBus.process_mode).is_equal(Node.PROCESS_MODE_ALWAYS)


func test_event_bus_is_first_autoload() -> void:
	# Arrange
	var file := FileAccess.open("res://project.godot", FileAccess.READ)
	var content := file.get_as_text()
	file.close()

	# Act — find [autoload] section and extract first entry
	var in_autoload := false
	var first_autoload_key := ""
	for line in content.split("\n"):
		if line.strip_edges() == "[autoload]":
			in_autoload = true
			continue
		if in_autoload and line.begins_with("["):
			break
		if in_autoload and "=" in line and not line.strip_edges().is_empty():
			first_autoload_key = line.split("=")[0].strip_edges()
			break

	# Assert
	assert_str(first_autoload_key).is_equal("EventBus")


# ── AC-3: Global accessibility ────────────────────────────────────────────────

func test_event_bus_is_globally_accessible() -> void:
	# Act
	var node := get_node_or_null("/root/EventBus")

	# Assert
	assert_that(node).is_not_null()
	assert_bool(node == EventBus).is_true()


# ── AC-4: Emit / connect round-trips ─────────────────────────────────────────

func test_drag_started_emit_delivers_payload() -> void:
	# Arrange — Dictionary used because GDScript lambdas capture locals by value.
	var captured := {"id": "", "pos": Vector2.ZERO}
	var handler := func(card_id: String, world_pos: Vector2) -> void:
		captured["id"] = card_id
		captured["pos"] = world_pos
	EventBus.drag_started.connect(handler)

	# Act
	EventBus.drag_started.emit("card_001", Vector2(10.0, 20.0))

	# Assert
	assert_str(captured["id"]).is_equal("card_001")
	assert_that(captured["pos"]).is_equal(Vector2(10.0, 20.0))

	# Cleanup
	EventBus.drag_started.disconnect(handler)


func test_combination_executed_emit_delivers_payload() -> void:
	# Arrange — Dictionary used because GDScript lambdas capture locals by value.
	var captured := {"recipe": "", "template": ""}
	var handler := func(recipe_id: String, template: String,
			_ia: String, _ib: String, _ca: String, _cb: String) -> void:
		captured["recipe"] = recipe_id
		captured["template"] = template
	EventBus.combination_executed.connect(handler)

	# Act
	EventBus.combination_executed.emit(
		"recipe_rose", "merge", "inst_a", "inst_b", "card_rose", "card_water"
	)

	# Assert
	assert_str(captured["recipe"]).is_equal("recipe_rose")
	assert_str(captured["template"]).is_equal("merge")

	# Cleanup
	EventBus.combination_executed.disconnect(handler)


func test_save_written_emit_delivers_payload() -> void:
	# Arrange — Dictionary used because GDScript lambdas capture locals by value.
	var captured := {"called": false}
	var handler := func() -> void:
		captured["called"] = true
	EventBus.save_written.connect(handler)

	# Act
	EventBus.save_written.emit()

	# Assert
	assert_bool(captured["called"]).is_true()

	# Cleanup
	EventBus.save_written.disconnect(handler)


func test_double_emit_fires_handler_twice() -> void:
	# Arrange — Dictionary used because GDScript lambdas capture locals by value.
	var captured := {"count": 0}
	var handler := func(_card_id: String, _world_pos: Vector2) -> void:
		captured["count"] = int(captured["count"]) + 1
	EventBus.drag_started.connect(handler)

	# Act
	EventBus.drag_started.emit("card_001", Vector2.ZERO)
	EventBus.drag_started.emit("card_002", Vector2.ONE)

	# Assert
	assert_int(captured["count"]).is_equal(2)

	# Cleanup
	EventBus.drag_started.disconnect(handler)


func test_disconnect_before_emit_handler_not_called() -> void:
	# Arrange — Dictionary used because GDScript lambdas capture locals by value.
	var captured := {"called": false}
	var handler := func(_card_id: String, _world_pos: Vector2) -> void:
		captured["called"] = true
	EventBus.drag_started.connect(handler)
	EventBus.drag_started.disconnect(handler)

	# Act
	EventBus.drag_started.emit("card_001", Vector2.ZERO)

	# Assert
	assert_bool(captured["called"]).is_false()


# ── AC-5: No custom methods beyond _ready ─────────────────────────────────────

func test_no_custom_methods_beyond_ready() -> void:
	# Arrange / Act
	var own_methods := _get_event_bus_own_methods()

	# Assert — only _ready is permitted
	for method_name in own_methods:
		assert_bool(method_name == "_ready") \
			.override_failure_message("Unexpected method on EventBus: %s" % method_name) \
			.is_true()
