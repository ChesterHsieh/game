# Epics Index

> **Last Updated**: 2026-04-22
> **Engine**: Godot 4.3 (pinned 2026-03-25; risk LOW)
> **Phase**: Pre-Production (entered 2026-04-21 via `/gate-check pre-production` PASS)
> **Layers Processed**: Foundation (4/4 epics Ready), Core (3/3 epics Ready), Feature (6/6 epics Ready), Presentation (5/5 epics Ready)
> **Next Layer**: All layers complete — begin `/create-stories` per epic

## Processing Order

Process in dependency-safe layer order: **Foundation → Core → Feature → Presentation**.

Within the Foundation layer, CardDatabase is the natural first story (pure data,
no dependencies). RecipeDatabase depends on CardDatabase (load-time ID validation).
InputSystem and AudioManager are independent and can parallelize after the data
layer lands.

Within the Core layer, TableLayoutSystem is stateless and has no runtime dependencies
beyond CardDatabase (soft). CardEngine depends on InputSystem signals. CardSpawningSystem
depends on CardDatabase. All three can begin once Foundation stories are Done.

## Epics

| # | Epic | Layer | System | GDD | Governing ADRs | TRs | Stories | Status |
|---|------|-------|--------|-----|----------------|-----|---------|--------|
| 1 | [card-database](card-database/EPIC.md) | Foundation | CardDatabase | `card-database.md` | ADR-001, ADR-005 | 11 | 7 stories | Ready |
| 2 | [recipe-database](recipe-database/EPIC.md) | Foundation | RecipeDatabase | `recipe-database.md` | ADR-001, ADR-005 | 12 | 7 stories | Ready |
| 3 | [input-system](input-system/EPIC.md) | Foundation | InputSystem | `input-system.md` | ADR-001, ADR-003 | 14 | 5 stories | Ready |
| 4 | [audio-manager](audio-manager/EPIC.md) | Foundation | AudioManager | `audio-manager.md` | ADR-001, ADR-003, ADR-004, ADR-005 | 20 | 8 stories | Ready |
| 5 | [card-engine](card-engine/EPIC.md) | Core | CardEngine | `card-engine.md` | ADR-002, ADR-001, ADR-003 | 20 | 4 stories | Ready |
| 6 | [table-layout-system](table-layout-system/EPIC.md) | Core | TableLayoutSystem | `table-layout-system.md` | ADR-001, ADR-002, ADR-003 | 17 | 3 stories | Ready |
| 7 | [card-spawning-system](card-spawning-system/EPIC.md) | Core | CardSpawningSystem | `card-spawning-system.md` | ADR-002, ADR-001, ADR-003, ADR-004 | 18 | 3 stories | Ready |
| 8 | [interaction-template-framework](interaction-template-framework/EPIC.md) | Feature | InteractionTemplateFramework | `interaction-template-framework.md` | ADR-003, ADR-001, ADR-005 | 16 | 4 stories | Ready |
| 9 | [status-bar-system](status-bar-system/EPIC.md) | Feature | StatusBarSystem | `status-bar-system.md` | ADR-005, ADR-001, ADR-003, ADR-004 | 12 | 3 stories | Ready |
| 10 | [scene-goal-system](scene-goal-system/EPIC.md) | Feature | SceneGoalSystem | `scene-goal-system.md` | ADR-005, ADR-001, ADR-003, ADR-004 | 12 | 3 stories | Ready |
| 11 | [hint-system](hint-system/EPIC.md) | Feature | HintSystem | `hint-system.md` | ADR-005, ADR-001, ADR-003, ADR-004 | 12 | 3 stories | Ready |
| 12 | [scene-manager](scene-manager/EPIC.md) | Feature | SceneManager | `scene-manager.md` | ADR-004, ADR-001, ADR-003, ADR-005 | 20 | 4 stories | Ready |
| 13 | [mystery-unlock-tree](mystery-unlock-tree/EPIC.md) | Feature | MysteryUnlockTree | `mystery-unlock-tree.md` | ADR-005, ADR-001, ADR-003, ADR-004 | 20 | 3 stories | Ready |
| 14 | [card-visual](card-visual/EPIC.md) | Presentation | CardVisual | `card-visual.md` | ADR-002, ADR-001, ADR-003 | 11 | 4 stories | Ready |
| 15 | [status-bar-ui](status-bar-ui/EPIC.md) | Presentation | StatusBarUI | `status-bar-ui.md` | ADR-001, ADR-003 | 11 | 4 stories | Ready |
| 16 | [scene-transition-ui](scene-transition-ui/EPIC.md) | Presentation | SceneTransitionUI | `scene-transition-ui.md` | ADR-004, ADR-001, ADR-003, ADR-005 | 15 | 6 stories | Ready |
| 17 | [main-menu](main-menu/EPIC.md) | Presentation | MainMenu | `main-menu.md` | ADR-001, ADR-003, ADR-004 | 12 | 4 stories | Ready |
| 18 | [final-epilogue-screen](final-epilogue-screen/EPIC.md) | Presentation | FinalEpilogueScreen | `final-epilogue-screen.md` | ADR-004, ADR-001, ADR-003 | 14 | 5 stories | Ready |
| 19 | [scene-composition](scene-composition/EPIC.md) | Presentation+Content | gameplay.tscn + Coffee Intro | (content) | ADR-004, ADR-005 | n/a | 5 stories | Ready |

