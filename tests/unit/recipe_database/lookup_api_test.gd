## Unit tests for RecipeDatabase Lookup API — Story 006.
## Covers AC-1 through AC-8 from story-006-lookup-api.md.
##
## Fixture strategy:
##   recipes_lookup_symmetric.tres        — one recipe (cat+dog, scene-01)
##                                          Used for: AC-1 (symmetric), AC-5 (identity)
##   recipes_lookup_scene_precedence.tres — two recipes same pair: global + scene-01
##                                          Used for: AC-2 (scene beats global),
##                                          AC-3 (global fallback to scene-02)
##   recipes_empty.tres                   — empty manifest
##                                          Used for: AC-4 (null on miss), AC-6 (stateless)
##   recipes_three_entries.tres           — 3 entries (all global)
##                                          Used for: AC-7 (O(1) structure check),
##                                          AC-8 (index populated after load)
##
## Note on AC-6 stateless:
##   GDScript has no built-in signal emission tracker.
##   The test verifies that repeated calls do not mutate _entries or _index size.
extends GdUnitTestSuite

# RecipeDatabase has no class_name (autoload name conflict), so preload + new().
const RecipeDatabaseScript := preload("res://src/core/recipe_database.gd")

const FIXTURE_SYMMETRIC        := "res://tests/fixtures/recipe_database/recipes_lookup_symmetric.tres"
const FIXTURE_SCENE_PRECEDENCE := "res://tests/fixtures/recipe_database/recipes_lookup_scene_precedence.tres"
const FIXTURE_EMPTY            := "res://tests/fixtures/recipe_database/recipes_empty.tres"
const FIXTURE_THREE_ENTRIES    := "res://tests/fixtures/recipe_database/recipes_three_entries.tres"


# ── AC-1: symmetric lookup returns the same result regardless of argument order ─

func test_lookup_symmetric_forward_order_returns_non_null() -> void:
	# Arrange
	var db: Node = RecipeDatabaseScript.new()
	db._load_manifest(FIXTURE_SYMMETRIC)

	# Act
	var result: RecipeEntry = db.lookup(&"cat", &"dog", &"scene-01")

	# Assert
	assert_object(result).is_not_null()
	db.free()


func test_lookup_symmetric_reverse_order_returns_non_null() -> void:
	# Arrange
	var db: Node = RecipeDatabaseScript.new()
	db._load_manifest(FIXTURE_SYMMETRIC)

	# Act
	var result: RecipeEntry = db.lookup(&"dog", &"cat", &"scene-01")

	# Assert
	assert_object(result).is_not_null()
	db.free()


func test_lookup_symmetric_forward_and_reverse_return_same_instance() -> void:
	# Arrange
	var db: Node = RecipeDatabaseScript.new()
	db._load_manifest(FIXTURE_SYMMETRIC)

	# Act
	var forward: RecipeEntry = db.lookup(&"cat", &"dog", &"scene-01")
	var reverse: RecipeEntry = db.lookup(&"dog", &"cat", &"scene-01")

	# Assert — same in-memory instance
	assert_that(forward.get_instance_id() == reverse.get_instance_id()).is_true()
	db.free()


func test_lookup_symmetric_result_has_correct_id() -> void:
	# Arrange
	var db: Node = RecipeDatabaseScript.new()
	db._load_manifest(FIXTURE_SYMMETRIC)

	# Act
	var result: RecipeEntry = db.lookup(&"cat", &"dog", &"scene-01")

	# Assert
	assert_that(result.id == &"sym-cat-dog-scene01").is_true()
	db.free()


# ── AC-2: scene-scoped rule takes precedence over global ─────────────────────

func test_lookup_scene_precedence_returns_scene_scoped_entry_not_global() -> void:
	# Arrange — fixture has both global and scene-01 rules for card_alpha+card_beta
	var db: Node = RecipeDatabaseScript.new()
	db._load_manifest(FIXTURE_SCENE_PRECEDENCE)

	# Act
	var result: RecipeEntry = db.lookup(&"card_alpha", &"card_beta", &"scene-01")

	# Assert — scene-01 rule, not the global additive rule
	assert_object(result).is_not_null()
	assert_that(result.id == &"prec-scene01").is_true()
	db.free()


