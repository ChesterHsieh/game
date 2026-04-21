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

# ─── Input / Card Engine (see design/gdd/card-engine.md, input-system.md) ────
signal drag_started(card_id: String, world_pos: Vector2)
signal drag_moved(card_id: String, world_pos: Vector2, delta: float)
signal drag_released(card_id: String, world_pos: Vector2)
signal proximity_entered(dragged_id: String, target_id: String)
signal proximity_exited(dragged_id: String, target_id: String)

# ─── Combination / Interaction Template Framework ────────────────────────────
# (see design/gdd/card-engine.md, interaction-template-framework.md)
signal combination_attempted(instance_id_a: String, instance_id_b: String)
signal combination_succeeded(instance_id_a: String, instance_id_b: String, template: String, config: Dictionary)
signal combination_failed(instance_id_a: String, instance_id_b: String)
# combination_executed is 6 params (MUT Rule 4 / OQ-7 expansion 2026-04-18):
# recipe_id + template + 2 instance_ids + 2 card_ids (for MUT discovery recording).
# All consumers must declare handlers with 6 params in Godot 4.3 (arity-strict).
signal combination_executed(
	recipe_id: String,
	template: String,
	instance_id_a: String,
	instance_id_b: String,
	card_id_a: String,
	card_id_b: String
)
signal merge_animation_complete(instance_id_a: String, instance_id_b: String, midpoint: Vector2)
signal animate_complete(instance_id: String)

# ─── Card Spawning System (see design/gdd/card-spawning-system.md) ───────────
signal card_spawned(instance_id: String, card_id: String, position: Vector2)
signal card_removing(instance_id: String)
signal card_removed(instance_id: String)

# ─── Status / Goal / Hint (see design/gdd/status-bar-system.md, scene-goal-system.md, hint-system.md) ──
signal bar_values_changed(values: Dictionary)
signal win_condition_met()
signal hint_level_changed(level: int)

# ─── Scene Lifecycle (see design/gdd/scene-manager.md) ───────────────────────
signal seed_cards_ready(seed_cards: Array)
signal scene_loading(scene_id: String)
signal scene_started(scene_id: String)
signal scene_completed(scene_id: String)
signal epilogue_started()

# ─── Mystery Unlock Tree (see design/gdd/mystery-unlock-tree.md) ─────────────
signal recipe_discovered(recipe_id: String, card_id_a: String, card_id_b: String, scene_id: String)
signal discovery_milestone_reached(milestone_id: String, discovery_count: int)
signal epilogue_conditions_met()
signal final_memory_ready()

# ─── Scene Transition UI (see design/gdd/scene-transition-ui.md) ─────────────
signal epilogue_cover_ready()

# ─── Startup (see design/gdd/main-menu.md) ───────────────────────────────────
signal game_start_requested()

# ─── Persistence (see design/gdd/save-progress-system.md) ────────────────────
signal save_written()
signal save_failed(reason: String)
```

> **Maintenance rule**: any new signal introduced by a GDD MUST be declared here
> before the emitting system is implemented. Declaring a signal in a GDD's
> "Signals Emitted" table without adding it here produces a runtime error at
> emit time. This list is the single source of truth; GDD tables are references
> to it, not alternatives.

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
