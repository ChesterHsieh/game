# PROTOTYPE - NOT FOR PRODUCTION
# Question: Does combining two cards feel like a discovery?
# Date: 2026-03-25

extends Node2D

# ── TUNING KNOBS (validated from card-engine prototype) ───────────────────────
const SNAP_RADIUS        = 80.0
const ATTRACTION_FACTOR  = 0.4
const SNAP_DURATION      = 0.12
const PUSH_DISTANCE      = 60.0
const PUSH_DURATION      = 0.18
const MERGE_DURATION     = 0.55
const CARD_W             = 80.0
const CARD_H             = 120.0

# ── CARD CONFIG ───────────────────────────────────────────────────────────────
@export var card_label: String = "Card"
@export var card_color: Color  = Color(0.95, 0.90, 0.75)

# ── STATE ─────────────────────────────────────────────────────────────────────
var state:        String  = "idle"
var drag_offset:  Vector2 = Vector2.ZERO
var attracted_to: Node2D  = null
var _tween:       Tween   = null
var _base_z:      int     = 0

# ── DRAW ──────────────────────────────────────────────────────────────────────
func _draw() -> void:
	var half = Vector2(CARD_W * 0.5, CARD_H * 0.5)
	var rect = Rect2(-half, Vector2(CARD_W, CARD_H))

	draw_rect(rect, card_color)

	if state in ["dragged", "attracting", "snapping"]:
		var shadow = Rect2(-half + Vector2(4, 6), Vector2(CARD_W, CARD_H))
		draw_rect(shadow, Color(0, 0, 0, 0.25))
		draw_rect(rect, card_color)

	var border_w = 2.5 if state in ["dragged", "attracting", "snapping"] else 1.5
	draw_rect(rect, Color(0.15, 0.1, 0.05), false, border_w)

	draw_circle(Vector2(0, 12), 26, Color(0.65, 0.78, 0.82))
	draw_arc(Vector2(0, 12), 26, 0, TAU, 32, Color(0.3, 0.3, 0.3), 1.2)

	var font = ThemeDB.fallback_font
	draw_string(font,
		Vector2(-CARD_W * 0.5 + 5, -CARD_H * 0.5 + 15),
		card_label,
		HORIZONTAL_ALIGNMENT_LEFT, CARD_W - 10, 12,
		Color(0.1, 0.05, 0.0))

	if state == "attracting":
		draw_arc(Vector2.ZERO, CARD_W * 0.62, 0, TAU, 40,
			Color(1.0, 0.88, 0.3, 0.55), 2.2)

func _process(_delta: float) -> void:
	queue_redraw()

# ── PUBLIC INTERFACE ──────────────────────────────────────────────────────────
func pick_up(offset: Vector2) -> void:
	print("[card] pick_up: ", card_label)
	state       = "dragged"
	drag_offset = offset
	scale       = Vector2(1.05, 1.05)
	_base_z     = z_index
	z_index     = 100
	if _tween:
		_tween.kill()

func update_position(cursor_world: Vector2, all_cards: Array) -> void:
	if state not in ["dragged", "attracting"]:
		return
	var target_pos = cursor_world + drag_offset
	var nearest: Node2D = null
	var nearest_dist: float = INF
	for other in all_cards:
		if other == self or other.state != "idle" or not other.visible:
			continue
		var dist = target_pos.distance_to(other.position)
		if dist < SNAP_RADIUS and dist < nearest_dist:
			nearest      = other
			nearest_dist = dist
	if nearest != null:
		if state != "attracting":
			print("[card] ", card_label, " attracted to ", nearest.card_label)
		state        = "attracting"
		attracted_to = nearest
		position     = lerp(target_pos, nearest.position, ATTRACTION_FACTOR)
	else:
		state        = "dragged"
		attracted_to = null
		position     = target_pos

func release() -> void:
	print("[card] release: ", card_label, " state=", state, " attracted_to=", attracted_to)
	scale   = Vector2.ONE
	z_index = _base_z
	if state == "attracting" and attracted_to != null:
		_do_snap()
	else:
		state        = "idle"
		attracted_to = null

# Called by main when ITF says combination failed
func push_away() -> void:
	state = "pushed"
	if attracted_to == null:
		state = "idle"
		return
	var push_dir    = (position - attracted_to.position).normalized()
	var push_target = position + push_dir * PUSH_DISTANCE
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "position", push_target, PUSH_DURATION)
	_tween.tween_callback(func() -> void:
		state        = "idle"
		attracted_to = null
	)

# Called by main when ITF says Merge template
func merge_out(midpoint: Vector2, on_complete: Callable) -> void:
	state = "merging"
	z_index = 50
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(self, "position", midpoint, MERGE_DURATION).set_trans(Tween.TRANS_SINE)
	_tween.tween_property(self, "scale", Vector2.ZERO, MERGE_DURATION).set_trans(Tween.TRANS_SINE)
	_tween.tween_property(self, "modulate:a", 0.0, MERGE_DURATION * 0.8)
	_tween.set_parallel(false)
	_tween.tween_callback(on_complete)

# Called by main to reset card for pool reuse
func reset(label: String, color: Color, pos: Vector2) -> void:
	card_label   = label
	card_color   = color
	position     = pos
	state        = "idle"
	scale        = Vector2.ONE
	modulate.a   = 1.0
	z_index      = 0
	attracted_to = null
	show()

func retire() -> void:
	state = "idle"
	hide()

# ── PRIVATE ───────────────────────────────────────────────────────────────────
# Returns the snap tween so main can wait for completion
func _do_snap() -> void:
	state = "snapping"
	var snap_pos = attracted_to.position + Vector2(16, 16)
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "position", snap_pos, SNAP_DURATION)
	_tween.tween_callback(_on_snap_complete)

func _on_snap_complete() -> void:
	print("[card] snap complete: ", card_label, " attracted_to=", attracted_to, " callback_valid=", _snap_callback.is_valid())
	state = "idle"
	if _snap_callback.is_valid():
		_snap_callback.call(self, attracted_to)

var _snap_callback: Callable = Callable()

func set_snap_callback(cb: Callable) -> void:
	_snap_callback = cb
