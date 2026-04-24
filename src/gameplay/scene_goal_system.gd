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

## Mutable copy of the scene's milestone list. Entries are removed as they fire
## so each milestone fires at most once per load_scene() per TR-scene-goal-system-014.
## Shape per entry: { "bar_id": String, "value": float, "spawns": PackedStringArray }
var _pending_milestones: Array[Dictionary] = []


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

	_build_pending_milestones()
	if not EventBus.bar_values_changed.is_connected(_on_bar_values_changed):
		EventBus.bar_values_changed.connect(_on_bar_values_changed)

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
	_pending_milestones.clear()
	if EventBus.bar_values_changed.is_connected(_on_bar_values_changed):
		EventBus.bar_values_changed.disconnect(_on_bar_values_changed)
	StatusBarSystem.reset()


# ── Private ───────────────────────────────────────────────────────────────────

func _on_win_condition_met() -> void:
	if _state != GoalState.ACTIVE:
		return
	_state = GoalState.COMPLETE
	# Local signal is kept for direct per-instance subscription (tests +
	# SceneManager which connects directly). EventBus fan-out feeds STUI /
	# MUT / AudioManager which all subscribe through the bus (ADR-003).
	scene_completed.emit(_scene_id)
	EventBus.scene_completed.emit(_scene_id)


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


## Parses `goal.milestones` from the loaded scene and populates
## [member _pending_milestones]. Entries with missing keys or referencing a
## `bar_id` that is not declared in `goal.bars` are skipped with a warning
## (per AC-4). Absent `milestones` key is a valid, common case — no warning.
func _build_pending_milestones() -> void:
	_pending_milestones.clear()

	var raw: Array = _goal_config.get("milestones", [])
	if raw.is_empty():
		return

	# Build set of valid bar_ids from the scene's bar list.
	var valid_bar_ids: Dictionary = {}
	for bar_variant in _goal_config.get("bars", []):
		if bar_variant is Dictionary and bar_variant.has("id"):
			valid_bar_ids[String(bar_variant["id"])] = true

	for entry_variant in raw:
		if not (entry_variant is Dictionary):
			push_warning("SceneGoal: milestone entry is not a Dictionary — skipped")
			continue
		var entry: Dictionary = entry_variant
		if not (entry.has("bar_id") and entry.has("value") and entry.has("spawns")):
			push_warning("SceneGoal: milestone entry missing required keys (bar_id/value/spawns) — skipped")
			continue

		var bar_id: String = String(entry["bar_id"])
		if not valid_bar_ids.has(bar_id):
			push_warning("SceneGoal: milestone references unknown bar_id '%s' — skipped" % bar_id)
			continue

		_pending_milestones.append({
			"bar_id": bar_id,
			"value":  float(entry["value"]),
			"spawns": PackedStringArray(entry["spawns"]),
		})


## Fires on every [signal EventBus.bar_values_changed]. For each pending
## milestone whose bar has reached its threshold, emits
## [signal EventBus.milestone_cards_spawn] with the milestone's spawn list
## and removes the entry from [member _pending_milestones] so it cannot
## fire again in the same scene.
func _on_bar_values_changed(values: Dictionary) -> void:
	if _state != GoalState.ACTIVE:
		return
	if _pending_milestones.is_empty():
		return

	# Collect indices that fire this tick; remove them in reverse order after
	# the loop so indices stay valid.
	var fired_indices: Array[int] = []
	for i in range(_pending_milestones.size()):
		var m: Dictionary = _pending_milestones[i]
		var bar_id: String = m["bar_id"]
		if not values.has(bar_id):
			continue
		var current: float = float(values[bar_id])
		if current >= float(m["value"]):
			EventBus.milestone_cards_spawn.emit(m["spawns"])
			fired_indices.append(i)

	for i in range(fired_indices.size() - 1, -1, -1):
		_pending_milestones.remove_at(fired_indices[i])


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
