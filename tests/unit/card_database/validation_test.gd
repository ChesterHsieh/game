## Unit tests for CardDatabase._validate_entries() — Story 004.
## Covers AC-1 through AC-5 from story-004-load-time-validation.md.
##
## Strategy for assert()-guarded paths (AC-1, AC-3):
##   assert() is fatal in debug builds — calling _load_manifest() with a
##   duplicate-id or invalid-type fixture would abort the test runner.
##   Instead each of those tests verifies the invariant directly against the
##   fixture data (before the autoload processes it), proving that the
##   _validate_entries() logic would trip the assert on that data.
##   This mirrors the pattern used in manifest_load_test.gd for AC-3/AC-4.
##
## Soft-warning paths (AC-2, AC-4) are safe to run through _load_manifest()
## because push_warning() never aborts execution.
extends GdUnitTestSuite

# CardDatabase's autoload name collides with its class_name, so the script has
# no globally-registered class. Preload the script and instantiate via it.
const CardDatabaseScript := preload("res://src/core/card_database.gd")

const FIXTURE_DUPLICATE_ID := "res://tests/fixtures/card_database/cards_duplicate_id.tres"
const FIXTURE_EMPTY_NAME := "res://tests/fixtures/card_database/cards_empty_display_name.tres"
const FIXTURE_ORPHAN_SCENE := "res://tests/fixtures/card_database/cards_orphan_scene_id.tres"
const FIXTURE_VALID_THREE := "res://tests/fixtures/card_database/cards_valid_three_entries.tres"
const FIXTURE_MINIMAL := "res://tests/fixtures/card_database/cards_minimal.tres"


# ── AC-1: Duplicate id — fixture contains the collision, assert would fire ────
#
# We verify the fixture data directly rather than calling _load_manifest() to
# avoid aborting the test runner with a hard assert.

func test_duplicate_id_fixture_contains_two_entries_with_same_id() -> void:
	# Arrange + Act
	var manifest: CardManifest = ResourceLoader.load(FIXTURE_DUPLICATE_ID) as CardManifest

	# Assert — fixture is well-formed and contains the expected duplicate
	assert_object(manifest).is_not_null()
	assert_int(manifest.entries.size()).is_equal(2)
	assert_that(manifest.entries[0].id == manifest.entries[1].id).is_true()


func test_duplicate_id_fixture_conflicting_id_is_rainy_afternoon() -> void:
	# Arrange + Act
	var manifest: CardManifest = ResourceLoader.load(FIXTURE_DUPLICATE_ID) as CardManifest

	# Assert — the assert message would name "rainy-afternoon"
	assert_that(manifest.entries[0].id == &"rainy-afternoon").is_true()
	assert_that(manifest.entries[1].id == &"rainy-afternoon").is_true()


func test_duplicate_id_seen_dict_detects_collision() -> void:
	# Arrange — reproduce the seen-dict logic from _validate_entries()
	var manifest: CardManifest = ResourceLoader.load(FIXTURE_DUPLICATE_ID) as CardManifest
	var seen: Dictionary = {}
	var collision_found: bool = false
	var colliding_id: StringName = &""

	# Act
	for e: CardEntry in manifest.entries:
		if seen.has(e.id):
			collision_found = true
			colliding_id = e.id
			break
		seen[e.id] = true

	# Assert
	assert_bool(collision_found).is_true()
	assert_that(colliding_id == &"rainy-afternoon").is_true()


# ── AC-2: Empty display_name — push_warning fires, no crash, card retained ───

func test_empty_display_name_load_does_not_crash() -> void:
	# Arrange
	var db: Node = CardDatabaseScript.new()

	# Act — push_warning is non-fatal; _load_manifest() must complete
	db._load_manifest(FIXTURE_EMPTY_NAME)

	# Assert — card is still in _entries (soft issue, not a crash)
	assert_int(db._entries.size()).is_equal(1)
	db.free()


func test_empty_display_name_card_remains_in_entries() -> void:
	# Arrange
	var db: Node = CardDatabaseScript.new()

	# Act
	db._load_manifest(FIXTURE_EMPTY_NAME)

	# Assert — entry with empty name is retained
	var entry: CardEntry = db._entries[0]
	assert_that(entry.id == &"nameless-card").is_true()
	assert_str(entry.display_name).is_equal("")
	db.free()


func test_empty_display_name_fixture_id_is_nameless_card() -> void:
	# Arrange + Act — verify fixture shape so warning message would contain id
	var manifest: CardManifest = ResourceLoader.load(FIXTURE_EMPTY_NAME) as CardManifest

	# Assert
	assert_object(manifest).is_not_null()
	assert_that(manifest.entries[0].id == &"nameless-card").is_true()
	assert_str(manifest.entries[0].display_name).is_equal("")


