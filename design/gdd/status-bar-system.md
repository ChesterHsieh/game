# Status Bar System

> **Status**: In Design
> **Author**: Chester + Claude
> **Last Updated**: 2026-03-24
> **Implements Pillar**: Discovery without Explanation

## Overview

The Status Bar System tracks two hidden progress bars — one for each person in the
relationship — and updates them as the player makes combinations. It listens to the
Interaction Template Framework's combination events and applies authored bar effects:
some combinations raise one bar, some raise both, some create tension between them.
The bars decay slowly over time, creating a soft pressure to keep combining. The system
does not know what the bars mean to the player, and it never tells her — that discovery
is hers. What it knows is the current values, and it signals the Scene Goal System when
those values satisfy the win condition.

## Player Fantasy

The bars are the game's first mystery. She sees two bars with no labels and no
instructions. Something about the game is asking her to figure out what they are.
The moment she makes a combination and one bar rises — and she connects the card
to the feeling — is a genuine insight, not a tutorial prompt. The Status Bar System
is successful when the bars feel like they're measuring something real about the
story. When she realizes "the first bar is him, the second bar is me," the system
disappears and the relationship takes its place.

## Detailed Design

### Core Rules

1. Status Bar System is **scene-conditional** — it is dormant until activated by
   Scene Goal System via `configure(scene_bar_config)`.
2. `scene_bar_config` defines everything about bars for a scene:
   - `bars`: list of `{id, initial_value, decay_rate_per_sec}` — count, identities,
     and decay behavior
   - `max_value`: upper bound for all bars in this scene (e.g., 100)
   - `win_condition`: `{type, threshold, duration_sec}` — what "winning" means
3. Bar effects are authored in `assets/data/bar-effects.json` — a flat map of
   `recipe_id → { bar_id: delta, ... }`. If a recipe has no entry, the combination
   has no bar effect.
4. On `combination_executed(recipe_id, ...)` from ITF: look up `recipe_id` in
   bar-effects data; apply each delta to the named bar; clamp all values to
   `[0, max_value]`; emit `bar_values_changed(values_dict)`
5. Decay: if a bar's `decay_rate_per_sec > 0`, it ticks down by that amount each
   second. Clamped at 0.
6. Win condition monitoring runs every frame while `Active`. For `sustain_above`:
   track how long ALL bars are simultaneously at or above `threshold`. When
   `sustained_time >= duration_sec`, emit `win_condition_met()`.
7. On `win_condition_met()`: enter `Complete` state. Stop decay, stop monitoring.
8. Status Bar System resets to `Dormant` on every scene transition.

### Bar Value Model

| Property | Type | Description |
|----------|------|-------------|
| `id` | string | Authored bar identifier (e.g. `chester`, `ju`). Opaque to the player. |
| `value` | float | Current value. Range `[0, max_value]`. |
| `initial_value` | float | Value when the scene loads. Authored per scene. |
| `decay_rate_per_sec` | float | How fast the bar drops passively. 0 = no decay. |
| `max_value` | float | Upper bound. Same for all bars in a scene. Authored per scene. |

### Bar Effects from Combinations

Bar effects are authored in `assets/data/bar-effects.json`:

```json
{
  "chester-morning-light": { "chester": 15, "ju": 5 },
  "chester-rainy-afternoon": { "chester": -10, "ju": 20 },
  "ju-home": { "chester": 8, "ju": 8 }
}
```

- Keys are `recipe_id` strings matching the Recipe Database
- Values are dictionaries of `bar_id → delta` (positive or negative)
- A recipe with no entry produces no bar change — valid for purely narrative combinations
- Deltas are applied then clamped: `+15` to a bar at 95 (max 100) results in 100

### Win Condition Detection

MVP win condition type: **`sustain_above`**

- `threshold`: float — all bars must be simultaneously at or above this value
- `duration_sec`: float — how long the condition must be sustained continuously

```
if all bars >= threshold:
    sustained_time += delta
else:
    sustained_time = 0

if sustained_time >= duration_sec:
    emit win_condition_met()
```

Future types (not required for MVP): `reach_value` (hit threshold once),
`sequence` (trigger specific combinations in order), `find_key` (discover a
specific recipe). These will be specified in Scene Goal System.

