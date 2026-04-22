# Story 004: Merge Template

> **Epic**: Interaction Template Framework
> **Status**: Complete
> **Layer**: Feature
> **Type**: Integration
> **Manifest Version**: 2026-04-21

## Context

**GDD**: `design/gdd/interaction-template-framework.md`
**Requirements**: `TR-interaction-template-framework-006` (Merge), `TR-interaction-template-framework-009`, `TR-interaction-template-framework-011` (merge-cancel path), `TR-interaction-template-framework-014`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-003: Inter-System Communication — EventBus Singleton
**ADR Decision Summary**: All inter-system communication via EventBus. The Merge template is Integration-type because it spans two systems across time: ITF emits `combination_succeeded(merge)` to Card Engine, then waits for Card Engine to emit `merge_animation_complete` before proceeding. This cross-system async handshake is the defining Integration boundary.

**Engine**: Godot 4.3 | **Risk**: LOW
**Engine Notes**: Use `await EventBus.merge_animation_complete` pattern — do NOT use `yield()` (deprecated 4.0). The merge wait must be cancellable if a source card is removed mid-animation (use a flag or disconnect the signal handler). `merge_animation_complete(instance_id_a, instance_id_b, midpoint: Vector2)` carries the midpoint for result card placement.

**Control Manifest Rules (Feature Layer)**:
- Required: Use EventBus for all cross-system events
- Forbidden: Never use `yield()` — use `await signal`

---

## Acceptance Criteria

*From GDD `design/gdd/interaction-template-framework.md`, scoped to this story:*

- [ ] Merge template: emits `combination_succeeded(instance_id_a, instance_id_b, "merge", {result_card: recipe.config.result_card})` — Card Engine begins merge animation
- [ ] After `merge_animation_complete(instance_id_a, instance_id_b, midpoint)` received: calls `CardSpawningSystem.remove_card(instance_id_a)` and `CardSpawningSystem.remove_card(instance_id_b)`
- [ ] After removal: calls `TableLayoutSystem.get_spawn_position(midpoint, live_positions, spawn_seed)` → `CardSpawningSystem.spawn_card(recipe.config.result_card, position)` → emits `combination_executed` (6-param)
- [ ] Edge case — source card removed mid-animation: when `card_removing(instance_id)` fires for one of the merge source cards while awaiting `merge_animation_complete`: cancel the merge wait, call `remove_card()` for whichever card still exists, do NOT spawn result card, log a warning

---

## Implementation Notes

*Derived from ADR-003:*

- `_execute_merge(recipe, instance_id_a, instance_id_b)` is an `async` function using `await`.
- Emit `combination_succeeded` with `{"result_card": recipe.config.result_card}` config dict.
- Track pending merge: `_pending_merge: Dictionary` keyed by `{id_a, id_b}` pair (use a String key like `"%s|%s" % [id_a, id_b]`). Set before `await`, clear on completion or cancellation.
- Listen to `EventBus.card_removing` in `_on_card_removing(instance_id)`: check if the removing card is in `_pending_merge`. If yes: cancel that merge (set a cancelled flag or disconnect `merge_animation_complete` listener), call `remove_card` for surviving card, log warning.
- After `merge_animation_complete` received: check cancelled flag before proceeding. If not cancelled: remove both source cards, spawn result, emit `combination_executed`.
- `merge_animation_complete` carries `midpoint: Vector2` — use directly for `get_spawn_position()` origin.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 003: Additive template and `combination_executed` base implementation
- Story 005: Animate template
- Story 006: Generator template — `card_removing` handler for generator cancel (separate concern)
- Story 007: Suspend/Resume pausing the merge wait

---

## QA Test Cases

**AC-1**: Merge completes successfully
- Given: recipe `"chester-ju"` is Merge with `result_card: "memory"`, both cards on table
- When: `combination_attempted("chester_0", "ju_0")` → `combination_succeeded` emitted → `merge_animation_complete("chester_0", "ju_0", Vector2(100,100))` fires
- Then: `remove_card("chester_0")` called; `remove_card("ju_0")` called; `spawn_card("memory", <pos>)` called; `combination_executed("chester-ju", "merge", "chester_0", "ju_0", "chester", "ju")` emitted

**AC-2**: Source card removed mid-animation cancels merge
- Given: Merge is awaiting `merge_animation_complete` for `("chester_0", "ju_0")`
- When: `card_removing("chester_0")` fires
- Then: merge is cancelled; `remove_card("ju_0")` called (surviving card); `spawn_card` NOT called; `combination_executed` NOT emitted; warning logged

**AC-3**: merge_animation_complete from different pair is ignored
- Given: ITF is awaiting merge for `("chester_0", "ju_0")`
- When: `merge_animation_complete("rain_0", "coffee_0", midpoint)` fires (different pair)
- Then: the `chester_0/ju_0` merge wait continues; nothing happens for the rain/coffee signal

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/interaction_template_framework/merge_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 003 (combination_executed signal pattern established) must be DONE; Card Engine epic must be DONE (merge_animation_complete signal)
- Unlocks: Story 005 (Animate template)
