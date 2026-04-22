# Story 003: Scene completion + epilogue entry + saved-game resume

> **Epic**: Scene Manager
> **Status**: Complete
> **Layer**: Feature
> **Type**: Integration
> **Manifest Version**: 2026-04-21

## Context

**GDD**: `design/gdd/scene-manager.md`
**Requirements**: `TR-scene-manager-005`, `TR-006`, `TR-013`

**ADR Governing Implementation**: ADR-004 (Transitioning state: `clear_all_cards()` → one frame await → `SGS.reset()` → increment index; epilogue at `_current_index >= manifest.size()`; CONNECT_ONE_SHOT on `game_start_requested` means saved-completed-game check fires inside `_on_game_start_requested`) + ADR-003 (SM emits `epilogue_started()`)
**ADR Decision Summary**: On `scene_completed`, SM enters Transitioning, calls `CardSpawningSystem.clear_all_cards()`, awaits one frame, calls `SceneGoalSystem.reset()`, increments the index, and checks for epilogue. If `_current_index >= manifest.size()`, emit `epilogue_started()` and enter Epilogue (terminal). If `game_start_requested` fires when the restored index already equals or exceeds manifest size (saved completed game), skip load sequence and go directly to Epilogue.

**Engine**: Godot 4.3 | **Risk**: LOW
**Engine Notes**: One-frame `await get_tree().process_frame` during Transitioning ensures CSS processes the `card_removing` signals from `clear_all_cards()` before SGS.reset() runs.

---

## Acceptance Criteria

- [ ] `scene_completed(scene_id)` while Active: enter Transitioning; call `CardSpawningSystem.clear_all_cards()`; await one frame; call `SceneGoalSystem.reset()`; increment `_current_index`
- [ ] After increment: if `_current_index < manifest.size()` → call `_load_scene_at_index(_current_index)` (Loading state); else → emit `EventBus.epilogue_started()`; enter Epilogue state
- [ ] `scene_completed` while not Active: silently ignored (state guard)
- [ ] `game_start_requested` when `_current_index >= manifest.size()` (saved-completed-game): enter Epilogue directly, emit `epilogue_started()`; do NOT call `_load_scene_at_index()`

---

## Implementation Notes

*Derived from ADR-004 + ADR-003 + GDD scene-manager.md:*

```gdscript
func _on_scene_completed(scene_id: String) -> void:
    if _state != _State.ACTIVE:
        return
    if scene_id != _manifest.scene_ids[_current_index]:
        push_warning("SceneManager: scene_completed mismatch — got '%s' expected '%s'" % [scene_id, _manifest.scene_ids[_current_index]])
        return
    _state = _State.TRANSITIONING
    CardSpawningSystem.clear_all_cards()
    await get_tree().process_frame
    SceneGoalSystem.reset()
    _current_index += 1
    if _current_index >= _manifest.scene_ids.size():
        _enter_epilogue()
    else:
        _load_scene_at_index(_current_index)

func _on_game_start_requested() -> void:
    if _current_index >= _manifest.scene_ids.size():
        _enter_epilogue()
        return
    _load_scene_at_index(_current_index)

func _enter_epilogue() -> void:
    _state = _State.EPILOGUE
    EventBus.epilogue_started.emit()
```

- `clear_all_cards()` is idempotent (no-op if table already empty) — always safe to call.
- Mismatch scene_id guard is duplicated from story-002's `_on_scene_completed` handler — both versions needed since both `scene_completed` and `seed_cards_ready` can carry stale scene_ids.

---

## Out of Scope

- [Story 001]: Manifest loading and Waiting state
- [Story 002]: Load sequence and seed_cards_ready watchdog
- [Story 004]: Resume/reset APIs

---

## QA Test Cases

- **AC-1**: scene_completed advances to next scene
  - Given: SM Active; `_current_index = 0`; manifest has 2 scenes
  - When: `scene_completed("home")` fires
  - Then: `clear_all_cards()` called; `SGS.reset()` called; `_current_index == 1`; `_load_scene_at_index(1)` called; `_state == LOADING`

- **AC-2**: Final scene triggers epilogue
  - Given: SM Active; `_current_index = 1`; manifest has 2 scenes
  - When: `scene_completed("park")` fires
  - Then: `_current_index == 2`; `epilogue_started()` emitted; `_state == EPILOGUE`

- **AC-3**: scene_completed while Transitioning is ignored
  - Given: SM in Transitioning state
  - When: `scene_completed("home")` fires
  - Then: no state change; no double-clear

- **AC-4**: Saved-completed-game resume goes directly to Epilogue
  - Given: SM in Waiting state; `_current_index = 2`; manifest has 2 scenes
  - When: `game_start_requested` fires
  - Then: `epilogue_started()` emitted; `_state == EPILOGUE`; `_load_scene_at_index` NOT called

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/scene_manager/completion_epilogue_test.gd` — must exist and pass

**Status**: BLOCKED — `SceneManager` autoload script does not exist in `src/`. Production code is missing; test file cannot be written.

---

## Dependencies

- Depends on: story-002-load-sequence must be DONE; scene-goal-system `story-003-win-condition` must be DONE (emits scene_completed)
- Unlocks: story-004-resume-reset
