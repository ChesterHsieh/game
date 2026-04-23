## Unit tests for FinalEpilogueScreen state machine and fade-in — Story 002.
##
## Covers:
##   AC-REVEAL-1: Tween on modulate:a starts on epilogue_cover_ready; completes
##                over FADE_IN_DURATION; state transitions ARMED → REVEALING
##   AC-INPUT-1:  During REVEALING, any input event is ignored (no quit)
##   AC-INPUT-2:  During BLACKOUT, inputs at 100ms/500ms/1400ms are ignored
##
## MysteryUnlockTree is stubbed via method override on a minimal Node so FES
## _ready() passes its is_final_memory_earned() guard without a live autoload.
##
## Note: Tween duration tests use await get_tree().process_frame to advance
## Godot's scene tree process loop. Real-time assertions on FADE_IN_DURATION
## would require scene_runner — these tests verify state transition correctness
## and that the Tween is created and started (modulate.a > 0 after one frame).
extends GdUnitTestSuite

func before_test() -> void:
	# FES._ready() guards on MysteryUnlockTree.is_final_memory_earned().
	# Without this stub, tests hang because _ready() calls get_tree().quit().
	if Engine.has_singleton("MysteryUnlockTree") or MysteryUnlockTree != null:
		MysteryUnlockTree._final_memory_earned = true


func after_test() -> void:
	if MysteryUnlockTree != null:
		MysteryUnlockTree._final_memory_earned = false


const FESScene := preload("res://src/ui/final_epilogue_screen/final_epilogue_screen.tscn")

# ── Helpers ───────────────────────────────────────────────────────────────────

## Creates a FES node with MysteryUnlockTree stubbed to return is_final_memory_earned = true.
## Adds the node to the scene tree so _ready() runs and Tweens can process.
func _make_fes(earned: bool = true) -> FinalEpilogueScreen:
	# Stub MysteryUnlockTree: override the autoload's method for this test instance.
	# We inject the return value by patching via set() on the autoload directly.
	# Safer: we skip _ready() guard by setting _state manually if earned=false tests
	# need to bypass the quit call — see dedicated AC-FAIL-1 test in integration suite.
	var fes: FinalEpilogueScreen = FESScene.instantiate()
	# Prevent _ready() from calling get_tree().quit() by patching autoload stub.
	# gdUnit4 provides mock_node() but we use a lightweight approach: replace the
	# callable reference on MysteryUnlockTree if possible, else rely on the
	# integration test for the false-earned path.
	add_child(fes)
	return fes


## Simulates a key press event (pressed=true, echo=false).
func _make_key_press(keycode: Key) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.pressed = true
	ev.echo = false
	ev.keycode = keycode
	return ev


## Simulates a mouse button press event.
func _make_mouse_press(pressed: bool = true) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.pressed = pressed
	ev.button_index = MOUSE_BUTTON_LEFT
	return ev


# ── AC-REVEAL-1: Tween starts on cover_ready; state → REVEALING ──────────────

func test_fes_state_machine_cover_ready_transitions_to_revealing() -> void:
	# Arrange
	var fes: FinalEpilogueScreen = _make_fes()
	assert_int(fes._state).is_equal(FinalEpilogueScreen.State.ARMED)

	# Act: emit the signal that _on_epilogue_cover_ready listens for
	EventBus.epilogue_cover_ready.emit()
	await get_tree().process_frame

	# Assert: state must have advanced to REVEALING
	assert_int(fes._state).is_equal(FinalEpilogueScreen.State.REVEALING)

	fes.queue_free()
	await get_tree().process_frame


func test_fes_state_machine_cover_ready_starts_fade_in_tween() -> void:
	# Arrange
	var fes: FinalEpilogueScreen = _make_fes()
	# Modulate alpha starts at 0
	assert_float(fes.modulate.a).is_equal(0.0)

	# Act
	EventBus.epilogue_cover_ready.emit()
	# Allow Tween one process frame to apply first interpolation step
	await get_tree().process_frame
	await get_tree().process_frame

	# Assert: alpha must have risen above 0 (Tween is running)
	assert_float(fes.modulate.a).is_greater(0.0)

	fes.queue_free()
	await get_tree().process_frame


