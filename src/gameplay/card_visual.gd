## CardVisual — per-card rendering component. Pure renderer, no game logic.
## Added as child of CardNode. Reads CardDatabase on spawn, CardEngine state each frame.
## Implements: design/gdd/card-visual.md
##
## Stories implemented:
##   001 — Card spawn and data read (CardDatabase → display_name, art, badge)
##   002 — State-driven visual config (scale, shadow, z-order per CardEngine state)
##   003 — Merge tween animation (scale-to-zero + opacity-to-zero; pool reset)
##   004 — Error handling and fallbacks (missing art, invalid card_id, long names)

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
var _has_badge: bool        = false   ## CardEntry has no badge field yet; always false

var _is_lifted: bool        = false   ## tracks whether shadow / scale are active
var _authored_z_index: int  = AUTHORED_Z_INDEX

## Active merge tween reference — kept so it can be killed on interruption.
var _merge_tween: Tween     = null


# ── Initialisation ────────────────────────────────────────────────────────────

## Called by Godot when the node enters the scene tree.
## Reads the parent CardNode's card_id and populates display data from CardDatabase.
func _ready() -> void:
	_authored_z_index = z_index
	_populate_from_parent()


## Re-populates display data from CardDatabase for the given card_id.
## Call this when a pooled card is acquired to clear stale data before reuse.
## [param new_card_id] — the card_id to display. Must match a CardDatabase entry.
func reset(new_card_id: String) -> void:
	_cancel_merge_tween()
	# Restore visual state to clean defaults before repopulating.
	scale      = IDLE_SCALE
	modulate.a = 1.0
	z_index    = _authored_z_index
	_is_lifted = false

	_display_name = INVALID_CARD_LABEL
	_art_texture  = null
	_has_badge    = false

	_read_card_data(new_card_id)
	queue_redraw()


# ── Per-Frame ─────────────────────────────────────────────────────────────────

## Each frame: reads the current card state from CardEngine and applies the
## matching visual configuration instantly (no tween between states except Merge).
func _process(_delta: float) -> void:
	var state := CardEngine.get_card_state(_instance_id)
	_apply_state_config(state)


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
		return

	# Legacy fallback — missing or unloadable art. Render the code-drawn
	# placeholder card so the debug / error state is visible.
	draw_rect(Rect2(-half, CARD_SIZE), COLOR_CARD_BG)
	draw_rect(Rect2(-half, CARD_SIZE), COLOR_CARD_BORDER, false, 1.5)
	var art_center := Vector2(0.0, 8.0)
	_draw_art(art_center)
	draw_arc(art_center, art_circle_radius, 0.0, TAU, 48, COLOR_CARD_BORDER, 1.0)
	_draw_label(half)


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
		_has_badge    = false
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

	# Badge — CardEntry does not yet have a badge field (GDD open question).
	# Default to false until the schema is extended.
	_has_badge = false


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
	var font    := ThemeDB.fallback_font
	var label_y := -half.y + float(label_font_size) + 4.0
	var label_x := -half.x + 6.0
	var max_w   := CARD_SIZE.x - 12.0
	draw_string(
		font, Vector2(label_x, label_y), _display_name,
		HORIZONTAL_ALIGNMENT_LEFT, max_w, label_font_size, COLOR_LABEL
	)


## Kills the active _merge_tween if one exists. Safe to call at any time.
func _cancel_merge_tween() -> void:
	if _merge_tween != null:
		_merge_tween.kill()
		_merge_tween = null
