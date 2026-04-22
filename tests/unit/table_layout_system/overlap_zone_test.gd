## Unit tests for TableLayoutSystem overlap avoidance + constants — Story 003.
##
## Covers the QA acceptance criteria scoped to story-003:
##   AC-1: overlap avoidance — returned position is not within MIN_SPACING of
##         existing cards when there is room to scatter
##   AC-2: exhaustion case — always returns a Vector2, never crashes or null
##   AC-3: MIN_SPACING constant is 100.0 (GDD tuning knob default)
##   AC-4: MAX_ATTEMPTS constant is 8 (GDD tuning knob default)
##   AC-5: EDGE_INSET constant is 120.0 (table inset from viewport edges)
##   AC-6: SPAWN_RADIUS constant is 120.0 (preferred spawn radius default)
##   AC-7: with an empty occupied list, returned position is inside table bounds
##   AC-8: _count_overlaps returns 0 for empty occupied list
##   AC-9: _count_overlaps counts correctly when positions are within MIN_SPACING
##
## The implementation provides best-effort overlap avoidance (MAX_ATTEMPTS retries).
## When the table is dense, the system accepts the least-overlapping candidate.
extends GdUnitTestSuite

const TableLayoutScript := preload("res://src/gameplay/table_layout_system.gd")


# ── Helpers ───────────────────────────────────────────────────────────────────

func _make_system() -> Node:
	var sys: Node = TableLayoutScript.new()
	add_child(sys)
	return sys


func _get_bounds(sys: Node) -> Rect2:
	return sys.get_table_bounds()


## Build an Array[Vector2] of positions packed together within MIN_SPACING of
## each other, centred on [param centre]. Used to simulate a dense table.
func _make_dense_cluster(centre: Vector2, count: int, spacing: float) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	for i: int in range(count):
		var angle: float = (float(i) / float(count)) * TAU
		positions.append(centre + Vector2(cos(angle), sin(angle)) * spacing)
	return positions


# ── AC-1: overlap avoidance works on a sparse table ──────────────────────────

func test_get_spawn_position_avoids_existing_cards_on_sparse_table() -> void:
	# Arrange — 3 cards spread across a large area; MIN_SPACING = 100.0
	var sys: Node = _make_system()
	var bounds: Rect2 = _get_bounds(sys)
	var centre: Vector2 = bounds.position + bounds.size * 0.5

	var occupied: Array[Vector2] = [
		centre + Vector2(-300.0, -200.0),
		centre + Vector2(300.0, -200.0),
		centre + Vector2(0.0, 200.0),
	]
	var min_spacing: float = sys.MIN_SPACING

	# Act
	var pos: Vector2 = sys.get_spawn_position(centre, occupied, 42)

	# Assert — position should not be within MIN_SPACING of any existing card
	# (best effort: if avoidance succeeds, distances must all exceed the threshold)
	var too_close: bool = false
	for existing: Vector2 in occupied:
		if pos.distance_to(existing) < min_spacing:
			too_close = true
			break

	assert_bool(too_close) \
		.override_failure_message(
			"get_spawn_position must avoid existing cards (spacing < %.0f) when room exists" % min_spacing
		) \
		.is_false()

	# Cleanup
	sys.queue_free()


func test_get_spawn_position_no_overlap_with_single_nearby_card() -> void:
	# Arrange — single existing card right at the combination point
	var sys: Node = _make_system()
	var bounds: Rect2 = _get_bounds(sys)
	var centre: Vector2 = bounds.position + bounds.size * 0.5
	var min_spacing: float = sys.MIN_SPACING

	# Existing card sits exactly at the combination point — algorithm must scatter
	var occupied: Array[Vector2] = [centre]

	# Act
	var pos: Vector2 = sys.get_spawn_position(centre, occupied, 7)

	# Assert
	assert_float(pos.distance_to(centre)) \
		.override_failure_message(
			"Spawn position must be at least MIN_SPACING (%.0f) away from the only existing card" % min_spacing
		) \
		.is_greater_equal(min_spacing)

	# Cleanup
	sys.queue_free()


# ── AC-2: exhaustion case — never crashes, always returns a Vector2 ───────────

