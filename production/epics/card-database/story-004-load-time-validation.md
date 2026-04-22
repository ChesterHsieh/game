# Story 004: Load-time validation — uniqueness, display_name, orphan scene

> **Epic**: card-database
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-04-21

## Context

**GDD**: `design/gdd/card-database.md`
**Requirement**: `TR-card-database-003` (unique kebab-case `id`, fail loudly
on duplicates), `TR-card-database-005` (non-empty `display_name`, log warning
on empty), `TR-card-database-008` (warn on orphaned `scene_id`).

**ADR Governing Implementation**: ADR-005 — `.tres` everywhere, §6 validation
strategy
**ADR Decision Summary**: Semantic validation lives in the consuming
autoload's `_ready()` via `assert` (hard) + `push_warning` (soft). Two
layers: structural (`@export` typing, automatic) + semantic (explicit
assertions after load).

**Engine**: Godot 4.3 | **Risk**: LOW
**Engine Notes**: `assert` is pre-cutoff; in release builds `assert` is
stripped unless `--check-only` is set — duplicates are a DEV-time error,
acceptable per ADR-005. `push_warning` fires regardless of build.

**Control Manifest Rules (Foundation layer)**:
- Required: semantic validation (uniqueness, cross-refs, ranges) runs in
  the consuming autoload's `_ready()` via `assert`; never inside the
  Resource class.
- Forbidden: silent fall-through on malformed data; validation methods on
  Resource classes.
- Guardrail: validation loop is O(n) over entries; for ~200 entries this
  runs in sub-millisecond time, well within the 20–50 ms startup budget.

---

## Acceptance Criteria

*From GDD `design/gdd/card-database.md`:*

- [ ] Duplicate `id` values across entries cause an `assert` failure at
      load time, with a message naming the duplicated id (GDD Edge Case:
      "Fail loudly at load time with the conflicting ID named.")
- [ ] Empty `display_name` on any entry logs a `push_warning` naming the
      offending `id` — does not crash (GDD Edge Case: "Catch at load time
      with a validation warning.")
- [ ] Invalid `type` value (outside the 7-member `CardType` enum) triggers
      an `assert` failure naming the offending card (structural typing
      covers this for `.tres`-authored files, but the assertion is kept
      as a defensive check)
- [ ] `scene_id` values that do not match any known scene (and are not the
      literal string `global`) log a `push_warning` naming the card and
      scene — card remains in the database, simply unspawnable (GDD Edge
      Case: "Log a warning at load time.")
- [ ] Validation runs exactly once, inside `CardDatabase._ready()`, after
      the manifest cast succeeds
- [ ] A fully valid fixture produces zero warnings and zero assertion
      failures (happy path baseline)

---

## Implementation Notes

*Derived from ADR-005 §6:*

1. Extend `res://src/core/card_database.gd` with a private `_validate_entries()`
   method called after the `as CardManifest` cast from Story 003:
   ```gdscript
   const KNOWN_SCENE_IDS: PackedStringArray = PackedStringArray([
       "global",
       # scene IDs are populated once SceneManager scope is scoped; for
       # MVP we hard-code the MVP scene ids here and revisit in a later
       # epic. See Out of Scope.
   ])

   func _validate_entries() -> void:
       var seen := {}
       for e: CardEntry in _entries:
           assert(not seen.has(e.id),
               "CardDatabase: duplicate card id: %s" % e.id)
           seen[e.id] = true

           if e.display_name == "":
               push_warning("CardDatabase: empty display_name on card %s" % e.id)

           assert(CardEntry.CardType.values().has(e.type),
               "CardDatabase: invalid CardType on card %s" % e.id)

           if not KNOWN_SCENE_IDS.has(String(e.scene_id)):
               push_warning("CardDatabase: orphaned scene_id '%s' on card %s"
                   % [e.scene_id, e.id])
   ```
2. Use `assert` for errors that must halt development (duplicate id, bad
   enum). Use `push_warning` for soft issues Ju should never see but that
   do not break gameplay (empty name, orphan scene).
3. Do NOT emit EventBus signals here. Validation is an internal startup
   concern; its outputs are the assertion stack or the Godot warning log.
4. Keep the known-scene-id list minimal for MVP. Once a SceneManager epic
   defines the authoritative scene registry, this check can read from it
   dynamically (follow-up, not this story).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 003: autoload load + cast (prerequisite; don't re-implement)
- Story 005: public lookup API
- Story 006: missing-art detection and placeholder warning
- Future: dynamic scene-id registry from SceneManager — today we use a
  hard-coded `KNOWN_SCENE_IDS` list, covered by a follow-up story in the
  SceneManager epic

---

## QA Test Cases

*For this Logic story — automated test specs:*

- **AC-1 (duplicate id triggers assert)**:
  - Given: a fixture manifest with two CardEntry SubResources sharing
    `id = "rainy-afternoon"`
  - When: CardDatabase `_ready()` runs in a test harness that captures
    assertion failures
  - Then: the test captures an assertion failure whose message contains
    the literal text `rainy-afternoon`
  - Edge cases: three-way duplicate (first two collide, fail on second);
    empty id (`""`) duplicated — fail with empty-name message

- **AC-2 (empty display_name triggers warning, not assertion)**:
  - Given: a fixture manifest with one CardEntry whose `display_name == ""`
    but otherwise valid fields (id = "nameless-card")
  - When: CardDatabase `_ready()` runs
  - Then: `push_warning` is called with a message containing `nameless-card`;
    no assertion fires; `_entries` still contains the card
  - Edge cases: whitespace-only name (`"   "`) — current spec treats as
    non-empty; documented as known limitation

- **AC-3 (invalid CardType triggers assert)**:
  - Given: a fixture manifest with an entry whose `type` was manually
    coerced to a value outside `CardEntry.CardType.values()` (e.g. 99)
  - When: CardDatabase `_ready()` runs
  - Then: the test captures an assertion failure whose message contains
    the offending card id
  - Edge cases: type = -1 → assertion fires; type = 6 (SEED, last valid)
    → no failure

- **AC-4 (orphan scene_id triggers warning, card remains in db)**:
  - Given: a fixture manifest with an entry whose
    `scene_id = "unknown-scene"` and `KNOWN_SCENE_IDS = ["global"]`
  - When: CardDatabase `_ready()` runs
  - Then: `push_warning` message contains both `unknown-scene` and the
    card id; `_entries` still contains the card
  - Edge cases: `scene_id == "global"` → no warning; `scene_id == ""` →
    warning (empty is treated as orphan)

- **AC-5 (valid fixture: no warnings, no failures)**:
  - Given: a fixture manifest with 3 entries with unique ids, non-empty
    names, valid types, and `scene_id = "global"`
  - When: CardDatabase `_ready()` runs
  - Then: zero `push_warning` calls; no assertion failures
  - Edge cases: empty manifest (`entries.size() == 0`) → also zero warnings,
    zero failures (not this story's concern to detect empty dbs)

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/card_database/validation_test.gd`
(gdUnit4, driven by multiple fixture manifests under
`tests/fixtures/card_database/`) — must exist and pass.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002 (CardEntry + CardManifest must exist), Story 003
  (autoload + load pipeline must be in place to extend)
- Unlocks: Story 005 (lookup API can assume validated entries)
