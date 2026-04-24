## StatusBarUI — visual layer for two progress bars and their hint arcs.
##
## Implements: design/gdd/status-bar-ui.md
## Stories:
##   001 — Scene configure and state machine
##   002 — Bar fill animation
##   003 — Hint arc animation
##   004 — Non-bar scenes and signal isolation
##
## Not an autoload. Added to gameplay scene as a left-side panel (HudLayer).
## Pure display component — emits nothing to EventBus. Leaf node.
##
## State machine:
##   Dormant → (bar goal scene loads, get_goal_config() returns bars) → Active
##   Active  → (win_condition_met)                                    → Frozen
##   Any     → (scene_loading)                                        → Dormant
##
## EventBus subscriptions (read-only, never emits):
##   bar_values_changed  — updates bar fill via tween (Active only)
##   hint_level_changed  — updates arc opacity via tween (Active only; stores level while Dormant)
##   scene_loading       — resets to Dormant
##   win_condition_met   — freezes at current fill

class_name StatusBarUI
extends Node2D

# ── Tuning (exported for in-editor tuning without code changes) ───────────────

## Pixel height of each bar at 100% fill. GDD default: 120px (halved for
## 720x450 logical viewport to keep the left panel from dominating the screen).
@export var bar_height_px: float = 60.0

## Pixel width of each bar. GDD default: 24px.
@export var bar_width_px: float = 20.0

## Font size for the bar label text (drawn below the bar).
@export var bar_label_font_size: int = 12

## Vertical gap between the bar and its label text in pixels.
@export var bar_label_gap_px: float = 8.0

## Duration of the bar fill animation in seconds. GDD default: 0.15s.
@export var bar_tween_sec: float = 0.15

## Arc opacity at hint Level 1 (faint). GDD default: 0.3.
@export var arc_faint_opacity: float = 0.3

## Duration of the arc fade tween in seconds. GDD default: 1.5s.
@export var arc_fade_sec: float = 1.5

## Width of the left-side panel in pixels. GDD default: 180px (halved for
## the 720x450 viewport — see bar_height_px note).
@export var panel_width_px: float = 90.0

# ── Colors ────────────────────────────────────────────────────────────────────
# Parchment aesthetic (Art Bible §4): cream translucent panel, warm ink-brown
# outline, warm amber fill. Replaces the previous dark-wood style so the bar
# blends with the scene's parchment ambient plate instead of fighting it.

const COLOR_PANEL_BG  := Color(0.96, 0.93, 0.87, 0.55)  ## warm cream parchment, semi-transparent
const COLOR_BAR_BG    := Color(0.40, 0.28, 0.20, 1.0)   ## warm ink-brown outline
const COLOR_BAR_FILL  := Color(0.82, 0.68, 0.42, 1.0)   ## warm amber
const COLOR_BAR_LABEL := Color(0.25, 0.18, 0.12, 1.0)   ## dark ink for label text
const COLOR_TICK      := Color(0.45, 0.33, 0.25, 0.75)  ## muted ink for integer tick marks
const COLOR_ARC       := Color(0.95, 0.88, 0.60, 1.0)   ## soft gold

## Full opacity constant used for Level 2 arc.
const ARC_OPACITY_FULL: float = 1.0

# ── State machine ─────────────────────────────────────────────────────────────

## Dormant: panel visible but empty; no bars rendered; signals ignored.
## Active:  bar goal scene loaded; bars rendered and updating.
## Frozen:  win condition met; bars visible at final values; no further updates.
enum UIState { DORMANT, ACTIVE, FROZEN }

var _state: UIState = UIState.DORMANT

# ── Bar data ──────────────────────────────────────────────────────────────────

## Ordered list of bar IDs (determines layout order).
var _bar_ids: Array[String] = []

## bar_id → display label (String). Falls back to the bar_id itself if the
## scene JSON does not supply a "label" field.
var _bar_labels: Dictionary = {}

## Cached CJK-capable SystemFont for label rendering — ThemeDB.fallback_font
## is Latin-only and cannot draw Chinese labels. Lazy-initialized in _ready().
var _label_font: SystemFont = null

## bar_id → float (0.0–max_value). Current displayed fill level (tweened).
var _fill_values: Dictionary = {}

## bar_id → Tween (active fill tween, or null if idle).
var _fill_tweens: Dictionary = {}

## Upper bound for bar values in this scene. Read from get_goal_config() on load.
var _max_value: float = 100.0

# ── Arc / hint data ───────────────────────────────────────────────────────────

