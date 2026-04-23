---
name: create-scene
description: Read a scene spec at design/scenes/[scene-id].md and generate all the scattered data-file edits required to make the scene playable — cards.tres, recipes.tres, bar-effects.json, scene JSON, scene-manifest.tres, KNOWN_SCENE_IDS, and asset-manifest rows. Runs cross-reference validation first; halts before any write if typos or dangling references exist.
argument-hint: "[scene-id]"
user-invocable: true
allowed-tools: Read, Glob, Grep, Write, Edit, Bash, AskUserQuestion, Task
---

# Create Scene

Drive an entire scene's data-layer from one source-of-truth spec file. Keeps
the 8+ scattered data files (cards / recipes / bar-effects / scene JSON /
manifest / KNOWN_SCENE_IDS / asset specs / asset manifest) in sync.

**Previous step**: hand-author the spec at `design/scenes/[scene-id].md` using
the `_TEMPLATE.md` shape.

**Next step after this**: run the game, verify scene loads, then
`/scene-audit [scene-id]` to confirm live data matches spec.

---

## Phase 1 — Parse Argument & Locate Spec

Extract `[scene-id]` from the argument. Normalise to kebab-case.

- If argument is a full path: read it directly.
- Otherwise: resolve to `design/scenes/[scene-id].md`.
- If the spec file does not exist:
  > "No spec found at `design/scenes/[scene-id].md`. Copy
  > `design/scenes/_TEMPLATE.md` to that path and fill it out first."
  > Then stop.

---

## Phase 2 — Load Context

Read **before any validation or write**:

- The scene spec (full file)
- `design/art/art-bible.md` — to cross-check any `art_style` references
- `assets/data/cards.tres` — to know which cards already exist
- `assets/data/recipes.tres` — to know which recipes already exist
- `assets/data/bar-effects.json` — current bar effects map
- `assets/data/scene-manifest.tres` — current scene order
- `src/core/card_database.gd` — current `KNOWN_SCENE_IDS`
- `.claude/rules/data-files.md` — enforce enum-ish lowercase rule
- `design/assets/asset-manifest.md` (if present) — for asset ID assignment

Extract from the spec:
- Section 1 → identity (scene_id, manifest_order, display_name)
- Section 2 → seed_cards list
- Section 3 → new cards to define
- Section 4 → recipes to add
- Section 5 → goal config
- Section 6 → bar list
- Section 7 → bar-effects mapping
- Section 8 → hint override (optional)
- Section 10 → palette override (optional)
- Section 10.2 → ambient indicator (optional — bottom-right parchment cue)
- Section 14 → STUI override (optional)
- Section 15 → one-time code additions (e.g. KNOWN_SCENE_IDS)

Report: "Loaded spec for `[scene-id]`. Existing cards: [N]. Existing
recipes: [N]. Existing scenes in manifest: [list]."

---

## Phase 3 — Cross-Reference Validation (BLOCKING — no writes if any fail)

Run every check from the spec's Section 17, plus:

1. **New cards don't shadow existing ones** — every `id` in Section 3 must
   not already exist in cards.tres
2. **Seed cards resolve** — every `card_id` in Section 2 either already
   exists OR is being defined in Section 3
3. **Recipe referential integrity** — every `card_a` / `card_b` /
   `result_card` / `keeps` resolves (existing or newly defined)
4. **No duplicate recipe ids** — every recipe `id` in Section 4 must not
   already exist in recipes.tres
5. **Bar effects link back to recipes** — every key in Section 7 must
   match a recipe `id` in Section 4
6. **Bar effects reference declared bars** — every bar `id` inside the
   effect delta map must appear in Section 6's bar list
7. **Template lowercase rule** — every recipe's `template` in Section 4
   is one of {`additive`, `merge`, `animate`, `generator`} (case-exact)
8. **Goal type supported** — Section 5's `type` is in
   `{sustain_above, reach_value}` (others are defined in GDD but not wired
   in SceneGoal yet — warn and ask if user wants to proceed)
