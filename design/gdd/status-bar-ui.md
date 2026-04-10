# Status Bar UI

> **Status**: In Design
> **Author**: Chester + Claude
> **Last Updated**: 2026-03-25
> **Implements Pillar**: Discovery Without Explanation

## Overview

Status Bar UI is the visual layer for the two progress bars and their hint arcs. It
listens to `bar_values_changed` from Status Bar System and animates each bar's fill
level in response. It listens to `hint_level_changed` from Hint System and fades a
counterclockwise arc around each bar — faint at Level 1, full at Level 2, hidden at
Level 0. The bars carry no labels, no numbers, and no tooltips. Status Bar UI renders
exactly what it receives: two fill levels and one arc opacity. It does not know what
the bars measure, what the win condition is, or what a combination did. It is a
display of state, not a source of meaning.

## Player Fantasy

She notices the bars before she understands them. Two quiet fills at the edge of the
screen — no label, no number, no explanation. She makes a combination and one bar
rises. She doesn't know why. She tries another. The same bar rises again. She's
starting to have a theory. The bars are the game's first mystery, and Status Bar UI
is successful when it holds that mystery: visible enough to notice, restrained enough
not to explain. If the hint arc appears — soft at first, then a little more — it
points without naming. The arc is not a warning. It's a suggestion from a game that
trusts her.

## Detailed Design

### Core Rules

1. Status Bar UI renders a **left-side panel**, positioned like Stacklands' quest sidebar. The panel is always visible during gameplay.
2. For bar-type goal scenes (`sustain_above`, `reach_value`): the panel contains **two unlabelled bar fills** with their hint arcs. No labels, no numbers, no win threshold indicator.
3. For non-bar goal scenes (`find_key`, `sequence`): panel content is **deferred to Vertical Slice** — stub shows an empty panel. Status Bar UI stays dormant for non-bar scenes.
4. Status Bar UI reads **bar count and bar IDs** from Scene Goal System via `get_goal_config()` on scene load — this determines how many bars to render.
5. On `bar_values_changed(values: Dictionary)` from Status Bar System: update each bar's fill level. Animate the fill change with a short tween (not instant snap).
6. On `hint_level_changed(level: int)` from Hint System: update the arc opacity on **all bars simultaneously**:
   - Level 0: arc hidden (opacity 0)
   - Level 1: arc at low opacity (faint)
   - Level 2: arc at full opacity
   Arc opacity change is a smooth fade, not instant.
7. Each bar's hint arc traces **counterclockwise** around the bar's border. The arc starts at the top and sweeps left.
8. Bar fill animates **bottom to top** (fill rises as value increases). The fill color is solid — no gradient, no numbers.
9. On `win_condition_met()` (indirectly via scene flow): bars freeze at their current fill. No additional win animation owned by Status Bar UI — that belongs to Scene Transition UI.
10. On scene transition: panel resets — bars return to empty, arcs hidden.

### States and Transitions

| State | Entry | Exit | Behavior |
|-------|-------|------|----------|
| `Dormant` | Default; non-bar goal scene | `configure()` called with bar data | Panel visible but empty. No bars rendered. |
| `Active` | Bar goal scene loads; `get_goal_config()` returns bars | Scene transition | Bars rendered and updating each frame. |
| `Frozen` | `win_condition_met()` received | Scene transition | Bars visible at final values. No further updates. |

### Interactions with Other Systems

| System | Direction | Interface |
|--------|-----------|-----------|
| **Scene Goal System** | Reads from | `get_goal_config()` on scene load — reads bar count and bar IDs to know how many bars to render. |
| **Status Bar System** | Listens to | `bar_values_changed(values: Dictionary)` — updates bar fill levels. |
| **Hint System** | Listens to | `hint_level_changed(level: int)` — updates arc opacity on all bars. |

## Formulas

**Bar fill height:**
```
fill_height = (current_value / max_value) * bar_height_px
```

| Variable | Type | Source | Description |
|----------|------|--------|-------------|
| `current_value` | float | `bar_values_changed` payload | Current bar value (0–max_value) |
| `max_value` | float | `get_goal_config()` | Upper bound for bars in this scene |
| `bar_height_px` | float | Tuning knob | Pixel height of the bar at 100% fill |

**Fill tween (on bar_values_changed):**
```
tween fill_height from current_displayed to new_fill_height over bar_tween_sec
```

| Variable | Default | Description |
|----------|---------|-------------|
| `bar_tween_sec` | 0.15s | Duration of fill level animation. Short — feels responsive, not laggy. |

**Arc opacity (on hint_level_changed):**
```
Level 0 → target_opacity = 0.0
Level 1 → target_opacity = arc_faint_opacity
Level 2 → target_opacity = 1.0
tween arc.modulate.a from current to target_opacity over arc_fade_sec
```

| Variable | Default | Description |
|----------|---------|-------------|
| `arc_faint_opacity` | 0.3 | Opacity of the arc at hint Level 1. Low enough to be subtle; high enough to notice. Tunable. |
| `arc_fade_sec` | 1.5s | Duration of the arc fade-in or fade-out. Slow — the arc should drift in, not snap. |

## Edge Cases

