## InteractionTemplateFramework — resolves combination_attempted into template execution.
## Autoload singleton. Sole listener of CardEngine.combination_attempted.
## Implements: Additive, Merge, Reject, Generator templates.
## Design doc: design/scenes/drive.md (Story 006 — Generator template)

extends Node

# ── Signals ───────────────────────────────────────────────────────────────────

## Broadcast after every successful template execution.
## Consumed by StatusBarSystem and HintSystem.
signal combination_executed(recipe_id: String, template: String,
		instance_id_a: String, instance_id_b: String)

# ── Tuning ────────────────────────────────────────────────────────────────────

## How long before the same recipe can fire again.
const COMBINATION_COOLDOWN_SEC := 30.0

# ── State ─────────────────────────────────────────────────────────────────────

## Current scene_id — needed to scope RecipeDatabase lookups.
var _scene_id: String = ""

## recipe_id -> float (Time.get_ticks_msec() / 1000 of last fire)
var _last_fired: Dictionary = {}

## Whether ITF is accepting combinations (false during scene transitions).
var _active: bool = true

## Pending merge: instance_id_a -> { instance_id_b, recipe } awaiting merge_complete
var _pending_merges: Dictionary = {}

## Active generators: compound key "%s|%s" % [generator_instance_id, recipe_id]
##   -> { generator_id, non_generator_id, timer: Timer, count: int, max_count, recipe }
## Compound key allows the same card to participate in multiple generators simultaneously
## (AC-5b: same card, two distinct recipe_ids → two distinct keys).
## Populated by _execute_generator(); cleaned up by _deregister_generator().
var _active_generators: Dictionary = {}


# ── Setup ─────────────────────────────────────────────────────────────────────

func _ready() -> void:
	CardEngine.combination_attempted.connect(_on_combination_attempted)
	CardEngine.merge_complete.connect(_on_merge_complete)
	# AC-2: cancel any active generator when its card is removed from the table.
	# DEVIATION (story-006): EventBus.card_removing is declared in event_bus.gd but
	# CardSpawning.remove_card() does not yet emit it. Generator teardown via this
	# signal will be inert until CardSpawning is updated. Flagged for backlog.
	EventBus.card_removing.connect(_on_card_removing)


# ── Public API ────────────────────────────────────────────────────────────────

## Set the active scene — required before any combination can resolve.
func set_scene_id(scene_id: String) -> void:
	_scene_id = scene_id


## Suspend ITF during scene transitions. All attempts are ignored.
func suspend() -> void:
	_active = false


## Resume ITF after scene load completes.
func resume() -> void:
	_active = true


## Reset cooldown timers (called on new scene load).
func reset_cooldowns() -> void:
	_last_fired.clear()


# ── Combination Resolution ────────────────────────────────────────────────────

func _on_combination_attempted(instance_id_a: String, instance_id_b: String) -> void:
	if not _active:
		return

	var card_id_a := _base_card_id(instance_id_a)
	var card_id_b := _base_card_id(instance_id_b)

	var recipe = RecipeDatabase.get_recipe(card_id_a, card_id_b, _scene_id)

	if recipe == null:
		CardEngine.on_combination_failed(instance_id_a, instance_id_b)
		return

	if _is_on_cooldown(recipe["id"]):
		CardEngine.on_combination_failed(instance_id_a, instance_id_b)
		return

	_execute_template(recipe, instance_id_a, instance_id_b)


func _execute_template(recipe: Dictionary, instance_id_a: String, instance_id_b: String) -> void:
	var template: String = String(recipe["template"]).to_lower()
	var config:   Dictionary = recipe.get("config", {})

	match template:
		"additive":
			_execute_additive(recipe, instance_id_a, instance_id_b, config)
		"merge":
			_execute_merge(recipe, instance_id_a, instance_id_b, config)
		"reject":
			_execute_reject(recipe, instance_id_a, instance_id_b, config)
		"animate":
			# Animate template deferred — no-op success so tutorial path doesn't bounce.
			CardEngine.on_combination_succeeded(instance_id_a, instance_id_b, "Animate", config)
		"generator":
			_execute_generator(recipe, instance_id_a, instance_id_b, config)
		_:
			push_warning("ITF: unsupported template '%s' — treating as failed" % template)
			CardEngine.on_combination_failed(instance_id_a, instance_id_b)
			return


