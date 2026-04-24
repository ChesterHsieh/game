## InteractionTemplateFramework — resolves combination_attempted into template execution.
## Autoload singleton. Sole listener of CardEngine.combination_attempted.
## MVP: Additive and Merge templates only. Animate/Generator deferred.

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


# ── Setup ─────────────────────────────────────────────────────────────────────

func _ready() -> void:
	CardEngine.combination_attempted.connect(_on_combination_attempted)
	CardEngine.merge_complete.connect(_on_merge_complete)


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
		"animate", "generator":
			# These templates are documented but not yet wired end-to-end; treat
			# as a no-op success so the tutorial path doesn't bounce.
			CardEngine.on_combination_succeeded(instance_id_a, instance_id_b, template.capitalize(), config)
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

	# Catalyst semantics: `keeps` (StringName card_id) names the card that
	# stays on the table. The other is consumed. Default (no `keeps`) is the
	# classic merge — both cards consumed. CardEngine's `_begin_merge` was
	# already told about `keeps` and skipped the catalyst's merge-animate,
	# so the kept node is untouched; we only need to remove the consumed side.
	var keeps_card_id: String = String(config.get("keeps", ""))
	var kept_node: Node2D = null
	if keeps_card_id != "" and _base_card_id(instance_id_a) == keeps_card_id:
		kept_node = CardSpawning.get_card_node(instance_id_a)
		CardSpawning.remove_card(instance_id_b)
	elif keeps_card_id != "" and _base_card_id(instance_id_b) == keeps_card_id:
		kept_node = CardSpawning.get_card_node(instance_id_b)
		CardSpawning.remove_card(instance_id_a)
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
	# StatusBarSystem and HintSystem are not notified.
	_last_fired[recipe["id"]] = Time.get_ticks_msec() / 1000.0


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


## Strips the "_N" instance suffix: "chester_0" → "chester"
static func _base_card_id(instance_id: String) -> String:
	var idx := instance_id.rfind("_")
	if idx == -1:
		return instance_id
	return instance_id.left(idx)


func _get_layout() -> Node:
	return CardSpawning._table_layout
