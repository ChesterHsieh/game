# Story 004: Duplicate-rule detection — same pair in same scene

> **Epic**: recipe-database
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-04-21

## Context

**GDD**: `design/gdd/recipe-database.md`
**Requirement**: `TR-recipe-database-005` — detect duplicate rules for
the same pair within the same scene at load time and fail loudly.

**ADR Governing Implementation**: ADR-005 — `.tres` everywhere, §6
validation strategy
**ADR Decision Summary**: Semantic validation in `_ready()` via `assert`.
Pair ordering is normalised (sort card_a/card_b alphabetically) so
`(a,b)` and `(b,a)` are detected as duplicates.

**Engine**: Godot 4.3 | **Risk**: LOW
**Engine Notes**: String/StringName comparison and Dictionary keying are
pre-cutoff. A string-tuple key like `"%s|%s|%s" % [scene_id, lo, hi]`
keeps the Dictionary small and O(1) per lookup.

**Control Manifest Rules (Foundation layer)**:
- Required: semantic validation in autoload `_ready()` via `assert`.
- Forbidden: "last rule wins" fallback on duplicates — would silently
  shadow earlier design intent.
- Guardrail: O(n) over recipes where n ≈ 60–300; sub-millisecond.

---

## Acceptance Criteria

*From GDD `design/gdd/recipe-database.md`:*

- [ ] Two recipes sharing the same (card_a, card_b) pair in the same
      `scene_id` trigger an `assert` failure naming the conflicting
      pair AND both recipe ids (GDD Edge Case: "Fail loudly at load time
      naming the conflicting pair. Never silently pick one.")
- [ ] Pair ordering is normalised — `(a=fee, b=fie)` and `(a=fie, b=fee)`
      in the same scene_id are detected as the same pair
- [ ] Duplicate detection DOES allow the same pair to appear in
      different `scene_id`s (global + scene-01 is acceptable; scene-01 +
      scene-02 is acceptable; scene-01 + scene-01 is not)
- [ ] Duplicate detection DOES allow `scene_id = &"global"` coexisting
      with a scene-scoped rule for the same pair — this is the scene
      precedence case (Story 006), NOT a duplicate
- [ ] Detection runs after Story 003's card-ref validation but before
      Story 005's clamp and Story 006's index-build
- [ ] A fully valid fixture (no duplicates) produces zero assertion
      failures

---

## Implementation Notes

*Derived from ADR-005 §6 and GDD Edge Case "Duplicate rule":*

1. Extend `_ready()` with `_validate_no_duplicates()`:
   ```gdscript
   func _validate_no_duplicates() -> void:
       var seen: Dictionary = {}   # "scene|lo|hi" → recipe_id
       for r: RecipeEntry in _entries:
           var key: String = _dup_key(r.scene_id, r.card_a, r.card_b)
           assert(not seen.has(key),
               "RecipeDatabase: duplicate rule for pair (%s, %s) in scene '%s' — recipes '%s' and '%s'"
                   % [r.card_a, r.card_b, r.scene_id, seen[key], r.id])
           seen[key] = r.id

   static func _dup_key(scene_id: StringName, a: StringName, b: StringName) -> String:
       var sa: String = String(a)
       var sb: String = String(b)
       var lo: String = sa if sa < sb else sb
       var hi: String = sb if sa < sb else sa
       return "%s|%s|%s" % [String(scene_id), lo, hi]
   ```
2. The key includes `scene_id`, so the same pair CAN coexist across
   scenes (different scene_id → different key). Global-vs-scene
   precedence is Story 006's concern — duplicate here means "same key,
   two entries".
3. Call `_validate_no_duplicates()` in `_ready()` AFTER
   `_validate_card_refs()` (Story 003) and BEFORE Story 005 clamp. The
   clamp-and-index need the deduped data.
4. Pair normalisation is stable: StringName comparison in Godot 4.3 is
   lexicographic and deterministic.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 003: card-ref validation
- Story 005: Generator interval_sec clamp
- Story 006: lookup API — scene-vs-global precedence is a LOOKUP concern,
  NOT a duplicate concern; don't conflate them here
- Warnings for additive with empty `spawns` (GDD Edge Case, not a
  duplicate concern) — can be a follow-up story, ignored in MVP

---

## QA Test Cases

*For this Logic story — automated test specs:*

- **AC-1 (same-pair same-scene triggers assert)**:
  - Given: a fixture with two recipes, both
    `card_a = &"card-x"`, `card_b = &"card-y"`, `scene_id = &"scene-01"`;
    recipe ids `recipe-a` and `recipe-b`
  - When: `_ready()` runs
  - Then: assertion fails; message contains `card-x`, `card-y`,
    `scene-01`, `recipe-a`, `recipe-b`
  - Edge cases: three-way duplicate → fails on second encountered

- **AC-2 (pair-order normalisation)**:
  - Given: two recipes — first with `(a=&"cat", b=&"dog")`, second with
    `(a=&"dog", b=&"cat")`, both `scene_id = &"scene-01"`
  - When: `_ready()` runs
  - Then: assertion fails (they are recognised as the same pair)

- **AC-3 (same pair in different scenes is OK)**:
  - Given: two recipes with identical `(card_a, card_b)` but
    `scene_id` differ (`&"scene-01"` and `&"scene-02"`)
  - When: `_ready()` runs
  - Then: no assertion failure

- **AC-4 (global + scene-scoped for same pair is OK — precedence is
    Story 006's concern)**:
  - Given: recipe `r-global` with `scene_id = &"global"` and recipe
    `r-scene` with `scene_id = &"scene-01"`, same (card_a, card_b)
  - When: `_ready()` runs
  - Then: no assertion failure

- **AC-5 (no duplicates: clean fixture)**:
  - Given: a fixture with 5 recipes each with unique (scene_id,
    normalized pair) keys
  - When: `_ready()` runs
  - Then: zero assertion failures

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/recipe_database/duplicate_detection_test.gd`
(gdUnit4) — must exist and pass.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002 (autoload), Story 003 (card-ref validation runs
  first so we only dedup valid data)
- Unlocks: Story 005 (clamp), Story 006 (lookup)
