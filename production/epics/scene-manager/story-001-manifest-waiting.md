# Story 001: SM autoload + manifest load + Waiting state

> **Epic**: Scene Manager
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Manifest Version**: 2026-04-21

## Context

**GDD**: `design/gdd/scene-manager.md`
**Requirements**: `TR-scene-manager-001`, `TR-002`, `TR-007`, `TR-008`, `TR-010`, `TR-016`, `TR-017`, `TR-018`, `TR-020`

**ADR Governing Implementation**: ADR-004 (SM is autoload position 11; `CONNECT_ONE_SHOT` for `game_start_requested`; `process_mode = PROCESS_MODE_ALWAYS`; defer first frame via `await get_tree().process_frame`) + ADR-005 (`scene-manifest.tres` as `SceneManifest` Resource; null check required)
**ADR Decision Summary**: Scene Manager enters Waiting state at `_ready()`, defers one frame before signals flow, validates all dependency autoloads, and loads the scene manifest via `ResourceLoader.load() as SceneManifest`. Missing or malformed manifest → enter Epilogue immediately (no crash).

**Engine**: Godot 4.3 | **Risk**: LOW
**Engine Notes**: `CONNECT_ONE_SHOT` flag causes the connection to auto-disconnect after first fire. `process_mode = PROCESS_MODE_ALWAYS` required so `await get_tree().process_frame` doesn't hang during pause. Autoload order guarantees all dependencies (EventBus, SGS, CSS, TLS, MUT) are initialized before SM position 11.

---

## Acceptance Criteria

- [ ] SceneManager is autoload singleton; `class_name SceneManager extends Node`; `enum _State { WAITING, LOADING, ACTIVE, TRANSITIONING, EPILOGUE }`; `var _state := _State.WAITING`
- [ ] `process_mode = PROCESS_MODE_ALWAYS` set in `_ready()` (or exported in scene)
- [ ] `_ready()`: await one frame (`await get_tree().process_frame`) before any signal work
- [ ] Validate required autoloads non-null (EventBus, SceneGoalSystem, CardSpawningSystem, TableLayoutSystem); log fatal error for any missing
- [ ] Load `assets/data/scene-manifest.tres` as `SceneManifest` Resource; on null result: log fatal error, enter Epilogue state, emit `epilogue_started()`
- [ ] On manifest load success: connect `EventBus.game_start_requested` with `CONNECT_ONE_SHOT`; remain in Waiting state
- [ ] Duplicate scene_ids in manifest accepted without reordering; log debug note
- [ ] All state machine signal handlers guard against unexpected states (e.g. `scene_completed` while not Active)

---

## Implementation Notes

*Derived from ADR-004 + ADR-005 + GDD scene-manager.md:*

```gdscript
class_name SceneManager extends Node

enum _State { WAITING, LOADING, ACTIVE, TRANSITIONING, EPILOGUE }
var _state := _State.WAITING
var _manifest: SceneManifest
var _current_index: int = 0
var _seed_cards_ready_timeout_sec: float = 5.0

func _ready() -> void:
    process_mode = PROCESS_MODE_ALWAYS
    await get_tree().process_frame
    _validate_dependencies()
    _manifest = ResourceLoader.load("res://assets/data/scene-manifest.tres") as SceneManifest
    if _manifest == null:
        push_error("SceneManager: scene-manifest.tres missing or malformed — entering Epilogue")
        _enter_epilogue()
        return
    _check_duplicate_scene_ids()
    EventBus.game_start_requested.connect(_on_game_start_requested, CONNECT_ONE_SHOT)

func _validate_dependencies() -> void:
    for dep in [EventBus, SceneGoalSystem, CardSpawningSystem, TableLayoutSystem]:
        if dep == null:
            push_error("SceneManager: required autoload missing — check project.godot autoload order")
```

- `_check_duplicate_scene_ids()`: iterate manifest scene_ids; track seen set; log `print("SceneManager: duplicate scene_id '%s' in manifest — allowed")` for each duplicate found.
- `_enter_epilogue()`: set `_state = _State.EPILOGUE`; emit `EventBus.epilogue_started()`.
- State guard pattern for all handlers: `if _state != _State.EXPECTED: return`.

---

## Out of Scope

- [Story 002]: Scene Load Sequence and watchdog timer
- [Story 003]: Scene completion, epilogue entry, and saved-completed-game resume
- [Story 004]: Resume Index API and `reset_to_waiting()`

---

## QA Test Cases

- **AC-1**: Valid manifest → Waiting state + one-shot connection
  - Given: valid `scene-manifest.tres` loaded; all autoloads present
  - When: `_ready()` completes
  - Then: `_state == WAITING`; `EventBus.game_start_requested` has one connection

- **AC-2**: Missing manifest → Epilogue + epilogue_started emitted
  - Given: `scene-manifest.tres` not found (ResourceLoader returns null)
  - When: `_ready()` runs
  - Then: `_state == EPILOGUE`; `EventBus.epilogue_started` emitted once

- **AC-3**: PROCESS_MODE_ALWAYS set
  - Given: SM node in scene tree
  - When: `_ready()` runs
  - Then: `process_mode == PROCESS_MODE_ALWAYS`

- **AC-4**: Duplicate scene_ids accepted
  - Given: manifest with `["home", "park", "home"]`
  - When: `_ready()` loads manifest
  - Then: no error; `_manifest` loaded; debug note logged

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/scene_manager/manifest_waiting_test.gd` — must exist and pass

**Status**: BLOCKED — `SceneManager` autoload script does not exist in `src/`. No `.gd` file found anywhere under `src/scenes/`, `src/gameplay/`, or `src/core/`; `project.godot` contains no `SceneManager` autoload entry. Test file cannot be written until the production implementation exists.

---

## Dependencies

- Depends on: foundation/autoload-setup `story-001` must be DONE (EventBus available); scene-goal-system `story-001` must be DONE; card-spawning-system `story-001` must be DONE; table-layout-system `story-001` must be DONE
- Unlocks: story-002-load-sequence