**Foundation subtotal**: 4 epics, 57 TRs, 0 untraced.
**Core subtotal**: 3 epics, 55 TRs, 0 untraced.
**Feature subtotal**: 6 epics, 92 TRs, 0 untraced.
**Presentation subtotal**: 5 epics, 63 TRs, 0 untraced.

## Infrastructure Not Covered by Epics

**EventBus** — declared in ADR-003 as the 30-signal autoload contract. Has no
dedicated GDD (pure architectural infrastructure). EventBus should be implemented
as the first story inside the first Foundation epic worked on (recommended:
card-database), or as a stand-alone spike story before epic decomposition begins.
Reference: `docs/architecture/adr-0003-signal-bus.md` lines 27–85 for the full
signal declaration table.

## Next Steps

1. ✅ All 4 Foundation epics decomposed into 27 stories total
2. ✅ All 3 Core epics decomposed: card-engine (4), table-layout-system (3), card-spawning-system (3) = 10 stories
3. ✅ All 6 Feature epics decomposed: ITF (4), SBS (3), SGS (3), HintSystem (3), SceneManager (4), MUT (3) = 20 stories
4. ✅ All 5 Presentation epics decomposed: CardVisual (4), StatusBarUI (4), SceneTransitionUI (6), MainMenu (4), FinalEpilogueScreen (5) = 23 stories total
5. `/story-readiness` → `/dev-story` per story to begin implementation (Foundation stories are unblocked now)
6. Or `/sprint-plan` to plan implementation order across all 80 stories

## History

| Date | Event |
|---|---|
| 2026-04-21 | Foundation-layer epics created via `/create-epics layer: foundation` (lean mode, PR-EPIC gate skipped per protocol) |
| 2026-04-21 | All 4 Foundation epics decomposed: card-database (7), recipe-database (7), input-system (5), audio-manager (8) = 27 stories total |
| 2026-04-22 | Core-layer epics created via `/create-epics layer: core` (lean mode, PR-EPIC gate skipped per protocol) — card-engine (20 TRs), table-layout-system (17 TRs), card-spawning-system (18 TRs) |
| 2026-04-22 | All 3 Core epics decomposed: card-engine (4), table-layout-system (3), card-spawning-system (3) = 10 stories total |
| 2026-04-22 | Feature-layer epics created via `/create-epics layer: feature` (lean mode, PR-EPIC gate skipped per protocol) — interaction-template-framework (16 TRs), status-bar-system (12 TRs), scene-goal-system (12 TRs), hint-system (12 TRs), scene-manager (20 TRs), mystery-unlock-tree (20 TRs) |
| 2026-04-22 | Presentation-layer epics created via `/create-epics layer: presentation` (lean mode, PR-EPIC gate skipped per protocol) — card-visual (11 TRs), status-bar-ui (11 TRs), scene-transition-ui (15 TRs), main-menu (12 TRs), final-epilogue-screen (14 TRs) = 63 TRs, 0 untraced |
| 2026-04-22 | All 6 Feature epics decomposed: ITF (4), SBS (3), SGS (3), HintSystem (3), SceneManager (4), MUT (3) = 20 stories total |
| 2026-04-22 | All 5 Presentation epics decomposed (parallel agents): CardVisual (4), StatusBarUI (4), SceneTransitionUI (6), MainMenu (4), FinalEpilogueScreen (5) = 23 stories total — all 18 epics fully decomposed (80 stories) |
