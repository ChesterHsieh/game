## Domain-specific assertion utilities for Moments tests.
## Extends gdUnit4 assertions with game-specific helpers.
##
## Auto-imported via class_name — no explicit preload needed.
class_name GameAssertions
extends RefCounted


# --- Value Range Assertions ---------------------------------------------------

static func assert_in_range(
	value: float,
	min_val: float,
	max_val: float,
	label: String = "value"
) -> void:
	assert(
		value >= min_val and value <= max_val,
		"%s %.4f is outside expected range [%.4f, %.4f]" % [label, value, min_val, max_val]
	)


static func assert_bar_value(value: float, max_value: float, label: String = "bar") -> void:
	assert_in_range(value, 0.0, max_value, label)


static func assert_hint_level(level: int) -> void:
	assert(
		level >= 0 and level <= 3,
		"hint_level %d is outside expected range [0, 3]" % level
	)


# --- FSM State Assertions ----------------------------------------------------

const CARD_ENGINE_STATES := [
	"Idle", "Dragged", "Attracting", "Snapping", "Pushed", "Executing"
]

const SCENE_MANAGER_STATES := [
	"Waiting", "Loading", "Playing", "Transitioning", "Epilogue"
]

const SAVE_LOAD_RESULTS := ["OK", "NO_SAVE_FOUND", "CORRUPT_RECOVERED"]


static func assert_valid_card_state(state: String) -> void:
	assert(
		state in CARD_ENGINE_STATES,
		"Card state '%s' is not a valid CardEngine state. Expected one of: %s" % [
			state, ", ".join(CARD_ENGINE_STATES)
		]
	)


static func assert_valid_scene_manager_state(state: String) -> void:
	assert(
		state in SCENE_MANAGER_STATES,
		"Scene Manager state '%s' is not valid. Expected one of: %s" % [
			state, ", ".join(SCENE_MANAGER_STATES)
		]
	)


# --- Resource Type Assertions (ADR-005) --------------------------------------

static func assert_resource_type(resource: Resource, expected_class: String) -> void:
	assert(
		resource != null,
		"Expected a %s Resource, got null" % expected_class
	)
	assert(
		resource.get_class() == expected_class or resource.is_class(expected_class),
		"Expected Resource of type %s, got %s" % [expected_class, resource.get_class()]
	)


static func assert_resource_loads(path: String) -> Resource:
	var res: Resource = ResourceLoader.load(path)
	assert(res != null, "ResourceLoader.load('%s') returned null" % path)
	return res


# --- Signal Assertions --------------------------------------------------------

static func assert_signal_emitted_on(
	source: Object,
	signal_name: String,
	action: Callable
) -> void:
	var emitted := false
	var handler := func(_a = null, _b = null, _c = null, _d = null, _e = null, _f = null) -> void:
		emitted = true
	source.connect(signal_name, handler)
	action.call()
	source.disconnect(signal_name, handler)
	assert(emitted, "Expected signal '%s' to be emitted, but it was not" % signal_name)


static func assert_signal_not_emitted_on(
	source: Object,
	signal_name: String,
	action: Callable
) -> void:
	var emitted := false
	var handler := func(_a = null, _b = null, _c = null, _d = null, _e = null, _f = null) -> void:
		emitted = true
	source.connect(signal_name, handler)
	action.call()
	source.disconnect(signal_name, handler)
	assert(not emitted, "Expected signal '%s' NOT to be emitted, but it was" % signal_name)


# --- Dictionary / Data Assertions --------------------------------------------

static func assert_has_keys(dict: Dictionary, keys: Array[String], label: String = "dict") -> void:
	for key: String in keys:
		assert(dict.has(key), "%s is missing required key '%s'" % [label, key])


static func assert_card_entry_valid(entry: Dictionary) -> void:
	assert_has_keys(entry, ["id", "display_name", "type", "scene_id"], "CardEntry")
	assert(entry["id"] != "", "CardEntry id must not be empty")
	assert(entry["display_name"] != "", "CardEntry display_name must not be empty")


static func assert_recipe_entry_valid(entry: Dictionary) -> void:
	assert_has_keys(entry, ["id", "card_a", "card_b", "template"], "RecipeEntry")
	var valid_templates := ["Additive", "Merge", "Animate", "Generator"]
	assert(
		entry["template"] in valid_templates,
		"RecipeEntry template '%s' is not valid. Expected one of: %s" % [
			entry["template"], ", ".join(valid_templates)
		]
	)
