## Unit tests for RecipeEntry and RecipeManifest Resource classes.
## Story 001 — recipe-database epic.
## gdUnit4 test suite: all 4 acceptance criteria.
extends GdUnitTestSuite


# ── AC-1: RecipeEntry class exists and all required properties are present ─────

func test_recipe_entry_has_required_properties() -> void:
	# Arrange
	var entry := RecipeEntry.new()

	# Act
	var prop_names: Array[String] = []
	for p: Dictionary in entry.get_property_list():
		prop_names.append(p["name"] as String)

	# Assert
	assert_array(prop_names).contains(["id", "card_a", "card_b", "template", "scene_id", "config"])


func test_recipe_entry_id_is_string_name_type() -> void:
	var entry := RecipeEntry.new()
	assert_int(typeof(entry.id)).is_equal(TYPE_STRING_NAME)


func test_recipe_entry_card_a_is_string_name_type() -> void:
	var entry := RecipeEntry.new()
	assert_int(typeof(entry.card_a)).is_equal(TYPE_STRING_NAME)


func test_recipe_entry_card_b_is_string_name_type() -> void:
	var entry := RecipeEntry.new()
	assert_int(typeof(entry.card_b)).is_equal(TYPE_STRING_NAME)


func test_recipe_entry_template_is_string_name_type() -> void:
	var entry := RecipeEntry.new()
	assert_int(typeof(entry.template)).is_equal(TYPE_STRING_NAME)


func test_recipe_entry_scene_id_is_string_name_type() -> void:
	var entry := RecipeEntry.new()
	assert_int(typeof(entry.scene_id)).is_equal(TYPE_STRING_NAME)


func test_recipe_entry_config_is_dictionary_type() -> void:
	var entry := RecipeEntry.new()
	assert_int(typeof(entry.config)).is_equal(TYPE_DICTIONARY)


# ── AC-2: RecipeEntry.new() returns correct defaults ─────────────────────────

func test_recipe_entry_default_id_is_empty_string_name() -> void:
	# Arrange / Act
	var entry := RecipeEntry.new()
	# Assert
	assert_that(entry.id == &"").is_true()


func test_recipe_entry_default_card_a_is_empty_string_name() -> void:
	var entry := RecipeEntry.new()
	assert_that(entry.card_a == &"").is_true()


func test_recipe_entry_default_card_b_is_empty_string_name() -> void:
	var entry := RecipeEntry.new()
	assert_that(entry.card_b == &"").is_true()


func test_recipe_entry_default_template_is_empty_string_name() -> void:
	var entry := RecipeEntry.new()
	assert_that(entry.template == &"").is_true()


func test_recipe_entry_default_scene_id_is_global() -> void:
	var entry := RecipeEntry.new()
	assert_that(entry.scene_id == &"global").is_true()


func test_recipe_entry_default_config_is_empty_dictionary() -> void:
	var entry := RecipeEntry.new()
	assert_int(entry.config.size()).is_equal(0)


# ── AC-3: RecipeManifest wraps Array[RecipeEntry] ────────────────────────────

func test_recipe_manifest_entries_starts_empty() -> void:
	# Arrange / Act
	var manifest := RecipeManifest.new()
	# Assert
	assert_int(manifest.entries.size()).is_equal(0)


func test_recipe_manifest_accepts_recipe_entry_append() -> void:
	# Arrange
	var manifest := RecipeManifest.new()
	var entry := RecipeEntry.new()
	# Act
	manifest.entries.append(entry)
	# Assert
	assert_int(manifest.entries.size()).is_equal(1)


func test_recipe_manifest_entry_is_recipe_entry_instance() -> void:
	# Arrange
	var manifest := RecipeManifest.new()
	var entry := RecipeEntry.new()
	# Act
	manifest.entries.append(entry)
	# Assert
	assert_bool(manifest.entries[0] is RecipeEntry).is_true()


# ── AC-4: Round-trip via ResourceLoader for each of the 4 templates ──────────

