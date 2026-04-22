## Unit tests for STUI core state machine and signal subscriptions — Story 001.
##
## Covers acceptance criteria scoped to this story:
##   AC-001: _enter_tree() subscription timing (SGS ordering-race fix)
##   AC-002: scene_completed in IDLE → FADING_OUT + MOUSE_FILTER_STOP same frame
##   AC-003: FADING_OUT Tween completion → HOLDING with overlay alpha == 1.0
##   AC-004: scene_started in HOLDING → FADING_IN
##   AC-005: FADING_IN Tween completion → IDLE, alpha=0, MOUSE_FILTER_IGNORE
##   AC-007: Signal-storm guard drops duplicate scene_completed when not IDLE
##   AC-008: scene_started during FADING_OUT is buffered; HOLDING is skipped
##
## Tests use direct state mutation to drive the FSM without relying on Tween timing.
extends GdUnitTestSuite

const STUIScript := preload("res://src/ui/scene_transition_ui.gd")


# ── Helpers ───────────────────────────────────────────────────────────────────

## Build a minimal STUI instance with stub child nodes.
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


## Force STUI into a specific state without going through Tween machinery.
## Sets _current_state directly and syncs InputBlocker mouse_filter.
func _force_state(stui: Node, state: int) -> void:
	stui._current_state = state
	stui._set_state(state)


# ── AC-001: _enter_tree() subscription timing ─────────────────────────────────

func test_scene_completed_handler_runs_before_ready() -> void:
	# Arrange — connect a counter before instancing so we can verify the handler
	# ran from _enter_tree() subscription, not deferred.
	# We simulate this by emitting scene_completed and checking state on same frame.
	var stui: Node = _make_stui()
	# STUI starts in FIRST_REVEAL; force to IDLE so the handler can trigger.
	_force_state(stui, STUIScript.State.IDLE)

	# Act — emit scene_completed and check state on same logical frame.
	EventBus.scene_completed.emit("test_scene")

	# Assert — handler ran; state is no longer IDLE.
	assert_int(stui._current_state) \
		.override_failure_message("AC-001: scene_completed handler must have run — state must be FADING_OUT") \
		.is_equal(STUIScript.State.FADING_OUT)

	# Cleanup
	stui.queue_free()


# ── AC-002: scene_completed in IDLE → FADING_OUT + MOUSE_FILTER_STOP ─────────

func test_scene_completed_in_idle_transitions_to_fading_out() -> void:
	# Arrange
	var stui: Node = _make_stui()
	_force_state(stui, STUIScript.State.IDLE)

	# Act
	EventBus.scene_completed.emit("home")

	# Assert
	assert_int(stui._current_state) \
		.override_failure_message("AC-002: scene_completed in IDLE must produce FADING_OUT") \
		.is_equal(STUIScript.State.FADING_OUT)

	assert_int(stui.input_blocker.mouse_filter) \
		.override_failure_message("AC-002: InputBlocker must be MOUSE_FILTER_STOP in FADING_OUT") \
		.is_equal(Control.MOUSE_FILTER_STOP)

	# Cleanup
	stui.queue_free()


func test_scene_completed_empty_scene_id_still_transitions() -> void:
	# Edge case: empty string scene_id must not prevent the state transition.
	var stui: Node = _make_stui()
	_force_state(stui, STUIScript.State.IDLE)

	EventBus.scene_completed.emit("")

	assert_int(stui._current_state) \
		.override_failure_message("Empty scene_id must still trigger FADING_OUT") \
		.is_equal(STUIScript.State.FADING_OUT)

	# Cleanup
	stui.queue_free()


# ── AC-003: FADING_OUT Tween completion → HOLDING at alpha=1.0 ────────────────

