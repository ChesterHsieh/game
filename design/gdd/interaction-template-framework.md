# Interaction Template Framework

> **Status**: In Design
> **Author**: Chester + Claude
> **Last Updated**: 2026-03-24
> **Implements Pillar**: Interaction is Expression

## Overview

The Interaction Template Framework is the system that decides what happens when two
cards combine. It listens for the Card Engine's combination events, queries the Recipe
Database for a matching rule, and executes one of four interaction templates — Additive,
Merge, Animate, or Generator. It is the bridge between the physical card layer and the
authored content layer: the Card Engine creates the moment of contact, the Recipe
Database stores Chester's intent, and the Interaction Template Framework carries out
that intent. Every combination outcome — a new card appearing, two cards merging into
one, a card that begins to orbit, a card that quietly produces new ones over time — is
the ITF executing a template on behalf of a recipe.

## Player Fantasy

The player never sees the Interaction Template Framework. What she sees is: she put
these two things together and something happened that only she would understand. The
ITF is successful when the outcome feels inevitable in hindsight — "of course those
two things together would produce this." It is the system that delivers the promise
of Pillar 2: "How two cards behave together reflects the nature of that memory." A
merge says something different than an additive. A generator says something different
than an animate. The player doesn't need to know the template name. She just needs
to feel that the game knew.

## Detailed Design

### Core Rules

1. ITF is the **sole listener** of `combination_attempted` from Card Engine.
2. The signal carries `instance_id_a` and `instance_id_b` (e.g. `chester_0`,
   `morning-light_0`). ITF derives base `card_id` from each by stripping the counter
   suffix: `"morning-light_0" → "morning-light"`.
3. On receiving `combination_attempted(instance_id_a, instance_id_b)`, ITF:
   - Derives `card_id_a`, `card_id_b` from the instance IDs
   - Queries Recipe Database: `lookup(card_id_a, card_id_b)` → recipe or null
   - If null: emits `combination_failed(instance_id_a, instance_id_b)` — done
   - If recipe found: checks cooldown state for that recipe
   - If on cooldown: emits `combination_failed` — done
   - If not on cooldown: executes template (see template sections), then starts cooldown timer
4. After every **successful** combination, ITF emits
   `combination_executed(recipe_id, template, instance_id_a, instance_id_b, card_id_a, card_id_b)`.
   The `card_id_a` / `card_id_b` values are read from the matched recipe (`recipe.card_a` / `recipe.card_b` in Recipe Database). This signal is consumed by Status Bar System, Mystery Unlock Tree, and Hint System. Godot 4.3 is arity-strict — all handlers MUST declare 6 params. Downstream
   systems do not need to listen to Card Engine directly.
5. ITF manages four categories of runtime state:
   - **Cooldown timers**: per recipe, tracks time since last fire
   - **Generator timers**: per active generator instance, fires `spawn_card()` on interval
   - **Generator counts**: per active generator instance, tracks how many cards produced
   - **Merge listeners**: waits for Card Engine's `merge_animation_complete` signal before
     removing source cards and spawning result

> ~~**Cross-system conflict (requires Card Engine GDD correction)**: Card Engine GDD
> currently uses `card_id` in `combination_attempted` parameters.~~ **RESOLVED**: Card Engine GDD §"Combination Firing" now emits `combination_attempted(instance_id_a, instance_id_b)` — the instance_id signature agreed with this GDD. No further edit needed.

### Template Execution: Additive

Both source cards remain on the table. New card(s) appear nearby.

**Execution sequence:**
1. Emit `combination_succeeded(instance_id_a, instance_id_b, "additive", {})` → Card Engine returns both cards to `Idle`
2. For each `card_id` in `recipe.config.spawns`:
   - Call `Table_Layout.get_spawn_position(combination_midpoint, live_card_positions, spawn_seed)` → `position`
   - Call `Card_Spawning.spawn_card(card_id, position)` → `instance_id`
3. Emit `combination_executed(recipe.id, "additive", instance_id_a, instance_id_b, recipe.card_a, recipe.card_b)`
4. Start cooldown timer for `recipe.id`

**Combination point**: midpoint between `instance_id_a.position` and `instance_id_b.position` at moment of snap.

### Template Execution: Merge

Both source cards are consumed. One result card replaces them.

