## SceneGoalSystem — per-scene configuration and completion authority.
## Autoload singleton. Reads scene JSON, configures StatusBarSystem, monitors goal.

extends Node

const SCENES_PATH := "res://assets/data/scenes/"

# ── Signals ───────────────────────────────────────────────────────────────────

## Fired after scene JSON is parsed — seed cards ready to spawn.
signal seed_cards_ready(seed_cards: Array)

## Fired when the goal condition is met.
signal scene_completed(scene_id: String)

# ── State ─────────────────────────────────────────────────────────────────────

enum GoalState { IDLE, ACTIVE, COMPLETE }
var _state: GoalState = GoalState.IDLE

var _scene_id:    String     = ""
var _goal_config: Dictionary = {}


# ── Setup ─────────────────────────────────────────────────────────────────────

func _ready() -> void:
	StatusBarSystem.win_condition_met.connect(_on_win_condition_met)


# ── Public API ────────────────────────────────────────────────────────────────

## Load and activate a scene by ID. Reads from assets/data/scenes/{scene_id}.json.
func load_scene(scene_id: String) -> void:
	if _state == GoalState.ACTIVE:
		push_warning("SceneGoal: load_scene called while Active — resetting first")
		reset()

	var path := SCENES_PATH + scene_id + ".json"
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("SceneGoal: scene file not found: '%s'" % path)
		return

	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_error("SceneGoal: JSON parse error in '%s'" % path)
		return
	file.close()

	var data: Dictionary = json.data
	if not _validate_scene_data(data, path):
		return

	_scene_id    = scene_id
	_goal_config = data["goal"]

	# Configure downstream systems
	ITF.set_scene_id(scene_id)
	ITF.reset_cooldowns()

	var goal_type: String = _goal_config.get("type", "")
	if goal_type in ["sustain_above", "reach_value"]:
		StatusBarSystem.configure(_build_bar_config())
	else:
		# Non-bar goals — StatusBarSystem stays Dormant
		pass

	_state = GoalState.ACTIVE

	var seed_cards: Array = data.get("seed_cards", [])
	seed_cards_ready.emit(seed_cards)


## Returns the current goal config while Active, or empty Dictionary when Idle.
func get_goal_config() -> Dictionary:
	return _goal_config.duplicate()


## Resets to Idle. Call after scene transition completes.
func reset() -> void:
	_state       = GoalState.IDLE
	_scene_id    = ""
	_goal_config = {}
	StatusBarSystem.reset()


# ── Private ───────────────────────────────────────────────────────────────────

func _on_win_condition_met() -> void:
	if _state != GoalState.ACTIVE:
		return
	_state = GoalState.COMPLETE
	scene_completed.emit(_scene_id)


func _build_bar_config() -> Dictionary:
	return {
		"bars":          _goal_config.get("bars", []),
		"max_value":     _goal_config.get("max_value", 100.0),
		"win_condition": {
			"type":         _goal_config.get("type", "sustain_above"),
			"threshold":    _goal_config.get("threshold", 60.0),
			"duration_sec": _goal_config.get("duration_sec", 30.0),
		}
	}


func _validate_scene_data(data: Dictionary, source: String) -> bool:
	if not data.has("scene_id"):
		push_error("SceneGoal: missing 'scene_id' in '%s'" % source)
		return false
	if not data.has("goal"):
		push_error("SceneGoal: missing 'goal' block in '%s'" % source)
		return false
	if not data.has("seed_cards"):
		push_warning("SceneGoal: no 'seed_cards' in '%s' — scene starts empty" % source)
	return true
