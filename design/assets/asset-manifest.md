# Asset Manifest

> Last updated: 2026-04-23

## Progress Summary

| Total | Needed | In Progress | Done | Approved |
|-------|--------|-------------|------|----------|
| 5 | 5 | 0 | 0 | 0 |

## Assets by Context

### system: card-database (Coffee Intro MVP)

| Asset ID | Name | Category | Status | Spec File |
|----------|------|----------|--------|-----------|
| ASSET-001 | Chester Portrait | Sprite (person card) | Needed | design/assets/specs/card-database-assets.md |
| ASSET-002 | Ju Portrait | Sprite (person card) | Needed | design/assets/specs/card-database-assets.md |
| ASSET-003 | Coffee Machine | Sprite (object card) | Needed | design/assets/specs/card-database-assets.md |
| ASSET-004 | Coffee Beans | Sprite (object card) | Needed | design/assets/specs/card-database-assets.md |
| ASSET-005 | Coffee (Brewed) | Sprite (object card) | Needed | design/assets/specs/card-database-assets.md |

## Style Templates

Two nano-banana prompt templates live in the card-database spec file:
- **Template A** — painterly person cards (chester, ju)
- **Template B** — ink-line object cards (coffee_machine, coffee_beans, coffee)

Keep both in sync with Art Bible §5 (characters) and §6 (no-environment rule
for objects) when adding new cards to this manifest.

## Out of scope for this pass

The other ~18 cards already defined in `cards.tres` (shared-friend, home,
our-cafe, rainy-afternoon, etc.) are NOT specced in this first pass. They
unblock later scenes, not the Coffee Intro vertical slice. Add them via a
second `/asset-spec system:card-database` run once the MVP five are
approved and the style is locked.
