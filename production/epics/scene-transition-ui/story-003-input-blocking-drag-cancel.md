# Story 003: Input blocking and drag cancel

> **Epic**: Scene Transition UI
> **Status**: Complete
> **Layer**: Presentation
> **Type**: Integration
> **Manifest Version**: 2026-04-21

## Context

**GDD**: `design/gdd/scene-transition-ui.md`
**Requirements**: `TR-scene-transition-ui-007`, `TR-scene-transition-ui-008`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-003: Signal Bus, ADR-004: Runtime Scene Composition
**ADR Decision Summary**: ADR-003 designates `InputSystem.cancel_drag()` as the only direct cross-system method call STUI makes — all other communication is signal-based. ADR-004 §2 specifies the InputBlocker is a full-screen ColorRect sibling of the Overlay Polygon2D within the STUI CanvasLayer.

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

- [ ] **AC-009** `scene_completed` while a drag is active → `InputSystem.cancel_drag()` called exactly once, same frame.
- [ ] **AC-010** In any non-IDLE state, a mouse-button `InputEvent` is absorbed by `InputBlocker` and does not reach underlying controls.

---

## Implementation Notes

*Derived from ADR-003 and ADR-004:*

- At the first line of the `_on_scene_completed` handler (after the signal-storm guard passes), call `InputSystem.cancel_drag()`. This is the only direct cross-system method call STUI makes (GDD Interactions table, ADR-003). It is safe to call when no drag is active — GDD Core Rule 6 and GDD Dependencies confirm `cancel_drag()` is a no-op when nothing is being dragged.
- The call must happen on the same frame as the `scene_completed` signal — before any Tween is started. Do not defer or await before calling `cancel_drag()`.
- `InputBlocker` is a `ColorRect` with `anchors_preset = PRESET_FULL_RECT` and `modulate.a = 0` (invisible but present). It absorbs mouse and touch events via `mouse_filter`:
  - `MOUSE_FILTER_STOP` in states: `FADING_OUT`, `HOLDING`, `FADING_IN`, `EPILOGUE`
  - `MOUSE_FILTER_IGNORE` in states: `IDLE`, `FIRST_REVEAL`
- Scope of blocking is **mouse and touch only**. In Godot 4.3, `MOUSE_FILTER_STOP` on a `ColorRect` blocks only mouse/touch events. Keyboard events (`_input`/`_unhandled_input`) flow through independently — STUI does not intercept `_input()` or `_gui_input()` callbacks (GDD Core Rule 7, GDD UI Requirements — Input Affordance). This is intentional for v1; keyboard handling is Settings' future concern.
- STUI never takes keyboard focus. The `ColorRect` + `MOUSE_FILTER_STOP` pattern is sufficient without stealing focus from any underlying game UI.
- For testability: in integration tests, mock `InputSystem` via a test-double or verify the call count via a signal emitted by a test-seam wrapper. The test must confirm exactly one call to `cancel_drag()` per `scene_completed` regardless of whether a drag was active.

---

## Out of Scope

- Story 001: state machine transitions, signal subscriptions, signal-storm guard
- Story 002: Polygon2D overlay geometry, CanvasLayer instancing
- Story 004: timing formulas, phase duration clamping
- Story 005: epilogue variant, FIRST_REVEAL fade
- Story 006: transition-variants.tres config, reduced-motion path

---

## QA Test Cases

*Integration — automated (`tests/integration/scene-transition-ui/stui_input_blocking_test.gd`):*

- **AC-009**: cancel_drag called exactly once on scene_completed
  - Given: A test double that wraps `InputSystem` and counts calls to `cancel_drag()`; STUI is in `State.IDLE`; a drag is simulated as active in the mock
  - When: `EventBus.scene_completed.emit("home")` fires
  - Then: The mock's `cancel_drag()` call count equals exactly 1
  - Edge cases:
    - No drag is active in the mock (cancel_drag is still called once — it is a no-op in this case)
    - Two rapid `scene_completed` signals: signal-storm guard drops the second; `cancel_drag()` is called exactly once total
    - `cancel_drag()` must be called on the same frame — assert call count before `await get_tree().process_frame`

- **AC-010**: Mouse InputEvent absorbed in non-IDLE states
  - Given: STUI is in `State.FADING_OUT` (InputBlocker has `MOUSE_FILTER_STOP`); a Control node exists beneath STUI in the scene tree with a `gui_input` handler that records received events
  - When: A synthetic `InputEventMouseButton` (left click) is sent into the scene via `Input.parse_input_event()` or equivalent
  - Then: The underlying Control's `gui_input` handler is not called; the InputBlocker has consumed the event
  - Edge cases:
    - Repeat in `State.HOLDING`: same absorption behaviour
    - Repeat in `State.FADING_IN`: same absorption behaviour
    - Repeat in `State.IDLE` (InputBlocker has `MOUSE_FILTER_IGNORE`): the underlying Control's `gui_input` **is** called — confirm pass-through

- **Mouse filter state transitions**:
  - Given: STUI starts in `State.IDLE` with `MOUSE_FILTER_IGNORE`
  - When: STUI transitions through FADING_OUT → HOLDING → FADING_IN → IDLE
  - Then: At each state entry, `input_blocker.mouse_filter` matches the expected value (STOP for non-IDLE active states; IGNORE for IDLE)
  - Edge cases: Verify filter is IGNORE immediately when IDLE is re-entered after FADING_IN Tween completes (not one frame later)

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/scene-transition-ui/stui_input_blocking_test.gd` (automated, must pass)
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002 (scene composition and Polygon2D overlay)
- Unlocks: Story 004 (transition timing formulas)
