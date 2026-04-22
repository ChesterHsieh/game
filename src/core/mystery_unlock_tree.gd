## MysteryUnlockTree — autoload singleton at position 12.
## Records first-time recipe discoveries, tracks milestones, evaluates epilogue
## conditions, and provides save/load serialization for the unlock tree state.
##
## This is a pure observer: it records what the player has discovered but never
## gates card spawning, blocks signals, or modifies other systems.
##
## NOTE: class_name is intentionally omitted. Godot 4 does not allow a script
## registered as an autoload singleton to also declare a class_name matching
## its autoload name — the engine reports "Class hides an autoload singleton".
## The autoload is accessed globally via the name "MysteryUnlockTree" assigned
## in project.godot.
##
## Implements: design/gdd/mystery-unlock-tree.md
## Stories: story-001-discovery-fsm, story-002-milestones-epilogue,
##          story-003-save-load-bypass
## ADR: ADR-003 (EventBus signals), ADR-004 (autoload position, pure observer),
##      ADR-005 (typed Resource config, debug-config exclusion)
extends Node


# ── State machine ─────────────────────────────────────────────────────────────

## Internal state enum. Starts INACTIVE; transitions driven by scene lifecycle
## signals. EPILOGUE is a terminal state.
##
## Transition table:
##   INACTIVE       --scene_started-->    ACTIVE
##   ACTIVE         --scene_started-->    ACTIVE  (re-enter same or new scene)
##   ACTIVE         --scene_completed-->  TRANSITIONING
##   TRANSITIONING  --scene_started-->    ACTIVE
##   * (non-EPILOGUE) --epilogue_started--> EPILOGUE
enum _State { INACTIVE, ACTIVE, TRANSITIONING, EPILOGUE }

var _state: _State = _State.INACTIVE


# ── Primary discovery storage ──────────────────────────────────────────────

## recipe_id → { order: int, scene_id: String, template: String,
##               card_id_a: String, card_id_b: String }
## First-writer-wins; duplicates are silently discarded.
var _discovered_recipes: Dictionary = {}

## Monotonically increasing counter. Incremented on each first-time discovery.
## Used for milestone threshold comparison.
var _discovery_order_counter: int = 0

## The scene_id active when combination_executed fires.
var _active_scene_id: String = ""


# ── Secondary indices ─────────────────────────────────────────────────────

## scene_id → Array[String] of recipe_ids discovered in that scene.
## Values are typed arrays: Array([], TYPE_STRING, "", null).
var _scene_discoveries: Dictionary = {}

## card_id → scene_id of the scene where the card first appeared in a discovery.
## First-writer-wins.
var _cards_in_discoveries: Dictionary = {}


# ── Milestone state (Story 002) ───────────────────────────────────────────

## Raw percentage thresholds loaded from config.
var _milestone_pct: Array[float] = [0.15, 0.50, 0.80]

## Resolved absolute discovery counts (de-duplicated, ascending).
var _milestone_thresholds: Array[int] = []

## Parallel to _milestone_thresholds. True when that threshold has already fired.
var _fired_milestones: Array[bool] = []

## Recipe IDs required for the epilogue final memory check.
var _epilogue_required_ids: Array[String] = []

## Whether epilogue_conditions_met has already been emitted this session.
var _epilogue_conditions_emitted: bool = false

## Whether final_memory_ready has been earned (set on epilogue_started).
var _final_memory_earned: bool = false

## Fraction of epilogue-required recipes needed to trigger epilogue_conditions_met.
## 0.0 suppresses the mid-session check; final_memory_ready still fires on
## epilogue_started.
var _partial_threshold: float = 0.80


# ── Save/load + debug bypass (Story 003) ─────────────────────────────────

## When true, milestone and epilogue evaluations are skipped. Used only during
## force_unlock_all bulk-fill to suppress all discovery signals.
var _suppress_signals: bool = false

## Test seam: injected config values from unit tests (overrides file load).
var _injected_config: Variant = null  # null or MutConfig resource

## Test seam: injected debug config from unit tests (overrides file load).
var _injected_debug_config: Variant = null  # null, false, or DebugConfig resource


