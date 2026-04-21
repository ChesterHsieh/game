# Hint System

> **Status**: In Design
> **Author**: Chester + Claude
> **Last Updated**: 2026-03-25
> **Implements Pillar**: Discovery Without Explanation

## Overview

The Hint System watches for player stagnation — periods where the status bars aren't
moving — and responds by fading in a silent visual cue around each bar. It does not
interrupt, instruct, or explain. It simply lets a shape appear: a counterclockwise arc
that traces around the bar, visible only after the player has been still long enough to
need it. The Hint System is the game's only concession to guidance, and it makes that
concession without words. It listens to `combination_executed` from ITF
to detect when Ju has stopped producing new combinations, reads the current goal config from Scene Goal System
to confirm a hint is relevant, and emits a signal to Status Bar UI when the arc should
begin fading in.

## Player Fantasy

She's been experimenting for a while — trying combinations, watching bars, forming
theories. Then she notices something she didn't see before: a faint arc, curving
counterclockwise around one of the bars. It wasn't there when she started. It appeared
quietly, without announcement. She doesn't know what it means yet — but the game is
telling her to look here. The arc is not an instruction. It's a gesture. The Hint System
is successful when she feels like she figured it out herself, and the arc was just a
nudge she barely noticed. It is invisible when it's working. When it fails, it either
arrives so late she's already frustrated, or so early it robs her of the discovery.

## Detailed Design

### Core Rules

1. Hint System is **goal-conditional**: it only activates for bar-type goals
   (`sustain_above`, `reach_value`). On scene load, it calls
   `Scene_Goal.get_goal_config()` — if goal type has no bars, Hint System stays
   `Dormant`.
2. On scene load (`seed_cards_ready` received from Scene Goal System): reset stagnation
   timer to 0, set hint level to 0, enter `Watching` state.
3. **Stagnation timer**: counts seconds since the last `combination_executed(recipe_id, template, instance_id_a, instance_id_b, card_id_a, card_id_b)` signal from ITF. Resets to 0 each time a combination fires. Hint System's handler declares all 6 params (Godot 4.3 arity-strict) and ignores the payload — only the fact of emission matters.
4. Hint levels:
   - **Level 1** (faint): stagnation timer reaches `stagnation_sec`. Emit
     `hint_level_changed(1)`. Status Bar UI fades arc in to low opacity.
   - **Level 2** (full): stagnation timer reaches `stagnation_sec * 2`. Emit
     `hint_level_changed(2)`. Status Bar UI fades arc to full opacity.
5. On `combination_executed` received: reset stagnation timer to 0. If hint level > 0:
   emit `hint_level_changed(0)` — Status Bar UI fades arc back out. Re-enter
   `Watching`. Stagnation clock restarts from zero.
6. On `win_condition_met()` from Status Bar System: enter `Dormant`. Emit
   `hint_level_changed(0)` to clear any visible arc.
7. On `scene_completed` from Scene Goal System: enter `Dormant`. Reset all state.
8. The arc hint applies to ALL bars simultaneously — one arc per bar, all fading in
   at the same level together.

### States and Transitions

| State | Entry | Exit | Behavior |
|-------|-------|------|----------|
| `Dormant` | Default; non-bar goal; win condition met; scene completed | `seed_cards_ready` with bar goal | No timer running. No hint emitted. |
| `Watching` | Bar goal scene loads; combination fires (hint resets) | Timer reaches `stagnation_sec` (→ Hint1) | Stagnation timer incrementing each frame. |
| `Hint1` | Timer ≥ `stagnation_sec` | Combo fires (→ Watching) OR timer ≥ `stagnation_sec * 2` (→ Hint2) | Faint arc showing. Timer still running. |
| `Hint2` | Timer ≥ `stagnation_sec * 2` | Combo fires (→ Watching) | Full arc showing. Timer stops — max hint reached. |

### Interactions with Other Systems

| System | Direction | Interface |
|--------|-----------|-----------|
| **Scene Goal System** | Listens to; reads | Listens to `seed_cards_ready` to activate on scene load. Listens to `scene_completed` to reset. Calls `get_goal_config()` to check if goal type uses bars. |
| **Interaction Template Framework** | Listens to | `combination_executed(recipe_id, template, instance_id_a, instance_id_b, card_id_a, card_id_b)` — resets stagnation timer and clears active hint. 6-param handler required. |
| **Status Bar System** | Listens to | `win_condition_met()` — enters Dormant, clears arc immediately. |
| **Status Bar UI** | Emits to | `hint_level_changed(level: int)` — 0 = hidden, 1 = faint arc, 2 = full arc. UI owns the fade animation. |

