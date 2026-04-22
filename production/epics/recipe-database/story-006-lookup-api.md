# Story 006: Public lookup API — symmetric pair + scene precedence

> **Epic**: recipe-database
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-04-21

## Context

**GDD**: `design/gdd/recipe-database.md`
**Requirement**: `TR-recipe-database-002` (symmetric lookup returning recipe
or null), `TR-recipe-database-006` (scene-scoped precedence over global),
`TR-recipe-database-008` (null on unmatched pair is non-error),
`TR-recipe-database-009` (stateless — no runtime writes).

**ADR Governing Implementation**: ADR-005 — `.tres` everywhere, §6
validation strategy; ADR-003 — direct autoload calls for read-only queries
**ADR Decision Summary**: `RecipeDatabase.lookup(card_a, card_b, scene_id)`
is a read-only query (ADR-003: "direct autoload calls for read-only queries").
The lookup index is built once in `_ready()` after all validation passes.
Pair order is normalised (sort alphabetically) so callers need not worry about
order. Scene-scoped rules take precedence over global rules.

**Engine**: Godot 4.3 | **Risk**: LOW
**Engine Notes**: Dictionary keyed by String, nested Dictionary for
scene-vs-global. All pre-cutoff. O(1) lookup per query.

**Control Manifest Rules (Foundation layer)**:
- Required: direct autoload calls for read-only queries; EventBus for events.
- Forbidden: runtime writes to `_entries` or the lookup index.
- Guardrail: O(1) per lookup; index build O(n) where n ≈ 60–300.

---

## Acceptance Criteria

*From GDD `design/gdd/recipe-database.md`:*

- [ ] `RecipeDatabase.lookup(card_a: StringName, card_b: StringName, scene_id: StringName) -> RecipeEntry`
      is the public API
- [ ] Lookup is symmetric: `lookup(&"a", &"b", scene)` returns the same
      result as `lookup(&"b", &"a", scene)`
- [ ] If a scene-scoped rule exists for the pair in the given `scene_id`,
      it is returned (scene takes precedence)
- [ ] If no scene-scoped rule exists but a global rule exists, the global
      rule is returned
- [ ] If no rule exists at all, `null` is returned — no error, no
      `push_error` (GDD: "Not an error — this is expected for incompatible
      pairs")
- [ ] The database is stateless: `lookup()` performs no writes, emits no
      signals, and has no side effects
- [ ] The internal index is built once in `_ready()` AFTER all validation
      steps (Stories 003–005)
- [ ] `lookup()` is O(1) — uses a pre-built Dictionary, not a linear scan
- [ ] Multiple calls with the same arguments return the same RecipeEntry
      instance (identity, not copy)

---

## Implementation Notes

*Derived from ADR-005 §6 and GDD Detailed Design:*

1. Build the lookup index in `_ready()` after all validation:
   ```gdscript
   # Key: "lo|hi" (normalised pair)
   # Value: Dictionary { scene_id: StringName → RecipeEntry }
   var _index: Dictionary = {}

   func _build_index() -> void:
       for r: RecipeEntry in _entries:
           var pair_key: String = _pair_key(r.card_a, r.card_b)
           if not _index.has(pair_key):
               _index[pair_key] = {}
           _index[pair_key][r.scene_id] = r

   static func _pair_key(a: StringName, b: StringName) -> String:
       var sa: String = String(a)
       var sb: String = String(b)
       var lo: String = sa if sa < sb else sb
       var hi: String = sb if sa < sb else sa
       return "%s|%s" % [lo, hi]
   ```
2. Public lookup with scene precedence:
   ```gdscript
   func lookup(card_a: StringName, card_b: StringName, scene_id: StringName) -> RecipeEntry:
       var pair_key: String = _pair_key(card_a, card_b)
       var scenes: Dictionary = _index.get(pair_key, {})
       if scenes.has(scene_id):
           return scenes[scene_id]
       if scenes.has(&"global"):
           return scenes[&"global"]
       return null
   ```
3. No `push_error` on miss — null-on-miss is by design. Callers (Card Engine)
   treat null as "incompatible pair → push-away".
4. The pair normalisation in `_pair_key` is the same sort used in Story 004's
   `_dup_key`, but without `scene_id` — the index is keyed by pair only,
   with scene as a nested sub-key. This makes the precedence check clean.
5. Call `_build_index()` as the LAST step in `_ready()`, after all validation
   and clamping. The index is the final artefact.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 003: card-ref validation (runs before index build)
- Story 004: duplicate-rule detection (runs before index build)
- Story 005: interval clamp (runs before index build)
- Story 007: seed recipes.tres
- `get_all()` API — not specified in the GDD; can be added if needed later
- Query by template type or scene — not specified

---

## QA Test Cases

*For this Logic story — automated test specs:*

- **AC-1 (symmetric lookup returns same result)**:
  - Given: a recipe with `card_a = &"cat"`, `card_b = &"dog"`,
    `scene_id = &"scene-01"`, `template = &"merge"`
  - When: `lookup(&"cat", &"dog", &"scene-01")` and
    `lookup(&"dog", &"cat", &"scene-01")`
  - Then: both return the same RecipeEntry instance

- **AC-2 (scene-scoped rule takes precedence over global)**:
  - Given: a global recipe `r-global` with `scene_id = &"global"` and
    a scene recipe `r-scene` with `scene_id = &"scene-01"`, same pair
  - When: `lookup(card_a, card_b, &"scene-01")`
  - Then: returns `r-scene` (not `r-global`)
  - Edge cases: `lookup(card_a, card_b, &"scene-02")` returns `r-global`
    (no scene-02 rule, falls through to global)

- **AC-3 (global rule returned when no scene-scoped rule)**:
  - Given: a global recipe for `(card_a, card_b)` only — no scene-scoped
    rules for this pair
  - When: `lookup(card_a, card_b, &"scene-01")`
  - Then: returns the global recipe

- **AC-4 (null on unmatched pair — no error)**:
  - Given: no recipe for the pair `(&"x", &"y")`
  - When: `lookup(&"x", &"y", &"scene-01")`
  - Then: returns `null`; no `push_error` emitted

- **AC-5 (identity: repeated calls return same instance)**:
  - Given: a recipe exists for a pair
  - When: `lookup()` is called twice with the same arguments
  - Then: `result_1 == result_2` (same object reference)

- **AC-6 (stateless: lookup has no side effects)**:
  - Given: a loaded RecipeDatabase
  - When: `lookup()` is called 100 times for the same pair
  - Then: no signals emitted, no `_entries` or `_index` modified

- **AC-7 (O(1) lookup — index is pre-built, not linear scan)**:
  - Given: a fixture with 100 recipes
  - When: `lookup()` is called
  - Then: completes in < 1 ms (verify via `Time.get_ticks_usec` or
    structural inspection that `_index` is a Dictionary)

- **AC-8 (index built after validation)**:
  - Given: a fixture with valid recipes
  - When: `_ready()` runs
  - Then: `_index` is populated and `lookup()` returns correct results;
    validation steps (stories 003–005) ran before index build

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/recipe_database/lookup_api_test.gd`
(gdUnit4) — must exist and pass.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002 (autoload), Story 003 (card-ref validation),
  Story 004 (duplicate detection), Story 005 (interval clamp)
- Unlocks: Story 007 (seed data), and downstream consumers
  (Interaction Template Framework epic)
