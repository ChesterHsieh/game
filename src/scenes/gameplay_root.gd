## GameplayRoot — runtime scene root composed per ADR-004 §2.
##
## This script is attached to the root Node2D of `gameplay.tscn`. Its sole
## responsibility is to kick off the game once the scene has finished its
## first frame, by emitting `EventBus.game_start_requested`. All runtime
## subsystems (SceneManager, SceneGoal, CardSpawning, etc.) are autoloads
## and are already live by the time this node enters the tree. The scene
## itself only contains the CanvasLayer hierarchy for Hud / Transition /
## Settings / Epilogue (instanced in the .tscn, not wired here).
##
## Boot sequence:
##   1. MainMenu calls `change_scene_to_file("res://src/scenes/gameplay.tscn")`
##   2. Godot instantiates gameplay.tscn — autoloads are untouched
##   3. This `_ready()` runs; after one frame, emits game_start_requested
##   4. SceneManager (in Waiting state since boot) consumes the signal via
##      CONNECT_ONE_SHOT and loads scene-manifest.tres[0] (coffee-intro)
##   5. SceneGoal.load_scene fires seed_cards_ready → CardSpawning spawns the
##      four tutorial cards into the scene tree
##
## Reference: docs/architecture/adr-0004-runtime-scene-composition.md §2
extends Node2D


func _ready() -> void:
	# Wait one frame so SceneManager's Waiting-state CONNECT_ONE_SHOT listener
	# is guaranteed to be active before we emit (ADR-003 ordering rule).
	await get_tree().process_frame
	_apply_debug_start_scene()
	EventBus.game_start_requested.emit()


## Dev-only: if debug-config.tres declares start_scene_index >= 0, jump there.
## File is excluded from release exports, so this is a no-op in production.
func _apply_debug_start_scene() -> void:
	var dbg: DebugConfig = ResourceLoader.load(
		"res://assets/data/debug-config.tres") as DebugConfig
	if dbg == null or dbg.start_scene_index < 0:
		return
	SceneManager.set_resume_index(dbg.start_scene_index)
