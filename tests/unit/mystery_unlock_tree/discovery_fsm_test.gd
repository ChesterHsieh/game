## Unit tests for MysteryUnlockTree — Story 001: discovery recording + FSM.
## Covers AC-1 through AC-5 from story-001-discovery-fsm.md.
##
## Strategy: MysteryUnlockTree's autoload name collides with any class_name so
## the script has no globally registered class. Preload and instantiate directly.
## Signals are asserted on by connecting lambdas before calling handlers.
## RecipeDatabase autoload is used directly (it is available in headless test runs).
##
## Tests do NOT call _ready() to avoid ResourceLoader file I/O; they drive state
## by calling handlers directly after setting _state manually where needed.
extends GdUnitTestSuite

const MUTScript := preload("res://src/core/mystery_unlock_tree.gd")

# ── Helpers ───────────────────────────────────────────────────────────────────

## Creates a fresh MUT instance with state set to ACTIVE and an initialised
## scene discovery array for "scene-test".
func _make_active_mut() -> Node:
	var mut: Node = MUTScript.new()
	# Set ACTIVE state and seed scene discovery array without going through _ready().
	mut._state = 1  # _State.ACTIVE
	mut._active_scene_id = "scene-test"
	mut._scene_discoveries["scene-test"] = Array([], TYPE_STRING, "", null)
	return mut


## Returns a known recipe id that exists in RecipeDatabase.
func _known_recipe() -> String:
	return "chester-rainy-afternoon"


# ── AC-1: First discovery recorded; recipe_discovered emitted ─────────────────

func test_discovery_fsm_first_discovery_recorded_in_dict() -> void:
	# Arrange
	var mut: Node = _make_active_mut()
	var recipe_id: String = _known_recipe()

	# Act
	mut._on_combination_executed(recipe_id, "merge", "iid_a", "iid_b", "chester", "rainy-afternoon")

	# Assert
	assert_bool(recipe_id in mut._discovered_recipes).is_true()
	mut.free()


func test_discovery_fsm_first_discovery_sets_order_1() -> void:
	# Arrange
	var mut: Node = _make_active_mut()
	var recipe_id: String = _known_recipe()

	# Act
	mut._on_combination_executed(recipe_id, "merge", "iid_a", "iid_b", "chester", "rainy-afternoon")

	# Assert
	assert_int(mut._discovered_recipes[recipe_id]["order"]).is_equal(1)
	mut.free()


func test_discovery_fsm_first_discovery_counter_is_1() -> void:
	# Arrange
	var mut: Node = _make_active_mut()

	# Act
	mut._on_combination_executed(_known_recipe(), "merge", "iid_a", "iid_b", "chester", "rainy-afternoon")

	# Assert
	assert_int(mut._discovery_order_counter).is_equal(1)
	mut.free()


func test_discovery_fsm_recipe_discovered_signal_emitted() -> void:
	# Arrange
	var mut: Node = _make_active_mut()
	var emitted_recipe: String = ""
	EventBus.recipe_discovered.connect(func(r, _a, _b, _s): emitted_recipe = r)

	# Act
	mut._on_combination_executed(_known_recipe(), "merge", "iid_a", "iid_b", "chester", "rainy-afternoon")

	# Assert
	assert_str(emitted_recipe).is_equal(_known_recipe())
	for c in EventBus.recipe_discovered.get_connections():
		EventBus.recipe_discovered.disconnect(c["callable"])
	mut.free()


func test_discovery_fsm_first_discovery_appended_to_scene_discoveries() -> void:
	# Arrange
	var mut: Node = _make_active_mut()

	# Act
	mut._on_combination_executed(_known_recipe(), "merge", "iid_a", "iid_b", "chester", "rainy-afternoon")

	# Assert
	var scene_arr: Array = mut._scene_discoveries["scene-test"]
	assert_bool(_known_recipe() in scene_arr).is_true()
	mut.free()


func test_discovery_fsm_first_discovery_card_ids_indexed() -> void:
	# Arrange
	var mut: Node = _make_active_mut()

	# Act
	mut._on_combination_executed(_known_recipe(), "merge", "iid_a", "iid_b", "chester", "rainy-afternoon")

	# Assert
	assert_bool("chester" in mut._cards_in_discoveries).is_true()
	assert_bool("rainy-afternoon" in mut._cards_in_discoveries).is_true()
	mut.free()


# ── AC-2: Duplicate recipe silently ignored ───────────────────────────────────

