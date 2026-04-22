## Integration tests for CardEngine FSM scaffold — Story 001.
##
## Covers QA test cases from story-001-fsm-scaffold.md:
##   AC-1: CardEngine initializes without errors; _states is empty on start
##   AC-2: Connects to 5 InputSystem signals (drag_started, drag_moved,
##          drag_released, proximity_entered, proximity_exited)
##   AC-3: State for a registered instance_id defaults to IDLE
##   AC-4: _set_state / _get_state roundtrip works correctly
##   AC-5: _end_drag clears _dragged_id and _attract_target
##
## ── BLOCKED ACs (implementation diverges from story spec) ─────────────────────
##
## The following story-001 ACs CANNOT be tested against the current implementation
## and are flagged here as BLOCKED:
##
##   AC-2 (partial): Story requires connection to EventBus signals. Implementation
##     connects to InputSystem signals instead. Tests verify InputSystem connections
##     only — the EventBus wiring specified in the story is absent.
##
##   AC-3 (card_spawned): Story requires CardEngine._ready() to connect
##     EventBus.card_spawned and register cards in _states on emit. No such
##     connection exists in _ready(). _states is populated only via _set_state().
##
##   AC-4 (card_removed): Story requires EventBus.card_removed to deregister a
##     card. No such listener is wired. Cannot be tested.
##
##   AC-5 (card_removing tween cancel): Story requires EventBus.card_removing to
##     kill the active_tween for that card. CardEngine has no active_tween storage
##     per card and no card_removing listener. Cannot be tested.
##
## These gaps should be resolved in a follow-up: either update card_engine.gd to
## add the EventBus lifecycle connections, or amend the story's ACs to match the
## InputSystem+CardSpawning pattern the implementation uses.
##
## All tests run headlessly against a fresh CardEngine script instance.
## CardSpawning is NOT invoked — tests manipulate _states directly.
extends GdUnitTestSuite

const CardEngineScript := preload("res://src/gameplay/card_engine.gd")


# ── Helpers ───────────────────────────────────────────────────────────────────

## Creates a fresh CardEngine node and adds it to the scene tree.
## Caller is responsible for calling .free() in cleanup.
func _make_engine() -> Node:
	var engine: Node = CardEngineScript.new()
	add_child(engine)
	return engine


# ── AC-1: Initializes without errors; internal state registry is empty ────────

func test_card_engine_wiring_states_dict_is_empty_on_init() -> void:
	# Arrange / Act
	var engine: Node = _make_engine()

	# Assert: no card states registered at startup
	assert_int(engine._states.size()) \
		.override_failure_message("_states must be empty on CardEngine init") \
		.is_equal(0)

	# Cleanup
	engine.free()


func test_card_engine_wiring_dragged_id_is_empty_string_on_init() -> void:
	var engine: Node = _make_engine()

	assert_str(engine._dragged_id) \
		.override_failure_message("_dragged_id must be empty string on init") \
		.is_equal("")

	engine.free()


func test_card_engine_wiring_attract_target_is_empty_string_on_init() -> void:
	var engine: Node = _make_engine()

	assert_str(engine._attract_target) \
		.override_failure_message("_attract_target must be empty string on init") \
		.is_equal("")

	engine.free()


func test_card_engine_wiring_combination_in_flight_false_on_init() -> void:
	var engine: Node = _make_engine()

	assert_bool(engine._combination_in_flight) \
		.override_failure_message("_combination_in_flight must be false on init") \
		.is_false()

	engine.free()


# ── AC-2 (partial): Connects to InputSystem signals ───────────────────────────
# Note: Story specifies EventBus connections. Implementation uses InputSystem.
# Tests verify the actual connections present in _ready().

func test_card_engine_wiring_drag_started_is_connected_to_input_system() -> void:
	var engine: Node = _make_engine()

	assert_bool(InputSystem.drag_started.is_connected(engine._on_drag_started)) \
		.override_failure_message("drag_started must be connected to _on_drag_started") \
		.is_true()

	engine.free()


func test_card_engine_wiring_drag_moved_is_connected_to_input_system() -> void:
	var engine: Node = _make_engine()

	assert_bool(InputSystem.drag_moved.is_connected(engine._on_drag_moved)) \
		.override_failure_message("drag_moved must be connected to _on_drag_moved") \
		.is_true()

	engine.free()


func test_card_engine_wiring_drag_released_is_connected_to_input_system() -> void:
	var engine: Node = _make_engine()

	assert_bool(InputSystem.drag_released.is_connected(engine._on_drag_released)) \
		.override_failure_message("drag_released must be connected to _on_drag_released") \
		.is_true()

	engine.free()


func test_card_engine_wiring_proximity_entered_is_connected_to_input_system() -> void:
	var engine: Node = _make_engine()

	assert_bool(InputSystem.proximity_entered.is_connected(engine._on_proximity_entered)) \
		.override_failure_message("proximity_entered must be connected to _on_proximity_entered") \
		.is_true()

	engine.free()


func test_card_engine_wiring_proximity_exited_is_connected_to_input_system() -> void:
	var engine: Node = _make_engine()

	assert_bool(InputSystem.proximity_exited.is_connected(engine._on_proximity_exited)) \
		.override_failure_message("proximity_exited must be connected to _on_proximity_exited") \
		.is_true()

	engine.free()


