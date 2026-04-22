# Epic: Mystery Unlock Tree

> **Layer**: Feature
> **GDD**: design/gdd/mystery-unlock-tree.md
> **Architecture Module**: Feature Layer — MysteryUnlockTree (autoload singleton, discovery registry)
> **Status**: Ready
> **Stories**: 3 stories created

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | MUT autoload + discovery recording + state machine | Logic | Ready | ADR-003, ADR-004 |
| 002 | Milestones + carry-forward + epilogue conditions | Logic | Ready | ADR-003, ADR-005 |
| 003 | Save/load round-trip + force_unlock_all dev bypass | Logic | Ready | ADR-004, ADR-005 |

## Overview

The Mystery Unlock Tree is a pure-observer autoload singleton that tracks which card combinations Ju has discovered across the full game session. It listens to ITF's 6-parameter `combination_executed` signal and records each unique recipe into `_discovered_recipes` (with scene context, discovery order, and template type) plus two secondary indices. It evaluates three kinds of output: per-discovery `recipe_discovered` signals (player-visible moments), silent `discovery_milestone_reached` signals (narrative beats, no UI feedback), and one-time epilogue condition signals. MUT answers Scene Goal System's `get_carry_forward_cards()` query to determine which prior-scene cards appear as additional seed cards in later scenes. Save/Progress integration uses `get_save_state()` / `load_save_state()`. A `force_unlock_all` dev flag (excluded from release exports) bulk-marks all recipes without firing any signals.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-005: Data File Format | `mut-config.tres`, `epilogue-requirements.tres`, `debug-config.tres`, and scene carry-forward data all as `.tres` Resources | LOW |
| ADR-001: Naming Conventions | snake_case variables/functions, PascalCase class names | LOW |
| ADR-003: Signal Bus | Listens to `combination_executed`, `scene_started`, `scene_completed`, `epilogue_started` via EventBus; emits `recipe_discovered`, `discovery_milestone_reached`, `epilogue_conditions_met`, `final_memory_ready` | LOW |
| ADR-004: Runtime Scene Composition | MUT is autoload position 10; must be declared after RecipeDatabase (position 3) in project.godot | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-mystery-unlock-tree-001 | MUT is autoload singleton; pure observer — never spawns cards, modifies recipes, or gates recipe execution | ADR-004 ✅ |
| TR-mystery-unlock-tree-002 | Discovery processing: on first-time `combination_executed` in Active state, record 5-field entry, populate secondary indices, emit `recipe_discovered` | ADR-003 ✅ |
| TR-mystery-unlock-tree-003 | Duplicate recipe silently ignored; `_discovery_order_counter` unchanged | ADR-003 ✅ |
| TR-mystery-unlock-tree-004 | Handler declares all 6 params of `combination_executed` (Godot 4.3 arity-strict); reads `recipe_id`, `card_id_a`, `card_id_b` | ADR-003 ✅ |
| TR-mystery-unlock-tree-005 | State machine: Inactive → Active (scene_started) → Transitioning (scene_completed) → Active (next scene_started) → Epilogue (epilogue_started, terminal) | ADR-004 ✅ |
| TR-mystery-unlock-tree-006 | Carry-forward eligibility: `get_carry_forward_cards(spec)` returns card IDs where all `requires_recipes` are in `_discovered_recipes` | ADR-005 ✅ |
| TR-mystery-unlock-tree-007 | Discovery milestones: `_milestone_pct` array resolved to absolute thresholds at `_ready()`; each threshold fires `discovery_milestone_reached` exactly once; post-resolution dedup removes collisions | ADR-005 ✅ |
| TR-mystery-unlock-tree-008 | Epilogue condition: load `epilogue-requirements.tres` at `_ready()`; emit `epilogue_conditions_met()` once mid-session when condition met; `_epilogue_conditions_emitted` persisted in save state | ADR-005 ✅ |
| TR-mystery-unlock-tree-009 | `final_memory_ready()` emitted on `epilogue_started()` if `R_found >= ceil(R_total * partial_threshold)` | ADR-003 ✅ |
| TR-mystery-unlock-tree-010 | `_epilogue_conditions_emitted` guard: once true, `epilogue_conditions_met()` never re-fires this or future sessions | ADR-005 ✅ |
| TR-mystery-unlock-tree-011 | `partial_threshold == 0.0` suppresses mid-session `epilogue_conditions_met` entirely; `final_memory_ready` still evaluated on `epilogue_started` | ADR-005 ✅ |
| TR-mystery-unlock-tree-012 | `force_unlock_all` dev bypass: bulk-marks all recipes without firing signals; `debug-config.tres` excluded from release exports | ADR-005 ✅ |
| TR-mystery-unlock-tree-013 | Save/load round-trip: `get_save_state()` / `load_save_state(data)` covers all three dictionaries and `_epilogue_conditions_emitted` | ADR-005 ✅ |
| TR-mystery-unlock-tree-014 | Stale recipe on load (removed from Recipe Database): prune from dictionaries, log warning, recalculate counter | ADR-005 ✅ |
| TR-mystery-unlock-tree-015 | `R_authored == 0` at startup (Recipe Database load failure): skip milestone resolution, set `_milestone_thresholds = []`, log error | ADR-004 ✅ |
| TR-mystery-unlock-tree-016 | Empty `_epilogue_required_ids`: log error, suppress both `epilogue_conditions_met` and `final_memory_ready` entirely | ADR-005 ✅ |
| TR-mystery-unlock-tree-017 | Autoload order: EventBus → RecipeDatabase → MysteryUnlockTree declared in project.godot | ADR-004 ✅ |
| TR-mystery-unlock-tree-018 | Query API is side-effect-free: no signals emitted, no dictionaries mutated by any read method | ADR-004 ✅ |
| TR-mystery-unlock-tree-019 | Typed-array write discipline: `_scene_discoveries` values initialized as `Array[String]` (not plain Array) | ADR-004 ✅ |
| TR-mystery-unlock-tree-020 | `force_unlock_all` excluded from release exports via `export_presets.cfg` per-preset exclude filter | ADR-005 ✅ |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/mystery-unlock-tree.md` are verified (AC-001 through AC-055)
- Logic stories have passing unit tests for all discovery, milestone, carry-forward, epilogue, and save/load scenarios
- `discovery_milestone_reached` and `epilogue_conditions_met` signals produce no player-visible feedback in downstream consumers

## Next Step

Run `/create-stories mystery-unlock-tree` to break this epic into implementable stories.
