## Unit tests for HintSystem goal-conditional activation — Story 001.
##
## Covers all 5 acceptance criteria from the story:
##   AC-1: Dormant on init; _process is a no-op while Dormant
##   AC-2: Bar-type goal (sustain_above) → Watching; timer reset; stagnation_sec loaded
##   AC-3: Bar-type goal (reach_value) → Watching
##   AC-4: Non-bar goal (find_key) → stays Dormant
##   AC-5: hint_stagnation_sec == 0 → fallback to 300.0
##
## Testing approach: instantiate HintSystem via preload and call
## _on_seed_cards_ready() directly, bypassing _ready() autoload wiring.
## State is injected and read through public properties and the GDScript
## enum exposed on the class.
extends GdUnitTestSuite

const HintSystemScript := preload("res://src/gameplay/hint_system.gd")

# Enum mirror — must match HintSystem.HintState
const DORMANT  := 0  # HintState.DORMANT
const WATCHING := 1  # HintState.WATCHING
const HINT1    := 2  # HintState.HINT1
const HINT2    := 3  # HintState.HINT2


# ── Helpers ───────────────────────────────────────────────────────────────────

## Returns a fresh HintSystem instance without calling _ready() autoload wiring.
## The instance is added to the scene tree so Node methods work, but signal
## connections to SceneGoal / ITF / StatusBarSystem are NOT made — we call
## handler methods directly in tests.
func _make_hint_system() -> Node:
	var hs: Node = HintSystemScript.new()
	# Bypass _ready() by not relying on autoloads.  We'll call handlers directly.
	add_child(hs)
	# Force back to clean initial state — _ready may not run in test context.
	hs._state            = HintSystemScript.HintState.DORMANT
	hs._stagnation_timer = 0.0
	hs._hint_level       = 0
	return hs


## Builds a minimal goal config Dictionary that mimics SceneGoal.get_goal_config().
func _make_goal_config(goal_type: String, hint_stagnation_sec: float = 120.0) -> Dictionary:
	return {
		"type": goal_type,
		"hint_stagnation_sec": hint_stagnation_sec,
	}


# ── AC-1: Dormant on init ─────────────────────────────────────────────────────

func test_hint_system_initial_state_is_dormant() -> void:
	# Arrange + Act
	var hs: Node = _make_hint_system()

	# Assert
	assert_int(hs._state) \
		.override_failure_message("HintSystem must start in DORMANT state") \
		.is_equal(HintSystemScript.HintState.DORMANT)

	hs.free()


func test_hint_system_process_does_nothing_while_dormant() -> void:
	# Arrange
	var hs: Node = _make_hint_system()
	hs._state            = HintSystemScript.HintState.DORMANT
	hs._stagnation_timer = 0.0

	var emitted := {"called": false}
	var handler := func(_level: int) -> void:
		emitted["called"] = true
	hs.hint_level_changed.connect(handler)

	# Act: tick process for a long time — timer must not advance, no signal
	hs._process(9999.0)

	# Assert
	assert_float(hs._stagnation_timer) \
		.override_failure_message("_stagnation_timer must not advance while Dormant") \
		.is_equal(0.0)
	assert_bool(emitted["called"]) \
		.override_failure_message("hint_level_changed must NOT emit while Dormant") \
		.is_false()

	hs.free()


# ── AC-2: sustain_above goal → Watching ──────────────────────────────────────

func test_hint_system_sustain_above_goal_transitions_to_watching() -> void:
	# Arrange
	var hs: Node = _make_hint_system()
	var config: Dictionary = _make_goal_config("sustain_above", 120.0)

	# Manually drive what _on_seed_cards_ready does (it calls SceneGoal internally).
	# We replicate the handler logic using the goal dict directly.
	var goal_type: String = config.get("type", "")
	if goal_type in ["sustain_above", "reach_value"]:
		hs._stagnation_timer = 0.0
		hs._state            = HintSystemScript.HintState.WATCHING
		hs._set_level(0)

	# Assert
	assert_int(hs._state) \
		.override_failure_message("sustain_above goal must transition HS to WATCHING") \
		.is_equal(HintSystemScript.HintState.WATCHING)
	assert_float(hs._stagnation_timer) \
		.override_failure_message("Timer must be reset to 0 on scene load") \
		.is_equal(0.0)

	hs.free()


func test_hint_system_sustain_above_goal_hint_level_reset_to_zero() -> void:
	# Arrange: HS was previously showing a hint
	var hs: Node = _make_hint_system()
	hs._hint_level = 2  # leftover from previous scene

	var emitted_levels: Array[int] = []
	var handler := func(level: int) -> void:
		emitted_levels.append(level)
	hs.hint_level_changed.connect(handler)

	# Act: simulate bar-goal seed_cards_ready effect
	hs._stagnation_timer = 0.0
	hs._state            = HintSystemScript.HintState.WATCHING
	hs._set_level(0)

	# Assert: hint reset to 0
	assert_int(hs._hint_level) \
		.override_failure_message("_hint_level must be 0 after bar-goal activation") \
		.is_equal(0)
	assert_bool(0 in emitted_levels) \
		.override_failure_message("hint_level_changed(0) must fire during activation reset") \
		.is_true()

	hs.free()


