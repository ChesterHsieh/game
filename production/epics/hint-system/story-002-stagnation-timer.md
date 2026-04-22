# Story 002: Stagnation timer + hint_level_changed

> **Epic**: Hint System
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Manifest Version**: 2026-04-21

## Context

**GDD**: `design/gdd/hint-system.md`
**Requirements**: `TR-hint-system-003`, `TR-004`, `TR-005`, `TR-006`, `TR-012`

**ADR Governing Implementation**: ADR-003 (EventBus — listen to `combination_executed` 6-param; emit `hint_level_changed(level: int)`)
**ADR Decision Summary**: The stagnation timer advances in `_process(delta)` and resets on every `combination_executed`. `hint_level_changed(0)` is idempotent — it is emitted whenever a combination fires, even if the hint is already at level 0.

**Engine**: Godot 4.3 | **Risk**: LOW
**Engine Notes**: Handler must declare all 6 params (Godot 4.3 arity-strict) even though HS ignores all of them.

---

## Acceptance Criteria

- [ ] While Watching: `_timer` increments by `delta` each frame
- [ ] At `_timer >= stagnation_sec`: emit `hint_level_changed(1)`; enter Hint1 state
- [ ] At `_timer >= stagnation_sec * 2`: emit `hint_level_changed(2)`; enter Hint2 state
- [ ] On any `combination_executed` while Watching / Hint1 / Hint2: emit `hint_level_changed(0)`; reset `_timer` to 0; return to Watching
- [ ] `hint_level_changed(0)` emitted even if already at level 0 (idempotent — does not skip)
- [ ] `combination_executed` handler declares all 6 params; ignores all payload values

---

## Implementation Notes

*Derived from ADR-003 + GDD hint-system.md:*

```gdscript
func _process(delta: float) -> void:
    if _state not in [_State.WATCHING, _State.HINT1, _State.HINT2]:
        return
    _timer += delta
    if _state == _State.WATCHING and _timer >= _stagnation_sec:
        _state = _State.HINT1
        EventBus.hint_level_changed.emit(1)
    elif _state == _State.HINT1 and _timer >= _stagnation_sec * 2.0:
        _state = _State.HINT2
        EventBus.hint_level_changed.emit(2)

func _on_combination_executed(_rid, _tmpl, _ia, _ib, _ca, _cb) -> void:
    if _state not in [_State.WATCHING, _State.HINT1, _State.HINT2]:
        return
    _timer = 0.0
    _state = _State.WATCHING
    EventBus.hint_level_changed.emit(0)
```

---

## Out of Scope

- [Story 001]: Activation and stagnation_sec loading
- [Story 003]: Deactivation on win and scene completion

---

## QA Test Cases

- **AC-1**: Timer crosses threshold into Hint1
  - Given: HS Watching; _stagnation_sec=10.0; _timer=0.0
  - When: `_process(10.1)` called
  - Then: `hint_level_changed(1)` emitted; `_state == HINT1`

- **AC-2**: Timer crosses into Hint2
  - Given: HS Hint1; _stagnation_sec=10.0; _timer=10.1
  - When: `_process(10.0)` called (brings timer to ≥20.0)
  - Then: `hint_level_changed(2)` emitted; `_state == HINT2`

- **AC-3**: Combination resets timer from Hint2
  - Given: HS Hint2; _timer=22.0
  - When: `combination_executed` fires (with 6 dummy params)
  - Then: `hint_level_changed(0)` emitted; `_timer == 0.0`; `_state == WATCHING`

- **AC-4**: hint_level_changed(0) emitted even at level 0
  - Given: HS Watching; _timer=0.5 (no hint showing yet)
  - When: combination_executed fires
  - Then: `hint_level_changed(0)` emitted; timer reset

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/hint_system/stagnation_timer_test.gd` — must exist and pass

**Status**: [x] Created — 13 test functions

---

## Dependencies

- Depends on: story-001-activation must be DONE; ITF `story-003-additive-template` must be DONE (combination_executed signal established)
- Unlocks: story-003-deactivation
