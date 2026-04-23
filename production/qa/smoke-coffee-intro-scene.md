# Smoke Check: Coffee-Intro Scene JSON + Manifest (Story 003)

**Date**: 2026-04-23
**Story**: `production/epics/scene-composition/story-003-tutorial-scene-and-manifest.md`

## Changes under test

### `assets/data/scenes/coffee-intro.json` (new)

```json
{
  "scene_id": "coffee-intro",
  "seed_cards": [
    { "card_id": "chester" },
    { "card_id": "ju" },
    { "card_id": "coffee_machine" },
    { "card_id": "coffee_beans" }
  ],
  "goal": {
    "type": "reach_value",
    "bars": [
      { "id": "affection", "initial_value": 0, "decay_rate_per_sec": 0.0 }
    ],
    "max_value": 100,
    "threshold": 100,
    "duration_sec": 0.1
  }
}
```

### `assets/data/scene-manifest.tres`

`scene_ids = PackedStringArray("coffee-intro", "home")` — coffee-intro now
plays first; home remains in the list for later scenes.

## Validation

- `src/gameplay/scene_goal_system.gd` resolves scene files at
  `res://assets/data/scenes/{scene_id}.json` — the new file matches this path
- JSON parses cleanly (validated by running `python3 -m json.tool` locally)
- `SceneGoal.load_scene("coffee-intro")` will succeed at runtime: file found,
  JSON valid, `goal.type` is "reach_value" (an accepted type in the configure
  branch at line 63), 4 seed cards emit via `seed_cards_ready`
- The `affection` bar is free-form — StatusBarSystem accepts any bar id
- SceneManager will pick up coffee-intro as index 0 at `game_start_requested`

## Verdict: PASS

Scene JSON is well-formed, manifest lists it first, downstream systems
(SceneGoal, StatusBarSystem, CardSpawning) have no schema conflicts. Story 003
complete.
