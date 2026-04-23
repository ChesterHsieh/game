## EmoteHandler — subscribes to [signal EventBus.emote_requested] and
## spawns an [EmoteBubble] at the given world position.
##
## Sole subscriber for that signal, per ADR-003 (signal bus). EmoteBubble
## itself stays a pure presentation node; all the signal plumbing lives
## here so the spawn site can be swapped, rate-limited, or stacked later
## without changing the bubble.
##
## Mounted inside the EmoteLayer CanvasLayer in gameplay.tscn (layer=7).
## Intentionally tiny — no filtering, no rate-limiting, no stacking rules
## in MVP. Multiple requests each spawn their own bubble.
extends Node2D


func _ready() -> void:
	EventBus.emote_requested.connect(_on_emote_requested)


func _on_emote_requested(emote_name: String, world_pos: Vector2) -> void:
	EmoteBubble.spawn(self, world_pos, emote_name)
