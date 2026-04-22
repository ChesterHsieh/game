## Unit tests for FinalEpilogueScreen input filter and dismiss — Story 003.
##
## Covers:
##   AC-INPUT-3: Valid dismiss in HOLDING → state transitions to QUITTING
##   AC-INPUT-4: InputEventMouseMotion never dismisses in any state
##   AC-INPUT-5: KEY_ESCAPE never dismisses
##   AC-INPUT-6: Mouse button release (pressed=false) never dismisses
##   AC-INPUT-7: Key echo (echo=true) never dismisses
##
## All tests drive _unhandled_input() and _on_dismiss() directly rather than
## injecting Godot engine input events, which avoids the need for a full scene
## runner and keeps tests deterministic (no window focus required).
##
## Note: get_tree().quit() terminates the process in a real run. In gdUnit4 the
## test runner intercepts quit() calls within the test SceneTree so tests can
## assert on _state == QUITTING without the process actually exiting.
extends GdUnitTestSuite

const FESScript := preload("res://src/ui/final_epilogue_screen/final_epilogue_screen.gd")

# ── Helpers ───────────────────────────────────────────────────────────────────

## Creates a FES node and forces it into HOLDING state, bypassing the Tween
## and blackout timer. This is the canonical "ready to accept input" state.
func _make_fes_in_holding() -> FinalEpilogueScreen:
	var fes: FinalEpilogueScreen = FESScript.new()
	add_child(fes)
	fes._state = FinalEpilogueScreen.State.HOLDING
	return fes


func _make_key_event(pressed: bool, echo: bool, keycode: Key) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.pressed = pressed
	ev.echo = echo
	ev.keycode = keycode
	return ev


func _make_mouse_button_event(pressed: bool) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.pressed = pressed
	ev.button_index = MOUSE_BUTTON_LEFT
	return ev


func _make_mouse_motion_event() -> InputEventMouseMotion:
	var ev := InputEventMouseMotion.new()
	ev.relative = Vector2(1.0, 0.0)
	return ev


# ── AC-INPUT-3: Valid dismiss in HOLDING → QUITTING ──────────────────────────

func test_fes_input_filter_valid_key_press_in_holding_sets_quitting() -> void:
	# Arrange
	var fes: FinalEpilogueScreen = _make_fes_in_holding()

	# Act
	var ev := _make_key_event(true, false, KEY_SPACE)
	fes._unhandled_input(ev)
	await get_tree().process_frame

	# Assert: state must be QUITTING (dismiss was accepted)
	assert_int(fes._state).is_equal(FinalEpilogueScreen.State.QUITTING)

	fes.queue_free()
	await get_tree().process_frame


func test_fes_input_filter_valid_key_enter_in_holding_sets_quitting() -> void:
	# Arrange
	var fes: FinalEpilogueScreen = _make_fes_in_holding()

	# Act
	var ev := _make_key_event(true, false, KEY_ENTER)
	fes._unhandled_input(ev)
	await get_tree().process_frame

	# Assert
	assert_int(fes._state).is_equal(FinalEpilogueScreen.State.QUITTING)

	fes.queue_free()
	await get_tree().process_frame


func test_fes_input_filter_mouse_button_press_in_holding_sets_quitting() -> void:
	# Arrange
	var fes: FinalEpilogueScreen = _make_fes_in_holding()

	# Act
	var ev := _make_mouse_button_event(true)
	fes._unhandled_input(ev)
	await get_tree().process_frame

	# Assert
	assert_int(fes._state).is_equal(FinalEpilogueScreen.State.QUITTING)

	fes.queue_free()
	await get_tree().process_frame


func test_fes_input_filter_second_dismiss_does_not_re_enter_quit() -> void:
	# Arrange: already in QUITTING after first dismiss
	var fes: FinalEpilogueScreen = _make_fes_in_holding()
	var ev_first := _make_key_event(true, false, KEY_SPACE)
	fes._unhandled_input(ev_first)
	await get_tree().process_frame
	assert_int(fes._state).is_equal(FinalEpilogueScreen.State.QUITTING)

	# Act: second dismiss attempt (state guard should block it)
	var ev_second := _make_key_event(true, false, KEY_ENTER)
	fes._unhandled_input(ev_second)
	await get_tree().process_frame

	# Assert: still QUITTING, not re-entrant
	assert_int(fes._state).is_equal(FinalEpilogueScreen.State.QUITTING)

	fes.queue_free()
	await get_tree().process_frame


# ── AC-INPUT-4: InputEventMouseMotion never dismisses ────────────────────────

func test_fes_input_filter_mouse_motion_never_dismisses_in_holding() -> void:
	# Arrange
	var fes: FinalEpilogueScreen = _make_fes_in_holding()

	# Act: simulate 10 motion events
	for _i: int in 10:
		var ev := _make_mouse_motion_event()
		fes._unhandled_input(ev)
	await get_tree().process_frame

	# Assert: still HOLDING
	assert_int(fes._state).is_equal(FinalEpilogueScreen.State.HOLDING)

	fes.queue_free()
	await get_tree().process_frame


