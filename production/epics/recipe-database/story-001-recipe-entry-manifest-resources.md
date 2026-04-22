# Story 001: RecipeEntry + RecipeManifest Resource classes

> **Epic**: recipe-database
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-04-21

## Context

**GDD**: `design/gdd/recipe-database.md`
**Requirement**: `TR-recipe-database-003` (4 template enum with
template-specific `config` schema), `TR-recipe-database-010` (typed Resource
manifest of RecipeEntry SubResources).

**ADR Governing Implementation**: ADR-005 — `.tres` everywhere, §2 (data
shape classes) and §8 (Dictionary exception for genuinely opaque data)
**ADR Decision Summary**: RecipeEntry is a `class_name RecipeEntry extends
Resource`. `config: Dictionary` is the documented exception — the shape is
template-specific and owned by the Interaction Template Framework. All
other fields are typed.

**Engine**: Godot 4.3 | **Risk**: LOW
**Engine Notes**: `class_name`, `@export` for Dictionary, typed `Array[T]`
are pre-cutoff.

**Control Manifest Rules (Foundation layer)**:
- Required: every data shape is `class_name <X> extends Resource` with
  typed `@export`; classes live in `res://src/data/`; no methods beyond
  engine-generated getters.
- Forbidden: methods on Resource classes; untyped Array; JSON anywhere
  under `res://assets/data/`.
- Guardrail: manifest cold-load (≈ 60 entries for MVP recipes.tres)
  completes in ≤ 15 ms.

---

## Acceptance Criteria

*From GDD "File Format and Schema" section and ADR-005 §2/§8:*

- [ ] `res://src/data/recipe_entry.gd` exists with
      `class_name RecipeEntry extends Resource`
- [ ] `RecipeEntry` has typed `@export` fields:
      `id: StringName`, `card_a: StringName`, `card_b: StringName`,
      `template: StringName`, `scene_id: StringName = &"global"`,
      `config: Dictionary`
- [ ] `res://src/data/recipe_manifest.gd` exists with
      `class_name RecipeManifest extends Resource` and
      `@export var entries: Array[RecipeEntry]`
- [ ] `RecipeEntry.new()` returns a Resource with all fields at declared
      defaults (`id`, `card_a`, `card_b`, `template` as empty StringName;
      `scene_id == &"global"`; `config == {}`)
- [ ] A hand-authored `.tres` using these classes loads via
      `ResourceLoader.load(...) as RecipeManifest` without errors
- [ ] All 4 template values (`additive`, `merge`, `animate`, `generator`)
      round-trip through the `template: StringName` field — the 4-template
      enum lives as string values, NOT a GDScript `enum`, because ADR-005
      §2 code sample uses `StringName` for extensibility

---

## Implementation Notes

*Derived from ADR-005 §2 (code sample for RecipeEntry) and §8:*

1. `res://src/data/recipe_entry.gd`:
   ```gdscript
   class_name RecipeEntry extends Resource

   @export var id: StringName
   @export var card_a: StringName
   @export var card_b: StringName
   @export var template: StringName          # "additive" | "merge" | "animate" | "generator"
   @export var scene_id: StringName = &"global"
   @export var config: Dictionary            # template-specific; shape owned by ITF
   ```
2. `res://src/data/recipe_manifest.gd`:
   ```gdscript
   class_name RecipeManifest extends Resource

   @export var entries: Array[RecipeEntry]
   ```
3. Do not declare a GDScript `enum Template`. Per ADR-005 §2 the template
   field is `StringName`. Canonical string values (lowercase) are
   `additive`, `merge`, `animate`, `generator`. The 4 valid values are
   asserted at load time by RecipeDatabase validation (covered in a later
   story); the Resource class itself stays schema-light.
4. `config: Dictionary` is intentionally untyped. Validation of
   template-specific keys (`spawns` for additive, `result_card` for merge,
   `motion`/`speed`/`target`/`duration_sec` for animate, `generates`/
   `interval_sec`/`max_count`/`generator_card` for generator) belongs in
   RecipeDatabase or the ITF — not here.
5. `scene_id` defaults to `&"global"` so hand-authored `.tres` entries
   without a set scene_id automatically fall into the global pool.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: RecipeDatabase autoload registration and load
- Story 003: cross-validation of card_a/card_b/result ids against CardDatabase
- Story 004: duplicate-rule detection
- Story 005: generator `interval_sec` clamp
- Story 006: public `lookup(card_a, card_b)` API
- Story 007: seed `recipes.tres` authoring

---

## QA Test Cases

*For this Logic story — automated test specs:*

- **AC-1 (RecipeEntry class and fields)**:
  - Given: a test script
  - When: it reads `RecipeEntry.new().get_property_list()`
  - Then: properties `id`, `card_a`, `card_b`, `template`, `scene_id`,
    `config` are present with the expected types
  - Edge cases: missing field (fail); wrong type (fail); extra field (warn)

- **AC-2 (defaults on RecipeEntry.new())**:
  - Given: `var r := RecipeEntry.new()`
  - When: the test reads each field
  - Then: `id`, `card_a`, `card_b`, `template` are empty StringName;
    `scene_id == &"global"`; `config == {}`
  - Edge cases: any non-default → fail

- **AC-3 (RecipeManifest wraps Array[RecipeEntry])**:
  - Given: `var m := RecipeManifest.new()`
  - When: the test appends a RecipeEntry and reads back
  - Then: `m.entries.size() == 1`; element is a RecipeEntry
  - Edge cases: typed-array enforcement rejects non-RecipeEntry appends

- **AC-4 (round-trip via ResourceLoader for each of 4 templates)**:
  - Given: four hand-authored fixtures under
    `tests/fixtures/recipe_database/` — one per template (additive,
    merge, animate, generator) — each with a populated `config`
    Dictionary matching the GDD Template Configurations section
  - When: `ResourceLoader.load(path) as RecipeManifest`
  - Then: returns a non-null RecipeManifest with 1 entry whose fields
    match the fixture; `config` Dictionary keys are preserved
  - Edge cases: cast to wrong type returns null; loading a truncated
    .tres file returns null

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/recipe_database/recipe_entry_test.gd`
(gdUnit4) — must exist and pass.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: card-database Story 001 (EventBus autoload must exist),
  card-database Story 002 (CardEntry/CardManifest classes — not a hard
  dep, but recipe validation downstream refers to cards, so authoring
  order is: CardEntry → RecipeEntry)
- Unlocks: Story 002 (RecipeDatabase autoload needs these classes)
