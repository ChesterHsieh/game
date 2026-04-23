# Story 002: Tutorial recipes + bar effects (brew, deliver)

> **Epic**: scene-composition
> **Status**: Complete
> **Layer**: Presentation + Content
> **Type**: Config/Data
> **Manifest Version**: 2026-04-21

## Context

**GDD**: `design/gdd/recipe-database.md`, `design/gdd/status-bar-system.md`
**Requirement**: reuses TR-recipe-database-001/002, TR-status-bar-system-002

**ADR Governing Implementation**: ADR-005: Data File Format Convention
**ADR Decision Summary**: Recipes persist in `assets/data/recipes.tres` as
`RecipeEntry` SubResources; bar effects are looked up by `recipe_id` in
`assets/data/bar-effects.json` (the one documented JSON exception per ADR-005 §8).

**Engine**: Godot 4.3 | **Risk**: LOW
**Engine Notes**: `RecipeDatabase._assert_card_exists()` cross-validates every
`card_a` / `card_b` / `result_card` against CardDatabase at load time — all
referenced IDs must exist or the game fails to boot.

**Control Manifest Rules (Content layer)**:
- Required: every recipe's `card_a`/`card_b`/`result_card` must match an entry in `cards.tres`
- Required: bar-effects.json key must equal the recipe `id`
- Forbidden: template strings outside {"additive","merge","animate","generator"}

---

## Acceptance Criteria

- [ ] Recipe `brew_coffee` exists in `recipes.tres` — `card_a=coffee_machine`, `card_b=coffee_beans`, `template="merge"`, `scene_id="coffee-intro"`, `config.result_card="coffee"`
- [ ] Recipe `deliver_coffee` exists — `card_a=coffee`, `card_b=ju`, `template="merge"`, `scene_id="coffee-intro"`, `config.result_card="morning-together"`
- [ ] `bar-effects.json` has an entry `"deliver_coffee": { "affection": 100 }`
- [ ] `RecipeDatabase.get_recipe(&"brew_coffee")` and `get_recipe(&"deliver_coffee")` both return non-null at startup
- [ ] No `push_error` from RecipeDatabase._assert_card_exists during load

---

## Implementation Notes

Append two `[sub_resource type="Resource" id="RecipeEntry_brew_coffee"]` and
`RecipeEntry_deliver_coffee` blocks to `recipes.tres`. Add their SubResource
references to the `RecipeManifest.entries` array. Both recipes use the existing
`Merge` template which consumes `card_a` and `card_b` and spawns `result_card`
at the merge midpoint (handled by ITF's MergeTemplate — no code change).

`bar-effects.json` currently contains three entries; add the new `deliver_coffee`
key at the top level. Key-naming rule (see `.claude/rules/data-files.md`): use
kebab-case keys matching the recipe `id`.

The +100 bar effect on `affection` triggers the `reach_value` win condition once
StatusBarSystem processes the combination_executed signal — so the moment the
player merges coffee with Ju, the scene completes.

The `morning-together` card already exists in `cards.tres` and serves as the
visible "merged result" left on the table when the scene transitions out.

---

## Out of Scope

- The bar definition itself (lives in the scene JSON — Story 003)
- The scene registration (Story 003)
- Scene-transition visuals when the win fires (already handled by STUI)

---

## QA Test Cases

- **AC-1 (brew_coffee exists)**:
  - Given: RecipeDatabase loaded `recipes.tres`
  - When: `RecipeDatabase.get_recipe(&"brew_coffee")` is called
  - Then: returns a `RecipeEntry` with `card_a == &"coffee_machine"`, `card_b == &"coffee_beans"`, `config["result_card"] == &"coffee"`

- **AC-2 (deliver_coffee exists)**:
  - Given: RecipeDatabase loaded
  - When: `RecipeDatabase.get_recipe(&"deliver_coffee")` is called
  - Then: returns a `RecipeEntry` with `card_a == &"coffee"`, `card_b == &"ju"`

- **AC-3 (bar effect wired)**:
  - Given: StatusBarSystem loaded `bar-effects.json`
  - When: the internal `_bar_effects["deliver_coffee"]` key is read
  - Then: the value is `{ "affection": 100 }`

- **AC-4 (cross-validation)**:
  - Given: project launches headlessly
  - When: game boots
  - Then: no `RecipeDatabase: unknown card_a/card_b/result_card` error in output

---

## Test Evidence

**Story Type**: Config/Data
**Required evidence**: smoke-check pass recorded in
`production/qa/smoke-coffee-intro-recipes.md`. No unit test required — the
cross-validation assertions in `RecipeDatabase._load_manifest()` are the
existing guard.

**Status**: [x] production/qa/smoke-coffee-intro-recipes.md — PASS 2026-04-23 (recipe IDs use kebab-case per project convention; result_card uses seed-together)

---

## Dependencies

- Depends on: Story 001 (card IDs must exist before recipes can reference them)
- Unlocks: Story 003 (scene config references bar id "affection")
