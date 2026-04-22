# Story 003: Cross-validation against CardDatabase — card_a / card_b / result IDs

> **Epic**: recipe-database
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Integration
> **Manifest Version**: 2026-04-21

## Context

**GDD**: `design/gdd/recipe-database.md`
**Requirement**: `TR-recipe-database-004` — validate all `card_a` /
`card_b` / result IDs exist in Card Database at load time; fail loudly on
unknown ID.

**ADR Governing Implementation**: ADR-005 — `.tres` everywhere, §6
validation strategy, GDD Requirements row for `recipe-database.md`
**ADR Decision Summary**: Cross-validation is a semantic check that runs
in the consuming autoload's `_ready()` after `ResourceLoader.load` + cast.
RecipeDatabase calls `CardDatabase.get_card(id)` for every card reference
in every recipe — autoload-order (CardDatabase #2, RecipeDatabase #3)
guarantees CardDatabase is populated before this check fires.

**Engine**: Godot 4.3 | **Risk**: LOW
**Engine Notes**: `assert` in dev build fires audibly with a stack trace.
In release build, assertions are stripped — but this failure mode is a
dev-time content authoring error, not a user-facing runtime condition.
That matches ADR-005's "fail loud" policy.

**Control Manifest Rules (Foundation layer)**:
- Required: semantic validation runs in consuming autoload's `_ready()`
  via `assert`; `CardDatabase.get_card(id)` is the canonical read-only
  query.
- Forbidden: silent fall-through on an unknown ID (would let a recipe
  ship referencing a card that doesn't exist); reaching into CardDatabase
  `_entries` directly (use `get_card` per Story 005 of card-database).
- Guardrail: validation is O(n × k) where n = recipes and k = card refs
  per recipe (typically 2–3). At 60 recipes that's ~180 dictionary
  lookups — sub-millisecond.

---

## Acceptance Criteria

*From GDD `design/gdd/recipe-database.md`:*

- [ ] Every `card_a` and `card_b` StringName is resolved via
      `CardDatabase.get_card(id)` — unknown ID triggers an `assert`
      failure whose message names both the missing card id AND the
      recipe id (GDD Edge Case: "Fail loudly at load time naming the
      missing ID and the recipe it belongs to.")
- [ ] For `template == &"merge"`: `config.result_card` is resolved
      against CardDatabase; unknown → assert with recipe id + missing id
- [ ] For `template == &"additive"`: every entry in `config.spawns`
      (Array[StringName]) is resolved; any unknown triggers assert
- [ ] For `template == &"generator"`: `config.generates` is resolved;
      unknown triggers assert
- [ ] For `template == &"animate"`: no card refs in `config`, so this
      template skips result-card validation
- [ ] Validation runs once during `RecipeDatabase._ready()`, AFTER
      `ResourceLoader.load` + cast + `_entries` store, BEFORE any other
      validation step (fail on unknown IDs before checking for dups)
- [ ] A fully valid fixture (all card refs exist) produces zero
      assertion failures and zero errors
- [ ] Missing / null `config` Dictionary on a non-animate template is
      itself an error (the template declared it needs `result_card` /
      `spawns` / `generates` but the field is absent)

---

## Implementation Notes

*Derived from ADR-005 §6 and the GDD Template Configurations section:*

1. Extend `RecipeDatabase._ready()` with a `_validate_card_refs()` step:
   ```gdscript
   func _validate_card_refs() -> void:
       for r: RecipeEntry in _entries:
           _assert_card_exists(r.card_a, r.id, "card_a")
           _assert_card_exists(r.card_b, r.id, "card_b")

           match r.template:
               &"additive":
                   var spawns: Array = r.config.get("spawns", [])
                   assert(spawns is Array,
                       "RecipeDatabase: recipe %s (additive) missing 'spawns' array" % r.id)
                   for spawn_id: StringName in spawns:
                       _assert_card_exists(StringName(spawn_id), r.id, "additive.spawn")
               &"merge":
                   var result_id: StringName = r.config.get("result_card", &"")
                   assert(result_id != &"",
                       "RecipeDatabase: recipe %s (merge) missing 'result_card'" % r.id)
                   _assert_card_exists(result_id, r.id, "merge.result_card")
               &"generator":
                   var gen_id: StringName = r.config.get("generates", &"")
                   assert(gen_id != &"",
                       "RecipeDatabase: recipe %s (generator) missing 'generates'" % r.id)
                   _assert_card_exists(gen_id, r.id, "generator.generates")
               &"animate":
                   pass   # no card refs in animate config
               _:
                   assert(false,
                       "RecipeDatabase: recipe %s has unknown template '%s' (valid: additive, merge, animate, generator)"
                           % [r.id, r.template])

   func _assert_card_exists(card_id: StringName, recipe_id: StringName, context: String) -> void:
       var entry: CardEntry = CardDatabase.get_card(card_id)
       # Note: CardDatabase.get_card also push_error's on miss per card-database
       # Story 005 AC-2. Here we additionally assert-halt so load fails loud
       # instead of continuing with a broken recipe.
       assert(entry != null,
           "RecipeDatabase: recipe '%s' references unknown card '%s' (context: %s)"
               % [recipe_id, card_id, context])
   ```
2. Call `_validate_card_refs()` as the FIRST validation step after the
   cast-and-store in `_ready()`. Later stories (004 duplicates, 005 clamp,
   006 lookup index) run after this.
3. The `_` arm of the `match` catches templates outside the 4 canonical
   values — this is how the template StringName contract becomes
   enforceable even though the class itself doesn't constrain the value.
4. Do NOT suppress `CardDatabase.get_card`'s built-in `push_error` on
   miss. It's fine for both to fire — the game will never reach runtime
   anyway because our assert halts load.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001, 002: prerequisites
- Story 004: duplicate-rule detection (runs after this, independent concern)
- Story 005: Generator interval clamp (runs after this)
- Story 006: lookup API
- Future: validating `config.motion` enum values for animate
  (`drift`/`orbit`/`pulse`/`float`) — that's an ITF concern, not a
  RecipeDatabase concern

---

## QA Test Cases

*For this Integration story — automated test specs:*

- **AC-1 (unknown card_a/card_b triggers assert naming both)**:
  - Given: a fixture recipe with `card_a = &"nonexistent-card"`,
    `card_b = &"rainy-afternoon"` (where `rainy-afternoon` exists in the
    test CardDatabase fixture and `nonexistent-card` does not);
    recipe `id = &"bad-recipe-1"`
  - When: RecipeDatabase `_ready()` runs
  - Then: the test captures an assertion failure whose message contains
    both `bad-recipe-1` AND `nonexistent-card`
  - Edge cases: both card_a and card_b unknown → fails on first
    encountered (card_a)

- **AC-2 (merge with unknown result_card)**:
  - Given: a merge recipe with known `card_a`/`card_b` but
    `config.result_card = &"unknown-result"`
  - When: `_ready()` runs
  - Then: assertion fails, message contains recipe id and
    `unknown-result`

- **AC-3 (additive with one unknown in spawns list)**:
  - Given: an additive recipe with known card_a/card_b, but
    `config.spawns = [&"known-card", &"unknown-spawn"]`
  - When: `_ready()` runs
  - Then: assertion fails, message contains recipe id and
    `unknown-spawn`

- **AC-4 (generator with unknown generates)**:
  - Given: a generator recipe with `config.generates = &"unknown-gen"`
  - When: `_ready()` runs
  - Then: assertion fails, message contains recipe id and `unknown-gen`

- **AC-5 (animate has no card refs — passes even with sparse config)**:
  - Given: an animate recipe with valid card_a/card_b and
    `config = { motion = &"drift", speed = 1.0, target = &"both" }`
    (no `result_card` / `spawns` / `generates`)
  - When: `_ready()` runs
  - Then: no assertion fails for missing card refs (animate is exempt)

- **AC-6 (unknown template value triggers assert)**:
  - Given: a recipe with `template = &"teleport"` (not in 4-value list)
  - When: `_ready()` runs
  - Then: assertion fails, message contains `teleport` and the 4 valid
    template names

- **AC-7 (missing required config key triggers assert)**:
  - Given: a merge recipe with `config = {}` (no `result_card` key)
  - When: `_ready()` runs
  - Then: assertion fails, message names recipe id and `result_card`

- **AC-8 (valid fixture: zero failures)**:
  - Given: a fixture recipes.tres with 1 recipe per template
    (additive, merge, animate, generator), all card refs pointing to
    cards present in the test CardDatabase fixture
  - When: `_ready()` runs
  - Then: no assertion failures
  - Edge cases: spawns list with 0 entries → no assertion (empty list
    is a GDD soft warning, not a hard error — Story 004 territory)

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/recipe_database/card_ref_validation_test.gd`
(gdUnit4) — must exist and pass.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002 (autoload must be loading recipes);
  card-database Stories 003 + 005 (CardDatabase must be loaded with
  `get_card` API available)
- Unlocks: Story 004 (duplicate detection), Story 005 (clamp), Story 006
  (lookup)