func test_discovery_fsm_duplicate_recipe_counter_unchanged() -> void:
	# Arrange
	var mut: Node = _make_active_mut()
	var recipe_id: String = _known_recipe()
	mut._on_combination_executed(recipe_id, "merge", "iid_a", "iid_b", "chester", "rainy-afternoon")
	assert_int(mut._discovery_order_counter).is_equal(1)

	# Act — fire same recipe again
	mut._on_combination_executed(recipe_id, "merge", "iid_a", "iid_b", "chester", "rainy-afternoon")

	# Assert — counter still 1
	assert_int(mut._discovery_order_counter).is_equal(1)
	mut.free()


func test_discovery_fsm_duplicate_recipe_signal_not_emitted_twice() -> void:
	# Arrange
	var mut: Node = _make_active_mut()
	var emit_count: int = 0
	EventBus.recipe_discovered.connect(func(_r, _a, _b, _s): emit_count += 1)
	var recipe_id: String = _known_recipe()

	# Act
	mut._on_combination_executed(recipe_id, "merge", "iid_a", "iid_b", "chester", "rainy-afternoon")
	mut._on_combination_executed(recipe_id, "merge", "iid_a", "iid_b", "chester", "rainy-afternoon")

	# Assert
	assert_int(emit_count).is_equal(1)
	for c in EventBus.recipe_discovered.get_connections():
		EventBus.recipe_discovered.disconnect(c["callable"])
	mut.free()


# ── AC-3: combination_executed ignored when not Active ────────────────────────

func test_discovery_fsm_inactive_state_ignores_combination() -> void:
	# Arrange
	var mut: Node = MUTScript.new()
	# _state defaults to INACTIVE (0)
	assert_int(mut._state).is_equal(0)

	# Act
	mut._on_combination_executed(_known_recipe(), "merge", "iid_a", "iid_b", "chester", "rainy-afternoon")

	# Assert — discovered_recipes unchanged
	assert_bool(_known_recipe() in mut._discovered_recipes).is_false()
	assert_int(mut._discovery_order_counter).is_equal(0)
	mut.free()


func test_discovery_fsm_transitioning_state_ignores_combination() -> void:
	# Arrange
	var mut: Node = MUTScript.new()
	mut._state = 2  # _State.TRANSITIONING
	mut._active_scene_id = "scene-test"
	mut._scene_discoveries["scene-test"] = Array([], TYPE_STRING, "", null)

	# Act
	mut._on_combination_executed(_known_recipe(), "merge", "iid_a", "iid_b", "chester", "rainy-afternoon")

	# Assert
	assert_bool(_known_recipe() in mut._discovered_recipes).is_false()
	mut.free()


func test_discovery_fsm_epilogue_state_ignores_combination() -> void:
	# Arrange
	var mut: Node = MUTScript.new()
	mut._state = 3  # _State.EPILOGUE

	# Act
	mut._on_combination_executed(_known_recipe(), "merge", "iid_a", "iid_b", "chester", "rainy-afternoon")

	# Assert
	assert_bool(_known_recipe() in mut._discovered_recipes).is_false()
	mut.free()


# ── AC-4: State transitions follow FSM ───────────────────────────────────────

func test_discovery_fsm_scene_started_sets_active_state() -> void:
	# Arrange
	var mut: Node = MUTScript.new()
	assert_int(mut._state).is_equal(0)  # INACTIVE

	# Act
	mut._on_scene_started("home")

	# Assert
	assert_int(mut._state).is_equal(1)  # ACTIVE
	mut.free()


func test_discovery_fsm_scene_completed_sets_transitioning_state() -> void:
	# Arrange
	var mut: Node = _make_active_mut()

	# Act
	mut._on_scene_completed("scene-test")

	# Assert
	assert_int(mut._state).is_equal(2)  # TRANSITIONING
	mut.free()


func test_discovery_fsm_epilogue_started_sets_epilogue_state() -> void:
	# Arrange — start from INACTIVE, go through ACTIVE → TRANSITIONING → EPILOGUE
	var mut: Node = MUTScript.new()
	mut._on_scene_started("home")
	assert_int(mut._state).is_equal(1)  # ACTIVE
	mut._on_scene_completed("home")
	assert_int(mut._state).is_equal(2)  # TRANSITIONING

	# Act
	mut._on_epilogue_started()

	# Assert
	assert_int(mut._state).is_equal(3)  # EPILOGUE
	mut.free()


