# Epic: Scene Goal System

> **Layer**: Feature
> **GDD**: design/gdd/scene-goal-system.md
> **Architecture Module**: Feature Layer — SceneGoalSystem (autoload singleton + SceneData Resource loader)
> **Status**: Ready
> **Stories**: 4 stories created

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | SceneData load + get_goal_config API | Logic | Ready | ADR-005 |
| 002 | SBS integration + seed_cards_ready | Integration | Ready | ADR-003, ADR-004 |
| 003 | Win condition handling + scene_completed | Integration | Ready | ADR-003 |
| 004 | Bar milestone spawn | Logic | Ready | ADR-005, ADR-003 |

## Overview

The Scene Goal System is the per-scene configuration and completion authority. On `load_scene(scene_id)`, it reads `assets/data/scenes/[scene_id].tres` (a typed `SceneData` Resource per ADR-005), constructs a `scene_bar_config`, calls `StatusBarSystem.configure()` for bar-type goals, and emits `seed_cards_ready(seed_cards[])`. For the MVP `sustain_above` goal it delegates win detection to Status Bar System and listens for `win_condition_met()`. Stubs for `find_key`, `sequence`, and `reach_value` goal types are present but inactive until Vertical Slice. Scene Goal System exposes `get_goal_config()` for Hint System and `reset()` for Scene Manager, and has no system-level math — all bar formulas live in Status Bar System.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-005: Data File Format | Per-scene config in `assets/data/scenes/[scene_id].tres` as typed `SceneData` Resource; `ResourceLoader.load()` with `as SceneData` cast | LOW |
| ADR-001: Naming Conventions | snake_case variables/functions, PascalCase class/Resource names | LOW |
| ADR-003: Signal Bus | Emits `seed_cards_ready` and `scene_completed` via EventBus; listens to `win_condition_met` from SBS | LOW |
| ADR-004: Runtime Scene Composition | SGS is autoload singleton (position 7 in canonical order); called by Scene Manager | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-scene-goal-system-001 | Read per-scene config from `assets/data/scenes/[scene_id].tres` via `ResourceLoader.load() as SceneData` | ADR-005 ✅ |
| TR-scene-goal-system-002 | `load_scene(scene_id)` is the single public entry point; called by Scene Manager | ADR-004 ✅ |
| TR-scene-goal-system-003 | For bar-type goals: call `StatusBarSystem.configure(scene_bar_config)` before emitting `seed_cards_ready` | ADR-003 ✅ |
| TR-scene-goal-system-004 | For non-bar goals (`find_key`, `sequence`): do NOT call `StatusBarSystem.configure()` | ADR-004 ✅ |
| TR-scene-goal-system-005 | Emit `seed_cards_ready(seed_cards[])` after scene JSON parsed successfully | ADR-003 ✅ |
| TR-scene-goal-system-006 | MVP goal monitoring: `sustain_above` — passive, relies on SBS `win_condition_met()` | ADR-003 ✅ |
| TR-scene-goal-system-007 | Stubs for `find_key` and `sequence` goal types: listen to ITF `combination_executed` (6-param handler) | ADR-003 ✅ |
| TR-scene-goal-system-008 | On goal met: emit `scene_completed(scene_id)`, enter Complete state, stop monitoring | ADR-003 ✅ |
| TR-scene-goal-system-009 | State machine: Idle → Active (on load_scene) → Complete (on goal met) → Idle (on reset) | ADR-004 ✅ |
| TR-scene-goal-system-010 | Missing or malformed scene .tres: log error, stay Idle, do not configure downstream systems | ADR-005 ✅ |
| TR-scene-goal-system-011 | `get_goal_config()` returns active goal data while Active; null while Idle | ADR-004 ✅ |
| TR-scene-goal-system-012 | New scene .tres added to `assets/data/scenes/` is loadable without code changes | ADR-005 ✅ |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/scene-goal-system.md` are verified
- Logic stories have passing unit tests for scene load, goal activation, and `scene_completed` emission
- A new `.tres` scene file can be added and loaded without code changes

## Next Step

Run `/create-stories scene-goal-system` to break this epic into implementable stories.
