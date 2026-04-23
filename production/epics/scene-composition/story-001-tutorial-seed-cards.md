# Story 001: Tutorial seed cards (coffee_machine, coffee_beans, coffee)

> **Epic**: scene-composition
> **Status**: Complete
> **Layer**: Presentation + Content
> **Type**: Config/Data
> **Manifest Version**: 2026-04-21

## Context

**GDD**: `design/gdd/card-database.md`
**Requirement**: reuses TR-card-database-001/002 (load, lookup) — no new TR

**ADR Governing Implementation**: ADR-005: Data File Format Convention
**ADR Decision Summary**: All card definitions live in `assets/data/cards.tres`
as `CardEntry` SubResources inside a typed `CardManifest`. No JSON for cards.

**Engine**: Godot 4.3 | **Risk**: LOW
**Engine Notes**: SubResource syntax + `ExtResource` references for shared
textures — stable in 4.3.

**Control Manifest Rules (Content layer)**:
- Required: scene_id populated on every card (global or a concrete scene id)
- Forbidden: hyphens in sub_resource `id="…"` (Godot 4.3 rejects them)
- Guardrail: keep card entry count under 50 per scene

---

## Acceptance Criteria

- [ ] `coffee_machine` card entry exists in `cards.tres` with `scene_id = "coffee-intro"` and `type = object`
- [ ] `coffee_beans` card entry exists with same scene_id and `type = object`
- [ ] `coffee` card entry exists with same scene_id and `type = object`
- [ ] All three entries have `art` pointing to an existing PNG (placeholder `home.png` is acceptable)
- [ ] `CardDatabase.get_card()` returns non-null for each of the three new IDs at startup (no error in editor)
- [ ] `CardEntry` sub_resource IDs in the .tres use underscores (not hyphens)

---

## Implementation Notes

Add three new `[sub_resource type="Resource" id="CardEntry_coffee_machine"]`
blocks to `assets/data/cards.tres`, following the existing `chester` /
`ju` pattern. Reference the already-declared placeholder `ExtResource("3_placeholder_art")`
until real art is commissioned. The `CardManifest.entries` array at the bottom
of the file must include the three new SubResource references.

Canonical entries:

```
id = &"coffee_machine"    display_name = "Coffee Machine"    type = 3 (object)    scene_id = &"coffee-intro"
id = &"coffee_beans"      display_name = "Coffee Beans"      type = 3 (object)    scene_id = &"coffee-intro"
id = &"coffee"            display_name = "Coffee"            type = 3 (object)    scene_id = &"coffee-intro"
```

The `type = 3` value is the `CardType.OBJECT` enum ordinal
(see `src/data/card_entry.gd` — order: PERSON=0, PLACE=1, FEELING=2, OBJECT=3, MOMENT=4, INSIDE_JOKE=5, SEED=6).

---

## Out of Scope

- Recipes that consume/produce these cards (Story 002)
- The scene file that seeds them (Story 003)
- Commissioned art — placeholder is fine for the Vertical Slice

---

## QA Test Cases

- **AC-1 (all three)**: `coffee_machine`, `coffee_beans`, `coffee` entries exist
  - Given: CardDatabase autoload loaded `cards.tres` at startup
  - When: `CardDatabase.get_card(&"coffee_machine")` is called
  - Then: returns a non-null `CardEntry` with `display_name == "Coffee Machine"`
  - Edge cases: repeat for `coffee_beans` and `coffee`; confirm each returns a valid entry

---

## Test Evidence

**Story Type**: Config/Data
**Required evidence**: smoke-check pass — after loading the project in the
editor, confirm no `CardDatabase: no card with id '…'` errors in the output
panel. Record as one line in `production/qa/smoke-coffee-intro-cards.md`.

**Status**: [x] production/qa/smoke-coffee-intro-cards.md — PASS 2026-04-23

---

## Dependencies

- Depends on: None (pure data edit)
- Unlocks: Story 002 (recipes reference these card IDs)
