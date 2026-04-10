## Archived Session State: 20260323_132520
# Session State — Moments

*Last updated: 2026-03-23*

## Current Task

Systems decomposition complete. Ready to begin designing individual system GDDs.

## Progress Checklist

- [x] Game concept created — design/gdd/game-concept.md
- [x] Systems index created — design/gdd/systems-index.md
- [ ] Card Database GDD
- [ ] Recipe Database GDD
- [ ] Card Engine GDD (PROTOTYPE THIS FIRST)
- [ ] Interaction Template Framework GDD
- [ ] Scene Goal System GDD
- [ ] Hint System GDD
- [ ] Status Bar System GDD

## Key Decisions Made

- Game: "Moments" — personal card-discovery gift for Ju (Chester's girlfriend)
- Engine: Godot 4.6 / GDScript
- 20 systems total: 13 MVP, 4 VS, 2 Alpha, 1 Full Vision
- Card Engine is highest-risk system — prototype before anything else
- Interaction template types: Additive, Merge, Animate, Generator

## Files Being Worked On

- design/gdd/systems-index.md (just completed)

## Open Questions

- Card Database schema: what fields does each card need? (name, art path, type, tags?)
- Recipe Database schema: what defines a "combination rule"?
- What does the card snap animation look and feel like at 60fps?

## Next Step

Run `/design-system card-database` OR `/design-system card-engine` to start GDD authoring.
Recommended: Card Database first (it's fast and unlocks everything else).
---

## Archived Session State: 20260323_163639
# Session State — Moments

*Last updated: 2026-03-23*

## Current Task

Recipe Database GDD complete. Ready to design next system.

## Progress Checklist

- [x] Game concept — design/gdd/game-concept.md
- [x] Systems index — design/gdd/systems-index.md
- [x] Card Database GDD — design/gdd/card-database.md
- [x] Recipe Database GDD — design/gdd/recipe-database.md
- [ ] Input System GDD
- [ ] Audio Manager GDD
- [ ] Card Engine GDD ← PROTOTYPE THIS FIRST
- [ ] Table Layout System GDD
- [ ] Card Spawning System GDD
- [ ] Interaction Template Framework GDD
- [ ] Status Bar System GDD
- [ ] Scene Goal System GDD
- [ ] Hint System GDD
- [ ] Card Visual GDD
- [ ] Status Bar UI GDD

## Key Decisions Made

- Card schema: id, display_name, flavor_text, art_path, type, scene_id, tags
- Card types: person, place, feeling, object, moment, inside_joke, seed
- Recipe matching: specific IDs only, symmetric (no wildcards)
- 4 templates: Additive (both stay + spawns), Merge (both → result), Animate (motion), Generator (produces over time)
- Scene-scoped rules take precedence over global rules
- Open: file format (JSON vs .tres) — decide before implementation
- Open: are combinations one-time or repeatable? — ITF to decide

## Next Step

`/design-system card-engine` — the most important system, should be prototyped first
---

## Archived Session State: 20260323_170819
# Session State — Moments

*Last updated: 2026-03-23*

## Current Task

Card Engine GDD complete. Ready to prototype or continue designing.

## Progress Checklist

- [x] Game concept — design/gdd/game-concept.md
- [x] Systems index — design/gdd/systems-index.md
- [x] Card Database GDD — design/gdd/card-database.md
- [x] Recipe Database GDD — design/gdd/recipe-database.md
- [x] Input System GDD — design/gdd/input-system.md
- [x] Card Engine GDD — design/gdd/card-engine.md
- [ ] Table Layout System GDD (#6)
- [ ] Card Spawning System GDD (#7)
- [ ] Interaction Template Framework GDD (#8)
- [ ] Status Bar System GDD (#9)
- [ ] Scene Goal System GDD (#10)
- [ ] Hint System GDD (#11)
- [ ] Card Visual GDD (#12)
- [ ] Status Bar UI GDD (#13)

## Key Decisions Made

- Card schema: id, display_name, flavor_text, art_path, type, scene_id, tags
- Card types: person, place, feeling, object, moment, inside_joke, seed
- Recipe matching: specific IDs only, symmetric
- 4 templates: Additive, Merge, Animate, Generator
- Snap trigger: Release-to-snap (Option B)
- During snap zone: rubber-band attraction lerp (attraction_factor = 0.25 default)
- Push-away: stays at release position, bounces off target (push_distance = 40px default)
- Input System signals drive Card Engine (no raw input in Card Engine)
- Audio Manager moved to Vertical Slice

## Open Questions (carry forward)

- File format: JSON vs .tres — decide before Card Engine implementation
- Are combinations one-time or repeatable? — ITF to decide
- Snap position offset (perfect center vs slight offset) — resolve in prototype
- Animate template position ownership — ITF design will resolve
- Z-order during drag — resolve with Card Visual design

## Next Step

Option 1: `/prototype card-engine` — validate the magnetic feel before writing more GDDs
Option 2: `/design-system table-layout-system` — continue GDD chain (#6)
---

## Archived Session State: 20260324_205522
# Session State

**Task**: Card Spawning System GDD — Complete
**File**: design/gdd/card-spawning-system.md

## Progress Checklist

- [x] Card Database — Designed
- [x] Recipe Database — Designed
- [x] Input System — Designed
- [x] Card Engine — Designed
- [x] Table Layout System — Designed
- [x] Card Spawning System — Designed
- [ ] Interaction Template Framework (#8) — Next
- [ ] Status Bar System (#9)
- [ ] Scene Goal System (#10)
- [ ] Hint System (#11)
- [ ] Card Visual (#12)
- [ ] Status Bar UI (#13)

## Key Decisions (Card Spawning)

- Multiple instances of same card_id CAN coexist (Generator produces multiples)
- Instance ID: `card_id + "_" + counter` (e.g. `morning-light_0`)
- Counter never reused — retired on removal
- Card Spawning is sole authority for node instantiation/freeing
- Signals: `card_spawned`, `card_removing`, `card_removed`
- `clear_all_cards()` for scene transitions; queues spawns during Clearing state

## Open Questions (deferred)

- File format: JSON vs .tres for Card/Recipe Databases
- Seed logging UX: console vs. logs/unfixed-seeds.txt
- `get_live_cards(card_id)` query — resolve when ITF is designed
---

## Archived Session State: 20260324_214259
# Session State

**Task**: Interaction Template Framework GDD — Complete
**File**: design/gdd/interaction-template-framework.md

## Progress Checklist

- [x] Card Database — Designed
- [x] Recipe Database — Designed
- [x] Input System — Designed
- [x] Card Engine — Designed (corrected: combination_attempted now uses instance_ids)
- [x] Table Layout System — Designed
- [x] Card Spawning System — Designed
- [x] Interaction Template Framework — Designed
- [ ] Status Bar System (#9) — Next
- [ ] Scene Goal System (#10)
- [ ] Hint System (#11)
- [ ] Card Visual (#12)
- [ ] Status Bar UI (#13)

## Key Decisions (ITF)

- Cooldown: same pair pushes away during cooldown (default 30s), re-fires after
- Animate: Card Engine owns motion per config; ITF passes config in combination_succeeded
- Generator max_count: ITF tracks count internally (no Card Spawning query needed)
- combination_executed signal broadcast after every successful execution
- ITF suspends during scene transitions (ignores combination_attempted)

## Cross-system fix applied

- Card Engine GDD updated: combination_attempted/succeeded/failed now use instance_ids

## Open Questions (deferred)

- Status Bar recipe config: bar-effect data in recipe vs. Status Bar's own lookup?
- combination_executed payload: add card_ids for Mystery Unlock Tree?
- Cooldown scope: global vs. per-scene reset?
- Animate stop condition: can a combination stop an infinite Animate?
---

## Archived Session State: 20260324_225055
# Session State

**Task**: Status Bar System GDD — Complete
**File**: design/gdd/status-bar-system.md

## Progress Checklist

- [x] Card Database — Designed
- [x] Recipe Database — Designed
- [x] Input System — Designed
- [x] Card Engine — Designed
- [x] Table Layout System — Designed
- [x] Card Spawning System — Designed
- [x] Interaction Template Framework — Designed
- [x] Status Bar System — Designed
- [ ] Scene Goal System (#10) — Next
- [ ] Hint System (#11)
- [ ] Card Visual (#12)
- [ ] Status Bar UI (#13)

## Key Decisions (Status Bar System)

- Scene-conditional: dormant until Scene Goal System calls configure()
- Bar effects in separate file: assets/data/bar-effects.json (recipe_id → bar deltas)
- Decay is per-scene configurable (0 = off, authored in scene_bar_config)
- Win condition type: sustain_above for MVP (threshold + duration_sec)
- Signals: bar_values_changed(values_dict), win_condition_met()

## Important architectural note

- Status Bar System is NOT active in every scene — only bar-based goal scenes
- Number of bars is scene-defined (supports 1, 2, or more)
- Scene Goal System is the coordinator that configures and listens to Status Bar System
---

## Session End: 20260325_125530
### Uncommitted Changes
.claude/docs/technical-preferences.md
CLAUDE.md
---

## Session End: 20260325_125636
### Uncommitted Changes
.claude/docs/technical-preferences.md
CLAUDE.md
---

## Session End: 20260325_125843
### Uncommitted Changes
.claude/docs/technical-preferences.md
CLAUDE.md
docs/engine-reference/godot/VERSION.md
---

## Session End: 20260325_130226
### Uncommitted Changes
.claude/docs/technical-preferences.md
CLAUDE.md
docs/engine-reference/godot/VERSION.md
---

## Session End: 20260325_130541
### Uncommitted Changes
.claude/docs/technical-preferences.md
CLAUDE.md
docs/engine-reference/godot/VERSION.md
---

## Session End: 20260325_130827
### Uncommitted Changes
.claude/docs/technical-preferences.md
.gitignore
CLAUDE.md
docs/engine-reference/godot/VERSION.md
---

## Session End: 20260325_131010
### Uncommitted Changes
.claude/docs/technical-preferences.md
.gitignore
CLAUDE.md
docs/engine-reference/godot/VERSION.md
---

## Session End: 20260325_131133
### Uncommitted Changes
.claude/docs/technical-preferences.md
.gitignore
CLAUDE.md
docs/engine-reference/godot/VERSION.md
---

## Session End: 20260325_131225
### Uncommitted Changes
.claude/docs/technical-preferences.md
.gitignore
CLAUDE.md
docs/engine-reference/godot/VERSION.md
---

## Session End: 20260325_131353
### Uncommitted Changes
.claude/docs/technical-preferences.md
.gitignore
CLAUDE.md
docs/engine-reference/godot/VERSION.md
---

## Session End: 20260325_131417
### Uncommitted Changes
.claude/docs/technical-preferences.md
.gitignore
CLAUDE.md
docs/engine-reference/godot/VERSION.md
---

## Session End: 20260325_131757
### Uncommitted Changes
.claude/docs/technical-preferences.md
.gitignore
CLAUDE.md
docs/engine-reference/godot/VERSION.md
---

## Session End: 20260325_132130
### Uncommitted Changes
.claude/docs/technical-preferences.md
.gitignore
CLAUDE.md
docs/engine-reference/godot/VERSION.md
---

## Session End: 20260325_132418
### Uncommitted Changes
.claude/docs/technical-preferences.md
.gitignore
CLAUDE.md
docs/engine-reference/godot/VERSION.md
---

## Session End: 20260325_134355
### Uncommitted Changes
.claude/docs/technical-preferences.md
.gitignore
CLAUDE.md
docs/engine-reference/godot/VERSION.md
---

## Session End: 20260325_134645
### Uncommitted Changes
.claude/docs/technical-preferences.md
.gitignore
CLAUDE.md
docs/engine-reference/godot/VERSION.md
---

## Session End: 20260325_135331
### Uncommitted Changes
.claude/docs/technical-preferences.md
.gitignore
CLAUDE.md
docs/engine-reference/godot/VERSION.md
---

## Session End: 20260325_140059
### Uncommitted Changes
.claude/docs/technical-preferences.md
.gitignore
CLAUDE.md
docs/engine-reference/godot/VERSION.md
---

## Session End: 20260325_140546
### Uncommitted Changes
.claude/docs/technical-preferences.md
.gitignore
CLAUDE.md
docs/engine-reference/godot/VERSION.md
---

## Session End: 20260325_141256
### Uncommitted Changes
.claude/docs/technical-preferences.md
.gitignore
CLAUDE.md
docs/engine-reference/godot/VERSION.md
---

## Session End: 20260325_141523
### Uncommitted Changes
.claude/docs/technical-preferences.md
.gitignore
CLAUDE.md
docs/engine-reference/godot/VERSION.md
---

## Session End: 20260325_142036
### Uncommitted Changes
.claude/docs/technical-preferences.md
.gitignore
CLAUDE.md
docs/engine-reference/godot/VERSION.md
---

## Session End: 20260325_142307
### Uncommitted Changes
.claude/docs/technical-preferences.md
.gitignore
CLAUDE.md
docs/engine-reference/godot/VERSION.md
---

## Session End: 20260327_004430
### Uncommitted Changes
.claude/docs/technical-preferences.md
.gitignore
CLAUDE.md
docs/engine-reference/godot/VERSION.md
---

## Session End: 20260327_005200
### Uncommitted Changes
.claude/docs/technical-preferences.md
.gitignore
CLAUDE.md
docs/engine-reference/godot/VERSION.md
---

## Session End: 20260327_005349
### Uncommitted Changes
.claude/docs/technical-preferences.md
.gitignore
CLAUDE.md
docs/engine-reference/godot/VERSION.md
---

## Session End: 20260327_005504
### Uncommitted Changes
.claude/docs/technical-preferences.md
.gitignore
CLAUDE.md
docs/engine-reference/godot/VERSION.md
---

## Session End: 20260327_010257
### Uncommitted Changes
.claude/docs/technical-preferences.md
.gitignore
CLAUDE.md
docs/engine-reference/godot/VERSION.md
---

## Session End: 20260327_010422
### Uncommitted Changes
.claude/docs/technical-preferences.md
.gitignore
CLAUDE.md
docs/engine-reference/godot/VERSION.md
---

## Session End: 20260327_010532
### Uncommitted Changes
.claude/docs/technical-preferences.md
.gitignore
CLAUDE.md
docs/engine-reference/godot/VERSION.md
---

## Session End: 20260327_010755
### Uncommitted Changes
.claude/docs/technical-preferences.md
.gitignore
CLAUDE.md
docs/engine-reference/godot/VERSION.md
---

## Session End: 20260327_011105
### Uncommitted Changes
.claude/docs/technical-preferences.md
.gitignore
CLAUDE.md
docs/engine-reference/godot/VERSION.md
---

## Session End: 20260327_011239
### Uncommitted Changes
.claude/docs/technical-preferences.md
.gitignore
CLAUDE.md
docs/engine-reference/godot/VERSION.md
---

## Session End: 20260327_011316
### Uncommitted Changes
.claude/docs/technical-preferences.md
.gitignore
CLAUDE.md
docs/engine-reference/godot/VERSION.md
---

## Session End: 20260327_011428
### Uncommitted Changes
.claude/docs/technical-preferences.md
.gitignore
CLAUDE.md
docs/engine-reference/godot/VERSION.md
---

## Session End: 20260327_011513
### Uncommitted Changes
.claude/docs/technical-preferences.md
.gitignore
CLAUDE.md
docs/engine-reference/godot/VERSION.md
---

## Session End: 20260327_011907
### Uncommitted Changes
.claude/docs/technical-preferences.md
.gitignore
CLAUDE.md
docs/engine-reference/godot/VERSION.md
---

## Session End: 20260327_012037
### Uncommitted Changes
.claude/docs/technical-preferences.md
.gitignore
CLAUDE.md
docs/engine-reference/godot/VERSION.md
---

## Session End: 20260327_012242
### Uncommitted Changes
.claude/docs/technical-preferences.md
.gitignore
CLAUDE.md
docs/engine-reference/godot/VERSION.md
---

## Session End: 20260327_213724
### Uncommitted Changes
.claude/docs/technical-preferences.md
.gitignore
CLAUDE.md
docs/engine-reference/godot/VERSION.md
---

## Session End: 20260327_214345
### Uncommitted Changes
.claude/docs/technical-preferences.md
.gitignore
CLAUDE.md
docs/engine-reference/godot/VERSION.md
---

## Session End: 20260327_214915
### Uncommitted Changes
.claude/docs/technical-preferences.md
.gitignore
CLAUDE.md
docs/engine-reference/godot/VERSION.md
---

## Session End: 20260328_010220
### Uncommitted Changes
.claude/docs/technical-preferences.md
.gitignore
CLAUDE.md
docs/engine-reference/godot/VERSION.md
---

## Session End: 20260328_122600
### Uncommitted Changes
.claude/docs/technical-preferences.md
.gitignore
CLAUDE.md
docs/engine-reference/godot/VERSION.md
---

## Session End: 20260328_164349
### Uncommitted Changes
.claude/docs/technical-preferences.md
.gitignore
CLAUDE.md
docs/engine-reference/godot/VERSION.md
---

## Session End: 20260328_165202
### Uncommitted Changes
.claude/docs/technical-preferences.md
.gitignore
CLAUDE.md
docs/engine-reference/godot/VERSION.md
---

## Session End: 20260328_165429
### Uncommitted Changes
.claude/docs/technical-preferences.md
.gitignore
CLAUDE.md
docs/engine-reference/godot/VERSION.md
---

## Session End: 20260328_170007
### Uncommitted Changes
.claude/docs/technical-preferences.md
.gitignore
CLAUDE.md
docs/engine-reference/godot/VERSION.md
---

## Session End: 20260328_170253
### Uncommitted Changes
.claude/docs/technical-preferences.md
.gitignore
CLAUDE.md
docs/engine-reference/godot/VERSION.md
---

## Session End: 20260328_170456
### Uncommitted Changes
.claude/docs/technical-preferences.md
.gitignore
CLAUDE.md
docs/engine-reference/godot/VERSION.md
---

## Session End: 20260328_170544
### Uncommitted Changes
.claude/docs/technical-preferences.md
.gitignore
CLAUDE.md
docs/engine-reference/godot/VERSION.md
---

## Session End: 20260328_170906
### Uncommitted Changes
.claude/docs/technical-preferences.md
.gitignore
CLAUDE.md
docs/engine-reference/godot/VERSION.md
---

## Session End: 20260328_172337
### Uncommitted Changes
.claude/docs/technical-preferences.md
.gitignore
CLAUDE.md
docs/engine-reference/godot/VERSION.md
---

## Session End: 20260328_173312
### Uncommitted Changes
.claude/docs/technical-preferences.md
.gitignore
CLAUDE.md
docs/engine-reference/godot/VERSION.md
---

## Session End: 20260410_131734
### Uncommitted Changes
.claude/docs/technical-preferences.md
.gitignore
CLAUDE.md
docs/engine-reference/godot/VERSION.md
---

## Session End: 20260410_132200
### Uncommitted Changes
.claude/docs/rules-reference.md
.claude/docs/technical-preferences.md
.gitignore
CLAUDE.md
docs/engine-reference/godot/VERSION.md
---

## Session End: 20260410_135225
### Uncommitted Changes
.claude/docs/rules-reference.md
.claude/docs/technical-preferences.md
.gitignore
CLAUDE.md
docs/engine-reference/godot/VERSION.md
---

## Session End: 20260410_135928
## Session End: 20260410_135928
### Uncommitted Changes
### Uncommitted Changes
.claude/docs/rules-reference.md
.claude/docs/technical-preferences.md
.claude/docs/rules-reference.md
.claude/settings.json
.claude/docs/technical-preferences.md
.gitignore
.claude/settings.json
CLAUDE.md
.gitignore
docs/engine-reference/godot/VERSION.md
CLAUDE.md
docs/engine-reference/godot/VERSION.md
---
---


## Session End: 20260410_140312
### Uncommitted Changes
.claude/docs/rules-reference.md
.claude/docs/technical-preferences.md
.claude/settings.json
.gitignore
CLAUDE.md
docs/engine-reference/godot/VERSION.md
---

## Session End: 20260410_140528
### Uncommitted Changes
.claude/docs/rules-reference.md
.claude/docs/technical-preferences.md
.gitignore
CLAUDE.md
docs/engine-reference/godot/VERSION.md
---

## Session End: 20260410_140543
### Uncommitted Changes
.claude/docs/rules-reference.md
.claude/docs/technical-preferences.md
.gitignore
CLAUDE.md
docs/engine-reference/godot/VERSION.md
---

## Session End: 20260410_140627
### Uncommitted Changes
.claude/docs/rules-reference.md
.claude/docs/technical-preferences.md
.gitignore
CLAUDE.md
docs/engine-reference/godot/VERSION.md
---

