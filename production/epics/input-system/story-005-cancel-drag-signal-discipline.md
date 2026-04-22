# Story 005: cancel_drag() + signal-only discipline

> **Epic**: input-system
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-04-21

## Context

**GDD**: `design/gdd/input-system.md`
**Requirement**: `TR-input-system-011` — expose `cancel_drag()` method
that emits `drag_released` at last known position and returns to Idle.
`TR-input-system-012` — operate purely as signal emitter; make no direct
method calls into gameplay systems.

**ADR Governing Implementation**: ADR-003 — EventBus is the sole
communication channel; direct method calls are forbidden for events.
**ADR Decision Summary**: `cancel_drag()` is a direct autoload method call
(ADR-003 allows direct calls for commands/queries to autoloads). It triggers
`drag_released` and proximity cleanup, then returns to Idle. InputSystem
itself never calls methods on Card Engine, ITF, or any downstream system —
it only emits EventBus signals.

**Engine**: Godot 4.3 | **Risk**: LOW
**Engine Notes**: No engine-specific concerns. Method call on autoload
singleton is standard GDScript.

**Control Manifest Rules (Foundation layer)**:
- Required: EventBus for cross-system events; direct autoload calls for
  read-only queries and command methods like `cancel_drag()`.
- Forbidden: InputSystem calling methods on gameplay systems.
- Guardrail: cancel_drag must be safe to call at any time, including when
  already Idle (no-op).

---

## Acceptance Criteria

*From GDD `design/gdd/input-system.md`:*

- [ ] `cancel_drag()` is a public method on InputSystem
- [ ] If in Dragging state: emits `EventBus.drag_released` at last known
      world position, fires `proximity_exited` for all active proximity
      targets, and transitions to Idle
- [ ] If already in Idle state: `cancel_drag()` is a safe no-op (no signal,
      no error)
- [ ] After `cancel_drag()`, FSM state is Idle and `_dragged_card_id` is
      empty
- [ ] InputSystem makes no direct method calls into Card Engine, ITF, or
      any gameplay system — signals only (verified by code review)
- [ ] All 5 EventBus signals (`drag_started`, `drag_moved`, `drag_released`,
      `proximity_entered`, `proximity_exited`) are emitted via
      `EventBus.<signal>.emit()`, never via local signals

---

## Implementation Notes

*Derived from GDD Edge Case "Drag cancelled by game event" and ADR-003:*

1. `cancel_drag()` implementation:
   ```gdscript
   func cancel_drag() -> void:
       if _state != State.DRAGGING:
           return
       # Emit proximity exits for all active targets
       for target_id: String in _proximity_targets:
           EventBus.proximity_exited.emit(_dragged_card_id, target_id)
       _proximity_targets.clear()
       # Emit drag_released at last known position
       EventBus.drag_released.emit(_dragged_card_id, _last_world_pos)
       _state = State.IDLE
       _dragged_card_id = ""
   ```
2. Callers of `cancel_drag()`: Scene Manager (on scene transition), Settings
   panel (on open — per cross-review carry-forward), pause menu. These are
   downstream systems calling INTO InputSystem (allowed — direct autoload
   calls for commands per ADR-003).
3. Signal-only discipline verification: grep InputSystem source for any
   `.call(`, `.call_deferred(`, or direct node references to gameplay
   systems. The only method calls should be to `EventBus.<signal>.emit()`
   and to Godot engine APIs (`get_viewport()`, `Input`, etc.).
4. InputSystem declares NO local signals. All signals are on EventBus.
   This prevents accidental direct-connection patterns.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: autoload + FSM
- Story 002: hit-test + drag_started
- Story 003: drag_moved + drag_released
- Story 004: proximity detection (provides `_proximity_targets` cleanup)
- Who calls `cancel_drag()` — caller stories belong to Scene Manager,
  Settings, and pause menu epics

---

## QA Test Cases

*For this Logic story — automated test specs:*

- **AC-1 (cancel_drag from Dragging state)**:
  - Given: InputSystem in Dragging state, dragging "card-a" at
    `_last_world_pos = Vector2(100, 200)`
  - When: `cancel_drag()` called
  - Then: `EventBus.drag_released` emitted with `card_id == "card-a"`,
    `world_pos == Vector2(100, 200)`; `_state == State.IDLE`;
    `_dragged_card_id == ""`

- **AC-2 (cancel_drag cleans up proximity)**:
  - Given: InputSystem dragging, with card-b and card-c in proximity
  - When: `cancel_drag()` called
  - Then: `EventBus.proximity_exited` emitted for both card-b and card-c
    BEFORE `drag_released` is emitted; `_proximity_targets` is empty

- **AC-3 (cancel_drag from Idle is no-op)**:
  - Given: InputSystem in Idle state
  - When: `cancel_drag()` called
  - Then: no signals emitted; state remains Idle; no error

- **AC-4 (signal-only discipline — no direct calls to gameplay systems)**:
  - Given: InputSystem source code at `res://src/core/input_system.gd`
  - When: code is inspected (grep for method calls)
  - Then: no references to CardEngine, ITF, StatusBar, or any gameplay
    system; only `EventBus.<signal>.emit()` for cross-system communication

- **AC-5 (all 5 signals emitted via EventBus)**:
  - Given: a full drag lifecycle (start → move → release) with proximity
  - When: monitoring EventBus signal connections
  - Then: all 5 signals (`drag_started`, `drag_moved`, `drag_released`,
    `proximity_entered`, `proximity_exited`) fire on EventBus, not on
    InputSystem

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/input_system/cancel_drag_test.gd`
(gdUnit4) — must exist and pass.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (autoload + FSM), Story 002 (Dragging state entry),
  Story 003 (drag_released pattern), Story 004 (proximity cleanup)
- Unlocks: downstream consumers — Scene Manager, Settings panel, pause menu
  can call `cancel_drag()` during interrupts
