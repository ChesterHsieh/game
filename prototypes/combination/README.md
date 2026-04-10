# Prototype: Combination (ITF)

**Core question**: Does combining two cards and seeing a result feel like a discovery?
Does the Merge animation feel like something meaningful happened?

## How to Run

1. Open `prototypes/combination/Main.tscn` in Godot 4.3
2. Press F6 (Run Current Scene)

## Recipes to Test

| Drag | Onto | Template | Result |
|------|------|----------|--------|
| Chester | Ju | **Merge** — both disappear | Morning Together |
| Chester | Home | **Additive** — both stay | Coffee |
| Ju | Home | **Additive** — both stay | Comfort |
| Any unlisted pair | — | **Push-away** | Nothing |

## What to Observe

- **Merge feel**: Do the two cards fading into a new card feel like something happened?
  Or does it feel mechanical / like a UI transition?
- **Additive feel**: Does the result card appearing nearby feel satisfying?
  Or does it feel like it just popped in?
- **Bar feedback**: Do the bars on the right feel connected to the combinations?
  Can you tell which combination affected which bar?
- **Discovery loop**: After a few combinations, does the table feel alive?

## Status Bars (right side)

Two unlabelled bars — blue (Chester) and pink (Ju). Each combination fills them
differently. They decay slowly over time. This tests whether the bar mystery
feels interesting or confusing.

## Fill in REPORT.md after testing.