# ── Lifecycle ─────────────────────────────────────────────────────────────

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_config()
	_resolve_milestones()
	_run_force_unlock_all()
	_connect_signals()


# ── Config loading ────────────────────────────────────────────────────────

## Loads MutConfig and EpilogueRequirements resources. If either is absent the
## inline defaults are used (MutConfig) or epilogue signals are suppressed
## (EpilogueRequirements). _inject_config() allows tests to bypass file I/O.
func _load_config() -> void:
	# MutConfig — use injected value or load from file; null falls back to defaults.
	var config: MutConfig
	if _injected_config != null:
		config = _injected_config as MutConfig
	else:
		config = ResourceLoader.load("res://assets/data/mut-config.tres") as MutConfig

	if config != null:
		_milestone_pct = config.milestone_pct.duplicate()
		_partial_threshold = config.partial_threshold

	# EpilogueRequirements — absent or empty suppresses both epilogue signals.
	var epi_res: EpilogueRequirements
	if _injected_config != null:
		# When config is injected for tests, epilogue-requirements is loaded from
		# file unless overridden via _inject_debug_config (which only covers debug).
		# Load normally so tests that don't need epilogue work without extra seams.
		epi_res = ResourceLoader.load(
				"res://assets/data/epilogue-requirements.tres") as EpilogueRequirements
	else:
		epi_res = ResourceLoader.load(
				"res://assets/data/epilogue-requirements.tres") as EpilogueRequirements

	if epi_res == null:
		push_error("MUT: epilogue-requirements.tres missing — suppressing epilogue signals")
		_epilogue_required_ids = []
		return

	_epilogue_required_ids = epi_res.recipe_ids.duplicate()
	if _epilogue_required_ids.is_empty():
		push_error("MUT: epilogue-requirements.tres is empty — suppressing epilogue signals")


## Resolves _milestone_pct float values to absolute discovery counts, then
## de-duplicates the resulting thresholds. Called once in _ready().
func _resolve_milestones() -> void:
	var R_authored: int = RecipeDatabase.get_recipe_count()
	if R_authored == 0:
		push_error("MUT: R_authored == 0 — skipping milestone resolution")
		_milestone_thresholds = []
		return

	var raw: Array[int] = []
	for p: float in _milestone_pct:
		raw.append(maxi(1, ceili(p * R_authored)))

	# De-duplicate: keep first occurrence of each unique threshold value.
	var seen: Dictionary = {}
	_milestone_thresholds = []
	for i: int in raw.size():
		if raw[i] not in seen:
			seen[raw[i]] = true
			_milestone_thresholds.append(raw[i])
		else:
			push_warning(
				"MUT: milestone_pct[%d] resolved to duplicate threshold %d — dropped"
				% [i, raw[i]])

	_fired_milestones.resize(_milestone_thresholds.size())
	_fired_milestones.fill(false)


## Runs the force_unlock_all dev bypass if debug-config.tres is present and its
## flag is set. Suppresses all signals during bulk-fill. Called after RecipeDB
## is available (after _resolve_milestones). In release builds the file is
## excluded from the export, so ResourceLoader.load returns null → no bypass.
func _run_force_unlock_all() -> void:
	var debug_cfg: DebugConfig
	if _injected_debug_config != null:
		debug_cfg = _injected_debug_config as DebugConfig
	else:
		debug_cfg = ResourceLoader.load(
				"res://assets/data/debug-config.tres") as DebugConfig

	if debug_cfg == null or not debug_cfg.force_unlock_all:
		return

	_suppress_signals = true
	var recipes: Array[String] = RecipeDatabase.get_all_recipe_ids()
	_scene_discoveries["__debug__"] = Array([], TYPE_STRING, "", null)
	for rid: String in recipes:
		if rid not in _discovered_recipes:
			_discovery_order_counter += 1
			_discovered_recipes[rid] = {
				"order": _discovery_order_counter,
				"scene_id": "__debug__",
				"template": "",
				"card_id_a": "",
				"card_id_b": "",
			}
			_scene_discoveries["__debug__"].append(rid)

	_discovery_order_counter = RecipeDatabase.get_recipe_count()
	_epilogue_conditions_emitted = true
	_final_memory_earned = true
	_suppress_signals = false
	push_warning(
		"MUT: force_unlock_all active — %d recipes bulk-marked (DEV ONLY)"
		% _discovery_order_counter)


