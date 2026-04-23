## Unit tests for MysteryUnlockTree — Story 003: save/load + force_unlock_all.
## Covers AC-1 through AC-4 from story-003-save-load-bypass.md.
##
## Strategy:
## - get_save_state / load_save_state are exercised via in-memory round-trips.
## - Stale recipe pruning is verified by writing a save_state dict with a
##   recipe_id that doesn't exist in RecipeDatabase, then loading it.
## - force_unlock_all is tested via _inject_debug_config() test seam. A real
##   DebugConfig resource is constructed in-memory; _run_force_unlock_all() is
##   called directly.
## - Because ResourceLoader file I/O is bypassed throughout, tests are
##   deterministic and do not depend on file system state.
##
## Persistence deferral: no SaveSystem autoload exists yet. The get_save_state /
## load_save_state API is tested as a serialisation contract. Actual file
## persistence is deferred (see story-003 deferral note in mystery_unlock_tree.gd).
extends GdUnitTestSuite

const MUTScript := preload("res://src/core/mystery_unlock_tree.gd")

# Known recipes present in RecipeDatabase.
const RECIPE_A := "chester-rainy-afternoon"
const RECIPE_B := "ju-our-cafe"
const RECIPE_C := "that-argument-safe"


# ── Helpers ───────────────────────────────────────────────────────────────────

## Builds a minimal save-state dictionary with the provided discovered_recipes dict.
func _make_save_data(
		discovered: Dictionary,
		epilogue_emitted: bool = false,
		final_memory: bool = false) -> Dictionary:

	var scene_disc: Dictionary = {}
	for rid: String in discovered.keys():
		var scene_id: String = discovered[rid].get("scene_id", "scene-test")
		if scene_id not in scene_disc:
			scene_disc[scene_id] = Array([], TYPE_STRING, "", null)
		scene_disc[scene_id].append(rid)

	return {
		"discovered_recipes": discovered.duplicate(true),
		"scene_discoveries": scene_disc,
		"cards_in_discoveries": {},
		"epilogue_conditions_emitted": epilogue_emitted,
		"final_memory_earned": final_memory,
	}


## Creates a minimal discovery record dict.
func _rec(order: int, scene_id: String) -> Dictionary:
	return {
		"order": order,
		"scene_id": scene_id,
		"template": "merge",
		"card_id_a": "card-a",
		"card_id_b": "card-b",
	}


# ── AC-1: get_save_state round-trips correctly ────────────────────────────────

func test_save_load_round_trip_preserves_discovered_recipes() -> void:
	# Arrange
	var mut: Node = MUTScript.new()
	mut._discovered_recipes[RECIPE_A] = _rec(1, "scene-01")
	mut._discovered_recipes[RECIPE_B] = _rec(2, "scene-01")
	mut._discovered_recipes[RECIPE_C] = _rec(3, "scene-01")
	mut._discovery_order_counter = 3
	mut._epilogue_conditions_emitted = true

	# Act — serialise then restore into a fresh instance
	var data: Dictionary = mut.get_save_state()
	var mut2: Node = MUTScript.new()
	mut2.load_save_state(data)

	# Assert
	assert_bool(RECIPE_A in mut2._discovered_recipes).is_true()
	assert_bool(RECIPE_B in mut2._discovered_recipes).is_true()
	assert_bool(RECIPE_C in mut2._discovered_recipes).is_true()
	assert_int(mut2._discovery_order_counter).is_equal(3)
	mut.free()
	mut2.free()


func test_save_load_round_trip_preserves_epilogue_conditions_emitted() -> void:
	# Arrange
	var mut: Node = MUTScript.new()
	mut._epilogue_conditions_emitted = true

	# Act
	var data: Dictionary = mut.get_save_state()
	var mut2: Node = MUTScript.new()
	mut2.load_save_state(data)

	# Assert
	assert_bool(mut2._epilogue_conditions_emitted).is_true()
	mut.free()
	mut2.free()


func test_save_load_round_trip_preserves_final_memory_earned() -> void:
	# Arrange
	var mut: Node = MUTScript.new()
	mut._final_memory_earned = true

	# Act
	var data: Dictionary = mut.get_save_state()
	var mut2: Node = MUTScript.new()
	mut2.load_save_state(data)

	# Assert
	assert_bool(mut2._final_memory_earned).is_true()
	mut.free()
	mut2.free()


