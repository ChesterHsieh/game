## CardSpawning — sole authority for creating and removing card nodes.
## Autoload singleton. Assigns unique instance IDs and maintains the live card registry.
## Registers/unregisters nodes with InputSystem so they become draggable immediately.

extends Node

const CARD_NODE_SCENE := "res://src/gameplay/card_node.tscn"

# ── Signals ───────────────────────────────────────────────────────────────────

signal card_spawned(instance_id: String, card_id: String, position: Vector2)
signal card_removed(instance_id: String)

# ── Registry ──────────────────────────────────────────────────────────────────

# instance_id -> Node2D
var _live_cards: Dictionary = {}

# card_id -> int (next counter value, never reused)
var _counters: Dictionary = {}

# Preloaded scene
var _card_scene: PackedScene = null

# Table layout — instantiated once, used for position queries
var _table_layout: Node = null


# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	_card_scene   = load(CARD_NODE_SCENE)
	_table_layout = load("res://src/gameplay/table_layout_system.gd").new()
	add_child(_table_layout)


# ── Public API ────────────────────────────────────────────────────────────────

## Spawns a card with [param card_id] at [param position].
## Validates card_id against CardDatabase. Returns the assigned instance_id.
func spawn_card(card_id: String, position: Vector2) -> String:
	if not CardDatabase.has_card(card_id):
		push_error("CardSpawning: cannot spawn unknown card_id '%s'" % card_id)
		return ""

	var instance_id := _next_instance_id(card_id)
	var node: Node2D = _card_scene.instantiate()
	node.instance_id = instance_id
	node.card_id     = card_id
	node.position    = position

	get_tree().current_scene.add_child(node)
	_live_cards[instance_id] = node

	# Register with InputSystem — half-size matches card art dimensions (80×120 / 2)
	InputSystem.register_card(instance_id, node, Vector2(40.0, 60.0))

	card_spawned.emit(instance_id, card_id, position)
	return instance_id


## Removes the card with [param instance_id] from the table and frees its node.
func remove_card(instance_id: String) -> void:
	if not _live_cards.has(instance_id):
		push_warning("CardSpawning: remove_card called for unknown instance_id '%s'" % instance_id)
		return

	var node: Node2D = _live_cards[instance_id]
	InputSystem.unregister_card(instance_id)
	_live_cards.erase(instance_id)
	node.queue_free()

	card_removed.emit(instance_id)


## Returns the Node2D for [param instance_id], or null if not found.
func get_card_node(instance_id: String) -> Node2D:
	return _live_cards.get(instance_id, null)


## Returns all live instance IDs.
func get_all_instance_ids() -> Array[String]:
	var ids: Array[String] = []
	for k: String in _live_cards:
		ids.append(k)
	return ids


## Removes all live cards from the table. Idempotent — safe to call on an
## empty table (no-op). Iterates a snapshot of IDs so removal does not
## invalidate the iteration.
##
## Used by SceneManager during scene transitions (ADR-004).
##
## Usage example:
##   CardSpawning.clear_all_cards()
func clear_all_cards() -> void:
	var ids := get_all_instance_ids()
	for id: String in ids:
		remove_card(id)


## Returns world positions of all live cards (for overlap avoidance).
func get_all_card_positions() -> Array[Vector2]:
	var positions: Array[Vector2] = []
	for node: Node2D in _live_cards.values():
		positions.append(node.position)
	return positions


## Spawns seed cards for a scene using TableLayoutSystem for positioning.
## [param seed_cards] is an Array of Dictionaries with at minimum a "card_id" key.
func spawn_seed_cards(seed_cards: Array, rng_seed: int = -1) -> void:
	var positions: Dictionary = _table_layout.get_seed_positions(seed_cards, rng_seed)
	for card_id: String in positions:
		spawn_card(card_id, positions[card_id])


# ── Private ───────────────────────────────────────────────────────────────────

func _next_instance_id(card_id: String) -> String:
	if not _counters.has(card_id):
		_counters[card_id] = 0
	var counter: int = _counters[card_id]
	_counters[card_id] += 1
	return "%s_%d" % [card_id, counter]
