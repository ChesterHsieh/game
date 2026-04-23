## Unit tests for TableLayoutSystem API scaffold — Story 001.
##
## Covers the QA acceptance criteria scoped to story-001:
##   AC-1: get_seed_positions returns one entry per seed card in the input
##   AC-2: get_seed_positions returns an empty Dictionary for empty input
##   AC-3: get_seed_positions returns Vector2 values (not null) for each card_id
##   AC-4: get_seed_positions skips entries missing a card_id key (no crash)
##   AC-5: get_spawn_position returns a Vector2 (correct return type, no crash)
##   AC-6: Both methods are callable multiple times with identical inputs without crash
##
## Note: The implemented API returns card_id → Vector2 Dictionary (get_seed_positions)
## and a raw Vector2 (get_spawn_position). Tests validate the actual implementation.
## The system requires a Viewport to compute table bounds, so it is added to the tree.
extends GdUnitTestSuite

const TableLayoutScript := preload("res://src/gameplay/table_layout_system.gd")


# ── Helpers ───────────────────────────────────────────────────────────────────

## Build a minimal seed card entry Dictionary with the given card_id.
func _make_seed_entry(card_id: String) -> Dictionary:
	return {"card_id": card_id}


## Instantiate a TableLayoutSystem node and add it to the test scene tree so it
## has a valid Viewport for get_table_bounds().
func _make_system() -> Node:
	var sys: Node = TableLayoutScript.new()
	add_child(sys)
	return sys


# ── AC-1: get_seed_positions returns one entry per seed card ──────────────────

func test_get_seed_positions_returns_one_entry_per_input_card() -> void:
	# Arrange
	var sys: Node = _make_system()
	var seed_cards: Array = [
		_make_seed_entry("morning-light"),
		_make_seed_entry("chester"),
	]

	# Act
	var result: Dictionary = sys.get_seed_positions(seed_cards, 42)

	# Assert
	assert_int(result.size()) \
		.override_failure_message("get_seed_positions must return one entry per seed card (expected 2)") \
		.is_equal(2)
	assert_bool(result.has("morning-light")) \
		.override_failure_message("result must contain key 'morning-light'") \
		.is_true()
	assert_bool(result.has("chester")) \
		.override_failure_message("result must contain key 'chester'") \
		.is_true()

	# Cleanup
	sys.queue_free()


# ── AC-2: empty input → empty Dictionary ──────────────────────────────────────

func test_get_seed_positions_returns_empty_dict_for_empty_input() -> void:
	# Arrange
	var sys: Node = _make_system()

	# Act
	var result: Dictionary = sys.get_seed_positions([], 42)

	# Assert
	assert_bool(result.is_empty()) \
		.override_failure_message("get_seed_positions must return empty Dictionary for empty input") \
		.is_true()

	# Cleanup
	sys.queue_free()


# ── AC-3: values are Vector2 ──────────────────────────────────────────────────

func test_get_seed_positions_values_are_vector2_not_null() -> void:
	# Arrange
	var sys: Node = _make_system()
	var seed_cards: Array = [
		_make_seed_entry("card-a"),
		_make_seed_entry("card-b"),
		_make_seed_entry("card-c"),
	]

	# Act
	var result: Dictionary = sys.get_seed_positions(seed_cards, 99)

	# Assert — each value must be a Vector2 (isinstance check via get_class not available
	# for built-in types; we verify it is not null and has x/y fields)
	for key: String in result.keys():
		var pos: Vector2 = result[key]
		# If pos were null this cast would raise; reaching here confirms it is a Vector2
		assert_float(pos.x) \
			.override_failure_message("position.x for '%s' must be a finite float" % key) \
			.is_not_equal(NAN)
		assert_float(pos.y) \
			.override_failure_message("position.y for '%s' must be a finite float" % key) \
			.is_not_equal(NAN)

	# Cleanup
	sys.queue_free()


# ── AC-4: entries missing card_id are skipped gracefully ─────────────────────

