# QA Evidence: Card Visual — State-driven visual config

> **Story**: card-visual/story-002-state-driven-visual-config.md
> **Type**: Visual/Feel
> **Status**: [ ] Pending sign-off
> **Evidence Gate**: ADVISORY

---

## Setup

1. Open the project in Godot 4.3 and run `gameplay.tscn` (or the current play scene).
2. Ensure at least two cards are on the table.
3. Confirm `CardEngine.MERGE_DURATION_SEC` is the default (0.55 s) — no tuning changes needed for this test.

---

## Test Cases

### AC-1 — Dragging lifts the card instantly

**Steps:**
1. Observe a card at rest on the table (Idle state — 100% scale, no shadow).
2. Click and hold the card to begin dragging.

**Verify:**
- The card visibly enlarges to ~105% of its rest size on the same frame the drag starts.
- A drop shadow appears beneath the card frame simultaneously.
- No delay or animation is visible between click and the visual change.

**Pass Condition:** Scale and shadow change occur on the same frame as drag start.

**Screenshot placeholder:**
`[ drag-start-frame.png — attach here ]`

---

### AC-2 — Releasing outside a snap zone restores instantly

**Steps:**
1. Drag a card to an empty area of the table.
2. Release the mouse button.

**Verify:**
- The card immediately returns to 100% scale.
- The drop shadow disappears simultaneously.
- No gradual scale-down or shadow fade is visible.

**Pass Condition:** Scale and shadow restore instantaneously on drag release.

**Screenshot placeholder:**
`[ drag-release-idle.png — attach here ]`

---

### AC-3 — Attracting state matches Dragged appearance

**Steps:**
1. Drag a card close enough to another card to trigger magnetic attraction (card enters Attracting state).
2. Observe both cards.

**Verify:**
- The dragged card's scale and shadow remain identical to the Dragged state.
- No secondary ring, glow, or indicator appears on either card beyond the existing scale and shadow.

**Pass Condition:** Dragged and Attracting states are visually indistinguishable.

**Screenshot placeholder:**
`[ attracting-state-comparison.png — attach here ]`

---

### AC-4 — Pushed state renders at 100% with no shadow

**Steps:**
1. Trigger a failed combination to push a card away.
2. Observe the pushed card throughout and after the push-away tween.

**Verify:**
- The pushed card renders at 100% scale throughout the push.
- No shadow appears on the pushed card.
- After the push-away tween completes the card is visually identical to an Idle card.

**Pass Condition:** Pushed card is visually identical to Idle except for its position.

**Screenshot placeholder:**
`[ pushed-state.png — attach here ]`

---

### AC-5 — Dragged card renders above all others

**Steps:**
1. Drag a card so that it overlaps at least two other cards on the table.

**Verify:**
- The dragged card's frame, art, label, and border are fully visible above all other cards.
- No other card's elements are drawn on top of the dragged card at any point.

**Pass Condition:** Dragged card is topmost at all times during drag.

**Screenshot placeholder:**
`[ drag-z-order-above.png — attach here ]`

---

### AC-6 — Z-order restores after releasing to Idle

**Steps:**
1. Drag a card over another card whose authored z-order is higher.
2. Release the card (Idle transition).

**Verify:**
- After release the released card's z-order returns to its pre-drag authored position.
- Cards with a higher authored z-order may now render in front of the released card.

**Pass Condition:** Released card's rendering order matches its authored table position.

**Screenshot placeholder:**
`[ z-order-restored.png — attach here ]`

---

## Sign-off

- [ ] Tester name: _______________
- [ ] Date: _______________
- [ ] All 6 ACs pass: [ ] Yes / [ ] No (note failures below)

**Failures / notes:**

_None recorded._
