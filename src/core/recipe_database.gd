## RecipeDatabase — read-only combination rule registry.
## Autoload singleton. Loads all recipe JSON from assets/data/recipes/ at startup.
## Validates all card ID references against CardDatabase at load time.
## Lookup is symmetric: get_recipe("chester","ju","home") == get_recipe("ju","chester","home").

extends Node

const DATA_PATH := "res://assets/data/recipes/"

# _scene_recipes[scene_id][pair_key] -> recipe Dictionary
# _global_recipes[pair_key] -> recipe Dictionary
# pair_key = sorted card IDs joined with "+" e.g. "chester+ju"
var _scene_recipes:  Dictionary = {}
var _global_recipes: Dictionary = {}


func _ready() -> void:
	_load_all()


## Returns the recipe for [param card_a_id] + [param card_b_id] in [param scene_id],
## or null if no rule exists. Scene-scoped rules take precedence over global.
## Returning null is normal — it means the pair is incompatible (push-away fires).
func get_recipe(card_a_id: String, card_b_id: String, scene_id: String) -> Variant:
	var key := _make_key(card_a_id, card_b_id)

	# Scene-scoped takes precedence
	if _scene_recipes.has(scene_id) and _scene_recipes[scene_id].has(key):
		return _scene_recipes[scene_id][key]

	if _global_recipes.has(key):
		return _global_recipes[key]

	return null


## Returns true if any rule exists for this card pair in [param scene_id].
func has_recipe(card_a_id: String, card_b_id: String, scene_id: String) -> bool:
	return get_recipe(card_a_id, card_b_id, scene_id) != null


## Returns all recipes as a flat Array of Dictionaries.
func get_all_recipes() -> Array:
	var result: Array = []
	for scene_map in _scene_recipes.values():
		result.append_array(scene_map.values())
	result.append_array(_global_recipes.values())
	return result


# ── Private ───────────────────────────────────────────────────────────────────

func _load_all() -> void:
	var dir := DirAccess.open(DATA_PATH)
	if dir == null:
		push_error("RecipeDatabase: cannot open data directory '%s'" % DATA_PATH)
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".json"):
			_load_file(DATA_PATH + file_name)
		file_name = dir.get_next()
	dir.list_dir_end()

	var total := get_all_recipes().size()
	print("RecipeDatabase: loaded %d recipe(s)" % total)


func _load_file(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("RecipeDatabase: cannot read '%s'" % path)
		return

	var raw := file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(raw) != OK:
		push_error("RecipeDatabase: JSON parse error in '%s': %s" % [path, json.get_error_message()])
		return

	_validate_and_store(json.data, path)


func _validate_and_store(data: Dictionary, source: String) -> void:
	# Required fields
	var id: String = data.get("id", "")
	if id == "":
		push_error("RecipeDatabase: missing 'id' in '%s' — skipping" % source)
		return

	var card_a: String = data.get("card_a", "")
	var card_b: String = data.get("card_b", "")
	if card_a == "" or card_b == "":
		push_error("RecipeDatabase: recipe '%s' missing card_a or card_b — skipping" % id)
		return

	if data.get("template", "") == "":
		push_error("RecipeDatabase: recipe '%s' missing template — skipping" % id)
		return

	if not data.has("config"):
		push_error("RecipeDatabase: recipe '%s' missing config — skipping" % id)
		return

	# Validate card IDs against CardDatabase
	if not CardDatabase.has_card(card_a):
		push_error("RecipeDatabase: recipe '%s' references unknown card_a '%s'" % [id, card_a])
		return
	if not CardDatabase.has_card(card_b):
		push_error("RecipeDatabase: recipe '%s' references unknown card_b '%s'" % [id, card_b])
		return

	# Validate result/spawn card IDs
	_validate_config_card_ids(id, data["template"], data["config"])

	# Generator interval floor
	if data["template"] == "Generator":
		var cfg: Dictionary = data["config"]
		if cfg.get("interval_sec", 1.0) < 0.5:
			push_warning("RecipeDatabase: recipe '%s' interval_sec < 0.5 — clamped to 0.5" % id)
			cfg["interval_sec"] = 0.5

	# Additive with empty spawns
	if data["template"] == "Additive":
		var spawns = data["config"].get("spawns", [])
		if spawns.is_empty():
			push_warning("RecipeDatabase: recipe '%s' has empty spawns list — no-op combination" % id)

	# Duplicate check and store
	var scene_id: String = data.get("scene_id", "global")
	var key := _make_key(card_a, card_b)

	if scene_id == "global":
		if _global_recipes.has(key):
			push_error("RecipeDatabase: duplicate global rule for pair '%s' (recipe '%s')" % [key, id])
			return
		_global_recipes[key] = data
	else:
		if not _scene_recipes.has(scene_id):
			_scene_recipes[scene_id] = {}
		if _scene_recipes[scene_id].has(key):
			push_error("RecipeDatabase: duplicate scene rule for pair '%s' in scene '%s' (recipe '%s')" % [key, scene_id, id])
			return
		_scene_recipes[scene_id][key] = data


func _validate_config_card_ids(recipe_id: String, template: String, config: Dictionary) -> void:
	match template:
		"Merge":
			var result: String = config.get("result_card", "")
			if result != "" and not CardDatabase.has_card(result):
				push_error("RecipeDatabase: recipe '%s' Merge result_card '%s' not in CardDatabase" % [recipe_id, result])
		"Additive":
			for spawn_id in config.get("spawns", []):
				if not CardDatabase.has_card(spawn_id):
					push_error("RecipeDatabase: recipe '%s' Additive spawn '%s' not in CardDatabase" % [recipe_id, spawn_id])
		"Generator":
			var gen: String = config.get("generates", "")
			if gen != "" and not CardDatabase.has_card(gen):
				push_error("RecipeDatabase: recipe '%s' Generator generates '%s' not in CardDatabase" % [recipe_id, gen])


static func _make_key(card_a_id: String, card_b_id: String) -> String:
	var ids := [card_a_id, card_b_id]
	ids.sort()
	return "+".join(ids)
