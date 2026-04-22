## CardDatabase — autoload #2. Loads the CardManifest at startup and holds
## all CardEntry resources for the session.
## Lookup API (Story 005) and missing-art detection (Story 006) are added by
## later stories. This autoload owns load, validation (Story 004), and storage.
##
## NOTE: class_name is intentionally omitted. Godot 4 does not allow a script
## registered as an autoload singleton to also declare a class_name matching
## its autoload name — the engine reports "Class hides an autoload singleton".
## The autoload is accessed globally via the name assigned in project.godot.
extends Node

const MANIFEST_PATH := "res://assets/data/cards.tres"

## Known scene identifiers. Cards with a scene_id not in this list log a
## push_warning at load time. Extend this list when the SceneManager epic
## defines the authoritative scene registry.
## Note: PackedStringArray literals are not compile-time constants in GDScript
## 4.3, so this is declared as a var rather than const.
var KNOWN_SCENE_IDS: PackedStringArray = PackedStringArray(["global", "scene-01"])

var _entries: Array[CardEntry] = []
var _index: Dictionary = {}   # StringName → CardEntry


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_manifest(MANIFEST_PATH)


## Loads a CardManifest .tres at [param path] and stores its entries on this
## autoload. Separated from _ready() so tests can inject a fixture path.
## Fails the assert if the file is missing or is not a CardManifest.
func _load_manifest(path: String) -> void:
	var raw: Resource = ResourceLoader.load(path)
	var manifest: CardManifest = raw as CardManifest
	assert(manifest != null,
		"CardDatabase: %s is missing or not a CardManifest" % path)
	_entries = manifest.entries
	_validate_entries()
	_build_index()


## Validates all loaded entries for semantic correctness.
## Hard errors (duplicate id, invalid CardType) use assert — they halt
## execution in debug builds and are caught at dev time.
## Soft issues (empty display_name, orphaned scene_id) use push_warning —
## the card remains usable but the designer is alerted.
## Called once inside _load_manifest(), after the cast succeeds.
func _validate_entries() -> void:
	var seen: Dictionary = {}
	for e: CardEntry in _entries:
		assert(not seen.has(e.id),
			"CardDatabase: duplicate card id: %s" % e.id)
		seen[e.id] = true

		if e.display_name == "":
			push_warning("CardDatabase: empty display_name on card %s" % e.id)

		assert(CardEntry.CardType.values().has(e.type),
			"CardDatabase: invalid CardType on card %s" % e.id)

		if not KNOWN_SCENE_IDS.has(String(e.scene_id)):
			push_warning("CardDatabase: orphaned scene_id '%s' on card %s"
				% [e.scene_id, e.id])

		if e.art == null:
			push_warning("CardDatabase: missing art on card %s" % e.id)


## Builds the id→entry index from _entries. Called once at the end of
## _load_manifest(), after _validate_entries() has asserted uniqueness.
## Separated so tests that call _load_manifest() get the index for free.
func _build_index() -> void:
	_index.clear()
	for e: CardEntry in _entries:
		_index[e.id] = e


## Returns the [CardEntry] for [param id], or null if no card with that id
## exists. Logs an error via push_error naming the missing id.
## Callers must treat the returned entry as read-only.
##
## Usage example:
##   var entry: CardEntry = CardDatabase.get_card(&"rainy-afternoon")
func get_card(id: StringName) -> CardEntry:
	var entry: CardEntry = _index.get(id, null)
	if entry == null:
		push_error("CardDatabase: no card with id '%s'" % id)
	return entry


## Returns the full populated entries array in stable (declaration) order.
## Callers must not mutate the returned array or its elements.
##
## Usage example:
##   for entry: CardEntry in CardDatabase.get_all():
##       print(entry.display_name)
func get_all() -> Array[CardEntry]:
	return _entries
