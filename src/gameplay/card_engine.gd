## CardEngine — manages card physical state, drag, attraction, snap, and push-away.
## Autoload singleton. Connects to InputSystem signals. Fires combination_attempted.
## Does NOT read recipes — fires signal and waits for ITF to respond.

extends Node

# ── Signals ───────────────────────────────────────────────────────────────────

## Fired when a snap tween completes and a combination should be resolved.
signal combination_attempted(instance_id_a: String, instance_id_b: String)

## Fired when a Merge animation completes — ITF listens to clean up source cards.
signal merge_complete(instance_id_a: String, instance_id_b: String, midpoint: Vector2)

# ── Tuning (validated in card-engine prototype) ────────────────────────────────

## How far the dragged card drifts toward the target while in snap range.
const ATTRACTION_FACTOR  := 0.4
## Duration of the snap tween when releasing in snap range.
const SNAP_DURATION_SEC  := 0.12
## Offset from target center when snapping (keeps both cards visible).
const SNAP_OFFSET        := Vector2(16.0, 16.0)
## Distance the card bounces away on a failed combination.
const PUSH_DISTANCE      := 60.0
## Duration of the push-away tween.
const PUSH_DURATION_SEC  := 0.18
## Duration of the merge fade/scale animation.
const MERGE_DURATION_SEC := 0.55

# ── Card States ───────────────────────────────────────────────────────────────

enum State { IDLE, DRAGGED, ATTRACTING, SNAPPING, PUSHED, EXECUTING }

# ── Internal State ────────────────────────────────────────────────────────────

# instance_id -> State
var _states: Dictionary = {}

# The single card currently being dragged (instance_id or "")
var _dragged_id: String = ""

# The target card being approached during Attracting (instance_id or "")
var _attract_target: String = ""

# Latest cursor world position — updated every drag_moved signal
var _cursor_pos: Vector2 = Vector2.ZERO

# Guard: only one combination can be in-flight at a time
var _combination_in_flight: bool = false


# ── Setup ─────────────────────────────────────────────────────────────────────

func _ready() -> void:
	EventBus.drag_started.connect(_on_drag_started)
	EventBus.drag_moved.connect(_on_drag_moved)
	EventBus.drag_released.connect(_on_drag_released)
	EventBus.proximity_entered.connect(_on_proximity_entered)
	EventBus.proximity_exited.connect(_on_proximity_exited)


# ── Per-Frame Update ──────────────────────────────────────────────────────────

func _process(_delta: float) -> void:
	if _dragged_id == "":
		return

	var dragged_node := _get_node(_dragged_id)
	if dragged_node == null:
		return

	match _get_state(_dragged_id):
		State.DRAGGED:
			dragged_node.position = _cursor_pos

		State.ATTRACTING:
			var target_node := _get_node(_attract_target)
			if target_node != null:
				dragged_node.position = lerp(_cursor_pos, target_node.position, ATTRACTION_FACTOR)


# ── InputSystem Signal Handlers ───────────────────────────────────────────────

func _on_drag_started(instance_id: String, world_pos: Vector2) -> void:
	_dragged_id  = instance_id
	_cursor_pos  = world_pos
	_set_state(instance_id, State.DRAGGED)

	var node := _get_node(instance_id)
	if node != null:
		node.z_index = 100


func _on_drag_moved(instance_id: String, world_pos: Vector2, _delta: Vector2) -> void:
	if instance_id != _dragged_id:
		return
	_cursor_pos = world_pos


func _on_drag_released(instance_id: String, world_pos: Vector2) -> void:
	if instance_id != _dragged_id:
		return

	_cursor_pos = world_pos

	match _get_state(instance_id):
		State.ATTRACTING:
			_begin_snap(instance_id, _attract_target)
		State.DRAGGED:
			# Released in open space — drop in place
			_set_state(instance_id, State.IDLE)
			_end_drag()
		_:
			_end_drag()