func test_lookup_scene_precedence_scene_scoped_entry_has_merge_template() -> void:
	# scene-01 entry uses merge template; global uses additive
	var db: Node = RecipeDatabaseScript.new()
	db._load_manifest(FIXTURE_SCENE_PRECEDENCE)

	var result: RecipeEntry = db.lookup(&"card_alpha", &"card_beta", &"scene-01")

	assert_that(result.template == &"merge").is_true()
	db.free()


# ── AC-3: global rule returned when no scene-scoped rule for the queried scene ─

func test_lookup_scene_precedence_unknown_scene_falls_through_to_global() -> void:
	# Arrange — fixture has no scene-02 rule; only global and scene-01
	var db: Node = RecipeDatabaseScript.new()
	db._load_manifest(FIXTURE_SCENE_PRECEDENCE)

	# Act — scene-02 has no scoped rule; should get global
	var result: RecipeEntry = db.lookup(&"card_alpha", &"card_beta", &"scene-02")

	# Assert — global entry returned
	assert_object(result).is_not_null()
	assert_that(result.id == &"prec-global").is_true()
	db.free()


func test_lookup_scene_precedence_global_entry_has_additive_template() -> void:
	var db: Node = RecipeDatabaseScript.new()
	db._load_manifest(FIXTURE_SCENE_PRECEDENCE)

	var result: RecipeEntry = db.lookup(&"card_alpha", &"card_beta", &"scene-02")

	assert_that(result.template == &"additive").is_true()
	db.free()


func test_lookup_global_scene_id_arg_returns_global_entry() -> void:
	# Calling lookup with &"global" as scene_id should return the global entry directly
	var db: Node = RecipeDatabaseScript.new()
	db._load_manifest(FIXTURE_SCENE_PRECEDENCE)

	var result: RecipeEntry = db.lookup(&"card_alpha", &"card_beta", &"global")

	assert_object(result).is_not_null()
	assert_that(result.id == &"prec-global").is_true()
	db.free()


# ── AC-4: null returned on unmatched pair — no push_error ────────────────────

func test_lookup_unmatched_pair_returns_null() -> void:
	# Arrange — empty manifest has no recipes
	var db: Node = RecipeDatabaseScript.new()
	db._load_manifest(FIXTURE_EMPTY)

	# Act
	var result: RecipeEntry = db.lookup(&"x", &"y", &"scene-01")

	# Assert — null, no crash, no push_error
	assert_object(result).is_null()
	db.free()


func test_lookup_pair_not_in_nonempty_manifest_returns_null() -> void:
	# Arrange — three_entries fixture has specific pairs; z+w is not among them
	var db: Node = RecipeDatabaseScript.new()
	db._load_manifest(FIXTURE_THREE_ENTRIES)

	# Act
	var result: RecipeEntry = db.lookup(&"z", &"w", &"global")

	# Assert
	assert_object(result).is_null()
	db.free()


func test_lookup_same_card_both_args_returns_null_when_no_self_pair_recipe() -> void:
	# Edge case: card paired with itself — not a defined recipe in any fixture
	var db: Node = RecipeDatabaseScript.new()
	db._load_manifest(FIXTURE_SYMMETRIC)

	var result: RecipeEntry = db.lookup(&"cat", &"cat", &"scene-01")

	assert_object(result).is_null()
	db.free()


# ── AC-5: identity — repeated calls return the same RecipeEntry instance ──────

func test_lookup_repeated_calls_return_same_instance() -> void:
	# Arrange
	var db: Node = RecipeDatabaseScript.new()
	db._load_manifest(FIXTURE_SYMMETRIC)

	# Act
	var first: RecipeEntry = db.lookup(&"cat", &"dog", &"scene-01")
	var second: RecipeEntry = db.lookup(&"cat", &"dog", &"scene-01")

	# Assert — identity equality (same object reference)
	assert_that(first.get_instance_id() == second.get_instance_id()).is_true()
	db.free()


func test_lookup_repeated_100_times_all_same_instance() -> void:
	# Stress version of AC-5
	var db: Node = RecipeDatabaseScript.new()
	db._load_manifest(FIXTURE_SYMMETRIC)
	var expected_id: int = db.lookup(&"cat", &"dog", &"scene-01").get_instance_id()

	for _i: int in range(100):
		var r: RecipeEntry = db.lookup(&"cat", &"dog", &"scene-01")
		assert_that(r.get_instance_id() == expected_id).is_true()

	db.free()


