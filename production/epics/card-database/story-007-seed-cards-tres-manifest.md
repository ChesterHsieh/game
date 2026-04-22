# Story 007: Seed cards.tres manifest — MVP scene-01 card set

> **Epic**: card-database
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Config/Data
> **Manifest Version**: 2026-04-21

## Context

**GDD**: `design/gdd/card-database.md`
**Requirement**: `TR-card-database-011` — scale to ~120–200 total card
entries across 5–8 scenes with ~20–30 cards per scene.

**ADR Governing Implementation**: ADR-005 — `.tres` everywhere, §3 file
layout
**ADR Decision Summary**: Single `cards.tres` manifest at
`res://assets/data/cards.tres` holds all card SubResources. Solo dev, N=1
audience; single manifest is acceptable up to ~400 entries; split into
per-scene manifests only if that ceiling is exceeded.

**Engine**: Godot 4.3 | **Risk**: LOW
**Engine Notes**: Editor first-open of a 200-entry `cards.tres` takes 1–3 s
on Chester's dev machine (ADR-005 §3, Performance Implications table).
Cold runtime load is 20–50 ms. Within budget.

**Control Manifest Rules (Foundation layer)**:
- Required: all persistent content uses `.tres`; `cards.tres` at the
  declared path.
- Forbidden: hardcoded card content in `.gd` files; `.json` anywhere under
  `res://assets/data/`.
- Guardrail: editor first-open ≤ 3 s at 200 entries; cold runtime load
  ≤ 50 ms.

---

## Acceptance Criteria

*From GDD `design/gdd/card-database.md` (Tuning Knobs) and ADR-005 §3:*

- [ ] `res://assets/data/cards.tres` exists as a typed `CardManifest`
      Resource
- [ ] Manifest contains the MVP scene-01 card set (~20–30 entries per GDD
      Tuning Knob "Cards per scene"), with each entry configured for
      `scene_id = "scene-01"` or `"global"` (as appropriate for seed cards
      vs. universal cards)
- [ ] All entries have: unique kebab-case `id`, non-empty `display_name`,
      valid `type` from the 7-member `CardType` enum, valid `scene_id`,
      and a non-null `art` Texture2D reference (placeholder PNGs are
      acceptable for this story — final art is content authoring)
- [ ] Manifest passes all CardDatabase validation from Stories 004 + 006
      with zero `assert` failures and zero `push_warning` calls
- [ ] Game launches without errors; CardDatabase `_ready()` completes in
      under 50 ms (smoke-measured via log timestamps)
- [ ] Editor first-open of `cards.tres` completes within 3 s (smoke-measured)
- [ ] At least one entry of each `CardType` enum value appears in the
      manifest (person, place, feeling, object, moment, inside_joke, seed)
      — proves the schema round-trips for all types

---

## Implementation Notes

*Derived from ADR-005 §3 and the GDD Card Types table:*

1. Author `res://assets/data/cards.tres` via the Godot editor:
   - Create a new Resource → select `CardManifest` class
   - For each MVP scene-01 card, add a `CardEntry` SubResource to `entries`
   - Set fields via Inspector (drag-drop Texture2D for `art`, pick enum
     value for `type`, fill StringName/String fields)
   - Save
2. Use placeholder art from `res://assets/cards/_placeholder/` (any
   colored rectangle PNG is fine). Placeholder PNGs should be committed
   so the manifest validates in CI.
3. Seed cards (`type = SEED`) are placed on the table at scene start by
   Card Spawning System (future epic). Mark these explicitly so the
   downstream epic can filter.
4. Inside-joke cards require real content from Chester — use placeholder
   `display_name` like "Joke placeholder 1" for now. Content authoring
   (writing the real memories) is a separate, ongoing task, not this
   story's scope.
5. Kebab-case ids: `rainy-afternoon`, `first-call`, `our-cafe`. Avoid
   spaces, capitals, underscores. ADR-001 + GDD Card Schema enforce this.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Final Chester-authored card content (memory text, real art) — that is
  ongoing content work across the entire project, not a single story
- Additional scene manifests (`scene-02` onward) — create in a follow-up
  story once CardDatabase + RecipeDatabase are proven end-to-end
- Placeholder-art PNG creation if artwork does not yet exist — use any
  existing placeholder from the project or generate via Godot CanvasItem
  dumps

---

## QA Test Cases

*For this Config/Data story — smoke-check steps (not an automated test):*

- **Manual check 1 (manifest loads)**:
  - Setup: run the project from Godot editor or CLI
  - Verify: CardDatabase `_ready()` completes without assertion or error
  - Pass condition: Godot log contains no `push_error` entries from
    CardDatabase during startup

- **Manual check 2 (zero warnings on valid fixture)**:
  - Setup: run the project and capture Godot console output
  - Verify: no `push_warning` messages from CardDatabase fire — no
    "empty display_name", no "orphaned scene_id", no "missing art"
  - Pass condition: grep the log for `CardDatabase:` — all lines must be
    informational (e.g. load-complete timestamp), not warnings

- **Manual check 3 (7-type coverage)**:
  - Setup: open `cards.tres` in the Godot editor
  - Verify: the `entries` array contains at least one CardEntry of each
    CardType value (person, place, feeling, object, moment, inside_joke,
    seed)
  - Pass condition: Inspector count by type meets the 7-type coverage
    requirement

- **Manual check 4 (editor open time ≤ 3 s)**:
  - Setup: close the Godot editor; open the project; double-click
    `cards.tres` and time the Inspector reveal
  - Verify: Inspector becomes interactive in under 3 seconds
  - Pass condition: stopwatch or subjective "no perceptible lag beyond
    3 s"

- **Manual check 5 (cold runtime load ≤ 50 ms)**:
  - Setup: add a one-shot `print("db_load_ms=%.2f" %
    ((Time.get_ticks_usec() - start) / 1000.0))` around the CardDatabase
    `_ready()` load block (remove after check)
  - Verify: printed value ≤ 50 ms
  - Pass condition: ≤ 50 ms on Chester's dev machine

---

## Test Evidence

**Story Type**: Config/Data
**Required evidence**: smoke-check document at
`production/qa/smoke-cards-tres-[date].md` recording pass/fail for all 5
manual checks above.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Stories 001–006 (infrastructure must be in place to even
  load and validate the manifest)
- Unlocks: every downstream story that needs to reference real card ids
  (RecipeDatabase recipes, CardSpawningSystem seed lists, SceneGoalSystem
  goal configs)
