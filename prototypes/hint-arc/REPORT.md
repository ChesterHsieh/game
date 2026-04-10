# Prototype Report: Hint Arc

**Date**: 2026-03-27
**Tester**: Chester

---

## Hypothesis

A counterclockwise arc fading in around the status bars after a period of
inactivity will feel like a gentle, wordless nudge — not a spoiler. Two levels
(faint → full) will give the player a chance to notice before the hint becomes
obvious.

---

## Approach

- Same 3 cards and combination logic as combination prototype
- Stagnation timer compressed to 6s (production default: 300s)
- Level 1 at 6s (ARC_ALPHA_L1 = 0.45), Level 2 at 12s (ARC_ALPHA_L2 = 0.90)
- Glow drawn as tight frame + soft halo around each bar
- BarLayer Node2D draws on top of Background (draw order fix)
- Any combination resets timer and fades glow out

---

## Status: DEFERRED

Hint arc feel requires real content and a real scene goal to evaluate properly.
Isolated testing doesn't give enough signal — the glow needs to appear after
genuine stagnation, not a compressed 6s timer.

**Re-evaluate after**: Status Bar UI, Scene Goal System, and first playable scene
are implemented. Run a full session and observe whether the glow reads as a nudge
or noise in context.

---

## Current Tuning (locked for now)

| Knob | Value | Notes |
|------|-------|-------|
| `HINT_DELAY` | 300s (production) / 6s (debug) | Compressed for testing only |
| `ARC_ALPHA_L1` | 0.45 | Faint — first nudge |
| `ARC_ALPHA_L2` | 0.90 | Full — clear signal |
| `HINT_FADE_IN` | 1.5s | Lerp speed |
| Glow shape | Tight frame + soft halo around bar | Circle was visual noise; frame reads as "this bar" |

---

## Lessons Learned

- Drawing in Node2D `_draw()` is painted BEFORE children — a child ColorRect
  will cover it. Use a dedicated Node2D as the last scene child for overlay drawing.
- A circle around a tall narrow bar reads as decoration, not direction.
  A tight frame directly around the bar reads as "look at this."
- Hint arc feel cannot be validated in isolation — needs real stagnation context.

---

## Recommendation: PROCEED (conditional)

Shape and draw order are solved. Timing and opacity TBD — re-evaluate in a
full playtest session once the first complete scene is playable.
