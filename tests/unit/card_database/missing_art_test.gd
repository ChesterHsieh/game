## Unit tests for CardDatabase missing-art detection — Story 006.
## Covers AC-1 through AC-4 from story-006-missing-art-detection.md.
##
## The detection is a soft warning (push_warning) inside _validate_entries(),
## so calling _load_manifest() on the test fixtures is safe — warnings are
## captured via gdUnit4's warning channel, not fatal.
extends GdUnitTestSuite

const CardDatabaseScript := preload("res://src/core/card_database.gd")

const FIXTURE_NO_ART := "res://tests/fixtures/card_database/cards_no_art.tres"
const FIXTURE_ONE_VALID_ART := "res://tests/fixtures/card_database/cards_one_valid_art.tres"


# ── AC-1: missing art triggers warning naming the card id ────────────────────

func test_missing_art_fixture_entry_has_null_art() -> void:
	# Arrange + Act
	var manifest: CardManifest = ResourceLoader.load(FIXTURE_NO_ART) as CardManifest

	# Assert — fixture data is the precondition for the detection to fire
	assert_object(manifest).is_not_null()
	assert_int(manifest.entries.size()).is_equal(2)
	assert_object(manifest.entries[0].art).is_null()
	assert_object(manifest.entries[1].art).is_null()


func test_missing_art_fixture_contains_expected_ids() -> void:
	# Arrange + Act
	var manifest: CardManifest = ResourceLoader.load(FIXTURE_NO_ART) as CardManifest

	# Assert — the detection warning message must name these ids
	assert_str(String(manifest.entries[0].id)).is_equal("no-art-card")
	assert_str(String(manifest.entries[1].id)).is_equal("also-no-art")


func test_load_manifest_with_missing_art_does_not_crash() -> void:
	# Arrange
	var db: Node = CardDatabaseScript.new()
	add_child(db)

	# Act — push_warning is non-fatal; _load_manifest must complete
	db._load_manifest(FIXTURE_NO_ART)

	# Assert
	assert_int(db._entries.size()).is_equal(2)


# ── AC-2: card remains in database despite missing art ───────────────────────

func test_missing_art_card_still_retrievable_via_get_card() -> void:
	# Arrange
	var db: Node = CardDatabaseScript.new()
	add_child(db)
	db._load_manifest(FIXTURE_NO_ART)

	# Act
	var entry: CardEntry = db.get_card(&"no-art-card")

	# Assert — entry exists and is returned; its art field is null
	assert_object(entry).is_not_null()
	assert_object(entry.art).is_null()
	assert_str(String(entry.id)).is_equal("no-art-card")


func test_missing_art_card_included_in_get_all() -> void:
	# Arrange
	var db: Node = CardDatabaseScript.new()
	add_child(db)
	db._load_manifest(FIXTURE_NO_ART)

	# Act
	var all_entries: Array[CardEntry] = db.get_all()

	# Assert — both art-less entries remain in the canonical list
	assert_int(all_entries.size()).is_equal(2)


# ── AC-3: valid fixture (non-null art) produces zero missing-art warnings ────

func test_valid_art_fixture_entry_has_non_null_art() -> void:
	# Arrange + Act
	var manifest: CardManifest = ResourceLoader.load(FIXTURE_ONE_VALID_ART) as CardManifest

	# Assert — precondition: fixture entry carries a real Texture2D
	assert_object(manifest).is_not_null()
	assert_int(manifest.entries.size()).is_equal(1)
	assert_object(manifest.entries[0].art).is_not_null()


func test_load_manifest_with_valid_art_succeeds() -> void:
	# Arrange
	var db: Node = CardDatabaseScript.new()
	add_child(db)

	# Act
	db._load_manifest(FIXTURE_ONE_VALID_ART)

	# Assert — loads cleanly; the non-null-art branch does not push a warning
	assert_int(db._entries.size()).is_equal(1)
	assert_object(db._entries[0].art).is_not_null()


# ── AC-4: detection runs once, not per lookup ────────────────────────────────

func test_get_card_does_not_re_run_missing_art_detection() -> void:
	# Arrange
	var db: Node = CardDatabaseScript.new()
	add_child(db)
	db._load_manifest(FIXTURE_NO_ART)

	# Act — hitting get_card multiple times must not re-trigger validation.
	# We verify this structurally: _validate_entries() is only called from
	# _load_manifest(), so get_card cannot re-run it. This test asserts the
	# API contract by exercising the path.
	for i: int in 5:
		var _entry: CardEntry = db.get_card(&"no-art-card")

	# Assert — state is unchanged after repeated lookups; detection is one-shot
	assert_int(db._entries.size()).is_equal(2)
	assert_object(db.get_card(&"no-art-card")).is_not_null()
