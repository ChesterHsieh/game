# Story 003: drag_moved + drag_released + single-drag enforcement

> **Epic**: input-system
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-04-21

## Context

**GDD**: `design/gdd/input-system.md`
**Requirement**: `TR-input-system-004` — emit `drag_moved` each frame
during active drag. `TR-input-system-005` — emit `drag_released` on
left-mouse release. `TR-input-system-008` — enforce single active drag;
second press ignored.

**ADR Governing Implementation**: ADR-003 — `drag_moved(card_id: String, world_pos: Vector2, delta: float)` and `drag_released(card_id: String, world_pos: Vector2)` declared in EventBus
**ADR Decision Summary**: During Dragging state, InputSystem emits
`drag_moved` via EventBus each frame the mouse moves. On mouse release,
emits `drag_released` and transitions back to Idle. Only one drag at a time.

**Engine**: Godot 4.3 | **Risk**: LOW
**Engine Notes**: `InputEventMouseMotion` in `_unhandled_input()` fires
per-frame during mouse movement. `event.relative` provides the screen-space
delta. Coordinate conversion uses the same Camera2D transform from Story 001.

**Control Manifest Rules (Foundation layer)**:
- Required: emit signals via EventBus.
- Forbidden: direct method calls into downstream systems.
- Guardrail: per-frame signal emission must be lightweight (< 0.1 ms).

---

## Acceptance Criteria

*From GDD `design/gdd/input-system.md`:*

- [ ] While in Dragging state, mouse movement emits
      `EventBus.drag_moved.emit(card_id, world_pos, delta)` each frame
- [ ] `world_pos` is in world coordinates (converted from screen via
      Camera2D)
- [ ] `delta` is the frame-to-frame world-space movement vector
- [ ] On left-mouse release during Dragging state:
      `EventBus.drag_released.emit(card_id, world_pos)` fires
- [ ] After drag_released, FSM returns to Idle
- [ ] Only one drag is active at any time — second left-press while
      Dragging is ignored (no new drag_started, no state change)
- [ ] Mouse leaving the window mid-drag: `drag_released` fires at last
      known position when release eventually occurs (Godot captures mouse
      during drag)

---

## Implementation Notes

*Derived from GDD Events Emitted table and Edge Cases:*

1. Handle mouse motion in `_unhandled_input()`:
   ```gdscript
   if event is InputEventMouseMotion and _state == State.DRAGGING:
       var world_pos: Vector2 = _screen_to_world(event.position)
       var delta: Vector2 = world_pos - _last_world_pos
       _last_world_pos = world_pos
       EventBus.drag_moved.emit(_dragged_card_id, world_pos, delta)
   ```
2. Handle mouse release:
   ```gdscript
   if event is InputEventMouseButton:
       if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
           if _state == State.DRAGGING:
               var world_pos: Vector2 = _screen_to_world(event.position)
               EventBus.drag_released.emit(_dragged_card_id, world_pos)
               _state = State.IDLE
               _dragged_card_id = ""
   ```
3. Note: ADR-003 declares `drag_moved` with `delta: float` but the GDD
   specifies `delta: Vector2`. The implementation should match the GDD
   (Vector2 delta is more useful for 2D drag). EventBus declaration may need
   updating from `float` to `Vector2` — flag this during implementation.
4. Single-drag enforcement is dual-guarded: Story 002 checks `_state != IDLE`
   before starting a new drag, and this story's release handler resets state
   to Idle. No race condition is possible in single-threaded GDScript.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: autoload + FSM skeleton
- Story 002: hit-test + drag_started
- Story 004: proximity detection (runs during Dragging state but is a
  separate concern)
- Story 005: cancel_drag()

---

## QA Test Cases

*For this Logic story — automated test specs:*

- **AC-1 (drag_moved emitted during drag)**:
  - Given: InputSystem in Dragging state, dragging "test-card"
  - When: mouse moves from (100, 100) to (120, 130)
  - Then: `EventBus.drag_moved` emitted with `card_id == "test-card"`,
    correct world_pos, and `delta == Vector2(20, 30)` (in world space)

- **AC-2 (drag_released on mouse up)**:
  - Given: InputSystem in Dragging state, dragging "test-card"
  - When: left mouse button released at (200, 200)
  - Then: `EventBus.drag_released` emitted with `card_id == "test-card"`
    and correct world_pos; `_state == State.IDLE`

- **AC-3 (state resets to Idle after release)**:
  - Given: InputSystem just emitted drag_released
  - When: test reads `_state`
  - Then: `_state == State.IDLE`; `_dragged_card_id == ""`

- **AC-4 (single drag enforcement)**:
  - Given: InputSystem in Dragging state (dragging "card-a")
  - When: second left-press on "card-b"
  - Then: no new `drag_started` emitted; still dragging "card-a";
    `_state == State.DRAGGING`

- **AC-5 (world coordinates, not screen)**:
  - Given: Camera2D offset such that screen (0,0) maps to world (100,200)
  - When: drag moves to screen (50, 50)
  - Then: `world_pos` in `drag_moved` is (150, 250), not (50, 50)

- **AC-6 (delta is world-space difference)**:
  - Given: two consecutive frames with world_pos (100, 100) then (110, 120)
  - When: drag_moved fires on the second frame
  - Then: `delta == Vector2(10, 20)`

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/input_system/drag_moved_released_test.gd`
(gdUnit4) — must exist and pass.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (autoload + FSM), Story 002 (hit-test sets up
  Dragging state)
- Unlocks: Story 004 (proximity runs during Dragging phase), Story 005
  (cancel_drag exits Dragging)
