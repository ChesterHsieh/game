## StatusBarUI — visual layer for two progress bars and their hint arcs.
## Not an autoload. Added to game scene as a left-side panel.
## Implements: design/gdd/status-bar-ui.md

extends Node2D

# ── Tuning ────────────────────────────────────────────────────────────────────

const PANEL_WIDTH_PX  := 180.0
const BAR_HEIGHT_PX   := 120.0
const BAR_WIDTH_PX    := 24.0
const BAR_TWEEN_SEC   := 0.15
const ARC_FAINT_OPACITY := 0.3
const ARC_FADE_SEC    := 1.5

# ── Colors ────────────────────────────────────────────────────────────────────

const COLOR_PANEL_BG  := Color(0.18, 0.16, 0.14, 0.85)
const COLOR_BAR_BG    := Color(0.30, 0.27, 0.24, 1.0)
const COLOR_BAR_FILL  := Color(0.82, 0.68, 0.42, 1.0)   ## warm amber
const COLOR_ARC       := Color(0.95, 0.88, 0.60, 1.0)   ## soft gold

# ── State ─────────────────────────────────────────────────────────────────────

enum UIState { DORMANT, ACTIVE, FROZEN }
var _state: UIState = UIState.DORMANT

## bar_id -> float (0.0–max_value), displayed fill value
var _fill_values:  Dictionary = {}

## bar_id -> float (0.0–max_value), target fill value being tweened toward
var _target_values: Dictionary = {}

## bar_id -> Tween (active fill tween, or null)
var _fill_tweens: Dictionary = {}

## Ordered list of bar_ids (for layout)
var _bar_ids: Array[String] = []

## max_value for this scene
var _max_value: float = 100.0

## 0.0–1.0, current arc opacity (tweened)
var _arc_opacity: float = 0.0

## Active arc tween (or null)
var _arc_tween: Tween = null


# ── Setup ─────────────────────────────────────────────────────────────────────

func _ready() -> void:
	StatusBarSystem.bar_values_changed.connect(_on_bar_values_changed)
	HintSystem.hint_level_changed.connect(_on_hint_level_changed)
	SceneGoal.scene_completed.connect(_on_scene_completed)


# ── Public API ────────────────────────────────────────────────────────────────

## Called on scene load to configure bars. Reads from SceneGoal.get_goal_config().
func configure_for_scene() -> void:
	var config := SceneGoal.get_goal_config()
	var goal_type: String = config.get("type", "")

	if goal_type not in ["sustain_above", "reach_value"]:
		_state = UIState.DORMANT
		queue_redraw()
		return

	_max_value = float(config.get("max_value", 100.0))
	var bars: Array = config.get("bars", [])

	_bar_ids.clear()
	_fill_values.clear()
	_target_values.clear()
	_fill_tweens.clear()
	_arc_opacity = 0.0

	if bars.is_empty():
		push_warning("StatusBarUI: bar goal has no bars defined")
		_state = UIState.DORMANT
		queue_redraw()
		return

	for bar: Dictionary in bars:
		var bar_id: String = bar.get("id", "")
		if bar_id == "":
			continue
		_bar_ids.append(bar_id)
		var initial: float = float(bar.get("initial_value", 0.0))
		_fill_values[bar_id]   = initial
		_target_values[bar_id] = initial

	_state = UIState.ACTIVE
	queue_redraw()


## Reset to dormant (called on scene transition).
func reset() -> void:
	for bar_id: String in _fill_tweens:
		var tw = _fill_tweens[bar_id]
		if tw != null and tw.is_valid():
			tw.kill()
	_fill_tweens.clear()

	if _arc_tween != null and _arc_tween.is_valid():
		_arc_tween.kill()
	_arc_tween = null

	_bar_ids.clear()
	_fill_values.clear()
	_target_values.clear()
	_arc_opacity = 0.0
	_state       = UIState.DORMANT
	queue_redraw()


# ── Signal Handlers ───────────────────────────────────────────────────────────

func _on_bar_values_changed(values: Dictionary) -> void:
	if _state != UIState.ACTIVE:
		return

	for bar_id: String in values:
		if not _fill_values.has(bar_id):
			continue

		var new_target: float = float(values[bar_id])
		_target_values[bar_id] = new_target

		# Cancel existing tween for this bar, start a new one from current displayed value
		var existing = _fill_tweens.get(bar_id)
		if existing != null and existing.is_valid():
			existing.kill()

		var from_val: float = float(_fill_values[bar_id])
		var tween := create_tween()
		tween.tween_method(
			func(v: float) -> void:
				_fill_values[bar_id] = v
				queue_redraw(),
			from_val, new_target, BAR_TWEEN_SEC
		)
		_fill_tweens[bar_id] = tween


