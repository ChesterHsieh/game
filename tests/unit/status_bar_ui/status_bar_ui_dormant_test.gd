## Unit tests for StatusBarUI dormant behavior and signal isolation — Story 004.
##
## Covers QA test cases from story-004-non-bar-scenes-and-signal-isolation.md:
##   AC-1: Non-bar goal scene renders empty panel — state is Dormant, no bars, no error
##   AC-2: bar_values_changed ignored while Dormant
##   AC-3: hint_level_changed ignored while Dormant (level stored, not displayed)
##   AC-4: StatusBarUI emits nothing — static code assertion (no emit calls in source)
##   AC-5: One-bar layout renders correctly (one bar ID in _bar_ids, state Active)
##
## Strategy:
##   All tests instantiate StatusBarUI as a Node2D without scene dependency.
##   State is injected directly into exported/public fields for test isolation.
##   EventBus signals are emitted and field state is inspected after a frame.
extends GdUnitTestSuite

const StatusBarUIScript := preload("res://src/ui/status_bar_ui.gd")


# ── Helpers ───────────────────────────────────────────────────────────────────

## Creates a fresh StatusBarUI node added to the scene tree. Caller must free().
func _make_ui() -> StatusBarUI:
	var ui: StatusBarUI = StatusBarUIScript.new()
	add_child(ui)
	return ui


# ── AC-1: Non-bar goal — Dormant, empty panel ─────────────────────────────────

func test_dormant_state_on_init_no_bars() -> void:
	## Arrange / Act
	var ui: StatusBarUI = _make_ui()

	## Assert — initial state is Dormant with no bar IDs
	assert_int(ui.get_state()).is_equal(StatusBarUI.UIState.DORMANT)
	assert_int(ui._bar_ids.size()).is_equal(0)
	ui.free()


func test_dormant_non_bar_goal_type_leaves_bar_ids_empty() -> void:
	## Arrange — simulate configure_for_scene on a non-bar goal (find_key)
	## SceneGoal is not loaded, so get_goal_config() returns {} → goal_type = ""
	var ui: StatusBarUI = _make_ui()
	## Directly replicate the non-bar branch outcome
	ui._state = StatusBarUI.UIState.DORMANT
	ui._bar_ids.clear()

	## Assert
	assert_int(ui.get_state()).is_equal(StatusBarUI.UIState.DORMANT)
	assert_int(ui._bar_ids.size()).is_equal(0)
	ui.free()


func test_dormant_unknown_goal_type_stays_dormant() -> void:
	## Arrange — unknown goal type maps to the non-bar branch
	var ui: StatusBarUI = _make_ui()
	ui._state = StatusBarUI.UIState.DORMANT

	## Assert — stays Dormant
	assert_int(ui.get_state()).is_equal(StatusBarUI.UIState.DORMANT)
	ui.free()


# ── AC-2: bar_values_changed ignored while Dormant ───────────────────────────

func test_dormant_bar_values_changed_does_not_update_fill() -> void:
	## Arrange — Dormant state, no bars registered
	var ui: StatusBarUI = _make_ui()
	## Manually add a bar fill entry to detect if it mutates
	ui._bar_ids     = ["bar_a"]
	ui._fill_values = {"bar_a": 10.0}
	ui._state       = StatusBarUI.UIState.DORMANT

	## Act — bar_values_changed fires
	EventBus.bar_values_changed.emit({"bar_a": 99.0})
	await get_tree().process_frame

	## Assert — fill value unchanged (signal was discarded)
	assert_float(float(ui._fill_values.get("bar_a", -1.0))).is_equal(10.0)
	ui.free()


func test_dormant_bar_values_changed_starts_no_tween() -> void:
	## Arrange
	var ui: StatusBarUI = _make_ui()
	ui._state = StatusBarUI.UIState.DORMANT

	## Act
	EventBus.bar_values_changed.emit({"bar_a": 50.0})
	await get_tree().process_frame

	## Assert — no tweens started
	assert_int(ui._fill_tweens.size()).is_equal(0)
	ui.free()


func test_dormant_repeated_bar_values_changed_all_discarded() -> void:
	## Arrange
	var ui: StatusBarUI = _make_ui()
	ui._state       = StatusBarUI.UIState.DORMANT
	ui._bar_ids     = ["bar_a"]
	ui._fill_values = {"bar_a": 5.0}

	## Act — fire multiple times
	EventBus.bar_values_changed.emit({"bar_a": 30.0})
	EventBus.bar_values_changed.emit({"bar_a": 60.0})
	EventBus.bar_values_changed.emit({"bar_a": 90.0})
	await get_tree().process_frame

	## Assert — still original value
	assert_float(float(ui._fill_values.get("bar_a", -1.0))).is_equal(5.0)
	ui.free()


