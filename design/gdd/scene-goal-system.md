# Scene Goal System

> **Status**: In Design
> **Author**: Chester + Claude
> **Last Updated**: 2026-03-24
> **Implements Pillar**: Discovery Without Explanation

## Overview

The Scene Goal System is the per-scene configuration and completion authority. When
a scene loads, it reads the authored scene data — the goal type, bar configuration,
and seed card list — and activates all scene-level systems by passing them their
configuration. It tells the Status Bar System which bars to track and what "winning"
means for this scene. It listens for `win_condition_met()` from the Status Bar System
and, when it fires, triggers the scene completion sequence. Every scene in Moments
has a different goal — sustain two bars, find a key combination, trigger a sequence
— and the Scene Goal System is what makes that variety possible without code changes
per scene.

## Player Fantasy

The Scene Goal System is the system she never sees. What she sees is a table of
cards, two unlabelled bars, and a quiet question: *what am I doing here?* The
answer is planted — authored by Chester for this specific scene — but she has to
find it herself. The Scene Goal System is successful when the goal feels like it
was always obvious in hindsight. When the bars finally hold steady and the scene
resolves, it shouldn't feel like she completed a level. It should feel like she
understood something. The system doesn't congratulate her. It just changes — the
table shifts, a card appears, a door opens. The discovery was hers. The system
was just waiting.

## Detailed Design

### Core Rules

1. Scene Goal System reads per-scene configuration from `assets/data/scenes/[scene_id].json`.
   The JSON contains: `scene_id`, `seed_cards[]`, and a `goal` block whose structure depends
   on goal type.
2. Scene Goal System exposes one method: `load_scene(scene_id)`. This is called by Scene
   Manager when a scene begins.
3. On `load_scene(scene_id)`:
   - Parse scene JSON for `scene_id`
   - If goal type uses bars (`sustain_above`, `reach_value`): call
     `StatusBarSystem.configure(scene_bar_config)` — constructed from the `goal` block
   - If goal type does NOT use bars (`find_key`, `sequence`): do not call
     `StatusBarSystem.configure()` — Status Bar System stays Dormant
   - Emit `seed_cards_ready(seed_cards[])` — Scene Manager listens and spawns the seed cards
   - Enter `Active` state
4. Scene Goal System monitors the active goal:
   - **`sustain_above`** (MVP): Passive — relies entirely on Status Bar System. Listens for
     `win_condition_met()`. No per-frame processing.
   - **`find_key`** (stub, Vertical Slice): Listens to ITF's `combination_executed(recipe_id, template, instance_id_a, instance_id_b, card_id_a, card_id_b)`. When `recipe_id == goal.key_recipe_id`, goal is met. SGS reads only `recipe_id` but MUST declare the full 6-param handler (Godot 4.3 arity-strict).
   - **`sequence`** (stub, Vertical Slice): Listens to ITF's `combination_executed` (same 6-param handler). Tracks
     position in `goal.steps[]`. Advances on each matching recipe in order. Goal met when all
     steps complete.
   - **`reach_value`** (stub, Vertical Slice): Configured via Status Bar System same as
     `sustain_above` but with `duration_sec: 0` — bar hits threshold once, no hold required.
5. On goal met: emit `scene_completed(scene_id)`. Enter `Complete` state. Stop all goal
   monitoring.
6. Scene Goal System resets to `Idle` when Scene Manager calls `reset()` after transition
   completes.

**Scene JSON format (`sustain_above`):**
```json
{
  "scene_id": "home",
  "seed_cards": ["chester", "ju"],
  "goal": {
    "type": "sustain_above",
    "bars": [
      { "id": "chester", "initial_value": 20, "decay_rate_per_sec": 0.5 },
      { "id": "ju",      "initial_value": 20, "decay_rate_per_sec": 0.5 }
    ],
    "max_value": 100,
    "threshold": 60,
    "duration_sec": 30
  }
}
```

**`scene_bar_config` constructed and passed to Status Bar System:**
```
{
  bars: goal.bars,
  max_value: goal.max_value,
  win_condition: { type: "sustain_above", threshold: goal.threshold, duration_sec: goal.duration_sec }
}
```

### States and Transitions

| State | Entry | Exit | Behavior |
|-------|-------|------|----------|
| `Idle` | Default; after `reset()` called | `load_scene()` called | No monitoring. Scene JSON not loaded. |
| `Active` | `load_scene()` completes | Goal condition met | Monitoring active goal; Status Bar configured (if bar goal) |
| `Complete` | Goal condition met | `reset()` called by Scene Manager | `scene_completed` emitted; monitoring stopped |

### Interactions with Other Systems

