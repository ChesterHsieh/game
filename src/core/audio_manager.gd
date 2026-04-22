## AudioManager — autoload #5. Foundation-layer singleton that owns all audio
## playback for Moments. Loads config at startup and enters silent-fallback mode
## if the config is missing or wrong type — no crash, game runs without audio.
##
## Load order: after EventBus (autoload #1). EventBus must be ready before
## AudioManager connects to its signals (Story 005).
##
## Story 002: SFX pool allocation
## Story 003: pitch + volume randomization
## Story 004: per-event cooldowns
## Story 005: EventBus signal wiring
## Story 006: music crossfade state machine
## Story 007: public API (set_bus_volume, fade_out_all)
## Story 008: seeds audio_config.tres
##
## NOTE: class_name is intentionally omitted. Godot 4 does not allow a script
## registered as an autoload singleton to also declare a class_name matching
## its autoload name — the engine reports "Class hides an autoload singleton".
## The autoload is accessed globally via the name assigned in project.godot.
extends Node

## Path to the typed AudioConfig resource. Missing file triggers silent mode.
const CONFIG_PATH := "res://assets/data/audio_config.tres"

## Loaded AudioConfig resource. Null when in silent mode.
var _config: AudioConfig = null

## True when config is missing or wrong type. All downstream stories check this
## before playing audio. EventBus connections are still established in Story 005
## so cooldowns and state transitions work even when silent. (TR-019)
var _silent_mode: bool = false


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	var raw: Resource = ResourceLoader.load(CONFIG_PATH)
	var config: AudioConfig = raw as AudioConfig
	if config == null:
		push_error(
			"AudioManager: %s is missing or not an AudioConfig — entering silent mode"
			% CONFIG_PATH
		)
		_silent_mode = true
		return
	_config = config
	# Story 002 adds SFX pool init here
	# Story 005 adds EventBus connections here
	# Story 006 adds music player init here


## Returns true if AudioManager is in silent-fallback mode (no config loaded).
## Downstream stories check this before performing any playback operations.
##
## Example:
##   if AudioManager.is_silent():
##       return
func is_silent() -> bool:
	return _silent_mode


## Returns the loaded AudioConfig, or null when in silent mode.
## Story 002 uses this to read sfx_pool_size. Story 006 uses crossfade_duration.
##
## Example:
##   var cfg: AudioConfig = AudioManager.get_config()
##   if cfg == null: return
func get_config() -> AudioConfig:
	return _config
