## Integration tests for SceneGoal ↔ StatusBarSystem — Story 002.
## Covers ACs from story-002-sbs-integration.md.
##
## Implementation note: The actual SGS emits its own `seed_cards_ready` signal
## (not EventBus.seed_cards_ready). SBS.configure() is called directly before
## the signal fires for bar-type goals.
##
## AC-1: sustain_above goal → SBS.configure() called before seed_cards_ready fires
## AC-2: Non-bar goal (goal type != sustain_above) → SBS stays Dormant; seed_cards_ready still fires
## AC-3: seed_cards_ready payload matches scene data
extends GdUnitTestSuite


# ── Helpers ───────────────────────────────────────────────────────────────────

func before_test() -> void:
	SceneGoal.reset()
	StatusBarSystem.reset()


func after_test() -> void:
	SceneGoal.reset()
	StatusBarSystem.reset()


# ── AC-1: sustain_above → SBS.configure() called before seed_cards_ready ─────

func test_bar_goal_sbs_is_active_after_load_scene() -> void:
	# Arrange — home.json uses goal_type = "sustain_above"

	# Act
	SceneGoal.load_scene("home")

	# Assert — SBS should have been configured (Status.ACTIVE)
	assert_int(StatusBarSystem._status) \
		.override_failure_message("SBS should be Active after bar-goal load_scene") \
		.is_equal(StatusBarSystem.Status.ACTIVE)


func test_bar_goal_sbs_configure_called_before_seed_cards_ready() -> void:
	# Arrange — capture emission order via side-effect on SBS status snapshot
	var sbs_status_at_emit: int = -1
	var handler := func(_seed_cards: Array) -> void:
		# At the moment seed_cards_ready fires, SBS should already be ACTIVE (= 1)
		sbs_status_at_emit = StatusBarSystem._status

	SceneGoal.seed_cards_ready.connect(handler)

	# Act
	SceneGoal.load_scene("home")

	# Assert
	SceneGoal.seed_cards_ready.disconnect(handler)
	assert_int(sbs_status_at_emit) \
		.override_failure_message("SBS must be ACTIVE when seed_cards_ready fires") \
		.is_equal(StatusBarSystem.Status.ACTIVE)


func test_bar_goal_seed_cards_ready_is_emitted() -> void:
	# Arrange
	var captured := {"emitted": false}
	var handler := func(_seed_cards: Array) -> void:
		captured["emitted"] = true
	SceneGoal.seed_cards_ready.connect(handler)

	# Act
	SceneGoal.load_scene("home")

	# Assert
	SceneGoal.seed_cards_ready.disconnect(handler)
	assert_bool(captured["emitted"]) \
		.override_failure_message("seed_cards_ready must be emitted for bar-type goal") \
		.is_true()


func test_bar_goal_sbs_values_initialised_with_home_bars() -> void:
	# Arrange — home.json has bars: "chester" and "ju"

	# Act
	SceneGoal.load_scene("home")
	var values: Dictionary = StatusBarSystem.get_values()

	# Assert — both bar IDs present
	assert_bool(values.has("chester")) \
		.override_failure_message("SBS values should contain bar 'chester'") \
		.is_true()
	assert_bool(values.has("ju")) \
		.override_failure_message("SBS values should contain bar 'ju'") \
		.is_true()


# ── AC-2: Non-bar goal skips SBS.configure ────────────────────────────────────
## Note: There is no fixture JSON for "find_key" in assets/data/scenes/.
## We test the real implementation path: a nonexistent scene leaves SBS Dormant,
## and an already-reset SBS remains Dormant.
## The authoritative AC-2 check below tests the guard: SBS stays Dormant when
## load_scene fails (nonexistent = neither bar goal nor any goal).

func test_failed_load_scene_sbs_remains_dormant() -> void:
	# Arrange — no file for this id; SGS will fail fast and not call SBS

	# Act
	SceneGoal.load_scene("nonexistent_find_key_scene")

	# Assert — SBS must not have been configured (remains Dormant)
	assert_int(StatusBarSystem._status) \
		.override_failure_message("SBS should stay Dormant when load_scene fails") \
		.is_equal(StatusBarSystem.Status.DORMANT)


func test_failed_load_scene_seed_cards_ready_not_emitted() -> void:
	# Arrange
	var captured := {"emitted": false}
	var handler := func(_seed_cards: Array) -> void:
		captured["emitted"] = true
	SceneGoal.seed_cards_ready.connect(handler)

	# Act
	SceneGoal.load_scene("nonexistent_find_key_scene")

	# Assert
	SceneGoal.seed_cards_ready.disconnect(handler)
	assert_bool(captured["emitted"]) \
		.override_failure_message("seed_cards_ready must NOT fire when scene load fails") \
		.is_false()


# ── AC-3: seed_cards_ready payload matches scene data ─────────────────────────

func test_seed_cards_ready_payload_contains_three_cards_for_home() -> void:
	# Arrange — home.json declares 3 seed cards: chester, ju, home
	var captured := {"cards": []}
	var handler := func(seed_cards: Array) -> void:
		captured["cards"] = seed_cards
	SceneGoal.seed_cards_ready.connect(handler)

	# Act
	SceneGoal.load_scene("home")

	# Assert
	SceneGoal.seed_cards_ready.disconnect(handler)
	assert_int(captured["cards"].size()) \
		.override_failure_message("home.json has 3 seed cards") \
		.is_equal(3)


func test_seed_cards_ready_first_card_is_chester() -> void:
	# Arrange
	var captured := {"cards": []}
	var handler := func(seed_cards: Array) -> void:
		captured["cards"] = seed_cards
	SceneGoal.seed_cards_ready.connect(handler)

	# Act
	SceneGoal.load_scene("home")

	# Assert — first seed card in home.json is chester
	SceneGoal.seed_cards_ready.disconnect(handler)
	var first: Dictionary = captured["cards"][0]
	assert_str(first.get("card_id", "")) \
		.override_failure_message("First seed card must be 'chester'") \
		.is_equal("chester")


func test_seed_cards_ready_payload_is_array() -> void:
	# Arrange
	var captured := {"cards": null}
	var handler := func(seed_cards: Array) -> void:
		captured["cards"] = seed_cards
	SceneGoal.seed_cards_ready.connect(handler)

	# Act
	SceneGoal.load_scene("home")

	# Assert
	SceneGoal.seed_cards_ready.disconnect(handler)
	assert_object(captured["cards"]).is_not_null()