func test_fes_input_filter_mouse_motion_never_dismisses_in_revealing() -> void:
	# Arrange: REVEALING state
	var fes: FinalEpilogueScreen = FESScript.new()
	add_child(fes)
	fes._state = FinalEpilogueScreen.State.REVEALING

	# Act
	var ev := _make_mouse_motion_event()
	fes._unhandled_input(ev)
	await get_tree().process_frame

	# Assert: still REVEALING
	assert_int(fes._state).is_equal(FinalEpilogueScreen.State.REVEALING)

	fes.queue_free()
	await get_tree().process_frame


# ── AC-INPUT-5: KEY_ESCAPE never dismisses ────────────────────────────────────

func test_fes_input_filter_escape_key_never_dismisses() -> void:
	# Arrange
	var fes: FinalEpilogueScreen = _make_fes_in_holding()

	# Act
	var ev := _make_key_event(true, false, KEY_ESCAPE)
	fes._unhandled_input(ev)
	await get_tree().process_frame

	# Assert: still HOLDING
	assert_int(fes._state).is_equal(FinalEpilogueScreen.State.HOLDING)

	fes.queue_free()
	await get_tree().process_frame


func test_fes_input_filter_escape_key_release_never_dismisses() -> void:
	# Arrange
	var fes: FinalEpilogueScreen = _make_fes_in_holding()

	# Act: release event for Escape (caught by pressed==false guard before keycode check)
	var ev := _make_key_event(false, false, KEY_ESCAPE)
	fes._unhandled_input(ev)
	await get_tree().process_frame

	# Assert: still HOLDING
	assert_int(fes._state).is_equal(FinalEpilogueScreen.State.HOLDING)

	fes.queue_free()
	await get_tree().process_frame


# ── AC-INPUT-6: Mouse button release never dismisses ─────────────────────────

func test_fes_input_filter_mouse_button_release_never_dismisses() -> void:
	# Arrange
	var fes: FinalEpilogueScreen = _make_fes_in_holding()

	# Act: pressed=false (button release)
	var ev := _make_mouse_button_event(false)
	fes._unhandled_input(ev)
	await get_tree().process_frame

	# Assert: still HOLDING
	assert_int(fes._state).is_equal(FinalEpilogueScreen.State.HOLDING)

	fes.queue_free()
	await get_tree().process_frame


func test_fes_input_filter_right_mouse_button_release_never_dismisses() -> void:
	# Arrange
	var fes: FinalEpilogueScreen = _make_fes_in_holding()

	# Act
	var ev := InputEventMouseButton.new()
	ev.pressed = false
	ev.button_index = MOUSE_BUTTON_RIGHT
	fes._unhandled_input(ev)
	await get_tree().process_frame

	# Assert
	assert_int(fes._state).is_equal(FinalEpilogueScreen.State.HOLDING)

	fes.queue_free()
	await get_tree().process_frame


# ── AC-INPUT-7: Key echo events never dismiss ─────────────────────────────────

func test_fes_input_filter_key_echo_space_never_dismisses() -> void:
	# Arrange
	var fes: FinalEpilogueScreen = _make_fes_in_holding()

	# Act: pressed=true, echo=true (held-key auto-repeat)
	var ev := _make_key_event(true, true, KEY_SPACE)
	fes._unhandled_input(ev)
	await get_tree().process_frame

	# Assert: still HOLDING
	assert_int(fes._state).is_equal(FinalEpilogueScreen.State.HOLDING)

	fes.queue_free()
	await get_tree().process_frame


func test_fes_input_filter_key_echo_enter_never_dismisses() -> void:
	# Arrange
	var fes: FinalEpilogueScreen = _make_fes_in_holding()

	# Act
	var ev := _make_key_event(true, true, KEY_ENTER)
	fes._unhandled_input(ev)
	await get_tree().process_frame

	# Assert
	assert_int(fes._state).is_equal(FinalEpilogueScreen.State.HOLDING)

	fes.queue_free()
	await get_tree().process_frame


# ── Comprehensive filter matrix (GDD Story 003 QA table) ─────────────────────

func test_fes_input_filter_comprehensive_matrix_all_reject_cases() -> void:
	# Arrange: one shared FES in HOLDING
	var fes: FinalEpilogueScreen = _make_fes_in_holding()

	var reject_events: Array = [
		_make_key_event(true, false, KEY_ESCAPE),     # Escape: always rejected
		_make_key_event(true, true, KEY_SPACE),       # echo: rejected
		_make_key_event(false, false, KEY_SPACE),     # release: rejected
		_make_mouse_button_event(false),              # mouse release: rejected
		_make_mouse_motion_event(),                   # motion: rejected
	]

	# Act + Assert: none of these should move FES to QUITTING
	for ev: InputEvent in reject_events:
		fes._unhandled_input(ev)
		await get_tree().process_frame
		assert_int(fes._state).is_equal(FinalEpilogueScreen.State.HOLDING)

	fes.queue_free()
	await get_tree().process_frame
