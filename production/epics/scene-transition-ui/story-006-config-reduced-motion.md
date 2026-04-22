# Story 006: Config data and reduced-motion path

> **Epic**: Scene Transition UI
> **Status**: Complete
> **Layer**: Presentation
> **Type**: Logic
> **Manifest Version**: 2026-04-21

## Context

**GDD**: `design/gdd/scene-transition-ui.md`
**Requirements**: `TR-scene-transition-ui-012`, `TR-scene-transition-ui-013`, `TR-scene-transition-ui-014`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-005: Data File Format Convention, ADR-004: Runtime Scene Composition
**ADR Decision Summary**: ADR-005 §1 mandates `.tres` for all config data — `transition-variants.tres` must be a `TransitionVariants extends Resource` loaded via `ResourceLoader` with `as TransitionVariants` cast and null check. JSON and `FileAccess` are forbidden. ADR-004 §2 governs where STUI reads `ProjectSettings` for reduced-motion: at the start of each transition, not cached at boot.

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

- [ ] **AC-014** Reduced-motion path: when `reduced_motion == true`, transition total equals `reduced_motion_rise_ms + reduced_motion_hold_ms + reduced_motion_fade_ms` (400+600+400 = 1400ms default), curl vertex displacement is zero, and paper-breathe is disabled.
- [ ] **AC-020** STUI never writes save-state, never calls `get_tree().change_scene_to_*`, never emits `scene_loading`/`scene_started`/`scene_completed`, and never creates a text-bearing Node in release builds. (The only signal STUI emits is `epilogue_cover_ready`; debug builds may render `debug_draw_state`.)
- [ ] **Edge Case E-10** `transition-variants.tres` is missing or wrong `class_name` (`as TransitionVariants` cast returns null) → STUI uses hardcoded default tuning knobs and logs a warning at `_enter_tree()`. Color values are validated (clamped to [0,1] per channel); out-of-range entries fall back to default tint.

---

## Implementation Notes

*Derived from ADR-005 §1–§4 and GDD Core Rules 11–12:*

### transition-variants.tres loading (ADR-005)

- The `TransitionVariants` Resource class is declared as:
  ```gdscript
  class_name TransitionVariants extends Resource
  @export var variants: Dictionary = {}
  # variants = { "scene_id": { "fold_duration_scale": float, "paper_tint": Color, ... } }
  ```
  Class file lives in `res://src/data/transition_variants.gd` (ADR-001 naming: snake_case file, PascalCase class).
- At `_enter_tree()`, STUI attempts to load `assets/data/ui/transition-variants.tres` via `ResourceLoader.load("res://assets/data/ui/transition-variants.tres") as TransitionVariants`. The `as TransitionVariants` cast is mandatory — bare cast-less loads are a code-review reject per ADR-005 §9 (Control Manifest Forbidden: `bare_null_check_on_resource_load`).
- If the cast returns null (file missing, wrong type, wrong `class_name`): log a warning with `push_warning(...)` naming the missing file path; proceed with hardcoded defaults (GDD Edge Case E-10). Do not crash or error-out.
- Per-scene lookup: at each transition start, look up `scene_id` in `_variants_resource.variants`. If the key is absent, fall back to `"default"`. If `"default"` is also absent, use hardcoded defaults. Only keys defined in GDD Tuning Knobs §Per-scene override are consumed; any unrecognised keys are silently ignored.
- Color values from config are validated: each channel `r`, `g`, `b` is clamped to `[0.0, 1.0]` before use. Out-of-range entries fall back to the default tint for that phase (GDD E-10).
- **Forbidden**: never use `FileAccess.open(...)` + `JSON.parse_string(...)` for this file. Never write `.json` paths under `res://assets/data/`. These are registered forbidden patterns in the Control Manifest and ADR-005 §9.

### Reduced-motion path (GDD Core Rule 11)

- At the start of each transition, read `ProjectSettings.get_setting("stui/reduced_motion_default", false)` as a `bool`. This is read fresh per transition — not cached at boot — so changes during a dev session (E-9) take effect on the next transition without a restart.
- When `reduced_motion == true`, the path is a **slowed flat page-lift** — not a crossfade (GDD Core Rule 11 explicitly forbids a crossfade for accessibility users):
  - Rise: `reduced_motion_rise_ms` (default 400ms), linear ease (not ease-in-quad)
  - Hold: `reduced_motion_hold_ms` (default 600ms)
  - Fade-out: `reduced_motion_fade_ms` (default 400ms), linear ease (not ease-out-cubic)
  - Curl vertex displacement: zero (`θ = 0.0`); Polygon2D stays flat
  - Rotation: none
  - Paper-breathe: disabled (`A = 0`)
  - Audio pitch variation: `p = 1.0` (locked); rustle and settle SFX still play
  - Total: 400+600+400 = 1400ms — **not subject to T_MIN/T_MAX clamp** (GDD Formula 1, Clamp section)
  - Epilogue variant: same reduced path with amber tint and open-ended hold

