# Story 006: Generator Template

> **Epic**: Interaction Template Framework
> **Status**: Not Started (reopened 2026-04-24 — prior Complete flag was incorrect; no implementation existed in `src/gameplay/interaction_template_framework.gd`, which still routes `"generator"` to a no-op stub at line 96. The unit test file `tests/unit/interaction_template_framework/generator_test.gd` is a gap-documenting stub, not passing evidence.)
> **Layer**: Feature
> **Type**: Logic + Integration
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

- [ ] **AC-1 (spawn loop)**: Generator template — both source cards remain Idle; emits `combination_succeeded(instance_id_a, instance_id_b, "generator", {})` returning both to Idle; identifies the generator card from `recipe.config.generator_card`; starts a timer that, every `config.interval_sec`, calls `TableLayoutSystem.get_spawn_position(generator_pos, live_positions, null)` → `CardSpawningSystem.spawn_card(config.generates, pos)` and increments `count_produced`
- [ ] **AC-2 (max_count cap)**: When `max_count` is set and `count_produced >= max_count`: stop timer, deregister generator — no further spawns. When `max_count` is `null`: production continues indefinitely
- [ ] **AC-3 (both inputs remain)**: Both `instance_id_a` and `instance_id_b` remain on the table (not consumed); neither is removed during or after `_execute_generator`
- [ ] **AC-4 (either input removed cancels)**: ITF subscribes to `card_removing(instance_id)`. If the removed id matches **either** the generator card **or** the non-generator input card of an active generator entry, stop that entry's timer immediately and deregister — no further spawns. (Extends the GDD rule which only covered the generator card; rationale: both cards represent the relationship, losing either breaks it.)
- [ ] **AC-5 (bookkeeping)**: Registers generator instance in `_active_generators` with `{generates: String, interval_sec: float, max_count: int|null, count_produced: 0, non_generator_id: String, timer: Timer}`. `combination_executed(recipe_id, "generator", ...)` emitted immediately after `combination_succeeded` (before any timer ticks). Cooldown timer (`_last_fired[recipe_id]`) starts at execution, not at first tick. Same card may appear in `_active_generators` under different compound keys for different `recipe_id`s (two independent generators on one card).

---

## Implementation Notes

*Derived from ADR-003:*

- `_active_generators: Dictionary` — keys are compound `"%s|%s" % [generator_instance_id, recipe.id]`, values are `{generator_id, non_generator_id, generates, interval_sec, max_count, count_produced, timer: Timer}`. Compound key supports the "same card, two generators" case.
- `_execute_generator(recipe, instance_id_a, instance_id_b)`:
  1. Emit `combination_succeeded(..., "Generator", config)`.
  2. Identify generator card: `var gen_id = instance_id_a if recipe.config.generator_card == "card_a" else instance_id_b`; `var other_id = instance_id_b if gen_id == instance_id_a else instance_id_a`.
  3. Create a `Timer` child node: `var t = Timer.new(); add_child(t); t.wait_time = recipe.config.interval_sec; t.one_shot = false`.
  4. Build compound key: `var key = "%s|%s" % [gen_id, recipe.id]`.
  5. Connect: `t.timeout.connect(_on_generator_tick.bind(key))`.
  6. Store in `_active_generators[key] = {generator_id: gen_id, non_generator_id: other_id, generates: ..., interval_sec: ..., max_count: ..., count_produced: 0, timer: t}`.
  7. `t.start()`.
  8. Record cooldown (`_last_fired[recipe.id] = ...`) and emit `combination_executed(recipe.id, "Generator", instance_id_a, instance_id_b)`.
- `_on_generator_tick(key)`: look up entry; if `max_count != null and count_produced >= max_count` → `_deregister_generator(key)` and return. Otherwise: get generator card node position via `CardSpawning.get_card_node(generator_id)`, call `get_spawn_position` + `spawn_card(generates, pos)`, increment `count_produced`.
- `_deregister_generator(key)`: `entry.timer.stop(); entry.timer.queue_free(); _active_generators.erase(key)`.
- `_on_card_removing(instance_id)`: iterate `_active_generators` entries; for any entry where `entry.generator_id == instance_id` **or** `entry.non_generator_id == instance_id` → collect key and `_deregister_generator(key)`. (Two-phase: collect-then-erase to avoid mutating dict during iteration.) Also handles Story 004's merge-cancel path for pending merges.
- Subscribe to `CardSpawning.card_removing` in `_ready()` (new subscription for this story).
- Edge case: if generator card node is null at tick time (removed mid-frame before signal dispatched), skip spawn for that tick and let the upcoming `card_removing` deregister.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 004: Merge-cancel path in `_on_card_removing` (generator-cancel is an extension of the same handler)
- Story 007: Suspend/Resume pausing generator timers

