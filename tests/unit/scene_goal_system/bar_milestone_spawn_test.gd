## Unit tests for SceneGoal bar-milestone spawn — Story 004.
##
## Covers:
##   AC-1: Milestone fires on first reach via EventBus.bar_values_changed
##   AC-2: Milestone fires at most once per load_scene()
##   AC-3: Scene with no `milestones` key loads without error
##   AC-4: Milestone with unknown bar_id logs a warning and is skipped
##
## Testing approach: exercise the SGS autoload by injecting a _goal_config
## Dictionary directly and calling _build_pending_milestones() +
## _on_bar_values_changed() — this bypasses file I/O and keeps the test
## deterministic without live JSON fixtures.
extends GdUnitTestSuite


# ── Helpers ───────────────────────────────────────────────────────────────────

## Forces SGS into Active state with the given goal config, without going
## through load_scene() (which requires a JSON file on disk).
func _inject_goal(goal: Dictionary) -> void:
	SceneGoal._state            = SceneGoal.GoalState.ACTIVE
	SceneGoal._scene_id         = "test_scene"
	SceneGoal._goal_config      = goal
	SceneGoal._build_pending_milestones()


func _make_bar_config(bar_id: String) -> Dictionary:
	return {
		"id":           bar_id,
		"label":        bar_id,
		"start_value":  0.0,
		"color":        "#808080",
	}


func before_test() -> void:
	SceneGoal.reset()


func after_test() -> void:
	SceneGoal.reset()


# ── AC-1: milestone fires on first reach ─────────────────────────────────────

func test_milestone_fires_on_first_reach() -> void:
	# Arrange
	_inject_goal({
		"type":      "reach_value",
		"bars":      [_make_bar_config("journey_progress")],
		"milestones": [
			{"bar_id": "journey_progress", "value": 2, "spawns": ["good_scenery"]},
		],
	})

	var captured: Array = []
	var handler := func(spawns: PackedStringArray) -> void:
		captured.append(spawns)
	EventBus.milestone_cards_spawn.connect(handler)

	# Act
	EventBus.bar_values_changed.emit({"journey_progress": 2.0})

	# Assert
	assert_int(captured.size()) \
		.override_failure_message("milestone_cards_spawn must fire exactly once on threshold reach") \
		.is_equal(1)
	assert_array(Array(captured[0])) \
		.override_failure_message("spawns array must match milestone config") \
		.contains_exactly(["good_scenery"])

	EventBus.milestone_cards_spawn.disconnect(handler)


func test_milestone_fires_when_value_exceeds_threshold() -> void:
	# Arrange
	_inject_goal({
		"bars":      [_make_bar_config("progress")],
		"milestones": [
			{"bar_id": "progress", "value": 5, "spawns": ["reward"]},
		],
	})
	var fire_count := [0]
	var handler := func(_spawns: PackedStringArray) -> void:
		fire_count[0] += 1
	EventBus.milestone_cards_spawn.connect(handler)

	# Act: jump well past threshold
	EventBus.bar_values_changed.emit({"progress": 10.0})

	# Assert
	assert_int(fire_count[0]) \
		.override_failure_message("Milestone must fire when current >= threshold") \
		.is_equal(1)

	EventBus.milestone_cards_spawn.disconnect(handler)


func test_milestone_does_not_fire_below_threshold() -> void:
	# Arrange
	_inject_goal({
		"bars":      [_make_bar_config("progress")],
		"milestones": [
			{"bar_id": "progress", "value": 5, "spawns": ["reward"]},
		],
	})
	var fire_count := [0]
	var handler := func(_spawns: PackedStringArray) -> void:
		fire_count[0] += 1
	EventBus.milestone_cards_spawn.connect(handler)

	# Act: one below threshold
	EventBus.bar_values_changed.emit({"progress": 4.999})

	# Assert
	assert_int(fire_count[0]) \
		.override_failure_message("Milestone must NOT fire below threshold") \
		.is_equal(0)

	EventBus.milestone_cards_spawn.disconnect(handler)


# ── AC-2: fires at most once ─────────────────────────────────────────────────

func test_milestone_fires_at_most_once_on_repeated_reach() -> void:
	# Arrange
	_inject_goal({
		"bars":      [_make_bar_config("journey_progress")],
		"milestones": [
			{"bar_id": "journey_progress", "value": 2, "spawns": ["good_scenery"]},
		],
	})
	var fire_count := [0]
	var handler := func(_spawns: PackedStringArray) -> void:
		fire_count[0] += 1
	EventBus.milestone_cards_spawn.connect(handler)

	# Act
	EventBus.bar_values_changed.emit({"journey_progress": 2.0})
	EventBus.bar_values_changed.emit({"journey_progress": 2.0})
	EventBus.bar_values_changed.emit({"journey_progress": 3.0})

	# Assert
	assert_int(fire_count[0]) \
		.override_failure_message("Milestone must fire at most once per load_scene()") \
		.is_equal(1)

	EventBus.milestone_cards_spawn.disconnect(handler)


