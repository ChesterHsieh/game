# PROTOTYPE - NOT FOR PRODUCTION
# Question: Does reaching the sustain goal feel like a breakthrough or "task complete"?
# Date: 2026-03-27

extends Node2D

# ── RECIPES ───────────────────────────────────────────────────────────────────
const RECIPES = {
	"Chester+Ju":   {"template": "merge",    "result": "Morning Together", "color": Color(1.0, 0.92, 0.72)},
	"Chester+Home": {"template": "additive", "result": "Coffee",           "color": Color(0.72, 0.52, 0.32)},
	"Ju+Home":      {"template": "additive", "result": "Comfort",          "color": Color(0.88, 0.78, 0.88)},
}

const BAR_EFFECTS = {
	"Morning Together": {"chester": 60, "ju": 60},
	"Coffee":           {"chester": 18, "ju":  8},
	"Comfort":          {"chester":  8, "ju": 18},
}

# ── BAR / WIN TUNING ──────────────────────────────────────────────────────────
const MAX_BAR            = 100.0
const DECAY_RATE         = 0.5
const BAR_W              = 20.0
const BAR_H              = 160.0
const BAR_PADDING        = 16.0

const SUSTAIN_THRESHOLD  = 60.0   # both bars must be above this to hold
const SUSTAIN_DURATION   = 5.0    # seconds both must stay above threshold (production: 30s)

# ── WIN SEQUENCE TUNING ───────────────────────────────────────────────────────
const CARD_EXIT_DURATION = 0.9    # cards float up and fade out
const CARD_EXIT_RISE     = 120.0  # pixels cards rise during exit
const TITLE_FADE_IN      = 1.2    # title text fade-in duration
const TITLE_HOLD         = 2.5    # seconds title is fully visible
const SCENE_FADE_OUT     = 1.2    # fade to black duration
const RESTART_DELAY      = 0.8    # pause before restart

# ── STATE ─────────────────────────────────────────────────────────────────────
var _all_cards:      Array  = []
var _active:         Array  = []
var _dragged:        Node2D = null
var _bar_values             = {"chester": 20.0, "ju": 20.0}

var _sustain_timer:  float  = 0.0
var _scene_state:    String = "playing"   # playing | winning | done

# Win sequence draw state
var _title_alpha:    float  = 0.0
var _overlay_alpha:  float  = 0.0   # black fade overlay
var _win_timer:      float  = 0.0   # timer driving the win sequence phases

# ── SETUP ─────────────────────────────────────────────────────────────────────
func _ready() -> void:
	for child in $Cards.get_children():
		child.set_snap_callback(_on_snap_complete)
		_all_cards.append(child)
		if child.visible:
			_active.append(child)

func _input(event: InputEvent) -> void:
	if _scene_state != "playing":
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_try_pick_up(get_global_mouse_position())
		else:
			_release()

func _process(delta: float) -> void:
	match _scene_state:
		"playing":
			if _dragged != null:
				_dragged.update_position(get_global_mouse_position(), _active)
			_decay_bars(delta)
			_update_sustain(delta)
		"winning":
			_update_win_sequence(delta)
		"done":
			pass

	var bar_layer = $BarLayer
	bar_layer.bar_values    = _bar_values
	bar_layer.hint_alpha    = 0.0
	bar_layer.max_bar       = MAX_BAR
	bar_layer.threshold     = SUSTAIN_THRESHOLD
	bar_layer.sustain_timer = _sustain_timer
	bar_layer.sustain_max   = SUSTAIN_DURATION

	queue_redraw()

# ── SUSTAIN WIN DETECTION ─────────────────────────────────────────────────────
func _update_sustain(delta: float) -> void:
	var both_above = (_bar_values["chester"] >= SUSTAIN_THRESHOLD and
					  _bar_values["ju"]      >= SUSTAIN_THRESHOLD)
	if both_above:
		_sustain_timer += delta
		if _sustain_timer >= SUSTAIN_DURATION:
			_begin_win_sequence()
	else:
		_sustain_timer = 0.0

# ── WIN SEQUENCE ──────────────────────────────────────────────────────────────
func _begin_win_sequence() -> void:
	_scene_state = "winning"
	_win_timer   = 0.0
	_dragged     = null

	# Float all active cards up and fade them out
	for card in _active:
		var t = card.create_tween()
		t.set_parallel(true)
		t.tween_property(card, "position",   card.position + Vector2(0, -CARD_EXIT_RISE), CARD_EXIT_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		t.tween_property(card, "modulate:a", 0.0, CARD_EXIT_DURATION * 0.8)

func _update_win_sequence(delta: float) -> void:
	_win_timer += delta

	var title_start  = CARD_EXIT_DURATION + 0.2
	var fade_start   = title_start + TITLE_FADE_IN + TITLE_HOLD

	# Title fade in
	if _win_timer >= title_start:
		var t = clamp((_win_timer - title_start) / TITLE_FADE_IN, 0.0, 1.0)
		_title_alpha = t

	# Scene fade to black
	if _win_timer >= fade_start:
		var t = clamp((_win_timer - fade_start) / SCENE_FADE_OUT, 0.0, 1.0)
		_overlay_alpha = t

	# Restart
	if _win_timer >= fade_start + SCENE_FADE_OUT + RESTART_DELAY:
		_restart()

func _restart() -> void:
	get_tree().reload_current_scene()

# ── DRAW ──────────────────────────────────────────────────────────────────────
func _draw() -> void:
	var vw   = get_viewport().get_visible_rect().size.x
	var vh   = get_viewport().get_visible_rect().size.y
	var font = ThemeDB.fallback_font

	# Debug: sustain progress bar (top right)
	if _scene_state == "playing":
		var progress = clamp(_sustain_timer / SUSTAIN_DURATION, 0.0, 1.0)
		var pw = 160.0
		var ph = 8.0
		var px = vw - pw - 20
		var py = 20.0
		draw_rect(Rect2(px, py, pw, ph), Color(0.2, 0.2, 0.2, 0.6))
		if progress > 0:
			draw_rect(Rect2(px, py, pw * progress, ph), Color(1.0, 0.9, 0.4, 0.8))
		draw_rect(Rect2(px, py, pw, ph), Color(0.8, 0.8, 0.8, 0.4), false, 1.0)
		draw_string(font, Vector2(px, py - 4), "Hold both bars above 60 for %.0fs" % SUSTAIN_DURATION,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 1, 1, 0.5))

	# Win title
	if _title_alpha > 0.01:
		var title     = "A Morning Together"
		var font_size = 48
		var tw        = font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var tx        = (vw - tw) * 0.5
		var ty        = vh * 0.5 - 10

		# Soft backing glow
		draw_rect(Rect2(tx - 32, ty - font_size - 8, tw + 64, font_size + 24),
			Color(0.0, 0.0, 0.0, _title_alpha * 0.5))
		# Title text
		draw_string(font, Vector2(tx, ty), title,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size,
			Color(1.0, 0.96, 0.82, _title_alpha))

	# Black fade overlay
	if _overlay_alpha > 0.01:
		draw_rect(Rect2(0, 0, vw, vh), Color(0.0, 0.0, 0.0, _overlay_alpha))

# ── COMBINATION LOGIC ─────────────────────────────────────────────────────────
func _on_snap_complete(card_a: Node2D, card_b: Node2D) -> void:
	if card_a == null or card_b == null or _scene_state != "playing":
		return
	var labels = [card_a.card_label, card_b.card_label]
	labels.sort()
	var key = "+".join(labels)
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