# ── Additive ──────────────────────────────────────────────────────────────────

func _execute_additive(recipe: Dictionary, instance_id_a: String, instance_id_b: String,
		config: Dictionary) -> void:
	CardEngine.on_combination_succeeded(instance_id_a, instance_id_b, "Additive", config)

	var node_a := CardSpawning.get_card_node(instance_id_a)
	var node_b := CardSpawning.get_card_node(instance_id_b)
	var combo_point := Vector2(300, 300)  # fallback
	if node_a != null and node_b != null:
		combo_point = (node_a.position + node_b.position) * 0.5

	var occupied := CardSpawning.get_all_card_positions()
	var layout   := _get_layout()

	for spawn_card_id: String in config.get("spawns", []):
		var pos: Vector2 = layout.get_spawn_position(combo_point, occupied, -1)
		CardSpawning.spawn_card(spawn_card_id, pos)
		occupied.append(pos)

	# Catalyst semantics for additive: if `keeps` is declared, the unnamed
	# side(s) are consumed. Absent `keeps` = both cards remain (default — used
	# by spawn-only additives like that-park-nervous → safe).
	var keeps_ids: Array[String] = _keeps_list(config)
	if not keeps_ids.is_empty():
		var card_id_a: String = _base_card_id(instance_id_a)
		var card_id_b: String = _base_card_id(instance_id_b)
		if not (card_id_a in keeps_ids):
			CardSpawning.remove_card(instance_id_a)
		if not (card_id_b in keeps_ids):
			CardSpawning.remove_card(instance_id_b)

	_fire_executed(recipe["id"], "Additive", instance_id_a, instance_id_b)


# ── Merge ─────────────────────────────────────────────────────────────────────

func _execute_merge(recipe: Dictionary, instance_id_a: String, instance_id_b: String,
		config: Dictionary) -> void:
	# CardEngine's match is PascalCase — keep this call string consistent.
	# `config` is passed through so CardEngine can read `keeps` and skip
	# animating the catalyst card.
	CardEngine.on_combination_succeeded(instance_id_a, instance_id_b, "Merge", config)
	# Store pending merge — resolved when merge_complete fires from CardEngine
	_pending_merges[instance_id_a] = {
		"instance_id_b": instance_id_b,
		"recipe":        recipe,
	}


func _on_merge_complete(instance_id_a: String, instance_id_b: String, midpoint: Vector2) -> void:
	if not _pending_merges.has(instance_id_a):
		return

	var pending: Dictionary = _pending_merges[instance_id_a]
	_pending_merges.erase(instance_id_a)

	var recipe: Dictionary = pending["recipe"]
	var config: Dictionary = recipe.get("config", {})

	# Catalyst semantics: `keeps` names which card(s) stay on the table — the
	# rest are consumed. Accepts either a single StringName/String or an Array
	# of them (dual-catalyst recipes). Default (no `keeps`) is the classic
	# merge — both cards consumed. CardEngine's `_begin_merge` was already
	# told about `keeps` and skipped the kept cards' merge-animate, so kept
	# nodes are untouched; we only need to remove the consumed side(s).
	var keeps_ids: Array[String] = _keeps_list(config)
	var card_id_a: String = _base_card_id(instance_id_a)
	var card_id_b: String = _base_card_id(instance_id_b)
	var a_kept: bool = card_id_a in keeps_ids
	var b_kept: bool = card_id_b in keeps_ids
	var kept_node: Node2D = null
	if a_kept and not b_kept:
		kept_node = CardSpawning.get_card_node(instance_id_a)
		CardSpawning.remove_card(instance_id_b)
	elif b_kept and not a_kept:
		kept_node = CardSpawning.get_card_node(instance_id_b)
		CardSpawning.remove_card(instance_id_a)
	elif a_kept and b_kept:
		# Both kept — no removal. Prefer A as the eject-origin anchor.
		kept_node = CardSpawning.get_card_node(instance_id_a)
	else:
		CardSpawning.remove_card(instance_id_a)
		CardSpawning.remove_card(instance_id_b)

	if kept_node != null:
		kept_node.z_index = 0

	var result_card_id: String = String(config.get("result_card", ""))
	if result_card_id != "":
		var occupied := CardSpawning.get_all_card_positions()
		var layout   := _get_layout()
		var pos: Vector2 = layout.get_spawn_position(midpoint, occupied, -1)
		var new_id := CardSpawning.spawn_card(result_card_id, pos)
		# Eject effect: spawn slightly offset from kept-card, then tween to
		# the final position so the product appears to pop out.
		if new_id != "" and kept_node != null:
			var new_node: Node2D = CardSpawning.get_card_node(new_id)
			if new_node != null:
				var launch_from: Vector2 = midpoint
				new_node.position = launch_from
				var eject_tween := new_node.create_tween()
				eject_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				eject_tween.tween_property(new_node, "position", pos, 0.30)

	# Emote reaction — RO-style thought bubble at the merge midpoint.
	# EmoteHandler (gameplay.tscn) listens and spawns the bubble.
	var emote_name: String = String(config.get("emote", "")).to_lower()
	if emote_name != "" and emote_name != "none":
		EventBus.emote_requested.emit(emote_name, midpoint)

	_fire_executed(recipe["id"], "Merge", instance_id_a, instance_id_b)


