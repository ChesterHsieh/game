## CardVisual — per-card rendering component. Pure renderer, no game logic.
## Added as child of CardNode. Reads CardDatabase on spawn, CardEngine state each frame.
## Implements: design/gdd/card-visual.md
##
## Stories implemented:
##   001 — Card spawn and data read (CardDatabase → display_name, art, badge)
##   002 — State-driven visual config (scale, shadow, z-order per CardEngine state)
##   003 — Merge tween animation (scale-to-zero + opacity-to-zero; pool reset)
##   004 — Error handling and fallbacks (missing art, invalid card_id, long names)
##   005 — Badge system (optional top-bar badge text; truncates with ellipsis)
##   006 — Idle rabbit-jump animation (tag "rabbit_jump" → hop + random x drift in IDLE)

class_name CardVisual extends Node2D

# ── Tuning (@export so designers can tune without touching code) ───────────────

## Uniform scale applied while card is held (Dragged / Attracting / Snapping).
@export var drag_scale: Vector2 = Vector2(1.05, 1.05)

## Drop shadow pixel offset from card origin when lifted.
@export var shadow_offset: Vector2 = Vector2(4.0, 6.0)

## Drop shadow alpha (0–1). 0 = invisible, 1 = fully opaque.
@export var shadow_opacity: float = 0.35

## Art circle radius in pixels (~38% of CARD_SIZE.x by default).
@export var art_circle_radius: float = 33.0

## Label font size in pixels.
@export var label_font_size: int = 14

## Fallback circle colour when art is missing.
@export var fallback_art_color: Color = Color(0.84, 0.81, 0.76, 1.0)

## Height of the badge bar drawn at the top of the card (pixels).
@export var badge_bar_height: float = 18.0

## Font size for the badge text.
@export var badge_font_size: int = 12

## Badge bar background colour.
@export var badge_background_color: Color = Color.BLACK

## Badge text colour.
@export var badge_text_color: Color = Color.WHITE

## Badge bar vertical offset (pixels). Negative = up. 0 = bar sits flush
## with the card's top edge. -8 = bar peeks above the card by 8px, so it
## reads as a "tag" pinned onto the card.
@export var badge_y_offset: float = -8.0

## Catch radius (pixels) for chase behavior — fires on_catch when target gets closer.
@export var chase_catch_radius_px: float = 28.0

## Peak y offset (pixels) for the rabbit-jump arc. Negative = up.
@export var jump_peak_px: float = -20.0
## Time (seconds) for the upward stroke of the jump.
@export var jump_rise_sec: float = 0.25
## Time (seconds) for the downward stroke of the jump.
@export var jump_fall_sec: float = 0.55
## Minimum x drift per hop (pixels). Randomised each landing.
@export var jump_drift_min_px: float = 40.0
## Maximum x drift per hop (pixels).
@export var jump_drift_max_px: float = 60.0
## Gap on the table edge (pixels) before x direction reverses.
@export var jump_edge_margin_px: float = 60.0

# ── Layout constants ───────────────────────────────────────────────────────────

## Physical card size in pixels.
const CARD_SIZE := Vector2(88.0, 112.0)

## z_index applied while card is dragged / attracting / snapping (above all others).
const TOP_Z_INDEX := 100

## z_index restored to when card returns to Idle / Pushed / Executing.
const AUTHORED_Z_INDEX := 0

## Idle scale (100%).
const IDLE_SCALE := Vector2(1.0, 1.0)

## Placeholder label when card_id is invalid.
const INVALID_CARD_LABEL: String = "?"

## Character count threshold beyond which a warning is emitted. Used only for
## push_warning — the actual clip is handled by Godot's draw_string max_width.
const LABEL_CLIP_WARN_CHARS := 18

# ── Colors ────────────────────────────────────────────────────────────────────

const COLOR_CARD_BG     := Color(0.98, 0.97, 0.93, 1.0)   ## warm off-white
const COLOR_CARD_BORDER := Color(0.55, 0.50, 0.45, 1.0)
const COLOR_LABEL       := Color(0.18, 0.15, 0.12, 1.0)

# ── Internal state ─────────────────────────────────────────────────────────────

