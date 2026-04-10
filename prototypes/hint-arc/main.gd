# PROTOTYPE - NOT FOR PRODUCTION
# Question: Does the hint arc feel like a nudge or a spoiler?
#           What stagnation delay feels right?
# Date: 2026-03-27

extends Node2D

# ── RECIPES ───────────────────────────────────────────────────────────────────
const RECIPES = {
	"Chester+Ju":   {"template": "merge",    "result": "Morning Together", "color": Color(1.0, 0.92, 0.72)},
	"Chester+Home": {"template": "additive", "result": "Coffee",           "color": Color(0.72, 0.52, 0.32)},
	"Ju+Home":      {"template": "additive", "result": "Comfort",          "color": Color(0.88, 0.78, 0.88)},
}

const BAR_EFFECTS = {
	"Morning Together": {"chester": 20, "ju": 20},
	"Coffee":           {"chester": 12, "ju":  5},
	"Comfort":          {"chester":  5, "ju": 12},
}

# ── TUNING ────────────────────────────────────────────────────────────────────
const MAX_BAR        = 100.0
const DECAY_RATE     = 0.5
const BAR_W          = 20.0
const BAR_H          = 160.0
const BAR_PADDING    = 16.0

# HINT TUNING — adjust these to find the right feel
const HINT_DELAY     = 6.0    # seconds of no combo before Level 1 arc appears
							   # (production default: 300s — compressed for testing)
const HINT_FADE_IN   = 1.5    # seconds to fade in the arc
const ARC_ALPHA_L1   = 0.45   # arc opacity at Level 1 (faint)
const ARC_ALPHA_L2   = 0.90   # arc opacity at Level 2 (full)
const ARC_RADIUS_PAD = 14.0   # how far the arc extends beyond the bar half-height

# ── STATE ─────────────────────────────────────────────────────────────────────
var _all_cards:  Array  = []
var _active:     Array  = []
var _dragged:    Node2D = null

var _bar_values = {"chester": 20.0, "ju": 20.0}

# Hint state
var _stagnation_timer: float = 0.0
var _hint_level:       int   = 0       # 0=hidden, 1=faint, 2=full
var _hint_alpha:       float = 0.0     # current drawn alpha (lerped)
var _hint_target:      float = 0.0     # target alpha for lerp

# ── SETUP ─────────────────────────────────────────────────────────────────────
func _ready() -> void:
	for child in $Cards.get_children():
		child.set_snap_callback(_on_snap_complete)
		_all_cards.append(child)
		if child.visible:
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
	_update_hint(delta)

	# Push state to BarLayer (draws on top of Background)
	var bar_layer = $BarLayer
	bar_layer.bar_values = _bar_values
	bar_layer.hint_alpha = _hint_alpha
	bar_layer.max_bar    = MAX_BAR

	queue_redraw()

# ── HINT LOGIC ────────────────────────────────────────────────────────────────
func _update_hint(delta: float) -> void:
	# Advance stagnation timer
	_stagnation_timer += delta

	# Check level transitions (only advance, never regress here)
	if _hint_level < 2 and _stagnation_timer >= HINT_DELAY * 2.0:
		_set_hint_level(2)
	elif _hint_level < 1 and _stagnation_timer >= HINT_DELAY:
		_set_hint_level(1)

	# Lerp drawn alpha toward target
	_hint_alpha = lerp(_hint_alpha, _hint_target, delta / HINT_FADE_IN)

func _set_hint_level(level: int) -> void:
	_hint_level = level
	match level:
		0: _hint_target = 0.0
		1: _hint_target = ARC_ALPHA_L1
		2: _hint_target = ARC_ALPHA_L2
	print("[hint] level -> ", level, "  (alpha target: ", _hint_target, ")")

func _reset_hint() -> void:
	_stagnation_timer = 0.0
	_set_hint_level(0)

# ── DRAW (debug text only — bars drawn by BarLayer child) ────────────────────
func _draw() -> void:
	var font = ThemeDB.fallback_font
	var timer_text = "Hint timer: %.1fs  Level: %d" % [_stagnation_timer, _hint_level]
	draw_string(font, Vector2(16, 30), timer_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.7))
	var threshold_text = "L1 at %.0fs   L2 at %.0fs   (HINT_DELAY = %.0f)" % [HINT_DELAY, HINT_DELAY * 2.0, HINT_DELAY]
	draw_string(font, Vector2(16, 50), threshold_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.45))

# ── COMBINATION LOGIC ─────────────────────────────────────────────────────────
func _on_snap_complete(card_a: Node2D, card_b: Node2D) -> void:
	if card_a == null or card_b == null:
		return

	var labels = [card_a.card_label, card_b.card_label]
	labels.sort()
	var key = "+".join(labels)

	_reset_hint()   # any combination resets the hint clock

	if not RECIPES.has(key):
		card_a.push_away()
		return

	var recipe = RECIPES[key]
	_apply_bar_effects(recipe["result"])

	if recipe["template"] == "merge":
		_do_merge(card_a, card_b, recipe)
	else:
		_do_additive(card_a, card_b, recipe)

func _do_merge(card_a: Node2D, card_b: Node2D, recipe: Dictionary) -> void:
	var midpoint   = (card_a.position + card_b.position) * 0.5
	var done_count = [0]
	var finish = func() -> void:
		done_count[0] += 1
		if done_count[0] == 2:
			_retire_card(card_a)
			_retire_card(card_b)
			_spawn_card(recipe["result"], recipe["color"], midpoint)
	card_a.merge_out(midpoint, finish)
	card_b.merge_out(midpoint, finish)

func _do_additive(card_a: Node2D, card_b: Node2D, recipe: Dictionary) -> void:
	card_a.state = "idle"
	card_b.state = "idle"
	_spawn_card(recipe["result"], recipe["color"], card_b.position + Vector2(100, 0))

func _apply_bar_effects(result_label: String) -> void:
	if not BAR_EFFECTS.has(result_label):
		return
	for bar_id in BAR_EFFECTS[result_label]:
		if _bar_values.has(bar_id):
			_bar_values[bar_id] = clamp(_bar_values[bar_id] + BAR_EFFECTS[result_label][bar_id], 0, MAX_BAR)

func _decay_bars(delta: float) -> void:
	for bar_id in _bar_values:
		_bar_values[bar_id] = clamp(_bar_values[bar_id] - DECAY_RATE * delta, 0, MAX_BAR)

# ── CARD POOL ─────────────────────────────────────────────────────────────────
func _spawn_card(label: String, color: Color, pos: Vector2) -> void:
	for card in _all_cards:
		if not card.visible:
			card.reset(label, color, pos)
			if not _active.has(card):
				_active.append(card)
			return
	push_warning("Card pool exhausted!")

func _retire_card(card: Node2D) -> void:
	card.retire()
	_active.erase(card)

# ── DRAG ──────────────────────────────────────────────────────────────────────
func _try_pick_up(mouse_pos: Vector2) -> void:
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
