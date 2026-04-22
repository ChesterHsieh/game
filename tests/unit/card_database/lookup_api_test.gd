## Unit tests for CardDatabase Lookup API — Story 005.
## Covers AC-1 through AC-4 from story-005-lookup-api.md.
##
## Fixture strategy:
##   - cards_rainy_afternoon.tres   — single MOMENT card; used for AC-1, AC-4
##   - cards_valid_three_entries.tres — three entries (alpha/beta/gamma); used for AC-3
##   - cards_minimal.tres           — one entry that is NOT rainy-afternoon; used for AC-2
##
## Note on AC-2 (push_error):
##   gdUnit4 does not intercept push_error() at runtime. The test verifies null
##   is returned and the game does not crash; the error message is visually
##   confirmed in the test runner's output log, which meets the story's
##   "does not crash" contract.
extends GdUnitTestSuite

# CardDatabase has no class_name (autoload name conflict), so preload + new().
const CardDatabaseScript := preload("res://src/core/card_database.gd")

const FIXTURE_RAINY_AFTERNOON := "res://tests/fixtures/card_database/cards_rainy_afternoon.tres"
const FIXTURE_VALID_THREE     := "res://tests/fixtures/card_database/cards_valid_three_entries.tres"
const FIXTURE_MINIMAL         := "res://tests/fixtures/card_database/cards_minimal.tres"


# ── AC-1: get_card returns full CardEntry for valid id ────────────────────────

func test_get_card_valid_id_returns_non_null_entry() -> void:
	# Arrange
	var db: Node = CardDatabaseScript.new()
	db._load_manifest(FIXTURE_RAINY_AFTERNOON)

	# Act
	var entry: CardEntry = db.get_card(&"rainy-afternoon")

	# Assert
	assert_object(entry).is_not_null()
	db.free()


func test_get_card_valid_id_returns_correct_id_field() -> void:
	# Arrange
	var db: Node = CardDatabaseScript.new()
	db._load_manifest(FIXTURE_RAINY_AFTERNOON)

	# Act
	var entry: CardEntry = db.get_card(&"rainy-afternoon")

	# Assert
	assert_that(entry.id == &"rainy-afternoon").is_true()
	db.free()


func test_get_card_valid_id_returns_correct_display_name() -> void:
	# Arrange
	var db: Node = CardDatabaseScript.new()
	db._load_manifest(FIXTURE_RAINY_AFTERNOON)

	# Act
	var entry: CardEntry = db.get_card(&"rainy-afternoon")

	# Assert
	assert_str(entry.display_name).is_equal("Rainy afternoon")
	db.free()


func test_get_card_valid_id_returns_correct_type_moment() -> void:
	# Arrange
	var db: Node = CardDatabaseScript.new()
	db._load_manifest(FIXTURE_RAINY_AFTERNOON)

	# Act
	var entry: CardEntry = db.get_card(&"rainy-afternoon")

	# Assert — CardType.MOMENT == 4
	assert_int(entry.type).is_equal(CardEntry.CardType.MOMENT)
	db.free()


func test_get_card_valid_id_returns_correct_scene_id_global() -> void:
	# Arrange
	var db: Node = CardDatabaseScript.new()
	db._load_manifest(FIXTURE_RAINY_AFTERNOON)

	# Act
	var entry: CardEntry = db.get_card(&"rainy-afternoon")

	# Assert
	assert_that(entry.scene_id == &"global").is_true()
	db.free()


func test_get_card_string_arg_coerces_to_stringname() -> void:
	# Edge case: passing a String (not StringName) still finds the entry
	# via GDScript's implicit String→StringName coercion.
	# Arrange
	var db: Node = CardDatabaseScript.new()
	db._load_manifest(FIXTURE_RAINY_AFTERNOON)

	# Act — intentionally passing a plain String
	var entry: CardEntry = db.get_card("rainy-afternoon")

	# Assert
	assert_object(entry).is_not_null()
	db.free()


# ── AC-2: get_card returns null on miss; push_error fires; no crash ───────────

