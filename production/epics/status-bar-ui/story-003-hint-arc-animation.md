# Story 003: Hint Arc Animation

> **Epic**: Status Bar UI
> **Status**: Complete
> **Layer**: Presentation
> **Type**: Visual/Feel
> **Manifest Version**: 2026-04-21

## Context

**GDD**: `design/gdd/status-bar-ui.md`
**Requirement**: `TR-status-bar-ui-003`, `TR-status-bar-ui-006`, `TR-status-bar-ui-007`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-003: Inter-System Communication — EventBus Singleton; ADR-001: Naming Conventions — snake_case
**ADR Decision Summary**: StatusBarUI subscribes to `hint_level_changed` on EventBus using typed callable syntax — no direct reference to HintSystem. All arc opacity animation is driven by `create_tween()` + chained `tween_property()` on the arc node's `modulate.a` property.

**Engine**: Godot 4.3 | **Risk**: LOW
**Engine Notes**: Tween API (`create_tween()`, chained `tween_property()`, `Tween.kill()`) stable in 4.3. Signal `connect(callable)` syntax. `modulate.a` is a valid tween target on CanvasItem in 4.3. EventBus autoload stable.

**Control Manifest Rules (Presentation Layer)**:
- Required: Use EventBus autoload for all cross-system events — subscribe via `EventBus.signal_name.connect(callable)`
- Required: Direct autoload calls reserved for read-only queries (`SceneGoalSystem.get_goal_config()`)
- Required: Card visuals use `create_tween()` + chained `tween_property()` for all animation
- Forbidden: Never use direct node references or hardcoded node paths for inter-system communication

---

## Acceptance Criteria

*From GDD `design/gdd/status-bar-ui.md`, scoped to this story:*

- [ ] `hint_level_changed(1)`: all bar arcs begin fading in to `arc_faint_opacity` over `arc_fade_sec`
- [ ] `hint_level_changed(2)`: all bar arcs fade to full opacity (1.0) over `arc_fade_sec`
- [ ] `hint_level_changed(0)`: all bar arcs fade to hidden (0.0) over `arc_fade_sec`
- [ ] Hint level escalating from 1→2 before fade completes: no opacity jump; tween continues smoothly from current value
- [ ] Arc traces counterclockwise around each bar's border, starting from the top

---

## Implementation Notes

*Derived from governing ADR(s):*

**From ADR-003 (Signal Bus):**
- Subscribe in `_ready()`: `EventBus.hint_level_changed.connect(_on_hint_level_changed)` — typed callable, not string-based.
- Handler signature: `func _on_hint_level_changed(level: int) -> void`
- Never reference HintSystem directly. EventBus is the only channel.
- The edge case where `hint_level_changed` fires while Dormant (GDD Edge Cases table): store the incoming level but do not apply it to any arc node until state is Active.

**From ADR-001 (Naming Conventions):**
- Handler function: `_on_hint_level_changed` (signal callback prefix `_on_`)
- Tuning exports: `@export var arc_faint_opacity: float = 0.3`, `@export var arc_fade_sec: float = 1.5`
- Per-bar arc tween references stored as private typed variables: `var _arc_tweens: Dictionary = {}`
- Opacity mapping constant or local variable: use `SCREAMING_SNAKE_CASE` if declared as a constant — e.g. `const ARC_OPACITY_FULL: float = 1.0`

**From Control Manifest (Presentation Layer):**
- Use `create_tween()` + `.tween_property(arc_node, "modulate:a", target_opacity, arc_fade_sec)` for all opacity changes.
- To cancel an in-flight arc tween: call `tween.kill()` before creating the new one. Read the arc node's current `modulate.a` at cancel time so the new tween starts from the actual visual opacity — no jump.
- `hint_level_changed(0)` while arc is already at opacity 0: tween to 0 anyway — idempotent, no visible change (matches GDD Edge Cases).
- State guard: if `_state != State.ACTIVE`, store the level but do not start a tween. If state later becomes Active, apply the stored level.

**Arc direction (from GDD):**
- Arc traces counterclockwise around each bar's border, starting from the top. This is a layout/shader/draw decision — the arc node must be configured to sweep left from the top edge. The opacity tween controls visibility only; the arc geometry/draw order is set at scene build time.

**Opacity mapping (from GDD Formulas):**
```
Level 0 → target_opacity = 0.0
Level 1 → target_opacity = arc_faint_opacity   (default 0.3)
Level 2 → target_opacity = 1.0
tween arc.modulate.a from current to target_opacity over arc_fade_sec
```

---

## Out of Scope

- Story 001: State machine (prerequisite — provides Active state and arc nodes)
- Story 002: Bar fill animation — arc tween is independent of fill tween
- Story 004: Non-bar scene dormant behavior

---

## QA Test Cases

*For Visual/Feel — manual:*

- **AC-1**: `hint_level_changed(1)` fades arc to `arc_faint_opacity`
  - Setup: Load a bar-type goal scene; StatusBarUI is Active with arcs at opacity 0. Fire `EventBus.hint_level_changed.emit(1)`
  - Verify: Both bar arcs begin fading in. After `arc_fade_sec` (1.5s), both arcs are at opacity 0.3 — faint but visible
  - Pass condition: Fade is smooth (not instant); final opacity is 0.3 (not 0.0, not 1.0); both bars' arcs update simultaneously

- **AC-2**: `hint_level_changed(2)` fades arc to full opacity
  - Setup: Arcs are at any opacity (0, 0.3, or mid-tween). Fire `EventBus.hint_level_changed.emit(2)`
  - Verify: All bar arcs fade to opacity 1.0 over `arc_fade_sec`
  - Pass condition: Final opacity is 1.0; fade is smooth; both bars update simultaneously

- **AC-3**: `hint_level_changed(0)` fades arc to hidden
  - Setup: Arcs are at opacity 0.3 or 1.0. Fire `EventBus.hint_level_changed.emit(0)`
  - Verify: All bar arcs fade to opacity 0.0 over `arc_fade_sec`
  - Pass condition: Final opacity is 0.0 (fully hidden); fade is smooth; idempotent if already hidden (no error, no visible snap)

- **AC-4**: Level 1→2 escalation before fade completes — no jump
  - Setup: Fire `hint_level_changed(1)`. While arcs are mid-fade (e.g. at ~0.15 opacity), fire `hint_level_changed(2)`
  - Verify: Arc does not jump to any opacity value; it continues smoothly upward toward 1.0 from wherever it was
  - Pass condition: No visible opacity discontinuity; final opacity reaches 1.0

- **AC-5**: Arc direction — counterclockwise from top
  - Setup: With arcs visible at any opacity, inspect each bar's arc visually
  - Verify: The arc starts at the top of the bar border and sweeps to the left (counterclockwise)
  - Pass condition: Arc does not start at bottom or sweep clockwise

---

## Test Evidence

**Story Type**: Visual/Feel
**Required evidence**: `production/qa/evidence/status-bar-ui-arc-animation-evidence.md`
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002 (Bar fill animation — confirms Active state wiring and bar node structure are in place)
- Unlocks: Story 004 (Non-bar scenes and signal isolation)
