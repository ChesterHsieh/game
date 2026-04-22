## Integration tests for Story 007 — seed recipes.tres manifest (MVP scene-01 recipe set).
##
## Verifies the production manifest at res://assets/data/recipes.tres:
##   AC-1: manifest loads as a valid RecipeManifest
##   AC-2: at least 12 entries are present (story minimum: 10 + 2 global)
##   AC-3: all 4 template values appear at least once (additive, merge, animate, generator)
##   AC-4: scene-01 entries have scene_id == &"scene-01" and count >= 10
##   AC-5: global recipes have scene_id == &"global" and count >= 2
##   AC-6: every entry has a non-empty id
##   AC-7: every entry id is unique and matches kebab-case
##   AC-8: generator recipes have interval_sec >= 0.5
##   AC-9: no duplicate (scene_id, normalised pair) combinations
##   AC-10: RecipeDatabase loads the production manifest without assertion failures
extends GdUnitTestSuite

const RecipeDatabaseScript := preload("res://src/core/recipe_database.gd")
const PRODUCTION_MANIFEST := "res://assets/data/recipes.tres"

## Reusable helper: load the production manifest as RecipeManifest.
func _load_production_manifest() -> RecipeManifest:
	return ResourceLoader.load(PRODUCTION_MANIFEST) as RecipeManifest


# ── AC-1: manifest loads as RecipeManifest ────────────────────────────────────

func test_production_manifest_loads_as_recipe_manifest() -> void:
	# Arrange / Act
	var manifest: RecipeManifest = _load_production_manifest()

	# Assert
	assert_object(manifest).is_not_null()


# ── AC-2: entry count ─────────────────────────────────────────────────────────

func test_production_manifest_has_at_least_twelve_entries() -> void:
	# Arrange
	var manifest: RecipeManifest = _load_production_manifest()

	# Assert — story spec: >= 10 scene-01 + >= 2 global
	assert_int(manifest.entries.size()).is_greater_equal(12)


# ── AC-3: all 4 template values present ──────────────────────────────────────

func test_production_manifest_contains_at_least_one_additive_recipe() -> void:
	# Arrange
	var manifest: RecipeManifest = _load_production_manifest()
	var found := false
	for e: RecipeEntry in manifest.entries:
		if e.template == &"additive":
			found = true
			break

	# Assert
	assert_bool(found).is_true()


func test_production_manifest_contains_at_least_one_merge_recipe() -> void:
	var manifest: RecipeManifest = _load_production_manifest()
	var found := false
	for e: RecipeEntry in manifest.entries:
		if e.template == &"merge":
			found = true
			break
	assert_bool(found).is_true()


func test_production_manifest_contains_at_least_one_animate_recipe() -> void:
	var manifest: RecipeManifest = _load_production_manifest()
	var found := false
	for e: RecipeEntry in manifest.entries:
		if e.template == &"animate":
			found = true
			break
	assert_bool(found).is_true()


func test_production_manifest_contains_at_least_one_generator_recipe() -> void:
	var manifest: RecipeManifest = _load_production_manifest()
	var found := false
	for e: RecipeEntry in manifest.entries:
		if e.template == &"generator":
			found = true
			break
	assert_bool(found).is_true()


# ── AC-4: scene-01 entries ────────────────────────────────────────────────────

func test_production_manifest_has_at_least_ten_scene_01_entries() -> void:
	# Arrange
	var manifest: RecipeManifest = _load_production_manifest()
	var count := 0
	for e: RecipeEntry in manifest.entries:
		if e.scene_id == &"scene-01":
			count += 1

	# Assert — story spec requires >= 10 recipes for scene-01
	assert_int(count).is_greater_equal(10)


# ── AC-5: global recipes ──────────────────────────────────────────────────────

func test_production_manifest_has_at_least_two_global_recipes() -> void:
	# Arrange
	var manifest: RecipeManifest = _load_production_manifest()
	var count := 0
	for e: RecipeEntry in manifest.entries:
		if e.scene_id == &"global":
			count += 1

	# Assert — story spec: at least 2 global recipes
	assert_int(count).is_greater_equal(2)


# ── AC-6: non-empty id on every entry ────────────────────────────────────────

func test_production_manifest_all_entries_have_non_empty_id() -> void:
	# Arrange
	var manifest: RecipeManifest = _load_production_manifest()

	# Assert
	for e: RecipeEntry in manifest.entries:
		assert_str(String(e.id)).is_not_empty()


# ── AC-7: unique ids and kebab-case format ────────────────────────────────────

func test_production_manifest_all_ids_are_unique() -> void:
	# Arrange
	var manifest: RecipeManifest = _load_production_manifest()
	var seen: Dictionary = {}

	# Assert — duplicate detection mirrors RecipeDatabase._validate_no_duplicates()
	for e: RecipeEntry in manifest.entries:
		assert_bool(seen.has(e.id)).is_false()
		seen[e.id] = true


