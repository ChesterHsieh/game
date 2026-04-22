# Story 005: Public lookup API — get_card(id) + get_all()

> **Epic**: card-database
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-04-21

## Context

**GDD**: `design/gdd/card-database.md`
**Requirement**: `TR-card-database-002` (read-only lookup by `id` returning
full card entry), `TR-card-database-006` (log clear error naming missing id
when lookup requests unknown card; do not crash).

**ADR Governing Implementation**: ADR-005 — `.tres` everywhere, Key
Interfaces section
**ADR Decision Summary**: `CardDatabase` exposes two read-only methods:
`get_card(id: StringName) -> CardEntry` (null on miss) and
`get_all() -> Array[CardEntry]`. Direct autoload calls are reserved for
read-only queries per ADR-003.

**Engine**: Godot 4.3 | **Risk**: LOW
**Engine Notes**: Dictionary lookup by StringName key is O(1) and
pre-cutoff; `push_error` fires in all builds.

**Control Manifest Rules (Foundation layer)**:
- Required: direct autoload calls are reserved for read-only queries
  (`CardDatabase.get_card(id)` is the canonical example);
  EventBus is for events, not queries.
- Forbidden: mutating database state at runtime (no `set_card`, `add_card`,
  `remove_card` methods — those would invite save/load races).
- Guardrail: `get_card(id)` runs in O(1) via a pre-built id→entry index;
  budget ≤ 0.1 ms per call.

---

## Acceptance Criteria

*From GDD `design/gdd/card-database.md`:*

- [ ] `CardDatabase.get_card(id: StringName) -> CardEntry` returns the full
      card entry for a valid id — all fields from the Card Schema table
      (GDD acceptance criterion: "Given a valid card ID, the database
      returns the correct card entry with all fields")
- [ ] `CardDatabase.get_card(id)` for an unknown id logs an error via
      `push_error` naming the missing id and returns `null` — does not
      crash (GDD Edge Case: "Log a clear error naming the missing ID.
      Do not crash silently.")
- [ ] `CardDatabase.get_all() -> Array[CardEntry]` returns the full
      populated entries array in stable order
- [ ] Both methods are safe to call from any autoload position #2+ once
      `_ready()` has completed (autoload ordering guarantees load-before-use
      — see Story 003 AC-5)
- [ ] The returned `CardEntry` is the in-memory instance, not a deep copy;
      callers must treat it as read-only (documented in the method's doc
      comment; enforcement is convention, not runtime)
- [ ] Repeated `get_card(id)` calls for the same id return the same
      instance (identity, not value equality)

---

## Implementation Notes

*Derived from ADR-005 Key Interfaces and ADR-003 direct-query pattern:*

1. Extend `res://src/core/card_database.gd`:
   ```gdscript
   var _index: Dictionary = {}   # StringName → CardEntry

   func _ready() -> void:
       # Story 003 load + Story 004 _validate_entries(); then:
       _build_index()

   func _build_index() -> void:
       _index.clear()
       for e: CardEntry in _entries:
           _index[e.id] = e

   ## Returns the CardEntry for [param id], or null if no card with that id
   ## exists. Logs an error via push_error naming the missing id.
   ## Callers must treat the returned entry as read-only.
   func get_card(id: StringName) -> CardEntry:
       var entry: CardEntry = _index.get(id, null)
       if entry == null:
           push_error("CardDatabase: no card with id '%s'" % id)
       return entry

   ## Returns the full populated entries array. Callers must not mutate.
   func get_all() -> Array[CardEntry]:
       return _entries
   ```
2. Build the id→entry index once, at the end of `_ready()`, after validation
   has asserted uniqueness. This guarantees the index matches the validated
   truth.
3. Do not expose `_entries` or `_index` — lookup must go through the two
   public methods so future refactors (e.g. splitting into per-scene
   manifests per ADR-005 §3 rollback) remain possible.
4. Do not emit a `card_not_found` signal; logging is sufficient for MVP.
   If downstream systems need to react to missing ids, add an EventBus
   signal in a follow-up story (YAGNI until a consumer asks for it).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002, 003, 004: prerequisite infrastructure
- Story 006: `art` field null-check / placeholder warning (separate concern
  even though it touches CardEntry)
- Future: filter-by-type or filter-by-scene convenience methods. Add if a
  consumer needs them; do not pre-build.

---

## QA Test Cases

*For this Logic story — automated test specs:*

- **AC-1 (get_card returns full CardEntry for valid id)**:
  - Given: CardDatabase has loaded a fixture with a card
    `id = "rainy-afternoon"`, `display_name = "Rainy afternoon"`,
    `type = CardType.MOMENT`, `scene_id = "global"`
  - When: `CardDatabase.get_card(&"rainy-afternoon")`
  - Then: returns a non-null CardEntry; all six public fields match the
    fixture values exactly
  - Edge cases: StringName vs String mismatch — test uses `&"..."`;
    passing a `String` should still work via implicit conversion

- **AC-2 (get_card returns null + push_error on miss)**:
  - Given: CardDatabase has loaded a fixture that does NOT contain
    `id = "nonexistent-card"`
  - When: `CardDatabase.get_card(&"nonexistent-card")`
  - Then: returns null; `push_error` captures a message containing the
    literal text `nonexistent-card`; no assertion fires (game keeps running)
  - Edge cases: empty StringName `&""` → null + error (not a valid id);
    case-mismatch `&"Rainy-Afternoon"` vs stored `&"rainy-afternoon"` →
    null + error (lookup is case-sensitive)

- **AC-3 (get_all returns full populated array)**:
  - Given: CardDatabase has loaded a fixture with 3 entries
  - When: `CardDatabase.get_all()`
  - Then: returns an Array[CardEntry] of length 3 whose elements are the
    three fixture entries in declaration order
  - Edge cases: empty manifest → returns empty array (no null)

- **AC-4 (identity, not deep copy)**:
  - Given: `var a := CardDatabase.get_card(&"card-1")`;
    `var b := CardDatabase.get_card(&"card-1")`
  - When: the test compares `a == b` and `a.get_instance_id() == b.get_instance_id()`
  - Then: both comparisons are true (same instance)
  - Edge cases: calling `get_all()[0]` vs `get_card(get_all()[0].id)` —
    should also be identical instance

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/card_database/lookup_api_test.gd`
(gdUnit4) — must exist and pass.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 003 (autoload + `_entries`), Story 004 (validation —
  index must only be built after uniqueness is asserted)
- Unlocks: Story 006 (missing-art detection may reuse `get_all()`); all
  downstream systems (Recipe Database, Card Engine, Card Visual, Card
  Spawning, Save/Progress) that resolve cards by id
