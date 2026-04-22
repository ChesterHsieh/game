## Factory functions for creating test game objects.
## Returns minimal objects for unit testing without requiring the scene tree.
##
## Bounds and defaults trace to GDD Formulas and Tuning Knobs sections.
class_name GameFactory
extends RefCounted


# --- GDD-derived constants ----------------------------------------------------

const DEFAULT_MAX_BAR_VALUE := 100.0
const DEFAULT_INITIAL_BAR_VALUE := 0.0
const DEFAULT_SNAP_RADIUS := 80.0
const SNAP_RADIUS_MIN := 40.0
const SNAP_RADIUS_MAX := 160.0
const DEFAULT_STAGNATION_SEC := 300.0
const STAGNATION_SEC_MIN := 60.0
const STAGNATION_SEC_MAX := 900.0
const DEFAULT_POOL_SIZE := 30
const CARD_TYPES := ["person", "place", "feeling", "object", "moment", "inside_joke", "seed"]
const TEMPLATES := ["Additive", "Merge", "Animate", "Generator"]


# --- Card Entry ---------------------------------------------------------------

static func make_card_entry(overrides: Dictionary = {}) -> Dictionary:
	var entry := {
		"id": overrides.get("id", "test-card-001"),
		"display_name": overrides.get("display_name", "Test Card"),
		"flavor_text": overrides.get("flavor_text", "A card for testing."),
		"art_path": overrides.get("art_path", "res://assets/cards/placeholder.png"),
		"type": overrides.get("type", "object"),
		"scene_id": overrides.get("scene_id", "home"),
		"tags": overrides.get("tags", PackedStringArray()),
	}
	return entry


static func make_card_entries(count: int, scene_id: String = "home") -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for i: int in range(count):
		entries.append(make_card_entry({
			"id": "test-card-%03d" % i,
			"display_name": "Test Card %d" % i,
			"scene_id": scene_id,
		}))
	return entries


# --- Recipe Entry -------------------------------------------------------------

static func make_recipe_entry(overrides: Dictionary = {}) -> Dictionary:
	var entry := {
		"id": overrides.get("id", "test-recipe-001"),
		"card_a": overrides.get("card_a", "test-card-001"),
		"card_b": overrides.get("card_b", "test-card-002"),
		"template": overrides.get("template", "Additive"),
		"config": overrides.get("config", {}),
		"scene_id": overrides.get("scene_id", "home"),
	}
	return entry


static func make_recipe_pair(
	card_a_id: String,
	card_b_id: String,
	template: String = "Additive",
	config: Dictionary = {}
) -> Dictionary:
	return make_recipe_entry({
		"id": "%s+%s" % [card_a_id, card_b_id],
		"card_a": card_a_id,
		"card_b": card_b_id,
		"template": template,
		"config": config,
	})


# --- Bar Config ---------------------------------------------------------------

static func make_bar_config(overrides: Dictionary = {}) -> Dictionary:
	var config := {
		"bars": overrides.get("bars", [
			{
				"bar_id": "chester",
				"display_name": "Chester",
				"initial_value": overrides.get("initial_value", DEFAULT_INITIAL_BAR_VALUE),
				"max_value": overrides.get("max_value", DEFAULT_MAX_BAR_VALUE),
				"decay_rate": overrides.get("decay_rate", 0.0),
			},
		]),
		"win_condition": overrides.get("win_condition", {
			"type": "sustain",
			"threshold": overrides.get("threshold", 80.0),
			"duration_sec": overrides.get("duration_sec", 3.0),
		}),
	}
	return config


static func make_bar_effects(recipe_id: String, effects: Dictionary = {}) -> Dictionary:
	if effects.is_empty():
		effects = {"chester": 10.0}
	return {recipe_id: effects}


# --- Scene Data ---------------------------------------------------------------

static func make_scene_data(overrides: Dictionary = {}) -> Dictionary:
	var data := {
		"id": overrides.get("id", "home"),
		"seed_cards": overrides.get("seed_cards", PackedStringArray(["test-card-001", "test-card-002"])),
		"carry_forward": overrides.get("carry_forward", []),
		"goal": overrides.get("goal", {"type": "sustain", "threshold": 80.0, "duration_sec": 3.0}),
		"bar_config": overrides.get("bar_config", make_bar_config()),
		"hint_stagnation_sec": overrides.get("hint_stagnation_sec", DEFAULT_STAGNATION_SEC),
	}
	return data


# --- Save State ---------------------------------------------------------------

static func make_save_state(overrides: Dictionary = {}) -> Dictionary:
	var state := {
		"schema_version": overrides.get("schema_version", 1),
		"saved_at_unix": overrides.get("saved_at_unix", 1713700000),
		"moments_build": overrides.get("moments_build", "test"),
		"resume_index": overrides.get("resume_index", 0),
		"mystery_unlock_tree": overrides.get("mystery_unlock_tree", {}),
	}
	return state


# --- Minimal Node Helpers (for unit tests that need a Node) -------------------

static func make_card_node(card_id: String = "test-card-001", position: Vector2 = Vector2.ZERO) -> Node2D:
	var node := Node2D.new()
	node.name = "Card_%s" % card_id
	node.position = position
	node.set_meta("card_id", card_id)
	node.set_meta("instance_id", "inst_%s_%d" % [card_id, randi()])
	node.set_meta("fsm_state", "Idle")
	return node


static func make_card_nodes(card_ids: PackedStringArray, spacing: float = 120.0) -> Array[Node2D]:
	var nodes: Array[Node2D] = []
	for i: int in range(card_ids.size()):
		var pos := Vector2(i * spacing, 0.0)
		nodes.append(make_card_node(card_ids[i], pos))
	return nodes


# --- Position Helpers ---------------------------------------------------------

static func positions_within_snap(
	snap_radius: float = DEFAULT_SNAP_RADIUS
) -> Array[Vector2]:
	var half := snap_radius * 0.4
	return [Vector2.ZERO, Vector2(half, 0.0)]


static func positions_outside_snap(
	snap_radius: float = DEFAULT_SNAP_RADIUS
) -> Array[Vector2]:
	var beyond := snap_radius * 1.5
	return [Vector2.ZERO, Vector2(beyond, 0.0)]