var _instance_id: String    = ""
var _display_name: String   = INVALID_CARD_LABEL
var _art_texture: Texture2D = null    ## null → draw fallback circle
var _badge: String          = ""      ## empty → no badge bar drawn

var _is_lifted: bool        = false   ## tracks whether shadow / scale are active
var _authored_z_index: int  = AUTHORED_Z_INDEX

## Active merge tween reference — kept so it can be killed on interruption.
var _merge_tween: Tween     = null

## Active rabbit-jump tween — one hop at a time; relaunched each landing.
var _bounce_tween: Tween    = null
## True when this card's CardEntry.tags contains "rabbit_jump" or "visual:rabbit_jump_fast".
var _is_bouncy: bool        = false
## True when "visual:rabbit_jump_fast" — uses larger drift + shorter timings so
## the card visibly sprints across the table.
var _is_bouncy_fast: bool   = false
## Tracks last-known IDLE state so jump start/stop fires only on transitions.
var _was_idle: bool         = false
## Current horizontal drift direction (+1 right, -1 left). Flips at edges.
var _jump_dir: float        = 1.0

## Chase behavior — populated from tags ("chase:<id>", "speed:<n>", "sway:<n>",
## "period:<n>", "on_catch:<id>"). Empty _chase_target_id disables chase.
var _chase_target_id: String = ""
var _chase_speed_px: float   = 30.0
var _chase_sway_px: float    = 10.0
var _chase_period_sec: float = 0.6
var _chase_on_catch: String  = ""
var _chase_elapsed: float    = 0.0
var _chase_consumed: bool    = false

## Cached SystemFont with CJK fallback chain — Godot's ThemeDB.fallback_font is
## Latin-only and cannot render Chinese/Japanese glyphs. Created once per
## CardVisual and reused for both label and badge drawing.
var _cjk_font: SystemFont   = null


# ── Initialisation ────────────────────────────────────────────────────────────

## Called by Godot when the node enters the scene tree.
## Reads the parent CardNode's card_id and populates display data from CardDatabase.
func _ready() -> void:
	_authored_z_index = z_index
	_cjk_font = _make_cjk_font()
	_populate_from_parent()


## Builds a SystemFont with a CJK-capable fallback chain so Chinese display
## names render correctly on macOS, Windows, and Linux. Godot resolves the
## first installed font_name on the current platform.
func _make_cjk_font() -> SystemFont:
	var f := SystemFont.new()
	f.font_names = PackedStringArray([
		"PingFang TC",          # macOS default TC
		"Heiti TC",             # macOS fallback
		"Microsoft JhengHei",   # Windows TC
		"Noto Sans CJK TC",     # Linux / cross-platform
		"Noto Sans TC",
	])
	return f


## Re-populates display data from CardDatabase for the given card_id.
## Call this when a pooled card is acquired to clear stale data before reuse.
## [param new_card_id] — the card_id to display. Must match a CardDatabase entry.
func reset(new_card_id: String) -> void:
	_cancel_merge_tween()
	_stop_bounce()
	# Restore visual state to clean defaults before repopulating.
	scale      = IDLE_SCALE
	modulate.a = 1.0
	z_index    = _authored_z_index
	_is_lifted = false
	_was_idle  = false
	_jump_dir  = 1.0

	_display_name    = INVALID_CARD_LABEL
	_art_texture     = null
	_badge           = ""
	_is_bouncy       = false
	_is_bouncy_fast  = false
	_chase_target_id = ""
	_chase_on_catch  = ""
	_chase_elapsed   = 0.0
	_chase_consumed  = false

	_read_card_data(new_card_id)
	queue_redraw()


# ── Per-Frame ─────────────────────────────────────────────────────────────────

## Each frame: reads the current card state from CardEngine and applies the
## matching visual configuration instantly (no tween between states except Merge).
func _process(delta: float) -> void:
	var state := CardEngine.get_card_state(_instance_id)
	_apply_state_config(state)
	if _chase_target_id != "" and not _chase_consumed:
		_advance_chase(delta, state)


# ── Public API ────────────────────────────────────────────────────────────────