---

## QA Test Cases

**AC-1a**: Generator spawns cards at interval
- Given: recipe `"chester-coffee"` is Generator with `generates: "memory"`, `interval_sec: 0.1`, `max_count: 3`; override timer to fire synchronously in test (or `await get_tree().create_timer(0.35).timeout`)
- When: `combination_attempted("chester_0", "coffee_0")` fires
- Then: `combination_executed` emitted once; `spawn_card("memory", <pos>)` called exactly 3 times; no further spawns after max_count; generator deregistered from `_active_generators`

**AC-1b**: Each tick positions the new card via TableLayoutSystem
- Given: generator active
- When: tick fires
- Then: `get_spawn_position(generator_pos, live_positions, null)` called before `spawn_card`; spawn position comes from that call

**AC-2**: max_count = null means unlimited
- Given: `max_count = null` in config; `interval_sec = 0.05`
- When: 10 ticks fire
- Then: 10 cards spawned; generator still registered; no exhaustion

**AC-3**: Both input cards remain on the table
- Given: Generator recipe fires
- When: after `_execute_generator` returns and one tick has fired
- Then: `CardSpawning.get_card_node(instance_id_a)` and `(instance_id_b)` both still return non-null; neither in removal queue

**AC-4a**: Generator card removed cancels timer
- Given: generator active for `"chester_0"` (generator) + `"coffee_0"` (non-generator), timer running
- When: `card_removing("chester_0")` fires
- Then: timer stopped; compound-key entry removed from `_active_generators`; no further `spawn_card` calls on subsequent tick interval

**AC-4b**: Non-generator input card removed also cancels timer ⚠ NEW vs GDD
- Given: generator active for `"chester_0"` (generator) + `"coffee_0"` (non-generator), timer running
- When: `card_removing("coffee_0")` fires
- Then: timer stopped; compound-key entry removed from `_active_generators`; no further `spawn_card` calls

**AC-5a**: combination_executed fires immediately (before first tick)
- Given: Generator recipe fires
- When: after `combination_succeeded`
- Then: `combination_executed` emitted before any timer tick; `count_produced == 0` at time of emission; `_last_fired[recipe_id]` recorded

**AC-5b**: Same card in two generators uses distinct compound keys
- Given: `"chester_0"` is generator in recipe A *and* recipe B simultaneously
- When: both `_execute_generator` calls complete
- Then: `_active_generators` has two distinct keys (`"chester_0|recipe-a"`, `"chester_0|recipe-b"`); both timers independent; removing `"chester_0"` deregisters both

**INTEGRATION**: End-to-end with real Card Engine + Card Spawning autoloads
- Given: real ITF + CardEngine + CardSpawning + TableLayoutSystem autoloads; recipe in RecipeDatabase; two cards on scene
- When: player performs real combination via Card Engine snap → `combination_attempted` fires via signal (not direct call)
- Then: after N intervals, N new cards visible in scene tree; removing a source card stops production

---

## Test Evidence

**Story Type**: Logic + Integration
**Required evidence**:
- Unit: `tests/unit/interaction_template_framework/generator_test.gd` — REWRITE existing gap-documenting stub to enforce AC-1 through AC-5b; all tests must pass against real implementation
- Integration: `tests/integration/interaction_template_framework/generator_lifecycle_test.gd` — new file; exercise full signal path (CardEngine.combination_attempted → ITF → CardSpawning.spawn_card); cover AC-4a and AC-4b with real `card_removing` signal

**Status**:
- [ ] Unit test rewritten and passing (currently: stub file exists at `tests/unit/interaction_template_framework/generator_test.gd` but documents gaps rather than enforces behaviour — guarded by `has_method("_execute_generator")` silent-skip)
- [ ] Integration test written and passing

---

## Dependencies

- Depends on: Story 003 (combination_executed pattern), Story 004 (`_on_card_removing` handler skeleton) must be DONE
- Unlocks: Story 007 (Suspend/Resume needs to pause generator timers)