# ── Signal wiring ─────────────────────────────────────────────────────────

func _connect_signals() -> void:
	EventBus.scene_started.connect(_on_scene_started)
	EventBus.scene_completed.connect(_on_scene_completed)
	EventBus.epilogue_started.connect(_on_epilogue_started)
	EventBus.combination_executed.connect(_on_combination_executed)
	# recipe_discovered is an output signal — MUT emits it, not listens to it.


# ── State machine handlers ────────────────────────────────────────────────

## scene_started: Inactive or Transitioning → Active.
## Sets the active scene and initialises a typed discovery array for the scene.
func _on_scene_started(scene_id: String) -> void:
	_active_scene_id = scene_id
	_state = _State.ACTIVE
	if scene_id not in _scene_discoveries:
		_scene_discoveries[scene_id] = Array([], TYPE_STRING, "", null)


## scene_completed: Active → Transitioning (only if scene_id matches).
## Mismatching scene_id is silently ignored.
func _on_scene_completed(scene_id: String) -> void:
	if _state == _State.ACTIVE and scene_id == _active_scene_id:
		_state = _State.TRANSITIONING


## epilogue_started: any non-terminal state → Epilogue (terminal).
## Logs a warning if coming from Active (scene not properly completed first).
## Evaluates final_memory_ready at this point.
func _on_epilogue_started() -> void:
	if _state == _State.ACTIVE:
		push_warning("MUT: epilogue_started received while still Active — scene may not have completed")
	if _state == _State.EPILOGUE:
		return
	_state = _State.EPILOGUE

	if _epilogue_required_ids.is_empty():
		return

	var R_found: int = _count_epilogue_found()
	var threshold: int = ceili(_epilogue_required_ids.size() * _partial_threshold)
	if R_found >= threshold:
		_final_memory_earned = true
		EventBus.final_memory_ready.emit()


## combination_executed: 6-param handler required by Godot 4.3 arity rules.
## Only processes in Active state; silently ignores duplicates.
##
## Param order per EventBus declaration:
##   combination_executed(recipe_id, template, instance_id_a, instance_id_b,
##                        card_id_a, card_id_b)
func _on_combination_executed(
		recipe_id: String, _template: String,
		_iid_a: String, _iid_b: String,
		card_id_a: String, card_id_b: String) -> void:

	if _state != _State.ACTIVE:
		return

	# Duplicate: silently discard — no counter change, no signal.
	if recipe_id in _discovered_recipes:
		return

	# Unknown recipe: warn and skip.
	if not RecipeDatabase.has_recipe(recipe_id):
		push_warning("MUT: unknown recipe_id '%s' — skipping" % recipe_id)
		return

	# Record the discovery.
	_discovery_order_counter += 1
	_discovered_recipes[recipe_id] = {
		"order": _discovery_order_counter,
		"scene_id": _active_scene_id,
		"template": _template,
		"card_id_a": card_id_a,
		"card_id_b": card_id_b,
	}
	_scene_discoveries[_active_scene_id].append(recipe_id)

	# Update card index (first-writer-wins; skip empty ids with a warning).
	if card_id_a != "":
		if card_id_a not in _cards_in_discoveries:
			_cards_in_discoveries[card_id_a] = _active_scene_id
	else:
		push_warning("MUT: empty card_id_a in combination_executed for recipe '%s'" % recipe_id)

	if card_id_b != "":
		if card_id_b not in _cards_in_discoveries:
			_cards_in_discoveries[card_id_b] = _active_scene_id
	else:
		push_warning("MUT: empty card_id_b in combination_executed for recipe '%s'" % recipe_id)

	# Emit recipe_discovered BEFORE milestone/epilogue so listeners see the
	# discovery before any downstream conditions are evaluated.
	EventBus.recipe_discovered.emit(recipe_id, card_id_a, card_id_b, _active_scene_id)

	if not _suppress_signals:
		_evaluate_milestones()
		_evaluate_epilogue_conditions()


