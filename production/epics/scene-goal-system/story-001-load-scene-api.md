# Story 001: SGS autoload + SceneData Resource + load_scene API

> **Epic**: Scene Goal System
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Manifest Version**: 2026-04-21

## Context

**GDD**: `design/gdd/scene-goal-system.md`
**Requirements**: `TR-scene-goal-system-001`, `TR-002`, `TR-009`, `TR-010`, `TR-011`, `TR-012`

**ADR Governing Implementation**: ADR-005 (`SceneData` as typed Resource; `ResourceLoader.load() as SceneData` with null check) + ADR-004 (SGS is autoload position 7)
**ADR Decision Summary**: Per-scene config lives in `assets/data/scenes/[scene_id].tres` as a typed `SceneData` Resource. SGS loads it on `load_scene()` call. Missing or wrong-type file stays SGS in Idle and logs an error — it never crashes.

**Engine**: Godot 4.3 | **Risk**: LOW
**Engine Notes**: `ResourceLoader.load() as SceneData` — if file exists but schema drifted, cast returns null. Null check is load-bearing (ADR-005 BLOCKING-1).

---

## Acceptance Criteria

- [ ] `SceneData` Resource class defined with typed `@export` fields: `scene_id: String`, `goal_type: String`, `seed_cards: Array`, `bars: Array`, `win_condition: Dictionary`, `hint_stagnation_sec: float`
- [ ] `load_scene(scene_id: String)` loads `res://assets/data/scenes/[scene_id].tres` via `ResourceLoader.load() as SceneData`; null check with `push_error` and stay Idle on failure
- [ ] On success: SGS transitions Idle → Active; stores loaded `SceneData`
- [ ] `get_goal_config()` returns the active `SceneData` while Active; returns null while Idle
- [ ] `reset()`: transitions Active/Complete → Idle; clears stored SceneData
- [ ] A new `.tres` file added to `assets/data/scenes/` is loadable without code changes

---

## Implementation Notes

*Derived from ADR-005 + GDD scene-goal-system.md:*

- `SceneData` class (`res://src/data/scene_data.gd`):
  ```gdscript
  class_name SceneData extends Resource
  @export var scene_id: String = ""
  @export var goal_type: String = "sustain_above"
  @export var seed_cards: Array = []
  @export var bars: Array = []
  @export var win_condition: Dictionary = {}
  @export var hint_stagnation_sec: float = 300.0
  ```
- `load_scene(scene_id: String) -> void`:
  ```gdscript
  var path := "res://assets/data/scenes/%s.tres" % scene_id
  var data := ResourceLoader.load(path) as SceneData
  if data == null:
      push_error("SGS: failed to load SceneData for '%s'" % scene_id)
      return
  _active_data = data
  _state = _State.ACTIVE
  ```
- `get_goal_config() -> SceneData`: return `_active_data if _state == _State.ACTIVE else null`.
- `reset() -> void`: `_state = _State.IDLE; _active_data = null`.

---

## Out of Scope

- [Story 002]: SBS integration, seed_cards_ready emission, find_key/sequence stubs
- [Story 003]: Win condition handling, scene_completed emission

---

## QA Test Cases

- **AC-1**: Missing .tres stays Idle
  - Given: no file at `res://assets/data/scenes/nonexistent.tres`
  - When: `load_scene("nonexistent")` called
  - Then: `push_error` called; `_state == IDLE`; `get_goal_config()` returns null

- **AC-2**: Valid .tres transitions to Active
  - Given: `scene-01.tres` exists as valid `SceneData` Resource
  - When: `load_scene("scene-01")` called
  - Then: `_state == ACTIVE`; `get_goal_config()` returns the loaded SceneData

- **AC-3**: reset returns to Idle
  - Given: SGS Active
  - When: `reset()` called
  - Then: `_state == IDLE`; `get_goal_config()` returns null

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/scene_goal_system/load_scene_api_test.gd` — must exist and pass

**Status**: [x] Created — `tests/unit/scene_goal_system/load_scene_api_test.gd` (12 test functions)

---

## Dependencies

- Depends on: card-database `story-002-card-entry-manifest-resources` must be DONE (SceneData Resource class pattern follows same ADR-005 approach)
- Unlocks: story-002-sbs-integration, status-bar-system `story-001-configure-state`
