## CardVisual — per-card rendering component. Pure renderer, no game logic.
## Added as child of card_node. Reads CardDatabase on spawn, CardEngine state each frame.
## Implements: design/gdd/card-visual.md

extends Node2D

# ── Tuning ────────────────────────────────────────────────────────────────────

const DRAG_SCALE      := Vector2(1.05, 1.05)
const IDLE_SCALE      := Vector2(1.0,  1.0)
const CARD_SIZE       := Vector2(88.0, 112.0)
const ART_RADIUS      := 28.0        ## ~32% of card width — safe within label+badge regions
const LABEL_FONT_SIZE := 14
const SHADOW_OFFSET   := Vector2(4.0, 6.0)
const SHADOW_OPACITY  := 0.35
const Z_LIFTED        := 100
const Z_IDLE          := 0

# ── Colors ────────────────────────────────────────────────────────────────────

const COLOR_CARD_BG     := Color(0.98, 0.97, 0.93, 1.0)  ## warm off-white
const COLOR_CARD_BORDER := Color(0.55, 0.50, 0.45, 1.0)
const COLOR_ART_FILL    := Color(0.84, 0.81, 0.76, 1.0)  ## placeholder art bg
const COLOR_LABEL       := Color(0.18, 0.15, 0.12, 1.0)
const COLOR_SHADOW      := Color(0.0,  0.0,  0.0,  SHADOW_OPACITY)

# ── State ─────────────────────────────────────────────────────────────────────

var _instance_id:  String     = ""
var _display_name: String     = "?"
var _art_texture:  Texture2D  = null   ## null → draw placeholder circle
var _is_lifted:    bool       = false


# ── Setup ─────────────────────────────────────────────────────────────────────

func _ready() -> void:
	var parent := get_parent()
	if parent == null:
		push_warning("CardVisual: no parent node")
		return

	_instance_id = parent.get("instance_id") as String
	var card_id: String = parent.get("card_id") as String

	var card_data = CardDatabase.get_card(card_id)
	if card_data == null:
		push_error("CardVisual: no card data for '%s'" % card_id)
	else:
		_display_name = card_data.get("display_name", card_id)
		if _display_name == "":
			push_warning("CardVisual: empty display_name for '%s'" % card_id)
			_display_name = card_id

		var art_path: String = card_data.get("art_path", "")
		if art_path != "":
			# Convert res:// path to absolute so we can load PNGs directly
			# without requiring a Godot editor import step first.
			var abs_path := ProjectSettings.globalize_path(art_path)
			if FileAccess.file_exists(abs_path):
				var image := Image.load_from_file(abs_path)
				if image:
					_art_texture = ImageTexture.create_from_image(image)
			if _art_texture == null:
				push_warning("CardVisual: art not found for '%s': %s" % [card_id, art_path])

	queue_redraw()


# ── Per-Frame ─────────────────────────────────────────────────────────────────

func _process(_delta: float) -> void:
	var state := CardEngine.get_card_state(_instance_id)
	var lifted: bool = state in [
		CardEngine.State.DRAGGED,
		CardEngine.State.ATTRACTING,
		CardEngine.State.SNAPPING,
	]

	if lifted != _is_lifted:
		_is_lifted = lifted
		scale      = DRAG_SCALE if lifted else IDLE_SCALE
		queue_redraw()


# ── Rendering ─────────────────────────────────────────────────────────────────

func _draw() -> void:
	var half := CARD_SIZE * 0.5

	# Drop shadow — offset rect, only when lifted
	if _is_lifted:
		draw_rect(
			Rect2(-half + SHADOW_OFFSET, CARD_SIZE),
			COLOR_SHADOW
		)

	# Card background
	draw_rect(Rect2(-half, CARD_SIZE), COLOR_CARD_BG)

	# Card border
	draw_rect(Rect2(-half, CARD_SIZE), COLOR_CARD_BORDER, false, 1.5)

	# Art region: centered, shifted slightly below the card center to leave room for label
	var art_center := Vector2(0.0, 8.0)
	if _art_texture != null:
		# Draw texture square, then redraw circle border on top.
		# Full circular clip deferred until shader pipeline is configured.
		var art_rect := Rect2(
			art_center - Vector2(ART_RADIUS, ART_RADIUS),
			Vector2(ART_RADIUS * 2.0, ART_RADIUS * 2.0)
		)
		draw_texture_rect(_art_texture, art_rect, false)
	else:
		draw_circle(art_center, ART_RADIUS, COLOR_ART_FILL)

	# Art circle border (defines the circular boundary visually)
	draw_arc(art_center, ART_RADIUS, 0.0, TAU, 48, COLOR_CARD_BORDER, 1.0)

	# Label — top of card, single line, clipped by card width
	var font := ThemeDB.fallback_font
	var label_y := -half.y + float(LABEL_FONT_SIZE) + 4.0
	var label_x := -half.x + 6.0
	var max_w   := CARD_SIZE.x - 12.0
	draw_string(
		font, Vector2(label_x, label_y), _display_name,
		HORIZONTAL_ALIGNMENT_LEFT, max_w, LABEL_FONT_SIZE, COLOR_LABEL
	)
