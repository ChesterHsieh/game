## AmbientIndicator — per-scene decorative parchment background.
##
## Lives in gameplay.tscn on AmbientLayer (CanvasLayer=-1 so it sits behind
## the CardTable and everything else). Subscribes to EventBus.scene_started
## and swaps a NinePatchRect's texture per the current scene's JSON
## `ambient` block.
##
## Rendering uses NinePatchRect with 9-slice margins so the four ornamental
## corners stay undistorted at their native pixel size while the centre and
## four edges stretch to fill any viewport aspect. This is why the frame
## "fully expands" to the viewport edges without distortion regardless of
## PNG aspect ratio vs. viewport ratio.
##
## A sibling `PaperBackfill` ColorRect (cream, set in gameplay.tscn) fills
## the same rect behind the NinePatchRect so if the player resizes or
## somehow exposes an edge, the underlying colour matches the parchment.
##
## Scene JSON `ambient` block shape (all fields optional):
##   "ambient": {
##       "path":   "res://assets/ambient/[scene-id].png" | "none",
##       "alpha":  0.9,
##       "anchor": "full_viewport" (default) | "bottom_right"  ← legacy corner
##   }
##
## Absent block or path = hidden plate.
##
## Spec: design/scenes/_TEMPLATE.md §10.2
## Story: production/epics/scene-composition/story-006-ambient-indicator-render.md
extends Control


const SCENES_PATH := "res://assets/data/scenes/"
const DEFAULT_ALPHA  := 0.9
const DEFAULT_ANCHOR := "full_viewport"
const LEGACY_CORNER_SIZE := Vector2(160.0, 160.0)  ## only used when anchor == "bottom_right"
const CORNER_MARGIN := 16.0


@onready var _nine_patch: NinePatchRect = $NinePatchRect
@onready var _cover_rect: TextureRect   = $CoverRect


func _ready() -> void:
	# Hidden at boot so there's no flash of stale texture before the
	# first scene_started fires (AC-6).
	_nine_patch.hide()
	_cover_rect.hide()
	# Input pass-through — even as a full-viewport background, the plate
	# must not swallow card drags (AC-4). All three Controls get
	# MOUSE_FILTER_IGNORE (set in .tscn too, belt-and-braces).
	_nine_patch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cover_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	EventBus.scene_started.connect(_on_scene_started)


func _on_scene_started(scene_id: String) -> void:
	var data: Dictionary = _read_scene_json(scene_id)
	if data.is_empty():
		_nine_patch.hide()
		_cover_rect.hide()
		return

	var ambient: Dictionary = data.get("ambient", {})
	var ambient_path: String = String(ambient.get("path", "none"))
	if ambient_path == "" or ambient_path == "none":
		_nine_patch.hide()
		_cover_rect.hide()
		return

	var tex: Texture2D = load(ambient_path) as Texture2D
	if tex == null:
		push_warning(
			"AmbientIndicator: could not load '%s' for scene '%s' — hiding plate"
			% [ambient_path, scene_id])
		_nine_patch.hide()
		_cover_rect.hide()
		return

	var alpha: float = clampf(float(ambient.get("alpha", DEFAULT_ALPHA)), 0.0, 1.0)
	var fit: String = String(ambient.get("fit", "nine_patch"))

	if fit == "cover":
		# Full-viewport composed artwork — use TextureRect with
		# STRETCH_KEEP_ASPECT_COVERED so the image fills the viewport
		# without distortion (cropping the overflow axis, like CSS
		# background-size: cover). Ignores `anchor` — always full_viewport.
		_cover_rect.texture    = tex
		_cover_rect.modulate.a = alpha
		_nine_patch.hide()
		_cover_rect.show()
	else:
		_nine_patch.texture    = tex
		_nine_patch.modulate.a = alpha
		var anchor_name: String = String(ambient.get("anchor", DEFAULT_ANCHOR))
		_apply_anchor(anchor_name, ambient)
		_cover_rect.hide()
		_nine_patch.show()


## Loads + parses `assets/data/scenes/[scene_id].json`. Returns {} on any
## failure (missing file, invalid JSON) — caller treats that as "no ambient".
func _read_scene_json(scene_id: String) -> Dictionary:
	var path := SCENES_PATH + scene_id + ".json"
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		file.close()
		return {}
	file.close()
	var parsed: Variant = json.data
	if parsed is Dictionary:
		return parsed as Dictionary
	return {}


## Positions the NinePatchRect. Two modes:
##
##   full_viewport (default) — anchored to all four corners, filling the
##     whole logical viewport. NinePatchRect's 9-slice keeps the four
##     ornamental corners at their native pixel size while the centre
##     + edges stretch to fill any viewport aspect. This is why the
##     frame doesn't distort no matter what aspect the source PNG is.
##
##   bottom_right (legacy corner mode) — small 160×160 vignette in the
##     bottom-right, kept for spec-backward-compatibility with any scene
##     that prefers a corner cue rather than a full background. In this
##     mode the 9-slice margins still apply but the output rect is small
##     so the corners essentially ARE the whole image.
func _apply_anchor(anchor_name: String, ambient: Dictionary) -> void:
	match anchor_name:
		"full_viewport":
			_nine_patch.anchor_left   = 0.0
			_nine_patch.anchor_top    = 0.0
			_nine_patch.anchor_right  = 1.0
			_nine_patch.anchor_bottom = 1.0
			_nine_patch.offset_left   = 0.0
			_nine_patch.offset_top    = 0.0
			_nine_patch.offset_right  = 0.0
			_nine_patch.offset_bottom = 0.0
			_nine_patch.custom_minimum_size = Vector2.ZERO
		"bottom_right":
			var size_block: Dictionary = ambient.get("size_px", {})
			var size: Vector2 = Vector2(
				float(size_block.get("w", LEGACY_CORNER_SIZE.x)),
				float(size_block.get("h", LEGACY_CORNER_SIZE.y)))
			_nine_patch.anchor_left   = 1.0
			_nine_patch.anchor_top    = 1.0
			_nine_patch.anchor_right  = 1.0
			_nine_patch.anchor_bottom = 1.0
			_nine_patch.offset_left   = -size.x - CORNER_MARGIN
			_nine_patch.offset_top    = -size.y - CORNER_MARGIN
			_nine_patch.offset_right  = -CORNER_MARGIN
			_nine_patch.offset_bottom = -CORNER_MARGIN
			_nine_patch.custom_minimum_size = size
		_:
			push_warning(
				"AmbientIndicator: unknown anchor '%s' — falling back to full_viewport"
				% anchor_name)
			_apply_anchor("full_viewport", ambient)