### States and Transitions

| State | Entry | Exit | Behavior |
|-------|-------|------|----------|
| `Dormant` | Default; on scene transition | `configure()` called | No tracking, no decay, ignores `combination_executed` |
| `Active` | `configure(scene_bar_config)` called | Win condition met OR scene transition | Tracks values, applies decay each frame, monitors win condition |
| `Complete` | `win_condition_met()` emitted | Scene transition (→ Dormant) | Win emitted; no further tracking or decay |

### Interactions with Other Systems

| System | Direction | Interface |
|--------|-----------|-----------|
| **Interaction Template Framework** | Listens | `combination_executed(recipe_id, ...)` — looks up bar effects and applies deltas |
| **Scene Goal System** | Configured by | `configure(scene_bar_config)` on scene load; listens to `win_condition_met()` |
| **Status Bar UI** | Emits to | `bar_values_changed(values_dict)` — UI reads current values and animates bars |
| **Hint System** | Emits to | Same `bar_values_changed` — Hint System watches how long values have been stagnant |

## Formulas

### Bar Value After Combination

```
new_value = clamp(current_value + delta, 0, max_value)
```

| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| `current_value` | float | [0, max_value] | Status Bar System internal | Current bar value before combination |
| `delta` | float | -max_value to +max_value | `assets/data/bar-effects.json` | Authored effect for this recipe on this bar |
| `max_value` | float | 1–200 | scene_bar_config | Upper bound for all bars in this scene |

### Bar Decay Per Frame

```
new_value = clamp(current_value - (decay_rate_per_sec * delta_time), 0, max_value)
```

| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| `decay_rate_per_sec` | float | 0–10 | scene_bar_config per bar | Points lost per second. 0 = no decay. |
| `delta_time` | float | ~0.016 | Godot `_process(delta)` | Frame time in seconds |

### Win Condition Timer (sustain_above type)

```
if all(bar.value >= threshold for bar in bars):
    sustained_time += delta_time
else:
    sustained_time = 0

if sustained_time >= duration_sec:
    emit win_condition_met()
```

| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| `threshold` | float | 0–max_value | scene_bar_config.win_condition | Minimum value all bars must simultaneously reach |
| `duration_sec` | float | 5–300s | scene_bar_config.win_condition | How long bars must stay above threshold |
| `sustained_time` | float | 0→duration_sec | Internal | Resets to 0 if any bar drops below threshold |

**Example (Home scene)**: `max_value=100`, `threshold=60`, `duration_sec=30`,
`decay_rate=0.5/sec`. Player must keep both bars above 60 for 30 continuous seconds
while passive decay pulls them down at half a point per second.

## Edge Cases

| Case | Trigger | Expected Behavior |
|------|---------|------------------|
| **Scene has no bars** | Scene Goal System uses a non-bar goal type; `configure()` never called | Stays `Dormant`. `combination_executed` signals silently ignored. No error. |
| **Recipe has no bar effect** | `combination_executed` fires for a recipe not in `bar-effects.json` | No delta applied. No log — this is the normal case for purely narrative combinations. |
| **Delta pushes bar above max** | `+50` applied to a bar at 80 with max 100 | Clamp to 100. No overflow. |
| **Delta pushes bar below 0** | `-30` applied to a bar at 10 | Clamp to 0. Bars cannot go negative. |
| **Sustained_time resets just before win** | Bars drop below threshold at `sustained_time = 29.9s` (out of 30s) | `sustained_time` resets to 0. Player must sustain again from scratch. No grace period. |
| **Win condition met mid-animation** | Bars hit threshold during a Merge animation before its `combination_executed` fires | Win detection runs every frame — if a previous combination already pushed bars to threshold, the frame loop catches it. No timing dependency on animations. |
| **bar-effects.json references unknown bar_id** | A recipe targets `"happiness"` but scene only defines `"chester"` and `"ju"` | Skip the effect for the unknown bar_id. Apply effects for valid IDs. Log a warning. |
| **configure() called while Active** | Scene loads a second time without a transition (bug case) | Overwrite existing config, reset all bar values to `initial_value`, reset `sustained_time = 0`. Log a warning. |
| **All bars at 0, decay still running** | Decay ticks on bars already at 0 | Clamp to 0. No negative values. No log needed. |