func _on_hint_level_changed(level: int) -> void:
	var target_opacity: float
	match level:
		0: target_opacity = 0.0
		1: target_opacity = ARC_FAINT_OPACITY
		_: target_opacity = 1.0   ## level 2+

	if _arc_tween != null and _arc_tween.is_valid():
		_arc_tween.kill()

	var from_opacity: float = _arc_opacity
	_arc_tween = create_tween()
	_arc_tween.tween_method(
		func(v: float) -> void:
			_arc_opacity = v
			queue_redraw(),
		from_opacity, target_opacity, ARC_FADE_SEC
	)


func _on_scene_completed(_scene_id: String) -> void:
	_state = UIState.FROZEN
	# Cancel fill tweens — freeze at current displayed values
	for bar_id: String in _fill_tweens:
		var tw = _fill_tweens[bar_id]
		if tw != null and tw.is_valid():
			tw.kill()
	_fill_tweens.clear()
	queue_redraw()


# ── Rendering ─────────────────────────────────────────────────────────────────

func _draw() -> void:
	# Panel background
	draw_rect(Rect2(0.0, 0.0, PANEL_WIDTH_PX, _panel_height()), COLOR_PANEL_BG)

	if _state == UIState.DORMANT or _bar_ids.is_empty():
		return

	var count := _bar_ids.size()
	for i in range(count):
		var bar_id: String = _bar_ids[i]
		var bar_x  := _bar_x(i, count)
		var bar_top := _bar_top()
		_draw_bar(bar_x, bar_top, bar_id)


func _draw_bar(bar_x: float, bar_top: float, bar_id: String) -> void:
	# Background track
	draw_rect(
		Rect2(bar_x, bar_top, BAR_WIDTH_PX, BAR_HEIGHT_PX),
		COLOR_BAR_BG
	)

	# Fill — bottom to top
	var current: float = float(_fill_values.get(bar_id, 0.0))
	var fill_h := (current / _max_value) * BAR_HEIGHT_PX
	fill_h = clampf(fill_h, 0.0, BAR_HEIGHT_PX)
	if fill_h > 0.0:
		draw_rect(
			Rect2(bar_x, bar_top + BAR_HEIGHT_PX - fill_h, BAR_WIDTH_PX, fill_h),
			COLOR_BAR_FILL
		)

	# Track border
	draw_rect(Rect2(bar_x, bar_top, BAR_WIDTH_PX, BAR_HEIGHT_PX), COLOR_BAR_BG, false, 1.0)

	# Hint arc — counterclockwise around bar border, starting from top
	if _arc_opacity > 0.001:
		var arc_color := Color(COLOR_ARC.r, COLOR_ARC.g, COLOR_ARC.b, _arc_opacity)
		_draw_bar_arc(bar_x, bar_top, arc_color)


func _draw_bar_arc(bar_x: float, bar_top: float, arc_color: Color) -> void:
	## Counterclockwise rect perimeter arc via polyline around the bar's border.
	## Starts at top-left, goes: left down → bottom-left → right → top-right → top across.
	## Full perimeter = one glowing frame; partial would require parametric trimming.
	## For MVP: draw the full perimeter as a glow at arc_opacity.
	var pad  := 2.0   ## small outset so arc sits just outside the bar
	var x0   := bar_x - pad
	var y0   := bar_top - pad
	var x1   := bar_x + BAR_WIDTH_PX + pad
	var y1   := bar_top + BAR_HEIGHT_PX + pad

	## Counterclockwise: top-right → top-left → bottom-left → bottom-right → top-right
	var pts: PackedVector2Array = [
		Vector2(x1, y0),   ## top-right
		Vector2(x0, y0),   ## top-left
		Vector2(x0, y1),   ## bottom-left
		Vector2(x1, y1),   ## bottom-right
		Vector2(x1, y0),   ## back to top-right (close loop)
	]
	draw_polyline(pts, arc_color, 2.0)


# ── Layout Helpers ────────────────────────────────────────────────────────────

func _panel_height() -> float:
	return get_viewport().get_visible_rect().size.y


func _bar_top() -> float:
	## Centers the bar group vertically in the panel.
	return (_panel_height() - BAR_HEIGHT_PX) * 0.5


func _bar_x(index: int, total: int) -> float:
	## Stacks bars vertically within the panel (one column, centered horizontally).
	## For MVP with two bars: renders them as a horizontal pair centered in panel.
	var total_width := float(total) * BAR_WIDTH_PX + float(total - 1) * 12.0
	var start_x     := (PANEL_WIDTH_PX - total_width) * 0.5
	return start_x + float(index) * (BAR_WIDTH_PX + 12.0)
