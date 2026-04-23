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
@export var bar_width_px: float = 12.0

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

const COLOR_PANEL_BG  := Color(0.18, 0.16, 0.14, 0.85)
const COLOR_BAR_BG    := Color(0.30, 0.27, 0.24, 1.0)
const COLOR_BAR_FILL  := Color(0.82, 0.68, 0.42, 1.0)  ## warm amber
const COLOR_ARC       := Color(0.95, 0.88, 0.60, 1.0)  ## soft gold

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
	## Bar background track.
	draw_rect(
		Rect2(bar_x, bar_top, bar_width_px, bar_height_px),
		COLOR_BAR_BG
	)

	## Fill — bottom to top (Story 002).
	## fill_height = (current_value / max_value) * bar_height_px
	var current: float = float(_fill_values.get(bar_id, 0.0))
	var fill_h: float  = (current / _max_value) * bar_height_px
	fill_h = clampf(fill_h, 0.0, bar_height_px)
	if fill_h > 0.0:
		draw_rect(
			Rect2(bar_x, bar_top + bar_height_px - fill_h, bar_width_px, fill_h),
			COLOR_BAR_FILL
		)

	## Track border outline.
	draw_rect(Rect2(bar_x, bar_top, bar_width_px, bar_height_px), COLOR_BAR_BG, false, 1.0)

	## Hint arc — counterclockwise around bar border, starting from top (Story 003).
	if _arc_opacity > 0.001:
		var arc_color := Color(COLOR_ARC.r, COLOR_ARC.g, COLOR_ARC.b, _arc_opacity)
		_draw_bar_arc(bar_x, bar_top, arc_color)


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
