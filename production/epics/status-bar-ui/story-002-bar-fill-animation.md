# Story 002: Bar Fill Animation

> **Epic**: Status Bar UI
> **Status**: Complete
> **Layer**: Presentation
> **Type**: Visual/Feel
> **Manifest Version**: 2026-04-21

## Context

**GDD**: `design/gdd/status-bar-ui.md`
**Requirement**: `TR-status-bar-ui-002`, `TR-status-bar-ui-004`, `TR-status-bar-ui-005`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-001: Naming Conventions — snake_case; ADR-003: Inter-System Communication — EventBus Singleton
**ADR Decision Summary**: StatusBarUI subscribes to `bar_values_changed` on EventBus using typed callable syntax — no direct reference to StatusBarSystem. All fill animation is driven by `create_tween()` + chained `tween_property()` as required by the Presentation Layer rules; no physics, no `_process` polling.

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

- [ ] `bar_values_changed` updates each named bar's fill to the correct height with a `bar_tween_sec` tween
- [ ] Fill animates bottom-to-top; a value of 0 shows an empty bar, max_value shows a full bar
- [ ] Two rapid `bar_values_changed` signals: second tween cancels the first and starts from current displayed height — no jump

---

## Implementation Notes

*Derived from governing ADR(s):*

**From ADR-003 (Signal Bus):**
- Subscribe in `_ready()`: `EventBus.bar_values_changed.connect(_on_bar_values_changed)` — typed callable, not string-based.
- Handler signature: `func _on_bar_values_changed(values: Dictionary) -> void` — `values` maps bar ID (`String`) to current value (`float`).
- Never reference StatusBarSystem directly. Never call StatusBarSystem methods. EventBus is the only channel.

**From ADR-001 (Naming Conventions):**
- Handler function: `_on_bar_values_changed` (signal callback prefix `_on_`)
- Tween duration variable: `bar_tween_sec` (snake_case, exported for tuning)
- Tuning constants or exports follow `@export var bar_tween_sec: float = 0.15`
- Per-bar tween references stored as private typed variables: `var _fill_tweens: Dictionary = {}`

**From Control Manifest (Presentation Layer):**
- Use `create_tween()` + `.tween_property(fill_node, "size:y", new_fill_height, bar_tween_sec)` — not `AnimationPlayer`, not manual `_process` lerp.
- To cancel an in-flight tween: call `tween.kill()` before creating the new tween. Read the bar node's current displayed `size.y` at cancel time so the new tween starts from the actual visual position — no snap or jump.
- State guard: if `_state != State.ACTIVE`, discard the signal and return immediately (Dormant and Frozen states ignore fill updates).

**Formula (from GDD):**
```
fill_height = (current_value / max_value) * bar_height_px
```
- `max_value` comes from `get_goal_config()` (read at scene load in Story 001)
- `bar_height_px` is a tuning knob (`@export var bar_height_px: float = 120.0`)

---

## Out of Scope

- Story 001: State machine and scene configure (prerequisite)
- Story 003: Hint arc animation — arc tween is separate from fill tween
- Story 004: Dormant/signal isolation behavior

---

## QA Test Cases

*For Visual/Feel — manual:*

- **AC-1**: `bar_values_changed` updates fill to correct height
  - Setup: Load a bar-type goal scene so StatusBarUI is Active with two bars. Use a debug emit tool or test scene to fire `EventBus.bar_values_changed.emit({"bar_a": 50.0, "bar_b": 25.0})` where `max_value = 100.0` and `bar_height_px = 120px`
  - Verify: Bar A fill height animates to 60px (50% of 120px); Bar B fill height animates to 30px (25% of 120px)
  - Pass condition: Both bars reach the target fill height at the end of the `bar_tween_sec` (0.15s) tween; fill is measured bottom-to-top (bottom of bar = empty, top = full)

- **AC-2**: Value 0 shows empty bar; max_value shows full bar
  - Setup: Fire `bar_values_changed` with value = 0 for one bar and value = max_value for the other
  - Verify: Bar with value 0 has fill height of 0px (visually empty); bar with max_value has fill height equal to `bar_height_px` (visually full)
  - Pass condition: No fill visible for 0; full fill visible for max_value; no overshoot or undershoot

- **AC-3**: Rapid double signal — no jump
  - Setup: Fire two `bar_values_changed` signals in quick succession (< 0.15s apart), changing bar value from 20 to 60 to 80
  - Verify: The bar does not jump to 60 and then snap to a new start; it smoothly continues toward 80 from wherever the fill was when the second signal arrived
  - Pass condition: At no point does the fill visually jump backward or skip. The transition from the first tween's mid-point to the final value of 80 is smooth.

---

## Test Evidence

**Story Type**: Visual/Feel
**Required evidence**: `production/qa/evidence/status-bar-ui-fill-animation-evidence.md`
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (Scene configure and state machine — provides Active state and bar nodes)
- Unlocks: Story 003 (Hint arc animation)
