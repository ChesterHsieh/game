# Prototype: Card Engine

**Core question**: Does the magnetic snap attraction feel right?

## How to Run

1. Open Godot 4.3
2. Open the project at the root of this repo (`project.godot` — create one if needed, or open via `File > Open Project`)
3. Open `prototypes/card-engine/Main.tscn`
4. Press **F5** (or Play Scene / F6)

> If prompted to create a project.godot, click Yes and let Godot initialize
> the project at the repo root. The scene path will be `res://prototypes/card-engine/Main.tscn`.

## What to Test

Drag each card and observe:

| Gesture | Expected feel | Fail condition |
|---------|--------------|----------------|
| Pick up | Card lifts slightly (105% scale) | Card doesn't feel "grabbed" |
| Move near another card | Card drifts toward target | Pull feels sticky / invisible |
| Drop in range | Smooth snap tween (0.12s) | Snap feels instant OR sluggish |
| Push-away (50% random) | Gentle bounce away | Bounce feels violent OR invisible |
| Drop outside range | Card drops in place | Card teleports / stutters |

## Tuning Knobs

All constants are at the top of `card.gd`:

| Constant | Default | What it changes |
|----------|---------|----------------|
| `SNAP_RADIUS` | 80px | How close before pull begins |
| `ATTRACTION_FACTOR` | 0.25 | How strongly the card drifts toward target |
| `SNAP_DURATION` | 0.12s | Speed of the snap tween |
| `PUSH_DISTANCE` | 40px | How far the card bounces on failure |
| `PUSH_DURATION` | 0.18s | Speed of the push-away tween |

Change a value, save, and the scene hot-reloads. No restart needed.

## Recording Results

Fill in `REPORT.md` after testing with your observations on each tuning knob.
The report drives the production Card Engine implementation.
