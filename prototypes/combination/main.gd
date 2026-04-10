# PROTOTYPE - NOT FOR PRODUCTION
# Question: Does combining two cards feel like a discovery?
# Date: 2026-03-25

extends Node2D

# ── HARDCODED RECIPES (stand-in for Recipe Database + ITF) ───────────────────
# key: sorted card labels joined with "+"
# template: "additive" (both cards stay, result spawns) | "merge" (both disappear)
const RECIPES = {
	"Chester+Ju":   {"template": "merge",    "result": "Morning Together", "color": Color(1.0, 0.92, 0.72)},
	"Chester+Home": {"template": "additive", "result": "Coffee",           "color": Color(0.72, 0.52, 0.32)},
	"Ju+Home":      {"template": "additive", "result": "Comfort",          "color": Color(0.88, 0.78, 0.88)},
}

# ── BAR EFFECTS (stand-in for bar-effects.json) ───────────────────────────────
const BAR_EFFECTS = {
	"Morning Together": {"chester": 20, "ju": 20},
	"Coffee":           {"chester": 12, "ju":  5},
	"Comfort":          {"chester":  5, "ju": 12},
}

# ── TUNING ────────────────────────────────────────────────────────────────────
const MAX_BAR      = 100.0
const DECAY_RATE   = 0.5      # points per second
const BAR_W        = 20.0
const BAR_H        = 160.0
const BAR_PADDING  = 16.0

# ── STATE ─────────────────────────────────────────────────────────────────────
var _all_cards:  Array  = []   # all card nodes (pool)
var _active:     Array  = []   # currently visible cards
var _dragged:    Node2D = null

var _bar_values = {"chester": 20.0, "ju": 20.0}

# ── SETUP ─────────────────────────────────────────────────────────────────────
func _ready() -> void:
	for child in $Cards.get_children():
		child.set_snap_callback(_on_snap_complete)
		_all_cards.append(child)
		if child.visible:       # pool cards start hidden — don't add to _active yet
			_active.append(child)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_try_pick_up(get_global_mouse_position())
		else:
			_release()

func _process(delta: float) -> void:
	if _dragged != null:
		_dragged.update_position(get_global_mouse_position(), _active)
	_decay_bars(delta)
	queue_redraw()

# ── DRAW (status bars) ────────────────────────────────────────────────────────
func _draw() -> void:
	var bar_names = ["chester", "ju"]
	var bar_colors = [Color(0.4, 0.6, 0.9), Color(0.9, 0.5, 0.6)]
	var base_x = get_viewport().get_visible_rect().size.x - (BAR_W + BAR_PADDING) * 2 - 20

	var vh = get_viewport().get_visible_rect().size.y
	for i in 2:
		var bx   = base_x + i * (BAR_W + BAR_PADDING)
		var val  = _bar_values[bar_names[i]]
		var fill = (val / MAX_BAR) * BAR_H
		var by   = vh - BAR_PADDING - BAR_H

		# Background
		draw_rect(Rect2(bx, by, BAR_W, BAR_H), Color(0.15, 0.15, 0.15, 0.6))
		# Fill (bottom up)
		if fill > 0:
			draw_rect(Rect2(bx, by + BAR_H - fill, BAR_W, fill), bar_colors[i])
		# Border
		draw_rect(Rect2(bx, by, BAR_W, BAR_H), Color(0.8, 0.8, 0.8, 0.5), false, 1.5)

# ── COMBINATION LOGIC ─────────────────────────────────────────────────────────
func _on_snap_complete(card_a: Node2D, card_b: Node2D) -> void:
	print("[main] snap_complete: card_a=", card_a, " card_b=", card_b)
	if card_a == null or card_b == null:
		return

	# Build recipe key from sorted card labels
	var labels = [card_a.card_label, card_b.card_label]
	labels.sort()
	var key = "+".join(labels)
	print("[main] recipe key='", key, "' found=", RECIPES.has(key))

	if not RECIPES.has(key):
		# No recipe — push away
		card_a.push_away()
		return

	var recipe = RECIPES[key]
	_apply_bar_effects(recipe["result"])

	if recipe["template"] == "merge":
		_do_merge(card_a, card_b, recipe)
	else:
		_do_additive(card_a, card_b, recipe)

func _do_merge(card_a: Node2D, card_b: Node2D, recipe: Dictionary) -> void:
	var midpoint = (card_a.position + card_b.position) * 0.5
	var done_count = [0]  # mutable counter via array

	var finish = func() -> void:
		done_count[0] += 1
		if done_count[0] == 2:
			_retire_card(card_a)
			_retire_card(card_b)
			_spawn_card(recipe["result"], recipe["color"], midpoint)

	card_a.merge_out(midpoint, finish)
	card_b.merge_out(midpoint, finish)

func _do_additive(card_a: Node2D, card_b: Node2D, recipe: Dictionary) -> void:
	# Both cards stay; result spawns nearby
	card_a.state = "idle"
	card_b.state = "idle"
	var spawn_pos = card_b.position + Vector2(100, 0)
	_spawn_card(recipe["result"], recipe["color"], spawn_pos)

func _apply_bar_effects(result_label: String) -> void:
	if not BAR_EFFECTS.has(result_label):
		return
	var effects = BAR_EFFECTS[result_label]
	for bar_id in effects:
		if _bar_values.has(bar_id):
			_bar_values[bar_id] = clamp(_bar_values[bar_id] + effects[bar_id], 0, MAX_BAR)

func _decay_bars(delta: float) -> void:
	for bar_id in _bar_values:
		_bar_values[bar_id] = clamp(_bar_values[bar_id] - 0.5 * delta, 0, MAX_BAR)

# ── CARD POOL ─────────────────────────────────────────────────────────────────
func _spawn_card(label: String, color: Color, pos: Vector2) -> void:
	# Find a hidden (retired) card to reuse
	for card in _all_cards:
		if not card.visible:
			card.reset(label, color, pos)
			if not _active.has(card):
				_active.append(card)
			return
	# Pool exhausted — log warning (shouldn't happen in prototype)
	push_warning("Card pool exhausted!")

func _retire_card(card: Node2D) -> void:
	card.retire()
	_active.erase(card)

# ── DRAG ──────────────────────────────────────────────────────────────────────
func _try_pick_up(mouse_pos: Vector2) -> void:
	print("[main] try_pick_up, active_count=", _active.size())
	var best: Node2D = null
	var best_z: int  = -999
	for card in _active:
		if card.state != "idle" or not card.visible:
			continue
		var local = card.to_local(mouse_pos)
		if abs(local.x) <= card.CARD_W * 0.5 and abs(local.y) <= card.CARD_H * 0.5:
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