func _on_proximity_entered(dragged_id: String, target_id: String) -> void:
	if dragged_id != _dragged_id:
		return
	if _get_state(dragged_id) != State.DRAGGED:
		return
	_attract_target = target_id
	_set_state(dragged_id, State.ATTRACTING)


func _on_proximity_exited(dragged_id: String, target_id: String) -> void:
	if dragged_id != _dragged_id or target_id != _attract_target:
		return
	if _get_state(dragged_id) != State.ATTRACTING:
		return
	_attract_target = ""
	_set_state(dragged_id, State.DRAGGED)


# ── Snap ──────────────────────────────────────────────────────────────────────

func _begin_snap(instance_id: String, target_id: String) -> void:
	if _combination_in_flight:
		# Another combination already resolving — drop card in place
		_set_state(instance_id, State.IDLE)
		_end_drag()
		return

	var dragged_node := _get_node(instance_id)
	var target_node  := _get_node(target_id)
	if dragged_node == null or target_node == null:
		_set_state(instance_id, State.IDLE)
		_end_drag()
		return

	_set_state(instance_id, State.SNAPPING)
	_end_drag()

	var snap_pos := target_node.position + SNAP_OFFSET
	var tween    := dragged_node.create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(dragged_node, "position", snap_pos, SNAP_DURATION_SEC)
	tween.tween_callback(func() -> void:
		_on_snap_complete(instance_id, target_id)
	)


func _on_snap_complete(instance_id_a: String, instance_id_b: String) -> void:
	if _get_node(instance_id_b) == null:
		# Target was removed mid-snap
		_set_state(instance_id_a, State.IDLE)
		return

	_set_state(instance_id_a, State.EXECUTING)
	_combination_in_flight = true
	combination_attempted.emit(instance_id_a, instance_id_b)


# ── Combination Response (called by ITF) ─────────────────────────────────────

## Called by ITF when the recipe lookup succeeds.
## [param template] is "Additive", "Merge", "Animate", or "Generator".
func on_combination_succeeded(instance_id_a: String, instance_id_b: String,
		template: String, _config: Dictionary) -> void:
	_combination_in_flight = false

	match template:
		"Additive":
			_set_state(instance_id_a, State.IDLE)
			_set_state(instance_id_b, State.IDLE)
			var node_a := _get_node(instance_id_a)
			var node_b := _get_node(instance_id_b)
			if node_a != null: node_a.z_index = 0
			if node_b != null: node_b.z_index = 0

		"Merge":
			_begin_merge(instance_id_a, instance_id_b, String(_config.get("keeps", "")))

		_:
			# Animate / Generator — return to Idle for now; ITF drives further
			_set_state(instance_id_a, State.IDLE)
			_set_state(instance_id_b, State.IDLE)


## Called by ITF when no recipe matches the card pair.
func on_combination_failed(instance_id_a: String, _instance_id_b: String) -> void:
	_combination_in_flight = false
	_begin_push_away(instance_id_a, _instance_id_b)


## Called by ITF for the Reject template.
## Pushes both cards away from each other, scaled by push_multiplier.
func on_combination_rejected(instance_id_a: String, instance_id_b: String,
		push_multiplier: float = 1.0) -> void:
	_combination_in_flight = false
	_begin_push_away(instance_id_a, instance_id_b, push_multiplier)
	_begin_push_away(instance_id_b, instance_id_a, push_multiplier)


# ── Push-Away ─────────────────────────────────────────────────────────────────

func _begin_push_away(instance_id: String, target_id: String, push_multiplier: float = 1.0) -> void:
	var node        := _get_node(instance_id)
	var target_node := _get_node(target_id)
	if node == null:
		return

	_set_state(instance_id, State.PUSHED)

	var push_dir: Vector2
	if target_node != null:
		var delta := node.position - target_node.position
		push_dir = delta.normalized() if delta.length_squared() > 0.01 else Vector2.RIGHT
	else:
		push_dir = Vector2.RIGHT

	var bounds     := _get_table_bounds()
	var push_target := (node.position + push_dir * PUSH_DISTANCE * push_multiplier).clamp(
		bounds.position, bounds.position + bounds.size)

	var tween := node.create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "position", push_target, PUSH_DURATION_SEC)
	tween.tween_callback(func() -> void:
		_set_state(instance_id, State.IDLE)
		node.z_index = 0
	)


