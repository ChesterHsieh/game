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

## Minimum generator interval in seconds. Values below this are clamped at
## load time with a push_warning. GDD Tuning Knob — TR-recipe-database-007.
const MIN_INTERVAL_SEC := 0.5

var _entries: Array[RecipeEntry] = []
## Pair-keyed lookup index. Key: normalised "lo|hi" pair string.
## Value: Dictionary { scene_id: StringName → RecipeEntry }.
## Built once in _load_manifest() after all validation steps.
var _index: Dictionary = {}


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
	_validate_card_refs()
	_validate_no_duplicates()
	_clamp_generator_intervals()
	_build_index()


## Validates that every card reference (card_a, card_b, and template-specific
## result/spawn/generates IDs) resolves in CardDatabase. Runs first among all
## validation steps so unknown IDs surface before duplicate or clamp checks.
## Hard assert — unknown card ID halts load in debug builds (dev-time content
## authoring error, per ADR-005 §6).
##
## Template routing:
##   additive  — config["spawns"]: Array each element resolved
##   merge     — config["result_card"]: StringName resolved
##   generator — config["generates"]: StringName resolved
##   animate   — no card refs in config; skipped
##   unknown   — assert halt (invalid template)
func _validate_card_refs() -> void:
	for r: RecipeEntry in _entries:
		_assert_card_exists(r.card_a, r.id, "card_a")
		_assert_card_exists(r.card_b, r.id, "card_b")

		match r.template:
			&"additive":
				var spawns: Array = r.config.get("spawns", [])
				assert(spawns is Array,
					"RecipeDatabase: recipe %s (additive) missing 'spawns' array" % r.id)
				for spawn_id: StringName in spawns:
					_assert_card_exists(StringName(spawn_id), r.id, "additive.spawn")
			&"merge":
				var result_id: StringName = r.config.get("result_card", &"")
				assert(result_id != &"",
					"RecipeDatabase: recipe %s (merge) missing 'result_card'" % r.id)
				_assert_card_exists(result_id, r.id, "merge.result_card")
			&"generator":
				var gen_id: StringName = r.config.get("generates", &"")
				assert(gen_id != &"",
					"RecipeDatabase: recipe %s (generator) missing 'generates'" % r.id)
				_assert_card_exists(gen_id, r.id, "generator.generates")
			&"animate":
				pass  # no card refs in animate config
			_:
				assert(false,
					"RecipeDatabase: recipe %s has unknown template '%s' (valid: additive, merge, animate, generator)"
						% [r.id, r.template])


## Checks that [param card_id] exists in CardDatabase. Asserts with a message
## naming both the [param recipe_id] and [param context] so authors can find the
## offending recipe immediately.
## CardDatabase.get_card() also push_errors on miss — both fire for loud failure.
##
## Usage example:
##   _assert_card_exists(&"rainy-afternoon", &"recipe-01", "card_a")
func _assert_card_exists(card_id: StringName, recipe_id: StringName, context: String) -> void:
	var entry: CardEntry = CardDatabase.get_card(card_id)
	assert(entry != null,
		"RecipeDatabase: recipe '%s' references unknown card '%s' (context: %s)"
			% [recipe_id, card_id, context])


## Detects duplicate rules for the same (scene_id, normalised pair) within the
## loaded entries. Pair (a,b) and (b,a) in the same scene_id are equivalent.
## The same pair in DIFFERENT scene_ids is allowed — that is the scene-scoped
## override mechanic (Story 006 precedence concern, not a duplicate).
## Hard assert — duplicate rules indicate a content-authoring error.
##
## Key format: "[scene_id]|[lo]|[hi]" where lo ≤ hi lexicographically.
func _validate_no_duplicates() -> void:
	var seen: Dictionary = {}  # String → StringName recipe_id
	for r: RecipeEntry in _entries:
		var key: String = _dup_key(r.scene_id, r.card_a, r.card_b)
		assert(not seen.has(key),
			"RecipeDatabase: duplicate rule for pair (%s, %s) in scene '%s' — recipes '%s' and '%s'"
				% [r.card_a, r.card_b, r.scene_id, seen.get(key, &""), r.id])
		seen[key] = r.id


## Returns a normalised deduplication key for a recipe pair in a scene.
## Sorting card_a / card_b lexicographically ensures (a,b) == (b,a).
## Includes scene_id so the same pair in different scenes does NOT collide.
##
## Usage example:
##   var key := RecipeDatabaseScript._dup_key(&"scene-01", &"cat", &"dog")
##   # → "scene-01|cat|dog"
static func _dup_key(scene_id: StringName, a: StringName, b: StringName) -> String:
	var sa: String = String(a)
	var sb: String = String(b)
	var lo: String = sa if sa <= sb else sb
	var hi: String = sb if sa <= sb else sa
	return "%s|%s|%s" % [String(scene_id), lo, hi]


