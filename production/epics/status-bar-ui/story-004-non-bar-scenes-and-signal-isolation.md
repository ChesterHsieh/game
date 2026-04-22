# Story 004: Non-Bar Scenes and Signal Isolation

> **Epic**: Status Bar UI
> **Status**: Complete
> **Layer**: Presentation
> **Type**: Logic
> **Manifest Version**: 2026-04-21

## Context

**GDD**: `design/gdd/status-bar-ui.md`
**Requirement**: `TR-status-bar-ui-009`, `TR-status-bar-ui-011`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-001: Naming Conventions — snake_case; ADR-003: Inter-System Communication — EventBus Singleton
**ADR Decision Summary**: StatusBarUI is a pure display component and a leaf node — it emits nothing to EventBus. For non-bar goal scenes, `get_goal_config()` returns a non-bar goal type and StatusBarUI stays Dormant with an empty panel. All signal handlers guard on state before acting, so signals received while Dormant are silently discarded with no side effects.

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

- [ ] In a non-bar goal scene: panel is empty; no bars, no arcs, no error
- [ ] Emits nothing (StatusBarUI is a pure display component)
- [ ] Panel with one bar renders correctly (bar centered); panel with two bars renders correctly (bars side by side or stacked)

---

## Implementation Notes

*Derived from governing ADR(s):*

**From ADR-003 (Signal Bus):**
- StatusBarUI must never call any `EventBus.*.emit(...)` — it is a leaf node and pure display component. No signals emitted, ever.
- The Dormant state guard established in Story 001 covers both `bar_values_changed` and `hint_level_changed`: if `_state != State.ACTIVE`, handlers return immediately without touching bar or arc nodes.
- `bar_values_changed` firing while Dormant (GDD Edge Cases): ignored — no update, no error.
- `hint_level_changed` firing while Dormant (GDD Edge Cases): ignored — arc opacity stored internally but not displayed until Active (if the scene ever becomes Active).
- The no-emit guarantee is structurally enforced: StatusBarUI contains no `EventBus.*.emit()` calls anywhere in its codebase.

**From ADR-001 (Naming Conventions):**
- Non-bar goal type check uses a typed comparison against an enum or string constant from the config — not a bare string literal in logic. Example: `if config.goal_type != GoalType.SUSTAIN_ABOVE and config.goal_type != GoalType.REACH_VALUE: return`
- Panel and bar nodes follow snake_case naming: `panel_container`, `bar_a_fill`, `bar_b_fill`
- One-bar layout uses a centering helper; the layout logic is in a private method: `func _layout_bars(bar_count: int) -> void`

**From Control Manifest (Global Rules):**
- Public methods must be unit-testable — the Dormant guard logic and the no-emit guarantee should be verifiable without a running scene. Expose a `get_state() -> State` method for test inspection.
- Doc comment required on any public method: `## Returns the current state of the StatusBarUI.`

**Layout behavior (from GDD Edge Cases):**
- One bar: render centered in the panel.
- Two bars: render side by side or stacked — layout is resolved in prototype, not prescribed here.
- Zero bars (content error): render empty panel, log a warning. State remains Dormant.

---

## Out of Scope

- Story 001: State machine wiring (prerequisite)
- Story 002: Fill animation implementation (prerequisite)
- Story 003: Arc animation implementation (prerequisite)
- Non-bar goal panel content for `find_key` and `sequence` scenes: deferred to Vertical Slice (GDD Open Questions)

---

## QA Test Cases

*For Logic — automated:*

- **AC-1**: Non-bar goal scene renders empty panel with no error
  - Given: `SceneGoalSystem.get_goal_config()` returns a config with goal type `find_key` or `sequence` (non-bar type)
  - When: StatusBarUI processes the config in `_ready()` (or on `scene_started`)
  - Then: State is `DORMANT`; no bar nodes are visible; no arc nodes are visible; no GDScript error is raised
  - Edge cases: Config returns an unknown goal type — same behavior as non-bar; state stays Dormant, no error

- **AC-2**: `bar_values_changed` ignored while Dormant
  - Given: StatusBarUI is in `DORMANT` state (non-bar scene loaded)
  - When: `EventBus.bar_values_changed.emit({"bar_a": 50.0})` fires
  - Then: No bar node fill height changes; no tween is started; no error is raised
  - Edge cases: Signal fires multiple times — each is silently discarded

- **AC-3**: `hint_level_changed` ignored while Dormant
  - Given: StatusBarUI is in `DORMANT` state
  - When: `EventBus.hint_level_changed.emit(1)` fires
  - Then: No arc node opacity changes; no tween is started; no error is raised
  - Edge cases: Level 2 then Level 0 fired while Dormant — all discarded silently

- **AC-4**: StatusBarUI emits nothing
  - Given: StatusBarUI is running in any state (Dormant, Active, or Frozen)
  - When: Any combination of signals fire on EventBus and user interactions occur
  - Then: No `EventBus.*.emit(...)` call is made by StatusBarUI code
  - Edge cases: This is a static code assertion — no `emit` call appears anywhere in `status_bar_ui.gd`

- **AC-5**: One-bar layout renders correctly
  - Given: `get_goal_config()` returns a config with exactly one bar ID
  - When: StatusBarUI configures itself
  - Then: One bar is visible and centered in the panel; state is `ACTIVE`
  - Edge cases: `bar_height_px` and `bar_width_px` tuning knobs apply correctly to the single bar

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/status-bar-ui/status_bar_ui_dormant_test.gd`
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 003 (Hint arc animation — all signal handling paths must be implemented before isolation can be verified end-to-end)
- Unlocks: None (final story in the epic)
