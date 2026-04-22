# Story 001: InputSystem autoload + 2-state FSM skeleton

> **Epic**: input-system
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Integration
> **Manifest Version**: 2026-04-21

## Context

**GDD**: `design/gdd/input-system.md`
**Requirement**: `TR-input-system-001` — register as autoload singleton;
sole owner of raw mouse InputEvent for drag interactions.
`TR-input-system-007` — convert screen→world coordinates via Camera2D.
`TR-input-system-014` — two-state FSM (Idle, Dragging); right-click
ignored in MVP.

**ADR Governing Implementation**: ADR-003 — EventBus singleton (InputSystem
emits 5 signals via EventBus); ADR-004 — runtime scene composition (autoload
position #4 in the 12-autoload canonical order)
**ADR Decision Summary**: InputSystem is autoload #4 (after RecipeDatabase),
`process_mode = PROCESS_MODE_ALWAYS`. It owns raw mouse input for drag
interactions. All drag/proximity signals are emitted on EventBus (ADR-003),
not on InputSystem directly.

**Engine**: Godot 4.3 | **Risk**: LOW
**Engine Notes**: `_unhandled_input()` + `get_viewport().get_camera_2d()`
for screen→world conversion are stable in 4.3. `Input.get_mouse_button_mask()`
for detecting held buttons is pre-cutoff.

**Control Manifest Rules (Foundation layer)**:
- Required: autoload order per ADR-004 §1; `process_mode = PROCESS_MODE_ALWAYS`;
  EventBus for cross-system events.
- Forbidden: direct method calls into gameplay systems; holding references
  to other systems.
- Guardrail: per-frame `_process()` for drag tracking must stay under 0.5 ms.

---

## Acceptance Criteria

*From GDD `design/gdd/input-system.md`:*

- [ ] `res://src/core/input_system.gd` exists with `extends Node`
- [ ] Registered as autoload #4 in `project.godot`, immediately after
      `RecipeDatabase`, with `process_mode = PROCESS_MODE_ALWAYS`
- [ ] Two-state FSM: `Idle` and `Dragging` as an enum
- [ ] Default state is `Idle`
- [ ] `_unhandled_input()` receives mouse button events
- [ ] Screen→world coordinate conversion utility using Camera2D transform
- [ ] Right-click is explicitly ignored (no-op)
- [ ] FSM state is readable for testing (internal `_state` variable)

---

## Implementation Notes

*Derived from ADR-003, ADR-004 §1, and GDD States and Transitions:*

1. `res://src/core/input_system.gd`:
   ```gdscript
   class_name InputSystem extends Node

   enum State { IDLE, DRAGGING }

   var _state: State = State.IDLE
   var _dragged_card_id: String = ""
   var _last_world_pos: Vector2 = Vector2.ZERO

   func _ready() -> void:
       process_mode = PROCESS_MODE_ALWAYS

   func _screen_to_world(screen_pos: Vector2) -> Vector2:
       var camera: Camera2D = get_viewport().get_camera_2d()
       if camera == null:
           return screen_pos
       return camera.get_global_transform().affine_inverse() * screen_pos
   ```
2. `project.godot` → `[autoload]` section, fourth line:
   ```
   InputSystem="*res://src/core/input_system.gd"
   ```
3. `_unhandled_input()` is the entry point — not `_input()`. This ensures
   UI elements consume events first (buttons, panels, etc.).
4. The FSM has exactly two states. No `Pending` state — press either hits a
   card (→ Dragging) or misses (stays Idle). Transition logic is in Story 002.
5. Screen→world conversion returns screen_pos unchanged if no Camera2D
   exists (safety for test environments without a camera).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: hit-test + drag_started signal emission
- Story 003: drag_moved + drag_released
- Story 004: proximity detection
- Story 005: cancel_drag()
- Touch input — mouse only for MVP

---

## QA Test Cases

*For this Integration story — automated test specs:*

- **AC-1 (autoload position #4)**:
  - Given: project running
  - When: test reads `project.godot` `[autoload]` section
  - Then: fourth autoload entry is `InputSystem=...`
  - Edge cases: InputSystem before RecipeDatabase → fail

- **AC-2 (process_mode)**:
  - Given: InputSystem autoload loaded
  - When: test queries `InputSystem.process_mode`
  - Then: `process_mode == PROCESS_MODE_ALWAYS`

- **AC-3 (default state is Idle)**:
  - Given: InputSystem just loaded
  - When: test reads `InputSystem._state`
  - Then: `_state == State.IDLE`

- **AC-4 (screen→world conversion)**:
  - Given: a Camera2D at position (100, 200)
  - When: `_screen_to_world(Vector2(300, 400))` is called
  - Then: returns the correct world-space position accounting for
    camera offset
  - Edge cases: no Camera2D → returns screen_pos unchanged

- **AC-5 (right-click ignored)**:
  - Given: InputSystem in Idle state
  - When: a right-click InputEventMouseButton is sent
  - Then: state remains Idle; no signals emitted

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/input_system/autoload_fsm_test.gd`
(gdUnit4) — must exist and pass.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: card-database Story 001 (EventBus must exist — InputSystem
  emits on EventBus); RecipeDatabase autoload at #3 (InputSystem is #4)
- Unlocks: Story 002 (hit-test), Story 003 (drag lifecycle), Story 004
  (proximity), Story 005 (cancel_drag)
