---
name: scene-audit
description: Validate that a scene's live data files (cards.tres, recipes.tres, bar-effects.json, scene JSON, scene-manifest.tres, KNOWN_SCENE_IDS) match the spec at design/scenes/[scene-id].md. Reports drift — entries present in data but not in spec, entries in spec but not in data, and referential integrity violations.
argument-hint: "[scene-id]"
user-invocable: true
allowed-tools: Read, Glob, Grep, Bash
---

# Scene Audit

Compare an existing scene's **on-disk data** against its **spec**. Catches
drift from two directions:

- **Spec says X, data says Y** — someone edited the .tres / .json directly
- **Spec changed but skill not re-run** — designer updated the spec but
  forgot to propagate via `/create-scene`

This skill **never writes**. It only reports.

---

## Phase 1 — Parse & Load

- Resolve spec at `design/scenes/[scene-id].md`. Stop if missing.
- Read all data files referenced by Section 16 of the spec:
  - `assets/data/cards.tres`
  - `assets/data/recipes.tres`
  - `assets/data/bar-effects.json`
  - `assets/data/scenes/[scene-id].json`
  - `assets/data/scene-manifest.tres`
  - `src/core/card_database.gd` (for `KNOWN_SCENE_IDS`)

---

## Phase 2 — Extract Both Sides

From the **spec**, extract the expected shape for each data file. From the
**data files**, extract what's actually present.

Build two normalised dictionaries per category (cards, recipes,
bar-effects entries, scene JSON payload, manifest order, known ids).

---

## Phase 3 — Diff & Report

For each category, emit:

- ✓ entries that match
- ⚠ entries in spec but missing from data → "spec orphan"
- ⚠ entries in data but missing from spec → "data orphan (drift)"
- ✗ entries present in both but with mismatched fields → "value mismatch"

Example report block:

```
## Cards

✓ coffee_machine, coffee_beans, coffee — all match spec
⚠ coffee_machine.flavor_text: spec="Hums before sunrise." data="Wakes the room."
  → data diverges. Either (a) update the spec to match, or
  (b) re-run `/create-scene` to overwrite data with spec.

## Recipes

✓ brew-coffee, deliver-coffee — all match
⚠ spec orphan: "roast-bean" (in spec Section 4, not in recipes.tres)
  → likely means /create-scene hasn't been re-run since the spec changed.

## Bar-Effects

✗ value mismatch on "deliver-coffee":
    spec:  { "affection": 100 }
    data:  { "affection": 80 }
  → tune value chosen via playtest; update spec or revert data.

## Scene JSON

✓ all fields match

## Scene Manifest

✓ "coffee-intro" present at index 0 as spec'd

## KNOWN_SCENE_IDS

✓ "coffee-intro" listed
```

---

## Phase 4 — Referential Integrity Check

Independent of spec-vs-data drift, run the same checks from
`/create-scene` Phase 3:

1. Every recipe's `card_a` / `card_b` / `result_card` / `keeps` resolves
   to an existing card in cards.tres
2. Every bar-effects key matches a recipe id in recipes.tres
3. Every bar_id in deliveries is declared in the scene goal's `bars`
4. Scene id appears in `scene-manifest.tres`
5. Scene id is in `KNOWN_SCENE_IDS`
6. Every recipe `template` is lowercase + valid

Any violation here is a runtime bug waiting to happen. Report separately:

```
## Referential Integrity

✗ Recipe "brew-coffee" references result_card "coffe" — typo (no such card)
```

---

## Phase 5 — Verdict

```
## Scene Audit: `[scene-id]`

Spec version: [hash or timestamp]
Date: [today]

### Drift
- N mismatches
- N spec orphans
- N data orphans

### Integrity
- N violations

### Verdict: CLEAN / DRIFT / BROKEN
```

- **CLEAN**: no drift, no integrity violations → spec and data are in sync
- **DRIFT**: spec/data mismatches but no integrity violations → game still
  runs, but the spec is no longer trustworthy as documentation
- **BROKEN**: integrity violations present → game will throw runtime
  errors or silently fail a recipe

If **BROKEN**: recommend running `/create-scene [scene-id]` to re-apply
the spec, OR editing the spec to match the (intentional) data state.

If **DRIFT** only: present both sides and let the user decide which is
the source of truth per item.

---

## Recommended Next Steps

- **CLEAN** → no action
- **DRIFT** → `/create-scene [id]` if spec is authoritative, or edit spec
- **BROKEN** → fix the integrity violation first (usually a typo), then
  re-audit