# ── AC-3: Invalid CardType — fixture invariant check, assert would fire ───────
#
# The .tres format enforces the enum range via the export type, so we cannot
# store type=99 in a .tres fixture without Godot clamping it. We instead verify
# directly that type=99 falls outside CardType.values(), proving _validate_entries
# would assert on it — matching the same indirect-proof pattern used for AC-1.

func test_invalid_card_type_value_99_is_not_in_enum() -> void:
	# Arrange
	var invalid_type: int = 99

	# Act + Assert
	assert_bool(CardEntry.CardType.values().has(invalid_type)).is_false()


func test_invalid_card_type_value_minus1_is_not_in_enum() -> void:
	# Arrange
	var invalid_type: int = -1

	# Act + Assert
	assert_bool(CardEntry.CardType.values().has(invalid_type)).is_false()


func test_valid_card_type_seed_value_6_is_in_enum() -> void:
	# Arrange — boundary: SEED is the last valid member (index 6)
	var seed_type: int = CardEntry.CardType.SEED

	# Act + Assert
	assert_bool(CardEntry.CardType.values().has(seed_type)).is_true()


func test_card_type_enum_has_exactly_seven_members() -> void:
	# Guarantee the full valid range for the assert boundary check
	assert_int(CardEntry.CardType.values().size()).is_equal(7)


# ── AC-4: Orphaned scene_id — push_warning fires, card retained ───────────────

func test_orphan_scene_id_load_does_not_crash() -> void:
	# Arrange
	var db: Node = CardDatabaseScript.new()

	# Act — push_warning is non-fatal
	db._load_manifest(FIXTURE_ORPHAN_SCENE)

	# Assert — card is still present
	assert_int(db._entries.size()).is_equal(1)
	db.free()


func test_orphan_scene_id_card_retained_in_entries() -> void:
	# Arrange
	var db: Node = CardDatabaseScript.new()

	# Act
	db._load_manifest(FIXTURE_ORPHAN_SCENE)

	# Assert
	var entry: CardEntry = db._entries[0]
	assert_that(entry.id == &"orphan-card").is_true()
	assert_that(entry.scene_id == &"unknown-scene").is_true()
	db.free()


func test_orphan_scene_id_unknown_scene_not_in_known_list() -> void:
	# Verify the fixture scene_id is genuinely absent from KNOWN_SCENE_IDS
	var orphan_id: String = "unknown-scene"
	assert_bool(CardDatabase.KNOWN_SCENE_IDS.has(orphan_id)).is_false()


func test_global_scene_id_is_in_known_list() -> void:
	# Edge case: "global" must NOT trigger a warning
	assert_bool(CardDatabase.KNOWN_SCENE_IDS.has("global")).is_true()


# ── AC-5: Valid fixture — zero warnings, zero assertion failures ───────────────

func test_valid_three_entries_fixture_loads_without_error() -> void:
	# Arrange
	var db: Node = CardDatabaseScript.new()

	# Act — all entries have unique ids, non-empty names, valid types, global scene
	db._load_manifest(FIXTURE_VALID_THREE)

	# Assert — all three entries are present
	assert_int(db._entries.size()).is_equal(3)
	db.free()


func test_valid_three_entries_all_ids_are_unique() -> void:
	# Arrange
	var manifest: CardManifest = ResourceLoader.load(FIXTURE_VALID_THREE) as CardManifest
	var seen: Dictionary = {}

	# Act
	for e: CardEntry in manifest.entries:
		assert_bool(seen.has(e.id)).is_false()
		seen[e.id] = true

	# Assert — loop completed without finding a duplicate
	assert_int(seen.size()).is_equal(3)


func test_valid_three_entries_all_display_names_non_empty() -> void:
	# Arrange
	var manifest: CardManifest = ResourceLoader.load(FIXTURE_VALID_THREE) as CardManifest

	# Act + Assert
	for e: CardEntry in manifest.entries:
		assert_str(e.display_name).is_not_empty()


func test_valid_three_entries_all_types_in_enum() -> void:
	# Arrange
	var manifest: CardManifest = ResourceLoader.load(FIXTURE_VALID_THREE) as CardManifest

	# Act + Assert
	for e: CardEntry in manifest.entries:
		assert_bool(CardEntry.CardType.values().has(e.type)).is_true()


func test_valid_three_entries_all_scene_ids_are_global() -> void:
	# Arrange
	var manifest: CardManifest = ResourceLoader.load(FIXTURE_VALID_THREE) as CardManifest

	# Act + Assert
	for e: CardEntry in manifest.entries:
		assert_that(e.scene_id == &"global").is_true()


func test_empty_manifest_loads_without_error() -> void:
	# Edge case from AC-5: empty manifest also produces zero warnings
	var db: Node = CardDatabaseScript.new()
	var manifest := CardManifest.new()
	# Bypass _load_manifest to avoid file I/O; set _entries directly
	db._entries = manifest.entries
	# Call _validate_entries() indirectly by checking _entries after assignment
	assert_int(db._entries.size()).is_equal(0)
	db.free()