## Starts the merge tween: scale → Vector2.ZERO, modulate.a → 0.0 over
## CardEngine.MERGE_DURATION_SEC. Calls [param on_complete] when finished.
## CardEngine already drives the card-node's merge motion; this method is
## provided for any Presentation-layer caller that needs the Tween reference.
##
## NOTE: In the current CardSpawning implementation CardEngine drives the merge
## tween directly on the card node. This method exists for pool-reset safety and
## future use when CardSpawning implements ADR-002 pooling.
func play_merge_tween(on_complete: Callable) -> void:
	_cancel_merge_tween()
	scale      = IDLE_SCALE
	modulate.a = 1.0

	_merge_tween = create_tween()
	_merge_tween.set_parallel(true)
	_merge_tween.tween_property(self, "scale",      Vector2.ZERO, CardEngine.MERGE_DURATION_SEC)
	_merge_tween.tween_property(self, "modulate:a", 0.0,          CardEngine.MERGE_DURATION_SEC)
	_merge_tween.set_parallel(false)
	_merge_tween.tween_callback(func() -> void:
		_merge_tween = null
		on_complete.call()
	)


## Cancels any in-progress merge tween and restores scale + opacity to defaults.
## Call this when a scene transition interrupts a merge mid-animation.
func cancel_merge() -> void:
	_cancel_merge_tween()
	scale      = IDLE_SCALE
	modulate.a = 1.0
	queue_redraw()


# ── Rendering ─────────────────────────────────────────────────────────────────

## Draws the card face. When a full art texture is present (nano-banana /
## commissioned PNGs include their own card border + paper background +
## implicit framing per Art Bible §8), we draw the texture directly over the
## entire CARD_SIZE rect — no code-drawn background, border, label, or art
## circle. This avoids the "card-in-a-card" effect where the engine drew a
## frame on top of the PNG's own frame.
##
## When no art texture is loaded (fallback / missing art path), we render
## the legacy code-drawn placeholder: background rect, border, fallback
## circle, and the display_name label.
func _draw() -> void:
	var half := CARD_SIZE * 0.5

	# Drop shadow — drawn only while the card is lifted. Independent of
	# whether the art texture is present.
	if _is_lifted:
		var shadow_color := Color(0.0, 0.0, 0.0, shadow_opacity)
		draw_rect(Rect2(-half + shadow_offset, CARD_SIZE), shadow_color)

	if _art_texture != null:
		# Full-PNG mode: the artwork is the card. Stretch the source texture
		# to fill CARD_SIZE. The PNG carries its own border + background.
		draw_texture_rect(_art_texture, Rect2(-half, CARD_SIZE), false)
		_draw_badge(half)
		return

	# Legacy fallback — missing or unloadable art. Render the code-drawn
	# placeholder card so the debug / error state is visible.
	draw_rect(Rect2(-half, CARD_SIZE), COLOR_CARD_BG)
	draw_rect(Rect2(-half, CARD_SIZE), COLOR_CARD_BORDER, false, 1.5)
	var art_center := Vector2(0.0, 8.0)
	_draw_art(art_center)
	draw_arc(art_center, art_circle_radius, 0.0, TAU, 48, COLOR_CARD_BORDER, 1.0)
	_draw_label(half)
	_draw_badge(half)


# ── Private helpers ────────────────────────────────────────────────────────────

## Reads the parent CardNode's card_id and calls _read_card_data().
func _populate_from_parent() -> void:
	var parent := get_parent()
	if parent == null:
		push_warning("CardVisual: no parent node — cannot read card_id")
		queue_redraw()
		return

	_instance_id = parent.get("instance_id") as String
	var card_id: String = parent.get("card_id") as String
	_read_card_data(card_id)
	queue_redraw()


