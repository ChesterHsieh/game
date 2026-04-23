# Story 006: Ambient Indicator — per-scene parchment place cue

> **Epic**: scene-composition
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Integration
> **Manifest Version**: 2026-04-21

## Context

**GDD / Spec**: `design/scenes/_TEMPLATE.md` §10.2 (Ambient Indicator) —
a small decorative vignette pinned to a corner of the viewport that
signals *where* the scene takes place. Purely set dressing; no gameplay
semantics.

**ADR Governing Implementation**: ADR-004 (runtime scene composition —
the indicator is a child of `gameplay.tscn`, not a new autoload)

**Engine**: Godot 4.3 | **Risk**: LOW
**Engine Notes**: `TextureRect`, `CanvasLayer`, `Control.anchor_*`,
`modulate.a`, `get_tree().current_scene` — all stable in 4.3.

**Control Manifest Rules (Presentation)**:
- Required: element sits on a CanvasLayer within `gameplay.tscn`
- Required: `mouse_filter = MOUSE_FILTER_IGNORE` on every node under the
  indicator so drags pass through to cards
- Forbidden: element emits / reads any EventBus signal except the
  `scene_started` subscription used to swap its texture

---

## Acceptance Criteria

- [ ] **AC-1** `gameplay.tscn` gains an `AmbientLayer` (CanvasLayer,
      `layer = 6` — above HudLayer=5, below TransitionLayer=10) with a
      child `AmbientIndicator` (Control anchored bottom-right) that hosts
      a `TextureRect`.
- [ ] **AC-2** `AmbientIndicator` subscribes to
      `EventBus.scene_started` in `_ready()` via a non-CONNECT_ONE_SHOT
      connection (fires once per scene entry).
- [ ] **AC-3** On each `scene_started(scene_id)`, the indicator loads
      `assets/data/scenes/[scene_id].json`, reads the
      `ambient` block (new optional field), and:
  - If `ambient.path == "none"` or field missing: hide the TextureRect
  - Else: set `texture = load(ambient.path)`, `anchor_*` per
    `ambient.anchor`, size per `ambient.size_px`, `modulate.a` per
    `ambient.alpha` (defaults: `bottom_right`, `{w:160,h:120}`, `0.85`)
- [ ] **AC-4** `mouse_filter = MOUSE_FILTER_IGNORE` on the AmbientLayer
      CanvasLayer children; card drags in the bottom-right quadrant
      must still register (manual verify on coffee-intro).
- [ ] **AC-5** Missing PNG (`load()` returns null) must not crash; hide
      the TextureRect and emit `push_warning` naming the scene_id.
- [ ] **AC-6** The indicator is hidden by default at `_ready()` until the
      first `scene_started` fires (no flash of stale texture).

---

## Implementation Notes

### gameplay.tscn additions

```
GameplayRoot (Node2D)
├── HudLayer (CanvasLayer, layer=5)
├── AmbientLayer (CanvasLayer, layer=6)           ← NEW
│   └── AmbientIndicator (Control, anchor bottom-right)  ← NEW
│       └── TextureRect (expand_mode = IGNORE_SIZE)
├── TransitionLayer (CanvasLayer, layer=10)
├── SettingsPanelHost (CanvasLayer, layer=15)
└── EpilogueLayer (CanvasLayer, layer=20)
```

### Script skeleton — `src/ui/ambient_indicator.gd`

