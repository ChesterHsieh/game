# PROTOTYPE - NOT FOR PRODUCTION
# Question: Does magnetic snap attraction feel right?
# Date: 2026-03-25

extends Node2D

# ── TUNING KNOBS ─────────────────────────────────────────────────────────────
# Change these freely during testing to find the right feel
const SNAP_RADIUS        = 80.0   # px — how close before attraction begins
const ATTRACTION_FACTOR  = 0.4   # 0.0 = no pull, 0.5 = halfway to target
const SNAP_DURATION      = 0.12   # sec — snap tween speed
const PUSH_DISTANCE      = 40.0   # px — how far card bounces on failure
const PUSH_DURATION      = 0.18   # sec — push-away tween speed
const CARD_W             = 80.0
const CARD_H             = 120.0

# ── CARD CONFIG ───────────────────────────────────────────────────────────────
@export var card_label: String = "Card"
@export var card_color: Color  = Color(0.95, 0.90, 0.75)

# ── STATE ─────────────────────────────────────────────────────────────────────
# String states for easy cross-script access
var state: String = "idle"  # idle | dragged | attracting | snapping | pushed
var drag_offset:  Vector2 = Vector2.ZERO
var attracted_to: Node2D  = null
var _tween:       Tween   = null
var _base_z:      int     = 0

# ── VISUAL ────────────────────────────────────────────────────────────────────
func _draw() -> void:
	var half = Vector2(CARD_W * 0.5, CARD_H * 0.5)
	var rect = Rect2(-half, Vector2(CARD_W, CARD_H))

	# Card body
	draw_rect(rect, card_color)

	# Drop shadow hint when lifted (draw before border so it's underneath)
	if state in ["dragged", "attracting", "snapping"]:
		var shadow_rect = Rect2(-half + Vector2(4, 6), Vector2(CARD_W, CARD_H))
		draw_rect(shadow_rect, Color(0, 0, 0, 0.25))
		draw_rect(rect, card_color)  # redraw card on top of shadow

	# Border
	var border_w = 2.5 if state in ["dragged", "attracting", "snapping"] else 1.5
	draw_rect(rect, Color(0.15, 0.1, 0.05), false, border_w)

	# Circular art placeholder
	draw_circle(Vector2(0, 12), 26, Color(0.65, 0.78, 0.82))
	draw_arc(Vector2(0, 12), 26, 0, TAU, 32, Color(0.3, 0.3, 0.3), 1.2)

	# Card label at top
	var font = ThemeDB.fallback_font
	draw_string(font,
		Vector2(-CARD_W * 0.5 + 5, -CARD_H * 0.5 + 15),
		card_label,
		HORIZONTAL_ALIGNMENT_LEFT, CARD_W - 10, 12,
		Color(0.1, 0.05, 0.0))

	# Attraction ring — visible feedback that snap is possible
	if state == "attracting":
		draw_arc(Vector2.ZERO, CARD_W * 0.62, 0, TAU, 40,
			Color(1.0, 0.88, 0.3, 0.55), 2.2)

func _process(_delta: float) -> void:
	queue_redraw()

# ── PUBLIC INTERFACE (called by main.gd) ──────────────────────────────────────
func pick_up(offset: Vector2) -> void:
	state      = "dragged"
	drag_offset = offset
	scale      = Vector2(1.05, 1.05)
	_base_z    = z_index
	z_index    = 100
	if _tween:
		_tween.kill()

func update_position(cursor_world: Vector2, all_cards: Array) -> void:
	if state not in ["dragged", "attracting"]:
		return

	var target_pos = cursor_world + drag_offset

	# Find nearest idle card within snap radius
	var nearest:      Node2D = null
	var nearest_dist: float  = INF
	for other in all_cards:
		if other == self or other.state != "idle":
			continue
		var dist = target_pos.distance_to(other.position)
		if dist < SNAP_RADIUS and dist < nearest_dist:
			nearest      = other
			nearest_dist = dist

	if nearest != null:
		state        = "attracting"
		attracted_to = nearest
		position     = lerp(target_pos, nearest.position, ATTRACTION_FACTOR)
	else:
		state        = "dragged"
		attracted_to = null
		position     = target_pos

func release() -> void:
	scale   = Vector2.ONE
	z_index = _base_z

	if state == "attracting" and attracted_to != null:
		_do_snap()
	else:
		state        = "idle"
		attracted_to = null

# ── PRIVATE ───────────────────────────────────────────────────────────────────
func _do_snap() -> void:
	state = "snapping"
	# Offset slightly so both cards remain visible
	var snap_pos = attracted_to.position + Vector2(16, 16)
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_SINE)
	_tween.set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "position", snap_pos, SNAP_DURATION)
	_tween.tween_callback(_on_snap_complete)

func _on_snap_complete() -> void:
	state = "idle"
	# Prototype: 50/50 success vs push-away so both paths can be tested
	# In production this comes from ITF's combination_succeeded/failed signal
	if randf() > 0.5:
		_do_push_away()
	# else: success — cards stay together (Additive template)

func _do_push_away() -> void:
	state = "pushed"
	if attracted_to == null:
		state = "idle"
		return
	var push_dir    = (position - attracted_to.position).normalized()
	var push_target = position + push_dir * PUSH_DISTANCE
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_QUAD)
	_tween.set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "position", push_target, PUSH_DURATION)
	_tween.tween_callback(func() -> void:
		state        = "idle"
		attracted_to = null
	)