### Statelessness (GDD Core Rule 12, AC-020)

- STUI persists nothing. It never calls `ResourceSaver.save(...)`. It never calls `get_tree().change_scene_to_file(...)` or `change_scene_to_packed(...)`. It never emits `scene_loading`, `scene_started`, or `scene_completed` signals. The only signal STUI emits is `EventBus.epilogue_cover_ready`.
- On load/resume, STUI begins in the state determined by the boot sequence (`FIRST_REVEAL` for a new session; `IDLE` if STUI is somehow re-instanced mid-session, though this is not a normal flow). Scene Manager drives whatever transition the loaded state requires via normal signal emission.
- Debug-only nodes (state label from `debug_draw_state`) are never created in release builds. Use `OS.is_debug_build()` guard or Godot export filter pattern.

---

## Out of Scope

- Story 001: state machine, signal subscriptions
- Story 002: Polygon2D geometry, CanvasLayer instancing
- Story 003: cancel_drag(), InputBlocker
- Story 004: Formula 1–4 math, phase clamping
- Story 005: epilogue variant behaviour, FIRST_REVEAL timing, epilogue_cover_ready emission

---

## QA Test Cases

*Logic — automated (`tests/unit/scene-transition-ui/stui_config_reduced_motion_test.gd`):*

- **AC-014**: Reduced-motion path — total duration and zero curl
  - Given: `ProjectSettings.get_setting("stui/reduced_motion_default", false)` returns `true`; knobs at defaults (`reduced_motion_rise_ms=400`, `reduced_motion_hold_ms=600`, `reduced_motion_fade_ms=400`)
  - When: A transition is triggered and phase durations are resolved
  - Then: `D_rise = 400ms`, `D_hold = 600ms`, `D_fade = 400ms`; total = 1400ms (not clamped to T_MIN=1700); curl theta returned by `_compute_curl_rotation()` equals 0.0; paper-breathe amplitude equals 0.0
  - Edge cases: Total of 1400ms is below T_MIN=1700 — confirm NO scaling is applied to the reduced-motion path

- **AC-014**: Reduced-motion path — linear ease curves
  - Given: `reduced_motion = true`
  - When: The rise and fade Tweens are created
  - Then: Both Tweens use linear ease (not `EASE_IN_OUT`+`TRANS_QUAD` for rise, not `EASE_OUT`+`TRANS_CUBIC` for fade)
  - Edge cases: Standard path must still use the non-linear ease curves; confirm the two code paths are distinct

- **E-10**: Missing transition-variants.tres — fallback to hardcoded defaults
  - Given: `assets/data/ui/transition-variants.tres` does not exist (or is an incompatible type)
  - When: STUI's `_enter_tree()` attempts to load it
  - Then: `push_warning` is called with a message referencing the missing path; `_variants_resource` is null; all subsequent per-scene lookups use hardcoded default knob values; no crash or error-out occurs
  - Edge cases: File exists but `class_name` is wrong (cast returns null) — same warning + fallback behaviour

- **E-10**: Out-of-range color channel clamped to [0,1]
  - Given: A mock `TransitionVariants` resource with `paper_tint = Color(1.5, -0.2, 0.88)` for scene_id "home"
  - When: STUI looks up the tint for scene "home"
  - Then: The applied color has channels clamped: `r = 1.0`, `g = 0.0`, `b = 0.88` (within [0,1]); no crash; default tint is NOT used as a complete fallback (only the out-of-range channels are clamped)
  - Edge cases: All channels in range → no clamping applied

- **AC-020**: STUI emits no forbidden signals
  - Given: An event counter connected to `EventBus.scene_loading`, `EventBus.scene_started`, `EventBus.scene_completed`
  - When: A full transition cycle runs (FADING_OUT → HOLDING → FADING_IN → IDLE)
  - Then: All three counters equal 0; only `epilogue_cover_ready` may be emitted (tested separately in Story 005)
  - Edge cases: Run the epilogue cycle as well; confirm `scene_completed` is never emitted by STUI in any state

- **AC-020**: STUI never calls change_scene_to_*
  - Given: A test seam that patches `get_tree().change_scene_to_file` with a call-counter mock
  - When: A full transition cycle and an epilogue cycle both complete
  - Then: The mock's call count equals 0

- **ProjectSettings read per transition**:
  - Given: `reduced_motion` starts as `false`; mid-test it is changed to `true` (simulating a dev-time change, GDD E-9)
  - When: The next transition is triggered after the change
  - Then: The new transition uses the reduced-motion path; the previous transition was unaffected
  - Edge cases: Change back to `false` — subsequent transition uses the normal path

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/scene-transition-ui/stui_config_reduced_motion_test.gd` (automated, must pass)
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 005 (epilogue variant and FIRST_REVEAL)
- Unlocks: None — this is the final story in the epic