## Formulas

Hint System has one formula: the stagnation timer and its two thresholds.

**Stagnation timer (per frame, while Watching or Hint1):**

```
stagnation_timer += delta_time

if stagnation_timer >= stagnation_sec * 2:
    enter Hint2 → emit hint_level_changed(2)
elif stagnation_timer >= stagnation_sec:
    enter Hint1 → emit hint_level_changed(1)

on combination_executed:
    stagnation_timer = 0
    emit hint_level_changed(0)  // if level was > 0
```

| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| `stagnation_timer` | float | 0 → ∞ | Hint System internal | Seconds since last combination fired. Resets on every `combination_executed`. |
| `stagnation_sec` | float | 60–600s | Tuning knob | Time without a combo before Level 1 hint appears. Default: 300s (5 min). |
| `stagnation_sec * 2` | float | 120–1200s | Derived | Time without a combo before Level 2 hint appears. Always double Level 1. |
| `delta_time` | float | ~0.016 | Godot `_process(delta)` | Frame time in seconds. |

**Example (Home scene)**: `stagnation_sec = 300`. Level 1 arc appears after 5 minutes
of no combinations. Level 2 full arc appears after 10 minutes. Any combination resets
the clock and fades the arc.

## Edge Cases

| Case | Trigger | Expected Behavior |
|------|---------|------------------|
| **Non-bar goal scene** | `get_goal_config()` returns `find_key` or `sequence` goal type | Stay `Dormant`. Do not start stagnation timer. No arc ever shown for non-bar scenes. |
| **Combination fires while Dormant** | ITF fires `combination_executed` before scene loads | Ignored. Stagnation timer is not running. |
| **First combination fires just before Level 1** | Combo fires at `stagnation_timer = 299s` (threshold 300s) | Timer resets to 0. No hint shown — correct. Level 1 never triggered. |
| **stagnation_sec set to 0** | Tuning knob set to zero | Level 1 triggers immediately on scene load before any player input. Level 2 triggers at frame 2. Avoid — reserved for debugging only. |
| **Player pauses the game** | Game paused, `_process(delta)` stops | `delta_time` is 0 while paused — stagnation timer does not advance. Hint timing is play-time, not wall-time. Correct behavior. |
| **Scene completes while hint is showing** | `win_condition_met()` fires with Level 2 arc visible | Enter Dormant, emit `hint_level_changed(0)`. Arc fades out as win sequence begins. No overlap. |
| **Rapid combo spam resets timer repeatedly** | Player fires combinations every few seconds indefinitely | Timer never reaches `stagnation_sec`. No hint shown. Correct — an engaged player needs no hint. |
| **hint_level_changed(0) emitted while already at level 0** | Combo fires when no hint is showing (level already 0) | Emit `hint_level_changed(0)` anyway — idempotent signal. Status Bar UI ignores a no-op fade. |
| **Win condition met before stagnation timer expires** | Player wins the scene before 5 min of stagnation | Hint never shows. Correct — fast players need no hint. |

## Dependencies

### Upstream (this system depends on)

| System | What We Need | Hardness |
|--------|-------------|----------|
| **Scene Goal System** | `seed_cards_ready` signal (activate); `scene_completed` signal (reset); `get_goal_config()` method (check bar goal type) | Hard — cannot activate or know what to hint without this |
| **Status Bar System** | `win_condition_met()` signal — enter Dormant immediately on scene win | Soft — scene would still reset via `scene_completed`, but arc would linger during win animation |
| **Interaction Template Framework** | `combination_executed(recipe_id, template, instance_id_a, instance_id_b, card_id_a, card_id_b)` — reset stagnation timer on every combo. 6-param handler required. | Hard — without this, stagnation cannot be detected |

### Downstream (systems that depend on this)

| System | What They Need |
|--------|---------------|
| **Status Bar UI** | `hint_level_changed(level: int)` — drives arc opacity (0 = hidden, 1 = faint, 2 = full) |

