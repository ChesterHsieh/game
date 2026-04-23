## AmbientIndicator — per-scene parchment place cue.
##
## Pinned to the bottom-right of gameplay.tscn's AmbientLayer (CanvasLayer=6).
## Subscribes to EventBus.scene_started and swaps its TextureRect texture
## per the current scene's JSON `ambient` block. Purely decorative — no
## gameplay semantics, no signal emissions, no input consumption.
##
## Scene JSON `ambient` block shape (all fields optional):
##   "ambient": {
##       "path":    "res://assets/ambient/[scene-id].png" | "none",
##       "anchor":  "bottom_right" | "bottom_left" | "top_right" | "top_left",
##       "size_px": { "w": 160, "h": 120 },
##       "alpha":   0.85
##   }
##
## Absent block or path = hidden indicator.
##
## Spec: design/scenes/_TEMPLATE.md §10.2
## Story: production/epics/scene-composition/story-006-ambient-indicator-render.md
extends Control


const SCENES_PATH := "res://assets/data/scenes/"
const DEFAULT_ANCHOR := "bottom_right"
const DEFAULT_SIZE   := Vector2(160.0, 120.0)
const DEFAULT_ALPHA  := 0.85
const EDGE_MARGIN    := 16.0


@onready var _texture_rect: TextureRect = $TextureRect


func _ready() -> void:
	# Hidden at boot so there's no flash of stale texture before the
	# first scene_started fires (AC-6).
	_texture_rect.hide()
	# Belt-and-braces: ensure the whole subtree is input-transparent so
	# card drags under the indicator still register (AC-4).
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
			"AmbientIndicator: could not load '%s' for scene '%s' — hiding indicator"
			% [ambient_path, scene_id])
		_texture_rect.hide()
		return

	var size_block: Dictionary = ambient.get("size_px", {})
	var target_size: Vector2 = Vector2(
		float(size_block.get("w", DEFAULT_SIZE.x)),
		float(size_block.get("h", DEFAULT_SIZE.y)))

	_texture_rect.texture             = tex
	_texture_rect.expand_mode         = TextureRect.EXPAND_IGNORE_SIZE
	_texture_rect.stretch_mode        = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_texture_rect.custom_minimum_size = target_size
	_texture_rect.modulate.a          = clampf(float(ambient.get("alpha", DEFAULT_ALPHA)), 0.0, 1.0)

	var anchor_name: String = String(ambient.get("anchor", DEFAULT_ANCHOR))
	_apply_anchor(anchor_name, target_size)

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


## Positions the TextureRect in the named corner of the viewport with a
## small edge margin. `size` is the logical width/height of the indicator.
func _apply_anchor(anchor_name: String, size: Vector2) -> void:
	match anchor_name:
		"bottom_right":
			_set_corner_anchor(1.0, 1.0, -size.x - EDGE_MARGIN, -size.y - EDGE_MARGIN, -EDGE_MARGIN, -EDGE_MARGIN)
		"bottom_left":
			_set_corner_anchor(0.0, 1.0, EDGE_MARGIN, -size.y - EDGE_MARGIN, size.x + EDGE_MARGIN, -EDGE_MARGIN)
		"top_right":
			_set_corner_anchor(1.0, 0.0, -size.x - EDGE_MARGIN, EDGE_MARGIN, -EDGE_MARGIN, size.y + EDGE_MARGIN)
		"top_left":
			_set_corner_anchor(0.0, 0.0, EDGE_MARGIN, EDGE_MARGIN, size.x + EDGE_MARGIN, size.y + EDGE_MARGIN)
		_:
			push_warning("AmbientIndicator: unknown anchor '%s' — falling back to bottom_right" % anchor_name)
			_set_corner_anchor(1.0, 1.0, -size.x - EDGE_MARGIN, -size.y - EDGE_MARGIN, -EDGE_MARGIN, -EDGE_MARGIN)


func _set_corner_anchor(ax: float, ay: float, ol: float, ot: float, or_: float, ob: float) -> void:
	_texture_rect.anchor_left   = ax
	_texture_rect.anchor_top    = ay
	_texture_rect.anchor_right  = ax
	_texture_rect.anchor_bottom = ay
	_texture_rect.offset_left   = ol
	_texture_rect.offset_top    = ot
	_texture_rect.offset_right  = or_
	_texture_rect.offset_bottom = ob
