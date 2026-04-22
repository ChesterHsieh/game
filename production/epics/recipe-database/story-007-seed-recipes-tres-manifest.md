# Story 007: Seed recipes.tres manifest — MVP scene-01 recipe set

> **Epic**: recipe-database
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Config/Data
> **Manifest Version**: 2026-04-21

## Context

**GDD**: `design/gdd/recipe-database.md`
**Requirement**: `TR-recipe-database-012` — scale to ~150–300 total recipes,
~30–60 per scene. This story seeds the initial set for MVP.

**ADR Governing Implementation**: ADR-005 — `.tres` everywhere, §2 and §4
**ADR Decision Summary**: `res://assets/data/recipes.tres` is a
`RecipeManifest` Resource containing `RecipeEntry` SubResources. Authored by
hand in the Godot inspector or text editor. All 4 template types must be
exercised at least once.

**Engine**: Godot 4.3 | **Risk**: LOW
**Engine Notes**: `.tres` SubResource authoring is stable in 4.3. The
manifest file size for ~30 entries is negligible.

**Control Manifest Rules (Foundation layer)**:
- Required: all persistent data as `.tres` Resource files.
- Forbidden: JSON data files under `res://assets/data/`.
- Guardrail: cold load of `recipes.tres` (≈ 60 entries) 10–15 ms.

---

## Acceptance Criteria

*From GDD `design/gdd/recipe-database.md`:*

- [ ] `res://assets/data/recipes.tres` exists as a valid `RecipeManifest`
      resource
- [ ] Contains at least one recipe per template type (additive, merge,
      animate, generator) — all 4 templates exercised
- [ ] Contains at least 10 recipes total for the MVP scene (`scene-01`)
- [ ] At least 2 recipes are `scene_id = &"global"` (cross-scene
      combinations)
- [ ] Every `card_a`, `card_b`, and result card ID references a card that
      exists in `res://assets/data/cards.tres` (card-database Story 007)
- [ ] Every recipe `id` is unique and follows kebab-case naming
- [ ] Generator recipes have `interval_sec >= 0.5`
- [ ] RecipeDatabase loads the manifest without assertion failures
      (passes all validation from Stories 003–005)
- [ ] The file round-trips cleanly: load → save → load produces identical
      data (no Godot serialisation artefacts)

---

## Implementation Notes

*Derived from ADR-005 §4 and GDD Template Configurations:*

1. Author `res://assets/data/recipes.tres` with the Godot inspector or as
   a hand-written `.tres` text file. Use SubResource syntax:
   ```
   [gd_resource type="Resource" script_class="RecipeManifest" ...]

   [sub_resource type="Resource" id="RecipeEntry_1"]
   script = ExtResource("recipe_entry_script")
   id = &"chester-rainy-afternoon"
   card_a = &"chester"
   card_b = &"rainy-afternoon"
   template = &"merge"
   scene_id = &"scene-01"
   config = { "result_card": &"cozy-reading-session" }
   ```
2. Include representative recipes:
   - **Additive**: both cards stay, new card spawns — e.g. combining
     `park-bench` + `sunset` spawns `shared-moment`
   - **Merge**: both cards consumed, one result — e.g. `chester` +
     `rainy-afternoon` → `cozy-reading-session`
   - **Animate**: cards begin moving — e.g. `lantern` + `night-sky` →
     drift motion
   - **Generator**: one card periodically spawns another — e.g.
     `coffee-machine` + `morning` → generates `coffee-cup` every 5s
3. Card IDs used here MUST match entries in card-database Story 007's
   `cards.tres`. Coordinate content to ensure cross-validation passes.
4. Recipe IDs follow kebab-case: `[card-a-slug]-[card-b-slug]` or
   `[descriptive-name]`. Must be unique across the entire manifest.
5. Include at least 2 global recipes to exercise the scene-precedence
   lookup path in Story 006.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: RecipeEntry/RecipeManifest classes (prerequisite)
- Story 002: RecipeDatabase autoload (loads this file)
- Stories 003–006: validation and lookup (consume this file)
- Full content authoring (all ~150–300 recipes) — this is the seed set only;
  additional recipes added during Content Production phase
- Card art assets — placeholder PNGs are acceptable

---

## QA Test Cases

*For this Config/Data story — smoke check:*

- **SC-1 (manifest loads without errors)**:
  - Given: `res://assets/data/recipes.tres` exists
  - When: RecipeDatabase `_ready()` runs (game launch or test runner)
  - Then: no assertion failures, no errors in output log

- **SC-2 (all 4 templates present)**:
  - Given: loaded manifest
  - When: inspecting `_entries`
  - Then: at least one recipe per template value (additive, merge,
    animate, generator)

- **SC-3 (all card refs valid)**:
  - Given: loaded manifest with card-database also loaded
  - When: Story 003 cross-validation runs
  - Then: zero assertion failures (all card_a/card_b/result refs exist)

- **SC-4 (no duplicates)**:
  - Given: loaded manifest
  - When: Story 004 duplicate detection runs
  - Then: zero assertion failures

- **SC-5 (generator intervals valid)**:
  - Given: loaded manifest
  - When: Story 005 interval clamp runs
  - Then: zero clamp warnings (all generators have interval_sec >= 0.5)

- **SC-6 (kebab-case IDs)**:
  - Given: loaded manifest
  - When: inspecting each recipe id
  - Then: all ids match `/^[a-z0-9]+(-[a-z0-9]+)*$/` pattern

---

## Test Evidence

**Story Type**: Config/Data
**Required evidence**: `production/qa/smoke-recipes-tres-[date].md`
(smoke check pass) — must exist.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (classes), Story 002 (autoload), Stories 003–006
  (validation + lookup); card-database Story 007 (cards.tres must exist
  with matching card IDs)
- Unlocks: Interaction Template Framework epic (needs recipes to test
  template execution)
