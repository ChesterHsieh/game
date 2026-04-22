# Story 002: Scene composition and Polygon2D overlay

> **Epic**: Scene Transition UI
> **Status**: Complete
> **Layer**: Presentation
> **Type**: Integration
> **Manifest Version**: 2026-04-21

## Context

**GDD**: `design/gdd/scene-transition-ui.md`
**Requirements**: `TR-scene-transition-ui-001`, `TR-scene-transition-ui-005`, `TR-scene-transition-ui-009`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-004: Runtime Scene Composition
**ADR Decision Summary**: ADR-004 §2 specifies the canonical `gameplay.tscn` node tree: STUI lives under `TransitionLayer` (CanvasLayer, layer=10) as a child of the main gameplay scene — it is never an autoload. The root STUI node sets `process_mode = PROCESS_MODE_ALWAYS` so Tweens run even if the game tree is paused.

**Engine**: Godot 4.3 | **Risk**: LOW
**Engine Notes**: Tween API (`create_tween()`, `tween_property()`, `Tween.kill()`), `CanvasLayer`, `Polygon2D` vertex array write, `MOUSE_FILTER_STOP`/`MOUSE_FILTER_IGNORE`, `PROCESS_MODE_ALWAYS` all stable in 4.3. `CONNECT_ONE_SHOT` flag stable.

**Control Manifest Rules (Presentation Layer)**:
- Required: gameplay.tscn CanvasLayer stack — TransitionLayer at layer=10, EpilogueLayer at layer=20
- Required: STUI emits `epilogue_cover_ready` when amber cover reaches full opacity; FES waits on this
- Required: HudLayer hides itself on `epilogue_started`
- Forbidden: Never change CanvasLayer ordering without a new ADR
- Forbidden: Never call `change_scene_to_file` during epilogue handoff
- Forbidden: Never use `FileAccess` + JSON for data — use ResourceLoader + typed Resource

---

## Acceptance Criteria

*From GDD `design/gdd/scene-transition-ui.md`, scoped to this story:*

- [ ] **AC-017** With a real EventBus autoload, emitting `scene_completed("home")` then `scene_started("park")` drives IDLE → FADING_OUT → HOLDING → FADING_IN → IDLE within total_min_ms..total_max_ms wall-clock budget. This is the full happy-path smoke test.

---

## Implementation Notes

*Derived from ADR-004 §2:*

- `scene_transition_ui.tscn` is instanced as the child of `TransitionLayer` (CanvasLayer, layer=10) inside `gameplay.tscn`. It is **not** an autoload and is not registered in `project.godot`. It dies with `gameplay.tscn` on quit-to-menu (GDD Core Rule 1).
- The node tree of `scene_transition_ui.tscn` per GDD UI Requirements:
  ```
  SceneTransitionUI (CanvasLayer, layer=10, process_mode=ALWAYS)
  ├── InputBlocker  (ColorRect, anchors_preset=PRESET_FULL_RECT, modulate.a=0)
  ├── Overlay       (Polygon2D, textured with paper_texture.png, modulate.a=0 initially)
  └── RustleAudio   (AudioStreamPlayer, bus=SFX_UI)
  ```
- `process_mode = PROCESS_MODE_ALWAYS` on the STUI root propagates to all children including `RustleAudio` — intentional so audio continues through any future pause overlay (GDD Engine/Platform assumptions, ADR-004 §1).
- **Polygon2D geometry** — 12-segment vertical strip: 13 top-edge vertices + 13 bottom-edge vertices = 26 polygon points. Vertex positions are computed from `get_viewport().size` at each transition start (GDD UI Requirements, Viewport Responsiveness). No hardcoded pixel coordinates.
- Vertices span the full viewport width (x: 0 to `viewport_size.x`) and full height (y: 0 and `viewport_size.y`) with 13 columns evenly spaced across x. Top-edge vertices are polygon points 0–12; bottom-edge vertices are 13–25 (or stored as interleaved pairs — implementation detail, must produce the 12-segment strip described in GDD).
- **z_index within STUI**: `InputBlocker.z_index = 0`, `Overlay.z_index = 1` (GDD UI Requirements, Z-ordering contract — InputBlocker is a Control, Overlay is a Node2D; ordering between them is explicit via z_index).
- The full happy-path integration test (AC-017) requires: a real `EventBus` autoload present in the test scene; STUI instanced as a child of a CanvasLayer; timing measured from emit of `scene_completed` to STUI reaching `IDLE` state after the full cycle. Total wall-clock must fall within [T_MIN, T_MAX] ms as set by the nominal knobs.

---

## Out of Scope

- Story 001: state machine enum, signal subscriptions, signal-storm guard
- Story 003: InputSystem.cancel_drag() call, mouse event absorption verification
- Story 004: timing formulas (Formula 1–4), phase variation and clamping
- Story 005: epilogue variant, FIRST_REVEAL
- Story 006: transition-variants.tres config loading, reduced-motion path

---

## QA Test Cases

*Integration — automated (`tests/integration/scene-transition-ui/stui_scene_composition_test.gd`):*

- **AC-017**: Full happy-path IDLE → FADING_OUT → HOLDING → FADING_IN → IDLE
  - Given: A test scene with `EventBus` autoload active; `SceneTransitionUI` instanced under a CanvasLayer (layer=10); STUI starts in `State.IDLE`
  - When: `EventBus.scene_completed.emit("home")` is emitted; then after STUI enters `HOLDING`, `EventBus.scene_started.emit("park")` is emitted
  - Then: STUI passes through states FADING_OUT → HOLDING → FADING_IN → IDLE; total wall-clock time from `scene_completed` emit to reaching `IDLE` is within `[total_min_ms, total_max_ms]` (default 1700ms–2200ms)
  - Edge cases:
    - Verify Overlay `modulate.a` equals 1.0 when HOLDING is entered
    - Verify Overlay `modulate.a` equals 0.0 when IDLE is entered after FADING_IN
    - Verify `InputBlocker.mouse_filter == MOUSE_FILTER_STOP` throughout FADING_OUT, HOLDING, FADING_IN
    - Verify `InputBlocker.mouse_filter == MOUSE_FILTER_IGNORE` when IDLE is re-entered

- **Polygon2D geometry smoke**:
  - Given: A STUI instance with a known viewport size (e.g., 1280×720)
  - When: A transition is triggered and vertex positions are computed
  - Then: The `Overlay.polygon` array contains exactly 26 Vector2 points; x-coordinates of top-edge vertices span [0, 1280]; y-coordinates of top-edge vertices are all 0; y-coordinates of bottom-edge vertices are all 720; vertex spacing is uniform (13 evenly spaced columns)
  - Edge cases: viewport size of 1920×1080; vertex positions scale correctly

- **process_mode smoke**:
  - Given: STUI is mid-transition (FADING_OUT) and the scene tree is paused (`get_tree().paused = true`)
  - When: Process frames advance
  - Then: The rise Tween continues to completion — STUI enters HOLDING despite tree pause
  - Edge cases: Unpause mid-HOLDING; fade Tween must continue normally

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/scene-transition-ui/stui_scene_composition_test.gd` (automated, must pass)
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (core state machine and signal subscriptions)
- Unlocks: Story 003 (input blocking and drag cancel)
