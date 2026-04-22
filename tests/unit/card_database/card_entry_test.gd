## Unit tests for CardEntry and CardManifest Resource classes.
## Story 002 — card-database epic.
## gdUnit4 test suite: all 5 acceptance criteria.
extends GdUnitTestSuite


# ── AC-1: CardEntry class exists and all required properties are present ──────

func test_card_entry_has_required_properties() -> void:
	var entry := CardEntry.new()
	var props: Array[Dictionary] = []
	for p: Dictionary in entry.get_property_list():
		props.append(p)

	var prop_names: Array[String] = []
	for p: Dictionary in props:
		prop_names.append(p["name"] as String)

	assert_array(prop_names).contains(["id", "display_name", "flavor_text",
			"art", "type", "scene_id", "tags"])


func test_card_entry_id_is_string_name_type() -> void:
	var entry := CardEntry.new()
	assert_that(entry.id).is_instanceof(StringName)


func test_card_entry_display_name_is_string_type() -> void:
	var entry := CardEntry.new()
	assert_that(entry.display_name).is_instanceof(String)


func test_card_entry_tags_is_packed_string_array_type() -> void:
	var entry := CardEntry.new()
	assert_that(entry.tags).is_instanceof(PackedStringArray)


# ── AC-2: CardType enum has exactly 7 values in declaration order ─────────────

func test_card_type_enum_has_exactly_seven_values() -> void:
	var values: Array = CardEntry.CardType.values()
	assert_int(values.size()).is_equal(7)


func test_card_type_enum_values_are_in_declaration_order() -> void:
	assert_int(CardEntry.CardType.PERSON).is_equal(0)
	assert_int(CardEntry.CardType.PLACE).is_equal(1)
	assert_int(CardEntry.CardType.FEELING).is_equal(2)
	assert_int(CardEntry.CardType.OBJECT).is_equal(3)
	assert_int(CardEntry.CardType.MOMENT).is_equal(4)
	assert_int(CardEntry.CardType.INSIDE_JOKE).is_equal(5)
	assert_int(CardEntry.CardType.SEED).is_equal(6)


func test_card_type_enum_contains_all_named_keys() -> void:
	var keys: Array = CardEntry.CardType.keys()
	assert_array(keys).contains([
		"PERSON", "PLACE", "FEELING", "OBJECT", "MOMENT", "INSIDE_JOKE", "SEED"
	])


# ── AC-3: CardEntry.new() returns correct defaults ────────────────────────────

func test_card_entry_default_flavor_text_is_empty_string() -> void:
	var entry := CardEntry.new()
	assert_str(entry.flavor_text).is_equal("")


func test_card_entry_default_tags_is_empty_packed_string_array() -> void:
	var entry := CardEntry.new()
	assert_int(entry.tags.size()).is_equal(0)


func test_card_entry_default_type_is_person() -> void:
	var entry := CardEntry.new()
	assert_int(entry.type).is_equal(CardEntry.CardType.PERSON)


func test_card_entry_default_art_is_null() -> void:
	var entry := CardEntry.new()
	assert_object(entry.art).is_null()


func test_card_entry_default_id_is_empty_string_name() -> void:
	var entry := CardEntry.new()
	assert_that(entry.id == &"").is_true()


func test_card_entry_default_display_name_is_empty_string() -> void:
	var entry := CardEntry.new()
	assert_str(entry.display_name).is_equal("")


func test_card_entry_default_scene_id_is_empty_string_name() -> void:
	var entry := CardEntry.new()
	assert_that(entry.scene_id == &"").is_true()


# ── AC-4: CardManifest wraps Array[CardEntry] ─────────────────────────────────

func test_card_manifest_entries_starts_empty() -> void:
	var manifest := CardManifest.new()
	assert_int(manifest.entries.size()).is_equal(0)


func test_card_manifest_accepts_card_entry_append() -> void:
	var manifest := CardManifest.new()
	var entry := CardEntry.new()
	manifest.entries.append(entry)
	assert_int(manifest.entries.size()).is_equal(1)


func test_card_manifest_entry_is_card_entry_instance() -> void:
	var manifest := CardManifest.new()
	var entry := CardEntry.new()
	manifest.entries.append(entry)
	assert_bool(manifest.entries[0] is CardEntry).is_true()


# ── AC-5: Round-trip via ResourceLoader ──────────────────────────────────────

func test_resource_loader_returns_card_manifest() -> void:
	var manifest: CardManifest = ResourceLoader.load(
			"res://tests/fixtures/card_database/cards_minimal.tres") as CardManifest
	assert_object(manifest).is_not_null()


func test_resource_loader_manifest_has_one_entry() -> void:
	var manifest: CardManifest = ResourceLoader.load(
			"res://tests/fixtures/card_database/cards_minimal.tres") as CardManifest
	assert_int(manifest.entries.size()).is_equal(1)


func test_resource_loader_entry_fields_match_fixture() -> void:
	var manifest: CardManifest = ResourceLoader.load(
			"res://tests/fixtures/card_database/cards_minimal.tres") as CardManifest
	var entry: CardEntry = manifest.entries[0]
	assert_that(entry.id == &"test_seed_001").is_true()
	assert_str(entry.display_name).is_equal("Test Seed Card")
	assert_int(entry.type).is_equal(CardEntry.CardType.SEED)
	assert_that(entry.scene_id == &"global").is_true()