func test_get_card_unknown_id_returns_null() -> void:
	# Arrange
	var db: Node = CardDatabaseScript.new()
	db._load_manifest(FIXTURE_MINIMAL)  # does NOT contain "nonexistent-card"

	# Act
	var entry: CardEntry = db.get_card(&"nonexistent-card")

	# Assert — null is returned; push_error fires (visible in runner log)
	assert_object(entry).is_null()
	db.free()


func test_get_card_empty_stringname_returns_null() -> void:
	# Edge case: &"" is not a valid id
	# Arrange
	var db: Node = CardDatabaseScript.new()
	db._load_manifest(FIXTURE_MINIMAL)

	# Act
	var entry: CardEntry = db.get_card(&"")

	# Assert
	assert_object(entry).is_null()
	db.free()


func test_get_card_case_mismatch_returns_null() -> void:
	# Edge case: lookup is case-sensitive — "Rainy-Afternoon" != "rainy-afternoon"
	# Arrange
	var db: Node = CardDatabaseScript.new()
	db._load_manifest(FIXTURE_RAINY_AFTERNOON)

	# Act
	var entry: CardEntry = db.get_card(&"Rainy-Afternoon")

	# Assert — wrong case, must return null
	assert_object(entry).is_null()
	db.free()


# ── AC-3: get_all returns full populated array ────────────────────────────────

func test_get_all_returns_array_of_correct_length() -> void:
	# Arrange
	var db: Node = CardDatabaseScript.new()
	db._load_manifest(FIXTURE_VALID_THREE)

	# Act
	var all: Array[CardEntry] = db.get_all()

	# Assert
	assert_int(all.size()).is_equal(3)
	db.free()


func test_get_all_first_entry_is_card_alpha() -> void:
	# Arrange
	var db: Node = CardDatabaseScript.new()
	db._load_manifest(FIXTURE_VALID_THREE)

	# Act
	var all: Array[CardEntry] = db.get_all()

	# Assert — declaration order must be preserved
	assert_that(all[0].id == &"card-alpha").is_true()
	db.free()


func test_get_all_last_entry_is_card_gamma() -> void:
	# Arrange
	var db: Node = CardDatabaseScript.new()
	db._load_manifest(FIXTURE_VALID_THREE)

	# Act
	var all: Array[CardEntry] = db.get_all()

	# Assert
	assert_that(all[2].id == &"card-gamma").is_true()
	db.free()


func test_get_all_empty_manifest_returns_empty_array_not_null() -> void:
	# Edge case from AC-3: empty manifest → empty array, not null
	# Arrange
	var db: Node = CardDatabaseScript.new()
	# Bypass file I/O — set _entries directly (same pattern as validation_test.gd)
	var empty: Array[CardEntry] = []
	db._entries = empty
	db._build_index()

	# Act
	var all: Array[CardEntry] = db.get_all()

	# Assert
	assert_object(all).is_not_null()
	assert_int(all.size()).is_equal(0)
	db.free()


# ── AC-4: identity — repeated calls return the same instance ─────────────────

func test_get_card_repeated_calls_return_same_instance() -> void:
	# Arrange
	var db: Node = CardDatabaseScript.new()
	db._load_manifest(FIXTURE_RAINY_AFTERNOON)

	# Act
	var a: CardEntry = db.get_card(&"rainy-afternoon")
	var b: CardEntry = db.get_card(&"rainy-afternoon")

	# Assert — same in-memory instance (identity)
	assert_that(a == b).is_true()
	assert_that(a.get_instance_id() == b.get_instance_id()).is_true()
	db.free()


func test_get_card_and_get_all_return_same_instance() -> void:
	# Edge case: get_all()[0] and get_card(get_all()[0].id) are identical
	# Arrange
	var db: Node = CardDatabaseScript.new()
	db._load_manifest(FIXTURE_RAINY_AFTERNOON)

	# Act
	var from_all: CardEntry = db.get_all()[0]
	var from_get: CardEntry = db.get_card(db.get_all()[0].id)

	# Assert
	assert_that(from_all.get_instance_id() == from_get.get_instance_id()).is_true()
	db.free()
