# Prototype Report: Card Engine

**Date**: [fill in after testing]
**Tester**: Chester

---

## Hypothesis

Magnetic snap attraction with `ATTRACTION_FACTOR = 0.25` and `SNAP_DURATION = 0.12s`
will feel physically satisfying — like picking up an object with weight that "knows"
when another card is nearby.

---

## Approach

Built a minimal 3-card prototype in Godot 4.3 with:
- Drag via mouse offset tracking
- Attraction lerp when within `SNAP_RADIUS`
- Snap tween on release in-range
- 50/50 push-away / stay on snap complete (tests both paths without needing ITF)
- All tuning constants exposed at the top of `card.gd`

Shortcuts taken:
- No art (colored rectangles with circle placeholder)
- No recipe system (random success/fail)
- No Card Database (card labels hardcoded in scene)
- No EventBus (direct method calls, fine for single-script prototype)

---

## Result

- Pick-up feel: Good — 105% scale communicates "lifted"
- Attraction pull: 0.4 feels right — noticeable without feeling sticky
- Snap tween: 0.12s feels satisfying — not instant, not sluggish
- Push-away: 60px travel at 0.18s — rejection is clear and readable
- Overall: Core feel validates. Proceed to production implementation.

---

## Tuning Log

| Knob | Tried | Winner | Notes |
|------|-------|--------|-------|
| `ATTRACTION_FACTOR` | 0.25, 0.4 | 0.4 | 0.25 felt too subtle; 0.4 feels right |
| `SNAP_RADIUS` | 80 (default) | 80 | Not tested — default feels reasonable |
| `SNAP_DURATION` | 0.12 (default) | 0.12 | Feels right, no change needed |
| `PUSH_DISTANCE` | 40, 60 | 60 | 40 felt too subtle; 60 makes the rejection clear |
| `PUSH_DURATION` | 0.18 (default) | 0.18 | Feels right, no change needed |

---

## Recommendation: PROCEED

---

## If Proceeding

Values to carry into production Card Engine implementation:

```
SNAP_RADIUS       = 80.0
ATTRACTION_FACTOR = 0.4
SNAP_DURATION     = 0.12
PUSH_DISTANCE     = 60.0
PUSH_DURATION     = 0.18
```

Production differences from prototype:
- Replace random success/fail with `combination_attempted` signal → ITF response
- Replace direct method calls with EventBus signals
- Add merge animation (scale + fade tween) for Merge template
- Add z-order management per Card Engine GDD
- Card Database integration for real labels and art

---

## Lessons Learned

[Fill in after testing — discoveries that affect other systems]
