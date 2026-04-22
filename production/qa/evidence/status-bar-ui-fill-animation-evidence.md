# QA Evidence: Status Bar UI — Bar Fill Animation (Story 002)

> **Story**: `production/epics/status-bar-ui/story-002-bar-fill-animation.md`
> **Type**: Visual/Feel
> **Status**: PENDING MANUAL WALKTHROUGH
> **Reviewed by**: —
> **Date**: —

---

## Manual Walkthrough Checklist

This document records the results of the manual QA walkthrough for Story 002.
A tester runs through each acceptance criterion in a running Godot 4.3 session
and marks Pass or Fail with notes.

### Setup

1. Load a bar-type goal scene (`sustain_above` or `reach_value`) in the gameplay scene.
2. Confirm StatusBarUI is in Active state — two bars visible in the left panel.
3. Open the Godot remote debugger or attach a GDScript console to emit test signals.

---

### AC-1: bar_values_changed updates fill to correct height

**Test steps**:
1. Emit: `EventBus.bar_values_changed.emit({"bar_a": 50.0, "bar_b": 25.0})`
   (assuming `max_value = 100.0`, `bar_height_px = 120.0`)
2. Wait for `bar_tween_sec` (0.15s) to complete.

**Expected**:
- Bar A fill height = `(50.0 / 100.0) * 120.0 = 60px`
- Bar B fill height = `(25.0 / 100.0) * 120.0 = 30px`
- Fill rises bottom-to-top; fill color is solid warm amber.

**Result**: [ ] Pass  [ ] Fail

**Notes**:

---

### AC-2: Value 0 shows empty bar; max_value shows full bar

**Test steps**:
1. Emit: `EventBus.bar_values_changed.emit({"bar_a": 0.0, "bar_b": 100.0})`
2. Wait for tween to complete (0.15s).

**Expected**:
- Bar A: no fill visible (fill height = 0px).
- Bar B: fill reaches top of bar (fill height = 120px).
- No overshoot or undershoot.

**Result**: [ ] Pass  [ ] Fail

**Notes**:

---

### AC-3: Rapid double signal — no jump

**Test steps**:
1. Emit: `EventBus.bar_values_changed.emit({"bar_a": 20.0})`
2. Immediately emit (within 0.1s): `EventBus.bar_values_changed.emit({"bar_a": 80.0})`
3. Observe bar A during the transition.

**Expected**:
- Bar A does not snap or jump to 20px fill and then restart from 0.
- The fill continues smoothly from wherever it was when the second signal arrived.
- Final fill height = 96px (80% of 120px).
- No visible discontinuity in either direction.

**Result**: [ ] Pass  [ ] Fail

**Notes**:

---

## Implementation Notes

The following implementation details were verified during code review:

- Fill formula: `fill_height = (current_value / max_value) * bar_height_px` — implemented in `_draw_bar()`.
- Tween method: `create_tween()` + `tween_method()` updating `_fill_values[bar_id]` and calling `queue_redraw()` each frame — no `_process` polling.
- Rapid signal cancel: existing tween is killed before new tween is created; new tween starts from the current `_fill_values[bar_id]` (the actual displayed value at cancel time) — no jump.
- State guard: handler returns immediately if `_state != UIState.ACTIVE`.

**Source file**: `src/ui/status_bar_ui.gd` — `_on_bar_values_changed()`

---

## Sign-off

Once all ACs pass, update **Story Type** status in story-002 to Complete and record:

- Tester name:
- Date tested:
- Godot version: 4.3
- Platform:
- Any deviations noted:
