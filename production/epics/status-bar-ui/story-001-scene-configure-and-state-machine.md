# Story 001: Scene Configure and State Machine

> **Epic**: Status Bar UI
> **Status**: Complete
> **Layer**: Presentation
> **Type**: Integration
> **Manifest Version**: 2026-04-21

## Context

**GDD**: `design/gdd/status-bar-ui.md`
**Requirement**: `TR-status-bar-ui-001`, `TR-status-bar-ui-008`, `TR-status-bar-ui-010`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-003: Inter-System Communication — EventBus Singleton; ADR-001: Naming Conventions — snake_case
**ADR Decision Summary**: StatusBarUI reads bar configuration via a direct autoload call to `SceneGoalSystem.get_goal_config()` on scene load (read-only query, not an event). Scene lifecycle resets are driven by EventBus signals (`scene_loading` or `scene_started`) rather than direct node references — no system holds a reference to another.

**Engine**: Godot 4.3 | **Risk**: LOW
**Engine Notes**: Tween API (`create_tween()`, chained `tween_property()`, `Tween.kill()`) stable in 4.3. Signal `connect(callable)` syntax. EventBus autoload stable.

**Control Manifest Rules (Presentation Layer)**:
- Required: Use EventBus autoload for all cross-system events — subscribe via `EventBus.signal_name.connect(callable)`
- Required: Direct autoload calls reserved for read-only queries (`SceneGoalSystem.get_goal_config()`)
- Required: Card visuals use `create_tween()` + chained `tween_property()` for all animation
- Forbidden: Never use direct node references or hardcoded node paths for inter-system communication

---

## Acceptance Criteria

*From GDD `design/gdd/status-bar-ui.md`, scoped to this story:*

- [ ] In a bar-type goal scene: two unlabelled bars render in the left panel on scene load
- [ ] Scene transition resets panel: bars empty, arcs hidden, state = Dormant
- [ ] Dormant state: panel visible but empty — no bars rendered, signals ignored
- [ ] Active state: bar goal scene loaded; `get_goal_config()` returns bars; bars rendered and updating
- [ ] Frozen state: entered on `win_condition_met()`; bars visible at final values; no further updates

---

## Implementation Notes

*Derived from governing ADR(s):*

**From ADR-003 (Signal Bus):**
- Call `SceneGoalSystem.get_goal_config()` directly in `_ready()` (or on `scene_started`) — this is a read-only query, not an EventBus event. Autoload calls for queries are the approved pattern.
- Subscribe to `EventBus.scene_loading` or `EventBus.scene_started` to trigger the reset sequence (bars empty, arcs hidden, state = Dormant). Do not hold a direct reference to SceneManager.
- Subscribe to `EventBus.win_condition_met` to enter the Frozen state. Disconnect or ignore `bar_values_changed` while Frozen.
- Signal connections must use typed callable syntax: `EventBus.win_condition_met.connect(_on_win_condition_met)` — string-based `connect()` is forbidden.

**From ADR-001 (Naming Conventions):**
- File: `status_bar_ui.gd`, scene: `status_bar_ui.tscn`, class: `class_name StatusBarUI`
- State enum: `PascalCase` name, `SCREAMING_SNAKE_CASE` values — e.g. `enum State { DORMANT, ACTIVE, FROZEN }`
- Private state variable: `var _state: State = State.DORMANT`
- Method for configure: `func _configure_bars(config: Dictionary) -> void`

**From Control Manifest (Presentation Layer):**
- StatusBarUI lives in `HudLayer` (CanvasLayer, `layer = 5`) inside `gameplay.tscn`.
- `HudLayer` hides itself on `epilogue_started` — StatusBarUI inherits this visibility and need not handle it independently.

---

## Out of Scope

- Story 002: Bar fill animation in response to `bar_values_changed`
- Story 003: Hint arc animation in response to `hint_level_changed`
- Story 004: Non-bar scene dormant behavior and signal isolation

---

## QA Test Cases

*For Integration — automated:*

- **AC-1**: Two unlabelled bars render in the left panel on scene load (bar-type goal)
  - Given: A bar-type goal scene is loaded; `SceneGoalSystem.get_goal_config()` returns a config with two bar IDs
  - When: StatusBarUI `_ready()` executes (or `scene_started` fires)
  - Then: Two bar nodes are visible in the left panel; state is `ACTIVE`
  - Edge cases: Config returns exactly one bar — one bar renders centered; config returns zero bars — panel is empty, warning logged, state remains `DORMANT`

- **AC-2**: Scene transition resets panel
  - Given: StatusBarUI is in `ACTIVE` state with bars visible and arcs showing
  - When: `scene_loading` (or equivalent reset signal) fires
  - Then: All bar fills are set to 0, all arc opacities are 0, state is `DORMANT`
  - Edge cases: Reset fires while a fill tween is in progress — tween is killed before reset; reset fires while already Dormant — idempotent, no error

- **AC-3**: Frozen state ignores further updates
  - Given: StatusBarUI is in `ACTIVE` state
  - When: `win_condition_met()` fires on EventBus
  - Then: State transitions to `FROZEN`; subsequent `bar_values_changed` signals are ignored (bars do not update)
  - Edge cases: `win_condition_met` fires while a tween is mid-flight — tween is killed, bars freeze at current displayed height

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/status-bar-ui/status_bar_ui_state_machine_test.gd`
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None (first story in the chain)
- Unlocks: Story 002 (Bar fill animation)