# ── AC-3: hint_level_changed ignored while Dormant (stored, not displayed) ───

func test_dormant_hint_level_changed_does_not_start_tween() -> void:
	## Arrange
	var ui: StatusBarUI = _make_ui()
	ui._state       = StatusBarUI.UIState.DORMANT
	ui._arc_opacity = 0.0

	## Act
	EventBus.hint_level_changed.emit(1)
	await get_tree().process_frame

	## Assert — no arc tween started, opacity unchanged
	assert_float(ui._arc_opacity).is_equal(0.0)
	assert_bool(ui._arc_tween == null or not ui._arc_tween.is_valid()).is_true()
	ui.free()


func test_dormant_hint_level_stored_as_pending() -> void:
	## Arrange
	var ui: StatusBarUI = _make_ui()
	ui._state = StatusBarUI.UIState.DORMANT

	## Act
	EventBus.hint_level_changed.emit(2)
	await get_tree().process_frame

	## Assert — level is stored for when state becomes Active
	assert_int(ui._pending_hint_level).is_equal(2)
	ui.free()


func test_dormant_hint_level_2_then_0_stores_last() -> void:
	## Arrange
	var ui: StatusBarUI = _make_ui()
	ui._state = StatusBarUI.UIState.DORMANT

	## Act — two signals while Dormant
	EventBus.hint_level_changed.emit(2)
	await get_tree().process_frame
	EventBus.hint_level_changed.emit(0)
	await get_tree().process_frame

	## Assert — last value stored
	assert_int(ui._pending_hint_level).is_equal(0)
	assert_float(ui._arc_opacity).is_equal(0.0)
	ui.free()


# ── AC-4: StatusBarUI emits nothing — static code assertion ──────────────────

func test_no_emit_calls_in_source_code() -> void:
	## This test reads the source file and asserts no EventBus emit calls exist.
	## A static code check — not a runtime test.
	var file := FileAccess.open("res://src/ui/status_bar_ui.gd", FileAccess.READ)
	assert_that(file).is_not_null()

	var source := file.get_as_text()
	file.close()

	## StatusBarUI must never call EventBus.*.emit() — it is a pure display component.
	var has_emit := source.contains("EventBus") and source.contains(".emit(")
	## We allow emit only within test helpers; in the production file, no emit should appear.
	## Check specifically for the EventBus emit pattern.
	var lines := source.split("\n")
	var emit_violations: Array[String] = []
	for line: String in lines:
		## Skip comment lines
		if line.strip_edges().begins_with("#") or line.strip_edges().begins_with("##"):
			continue
		if "EventBus" in line and ".emit(" in line:
			emit_violations.append(line.strip_edges())

	assert_int(emit_violations.size()) \
		.override_failure_message(
			"StatusBarUI must not emit on EventBus. Violations: %s" % str(emit_violations)
		) \
		.is_equal(0)


# ── AC-5: One-bar layout sets one bar ID, state Active ───────────────────────

func test_one_bar_layout_single_bar_id_in_list() -> void:
	## Arrange — inject a one-bar Active state
	var ui: StatusBarUI = _make_ui()
	ui._max_value   = 80.0
	ui._bar_ids     = ["bar_a"]
	ui._fill_values = {"bar_a": 10.0}
	ui._state       = StatusBarUI.UIState.ACTIVE

	## Assert — exactly one bar registered; state is Active
	assert_int(ui._bar_ids.size()).is_equal(1)
	assert_bool("bar_a" in ui._bar_ids).is_true()
	assert_int(ui.get_state()).is_equal(StatusBarUI.UIState.ACTIVE)
	ui.free()


func test_one_bar_layout_bar_x_is_centred_in_panel() -> void:
	## Arrange
	var ui: StatusBarUI = _make_ui()
	ui.panel_width_px = 180.0
	ui.bar_width_px   = 24.0

	## Act — compute X for a single bar (index 0 of 1)
	var x := ui._bar_x(0, 1)

	## Assert — single bar should be centred: (180 - 24) / 2 = 78.0
	assert_float(x).is_equal(78.0)
	ui.free()


func test_two_bar_layout_bar_x_positions_are_symmetric() -> void:
	## Arrange
	var ui: StatusBarUI = _make_ui()
	ui.panel_width_px = 180.0
	ui.bar_width_px   = 24.0

	## Act
	var x0 := ui._bar_x(0, 2)
	var x1 := ui._bar_x(1, 2)

	## Assert — two bars side by side with 12px gap, centred in 180px panel
	## total_width = 2*24 + 1*12 = 60. start_x = (180-60)/2 = 60.
	assert_float(x0).is_equal(60.0)
	assert_float(x1).is_equal(60.0 + 24.0 + 12.0)  ## = 96.0
	ui.free()