func test_save_load_get_save_state_returns_deep_copy() -> void:
	# Arrange — verify that mutating the returned dict doesn't affect MUT state.
	var mut: Node = MUTScript.new()
	mut._discovered_recipes[RECIPE_A] = _rec(1, "s")

	# Act
	var data: Dictionary = mut.get_save_state()
	data["discovered_recipes"].erase(RECIPE_A)

	# Assert — original dict unaffected
	assert_bool(RECIPE_A in mut._discovered_recipes).is_true()
	mut.free()


# ── AC-2: Stale recipe pruned on load ────────────────────────────────────────

func test_save_load_stale_recipe_not_in_discovered_after_load() -> void:
	# Arrange — save data contains a recipe_id not in RecipeDatabase
	var stale_id: String = "stale-recipe-does-not-exist-xyz"
	var discovered: Dictionary = {
		stale_id: _rec(1, "scene-01"),
		RECIPE_A: _rec(2, "scene-01"),
	}
	var data: Dictionary = _make_save_data(discovered)

	# Act
	var mut: Node = MUTScript.new()
	mut.load_save_state(data)

	# Assert — stale entry removed; valid entry retained
	assert_bool(stale_id in mut._discovered_recipes).is_false()
	assert_bool(RECIPE_A in mut._discovered_recipes).is_true()
	mut.free()


func test_save_load_stale_recipe_counter_reflects_surviving_entries() -> void:
	# Arrange
	var stale_id: String = "stale-recipe-does-not-exist-xyz"
	var discovered: Dictionary = {
		stale_id: _rec(1, "scene-01"),
		RECIPE_A: _rec(2, "scene-01"),
	}
	var data: Dictionary = _make_save_data(discovered)

	# Act
	var mut: Node = MUTScript.new()
	mut.load_save_state(data)

	# Assert — counter equals surviving count (1 valid recipe)
	assert_int(mut._discovery_order_counter).is_equal(1)
	mut.free()


func test_save_load_stale_recipe_pruned_from_scene_discoveries() -> void:
	# Arrange
	var stale_id: String = "stale-recipe-does-not-exist-xyz"
	var discovered: Dictionary = {
		stale_id: _rec(1, "scene-01"),
	}
	var data: Dictionary = _make_save_data(discovered)

	# Act
	var mut: Node = MUTScript.new()
	mut.load_save_state(data)

	# Assert — stale id not present in any scene discovery array
	for scene_id: String in mut._scene_discoveries.keys():
		var arr: Array = mut._scene_discoveries[scene_id]
		assert_bool(stale_id in arr).is_false()
	mut.free()


func test_save_load_all_valid_recipes_survive_pruning() -> void:
	# Arrange — all three are known recipes
	var discovered: Dictionary = {
		RECIPE_A: _rec(1, "scene-01"),
		RECIPE_B: _rec(2, "scene-01"),
		RECIPE_C: _rec(3, "scene-01"),
	}
	var data: Dictionary = _make_save_data(discovered)

	# Act
	var mut: Node = MUTScript.new()
	mut.load_save_state(data)

	# Assert
	assert_int(mut._discovered_recipes.size()).is_equal(3)
	assert_int(mut._discovery_order_counter).is_equal(3)
	mut.free()


# ── AC-3: force_unlock_all bulk-marks without signals ────────────────────────

func test_save_load_force_unlock_all_marks_all_recipes() -> void:
	# Arrange — create a DebugConfig resource with force_unlock_all = true
	var dbg_cfg: DebugConfig = DebugConfig.new()
	dbg_cfg.force_unlock_all = true

	var mut: Node = MUTScript.new()
	mut._inject_debug_config(dbg_cfg)

	# Act
	mut._run_force_unlock_all()

	# Assert — all RecipeDatabase recipes are now discovered
	var expected_count: int = RecipeDatabase.get_recipe_count()
	assert_int(mut._discovered_recipes.size()).is_equal(expected_count)
	assert_int(mut._discovery_order_counter).is_equal(expected_count)
	mut.free()


func test_save_load_force_unlock_all_does_not_emit_recipe_discovered() -> void:
	# Arrange
	var dbg_cfg: DebugConfig = DebugConfig.new()
	dbg_cfg.force_unlock_all = true

	var mut: Node = MUTScript.new()
	mut._inject_debug_config(dbg_cfg)
	var emitted: bool = false
	EventBus.recipe_discovered.connect(func(_r, _a, _b, _s): emitted = true)

	# Act
	mut._run_force_unlock_all()

	# Assert
	assert_bool(emitted).is_false()
	for c in EventBus.recipe_discovered.get_connections():
		EventBus.recipe_discovered.disconnect(c["callable"])
	mut.free()


