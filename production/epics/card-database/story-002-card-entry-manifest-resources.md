# Story 002: CardEntry + CardManifest Resource classes

> **Epic**: card-database
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 7 pts
> **Manifest Version**: 2026-04-21

## Context

**GDD**: `design/gdd/card-database.md`
**Requirement**: `TR-card-database-004` (7 card types enum),
`TR-card-database-009` (persist card definitions as typed Resource manifest
of CardEntry SubResources).
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh
at review time.)*

**ADR Governing Implementation**: ADR-005 — `.tres` everywhere
**ADR Decision Summary**: Every data shape is modelled as a
`class_name X extends Resource` with typed `@export` fields. Classes live in
`res://src/data/`. No methods beyond engine-generated getters. Semantic
validation lives in the consuming autoload, not the Resource class.

**Engine**: Godot 4.3 | **Risk**: LOW
**Engine Notes**: `class_name`, `@export`, typed `Array[T]`, and enums in
Resources are all pre-cutoff and stable. UID-safe `Texture2D` references
require the `.import` file to be generated on first editor open.

**Control Manifest Rules (Foundation layer)**:
- Required: every data shape is `class_name <X> extends Resource` with typed
  `@export` fields; classes live in `res://src/data/`; no methods beyond
  engine-generated getters.
- Forbidden: methods (other than export-generated) on Resource classes;
  untyped `Array` / `Dictionary`; string paths for Texture references.
- Guardrail: `cards.tres` with ~200 entries should cold-load in 20–50 ms.

---

## Acceptance Criteria

*From GDD `design/gdd/card-database.md` and ADR-005 §2, scoped to this story:*

- [ ] `res://src/data/card_entry.gd` exists with
      `class_name CardEntry extends Resource`
- [ ] `CardEntry` declares an `enum CardType { PERSON, PLACE, FEELING,
      OBJECT, MOMENT, INSIDE_JOKE, SEED }` (exactly 7 values)
- [ ] `CardEntry` has typed `@export` fields matching ADR-005 §2:
      `id: StringName`, `display_name: String`, `flavor_text: String = ""`,
      `art: Texture2D`, `type: CardType`, `scene_id: StringName`,
      `tags: PackedStringArray`
- [ ] `res://src/data/card_manifest.gd` exists with
      `class_name CardManifest extends Resource` and
      `@export var entries: Array[CardEntry]`
- [ ] Instantiating `CardEntry.new()` returns a Resource with all fields at
      their declared defaults (`flavor_text == ""`, `tags == []`,
      `type == CardType.PERSON`, etc.)
- [ ] A hand-authored `.tres` file using these classes loads via
      `ResourceLoader.load(...) as CardManifest` without errors
- [ ] All 7 card types are representable (acceptance criterion from GDD)

---

## Implementation Notes

*Derived from ADR-005 §2:*

1. `res://src/data/card_entry.gd`:
   ```gdscript
   class_name CardEntry extends Resource

   enum CardType { PERSON, PLACE, FEELING, OBJECT, MOMENT, INSIDE_JOKE, SEED }

   @export var id: StringName
   @export var display_name: String
   @export var flavor_text: String = ""
   @export var art: Texture2D
   @export var type: CardType
   @export var scene_id: StringName
   @export var tags: PackedStringArray
   ```
2. `res://src/data/card_manifest.gd`:
   ```gdscript
   class_name CardManifest extends Resource

   @export var entries: Array[CardEntry]
   ```
3. Do not add methods (getters, setters, validators). Validation belongs to
   `CardDatabase._ready()` per ADR-005 §6 and Story 004.
4. `art: Texture2D` gives UID-safe drag-drop in the Inspector; kebab-case
   card IDs live in `id: StringName` (uniqueness enforced later, not here).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 003: autoload registration and manifest loading
- Story 004: uniqueness / display_name / orphan-scene validation
- Story 005: public `get_card(id)` / `get_all()` API
- Story 006: missing-art detection and placeholder warning
- Story 007: seed `cards.tres` manifest authoring

---

## QA Test Cases

*For this Logic story — automated test specs:*

- **AC-1 (CardEntry class exists and matches schema)**:
  - Given: a test script
  - When: it reads `CardEntry`'s property list via
    `ClassDB`-equivalent reflection (`CardEntry.new().get_property_list()`)
  - Then: properties `id`, `display_name`, `flavor_text`, `art`, `type`,
    `scene_id`, `tags` are all present with the expected types
  - Edge cases: missing field → fail; wrong type → fail; extra field
    (warn but pass)

- **AC-2 (CardType enum has exactly 7 values)**:
  - Given: `CardEntry.CardType`
  - When: the test reads `CardEntry.CardType.values()`
  - Then: returns an array of length 7 containing PERSON, PLACE, FEELING,
    OBJECT, MOMENT, INSIDE_JOKE, SEED in declaration order
  - Edge cases: 6 values (fail), 8 values (fail), reordered (fail)

- **AC-3 (defaults on CardEntry.new())**:
  - Given: `var e := CardEntry.new()`
  - When: the test reads each field
  - Then: `flavor_text == ""`; `tags == PackedStringArray()`;
    `type == CardEntry.CardType.PERSON` (first enum value, value 0);
    `id`, `display_name`, `scene_id` are empty StringName; `art` is null
  - Edge cases: any non-default value on `.new()` → fail

- **AC-4 (CardManifest wraps Array[CardEntry])**:
  - Given: `var m := CardManifest.new()`
  - When: the test appends a `CardEntry.new()` to `m.entries` and reads back
  - Then: `m.entries.size() == 1`; `m.entries[0] is CardEntry == true`
  - Edge cases: appending a non-CardEntry should fail typed-array enforcement

- **AC-5 (round-trip via ResourceLoader)**:
  - Given: a hand-authored fixture `tests/fixtures/card_database/cards_minimal.tres`
    containing one CardEntry SubResource
  - When: `ResourceLoader.load("res://tests/fixtures/card_database/cards_minimal.tres") as CardManifest`
  - Then: returns a non-null CardManifest with 1 entry whose fields match
    the fixture
  - Edge cases: cast to wrong type returns null; missing file logs error

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/card_database/card_entry_test.gd`
(gdUnit4) — must exist and pass.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (EventBus must exist so autoload order is valid,
  though CardEntry/CardManifest themselves don't touch EventBus)
- Unlocks: Story 003 (CardDatabase autoload loads `cards.tres` as CardManifest)

---

## Completion Notes

**Completed**: 2026-04-22
**Criteria**: 7/7 passing (0 deferred)
**Files created**:
- `src/data/card_entry.gd`
- `src/data/card_manifest.gd`
- `tests/unit/card_database/card_entry_test.gd` (22 gdUnit4 test functions)
- `tests/fixtures/card_database/cards_minimal.tres`
**Deviations**: ADVISORY — test fixture content drifted from approved draft (`rainy-afternoon`/MOMENT → `test_seed_001`/SEED); functionally equivalent, no spec violation
**Test Evidence**: Logic — `tests/unit/card_database/card_entry_test.gd` (22 tests, covers all 5 QA test cases)
**Code Review**: Complete (lean-mode inline review) — verdict APPROVED WITH SUGGESTIONS
**Lean gates skipped**: QL-TEST-COVERAGE, LP-CODE-REVIEW (per `production/review-mode.txt` default)
