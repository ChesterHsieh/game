# Epic: Card Spawning System

> **Layer**: Core
> **GDD**: `design/gdd/card-spawning-system.md`
> **Architecture Module**: `CardSpawningSystem` — sole `instantiate()`/`queue_free()` authority; instance_id registry; lifecycle signals
> **Status**: Ready
> **Stories**: 3 stories created 2026-04-22 — see table below

## Overview

CardSpawningSystem is the sole system with authority to create or destroy card nodes on
the table. No other system may call `instantiate()` or `queue_free()` on card nodes
directly. It assigns each spawned card a unique `instance_id` in the format
`card_id + "_" + counter` (e.g. `morning-light_0`) and maintains an authoritative
runtime registry of all live cards. Counters increment globally across the session and
retired values are never reused — preventing stale signal references from redirecting
to newly spawned cards.

The system has two callers: **Interaction Template Framework** (combination-driven spawns
and removals) and **Scene Manager** (seed card setup and scene-transition clearing). It
emits three lifecycle signals — `card_spawned`, `card_removing`, `card_removed` — that
CardEngine and CardVisual use to register, cancel tweens, and attach visuals.
`card_removing` fires before `queue_free` so CardEngine can cancel in-flight tweens
safely. During scene transitions the system enters a `Clearing` state and queues any
incoming spawn requests until the clear completes.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-002: Card object pooling | CardSpawningSystem is the sole instantiate/free authority; instance_id registry prevents stale refs | LOW |
| ADR-001: Naming conventions | snake_case files/variables, PascalCase class_name; `card_spawning_system.gd` | LOW |
| ADR-003: Signal bus (EventBus) | card_spawned / card_removing / card_removed emitted on EventBus; all consumers connect via bus | LOW |
| ADR-004: Runtime scene composition + autoload order | CardSpawningSystem is autoload #7; Scene Manager calls it during load and transition | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-card-spawning-system-001 | Sole authority for card node instantiate()/queue_free(); no other system may create or destroy card nodes | ADR-002 ✅ |
| TR-card-spawning-system-002 | Maintain internal registry Dictionary {instance_id: String → Node} of all live card nodes on table | ADR-002 ✅ |
| TR-card-spawning-system-003 | Maintain per-card_id counter Dictionary _next_counter; increment on each spawn, never reset during session | ADR-002 ✅ |
| TR-card-spawning-system-004 | Generate instance_id as card_id + '_' + str(counter); retired counters are never reused | ADR-002 ✅ |
| TR-card-spawning-system-005 | spawn_card(card_id, position) → instance_id; validates card_id in Card Database, returns null on failure | ADR-001, ADR-002 ✅ |
| TR-card-spawning-system-006 | On spawn: instantiate scene, set card_id/instance_id properties, set position, add_child, register, emit signal | ADR-002, ADR-004 ✅ |
| TR-card-spawning-system-007 | Emit card_spawned(instance_id: String, card_id: String, position: Vector2) after add_child completes | ADR-003 ✅ |
| TR-card-spawning-system-008 | remove_card(instance_id): emit card_removing BEFORE erase + free; emit card_removed AFTER free | ADR-003 ✅ |
| TR-card-spawning-system-009 | card_removing must fire before queue_free to allow Card Engine to cancel in-flight tweens on the node | ADR-003 ✅ |
| TR-card-spawning-system-010 | remove_card with unknown instance_id: log warning, no crash, no action (idempotent) | ADR-002 ✅ |
| TR-card-spawning-system-011 | spawn_card with unknown card_id: log error naming ID and caller, return null, do not instantiate | ADR-002 ✅ |
| TR-card-spawning-system-012 | Internal state machine: Ready (accepts requests) vs Clearing (queues spawns until clear completes) | ADR-002 ✅ |
| TR-card-spawning-system-013 | clear_all_cards(): enter Clearing, emit card_removing + card_removed for each live card, empty registry | ADR-003, ADR-004 ✅ |
| TR-card-spawning-system-014 | During Clearing, queue incoming spawn_card() calls and execute after clear completes | ADR-002 ✅ |
| TR-card-spawning-system-015 | spawn_seed_cards(scene_data) → instance_id[]; preserves input ordering in returned array | ADR-001, ADR-002 ✅ |
| TR-card-spawning-system-016 | Expose get_live_cards() returning authoritative list of current instance_ids on table | ADR-002 ✅ |
| TR-card-spawning-system-017 | Only ITF and Scene Manager may invoke spawn_card / remove_card / spawn_seed_cards / clear_all_cards | ADR-002 ✅ |
| TR-card-spawning-system-018 | Downstream signal consumers: Card Engine (register/cancel/deregister) and Card Visual (attach visuals) | ADR-003 ✅ |

**Coverage**: 18 / 18 TRs ✅ (zero untraced)

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/card-spawning-system.md` are verified
- All Logic and Integration stories have passing test files in `tests/unit/card_spawning_system/` and `tests/integration/card_spawning_system/`
- instance_id uniqueness and counter non-reuse are verified by automated tests
- Clearing-state queue behavior is verified under scene transition conditions

## Stories

| # | Story | Type | Status | ADRs | TRs |
|---|-------|------|--------|------|-----|
| 001 | [CardSpawningSystem autoload + object pool + instance_id registry](story-001-pool-registry.md) | Logic | Ready | ADR-002 | TR-001, TR-002, TR-003, TR-004, TR-016, TR-017 |
| 002 | [spawn_card() + card lifecycle signals](story-002-spawn-lifecycle.md) | Integration | Ready | ADR-002, ADR-003, ADR-004 | TR-005, TR-006, TR-007, TR-011, TR-015, TR-018 |
| 003 | [remove_card() + Clearing state + clear_all_cards()](story-003-remove-clearing.md) | Integration | Ready | ADR-002, ADR-003, ADR-004 | TR-008, TR-009, TR-010, TR-012, TR-013, TR-014 |

**Coverage**: 18 / 18 TRs mapped to stories.

## Next Step

Start implementation: `/story-readiness production/epics/card-spawning-system/story-001-pool-registry.md`
then `/dev-story` to begin. Work stories in order — story-003 is the final unlock for the Feature layer epics (InteractionTemplateFramework depends on CardEngine + CardSpawningSystem both Done).
