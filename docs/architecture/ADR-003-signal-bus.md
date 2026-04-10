# ADR-003: Inter-System Communication — EventBus Singleton

> **Status**: Accepted
> **Date**: 2026-03-25
> **Decider**: Chester

## Context

Moments has 12+ systems that need to communicate (Card Engine → ITF, ITF → Status
Bar System, Hint System → Status Bar UI, etc.). Two approaches:

1. **Direct node references**: System A holds a reference to System B and calls
   methods or connects to signals directly. Simple for small graphs; becomes
   fragile as the system count grows (node paths hardcoded, load-order dependencies).
2. **Signal bus (EventBus singleton)**: An autoload singleton declares all game
   signals. Systems `emit` to EventBus; systems `connect` from EventBus. No system
   holds a reference to another.

## Decision

Use a **`EventBus` autoload singleton** as the inter-system signal hub.

```gdscript
# res://src/core/event_bus.gd (autoloaded as "EventBus")
extends Node

signal drag_started(card_id: String, world_pos: Vector2)
signal drag_moved(card_id: String, world_pos: Vector2, delta: float)
signal drag_released(card_id: String, world_pos: Vector2)
signal proximity_entered(dragged_id: String, target_id: String)
signal proximity_exited(dragged_id: String, target_id: String)

signal combination_attempted(instance_id_a: String, instance_id_b: String)
signal combination_succeeded(instance_id_a: String, instance_id_b: String, template: String, config: Dictionary)
signal combination_failed(instance_id_a: String, instance_id_b: String)
signal combination_executed(recipe_id: String, template: String, instance_id_a: String, instance_id_b: String)

signal bar_values_changed(values: Dictionary)
signal win_condition_met()
signal hint_level_changed(level: int)
signal seed_cards_ready(seed_cards: Array)
signal scene_completed(scene_id: String)
# ... all signals from GDDs
```

Systems emit: `EventBus.bar_values_changed.emit(values)`
Systems connect: `EventBus.bar_values_changed.connect(_on_bar_values_changed)`

Read-only method calls (e.g. `CardDatabase.get_card(id)`, `SceneGoalSystem.get_goal_config()`)
remain as direct autoload calls — EventBus is for events, not queries.

## Consequences

- Systems are fully decoupled — no node path dependencies, no load-order fragility
- All signals are declared in one place — easy to audit the full event graph
- Aligns exactly with GDD signal tables (every signal in every GDD maps to an EventBus declaration)
- Direct autoload calls for read-only queries keep data access simple without event overhead
- `CardDatabase` and `SceneGoalSystem` are also autoloads (singletons) for read-only query access
