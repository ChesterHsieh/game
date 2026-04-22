## Unit tests for CardSpawning pool registry — Story 001.
## Covers AC-1 through AC-4 from story-001-pool-registry.md.
##
## Isolation strategy:
##   CardSpawning is an autoload (registered as "CardSpawning" in project.godot).
##   spawn_card() calls CardDatabase.has_card() — a method that does NOT exist on
##   the CardDatabase autoload (which only exposes get_card / get_all).  Calling
##   spawn_card() in a headless test environment would therefore raise a script
##   error before any node creation occurs.
##
##   These unit tests therefore exercise the internal helpers that implement the
##   registry contract without going through spawn_card():
##     • _next_instance_id() — counter and format logic (AC-1, AC-2, AC-3)
##     • get_all_instance_ids() — live-card list (AC-4)
##     • get_card_node() — registry lookup (AC-4 inverse: removed cards absent)
##
##   The manual-registry manipulation pattern (inject into _live_cards directly)
##   is used here the same way lookup_api_test.gd manipulates _entries directly.
##
## AC-5 (pool exhaustion warning) is NOT covered here because the actual
## implementation does not use a pool (it calls PackedScene.instantiate() at
## runtime and queue_free() on remove), so exhaustion is not reachable.
## See story-001-pool-registry.md §Implementation Notes vs. ADR-002 for the
## divergence note.
extends GdUnitTestSuite

const CardSpawningScript := preload("res://src/gameplay/card_spawning_system.gd")


# ── Helpers ───────────────────────────────────────────────────────────────────

## Create a fresh CardSpawning instance with no children (no scene) and an
## empty registry.  add_child() puts it in the test suite's scene tree so
## Godot's Node methods work, then teardown frees it.
func _make_system() -> Node:
	var sys: Node = CardSpawningScript.new()
	add_child(sys)
	return sys


## Inject a stub card node directly into _live_cards so tests can verify
## registry queries without going through spawn_card().
func _inject_card(sys: Node, instance_id: String, card_id: String, pos: Vector2) -> Node2D:
	var stub := Node2D.new()
	stub.name = "Stub_%s" % instance_id
	stub.position = pos
	stub.set_meta("card_id", card_id)
	stub.set_meta("instance_id", instance_id)
	sys.add_child(stub)
	sys._live_cards[instance_id] = stub
	return stub


# ── AC-1: instance_id format is "{card_id}_{counter}" ────────────────────────

func test_next_instance_id_format_is_card_id_underscore_counter() -> void:
	# Arrange
	var sys: Node = _make_system()

	# Act — first call for a fresh card_id starts at 0
	var result: String = sys._next_instance_id("morning-light")

	# Assert
	assert_str(result).is_equal("morning-light_0")
	sys.queue_free()


func test_next_instance_id_uses_card_id_as_prefix() -> void:
	# Arrange
	var sys: Node = _make_system()

	# Act
	var result: String = sys._next_instance_id("chester")

	# Assert
	assert_bool(result.begins_with("chester_")).is_true()
	sys.queue_free()


func test_next_instance_id_suffix_is_numeric_string() -> void:
	# Arrange
	var sys: Node = _make_system()

	# Act
	var result: String = sys._next_instance_id("ju")
	var parts: PackedStringArray = result.split("_")
	var suffix: String = parts[parts.size() - 1]

	# Assert — suffix must be a non-negative integer string
	assert_bool(suffix.is_valid_int()).is_true()
	assert_bool(suffix.to_int() >= 0).is_true()
	sys.queue_free()


func test_next_instance_id_first_counter_is_zero() -> void:
	# Edge case: explicitly confirm the counter starts at 0, not 1
	# Arrange
	var sys: Node = _make_system()

	# Act
	var result: String = sys._next_instance_id("safe")

	# Assert
	assert_str(result).is_equal("safe_0")
	sys.queue_free()


# ── AC-2: counter increments per card_id ─────────────────────────────────────

func test_next_instance_id_second_call_returns_counter_one() -> void:
	# Arrange
	var sys: Node = _make_system()

	# Act
	var _first: String = sys._next_instance_id("morning-light")
	var second: String = sys._next_instance_id("morning-light")

	# Assert
	assert_str(second).is_equal("morning-light_1")
	sys.queue_free()


func test_next_instance_id_different_card_ids_have_independent_counters() -> void:
	# Arrange
	var sys: Node = _make_system()

	# Act — interleave two different card_ids
	var a0: String = sys._next_instance_id("chester")
	var b0: String = sys._next_instance_id("ju")
	var a1: String = sys._next_instance_id("chester")

	# Assert — each card_id tracks its own counter independently
	assert_str(a0).is_equal("chester_0")
	assert_str(b0).is_equal("ju_0")
	assert_str(a1).is_equal("chester_1")
	sys.queue_free()


func test_next_instance_id_counter_increments_monotonically() -> void:
	# Arrange
	var sys: Node = _make_system()

	# Act — call 5 times for the same card_id
	var ids: Array[String] = []
	for _i: int in range(5):
		ids.append(sys._next_instance_id("our-song"))

	# Assert — IDs must be our-song_0 through our-song_4 in order
	for i: int in range(5):
		assert_str(ids[i]).is_equal("our-song_%d" % i)
	sys.queue_free()


# ── AC-3: counter never reused after removal ──────────────────────────────────

