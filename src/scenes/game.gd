## GameScene — top-level production scene controller.
## Loads the "home" scene, spawns seed cards, connects the presentation layer.

extends Node2D

const TABLE_COLOR := Color(0.22, 0.18, 0.15, 1.0)  ## warm dark brown table

@onready var _status_bar_ui: Node2D = $StatusBarUI


func _ready() -> void:
	SceneGoal.seed_cards_ready.connect(_on_seed_cards_ready)
	SceneGoal.load_scene("home")


func _draw() -> void:
	draw_rect(get_viewport().get_visible_rect(), TABLE_COLOR)


func _on_seed_cards_ready(seed_cards: Array) -> void:
	_status_bar_ui.configure_for_scene()
	CardSpawning.spawn_seed_cards(seed_cards, 42)
