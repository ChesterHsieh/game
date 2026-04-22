# Story 005: Visual layout and error fallbacks

> **Epic**: Final Epilogue Screen
> **Status**: Complete
> **Layer**: Presentation
> **Type**: UI
> **Manifest Version**: 2026-04-21

## Context

**GDD**: `design/gdd/final-epilogue-screen.md`
**Requirements**: `TR-final-epilogue-screen-010`, `TR-final-epilogue-screen-014`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-001: Naming Conventions — snake_case
**ADR Decision Summary**: Files follow snake_case (`final_epilogue_screen.gd`, `final_epilogue_screen.tscn`); classes are PascalCase (`FinalEpilogueScreen`); constants are SCREAMING_SNAKE_CASE (`ILLUSTRATION_PATH`). All node names in the scene tree follow the same PascalCase convention used for nodes across the project.

**Engine**: Godot 4.3 | **Risk**: LOW
**Engine Notes**: `Control` with `PRESET_FULL_RECT` (via `set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)` in code, or anchor properties set to 0/1/0/1 in scene) is stable in 4.3. `ColorRect` is stable. `CenterContainer` is stable. `TextureRect` with `expand_mode = TextureRect.EXPAND_KEEP_ASPECT_CENTERED` is stable in 4.3 — this replaces the deprecated Godot 3.x `stretch_mode`. `ResourceLoader.load()` returning `null` on failure (missing or corrupt file) is the documented error path in 4.3.

**Control Manifest Rules (Presentation Layer)**:
- Required: EpilogueLayer is CanvasLayer layer=20; FES pre-instanced in Armed state
- Required: FES root is `Control` with `PRESET_FULL_RECT`; modulate-driven fade
- Forbidden: No UI chrome of any kind over the image — no text, no labels, no buttons, no watermarks
- Forbidden: Never make FES its own autoload or use `change_scene_to_file` to reach it

---

## Acceptance Criteria

*From GDD `design/gdd/final-epilogue-screen.md`, scoped to this story:*

- [ ] **AC-VISUAL-1**: The illustration is centered in the viewport at all supported resolutions (1024×768, 1920×1080, 3840×2160). No clipping, no stretching beyond aspect ratio.
- [ ] **AC-VISUAL-2**: The image is fully visible at alpha = 1.0 at `t = FADE_IN_DURATION` post-cover-ready. No UI chrome, text, or overlay is rendered at any time during or after FES.
- [ ] **AC-FAIL-2**: If the illustration PNG fails to load, FES renders the background color only (no crash, no exception). Stderr log produced.

---

## Implementation Notes

*Derived from ADR-001 and GDD Detailed Design §Core Rule 3, §Visual/Audio Requirements — Visual, §Edge Cases EC-3, EC-12, EC-14:*

**Scene root — `Control` with `PRESET_FULL_RECT` (GDD Core Rule 3)**:
- Root node type: `Control`
- Anchor preset: `PRESET_FULL_RECT` — fills the viewport in all directions
- `mouse_filter = Control.MOUSE_FILTER_IGNORE` on ALL Control nodes in the tree so click events propagate to `_unhandled_input` at the scene root (GDD Core Rule 3 explicit requirement)
- The root `Control` is the node whose `modulate.a` is animated by the Tween (see Story 002)

**Node tree**:
```
FinalEpilogueScreen (Control, PRESET_FULL_RECT, mouse_filter=IGNORE)  ← scene root / script host
└── Background (ColorRect, anchors full_rect, mouse_filter=IGNORE)     ← solid color fill
└── IllustrationContainer (CenterContainer, PRESET_FULL_RECT, mouse_filter=IGNORE)
    └── Illustration (TextureRect, expand_mode=KEEP_ASPECT_CENTERED, mouse_filter=IGNORE)
```

`CenterContainer` with `PRESET_FULL_RECT` centers its single child in the available viewport space. `TextureRect.expand_mode = TextureRect.EXPAND_KEEP_ASPECT_CENTERED` scales the texture up or down to fit while preserving aspect ratio — small windows letterbox, large windows scale up and center (GDD EC-12).

**No UI chrome rule (GDD §Visual/Audio Requirements — hard rule)**:
No `Label`, `Button`, `RichTextLabel`, `Panel`, or any other visible UI node may be added to the FES scene tree at any point. No "Press any key" prompt. No title. No credits. No watermarks. No `ProgressBar`. This is enforced by the scene tree structure above — only `ColorRect` and `TextureRect` render content.

**Illustration load and missing-PNG fallback (GDD EC-3, TR-final-epilogue-screen-014)**:
```gdscript
const ILLUSTRATION_PATH: String = "res://assets/epilogue/illustration.png"

func _load_illustration() -> void:
    var texture: Texture2D = ResourceLoader.load(ILLUSTRATION_PATH, "Texture2D") as Texture2D
    if texture == null:
        push_error("FES: illustration PNG failed to load from '%s' — rendering background color only" % ILLUSTRATION_PATH)
        # TextureRect with null texture renders nothing; ColorRect (Background) remains visible
        return
    _illustration.texture = texture
```
`ResourceLoader.load()` returns `null` on failure (file not found, decode error, disk read error). The `as Texture2D` cast makes this explicit. When `null`, `push_error()` logs to stderr and the function returns early. `_illustration.texture` remains `null` — a `TextureRect` with no texture renders as transparent, which over the `ColorRect` background produces a clean solid-color result with no visible error state (GDD EC-3 fallback: "FES still loads but displays a fallback state — solid-color background, no illustration").