# ── AC-3 (partial): _set_state stores IDLE for a new instance_id ─────────────
# Note: Card lifecycle signals (card_spawned) are not wired. We verify the
# _set_state/_get_state contract the FSM relies on internally.

func test_card_engine_wiring_set_state_registers_idle_for_new_id() -> void:
	# Arrange
	var engine: Node = _make_engine()

	# Act: manually register a card ID at IDLE — mirrors what card_spawned would do
	engine._set_state("test-card_0", engine.State.IDLE)

	# Assert
	assert_int(engine._states["test-card_0"] as int) \
		.override_failure_message("Registered card must have IDLE state") \
		.is_equal(engine.State.IDLE)

	engine.free()


func test_card_engine_wiring_get_state_returns_idle_for_unknown_id() -> void:
	# Arrange
	var engine: Node = _make_engine()

	# Act: query an id that was never registered
	var state: int = engine._get_state("nonexistent_id") as int

	# Assert: defaults to IDLE per implementation
	assert_int(state) \
		.override_failure_message("Unknown id must return IDLE (default)") \
		.is_equal(engine.State.IDLE)

	engine.free()


func test_card_engine_wiring_set_state_can_set_all_six_states() -> void:
	# Arrange
	var engine: Node = _make_engine()
	var all_states: Array = [
		engine.State.IDLE,
		engine.State.DRAGGED,
		engine.State.ATTRACTING,
		engine.State.SNAPPING,
		engine.State.PUSHED,
		engine.State.EXECUTING,
	]

	for s: int in all_states:
		# Act
		engine._set_state("test-card_0", s)

		# Assert
		assert_int(engine._get_state("test-card_0") as int) \
			.override_failure_message("State roundtrip failed for state %d" % s) \
			.is_equal(s)

	engine.free()


# ── AC-4 (partial): Deregistration via _states.erase ─────────────────────────
# Note: card_removed EventBus listener is absent. Tests verify the underlying
# dictionary erase behavior that the listener would rely on.

func test_card_engine_wiring_erase_removes_card_from_states() -> void:
	# Arrange
	var engine: Node = _make_engine()
	engine._set_state("morning-light_0", engine.State.IDLE)
	assert_bool(engine._states.has("morning-light_0")).is_true()

	# Act: simulate what card_removed handler would do
	engine._states.erase("morning-light_0")

	# Assert
	assert_bool(engine._states.has("morning-light_0")) \
		.override_failure_message("Card must be deregistered after erase") \
		.is_false()

	engine.free()


# ── AC-5 (partial): _end_drag clears dragged ID and attract target ────────────
# Note: card_removing tween-cancel behavior is not implemented. We verify
# _end_drag clears navigation state, which is the only implemented cleanup path.

func test_card_engine_wiring_end_drag_clears_dragged_id() -> void:
	# Arrange
	var engine: Node = _make_engine()
	engine._dragged_id = "test-card_0"
	engine._attract_target = "target-card_0"

	# Act
	engine._end_drag()

	# Assert
	assert_str(engine._dragged_id) \
		.override_failure_message("_dragged_id must be empty after _end_drag") \
		.is_equal("")

	engine.free()


func test_card_engine_wiring_end_drag_clears_attract_target() -> void:
	# Arrange
	var engine: Node = _make_engine()
	engine._dragged_id = "test-card_0"
	engine._attract_target = "target-card_0"

	# Act
	engine._end_drag()

	# Assert
	assert_str(engine._attract_target) \
		.override_failure_message("_attract_target must be empty after _end_drag") \
		.is_equal("")

	engine.free()


# ── FSM enum completeness ─────────────────────────────────────────────────────

func test_card_engine_wiring_state_enum_has_six_values() -> void:
	var engine: Node = _make_engine()

	# All six states from the GDD must exist in the enum
	var _ := engine.State.IDLE
	var __ := engine.State.DRAGGED
	var ___ := engine.State.ATTRACTING
	var ____ := engine.State.SNAPPING
	var _____ := engine.State.PUSHED
	var ______ := engine.State.EXECUTING

	# If any name is missing, GDScript will error at parse time — reaching here
	# confirms all six exist.
	assert_bool(true) \
		.override_failure_message("All 6 FSM states must exist in CardEngine.State enum") \
		.is_true()

	engine.free()


# ── get_card_state public API ─────────────────────────────────────────────────

func test_card_engine_wiring_get_card_state_public_returns_idle_for_unknown() -> void:
	var engine: Node = _make_engine()

	var state: int = engine.get_card_state("unknown_id") as int

	assert_int(state) \
		.override_failure_message("get_card_state must return IDLE for unknown id") \
		.is_equal(engine.State.IDLE)

	engine.free()


func test_card_engine_wiring_get_card_state_public_returns_set_state() -> void:
	var engine: Node = _make_engine()
	engine._set_state("card_0", engine.State.DRAGGED)

	var state: int = engine.get_card_state("card_0") as int

	assert_int(state) \
		.override_failure_message("get_card_state must return the state set via _set_state") \
		.is_equal(engine.State.DRAGGED)

	engine.free()
