# Story 002: Cooldown State Machine

> **Epic**: Interaction Template Framework
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Manifest Version**: 2026-04-21

## Context

**GDD**: `design/gdd/interaction-template-framework.md`
**Requirements**: `TR-interaction-template-framework-006`, `TR-interaction-template-framework-007`, `TR-interaction-template-framework-016`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-003: Inter-System Communication — EventBus Singleton
**ADR Decision Summary**: All inter-system events flow through EventBus. `combination_succeeded` and `combination_failed` are emitted to Card Engine via EventBus — Card Engine listens and returns cards to Idle or begins animations.

**Engine**: Godot 4.3 | **Risk**: LOW
**Engine Notes**: Use `Time.get_ticks_msec()` (not deprecated `OS.get_ticks_msec()`) for cooldown timing. Cooldown check converts msec to seconds: `(Time.get_ticks_msec() - last_fired_msec[recipe_id]) / 1000.0 >= combination_cooldown_sec`.

**Control Manifest Rules (Feature Layer)**:
- Required: Use EventBus for all cross-system events
- Required: Gameplay values are data-driven — `combination_cooldown_sec` is a constant (tuning knob), not hardcoded magic number
- Forbidden: Never use direct node references for inter-system communication

---

## Acceptance Criteria

*From GDD `design/gdd/interaction-template-framework.md`, scoped to this story:*

- [ ] Given a valid recipe found by lookup AND recipe is NOT on cooldown: emit `EventBus.combination_succeeded(instance_id_a, instance_id_b, template, config)`
- [ ] Given a valid recipe found by lookup AND recipe IS on cooldown: emit `EventBus.combination_failed(instance_id_a, instance_id_b)` — do NOT start a new cooldown timer
- [ ] After `combination_cooldown_sec` seconds elapse since last fire: same recipe is Available again and fires `combination_succeeded` on next attempt
- [ ] `combination_cooldown_sec` constant defaults to `30.0` seconds; changing it in code affects all recipes without other changes
- [ ] Per-recipe cooldown state: `Available` (default, never-fired, or timer expired) vs `Cooling` (fired, timer active)
- [ ] First-ever attempt on a recipe is always Available (no prior cooldown entry)

---

## Implementation Notes

*Derived from ADR-003 Implementation Guidelines:*

- Add `_last_fired_msec: Dictionary = {}` — keys are `recipe_id: String`, values are `int` (msec timestamp)
- Add constant `const COMBINATION_COOLDOWN_SEC: float = 30.0`
- `_is_on_cooldown(recipe_id: String) -> bool`: `return _last_fired_msec.has(recipe_id) and (Time.get_ticks_msec() - _last_fired_msec[recipe_id]) / 1000.0 < COMBINATION_COOLDOWN_SEC`
- In `_on_combination_attempted`: after successful `RecipeDatabase.lookup()`, call `_is_on_cooldown(recipe.id)`. If cooling: emit `combination_failed`. If available: emit `combination_succeeded(instance_id_a, instance_id_b, recipe.template, recipe.config)` then `_last_fired_msec[recipe.id] = Time.get_ticks_msec()`.
- `combination_succeeded` carries `template` and `config` so Card Engine knows what animation to begin (merge tween, animate motion, etc.) — the config `Dictionary` is opaque passthrough from `RecipeEntry.config`.
- The "no cooldown for first attempt" case is handled naturally: `_last_fired_msec` has no entry, so `_is_on_cooldown` returns false.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: The recipe lookup and combination_failed for no-recipe case
- Story 003–006: Actual template execution (what happens after combination_succeeded is emitted)
- Story 007: Suspend/Resume pausing the cooldown timers

---

## QA Test Cases

**AC-1**: combination_succeeded on first valid hit
- Given: recipe `"chester-ju"` exists in RecipeDatabase, ITF has no cooldown entry for it
- When: `combination_attempted("chester_0", "ju_0")` fires
- Then: `combination_succeeded("chester_0", "ju_0", recipe.template, recipe.config)` is emitted; `combination_failed` is NOT emitted

**AC-2**: combination_failed on cooldown
- Given: recipe `"chester-ju"` just fired (cooldown started), `COMBINATION_COOLDOWN_SEC = 30.0`
- When: `combination_attempted("chester_0", "ju_0")` fires again immediately
- Then: `combination_failed("chester_0", "ju_0")` is emitted; `combination_succeeded` is NOT emitted; no new cooldown timestamp written
- Edge cases: attempt at `t = 29.9s` → still cooling; attempt at `t = 30.0s` → Available

**AC-3**: Cooldown expires and recipe fires again
- Given: `COMBINATION_COOLDOWN_SEC = 0.1` (test override), recipe fired once
- When: `combination_attempted` fires after 0.1s
- Then: `combination_succeeded` fires (Available again)

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/interaction_template_framework/cooldown_test.gd` — must exist and pass

**Status**: [x] Created — `tests/unit/interaction_template_framework/cooldown_test.gd` (13 test functions)

---

## Dependencies

- Depends on: Story 001 (`_on_combination_attempted` handler + recipe lookup) must be DONE
- Unlocks: Story 003 (Additive template — needs combination_succeeded to have been emitted)