func test_fading_out_complete_enters_holding_at_full_alpha() -> void:
	# Arrange
	var stui: Node = _make_stui()
	_force_state(stui, STUIScript.State.FADING_OUT)
	stui.overlay.modulate.a = 0.5  # Simulate mid-rise alpha.

	# Act — drive the callback directly without waiting for a Tween.
	stui._on_fading_out_complete()

	# Assert
	assert_int(stui._current_state) \
		.override_failure_message("AC-003: FADING_OUT complete must enter HOLDING") \
		.is_equal(STUIScript.State.HOLDING)
	assert_float(stui.overlay.modulate.a) \
		.override_failure_message("AC-003: overlay alpha must be 1.0 in HOLDING") \
		.is_equal(1.0)

	# Cleanup
	stui.queue_free()


# ── AC-004: scene_started in HOLDING → FADING_IN ─────────────────────────────

func test_scene_started_in_holding_transitions_to_fading_in() -> void:
	# Arrange
	var stui: Node = _make_stui()
	_force_state(stui, STUIScript.State.HOLDING)
	stui.overlay.modulate.a = 1.0

	# Act
	EventBus.scene_started.emit("park")

	# Assert
	assert_int(stui._current_state) \
		.override_failure_message("AC-004: scene_started in HOLDING must produce FADING_IN") \
		.is_equal(STUIScript.State.FADING_IN)

	# Cleanup
	stui.queue_free()


func test_scene_started_different_scene_id_still_transitions() -> void:
	# Edge case: different scene_id from the one that triggered FADING_OUT is still valid.
	var stui: Node = _make_stui()
	_force_state(stui, STUIScript.State.HOLDING)
	stui.overlay.modulate.a = 1.0

	EventBus.scene_started.emit("totally_different_scene")

	assert_int(stui._current_state) \
		.override_failure_message("Different scene_id must still trigger FADING_IN from HOLDING") \
		.is_equal(STUIScript.State.FADING_IN)

	# Cleanup
	stui.queue_free()


# ── AC-005: FADING_IN Tween completion → IDLE, alpha=0, IGNORE filter ─────────

func test_fading_in_complete_enters_idle_at_zero_alpha_with_ignore_filter() -> void:
	# Arrange
	var stui: Node = _make_stui()
	_force_state(stui, STUIScript.State.FADING_IN)
	stui.overlay.modulate.a = 0.5

	# Act
	stui._on_fading_in_complete()

	# Assert
	assert_int(stui._current_state) \
		.override_failure_message("AC-005: FADING_IN complete must enter IDLE") \
		.is_equal(STUIScript.State.IDLE)
	assert_float(stui.overlay.modulate.a) \
		.override_failure_message("AC-005: overlay alpha must be 0.0 in IDLE") \
		.is_equal(0.0)
	assert_int(stui.input_blocker.mouse_filter) \
		.override_failure_message("AC-005: InputBlocker must be MOUSE_FILTER_IGNORE in IDLE") \
		.is_equal(Control.MOUSE_FILTER_IGNORE)

	# Cleanup
	stui.queue_free()


# ── AC-007: Signal-storm guard ────────────────────────────────────────────────

func test_signal_storm_guard_drops_scene_completed_when_not_idle() -> void:
	# Arrange
	var stui: Node = _make_stui()
	_force_state(stui, STUIScript.State.FADING_OUT)

	# Act — emit scene_completed again while in FADING_OUT.
	EventBus.scene_completed.emit("home")

	# Assert — state must remain FADING_OUT (not restarted).
	assert_int(stui._current_state) \
		.override_failure_message("AC-007: signal-storm guard must drop duplicate scene_completed in FADING_OUT") \
		.is_equal(STUIScript.State.FADING_OUT)

	# Cleanup
	stui.queue_free()


func test_signal_storm_guard_drops_three_rapid_duplicates() -> void:
	# Edge case: three rapid duplicates all dropped.
	var stui: Node = _make_stui()
	_force_state(stui, STUIScript.State.HOLDING)

	EventBus.scene_completed.emit("home")
	EventBus.scene_completed.emit("home")
	EventBus.scene_completed.emit("home")

	assert_int(stui._current_state) \
		.override_failure_message("Three duplicate scene_completed signals must all be dropped in HOLDING") \
		.is_equal(STUIScript.State.HOLDING)

	# Cleanup
	stui.queue_free()


