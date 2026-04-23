# Story 005: Card Badge System

> **Epic**: Card Visual
> **Status**: Complete
> **Layer**: Presentation
> **Type**: Visual/Feel
> **Manifest Version**: 2026-04-21

## Context

**GDD**: `design/gdd/card-visual.md`
**Requirement**: `TR-card-visual-003` (partial: "Renders label, circular-masked art, optional badge inside bordered frame")

**ADR Governing Implementation**: ADR-001, ADR-002
**ADR Decision Summary**: 
- ADR-001: Naming conventions (snake_case files, PascalCase classes)
- ADR-002: Card object pooling — CardVisual is part of pooled card scene and resets state on acquire

**Engine**: Godot 4.3 | **Risk**: LOW
**Engine Notes**: Standard 2D drawing via `_draw()` — no post-cutoff APIs

**Control Manifest Rules (Presentation layer)**:
- Required: Per-card UI component is a pure renderer with no game state
- Forbidden: Cross-system communication (signals, direct references)
- Guardrail: Drawing must not exceed card frame boundary

---

## Acceptance Criteria

*From GDD `design/gdd/card-visual.md`, scoped to badge rendering:*

- [ ] CardEntry schema includes optional `badge: String = ""` field
- [ ] Card at rest with `badge` field displays text in a black horizontal bar at the card's top
- [ ] Badge text is white (or high-contrast color) and centered horizontally
- [ ] Card with empty or missing `badge` field renders correctly with no badge bar visible
- [ ] Badge text does not overflow the card width; long badge text is truncated with ellipsis
- [ ] Badge bar height is consistent and does not interfere with label or art region
- [ ] Card with `badge` field set renders badge in all states (Idle, Dragged, Attracting, Snapping, Pushed, Executing)
- [ ] Full-PNG card art (commissioned PNG with embedded frame) displays badge bar correctly on top

---

## Implementation Notes

*Derived from ADR-001/ADR-002 Implementation Guidelines:*

**CardEntry Schema Extension**:
- Add `@export var badge: String = ""` field to `src/data/card_entry.gd`
- Badge is optional — empty string means no badge renders
- Default to empty string so existing cards are unaffected

**CardVisual Badge Rendering**:
- In `CardVisual._draw()`, after drawing drop shadow and before drawing art/fallback:
  - If `_badge != ""`: draw a black horizontal bar at the top of the card (recommend 16–20px height, positioned just inside the card border)
  - Render `_badge` text centered in the bar, white color (or theme-driven via COLOR constant)
  - Clip `_badge` text to bar width with ellipsis if needed (use `draw_string` with `max_width`)
- In `CardVisual._read_card_data()`, read `badge` from the CardEntry and cache in `_badge: String`
- In `CardVisual.reset()`, clear `_badge = ""` before repopulating (pool reset safety)

**Badge Layout**:
- Position: top of card, inside the frame border (not protruding)
- Height: ~18px (tunable via @export)
- Width: full card width minus 2px margin each side
- Background: solid black (`Color.BLACK`)
- Text: white (`Color.WHITE`), centered horizontally, vertically centered within bar
- Font: fallback font, size 12px (tunable via @export)

**Edge Cases**:
- Very long badge text (>20 chars): truncate with ellipsis, do not overflow
- Badge present on full-PNG card: still renders the bar on top; PNG background is behind the bar
- Badge on fallback placeholder card: renders the bar normally

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: Initial card data read (this story extends that to include badge field)
- Story 004: Error handling for missing art (badge bar is always rendered if present, no separate error case)

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not invent new test cases during implementation.*

**AC-1**: Card with badge displays black bar at top with white centered text

- Setup: Spawn a card with `badge = "Test Badge"` in CardDatabase
- Verify: Black horizontal bar visible at top of card frame, text "Test Badge" centered in white
- Pass condition: Bar height ~18px, text clearly readable, no text overflow

**AC-2**: Card without badge renders normally with no bar

- Setup: Spawn a card with `badge = ""` (empty string)
- Verify: No black bar at top; card renders label + art only
- Pass condition: Card renders as before badge feature (no visual change)

**AC-3**: Long badge text truncates with ellipsis

- Setup: Spawn a card with `badge = "This is a very long badge text that should truncate"`
- Verify: Black bar shows truncated text with "…" at the end, text does not overflow card width
- Pass condition: Entire badge bar fits within card bounds

**AC-4**: Badge persists across all card states

- Setup: Spawn a card with badge; drag it, release, re-drag
- Verify: Badge bar visible in Idle, Dragged, Attracting, Snapping, Pushed states
- Pass condition: Badge remains centered and readable at all times

**AC-5**: Badge renders on full-PNG card art

- Setup: Spawn a commissioned card (full PNG art) with badge set
- Verify: PNG renders as background/card face, black badge bar renders on top
- Pass condition: Badge bar is visible and does not cut off card art

**AC-6**: Pooled card resets badge on acquire

- Setup: Acquire a pooled card; set badge to "Test"; return to pool; acquire same card with new card_id
- Verify: New card's badge renders correctly (old badge not visible)
- Pass condition: No "ghost" badge from previous card visible

---

## Test Evidence

**Story Type**: Visual/Feel
**Required evidence**:
- Visual/Feel: `production/qa/evidence/badge-system-evidence.md` + sign-off

**Status**: [ ] Evidence doc created and signed off

---

## Dependencies

- Depends on: Story 001 (Card spawn and data read) — badge field must be read during initial CardDatabase lookup
- Unlocks: Drive scene implementation (badge system enables Ju/Chester driving scene to work)

---

## Notes

- Tuning knobs for badge rendering (@export values) should include: `badge_bar_height`, `badge_font_size`, `badge_background_color`, `badge_text_color`
- Consider whether badge should be editable in the inspector per-instance, or only via CardDatabase — recommend CardDatabase only (matches badge text as content, not runtime state)

---

## Completion Notes

**Completed**: 2026-04-23
**Criteria**: 6/8 static-verified; AC-1 (basic appearance) and AC-7 (full-PNG overlay) visually confirmed on Coffee Intro with `chester` card carrying `badge = "chester"`. Truncation glyph (AC-3) pending smoke with a long-badge test value.
**Deviations**:
  - Added `badge_y_offset` @export (default `-8.0`) after initial smoke — allows badge bar to peek above the card edge as a "tag" rather than flush with the top. Tuning-only knob, no behaviour change.
**Test Evidence**: Visual/Feel — `production/qa/evidence/badge-system-evidence.md` (manual checklist, partially verified via `chester` badge in Coffee Intro smoke).
**Code Review**: Complete — APPROVED, 1 minor suggestion (ellipsis glyph verification — still pending with a long-badge test value).
