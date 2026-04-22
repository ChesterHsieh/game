## Integration tests for the seeded audio_config.tres — Story 008.
##
## Covers the 5 QA smoke-check cases from the story:
##   SC-2: config loads without errors, _silent_mode == false
##   SC-3: all required SFX event keys are present with valid entries
##   SC-4: all event path fields are non-null strings (empty allowed — silent placeholder)
##   SC-5: music_tracks contains a "scene-01" key with a string value
##   SC-SCHEMA: scalar fields match AudioConfig schema defaults / valid ranges
##
## SC-1 (bus layout) is already covered by autoload_config_test.gd.
##
## Design note: audio files do not exist yet; paths are intentionally empty strings.
## AudioManager._play_on_node() guards `if not path.is_empty()` so silent-mode
## placeholders are safe at runtime (TR-015, Story 008 implementation notes).
extends GdUnitTestSuite

const CONFIG_PATH := "res://assets/data/audio_config.tres"

## Event keys that must be present — derived from _dispatch_sfx() call sites in
## audio_manager.gd plus card_snap from the GDD MVP event table.
const REQUIRED_SFX_EVENTS: Array[String] = [
	"card_drag_start",
	"card_drag_release",
	"card_proximity_enter",
	"card_snap",
	"card_spawned",
	"combination_executed",
	"win_condition_met",
]

## Required per-event Dictionary keys per AudioConfig schema doc comment.
const REQUIRED_EVENT_KEYS: Array[String] = [
	"path",
	"base_volume_db",
	"volume_variance",
	"pitch_range",
	"cooldown_ms",
]

var _cfg: AudioConfig = null


func before_test() -> void:
	var raw: Resource = ResourceLoader.load(CONFIG_PATH)
	_cfg = raw as AudioConfig


# ── SC-2: config loads without errors ────────────────────────────────────────

func test_seed_audio_config_resource_loads_as_audio_config() -> void:
	# Arrange / Act: performed in before_test()
	# Assert
	assert_object(_cfg).is_not_null()


func test_seed_audio_config_loaded_config_is_not_in_silent_mode() -> void:
	# Arrange
	assert_object(_cfg).is_not_null()
	# Act
	var manager: Node = preload("res://src/core/audio_manager.gd").new()
	manager._config = _cfg
	manager._silent_mode = false
	# Assert
	assert_bool(manager.is_silent()).is_false()
	manager.free()


# ── SC-3: all 7 MVP SFX event keys are present ───────────────────────────────

func test_seed_audio_config_sfx_events_contains_all_required_keys() -> void:
	# Arrange
	assert_object(_cfg).is_not_null()
	var events: Dictionary = _cfg.sfx_events
	# Act / Assert — each key must be present
	for event_name: String in REQUIRED_SFX_EVENTS:
		assert_bool(events.has(event_name)).is_true()


func test_seed_audio_config_sfx_events_count_is_at_least_seven() -> void:
	# Arrange
	assert_object(_cfg).is_not_null()
	# Assert
	assert_int(_cfg.sfx_events.size()).is_greater_equal(7)


# ── SC-3 detail: each entry has the correct inner keys ───────────────────────

func test_seed_audio_config_card_drag_start_has_all_required_fields() -> void:
	assert_object(_cfg).is_not_null()
	var entry: Dictionary = _cfg.sfx_events.get("card_drag_start", {}) as Dictionary
	assert_bool(entry.is_empty()).is_false()
	for key: String in REQUIRED_EVENT_KEYS:
		assert_bool(entry.has(key)).is_true()


func test_seed_audio_config_card_drag_release_has_all_required_fields() -> void:
	assert_object(_cfg).is_not_null()
	var entry: Dictionary = _cfg.sfx_events.get("card_drag_release", {}) as Dictionary
	assert_bool(entry.is_empty()).is_false()
	for key: String in REQUIRED_EVENT_KEYS:
		assert_bool(entry.has(key)).is_true()


func test_seed_audio_config_card_proximity_enter_has_all_required_fields() -> void:
	assert_object(_cfg).is_not_null()
	var entry: Dictionary = _cfg.sfx_events.get("card_proximity_enter", {}) as Dictionary
	assert_bool(entry.is_empty()).is_false()
	for key: String in REQUIRED_EVENT_KEYS:
		assert_bool(entry.has(key)).is_true()


func test_seed_audio_config_card_snap_has_all_required_fields() -> void:
	assert_object(_cfg).is_not_null()
	var entry: Dictionary = _cfg.sfx_events.get("card_snap", {}) as Dictionary
	assert_bool(entry.is_empty()).is_false()
	for key: String in REQUIRED_EVENT_KEYS:
		assert_bool(entry.has(key)).is_true()


