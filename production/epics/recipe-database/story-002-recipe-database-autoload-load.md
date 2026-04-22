# Story 002: RecipeDatabase autoload — manifest load + typed cast

> **Epic**: recipe-database
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Integration
> **Manifest Version**: 2026-04-21

## Context

**GDD**: `design/gdd/recipe-database.md`
**Requirement**: `TR-recipe-database-001` (load at game start, hold for
session), `TR-recipe-database-010` (ResourceLoader + as RecipeManifest
cast), `TR-recipe-database-011` (load completes before any combination
attempt).

**ADR Governing Implementation**: ADR-005 — `.tres` everywhere, §4 loading
pattern
**ADR Decision Summary**: Same structural pattern as CardDatabase —
`ResourceLoader.load("res://assets/data/recipes.tres") as RecipeManifest`,
null-check assert, store entries, then validate.

**Engine**: Godot 4.3 | **Risk**: LOW
**Engine Notes**: RecipeDatabase sits at autoload position #3 (after
EventBus and CardDatabase) per the canonical order in ADR-004 §1 and the
Control Manifest. Load order matters because later stories cross-validate
recipe card references against CardDatabase.

**Control Manifest Rules (Foundation layer)**:
- Required: `ResourceLoader.load` + `as <CustomClass>` cast + null check;
  autoload order `EventBus → CardDatabase → RecipeDatabase → ...`; every
  autoload sets `process_mode = PROCESS_MODE_ALWAYS`.
- Forbidden: `FileAccess.open + JSON.parse_string`; bare ResourceLoader
  load without cast; reordering autoloads.
- Guardrail: cold load of `recipes.tres` (≈ 60 entries) 10–15 ms.

---

## Acceptance Criteria

*From GDD `design/gdd/recipe-database.md`:*

- [ ] `res://src/core/recipe_database.gd` exists with `extends Node`
- [ ] Registered as autoload #3 in `project.godot`, immediately after
      `CardDatabase`, with `process_mode = PROCESS_MODE_ALWAYS`
- [ ] `_ready()` calls
      `ResourceLoader.load("res://assets/data/recipes.tres") as RecipeManifest`
      and asserts the result is non-null
- [ ] Entries are stored on the autoload instance for session-long access
- [ ] Full load completes inside `_ready()` (no deferred / lazy load)
- [ ] Missing `recipes.tres` fails the assert with a message naming the
      path
- [ ] Wrong-type `.tres` (e.g. a bare Resource) also fails the null-check
      after cast
- [ ] GDD acceptance criterion: "Database loads fully before any card
      combination can be attempted" — satisfied by autoload-order ordering

---

## Implementation Notes

*Derived from ADR-005 §4 and the CardDatabase pattern in card-database Story 003:*

1. `res://src/core/recipe_database.gd`:
   ```gdscript
   class_name RecipeDatabase extends Node

   const MANIFEST_PATH := "res://assets/data/recipes.tres"

   var _entries: Array[RecipeEntry] = []

   func _ready() -> void:
       var raw: Resource = ResourceLoader.load(MANIFEST_PATH)
       var manifest: RecipeManifest = raw as RecipeManifest
       assert(manifest != null,
           "RecipeDatabase: %s is missing or not a RecipeManifest" % MANIFEST_PATH)
       _entries = manifest.entries
       # Story 003 appends cross-validation against CardDatabase here.
       # Story 004 appends duplicate-rule detection.
       # Story 005 appends Generator interval_sec clamp.
       # Story 006 builds the lookup index.
   ```
2. `project.godot` → `[autoload]` section, third line (after EventBus and
   CardDatabase):
   ```
   RecipeDatabase="*res://src/core/recipe_database.gd"
   ```
3. Keep `_ready()` structure parallel to CardDatabase — this deliberate
   symmetry makes the pattern recognisable to reviewers (ADR-005 §4 goal).
4. Do not emit an EventBus signal on load complete. Downstream systems
   (ITF) read via `RecipeDatabase.lookup(...)` directly — autoload-order
   is the ordering guarantee.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: RecipeEntry/RecipeManifest classes (prerequisite)
- Story 003: cross-validation against CardDatabase
- Story 004: duplicate-rule detection
- Story 005: Generator interval clamp
- Story 006: lookup API
- Story 007: seed recipes.tres

---

## QA Test Cases

*For this Integration story — automated test specs:*

- **AC-1 (autoload position #3 with PROCESS_MODE_ALWAYS)**:
  - Given: project running
  - When: test reads `project.godot` `[autoload]` section and queries
    `RecipeDatabase.process_mode`
  - Then: third autoload entry is `RecipeDatabase=...`;
    `process_mode == PROCESS_MODE_ALWAYS`
  - Edge cases: RecipeDatabase before CardDatabase → fail

- **AC-2 (happy-path load from fixture)**:
  - Given: a fixture `recipes.tres` with 3 valid RecipeEntry SubResources
  - When: RecipeDatabase `_ready()` runs
  - Then: `_entries` array has length 3 and each element is non-null
  - Edge cases: empty manifest → load succeeds with empty `_entries`

- **AC-3 (missing file fails assertively)**:
  - Given: no file at `res://assets/data/recipes.tres` (fixture path
    swap via DI)
  - When: RecipeDatabase `_ready()` runs
  - Then: assertion fails with message naming the missing path

- **AC-4 (wrong-type .tres fails)**:
  - Given: a `.tres` at expected path whose root is not a RecipeManifest
  - When: RecipeDatabase `_ready()` runs
  - Then: `as RecipeManifest` yields null, assertion fails

- **AC-5 (load-before-combination ordering)**:
  - Given: RecipeDatabase at #3 and a dummy downstream autoload at #4
  - When: downstream's `_ready()` reads `RecipeDatabase._entries.size()`
  - Then: downstream observes the populated array
  - Edge cases: reordering autoloads → downstream sees empty array

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/recipe_database/manifest_load_test.gd`
(gdUnit4) — must exist and pass.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (RecipeEntry + RecipeManifest classes);
  card-database Story 003 (CardDatabase autoload must be at #2 before
  RecipeDatabase at #3)
- Unlocks: Story 003 (cross-validation extends `_ready()`), Stories 004–006
