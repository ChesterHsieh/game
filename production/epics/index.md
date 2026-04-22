# Epics Index

> **Last Updated**: 2026-04-21
> **Engine**: Godot 4.3 (pinned 2026-03-25; risk LOW)
> **Phase**: Pre-Production (entered 2026-04-21 via `/gate-check pre-production` PASS)
> **Layers Processed**: Foundation (4/4 epics Ready)
> **Next Layer**: Core — run `/create-epics layer: core` after Foundation stories land

## Processing Order

Process in dependency-safe layer order: **Foundation → Core → Feature → Presentation**.

Within the Foundation layer, CardDatabase is the natural first story (pure data,
no dependencies). RecipeDatabase depends on CardDatabase (load-time ID validation).
InputSystem and AudioManager are independent and can parallelize after the data
layer lands.

## Epics

| # | Epic | Layer | System | GDD | Governing ADRs | TRs | Stories | Status |
|---|------|-------|--------|-----|----------------|-----|---------|--------|
| 1 | [card-database](card-database/EPIC.md) | Foundation | CardDatabase | `card-database.md` | ADR-001, ADR-005 | 11 | 7 stories | Ready |
| 2 | [recipe-database](recipe-database/EPIC.md) | Foundation | RecipeDatabase | `recipe-database.md` | ADR-001, ADR-005 | 12 | 7 stories | Ready |
| 3 | [input-system](input-system/EPIC.md) | Foundation | InputSystem | `input-system.md` | ADR-001, ADR-003 | 14 | 5 stories | Ready |
| 4 | [audio-manager](audio-manager/EPIC.md) | Foundation | AudioManager | `audio-manager.md` | ADR-001, ADR-003, ADR-004, ADR-005 | 20 | 8 stories | Ready |

**Foundation subtotal**: 4 epics, 57 TRs, 0 untraced.

## Infrastructure Not Covered by Epics

**EventBus** — declared in ADR-003 as the 30-signal autoload contract. Has no
dedicated GDD (pure architectural infrastructure). EventBus should be implemented
as the first story inside the first Foundation epic worked on (recommended:
card-database), or as a stand-alone spike story before epic decomposition begins.
Reference: `docs/architecture/adr-0003-signal-bus.md` lines 27–85 for the full
signal declaration table.

## Next Steps

1. ✅ All 4 Foundation epics decomposed into 27 stories total
2. `/story-readiness` → `/dev-story` per story to begin implementation (start with card-database story-001)
3. After Foundation stories are `Done`: `/create-epics layer: core` (CardEngine, TableLayoutSystem, CardSpawningSystem)

## History

| Date | Event |
|---|---|
| 2026-04-21 | Foundation-layer epics created via `/create-epics layer: foundation` (lean mode, PR-EPIC gate skipped per protocol) |
| 2026-04-21 | All 4 Foundation epics decomposed: card-database (7), recipe-database (7), input-system (5), audio-manager (8) = 27 stories total |