# ── Milestone + epilogue evaluation ──────────────────────────────────────

## Checks whether _discovery_order_counter just crossed any unfired threshold.
## Milestones are evaluated in ascending index order (GDD Rule 8 before Rule 9).
## Each threshold fires at most once per session.
func _evaluate_milestones() -> void:
	for i: int in _milestone_thresholds.size():
		if not _fired_milestones[i] and _discovery_order_counter == _milestone_thresholds[i]:
			_fired_milestones[i] = true
			EventBus.discovery_milestone_reached.emit(
				"milestone_" + str(i), _discovery_order_counter)


## Emits epilogue_conditions_met when the partial_threshold is crossed.
## Fires at most once per session. Suppressed when partial_threshold == 0.0
## or _epilogue_required_ids is empty.
func _evaluate_epilogue_conditions() -> void:
	if _epilogue_required_ids.is_empty():
		return
	if _partial_threshold == 0.0:
		return
	if _epilogue_conditions_emitted:
		return

	var R_found: int = _count_epilogue_found()
	var threshold: int = ceili(_epilogue_required_ids.size() * _partial_threshold)
	if R_found >= threshold:
		_epilogue_conditions_emitted = true
		EventBus.epilogue_conditions_met.emit()


## Counts how many epilogue-required recipe_ids have been discovered.
func _count_epilogue_found() -> int:
	var count: int = 0
	for r: String in _epilogue_required_ids:
		if r in _discovered_recipes:
			count += 1
	return count


# ── Public query API (side-effect-free) ───────────────────────────────────

## Returns true if [param recipe_id] has been discovered in this session.
##
## Usage example:
##   if MysteryUnlockTree.is_recipe_discovered("chester-rainy-afternoon"):
##       print("already found")
func is_recipe_discovered(recipe_id: String) -> bool:
	return recipe_id in _discovered_recipes


## Returns the total number of unique recipes discovered so far.
##
## Usage example:
##   var count: int = MysteryUnlockTree.get_discovery_count()
func get_discovery_count() -> int:
	return _discovery_order_counter


## Returns the Array[String] of recipe_ids discovered in [param scene_id].
## Returns an empty array if the scene has not been visited.
##
## Usage example:
##   var ids: Array = MysteryUnlockTree.get_scene_discoveries("scene-01")
func get_scene_discoveries(scene_id: String) -> Array:
	return _scene_discoveries.get(scene_id, [])


## Returns the 5-field record dict for [param recipe_id], or an empty Dictionary
## if the recipe has not been discovered yet.
## Fields: order, scene_id, template, card_id_a, card_id_b.
##
## Usage example:
##   var rec: Dictionary = MysteryUnlockTree.get_discovery_record("ju-our-cafe")
func get_discovery_record(recipe_id: String) -> Dictionary:
	return _discovered_recipes.get(recipe_id, {})


## Returns true if [param card_id] appeared in any recorded discovery.
##
## Usage example:
##   if MysteryUnlockTree.is_card_in_discovery("chester"):
##       print("chester contributed to a recipe")
func is_card_in_discovery(card_id: String) -> bool:
	return card_id in _cards_in_discoveries


## Returns true when final_memory_ready has been earned (set on epilogue_started).
## Used by FinalEpilogueScreen to decide which ending to show.
##
## Usage example:
##   if MysteryUnlockTree.is_final_memory_earned():
##       show_full_epilogue()
func is_final_memory_earned() -> bool:
	return _final_memory_earned


