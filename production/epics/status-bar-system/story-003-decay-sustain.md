# Story 003: Passive decay + sustain win condition

> **Epic**: Status Bar System
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Manifest Version**: 2026-04-21

## Context

**GDD**: `design/gdd/status-bar-system.md`
**Requirements**: `TR-status-bar-system-006`, `TR-007`, `TR-008`

**ADR Governing Implementation**: ADR-004 (SBS runs in `_process` each frame while Active; `win_condition_met` is terminal within a scene and freezes SBS until next `configure()`)
**ADR Decision Summary**: Decay and win monitoring run in `_process(delta)`. `win_condition_met` emits exactly once per scene and SBS transitions to Complete. Complete state suppresses all further bar updates and decay.

**Engine**: Godot 4.3 | **Risk**: LOW

---

## Acceptance Criteria

- [ ] While Active: each bar ticks down by `bar.decay_rate_per_sec * delta` every frame; values clamped at 0
- [ ] `sustain_above` win monitoring: `_sustained_time` increments by `delta` each frame when all active bars are ≥ `win_condition.threshold`; resets to 0 if any bar drops below threshold
- [ ] `win_condition_met()` emitted exactly once when `_sustained_time >= win_condition.duration_sec`
- [ ] After `win_condition_met()`: SBS enters Complete; decay stops; `_sustained_time` no longer increments; no duplicate emissions
- [ ] While Dormant or Complete: `_process` is a no-op (no decay, no monitoring)

---

## Implementation Notes

*Derived from GDD status-bar-system.md decay and sustain sections:*

```gdscript
func _process(delta: float) -> void:
    if _state != _State.ACTIVE:
        return

    # Decay
    for bar_id in _bars:
        _bars[bar_id].value = maxf(_bars[bar_id].value - _bars[bar_id].decay_rate * delta, 0.0)

    # Sustain check
    var all_above := true
    for bar_id in _bars:
        if _bars[bar_id].value < _win_threshold:
            all_above = false
            break

    if all_above:
        _sustained_time += delta
        if _sustained_time >= _win_duration_sec:
            _state = _State.COMPLETE
            EventBus.win_condition_met.emit()
    else:
        _sustained_time = 0.0

    EventBus.bar_values_changed.emit(_get_values_dict())
```

- `_win_threshold` and `_win_duration_sec` stored from `configure()` call.
- Emit `bar_values_changed` every frame while Active so Status Bar UI stays live. (Can be optimized later to only emit on change — out of scope here.)

---

## Out of Scope

- [Story 001]: configure() and FSM
- [Story 002]: combination_executed handling and bar effects

---

## QA Test Cases

- **AC-1**: Decay reduces bar value each frame
  - Given: SBS Active; "warmth" value=50.0; decay_rate=10.0/s
  - When: `_process(0.1)` called once
  - Then: "warmth".value ≈ 49.0

- **AC-2**: Decay clamped at 0
  - Given: "warmth" value=0.5; decay_rate=10.0/s
  - When: `_process(0.1)` called
  - Then: "warmth".value == 0.0 (not negative)

- **AC-3**: sustained_time resets when bar drops below threshold
  - Given: threshold=70.0; "warmth"=75.0; "connection"=65.0; _sustained_time=1.0
  - When: `_process(delta)` runs
  - Then: _sustained_time resets to 0.0 ("connection" < threshold)

- **AC-4**: win_condition_met fires exactly once
  - Given: threshold=50.0; duration_sec=1.0; both bars ≥ 50 continuously
  - When: `_process(0.5)` × 2 ticks
  - Then: `win_condition_met` emitted exactly once; SBS enters Complete; no second emission on third tick

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/status_bar_system/decay_sustain_test.gd` — must exist and pass

**Status**: [x] Created — `tests/unit/status_bar_system/decay_sustain_test.gd` (23 test functions)

---

## Dependencies

- Depends on: story-001-configure-state must be DONE
- Unlocks: scene-goal-system `story-003-win-condition`; hint-system `story-003-deactivation`