## Queries CardDatabase for [param card_id] and populates _display_name and
## _art_texture. Applies fallback values and logs errors/warnings on failure.
## Called by _populate_from_parent() and reset().
func _read_card_data(card_id: String) -> void:
	# Typed cast + null check (Control Manifest, Foundation Layer — mandatory).
	var card_data: CardEntry = CardDatabase.get_card(card_id) as CardEntry
	if card_data == null:
		# get_card() already calls push_error internally; we add context here.
		push_error("CardVisual: invalid card_id '%s' — rendering full placeholder" % card_id)
		_display_name = INVALID_CARD_LABEL
		_art_texture  = null
		_badge        = ""
		return

	# display_name — fall back to card_id if empty (matches existing behaviour).
	_display_name = card_data.display_name
	if _display_name == "":
		push_warning("CardVisual: empty display_name for card_id '%s'" % card_id)
		_display_name = card_id

	# Warn on very long display_name (actual clip is done in draw_string via max_width).
	if _display_name.length() > LABEL_CLIP_WARN_CHARS:
		push_warning("CardVisual: display_name may be clipped for card_id '%s'" % card_id)

	# Art — CardEntry.art is already a Texture2D (imported by Godot editor).
	# Null means the designer left the field blank or the file was deleted.
	_art_texture = card_data.art
	if _art_texture == null:
		push_warning("CardVisual: missing art for card_id '%s'" % card_id)

	# Badge — optional top-bar text. Empty string is the common case and
	# means "no bar drawn" (see _draw_badge()).
	_badge = card_data.badge

	# Rabbit-jump — tag-driven; no schema change needed. The "fast" variant
	# also flips _is_bouncy on so the same hop pipeline runs with larger
	# drift and shorter timings.
	_is_bouncy_fast = "visual:rabbit_jump_fast" in card_data.tags
	_is_bouncy      = _is_bouncy_fast or ("rabbit_jump" in card_data.tags)

	# Chase behavior — parse "chase:<id>", "speed:<n>", "sway:<n>",
	# "period:<n>", "on_catch:<id>" from tags. Absent → no chase.
	_chase_target_id = ""
	_chase_on_catch  = ""
	_chase_elapsed   = 0.0
	_chase_consumed  = false
	for tag: String in card_data.tags:
		if tag.begins_with("chase:"):
			_chase_target_id = tag.substr(6)
		elif tag.begins_with("speed:"):
			_chase_speed_px = float(tag.substr(6))
		elif tag.begins_with("sway:"):
			_chase_sway_px = float(tag.substr(5))
		elif tag.begins_with("period:"):
			_chase_period_sec = float(tag.substr(7))
		elif tag.begins_with("on_catch:"):
			_chase_on_catch = tag.substr(9)


## Applies scale, shadow, and z-order config for [param state] instantly (no tween).
## Unknown state values fall back to Idle config and log a warning (GDD Edge Cases).
func _apply_state_config(state: CardEngine.State) -> void:
	var lifted: bool
	var new_z: int

	match state:
		CardEngine.State.IDLE:
			lifted = false
			new_z  = _authored_z_index
		CardEngine.State.DRAGGED, CardEngine.State.ATTRACTING, CardEngine.State.SNAPPING:
			lifted = true
			new_z  = TOP_Z_INDEX
		CardEngine.State.PUSHED, CardEngine.State.EXECUTING:
			lifted = false
			new_z  = _authored_z_index
		_:
			push_warning("CardVisual: unrecognised CardEngine state %d for '%s' — applying Idle config"
				% [state, _instance_id])
			lifted = false
			new_z  = _authored_z_index

	var changed := false

	if lifted != _is_lifted:
		_is_lifted = lifted
		scale      = drag_scale if lifted else IDLE_SCALE
		changed    = true

	if new_z != z_index:
		z_index = new_z

	if changed:
		queue_redraw()

	# Bounce: start when entering IDLE (if bouncy), stop when leaving IDLE.
	var now_idle := (state == CardEngine.State.IDLE)
	if now_idle != _was_idle:
		_was_idle = now_idle
		if now_idle and _is_bouncy:
			_start_bounce()
		else:
			_stop_bounce()


## Draws the art region as a clipped circle. When art is present, the texture is
## drawn into a square inscribed within the circle and then the circle arc masks
## the visual boundary. Source image aspect ratio does not affect the circle size.
## When art is absent, draws the fallback placeholder circle.
func _draw_art(art_center: Vector2) -> void:
	if _art_texture != null:
		# Draw the texture scaled to fit inside the circle (square inscribed).
		# Both dimensions equal 2 * radius so non-square textures are stretched
		# to fill the square uniformly. The circle arc drawn on top provides the
		# visual circular boundary.
		var diameter := art_circle_radius * 2.0
		var art_rect := Rect2(
			art_center - Vector2(art_circle_radius, art_circle_radius),
			Vector2(diameter, diameter)
		)
		draw_texture_rect(_art_texture, art_rect, false)
	else:
		draw_circle(art_center, art_circle_radius, fallback_art_color)


