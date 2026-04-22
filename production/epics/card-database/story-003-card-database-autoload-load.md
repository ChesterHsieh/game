# Story 003: CardDatabase autoload — manifest load + typed cast

> **Epic**: card-database
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Integration
> **Manifest Version**: 2026-04-21

## Context

**GDD**: `design/gdd/card-database.md`
**Requirement**: `TR-card-database-001` (load at game start, hold for session),
`TR-card-database-009` (ResourceLoader + CardManifest cast),
`TR-card-database-010` (full DB load completes before any card instantiation).

**ADR Governing Implementation**: ADR-005 — `.tres` everywhere, §4 loading
pattern
**ADR Decision Summary**: Every database autoload uses `ResourceLoader.load`
→ `as <CustomClass>` cast → null-check assert → `_validate_entries()`.
Bare null-check on untyped Resource is insufficient (schema-drift defeats it).

**Engine**: Godot 4.3 | **Risk**: LOW
**Engine Notes**: `ResourceLoader.load` and the `as` cast operator are
pre-cutoff; no post-cutoff APIs. Autoloads are initialised in the order
declared in `project.godot`; CardDatabase sits at position #2, right after
EventBus.

**Control Manifest Rules (Foundation layer)**:
- Required: all persistent data uses `.tres` via `ResourceLoader.load`;
  every load is paired with `as <CustomClass>` cast + null check;
  `project.godot` declares 12 autoloads in canonical order (CardDatabase #2);
  every autoload sets `process_mode = PROCESS_MODE_ALWAYS`.
- Forbidden: `FileAccess.open(...) + JSON.parse_string(...)`;
  bare `ResourceLoader.load(...)` without `as <Type>` cast;
  reordering autoloads outside the canonical sequence.
- Guardrail: cold load of `cards.tres` (~200 entries) 20–50 ms, within
  startup budget.

---

## Acceptance Criteria

*From GDD `design/gdd/card-database.md` and ADR-005 §4:*

- [ ] `res://src/core/card_database.gd` exists with `extends Node`
- [ ] Registered as autoload #2 in `project.godot`, immediately after
      `EventBus`, with `process_mode = PROCESS_MODE_ALWAYS`
- [ ] `_ready()` calls
      `ResourceLoader.load("res://assets/data/cards.tres") as CardManifest`
      and asserts the result is non-null
- [ ] Entries are stored on the autoload instance for session-long access
- [ ] Full database load completes inside `_ready()` (no deferred load,
      no lazy-load race conditions — GDD acceptance criterion)
- [ ] Missing `cards.tres` logs a clear error naming the path and fails
      the assert rather than silently starting with zero cards
- [ ] Wrong-type `.tres` (e.g. a Resource that is not a CardManifest)
      also fails the null-check after cast

---

## Implementation Notes

*Derived from ADR-005 §4 and §9 (forbidden-pattern registry):*

1. `res://src/core/card_database.gd`:
   ```gdscript
   class_name CardDatabase extends Node

   const MANIFEST_PATH := "res://assets/data/cards.tres"

   var _entries: Array[CardEntry] = []

   func _ready() -> void:
       var raw: Resource = ResourceLoader.load(MANIFEST_PATH)
       var manifest: CardManifest = raw as CardManifest
       assert(manifest != null,
           "CardDatabase: %s is missing or not a CardManifest" % MANIFEST_PATH)
       _entries = manifest.entries
       # Story 004 appends _validate_entries() here.
   ```
2. `project.godot` → `[autoload]` section (second line):
   ```
   CardDatabase="*res://src/core/card_database.gd"
   ```
3. Do not defer loading to `call_deferred` or `_process`. The GDD
   requirement is that no card can be instantiated before the database is
   fully loaded — `_ready()` completion is the ordering guarantee.
4. The `as CardManifest` cast IS the BLOCKING-1 fix from ADR-005 §5/§9:
   a schema-drifted `.tres` loads as a generic `Resource` and would pass a
   bare null-check. Keep the cast + assert pattern verbatim.
5. Do NOT emit an EventBus signal for "database loaded" at this stage —
   downstream systems read from `CardDatabase` directly for lookups
   (autoload-order ensures they see a populated instance).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: CardEntry / CardManifest class authoring (must be DONE first)
- Story 004: `_validate_entries()` semantic checks (uniqueness, names, scenes)
- Story 005: public `get_card(id)` / `get_all()` API
- Story 006: missing-art detection
- Story 007: seed `cards.tres` authoring (a placeholder fixture is fine here)

---

## QA Test Cases

*For this Integration story — automated test specs:*

- **AC-1 (autoload position #2 with PROCESS_MODE_ALWAYS)**:
  - Given: Godot project is running
  - When: the test reads `project.godot` `[autoload]` section AND queries
    `CardDatabase.process_mode`
  - Then: second autoload entry is `CardDatabase=...`;
    `process_mode == PROCESS_MODE_ALWAYS`
  - Edge cases: CardDatabase before EventBus → fail; wrong process_mode → fail

- **AC-2 (happy-path load from fixture)**:
  - Given: a fixture `cards.tres` exists at the expected path with 3 valid
    CardEntry SubResources
  - When: CardDatabase `_ready()` runs
  - Then: internal `_entries` array has length 3 and each element is a
    non-null CardEntry
  - Edge cases: empty entries array → load succeeds with zero-length
    `_entries` (validation is Story 004's concern)

- **AC-3 (missing file fails assertively)**:
  - Given: no file at `res://assets/data/cards.tres` (test swaps path for
    a non-existent one via dependency injection or fixture override)
  - When: CardDatabase `_ready()` runs
  - Then: the assertion fails with a message naming the missing path
  - Edge cases: path points to directory → same failure; path has typo →
    same failure

- **AC-4 (wrong-type .tres fails after cast)**:
  - Given: a `.tres` at the expected path whose root is a different
    Resource class (e.g. a bare `Resource` or an unrelated `RecipeManifest`)
  - When: CardDatabase `_ready()` runs
  - Then: `as CardManifest` yields null, assertion fails
  - Edge cases: cast to CardManifest of a schema-drifted CardManifest that
    dropped the `entries` field → assertion still fails (defaults to null)

- **AC-5 (load-before-instantiation ordering)**:
  - Given: CardDatabase and a dummy downstream autoload are both registered,
    with the downstream at position #3
  - When: the downstream's `_ready()` queries `CardDatabase._entries.size()`
  - Then: the downstream observes the populated entries array — not an
    empty array from a still-loading database
  - Edge cases: reordering autoloads out of spec → downstream sees empty
    array (this test becomes the regression signal)

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/card_database/manifest_load_test.gd`
(gdUnit4) — must exist and pass.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (EventBus autoload must be #1 before CardDatabase #2);
  Story 002 (CardEntry + CardManifest classes must exist before this
  autoload can cast to them)
- Unlocks: Story 004 (validation extends `_ready()`), Story 005 (lookup API
  reads `_entries`), Story 006 (missing-art detection runs after load)

---

## Completion Notes
**Completed**: 2026-04-22
**Criteria**: 7/7 passing
**Deviations**: None
**Test Evidence**: Integration — `tests/integration/card_database/manifest_load_test.gd` (12 test functions)
**Code Review**: Complete (APPROVED — inline review, lean mode; LP-CODE-REVIEW gate skipped)
**Notes**: First `/dev-story` attempt went off-spec (wrote Story 004/005 methods into `card_database.gd`, wrong test path). Reverted and re-implemented cleanly. Placeholder `assets/data/cards.tres` authored here per Story Out-of-Scope allowance; Story 007 will replace with real seed data.