# ── Reject ────────────────────────────────────────────────────────────────────

func _execute_reject(recipe: Dictionary, instance_id_a: String, instance_id_b: String,
		config: Dictionary) -> void:
	var multiplier: float = float(config.get("repulsion_multiplier", 1.0))

	var node_a := CardSpawning.get_card_node(instance_id_a)
	var node_b := CardSpawning.get_card_node(instance_id_b)

	CardEngine.on_combination_rejected(instance_id_a, instance_id_b, multiplier)

	var emote_name: String = String(config.get("emote", "")).to_lower()
	if emote_name != "" and emote_name != "none" and node_a != null and node_b != null:
		var midpoint: Vector2 = (node_a.position + node_b.position) * 0.5
		EventBus.emote_requested.emit(emote_name, midpoint)

	# Reject is intentionally not scored — skips combination_executed so
	# StatusBarSystem and HintSystem are not notified. Also skips writing
	# _last_fired so the reject can fire every drop (nav-reject must always
	# produce the angry bounce, regardless of how often the player retries).


# ── Generator ─────────────────────────────────────────────────────────────────
## Implements Story 006 — Generator template.
##
## Config keys (all from recipe["config"]):
##   generates    : String  — card_id spawned each tick
##   interval_sec : float   — seconds between spawns
##   max_count    : int|null — total cards to produce; null = unlimited
##   generator_card: "card_a"|"card_b" — which interaction card becomes the generator
##
## Lifecycle:
##   1. combination_attempted → _execute_generator() fires immediately
##   2. combination_executed emitted (AC-3: before first tick)
##   3. A Godot Timer ticks every interval_sec, calling _on_generator_tick()
##   4. Each tick spawns one card; increments count; stops at max_count (AC-1)
##   5. EventBus.card_removing → _on_card_removing() → _deregister_generator() (AC-2)

func _execute_generator(recipe: Dictionary, instance_id_a: String, instance_id_b: String,
		config: Dictionary) -> void:
	# Resolve which instance is the generator card (the one that stays on the table).
	var generator_card_slot: String = String(config.get("generator_card", "card_a")).to_lower()
	var gen_instance_id: String = instance_id_a if generator_card_slot == "card_a" else instance_id_b
	var other_instance_id: String = instance_id_b if gen_instance_id == instance_id_a else instance_id_a

	# Tell CardEngine: combination succeeded — both cards remain on table (AC-3).
	CardEngine.on_combination_succeeded(instance_id_a, instance_id_b, "Generator", config)

	# AC-5a: emit combination_executed BEFORE the first tick fires.
	_fire_executed(recipe["id"], "Generator", instance_id_a, instance_id_b)

	var interval: float = float(config.get("interval_sec", 5.0))
	var max_count: Variant = config.get("max_count", null)

	# AC-5b: Compound key supports the same card participating in two generator recipes
	# simultaneously (e.g., "chester_0|recipe-a" and "chester_0|recipe-b").
	var key: String = "%s|%s" % [gen_instance_id, recipe["id"]]

	# Build a Godot Timer owned by this node so it auto-cleans on queue_free().
	var timer := Timer.new()
	timer.wait_time = interval
	timer.one_shot = false
	add_child(timer)

	# AC-4b: store non_generator_id so _on_card_removing can cancel if EITHER card leaves.
	_active_generators[key] = {
		"generator_id":     gen_instance_id,
		"non_generator_id": other_instance_id,
		"timer":            timer,
		"count":            0,
		"max_count":        max_count,
		"recipe":           recipe,
	}

	# Bind the tick handler with the compound key for lookup.
	timer.timeout.connect(_on_generator_tick.bind(key))
	timer.start()


