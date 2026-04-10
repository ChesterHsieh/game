## CardDatabase — read-only card definition registry.
## Autoload singleton. Loads all card JSON from assets/data/cards/ at startup.
## No system writes to this at runtime.

extends Node

const DATA_PATH := "res://assets/data/cards/"

var _cards: Dictionary = {}  # id -> card data Dictionary


func _ready() -> void:
	_load_all()


## Returns card data for [param id], or an empty Dictionary if not found.
## Logs an error on miss — callers should check has_card() when in doubt.
func get_card(id: String) -> Dictionary:
	if not _cards.has(id):
		push_error("CardDatabase: card '%s' not found" % id)
		return {}
	return _cards[id]


## Returns true if a card with [param id] exists in the database.
func has_card(id: String) -> bool:
	return _cards.has(id)


## Returns all card entries as an Array of Dictionaries.
func get_all_cards() -> Array:
	return _cards.values()


## Returns all cards whose [code]scene_id[/code] matches [param scene_id],
## plus any cards with [code]scene_id == "global"[/code].
func get_cards_for_scene(scene_id: String) -> Array:
	var result: Array = []
	for card in _cards.values():
		if card.get("scene_id", "") == scene_id or card.get("scene_id", "") == "global":
			result.append(card)
	return result


# ── Private ───────────────────────────────────────────────────────────────────

func _load_all() -> void:
	var dir := DirAccess.open(DATA_PATH)
	if dir == null:
		push_error("CardDatabase: cannot open data directory '%s'" % DATA_PATH)
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".json"):
			_load_file(DATA_PATH + file_name)
		file_name = dir.get_next()
	dir.list_dir_end()

	print("CardDatabase: loaded %d card(s)" % _cards.size())


func _load_file(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("CardDatabase: cannot read '%s'" % path)
		return

	var raw := file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(raw) != OK:
		push_error("CardDatabase: JSON parse error in '%s': %s" % [path, json.get_error_message()])
		return

	_validate_and_store(json.data, path)


func _validate_and_store(data: Dictionary, source: String) -> void:
	# Required: id
	var id: String = data.get("id", "")
	if id == "":
		push_error("CardDatabase: missing or empty 'id' in '%s' — skipping" % source)
		return

	# Required: type
	if data.get("type", "") == "":
		push_error("CardDatabase: missing or empty 'type' for card '%s' — skipping" % id)
		return

	# Warning: empty display_name
	if data.get("display_name", "") == "":
		push_warning("CardDatabase: empty 'display_name' for card '%s'" % id)

	# Duplicate check
	if _cards.has(id):
		push_error("CardDatabase: duplicate id '%s' found in '%s' — skipping" % [id, source])
		return

	_cards[id] = data
