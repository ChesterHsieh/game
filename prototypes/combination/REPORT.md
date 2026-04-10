# Prototype Report: Combination (ITF)

**Date**: 2026-03-25
**Tester**: Chester

---

## Hypothesis

Combining two cards via Merge (both disappear → result spawns) will feel like a
meaningful moment. Additive (both stay → result spawns nearby) will feel like
discovering a new fact. The status bars will feel mysterious and connected.

---

## Approach

- 3 seed cards (Chester, Ju, Home) + 5 pool cards for results
- 3 hardcoded recipes (Merge × 1, Additive × 2)
- Unrecognised pairs push away
- Two status bars with decay (stand-in for Status Bar System)
- No art — color-coded cards only

---

## Result

- **Merge animation feel**: Too fast at 0.28s → tuned to 0.55s, feels weightier
- **Result card appearing**: Feels earned — the snap-then-vanish-then-appear sequence reads clearly as cause and effect
- **Bar feedback**: Bars were off-screen (hardcoded y=540 didn't match viewport height) — fixed to use `get_visible_rect().size.y`. Still need real playtest of the feel once visible.
- **Push-away on unknown pair**: Feels like "not yet" — reads correctly as a hint that a recipe exists but hasn't been discovered yet

---

## Questions Answered

- [x] Does the Merge animation feel weighty? → Not at 0.28s. 0.55s is better. May need further tuning in production.
- [x] Does the result card appearing feel earned? → Yes. The sequence (attract → snap → merge out → spawn) creates a clear discovery beat.
- [x] Do the bars feel connected? → Inconclusive — bars were off-screen during initial playtest. Architecture is sound; visual position bug fixed.
- [x] Does push-away feel like "not yet"? → Yes. Reads as a soft signal, not a hard error.

---

## Metrics

- MERGE_DURATION winner: **0.55s** (0.28s was too fast)
- Push-away: feels correct at existing tuning (PUSH_DISTANCE=60, PUSH_DURATION=0.18)
- Snap: feels correct at SNAP_DURATION=0.12
- Iteration count: 4 bug fixes before prototype ran (Callable check, return type, pool card visibility, main scene config)

---

## Recommendation: PROCEED

The core discovery loop works. Dragging Chester onto Ju and watching them merge
into "Morning Together" produces a clear, legible moment. The push-away on
unknown pairs reads as mystery rather than error. The bar architecture is sound
even though the visual had a positioning bug. Merge timing at 0.55s feels
appropriately weighty for a personal gift game — not instant, not slow.

The concept is validated. Production implementation should be written from scratch
against the full GDD signal architecture.

---

## If Proceeding

Production differences from prototype:

- Replace hardcoded `RECIPES` dict with Recipe Database + ITF signal flow
- Replace hardcoded `BAR_EFFECTS` dict with bar-effects.json lookup
- Replace drawn bars with Status Bar UI scene (left panel per GDD, not right)
- Add card art (circular crop) per Card Visual GDD
- Use EventBus signals instead of direct Callable callbacks
- Scene Goal System drives win condition instead of prototype bars
- MERGE_DURATION production target: **0.55s** (validated)

---

## Lessons Learned

- Pool cards must start hidden AND be excluded from `_active` array — two separate guards needed
- GDScript `Callable` validity requires `.is_valid()` — `if callable_var:` is always false
- Godot `_draw()` coordinates are in local space — use `get_visible_rect().size` not hardcoded pixel values
- Running the correct scene matters: no main scene configured in project.godot caused silent failures
- Merge at 0.55s > 0.28s for a personal/emotional game — slower reads as more meaningful