**Execution sequence:**
1. Emit `combination_succeeded(instance_id_a, instance_id_b, "merge", {result_card: recipe.config.result_card})` → Card Engine begins merge animation (tween both cards to midpoint, scale/fade to zero)
2. Wait for `merge_animation_complete(instance_id_a, instance_id_b, midpoint)` from Card Engine
3. Call `Card_Spawning.remove_card(instance_id_a)`; `Card_Spawning.remove_card(instance_id_b)`
4. Call `Table_Layout.get_spawn_position(midpoint, live_card_positions, spawn_seed)` → `position`
5. Call `Card_Spawning.spawn_card(recipe.config.result_card, position)` → new `instance_id`
6. Emit `combination_executed(recipe.id, "merge", instance_id_a, instance_id_b, recipe.card_a, recipe.card_b)`
7. Start cooldown timer for `recipe.id`

### Template Execution: Animate

One or both source cards begin a looping motion. No cards are produced or consumed.

**Execution sequence:**
1. Emit `combination_succeeded(instance_id_a, instance_id_b, "animate", config)` where
   `config = {motion, speed, target, duration_sec}` from Recipe Database
2. Card Engine applies motion per config to the target card(s). Card(s) enter `Executing`
   state — cannot be dragged while animating.
3. If `duration_sec` is set: Card Engine emits `animate_complete(instance_id)` when done
   → card returns to `Idle`
4. If `duration_sec` is null: animation loops indefinitely until scene transition calls
   `clear_all_cards()`
5. Emit `combination_executed(recipe.id, "animate", instance_id_a, instance_id_b, recipe.card_a, recipe.card_b)`
6. Start cooldown timer for `recipe.id`

**Note**: An animating card in `Executing` state cannot be dragged or participate in
another combination until the animation ends or the scene clears.

### Template Execution: Generator

One source card becomes a generator, periodically producing new cards. Both source cards remain.

**Execution sequence:**
1. Emit `combination_succeeded(instance_id_a, instance_id_b, "generator", {})` → Card Engine returns both cards to `Idle`
2. Identify the generator instance: `generator_instance_id = instance_id_a if config.generator_card == "card_a" else instance_id_b`
3. Register in `_active_generators`: `{ generator_instance_id, generates, interval_sec, max_count, count_produced: 0 }`
4. Start the generation timer for `generator_instance_id`
5. Emit `combination_executed(recipe.id, "generator", instance_id_a, instance_id_b, recipe.card_a, recipe.card_b)`
6. Start cooldown timer for `recipe.id`

**On each timer tick:**
1. If `max_count` is set and `count_produced >= max_count` → stop timer, deregister generator
2. Call `Table_Layout.get_spawn_position(generator_card.position, live_card_positions, null)` → `position`
3. Call `Card_Spawning.spawn_card(config.generates, position)` → new `instance_id`
4. Increment `count_produced`

**On generator card removed** (ITF listens to `card_removing(instance_id)`):
- If `instance_id` is in `_active_generators`: stop its timer, deregister it

### States and Transitions

ITF is primarily event-driven but maintains three layers of state:

**System-level state:**

| State | Entry | Exit | Behavior |
|-------|-------|------|----------|
| `Ready` | Default; on scene load complete | Scene transition begins | Accepts and resolves `combination_attempted` events |
| `Suspended` | Scene transition begins | Scene load complete | Ignores all `combination_attempted` events; all cooldown/generator timers paused |

**Per-recipe state (cooldown):**

| State | Entry | Exit | Behavior |
|-------|-------|------|----------|
| `Available` | Default; on cooldown timer expiry | Recipe fires successfully | Recipe fires normally on `combination_attempted` |
| `Cooling` | Recipe fires successfully | `combination_cooldown_sec` elapses | Returns `combination_failed` on `combination_attempted` for this recipe |

**Per-generator state:**

| State | Entry | Exit | Behavior |
|-------|-------|------|----------|
| `Generating` | Generator combination fires | max_count reached OR generator card removed | Timer running; producing cards on interval |
| `Exhausted` | `max_count` reached | — (terminal) | Timer stopped; no more production |
| `Stopped` | Generator card removed | — (terminal) | Timer cancelled; entry removed from `_active_generators` |

### Interactions with Other Systems