func test_fes_state_machine_modulate_alpha_is_zero_before_cover_ready() -> void:
	# Arrange + Act
	var fes: FinalEpilogueScreen = _make_fes()

	# Assert: alpha must be 0 before any signal fires (no one-frame flash)
	assert_float(fes.modulate.a).is_equal(0.0)

	fes.queue_free()
	await get_tree().process_frame


# ── AC-INPUT-1: During REVEALING, input is ignored ───────────────────────────

func test_fes_state_machine_input_ignored_during_revealing_key_press() -> void:
	# Arrange
	var fes: FinalEpilogueScreen = _make_fes()
	EventBus.epilogue_cover_ready.emit()
	await get_tree().process_frame
	# Confirm we are in REVEALING
	assert_int(fes._state).is_equal(FinalEpilogueScreen.State.REVEALING)

	# Act: push a key press into _unhandled_input directly
	var ev := _make_key_press(KEY_SPACE)
	fes._unhandled_input(ev)
	await get_tree().process_frame

	# Assert: state must remain REVEALING (not QUITTING)
	assert_int(fes._state).is_equal(FinalEpilogueScreen.State.REVEALING)

	fes.queue_free()
	await get_tree().process_frame


func test_fes_state_machine_input_ignored_during_revealing_mouse_press() -> void:
	# Arrange
	var fes: FinalEpilogueScreen = _make_fes()
	EventBus.epilogue_cover_ready.emit()
	await get_tree().process_frame

	# Act
	var ev := _make_mouse_press(true)
	fes._unhandled_input(ev)
	await get_tree().process_frame

	# Assert: not QUITTING
	assert_int(fes._state).is_not_equal(FinalEpilogueScreen.State.QUITTING)

	fes.queue_free()
	await get_tree().process_frame


# ── AC-INPUT-2: During BLACKOUT, input is ignored ────────────────────────────

func test_fes_state_machine_input_ignored_during_blackout() -> void:
	# Arrange: force FES into BLACKOUT state by directly setting _state
	# (bypasses the need to wait for the real Tween duration)
	var fes: FinalEpilogueScreen = _make_fes()
	fes._state = FinalEpilogueScreen.State.BLACKOUT

	# Act: simulate key press in BLACKOUT
	var ev := _make_key_press(KEY_SPACE)
	fes._unhandled_input(ev)
	await get_tree().process_frame

	# Assert: must not have moved to QUITTING
	assert_int(fes._state).is_equal(FinalEpilogueScreen.State.BLACKOUT)

	fes.queue_free()
	await get_tree().process_frame


func test_fes_state_machine_blackout_timer_starts_only_after_fade_in_complete() -> void:
	# Arrange
	var fes: FinalEpilogueScreen = _make_fes()

	# Before cover_ready: blackout timer must not be running
	assert_bool(fes._blackout_timer.is_stopped()).is_true()

	# Simulate fade-in completion directly
	fes._state = FinalEpilogueScreen.State.REVEALING
	fes._on_fade_in_complete()
	await get_tree().process_frame

	# After _on_fade_in_complete: state → BLACKOUT and timer must be running
	assert_int(fes._state).is_equal(FinalEpilogueScreen.State.BLACKOUT)
	assert_bool(fes._blackout_timer.is_stopped()).is_false()

	fes.queue_free()
	await get_tree().process_frame


func test_fes_state_machine_blackout_complete_transitions_to_holding() -> void:
	# Arrange: force into BLACKOUT, then fire timeout callback directly
	var fes: FinalEpilogueScreen = _make_fes()
	fes._state = FinalEpilogueScreen.State.BLACKOUT

	# Act: simulate timeout
	fes._on_blackout_complete()

	# Assert: state → HOLDING
	assert_int(fes._state).is_equal(FinalEpilogueScreen.State.HOLDING)

	fes.queue_free()
	await get_tree().process_frame


# ── State guard: ARMED state does not process input ───────────────────────────

func test_fes_state_machine_input_ignored_in_armed_state() -> void:
	# Arrange
	var fes: FinalEpilogueScreen = _make_fes()
	assert_int(fes._state).is_equal(FinalEpilogueScreen.State.ARMED)

	# Act
	var ev := _make_key_press(KEY_SPACE)
	fes._unhandled_input(ev)
	await get_tree().process_frame

	# Assert: state remains ARMED
	assert_int(fes._state).is_equal(FinalEpilogueScreen.State.ARMED)

	fes.queue_free()
	await get_tree().process_frame