**`@onready` references (ADR-001 / GDScript standard)**:
```gdscript
@onready var _background: ColorRect = %Background
@onready var _illustration: TextureRect = %Illustration
@onready var _cover_ready_timeout_timer: Timer = %CoverReadyTimeoutTimer
```
Unique names (`%`) used for direct scene-tree lookup without fragile path strings.

**Window resize handling (GDD EC-14)**:
No custom code required. Godot's `Control` layout engine recomputes anchors and `CenterContainer` centering automatically on viewport size change. `TextureRect.EXPAND_KEEP_ASPECT_CENTERED` re-scales at the new size. The Tween continues on `modulate:a` (a scalar property, unaffected by layout changes).

**`ILLUSTRATION_PATH` as `const String` (GDD §Tuning Knobs)**:
Per GDD §Tuning Knobs note: `const` is chosen over `@export` because `@export` and `const` are mutually exclusive in GDScript, and this value is a frozen-once asset path, not a per-scene designer knob. Changing the illustration requires both a code edit and a file on disk — intentional coupling.

**`_load_illustration()` call timing**: called from `_on_epilogue_cover_ready()` (the Loading → Ready transition) before the Tween starts, so the texture is resident by the time alpha begins rising.

---

## Out of Scope

- Story 001: The `_ready()` guard sequence, CONNECT_ONE_SHOT wiring, and `_on_epilogue_cover_ready` entry point
- Story 002: The Tween creation and state machine
- Story 003: Input filter and dismiss logic
- Story 004: AudioManager call and COVER_READY_TIMEOUT timer

---

## QA Test Cases

*UI — manual:*

- **AC-VISUAL-1**: Illustration centered at 1024×768, 1920×1080, 3840×2160
  - Setup: set Godot window size to each resolution; reach FES reveal (or force-call `_on_epilogue_cover_ready()` in the editor with a placeholder PNG); wait for `modulate.a = 1.0`
  - Verify: illustration bounding box is horizontally and vertically centered within ±2 pixels; no clipping at edges; illustration is not stretched (aspect ratio preserved); margins are present on all sides (illustration fills ~80% of shorter dimension)
  - Pass condition: screenshot pixel-check at three resolutions; bounding box center matches viewport center ±2px; aspect ratio delta < 0.5%

- **AC-VISUAL-2**: No UI chrome at any point during or after FES
  - Setup: run game to epilogue; observe FES from Armed through Holding states
  - Verify: at every state — Armed (alpha=0), Revealing (alpha 0→1), Blackout (alpha=1), Holding (alpha=1) — no text, no buttons, no labels, no watermarks, no progress indicators are visible. Take screenshots at `t=0`, `t=FADE_IN_DURATION/2`, `t=FADE_IN_DURATION`, `t=FADE_IN_DURATION + INPUT_BLACKOUT_DURATION + 500ms`
  - Pass condition: each screenshot contains only the background color and illustration pixels; pixel-diff against a reference image of the illustration on the background color; any unexpected pixels at a non-illustration location fail the test

- **AC-FAIL-2**: Missing/corrupt PNG → background color only, no crash
  - Setup: rename or remove `res://assets/epilogue/illustration.png`; instantiate FES scene; trigger `_on_epilogue_cover_ready()` (or emit `epilogue_cover_ready` from EventBus)
  - Verify: no GDScript exception raised; no crash; FES reaches `modulate.a = 1.0` normally; screen shows only the background `ColorRect` color; stderr contains the error message with `ILLUSTRATION_PATH` and description
  - Pass condition: game process is still alive after `FADE_IN_DURATION`; `Input.mouse_mode == MOUSE_MODE_HIDDEN`; no error dialog visible to user; stderr log line confirmed in console

*Automated screenshot test (advisory — to be written as part of implementation)*:

- **AC-VISUAL-1 automated**: pixel-check at three resolutions
  - Given: FES instantiated with a known test PNG (solid red 512×512 square)
  - When: Tween completes (`modulate.a = 1.0`); screenshot captured
  - Then: red bounding box center matches viewport center ±2px at 1024×768, 1920×1080, 3840×2160
  - Evidence location: `production/qa/evidence/fes-visual-layout-evidence.md`

---

## Test Evidence

**Story Type**: UI
**Required evidence**: `production/qa/evidence/fes-visual-layout-evidence.md`
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (Pre-instancing and CONNECT_ONE_SHOT — the scene must exist as a child of EpilogueLayer before layout testing is meaningful); Story 002 (the Tween animates `modulate:a` on the scene root Control node defined here)
- Unlocks: None (this is the final story in the epic dependency chain)