func test_round_trip_additive_template_loads_non_null_manifest() -> void:
	# Arrange / Act
	var manifest: RecipeManifest = ResourceLoader.load(
			"res://tests/fixtures/recipe_database/recipe_additive.tres") as RecipeManifest
	# Assert
	assert_object(manifest).is_not_null()


func test_round_trip_additive_template_has_one_entry() -> void:
	var manifest: RecipeManifest = ResourceLoader.load(
			"res://tests/fixtures/recipe_database/recipe_additive.tres") as RecipeManifest
	assert_int(manifest.entries.size()).is_equal(1)


func test_round_trip_additive_template_entry_fields_match_fixture() -> void:
	# Arrange
	var manifest: RecipeManifest = ResourceLoader.load(
			"res://tests/fixtures/recipe_database/recipe_additive.tres") as RecipeManifest
	# Act
	var entry: RecipeEntry = manifest.entries[0]
	# Assert
	assert_that(entry.id == &"test_additive_001").is_true()
	assert_that(entry.card_a == &"card_flowers").is_true()
	assert_that(entry.card_b == &"card_music").is_true()
	assert_that(entry.template == &"additive").is_true()
	assert_that(entry.scene_id == &"global").is_true()
	assert_bool(entry.config.has("spawns")).is_true()


func test_round_trip_merge_template_loads_non_null_manifest() -> void:
	var manifest: RecipeManifest = ResourceLoader.load(
			"res://tests/fixtures/recipe_database/recipe_merge.tres") as RecipeManifest
	assert_object(manifest).is_not_null()


func test_round_trip_merge_template_entry_fields_match_fixture() -> void:
	# Arrange
	var manifest: RecipeManifest = ResourceLoader.load(
			"res://tests/fixtures/recipe_database/recipe_merge.tres") as RecipeManifest
	# Act
	var entry: RecipeEntry = manifest.entries[0]
	# Assert
	assert_that(entry.template == &"merge").is_true()
	assert_bool(entry.config.has("result_card")).is_true()
	assert_that(entry.config["result_card"] == &"card_shelter").is_true()


func test_round_trip_animate_template_loads_non_null_manifest() -> void:
	var manifest: RecipeManifest = ResourceLoader.load(
			"res://tests/fixtures/recipe_database/recipe_animate.tres") as RecipeManifest
	assert_object(manifest).is_not_null()


func test_round_trip_animate_template_entry_fields_match_fixture() -> void:
	# Arrange
	var manifest: RecipeManifest = ResourceLoader.load(
			"res://tests/fixtures/recipe_database/recipe_animate.tres") as RecipeManifest
	# Act
	var entry: RecipeEntry = manifest.entries[0]
	# Assert
	assert_that(entry.template == &"animate").is_true()
	assert_bool(entry.config.has("motion")).is_true()
	assert_bool(entry.config.has("speed")).is_true()
	assert_bool(entry.config.has("target")).is_true()
	assert_bool(entry.config.has("duration_sec")).is_true()


func test_round_trip_generator_template_loads_non_null_manifest() -> void:
	var manifest: RecipeManifest = ResourceLoader.load(
			"res://tests/fixtures/recipe_database/recipe_generator.tres") as RecipeManifest
	assert_object(manifest).is_not_null()


func test_round_trip_generator_template_entry_fields_match_fixture() -> void:
	# Arrange
	var manifest: RecipeManifest = ResourceLoader.load(
			"res://tests/fixtures/recipe_database/recipe_generator.tres") as RecipeManifest
	# Act
	var entry: RecipeEntry = manifest.entries[0]
	# Assert
	assert_that(entry.template == &"generator").is_true()
	assert_bool(entry.config.has("generates")).is_true()
	assert_bool(entry.config.has("interval_sec")).is_true()
	assert_bool(entry.config.has("max_count")).is_true()
	assert_bool(entry.config.has("generator_card")).is_true()


func test_round_trip_wrong_type_cast_returns_null() -> void:
	# Arrange / Act — cast RecipeManifest as CardManifest should return null
	var raw: Resource = ResourceLoader.load(
			"res://tests/fixtures/recipe_database/recipe_additive.tres")
	var wrong_cast: CardManifest = raw as CardManifest
	# Assert
	assert_object(wrong_cast).is_null()