9. **Manifest order not duplicate** — Section 1's `manifest_order` is not
   already occupied by another scene (check the spec's order vs. actual
   manifest)

   **Ambient indicator existence check** — if Section 10.2 declares
   `ambient_path` and the value is not `none`, verify the PNG exists at
   that path. If missing, emit a ⚠ warning ("ambient asset not yet
   committed — scene will load but the ambient vignette will be blank
   until the asset lands") rather than a blocking error. Ambient is
   purely decorative; scene can still run without it.
10. **art_style known** — if Section 3 lists `art_style: Template A` or
    `Template B`, confirm the Art Bible sections exist; if custom, warn
11. **Epilogue coherence** — if Section 11 says `next_scene: none` AND
    Section 12 marks `final-memory: YES`, the epilogue content slot in
    Section 11 must not be empty

Present the full validation report:

```
## Validation for `[scene-id]`

✓ Seed cards resolve
✗ Recipe "brew-X" references unknown card "coffe_machine" (typo?)
✓ Templates lowercase
⚠ Goal type "find_key" not yet wired — implementation will default to no-op
```

If any ✗ exists: **stop, do not write anything**. Print the minimal fix
and wait for the user to correct the spec.

If only ⚠ warnings: `AskUserQuestion`:
- Prompt: "Validation passed with N warnings. Proceed to write files?"
- Options: `[A] Yes — proceed with warnings` / `[B] Stop — I'll revise the spec first`

---

## Phase 4 — Preview Changes

Before any write, present the diff summary:

```
## Files to modify for `[scene-id]`

| File | Change |
|---|---|
| assets/data/cards.tres | +3 SubResources, +3 ExtResources, entries array appended |
| assets/data/recipes.tres | +2 SubResources, entries array appended |
| assets/data/bar-effects.json | +1 key: "deliver-coffee" |
| assets/data/scenes/[scene-id].json | create |
| assets/data/scene-manifest.tres | scene_ids extended at index N |
| src/core/card_database.gd | KNOWN_SCENE_IDS += ["scene-id"] |
| design/assets/specs/card-database-assets.md | +3 asset specs |
| design/assets/asset-manifest.md | +3 rows |
```

Ask: "May I apply these changes?"
Options: `[A] Yes — apply all` / `[B] Stop — I want to review first`

---

## Phase 5 — Apply Changes

In dependency order (important — later steps reference earlier ones):

1. **cards.tres** — append new card ExtResources + SubResources. If the
   art PNG does not exist on disk yet, use the placeholder
   `3_placeholder_art` ExtResource; otherwise create a new ExtResource
   for the PNG. Append new SubResource refs to the `entries` array.
   Update `load_steps` in the header.

2. **recipes.tres** — append new SubResource blocks + entries array.
   Bump `load_steps`.

3. **bar-effects.json** — merge new keys; keep the existing entries.

4. **scenes/[scene-id].json** — write new file.

5. **scene-manifest.tres** — insert `scene_id` at the spec's
   `manifest_order` index; push later scenes back.

6. **card_database.gd** — add scene_id to `KNOWN_SCENE_IDS` if missing.

7. **asset-manifest + card-database asset spec** — if Section 3 declares
   new cards with `art_style: Template A/B`, append rows via the same
   pattern as `/asset-spec system:card-database`. If the asset spec file
   doesn't exist, stop and recommend running `/asset-spec` separately.

Each write emits a short log line: `wrote cards.tres (+3 SubResources)`.

---

## Phase 6 — Smoke Check

After all writes:

```
pkill -9 -f "Godot.app/Contents/MacOS/Godot"
/Applications/Godot.app/Contents/MacOS/Godot --headless --import
```

Then a short editor scan:
```
/Applications/Godot.app/Contents/MacOS/Godot --headless --editor --quit 2>&1 | \
  grep -iE "error|parse|CardDatabase|RecipeDatabase|[scene-id]" | head -20
```

Report any new errors. Expected output should be empty (or only the
pre-existing `debug-config.tres` warning).

---

## Phase 7 — Summary & Next Steps

Present:

```
## Scene `[scene-id]` scaffolded

Files written: 8
Cards added: N  (art: N generated / N still placeholder)
Recipes added: N
Bars declared: N

Smoke check: PASS / FAIL

Next:
  1. If any card art is still placeholder, run `/asset-spec` then
     generate the PNGs via nano-banana
  2. Run the game, verify the scene loads and the puzzle solves
  3. Run `/scene-audit [scene-id]` to confirm live data matches spec
  4. Write a playtest report at `production/playtests/[scene-id]-NNN.md`
```

---

## Collaborative Protocol

- **Validation before writes** — never skip Phase 3. The whole point of
  this skill is catching typos before they propagate to 8 files.
- **One source of truth** — the spec is authoritative. If the user made
  a runtime change directly to a data file (e.g. edited cards.tres by
  hand), this skill may overwrite. Warn and offer a dry-run diff option
  when the existing data diverges from what the spec says to produce.
- **Idempotent** — re-running the skill on an already-processed spec
  should be a no-op (detect existing entries, skip them). This lets
  designers iterate on the spec without fear.
- **Never touch code beyond KNOWN_SCENE_IDS** — the skill is data-only.
  If the spec implies a code change (new goal type, new template type),
  stop and surface it as a TODO, do not modify gameplay logic.

---

## Error Recovery

- **Spec parse error** — the spec is missing a required section → point
  at `_TEMPLATE.md` and stop
- **Partial write failure** — roll back (keep a backup of each touched
  file in `/tmp/` before writing; restore if any step fails)
- **Godot smoke fails** — do NOT roll back (the files may be correct and
  the error pre-existing). Surface the error and let the user decide

---

## Recommended Next Steps After PASS

- Run `/scene-audit [scene-id]` to verify live data matches the spec
- If new card art is needed, generate via `/asset-spec` + nano-banana
- Playtest, document in `production/playtests/[scene-id]-NNN.md`