| System | Direction | Interface |
|--------|-----------|-----------|
| **Card Engine** | Bidirectional | Listens: `combination_attempted(instance_id_a, instance_id_b)`. Emits: `combination_succeeded(a, b, template, config)` and `combination_failed(a, b)`. Also listens to `merge_animation_complete(a, b, midpoint)` and `animate_complete(instance_id)` for template completion. |
| **Recipe Database** | Reads | `lookup(card_id_a, card_id_b)` → recipe or null. Called on every `combination_attempted`. |
| **Card Spawning System** | Calls | `spawn_card(card_id, position)` → `instance_id` for Additive results, Merge results, and Generator outputs. `remove_card(instance_id)` × 2 for Merge source cards. Also listens to `card_removing(instance_id)` to cancel Generator timers. |
| **Table Layout System** | Calls | `get_spawn_position(origin, live_positions, seed)` → `Vector2` before every `spawn_card()` call. ITF calls Table Layout; Card Spawning only receives the final position. |
| **Status Bar System** | Emits signal to | `combination_executed(recipe_id, template, instance_id_a, instance_id_b, card_id_a, card_id_b)` — Status Bar System listens to update bar values (ignores `card_id_*`) |
| **Mystery Unlock Tree** | Emits signal to | Same `combination_executed` signal — MUT uses `card_id_a` / `card_id_b` to record discovery without an extra Recipe Database lookup |
| **Hint System** | Emits signal to | Same `combination_executed` signal — Hint System resets stagnation timer (ignores payload fields) |
| **Scene Manager** | Receives call from | `suspend()` on scene transition begin; `resume()` on scene load complete |

## Formulas

### Cooldown Check

```
is_on_cooldown(recipe_id) =
  (current_time - last_fired_time[recipe_id]) < combination_cooldown_sec
```

| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| `current_time` | float | 0 → ∞ | Godot `Time.get_ticks_msec()` converted to seconds | Current game time |
| `last_fired_time[recipe_id]` | float | 0 → ∞ | ITF internal dict | Timestamp of last successful fire for this recipe; 0 if never fired |
| `combination_cooldown_sec` | float | 5–120s | Tuning knob (default 30s) | How long before the same pair can re-fire |

**Expected behavior**: At 30s default, a player who fires the same Additive pair twice
waits 30 seconds before it fires again. During cooldown, the pair pushes away like an
incompatible pair.

Generator `interval_sec` is authored directly in the Recipe Database and not computed
by ITF. No other formulas owned by this system.

## Edge Cases

| Case | Trigger | Expected Behavior |
|------|---------|------------------|
| **No recipe found** | `combination_attempted` for an unknown pair | Emit `combination_failed`. Not an error — incompatible pairs are expected. |
| **Recipe on cooldown** | Same pair attempted before cooldown expires | Emit `combination_failed` — push-away fires. No log needed (expected player behavior). |
| **Merge: source card removed during animation** | `card_removing` fires for one of the merge source cards mid-animation | Cancel wait for `merge_animation_complete`. Call `remove_card()` for whichever card still exists. Do not spawn result card — merge was interrupted. Log a warning. |
| **Generator: same card starts a second generator** | Player combines a generator card with a new pair that triggers another Generator recipe | Allow — the same card can be in `_active_generators` twice with different `recipe_id`s. Each tracked independently. |
| **Generator: generator card merged away** | A Merge combination consumes the generator card | `card_removing` fires → ITF stops that generator timer immediately and deregisters it. Merge proceeds normally. |
| **Additive: Table Layout returns null position** | Table is full — no valid spawn position found | Log a warning. Do not call `spawn_card()` for that card. Emit `combination_executed` anyway — the combination happened even if the result couldn't be placed. |
| **ITF receives combination_attempted while Suspended** | Scene transition in progress | Ignore silently. Card Engine should not fire combinations during transition, but if it does, ITF drops the event. |
| **Animate: card removed mid-animation** | `card_removing` fires for a card in Executing/Animate state | Card Engine cancels tween; Card Spawning frees node. ITF owns no ongoing state for Animate — no additional handling needed. |
| **Multiple Animate combos on same card** | A second Animate triggers on a card already in `Executing` | Not possible — Executing cards cannot be dragged. Card Engine will not fire `combination_attempted` for a card in Executing state. |

## Dependencies

### Upstream (this system depends on)

| System | What We Need | Hardness |
|--------|-------------|----------|
| **Card Engine** | `combination_attempted(instance_id_a, instance_id_b)` signal; `merge_animation_complete(a, b, midpoint)` signal; `animate_complete(instance_id)` signal | Hard — ITF cannot function without these |
| **Recipe Database** | `lookup(card_id_a, card_id_b)` → recipe or null | Hard — ITF has no behavior without recipes |
| **Card Spawning System** | `spawn_card(card_id, position)` → `instance_id`; `remove_card(instance_id)`; `card_removing(instance_id)` signal | Hard for Merge/Additive/Generator templates; not required for Animate-only |
| **Table Layout System** | `get_spawn_position(origin, live_positions, seed)` → `Vector2` | Hard for Additive/Merge/Generator; not used for Animate |

