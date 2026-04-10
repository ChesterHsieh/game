# Prototype Report: Scene Win

**Date**: 2026-03-27
**Tester**: Chester

---

## Hypothesis

When both bars stay above the threshold for the required hold duration, the scene
completing should feel like a breakthrough — a quiet moment of recognition, not a
"level cleared" reward screen. Cards floating away + a title reveal should feel
personal and earned.

---

## Approach

- Same 3 cards + combination logic as previous prototypes
- `sustain_above` goal: both bars above 60 for 5s (production: 30s)
- Yellow threshold line on bars shows the target
- Golden glow builds on bars while both are held above threshold
- Win sequence: cards float up + fade → title "A Morning Together" fades in → black fade → restart

---

## Result

**Verdict: Looks perfect.**

- Card exit feel: ✓ satisfying
- Title reveal feel: ✓ feels like a discovery moment
- Title hold (2.5s): ✓ right duration
- Golden hold glow: ✓ communicates progress clearly
- Black fade: ✓ reads as scene ending, not crash
- Overall: breakthrough feeling ✓

---

## Validated Tuning Values

| Knob | Value | Status |
|------|-------|--------|
| `CARD_EXIT_DURATION` | 0.9s | Locked |
| `CARD_EXIT_RISE` | 120px | Locked |
| `TITLE_FADE_IN` | 1.2s | Locked |
| `TITLE_HOLD` | 2.5s | Locked |
| `SCENE_FADE_OUT` | 1.2s | Locked |
| `SUSTAIN_THRESHOLD` | 60 / 100 | Locked |
| `SUSTAIN_DURATION` | 30s (production) | Locked |

---

## Recommendation: PROCEED

The win sequence feels like a quiet breakthrough, not a reward screen. The card
float-out clears the table cleanly, the title reveal lands as a personal moment,
and the black fade reads as a scene transition rather than a game-over. The golden
glow on bars during the hold period communicates progress without being intrusive.
All animation timings validated — carry these values directly into production.

---

## If Proceeding

- Connect to real EventBus signals (`win_condition_met`, `scene_completed`)
- Replace hardcoded title with scene name from scene JSON
- Add audio cue on win — silence may feel empty in the full game
- Scene Transition UI owns this animation in production
- Consider whether a "reward card" appears after the title (open question in Scene Goal System GDD)

---

## Lessons Learned

- Bar effects need to be generous (+60) for the win moment to be reachable without frustration
- The golden glow building on bars during the sustain hold is load-bearing — it tells the player "keep going, something is happening"
- Title reveal on black background reads as intimate, not clinical
