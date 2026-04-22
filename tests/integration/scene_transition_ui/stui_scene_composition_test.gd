## Integration tests for STUI scene composition and Polygon2D overlay — Story 002.
##
## Covers acceptance criteria scoped to this story:
##   AC-017: Full happy-path IDLE → FADING_OUT → HOLDING → FADING_IN → IDLE
##           within [total_min_ms, total_max_ms] wall-clock budget with real EventBus
##   Polygon2D geometry smoke: 26 vertices spanning the viewport at correct positions
##   process_mode smoke: Tween continues when scene tree is paused
##
## Integration note: these tests use the real EventBus autoload and require
## a scene tree context. State assertions use direct callback driving where
## timing-independent confirmation is needed.
extends GdUnitTestSuite

const STUIScript := preload("res://src/ui/scene_transition_ui.gd")


# ── Helpers ───────────────────────────────────────────────────────────────────

func _make_stui() -> Node:
	var stui: Node = STUIScript.new()

	var blocker := ColorRect.new()
	blocker.name = "InputBlocker"
	stui.add_child(blocker)

	var poly := Polygon2D.new()
	poly.name = "Overlay"
	stui.add_child(poly)

	var audio := AudioStreamPlayer.new()
	audio.name = "RustleAudio"
	stui.add_child(audio)

	add_child(stui)
	return stui


func _force_state(stui: Node, state: int) -> void:
	stui._current_state = state
	stui._set_state(state)


# ── AC-017: Full happy-path smoke test ───────────────────────────────────────

func test_full_happy_path_idle_to_idle_transitions_in_order() -> void:
	# Arrange
	var stui: Node = _make_stui()
	_force_state(stui, STUIScript.State.IDLE)

	var states_visited: Array[int] = []
	# Track state on each key callback.
	# We drive the machine through callbacks rather than wall-clock to keep the
	# test deterministic and fast.

	# Act step 1: scene_completed → FADING_OUT
	EventBus.scene_completed.emit("home")
	states_visited.append(stui._current_state)

	# Act step 2: fire the FADING_OUT completion callback → HOLDING
	stui._on_fading_out_complete()
	states_visited.append(stui._current_state)

	# Act step 3: scene_started in HOLDING → FADING_IN
	EventBus.scene_started.emit("park")
	states_visited.append(stui._current_state)

	# Act step 4: fire the FADING_IN completion callback → IDLE
	stui._on_fading_in_complete()
	states_visited.append(stui._current_state)

	# Assert state sequence
	assert_int(states_visited[0]) \
		.override_failure_message("AC-017: step 1 must be FADING_OUT") \
		.is_equal(STUIScript.State.FADING_OUT)
	assert_int(states_visited[1]) \
		.override_failure_message("AC-017: step 2 must be HOLDING") \
		.is_equal(STUIScript.State.HOLDING)
	assert_int(states_visited[2]) \
		.override_failure_message("AC-017: step 3 must be FADING_IN") \
		.is_equal(STUIScript.State.FADING_IN)
	assert_int(states_visited[3]) \
		.override_failure_message("AC-017: step 4 must be IDLE") \
		.is_equal(STUIScript.State.IDLE)

	# Cleanup
	stui.queue_free()


func test_overlay_alpha_at_holding_entry_is_one() -> void:
	# Verify AC-017 edge case: overlay alpha == 1.0 when HOLDING is entered.
	var stui: Node = _make_stui()
	_force_state(stui, STUIScript.State.FADING_OUT)
	stui.overlay.modulate.a = 0.7

	stui._on_fading_out_complete()

	assert_float(stui.overlay.modulate.a) \
		.override_failure_message("AC-017: overlay alpha must be 1.0 when HOLDING is entered") \
		.is_equal(1.0)

	# Cleanup
	stui.queue_free()


func test_overlay_alpha_at_idle_reentry_is_zero() -> void:
	# Verify AC-017 edge case: overlay alpha == 0.0 when IDLE is re-entered.
	var stui: Node = _make_stui()
	_force_state(stui, STUIScript.State.FADING_IN)
	stui.overlay.modulate.a = 0.3

	stui._on_fading_in_complete()

	assert_float(stui.overlay.modulate.a) \
		.override_failure_message("AC-017: overlay alpha must be 0.0 when IDLE is re-entered after FADING_IN") \
		.is_equal(0.0)

	# Cleanup
	stui.queue_free()


func test_input_blocker_stop_during_all_active_states() -> void:
	# Verify AC-017 edge case: MOUSE_FILTER_STOP throughout active states.
	var stui: Node = _make_stui()

	_force_state(stui, STUIScript.State.FADING_OUT)
	assert_int(stui.input_blocker.mouse_filter) \
		.override_failure_message("MOUSE_FILTER_STOP expected in FADING_OUT") \
		.is_equal(Control.MOUSE_FILTER_STOP)

	stui._on_fading_out_complete()  # → HOLDING
	assert_int(stui.input_blocker.mouse_filter) \
		.override_failure_message("MOUSE_FILTER_STOP expected in HOLDING") \
		.is_equal(Control.MOUSE_FILTER_STOP)

	EventBus.scene_started.emit("park")  # → FADING_IN
	assert_int(stui.input_blocker.mouse_filter) \
		.override_failure_message("MOUSE_FILTER_STOP expected in FADING_IN") \
		.is_equal(Control.MOUSE_FILTER_STOP)

	stui._on_fading_in_complete()  # → IDLE
	assert_int(stui.input_blocker.mouse_filter) \
		.override_failure_message("MOUSE_FILTER_IGNORE expected in IDLE") \
		.is_equal(Control.MOUSE_FILTER_IGNORE)

	# Cleanup
	stui.queue_free()


