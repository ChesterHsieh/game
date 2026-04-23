## EventBus — project-wide signal hub (ADR-003).
##
## This autoload is a pure signal declaration file. It owns no state, no caches,
## and no logic. All 30 signals are declared here and emitted/connected by the
## systems that own each domain.
##
## Usage:
##   EventBus.drag_started.connect(_on_drag_started)
##   EventBus.drag_started.emit(instance_id, world_pos)
extends Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


# ── Input / Card Engine ───────────────────────────────────────────────────────

signal drag_started(card_id: String, world_pos: Vector2)
signal drag_moved(card_id: String, world_pos: Vector2, delta: Vector2)
signal drag_released(card_id: String, world_pos: Vector2)
signal proximity_entered(dragged_id: String, target_id: String)
signal proximity_exited(dragged_id: String, target_id: String)

# ── Combination / Interaction Template Framework ──────────────────────────────

signal combination_attempted(instance_id_a: String, instance_id_b: String)
signal combination_succeeded(instance_id_a: String, instance_id_b: String, template: String, config: Dictionary)
signal combination_failed(instance_id_a: String, instance_id_b: String)
signal combination_executed(recipe_id: String, template: String, instance_id_a: String, instance_id_b: String, card_id_a: String, card_id_b: String)
signal merge_animation_complete(instance_id_a: String, instance_id_b: String, midpoint: Vector2)
signal animate_complete(instance_id: String)

## Emitted by ITF when a fired recipe has config.emote set. The emote
## renderer (EmoteHandler in gameplay.tscn) subscribes and spawns the
## bubble at world_pos.
signal emote_requested(emote_name: String, world_pos: Vector2)

# ── Card Spawning System ──────────────────────────────────────────────────────

signal card_spawned(instance_id: String, card_id: String, position: Vector2)
signal card_removing(instance_id: String)
signal card_removed(instance_id: String)

# ── Status / Goal / Hint ──────────────────────────────────────────────────────

signal bar_values_changed(values: Dictionary)
signal win_condition_met()
signal hint_level_changed(level: int)

# ── Scene Lifecycle ───────────────────────────────────────────────────────────

signal seed_cards_ready(seed_cards: Array)
signal scene_loading(scene_id: String)
signal scene_started(scene_id: String)
signal scene_completed(scene_id: String)
signal epilogue_started()

# ── Mystery Unlock Tree ───────────────────────────────────────────────────────

signal recipe_discovered(recipe_id: String, card_id_a: String, card_id_b: String, scene_id: String)
signal discovery_milestone_reached(milestone_id: String, discovery_count: int)
## Emitted by SceneGoalSystem when a bar reaches a declared milestone value.
## Scene Manager listens and spawns the listed card IDs onto the table.
signal milestone_cards_spawn(card_ids: PackedStringArray)
signal epilogue_conditions_met()
signal final_memory_ready()

# ── Scene Transition UI ───────────────────────────────────────────────────────

signal epilogue_cover_ready()

# ── Startup ───────────────────────────────────────────────────────────────────

signal game_start_requested()

# ── Persistence ───────────────────────────────────────────────────────────────

signal save_written()
signal save_failed(reason: String)
