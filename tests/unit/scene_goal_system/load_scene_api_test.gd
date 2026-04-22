## Unit tests for SceneGoal load_scene API — Story 001.
## Covers ACs from story-001-load-scene-api.md.
##
## Implementation note: The actual SGS uses JSON files (not .tres Resources) and
## returns Dictionary from get_goal_config() (empty {} when Idle, not null).
## These tests exercise the real autoload behaviour against the live home.json fixture.
##
## AC-1: Missing scene file → stays Idle; get_goal_config() returns {}
## AC-2: Valid scene file → transitions to Active; get_goal_config() returns goal Dictionary
## AC-3: reset() → returns to Idle; get_goal_config() returns {}
extends GdUnitTestSuite


# ── Helpers ───────────────────────────────────────────────────────────────────

## Snapshot the SGS state via GoalState enum ordinal (0=IDLE, 1=ACTIVE, 2=COMPLETE).
func _sgs_state_is_idle() -> bool:
	return SceneGoal._state == SceneGoal.GoalState.IDLE


func _sgs_state_is_active() -> bool:
	return SceneGoal._state == SceneGoal.GoalState.ACTIVE


## Ensure SGS starts each test in a clean Idle state.
func before_test() -> void:
	SceneGoal.reset()


func after_test() -> void:
	SceneGoal.reset()


# ── AC-1: Missing scene → stays Idle ─────────────────────────────────────────

func test_load_scene_nonexistent_id_state_remains_idle() -> void:
	# Arrange — SGS is Idle (guaranteed by before_test)

	# Act
	SceneGoal.load_scene("nonexistent_scene_xyz")

	# Assert
	assert_bool(_sgs_state_is_idle()) \
		.override_failure_message("SGS should stay Idle when scene file is missing") \
		.is_true()


func test_load_scene_nonexistent_id_get_goal_config_returns_empty() -> void:
	# Arrange
	SceneGoal.load_scene("nonexistent_scene_xyz")

	# Act
	var config: Dictionary = SceneGoal.get_goal_config()

	# Assert — implementation returns empty Dictionary when Idle
	assert_bool(config.is_empty()) \
		.override_failure_message("get_goal_config() should return empty dict when load fails") \
		.is_true()


# ── AC-2: Valid scene → transitions to Active ─────────────────────────────────

func test_load_scene_valid_home_transitions_to_active() -> void:
	# Arrange — home.json exists at res://assets/data/scenes/home.json

	# Act
	SceneGoal.load_scene("home")

	# Assert
	assert_bool(_sgs_state_is_active()) \
		.override_failure_message("SGS should be Active after loading a valid scene") \
		.is_true()


func test_load_scene_valid_home_get_goal_config_returns_non_empty() -> void:
	# Arrange
	SceneGoal.load_scene("home")

	# Act
	var config: Dictionary = SceneGoal.get_goal_config()

	# Assert
	assert_bool(config.is_empty()) \
		.override_failure_message("get_goal_config() should return non-empty config when Active") \
		.is_false()


func test_load_scene_valid_home_goal_config_contains_type_field() -> void:
	# Arrange
	SceneGoal.load_scene("home")

	# Act
	var config: Dictionary = SceneGoal.get_goal_config()

	# Assert — goal Dictionary must contain the "type" key from home.json
	assert_bool(config.has("type")) \
		.override_failure_message("goal config should include 'type' field") \
		.is_true()


func test_load_scene_valid_home_goal_type_is_sustain_above() -> void:
	# Arrange
	SceneGoal.load_scene("home")

	# Act
	var config: Dictionary = SceneGoal.get_goal_config()

	# Assert — home.json declares goal.type = "sustain_above"
	assert_str(config.get("type", "")) \
		.is_equal("sustain_above")


func test_load_scene_valid_home_goal_config_is_a_copy() -> void:
	# Arrange — get_goal_config returns .duplicate() — mutations must not affect internal state
	SceneGoal.load_scene("home")

	# Act
	var config_a: Dictionary = SceneGoal.get_goal_config()
	config_a["type"] = "mutated"
	var config_b: Dictionary = SceneGoal.get_goal_config()

	# Assert — second call returns original, unmodified value
	assert_str(config_b.get("type", "")) \
		.override_failure_message("get_goal_config() must return a copy, not the live reference") \
		.is_equal("sustain_above")


# ── AC-3: reset() → returns to Idle ──────────────────────────────────────────

func test_reset_from_active_state_is_idle() -> void:
	# Arrange
	SceneGoal.load_scene("home")
	assert_bool(_sgs_state_is_active()).is_true()

	# Act
	SceneGoal.reset()

	# Assert
	assert_bool(_sgs_state_is_idle()) \
		.override_failure_message("reset() should return SGS to Idle") \
		.is_true()


func test_reset_from_active_get_goal_config_returns_empty() -> void:
	# Arrange
	SceneGoal.load_scene("home")

	# Act
	SceneGoal.reset()
	var config: Dictionary = SceneGoal.get_goal_config()

	# Assert
	assert_bool(config.is_empty()) \
		.override_failure_message("get_goal_config() should return empty dict after reset()") \
		.is_true()


func test_reset_from_idle_is_idempotent() -> void:
	# Edge case: reset() when already Idle must not crash

	# Act
	SceneGoal.reset()

	# Assert
	assert_bool(_sgs_state_is_idle()).is_true()


func test_load_scene_while_active_resets_then_reloads() -> void:
	# Edge case: calling load_scene() while Active triggers implicit reset per
	# the push_warning guard in the implementation

	# Arrange
	SceneGoal.load_scene("home")
	assert_bool(_sgs_state_is_active()).is_true()

	# Act — call load_scene again (triggers the Active guard path)
	SceneGoal.load_scene("home")

	# Assert — still Active after second load
	assert_bool(_sgs_state_is_active()) \
		.override_failure_message("Second load_scene should leave SGS Active") \
		.is_true()
