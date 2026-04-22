# Epic: Card Engine

> **Layer**: Core
> **GDD**: `design/gdd/card-engine.md`
> **Architecture Module**: `CardEngine` — per-card FSM (6 states), all Tween-based motion
> **Status**: Ready
> **Stories**: 4 stories created 2026-04-22 — see table below

## Overview

CardEngine manages the physical lifecycle of every card on the table: drag movement,
magnetic snap attraction, push-away rejection, and combination detection. It listens
exclusively to InputSystem signals and translates them into card motion via Godot Tween
nodes. When a dragged card is released within snap range of another, CardEngine fires
`combination_attempted` and the Interaction Template Framework resolves the outcome.
CardEngine owns authoritative runtime card positions — Table Layout System provides
initial placement only. All 6 FSM states (Idle, Dragged, Attracting, Snapping, Pushed,
Executing) must be cancellable mid-flight when a `card_removing` signal arrives.

This is the highest-feel-risk system in the game. If the magnetic snap doesn't feel
right, nothing else does. Prototype tuning knobs early and iterate before writing content.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-002: Card object pooling | Per-card nodes managed by CardSpawningSystem; CardEngine registers/deregisters via lifecycle signals | LOW |
| ADR-001: Naming conventions | snake_case variables/files, PascalCase class_name; `card_engine.gd` | LOW |
| ADR-003: Signal bus (EventBus) | All cross-system communication via 30-signal EventBus autoload | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-card-engine-001 | Consume 5 InputSystem signals: drag_started, drag_moved, drag_released, proximity_entered, proximity_exited | ADR-003 ✅ |
| TR-card-engine-002 | Per-card FSM with 6 states: Idle, Dragged, Attracting, Snapping, Pushed, Executing | ADR-002 ✅ |
| TR-card-engine-003 | Own authoritative runtime Vector2 position per card node; Table Layout provides initial placement only | ADR-002 ✅ |
| TR-card-engine-004 | In Dragged state, update card.position to cursor world_pos every frame with zero perceptible lag | ADR-002 ✅ |
| TR-card-engine-005 | In Attracting state, apply lerp(cursor_world_pos, target.position, attraction_factor) each frame | ADR-002 ✅ |
| TR-card-engine-006 | Target-follow: attraction lerp re-reads target_card.position each frame so moving targets are tracked | ADR-002 ✅ |
| TR-card-engine-007 | All motion (drag, attraction, snap, push, merge) uses Godot Tween nodes; must be cancellable mid-flight | ADR-002 ✅ |
| TR-card-engine-008 | Snap tween targets target_card.position + snap_offset; duration = snap_duration_sec (default 0.12s, range 0.05–0.3) | ADR-002 ✅ |
| TR-card-engine-009 | On snap tween complete, emit combination_attempted(instance_id_a: String, instance_id_b: String) | ADR-003 ✅ |
| TR-card-engine-010 | Listen for combination_succeeded(a, b, template, config) and combination_failed(a, b) from ITF | ADR-003 ✅ |
| TR-card-engine-011 | Push-away: tween card to pos + normalize(pos − target.pos) * push_distance with ease_out over push_duration_sec | ADR-002 ✅ |
| TR-card-engine-012 | Clamp push_target to table bounds before tweening to prevent off-table placement | ADR-002 ✅ |
| TR-card-engine-013 | Merge template: tween both cards to midpoint, scale to 0, fade to 0 over merge_duration_sec (default 0.25s) | ADR-002 ✅ |
| TR-card-engine-014 | Emit merge_animation_complete(a, b, midpoint) and animate_complete(instance_id) to ITF | ADR-003 ✅ |
| TR-card-engine-015 | Enforce single in-flight combination: ignore new combination_attempted until current resolves | ADR-002 ✅ |
| TR-card-engine-016 | On card_removing signal, cancel any in-flight tween bound to that instance_id before node free | ADR-002, ADR-003 ✅ |
| TR-card-engine-017 | Dragged card renders on top via elevated z_index; coordinate z-order policy with Card Visual | ADR-001 ✅ |
| TR-card-engine-018 | Listen to card_spawned to register node; listen to card_removed to deregister and null-check references | ADR-003 ✅ |
| TR-card-engine-019 | Snap tween interruption: new drag_started cancels Snapping and transitions card back to Dragged | ADR-002 ✅ |
| TR-card-engine-020 | attraction_factor 0.0–0.5 (default 0.4); snap_duration 0.05–0.3s; push_distance 20–80px (default 60) | ADR-002 ✅ |

**Coverage**: 20 / 20 TRs ✅ (zero untraced)

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/card-engine.md` are verified
- All Logic and Integration stories have passing test files in `tests/unit/card_engine/` and `tests/integration/card_engine/`
- All Visual/Feel stories have screenshot evidence + sign-off in `production/qa/evidence/`
- The magnetic snap feel has been iterated and signed off on (attraction_factor, snap_duration, push_distance tuned)

## Stories

| # | Story | Type | Status | ADRs | TRs |
|---|-------|------|--------|------|-----|
| 001 | [CardEngine autoload + 6-state FSM scaffold](story-001-fsm-scaffold.md) | Integration | Ready | ADR-002, ADR-003 | TR-001, TR-002, TR-003, TR-018 |
| 002 | [Drag and Attracting motion](story-002-drag-attract-motion.md) | Logic | Ready | ADR-002 | TR-004, TR-005, TR-006, TR-017, TR-020 |
| 003 | [Snap, combination handshake, and push-away](story-003-snap-combination-pushaway.md) | Integration | Ready | ADR-002, ADR-003 | TR-007, TR-008, TR-009, TR-010, TR-011, TR-012, TR-015, TR-019 |
| 004 | [Merge and Animate template animations + tween cancellation](story-004-merge-animate-tween.md) | Visual/Feel | Ready | ADR-002, ADR-003 | TR-013, TR-014, TR-016 |

**Coverage**: 20 / 20 TRs mapped to stories.

## Next Step

Start implementation: `/story-readiness production/epics/card-engine/story-001-fsm-scaffold.md`
then `/dev-story` to begin. Work stories in order — each story's `Depends on:` field lists what must be DONE first.
