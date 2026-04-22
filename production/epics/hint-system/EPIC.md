# Epic: Hint System

> **Layer**: Feature
> **GDD**: design/gdd/hint-system.md
> **Architecture Module**: Feature Layer — HintSystem (autoload singleton, stagnation timer)
> **Status**: Ready
> **Stories**: 3 stories created

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | HintSystem autoload + goal-conditional activation | Logic | Ready | ADR-004, ADR-005 |
| 002 | Stagnation timer + hint_level_changed | Logic | Ready | ADR-003 |
| 003 | Deactivation + edge cases | Logic | Ready | ADR-003, ADR-004 |

## Overview

The Hint System watches for player stagnation and responds by signalling Status Bar UI to fade in a silent counterclockwise arc around each bar. It is goal-conditional — only activates for bar-type goals (`sustain_above`, `reach_value`). On scene load it reads `get_goal_config()` from Scene Goal System; if no bars are present it stays Dormant. The stagnation timer counts seconds since the last `combination_executed` from ITF. At `stagnation_sec` it emits `hint_level_changed(1)` (faint arc); at `stagnation_sec * 2` it emits `hint_level_changed(2)` (full arc). Any combination resets the clock and emits `hint_level_changed(0)`. The `stagnation_sec` value is per-scene from `SceneData.hint_stagnation_sec` (falling back to 300s if absent), enabling late-chapter scenes to have longer discovery windows.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-005: Data File Format | Per-scene `hint_stagnation_sec` field in `SceneData` Resource; fallback to 300s if absent | LOW |
| ADR-001: Naming Conventions | snake_case variables/signals, PascalCase class names | LOW |
| ADR-003: Signal Bus | Listens to ITF `combination_executed` and SBS `win_condition_met`; emits `hint_level_changed` | LOW |
| ADR-004: Runtime Scene Composition | HintSystem is autoload singleton; initialized before any scene signals flow | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-hint-system-001 | Hint System only activates for bar-type goals; stays Dormant for `find_key` / `sequence` | ADR-004 ✅ |
| TR-hint-system-002 | On scene load (`seed_cards_ready` received): call `get_goal_config()`, reset timer to 0, enter Watching | ADR-003 ✅ |
| TR-hint-system-003 | Stagnation timer counts seconds since last `combination_executed`; resets to 0 on each signal | ADR-003 ✅ |
| TR-hint-system-004 | Handler declares all 6 params of `combination_executed` (Godot 4.3 arity-strict); ignores payload | ADR-003 ✅ |
| TR-hint-system-005 | At `stagnation_sec`: emit `hint_level_changed(1)`; at `stagnation_sec * 2`: emit `hint_level_changed(2)` | ADR-004 ✅ |
| TR-hint-system-006 | On combination while hint showing: emit `hint_level_changed(0)`, reset timer, re-enter Watching | ADR-003 ✅ |
| TR-hint-system-007 | On `win_condition_met()`: enter Dormant, emit `hint_level_changed(0)` | ADR-003 ✅ |
| TR-hint-system-008 | On `scene_completed`: enter Dormant, reset all state | ADR-003 ✅ |
| TR-hint-system-009 | State machine: Dormant → Watching → Hint1 → Hint2 (and back to Watching on combo) | ADR-004 ✅ |
| TR-hint-system-010 | `stagnation_sec` read from `SceneData.hint_stagnation_sec`; fallback to 300s if field absent | ADR-005 ✅ |
| TR-hint-system-011 | Pausing the game does not advance the stagnation timer (`_process(delta)` stops) | ADR-004 ✅ |
| TR-hint-system-012 | `hint_level_changed(0)` emitted when combo fires even if hint already at level 0 (idempotent) | ADR-003 ✅ |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/hint-system.md` are verified
- Logic stories have passing unit tests: timer threshold crossings, combo reset, dormant-for-non-bar-goal
- `stagnation_sec` can be changed per-scene in `SceneData` without code changes

## Next Step

Run `/create-stories hint-system` to break this epic into implementable stories.
