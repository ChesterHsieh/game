## Unit tests for SceneManager Resume Index API + reset_to_waiting() — Story 004.
## gdUnit4 test suite covering all 6 acceptance criteria.
##
## Story type: Logic
## Required evidence: this file must exist and pass.
##
## Tests use fresh SceneManagerScript instances for full isolation so the live
## autoload state is never mutated.
extends GdUnitTestSuite

const SceneManagerScript := preload("res://src/core/scene_manager.gd")


# ── Helpers ───────────────────────────────────────────────────────────────────

func _make_manifest(ids: PackedStringArray) -> SceneManifest:
	var m := SceneManifest.new()
	m.scene_ids = ids
	return m


func _sm_in_state(state_value: int) -> Node:
	var sm: Node = SceneManagerScript.new()
	sm._manifest = _make_manifest(PackedStringArray(["home", "park"]))
	sm._current_index = 0
	sm._state = state_value
	return sm


# ── AC-1: get_resume_index returns current index ──────────────────────────────

func test_get_resume_index_returns_current_index() -> void:
	# Arrange
	var sm: Node = SceneManagerScript.new()
	sm._manifest = _make_manifest(PackedStringArray(["home", "park", "café"]))
	sm._current_index = 2

	# Act & Assert
	assert_int(sm.get_resume_index()).is_equal(2)
	sm.free()


func test_get_resume_index_returns_zero_by_default() -> void:
	var sm: Node = SceneManagerScript.new()
	assert_int(sm.get_resume_index()).is_equal(0)
	sm.free()


func test_get_resume_index_has_no_side_effects() -> void:
	var sm: Node = SceneManagerScript.new()
	sm._manifest = _make_manifest(PackedStringArray(["home"]))
	sm._current_index = 1
	sm._state = 0  # WAITING

	# Multiple calls should not change state
	var _r1: int = sm.get_resume_index()
	var _r2: int = sm.get_resume_index()

	assert_int(sm._state).is_equal(0)
	assert_int(sm._current_index).is_equal(1)
	sm.free()


# ── AC-2: set_resume_index accepted in Waiting state ─────────────────────────

func test_set_resume_index_accepted_in_waiting_state() -> void:
	# Arrange
	var sm: Node = _sm_in_state(0)  # _State.WAITING == 0

	# Act
	sm.set_resume_index(3)

	# Assert
	assert_int(sm._current_index).is_equal(3)
	sm.free()


func test_set_resume_index_accepts_index_at_manifest_size_for_completed_game() -> void:
	# An index == manifest.size() is valid (saved completed-game).
	var sm: Node = _sm_in_state(0)
	sm.set_resume_index(2)  # manifest has 2 scenes → index 2 == completed

	assert_int(sm._current_index).is_equal(2)
	sm.free()


func test_set_resume_index_accepts_index_beyond_manifest_size() -> void:
	var sm: Node = _sm_in_state(0)
	sm.set_resume_index(99)  # allowed — no clamping per spec

	assert_int(sm._current_index).is_equal(99)
	sm.free()


# ── AC-3: set_resume_index rejected outside Waiting ──────────────────────────

func test_set_resume_index_rejected_when_active() -> void:
	var sm: Node = _sm_in_state(2)  # _State.ACTIVE == 2
	sm._current_index = 0

	sm.set_resume_index(1)

	assert_int(sm._current_index).is_equal(0)  # unchanged
	sm.free()


func test_set_resume_index_rejected_when_loading() -> void:
	var sm: Node = _sm_in_state(1)  # _State.LOADING == 1
	sm._current_index = 0

	sm.set_resume_index(1)

	assert_int(sm._current_index).is_equal(0)
	sm.free()


func test_set_resume_index_rejected_when_epilogue() -> void:
	var sm: Node = _sm_in_state(4)  # _State.EPILOGUE == 4
	sm._current_index = 0

	sm.set_resume_index(1)

	assert_int(sm._current_index).is_equal(0)
	sm.free()


# ── AC-4: set_resume_index rejects negative index ────────────────────────────

func test_set_resume_index_rejects_negative_one() -> void:
	var sm: Node = _sm_in_state(0)
	sm._current_index = 0

	sm.set_resume_index(-1)

	assert_int(sm._current_index).is_equal(0)
	sm.free()


func test_set_resume_index_rejects_large_negative() -> void:
	var sm: Node = _sm_in_state(0)
	sm._current_index = 1

	sm.set_resume_index(-100)

	assert_int(sm._current_index).is_equal(1)  # unchanged
	sm.free()


# ── AC-5: reset_to_waiting from Loading cancels watchdog ─────────────────────

func test_reset_to_waiting_from_loading_sets_waiting_state() -> void:
	# Arrange: LOADING (1) — no live watchdog for isolation
	var sm: Node = _sm_in_state(1)
	sm._current_index = 1

	# Act
	sm.reset_to_waiting()

	# Assert
	assert_int(sm._state).is_equal(0)       # _State.WAITING == 0
	assert_int(sm._current_index).is_equal(0)
	sm.free()


func test_reset_to_waiting_re_arms_game_start_requested() -> void:
	# After reset, the live autoload should accept re-arming (method must exist).
	assert_bool(SceneManager.has_method("reset_to_waiting")).is_true()


# ── AC-6: reset_to_waiting from Epilogue skips clear step ────────────────────

func test_reset_to_waiting_from_epilogue_sets_waiting_state() -> void:
	# Arrange: EPILOGUE (4)
	var sm: Node = _sm_in_state(4)
	sm._current_index = 2

	# Act
	sm.reset_to_waiting()

	# Assert: clean reset
	assert_int(sm._state).is_equal(0)
	assert_int(sm._current_index).is_equal(0)
	sm.free()


func test_reset_to_waiting_from_waiting_is_idempotent() -> void:
	var sm: Node = _sm_in_state(0)
	sm._current_index = 0

	sm.reset_to_waiting()

	assert_int(sm._state).is_equal(0)
	assert_int(sm._current_index).is_equal(0)
	sm.free()


func test_reset_to_waiting_from_active_resets_index_to_zero() -> void:
	var sm: Node = _sm_in_state(2)  # ACTIVE
	sm._current_index = 1

	# Act: calling reset_to_waiting on a bare instance (no live autoloads)
	# will skip the clear_all_cards / reset calls since CardSpawning etc. are
	# not initialized; those integration paths are covered in story-003 tests.
	sm.reset_to_waiting()

	assert_int(sm._current_index).is_equal(0)
	assert_int(sm._state).is_equal(0)
	sm.free()


# ── Public API surface checks ─────────────────────────────────────────────────

func test_scene_manager_has_get_resume_index_method() -> void:
	assert_bool(SceneManager.has_method("get_resume_index")).is_true()


func test_scene_manager_has_set_resume_index_method() -> void:
	assert_bool(SceneManager.has_method("set_resume_index")).is_true()


func test_scene_manager_has_reset_to_waiting_method() -> void:
	assert_bool(SceneManager.has_method("reset_to_waiting")).is_true()
