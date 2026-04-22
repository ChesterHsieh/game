# Story 002: SBS integration + seed_cards_ready

> **Epic**: Scene Goal System
> **Status**: Complete
> **Layer**: Feature
> **Type**: Integration
> **Manifest Version**: 2026-04-21

## Context

**GDD**: `design/gdd/scene-goal-system.md`
**Requirements**: `TR-scene-goal-system-003`, `TR-004`, `TR-005`, `TR-007`

**ADR Governing Implementation**: ADR-003 (EventBus — emit `seed_cards_ready(seed_cards[])` after scene is configured; stubs listen to 6-param `combination_executed`) + ADR-004 (SGS calls `StatusBarSystem.configure()` as a direct autoload call — read/write service, not a signal)
**ADR Decision Summary**: `StatusBarSystem.configure()` is a direct call (not a signal) because it is a state-writing operation on a singleton, not a broadcast event. `seed_cards_ready` is an EventBus signal because Scene Manager and CardSpawningSystem both need to react to it.

**Engine**: Godot 4.3 | **Risk**: LOW

---

## Acceptance Criteria

- [ ] For `goal_type == "sustain_above"` (bar-type): call `StatusBarSystem.configure(scene_bar_config)` before emitting `seed_cards_ready`; `scene_bar_config` is constructed from the loaded `SceneData`
- [ ] For `goal_type == "find_key"` or `"sequence"`: do NOT call `StatusBarSystem.configure()`; only emit `seed_cards_ready`
- [ ] After configuring (or skipping for non-bar): emit `EventBus.seed_cards_ready(scene_data.seed_cards)`
- [ ] `find_key` and `sequence` stubs: connect to `EventBus.combination_executed` in `_ready()`; handler declares all 6 params; currently logs a debug message and does nothing else

---

## Implementation Notes

*Derived from ADR-003 + ADR-004 + GDD scene-goal-system.md:*

- After `_active_data` is loaded (story-001), continue `load_scene()`:
  ```gdscript
  if _active_data.goal_type == "sustain_above":
      var bar_config := _build_bar_config(_active_data)
      StatusBarSystem.configure(bar_config)
  # else: no SBS configuration for non-bar goals

  EventBus.seed_cards_ready.emit(_active_data.seed_cards)
  ```
- `_build_bar_config(data: SceneData) -> BarConfig`:
  ```gdscript
  var config := BarConfig.new()
  config.bars = data.bars
  config.max_value = data.win_condition.get("max_value", 100.0)
  config.win_condition = data.win_condition
  return config
  ```
- **Stubs**: in `_ready()`, `EventBus.combination_executed.connect(_on_combination_executed_stub)`. Handler: `func _on_combination_executed_stub(rid, tmpl, ia, ib, ca, cb): pass  # find_key/sequence monitoring — Vertical Slice`.

---

## Out of Scope

- [Story 001]: SceneData loading
- [Story 003]: Win condition listening and scene_completed

---

## QA Test Cases

- **AC-1**: Bar goal calls SBS.configure before seed_cards_ready
  - Given: SceneData with goal_type="sustain_above"; mock SBS.configure() callable
  - When: `load_scene("scene-01")` called
  - Then: `StatusBarSystem.configure()` called; then `seed_cards_ready` emitted (in that order)

- **AC-2**: Non-bar goal skips SBS.configure
  - Given: SceneData with goal_type="find_key"
  - When: `load_scene("find-key-scene")` called
  - Then: `StatusBarSystem.configure()` NOT called; `seed_cards_ready` still emitted

- **AC-3**: seed_cards_ready payload matches scene data
  - Given: SceneData with seed_cards=["morning-light","chester"]
  - When: `load_scene("scene-01")` called
  - Then: `seed_cards_ready(["morning-light","chester"])` emitted

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/scene_goal_system/sbs_integration_test.gd` — must exist and pass

**Status**: [x] Created — `tests/integration/scene_goal_system/sbs_integration_test.gd` (9 test functions)

---

## Dependencies

- Depends on: story-001-load-scene-api must be DONE; status-bar-system `story-001-configure-state` must be DONE
- Unlocks: story-003-win-condition
