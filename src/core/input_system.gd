## InputSystem — translates raw mouse input into semantic drag events.
## Autoload singleton. The sole owner of left-mouse drag input for cards.
## Emits typed signals; contains no gameplay logic.
## Card Engine connects to these signals to drive card movement and magnetic snap.

extends Node

# ── Signals ───────────────────────────────────────────────────────────────────

## Fired when the player presses left mouse on a registered card.
signal drag_started(card_id: String, world_pos: Vector2)

## Fired every frame while a drag is active and the mouse has moved.
signal drag_moved(card_id: String, world_pos: Vector2, delta: Vector2)

## Fired when the player releases left mouse, or when cancel_drag() is called.
signal drag_released(card_id: String, world_pos: Vector2)

## Fired when the dragged card's center enters snap_radius of a stationary card.
signal proximity_entered(dragged_id: String, target_id: String)

## Fired when the dragged card's center exits snap_radius of a stationary card.
signal proximity_exited(dragged_id: String, target_id: String)

# ── Tuning ─────────────────────────────────────────────────────────────────────

## Distance (world pixels) at which proximity_entered fires.
## Validated at 80px in card-engine prototype.
const SNAP_RADIUS := 80.0

# ── State ─────────────────────────────────────────────────────────────────────

# Registered cards: card_id -> { node: Node2D, half_size: Vector2 }
var _cards: Dictionary = {}

var _state:            String        = "idle"  # "idle" | "dragging"
var _dragged_id:       String        = ""
var _last_world_pos:   Vector2       = Vector2.ZERO
var _proximity_active: Array[String] = []      # card_ids currently within snap_radius


# ── Registration ──────────────────────────────────────────────────────────────

## Register a card node so the Input System can hit-test and track it.
## [param half_size] is half the card's width/height in world pixels (default 40×60).
## Call this when a card node is added to the scene.
func register_card(card_id: String, node: Node2D, half_size: Vector2 = Vector2(40.0, 60.0)) -> void:
	_cards[card_id] = {"node": node, "half_size": half_size}


## Unregister a card node. Call this before removing a card from the scene.
## If the unregistered card is currently being dragged, the drag is cancelled.
func unregister_card(card_id: String) -> void:
	if _dragged_id == card_id:
		cancel_drag()
	_cards.erase(card_id)


## Cancel any active drag, emitting drag_released at the last known position.
## Called by external systems (scene transitions, pause) to interrupt a drag cleanly.
func cancel_drag() -> void:
	if _state == "dragging":
		drag_released.emit(_dragged_id, _last_world_pos)
		_end_drag()


# ── Input ─────────────────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	if (event as InputEventMouseButton).button_index != MOUSE_BUTTON_LEFT:
		return

	if event.pressed:
		if _state == "idle":
			var world_pos := _world_mouse_pos()
			var hit_id    := _hit_test(world_pos)
			if hit_id != "":
				_state          = "dragging"
				_dragged_id     = hit_id
				_last_world_pos = world_pos
				drag_started.emit(hit_id, world_pos)
	else:
		if _state == "dragging":
			var world_pos := _world_mouse_pos()
			drag_released.emit(_dragged_id, world_pos)
			_end_drag()


func _process(_delta: float) -> void:
	if _state != "dragging":
		return

	var world_pos := _world_mouse_pos()
	var delta     := world_pos - _last_world_pos

	if delta != Vector2.ZERO:
		drag_moved.emit(_dragged_id, world_pos, delta)

	_last_world_pos = world_pos
	_check_proximity(world_pos)


# ── Private ───────────────────────────────────────────────────────────────────

## Returns the card_id of the card under [param world_pos], or "" if none.
## When cards overlap, picks the one with the highest z_index.
func _hit_test(world_pos: Vector2) -> String:
	var best_id: String = ""
	var best_z:  int    = -999999

	for card_id: String in _cards:
		var entry: Dictionary = _cards[card_id]
		var node: Node2D      = entry["node"]
		if not node.is_inside_tree() or not node.visible:
			continue
		var local: Vector2 = world_pos - node.global_position
		var half:  Vector2 = entry["half_size"]
		if abs(local.x) <= half.x and abs(local.y) <= half.y:
			if node.z_index > best_z:
				best_z = node.z_index
				best_id = card_id

	return best_id


## Checks all registered cards for proximity to [param dragged_world_pos].
## Fires proximity_entered / proximity_exited as cards enter or leave snap_radius.
func _check_proximity(dragged_world_pos: Vector2) -> void:
	var now_in: Array[String] = []

	for card_id: String in _cards:
		if card_id == _dragged_id:
			continue
		var node: Node2D = _cards[card_id]["node"]
		if not node.is_inside_tree() or not node.visible:
			continue
		if dragged_world_pos.distance_to(node.global_position) < SNAP_RADIUS:
			now_in.append(card_id)

	for card_id: String in now_in:
		if card_id not in _proximity_active:
			proximity_entered.emit(_dragged_id, card_id)

	for card_id: String in _proximity_active:
		if card_id not in now_in:
			proximity_exited.emit(_dragged_id, card_id)

	_proximity_active = now_in


func _end_drag() -> void:
	_state = "idle"
	_dragged_id = ""
	_proximity_active.clear()


## Converts viewport mouse position to world coordinates.
func _world_mouse_pos() -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() \
		* get_viewport().get_mouse_position()