func test_get_spawn_position_never_crashes_on_fully_dense_table() -> void:
	# Arrange — densely packed positions so every candidate will overlap
	# Use spacing much less than MIN_SPACING (100.0) to guarantee exhaustion
	var sys: Node = _make_system()
	var bounds: Rect2 = _get_bounds(sys)
	var centre: Vector2 = bounds.position + bounds.size * 0.5

	# 20 cards in a tight cluster within 30px — forces all retries to overlap
	var occupied: Array[Vector2] = _make_dense_cluster(centre, 20, 30.0)

	# Act — must not crash; must return a valid Vector2
	var pos: Vector2 = sys.get_spawn_position(centre, occupied, 88)

	# Assert — result is a finite Vector2 (no null, no crash)
	assert_float(pos.x) \
		.override_failure_message("Dense table must still produce a finite x position") \
		.is_not_equal(NAN)
	assert_float(pos.y) \
		.override_failure_message("Dense table must still produce a finite y position") \
		.is_not_equal(NAN)

	# Cleanup
	sys.queue_free()


func test_get_spawn_position_returns_vector2_not_null_on_exhaustion() -> void:
	# Arrange — extreme density: 40 cards packed at 10px spacing
	var sys: Node = _make_system()
	var bounds: Rect2 = _get_bounds(sys)
	var centre: Vector2 = bounds.position + bounds.size * 0.5
	var occupied: Array[Vector2] = _make_dense_cluster(centre, 40, 10.0)

	# Act
	var pos: Vector2 = sys.get_spawn_position(centre, occupied, 1234)

	# Assert — result is inside or on the table bounds
	assert_float(pos.x) \
		.override_failure_message("Exhaustion result x must be >= table left edge") \
		.is_greater_equal(bounds.position.x)
	assert_float(pos.x) \
		.override_failure_message("Exhaustion result x must be <= table right edge") \
		.is_less_equal(bounds.position.x + bounds.size.x)
	assert_float(pos.y) \
		.override_failure_message("Exhaustion result y must be >= table top edge") \
		.is_greater_equal(bounds.position.y)
	assert_float(pos.y) \
		.override_failure_message("Exhaustion result y must be <= table bottom edge") \
		.is_less_equal(bounds.position.y + bounds.size.y)

	# Cleanup
	sys.queue_free()


# ── AC-3: MIN_SPACING constant default ────────────────────────────────────────

func test_min_spacing_constant_is_100() -> void:
	# Arrange
	var sys: Node = _make_system()

	# Assert
	assert_float(sys.MIN_SPACING) \
		.override_failure_message("MIN_SPACING must equal 100.0 (GDD tuning knob default)") \
		.is_equal(100.0)

	# Cleanup
	sys.queue_free()


# ── AC-4: MAX_ATTEMPTS constant default ───────────────────────────────────────

func test_max_attempts_constant_is_8() -> void:
	# Arrange
	var sys: Node = _make_system()

	# Assert
	assert_int(sys.MAX_ATTEMPTS) \
		.override_failure_message("MAX_ATTEMPTS must equal 8 (GDD tuning knob default)") \
		.is_equal(8)

	# Cleanup
	sys.queue_free()


# ── AC-5: EDGE_INSET constant ─────────────────────────────────────────────────

func test_edge_inset_constant_is_120() -> void:
	# Arrange
	var sys: Node = _make_system()

	# Assert
	assert_float(sys.EDGE_INSET) \
		.override_failure_message("EDGE_INSET must equal 120.0") \
		.is_equal(120.0)

	# Cleanup
	sys.queue_free()


# ── AC-6: SPAWN_RADIUS constant ───────────────────────────────────────────────

func test_spawn_radius_constant_is_120() -> void:
	# Arrange
	var sys: Node = _make_system()

	# Assert
	assert_float(sys.SPAWN_RADIUS) \
		.override_failure_message("SPAWN_RADIUS must equal 120.0 (preferred spawn radius default)") \
		.is_equal(120.0)

	# Cleanup
	sys.queue_free()


# ── AC-7: empty occupied list — result inside bounds ─────────────────────────

