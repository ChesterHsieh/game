# Story 003: Additive Template & combination_executed Signal

> **Epic**: Interaction Template Framework
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Manifest Version**: 2026-04-21

## Context

**GDD**: `design/gdd/interaction-template-framework.md`
**Requirements**: `TR-interaction-template-framework-004`, `TR-interaction-template-framework-005`, `TR-interaction-template-framework-012`, `TR-interaction-template-framework-013`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-003: Inter-System Communication — EventBus Singleton; ADR-005: Data File Format
**ADR Decision Summary**: All events via EventBus. `combination_executed` is a 6-param signal (expanded per MUT Rule 4 / OQ-7) — all consumers must declare handlers with exactly 6 params in Godot 4.3 (arity-strict). `RecipeEntry.config` is a `Dictionary` passthrough — `config.spawns` is the Array[String] of card IDs to spawn for Additive.

**Engine**: Godot 4.3 | **Risk**: LOW
**Engine Notes**: `combination_executed` declared with 6 typed params in EventBus — `signal combination_executed(recipe_id: String, template: String, instance_id_a: String, instance_id_b: String, card_id_a: String, card_id_b: String)`. Arity-strict: any downstream handler with a different param count raises a runtime error on the first emit.

**Control Manifest Rules (Feature Layer)**:
- Required: Use EventBus for all cross-system events
- Required: Direct autoload calls for read-only queries (TableLayoutSystem.get_spawn_position, CardSpawningSystem.spawn_card)
- Forbidden: Never add signals outside EventBus

---

## Acceptance Criteria

*From GDD `design/gdd/interaction-template-framework.md`, scoped to this story:*

- [ ] Additive template: both source cards remain on the table (no remove_card calls); result card(s) spawn near the combination midpoint
- [ ] For each `card_id` in `recipe.config.spawns`: calls `TableLayoutSystem.get_spawn_position(midpoint, live_card_positions, spawn_seed)` → calls `CardSpawningSystem.spawn_card(card_id, position)`
- [ ] `combination_executed(recipe_id, "additive", instance_id_a, instance_id_b, card_id_a, card_id_b)` is emitted after all spawns complete (6 params, in order)
- [ ] `combination_executed` does NOT fire when `combination_failed` was emitted (no recipe, or on cooldown)
- [ ] If `TableLayoutSystem.get_spawn_position()` returns null (table full): log a warning; skip spawn for that card; still emit `combination_executed`

---

## Implementation Notes

*Derived from ADR-003 and ADR-005:*

- After Story 002 emits `combination_succeeded` for an Additive recipe, ITF executes `_execute_additive(recipe, instance_id_a, instance_id_b)`.
- Combination midpoint: `(card_a.position + card_b.position) / 2.0` — read positions from the card nodes via CardSpawningSystem or passed as part of the combination context. (Card Engine may include position data in the combination event — if not, query CardSpawningSystem for position by instance_id.)
- `live_card_positions` is the current set of all card positions — call `CardSpawningSystem.get_all_positions()` (or equivalent) to collect.
- For each spawn: `var pos = TableLayoutSystem.get_spawn_position(midpoint, live_positions, null)`. If pos is null: `push_warning("ITF: No spawn position for %s — table full" % card_id)`, skip spawn, continue loop.
- After all spawns: emit `EventBus.combination_executed.emit(recipe.id, "additive", instance_id_a, instance_id_b, recipe.card_a, recipe.card_b)`.
- `recipe.card_a` and `recipe.card_b` are the base card IDs from the `RecipeEntry` Resource — these go into the `card_id_a`/`card_id_b` params (not the `instance_id`s).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 004: Merge template (source cards consumed)
- Story 005: Animate template (no spawns)
- Story 006: Generator template (timed spawns)
- Any consumer of `combination_executed` (SBS, MUT, HS handle their own subscriptions)

---

## QA Test Cases

**AC-1**: Additive spawns result cards and emits combination_executed
- Given: recipe `"chester-ju"` is Additive with `spawns: ["morning-light"]`, both source cards at known positions
- When: `combination_attempted("chester_0", "ju_0")` fires and recipe is Available
- Then: `CardSpawningSystem.spawn_card("morning-light", <position>)` is called once; `combination_executed("chester-ju", "additive", "chester_0", "ju_0", "chester", "ju")` is emitted; `remove_card` is NOT called for either source
- Edge cases: recipe with `spawns: ["a", "b"]` → two spawn calls

**AC-2**: combination_executed NOT emitted for failed combination
- Given: pair has no recipe
- When: `combination_attempted` fires → `combination_failed` is emitted
- Then: `combination_executed` is NOT emitted

**AC-3**: Table-full path still emits combination_executed
- Given: `TableLayoutSystem.get_spawn_position()` returns null (table full)
- When: Additive fires
- Then: warning is logged; `spawn_card` is NOT called for the full-table card; `combination_executed` IS emitted

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/interaction_template_framework/additive_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002 (cooldown state machine + combination_succeeded) must be DONE; Core epics (TableLayoutSystem, CardSpawningSystem) must be DONE
- Unlocks: Story 004 (Merge template)
