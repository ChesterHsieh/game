# Story 003: Win condition handling + scene_completed

> **Epic**: Scene Goal System
> **Status**: Complete
> **Layer**: Feature
> **Type**: Integration
> **Manifest Version**: 2026-04-21

## Context

**GDD**: `design/gdd/scene-goal-system.md`
**Requirements**: `TR-scene-goal-system-006`, `TR-008`

**ADR Governing Implementation**: ADR-003 (EventBus — listen for `win_condition_met` from SBS; emit `scene_completed(scene_id)` back on EventBus)
**ADR Decision Summary**: For the `sustain_above` goal, SGS delegates win detection entirely to SBS and listens for its `win_condition_met` signal. SGS's response is to emit `scene_completed` and enter Complete — it does not duplicate the win logic.

**Engine**: Godot 4.3 | **Risk**: LOW

---

## Acceptance Criteria

- [ ] SGS connects to `EventBus.win_condition_met` in `_ready()`
- [ ] On `win_condition_met()` while Active: emit `EventBus.scene_completed(scene_id)`; enter Complete state; disconnect or ignore further `win_condition_met` signals (no duplicate emissions)
- [ ] While Idle or Complete: `win_condition_met` is ignored
- [ ] After entering Complete, `get_goal_config()` still returns the active SceneData (for Hint System to read during the transition)

---

## Implementation Notes

*Derived from ADR-003 + GDD scene-goal-system.md:*

- Connect: `EventBus.win_condition_met.connect(_on_win_condition_met)` in `_ready()`.
- Handler:
  ```gdscript
  func _on_win_condition_met() -> void:
      if _state != _State.ACTIVE:
          return
      _state = _State.COMPLETE
      EventBus.scene_completed.emit(_active_data.scene_id)
  ```
- `get_goal_config()` returns `_active_data` when Complete as well as Active (only returns null when Idle after `reset()`).

---

## Out of Scope

- [Story 001]: SceneData loading and state machine
- [Story 002]: SBS.configure() and seed_cards_ready

---

## QA Test Cases

- **AC-1**: scene_completed fires on win
  - Given: SGS Active with scene_id="scene-01"; listener on EventBus.scene_completed
  - When: `EventBus.win_condition_met.emit()` fires
  - Then: `scene_completed("scene-01")` emitted; `_state == COMPLETE`

- **AC-2**: No duplicate scene_completed
  - Given: SGS already Complete
  - When: `win_condition_met` fires again
  - Then: `scene_completed` NOT emitted a second time

- **AC-3**: get_goal_config returns data while Complete
  - Given: SGS in Complete state
  - When: `get_goal_config()` called
  - Then: returns the active SceneData (not null)

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/scene_goal_system/win_condition_test.gd` — must exist and pass

**Status**: [x] Created — `tests/integration/scene_goal_system/win_condition_test.gd` (9 test functions)

---

## Dependencies

- Depends on: story-002-sbs-integration must be DONE; status-bar-system `story-003-decay-sustain` must be DONE (SBS emits win_condition_met)
- Unlocks: hint-system (HS listens to scene_completed for deactivation); scene-manager (SM listens to scene_completed for progression)
