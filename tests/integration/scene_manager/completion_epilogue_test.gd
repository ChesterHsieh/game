## Integration tests for SceneManager scene completion + epilogue — Story 003.
## gdUnit4 test suite covering all 4 acceptance criteria.
##
## Story type: Integration
## Required evidence: this file must exist and pass.
##
## Integration strategy: structural and state-assertion tests on the live
## autoload plus a fresh SceneManagerScript instance for isolation of the
## completion/epilogue logic paths.
extends GdUnitTestSuite

const SceneManagerScript := preload("res://src/core/scene_manager.gd")


# ── Helpers ───────────────────────────────────────────────────────────────────

func _make_manifest(ids: PackedStringArray) -> SceneManifest:
	var m := SceneManifest.new()
	m.scene_ids = ids
	return m


# ── AC-1: scene_completed advances state machine ──────────────────────────────

func test_scene_manager_has_on_scene_completed_handler() -> void:
	assert_bool(SceneManager.has_method("_on_scene_completed")).is_true()


func test_scene_manager_has_enter_epilogue_method() -> void:
	assert_bool(SceneManager.has_method("_enter_epilogue")).is_true()


func test_card_spawning_has_clear_all_cards_for_transition() -> void:
	assert_bool(CardSpawning.has_method("clear_all_cards")).is_true()


func test_scene_goal_has_reset_method_for_transition() -> void:
	assert_bool(SceneGoal.has_method("reset")).is_true()


# ── AC-2: Final scene triggers epilogue ───────────────────────────────────────
#
# We verify the epilogue signal path exists and that _enter_epilogue sets the
# correct terminal state. We do this on a fresh instance to avoid mutating
# the live autoload.

func test_scene_manager_enter_epilogue_sets_epilogue_state() -> void:
	# Arrange: fresh instance with a manifest
	var sm: Node = SceneManagerScript.new()
	sm._manifest = _make_manifest(PackedStringArray(["home"]))
	sm._state = 2  # _State.ACTIVE

	# Act
	sm._enter_epilogue()

	# Assert: _State.EPILOGUE == 4
	assert_int(sm._state).is_equal(4)
	sm.free()


func test_event_bus_has_epilogue_started_signal() -> void:
	assert_bool(EventBus.has_signal("epilogue_started")).is_true()


# ── AC-3: scene_completed while not Active is ignored ─────────────────────────

func test_scene_manager_on_scene_completed_guards_non_active_state() -> void:
	# Arrange: fresh instance in WAITING state (0)
	var sm: Node = SceneManagerScript.new()
	sm._manifest = _make_manifest(PackedStringArray(["home", "park"]))
	sm._current_index = 0
	sm._state = 0  # _State.WAITING

	# Act: call with the correct scene_id — should be ignored because state != ACTIVE
	sm._on_scene_completed("home")

	# Assert: state unchanged — still WAITING (0), not TRANSITIONING (3)
	assert_int(sm._state).is_equal(0)
	sm.free()


func test_scene_manager_on_scene_completed_guards_transitioning_state() -> void:
	# Arrange: fresh instance in TRANSITIONING state (3)
	var sm: Node = SceneManagerScript.new()
	sm._manifest = _make_manifest(PackedStringArray(["home", "park"]))
	sm._current_index = 0
	sm._state = 3  # _State.TRANSITIONING

	# Act
	sm._on_scene_completed("home")

	# Assert: still TRANSITIONING (3), no double-clear triggered
	assert_int(sm._state).is_equal(3)
	sm.free()


# ── AC-4: Saved-completed-game resume goes directly to Epilogue ───────────────

func test_scene_manager_on_game_start_requested_enters_epilogue_when_index_past_end() -> void:
	# Arrange: fresh instance; index at manifest.size() == "completed"
	var sm: Node = SceneManagerScript.new()
	sm._manifest = _make_manifest(PackedStringArray(["home", "park"]))
	sm._current_index = 2  # == manifest.size() → completed
	sm._state = 0  # _State.WAITING

	# Act
	sm._on_game_start_requested()

	# Assert: _State.EPILOGUE == 4
	assert_int(sm._state).is_equal(4)
	sm.free()


func test_scene_manager_on_game_start_requested_does_not_call_load_when_completed() -> void:
	# Verifies _load_scene_at_index is NOT entered — state jumps straight to EPILOGUE.
	var sm: Node = SceneManagerScript.new()
	sm._manifest = _make_manifest(PackedStringArray(["home"]))
	sm._current_index = 1  # == manifest.size() → completed
	sm._state = 0  # _State.WAITING

	sm._on_game_start_requested()

	# If _load_scene_at_index ran it would set state to LOADING (1), not EPILOGUE (4).
	assert_int(sm._state).is_equal(4)
	sm.free()


# ── AC-5: Mismatch scene_id in scene_completed logs warning, ignores call ─────

func test_scene_manager_on_scene_completed_ignores_mismatched_scene_id() -> void:
	# Arrange: fresh instance in ACTIVE state with "home" as current scene
	var sm: Node = SceneManagerScript.new()
	sm._manifest = _make_manifest(PackedStringArray(["home", "park"]))
	sm._current_index = 0
	sm._state = 2  # _State.ACTIVE

	# Act: fire with wrong scene_id
	sm._on_scene_completed("park")

	# Assert: state unchanged — still ACTIVE (2)
	assert_int(sm._state).is_equal(2)
	sm.free()
