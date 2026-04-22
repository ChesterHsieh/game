# Epic: Table Layout System

> **Layer**: Core
> **GDD**: `design/gdd/table-layout-system.md`
> **Architecture Module**: `TableLayoutSystem` — stateless; pure positional helpers; seeded RNG
> **Status**: Ready
> **Stories**: 3 stories created 2026-04-22 — see table below

## Overview

TableLayoutSystem is responsible for placing cards in 2D space. It is entirely stateless
at runtime — every call is a pure function: inputs → position output. It computes where
seed cards appear at scene start (`get_seed_card_positions`) and where newly spawned cards
land after a combination (`get_spawn_position`). All placement uses a seeded Godot
`RandomNumberGenerator` so positions are deterministic for a given seed: Chester can fix
any spawn position permanently by recording the logged seed into the recipe or scene data.
The system never moves cards — it provides target positions only; CardSpawningSystem and
SceneManager carry those positions to their destinations.

Overlap avoidance is best-effort: the system retries up to `max_scatter_attempts` and
accepts the least-overlapping position rather than failing. The table must never refuse
to place a card.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-001: Naming conventions | snake_case files/variables, PascalCase class_name; `table_layout_system.gd` | LOW |
| ADR-002: Card object pooling | Positional outputs consumed by CardSpawningSystem which owns node lifecycle | LOW |
| ADR-003: Signal bus (EventBus) | No direct signals emitted — output is synchronous return values to callers | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-table-layout-system-001 | System is stateless at runtime: every call is pure function (inputs → position); no tracking of placed cards | ADR-001 ✅ |
| TR-table-layout-system-002 | Expose get_seed_card_positions(scene_data) → [{card_id, position, seed_used}] for Scene Manager | ADR-001 ✅ |
| TR-table-layout-system-003 | Expose get_spawn_position(combination_point, existing_cards: Vector2[], spawn_seed) → (Vector2, seed) | ADR-001 ✅ |
| TR-table-layout-system-004 | All RNG uses seeded Godot RandomNumberGenerator; deterministic output for identical seed input | ADR-002 ✅ |
| TR-table-layout-system-005 | When spawn_seed / placement_seed is null, generate random seed and log to console for author capture | ADR-001 ✅ |
| TR-table-layout-system-006 | Treat seed value 0 as valid fixed seed, distinct from null | ADR-001 ✅ |
| TR-table-layout-system-007 | Spawn sampling: offset = randf_range(spawn_min_distance, spawn_max_distance); angle = randf_range(0, TAU) | ADR-001 ✅ |
| TR-table-layout-system-008 | Candidate = combination_point + Vector2(cos(angle), sin(angle)) * offset | ADR-001 ✅ |
| TR-table-layout-system-009 | Clamp candidate to Rect2(table_bounds.position, table_bounds.end − card_size) before overlap check | ADR-001 ✅ |
| TR-table-layout-system-010 | Overlap avoidance: reject candidate if within min_card_spacing of any existing card; retry up to max_scatter_attempts | ADR-001 ✅ |
| TR-table-layout-system-011 | On attempt exhaustion, accept least-overlapping candidate and log warning; never fail to return a position | ADR-001 ✅ |
| TR-table-layout-system-012 | Resolve zone enum (left/center/right/top/bottom) to Rect2 region of table for seed placement | ADR-001 ✅ |
| TR-table-layout-system-013 | Clamp combination_point to table bounds before sampling to handle mid-tween edge cases | ADR-001 ✅ |
| TR-table-layout-system-014 | Self-correct misconfigured spawn_min_distance > spawn_max_distance by swapping values with warning | ADR-001 ✅ |
| TR-table-layout-system-015 | Validate card_id against Card Database; log error on zone smaller than card_size and fall back to zone center | ADR-001 ✅ |
| TR-table-layout-system-016 | Tuning knobs: spawn_min_distance 40–120px (default 80), spawn_max_distance 100–250px (default 160) | ADR-001 ✅ |
| TR-table-layout-system-017 | Tuning knobs: min_card_spacing 0–30px (default 10), max_scatter_attempts 3–20 (default 8) | ADR-001 ✅ |

**Coverage**: 17 / 17 TRs ✅ (zero untraced)

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/table-layout-system.md` are verified
- All Logic stories have passing test files in `tests/unit/table_layout_system/`
- Determinism is verified: same seed always returns same position
- The authoring workflow (null seed → log → fix in .tres) is documented and working

## Stories

| # | Story | Type | Status | ADRs | TRs |
|---|-------|------|--------|------|-----|
| 001 | [TableLayoutSystem autoload + stateless API scaffold](story-001-api-scaffold.md) | Logic | Ready | ADR-001 | TR-001, TR-002, TR-003, TR-015 |
| 002 | [Seeded RNG + spawn position sampling](story-002-seeded-rng-sampling.md) | Logic | Ready | ADR-001, ADR-002 | TR-004, TR-005, TR-006, TR-007, TR-008, TR-009, TR-013, TR-014 |
| 003 | [Overlap avoidance + zone placement + tuning knobs](story-003-overlap-zone.md) | Logic | Ready | ADR-001 | TR-010, TR-011, TR-012, TR-016, TR-017 |

**Coverage**: 17 / 17 TRs mapped to stories.

## Next Step

Start implementation: `/story-readiness production/epics/table-layout-system/story-001-api-scaffold.md`
then `/dev-story` to begin. Stories 002 and 003 both depend on story-001; they can be worked in parallel once story-001 is Done.