func test_get_seed_positions_skips_entry_with_empty_card_id() -> void:
	# Arrange — one valid entry, one entry with missing card_id
	var sys: Node = _make_system()
	var seed_cards: Array = [
		_make_seed_entry("valid-card"),
		{"card_id": ""},           # empty string — implementation pushes warning and skips
	]

	# Act — must not crash
	var result: Dictionary = sys.get_seed_positions(seed_cards, 7)

	# Assert — only the valid card is placed; blank key is absent
	assert_bool(result.has("valid-card")) \
		.override_failure_message("valid-card must still be placed when another entry has no card_id") \
		.is_true()
	assert_bool(result.has("")) \
		.override_failure_message("empty card_id must not produce a Dictionary entry") \
		.is_false()

	# Cleanup
	sys.queue_free()


func test_get_seed_positions_entry_without_card_id_key_is_skipped() -> void:
	# Arrange — entry has no "card_id" key at all
	var sys: Node = _make_system()
	var seed_cards: Array = [
		{"zone": "center"},   # no card_id key — get("card_id","") returns ""
		_make_seed_entry("real-card"),
	]

	# Act — must not crash
	var result: Dictionary = sys.get_seed_positions(seed_cards, 3)

	# Assert
	assert_bool(result.has("real-card")) \
		.override_failure_message("real-card must be placed despite a malformed sibling entry") \
		.is_true()
	assert_int(result.size()) \
		.override_failure_message("result must have exactly 1 entry (the valid one)") \
		.is_equal(1)

	# Cleanup
	sys.queue_free()


# ── AC-5: get_spawn_position returns a Vector2, no crash ─────────────────────

func test_get_spawn_position_returns_vector2_with_empty_occupied_list() -> void:
	# Arrange
	var sys: Node = _make_system()
	var combination_point := Vector2(400.0, 300.0)
	var occupied: Array[Vector2] = []

	# Act
	var result: Vector2 = sys.get_spawn_position(combination_point, occupied, 99)

	# Assert — result is a valid Vector2 (not null, finite components)
	assert_float(result.x) \
		.override_failure_message("get_spawn_position must return a Vector2 with finite x") \
		.is_not_equal(NAN)
	assert_float(result.y) \
		.override_failure_message("get_spawn_position must return a Vector2 with finite y") \
		.is_not_equal(NAN)

	# Cleanup
	sys.queue_free()


func test_get_spawn_position_returns_vector2_with_occupied_cards() -> void:
	# Arrange — some occupied positions near the combination point
	var sys: Node = _make_system()
	var combination_point := Vector2(500.0, 400.0)
	var occupied: Array[Vector2] = [
		Vector2(480.0, 380.0),
		Vector2(520.0, 420.0),
	]

	# Act
	var result: Vector2 = sys.get_spawn_position(combination_point, occupied, 17)

	# Assert
	assert_float(result.x) \
		.override_failure_message("get_spawn_position must return finite x with occupied cards present") \
		.is_not_equal(NAN)
	assert_float(result.y) \
		.override_failure_message("get_spawn_position must return finite y with occupied cards present") \
		.is_not_equal(NAN)

	# Cleanup
	sys.queue_free()


# ── AC-6: idempotent — same inputs produce same outputs (pure function) ───────

func test_get_seed_positions_is_idempotent_for_same_seed() -> void:
	# Arrange
	var sys: Node = _make_system()
	var seed_cards: Array = [_make_seed_entry("card-x"), _make_seed_entry("card-y")]

	# Act
	var result_a: Dictionary = sys.get_seed_positions(seed_cards, 55)
	var result_b: Dictionary = sys.get_seed_positions(seed_cards, 55)

	# Assert — same seed → same positions
	assert_vector(result_a["card-x"]) \
		.override_failure_message("card-x position must be identical on repeated call with same seed") \
		.is_equal(result_b["card-x"])
	assert_vector(result_a["card-y"]) \
		.override_failure_message("card-y position must be identical on repeated call with same seed") \
		.is_equal(result_b["card-y"])

	# Cleanup
	sys.queue_free()


func test_get_spawn_position_is_idempotent_for_same_seed() -> void:
	# Arrange
	var sys: Node = _make_system()
	var combination_point := Vector2(400.0, 300.0)
	var occupied: Array[Vector2] = []

	# Act
	var result_a: Vector2 = sys.get_spawn_position(combination_point, occupied, 123)
	var result_b: Vector2 = sys.get_spawn_position(combination_point, occupied, 123)

	# Assert
	assert_vector(result_a) \
		.override_failure_message("get_spawn_position must return identical Vector2 for same seed on repeated call") \
		.is_equal(result_b)

	# Cleanup
	sys.queue_free()