| Case | Trigger | Expected Behavior |
|------|---------|------------------|
| **Non-bar goal scene** | `get_goal_config()` returns `find_key` or `sequence` goal type | Stay `Dormant`. Render empty panel. No bars, no arcs. No error. |
| **bar_values_changed fires while Dormant** | Status Bar System emits before scene loads (edge case) | Ignored. No bar fill update when Dormant. |
| **hint_level_changed fires while Dormant** | Hint System emits while no bars are showing | Ignored. Arc opacity stored but not displayed until Active. |
| **hint_level_changed(0) while arc already hidden** | Hint System emits 0 when arc is already at opacity 0 | Tween to 0 — idempotent. No visible change. Matches Hint System idempotent behavior. |
| **hint_level_changed(1) then (2) before fade completes** | Hint System escalates before Level 1 fade-in finishes | Cancel Level 1 tween. Start Level 2 tween from current opacity. No jump. |
| **Bar fill tween interrupted by another bar_values_changed** | Bar changes rapidly (two combos fired quickly) | Cancel previous tween. Start new tween from current displayed fill. No jump or glitch. |
| **win_condition_met while arc is fading** | Win fires with Level 1 or 2 arc mid-fade | Freeze bars at current fill. Arc tween can continue to its endpoint or cancel — either is acceptable since Scene Transition UI will take over the screen. |
| **get_goal_config() returns zero bars** | Scene JSON has empty bars array | Render empty panel. Log a warning (unusual — a bar goal with no bars is a content error). |
| **One bar, not two** | Scene JSON defines only one bar | Render one bar centered in the panel. Layout adapts gracefully. |

## Dependencies

### Upstream (this system depends on)

| System | What We Need | Hardness |
|--------|-------------|----------|
| **Scene Goal System** | `get_goal_config()` — bar count and bar IDs on scene load | Hard — cannot know how many bars to render without it |
| **Status Bar System** | `bar_values_changed(values: Dictionary)` — drives bar fill animation | Hard — bars never move without this signal |
| **Hint System** | `hint_level_changed(level: int)` — drives arc opacity | Hard — hint arc cannot function without this |

### Downstream (systems that depend on this)

None. Status Bar UI is a leaf node — nothing depends on it.

### Signals Emitted

None. Status Bar UI is a pure display component.

## Tuning Knobs

| Knob | Type | Default | Safe Range | Too Low | Too High |
|------|------|---------|------------|---------|----------|
| `bar_height_px` | float | 120px | 80–200px | Bars too small to read fill level | Bars dominate the panel; feel heavy |
| `bar_width_px` | float | 24px | 16–40px | Bars too thin; hard to see fill | Bars look chunky; out of character |
| `bar_tween_sec` | float | 0.15s | 0.05–0.4s | Fill snaps with no animation | Fill lags behind actual value; feels sluggish |
| `arc_faint_opacity` | float | 0.3 | 0.1–0.5 | Arc invisible at Level 1; hint unnoticed | Level 1 arc feels as strong as Level 2; no escalation |
| `arc_fade_sec` | float | 1.5s | 0.5–3.0s | Arc snaps in; feels like an alert, not a nudge | Arc takes too long to appear; hint effect lost |
| `panel_width_px` | float | 180px | 140–240px | Panel too narrow for bars + padding | Panel takes too much space from the table |

## Acceptance Criteria

- [ ] In a bar-type goal scene: two unlabelled bars render in the left panel on scene load
- [ ] In a non-bar goal scene: panel is empty; no bars, no arcs, no error
- [ ] `bar_values_changed` updates each named bar's fill to the correct height with a `bar_tween_sec` tween
- [ ] Fill animates bottom-to-top; a value of 0 shows an empty bar, max_value shows a full bar
- [ ] Two rapid `bar_values_changed` signals: second tween cancels the first and starts from current displayed height — no jump
- [ ] `hint_level_changed(1)`: all bar arcs begin fading in to `arc_faint_opacity` over `arc_fade_sec`
- [ ] `hint_level_changed(2)`: all bar arcs fade to full opacity (1.0) over `arc_fade_sec`
- [ ] `hint_level_changed(0)`: all bar arcs fade to hidden (0.0) over `arc_fade_sec`
- [ ] Hint level escalating from 1→2 before fade completes: no opacity jump; tween continues smoothly from current value
- [ ] Arc traces counterclockwise around each bar's border, starting from the top
- [ ] Bars freeze at current fill when scene completes (no further updates after win)
- [ ] Scene transition resets panel: bars empty, arcs hidden, state = Dormant
- [ ] All tuning knobs (`bar_height_px`, `bar_width_px`, `bar_tween_sec`, `arc_faint_opacity`, `arc_fade_sec`, `panel_width_px`) changeable without modifying any other system
- [ ] Panel with one bar renders correctly (bar centered); panel with two bars renders correctly (bars side by side or stacked)

## Open Questions

- **Non-bar goal panel content**: For `find_key` and `sequence` scenes, the left panel is currently empty. Vertical Slice will need to define what it shows — likely a visual goal indicator (silhouette, ??? cards, or a sequence of steps). Resolve when those goal types are designed.
- **Bar layout: side by side vs. stacked**: Two bars in the panel could sit side by side (horizontal) or stacked vertically. Resolve in prototype — depends on panel aspect ratio and how tall the bars feel.
- **Bar fill color**: Not specified here — a single solid color (no gradient). Resolve with art direction during implementation. Color should feel warm, not gamey.
- **Panel background style**: Should the panel have a bordered frame (like Stacklands' quest sidebar) or be more minimal? Resolve with art direction. The panel should feel like part of the table, not a separate HUD.
- **Win threshold indicator**: Currently no threshold is shown on the bars. If playtesting shows players don't understand the win condition, a subtle marker at the threshold height could be added — but only if discovery fails. Start without it.