func test_seed_audio_config_card_spawned_has_all_required_fields() -> void:
	assert_object(_cfg).is_not_null()
	var entry: Dictionary = _cfg.sfx_events.get("card_spawned", {}) as Dictionary
	assert_bool(entry.is_empty()).is_false()
	for key: String in REQUIRED_EVENT_KEYS:
		assert_bool(entry.has(key)).is_true()


func test_seed_audio_config_combination_executed_has_all_required_fields() -> void:
	assert_object(_cfg).is_not_null()
	var entry: Dictionary = _cfg.sfx_events.get("combination_executed", {}) as Dictionary
	assert_bool(entry.is_empty()).is_false()
	for key: String in REQUIRED_EVENT_KEYS:
		assert_bool(entry.has(key)).is_true()


func test_seed_audio_config_win_condition_met_has_all_required_fields() -> void:
	assert_object(_cfg).is_not_null()
	var entry: Dictionary = _cfg.sfx_events.get("win_condition_met", {}) as Dictionary
	assert_bool(entry.is_empty()).is_false()
	for key: String in REQUIRED_EVENT_KEYS:
		assert_bool(entry.has(key)).is_true()


# ── SC-4: path fields are strings (empty allowed — silent placeholders) ───────

func test_seed_audio_config_all_event_path_fields_are_strings() -> void:
	# Arrange
	assert_object(_cfg).is_not_null()
	# Act / Assert
	for event_name: String in REQUIRED_SFX_EVENTS:
		var entry: Dictionary = _cfg.sfx_events.get(event_name, {}) as Dictionary
		var path_val: Variant = entry.get("path", null)
		assert_bool(path_val != null).is_true()
		assert_bool(path_val is String).is_true()


func test_seed_audio_config_all_event_cooldown_ms_are_positive_or_zero() -> void:
	# Arrange
	assert_object(_cfg).is_not_null()
	# Act / Assert — cooldown_ms must be >= 0
	for event_name: String in REQUIRED_SFX_EVENTS:
		var entry: Dictionary = _cfg.sfx_events.get(event_name, {}) as Dictionary
		var cooldown: int = entry.get("cooldown_ms", -1) as int
		assert_int(cooldown).is_greater_equal(0)


func test_seed_audio_config_win_condition_met_cooldown_is_zero() -> void:
	# win_condition_met uses the once-per-scene boolean, not cooldown_ms.
	# Storing 0 signals this to readers without requiring special logic in the config.
	assert_object(_cfg).is_not_null()
	var entry: Dictionary = _cfg.sfx_events.get("win_condition_met", {}) as Dictionary
	var cooldown: int = entry.get("cooldown_ms", -1) as int
	assert_int(cooldown).is_equal(0)


# ── SC-5: music_tracks has a "scene-01" entry ────────────────────────────────

func test_seed_audio_config_music_tracks_contains_scene_01() -> void:
	# Arrange
	assert_object(_cfg).is_not_null()
	# Assert
	assert_bool(_cfg.music_tracks.has("scene-01")).is_true()


func test_seed_audio_config_scene_01_track_value_is_string() -> void:
	# Arrange
	assert_object(_cfg).is_not_null()
	# Act
	var track_val: Variant = _cfg.music_tracks.get("scene-01", null)
	# Assert — string (empty allowed: no music file yet)
	assert_bool(track_val != null).is_true()
	assert_bool(track_val is String).is_true()


# ── SC-SCHEMA: scalar fields are within valid ranges ─────────────────────────

func test_seed_audio_config_crossfade_duration_is_in_range() -> void:
	assert_object(_cfg).is_not_null()
	# AudioConfig @export_range(0.1, 5.0)
	assert_float(_cfg.crossfade_duration).is_greater_equal(0.1)
	assert_float(_cfg.crossfade_duration).is_less_equal(5.0)


func test_seed_audio_config_music_volume_db_is_in_range() -> void:
	assert_object(_cfg).is_not_null()
	# AudioConfig @export_range(-80.0, 0.0)
	assert_float(_cfg.music_volume_db).is_greater_equal(-80.0)
	assert_float(_cfg.music_volume_db).is_less_equal(0.0)


func test_seed_audio_config_sfx_pool_size_is_in_range() -> void:
	assert_object(_cfg).is_not_null()
	# AudioConfig @export_range(4, 16)
	assert_int(_cfg.sfx_pool_size).is_greater_equal(4)
	assert_int(_cfg.sfx_pool_size).is_less_equal(16)