## Called every interval_sec by the Timer owned by this generator entry.
## Spawns one card; stops the timer if max_count is reached (AC-1, AC-2).
## key: compound key "%s|%s" % [generator_instance_id, recipe_id]
func _on_generator_tick(key: String) -> void:
	if not _active_generators.has(key):
		return

	var entry: Dictionary = _active_generators[key]
	var recipe: Dictionary = entry["recipe"]
	var config: Dictionary = recipe.get("config", {})
	var max_count: Variant = entry["max_count"]

	# AC-2: max_count null means unlimited — skip the exhaustion check.
	if max_count != null and entry["count"] >= int(max_count):
		_deregister_generator(key)
		return

	# Spawn the generated card near the generator card's current position.
	# Edge case: if generator card node is null at tick time (removed mid-frame before
	# signal dispatched), skip spawn for this tick — card_removing will deregister shortly.
	var gen_node := CardSpawning.get_card_node(entry["generator_id"])
	var origin := Vector2(300, 300)  # fallback if node not found
	if gen_node != null:
		origin = gen_node.position

	var occupied := CardSpawning.get_all_card_positions()
	var layout   := _get_layout()
	var pos: Vector2 = layout.get_spawn_position(origin, occupied, -1)
	CardSpawning.spawn_card(String(config.get("generates", "")), pos)

	entry["count"] += 1

	# AC-1: stop after max_count cards have been produced.
	if max_count != null and entry["count"] >= int(max_count):
		_deregister_generator(key)


## Stop and remove a generator entry by compound key. Safe to call if key is absent.
## key: compound key "%s|%s" % [generator_instance_id, recipe_id]
func _deregister_generator(key: String) -> void:
	if not _active_generators.has(key):
		return

	var entry: Dictionary = _active_generators[key]
	var timer: Timer = entry["timer"]
	timer.stop()
	timer.queue_free()
	_active_generators.erase(key)


## AC-4: Called when any card is removed from the table. Cancels every generator
## entry where the removed card is EITHER the generator_id OR the non_generator_id.
## Two-phase (collect-then-erase) to avoid mutating the dict during iteration.
## NOTE: EventBus.card_removing is currently not emitted by CardSpawning.remove_card().
## This handler is wired and correct, but won't fire until CardSpawning is updated.
func _on_card_removing(instance_id: String) -> void:
	var keys_to_remove: Array[String] = []
	for key: String in _active_generators.keys():
		var entry: Dictionary = _active_generators[key]
		if entry["generator_id"] == instance_id or entry["non_generator_id"] == instance_id:
			keys_to_remove.append(key)
	for key: String in keys_to_remove:
		_deregister_generator(key)


# ── Helpers ───────────────────────────────────────────────────────────────────

func _fire_executed(recipe_id: String, template: String,
		instance_id_a: String, instance_id_b: String) -> void:
	_last_fired[recipe_id] = Time.get_ticks_msec() / 1000.0
	combination_executed.emit(recipe_id, template, instance_id_a, instance_id_b)


func _is_on_cooldown(recipe_id: String) -> bool:
	if not _last_fired.has(recipe_id):
		return false
	var elapsed: float = Time.get_ticks_msec() / 1000.0 - float(_last_fired[recipe_id])
	return elapsed < COMBINATION_COOLDOWN_SEC


## Normalize the `keeps` config value into a list of card_ids.
## Accepts String, StringName, or Array of either. Absent → empty list.
static func _keeps_list(config: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var raw: Variant = config.get("keeps", null)
	if raw == null:
		return out
	if raw is Array:
		for item: Variant in raw:
			var s: String = String(item)
			if s != "":
				out.append(s)
	else:
		var s: String = String(raw)
		if s != "":
			out.append(s)
	return out


## Strips the "_N" instance suffix: "chester_0" → "chester"
static func _base_card_id(instance_id: String) -> String:
	var idx := instance_id.rfind("_")
	if idx == -1:
		return instance_id
	return instance_id.left(idx)


func _get_layout() -> Node:
	return CardSpawning._table_layout
