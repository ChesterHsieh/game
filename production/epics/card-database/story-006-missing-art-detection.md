# Story 006: Missing-art detection + placeholder warning

> **Epic**: card-database
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-04-21

## Context

**GDD**: `design/gdd/card-database.md`
**Requirement**: `TR-card-database-007` — reference card art via
`res://assets/cards/*.png` paths; missing asset falls back to placeholder
with warning.

**ADR Governing Implementation**: ADR-005 — `.tres` everywhere, §2 (typed
Texture2D export)
**ADR Decision Summary**: `CardEntry.art` is a `Texture2D` `@export` (UID-safe
across asset moves). A missing Texture at load time manifests as
`art == null`. Detection + warning is CardDatabase's responsibility; the
actual placeholder rendering is CardVisual's responsibility (separate
epic, Presentation layer).

**Engine**: Godot 4.3 | **Risk**: LOW
**Engine Notes**: Godot auto-generates `.import` metadata for Texture2D
references. If the source PNG is missing at project load, the `@export`
resolves to null. `push_warning` captures this without crashing.

**Control Manifest Rules (Foundation layer)**:
- Required: semantic validation runs in the consuming autoload's `_ready()`.
- Forbidden: assuming texture paths exist (will null-silently on asset
  moves if we used a `String` path instead of `Texture2D` — ADR-005 §2
  specifically chose Texture2D to surface this).
- Guardrail: missing-art check is O(n) over entries; runs once at startup.

---

## Acceptance Criteria

*From GDD `design/gdd/card-database.md` and GDD Edge Case "Missing art asset":*

- [ ] CardDatabase detects entries where `art == null` during `_ready()`
      and logs a `push_warning` message naming the card id
- [ ] The card remains in `_entries` and is returned by `get_card(id)` —
      missing art does not invalidate the entry (GDD: "Card Visual renders
      a fallback placeholder image. Log a warning naming the card ID.")
- [ ] The warning message includes the literal card `id`, so Chester can
      grep logs for the offending entry
- [ ] Missing-art detection runs once, during `_ready()`, after load +
      validation (Story 003 + 004); it does not repeat per lookup
- [ ] A fully valid fixture (all entries have non-null `art`) produces
      zero missing-art warnings
- [ ] CardVisual placeholder rendering is explicitly out of scope — this
      story only covers detection and warning emission

---

## Implementation Notes

*Derived from ADR-005 §2 and GDD Edge Cases:*

1. Extend the `_validate_entries()` loop in `res://src/core/card_database.gd`
   (added in Story 004) with one additional check:
   ```gdscript
   func _validate_entries() -> void:
       var seen := {}
       for e: CardEntry in _entries:
           # ... Story 004 checks ...

           if e.art == null:
               push_warning("CardDatabase: missing art on card %s" % e.id)
   ```
2. Do not emit an EventBus signal. Card Visual will null-check `art` at
   render time and substitute its placeholder; no cross-autoload handshake
   is needed.
3. Do not attempt to load a placeholder Texture here. Placeholder art is
   visual presentation — that belongs in the Card Visual epic, not here.
4. If the fixture `.tres` has a `.import` file but the source PNG was
   deleted, Godot will resolve the `@export var art` to null at load —
   that IS the condition this check catches. No additional `FileAccess`
   probing is needed (and would violate ADR-005 §9).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- CardVisual placeholder rendering (belongs to a future Presentation epic)
- Auto-generating a placeholder Texture in-memory (CardVisual concern)
- Fixing the missing asset (that is an authoring task, not a code task)
- Story 007: authoring the seed `cards.tres` with real art files

---

## QA Test Cases

*For this Logic story — automated test specs:*

- **AC-1 (missing art triggers warning naming card)**:
  - Given: a fixture manifest with one CardEntry whose `art` field is
    null but other fields are valid (id = "no-art-card")
  - When: CardDatabase `_ready()` runs
  - Then: `push_warning` captures a message containing the literal text
    `no-art-card`; no assertion fires
  - Edge cases: multiple entries missing art → one warning per entry

- **AC-2 (card remains in database despite missing art)**:
  - Given: same fixture as AC-1
  - When: `CardDatabase.get_card(&"no-art-card")` after `_ready()`
  - Then: returns a non-null CardEntry; its `art` field is null
  - Edge cases: `get_all()` still includes the art-less card in count

- **AC-3 (valid fixture produces zero missing-art warnings)**:
  - Given: a fixture manifest with 3 entries whose `art` fields all point
    to valid Texture2D Resources (fixture textures under
    `tests/fixtures/card_database/art/`)
  - When: CardDatabase `_ready()` runs
  - Then: zero `push_warning` calls mentioning "missing art"
  - Edge cases: other warnings (e.g. orphan scene_id) may still fire —
    this test filters by "missing art" substring

- **AC-4 (detection runs once, not per lookup)**:
  - Given: CardDatabase loaded with one art-less entry
  - When: the test captures warning count after `_ready()`, then calls
    `get_card(&"no-art-card")` 5 times, then re-reads warning count
  - Then: warning count is 1 after `_ready()` and still 1 after the 5
    lookups (detection is not re-running per call)

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/card_database/missing_art_test.gd`
(gdUnit4) — must exist and pass.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 004 (`_validate_entries()` is the host method where
  this check lives)
- Unlocks: future CardVisual stories can assume "missing art" warnings
  already fire at startup, and can focus on render-time fallback behavior
