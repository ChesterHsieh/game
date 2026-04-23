## MainMenu — presentation-layer entry point.
##
## Owns nothing but its own two widgets (Title TextureRect and Start TextureButton).
## Emits no EventBus signals and holds no references to any autoload beyond the
## Godot SceneTree.  This is enforced by AC-RULE-1 and AC-RULE-2.
##
## States:
##   IDLE     — default; Start and Esc input are live.
##   STARTING — change_scene_to_file queued; Esc is ignored; Start is disabled.
##   EXITING  — get_tree().quit() called; all further input is ignored.
##
## ADR references: ADR-001 (naming), ADR-003 (no EventBus coupling).
## GDD: design/gdd/main-menu.md
## Stories: main-menu/story-001 through story-004
class_name MainMenu
extends Control


# ── Constants ─────────────────────────────────────────────────────────────────

## Path to the gameplay container scene.  Declared as const — not @export
## (const and @export are mutually exclusive in GDScript).
## Change this only if the file is moved; mismatches surface at first run.
const GAMEPLAY_SCENE_PATH: String = "res://src/scenes/gameplay.tscn"

## When false, Esc does nothing — OS window-close (Alt+F4 / Cmd+Q) remains the
## only quit path.  Useful for harnessed playtest sessions.
const ESC_QUIT_ENABLED: bool = true


# ── State ─────────────────────────────────────────────────────────────────────

enum State { IDLE, STARTING, EXITING }

## Current menu state.  Starts as IDLE after _ready() completes.
var _state: State = State.IDLE

## Test seams: production code leaves both null. Tests assign no-op / stub
## callables to exercise state transitions without terminating the runner.
var _quit_override: Callable = Callable()
var _change_scene_override: Callable = Callable()


# ── Node references ───────────────────────────────────────────────────────────

@onready var _start_button: TextureButton = %StartButton


# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	# AC-BOOT-1: keyboard users can press Enter immediately on launch.
	_start_button.grab_focus()

	# Connect the button pressed signal — all three activation paths (click,
	# Enter, Space) fire this via Godot's ui_accept → TextureButton.pressed.
	_start_button.pressed.connect(_on_start_button_pressed)

	# Enter Idle — explicit assignment for test readability.
	_state = State.IDLE

	# AC-RULE-1 / AC-RULE-2 enforced: no EventBus, no autoload calls here.


# ── Input ─────────────────────────────────────────────────────────────────────

## Handles Esc (quit guard) and focus recovery for keyboard-only navigation.
## Called for input events not consumed by the GUI layer.
func _unhandled_input(event: InputEvent) -> void:
	# AC-FOCUS-1: re-focus Start before processing any keyboard event if focus
	# has drifted (e.g. a mouse click on the empty background).
	if event is InputEventKey:
		var focus_owner: Control = get_viewport().gui_get_focus_owner()
		if focus_owner != _start_button:
			_start_button.grab_focus()
			# Do not consume — let the event continue processing below.

	# AC-QUIT-1 / AC-QUIT-2 / AC-QUIT-3: Esc handling with state guard.
	if event.is_action_pressed("ui_cancel"):
		if not ESC_QUIT_ENABLED:
			get_viewport().set_input_as_handled()
			return
		if _state != State.IDLE:
			# AC-QUIT-2: ignore Esc during Starting or Exiting.
			get_viewport().set_input_as_handled()
			return
		_state = State.EXITING
		if _quit_override.is_valid():
			_quit_override.call()
		else:
			get_tree().quit()


# ── Start activation ──────────────────────────────────────────────────────────

## Called when Start is activated (click, Enter, or Space via ui_accept).
## AC-RULE-3: double-press guard — _state and disabled together prevent a second
## execution reaching change_scene_to_file.
func _on_start_button_pressed() -> void:
	# Guard: only accept activation from Idle.
	if _state != State.IDLE:
		return

	# AC-START-1 step 1: transition to Starting.
	_state = State.STARTING

	# AC-START-1 step 2: disable before scene switch call so any queued second
	# press event sees disabled=true and does not re-fire the handler.
	_start_button.disabled = true

	# AC-START-1 step 3: request scene switch.
	var err: Error
	if _change_scene_override.is_valid():
		err = _change_scene_override.call(GAMEPLAY_SCENE_PATH) as Error
	else:
		err = get_tree().change_scene_to_file(GAMEPLAY_SCENE_PATH)

	# AC-FAIL-1: synchronous non-OK error recovery.
	# Deferred failures (missing tscn, parse errors) return OK and are invisible
	# here — they are caught by Scene Manager's Waiting-state watchdog (OQ-2).
	if err != OK:
		push_error(
			"MainMenu: change_scene_to_file failed with error %d for path: %s"
			% [err, GAMEPLAY_SCENE_PATH]
		)
		# AC-FAIL-1 / AC-FAIL-2: re-enable button so the user can retry.
		_start_button.disabled = false
		_state = State.IDLE
		return

	# On OK: Godot queues the scene switch.  This node will be freed next frame.
	# No further action required from Main Menu.
