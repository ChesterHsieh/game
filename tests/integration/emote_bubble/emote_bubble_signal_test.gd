## Integration test for Emote Bubble signal + handler wiring — Story 007.
##
## Covers the auto-testable acceptance criteria:
##   AC-1: EventBus.emote_requested signal exists with the right shape
##   AC-3: EmoteHandler, on _ready(), connects to emote_requested and
##         spawns an EmoteBubble child when the signal fires
##   AC-4: EmoteBubble self-frees after its animation completes
##   AC-5: Animation timing exported vars have the spec values
##   AC-6: Missing PNG → push_warning + immediate self-free, no crash
##   AC-7: Multiple emotes coexist under EmoteHandler
##
## AC-2 (ITF emits on config.emote) and AC-9 (coffee-intro smoke) are
## covered by manual evidence — see
## production/qa/evidence/emote-bubble-render-evidence.md.
extends GdUnitTestSuite

const EmoteBubbleScript := preload("res://src/ui/emote_bubble.gd")
const EmoteHandlerScript := preload("res://src/ui/emote_handler.gd")

# Full animation duration from the spec: 0.15 + 1.2 + 0.25 = 1.6s.
# Wait a bit longer than that to let queue_free() actually run.
const FULL_ANIM_SEC := 1.6
const FULL_ANIM_MS  := 1700


# ── AC-1: signal exists ───────────────────────────────────────────────────────

func test_event_bus_emote_requested_signal_exists() -> void:
	# Act + Assert
	assert_bool(EventBus.has_signal("emote_requested")) \
		.override_failure_message("EventBus must declare emote_requested signal") \
		.is_true()


# ── AC-5: timing knobs are the spec values ───────────────────────────────────

func test_emote_bubble_timing_knobs_match_spec() -> void:
	# Arrange
	var bubble: EmoteBubble = EmoteBubbleScript.new()

	# Assert
	assert_float(bubble.pop_in_sec) \
		.override_failure_message("pop_in_sec must default to 0.15") \
		.is_equal(0.15)
	assert_float(bubble.hold_sec) \
		.override_failure_message("hold_sec must default to 1.2") \
		.is_equal(1.2)
	assert_float(bubble.fade_out_sec) \
		.override_failure_message("fade_out_sec must default to 0.25") \
		.is_equal(0.25)

	bubble.free()


# ── AC-3 + AC-4: handler spawns bubble, bubble self-frees ────────────────────

func test_emote_handler_spawns_bubble_on_signal() -> void:
	# Arrange
	var handler: Node2D = EmoteHandlerScript.new()
	add_child(handler)
	# _ready will connect to EventBus.emote_requested

	# Act
	EventBus.emote_requested.emit("spark", Vector2(100, 200))
	await get_tree().process_frame

	# Assert: EmoteHandler got a child EmoteBubble
	var bubble_count := 0
	for child in handler.get_children():
		if child is EmoteBubble:
			bubble_count += 1
	assert_int(bubble_count) \
		.override_failure_message("EmoteHandler must spawn exactly one EmoteBubble child") \
		.is_equal(1)

	# Cleanup: disconnect to avoid leaking into other tests
	EventBus.emote_requested.disconnect(handler._on_emote_requested)
	handler.free()


func test_emote_bubble_self_frees_after_animation() -> void:
	# Arrange
	var handler: Node2D = EmoteHandlerScript.new()
	add_child(handler)

	# Act
	EventBus.emote_requested.emit("spark", Vector2.ZERO)
	await get_tree().process_frame

	# Wait out the full 1.6s animation
	await get_tree().create_timer(FULL_ANIM_SEC + 0.1).timeout

	# Assert: bubble freed
	var bubble_count := 0
	for child in handler.get_children():
		if child is EmoteBubble:
			bubble_count += 1
	assert_int(bubble_count) \
		.override_failure_message("EmoteBubble must self-free after animation completes") \
		.is_equal(0)

	EventBus.emote_requested.disconnect(handler._on_emote_requested)
	handler.free()


# ── AC-6: missing PNG tolerated ──────────────────────────────────────────────

func test_emote_bubble_missing_png_self_frees_without_crash() -> void:
	# Arrange
	var handler: Node2D = EmoteHandlerScript.new()
	add_child(handler)

	# Act: fire with a guaranteed-missing name
	EventBus.emote_requested.emit("nonexistent_emote_xyz", Vector2.ZERO)
	await get_tree().process_frame
	await get_tree().process_frame  # queue_free runs on deferred

	# Assert: no lingering bubble, no crash
	var bubble_count := 0
	for child in handler.get_children():
		if child is EmoteBubble:
			bubble_count += 1
	assert_int(bubble_count) \
		.override_failure_message("Missing-PNG bubble must self-free on the same frame") \
		.is_equal(0)

	EventBus.emote_requested.disconnect(handler._on_emote_requested)
	handler.free()


# ── AC-7: multiple coexisting emotes ─────────────────────────────────────────

func test_emote_handler_supports_multiple_concurrent_bubbles() -> void:
	# Arrange
	var handler: Node2D = EmoteHandlerScript.new()
	add_child(handler)

	# Act: fire two in quick succession
	EventBus.emote_requested.emit("spark", Vector2(10, 10))
	EventBus.emote_requested.emit("heart", Vector2(50, 50))
	await get_tree().process_frame

	# Assert: both bubbles exist simultaneously
	var bubble_count := 0
	for child in handler.get_children():
		if child is EmoteBubble:
			bubble_count += 1
	assert_int(bubble_count) \
		.override_failure_message("Two recipes firing in quick succession must spawn two bubbles") \
		.is_equal(2)

	EventBus.emote_requested.disconnect(handler._on_emote_requested)
	handler.free()
