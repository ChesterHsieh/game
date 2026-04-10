## HintSystem — watches for player stagnation and emits hint level signals.
## Autoload singleton. Emits hint_level_changed for StatusBarUI to display the arc.

extends Node

# ── Signals ───────────────────────────────────────────────────────────────────

## 0 = hidden, 1 = faint arc, 2 = full arc.
signal hint_level_changed(level: int)

# ── Tuning ────────────────────────────────────────────────────────────────────

## Seconds without a combination before Level 1 hint appears. (Production default.)
const STAGNATION_SEC := 300.0

# ── State ─────────────────────────────────────────────────────────────────────

enum HintState { DORMANT, WATCHING, HINT1, HINT2 }
var _state:            HintState = HintState.DORMANT
var _stagnation_timer: float     = 0.0
var _hint_level:       int       = 0


# ── Setup ─────────────────────────────────────────────────────────────────────

func _ready() -> void:
	SceneGoal.seed_cards_ready.connect(_on_seed_cards_ready)
	SceneGoal.scene_completed.connect(_on_scene_completed)
	ITF.combination_executed.connect(_on_combination_executed)
	StatusBarSystem.win_condition_met.connect(_on_win_condition_met)


# ── Per-Frame ─────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if _state not in [HintState.WATCHING, HintState.HINT1]:
		return

	_stagnation_timer += delta

	if _state == HintState.WATCHING and _stagnation_timer >= STAGNATION_SEC:
		_state = HintState.HINT1
		_set_level(1)
	elif _state == HintState.HINT1 and _stagnation_timer >= STAGNATION_SEC * 2.0:
		_state = HintState.HINT2
		_set_level(2)


# ── Signal Handlers ───────────────────────────────────────────────────────────

func _on_seed_cards_ready(_seed_cards: Array) -> void:
	var goal := SceneGoal.get_goal_config()
	var goal_type: String = goal.get("type", "")
	if goal_type in ["sustain_above", "reach_value"]:
		_stagnation_timer = 0.0
		_state            = HintState.WATCHING
		_set_level(0)
	else:
		_state = HintState.DORMANT


func _on_combination_executed(_recipe_id: String, _template: String,
		_a: String, _b: String) -> void:
	if _state == HintState.DORMANT:
		return
	_stagnation_timer = 0.0
	_state            = HintState.WATCHING
	if _hint_level != 0:
		_set_level(0)


func _on_win_condition_met() -> void:
	_state = HintState.DORMANT
	if _hint_level != 0:
		_set_level(0)


func _on_scene_completed(_scene_id: String) -> void:
	_state            = HintState.DORMANT
	_stagnation_timer = 0.0
	if _hint_level != 0:
		_set_level(0)


# ── Private ───────────────────────────────────────────────────────────────────

func _set_level(level: int) -> void:
	_hint_level = level
	hint_level_changed.emit(level)