# ── Merge ─────────────────────────────────────────────────────────────────────

func _begin_merge(instance_id_a: String, instance_id_b: String, keeps_card_id: String = "") -> void:
	var node_a := _get_node(instance_id_a)
	var node_b := _get_node(instance_id_b)
	if node_a == null or node_b == null:
		return

	# Catalyst mode: when `keeps_card_id` matches one side, that side skips
	# the merge-animate entirely (no shrink, no fade, no move). The product
	# is ejected from the consumed card's last position instead of a midpoint.
	var card_id_a: String = _card_id_of(instance_id_a)
	var card_id_b: String = _card_id_of(instance_id_b)
	var a_is_kept: bool = keeps_card_id != "" and card_id_a == keeps_card_id
	var b_is_kept: bool = keeps_card_id != "" and card_id_b == keeps_card_id

	var midpoint: Vector2
	if a_is_kept:
		midpoint = node_b.position
	elif b_is_kept:
		midpoint = node_a.position
	else:
		midpoint = (node_a.position + node_b.position) * 0.5

	var expected: int = (0 if a_is_kept else 1) + (0 if b_is_kept else 1)
	if expected == 0:
		# Degenerate: both cards are "keeps" — emit immediately next frame.
		call_deferred("emit_signal", "merge_complete", instance_id_a, instance_id_b, midpoint)
		return

	var done := [0]
	var finish := func() -> void:
		done[0] += 1
		if done[0] == expected:
			merge_complete.emit(instance_id_a, instance_id_b, midpoint)

	if not a_is_kept:
		_animate_merge_card(node_a, midpoint, finish)
	if not b_is_kept:
		_animate_merge_card(node_b, midpoint, finish)


## Helper: read the node's card_id field (set by CardSpawning at spawn time).
## Falls back to parsing the instance_id "card_id_N" form if the node has no
## field — only used when the node is already detached.
func _card_id_of(instance_id: String) -> String:
	var node: Node2D = _get_node(instance_id)
	if node != null and "card_id" in node:
		return String(node.card_id)
	var idx: int = instance_id.rfind("_")
	if idx == -1:
		return instance_id
	return instance_id.left(idx)


func _animate_merge_card(node: Node2D, midpoint: Vector2, on_done: Callable) -> void:
	node.z_index = 50
	var tween := node.create_tween()
	tween.set_parallel(true)
	tween.tween_property(node, "position",  midpoint,      MERGE_DURATION_SEC).set_trans(Tween.TRANS_SINE)
	tween.tween_property(node, "scale",     Vector2.ZERO,  MERGE_DURATION_SEC).set_trans(Tween.TRANS_SINE)
	tween.tween_property(node, "modulate:a", 0.0,          MERGE_DURATION_SEC * 0.8)
	tween.set_parallel(false)
	tween.tween_callback(on_done)


# ── Helpers ───────────────────────────────────────────────────────────────────

## Public: returns the current state for an instance_id (IDLE if unknown).
func get_card_state(instance_id: String) -> State:
	return _states.get(instance_id, State.IDLE)


func _get_state(instance_id: String) -> State:
	return _states.get(instance_id, State.IDLE)


func _set_state(instance_id: String, state: State) -> void:
	_states[instance_id] = state


func _get_node(instance_id: String) -> Node2D:
	return CardSpawning.get_card_node(instance_id)


func _end_drag() -> void:
	_dragged_id     = ""
	_attract_target = ""


func _get_table_bounds() -> Rect2:
	var vp := get_viewport().get_visible_rect()
	return Rect2(vp.position + Vector2(80, 80), vp.size - Vector2(160, 160))