func test_next_instance_id_counter_not_reset_after_registry_removal() -> void:
	# Arrange — simulate: spawn morning-light_0, spawn morning-light_1,
	# remove morning-light_0 (erase from _live_cards), then get next id
	var sys: Node = _make_system()
	var _id0: String = sys._next_instance_id("morning-light")  # morning-light_0
	var _id1: String = sys._next_instance_id("morning-light")  # morning-light_1

	# Simulate removal: erase from registry (counter in _counters is untouched)
	sys._live_cards.erase("morning-light_0")

	# Act
	var next_id: String = sys._next_instance_id("morning-light")

	# Assert — must be _2, not _0 (counter never resets)
	assert_str(next_id).is_equal("morning-light_2")
	sys.queue_free()


func test_next_instance_id_counter_not_reused_across_multiple_removals() -> void:
	# Arrange — generate 3 IDs, erase all from registry, verify counter continues
	var sys: Node = _make_system()
	for _i: int in range(3):
		var _ = sys._next_instance_id("that-photo")
	sys._live_cards.clear()  # Simulate removing all

	# Act
	var next_id: String = sys._next_instance_id("that-photo")

	# Assert — counter resumes at 3 (not 0)
	assert_str(next_id).is_equal("that-photo_3")
	sys.queue_free()


# ── AC-4: get_all_instance_ids / get_card_node reflect live registry ──────────

func test_get_all_instance_ids_returns_empty_when_no_cards() -> void:
	# Arrange
	var sys: Node = _make_system()

	# Act
	var ids: Array[String] = sys.get_all_instance_ids()

	# Assert
	assert_int(ids.size()).is_equal(0)
	sys.queue_free()


func test_get_all_instance_ids_contains_injected_card() -> void:
	# Arrange
	var sys: Node = _make_system()
	_inject_card(sys, "morning-light_0", "morning-light", Vector2(100.0, 100.0))

	# Act
	var ids: Array[String] = sys.get_all_instance_ids()

	# Assert
	assert_bool("morning-light_0" in ids).is_true()
	sys.queue_free()


func test_get_all_instance_ids_contains_all_live_cards() -> void:
	# Arrange — inject two live cards
	var sys: Node = _make_system()
	_inject_card(sys, "morning-light_0", "morning-light", Vector2(100.0, 100.0))
	_inject_card(sys, "chester_0", "chester", Vector2(200.0, 200.0))

	# Act
	var ids: Array[String] = sys.get_all_instance_ids()

	# Assert — both present
	assert_int(ids.size()).is_equal(2)
	assert_bool("morning-light_0" in ids).is_true()
	assert_bool("chester_0" in ids).is_true()
	sys.queue_free()


func test_get_all_instance_ids_does_not_contain_removed_card() -> void:
	# Arrange — inject two cards, then remove one from registry
	var sys: Node = _make_system()
	_inject_card(sys, "morning-light_0", "morning-light", Vector2(100.0, 100.0))
	_inject_card(sys, "chester_0", "chester", Vector2(200.0, 200.0))
	var stub: Node2D = sys._live_cards["morning-light_1"]  if sys._live_cards.has("morning-light_1") else null
	# Erase one entry to simulate removal
	sys._live_cards.erase("morning-light_0")

	# Act
	var ids: Array[String] = sys.get_all_instance_ids()

	# Assert — only chester_0 remains; morning-light_0 is gone
	assert_bool("morning-light_0" in ids).is_false()
	assert_bool("chester_0" in ids).is_true()
	if stub:
		stub.queue_free()
	sys.queue_free()


func test_get_card_node_returns_correct_node_for_live_card() -> void:
	# Arrange
	var sys: Node = _make_system()
	var stub: Node2D = _inject_card(sys, "morning-light_0", "morning-light", Vector2(100.0, 100.0))

	# Act
	var node: Node2D = sys.get_card_node("morning-light_0")

	# Assert — returned node is the same object we injected
	assert_that(node != null).is_true()
	assert_that(node == stub).is_true()
	sys.queue_free()


func test_get_card_node_returns_null_for_unknown_instance_id() -> void:
	# Arrange
	var sys: Node = _make_system()

	# Act
	var node: Node2D = sys.get_card_node("ghost_99")

	# Assert
	assert_that(node == null).is_true()
	sys.queue_free()


func test_get_card_node_returns_null_after_registry_removal() -> void:
	# Arrange
	var sys: Node = _make_system()
	_inject_card(sys, "morning-light_0", "morning-light", Vector2(100.0, 100.0))
	sys._live_cards.erase("morning-light_0")

	# Act
	var node: Node2D = sys.get_card_node("morning-light_0")

	# Assert
	assert_that(node == null).is_true()
	sys.queue_free()


# ── AC-4 (extended): get_all_card_positions reflects live registry ─────────────

func test_get_all_card_positions_returns_empty_when_no_cards() -> void:
	# Arrange
	var sys: Node = _make_system()

	# Act
	var positions: Array[Vector2] = sys.get_all_card_positions()

	# Assert
	assert_int(positions.size()).is_equal(0)
	sys.queue_free()


func test_get_all_card_positions_returns_position_of_injected_card() -> void:
	# Arrange
	var sys: Node = _make_system()
	var expected_pos := Vector2(123.0, 456.0)
	_inject_card(sys, "chester_0", "chester", expected_pos)

	# Act
	var positions: Array[Vector2] = sys.get_all_card_positions()

	# Assert
	assert_int(positions.size()).is_equal(1)
	assert_that(positions[0]).is_equal(expected_pos)
	sys.queue_free()
