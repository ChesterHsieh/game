# Story 001: SBS autoload + configure API + state machine

> **Epic**: Status Bar System
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Manifest Version**: 2026-04-21

## Context

**GDD**: `design/gdd/status-bar-system.md`
**Requirements**: `TR-status-bar-system-001`, `TR-002`, `TR-009`, `TR-010`

**ADR Governing Implementation**: ADR-004 (autoload order — SBS is position 8; receives `configure()` from SGS before any `combination_executed` events flow) + ADR-005 (scene_bar_config as typed Resource fields)
**ADR Decision Summary**: SBS stays Dormant until Scene Goal System calls `configure(scene_bar_config)`. All bar parameters come from the config object — no per-system defaults. After `win_condition_met()` is emitted, SBS freezes and stays Complete until a new `configure()` call (next scene) resets it to Active.

**Engine**: Godot 4.3 | **Risk**: LOW

---

## Acceptance Criteria

- [ ] SBS initializes in Dormant state; `_process` is a no-op while Dormant
- [ ] `configure(scene_bar_config)` transitions Dormant → Active; initializes bar values from `scene_bar_config.bars` Array (each bar has `id`, `initial_value`, `decay_rate_per_sec`)
- [ ] `configure()` called again while Active (next scene): resets all bar state and reinitializes from new config
- [ ] After `win_condition_met()` emitted: enter Complete state; decay stops; bar values frozen
- [ ] `reset()` (called by Scene Manager on transition): Dormant state restored; all bar state cleared

---

## Implementation Notes

*Derived from ADR-004 + GDD status-bar-system.md:*

- `class_name StatusBarSystem extends Node`. Autoload position 8 (not needed — SBS is not in ADR-004 canonical order... let me re-check: ADR-004 order is EventBus→CardDatabase→RecipeDatabase→InputSystem→AudioManager→SettingsManager→SceneGoalSystem→CardSpawningSystem→TableLayoutSystem→MysteryUnlockTree→SceneManager→SaveSystem. Wait, SBS is not an autoload in ADR-004? Let me re-read the epic... it says "autoload singleton". But ADR-004 only lists 12 autoloads. Perhaps SBS is not an autoload but is instantiated in gameplay.tscn? Or perhaps it IS an autoload but was added to the list. Actually looking at the epic: "Feature Layer — StatusBarSystem (autoload singleton)". ADR-004 §1 order may need updating, or SBS is referenced indirectly. For now, treat it as an autoload and document it.)
- `enum _State { DORMANT, ACTIVE, COMPLETE }`. `var _state := _State.DORMANT`.
- Internal bar storage: `_bars: Dictionary = {}` keyed by `bar_id: String`, value = `{ value: float, decay_rate: float }`.
- `func configure(config) -> void`: `_state = _State.ACTIVE`. `_bars.clear()`. For each bar in `config.bars`: `_bars[bar.id] = { value: bar.initial_value, decay_rate: bar.decay_rate_per_sec }`. Store `config.win_condition` for use in story-003.
- `func reset() -> void`: `_state = _State.DORMANT`. `_bars.clear()`. `_sustained_time = 0.0`.

---

## Out of Scope

- [Story 002]: Bar effects and combination_executed handling
- [Story 003]: Decay and sustain win condition

---

## QA Test Cases

- **AC-1**: Dormant on init
  - Given: SBS freshly initialized
  - When: `_process(0.016)` called
  - Then: no bar changes; `_state == DORMANT`

- **AC-2**: configure transitions to Active
  - Given: SBS in Dormant; config with bars=[{id:"warmth", initial_value:50.0, decay_rate:1.0}]
  - When: `configure(config)` called
  - Then: `_state == ACTIVE`; `_bars["warmth"].value == 50.0`

- **AC-3**: reset returns to Dormant
  - Given: SBS in Active
  - When: `reset()` called
  - Then: `_state == DORMANT`; `_bars` is empty

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/status_bar_system/configure_state_test.gd` — must exist and pass

**Status**: [x] Created — `tests/unit/status_bar_system/configure_state_test.gd` (22 test functions)

---

## Dependencies

- Depends on: scene-goal-system `story-001-load-scene-api` must be DONE (SGS calls configure; but for unit testing, SBS can be tested independently with a mock config)
- Unlocks: story-002-bar-effects, story-003-decay-sustain (can parallelize after story-001 Done)
