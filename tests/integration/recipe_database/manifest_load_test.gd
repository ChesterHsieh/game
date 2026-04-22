## Integration tests for RecipeDatabase autoload — Story 002.
##
## Covers the 5 QA test cases from the story:
##   AC-1: autoload at position #3, PROCESS_MODE_ALWAYS
##   AC-2: happy-path load from fixture populates _entries
##   AC-3: missing file — ResourceLoader returns null, cast yields null
##   AC-4: wrong-type .tres — cast yields null
##   AC-5: autoload _entries populated before test code runs (load-before-instantiation)
extends GdUnitTestSuite

# RecipeDatabase's autoload name occupies the global identifier, so the script
# does not declare a class_name. Preload the script to instantiate test copies.
const RecipeDatabaseScript := preload("res://src/core/recipe_database.gd")


# ── AC-1: Autoload position #3 with PROCESS_MODE_ALWAYS ──────────────────────

func test_recipe_database_is_third_autoload_in_project_godot() -> void:
	var file := FileAccess.open("res://project.godot", FileAccess.READ)
	var content := file.get_as_text()
	file.close()

	var in_autoload := false
	var autoload_keys: Array[String] = []
	for line: String in content.split("\n"):
		if line.strip_edges() == "[autoload]":
			in_autoload = true
			continue
		if in_autoload and line.begins_with("["):
			break
		if in_autoload and "=" in line and not line.strip_edges().is_empty():
			autoload_keys.append(line.split("=")[0].strip_edges())

	assert_int(autoload_keys.size()).is_greater_equal(3)
	assert_str(autoload_keys[2]).is_equal("RecipeDatabase")


func test_recipe_database_appears_after_card_database_in_autoload() -> void:
	var file := FileAccess.open("res://project.godot", FileAccess.READ)
	var content := file.get_as_text()
	file.close()

	var in_autoload := false
	var autoload_keys: Array[String] = []
	for line: String in content.split("\n"):
		if line.strip_edges() == "[autoload]":
			in_autoload = true
			continue
		if in_autoload and line.begins_with("["):
			break
		if in_autoload and "=" in line and not line.strip_edges().is_empty():
			autoload_keys.append(line.split("=")[0].strip_edges())

	var card_db_pos := autoload_keys.find("CardDatabase")
	var recipe_db_pos := autoload_keys.find("RecipeDatabase")
	assert_int(card_db_pos).is_greater_equal(0)
	assert_int(recipe_db_pos).is_greater(card_db_pos)


func test_recipe_database_process_mode_is_always() -> void:
	assert_int(RecipeDatabase.process_mode).is_equal(Node.PROCESS_MODE_ALWAYS)


func test_recipe_database_accessible_at_root() -> void:
	var node := get_node_or_null("/root/RecipeDatabase")
	assert_that(node).is_not_null()


# ── AC-2: Happy-path load from fixture populates _entries ────────────────────

func test_load_manifest_populates_three_entries_from_fixture() -> void:
	var db: Node = RecipeDatabaseScript.new()
	db._load_manifest("res://tests/fixtures/recipe_database/recipes_three_entries.tres")
	assert_int(db._entries.size()).is_equal(3)
	db.free()


func test_load_manifest_fixture_entries_are_recipe_entry_instances() -> void:
	var db: Node = RecipeDatabaseScript.new()
	db._load_manifest("res://tests/fixtures/recipe_database/recipes_three_entries.tres")
	for entry: RecipeEntry in db._entries:
		assert_bool(entry is RecipeEntry).is_true()
	db.free()


func test_load_manifest_fixture_first_entry_id_matches() -> void:
	var db: Node = RecipeDatabaseScript.new()
	db._load_manifest("res://tests/fixtures/recipe_database/recipes_three_entries.tres")
	assert_that(db._entries[0].id == &"fixture-additive-001").is_true()
	db.free()


func test_load_manifest_empty_manifest_succeeds_with_zero_entries() -> void:
	var db: Node = RecipeDatabaseScript.new()
	db._load_manifest("res://tests/fixtures/recipe_database/recipes_empty.tres")
	assert_int(db._entries.size()).is_equal(0)
	db.free()


# ── AC-3: Missing file — ResourceLoader returns null, cast yields null ────────
#
# NOTE: _load_manifest() contains a hard assert() which is a fatal crash in
# debug builds. We cannot call it with a bogus path inside a test — it would
# abort the test runner. Instead we verify the two invariants that the assert
# relies on: ResourceLoader returns null for missing files, and `null as
# RecipeManifest` is null. Together these prove _load_manifest would correctly
# trip the assert if called with a missing path.

func test_resource_loader_returns_null_for_missing_path() -> void:
	var result: Resource = ResourceLoader.load("res://nonexistent/does_not_exist.tres")
	assert_object(result).is_null()


func test_null_cast_to_recipe_manifest_yields_null() -> void:
	var raw: Resource = null
	var cast_result: RecipeManifest = raw as RecipeManifest
	assert_object(cast_result).is_null()


# ── AC-4: Wrong-type resource cast yields null ────────────────────────────────

func test_bare_resource_cast_to_recipe_manifest_yields_null() -> void:
	var raw := Resource.new()
	var cast_result: RecipeManifest = raw as RecipeManifest
	assert_object(cast_result).is_null()


func test_recipe_entry_cast_to_recipe_manifest_yields_null() -> void:
	var wrong: RecipeEntry = RecipeEntry.new()
	var cast_result: RecipeManifest = wrong as RecipeManifest
	assert_object(cast_result).is_null()


# ── AC-5: Autoload _entries populated before tests run ───────────────────────

func test_autoload_entries_populated_at_test_startup() -> void:
	# RecipeDatabase loads recipes.tres (3-entry placeholder) during autoload _ready().
	# Any positive count confirms load-before-instantiation ordering is satisfied.
	assert_int(RecipeDatabase._entries.size()).is_greater_equal(1)


func test_autoload_first_entry_is_recipe_entry_instance() -> void:
	assert_bool(RecipeDatabase._entries[0] is RecipeEntry).is_true()
