# Epic: Status Bar System

> **Layer**: Feature
> **GDD**: design/gdd/status-bar-system.md
> **Architecture Module**: Feature Layer — StatusBarSystem (autoload singleton)
> **Status**: Ready
> **Stories**: 3 stories created

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | SBS autoload + configure + state machine | Logic | Ready | ADR-005 |
| 002 | Bar effects (combination_executed handler) | Integration | Ready | ADR-003, ADR-005 |
| 003 | Decay + sustain win condition | Logic | Ready | ADR-003 |

## Overview

The Status Bar System tracks two hidden progress bars and updates them as the player makes combinations. It is dormant until Scene Goal System activates it via `configure(scene_bar_config)`. On each `combination_executed` from ITF it looks up the `recipe_id` in `assets/data/bar-effects.tres` and applies authored deltas. Bars decay passively each frame at a per-bar `decay_rate_per_sec`. The system monitors a `sustain_above` win condition every frame — when all bars are simultaneously at or above `threshold` for `duration_sec` continuous seconds, it emits `win_condition_met()` and freezes. All bar values, thresholds, and decay rates are authored per-scene in `scene_bar_config`; bar effects are authored in `bar-effects.tres` — no system-level tuning knobs exist.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-005: Data File Format | Bar effects authored in `assets/data/bar-effects.tres` as a `BarEffects` Resource (Dictionary: recipe_id → {bar_id: delta}) | LOW |
| ADR-001: Naming Conventions | snake_case variables/functions, PascalCase class names | LOW |
| ADR-003: Signal Bus | Listens to ITF `combination_executed` via EventBus; emits `bar_values_changed` and `win_condition_met` | LOW |
| ADR-004: Runtime Scene Composition | SBS is autoload singleton (position 8 in canonical order); receives `configure()` call from Scene Goal System | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-status-bar-system-001 | SBS is dormant until `configure(scene_bar_config)` is called by Scene Goal System | ADR-004 ✅ |
| TR-status-bar-system-002 | `scene_bar_config` defines bars (id, initial_value, decay_rate_per_sec), max_value, and win_condition | ADR-005 ✅ |
| TR-status-bar-system-003 | Bar effects authored in `assets/data/bar-effects.tres` as flat `recipe_id → {bar_id: delta}` map | ADR-005 ✅ |
| TR-status-bar-system-004 | On `combination_executed`: look up recipe_id in bar-effects, apply deltas, clamp to [0, max_value], emit `bar_values_changed` | ADR-003 ✅ |
| TR-status-bar-system-005 | Handler declares all 6 params of `combination_executed` (Godot 4.3 arity-strict); reads only recipe_id | ADR-003 ✅ |
| TR-status-bar-system-006 | Per-bar passive decay: tick down by `decay_rate_per_sec * delta` each frame while Active; clamp at 0 | ADR-004 ✅ |
| TR-status-bar-system-007 | Win condition `sustain_above`: track `sustained_time`; increment when all bars ≥ threshold; reset to 0 if any drops below | ADR-004 ✅ |
| TR-status-bar-system-008 | Emit `win_condition_met()` exactly once when `sustained_time >= duration_sec`; enter Complete state | ADR-003 ✅ |
| TR-status-bar-system-009 | After `win_condition_met()`: stop decay, stop monitoring, freeze bar values | ADR-004 ✅ |
| TR-status-bar-system-010 | State machine: Dormant → Active (on configure) → Complete (on win) → Dormant (on scene transition) | ADR-004 ✅ |
| TR-status-bar-system-011 | Unknown bar_id in bar-effects.tres: skip that effect, log warning, apply valid bar effects | ADR-005 ✅ |
| TR-status-bar-system-012 | Bar effects data editable in `bar-effects.tres` without code changes | ADR-005 ✅ |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/status-bar-system.md` are verified
- Logic stories have passing unit tests covering bar math (clamping, decay, sustain timer)
- `bar-effects.tres` can be edited without code changes and changes take effect at next scene load

## Next Step

Run `/create-stories status-bar-system` to break this epic into implementable stories.
