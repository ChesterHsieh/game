# Card Spawning System

> **Status**: In Design
> **Author**: Chester + Claude
> **Last Updated**: 2026-03-23
> **Implements Pillar**: Discovery without Explanation (new cards appear naturally, not mechanically)

## Overview

The Card Spawning System creates and destroys card nodes on the table. It is the sole
system with authority to add or remove cards — no other system touches node instantiation
directly. When a scene begins, it places seed cards at positions provided by the Table
Layout System. When a combination fires, the Interaction Template Framework calls it to
spawn result cards or remove consumed ones. It assigns each card node a unique instance
ID so that multiple copies of the same card can coexist on the table without conflict.
Spawned cards enter the table as `Idle` nodes; removed cards are freed from the scene tree.
The system emits signals on every spawn and removal so dependent systems can register or
deregister the affected nodes.

## Player Fantasy

The player never thinks about spawning. What she sees is a new card sliding into place
near where something just happened — a small arrival that says "look what you unlocked."
The spawning system is successful when cards feel like they were discovered, not
manufactured. A card appearing after a meaningful combination should feel like a
photograph slipping out from behind another one: it was always there; you just found it.

## Detailed Design

### Core Rules

1. The Card Spawning System is the **sole authority** for creating and removing card nodes. No other system calls `instantiate()` or `free()` on card nodes directly.
2. Every card node has two identifiers:
   - **`card_id`** (string) — the base card definition from the Card Database (e.g. `morning-light`)
   - **`instance_id`** (string) — unique node identity, format `card_id + "_" + zero-indexed counter` (e.g. `morning-light_0`, `morning-light_1`)
3. The counter is **per card_id** and increments globally across the session. It is never reused — even after a card is removed, its counter value is retired.
4. The Card Spawning System maintains an internal registry: `{ instance_id → node reference }` for all live cards. This is the authoritative list of cards currently on the table.
5. Callers request spawns; the Card Spawning System decides the instance_id and manages the node. Callers receive the instance_id back as confirmation.
6. Only two callers may request spawns: the **Interaction Template Framework** and the **Scene Manager**.

### Instance ID System

| Card | First instance | Second instance | Third instance |
|------|---------------|-----------------|----------------|
| `morning-light` | `morning-light_0` | `morning-light_1` | `morning-light_2` |
| `chester` | `chester_0` | `chester_1` | — |

Counter lookup: `_next_counter[card_id]`, initialized to 0. On each spawn: assign current value, increment. Never reset during a scene (only on full game reset).

**Why not reuse counters?** If `morning-light_0` is removed and `morning-light_0` is reissued to a new card, any in-flight signals (e.g. a snap tween) still referencing the old instance_id would silently redirect to the new card. Retired counters prevent this.

### Spawn Lifecycle

**Spawn request** (from ITF or Scene Manager):

```
spawn_card(card_id, position) → instance_id
```

1. Look up `card_id` in Card Database — assert it exists (fail loudly if not)
2. Assign `instance_id = card_id + "_" + _next_counter[card_id]`; increment counter
3. Instantiate the card scene node; set `card_id` and `instance_id` properties on it
4. Set node position to `position`
5. Add node to scene tree
6. Register in internal registry: `_live_cards[instance_id] = node`
7. Emit `card_spawned(instance_id, card_id, position)`
8. Return `instance_id`

**Remove request** (from ITF — Merge consumes both source cards):

```
remove_card(instance_id)
```

1. Look up `instance_id` in registry — assert it exists (log warning if not, no crash)
2. Emit `card_removing(instance_id)` — gives Card Engine time to cancel any active tweens on this node
3. Remove from registry: `_live_cards.erase(instance_id)`
4. Free the node from scene tree
5. Emit `card_removed(instance_id)`

**Scene load** (from Scene Manager):

```
spawn_seed_cards(scene_data) → instance_id[]
```

Calls `spawn_card()` for each seed card entry. Returns list of instance_ids in the same order as the input.

### States and Transitions

The Card Spawning System is mostly stateless — it manages the registry and counters, but individual card nodes own their own states (that's the Card Engine's job). The system has one internal state:

| State | Description |
|-------|-------------|
| `Ready` | Default; accepting spawn and remove requests |
| `Clearing` | Scene transition in progress; all cards being removed before new scene loads |

During `Clearing`, new spawn requests are queued and processed after clearing is complete.

### Interactions with Other Systems

| System | Direction | Interface |
|--------|-----------|-----------|
| **Card Database** | Reads | Validates `card_id` exists before spawning. Reads nothing else at spawn time — card data is the Card Visual's concern. |
| **Table Layout System** | Reads | `get_spawn_position()` and `get_seed_card_positions()` — called by ITF/Scene Manager *before* calling Card Spawning. Callers pass the position in; Card Spawning does not call Table Layout directly. |
| **Interaction Template Framework** | Serves | Receives `spawn_card(card_id, position)` and `remove_card(instance_id)` calls. Emits `card_spawned` and `card_removed` signals back. |
| **Scene Manager** | Serves | Receives `spawn_seed_cards(scene_data)` on scene load. Receives `clear_all_cards()` on scene transition. |
| **Card Engine** | Signals | Listens to `card_spawned` to register new card nodes into its state tracking. Listens to `card_removing` to cancel any in-flight tweens. Listens to `card_removed` to deregister. |
| **Card Visual** | Signals | Listens to `card_spawned` to attach visual components to the new node. |