func test_save_load_force_unlock_all_sets_epilogue_conditions_emitted() -> void:
	# Arrange
	var dbg_cfg: DebugConfig = DebugConfig.new()
	dbg_cfg.force_unlock_all = true

	var mut: Node = MUTScript.new()
	mut._inject_debug_config(dbg_cfg)

	# Act
	mut._run_force_unlock_all()

	# Assert
	assert_bool(mut._epilogue_conditions_emitted).is_true()
	mut.free()


func test_save_load_force_unlock_all_sets_final_memory_earned() -> void:
	# Arrange
	var dbg_cfg: DebugConfig = DebugConfig.new()
	dbg_cfg.force_unlock_all = true

	var mut: Node = MUTScript.new()
	mut._inject_debug_config(dbg_cfg)

	# Act
	mut._run_force_unlock_all()

	# Assert
	assert_bool(mut._final_memory_earned).is_true()
	mut.free()


func test_save_load_force_unlock_all_restores_suppress_signals_to_false() -> void:
	# Arrange
	var dbg_cfg: DebugConfig = DebugConfig.new()
	dbg_cfg.force_unlock_all = true

	var mut: Node = MUTScript.new()
	mut._inject_debug_config(dbg_cfg)

	# Act
	mut._run_force_unlock_all()

	# Assert — _suppress_signals must be false after bulk-fill
	assert_bool(mut._suppress_signals).is_false()
	mut.free()


func test_save_load_force_unlock_all_uses_debug_scene_id() -> void:
	# Arrange
	var dbg_cfg: DebugConfig = DebugConfig.new()
	dbg_cfg.force_unlock_all = true

	var mut: Node = MUTScript.new()
	mut._inject_debug_config(dbg_cfg)

	# Act
	mut._run_force_unlock_all()

	# Assert — all entries use scene_id "__debug__"
	for rid: String in mut._discovered_recipes.keys():
		assert_str(mut._discovered_recipes[rid]["scene_id"]).is_equal("__debug__")
	mut.free()


# ── AC-4: force_unlock_all absent (release build) ────────────────────────────

func test_save_load_force_unlock_all_absent_leaves_discovered_empty() -> void:
	# Arrange — _injected_debug_config remains null → file load returns null
	# We can't control the file system, but we can ensure the null-config path
	# is safe by injecting a null DebugConfig explicitly.
	var mut: Node = MUTScript.new()
	mut._inject_debug_config(null)  # simulate missing file

	# Act
	mut._run_force_unlock_all()

	# Assert
	assert_bool(mut._discovered_recipes.is_empty()).is_true()
	assert_bool(mut._suppress_signals).is_false()
	mut.free()


func test_save_load_force_unlock_all_flag_false_leaves_discovered_empty() -> void:
	# Arrange — DebugConfig present but flag is false
	var dbg_cfg: DebugConfig = DebugConfig.new()
	dbg_cfg.force_unlock_all = false

	var mut: Node = MUTScript.new()
	mut._inject_debug_config(dbg_cfg)

	# Act
	mut._run_force_unlock_all()

	# Assert
	assert_bool(mut._discovered_recipes.is_empty()).is_true()
	mut.free()


# ── is_final_memory_earned public API ────────────────────────────────────────

func test_save_load_is_final_memory_earned_returns_false_by_default() -> void:
	# Arrange
	var mut: Node = MUTScript.new()

	# Act + Assert
	assert_bool(mut.is_final_memory_earned()).is_false()
	mut.free()


func test_save_load_is_final_memory_earned_returns_true_after_force_unlock() -> void:
	# Arrange
	var dbg_cfg: DebugConfig = DebugConfig.new()
	dbg_cfg.force_unlock_all = true

	var mut: Node = MUTScript.new()
	mut._inject_debug_config(dbg_cfg)
	mut._run_force_unlock_all()

	# Act + Assert
	assert_bool(mut.is_final_memory_earned()).is_true()
	mut.free()


func test_save_load_is_final_memory_earned_restored_from_save_state() -> void:
	# Arrange
	var mut: Node = MUTScript.new()
	mut._final_memory_earned = true
	var data: Dictionary = mut.get_save_state()

	var mut2: Node = MUTScript.new()
	mut2.load_save_state(data)

	# Act + Assert
	assert_bool(mut2.is_final_memory_earned()).is_true()
	mut.free()
	mut2.free()
