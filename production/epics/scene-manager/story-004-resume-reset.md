# Story 004: Resume Index API + reset_to_waiting()

> **Epic**: Scene Manager
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Manifest Version**: 2026-04-21

## Context

**GDD**: `design/gdd/scene-manager.md`
**Requirements**: `TR-scene-manager-011`, `TR-012`, `TR-014`, `TR-015`

**ADR Governing Implementation**: ADR-004 (Resume Index API: `get_resume_index()` pure read; `set_resume_index()` guarded to Waiting state only; `reset_to_waiting()` cancels watchdog, clears cards/goal state, re-arms one-shot)
**ADR Decision Summary**: `set_resume_index()` is a startup-only setter — it rejects calls from any non-Waiting state and rejects negative indices. `reset_to_waiting()` is the full reset path for the Reset Progress flow: it restores SM to a state indistinguishable from fresh launch, re-arming the `CONNECT_ONE_SHOT` listener.

**Engine**: Godot 4.3 | **Risk**: LOW
**Engine Notes**: `CONNECT_ONE_SHOT` is consumed on the first `game_start_requested` fire. `reset_to_waiting()` must re-call `EventBus.game_start_requested.connect(handler, CONNECT_ONE_SHOT)` to re-arm. Calling `disconnect()` on a signal that is not connected raises an error — check `is_connected()` before disconnecting stale handlers.

---

## Acceptance Criteria

- [ ] `get_resume_index() -> int`: returns `_current_index`; no signals; safe from any state
- [ ] `set_resume_index(index: int) -> void`: guarded — only valid in Waiting state; rejects negative values with error log; accepts `index >= manifest.size()` (saved-completed-game); logs error and returns without mutating if called outside Waiting
- [ ] `reset_to_waiting()` from Loading: cancel watchdog timer before state mutation; disconnect stale `seed_cards_ready` handler if connected
- [ ] `reset_to_waiting()` from Active / Transitioning: call `CardSpawningSystem.clear_all_cards()` and `SceneGoalSystem.reset()`
- [ ] `reset_to_waiting()` from Epilogue: skip clear step (no cards); no SGS reset needed
- [ ] `reset_to_waiting()` from any state: set `_current_index = 0`; re-arm `CONNECT_ONE_SHOT` on `game_start_requested`; set `_state = WAITING`; emit no signals

---

## Implementation Notes

*Derived from ADR-004 + GDD scene-manager.md:*

```gdscript
func get_resume_index() -> int:
    return _current_index

func set_resume_index(index: int) -> void:
    if _state != _State.WAITING:
        push_error("SceneManager: set_resume_index called outside Waiting state — ignored")
        return
    if index < 0:
        push_error("SceneManager: set_resume_index negative index %d — ignored" % index)
        return
    _current_index = index

func reset_to_waiting() -> void:
    if _state == _State.LOADING:
        _cancel_watchdog()
        if EventBus.seed_cards_ready.is_connected(_on_seed_cards_ready):
            EventBus.seed_cards_ready.disconnect(_on_seed_cards_ready)
    elif _state in [_State.ACTIVE, _State.TRANSITIONING]:
        CardSpawningSystem.clear_all_cards()
        SceneGoalSystem.reset()
    # _State.EPILOGUE and _State.WAITING: nothing to clear
    _current_index = 0
    _state = _State.WAITING
    if not EventBus.game_start_requested.is_connected(_on_game_start_requested):
        EventBus.game_start_requested.connect(_on_game_start_requested, CONNECT_ONE_SHOT)
```

- `reset_to_waiting()` emits no signals. SaveSystem or UI is responsible for any screen transition.
- `set_resume_index()` does NOT clamp indices above `manifest.size()` — a saved "completed" index correctly drives the saved-game-epilogue path (story-003).

---

## Out of Scope

- [Story 001]: Manifest loading and Waiting state setup
- [Story 002]: Scene Load Sequence
- [Story 003]: Completion and epilogue entry

---

## QA Test Cases

- **AC-1**: get_resume_index returns current index
  - Given: SM with `_current_index = 2`
  - When: `get_resume_index()` called
  - Then: returns `2`; no side effects

- **AC-2**: set_resume_index accepted in Waiting
  - Given: SM in Waiting state; manifest present
  - When: `set_resume_index(3)` called
  - Then: `_current_index == 3`; no signals emitted

- **AC-3**: set_resume_index rejected outside Waiting
  - Given: SM in Active state
  - When: `set_resume_index(1)` called
  - Then: `_current_index` unchanged; error logged

- **AC-4**: set_resume_index rejects negative
  - Given: SM in Waiting state
  - When: `set_resume_index(-1)` called
  - Then: `_current_index` unchanged; error logged

- **AC-5**: reset_to_waiting from Loading cancels watchdog
  - Given: SM in Loading state; watchdog timer running
  - When: `reset_to_waiting()` called
  - Then: watchdog cancelled; `_state == WAITING`; `_current_index == 0`; game_start_requested re-armed

- **AC-6**: reset_to_waiting from Epilogue skips clear
  - Given: SM in Epilogue state
  - When: `reset_to_waiting()` called
  - Then: `clear_all_cards()` NOT called; `_state == WAITING`; one-shot re-armed

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/scene_manager/resume_reset_test.gd` — must exist and pass

**Status**: BLOCKED — `SceneManager` autoload script does not exist in `src/`. Production code is missing; test file cannot be written.

---

## Dependencies

- Depends on: story-003-completion-epilogue must be DONE
- Unlocks: None (final SceneManager story)
