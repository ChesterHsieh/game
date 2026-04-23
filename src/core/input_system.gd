## InputSystem — translates raw mouse input into semantic drag events.
##
## Autoload singleton (#4 in canonical order, after RecipeDatabase).
## The sole owner of left-mouse drag input for card interactions.
## All cross-system events are emitted on EventBus (ADR-003).
## Contains no gameplay logic — only observes and reports.
##
## NOTE: class_name is intentionally omitted. Godot 4 does not allow a script
## registered as an autoload singleton to also declare a class_name matching
## its autoload name — the engine reports "Class hides an autoload singleton".
## The autoload is accessed globally via the name assigned in project.godot.
##
## Story 001: FSM skeleton + coordinate conversion.
## Story 002: hit-test + drag_started emission.
## Story 003: drag_moved + drag_released.
## Story 004: proximity detection.
## Story 005: cancel_drag() + signal-only discipline.
extends Node


# ── Export variables ──────────────────────────────────────────────────────────

## Distance (world pixels) at which proximity_entered / proximity_exited fire.
## Default 80 px. Safe tuning range: 40–160 (advisory — not clamped at runtime).
## GDD TR-input-system-013.
@export var snap_radius: float = 80.0


# ── Enums ──────────────────────────────────────────────────────────────────────

## Two-state FSM. Default is IDLE.
## IDLE: no drag active; hit-test runs on press.
## DRAGGING: card is held; drag_moved + proximity checks run each frame.
enum State { IDLE, DRAGGING }


# ── Private state ─────────────────────────────────────────────────────────────

## Current FSM state. Readable by tests via InputSystem._state.
var _state: State = State.IDLE

## card_id of the card currently being dragged. Empty when IDLE.
var _dragged_card_id: String = ""

## Last known world-space position of the dragged card's center.
var _last_world_pos: Vector2 = Vector2.ZERO

## Registered cards: card_id -> { node: Node2D, half_size: Vector2 }
var _cards: Dictionary = {}

## Cards currently within snap_radius of the dragged card (card_id → true).
## Dictionary used for O(1) membership checks on enter/exit transitions.
var _proximity_active: Dictionary = {}


# ── Built-in virtual methods ──────────────────────────────────────────────────

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS


## Per-frame hook. Runs proximity check only while DRAGGING.
func _process(_delta: float) -> void:
	if _state != State.DRAGGING:
		return
	_check_proximity(_last_world_pos)


## Entry point for raw mouse input.
## Using _unhandled_input so UI elements (buttons, panels) consume events first.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_handle_mouse_motion(event as InputEventMouseMotion)
		return

	if not event is InputEventMouseButton:
		return

	var mouse_event := event as InputEventMouseButton

	# Right-click is explicitly ignored in MVP (GDD Edge Cases).
	if mouse_event.button_index == MOUSE_BUTTON_RIGHT:
		return

	if mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return

	if mouse_event.pressed:
		_handle_left_press(mouse_event.position)
	else:
		_handle_left_release(mouse_event.position)


# ── Public API ────────────────────────────────────────────────────────────────

## Register a card node so InputSystem can hit-test and track it.
##
## [param card_id] Unique identifier matching CardDatabase.
## [param node] The card's Node2D in the scene tree.
## [param half_size] Half the card's width/height in world pixels (default 40×60).
##
## Call this when a card node is added to the scene tree.
##
## Example:
##   InputSystem.register_card("rose", $CardVisual, Vector2(40.0, 60.0))
func register_card(card_id: String, node: Node2D, half_size: Vector2 = Vector2(40.0, 60.0)) -> void:
	_cards[card_id] = {"node": node, "half_size": half_size}


## Unregister a card node. Call this before removing a card from the scene tree.
## If the unregistered card is currently being dragged, the drag is cancelled.
##
## Example:
##   InputSystem.unregister_card("rose")
func unregister_card(card_id: String) -> void:
	if _dragged_card_id == card_id:
		cancel_drag()
	_cards.erase(card_id)


## Cancel any active drag, emitting drag_released at the last known position.
## Safe to call at any time — no-op when already Idle.
## Called by external systems (scene transitions, pause) to interrupt cleanly.
##
## Order of emissions (matches GDD Edge Case "Drag cancelled by game event"):
##   1. proximity_exited for every active proximity target
##   2. drag_released at _last_world_pos
##
## Example:
##   InputSystem.cancel_drag()
func cancel_drag() -> void:
	if _state != State.DRAGGING:
		return
	_flush_proximity_exits()
	EventBus.drag_released.emit(_dragged_card_id, _last_world_pos)
	_end_drag()


# ── Private methods ───────────────────────────────────────────────────────────

## Convert a screen-space position to world-space using the active Camera2D.
## Returns [param screen_pos] unchanged when no Camera2D is present
## (safe for test environments without a camera).
##
## [param screen_pos] Position in viewport/screen coordinates.
## Returns world-space Vector2.
func _screen_to_world(screen_pos: Vector2) -> Vector2:
	var camera: Camera2D = get_viewport().get_camera_2d()
	if camera == null:
		return screen_pos
	return camera.get_global_transform().affine_inverse() * screen_pos