# ── AC-3: no milestones key — no crash ───────────────────────────────────────

func test_goal_without_milestones_key_loads_without_error() -> void:
	# Arrange + Act
	_inject_goal({
		"type": "sustain_above",
		"bars": [_make_bar_config("bar_a")],
		# no "milestones" key
	})

	# Assert: pending list is empty, no signal will ever fire
	assert_int(SceneGoal._pending_milestones.size()) \
		.override_failure_message("_pending_milestones must be empty when goal has no milestones key") \
		.is_equal(0)

	# Firing bar_values_changed must not crash or emit
	var fire_count := [0]
	var handler := func(_spawns: PackedStringArray) -> void:
		fire_count[0] += 1
	EventBus.milestone_cards_spawn.connect(handler)

	EventBus.bar_values_changed.emit({"bar_a": 999.0})

	assert_int(fire_count[0]) \
		.override_failure_message("No milestone must fire when goal has no milestones key") \
		.is_equal(0)

	EventBus.milestone_cards_spawn.disconnect(handler)


# ── AC-4: unknown bar_id is skipped with a warning ───────────────────────────

func test_milestone_with_unknown_bar_id_is_skipped_at_load() -> void:
	# Arrange: one valid milestone + one with unknown bar_id
	_inject_goal({
		"bars":      [_make_bar_config("real_bar")],
		"milestones": [
			{"bar_id": "real_bar",        "value": 1, "spawns": ["good"]},
			{"bar_id": "nonexistent_bar", "value": 1, "spawns": ["ghost"]},
		],
	})

	# Assert: only the valid milestone is in pending
	assert_int(SceneGoal._pending_milestones.size()) \
		.override_failure_message("Unknown bar_id milestone must be filtered out at load") \
		.is_equal(1)
	assert_str(String(SceneGoal._pending_milestones[0]["bar_id"])) \
		.override_failure_message("Surviving milestone must be the valid one") \
		.is_equal("real_bar")


func test_milestone_with_unknown_bar_id_does_not_emit() -> void:
	# Arrange: only an unknown-bar milestone
	_inject_goal({
		"bars":      [_make_bar_config("real_bar")],
		"milestones": [
			{"bar_id": "nonexistent_bar", "value": 1, "spawns": ["ghost"]},
		],
	})
	var fire_count := [0]
	var handler := func(_spawns: PackedStringArray) -> void:
		fire_count[0] += 1
	EventBus.milestone_cards_spawn.connect(handler)

	# Act: fire with values for both (real and phantom)
	EventBus.bar_values_changed.emit({"real_bar": 999.0, "nonexistent_bar": 999.0})

	# Assert: no signal for phantom bar
	assert_int(fire_count[0]) \
		.override_failure_message("Unknown-bar milestone must never emit") \
		.is_equal(0)

	EventBus.milestone_cards_spawn.disconnect(handler)


# ── Bonus: multiple milestones on different bars fire independently ──────────

func test_multiple_milestones_fire_independently() -> void:
	# Arrange
	_inject_goal({
		"bars": [_make_bar_config("a"), _make_bar_config("b")],
		"milestones": [
			{"bar_id": "a", "value": 3, "spawns": ["card_a"]},
			{"bar_id": "b", "value": 5, "spawns": ["card_b"]},
		],
	})
	var captured: Array = []
	var handler := func(spawns: PackedStringArray) -> void:
		captured.append(Array(spawns))
	EventBus.milestone_cards_spawn.connect(handler)

	# Act: fire "a" first, then "b"
	EventBus.bar_values_changed.emit({"a": 3.0, "b": 0.0})
	EventBus.bar_values_changed.emit({"a": 3.0, "b": 5.0})

	# Assert: both fired, each exactly once
	assert_int(captured.size()) \
		.override_failure_message("Two independent milestones must both fire") \
		.is_equal(2)
	assert_array(captured[0]).contains_exactly(["card_a"])
	assert_array(captured[1]).contains_exactly(["card_b"])

	EventBus.milestone_cards_spawn.disconnect(handler)


# ── Reset clears pending milestones and disconnects handler ──────────────────

func test_reset_clears_pending_milestones() -> void:
	# Arrange
	_inject_goal({
		"bars":      [_make_bar_config("bar")],
		"milestones": [{"bar_id": "bar", "value": 1, "spawns": ["x"]}],
	})
	assert_int(SceneGoal._pending_milestones.size()).is_equal(1)

	# Act
	SceneGoal.reset()

	# Assert
	assert_int(SceneGoal._pending_milestones.size()) \
		.override_failure_message("reset() must clear _pending_milestones") \
		.is_equal(0)
	assert_bool(EventBus.bar_values_changed.is_connected(SceneGoal._on_bar_values_changed)) \
		.override_failure_message("reset() must disconnect the bar_values_changed handler") \
		.is_false()
