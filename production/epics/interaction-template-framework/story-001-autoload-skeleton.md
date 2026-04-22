# Story 001: Autoload Skeleton, EventBus Wiring & Recipe Lookup

> **Epic**: Interaction Template Framework
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Manifest Version**: 2026-04-21

## Context

**GDD**: `design/gdd/interaction-template-framework.md`
**Requirements**: `TR-interaction-template-framework-001`, `TR-interaction-template-framework-002`, `TR-interaction-template-framework-003`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-003: Inter-System Communication — EventBus Singleton; ADR-001: Naming Conventions
**ADR Decision Summary**: All inter-system communication flows through the EventBus autoload. Systems `connect` to EventBus signals in `_ready()`; no system holds a direct reference to another. Read-only queries (`RecipeDatabase.lookup()`) are direct autoload calls. Naming follows snake_case for variables/functions, PascalCase for classes/autoloads.

**Engine**: Godot 4.3 | **Risk**: LOW
**Engine Notes**: `Node.process_mode = PROCESS_MODE_ALWAYS` required so ITF processes even during pause. `EventBus.combination_attempted.connect(...)` typed signal connection pattern (string-based `connect()` is deprecated in 4.0).

**Control Manifest Rules (Feature Layer)**:
- Required: Use EventBus for all cross-system events — no direct node references
- Required: Declare every new signal in `event_bus.gd` before implementing the emitter
- Required: Direct autoload calls reserved for read-only queries (`RecipeDatabase.lookup()`)
- Forbidden: Never declare signals outside EventBus

---

## Acceptance Criteria

*From GDD `design/gdd/interaction-template-framework.md`, scoped to this story:*

- [ ] ITF is registered as an autoload singleton named `InteractionTemplateFramework` in `project.godot`
- [ ] On `_ready()`, ITF connects to `EventBus.combination_attempted` signal
- [ ] Given `instance_id = "morning-light_0"`, `_derive_card_id()` returns `"morning-light"` (strips trailing `_[counter]`)
- [ ] Given `instance_id = "chester"` (no suffix), `_derive_card_id()` returns `"chester"`
- [ ] On `combination_attempted(instance_id_a, instance_id_b)`: derives both card_ids and calls `RecipeDatabase.lookup(card_id_a, card_id_b)`
- [ ] When `RecipeDatabase.lookup()` returns null: emits `EventBus.combination_failed(instance_id_a, instance_id_b)`
- [ ] `combination_failed` does NOT fire when a recipe IS found (covered in Story 002)
- [ ] A new recipe added to `recipes.tres` without any code change to ITF causes it to be found by the lookup

---

## Implementation Notes

*Derived from ADR-003 and ADR-001:*

- File: `res://src/systems/interaction_template_framework.gd`, class name `InteractionTemplateFramework`, `extends Node`
- Set `process_mode = PROCESS_MODE_ALWAYS` in `_ready()` so the system is not paused by the scene tree
- Connect in `_ready()`: `EventBus.combination_attempted.connect(_on_combination_attempted)`
- `_derive_card_id(instance_id: String) -> String`: use `instance_id.rsplit("_", true, 1)[0]` — splits on last underscore, takes the left part. If no underscore, returns the full string unchanged.
- `_on_combination_attempted(instance_id_a: String, instance_id_b: String) -> void`: the main handler for this story just derives card_ids and looks up the recipe. Actual dispatch is handled in Story 002+.
- `RecipeDatabase.lookup(card_id_a, card_id_b)` is a direct autoload call (read-only query, per ADR-003). Returns a `RecipeEntry` Resource or null.
- Emit `EventBus.combination_failed.emit(instance_id_a, instance_id_b)` when lookup returns null.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: Cooldown check before recipe dispatch, `combination_succeeded` emit
- Story 003: Additive template execution and `combination_executed` signal
- Story 004: Merge template execution
- Story 005: Animate template execution
- Story 006: Generator template execution
- Story 007: `suspend()`/`resume()` and the Suspended state machine

---

## QA Test Cases

**AC-1**: `_derive_card_id` strips counter suffix
- Given: `instance_id = "morning-light_0"`
- When: `_derive_card_id("morning-light_0")` is called
- Then: returns `"morning-light"`
- Edge cases: `"chester"` (no suffix) → `"chester"`; `"a_b_c_2"` → `"a_b_c"`; `"ju_0"` → `"ju"`

**AC-2**: combination_failed fires for unknown pair
- Given: `RecipeDatabase` has no recipe for `("rain", "umbrella")`
- When: `EventBus.combination_attempted.emit("rain_0", "umbrella_0")`
- Then: `EventBus.combination_failed` is emitted with `("rain_0", "umbrella_0")`
- Edge cases: swapped order `("umbrella_0", "rain_0")` also fires `combination_failed`

**AC-3**: No combination_failed when recipe is found
- Given: `RecipeDatabase` returns a valid `RecipeEntry` for `("chester", "ju")`
- When: `EventBus.combination_attempted.emit("chester_0", "ju_0")`
- Then: `EventBus.combination_failed` is NOT emitted (recipe dispatch continues in Story 002+)

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/interaction_template_framework/skeleton_test.gd` — must exist and pass

**Status**: [x] Created — `tests/unit/interaction_template_framework/skeleton_test.gd` (10 test functions)

---

## Dependencies

- Depends on: Foundation epics (EventBus, CardDatabase, RecipeDatabase) must be DONE — ITF needs live RecipeDatabase.lookup()
- Unlocks: Story 002 (cooldown state machine builds on this handler)
