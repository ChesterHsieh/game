## Unit tests for RecipeDatabase validation — Stories 003 (cross-validation),
## 004 (duplicate detection), 005 (generator interval clamp).
##
## Hard-assert paths (Stories 003 + 004) are verified by direct fixture-data
## assertions rather than calling _load_manifest() — assert() is fatal in debug
## builds and would abort the test runner. This mirrors the pattern used in
## tests/unit/card_database/validation_test.gd.
##
## Soft-warning paths (Story 005 clamp) execute via _load_manifest() since
## push_warning() does not halt execution.
extends GdUnitTestSuite

const RecipeDatabaseScript := preload("res://src/core/recipe_database.gd")

const FIXTURE_ALL_VALID := "res://tests/fixtures/recipe_database/recipes_all_templates_valid.tres"
const FIXTURE_BAD_CARD_A := "res://tests/fixtures/recipe_database/recipes_cross_val_unknown_card_a.tres"
const FIXTURE_DUPLICATE := "res://tests/fixtures/recipe_database/recipes_duplicate_pair.tres"
const FIXTURE_LOW_INTERVAL := "res://tests/fixtures/recipe_database/recipes_low_interval.tres"


# ── Story 003 AC-1 : unknown card_a — verified at fixture-data level ─────────

func test_unknown_card_a_fixture_contains_nonexistent_card_reference() -> void:
	# Arrange + Act
	var manifest: RecipeManifest = ResourceLoader.load(FIXTURE_BAD_CARD_A) as RecipeManifest

	# Assert — fixture carries the invalid reference that the assert would catch
	assert_object(manifest).is_not_null()
	assert_int(manifest.entries.size()).is_equal(1)
	assert_str(String(manifest.entries[0].card_a)).is_equal("nonexistent-card")


# ── Story 003 AC-5 : animate template needs no card refs in config ───────────

func test_valid_fixture_animate_entry_has_no_result_or_generates_keys() -> void:
	# Arrange
	var manifest: RecipeManifest = ResourceLoader.load(FIXTURE_ALL_VALID) as RecipeManifest

	# Act — find the animate entry
	var animate_entry: RecipeEntry = null
	for r: RecipeEntry in manifest.entries:
		if r.template == &"animate":
			animate_entry = r
			break

	# Assert
	assert_object(animate_entry).is_not_null()
	assert_bool(animate_entry.config.has("result_card")).is_false()
	assert_bool(animate_entry.config.has("generates")).is_false()
	assert_bool(animate_entry.config.has("spawns")).is_false()


# ── Story 003 AC-8 : all-valid fixture contains the four canonical templates ─

func test_all_valid_fixture_covers_every_template() -> void:
	# Arrange
	var manifest: RecipeManifest = ResourceLoader.load(FIXTURE_ALL_VALID) as RecipeManifest

	# Act
	var templates_seen: Dictionary = {}
	for r: RecipeEntry in manifest.entries:
		templates_seen[r.template] = true

	# Assert
	assert_bool(templates_seen.has(&"additive")).is_true()
	assert_bool(templates_seen.has(&"merge")).is_true()
	assert_bool(templates_seen.has(&"animate")).is_true()
	assert_bool(templates_seen.has(&"generator")).is_true()


# ── Story 004 : duplicate pair fixture has symmetric pair in same scene_id ───

func test_duplicate_fixture_contains_symmetric_pair_in_same_scene() -> void:
	# Arrange
	var manifest: RecipeManifest = ResourceLoader.load(FIXTURE_DUPLICATE) as RecipeManifest

	# Assert — two entries with swapped card_a/card_b share a scene
	assert_object(manifest).is_not_null()
	assert_int(manifest.entries.size()).is_equal(2)
	assert_str(String(manifest.entries[0].scene_id)).is_equal(String(manifest.entries[1].scene_id))
	assert_str(String(manifest.entries[0].card_a)).is_equal(String(manifest.entries[1].card_b))
	assert_str(String(manifest.entries[0].card_b)).is_equal(String(manifest.entries[1].card_a))


func test_dup_key_normalises_symmetric_pairs_to_same_key() -> void:
	# Arrange + Act
	var key_forward: String = RecipeDatabaseScript._dup_key(&"scene-01", &"cat", &"dog")
	var key_reverse: String = RecipeDatabaseScript._dup_key(&"scene-01", &"dog", &"cat")

	# Assert — symmetric pair must normalise to identical key
	assert_str(key_forward).is_equal(key_reverse)
	assert_str(key_forward).is_equal("scene-01|cat|dog")


func test_dup_key_differs_across_scenes_for_same_pair() -> void:
	# Arrange + Act
	var global_key: String = RecipeDatabaseScript._dup_key(&"global", &"cat", &"dog")
	var scene_key: String = RecipeDatabaseScript._dup_key(&"scene-01", &"cat", &"dog")

	# Assert — same pair in different scenes must not collide (scene-scoped override)
	assert_str(global_key).is_not_equal(scene_key)


# ── Story 005 : generator interval clamp ─────────────────────────────────────

func test_clamp_low_interval_fixture_has_interval_below_minimum() -> void:
	# Arrange — precondition for the clamp path to fire
	var manifest: RecipeManifest = ResourceLoader.load(FIXTURE_LOW_INTERVAL) as RecipeManifest

	# Assert
	assert_object(manifest).is_not_null()
	assert_float(manifest.entries[0].config.get("interval_sec", -1.0)).is_less(RecipeDatabaseScript.MIN_INTERVAL_SEC)


func test_clamp_interval_below_minimum_is_raised_to_min_interval_sec() -> void:
	# Arrange
	var db: Node = RecipeDatabaseScript.new()
	add_child(db)

	# Act — soft-warning path, safe to execute
	db._clamp_generator_intervals.call()  # no-op without entries
	db._entries = (ResourceLoader.load(FIXTURE_LOW_INTERVAL) as RecipeManifest).entries
	db._clamp_generator_intervals()

	# Assert — the under-minimum value has been clamped up
	var clamped: float = db._entries[0].config.get("interval_sec", -1.0)
	assert_float(clamped).is_equal(RecipeDatabaseScript.MIN_INTERVAL_SEC)


func test_clamp_min_interval_sec_is_exactly_half_second() -> void:
	# Regression: GDD Tuning Knob TR-recipe-database-007 pins this at 0.5 s
	assert_float(RecipeDatabaseScript.MIN_INTERVAL_SEC).is_equal(0.5)


func test_clamp_non_generator_template_is_not_touched() -> void:
	# Arrange
	var db: Node = RecipeDatabaseScript.new()
	add_child(db)
	db._entries = (ResourceLoader.load(FIXTURE_ALL_VALID) as RecipeManifest).entries

	# Capture pre-clamp intervals on non-generator entries (should have none, but config is free-form)
	var animate_before: Dictionary = {}
	for r: RecipeEntry in db._entries:
		if r.template == &"animate":
			animate_before = r.config.duplicate(true)

	# Act
	db._clamp_generator_intervals()

	# Assert — animate config is untouched by the clamp pass
	for r: RecipeEntry in db._entries:
		if r.template == &"animate":
			assert_str(str(r.config)).is_equal(str(animate_before))