## Clamps generator recipes whose config["interval_sec"] is below MIN_INTERVAL_SEC
## (0.5 s). Emits push_warning naming the recipe id and original value — this is
## a content-authoring correction, not a fatal error, so execution continues.
## Non-generator templates are silently skipped.
func _clamp_generator_intervals() -> void:
	for r: RecipeEntry in _entries:
		if r.template != &"generator":
			continue
		var interval: float = r.config.get("interval_sec", MIN_INTERVAL_SEC)
		if interval < MIN_INTERVAL_SEC:
			push_warning(
				"RecipeDatabase: recipe '%s' generator interval_sec %.3f < %.1f — clamped to %.1f"
					% [r.id, interval, MIN_INTERVAL_SEC, MIN_INTERVAL_SEC])
			r.config["interval_sec"] = MIN_INTERVAL_SEC


## Builds the pair→scenes index from _entries. Called once at the end of
## _load_manifest(), after all validation steps have run. Clears any previous
## index so test code can call _load_manifest() repeatedly.
##
## Index structure:
##   _index["lo|hi"] = { scene_id: StringName → RecipeEntry }
## where "lo|hi" is the alphabetically normalised card-pair key.
func _build_index() -> void:
	_index.clear()
	for r: RecipeEntry in _entries:
		var pair_key: String = _pair_key(r.card_a, r.card_b)
		if not _index.has(pair_key):
			_index[pair_key] = {}
		_index[pair_key][r.scene_id] = r


## Returns a normalised "lo|hi" string key for the given card-id pair.
## Alphabetical sort ensures lookup is symmetric regardless of argument order.
## Static so tests can call it without a database instance.
##
## Usage example:
##   var key: String = RecipeDatabaseScript._pair_key(&"dog", &"cat")
##   # returns "cat|dog"
static func _pair_key(a: StringName, b: StringName) -> String:
	var sa: String = String(a)
	var sb: String = String(b)
	var lo: String = sa if sa < sb else sb
	var hi: String = sb if sa < sb else sa
	return "%s|%s" % [lo, hi]


## Looks up the recipe for the given card pair in the given scene.
## Returns the scene-scoped RecipeEntry if one exists for [param scene_id];
## falls through to the global rule if no scene-scoped rule exists;
## returns null if no rule exists at all — null is not an error.
## Lookup is symmetric: argument order of card_a / card_b does not matter.
## This method is O(1), read-only, and has no side effects.
##
## Usage example:
##   var recipe: RecipeEntry = RecipeDatabase.lookup(&"cat", &"dog", &"scene-01")
##   if recipe == null:
##       # incompatible pair — push away
func lookup(card_a: StringName, card_b: StringName, scene_id: StringName) -> RecipeEntry:
	var pair_key: String = _pair_key(card_a, card_b)
	var scenes: Dictionary = _index.get(pair_key, {})
	if scenes.has(scene_id):
		return scenes[scene_id]
	if scenes.has(&"global"):
		return scenes[&"global"]
	return null


## Returns the full populated entries array in stable (declaration) order.
## Callers must not mutate the returned array or its elements.
##
## Usage example:
##   for entry: RecipeEntry in RecipeDatabase.get_all():
##       print(entry.id)
func get_all() -> Array[RecipeEntry]:
	return _entries


## Returns true if a recipe with [param recipe_id] exists in the loaded
## manifest. Case-sensitive. Returns false for empty or unknown ids.
## Used by MysteryUnlockTree to validate incoming recipe_ids before recording.
## This method is read-only and has no side effects.
##
## Usage example:
##   if RecipeDatabase.has_recipe("home-rain-walk"):
##       print("known recipe")
func has_recipe(recipe_id: String) -> bool:
	for r: RecipeEntry in _entries:
		if String(r.id) == recipe_id:
			return true
	return false


## Returns the total number of recipes in the loaded manifest.
## Used by MysteryUnlockTree to resolve milestone percentage thresholds.
## Returns 0 if no entries are loaded (manifest absent or empty).
##
## Usage example:
##   var total: int = RecipeDatabase.get_recipe_count()
func get_recipe_count() -> int:
	return _entries.size()


## Returns an Array[String] of all recipe ids in stable (declaration) order.
## Used by MysteryUnlockTree's force_unlock_all bypass to bulk-fill all recipes.
## Callers must not mutate the returned array.
##
## Usage example:
##   for rid in RecipeDatabase.get_all_recipe_ids():
##       print(rid)
func get_all_recipe_ids() -> Array[String]:
	var ids: Array[String] = []
	for r: RecipeEntry in _entries:
		ids.append(String(r.id))
	return ids