## Current arc opacity (0.0–1.0); drives the arc draw color.
var _arc_opacity: float = 0.0

## Active arc fade tween (shared across all bar arcs).
var _arc_tween: Tween = null

## Last hint level received while Dormant. Applied when state becomes Active.
var _pending_hint_level: int = 0


# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	## Subscribe to EventBus signals via typed callable syntax (ADR-003).
	## StatusBarUI never emits — it only subscribes.
	EventBus.bar_values_changed.connect(_on_bar_values_changed)
	EventBus.hint_level_changed.connect(_on_hint_level_changed)
	EventBus.scene_loading.connect(_on_scene_loading)
	EventBus.win_condition_met.connect(_on_win_condition_met)

	_label_font = _make_cjk_font()

	## Self-wire scene configuration — SceneGoal emits seed_cards_ready after
	## load_scene() is complete, at which point the goal config is readable
	## and StatusBarUI can build its bar layout. This removes the previous
	## dependency on an external caller (legacy game.gd pattern).
	SceneGoal.seed_cards_ready.connect(_on_seed_cards_ready)


## Builds a SystemFont with a CJK-capable fallback chain (PingFang TC, Microsoft
## JhengHei, Noto Sans CJK TC). Mirrors CardVisual._make_cjk_font() so both
## label surfaces render Chinese identically. See card_visual.gd for rationale.
func _make_cjk_font() -> SystemFont:
	var f := SystemFont.new()
	f.font_names = PackedStringArray([
		"PingFang TC",
		"Heiti TC",
		"Microsoft JhengHei",
		"Noto Sans CJK TC",
		"Noto Sans TC",
	])
	return f


func _on_seed_cards_ready(_seed_cards: Array) -> void:
	configure_for_scene()


# ── Public API ────────────────────────────────────────────────────────────────

## Returns the current UIState. Used by tests and external observers.
## StatusBarUI does not emit state changes — poll this if needed.
func get_state() -> UIState:
	return _state


## Configure bars from the current scene's goal config.
## Call this on scene_started (or directly after scene loads for bar-type goals).
## Reads from SceneGoal.get_goal_config() — approved read-only query per ADR-003.
func configure_for_scene() -> void:
	var config: Dictionary = SceneGoal.get_goal_config()
	var goal_type: String = config.get("type", "")

	if goal_type not in ["sustain_above", "reach_value"]:
		_state = UIState.DORMANT
		queue_redraw()
		return

	_max_value = float(config.get("max_value", 100.0))
	var bars: Array = config.get("bars", [])

	_kill_all_fill_tweens()
	_bar_ids.clear()
	_bar_labels.clear()
	_fill_values.clear()
	_fill_tweens.clear()

	if bars.is_empty():
		push_warning("StatusBarUI: bar goal scene has no bars defined — staying Dormant")
		_state = UIState.DORMANT
		queue_redraw()
		return

	for bar: Dictionary in bars:
		var bar_id: String = bar.get("id", "")
		if bar_id.is_empty():
			continue
		_bar_ids.append(bar_id)
		var initial: float = float(bar.get("initial_value", 0.0))
		_fill_values[bar_id] = initial
		## Optional "label" field supplies a human-readable bar name.
		## Falls back to the bar_id itself if missing (legacy scenes).
		var label: String = String(bar.get("label", ""))
		_bar_labels[bar_id] = label if label != "" else bar_id

	_state = UIState.ACTIVE

	## Apply any hint level that arrived while Dormant.
	if _pending_hint_level != 0:
		_apply_hint_level(_pending_hint_level)
		_pending_hint_level = 0

	_layout_bars(_bar_ids.size())
	queue_redraw()


## Reset panel to Dormant state. Called on scene transition.
## Kills all in-flight tweens and clears bar state. Idempotent.
func reset() -> void:
	_kill_all_fill_tweens()
	_kill_arc_tween()

	_bar_ids.clear()
	_fill_values.clear()
	_fill_tweens.clear()
	_arc_opacity  = 0.0
	_pending_hint_level = 0
	_state        = UIState.DORMANT
	queue_redraw()


# ── EventBus signal handlers ──────────────────────────────────────────────────

