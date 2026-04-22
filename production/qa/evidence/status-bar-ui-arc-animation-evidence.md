# QA Evidence: Status Bar UI — Hint Arc Animation (Story 003)

> **Story**: `production/epics/status-bar-ui/story-003-hint-arc-animation.md`
> **Type**: Visual/Feel
> **Status**: PENDING MANUAL WALKTHROUGH
> **Reviewed by**: —
> **Date**: —

---

## Manual Walkthrough Checklist

This document records the results of the manual QA walkthrough for Story 003.
A tester runs through each acceptance criterion in a running Godot 4.3 session
and marks Pass or Fail with notes.

### Setup

1. Load a bar-type goal scene in the gameplay scene.
2. Confirm StatusBarUI is in Active state — two bars visible, arcs hidden (opacity 0).
3. Use the Godot remote debugger or GDScript console to emit test signals.

---

### AC-1: hint_level_changed(1) fades arc to arc_faint_opacity

**Test steps**:
1. Confirm arcs are at opacity 0 (hidden).
2. Emit: `EventBus.hint_level_changed.emit(1)`
3. Wait for `arc_fade_sec` (1.5s) to complete.

**Expected**:
- Both bar arcs begin fading in smoothly (not instantly).
- After 1.5s, arc opacity = 0.3 (faint but visible; arc glow visible around bar border).
- Both bars' arcs update simultaneously.

**Result**: [ ] Pass  [ ] Fail

**Notes**:

---

### AC-2: hint_level_changed(2) fades arc to full opacity

**Test steps**:
1. Arcs can be at any opacity (0, 0.3, or mid-tween).
2. Emit: `EventBus.hint_level_changed.emit(2)`
3. Wait for 1.5s.

**Expected**:
- All bar arcs fade to opacity 1.0 over `arc_fade_sec`.
- Fade is smooth (not instant); both bars update simultaneously.

**Result**: [ ] Pass  [ ] Fail

**Notes**:

---

### AC-3: hint_level_changed(0) fades arc to hidden

**Test steps**:
1. Set arcs to opacity 0.3 or 1.0 first (emit level 1 or 2 and wait).
2. Emit: `EventBus.hint_level_changed.emit(0)`
3. Wait for 1.5s.

**Expected**:
- All bar arcs fade to opacity 0.0 over 1.5s.
- Fade is smooth. If arcs are already at 0, tween runs but no visible change occurs (idempotent, no error).

**Result**: [ ] Pass  [ ] Fail

**Notes**:

---

### AC-4: Level 1 → 2 escalation before fade completes — no jump

**Test steps**:
1. Emit: `EventBus.hint_level_changed.emit(1)` — arcs begin fading in.
2. After ~0.5s (while arcs are mid-fade, approximately 0.1–0.15 opacity), emit: `EventBus.hint_level_changed.emit(2)`
3. Observe arc opacity progression.

**Expected**:
- Arc does not jump to any opacity value at the moment of escalation.
- Arc continues smoothly upward toward 1.0 from wherever it was when level 2 was received.
- Final opacity reaches 1.0.

**Result**: [ ] Pass  [ ] Fail

**Notes**:

---

### AC-5: Arc direction — counterclockwise from top

**Test steps**:
1. Set arcs to visible (level 1 or 2).
2. Inspect each bar's arc visually.

**Expected**:
- The arc starts at the top-right of the bar border and sweeps left (counterclockwise).
- Arc does not start at the bottom or sweep clockwise.
- Arc traces the full perimeter at the given opacity — the full border glows.

**Result**: [ ] Pass  [ ] Fail

**Notes**:

---

## Implementation Notes

The following implementation details were verified during code review:

- Opacity mapping:
  - Level 0 → `target_opacity = 0.0`
  - Level 1 → `target_opacity = arc_faint_opacity` (default 0.3)
  - Level 2+ → `target_opacity = 1.0`
- Tween: `create_tween()` + `tween_method()` updating `_arc_opacity` and calling `queue_redraw()`.
- Mid-tween cancel: existing arc tween is killed before new one starts; new tween begins from current `_arc_opacity` — no jump.
- Dormant guard: `_on_hint_level_changed()` stores level in `_pending_hint_level` if not Active; level applied when `configure_for_scene()` sets state to Active.
- Arc draw: `_draw_bar_arc()` draws a closed polyline around the bar perimeter with a 2px outline inset 2px outside the bar edge. Counterclockwise order: top-right → top-left → bottom-left → bottom-right → top-right.

**Source file**: `src/ui/status_bar_ui.gd` — `_on_hint_level_changed()`, `_apply_hint_level()`, `_draw_bar_arc()`

---

## Sign-off

Once all ACs pass, update **Story Type** status in story-003 to Complete and record:

- Tester name:
- Date tested:
- Godot version: 4.3
- Platform:
- Any deviations noted:
