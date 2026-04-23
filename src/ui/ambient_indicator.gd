## AmbientIndicator — per-scene decorative parchment background.
##
## Lives in gameplay.tscn on BackgroundLayer (CanvasLayer=-1 so it sits
## behind the CardTable and everything else). Subscribes to
## EventBus.scene_started and swaps its TextureRect texture per the
## current scene's JSON `ambient` block. Purely decorative — no gameplay
## semantics, no signal emissions, no input consumption.
##
## The concept evolved from the first cut (small corner vignette) into a
## full-viewport parchment plate with ornamental filigree borders whose
## corners subtly weave in scene-themed motifs. The node name stays
## AmbientIndicator for compatibility; "background plate" is the term
## used in the scene spec (_TEMPLATE.md §10.2).
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


@onready var _texture_rect: TextureRect = $TextureRect


func _ready() -> void:
	# Hidden at boot so there's no flash of stale texture before the
	# first scene_started fires (AC-6).
	_texture_rect.hide()
	# Input pass-through — even as a full-viewport background, the plate
	# must not swallow card drags (AC-4). Both Control and TextureRect
	# get MOUSE_FILTER_IGNORE.
	_texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	EventBus.scene_started.connect(_on_scene_started)


func _on_scene_started(scene_id: String) -> void:
	var data: Dictionary = _read_scene_json(scene_id)
	if data.is_empty():
		_texture_rect.hide()
		return

	var ambient: Dictionary = data.get("ambient", {})
	var ambient_path: String = String(ambient.get("path", "none"))
	if ambient_path == "" or ambient_path == "none":
		_texture_rect.hide()
		return

	var tex: Texture2D = load(ambient_path) as Texture2D
	if tex == null:
		push_warning(
			"AmbientIndicator: could not load '%s' for scene '%s' — hiding plate"
			% [ambient_path, scene_id])
		_texture_rect.hide()
		return

	_texture_rect.texture    = tex
	_texture_rect.modulate.a = clampf(float(ambient.get("alpha", DEFAULT_ALPHA)), 0.0, 1.0)

	var anchor_name: String = String(ambient.get("anchor", DEFAULT_ANCHOR))
	_apply_anchor(anchor_name, ambient)

	_texture_rect.show()


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


## Positions the TextureRect. Two modes:
##
##   full_viewport (default) — anchored to all four corners, filling the
##     whole logical viewport. The background stretches to fit; the
##     generated PNG is designed to tolerate aspect changes because the
##     centre is blank parchment and the ornamental border stays on the
##     edges regardless.
##
##   bottom_right (legacy corner mode) — small 160×160 vignette in the
##     bottom-right, kept for spec-backward-compatibility.
func _apply_anchor(anchor_name: String, ambient: Dictionary) -> void:
	match anchor_name:
		"full_viewport":
			_texture_rect.anchor_left   = 0.0
			_texture_rect.anchor_top    = 0.0
			_texture_rect.anchor_right  = 1.0
			_texture_rect.anchor_bottom = 1.0
			_texture_rect.offset_left   = 0.0
			_texture_rect.offset_top    = 0.0
			_texture_rect.offset_right  = 0.0
			_texture_rect.offset_bottom = 0.0
			_texture_rect.expand_mode   = TextureRect.EXPAND_IGNORE_SIZE
			_texture_rect.stretch_mode  = TextureRect.STRETCH_SCALE
			_texture_rect.custom_minimum_size = Vector2.ZERO
		"bottom_right":
			var size_block: Dictionary = ambient.get("size_px", {})
			var size: Vector2 = Vector2(
				float(size_block.get("w", LEGACY_CORNER_SIZE.x)),
				float(size_block.get("h", LEGACY_CORNER_SIZE.y)))
			_texture_rect.anchor_left   = 1.0
			_texture_rect.anchor_top    = 1.0
			_texture_rect.anchor_right  = 1.0
			_texture_rect.anchor_bottom = 1.0
			_texture_rect.offset_left   = -size.x - CORNER_MARGIN
			_texture_rect.offset_top    = -size.y - CORNER_MARGIN
			_texture_rect.offset_right  = -CORNER_MARGIN
			_texture_rect.offset_bottom = -CORNER_MARGIN
			_texture_rect.expand_mode   = TextureRect.EXPAND_IGNORE_SIZE
			_texture_rect.stretch_mode  = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			_texture_rect.custom_minimum_size = size
		_:
			push_warning(
				"AmbientIndicator: unknown anchor '%s' — falling back to full_viewport"
				% anchor_name)
			_apply_anchor("full_viewport", ambient)
