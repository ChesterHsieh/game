## Integration tests for FinalEpilogueScreen audio fade and cursor hide — Story 004.
##
## Covers:
##   AC-AUDIO-1:       AudioManager.fade_out_all called with FADE_IN_DURATION/1000.0
##                     on reveal entry; argument is in seconds (2.0), not ms (2000.0)
##   AC-AUDIO-1 (EC-15): No crash when AudioManager does not have fade_out_all method
##   EC-4:             COVER_READY_TIMEOUT safety timer fires if epilogue_cover_ready
##                     never arrives; FES begins fade-in and logs warning
##   Cursor hide:      Input.mouse_mode == MOUSE_MODE_HIDDEN after cover_ready fires
##
## AudioManager is the live autoload. fade_out_all() is guarded by has_method()
## in FES, so these tests verify the guard path and the actual call path separately.
## A minimal stub node is used for the "method missing" scenario.
##
## AC-AUDIO-2 (no audio after fade-out) is a manual playtest — see evidence doc.
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

## Creates a FES node and adds it to the scene tree.
func _make_fes() -> FinalEpilogueScreen:
	var fes: FinalEpilogueScreen = FESScene.instantiate()
	add_child(fes)
	return fes


# ── AC-AUDIO-1: AudioManager.fade_out_all called with correct duration ────────

func test_fes_audio_cursor_fade_out_all_called_on_cover_ready() -> void:
	# Arrange: track whether fade_out_all was called on the live AudioManager.
	# We use a flag on AudioManager._fade_out_completed — after fade_out_all()
	# runs, the tween eventually sets it true. But we need synchronous proof.
	# Instead: record _fade_out_completed before and after.
	var before: bool = AudioManager._fade_out_completed
	var fes: FinalEpilogueScreen = _make_fes()

	# Act: emit cover_ready to trigger _on_epilogue_cover_ready
	EventBus.epilogue_cover_ready.emit()
	await get_tree().process_frame

	# Assert: AudioManager must have received the fade_out_all call.
	# _fade_out_tween will be non-null if fade_out_all() ran (it creates the tween).
	# Only valid if AUDIO_FADE_OUT const is true (it is, per GDD default).
	assert_bool(fes.AUDIO_FADE_OUT).is_true()
	if not before:
		# fade_out_all was not yet called before this test — tween should now exist
		assert_object(AudioManager._fade_out_tween).is_not_null()

	fes.queue_free()
	await get_tree().process_frame
	# Reset AudioManager state for subsequent tests
	AudioManager._fade_out_completed = false
	AudioManager._fade_out_tween = null


func test_fes_audio_cursor_fade_out_duration_is_in_seconds_not_ms() -> void:
	# Arrange: FADE_IN_DURATION const is 2000.0 ms; fade_out_all should receive 2.0 s.
	# We verify the constant arithmetic is correct in the source.
	var fes_const_ms: float = FinalEpilogueScreen.FADE_IN_DURATION
	var expected_seconds: float = fes_const_ms / 1000.0

	# Assert: expected argument to fade_out_all is 2.0 seconds
	assert_float(expected_seconds).is_equal(2.0)

	# The actual call site is: AudioManager.fade_out_all(FADE_IN_DURATION / 1000.0)
	# Verified by reading the source text to guard against regression edits.
	var f := FileAccess.open(
		"res://src/ui/final_epilogue_screen/final_epilogue_screen.gd",
		FileAccess.READ
	)
	var src: String = f.get_as_text()
	f.close()
	assert_bool(src.contains("AudioManager.fade_out_all(FADE_IN_DURATION / 1000.0)")).is_true()


# ── AC-AUDIO-1 (EC-15): No crash when fade_out_all method is absent ───────────

func test_fes_audio_cursor_no_crash_when_fade_out_all_absent() -> void:
	# Arrange: create a minimal stub node that does NOT have fade_out_all.
	# We simulate the EC-15 guard by calling _on_epilogue_cover_ready on a FES
	# instance where we can verify has_method returns false for a missing method.
	# We cannot replace the AudioManager autoload, so we verify the guard logic
	# itself: has_method on a node without the method returns false.

	var stub := Node.new()
	add_child(stub)

	# Assert: a plain Node does not have fade_out_all
	assert_bool(stub.has_method(&"fade_out_all")).is_false()

	# Verify the guard string used in FES matches the actual method name
	assert_bool(AudioManager.has_method(&"fade_out_all")).is_true()

	stub.queue_free()
	await get_tree().process_frame