## Returns the qualifying card_ids from [param carry_forward_spec] — entries
## whose requires_recipes are all in _discovered_recipes.
## An entry with an empty requires_recipes list is vacuously eligible.
##
## [param carry_forward_spec]: Array of Dictionaries with keys:
##   "card_id": String — the card to carry forward
##   "requires_recipes": Array[String] — all must be discovered
##
## Usage example:
##   var cards = MysteryUnlockTree.get_carry_forward_cards([
##       { "card_id": "old-photo", "requires_recipes": ["chester-rainy-afternoon"] }
##   ])
func get_carry_forward_cards(carry_forward_spec: Array) -> Array[String]:
	var result: Array[String] = []
	for entry: Dictionary in carry_forward_spec:
		var eligible: bool = true
		for r_id: String in entry.get("requires_recipes", []):
			if r_id not in _discovered_recipes:
				eligible = false
				break
		if eligible:
			result.append(entry["card_id"])
	return result


# ── Save / load API (Story 003) ───────────────────────────────────────────

## Returns a deep-copied, serializable snapshot of the unlock tree state.
## No signals emitted; no mutations.
##
## Fields: discovered_recipes, scene_discoveries, cards_in_discoveries,
##         epilogue_conditions_emitted, final_memory_earned.
##
## Usage example:
##   var data: Dictionary = MysteryUnlockTree.get_save_state()
##   SaveSystem.write("mut", data)
func get_save_state() -> Dictionary:
	return {
		"discovered_recipes": _discovered_recipes.duplicate(true),
		"scene_discoveries": _scene_discoveries.duplicate(true),
		"cards_in_discoveries": _cards_in_discoveries.duplicate(true),
		"epilogue_conditions_emitted": _epilogue_conditions_emitted,
		"final_memory_earned": _final_memory_earned,
	}


## Restores unlock tree state from [param data]. Prunes any recipe_ids that are
## no longer in RecipeDatabase (stale entries from an older save), logs a
## warning per pruned entry, and recalculates _discovery_order_counter.
##
## NOTE: Actual persistence (file write/read) is deferred — no SaveSystem
## autoload exists yet. Call get_save_state() / load_save_state() via
## whatever persistence layer is available. Tracked in: story-003 deferral.
##
## Usage example:
##   var data: Dictionary = SaveSystem.read("mut")
##   MysteryUnlockTree.load_save_state(data)
func load_save_state(data: Dictionary) -> void:
	_discovered_recipes = data.get("discovered_recipes", {}).duplicate(true)
	_scene_discoveries = data.get("scene_discoveries", {}).duplicate(true)
	_cards_in_discoveries = data.get("cards_in_discoveries", {}).duplicate(true)
	_epilogue_conditions_emitted = data.get("epilogue_conditions_emitted", false)
	_final_memory_earned = data.get("final_memory_earned", false)
	_prune_stale_recipes()
	_recalculate_counter()


## Removes recipe_ids from all three dictionaries that are no longer in
## RecipeDatabase. Called by load_save_state() after restore.
func _prune_stale_recipes() -> void:
	var stale: Array[String] = []
	for rid: String in _discovered_recipes.keys():
		if not RecipeDatabase.has_recipe(rid):
			stale.append(rid)

	for rid: String in stale:
		push_warning("MUT: pruning stale recipe_id '%s' from save state" % rid)
		_discovered_recipes.erase(rid)
		for scene_id: String in _scene_discoveries.keys():
			_scene_discoveries[scene_id].erase(rid)
		# _cards_in_discoveries maps card_id → scene_id, not recipe_id → scene_id.
		# The card entries remain (the card itself is still valid); only recipes
		# are pruned. This is consistent with the ADR.


## Recalculates _discovery_order_counter to equal the number of surviving
## entries after pruning. Called by load_save_state() after _prune_stale_recipes().
func _recalculate_counter() -> void:
	_discovery_order_counter = _discovered_recipes.size()


# ── Test seams ────────────────────────────────────────────────────────────

## Injects a MutConfig resource or null for unit testing.
## Must be called before _ready() (or before _load_config() is called).
##
## Usage example (test):
##   mut._inject_config(my_config)
##   mut._ready()
func _inject_config(config: Variant) -> void:
	_injected_config = config


## Injects a DebugConfig resource or null for unit testing.
## Must be called before _ready() (or before _run_force_unlock_all() is called).
##
## Usage example (test):
##   mut._inject_debug_config(my_debug_cfg)
##   mut._ready()
func _inject_debug_config(config: Variant) -> void:
	_injected_debug_config = config
