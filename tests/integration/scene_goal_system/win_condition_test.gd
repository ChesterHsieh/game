## Integration tests for SceneGoal win condition handling — Story 003.
## Covers ACs from story-003-win-condition.md.
##
## Implementation note: SGS connects to StatusBarSystem.win_condition_met (not
## EventBus.win_condition_met). scene_completed is emitted on SGS itself, not on
## EventBus. get_goal_config() returns the Dictionary while Complete (not null).
##
## AC-1: scene_completed fires on SBS win_condition_met while Active
## AC-2: No duplicate scene_completed when win_condition_met fires again
## AC-3: get_goal_config() returns non-empty Dictionary while Complete
extends GdUnitTestSuite


# ── Helpers ───────────────────────────────────────────────────────────────────

func before_test() -> void:
	SceneGoal.reset()
	StatusBarSystem.reset()


func after_test() -> void:
	SceneGoal.reset()
	StatusBarSystem.reset()


## Put SGS into Active state by loading the home scene.
func _activate_sgs() -> void:
	SceneGoal.load_scene("home")


## Simulate a win by directly emitting SBS.win_condition_met.
## This exercises the signal connection SGS sets up in _ready().
func _trigger_win() -> void:
	StatusBarSystem.win_condition_met.emit()


# ── AC-1: scene_completed fires on win ────────────────────────────────────────

func test_win_condition_met_while_active_emits_scene_completed() -> void:
	# Arrange
	_activate_sgs()
	var captured := {"emitted": false}
	var handler := func(_scene_id: String) -> void:
		captured["emitted"] = true
	SceneGoal.scene_completed.connect(handler)

	# Act
	_trigger_win()

	# Assert
	SceneGoal.scene_completed.disconnect(handler)
	assert_bool(captured["emitted"]) \
		.override_failure_message("scene_completed must fire when SBS emits win_condition_met") \
		.is_true()


func test_win_condition_met_scene_completed_carries_correct_scene_id() -> void:
	# Arrange
	_activate_sgs()
	var captured := {"scene_id": ""}
	var handler := func(scene_id: String) -> void:
		captured["scene_id"] = scene_id
	SceneGoal.scene_completed.connect(handler)

	# Act
	_trigger_win()

	# Assert — scene_id loaded from home.json
	SceneGoal.scene_completed.disconnect(handler)
	assert_str(captured["scene_id"]) \
		.override_failure_message("scene_completed must carry scene_id 'home'") \
		.is_equal("home")


func test_win_condition_met_while_active_sgs_enters_complete_state() -> void:
	# Arrange
	_activate_sgs()

	# Act
	_trigger_win()

	# Assert
	assert_int(SceneGoal._state) \
		.override_failure_message("SGS should be in COMPLETE state after win") \
		.is_equal(SceneGoal.GoalState.COMPLETE)


# ── AC-2: No duplicate scene_completed ────────────────────────────────────────

func test_win_condition_met_twice_emits_scene_completed_only_once() -> void:
	# Arrange
	_activate_sgs()
	var captured := {"count": 0}
	var handler := func(_scene_id: String) -> void:
		captured["count"] = int(captured["count"]) + 1
	SceneGoal.scene_completed.connect(handler)

	# Act — trigger win twice
	_trigger_win()
	_trigger_win()

	# Assert
	SceneGoal.scene_completed.disconnect(handler)
	assert_int(captured["count"]) \
		.override_failure_message("scene_completed must only fire once even if win_condition_met fires twice") \
		.is_equal(1)


func test_win_condition_met_while_idle_does_not_emit_scene_completed() -> void:
	# Arrange — SGS is Idle (before_test ensures this); do NOT load a scene
	var captured := {"emitted": false}
	var handler := func(_scene_id: String) -> void:
		captured["emitted"] = true
	SceneGoal.scene_completed.connect(handler)

	# Act
	_trigger_win()

	# Assert
	SceneGoal.scene_completed.disconnect(handler)
	assert_bool(captured["emitted"]) \
		.override_failure_message("scene_completed must NOT fire when SGS is Idle") \
		.is_false()


func test_win_condition_met_while_complete_does_not_emit_scene_completed_again() -> void:
	# Arrange — drive SGS to Complete state first
	_activate_sgs()
	_trigger_win()
	assert_int(SceneGoal._state).is_equal(SceneGoal.GoalState.COMPLETE)

	var captured := {"count": 0}
	var handler := func(_scene_id: String) -> void:
		captured["count"] = int(captured["count"]) + 1
	SceneGoal.scene_completed.connect(handler)

	# Act — fire win_condition_met while already Complete
	_trigger_win()

	# Assert
	SceneGoal.scene_completed.disconnect(handler)
	assert_int(captured["count"]) \
		.override_failure_message("scene_completed must NOT fire when SGS is already Complete") \
		.is_equal(0)


# ── AC-3: get_goal_config returns data while Complete ─────────────────────────

func test_get_goal_config_returns_non_empty_while_complete() -> void:
	# Arrange
	_activate_sgs()
	_trigger_win()

	# Act
	var config: Dictionary = SceneGoal.get_goal_config()

	# Assert — Hint System relies on this during the transition animation
	assert_bool(config.is_empty()) \
		.override_failure_message("get_goal_config() must return non-empty config in Complete state") \
		.is_false()


func test_get_goal_config_complete_state_still_has_type_field() -> void:
	# Arrange
	_activate_sgs()
	_trigger_win()

	# Act
	var config: Dictionary = SceneGoal.get_goal_config()

	# Assert — goal type survives the Complete transition
	assert_bool(config.has("type")) \
		.override_failure_message("goal config must still contain 'type' while Complete") \
		.is_true()


func test_get_goal_config_complete_state_preserves_original_values() -> void:
	# Arrange
	_activate_sgs()
	var config_before: Dictionary = SceneGoal.get_goal_config()
	_trigger_win()

	# Act
	var config_after: Dictionary = SceneGoal.get_goal_config()

	# Assert — Complete must not modify the stored config
	assert_str(config_after.get("type", "")) \
		.override_failure_message("goal type must be unchanged after entering Complete") \
		.is_equal(config_before.get("type", ""))


func test_get_goal_config_returns_empty_after_reset_from_complete() -> void:
	# Arrange — full lifecycle: Idle → Active → Complete → reset → Idle
	_activate_sgs()
	_trigger_win()

	# Act
	SceneGoal.reset()
	var config: Dictionary = SceneGoal.get_goal_config()

	# Assert
	assert_bool(config.is_empty()) \
		.override_failure_message("get_goal_config() must return empty dict after reset from Complete") \
		.is_true()
