# Smoke Check: Coffee-Intro Tutorial Recipes (Story 002)

**Date**: 2026-04-23
**Story**: `production/epics/scene-composition/story-002-tutorial-recipes.md`

## Changes under test

### `assets/data/recipes.tres`

Added two new `RecipeEntry` SubResources:

| id | card_a | card_b | template | scene_id | result_card |
|---|---|---|---|---|---|
| `brew-coffee` | `coffee_machine` | `coffee_beans` | merge | `coffee-intro` | `coffee` |
| `deliver-coffee` | `coffee` | `ju` | merge | `coffee-intro` | `seed-together` |

### `assets/data/bar-effects.json`

Added key `"deliver-coffee": { "affection": 100 }`.

## Deviations from story spec

The story originally proposed underscore-named recipe IDs (`brew_coffee`,
`deliver_coffee`). Project convention — as seen in every other recipe id
(`chester-rainy-afternoon`, `ju-our-cafe`) and bar-effects key
(`chester-ju`, `chester-home`) — is kebab-case. Implemented kebab-case to
remain consistent; the sub_resource attribute id (`RecipeEntry_brew_coffee`)
still uses underscores because Godot 4.3 rejects hyphens there.

Result card for `deliver-coffee` is `seed-together` (existing card) rather
than `morning-together` (which does not exist in `cards.tres`).
`seed-together` is thematically fitting — the tutorial's delivery leaves
behind a "Together" memory card as visible evidence of the completed scene.

## Validation

- Editor reload (`godot --headless --editor --quit`) produced no
  `RecipeDatabase: unknown card_a/card_b/result_card` asserts.
- All three referenced cards (`coffee_machine`, `coffee_beans`, `coffee`)
  exist in `cards.tres` from Story 001; `ju` and `seed-together` are
  pre-existing.
- `bar-effects.json` remains valid JSON (no trailing-comma issues).

## Verdict: PASS

Recipes load cleanly. Bar effect is wired to `affection` which will be
declared as the scene bar in Story 003. Story 002 complete.