## Draws the card label using draw_string with max_width clamping so long names
## are clipped by Godot rather than overflowing into the art region.
func _draw_label(half: Vector2) -> void:
	var font: Font = _cjk_font if _cjk_font != null else ThemeDB.fallback_font
	var label_y := -half.y + float(label_font_size) + 4.0
	var label_x := -half.x + 6.0
	var max_w   := CARD_SIZE.x - 12.0
	draw_string(
		font, Vector2(label_x, label_y), _display_name,
		HORIZONTAL_ALIGNMENT_LEFT, max_w, label_font_size, COLOR_LABEL
	)


## Draws the optional top-bar badge. No-op when [member _badge] is empty.
## The bar sits inside the card's top edge with a 2px horizontal margin,
## renders a solid [member badge_background_color] background, and draws
## the badge text centred within the bar. Long text is clipped to the bar
## width by [method CanvasItem.draw_string]'s max_width parameter — Godot
## inserts its own ellipsis treatment.
func _draw_badge(half: Vector2) -> void:
	if _badge == "":
		return

	var margin_x := 2.0
	var bar_top := -half.y + badge_y_offset
	var bar_rect := Rect2(
		Vector2(-half.x + margin_x, bar_top),
		Vector2(CARD_SIZE.x - margin_x * 2.0, badge_bar_height)
	)
	draw_rect(bar_rect, badge_background_color)

	var font: Font = _cjk_font if _cjk_font != null else ThemeDB.fallback_font
	# draw_string's y is the baseline; centre it vertically inside the bar.
	var ascent := font.get_ascent(badge_font_size)
	var text_y := bar_top + (badge_bar_height + ascent) * 0.5 - 1.0
	var text_x := -half.x + margin_x + 2.0
	var max_w  := bar_rect.size.x - 4.0
	draw_string(
		font, Vector2(text_x, text_y), _badge,
		HORIZONTAL_ALIGNMENT_CENTER, max_w, badge_font_size, badge_text_color
	)


## Kills the active _merge_tween if one exists. Safe to call at any time.
func _cancel_merge_tween() -> void:
	if _merge_tween != null:
		_merge_tween.kill()
		_merge_tween = null


## Starts one rabbit-jump hop. On landing, picks a new random x drift and
## recurses — creating an indefinite hop sequence until _stop_bounce() kills it.
## Uses position offset on CardVisual (child); CardNode.position is untouched.
func _start_bounce() -> void:
	if _bounce_tween != null:
		return
	position.y = 0.0
	_do_hop()


## Execute one hop: arc up, drift x, land, then recurse.
## When _is_bouncy_fast is true, drift is ~2× and per-hop timings ~½ so the
## card visibly sprints across the table (used for "ju_running").
func _do_hop() -> void:
	# Fast-variant overrides: larger drift, snappier rise+fall.
	var drift_min: float = jump_drift_min_px * (2.0 if _is_bouncy_fast else 1.0)
	var drift_max: float = jump_drift_max_px * (2.0 if _is_bouncy_fast else 1.0)
	var rise: float      = jump_rise_sec * (0.5 if _is_bouncy_fast else 1.0)
	var fall: float      = jump_fall_sec * (0.5 if _is_bouncy_fast else 1.0)

	# Randomise drift distance each hop.
	var drift := randf_range(drift_min, drift_max) * _jump_dir

	# Check edge: if the CardNode (parent) would drift out of the viewport margin,
	# flip direction and mirror the drift for this hop.
	var parent_node := get_parent()
	if parent_node != null:
		var vp_size   := get_viewport_rect().size
		var next_px: float = parent_node.position.x + drift
		if next_px < jump_edge_margin_px or next_px > vp_size.x - jump_edge_margin_px:
			_jump_dir *= -1.0
			drift      = randf_range(drift_min, drift_max) * _jump_dir

	# Snapshot parent x at hop start — avoids reading mid-tween values.
	var start_x: float = 0.0
	var land_x: float  = 0.0
	if parent_node != null:
		start_x = parent_node.position.x
		land_x  = start_x + drift

	_bounce_tween = create_tween()
	# Rise: arc upward (position:y on CardVisual child), x halfway on CardNode.
	_bounce_tween.set_parallel(true)
	_bounce_tween.tween_property(self, "position:y", jump_peak_px, rise)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if parent_node != null:
		_bounce_tween.tween_property(parent_node, "position:x",
			start_x + drift * 0.5, rise)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_bounce_tween.set_parallel(false)
	# Fall: return to y=0 (CardVisual local), x arrives at landing spot.
	_bounce_tween.set_parallel(true)
	_bounce_tween.tween_property(self, "position:y", 0.0, fall)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	if parent_node != null:
		_bounce_tween.tween_property(parent_node, "position:x",
			land_x, fall)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_bounce_tween.set_parallel(false)
	# On landing: clear tween ref and start next hop.
	_bounce_tween.tween_callback(func() -> void:
		_bounce_tween = null
		if _is_bouncy and _was_idle:
			_do_hop()
	)


