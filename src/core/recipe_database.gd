## RecipeDatabase — autoload #3. Loads the RecipeManifest at startup and holds
## all RecipeEntry resources for the session.
## Cross-validation against CardDatabase (Story 003), duplicate-rule detection
## (Story 004), Generator interval clamp (Story 005), and the lookup index
## (Story 006) are added by later stories. This autoload owns load and storage.
##
## NOTE: class_name is intentionally omitted. Godot 4 does not allow a script
## registered as an autoload singleton to also declare a class_name matching
## its autoload name — the engine reports "Class hides an autoload singleton".
## The autoload is accessed globally via the name assigned in project.godot.
extends Node

const MANIFEST_PATH := "res://assets/data/recipes.tres"

var _entries: Array[RecipeEntry] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_manifest(MANIFEST_PATH)


## Loads a RecipeManifest .tres at [param path] and stores its entries on this
## autoload. Separated from _ready() so tests can inject a fixture path.
## Fails the assert if the file is missing or is not a RecipeManifest.
##
## Usage example:
##   RecipeDatabase._load_manifest("res://tests/fixtures/recipe_database/recipes_minimal.tres")
func _load_manifest(path: String) -> void:
	var raw: Resource = ResourceLoader.load(path)
	var manifest: RecipeManifest = raw as RecipeManifest
	assert(manifest != null,
		"RecipeDatabase: %s is missing or not a RecipeManifest" % path)
	_entries = manifest.entries
	# Story 003 appends cross-validation against CardDatabase here.
	# Story 004 appends duplicate-rule detection.
	# Story 005 appends Generator interval_sec clamp.
	# Story 006 builds the lookup index.


## Returns the full populated entries array in stable (declaration) order.
## Callers must not mutate the returned array or its elements.
##
## Usage example:
##   for entry: RecipeEntry in RecipeDatabase.get_all():
##       print(entry.id)
func get_all() -> Array[RecipeEntry]:
	return _entries