# ── AC-6: stateless — lookup has no side effects ─────────────────────────────

func test_lookup_stateless_entries_count_unchanged_after_100_calls() -> void:
	# Arrange
	var db: Node = RecipeDatabaseScript.new()
	db._load_manifest(FIXTURE_THREE_ENTRIES)
	var initial_count: int = db._entries.size()

	# Act — call lookup 100 times
	for _i: int in range(100):
		db.lookup(&"fixture_card_a", &"fixture_card_b", &"global")

	# Assert — _entries unchanged
	assert_int(db._entries.size()).is_equal(initial_count)
	db.free()


func test_lookup_stateless_index_size_unchanged_after_100_calls() -> void:
	# Arrange
	var db: Node = RecipeDatabaseScript.new()
	db._load_manifest(FIXTURE_THREE_ENTRIES)
	var initial_index_size: int = db._index.size()

	# Act
	for _i: int in range(100):
		db.lookup(&"fixture_card_a", &"fixture_card_b", &"global")

	# Assert — _index unchanged
	assert_int(db._index.size()).is_equal(initial_index_size)
	db.free()


# ── AC-7: O(1) lookup — _index is a pre-built Dictionary (structural) ─────────

func test_lookup_index_is_dictionary_type() -> void:
	# Structural check: _index must be a Dictionary for O(1) access
	var db: Node = RecipeDatabaseScript.new()
	db._load_manifest(FIXTURE_THREE_ENTRIES)

	assert_int(typeof(db._index)).is_equal(TYPE_DICTIONARY)
	db.free()


func test_lookup_index_size_matches_unique_pairs_in_manifest() -> void:
	# Three entries in fixture_three_entries, all with distinct pairs → 3 keys
	var db: Node = RecipeDatabaseScript.new()
	db._load_manifest(FIXTURE_THREE_ENTRIES)

	assert_int(db._index.size()).is_equal(3)
	db.free()


# ── AC-8: index built after _load_manifest — lookup works immediately ─────────

func test_lookup_index_populated_after_load_manifest() -> void:
	# Arrange
	var db: Node = RecipeDatabaseScript.new()

	# Act
	db._load_manifest(FIXTURE_SYMMETRIC)

	# Assert — _index has exactly one pair key
	assert_int(db._index.size()).is_equal(1)
	db.free()


func test_lookup_returns_correct_result_immediately_after_load_manifest() -> void:
	# Verifies index is ready (not deferred) after _load_manifest returns
	var db: Node = RecipeDatabaseScript.new()
	db._load_manifest(FIXTURE_SYMMETRIC)

	var result: RecipeEntry = db.lookup(&"cat", &"dog", &"scene-01")

	assert_object(result).is_not_null()
	assert_that(result.id == &"sym-cat-dog-scene01").is_true()
	db.free()


func test_lookup_empty_manifest_index_is_empty_after_load() -> void:
	# Edge case: empty manifest → empty index, lookup returns null
	var db: Node = RecipeDatabaseScript.new()
	db._load_manifest(FIXTURE_EMPTY)

	assert_int(db._index.size()).is_equal(0)
	assert_object(db.lookup(&"any", &"thing", &"global")).is_null()
	db.free()


# ── _pair_key unit tests — normalisation invariants ───────────────────────────

func test_pair_key_alphabetical_order_lo_before_hi() -> void:
	# "cat" < "dog" alphabetically → key is "cat|dog"
	var key: String = RecipeDatabaseScript._pair_key(&"cat", &"dog")
	assert_str(key).is_equal("cat|dog")


func test_pair_key_reverse_args_produces_same_key() -> void:
	var key_forward: String = RecipeDatabaseScript._pair_key(&"cat", &"dog")
	var key_reverse: String = RecipeDatabaseScript._pair_key(&"dog", &"cat")
	assert_str(key_forward).is_equal(key_reverse)


func test_pair_key_same_both_args_produces_self_pair_key() -> void:
	var key: String = RecipeDatabaseScript._pair_key(&"cat", &"cat")
	assert_str(key).is_equal("cat|cat")