## Dependencies

### Upstream (this system depends on)

| System | What We Need | Hardness |
|--------|-------------|----------|
| **Interaction Template Framework** | `combination_executed(recipe_id, template, instance_id_a, instance_id_b)` signal | Hard — no bar updates without this |

### Downstream (systems that depend on this)

| System | What They Need |
|--------|---------------|
| **Scene Goal System** | Calls `configure(scene_bar_config)` on scene load; listens to `win_condition_met()` |
| **Status Bar UI** | `bar_values_changed(values_dict)` to render bar fill levels |
| **Hint System** | `bar_values_changed` to detect stagnation (bars not moving for N seconds) |

### External Data

| Asset | Path | Description |
|-------|------|-------------|
| **Bar effects data** | `assets/data/bar-effects.json` | Chester's authored map of `recipe_id → {bar_id: delta}` |

### Signals Emitted

| Signal | Parameters | Fired when |
|--------|------------|-----------|
| `bar_values_changed` | `values: Dictionary` — `{bar_id: current_value, ...}` | After any bar value changes (combination or decay tick) |
| `win_condition_met` | none | When `sustained_time >= duration_sec` for the first time |

## Tuning Knobs

No system-level knobs — all tuning is authored per scene in `scene_bar_config`
and `assets/data/bar-effects.json`:

| Knob | Authored in | Default (Home scene) | Safe Range | Too Low | Too High |
|------|------------|---------------------|------------|---------|----------|
| `max_value` | scene_bar_config | 100 | 50–200 | Fine-grained; small deltas feel meaningless | Large deltas needed to feel impactful |
| `threshold` (win) | scene_bar_config | 60 | 30–90 | Win triggers too easily | Impossible to sustain; frustrating |
| `duration_sec` (win) | scene_bar_config | 30s | 5–120s | Win feels like lucky accident | Feels endless; no sense of progress |
| `decay_rate_per_sec` | scene_bar_config per bar | 0.5 | 0–5 | No pressure (0 = off) | Bars drain faster than combinations can fill |
| Bar deltas | `bar-effects.json` per recipe | varies | -30 to +30 | Combinations feel meaningless | Bars swing wildly; hard to balance |

## Acceptance Criteria

- [ ] Without `configure()` being called, `combination_executed` signals are silently ignored
- [ ] `configure(scene_bar_config)` sets bar values to `initial_value` and enters `Active` state
- [ ] A combination with a bar effect updates the correct bar(s) by the authored delta
- [ ] Values are always clamped to `[0, max_value]` — never negative, never over max
- [ ] `bar_values_changed(values_dict)` fires after every value change (combination or decay)
- [ ] Bars with `decay_rate_per_sec = 0` do not change between combinations
- [ ] Bars with `decay_rate_per_sec > 0` tick down each frame while `Active`
- [ ] `sustained_time` increments each frame when all bars are at or above `threshold`
- [ ] `sustained_time` resets to 0 immediately when any bar drops below `threshold`
- [ ] `win_condition_met()` fires exactly once when `sustained_time >= duration_sec`
- [ ] After `win_condition_met()`: decay stops; bar values freeze; no further updates
- [ ] Scene transition resets all bar values and enters `Dormant` state
- [ ] A bar effect targeting an unknown `bar_id` logs a warning and skips that bar only
- [ ] Bar effects data can be edited in `bar-effects.json` without code changes

## Open Questions

- **Scene Goal System bar config format**: When Scene Goal System is designed, confirm the exact schema for `scene_bar_config` — specifically whether bar IDs are free strings or constrained to a set.
- **Hint System stagnation threshold**: Hint System will watch `bar_values_changed` to detect when bars aren't moving. The stagnation duration (e.g., "bars haven't moved in 2 minutes") will be authored in Hint System. No change needed here.
- **Multiple win condition types**: `sustain_above` is MVP. Other types (`reach_value`, `sequence`, `find_key`) will be specified when Scene Goal System is designed and may require additional Status Bar System state or a different signal.