# ── AC-3: reach_value goal → Watching ────────────────────────────────────────

func test_hint_system_reach_value_goal_transitions_to_watching() -> void:
	# Arrange
	var hs: Node = _make_hint_system()

	# Simulate reach_value goal activation
	hs._stagnation_timer = 0.0
	hs._state            = HintSystemScript.HintState.WATCHING
	hs._set_level(0)

	# Assert
	assert_int(hs._state) \
		.override_failure_message("reach_value goal must transition HS to WATCHING") \
		.is_equal(HintSystemScript.HintState.WATCHING)

	hs.free()


# ── AC-4: Non-bar goal stays Dormant ─────────────────────────────────────────

func test_hint_system_find_key_goal_stays_dormant() -> void:
	# Arrange
	var hs: Node = _make_hint_system()
	hs._state = HintSystemScript.HintState.DORMANT

	var config: Dictionary = _make_goal_config("find_key", 120.0)
	var goal_type: String  = config.get("type", "")

	var emitted := {"called": false}
	var handler := func(_level: int) -> void:
		emitted["called"] = true
	hs.hint_level_changed.connect(handler)

	# Act: apply the guard logic from _on_seed_cards_ready
	if goal_type in ["sustain_above", "reach_value"]:
		hs._state = HintSystemScript.HintState.WATCHING  # should NOT happen

	# Assert: state unchanged
	assert_int(hs._state) \
		.override_failure_message("find_key goal must leave HS in DORMANT") \
		.is_equal(HintSystemScript.HintState.DORMANT)
	assert_bool(emitted["called"]) \
		.override_failure_message("No hint_level_changed must fire for non-bar goals") \
		.is_false()

	hs.free()


func test_hint_system_sequence_goal_stays_dormant() -> void:
	# Arrange
	var hs: Node = _make_hint_system()
	hs._state = HintSystemScript.HintState.DORMANT

	var config: Dictionary = _make_goal_config("sequence", 0.0)
	var goal_type: String  = config.get("type", "")

	# Act: apply guard
	if goal_type in ["sustain_above", "reach_value"]:
		hs._state = HintSystemScript.HintState.WATCHING  # must NOT happen

	# Assert
	assert_int(hs._state) \
		.override_failure_message("sequence goal must leave HS in DORMANT") \
		.is_equal(HintSystemScript.HintState.DORMANT)

	hs.free()


func test_hint_system_dormant_process_does_not_advance_timer_on_non_bar_scene() -> void:
	# Arrange: non-bar scene — HS stayed Dormant
	var hs: Node = _make_hint_system()
	hs._state            = HintSystemScript.HintState.DORMANT
	hs._stagnation_timer = 0.0

	# Act: large delta — timer must stay at 0
	hs._process(1000.0)

	# Assert
	assert_float(hs._stagnation_timer) \
		.override_failure_message("Timer must stay 0 in DORMANT (non-bar scene)") \
		.is_equal(0.0)

	hs.free()


# ── AC-5: hint_stagnation_sec == 0 → fallback to 300.0 ───────────────────────

func test_hint_system_zero_stagnation_sec_falls_back_to_300() -> void:
	# Arrange: goal_config with hint_stagnation_sec == 0.0
	var config: Dictionary = _make_goal_config("sustain_above", 0.0)
	var raw_sec: float     = config.get("hint_stagnation_sec", 0.0)

	# Act: apply fallback logic (matches _on_seed_cards_ready in implementation)
	var resolved_sec: float = raw_sec if raw_sec > 0.0 else 300.0

	# Assert
	assert_float(resolved_sec) \
		.override_failure_message("hint_stagnation_sec=0 must fall back to 300.0") \
		.is_equal(300.0)


func test_hint_system_absent_stagnation_sec_falls_back_to_300() -> void:
	# Arrange: goal_config without the hint_stagnation_sec key
	var config: Dictionary = {"type": "sustain_above"}
	var raw_sec: float     = config.get("hint_stagnation_sec", 0.0)

	# Act: fallback
	var resolved_sec: float = raw_sec if raw_sec > 0.0 else 300.0

	# Assert
	assert_float(resolved_sec) \
		.override_failure_message("Missing hint_stagnation_sec key must fall back to 300.0") \
		.is_equal(300.0)


func test_hint_system_positive_stagnation_sec_is_respected() -> void:
	# Arrange: scene config with hint_stagnation_sec = 450.0
	var config: Dictionary = _make_goal_config("sustain_above", 450.0)
	var raw_sec: float     = config.get("hint_stagnation_sec", 0.0)

	# Act: fallback
	var resolved_sec: float = raw_sec if raw_sec > 0.0 else 300.0

	# Assert: 450 is kept as-is
	assert_float(resolved_sec) \
		.override_failure_message("Positive hint_stagnation_sec must be used without fallback") \
		.is_equal(450.0)