```gdscript
extends Control

const SCENES_PATH := "res://assets/data/scenes/"

@onready var _texture_rect: TextureRect = $TextureRect


func _ready() -> void:
    _texture_rect.hide()
    EventBus.scene_started.connect(_on_scene_started)


func _on_scene_started(scene_id: String) -> void:
    var path := SCENES_PATH + scene_id + ".json"
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        _texture_rect.hide()
        return
    var json := JSON.new()
    if json.parse(file.get_as_text()) != OK:
        _texture_rect.hide()
        return
    file.close()

    var data: Dictionary = json.data
    var ambient: Dictionary = data.get("ambient", {})
    var ambient_path: String = ambient.get("path", "none")
    if ambient_path == "none" or ambient_path == "":
        _texture_rect.hide()
        return

    var tex: Texture2D = load(ambient_path) as Texture2D
    if tex == null:
        push_warning("AmbientIndicator: could not load %s" % ambient_path)
        _texture_rect.hide()
        return

    _texture_rect.texture       = tex
    _texture_rect.custom_minimum_size = Vector2(
        ambient.get("size_px", {}).get("w", 160),
        ambient.get("size_px", {}).get("h", 120))
    _texture_rect.modulate.a    = float(ambient.get("alpha", 0.85))
    _apply_anchor(ambient.get("anchor", "bottom_right"))
    _texture_rect.show()


func _apply_anchor(anchor_name: String) -> void:
    # Map the four supported anchor names to Control anchor presets.
    # Add a small margin so the indicator doesn't touch the screen edge.
    const MARGIN := 16
    match anchor_name:
        "bottom_right":
            _texture_rect.anchor_left   = 1.0
            _texture_rect.anchor_top    = 1.0
            _texture_rect.anchor_right  = 1.0
            _texture_rect.anchor_bottom = 1.0
            _texture_rect.offset_left   = -_texture_rect.custom_minimum_size.x - MARGIN
            _texture_rect.offset_top    = -_texture_rect.custom_minimum_size.y - MARGIN
            _texture_rect.offset_right  = -MARGIN
            _texture_rect.offset_bottom = -MARGIN
        # bottom_left / top_right / top_left follow the same pattern
        _:
            push_warning("AmbientIndicator: unknown anchor '%s'" % anchor_name)
```

### Scene JSON additions

Scene JSON gains an optional `ambient` block. Example for coffee-intro
(once the PNG lands):

```json
"ambient": {
    "path": "res://assets/ambient/coffee-intro.png",
    "anchor": "bottom_right",
    "size_px": { "w": 160, "h": 120 },
    "alpha": 0.85
}
```

Absent block = indicator hidden. SceneGoal already passes `scene_id` to
`EventBus.scene_started` — no SceneGoal change needed; the indicator
loads the JSON itself to stay decoupled.

---

## Out of Scope

- The ambient PNGs themselves (commissioned via `/asset-spec` + nano-banana
  as each scene goes live)
- Per-scene animation on the indicator (future Polish-phase story)
- Click-to-expand or tooltip interactions (no gameplay semantics per spec)

---

## QA Test Cases

- **AC-1 (tree shape)**
  - Setup: open `gameplay.tscn` in editor
  - Verify: AmbientLayer (layer=6) exists between HudLayer and TransitionLayer
  - Pass: inspector confirms the node hierarchy

- **AC-3 (path switching)**
  - Setup: two scene JSONs — one with `ambient.path` set to a real PNG,
    one with `ambient.path = "none"`
  - Manually run both; verify first shows the PNG, second hides
  - Pass: texture visible / hidden matches spec

- **AC-4 (input pass-through)**
  - Setup: load a scene with ambient indicator visible; spawn a card at
    the bottom-right corner of the play area (cheat or adjust seed)
  - Drag that card over the indicator's bounding box
  - Pass: drag still registers in CardEngine (indicator does not swallow
    the event)

- **AC-5 (missing art tolerance)**
  - Setup: scene JSON points to a path that does not exist
  - Run the game and open that scene
  - Pass: indicator hides, a `push_warning` appears in the output, game
    continues normally

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: either an integration test or a documented manual
QA pass. Preferred: manual QA doc at
`production/qa/evidence/ambient-indicator-render-evidence.md` with
screenshots from coffee-intro once the PNG is commissioned.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 004 (gameplay.tscn must exist)
- Unlocks: per-scene ambient assets can be commissioned + dropped in
  without further code changes