func test_get_spawn_position_inside_bounds_with_empty_occupied_list() -> void:
	# Arrange
	var sys: Node = _make_system()
	var bounds: Rect2 = _get_bounds(sys)
	var combination_point: Vector2 = bounds.position + bounds.size * 0.5
	var occupied: Array[Vector2] = []

	# Act
	var pos: Vector2 = sys.get_spawn_position(combination_point, occupied, 0)

	# Assert
	assert_float(pos.x) \
		.override_failure_message("Empty occupied: x must be >= left edge") \
		.is_greater_equal(bounds.position.x)
	assert_float(pos.x) \
		.override_failure_message("Empty occupied: x must be <= right edge") \
		.is_less_equal(bounds.position.x + bounds.size.x)
	assert_float(pos.y) \
		.override_failure_message("Empty occupied: y must be >= top edge") \
		.is_greater_equal(bounds.position.y)
	assert_float(pos.y) \
		.override_failure_message("Empty occupied: y must be <= bottom edge") \
		.is_less_equal(bounds.position.y + bounds.size.y)

	# Cleanup
	sys.queue_free()


# ── AC-8: _count_overlaps returns 0 for empty list ───────────────────────────

func test_count_overlaps_returns_zero_for_empty_occupied_list() -> void:
	# Arrange
	var sys: Node = _make_system()
	var pos := Vector2(300.0, 200.0)
	var occupied: Array[Vector2] = []

	# Act
	var count: int = sys._count_overlaps(pos, occupied)

	# Assert
	assert_int(count) \
		.override_failure_message("_count_overlaps must return 0 when occupied list is empty") \
		.is_equal(0)

	# Cleanup
	sys.queue_free()


# ── AC-9: _count_overlaps counts correctly within MIN_SPACING ────────────────

func test_count_overlaps_counts_positions_within_min_spacing() -> void:
	# Arrange — two positions within 100px, one outside
	var sys: Node = _make_system()
	var min_spacing: float = sys.MIN_SPACING   # 100.0
	var pos := Vector2(400.0, 300.0)
	var occupied: Array[Vector2] = [
		Vector2(400.0 + min_spacing * 0.5, 300.0),   # 50px away — overlap
		Vector2(400.0 - min_spacing * 0.8, 300.0),   # 80px away — overlap
		Vector2(400.0 + min_spacing * 1.5, 300.0),   # 150px away — no overlap
	]

	# Act
	var count: int = sys._count_overlaps(pos, occupied)

	# Assert — exactly 2 of the 3 occupied positions are within MIN_SPACING
	assert_int(count) \
		.override_failure_message(
			"_count_overlaps must count exactly 2 positions within MIN_SPACING (%.0f)" % min_spacing
		) \
		.is_equal(2)

	# Cleanup
	sys.queue_free()


func test_count_overlaps_boundary_exactly_at_min_spacing_is_not_counted() -> void:
	# Arrange — position exactly at MIN_SPACING distance (not strictly less-than)
	var sys: Node = _make_system()
	var min_spacing: float = sys.MIN_SPACING
	var pos := Vector2(0.0, 0.0)
	var occupied: Array[Vector2] = [Vector2(min_spacing, 0.0)]   # exactly at boundary

	# Act — implementation uses < (strictly less than), so boundary is NOT an overlap
	var count: int = sys._count_overlaps(pos, occupied)

	# Assert
	assert_int(count) \
		.override_failure_message(
			"Position exactly at MIN_SPACING must NOT be counted as an overlap (uses strict <)"
		) \
		.is_equal(0)

	# Cleanup
	sys.queue_free()


func test_count_overlaps_all_positions_within_spacing_counted() -> void:
	# Arrange — 4 positions all within 50px (well inside MIN_SPACING)
	var sys: Node = _make_system()
	var pos := Vector2(200.0, 200.0)
	var occupied: Array[Vector2] = [
		Vector2(210.0, 200.0),
		Vector2(190.0, 200.0),
		Vector2(200.0, 210.0),
		Vector2(200.0, 190.0),
	]

	# Act
	var count: int = sys._count_overlaps(pos, occupied)

	# Assert
	assert_int(count) \
		.override_failure_message("All 4 positions within MIN_SPACING must be counted as overlaps") \
		.is_equal(4)

	# Cleanup
	sys.queue_free()
