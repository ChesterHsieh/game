# Story 003: Deactivation + edge cases

> **Epic**: Hint System
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Manifest Version**: 2026-04-21

## Context

**GDD**: `design/gdd/hint-system.md`
**Requirements**: `TR-hint-system-007`, `TR-008`, `TR-011`

**ADR Governing Implementation**: ADR-003 (EventBus — listen to `win_condition_met` and `scene_completed` for deactivation) + ADR-004 (`_process` stops naturally when state is Dormant; pausing `process_mode` stops `_process`)
**ADR Decision Summary**: `win_condition_met` and `scene_completed` both push HS back to Dormant. Pausing the game stops `_process` entirely, which freezes the stagnation timer — no explicit pause guard needed.

**Engine**: Godot 4.3 | **Risk**: LOW
**Engine Notes**: `process_mode = PROCESS_MODE_INHERIT` (default) means pause stops `_process`. HS does not need `PROCESS_MODE_ALWAYS` — the timer should freeze when the game is paused.

---

## Acceptance Criteria

- [ ] On `win_condition_met()`: emit `hint_level_changed(0)`; enter Dormant state; `_timer` reset to 0
- [ ] On `scene_completed(scene_id)`: enter Dormant; reset all state (timer, hint level); no hint_level_changed emitted
- [ ] While paused (scene tree paused): `_process` does not run; stagnation timer does not advance
- [ ] `win_condition_met` while Dormant: ignored (no double deactivation)

---

## Implementation Notes

*Derived from ADR-003 + ADR-004 + GDD hint-system.md:*

```gdscript
func _on_win_condition_met() -> void:
    if _state == _State.DORMANT:
        return
    _state = _State.DORMANT
    _timer = 0.0
    EventBus.hint_level_changed.emit(0)

func _on_scene_completed(_scene_id: String) -> void:
    _state = _State.DORMANT
    _timer = 0.0
    # No hint_level_changed — scene is transitioning; UI will be reset anyway
```

- Process mode stays INHERIT (default) — pausing naturally freezes the timer. No code needed for TR-011.

---

## Out of Scope

- [Story 001]: Activation
- [Story 002]: Timer advancement and hint level signals

---

## QA Test Cases

- **AC-1**: win_condition_met deactivates + emits level 0
  - Given: HS in Hint2 state
  - When: `EventBus.win_condition_met.emit()`
  - Then: `hint_level_changed(0)` emitted; `_state == DORMANT`; `_timer == 0.0`

- **AC-2**: scene_completed resets quietly
  - Given: HS in Hint1 state; listener on hint_level_changed
  - When: `EventBus.scene_completed.emit("scene-01")`
  - Then: `_state == DORMANT`; `_timer == 0.0`; `hint_level_changed` NOT emitted

- **AC-3**: win_condition_met while Dormant is ignored
  - Given: HS already Dormant
  - When: `win_condition_met` fires
  - Then: `hint_level_changed` NOT emitted; no state change

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/hint_system/deactivation_test.gd` — must exist and pass

**Status**: [x] Created — 14 test functions

---

## Dependencies

- Depends on: story-002-stagnation-timer must be DONE; scene-goal-system `story-003-win-condition` must be DONE (emits scene_completed)
- Unlocks: None (final HintSystem story)
