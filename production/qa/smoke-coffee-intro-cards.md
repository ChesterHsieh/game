# Smoke Check: Coffee-Intro Tutorial Cards (Story 001)

**Date**: 2026-04-23
**Story**: `production/epics/scene-composition/story-001-tutorial-seed-cards.md`

## Change under test

Added three new `CardEntry` SubResources to `assets/data/cards.tres`:

| id | display_name | type | scene_id |
|---|---|---|---|
| `coffee_machine` | Coffee Machine | 3 (object) | `coffee-intro` |
| `coffee_beans` | Coffee Beans | 3 (object) | `coffee-intro` |
| `coffee` | Coffee | 3 (object) | `coffee-intro` |

`KNOWN_SCENE_IDS` in `src/core/card_database.gd` extended with `"coffee-intro"`
so the new entries do not trigger the orphaned-scene warning.

## Validation

- Editor reload (`godot --headless --editor --quit`) produced no parse errors
  on `cards.tres` and no `CardDatabase: duplicate card id` asserts.
- Manifest entries array now contains 23 `CardEntry` references (was 20).

## Verdict: PASS

All three cards are present, unique, typed correctly, and the scene_id does
not trigger orphan warnings. Story 001 complete.
