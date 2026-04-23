## SceneManager — autoload #12. Sequences scenes from the SceneManifest,
## coordinates seed card spawning, and drives the epilogue flow.
##
## Implements: design/gdd/scene-manager.md
## ADR: ADR-004 (state machine, watchdog timer, CONNECT_ONE_SHOT, process_mode)
##      ADR-005 (SceneManifest Resource, null-manifest → Epilogue)
##      ADR-003 (EventBus signal contracts, connect-before-call ordering)
##
## NOTE: class_name is intentionally omitted. Godot 4 does not allow a script
## registered as an autoload singleton to also declare a class_name matching
## its autoload name — the engine reports "Class hides an autoload singleton".
## The autoload is accessed globally via the name "SceneManager" in project.godot.
extends Node

# ── State Machine ─────────────────────────────────────────────────────────────

enum _State { WAITING, LOADING, ACTIVE, TRANSITIONING, EPILOGUE }

var _state: _State = _State.WAITING

# ── Data ──────────────────────────────────────────────────────────────────────

const MANIFEST_PATH := "res://assets/data/scene-manifest.tres"

## Loaded once at startup. Null only if the .tres file is missing or malformed,
## in which case SceneManager enters Epilogue immediately.
var _manifest: SceneManifest = null

## Index into _manifest.scene_ids pointing at the current (or next) scene.
var _current_index: int = 0

## Timeout in seconds before giving up waiting for seed_cards_ready.
## Matches ADR-004 spec value; exposed as var so tests can inject a smaller value.
var _seed_cards_ready_timeout_sec: float = 5.0

## Reference to the running SceneTreeTimer watchdog, or null if not active.
var _watchdog_timer: SceneTreeTimer = null


# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	_validate_dependencies()
	_manifest = ResourceLoader.load(MANIFEST_PATH) as SceneManifest
	if _manifest == null:
		push_error("SceneManager: scene-manifest.tres missing or malformed — entering Epilogue")
		_enter_epilogue()
		return
	_check_duplicate_scene_ids()
	# SceneGoal.scene_completed is persistent — wire it once here.
	SceneGoal.scene_completed.connect(_on_scene_completed)
	EventBus.game_start_requested.connect(_on_game_start_requested, CONNECT_ONE_SHOT)


# ── Public API ────────────────────────────────────────────────────────────────

## Returns the current scene index. Safe to call from any state.
## Used by SaveSystem to persist resume position.
##
## Usage example:
##   var idx: int = SceneManager.get_resume_index()
func get_resume_index() -> int:
	return _current_index


## Sets the scene index for resume. Only valid while in Waiting state.
## Accepts indices >= manifest.size() to represent a saved completed-game.
## Rejects negative indices.
##
## Usage example:
##   SceneManager.set_resume_index(save_data.scene_index)
func set_resume_index(index: int) -> void:
	if _state != _State.WAITING:
		push_error("SceneManager: set_resume_index called outside Waiting state — ignored")
		return
	if index < 0:
		push_error("SceneManager: set_resume_index negative index %d — ignored" % index)
		return
	_current_index = index


## Resets SceneManager to a clean Waiting state, re-arming the one-shot
## game_start_requested listener. Suitable for the Reset Progress flow.
## Emits no signals — caller is responsible for any UI transition.
##
## Behaviour per originating state:
##   Loading      → cancel watchdog, disconnect stale seed_cards_ready handler
##   Active / Transitioning → clear all cards, reset SceneGoal
##   Epilogue / Waiting → nothing to clear
##
## Usage example:
##   SceneManager.reset_to_waiting()
func reset_to_waiting() -> void:
	if _state == _State.LOADING:
		_cancel_watchdog()
		if SceneGoal.seed_cards_ready.is_connected(_on_seed_cards_ready):
			SceneGoal.seed_cards_ready.disconnect(_on_seed_cards_ready)
	elif _state == _State.ACTIVE or _state == _State.TRANSITIONING:
		CardSpawning.clear_all_cards()
		SceneGoal.reset()
	# _State.EPILOGUE and _State.WAITING: nothing to clear
	_current_index = 0
	_state = _State.WAITING
	if not EventBus.game_start_requested.is_connected(_on_game_start_requested):
		EventBus.game_start_requested.connect(_on_game_start_requested, CONNECT_ONE_SHOT)


