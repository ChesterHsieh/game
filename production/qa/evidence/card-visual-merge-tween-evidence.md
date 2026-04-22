# QA Evidence: Card Visual — Merge tween animation

> **Story**: card-visual/story-003-merge-tween-animation.md
> **Type**: Visual/Feel
> **Status**: [ ] Pending sign-off
> **Evidence Gate**: ADVISORY

---

## Setup

1. Open the project in Godot 4.3 and run `gameplay.tscn` (or the current play scene).
2. Confirm `CardEngine.MERGE_DURATION_SEC` is the default (0.55 s) — all timing
   assertions below assume this default. Note: this constant is defined in
   `src/gameplay/card_engine.gd` and is the single source of truth.
3. Ensure at least two cards with a known Merge recipe are on the table.

---

## Test Cases

### AC-1 — Merge animation: scale and opacity reach zero simultaneously

**Steps:**
1. Set up a valid Merge combination on the table.
2. Execute the combination so Card Engine drives both cards to the midpoint and
   transitions them to `Executing` (Merge template).

**Verify:**
- Both cards simultaneously shrink from full size to a point (scale → Vector2.ZERO).
- Both cards simultaneously fade from fully opaque to fully transparent (modulate.a → 0.0).
- The animation duration matches `MERGE_DURATION_SEC` (default 0.55 s) within one frame (~16 ms tolerance).
- After the animation completes, both cards are no longer visible on the table.
- No card geometry (border, art, label) remains visible after the tween finishes.

**Pass Condition:**
- `scale` reaches `Vector2(0, 0)` and `modulate.a` reaches `0.0` at the same moment.
- No card is visible after tween completion.
- Duration matches `MERGE_DURATION_SEC` within one frame.

**Screenshot / recording placeholder:**
`[ merge-animation-start.png — card at full size ]`
`[ merge-animation-mid.png — card at ~50% scale / opacity ]`
`[ merge-animation-end.png — table with no card geometry visible ]`

---

### AC-2 — Interrupted merge leaves no visual artifact

**Steps:**
1. Trigger a Merge combination.
2. Before `MERGE_DURATION_SEC` has elapsed (e.g. at the ~50% mark — ~0.28 s into
   the animation), trigger a scene transition or manually call
   `card_visual.cancel_merge()` in the Godot remote debugger.

**Verify:**
- The tween stops immediately when `cancel_merge()` is called.
- The card is either removed cleanly from the table or returned to the pool with
  `scale = Vector2(1.0, 1.0)` and `modulate.a = 1.0`.
- No "ghost" card is visible at partial scale or partial opacity anywhere on screen.
- Inspecting the scene tree shows no orphaned card node at an abnormal visual state.

**Pass Condition:**
- After the interruption, no card geometry at non-zero partial scale or partial opacity
  is visible anywhere on screen.
- `CardVisual.cancel_merge()` restores `scale` and `modulate.a` to defaults before
  pool return.

**Screenshot / recording placeholder:**
`[ merge-interrupted-mid.png — moment of interruption ]`
`[ merge-interrupted-after.png — table after interruption, no ghost card ]`

---

## Implementation Note

`CardEngine._animate_merge_card()` currently drives the merge tween directly on the
card's `Node2D` (`scale`, `modulate:a`, `position`). `CardVisual.play_merge_tween()`
is the Presentation-layer entry point for future CardSpawning pool integration.
`cancel_merge()` kills any active `_merge_tween` and resets `scale` and `modulate.a`.
Both methods are tested via `card_visual_fallbacks_test.gd` pool-reset cases.

---

## Sign-off

- [ ] Tester name: _______________
- [ ] Date: _______________
- [ ] All 2 ACs pass: [ ] Yes / [ ] No (note failures below)

**Failures / notes:**

_None recorded._