| System | Direction | Interface |
|--------|-----------|-----------|
| **Scene Manager** | Called by; listens to | Scene Manager calls `load_scene(scene_id)` and `reset()`. Scene Goal System emits `seed_cards_ready(seed_cards[])` and `scene_completed(scene_id)` — Scene Manager listens to both. |
| **Status Bar System** | Calls; listens to | Calls `StatusBarSystem.configure(scene_bar_config)` on `load_scene()` for bar-type goals. Listens to `win_condition_met()` from Status Bar System. |
| **Interaction Template Framework** | Listens to | Listens to `combination_executed(recipe_id, template, instance_id_a, instance_id_b, card_id_a, card_id_b)` for `find_key` and `sequence` goal types (Vertical Slice). SGS declares all 6 params, reads only `recipe_id`. No ITF interaction for MVP `sustain_above`. |
| **Hint System** | Emits to | Hint System reads `goal.type` and `goal.bars` from Scene Goal System to know what to hint about. Scene Goal System exposes a read-only `get_goal_config()` method. |

## Formulas

Scene Goal System performs no calculations. It translates authored scene JSON into
system configuration. All bar math (decay, clamping, sustain timing) is owned by
Status Bar System — see `design/gdd/status-bar-system.md`.

**scene_bar_config construction (sustain_above):**

```
scene_bar_config = {
  bars:          goal.bars             // [{id, initial_value, decay_rate_per_sec}, ...]
  max_value:     goal.max_value        // float, e.g. 100
  win_condition: {
    type:         "sustain_above"
    threshold:    goal.threshold       // float, e.g. 60
    duration_sec: goal.duration_sec    // float, e.g. 30
  }
}
```

| Field | Type | Authored in | Consumed by |
|-------|------|-------------|-------------|
| `bars[].id` | string | scene JSON | Status Bar System, bar-effects.json |
| `bars[].initial_value` | float | scene JSON | Status Bar System |
| `bars[].decay_rate_per_sec` | float | scene JSON | Status Bar System |
| `max_value` | float | scene JSON | Status Bar System |
| `threshold` | float | scene JSON | Status Bar System win condition |
| `duration_sec` | float | scene JSON | Status Bar System win condition |

## Edge Cases

| Case | Trigger | Expected Behavior |
|------|---------|------------------|
| **Scene JSON not found** | `load_scene("bad_id")` called with unknown scene_id | Log an error, stay `Idle`. Do not configure Status Bar System or emit `seed_cards_ready`. Scene Manager treats a missing scene as a fatal setup error. |
| **Scene JSON malformed** | Required field missing or wrong type | Log a parse error with the field name and scene_id. Stay `Idle`. Do not partially configure downstream systems. |
| **`load_scene()` called while `Active`** | Scene Manager calls `load_scene()` without first calling `reset()` (bug) | Call `reset()` internally first — clear old goal state and Status Bar config. Then load new scene normally. Log a warning. |
| **`win_condition_met()` fires while `Complete`** | Status Bar System emits a duplicate signal (should not happen per its GDD, but defensive) | Ignore. Scene is already `Complete`. Do not emit `scene_completed` twice. |
| **Goal type unrecognised** | Scene JSON contains `"type": "unknown_type"` | Log an error. Do not enter `Active` state. Stay `Idle`. |
| **Bar ID mismatch** | Scene JSON defines `bar_id: "chester"` but `bar-effects.json` uses a different name | This is a content authoring error, not a code error. Scene Goal System passes the config as-is. Status Bar System will log a warning on the unknown bar_id (per its GDD edge case). No crash. |
| **seed_cards list is empty** | Scene JSON has `"seed_cards": []` | Emit `seed_cards_ready([])` — valid, though unusual. Scene Manager spawns nothing. Scene is playable (player starts with empty table). Log a warning to catch accidental omission. |
| **sequence goal: out-of-order step fired** | Player fires `recipe-b` before `recipe-a` in a sequence goal | Do not advance. Sequence position stays at 0. Only the next expected recipe_id advances the counter. Prior steps are not re-required. |

## Dependencies

### Upstream (this system depends on)

| System | What We Need | Hardness |
|--------|-------------|----------|
| **Status Bar System** | `configure(scene_bar_config)` method; `win_condition_met()` signal | Hard for bar-type goals — Scene Goal System cannot complete `sustain_above` scenes without it |

### Downstream (systems that depend on this)

| System | What They Need |
|--------|---------------|
| **Scene Manager** | Calls `load_scene(scene_id)` and `reset()`. Listens to `seed_cards_ready(seed_cards[])` and `scene_completed(scene_id)` |
| **Hint System** | Calls `get_goal_config()` to read goal type and bar config — used to determine what to hint toward |
| **Status Bar UI** | Reads bar IDs and count from goal config (via Hint System or direct call) to know how many bars to render |
| **Scene Transition UI** | Listens to `scene_completed(scene_id)` (may listen directly or via Scene Manager) to trigger the breakthrough animation |