## Formulas

The Card Spawning System performs no calculations. All position computation is owned by
Table Layout System (called by the requester before calling Card Spawning). The only
numeric operation is the instance counter increment: `_next_counter[card_id] += 1` after
each spawn. No tuning math required.

## Edge Cases

| Case | Trigger | Expected Behavior |
|------|---------|------------------|
| **Unknown card_id** | `spawn_card()` called with an ID not in Card Database | Fail loudly: log an error naming the unknown ID and the caller. Do not spawn the card. Return null. |
| **Remove unknown instance_id** | `remove_card()` called with an instance_id not in registry | Log a warning. No crash. No action (card may already have been removed by a concurrent event). |
| **Scene transition mid-combination** | A Merge animation is playing when the Scene Manager calls `clear_all_cards()` | Enter `Clearing` state. Emit `card_removing` for all live cards immediately — Card Engine cancels tweens. Free all nodes. Queue any pending spawns for after load. |
| **Generator produces card onto a full table** | Generator fires while Table Layout exhausts positions | Card Spawning calls `spawn_card()` with the position returned by Table Layout (even if overlapping). Table Layout already warned about the full table — Card Spawning is not responsible for placement quality, only for node creation. |
| **Duplicate spawn_seed_cards call** | Scene Manager calls `spawn_seed_cards()` twice for the same scene | Each call produces new instance IDs with incremented counters. This results in duplicate cards on the table. Scene Manager is responsible for not calling twice. Card Spawning does not guard against this. |
| **Card node access after removal** | Card Engine holds an instance_id reference after `card_removed` fires | Card Engine must deregister on `card_removed`. If it accesses the node after this, Godot will error on the freed node. Card Engine should null-check after deregistering. |

## Dependencies

### Upstream (this system depends on)

| System | What We Need | Hardness |
|--------|-------------|----------|
| **Card Database** | Validate `card_id` exists before spawning. No other data needed at spawn time. | Soft — system still spawns without it, but can't validate IDs |
| **Table Layout System** | Callers use Table Layout to compute positions before calling Card Spawning. Card Spawning itself does not call Table Layout — it receives positions. | None direct — Table Layout is a caller-side dependency |

### Downstream (systems that depend on this)

| System | What They Need |
|--------|---------------|
| **Interaction Template Framework** | `spawn_card(card_id, position)` → `instance_id`; `remove_card(instance_id)`; `card_spawned` and `card_removed` signals |
| **Scene Manager** | `spawn_seed_cards(scene_data)` → `instance_id[]`; `clear_all_cards()` |
| **Card Engine** | `card_spawned(instance_id, card_id, position)` to register new nodes; `card_removing(instance_id)` to cancel tweens; `card_removed(instance_id)` to deregister |
| **Card Visual** | `card_spawned(instance_id, card_id, position)` to attach visual components |

### Signals Emitted

| Signal | Parameters | Fired when |
|--------|------------|-----------|
| `card_spawned` | `instance_id: String, card_id: String, position: Vector2` | Card node added to scene tree |
| `card_removing` | `instance_id: String` | Just before a card node is freed (gives consumers time to clean up) |
| `card_removed` | `instance_id: String` | After card node is freed |

## Tuning Knobs

No runtime tuning knobs. All placement values are owned by Table Layout System
(`spawn_min_distance`, `spawn_max_distance`, `min_card_spacing`, `max_scatter_attempts`).
The instance counter and registry behavior are not designer-adjustable.

## Acceptance Criteria

- [ ] `spawn_card(card_id, position)` returns a unique `instance_id` in the format `card_id + "_" + counter`
- [ ] Two calls to `spawn_card()` with the same `card_id` return different instance_ids (e.g. `morning-light_0`, `morning-light_1`)
- [ ] `card_spawned(instance_id, card_id, position)` signal fires immediately after node is added to scene tree
- [ ] `card_removing(instance_id)` fires before the node is freed; `card_removed(instance_id)` fires after
- [ ] `remove_card()` with an unknown instance_id logs a warning and does nothing (no crash)
- [ ] `spawn_card()` with an unknown `card_id` logs an error and returns null (no node created)
- [ ] Instance counters are never reused: a card_id that has been spawned 3 times and had 2 removed still assigns `_3` to the next spawn, not `_0` or `_1`
- [ ] `get_live_cards()` returns the authoritative list of all current instance_ids on the table
- [ ] `clear_all_cards()` removes all live cards, fires `card_removing` + `card_removed` for each, and leaves the registry empty
- [ ] During `Clearing` state, new `spawn_card()` calls are queued and execute after clearing completes
- [ ] Card Spawning System is the only system that calls `instantiate()` or `free()` on card nodes

## Open Questions

- **`get_live_cards()` query interface**: Should callers be able to query by `card_id` (e.g. "all instances of `morning-light`")? Useful for Generator to check if max_count is reached. Resolve when ITF is designed.
- **Counter persistence across scenes**: Do counters reset between scenes, or accumulate across the full session? Currently specified as session-global (never reset). If a bug requires resetting, revisit here.
- **Scene-scoped registry query**: Scene Manager may need to know which cards belong to the current scene (not cards queued for a new scene). Consider adding `get_live_cards(scene_id)` filter if needed.