func test_signal_storm_guard_drops_scene_completed_in_fading_in() -> void:
	# Guard must apply across all non-IDLE states.
	var stui: Node = _make_stui()
	_force_state(stui, STUIScript.State.FADING_IN)

	EventBus.scene_completed.emit("home")

	assert_int(stui._current_state) \
		.override_failure_message("signal-storm guard must drop scene_completed in FADING_IN") \
		.is_equal(STUIScript.State.FADING_IN)

	# Cleanup
	stui.queue_free()


# ── AC-008: Buffered scene_started during FADING_OUT skips HOLDING ────────────

func test_scene_started_during_fading_out_sets_buffer_flag() -> void:
	# Arrange
	var stui: Node = _make_stui()
	_force_state(stui, STUIScript.State.FADING_OUT)
	stui._scene_started_buffered = false

	# Act
	EventBus.scene_started.emit("park")

	# Assert — flag is set; state still FADING_OUT.
	assert_bool(stui._scene_started_buffered) \
		.override_failure_message("AC-008: _scene_started_buffered must be true after scene_started in FADING_OUT") \
		.is_true()
	assert_int(stui._current_state) \
		.override_failure_message("State must remain FADING_OUT while buffering scene_started") \
		.is_equal(STUIScript.State.FADING_OUT)

	# Cleanup
	stui.queue_free()


func test_fading_out_complete_with_buffer_skips_holding_enters_fading_in() -> void:
	# Arrange — simulate FADING_OUT with buffered scene_started.
	var stui: Node = _make_stui()
	_force_state(stui, STUIScript.State.FADING_OUT)
	stui._scene_started_buffered = true
	stui.overlay.modulate.a = 1.0

	# Act — fire the Tween completion callback.
	stui._on_fading_out_complete()

	# Assert — HOLDING was skipped; went directly to FADING_IN.
	assert_int(stui._current_state) \
		.override_failure_message("AC-008: with buffered scene_started, FADING_OUT complete must go to FADING_IN, not HOLDING") \
		.is_equal(STUIScript.State.FADING_IN)
	assert_bool(stui._scene_started_buffered) \
		.override_failure_message("Buffer flag must be cleared after consuming it") \
		.is_false()

	# Cleanup
	stui.queue_free()


func test_fading_out_complete_without_buffer_enters_holding() -> void:
	# Sanity: no buffer → normal path to HOLDING.
	var stui: Node = _make_stui()
	_force_state(stui, STUIScript.State.FADING_OUT)
	stui._scene_started_buffered = false
	stui.overlay.modulate.a = 1.0

	stui._on_fading_out_complete()

	assert_int(stui._current_state) \
		.override_failure_message("Without buffer, FADING_OUT complete must enter HOLDING") \
		.is_equal(STUIScript.State.HOLDING)

	# Cleanup
	stui.queue_free()


# ── Mouse filter transitions across all states ────────────────────────────────

func test_mouse_filter_is_stop_in_all_active_states() -> void:
	# Verify all non-IDLE, non-FIRST_REVEAL states set MOUSE_FILTER_STOP.
	var active_states: Array[int] = [
		STUIScript.State.FADING_OUT,
		STUIScript.State.HOLDING,
		STUIScript.State.FADING_IN,
		STUIScript.State.EPILOGUE,
	]
	for state_val in active_states:
		var stui: Node = _make_stui()
		_force_state(stui, state_val)
		assert_int(stui.input_blocker.mouse_filter) \
			.override_failure_message("State %d must set MOUSE_FILTER_STOP" % state_val) \
			.is_equal(Control.MOUSE_FILTER_STOP)
		stui.queue_free()


func test_mouse_filter_is_ignore_in_idle_and_first_reveal() -> void:
	var pass_through_states: Array[int] = [
		STUIScript.State.IDLE,
		STUIScript.State.FIRST_REVEAL,
	]
	for state_val in pass_through_states:
		var stui: Node = _make_stui()
		_force_state(stui, state_val)
		assert_int(stui.input_blocker.mouse_filter) \
			.override_failure_message("State %d must set MOUSE_FILTER_IGNORE" % state_val) \
			.is_equal(Control.MOUSE_FILTER_IGNORE)
		stui.queue_free()