# ── Private — State Transitions ───────────────────────────────────────────────

func _on_game_start_requested() -> void:
	# Saved-completed-game: index already at or past end of manifest → epilogue.
	if _current_index >= _manifest.scene_ids.size():
		_enter_epilogue()
		return
	_load_scene_at_index(_current_index)


func _load_scene_at_index(index: int) -> void:
	if _state == _State.LOADING:
		push_warning("SceneManager: _load_scene_at_index re-entrant call — aborting second call")
		return
	if _state == _State.EPILOGUE:
		push_error("SceneManager: _load_scene_at_index called in Epilogue — aborting")
		return

	var scene_id: String = _manifest.scene_ids[index]
	_state = _State.LOADING
	EventBus.scene_loading.emit(scene_id)

	# Connect BEFORE load_scene to guard against synchronous signal fire (ADR-003).
	# SceneGoal.seed_cards_ready is the signal that actually fires (adaptation plan).
	SceneGoal.seed_cards_ready.connect(_on_seed_cards_ready, CONNECT_ONE_SHOT)

	_watchdog_timer = get_tree().create_timer(_seed_cards_ready_timeout_sec)
	_watchdog_timer.timeout.connect(_on_seed_cards_ready_timeout.bind(scene_id))

	SceneGoal.load_scene(scene_id)


func _on_seed_cards_ready(seed_cards: Array) -> void:
	if _state != _State.LOADING:
		return
	_cancel_watchdog()
	# CardSpawning.spawn_seed_cards handles positioning via TableLayoutSystem
	# internally (approved adaptation plan — skip per-card position loop).
	CardSpawning.spawn_seed_cards(seed_cards)
	var scene_id: String = _manifest.scene_ids[_current_index]
	_state = _State.ACTIVE
	EventBus.scene_started.emit(scene_id)


func _on_seed_cards_ready_timeout(scene_id: String) -> void:
	if _state != _State.LOADING:
		return
	push_error("SceneManager: seed_cards_ready timeout for scene '%s' — entering Active with 0 cards" % scene_id)
	if SceneGoal.seed_cards_ready.is_connected(_on_seed_cards_ready):
		SceneGoal.seed_cards_ready.disconnect(_on_seed_cards_ready)
	_state = _State.ACTIVE
	EventBus.scene_started.emit(scene_id)


func _on_scene_completed(scene_id: String) -> void:
	if _state != _State.ACTIVE:
		return
	if scene_id != _manifest.scene_ids[_current_index]:
		push_warning("SceneManager: scene_completed mismatch — got '%s' expected '%s'" \
				% [scene_id, _manifest.scene_ids[_current_index]])
		return
	_state = _State.TRANSITIONING
	CardSpawning.clear_all_cards()
	await get_tree().process_frame
	SceneGoal.reset()
	_current_index += 1
	if _current_index >= _manifest.scene_ids.size():
		_enter_epilogue()
	else:
		_load_scene_at_index(_current_index)


func _enter_epilogue() -> void:
	_state = _State.EPILOGUE
	EventBus.epilogue_started.emit()


# ── Private — Helpers ─────────────────────────────────────────────────────────

func _validate_dependencies() -> void:
	# Use the actual autoload names registered in project.godot (adaptation plan).
	# StatusBarSystem included because SceneGoal depends on it at load time.
	for dep: Node in [EventBus, SceneGoal, CardSpawning, StatusBarSystem]:
		if dep == null:
			push_error("SceneManager: required autoload missing — check project.godot autoload order")


func _check_duplicate_scene_ids() -> void:
	var seen: Dictionary = {}
	for id: String in _manifest.scene_ids:
		if seen.has(id):
			print("SceneManager: duplicate scene_id '%s' in manifest — allowed" % id)
		seen[id] = true


func _cancel_watchdog() -> void:
	# SceneTreeTimer has no is_stopped() API in Godot 4.3 — it auto-frees when
	# its timeout fires or when no references remain. We simply disconnect any
	# pending listeners (defensive — prevents a deferred fire-after-cancel) and
	# null out our reference so the timer becomes eligible for GC.
	if _watchdog_timer != null:
		var conns: Array = _watchdog_timer.timeout.get_connections()
		for c in conns:
			_watchdog_timer.timeout.disconnect(c["callable"])
	_watchdog_timer = null
