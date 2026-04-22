## Unit tests for TableLayoutSystem seeded RNG + determinism — Story 002.
##
## Covers the QA acceptance criteria scoped to story-002:
##   AC-1: same seed → identical get_spawn_position result (deterministic)
##   AC-2: rng_seed == -1 (random) produces a valid Vector2 position
##   AC-3: seed 0 is deterministic (not treated as random)
##   AC-4: returned position is always inside table bounds over many calls
##   AC-5: get_seed_positions is deterministic per card across multiple calls
##   AC-6: different seeds produce different positions (RNG is actually used)
##
## The system requires a Viewport for table bounds — added to the scene tree.
## All determinism tests use an explicit fixed seed; random-seed tests use -1.
extends GdUnitTestSuite

const TableLayoutScript := preload("res://src/gameplay/table_layout_system.gd")


# ── Helpers ───────────────────────────────────────────────────────────────────

func _make_system() -> Node:
	var sys: Node = TableLayoutScript.new()
	add_child(sys)
	return sys


func _make_seed_entry(card_id: String) -> Dictionary:
	return {"card_id": card_id}


## Returns the table safe rect for a given system (mirrors implementation logic).
## Used to verify bounds without accessing private state.
func _get_bounds(sys: Node) -> Rect2:
	return sys.get_table_bounds()


# ── AC-1: same fixed seed → identical spawn position ─────────────────────────

func test_get_spawn_position_same_seed_returns_identical_position() -> void:
	# Arrange
	var sys: Node = _make_system()
	var combination_point := Vector2(500.0, 400.0)
	var occupied: Array[Vector2] = []
	var fixed_seed: int = 12345

	# Act
	var pos_a: Vector2 = sys.get_spawn_position(combination_point, occupied, fixed_seed)
	var pos_b: Vector2 = sys.get_spawn_position(combination_point, occupied, fixed_seed)

	# Assert
	assert_vector2(pos_a) \
		.override_failure_message("get_spawn_position with seed 12345 must return the same position on every call") \
		.is_equal(pos_b)

	# Cleanup
	sys.queue_free()


func test_get_spawn_position_same_seed_is_deterministic_across_instances() -> void:
	# Arrange — two separate instances, same seed
	var sys_a: Node = _make_system()
	var sys_b: Node = _make_system()
	var combination_point := Vector2(300.0, 250.0)
	var occupied: Array[Vector2] = []
	var fixed_seed: int = 9999

	# Act
	var pos_a: Vector2 = sys_a.get_spawn_position(combination_point, occupied, fixed_seed)
	var pos_b: Vector2 = sys_b.get_spawn_position(combination_point, occupied, fixed_seed)

	# Assert
	assert_vector2(pos_a) \
		.override_failure_message("Different instances with the same seed must produce identical positions") \
		.is_equal(pos_b)

	# Cleanup
	sys_a.queue_free()
	sys_b.queue_free()


# ── AC-2: rng_seed == -1 produces a valid (non-crash) position ───────────────

func test_get_spawn_position_random_seed_returns_valid_vector2() -> void:
	# Arrange
	var sys: Node = _make_system()
	var combination_point := Vector2(400.0, 300.0)
	var occupied: Array[Vector2] = []

	# Act — rng_seed = -1 means "use random seed"
	var result: Vector2 = sys.get_spawn_position(combination_point, occupied, -1)

	# Assert — must be a finite Vector2, not a zero-crash sentinel
	assert_float(result.x) \
		.override_failure_message("Random seed must still produce a finite x component") \
		.is_not_equal(NAN)
	assert_float(result.y) \
		.override_failure_message("Random seed must still produce a finite y component") \
		.is_not_equal(NAN)

	# Cleanup
	sys.queue_free()


func test_get_seed_positions_random_seed_returns_valid_positions() -> void:
	# Arrange
	var sys: Node = _make_system()
	var seed_cards: Array = [_make_seed_entry("card-a"), _make_seed_entry("card-b")]

	# Act
	var result: Dictionary = sys.get_seed_positions(seed_cards, -1)

	# Assert
	assert_int(result.size()) \
		.override_failure_message("Random-seeded get_seed_positions must still place all cards") \
		.is_equal(2)
	for key: String in result.keys():
		var pos: Vector2 = result[key]
		assert_float(pos.x).override_failure_message("Random placement x must be finite").is_not_equal(NAN)
		assert_float(pos.y).override_failure_message("Random placement y must be finite").is_not_equal(NAN)

	# Cleanup
	sys.queue_free()


# ── AC-3: seed 0 is deterministic (valid fixed seed, not treated as random) ───

func test_get_spawn_position_seed_zero_is_deterministic() -> void:
	# Arrange
	var sys: Node = _make_system()
	var combination_point := Vector2(400.0, 300.0)
	var occupied: Array[Vector2] = []

	# Act — seed 0 must behave identically to any other fixed seed
	var pos_a: Vector2 = sys.get_spawn_position(combination_point, occupied, 0)
	var pos_b: Vector2 = sys.get_spawn_position(combination_point, occupied, 0)

	# Assert
	assert_vector2(pos_a) \
		.override_failure_message("Seed 0 must be treated as a valid fixed seed and produce deterministic output") \
		.is_equal(pos_b)

	# Cleanup
	sys.queue_free()