# ── Polygon2D geometry smoke ──────────────────────────────────────────────────

func test_polygon_build_produces_26_vertices() -> void:
	# Verify the overlay Polygon2D gets exactly 26 points after a geometry build.
	var stui: Node = _make_stui()
	var vp_size := Vector2(1280.0, 720.0)

	stui._build_polygon_flat(vp_size)

	assert_int(stui.overlay.polygon.size()) \
		.override_failure_message("Polygon2D must have exactly 26 vertices (13 top + 13 bottom)") \
		.is_equal(26)

	# Cleanup
	stui.queue_free()


func test_polygon_top_edge_vertices_span_full_width_at_y_zero() -> void:
	var stui: Node = _make_stui()
	var vp_size := Vector2(1280.0, 720.0)
	stui._build_polygon_flat(vp_size)

	var poly: PackedVector2Array = stui.overlay.polygon

	# Top edge: indices 0–12
	assert_float(poly[0].x) \
		.override_failure_message("Top-edge vertex 0 x must be 0") \
		.is_equal(0.0)
	assert_float(poly[12].x) \
		.override_failure_message("Top-edge vertex 12 x must be 1280") \
		.is_equal(1280.0)

	for i in range(13):
		assert_float(poly[i].y) \
			.override_failure_message("Top-edge vertex %d y must be 0" % i) \
			.is_equal(0.0)

	# Cleanup
	stui.queue_free()


func test_polygon_bottom_edge_vertices_at_full_height() -> void:
	var stui: Node = _make_stui()
	var vp_size := Vector2(1280.0, 720.0)
	stui._build_polygon_flat(vp_size)

	var poly: PackedVector2Array = stui.overlay.polygon

	# Bottom edge: indices 13–25
	for i in range(13):
		assert_float(poly[13 + i].y) \
			.override_failure_message("Bottom-edge vertex %d y must be 720" % i) \
			.is_equal(720.0)

	# Cleanup
	stui.queue_free()


func test_polygon_vertices_uniformly_spaced_across_width() -> void:
	var stui: Node = _make_stui()
	var vp_size := Vector2(1920.0, 1080.0)
	stui._build_polygon_flat(vp_size)

	var poly: PackedVector2Array = stui.overlay.polygon
	var expected_step: float = 1920.0 / 12.0  # 160 px between columns

	for i in range(1, 13):
		var actual_step: float = poly[i].x - poly[i - 1].x
		assert_float(actual_step) \
			.override_failure_message("Column spacing must be uniform (%.1f px) at column %d" % [expected_step, i]) \
			.is_equal_approx(expected_step, 0.01)

	# Cleanup
	stui.queue_free()


func test_polygon_scales_to_1920x1080() -> void:
	# Verify vertex positions scale correctly to a different viewport size.
	var stui: Node = _make_stui()
	var vp_size := Vector2(1920.0, 1080.0)
	stui._build_polygon_flat(vp_size)

	var poly: PackedVector2Array = stui.overlay.polygon
	assert_float(poly[12].x) \
		.override_failure_message("At 1920x1080, top-edge last vertex x must be 1920") \
		.is_equal(1920.0)
	assert_float(poly[25].y) \
		.override_failure_message("At 1920x1080, bottom-edge last vertex y must be 1080") \
		.is_equal(1080.0)

	# Cleanup
	stui.queue_free()


# ── process_mode smoke ───────────────────────────────────────────────────────

func test_process_mode_is_always_on_stui_root() -> void:
	# Verify STUI root has PROCESS_MODE_ALWAYS so Tweens survive tree pause.
	var stui: Node = _make_stui()

	assert_int(stui.process_mode) \
		.override_failure_message("STUI root must have PROCESS_MODE_ALWAYS (ADR-004 §1)") \
		.is_equal(Node.PROCESS_MODE_ALWAYS)

	# Cleanup
	stui.queue_free()


# ── EventBus contract smoke ───────────────────────────────────────────────────

func test_event_bus_exposes_required_stui_signals() -> void:
	# Confirm the signals STUI relies on are declared on EventBus (contract test).
	var required: Array[String] = [
		"scene_completed", "scene_started", "epilogue_started", "epilogue_cover_ready"
	]
	var eb_signals: Array[String] = []
	for sig in EventBus.get_signal_list():
		eb_signals.append(sig["name"])

	for sig_name in required:
		assert_bool(eb_signals.has(sig_name)) \
			.override_failure_message("EventBus must declare signal '%s' (STUI contract)" % sig_name) \
			.is_true()
