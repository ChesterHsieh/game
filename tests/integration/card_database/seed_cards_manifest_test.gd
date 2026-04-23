## Integration tests for Story 007 — seed cards.tres manifest (MVP scene-01 card set).
##
## Verifies the production manifest at res://assets/data/cards.tres:
##   AC-1: manifest loads as a valid CardManifest
##   AC-2: all 20 entries are present
##   AC-3: all 7 CardType values appear at least once
##   AC-4: scene-01 entries have scene_id == &"scene-01"
##   AC-5: global seed cards have scene_id == &"global"
##   AC-6: every entry has a non-empty display_name
##   AC-7: every entry has a unique id
##   AC-8: every entry has a non-null art reference
##   AC-9: every entry has a valid CardType enum value
##   AC-10: CardDatabase loads the production manifest without warnings
##          (scene-01 is a known scene_id — no orphaned-scene_id push_warning)
extends GdUnitTestSuite

const CardDatabaseScript := preload("res://src/core/card_database.gd")
const PRODUCTION_MANIFEST := "res://assets/data/cards.tres"

## Reusable helper: load the production manifest as CardManifest.
func _load_production_manifest() -> CardManifest:
	return ResourceLoader.load(PRODUCTION_MANIFEST) as CardManifest


# ── AC-1: manifest loads as CardManifest ─────────────────────────────────────

func test_production_manifest_loads_as_card_manifest() -> void:
	# Arrange / Act
	var manifest: CardManifest = _load_production_manifest()

	# Assert
	assert_object(manifest).is_not_null()


# ── AC-2: entry count ─────────────────────────────────────────────────────────

func test_production_manifest_has_twenty_entries() -> void:
	# Arrange
	var manifest: CardManifest = _load_production_manifest()

	# Assert
	assert_int(manifest.entries.size()).is_equal(20)


# ── AC-3: all 7 CardType values appear ───────────────────────────────────────

func test_production_manifest_contains_at_least_one_person_card() -> void:
	# Arrange
	var manifest: CardManifest = _load_production_manifest()
	var found := false
	for e: CardEntry in manifest.entries:
		if e.type == CardEntry.CardType.PERSON:
			found = true
			break

	# Assert
	assert_bool(found).is_true()


func test_production_manifest_contains_at_least_one_place_card() -> void:
	var manifest: CardManifest = _load_production_manifest()
	var found := false
	for e: CardEntry in manifest.entries:
		if e.type == CardEntry.CardType.PLACE:
			found = true
			break
	assert_bool(found).is_true()


func test_production_manifest_contains_at_least_one_feeling_card() -> void:
	var manifest: CardManifest = _load_production_manifest()
	var found := false
	for e: CardEntry in manifest.entries:
		if e.type == CardEntry.CardType.FEELING:
			found = true
			break
	assert_bool(found).is_true()


func test_production_manifest_contains_at_least_one_object_card() -> void:
	var manifest: CardManifest = _load_production_manifest()
	var found := false
	for e: CardEntry in manifest.entries:
		if e.type == CardEntry.CardType.OBJECT:
			found = true
			break
	assert_bool(found).is_true()


func test_production_manifest_contains_at_least_one_moment_card() -> void:
	var manifest: CardManifest = _load_production_manifest()
	var found := false
	for e: CardEntry in manifest.entries:
		if e.type == CardEntry.CardType.MOMENT:
			found = true
			break
	assert_bool(found).is_true()


func test_production_manifest_contains_at_least_one_inside_joke_card() -> void:
	var manifest: CardManifest = _load_production_manifest()
	var found := false
	for e: CardEntry in manifest.entries:
		if e.type == CardEntry.CardType.INSIDE_JOKE:
			found = true
			break
	assert_bool(found).is_true()


func test_production_manifest_contains_at_least_one_seed_card() -> void:
	var manifest: CardManifest = _load_production_manifest()
	var found := false
	for e: CardEntry in manifest.entries:
		if e.type == CardEntry.CardType.SEED:
			found = true
			break
	assert_bool(found).is_true()


# ── AC-4: scene-01 entries ────────────────────────────────────────────────────

func test_production_manifest_has_scene_01_entries() -> void:
	# Arrange
	var manifest: CardManifest = _load_production_manifest()
	var count := 0
	for e: CardEntry in manifest.entries:
		if e.scene_id == &"scene-01":
			count += 1

	# Assert — story spec requires ~20-30 entries per scene
	assert_int(count).is_greater_equal(15)


# ── AC-5: global seed cards ───────────────────────────────────────────────────

func test_production_manifest_seed_cards_have_global_scene_id() -> void:
	# Arrange
	var manifest: CardManifest = _load_production_manifest()

	# Act / Assert — every SEED card must use "global" scene_id
	for e: CardEntry in manifest.entries:
		if e.type == CardEntry.CardType.SEED:
			assert_that(e.scene_id == &"global").is_true()


# ── AC-6: non-empty display_name on every entry ───────────────────────────────

func test_production_manifest_all_entries_have_non_empty_display_name() -> void:
	# Arrange
	var manifest: CardManifest = _load_production_manifest()

	# Assert
	for e: CardEntry in manifest.entries:
		assert_str(e.display_name).is_not_empty()


# ── AC-7: unique ids ──────────────────────────────────────────────────────────

func test_production_manifest_all_ids_are_unique() -> void:
	# Arrange
	var manifest: CardManifest = _load_production_manifest()
	var seen: Dictionary = {}

	# Assert — duplicate detection mirrors CardDatabase._validate_entries()
	for e: CardEntry in manifest.entries:
		assert_bool(seen.has(e.id)).is_false()
		seen[e.id] = true


# ── AC-8: non-null art on every entry ────────────────────────────────────────

func test_production_manifest_all_entries_have_non_null_art() -> void:
	# Arrange
	var manifest: CardManifest = _load_production_manifest()

	# Assert
	for e: CardEntry in manifest.entries:
		assert_object(e.art).is_not_null()


# ── AC-9: valid CardType enum value on every entry ────────────────────────────

func test_production_manifest_all_entries_have_valid_card_type() -> void:
	# Arrange
	var manifest: CardManifest = _load_production_manifest()
	var valid_values: Array = CardEntry.CardType.values()

	# Assert
	for e: CardEntry in manifest.entries:
		assert_bool(valid_values.has(e.type)).is_true()


# ── AC-10: CardDatabase validation passes without orphaned-scene_id warnings ──
#
# Verifies that scene-01 is a known scene_id in KNOWN_SCENE_IDS so no
# push_warning fires for any scene-01 card. We test this indirectly by
# confirming scene-01 appears in the KNOWN_SCENE_IDS array.

func test_card_database_known_scene_ids_includes_scene_01() -> void:
	# Assert — KNOWN_SCENE_IDS is a var (not const) per GDScript 4.3 constraint
	assert_bool(CardDatabase.KNOWN_SCENE_IDS.has("scene-01")).is_true()


func test_card_database_loads_production_manifest_via_load_manifest() -> void:
	# Arrange
	var db: Node = auto_free(CardDatabaseScript.new())

	# Act — this will assert-fail if the manifest is invalid
	db._load_manifest(PRODUCTION_MANIFEST)

	# Assert
	assert_int(db._entries.size()).is_equal(20)
	db.free()
