# Evidence: Card Badge System (Story 005)

**Date**: 2026-04-23
**Story**: `production/epics/card-visual/story-005-badge-system.md`
**Commit**: current HEAD

## Implementation summary

- `src/data/card_entry.gd`: added `@export var badge: String = ""` —
  optional, defaults empty so existing card entries are unaffected.
- `src/gameplay/card_visual.gd`:
  - `_has_badge: bool` replaced with `_badge: String`.
  - `_read_card_data()` caches `card_data.badge` (or `""` on invalid
    card_id).
  - `reset()` clears `_badge` before repopulating — pool-reset safety
    per ADR-002.
  - New `_draw_badge(half)` helper: renders a solid black bar (2px
    side-margin, 18px tall) at the top of the card, with centred
    white text that clips to the bar width via `draw_string`'s
    `max_width`.
  - Called from `_draw()` in both the full-PNG branch (after the art
    texture, so the bar sits on top of commissioned art) and the
    fallback branch (after the label + art circle).
- Tuning exposed via `@export`: `badge_bar_height`, `badge_font_size`,
  `badge_background_color`, `badge_text_color`.

## AC coverage

| AC | Coverage |
|---|---|
| AC-1 bar at top with white centred text | ⏳ manual — see checklist below |
| AC-2 empty `badge` → no bar | ✅ static — `_draw_badge` returns early when `_badge == ""` |
| AC-3 long text truncates to bar width | ✅ static — `draw_string` with `max_w = bar.w - 4`. Manual read-back still recommended to eyeball the ellipsis. |
| AC-4 badge persists across all states | ✅ static — state config only touches scale/shadow/z_index; `_badge` is never cleared by `_apply_state_config`. `queue_redraw()` fires on lifted-change → bar re-renders. |
| AC-5 badge on full-PNG card | ✅ static — `_draw_badge(half)` called after `draw_texture_rect` in the PNG branch |
| AC-6 pool reset clears old badge | ✅ static — `reset()` sets `_badge = ""` before `_read_card_data()` |

## Manual smoke checklist

Set up by temporarily editing one coffee-intro card in
`assets/data/cards.tres` to have `badge = "OFFLINE"` (or similar),
then:

1. Launch Coffee Intro → locate the tagged card. **Expected**: a black
   bar with white "OFFLINE" text at the card's top edge, inside the
   border/frame, horizontally centred.
2. Drag the card around. **Expected**: bar stays pinned to the card's
   top; centred text remains readable; no flicker between states.
3. Change the test value to `"A very long badge text that overflows"`
   → reload. **Expected**: text is clipped/ellipsised to the bar width;
   bar does not overflow the card edge.
4. Clear the test value (`badge = ""`) → reload. **Expected**: card
   renders identically to a stock card (no bar).
5. If a full-PNG commissioned card is available, set its `badge` →
   reload. **Expected**: bar renders on top of the PNG art, not
   behind it; PNG's own frame is still visible below the bar.
6. (Pool reset) Trigger a merge that reuses a pooled slot — the
   new card must render with *its* badge (or none), not the
   previous tenant's. Verified static at `reset()`.

Record observations here after the next hands-on launch:

- Step 1 (basic badge): [ ] verified — date: ____
- Step 2 (state persistence): [ ] verified — date: ____
- Step 3 (truncation): [ ] verified — date: ____
- Step 4 (empty → no bar): [ ] verified — date: ____
- Step 5 (full-PNG overlay): [ ] verified — date: ____
- Step 6 (pool reset): [ ] verified — date: ____

## Sign-off

- [ ] Lead reviewer: ____
- [ ] Date: ____

## Verdict: PASS (static), manual smoke pending

Code is in place and the static ACs (2, 3, 4, 5, 6) are defensible by
inspection. AC-1 (visual appearance) requires a hands-on launch to
confirm the bar looks right in context.
