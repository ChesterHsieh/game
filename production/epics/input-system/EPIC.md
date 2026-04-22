# Epic: Input System

> **Layer**: Foundation
> **GDD**: `design/gdd/input-system.md`
> **Architecture Module**: `InputSystem` (autoload singleton)
> **Status**: Ready
> **Stories**: 5 stories created 2026-04-21 — see table below

## Overview

InputSystem translates raw Godot mouse input into semantic drag + proximity
signals on EventBus. It is the sole owner of raw `InputEvent` for drag
interactions — no other system reads mouse events directly. Two-state FSM
(`Idle` / `Dragging`), screen→world coordinate conversion via Camera2D,
per-frame proximity check against all cards within `snap_radius` (default 80px),
and `cancel_drag()` for scene-transition/pause interrupts.

Emits 5 EventBus signals (per ADR-003): `drag_started`, `drag_moved`,
`drag_released`, `proximity_entered`, `proximity_exited`. Emits signals only —
never calls methods on downstream systems. Card Engine is the primary consumer.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-001: Naming conventions | snake_case signals + methods | LOW |
| ADR-003: Signal bus (EventBus) | 5 input signals declared in the 30-signal table (lines 27–85) | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-input-system-001 | Register as autoload singleton `InputSystem`; sole owner of raw mouse InputEvent for drag interactions | ADR-003 ✅ |
| TR-input-system-002 | Perform per-frame hit-test (area query / raycast) to identify card under cursor by `card_id` | ADR-001 ✅ |
| TR-input-system-003 | Emit signal `drag_started(card_id: String, world_pos: Vector2)` on left-mouse press on a card | ADR-003 ✅ |
| TR-input-system-004 | Emit signal `drag_moved(card_id: String, world_pos: Vector2, delta: Vector2)` each frame during active drag | ADR-003 ✅ |
| TR-input-system-005 | Emit signal `drag_released(card_id: String, world_pos: Vector2)` on left-mouse release | ADR-003 ✅ |
| TR-input-system-006 | Emit signals `proximity_entered`/`proximity_exited(dragged_id, target_id)` on snap_radius crossings | ADR-003 ✅ |
| TR-input-system-007 | Convert screen → world coordinates via Camera2D transform; all world_pos parameters in world space | ADR-001 ✅ |
| TR-input-system-008 | Enforce single active drag; second press while dragging is ignored (active drag takes precedence) | ADR-001 ✅ |
| TR-input-system-009 | Resolve overlapping cards by highest `z_index` (topmost picked up) | ADR-001 ✅ |
| TR-input-system-010 | Per-frame proximity check between dragged card and all other cards; guard against dragged_id == target_id | ADR-001 ✅ |
| TR-input-system-011 | Expose `cancel_drag()` method that emits `drag_released` at last known position and returns to Idle | ADR-003 ✅ |
| TR-input-system-012 | Operate purely as signal emitter; make no direct method calls into gameplay systems | ADR-003 ✅ |
| TR-input-system-013 | Expose tunable `snap_radius: float` (default 80px, range 40–160) as designer-adjustable parameter | ADR-001 ✅ |
| TR-input-system-014 | Track drag state machine with exactly two states (Idle, Dragging); right-click ignored in MVP | ADR-001 ✅ |

**Coverage**: 14 / 14 TRs ✅ (zero untraced)

## Carry-Forward

- **Settings + in-flight drag** (from `gdd-cross-review-2026-04-21-reverify.md`): Settings Rule 5 should call `InputSystem.cancel_drag()` on gear press before instancing the settings panel. Add this as a dependent story when the Settings epic is scoped.

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/input-system.md` are verified
- Logic stories (FSM transitions, proximity guard, z-order tie-break) have passing unit tests in `tests/unit/input_system/`
- Feel/Visual stories (drag responsiveness, proximity feedback) have screenshot + lead sign-off in `production/qa/evidence/`
- Signal declarations match ADR-003's 5 input-domain signals exactly (arity, names, param types)

## Stories

| # | Story | Type | Status | ADR | TRs |
|---|-------|------|--------|-----|-----|
| 001 | [InputSystem autoload + 2-state FSM skeleton](story-001-input-system-autoload-fsm.md) | Integration | Ready | ADR-003, ADR-004 | TR-001, TR-007, TR-014 |
| 002 | [Hit-test + drag_started + z-order resolution](story-002-hit-test-drag-started.md) | Logic | Ready | ADR-003 | TR-002, TR-003, TR-009 |
| 003 | [drag_moved + drag_released + single-drag enforcement](story-003-drag-moved-released.md) | Logic | Ready | ADR-003 | TR-004, TR-005, TR-008 |
| 004 | [Proximity detection — proximity_entered / proximity_exited](story-004-proximity-detection.md) | Logic | Ready | ADR-003 | TR-006, TR-010, TR-013 |
| 005 | [cancel_drag() + signal-only discipline](story-005-cancel-drag-signal-discipline.md) | Logic | Ready | ADR-003 | TR-011, TR-012 |

**Coverage**: 14 / 14 TRs mapped to stories.

## Next Step

Start implementation: `/story-readiness production/epics/input-system/story-001-input-system-autoload-fsm.md`
then `/dev-story` to begin. Work stories in order — each story's `Depends on:`
field lists what must be DONE first.