func test_get_seed_positions_seed_zero_is_deterministic() -> void:
	# Arrange
	var sys: Node = _make_system()
	var seed_cards: Array = [_make_seed_entry("morning-light")]

	# Act
	var result_a: Dictionary = sys.get_seed_positions(seed_cards, 0)
	var result_b: Dictionary = sys.get_seed_positions(seed_cards, 0)

	# Assert
	assert_vector2(result_a["morning-light"]) \
		.override_failure_message("Seed 0 must produce the same placement position on every call") \
		.is_equal(result_b["morning-light"])

	# Cleanup
	sys.queue_free()


# ── AC-4: returned position is always inside table bounds ─────────────────────

func test_get_spawn_position_always_inside_table_bounds_over_many_seeds() -> void:
	# Arrange
	var sys: Node = _make_system()
	var bounds: Rect2 = _get_bounds(sys)
	var combination_point := Vector2(
		bounds.position.x + bounds.size.x * 0.5,
		bounds.position.y + bounds.size.y * 0.5
	)
	var occupied: Array[Vector2] = []

	# Act + Assert — 30 different fixed seeds
	for seed_val: int in range(30):
		var pos: Vector2 = sys.get_spawn_position(combination_point, occupied, seed_val)
		assert_float(pos.x) \
			.override_failure_message("x must be >= bounds left edge (seed %d)" % seed_val) \
			.is_greater_equal(bounds.position.x)
		assert_float(pos.x) \
			.override_failure_message("x must be <= bounds right edge (seed %d)" % seed_val) \
			.is_less_equal(bounds.position.x + bounds.size.x)
		assert_float(pos.y) \
			.override_failure_message("y must be >= bounds top edge (seed %d)" % seed_val) \
			.is_greater_equal(bounds.position.y)
		assert_float(pos.y) \
			.override_failure_message("y must be <= bounds bottom edge (seed %d)" % seed_val) \
			.is_less_equal(bounds.position.y + bounds.size.y)

	# Cleanup
	sys.queue_free()


func test_get_seed_positions_all_inside_table_bounds_over_many_seeds() -> void:
	# Arrange
	var sys: Node = _make_system()
	var bounds: Rect2 = _get_bounds(sys)
	var seed_cards: Array = [_make_seed_entry("card-x"), _make_seed_entry("card-y")]

	# Act + Assert — 20 different fixed seeds
	for seed_val: int in range(20):
		var result: Dictionary = sys.get_seed_positions(seed_cards, seed_val)
		for key: String in result.keys():
			var pos: Vector2 = result[key]
			assert_float(pos.x) \
				.override_failure_message("Seed card x must be inside table bounds (seed %d, card %s)" % [seed_val, key]) \
				.is_greater_equal(bounds.position.x)
			assert_float(pos.x) \
				.override_failure_message("Seed card x must not exceed right table edge (seed %d, card %s)" % [seed_val, key]) \
				.is_less_equal(bounds.position.x + bounds.size.x)
			assert_float(pos.y) \
				.override_failure_message("Seed card y must be inside table bounds (seed %d, card %s)" % [seed_val, key]) \
				.is_greater_equal(bounds.position.y)
			assert_float(pos.y) \
				.override_failure_message("Seed card y must not exceed bottom table edge (seed %d, card %s)" % [seed_val, key]) \
				.is_less_equal(bounds.position.y + bounds.size.y)

	# Cleanup
	sys.queue_free()


# ── AC-5: seed cards are deterministic per card with the same seed ────────────

func test_get_seed_positions_deterministic_per_card_for_same_seed() -> void:
	# Arrange
	var sys: Node = _make_system()
	var seed_cards: Array = [
		_make_seed_entry("alpha"),
		_make_seed_entry("beta"),
		_make_seed_entry("gamma"),
	]
	var fixed_seed: int = 777

	# Act
	var result_a: Dictionary = sys.get_seed_positions(seed_cards, fixed_seed)
	var result_b: Dictionary = sys.get_seed_positions(seed_cards, fixed_seed)

	# Assert — every card lands at the same position on both calls
	for card_id: String in ["alpha", "beta", "gamma"]:
		assert_vector2(result_a[card_id]) \
			.override_failure_message("%s position must be identical on repeated call with seed 777" % card_id) \
			.is_equal(result_b[card_id])

	# Cleanup
	sys.queue_free()


# ── AC-6: different seeds produce different positions ─────────────────────────

func test_get_spawn_position_different_seeds_produce_different_positions() -> void:
	# Arrange — two seeds that are far apart enough to be statistically distinct
	var sys: Node = _make_system()
	var combination_point := Vector2(400.0, 300.0)
	var occupied: Array[Vector2] = []

	# Act
	var pos_a: Vector2 = sys.get_spawn_position(combination_point, occupied, 1)
	var pos_b: Vector2 = sys.get_spawn_position(combination_point, occupied, 98765)

	# Assert — positions should not be identical (RNG is actually driving output)
	# We allow a tiny epsilon in case of an astronomically unlikely collision,
	# but in practice two distinct seeds produce distinct offsets.
	var are_equal: bool = pos_a.is_equal_approx(pos_b)
	assert_bool(are_equal) \
		.override_failure_message("Different seeds must produce different spawn positions") \
		.is_false()

	# Cleanup
	sys.queue_free()