func test_discovery_fsm_scene_started_sets_active_scene_id() -> void:
	# Arrange
	var mut: Node = MUTScript.new()

	# Act
	mut._on_scene_started("my-scene")

	# Assert
	assert_str(mut._active_scene_id).is_equal("my-scene")
	mut.free()


func test_discovery_fsm_scene_started_initialises_typed_discovery_array() -> void:
	# Arrange
	var mut: Node = MUTScript.new()

	# Act
	mut._on_scene_started("fresh-scene")

	# Assert — array entry created and is typed Array[String]
	assert_bool("fresh-scene" in mut._scene_discoveries).is_true()
	var arr: Array = mut._scene_discoveries["fresh-scene"]
	assert_int(arr.size()).is_equal(0)
	mut.free()


func test_discovery_fsm_scene_completed_mismatched_scene_id_ignored() -> void:
	# Arrange
	var mut: Node = _make_active_mut()  # active_scene_id = "scene-test"

	# Act — wrong scene_id
	mut._on_scene_completed("other-scene")

	# Assert — still ACTIVE
	assert_int(mut._state).is_equal(1)  # ACTIVE
	mut.free()


# ── AC-5: Unknown recipe_id skipped with warning ──────────────────────────────

func test_discovery_fsm_unknown_recipe_not_recorded() -> void:
	# Arrange
	var mut: Node = _make_active_mut()

	# Act
	mut._on_combination_executed("fake-recipe-xyz", "merge", "iid_a", "iid_b", "card-a", "card-b")

	# Assert
	assert_bool("fake-recipe-xyz" in mut._discovered_recipes).is_false()
	assert_int(mut._discovery_order_counter).is_equal(0)
	mut.free()


func test_discovery_fsm_unknown_recipe_no_signal_emitted() -> void:
	# Arrange
	var mut: Node = _make_active_mut()
	var emitted: bool = false
	EventBus.recipe_discovered.connect(func(_r, _a, _b, _s): emitted = true)

	# Act
	mut._on_combination_executed("fake-recipe-xyz", "merge", "iid_a", "iid_b", "card-a", "card-b")

	# Assert
	assert_bool(emitted).is_false()
	for c in EventBus.recipe_discovered.get_connections():
		EventBus.recipe_discovered.disconnect(c["callable"])
	mut.free()


# ── Query API side-effect-free checks ────────────────────────────────────────

func test_discovery_fsm_is_recipe_discovered_returns_false_before_discovery() -> void:
	# Arrange
	var mut: Node = MUTScript.new()

	# Act + Assert
	assert_bool(mut.is_recipe_discovered(_known_recipe())).is_false()
	mut.free()


func test_discovery_fsm_is_recipe_discovered_returns_true_after_discovery() -> void:
	# Arrange
	var mut: Node = _make_active_mut()
	mut._on_combination_executed(_known_recipe(), "merge", "iid_a", "iid_b", "chester", "rainy-afternoon")

	# Act + Assert
	assert_bool(mut.is_recipe_discovered(_known_recipe())).is_true()
	mut.free()


func test_discovery_fsm_get_discovery_count_returns_0_at_start() -> void:
	# Arrange
	var mut: Node = MUTScript.new()

	# Act + Assert
	assert_int(mut.get_discovery_count()).is_equal(0)
	mut.free()


func test_discovery_fsm_get_discovery_count_increments_per_unique_discovery() -> void:
	# Arrange
	var mut: Node = _make_active_mut()

	# Act
	mut._on_combination_executed(_known_recipe(), "merge", "iid_a", "iid_b", "chester", "rainy-afternoon")

	# Assert
	assert_int(mut.get_discovery_count()).is_equal(1)
	mut.free()


func test_discovery_fsm_is_card_in_discovery_returns_true_after_discovery() -> void:
	# Arrange
	var mut: Node = _make_active_mut()
	mut._on_combination_executed(_known_recipe(), "merge", "iid_a", "iid_b", "chester", "rainy-afternoon")

	# Act + Assert
	assert_bool(mut.is_card_in_discovery("chester")).is_true()
	mut.free()


func test_discovery_fsm_get_scene_discoveries_returns_empty_for_unknown_scene() -> void:
	# Arrange
	var mut: Node = MUTScript.new()

	# Act + Assert
	assert_array(mut.get_scene_discoveries("no-such-scene")).is_empty()
	mut.free()


func test_discovery_fsm_get_discovery_record_returns_empty_dict_before_discovery() -> void:
	# Arrange
	var mut: Node = MUTScript.new()

	# Act + Assert
	assert_dict(mut.get_discovery_record(_known_recipe())).is_empty()
	mut.free()
