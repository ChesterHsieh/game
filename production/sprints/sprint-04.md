# Sprint 04 — Presentation Layer

**Status**: Complete
**Started**: 2026-03-27
**Goal**: Visible cards and status bars — first playable moment

## Deliverables

| # | Deliverable | File(s) | Status |
|---|-------------|---------|--------|
| 1 | CardEngine public state accessor | `src/gameplay/card_engine.gd` | [x] |
| 2 | Card Visual component | `src/gameplay/card_visual.gd` | [x] |
| 3 | Card node scene update | `src/gameplay/card_node.tscn` | [x] |
| 4 | Status Bar UI script | `src/ui/status_bar_ui.gd` | [x] |
| 5 | Status Bar UI scene | `src/ui/status_bar_ui.tscn` | [x] |

## GDDs Implemented

- `design/gdd/card-visual.md`
- `design/gdd/status-bar-ui.md`

## Decisions

- Card Visual is a Node2D child of card_node — inherits position/scale from parent
- Shadow and art rendered via `_draw()`; label uses `draw_string` with fallback font
- Art circular crop deferred (no shader configured) — placeholder circle for MVP
- Bar fill and arc drawn via `_draw()` in StatusBarUI; tweens drive `_fill_values` and `_arc_opacity`
- Bars stacked vertically in left panel (decision: stacked, matches narrow panel width)
- Status Bar UI lives in `src/ui/` (new directory, created with first file)
