## StatusBarSystem — tracks bar values and monitors the win condition.
## Autoload singleton. Dormant until configured by SceneGoal.
## Bar effects authored in assets/data/bar-effects.json.

extends Node

const BAR_EFFECTS_PATH := "res://assets/data/bar-effects.json"

# ── Signals ───────────────────────────────────────────────────────────────────

## Emitted every frame when bar values change (decay or combination effect).
## Kept as a local signal for direct per-instance subscription in unit tests;
## also forwarded to `EventBus.bar_values_changed` via `_emit_values()` so
## StatusBarUI and other EventBus subscribers get the update (ADR-003).
signal bar_values_changed(values: Dictionary)

## Emitted once when the win condition is satisfied.
signal win_condition_met()

# ── State ─────────────────────────────────────────────────────────────────────

enum Status { DORMANT, ACTIVE, COMPLETE }
var _status: Status = Status.DORMANT

## bar_id -> current float value
var _values: Dictionary = {}

## bar_id -> decay_rate_per_sec
var _decay_rates: Dictionary = {}

var _max_value:     float = 100.0
var _win_threshold: float = 60.0
var _win_duration:  float = 30.0
var _sustain_timer: float = 0.0

## recipe_id -> { bar_id: delta }
var _bar_effects: Dictionary = {}


# ── Setup ─────────────────────────────────────────────────────────────────────

func _ready() -> void:
	_load_bar_effects()
	ITF.combination_executed.connect(_on_combination_executed)


func _load_bar_effects() -> void:
	var file := FileAccess.open(BAR_EFFECTS_PATH, FileAccess.READ)
	if file == null:
		push_error("StatusBarSystem: cannot read '%s'" % BAR_EFFECTS_PATH)
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_error("StatusBarSystem: JSON parse error in bar-effects.json")
		return
	file.close()
	_bar_effects = json.data
	print("StatusBarSystem: loaded bar effects for %d recipe(s)" % _bar_effects.size())


# ── Public API ────────────────────────────────────────────────────────────────

## Configure for a new scene. Enters Active state.
func configure(scene_bar_config: Dictionary) -> void:
	_values.clear()
	_decay_rates.clear()
	_sustain_timer = 0.0
	_status        = Status.ACTIVE

	_max_value     = scene_bar_config.get("max_value", 100.0)

	for bar: Dictionary in scene_bar_config.get("bars", []):
		var bar_id: String = bar["id"]
		_values[bar_id]      = float(bar.get("initial_value", 0))
		_decay_rates[bar_id] = float(bar.get("decay_rate_per_sec", 0))

	var win: Dictionary = scene_bar_config.get("win_condition", {})
	_win_threshold = float(win.get("threshold", 60))
	_win_duration  = float(win.get("duration_sec", 30))

	_emit_values()


## Resets to Dormant. Call on scene transition.
func reset() -> void:
	_status        = Status.DORMANT
	_sustain_timer = 0.0
	_values.clear()
	_decay_rates.clear()


## Returns current bar values (read-only snapshot).
func get_values() -> Dictionary:
	return _values.duplicate()


# ── Per-Frame ─────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if _status != Status.ACTIVE:
		return

	var changed := false

	# Decay
	for bar_id: String in _values:
		var rate: float = _decay_rates.get(bar_id, 0.0)
		if rate > 0.0:
			var prev: float = _values[bar_id]
			_values[bar_id] = clamp(_values[bar_id] - rate * delta, 0.0, _max_value)
			if _values[bar_id] != prev:
				changed = true

	if changed:
		_emit_values()

	# Win condition: sustain_above
	_check_sustain(delta)


func _check_sustain(delta: float) -> void:
	var all_above := true
	for bar_id: String in _values:
		if _values[bar_id] < _win_threshold:
			all_above = false
			break

	if all_above:
		_sustain_timer += delta
		if _sustain_timer >= _win_duration:
			_status = Status.COMPLETE
			win_condition_met.emit()
	else:
		_sustain_timer = 0.0


# ── Combination Effect ────────────────────────────────────────────────────────

func _on_combination_executed(recipe_id: String, _template: String,
		_a: String, _b: String) -> void:
	if _status != Status.ACTIVE:
		return

	if not _bar_effects.has(recipe_id):
		return

	var effects: Dictionary = _bar_effects[recipe_id]
	var changed := false

	for bar_id: String in effects:
		if not _values.has(bar_id):
			push_warning("StatusBarSystem: bar_id '%s' from bar-effects not in active scene" % bar_id)
			continue
		var delta: float = float(effects[bar_id])
		_values[bar_id] = clamp(_values[bar_id] + delta, 0.0, _max_value)
		changed = true

	if changed:
		_emit_values()


## Broadcast current _values to both the local signal (test-facing) and the
## EventBus (UI + SceneGoal + MUT). Duplicating once avoids aliasing across
## handlers that might mutate the dict.
func _emit_values() -> void:
	var snapshot: Dictionary = _values.duplicate()
	bar_values_changed.emit(snapshot)
	if EventBus != null:
		EventBus.bar_values_changed.emit(snapshot)