### Downstream (systems that depend on this)

| System | What They Need |
|--------|---------------|
| **Status Bar System** | `combination_executed(recipe_id, template, instance_id_a, instance_id_b, card_id_a, card_id_b)` — to update bar values |
| **Mystery Unlock Tree** | Same `combination_executed` signal — to track discovered recipes with card_ids |
| **Hint System** | Same `combination_executed` signal — to reset stagnation timer |
| **Scene Manager** | Calls `ITF.suspend()` on scene transition begin; `ITF.resume()` on scene load complete |

### Signals Emitted

| Signal | Parameters | Fired when |
|--------|------------|-----------|
| `combination_succeeded` | `instance_id_a: String, instance_id_b: String, template: String, config: Dictionary` | Recipe found and not on cooldown — sent to Card Engine |
| `combination_failed` | `instance_id_a: String, instance_id_b: String` | No recipe or on cooldown — sent to Card Engine |
| `combination_executed` | `recipe_id: String, template: String, instance_id_a: String, instance_id_b: String, card_id_a: String, card_id_b: String` | Broadcast after every successful template execution. 6 params; all consumers must declare matching handler arity (Godot 4.3). |

## Tuning Knobs

| Knob | Type | Default | Safe Range | Too Low | Too High |
|------|------|---------|------------|---------|----------|
| `combination_cooldown_sec` | float | 30s | 5–120s | Player spams same pair repeatedly; discovery feels mechanical | Player forgets a combination worked; frustration when retry fails |

Generator timing (`interval_sec`, `max_count`) and animation parameters (`motion`,
`speed`, `duration_sec`) are authored per recipe in the Recipe Database — not
system-level tuning knobs.

## Acceptance Criteria

- [ ] Given a valid, non-cooldown card pair: `combination_succeeded` fires with correct template and config
- [ ] Given a pair with no recipe: `combination_failed` fires, push-away plays
- [ ] Given a pair on cooldown: `combination_failed` fires, push-away plays
- [ ] After `combination_cooldown_sec` elapses: same pair fires successfully again
- [ ] Additive: both source cards remain Idle; result card(s) spawn near combination point
- [ ] Merge: both source cards play fade/scale animation; on complete, both removed; result card spawned at midpoint
- [ ] Animate: target card enters Executing state, motion plays per config; card cannot be dragged during animation
- [ ] Animate with `duration_sec`: card returns to Idle after duration; can be dragged again
- [ ] Generator: both source cards return to Idle; generator timer starts; cards spawn at `interval_sec`
- [ ] Generator with `max_count`: production stops after `max_count` cards; no further spawns
- [ ] Generator card removed: timer stops immediately; no further spawns
- [ ] `combination_executed` fires after every successful template execution (all 4 templates)
- [ ] `combination_executed` does NOT fire for failed or cooldown-blocked combinations
- [ ] ITF ignores `combination_attempted` while in `Suspended` state
- [ ] A new recipe can be added to the Recipe Database without any code changes to ITF

## Open Questions

- ~~**Status Bar recipe config**: Status Bar System (undesigned) will need to know *how* a combination affects bar values.~~ **RESOLVED**: Status Bar System is Designed. Per `design/gdd/status-bar-system.md` Rule 4, SBS maintains its own lookup keyed by `recipe_id` against `assets/data/bar-effects.json`. Recipes themselves do NOT carry bar-effect data — SBS owns its own mapping.
- ~~**`combination_executed` payload**: Mystery Unlock Tree (undesigned) may need the actual `card_id`s (not just `instance_id`s) to track unique discoveries.~~ **RESOLVED** 2026-04-18 per MUT GDD Rule 4 — signal expanded to 6 params including `card_id_a`, `card_id_b`. Cascade applied to ITF/SBS/SGS/HS on 2026-04-21.
- **Cooldown per-scene or global**: Current design: cooldown is global (timers persist across scenes). Should cooldown reset when a new scene loads? Resolve with Scene Goal System design.
- **Animate stopping conditions**: For infinite-loop animations, the only stop is scene transition. Should a specific combination be able to stop an animation (e.g., combining the animating card with a third card)? Cards in Executing state currently can't be dragged. Resolve if a design calls for it.