func _on_bar_values_changed(values: Dictionary) -> void:
	## State guard: only Active state processes fill updates (Story 001 / Story 004).
	if _state != UIState.ACTIVE:
		return

	for bar_id: String in values:
		if not _fill_values.has(bar_id):
			continue

		var new_target: float = clampf(float(values[bar_id]), 0.0, _max_value)

		## Cancel any in-flight tween for this bar, starting the new one from
		## the current displayed fill — no visual jump (Story 002 AC-3).
		var existing: Tween = _fill_tweens.get(bar_id)
		if existing != null and existing.is_valid():
			existing.kill()

		var from_val: float = float(_fill_values.get(bar_id, 0.0))
		var tween := create_tween()
		tween.tween_method(
			func(v: float) -> void:
				_fill_values[bar_id] = v
				queue_redraw(),
			from_val, new_target, bar_tween_sec
		)
		_fill_tweens[bar_id] = tween


func _on_hint_level_changed(level: int) -> void:
	## State guard: while Dormant, store the level but apply no tween (Story 003 / Story 004).
	if _state != UIState.ACTIVE:
		_pending_hint_level = level
		return

	_apply_hint_level(level)


func _on_scene_loading(_scene_id: String) -> void:
	## Scene transition — reset to Dormant (Story 001 AC-2).
	reset()


func _on_win_condition_met() -> void:
	## Freeze bars at current displayed values. Kill fill tweens to stop mid-flight
	## animation. Arc tween may continue to its endpoint (GDD Edge Cases). (Story 001 AC-3)
	if _state == UIState.FROZEN:
		return
	_kill_all_fill_tweens()
	_state = UIState.FROZEN
	queue_redraw()


# ── Private helpers ───────────────────────────────────────────────────────────

## Apply a hint level opacity change. Only called when Active.
## Cancels any in-flight arc tween, starts new one from current opacity — no jump.
func _apply_hint_level(level: int) -> void:
	var target_opacity: float
	match level:
		0:  target_opacity = 0.0
		1:  target_opacity = arc_faint_opacity
		_:  target_opacity = ARC_OPACITY_FULL  ## Level 2 and above

	_kill_arc_tween()

	var from_opacity: float = _arc_opacity
	_arc_tween = create_tween()
	_arc_tween.tween_method(
		func(v: float) -> void:
			_arc_opacity = v
			queue_redraw(),
		from_opacity, target_opacity, arc_fade_sec
	)


## Apply layout constraints for the given bar count.
## Currently layout is driven by _bar_x() / _bar_top() at draw time.
## This method is the extension point for future layout modes (stacked, etc.).
func _layout_bars(bar_count: int) -> void:
	## For MVP: horizontal pair centred in panel. _bar_x() handles positioning.
	## One bar: centred. Two bars: side by side. Layout computed at draw time.
	if bar_count == 0:
		push_warning("StatusBarUI: _layout_bars called with 0 bars")


## Kill all active fill tweens. Safe to call when no tweens exist.
func _kill_all_fill_tweens() -> void:
	for bar_id: String in _fill_tweens:
		var tw: Tween = _fill_tweens[bar_id]
		if tw != null and tw.is_valid():
			tw.kill()
	_fill_tweens.clear()


## Kill the active arc tween. Safe to call when no tween exists.
func _kill_arc_tween() -> void:
	if _arc_tween != null and _arc_tween.is_valid():
		_arc_tween.kill()
	_arc_tween = null


# ── Rendering ─────────────────────────────────────────────────────────────────

func _draw() -> void:
	## Panel background — always visible during gameplay.
	draw_rect(Rect2(0.0, 0.0, panel_width_px, _panel_height()), COLOR_PANEL_BG)

	if _state == UIState.DORMANT or _bar_ids.is_empty():
		return

	var count := _bar_ids.size()
	for i in range(count):
		var bar_id: String = _bar_ids[i]
		var bar_x  := _bar_x(i, count)
		var bar_top := _bar_top()
		_draw_bar(bar_x, bar_top, bar_id)