func test_production_manifest_all_ids_match_kebab_case_pattern() -> void:
	# Arrange
	var manifest: RecipeManifest = _load_production_manifest()
	var kebab_regex := RegEx.new()
	kebab_regex.compile("^[a-z0-9]+(-[a-z0-9]+)*$")

	# Assert — SC-6: ids match /^[a-z0-9]+(-[a-z0-9]+)*$/
	for e: RecipeEntry in manifest.entries:
		var result: RegExMatch = kebab_regex.search(String(e.id))
		assert_object(result).is_not_null()


# ── AC-8: generator interval_sec >= 0.5 ──────────────────────────────────────

func test_production_manifest_all_generator_intervals_are_at_least_half_second() -> void:
	# Arrange
	var manifest: RecipeManifest = _load_production_manifest()

	# Assert — SC-5: no clamp warnings should fire for any generator
	for e: RecipeEntry in manifest.entries:
		if e.template != &"generator":
			continue
		var interval: float = e.config.get("interval_sec", 0.5)
		assert_float(interval).is_greater_equal(0.5)


# ── AC-9: no duplicate (scene_id, normalised pair) combinations ───────────────

func test_production_manifest_has_no_duplicate_scene_pair_combinations() -> void:
	# Arrange
	var manifest: RecipeManifest = _load_production_manifest()
	var seen: Dictionary = {}

	# Assert — mirrors RecipeDatabase._validate_no_duplicates() key format
	for e: RecipeEntry in manifest.entries:
		var sa: String = String(e.card_a)
		var sb: String = String(e.card_b)
		var lo: String = sa if sa <= sb else sb
		var hi: String = sb if sa <= sb else sa
		var key: String = "%s|%s|%s" % [String(e.scene_id), lo, hi]
		assert_bool(seen.has(key)).is_false()
		seen[key] = e.id


# ── AC-10: RecipeDatabase loads production manifest without assertion failures ─
#
# Verifies that all 4 validation passes (card refs, duplicates, generator
# intervals, index build) complete without halting. Tests scene-01 and global
# are in KNOWN_SCENE_IDS, so no orphaned-scene_id warnings fire.

func test_recipe_database_known_scene_ids_includes_scene_01() -> void:
	# Assert — scene-01 must be a known scene_id or RecipeDatabase would warn
	assert_bool(CardDatabase.KNOWN_SCENE_IDS.has("scene-01")).is_true()


func test_recipe_database_known_scene_ids_includes_global() -> void:
	assert_bool(CardDatabase.KNOWN_SCENE_IDS.has("global")).is_true()


func test_recipe_database_loads_production_manifest_via_load_manifest() -> void:
	# Arrange
	var db: Node = RecipeDatabaseScript.new()

	# Act — this will assert-fail if any card ref is unknown, if duplicates exist,
	# or if the manifest is not a RecipeManifest. All 4 validation passes run.
	db._load_manifest(PRODUCTION_MANIFEST)

	# Assert
	assert_int(db._entries.size()).is_greater_equal(12)
	db.free()


func test_recipe_database_load_manifest_builds_non_empty_index() -> void:
	# Arrange
	var db: Node = RecipeDatabaseScript.new()
	db._load_manifest(PRODUCTION_MANIFEST)

	# Assert — index is populated for at least one pair
	assert_int(db._index.size()).is_greater_equal(1)
	db.free()


func test_recipe_database_lookup_returns_recipe_for_known_scene_01_pair() -> void:
	# Arrange
	var db: Node = RecipeDatabaseScript.new()
	db._load_manifest(PRODUCTION_MANIFEST)

	# Act — chester + rainy-afternoon is a known scene-01 merge recipe
	var result: RecipeEntry = db.lookup(&"chester", &"rainy-afternoon", &"scene-01")

	# Assert
	assert_object(result).is_not_null()
	assert_that(result.template == &"merge").is_true()
	db.free()


func test_recipe_database_lookup_returns_global_recipe_when_no_scene_match() -> void:
	# Arrange
	var db: Node = RecipeDatabaseScript.new()
	db._load_manifest(PRODUCTION_MANIFEST)

	# Act — seed-start + seed-together is global only; lookup with any scene falls through
	var result: RecipeEntry = db.lookup(&"seed-start", &"seed-together", &"scene-01")

	# Assert — global fallback should resolve
	assert_object(result).is_not_null()
	assert_that(result.scene_id == &"global").is_true()
	db.free()


func test_recipe_database_lookup_returns_null_for_unknown_pair() -> void:
	# Arrange
	var db: Node = RecipeDatabaseScript.new()
	db._load_manifest(PRODUCTION_MANIFEST)

	# Act — no recipe exists for chester + ju in any scene
	var result: RecipeEntry = db.lookup(&"chester", &"ju", &"scene-01")

	# Assert
	assert_object(result).is_null()
	db.free()
