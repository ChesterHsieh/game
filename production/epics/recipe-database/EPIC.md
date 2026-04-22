# Epic: Recipe Database

> **Layer**: Foundation
> **GDD**: `design/gdd/recipe-database.md`
> **Architecture Module**: `RecipeDatabase` (autoload singleton)
> **Status**: Complete
> **Stories**: 7 stories created 2026-04-21 — see table below

## Overview

RecipeDatabase is the read-only, stateless lookup for every combination rule in
the game. Each entry maps a card pair `(card_a, card_b)` to one of four
interaction templates (Additive / Merge / Animate / Generator) plus a
template-specific `config`. Lookups are symmetric (pair order normalized), and
scene-scoped rules take precedence over global rules for the same pair.
Incompatible pairs return null — not an error, simply no rule exists.

Loaded from a `RecipeManifest` Resource (`res://assets/data/recipes.tres`) at
game start. Load-time validation cross-checks every `card_a` / `card_b` /
`result_card` against CardDatabase and fails loudly on unknown IDs.

**Depends on**: CardDatabase (load-time ID validation). The CardDatabase epic
must be implemented first.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-001: Naming conventions | snake_case / PascalCase / SCREAMING_SNAKE_CASE per kind | LOW |
| ADR-005: `.tres` everywhere | `RecipeEntry` Resource SubResources in `recipes.tres`; `config: Dictionary` is the documented exception (template-specific shape owned by ITF per ADR-005 §8) | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-recipe-database-001 | Load all recipe definitions once at game start and hold in memory for session | ADR-005 ✅ |
| TR-recipe-database-002 | Expose symmetric lookup by `(card_a_id, card_b_id)` pair returning recipe or null; normalize pair order | ADR-005 ✅ |
| TR-recipe-database-003 | Support 4 template enum: Additive, Merge, Animate, Generator, each with template-specific `config` schema | ADR-005 ✅ |
| TR-recipe-database-004 | Validate all card_a/card_b/result IDs exist in Card Database at load time; fail loudly on unknown ID | ADR-005 ✅ |
| TR-recipe-database-005 | Detect duplicate rules for same pair within same scene at load time and fail loudly | ADR-005 ✅ |
| TR-recipe-database-006 | Resolve scene-scoped rules with precedence over global rules for same pair | ADR-005 ✅ |
| TR-recipe-database-007 | Clamp Generator `interval_sec` minimum to 0.5 seconds; log warning on values below | ADR-005 ✅ |
| TR-recipe-database-008 | Return null for unmatched pairs as non-error signaling incompatibility | ADR-005 ✅ |
| TR-recipe-database-009 | Remain stateless — no runtime writes; all execution state owned by Interaction Template Framework | ADR-005 ✅ |
| TR-recipe-database-010 | Persist recipes in `res://assets/data/recipes.tres` as typed Resource manifest of `RecipeEntry` SubResources; load via `ResourceLoader.load() as RecipeManifest` | ADR-005 ✅ |
| TR-recipe-database-011 | Guarantee full DB load completes before any combination attempt can be made | ADR-005 ✅ |
| TR-recipe-database-012 | Scale to ~150–300 total recipes, ~30–60 per scene | ADR-005 ✅ |

**Coverage**: 12 / 12 TRs ✅ (zero untraced)

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/recipe-database.md` are verified
- Logic stories (symmetric lookup, precedence resolution, interval clamp) have passing unit tests in `tests/unit/recipe_database/`
- Cross-validation against CardDatabase is tested end-to-end in `tests/integration/recipe_database/`
- A seed `recipes.tres` manifest exists with at least the MVP-scene recipe set
- `Dictionary config` shape for each of the 4 templates is exercised at least once in test fixtures

## Stories

| # | Story | Type | Status | ADR | TRs |
|---|-------|------|--------|-----|-----|
| 001 | [RecipeEntry + RecipeManifest Resource classes](story-001-recipe-entry-manifest-resources.md) | Logic | Complete | ADR-005 | TR-003, TR-010 |
| 002 | [RecipeDatabase autoload — manifest load + typed cast](story-002-recipe-database-autoload-load.md) | Integration | Complete | ADR-005 | TR-001, TR-010, TR-011 |
| 003 | [Cross-validation against CardDatabase — card_a / card_b / result IDs](story-003-cross-validation-card-ids.md) | Integration | Complete | ADR-005 | TR-004 |
| 004 | [Duplicate-rule detection — same pair in same scene](story-004-duplicate-rule-detection.md) | Logic | Complete | ADR-005 | TR-005 |
| 005 | [Generator interval_sec clamp (≥ 0.5 s)](story-005-generator-interval-clamp.md) | Logic | Complete | ADR-005 | TR-007 |
| 006 | [Public lookup API — symmetric pair + scene precedence](story-006-lookup-api.md) | Logic | Complete | ADR-005 | TR-002, TR-006, TR-008, TR-009 |
| 007 | [Seed recipes.tres manifest — MVP scene-01 recipe set](story-007-seed-recipes-tres-manifest.md) | Config/Data | Complete | ADR-005 | TR-012 |

**Coverage**: 12 / 12 TRs mapped to stories (TR-003 + TR-010 span Stories 001+002; TR-010 + TR-011 in Story 002).

## Next Step

Start implementation: `/story-readiness production/epics/recipe-database/story-001-recipe-entry-manifest-resources.md`
then `/dev-story` to begin. Work stories in order — each story's `Depends on:`
field lists what must be DONE first.
