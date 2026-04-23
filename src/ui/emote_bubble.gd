## EmoteBubble — RO-style thought bubble popped up after a fired recipe.
##
## Pure presentation node. Does NOT subscribe to any signal — EmoteHandler
## calls the [method spawn] factory when [signal EventBus.emote_requested]
## fires. Self-frees when its pop-in → hold → fade-out tween completes.
##
## Timing knobs are exported so individual bubbles (or variants) can be
## tuned without touching code. See ADR-003 (signal bus) for why the
## subscription lives on EmoteHandler rather than here.
##
## Usage:
##     EmoteBubble.spawn(parent, world_pos, "spark")
class_name EmoteBubble extends Node2D

@export var pop_in_sec: float = 0.15
@export var hold_sec: float = 1.2
@export var fade_out_sec: float = 0.25
@export var size_logical: Vector2 = Vector2(80.0, 80.0)

@onready var _rect: TextureRect = $TextureRect


## Factory: creates an EmoteBubble at [param world_pos] showing
## [param emote_name]. Adds itself to [param parent]. Self-frees when its
## animation completes. Returns the bubble so callers can override knobs
## before the tween starts if they need to (MVP: nobody does).
static func spawn(parent: Node, world_pos: Vector2, emote_name: String) -> EmoteBubble:
	var bubble: EmoteBubble = preload("res://src/ui/emote_bubble.tscn").instantiate()
	parent.add_child(bubble)
	bubble.position = world_pos
	bubble.play(emote_name)
	return bubble


## Loads the emote PNG and runs the pop-in → hold → fade-out tween.
## If the PNG is missing, warns and self-frees without a visual glitch.
func play(emote_name: String) -> void:
	var path := "res://assets/emotes/%s.png" % emote_name
	var tex: Texture2D = load(path) as Texture2D
	if tex == null:
		push_warning("EmoteBubble: missing '%s'" % path)
		queue_free()
		return

	_rect.texture = tex
	_rect.custom_minimum_size = size_logical
	_rect.size = size_logical
	_rect.pivot_offset = size_logical * 0.5
	_rect.position = -size_logical * 0.5  # centre on Node2D origin

	# Pop-in scale on the TextureRect (so pivot works), modulate fade on self.
	_rect.scale = Vector2.ZERO
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_rect, "scale", Vector2.ONE, pop_in_sec)
	tw.tween_interval(hold_sec)
	tw.tween_property(self, "modulate:a", 0.0, fade_out_sec).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(queue_free)