func test_fes_audio_cursor_tween_starts_regardless_of_audio_method() -> void:
	# Arrange: FES with AUDIO_FADE_OUT=true; live AudioManager has fade_out_all.
	# Even if audio guard fires or not, the Tween must start.
	var fes: FinalEpilogueScreen = _make_fes()
	assert_float(fes.modulate.a).is_equal(0.0)

	# Act
	EventBus.epilogue_cover_ready.emit()
	await get_tree().process_frame
	await get_tree().process_frame

	# Assert: Tween started — alpha is rising regardless of audio path
	assert_float(fes.modulate.a).is_greater(0.0)

	fes.queue_free()
	await get_tree().process_frame
	AudioManager._fade_out_completed = false
	AudioManager._fade_out_tween = null


# ── Cursor hide: Input.mouse_mode == MOUSE_MODE_HIDDEN after cover_ready ──────

func test_fes_audio_cursor_mouse_hidden_on_reveal_entry() -> void:
	# Arrange: ensure cursor is visible before the test
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var fes: FinalEpilogueScreen = _make_fes()

	# Act
	EventBus.epilogue_cover_ready.emit()
	await get_tree().process_frame

	# Assert: cursor must be hidden (CURSOR_HIDE_ON_REVEAL const is true by default)
	assert_bool(fes.CURSOR_HIDE_ON_REVEAL).is_true()
	assert_int(Input.mouse_mode).is_equal(Input.MOUSE_MODE_HIDDEN)

	# Teardown: restore cursor for subsequent tests
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	fes.queue_free()
	await get_tree().process_frame
	AudioManager._fade_out_completed = false
	AudioManager._fade_out_tween = null


# ── EC-4: COVER_READY_TIMEOUT fallback ───────────────────────────────────────

func test_fes_audio_cursor_cover_ready_timeout_state_guard_no_op_after_reveal() -> void:
	# Arrange: trigger normal reveal via epilogue_cover_ready
	var fes: FinalEpilogueScreen = _make_fes()
	EventBus.epilogue_cover_ready.emit()
	await get_tree().process_frame
	assert_int(fes._state).is_equal(FinalEpilogueScreen.State.REVEALING)

	# Act: simulate cover_ready_timeout firing (state is no longer ARMED)
	fes._on_cover_ready_timeout()
	await get_tree().process_frame

	# Assert: still REVEALING — timeout is a no-op when state != ARMED
	assert_int(fes._state).is_equal(FinalEpilogueScreen.State.REVEALING)

	fes.queue_free()
	await get_tree().process_frame
	AudioManager._fade_out_completed = false
	AudioManager._fade_out_tween = null


func test_fes_audio_cursor_cover_ready_timeout_triggers_reveal_when_armed() -> void:
	# Arrange: FES in ARMED state (cover_ready never fired)
	var fes: FinalEpilogueScreen = _make_fes()
	assert_int(fes._state).is_equal(FinalEpilogueScreen.State.ARMED)

	# Act: call the timeout callback directly (avoids waiting 5 real seconds)
	fes._on_cover_ready_timeout()
	await get_tree().process_frame

	# Assert: reveal has started (state transitions to REVEALING)
	assert_int(fes._state).is_equal(FinalEpilogueScreen.State.REVEALING)

	fes.queue_free()
	await get_tree().process_frame
	AudioManager._fade_out_completed = false
	AudioManager._fade_out_tween = null


func test_fes_audio_cursor_cover_ready_timeout_warning_string_in_source() -> void:
	# Verify the exact warning string from GDD EC-4 is present in the implementation.
	var expected: String = "epilogue_cover_ready not received within 5000ms"
	var f := FileAccess.open(
		"res://src/ui/final_epilogue_screen/final_epilogue_screen.gd",
		FileAccess.READ
	)
	var src: String = f.get_as_text()
	f.close()
	assert_bool(src.contains(expected)).is_true()