## Handle a left-mouse-button press at [param screen_pos].
## Performs a hit-test at the cursor world position. If a registered card is
## found, transitions IDLE → DRAGGING and emits EventBus.drag_started.
## Guard: if already DRAGGING, the press is silently ignored (no re-entry).
##
## [param screen_pos] Viewport-space position from the InputEvent.
func _handle_left_press(screen_pos: Vector2) -> void:
	if _state != State.IDLE:
		return
	var world_pos: Vector2 = _screen_to_world(screen_pos)
	var card_id: String = _hit_test(world_pos)
	if card_id.is_empty():
		return
	_state = State.DRAGGING
	_dragged_card_id = card_id
	_last_world_pos = world_pos
	EventBus.drag_started.emit(card_id, world_pos)


## Handle a left-mouse-button release at [param screen_pos].
## Emits proximity_exited for all active proximity targets, then drag_released,
## then transitions to Idle. Guard: no-op when not in DRAGGING state.
func _handle_left_release(screen_pos: Vector2) -> void:
	if _state != State.DRAGGING:
		return
	var world_pos: Vector2 = _screen_to_world(screen_pos)
	# Emit drag_released BEFORE flushing proximity exits so CardEngine's
	# drag_released handler still sees the active attract_target and can
	# transition to SNAPPING. If we flushed first, proximity_exited would
	# reset state to DRAGGED and the release would be treated as "drop in
	# open space" even when the player clearly released on top of a target.
	# cancel_drag() keeps the opposite order (exits first) per GDD cancel
	# semantics — that path is genuinely interrupting the drag.
	EventBus.drag_released.emit(_dragged_card_id, world_pos)
	_flush_proximity_exits()
	_end_drag()


## Handle mouse motion during an active drag.
## Converts the screen-space position to world space, computes the frame delta,
## updates _last_world_pos, and emits EventBus.drag_moved.
## Guard: no-op when not in DRAGGING state.
##
## [param motion_event] The raw InputEventMouseMotion from _unhandled_input.
func _handle_mouse_motion(motion_event: InputEventMouseMotion) -> void:
	if _state != State.DRAGGING:
		return
	var world_pos: Vector2 = _screen_to_world(motion_event.position)
	var delta: Vector2 = world_pos - _last_world_pos
	_last_world_pos = world_pos
	EventBus.drag_moved.emit(_dragged_card_id, world_pos, delta)


## Returns the card_id of the topmost card (highest z_index) under
## [param world_pos], or "" if no card is at that position.
func _hit_test(world_pos: Vector2) -> String:
	var best_id: String = ""
	var best_z: int = -999999

	for card_id: String in _cards:
		var entry: Dictionary = _cards[card_id]
		var node: Node2D = entry["node"]
		if not node.is_inside_tree() or not node.visible:
			continue
		var local: Vector2 = world_pos - node.global_position
		var half: Vector2 = entry["half_size"]
		if abs(local.x) <= half.x and abs(local.y) <= half.y:
			if node.z_index > best_z:
				best_z = node.z_index
				best_id = card_id

	return best_id


## Check all registered cards for proximity to [param dragged_world_pos].
## Emits proximity_entered / proximity_exited as cards cross the snap_radius
## boundary. Guard: never fires when dragged_id == target_id (TR-input-system-010).
##
## Uses <= comparison so a card exactly on the boundary counts as inside
## (consistent with hit-test AABB which uses <=).
func _check_proximity(dragged_world_pos: Vector2) -> void:
	var now_in: Dictionary = {}

	for card_id: String in _cards:
		if card_id == _dragged_card_id:
			continue
		var node: Node2D = _cards[card_id]["node"]
		if not node.is_inside_tree() or not node.visible:
			continue
		if dragged_world_pos.distance_to(node.global_position) <= snap_radius:
			now_in[card_id] = true

	# Emit entered for newly in-range cards.
	for card_id: String in now_in:
		if not _proximity_active.has(card_id):
			EventBus.proximity_entered.emit(_dragged_card_id, card_id)

	# Emit exited for cards that left range.
	for card_id: String in _proximity_active:
		if not now_in.has(card_id):
			EventBus.proximity_exited.emit(_dragged_card_id, card_id)

	_proximity_active = now_in


## Emit proximity_exited for every card currently in _proximity_active, then
## clear the dictionary. Called before drag_released on any drag-end path
## (normal release and cancel_drag).
func _flush_proximity_exits() -> void:
	for target_id: String in _proximity_active:
		EventBus.proximity_exited.emit(_dragged_card_id, target_id)
	_proximity_active.clear()


## Transition out of DRAGGING state and reset drag tracking variables.
## Callers are responsible for calling _flush_proximity_exits() first if
## proximity signals are required (cancel_drag and _handle_left_release do this).
func _end_drag() -> void:
	_state = State.IDLE
	_dragged_card_id = ""
	_proximity_active.clear()