func _draw_bar(bar_x: float, bar_top: float, bar_id: String) -> void:
	## Parchment-style rendering: empty ink-brown outlined track (fill behind
	## is the translucent cream panel), amber fill from bottom, integer tick
	## marks across the track for small-max bars, label text below.

	var track_rect := Rect2(bar_x, bar_top, bar_width_px, bar_height_px)

	## Fill — bottom to top (Story 002). Drawn FIRST so the outline sits on top.
	## fill_height = (current_value / max_value) * bar_height_px
	var current: float = float(_fill_values.get(bar_id, 0.0))
	var fill_h: float  = (current / _max_value) * bar_height_px
	fill_h = clampf(fill_h, 0.0, bar_height_px)
	if fill_h > 0.0:
		draw_rect(
			Rect2(bar_x, bar_top + bar_height_px - fill_h, bar_width_px, fill_h),
			COLOR_BAR_FILL
		)

	## Integer tick marks — only meaningful for small-max bars (e.g. max=3 for
	## drive's journey_progress). Skip when max_value is large (e.g. 100 for
	## affection) to avoid a haystack of lines.
	if _max_value > 0.0 and _max_value <= 10.0:
		var max_int := int(_max_value)
		for n in range(1, max_int):
			var tick_y := bar_top + bar_height_px - (float(n) / _max_value) * bar_height_px
			draw_line(
				Vector2(bar_x, tick_y),
				Vector2(bar_x + bar_width_px, tick_y),
				COLOR_TICK,
				1.0
			)

	## Track border outline — drawn last so it stays crisp over fill + ticks.
	draw_rect(track_rect, COLOR_BAR_BG, false, 1.5)

	## Label text below the bar (e.g. "旅程進度 0/3"). Uses the CJK-capable
	## SystemFont so Chinese labels render on all platforms.
	_draw_bar_label(bar_x, bar_top, bar_id, current)

	## Hint arc — counterclockwise around bar border, starting from top (Story 003).
	if _arc_opacity > 0.001:
		var arc_color := Color(COLOR_ARC.r, COLOR_ARC.g, COLOR_ARC.b, _arc_opacity)
		_draw_bar_arc(bar_x, bar_top, arc_color)


## Draws the bar label plus current/max count below the bar. For scenes with
## small max_value (≤10) the count is shown as an integer ("N/3"); for larger
## ranges (affection 0–100) it's a percentage-style int ("42/100").
func _draw_bar_label(bar_x: float, bar_top: float, bar_id: String, current: float) -> void:
	if _label_font == null:
		return

	var label: String = _bar_labels.get(bar_id, bar_id)
	var count_text: String = "%d/%d" % [int(round(current)), int(round(_max_value))]
	var text := "%s %s" % [label, count_text]

	## Horizontally centre the text under the bar within the panel column.
	var text_size: Vector2 = _label_font.get_string_size(
		text, HORIZONTAL_ALIGNMENT_LEFT, -1, bar_label_font_size
	)
	var col_center := bar_x + bar_width_px * 0.5
	var text_x := col_center - text_size.x * 0.5
	var text_y := bar_top + bar_height_px + bar_label_gap_px + float(bar_label_font_size)

	draw_string(
		_label_font,
		Vector2(text_x, text_y),
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		bar_label_font_size,
		COLOR_BAR_LABEL
	)


func _draw_bar_arc(bar_x: float, bar_top: float, arc_color: Color) -> void:
	## Counterclockwise rect-perimeter arc around the bar border.
	## Starts at top-right, sweeps left (counterclockwise): top-right → top-left →
	## bottom-left → bottom-right → top-right.
	## For MVP the full perimeter is drawn as a glow at _arc_opacity.
	## Arc geometry is set here at draw time; opacity is controlled by the tween.
	const OUTLINE_PAD := 2.0  ## outset so arc sits just outside the bar fill
	var x0 := bar_x - OUTLINE_PAD
	var y0 := bar_top - OUTLINE_PAD
	var x1 := bar_x + bar_width_px + OUTLINE_PAD
	var y1 := bar_top + bar_height_px + OUTLINE_PAD

	## Counterclockwise: top-right → top-left → bottom-left → bottom-right → top-right
	var pts: PackedVector2Array = [
		Vector2(x1, y0),  ## top-right (start)
		Vector2(x0, y0),  ## top-left
		Vector2(x0, y1),  ## bottom-left
		Vector2(x1, y1),  ## bottom-right
		Vector2(x1, y0),  ## back to top-right (close loop)
	]
	draw_polyline(pts, arc_color, 2.0)


# ── Layout helpers ────────────────────────────────────────────────────────────

## Returns the visible panel height from the viewport.
func _panel_height() -> float:
	return get_viewport().get_visible_rect().size.y


## Returns the Y offset that centres the bar group vertically in the panel.
func _bar_top() -> float:
	return (_panel_height() - bar_height_px) * 0.5


## Returns the X offset for bar at index within a group of `total` bars.
## One bar: centred in panel. Two bars: side-by-side with 12px gap, centred.
func _bar_x(index: int, total: int) -> float:
	const GAP_PX := 12.0
	var total_width := float(total) * bar_width_px + float(total - 1) * GAP_PX
	var start_x     := (panel_width_px - total_width) * 0.5
	return start_x + float(index) * (bar_width_px + GAP_PX)
