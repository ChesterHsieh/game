# Epic: Card Database

> **Layer**: Foundation
> **GDD**: `design/gdd/card-database.md`
> **Architecture Module**: `CardDatabase` (autoload singleton)
> **Status**: Complete
> **Stories**: 7 stories created 2026-04-21 — see table below

## Overview

CardDatabase is the read-only single source of truth for every card definition in
the game. It loads a `CardManifest` Resource (`res://assets/data/cards.tres`) once
at game start, exposes read-only lookup by `id`, and performs load-time validation
(unique IDs, non-empty `display_name`, enum-valid `type`, warning on missing art).
No system writes to it at runtime. All other card-aware systems (Recipe Database,
Card Engine, Card Visual, Card Spawning System, Save/Progress System) resolve
card identity by `id` via this singleton.

Authoring the Card Database is equivalent to writing the game's content — every
memory encoded for Ju begins as an entry here.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-001: Naming conventions | snake_case for files and variables, PascalCase for class_name | LOW |
| ADR-005: `.tres` everywhere | Persist all game data as typed Godot Resource classes via `ResourceLoader.load() as CardManifest`; no JSON | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-card-database-001 | Load all card definitions once at game start and hold in memory for session (no lazy load) | ADR-005 ✅ |
| TR-card-database-002 | Expose read-only lookup by `id` returning full card entry (id, display_name, flavor_text, art_path, type, scene_id, tags) | ADR-005 ✅ |
| TR-card-database-003 | Enforce unique kebab-case `id` per card; fail loudly at load time on duplicate IDs | ADR-001, ADR-005 ✅ |
| TR-card-database-004 | Support 7 card types enum: person, place, feeling, object, moment, inside_joke, seed | ADR-005 ✅ |
| TR-card-database-005 | Validate `display_name` non-empty and log warning for empty entries at load time | ADR-005 ✅ |
| TR-card-database-006 | Log clear error naming missing ID when lookup requests unknown card; do not crash | ADR-005 ✅ |
| TR-card-database-007 | Reference card art via `res://assets/cards/*.png` paths; missing asset falls back to placeholder with warning | ADR-005 ✅ |
| TR-card-database-008 | Resolve cards by `scene_id` string or `global`; warn on orphaned scene_id references at load | ADR-005 ✅ |
| TR-card-database-009 | Persist card definitions in `res://assets/data/cards.tres` as typed Resource manifest of `CardEntry` SubResources; load via `ResourceLoader.load() as CardManifest` | ADR-005 ✅ |
| TR-card-database-010 | Guarantee full DB load completes before any card instantiation (no race condition) | ADR-005 ✅ |
| TR-card-database-011 | Scale to ~120–200 total card entries across 5–8 scenes with ~20–30 cards per scene | ADR-005 ✅ |

**Coverage**: 11 / 11 TRs ✅ (zero untraced)

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/card-database.md` are verified
- All Logic and Integration stories have passing test files in `tests/unit/card_database/` and `tests/integration/card_database/`
- Config/Data stories have a smoke-check pass documented in `production/qa/`
- A seed `cards.tres` manifest exists in `res://assets/data/` with at least the MVP-scene set of card entries

## Stories

| # | Story | Type | Status | ADR | TRs |
|---|-------|------|--------|-----|-----|
| 001 | [EventBus autoload — 30-signal contract](story-001-event-bus-autoload.md) | Integration | Complete | ADR-003 | (infra) |
| 002 | [CardEntry + CardManifest Resource classes](story-002-card-entry-manifest-resources.md) | Logic | Complete | ADR-005 | TR-004, TR-009 |
| 003 | [CardDatabase autoload — manifest load + typed cast](story-003-card-database-autoload-load.md) | Integration | Complete | ADR-005 | TR-001, TR-009, TR-010 |
| 004 | [Load-time validation — uniqueness, display_name, orphan scene](story-004-load-time-validation.md) | Logic | Complete | ADR-005 | TR-003, TR-005, TR-008 |
| 005 | [Public lookup API — get_card(id) + get_all()](story-005-lookup-api.md) | Logic | Complete | ADR-005 | TR-002, TR-006 |
| 006 | [Missing-art detection + placeholder warning](story-006-missing-art-detection.md) | Logic | Complete | ADR-005 | TR-007 |
| 007 | [Seed cards.tres manifest — MVP scene-01 card set](story-007-seed-cards-tres-manifest.md) | Config/Data | Complete | ADR-005 | TR-011 |

**Coverage**: 11 / 11 TRs mapped to stories (TR-004 mapped to Story 002; TR-009 spans Stories 002+003).

## Next Step

Start implementation: `/story-readiness production/epics/card-database/story-001-event-bus-autoload.md`
then `/dev-story` to begin. Work stories in order — each story's `Depends on:`
field lists what must be DONE first.
