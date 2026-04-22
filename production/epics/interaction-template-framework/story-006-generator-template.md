# Story 006: Generator Template

> **Epic**: Interaction Template Framework
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Manifest Version**: 2026-04-21

## Context

**GDD**: `design/gdd/interaction-template-framework.md`
**Requirements**: `TR-interaction-template-framework-008`, `TR-interaction-template-framework-011` (generator-cancel path), `TR-interaction-template-framework-016` (per-generator state)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-003: Inter-System Communication — EventBus Singleton
**ADR Decision Summary**: All inter-system events via EventBus. The `card_removing(instance_id)` signal from Card Spawning System is the trigger to cancel generator timers. Generator timers are Godot `Timer` nodes (children of ITF) or managed via `_process` — use whichever pattern is simpler. Direct autoload calls (`CardSpawningSystem.spawn_card`, `TableLayoutSystem.get_spawn_position`) are read-only queries, acceptable per ADR-003.

**Engine**: Godot 4.3 | **Risk**: LOW
**Engine Notes**: Use Godot `Timer` node (child of ITF) per active generator — `Timer.timeout.connect(callable)`. Set `one_shot = false`, `wait_time = interval_sec`. On generator exhausted or cancelled: `timer.stop()`, `timer.queue_free()`. Alternatively, track a `_process` accumulator per generator instance — either approach is valid.

**Control Manifest Rules (Feature Layer)**:
- Required: Use EventBus for all cross-system events
- Required: Direct autoload calls for read-only queries (CardSpawningSystem, TableLayoutSystem)

---

## Acceptance Criteria

*From GDD `design/gdd/interaction-template-framework.md`, scoped to this story:*

- [ ] Generator template: both source cards remain Idle; emits `combination_succeeded(instance_id_a, instance_id_b, "generator", {})` returning both to Idle; identifies the generator card from `recipe.config.generator_card` field
- [ ] Registers generator instance in `_active_generators` dict: `{generates: String, interval_sec: float, max_count: int|null, count_produced: 0}`
- [ ] Starts a timer for the generator instance; on each tick calls `TableLayoutSystem.get_spawn_position(generator_pos, live_positions, null)` → `CardSpawningSystem.spawn_card(config.generates, pos)`, increments `count_produced`
- [ ] When `max_count` is set and `count_produced >= max_count`: stop timer, deregister generator — no further spawns
- [ ] When `card_removing(instance_id)` fires and `instance_id` is in `_active_generators`: stop timer immediately, deregister — no further spawns
- [ ] `combination_executed(recipe_id, "generator", ...)` emitted immediately after `combination_succeeded` (before any timer ticks)
- [ ] Same card can be in `_active_generators` twice with different recipe_ids (two independent generators)

---

## Implementation Notes

*Derived from ADR-003:*

- `_active_generators: Dictionary` — keys are `generator_instance_id: String`, values are `{generates, interval_sec, max_count, count_produced, timer: Timer}`.
- `_execute_generator(recipe, instance_id_a, instance_id_b)`:
  1. Emit `combination_succeeded(..., "generator", {})`.
  2. Identify generator card: `var gen_id = instance_id_a if recipe.config.generator_card == "card_a" else instance_id_b`.
  3. Create a `Timer` child node: `var t = Timer.new(); add_child(t); t.wait_time = recipe.config.interval_sec; t.one_shot = false`.
  4. Connect: `t.timeout.connect(_on_generator_tick.bind(gen_id, recipe.config))`.
  5. Store in `_active_generators[gen_id] = {generates: recipe.config.generates, interval_sec: ..., max_count: ..., count_produced: 0, timer: t}`.
  6. `t.start()`.
  7. Emit `combination_executed` (6-param).
- `_on_generator_tick(generator_instance_id, config)`: get generator state, check `max_count`, spawn card via `get_spawn_position` + `spawn_card`, increment `count_produced`. If exhausted: `_deregister_generator(generator_instance_id)`.
- `_deregister_generator(id)`: `_active_generators[id].timer.stop(); _active_generators[id].timer.queue_free(); _active_generators.erase(id)`.
- In `_on_card_removing(instance_id)` (also handles Story 004's merge-cancel): if `_active_generators.has(instance_id)`: `_deregister_generator(instance_id)`.
- For the "same card, two generators" case: use a compound key `"%s|%s" % [generator_instance_id, recipe.id]` to allow multiple generator entries per card.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 004: Merge-cancel path in `_on_card_removing` (generator-cancel is an extension of the same handler)
- Story 007: Suspend/Resume pausing generator timers

---

## QA Test Cases

**AC-1**: Generator spawns cards at interval
- Given: recipe `"chester-coffee"` is Generator with `generates: "memory"`, `interval_sec: 0.1`, `max_count: 3`; override timer to fire synchronously in test
- When: `combination_attempted("chester_0", "coffee_0")` fires
- Then: `combination_executed` emitted; after 3 ticks `spawn_card("memory", <pos>)` called 3 times; no further spawns after max_count

**AC-2**: Generator card removed cancels timer
- Given: generator is active for `"chester_0"`, timer running
- When: `card_removing("chester_0")` fires
- Then: timer stopped; no further `spawn_card` calls; `_active_generators` no longer has `"chester_0"` entry

**AC-3**: combination_executed fires immediately (before first tick)
- Given: Generator recipe fires
- When: after `combination_succeeded`
- Then: `combination_executed` emitted before any timer tick; `count_produced == 0` at time of emission

**AC-4**: max_count: null means unlimited
- Given: `max_count = null` in config
- When: 100 ticks fire
- Then: 100 cards spawned; no exhaustion

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/interaction_template_framework/generator_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 003 (combination_executed pattern), Story 004 (`_on_card_removing` handler skeleton) must be DONE
- Unlocks: Story 007 (Suspend/Resume needs to pause generator timers)
