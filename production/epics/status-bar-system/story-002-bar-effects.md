# Story 002: Bar effects + combination_executed handler

> **Epic**: Status Bar System
> **Status**: Complete
> **Layer**: Feature
> **Type**: Integration
> **Manifest Version**: 2026-04-21

## Context

**GDD**: `design/gdd/status-bar-system.md`
**Requirements**: `TR-status-bar-system-003`, `TR-004`, `TR-005`, `TR-011`, `TR-012`

**ADR Governing Implementation**: ADR-003 (EventBus — listen to `combination_executed` with all 6 params) + ADR-005 (`bar-effects.tres` as typed `BarEffects` Resource loaded via `ResourceLoader.load() as BarEffects`)
**ADR Decision Summary**: Bar effects are authored in `assets/data/bar-effects.tres` — a flat `recipe_id → {bar_id: delta}` map. SBS loads this Resource once at `_ready()`, not on every combination. The handler must declare all 6 parameters of `combination_executed` (Godot 4.3 arity-strict) even though it only reads `recipe_id`.

**Engine**: Godot 4.3 | **Risk**: LOW
**Engine Notes**: `ResourceLoader.load("res://assets/data/bar-effects.tres") as BarEffects` — null check required per ADR-005 BLOCKING-1 guard.

---

## Acceptance Criteria

- [ ] SBS loads `assets/data/bar-effects.tres` at `_ready()` via `ResourceLoader.load() as BarEffects`; null check with `push_error` on failure
- [ ] `combination_executed` handler declares all 6 parameters; only uses `recipe_id` (arg 0)
- [ ] On `combination_executed`: look up `recipe_id` in loaded bar effects; for each bar delta: clamp result to `[0, max_value]`; emit `EventBus.bar_values_changed(values: Dictionary)` with updated `{bar_id: value}` map
- [ ] While Dormant or Complete: `combination_executed` signal is ignored (no bar updates)
- [ ] Unknown `recipe_id` in bar effects: no update, no error (recipe simply has no bar effect — valid)
- [ ] Unknown `bar_id` in a bar effect entry: skip that delta, log `push_warning`, apply valid bar deltas

---

## Implementation Notes

*Derived from ADR-003 + ADR-005 + GDD status-bar-system.md:*

- In `_ready()`: `_bar_effects = ResourceLoader.load("res://assets/data/bar-effects.tres") as BarEffects`. If null: `push_error("StatusBarSystem: bar-effects.tres missing or wrong type")`.
- Handler signature: `func _on_combination_executed(recipe_id: String, template: String, ia: String, ib: String, ca: String, cb: String) -> void`. Check `_state != _State.ACTIVE` → return.
- Look up: `var effect := _bar_effects.get_effect(recipe_id)` (returns null or `{bar_id: delta}` dict). If null → return (no bar effect for this recipe).
- Apply: for each `bar_id, delta` in effect: if `_bars.has(bar_id)`: `_bars[bar_id].value = clamp(_bars[bar_id].value + delta, 0.0, _max_value)`. Else: `push_warning("SBS: unknown bar_id '%s'" % bar_id)`.
- After applying all deltas: `EventBus.bar_values_changed.emit(_get_values_dict())`. `_get_values_dict()` returns `{bar_id: value}` for all active bars.
- `BarEffects` Resource class (to create in `src/data/bar_effects.gd`): `class_name BarEffects extends Resource`; `@export var effects: Dictionary = {}` (recipe_id → Dictionary of bar_id → float). `func get_effect(recipe_id: String) -> Variant: return effects.get(recipe_id, null)`.

---

## Out of Scope

- [Story 001]: configure() and state machine
- [Story 003]: Decay and sustain win condition logic

---

## QA Test Cases

- **AC-1**: bar_values_changed fires with correct values
  - Given: SBS Active; _bars={"warmth":50.0}; bar_effects has recipe "morning-light+chester" → {"warmth": +20.0}; max_value=100
  - When: `combination_executed("morning-light+chester", "additive", ...)` fires
  - Then: `bar_values_changed({"warmth": 70.0})` emitted

- **AC-2**: Clamping at max_value
  - Given: _bars={"warmth":90.0}; effect={"warmth": +20.0}; max_value=100
  - When: combination_executed fires
  - Then: `bar_values_changed({"warmth": 100.0})` (clamped, not 110.0)

- **AC-3**: Unknown bar_id skipped with warning
  - Given: effect has {"unknown_bar": +10.0, "warmth": +5.0}; SBS only has "warmth"
  - When: combination_executed fires
  - Then: `push_warning` called for "unknown_bar"; "warmth" still updated; no crash

- **AC-4**: Dormant SBS ignores combination_executed
  - Given: SBS in Dormant state
  - When: combination_executed fires
  - Then: no bar_values_changed emitted; _bars unchanged

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/status_bar_system/bar_effects_test.gd` — must exist and pass

**Status**: [x] Created — `tests/integration/status_bar_system/bar_effects_test.gd` (16 test functions)

---

## Dependencies

- Depends on: story-001-configure-state must be DONE; ITF `story-004-executed-cooldown` must be DONE (combination_executed signal flowing)
- Unlocks: story-003-decay-sustain
