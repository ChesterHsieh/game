# PROTOTYPE - NOT FOR PRODUCTION
# Question: Does magnetic snap attraction feel right?
# Date: 2026-03-25

extends Node2D

# ── STATE ─────────────────────────────────────────────────────────────────────
var _card_nodes: Array  = []
var _dragged:    Node2D = null

# ── SETUP ─────────────────────────────────────────────────────────────────────
func _ready() -> void:
	# Collect all card nodes from the Cards container
	for child in $Cards.get_children():
		_card_nodes.append(child)

# ── INPUT ─────────────────────────────────────────────────────────────────────
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_try_pick_up(get_global_mouse_position())
		else:
			_release()

func _process(_delta: float) -> void:
	if _dragged != null:
		_dragged.update_position(get_global_mouse_position(), _card_nodes)

# ── PRIVATE ───────────────────────────────────────────────────────────────────
func _try_pick_up(mouse_pos: Vector2) -> void:
	# Find the topmost idle card whose rect contains the mouse
	var best:   Node2D = null
	var best_z: int    = -999

	for card in _card_nodes:
		if card.state != "idle":
			continue
		var local = card.to_local(mouse_pos)
		var hw    = card.CARD_W * 0.5
		var hh    = card.CARD_H * 0.5
		if abs(local.x) <= hw and abs(local.y) <= hh:
			if card.z_index > best_z:
				best   = card
				best_z = card.z_index

	if best != null:
		_dragged = best
		best.pick_up(best.position - mouse_pos)

func _release() -> void:
	if _dragged != null:
		_dragged.release()
		_dragged = null
