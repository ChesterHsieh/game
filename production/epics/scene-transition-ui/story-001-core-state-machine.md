# Story 001: Core state machine and signal subscriptions

> **Epic**: Scene Transition UI
> **Status**: Complete
> **Layer**: Presentation
> **Type**: Logic
> **Manifest Version**: 2026-04-21

## Context

**GDD**: `design/gdd/scene-transition-ui.md`
**Requirements**: `TR-scene-transition-ui-002`, `TR-scene-transition-ui-004`, `TR-scene-transition-ui-010`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-003: Signal Bus, ADR-004: Runtime Scene Composition
**ADR Decision Summary**: ADR-003 mandates all cross-system communication via EventBus; systems connect in `_ready()` or `_enter_tree()`, never hold direct node references. ADR-004 specifies STUI is a CanvasLayer child of `gameplay.tscn` with `process_mode = PROCESS_MODE_ALWAYS`, and that `SceneManager` connects to `scene_completed` before `SaveSystem` — STUI must connect in `_enter_tree()` to precede both.

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

- [ ] **AC-001** STUI subscribes to EventBus signals in `_enter_tree()` — verifiable by emitting `scene_completed` in the same frame STUI is instanced and asserting the handler ran. This is the SGS-ordering-race fix.
- [ ] **AC-002** `scene_completed` in IDLE → STUI transitions to FADING_OUT same frame; `InputBlocker.mouse_filter` becomes `MOUSE_FILTER_STOP`.
- [ ] **AC-003** FADING_OUT Tween completion → HOLDING with `Overlay.modulate.a == 1.0`.
- [ ] **AC-004** `scene_started` in HOLDING → FADING_IN.
- [ ] **AC-005** FADING_IN Tween completion → IDLE with `Overlay.modulate.a == 0.0` and `InputBlocker.mouse_filter == MOUSE_FILTER_IGNORE`.
- [ ] **AC-007** Signal-storm guard: `scene_completed` or `scene_loading` emitted while STUI is not IDLE produces no state change and no new Tween.
- [ ] **AC-008** `scene_started` arriving during FADING_OUT is buffered; on FADING_OUT completion, STUI transitions directly to FADING_IN without entering HOLDING (E-5).

---

## Implementation Notes

*Derived from ADR-003 and ADR-004:*

- Subscribe to `EventBus.scene_completed`, `EventBus.scene_started`, and `EventBus.epilogue_started` inside `_enter_tree()`, not `_ready()`. This is the fix for the first-frame ordering race where SGS could emit `scene_completed` before STUI's `_ready()` runs (GDD Core Rule 2). `_ready()` is reserved for initial state setup only (Tween root creation, blocker anchor assignment).
- STUI does **not** subscribe to `scene_loading` — GDD Core Rule 2 explicitly states this signal was removed from STUI's subscription list (r2 cleanup).
- The state machine uses a `State` enum with values: `IDLE`, `FADING_OUT`, `HOLDING`, `FADING_IN`, `EPILOGUE`, `FADING_OUT`. `_current_state: State` is the authoritative runtime state.
- Signal-storm guard (GDD Core Rule 13, AC-007): at the top of the `_on_scene_completed` handler, if `_current_state != State.IDLE`, log at debug level and return immediately. No new Tween is created; no state change occurs.
- Buffered `scene_started` (GDD Edge Case E-5, AC-008): a `_scene_started_buffered: bool` flag is set when `scene_started` fires during `FADING_OUT`. When the `FADING_OUT` Tween completes, check this flag; if set, skip `HOLDING` and enter `FADING_IN` directly.
- InputBlocker `mouse_filter` transitions are paired with state transitions: entering any non-IDLE state → `MOUSE_FILTER_STOP`; entering IDLE → `MOUSE_FILTER_IGNORE`.
- `PROCESS_MODE_ALWAYS` is set on the STUI root node so Tweens survive any future pause overlay (ADR-004 §2).

---

## Out of Scope

- Story 002: scene instancing as CanvasLayer child of gameplay.tscn, Polygon2D overlay geometry
- Story 003: InputSystem.cancel_drag() call and mouse event absorption testing
- Story 004: timing formulas (Formula 1–4)
- Story 005: epilogue variant amber tint, epilogue_cover_ready emission, FIRST_REVEAL fade
- Story 006: transition-variants.tres config loading, reduced-motion path

---

## QA Test Cases

*Logic — automated (`tests/unit/scene-transition-ui/stui_state_machine_test.gd`):*

- **AC-001**: `_enter_tree()` subscription timing
  - Given: A test scene that instances SceneTransitionUI and immediately (same frame, before `_ready()` of the scene completes) emits `EventBus.scene_completed("test_scene")`
  - When: The frame processes
  - Then: STUI's internal `_current_state` equals `State.FADING_OUT` — confirming the handler ran before `_ready()`
  - Edge cases: Emit `scene_completed` before the node's `_ready()` fires; handler must still execute

- **AC-002**: `scene_completed` in IDLE transitions to FADING_OUT with input block
  - Given: STUI is in `State.IDLE`
  - When: `EventBus.scene_completed.emit("home")` fires
  - Then: `_current_state == State.FADING_OUT` on the same frame; `input_blocker.mouse_filter == MOUSE_FILTER_STOP`
  - Edge cases: Emit with empty string scene_id; state must still transition

- **AC-003**: FADING_OUT Tween completion enters HOLDING at alpha=1
  - Given: STUI is in `State.FADING_OUT` with an active rise Tween
  - When: The Tween's `finished` signal fires (or Tween is force-completed in test)
  - Then: `_current_state == State.HOLDING`; `overlay.modulate.a == 1.0`
  - Edge cases: Tween is killed mid-flight; must not enter HOLDING

- **AC-004**: `scene_started` in HOLDING transitions to FADING_IN
  - Given: STUI is in `State.HOLDING`
  - When: `EventBus.scene_started.emit("park")` fires
  - Then: `_current_state == State.FADING_IN`
  - Edge cases: Emit `scene_started` with a different scene_id than the one that triggered FADING_OUT; still transitions

- **AC-005**: FADING_IN Tween completion enters IDLE with alpha=0 and IGNORE filter
  - Given: STUI is in `State.FADING_IN` with an active fade Tween
  - When: The fade Tween completes
  - Then: `_current_state == State.IDLE`; `overlay.modulate.a == 0.0`; `input_blocker.mouse_filter == MOUSE_FILTER_IGNORE`
  - Edge cases: alpha assertion uses exact float equality (Tween drives to target value)

- **AC-007**: Signal-storm guard drops duplicate `scene_completed`
  - Given: STUI is in `State.FADING_OUT` (not IDLE)
  - When: `EventBus.scene_completed.emit("home")` fires a second time
  - Then: `_current_state` remains `State.FADING_OUT`; no new Tween is created; no state change
  - Edge cases: Emit 3 duplicate signals in rapid succession; all must be dropped

- **AC-008**: Buffered `scene_started` during FADING_OUT skips HOLDING
  - Given: STUI is in `State.FADING_OUT`
  - When: `EventBus.scene_started.emit("park")` fires before the rise Tween completes; then the rise Tween completes
  - Then: `_current_state` jumps from `FADING_OUT` directly to `FADING_IN`, never entering `HOLDING`
  - Edge cases: `scene_started` fires at the exact same frame as the Tween complete callback

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/scene-transition-ui/stui_state_machine_test.gd` (automated, must pass)
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None — this is the foundational story
- Unlocks: Story 002 (scene composition and Polygon2D overlay)
