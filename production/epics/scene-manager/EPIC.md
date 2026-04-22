# Epic: Scene Manager

> **Layer**: Feature
> **GDD**: design/gdd/scene-manager.md
> **Architecture Module**: Feature Layer — SceneManager (autoload singleton, scene lifecycle FSM)
> **Status**: Ready
> **Stories**: 4 stories created

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | SM autoload + manifest load + Waiting state | Logic | Ready | ADR-004, ADR-005 |
| 002 | Scene Load Sequence + seed_cards_ready watchdog | Integration | Ready | ADR-003, ADR-004 |
| 003 | Scene completion + epilogue entry + saved-game resume | Integration | Ready | ADR-003, ADR-004 |
| 004 | Resume Index API + reset_to_waiting() | Logic | Ready | ADR-004 |

## Overview

Scene Manager moves Ju through the chapters of her relationship story. It owns the scene lifecycle: loading `scene-manifest.tres` at startup, subscribing to `EventBus.game_start_requested` with `CONNECT_ONE_SHOT` (Main Menu fires this), coordinating the Scene Load Sequence (scene_loading → SGS.load_scene → seed card placement → scene_started), and advancing to the next scene on `scene_completed`. It is idle during gameplay — all mechanics are owned by other systems. When `_current_index >= manifest.size()` it emits `epilogue_started()`. Scene Manager exposes a Resume Index API (`get_resume_index` / `set_resume_index`) for Save/Progress integration and a `reset_to_waiting()` method for the Reset Progress flow. All signals flow through EventBus (ADR-003). A 5-second `seed_cards_ready` watchdog prevents deadlock on malformed scenes.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-004: Runtime Scene Composition | Scene Manager is autoload position 11; `CONNECT_ONE_SHOT` for `game_start_requested`; pre-instanced FES at layer 20 | LOW |
| ADR-001: Naming Conventions | snake_case variables/functions, PascalCase class names | LOW |
| ADR-003: Signal Bus | All inter-system communication via EventBus; SM emits `scene_loading`, `scene_started`, `epilogue_started` | LOW |
| ADR-005: Data File Format | `scene-manifest.tres` as `SceneManifest` Resource; per-scene data as `SceneData` Resource | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-scene-manager-001 | Load ordered scene manifest from `assets/data/scene-manifest.tres` (`SceneManifest` Resource) at `_ready()` | ADR-005 ✅ |
| TR-scene-manager-002 | On `_ready()`: enter Waiting state, subscribe to `game_start_requested` with `CONNECT_ONE_SHOT` | ADR-004 ✅ |
| TR-scene-manager-003 | Scene Load Sequence: emit `scene_loading` → call `SGS.load_scene` → connect `seed_cards_ready` before calling → place seed cards → emit `scene_started` | ADR-003 ✅ |
| TR-scene-manager-004 | `seed_cards_ready` must be connected before `load_scene()` is called (guard against synchronous signal) | ADR-003 ✅ |
| TR-scene-manager-005 | Scene Completion Sequence: Transitioning → `clear_all_cards()` → one frame await → `SGS.reset()` → increment index | ADR-004 ✅ |
| TR-scene-manager-006 | Next scene vs. epilogue: if index < manifest.size() load next; else enter Epilogue, emit `epilogue_started()` | ADR-003 ✅ |
| TR-scene-manager-007 | State machine: Waiting → Loading → Active → Transitioning → Epilogue (terminal) | ADR-004 ✅ |
| TR-scene-manager-008 | All state guards: ignore `scene_completed` / `seed_cards_ready` when not in the expected state | ADR-004 ✅ |
| TR-scene-manager-009 | `seed_cards_ready` watchdog timeout (default 5s): log error, emit `scene_started` with zero cards, enter Active | ADR-004 ✅ |
| TR-scene-manager-010 | Fatal error path: missing/malformed `scene-manifest.tres` → log error, enter Epilogue | ADR-005 ✅ |
| TR-scene-manager-011 | Resume Index API: `get_resume_index() -> int` (pure read); `set_resume_index(int)` (guarded: Waiting only) | ADR-004 ✅ |
| TR-scene-manager-012 | `set_resume_index` rejects negative values and invalid states with error log | ADR-004 ✅ |
| TR-scene-manager-013 | Saved completed-game resume: `_current_index >= manifest.size()` on `game_start_requested` → enter Epilogue directly | ADR-004 ✅ |
| TR-scene-manager-014 | `reset_to_waiting()`: clears all state, resets index to 0, re-arms `CONNECT_ONE_SHOT`, returns to Waiting | ADR-004 ✅ |
| TR-scene-manager-015 | `reset_to_waiting()` from Loading: cancel watchdog timer before state mutation | ADR-004 ✅ |
| TR-scene-manager-016 | `process_mode = PROCESS_MODE_ALWAYS` so SM processes even when scene tree is paused | ADR-004 ✅ |
| TR-scene-manager-017 | Validate required autoload singletons non-null in `_ready()`; log fatal error if missing | ADR-004 ✅ |
| TR-scene-manager-018 | Defer first frame via `await get_tree().process_frame` in `_ready()` before signals flow | ADR-004 ✅ |
| TR-scene-manager-019 | Mismatched `scene_completed` (scene_id doesn't match _manifest[_current_index]): ignore, log warning with both IDs | ADR-003 ✅ |
| TR-scene-manager-020 | Scene manifest containing duplicate scene_ids is accepted (no reordering); log debug note | ADR-005 ✅ |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/scene-manager.md` are verified (manifest loading, startup, load sequence, completion sequence, resume API, reset API, state guards, timeout, data validation, inter-system coordination)
- Logic and Integration stories have passing test files covering all state machine transitions and the full playthrough sequence

## Next Step

Run `/create-stories scene-manager` to break this epic into implementable stories.
