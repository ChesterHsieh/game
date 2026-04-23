# Epic: Scene Composition — Coffee Intro (Vertical Slice)

> **Layer**: Presentation + Content
> **GDD**: (content-level epic — references existing scene-manager, card-database, recipe-database GDDs)
> **Architecture Module**: `src/scenes/gameplay.tscn` + tutorial scene data
> **Status**: Ready
> **Stories**: 5

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | [Tutorial seed cards](story-001-tutorial-seed-cards.md) | Config/Data | Ready | ADR-005 |
| 002 | [Tutorial recipes + bar effects](story-002-tutorial-recipes.md) | Config/Data | Ready | ADR-005 |
| 003 | [Tutorial scene JSON + manifest](story-003-tutorial-scene-and-manifest.md) | Config/Data | Ready | ADR-005 |
| 004 | [Compose gameplay.tscn](story-004-gameplay-tscn-composition.md) | Integration | Ready | ADR-004 |
| 005 | [Vertical Slice playtest](story-005-vertical-slice-playtest.md) | Integration | Ready | ADR-004 |
| 006 | [Ambient Indicator render](story-006-ambient-indicator-render.md) | Integration | Ready | ADR-004 |

## Overview

This epic composes the first playable scene — the "Coffee Intro" tutorial —
and wires together the game's first end-to-end loop. Every Presentation-layer
epic up to this point deferred the composition of `gameplay.tscn` (the sibling
CanvasLayer hierarchy from ADR-004 §2). This epic completes that work by
instancing StatusBarUI, SceneTransitionUI, and FinalEpilogueScreen into a
single scene that MainMenu transitions to.

**Scene design**: 4 seed cards (Ju, Chester, coffee_machine, coffee_beans). The
player discovers 2 recipes: coffee_machine + coffee_beans → coffee, and then
coffee + Ju → scene complete. Chester is present as an ambient narrative card
seeding future scenes. The scene is intentionally tiny — it exists to teach the
drag-to-combine mechanic and to satisfy the Vertical Slice validation required
by the Pre-Production → Production phase gate.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-004: Runtime Scene Composition | `gameplay.tscn` pre-instances sibling CanvasLayers at z=0/5/10/15/20; gameplay_root.gd emits `game_start_requested` after `_ready()` | LOW |
| ADR-005: Data File Format | Scene JSON at `assets/data/scenes/coffee-intro.json`; cards and recipes in the existing `.tres` manifests; bar effects in `bar-effects.json` | LOW |

## GDD Requirements

This epic does not own new TR-IDs. It integrates already-covered requirements
from scene-manager (TR-scene-manager-002/003 scene load), card-database
(TR-card-database-001 load time), and scene-goal-system (TR-scene-goal-system-002
reach_value goal) into a single playable scene.

## Definition of Done

- All 5 stories Complete
- `src/scenes/gameplay.tscn` exists and runs from MainMenu → Start
- Player can drag-combine the 4 seed cards to produce coffee and win the scene
- `production/playtests/vertical-slice-001.md` through `-003.md` exist with
  notes from ≥3 independent sessions (per Pre-Production → Production gate)
- Re-running `/gate-check production` moves past the Vertical Slice Validation
  section

## Next Step

Run `/story-readiness production/epics/scene-composition/story-001-tutorial-seed-cards.md`
to begin the tutorial-data pass. Stories 001–003 are pure data edits and can be
done in parallel. Story 004 (gameplay.tscn composition) unlocks Story 005
(playtest).