### Signals Emitted

| Signal | Parameters | Fired when |
|--------|------------|-----------|
| `hint_level_changed` | `level: int` — 0, 1, or 2 | Level changes in either direction (showing or hiding) |

### Systems Index Update Required

Hint System must add **Interaction Template Framework** as an upstream dependency. The
systems index currently lists only Scene Goal System and Status Bar System. This does
not create a circular dependency — ITF is already upstream of both Status Bar System
and Scene Goal System.

**Cross-reference**: ~~Status Bar System GDD lists Hint System as a downstream consumer
of `bar_values_changed` — this is now superseded.~~ **RESOLVED 2026-04-21**: Status Bar System downstream + dependency rows have been updated to reflect that Hint System uses `combination_executed` from ITF.

## Tuning Knobs

| Knob | Type | Default | Safe Range | Too Low | Too High |
|------|------|---------|------------|---------|----------|
| `stagnation_sec` | float | 300s (5 min) | 60–600s | Hint appears before she's had a real chance to explore — robs the discovery moment | She may have been stuck and frustrated for 10+ minutes before any help arrives |

**Secondary effect**: `stagnation_sec * 2` is always the Level 2 threshold. There is
no separate knob — the two-level system is always proportional. If
`stagnation_sec = 300`, Level 2 is always at 600s.

**Per-scene override (added 2026-04-21 in response to `/review-all-gdds` W-D3):**
`stagnation_sec` is a per-scene authored value read from `assets/data/scenes/[scene_id].json` key `"hint_stagnation_sec"`. If the scene file omits the key, Hint System falls back to the system-level default of 300s. This allows late-chapter scenes (with larger card trees and longer genuine exploration time) to authorize a longer window (e.g. 450s for scene 5, 600s for scene 7) without editing the MVP default. Early playtest sessions will tune these per-scene values from observation rather than guessing upfront.

| Knob (per-scene) | Default fallback | Safe Range | Source |
|---|---|---|---|
| `hint_stagnation_sec` | `300.0` (if key absent) | 60–900s | `assets/data/scenes/[scene_id].json` |

**Rationale**: Per `/review-all-gdds` W-D3, flat global hint timing was flagged as a risk — the "discovery friction increases" design intent cannot be matched with a constant. Promoting to per-scene config now is trivial; post-authoring it would require edits across every scene file.

## Acceptance Criteria

- [ ] In a bar-type goal scene, stagnation timer starts at 0 on scene load
- [ ] After `stagnation_sec` of no combinations: `hint_level_changed(1)` fires exactly once
- [ ] After `stagnation_sec * 2` of no combinations: `hint_level_changed(2)` fires exactly once
- [ ] When a combination fires while at Level 1 or 2: `hint_level_changed(0)` fires and
      timer resets to 0
- [ ] After hint resets, stagnation timer restarts — Level 1 can appear again after another
      `stagnation_sec` of inactivity
- [ ] In a non-bar goal scene (`find_key`, `sequence`): Hint System stays `Dormant`, no
      `hint_level_changed` emitted regardless of time elapsed
- [ ] `win_condition_met()` while hint showing: `hint_level_changed(0)` fires, Hint System
      enters `Dormant`
- [ ] `scene_completed` resets all state — stagnation timer = 0, level = 0,
      state = `Dormant`
- [ ] Pausing the game does not advance the stagnation timer
- [ ] `hint_level_changed(0)` emitted when combo fires even if hint was already at level 0
      (idempotent)
- [ ] `stagnation_sec` can be changed in code without modifying any other system

## Open Questions

- **Per-scene stagnation timing**: Currently `stagnation_sec` is a global constant.
  If playtesting reveals that some scenes need faster or slower hints, move it to
  scene JSON. Resolve after first playtest.
- **Status Bar UI arc design**: Hint System emits `hint_level_changed(level)` but does
  not specify arc opacity values. Status Bar UI GDD must define: what opacity is
  "faint" (Level 1) vs "full" (Level 2), and how long the fade-in tween takes.
- ~~**Status Bar System GDD correction**: Status Bar System GDD lists Hint System as a
  consumer of `bar_values_changed`.~~ **RESOLVED 2026-04-21** — Status Bar System downstream table updated.
