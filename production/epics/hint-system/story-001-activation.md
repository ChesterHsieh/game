# Story 001: HintSystem autoload + goal-conditional activation

> **Epic**: Hint System
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Manifest Version**: 2026-04-21

## Context

**GDD**: `design/gdd/hint-system.md`
**Requirements**: `TR-hint-system-001`, `TR-002`, `TR-009`, `TR-010`

**ADR Governing Implementation**: ADR-004 (HS is autoload; initialized before any scene signals flow) + ADR-005 (`hint_stagnation_sec` from `SceneData.hint_stagnation_sec` field; fallback to 300s if 0 or absent)
**ADR Decision Summary**: HintSystem activates only for bar-type goals. It reads `stagnation_sec` from the loaded `SceneData` via `SceneGoalSystem.get_goal_config()` when `seed_cards_ready` fires.

**Engine**: Godot 4.3 | **Risk**: LOW

---

## Acceptance Criteria

- [ ] HintSystem initializes in Dormant state; `_process` is a no-op while Dormant
- [ ] On `seed_cards_ready`: calls `SceneGoalSystem.get_goal_config()`; if goal is a bar-type (sustain_above / reach_value): reset timer to 0, transition to Watching
- [ ] On `seed_cards_ready` with non-bar goal (find_key, sequence): stays Dormant
- [ ] `stagnation_sec` read from `goal_config.hint_stagnation_sec`; if 0 or absent: fallback to 300.0
- [ ] State machine: Dormant → Watching → Hint1 → Hint2 (and back via story-002)

---

## Implementation Notes

*Derived from ADR-004 + ADR-005 + GDD hint-system.md:*

- `class_name HintSystem extends Node`. `enum _State { DORMANT, WATCHING, HINT1, HINT2 }`. `var _state := _State.DORMANT`.
- Connect `EventBus.seed_cards_ready.connect(_on_seed_cards_ready)` in `_ready()`.
- `_on_seed_cards_ready(seed_cards) -> void`:
  ```gdscript
  var config := SceneGoalSystem.get_goal_config()
  if config == null or config.goal_type not in ["sustain_above", "reach_value"]:
      return  # stay Dormant
  _stagnation_sec = config.hint_stagnation_sec if config.hint_stagnation_sec > 0 else 300.0
  _timer = 0.0
  _state = _State.WATCHING
  ```
- `_process(delta)` only ticks when `_state == _State.WATCHING` (story-002 adds timer logic for Hint1/Hint2 transitions).

---

## Out of Scope

- [Story 002]: Stagnation timer and hint_level_changed signals
- [Story 003]: Deactivation on win and scene completion

---

## QA Test Cases

- **AC-1**: Bar goal activates Watching
  - Given: SceneGoalSystem.get_goal_config() returns SceneData with goal_type="sustain_above", hint_stagnation_sec=120.0
  - When: `EventBus.seed_cards_ready.emit([])` fires
  - Then: `_state == WATCHING`; `_stagnation_sec == 120.0`; `_timer == 0.0`

- **AC-2**: Non-bar goal stays Dormant
  - Given: goal_config.goal_type="find_key"
  - When: `seed_cards_ready` fires
  - Then: `_state == DORMANT`

- **AC-3**: Zero stagnation_sec falls back to 300s
  - Given: config.hint_stagnation_sec == 0.0
  - When: `seed_cards_ready` fires
  - Then: `_stagnation_sec == 300.0`

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/hint_system/activation_test.gd` — must exist and pass

**Status**: [x] Created — 10 test functions

---

## Dependencies

- Depends on: scene-goal-system `story-001-load-scene-api` must be DONE (SGS.get_goal_config() must exist)
- Unlocks: story-002-stagnation-timer