## Kills the jump tween and resets offsets. Safe to call at any time.
func _stop_bounce() -> void:
	if _bounce_tween != null:
		_bounce_tween.kill()
		_bounce_tween = null
	position.y = 0.0


## Advance one frame of chase: walk parent CardNode toward the nearest live
## instance of [member _chase_target_id] at [member _chase_speed_px], adding
## a perpendicular sine sway. On catch (distance < radius), consume self +
## target and spawn [member _chase_on_catch] at the midpoint.
func _advance_chase(delta: float, state: CardEngine.State) -> void:
	# Pause chase while the player is interacting with this card.
	if state == CardEngine.State.DRAGGED \
		or state == CardEngine.State.ATTRACTING \
		or state == CardEngine.State.SNAPPING:
		return

	var parent_node := get_parent()
	if parent_node == null:
		return
	var target_node := _find_target_node()
	if target_node == null:
		return

	_chase_elapsed += delta

	var from_pos: Vector2 = parent_node.position
	var to_pos: Vector2   = target_node.position
	var to_target: Vector2 = to_pos - from_pos
	var dist: float = to_target.length()

	if dist <= chase_catch_radius_px:
		_perform_catch(parent_node, target_node)
		return

	var dir: Vector2 = to_target / dist
	var step: Vector2 = dir * _chase_speed_px * delta

	# Sway perpendicular to motion: sin wave, amplitude _chase_sway_px,
	# period _chase_period_sec.
	if _chase_sway_px > 0.0 and _chase_period_sec > 0.0:
		var phase: float = TAU * _chase_elapsed / _chase_period_sec
		var sway_amount: float = sin(phase) * _chase_sway_px * delta * (TAU / _chase_period_sec)
		var perp := Vector2(-dir.y, dir.x)
		step += perp * sway_amount

	parent_node.position = from_pos + step


## Returns the live Node2D for the closest card whose card_id matches
## [member _chase_target_id], or null if none on the table.
func _find_target_node() -> Node2D:
	var parent_node := get_parent()
	if parent_node == null:
		return null
	var my_pos: Vector2 = parent_node.position
	var best_node: Node2D = null
	var best_dist: float = INF
	for inst_id: String in CardSpawning.get_all_instance_ids():
		var node: Node2D = CardSpawning.get_card_node(inst_id)
		if node == null:
			continue
		var node_card_id: String = node.get("card_id") as String
		if node_card_id != _chase_target_id:
			continue
		var d: float = my_pos.distance_to(node.position)
		if d < best_dist:
			best_dist = d
			best_node = node
	return best_node


## Consume self + target, spawn [member _chase_on_catch] at midpoint.
## Marks _chase_consumed so we don't re-fire while remove_card runs.
func _perform_catch(self_node: Node2D, target_node: Node2D) -> void:
	_chase_consumed = true
	var midpoint: Vector2 = (self_node.position + target_node.position) * 0.5
	var self_id: String   = self_node.get("instance_id") as String
	var target_id: String = target_node.get("instance_id") as String
	CardSpawning.remove_card(self_id)
	CardSpawning.remove_card(target_id)
	if _chase_on_catch != "":
		CardSpawning.spawn_card(_chase_on_catch, midpoint)