### External Data

| Asset | Path | Description |
|-------|------|-------------|
| **Scene data files** | `assets/data/scenes/[scene_id].json` | Chester's authored per-scene config: seed cards, goal type, bar config |

### Signals Emitted

| Signal | Parameters | Fired when |
|--------|------------|-----------|
| `seed_cards_ready` | `seed_cards: Array[String]` | After scene JSON parsed successfully, before `Active` state entered |
| `scene_completed` | `scene_id: String` | When goal condition is met (any goal type) |

**Cross-reference note**: Status Bar System GDD lists Scene Goal System as the caller of
`configure()` — consistent. ITF GDD open question re: cooldown reset on scene load is
deferred to Scene Manager design.

## Tuning Knobs

Scene Goal System has no system-level knobs — all tunable values are authored per-scene
in `assets/data/scenes/[scene_id].json`. The knobs below are owned by the scene data
files, not the code:

| Knob | Authored in | Home scene default | Safe Range | Too Low | Too High |
|------|-------------|-------------------|------------|---------|----------|
| `initial_value` (per bar) | scene JSON | 20 | 0–60 | Player starts near win threshold; no discovery arc | Player starts so low that bars feel impossible to fill |
| `threshold` (win) | scene JSON | 60 | 30–90 | Win triggers accidentally; no sense of achievement | Bars must be nearly full simultaneously; frustrating |
| `duration_sec` (win) | scene JSON | 30s | 5–120s | Win feels like a lucky accident | Feels endless; player can't tell progress is being made |
| `decay_rate_per_sec` (per bar) | scene JSON | 0.5 | 0–5 | No pressure (0 = off) | Bars drain faster than combinations can fill |
| Seed card count | scene JSON | 2 | 1–5 | Player has nothing to work with | Table feels crowded before any combinations fire |

**Note**: The bar-related ranges duplicate the Status Bar System tuning table intentionally
— the source of truth for bar math is `design/gdd/status-bar-system.md`. This table exists
to help Chester author scene JSON files with confident defaults.

## Acceptance Criteria

- [ ] `load_scene("home")` reads `assets/data/scenes/home.json` without error
- [ ] On `load_scene()` with a `sustain_above` goal: `StatusBarSystem.configure()` is called
      with the correct `scene_bar_config` before any bar values appear on screen
- [ ] On `load_scene()` with a `find_key` or `sequence` goal: `StatusBarSystem.configure()`
      is NOT called — Status Bar System stays Dormant
- [ ] `seed_cards_ready(["chester", "ju"])` fires immediately after scene JSON is parsed
- [ ] When Status Bar System emits `win_condition_met()`: `scene_completed("home")` fires
      exactly once
- [ ] `scene_completed` does NOT fire a second time if `win_condition_met()` is somehow
      received again while in `Complete` state
- [ ] `load_scene("nonexistent")` logs an error and stays `Idle` — no downstream systems
      configured
- [ ] `load_scene()` called on a malformed JSON logs a parse error with the missing field
      name and stays `Idle`
- [ ] `load_scene()` called while `Active` resets cleanly and loads the new scene (with a
      warning log)
- [ ] `reset()` called by Scene Manager returns system to `Idle` — subsequent
      `win_condition_met()` signals are ignored
- [ ] A new scene JSON file added to `assets/data/scenes/` is loadable without code changes
- [ ] `get_goal_config()` returns the current scene's goal data while `Active`; returns null
      while `Idle`

## Open Questions

- **ITF cooldown reset on scene load**: ITF GDD flagged this as unresolved. Does Scene Goal
  System call `ITF.reset_cooldowns()` on `load_scene()`, or does Scene Manager own this?
  Resolve when Scene Manager is designed. Recommendation: Scene Manager resets ITF cooldowns
  as part of the scene transition sequence — Scene Goal System should not reach into ITF
  directly.
- **Vertical Slice goal types**: `find_key`, `sequence`, and `reach_value` are stubbed here.
  Full specification deferred to Vertical Slice milestone. Each will require Scene Goal System
  to listen to ITF's `combination_executed(recipe_id, template, instance_id_a, instance_id_b, card_id_a, card_id_b)` signal — handler must declare all 6 params (Godot 4.3 arity-strict).
- **scene_completed payload**: Scene Manager and Scene Transition UI may need additional
  data beyond `scene_id` (e.g., a "reward card" to spawn on completion). Resolve when Scene
  Manager is designed.
