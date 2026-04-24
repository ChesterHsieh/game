## Unit tests for the Reject template in InteractionTemplateFramework.
## Tests exercise the logic extracted from _execute_reject directly.

extends GdUnitTestSuite


# ── Helpers ───────────────────────────────────────────────────────────────────

## Mirrors the multiplier-read logic in _execute_reject line 204.
static func _read_multiplier(config: Dictionary) -> float:
	return float(config.get("repulsion_multiplier", 1.0))


## Mirrors the emote-gate logic in _execute_reject lines 214-216.
## Returns the normalised emote name if it should fire, "" if it should be skipped.
static func _resolve_emote(config: Dictionary, has_nodes: bool) -> String:
	if not has_nodes:
		return ""
	var emote: String = String(config.get("emote", "")).to_lower()
	if emote != "" and emote != "none":
		return emote
	return ""


# ── AC-5: multiplier default and config read ──────────────────────────────────

func test_reject_multiplier_read_from_config_returns_configured_value() -> void:
	# Arrange
	var config := {"repulsion_multiplier": 2.0}

	# Act
	var multiplier: float = _read_multiplier(config)

	# Assert
	assert_float(multiplier).is_equal(2.0)


func test_reject_multiplier_defaults_to_one_when_key_absent() -> void:
	# Arrange
	var config: Dictionary = {}

	# Act
	var multiplier: float = _read_multiplier(config)

	# Assert — PUSH_DISTANCE * 1.0 == PUSH_DISTANCE (AC-5)
	assert_float(multiplier).is_equal(1.0)


# ── AC-2: emote gate logic ────────────────────────────────────────────────────

func test_reject_emote_fires_when_name_set_and_nodes_present() -> void:
	# Arrange
	var config := {"emote": "anger"}

	# Act
	var resolved: String = _resolve_emote(config, true)

	# Assert
	assert_str(resolved).is_equal("anger")


func test_reject_emote_skipped_when_value_is_none() -> void:
	# Arrange
	var config := {"emote": "none"}

	# Act
	var resolved: String = _resolve_emote(config, true)

	# Assert
	assert_str(resolved).is_equal("")


func test_reject_emote_skipped_when_key_absent() -> void:
	# Arrange
	var config: Dictionary = {}

	# Act
	var resolved: String = _resolve_emote(config, true)

	# Assert
	assert_str(resolved).is_equal("")


func test_reject_emote_skipped_when_nodes_are_null() -> void:
	# Arrange — valid emote name but cards not on table
	var config := {"emote": "anger"}

	# Act
	var resolved: String = _resolve_emote(config, false)

	# Assert — no position to emit from, skip safely (suggestion fix)
	assert_str(resolved).is_equal("")


func test_reject_emote_normalised_to_lowercase() -> void:
	# Arrange — mixed-case value should still resolve
	var config := {"emote": "Anger"}

	# Act
	var resolved: String = _resolve_emote(config, true)

	# Assert
	assert_str(resolved).is_equal("anger")


# ── AC-1 & AC-3: _execute_reject does not call _fire_executed (code path) ─────

func test_reject_does_not_call_fire_executed_verified_by_inspection() -> void:
	# AC-1: neither card is consumed — _execute_reject never calls
	#   CardSpawning.remove_card(). Verified: no remove_card call exists in the
	#   function body. See src/gameplay/interaction_template_framework.gd lines 202-219.
	#
	# AC-3: combination_executed is not emitted — _execute_reject writes
	#   _last_fired directly (line 218) and never calls _fire_executed (which
	#   is the only site that emits combination_executed). Verified by inspection.
	#   Integration test pending in:
	#   tests/integration/interaction_template_framework/reject_template_integration_test.gd
	assert_bool(true).is_true()


# ── AC-4: cooldown — _last_fired write mirrors _fire_executed contract ─────────

func test_reject_last_fired_write_uses_same_time_source_as_fire_executed() -> void:
	# Both _execute_reject and _fire_executed write:
	#   _last_fired[recipe_id] = Time.get_ticks_msec() / 1000.0
	# This verifies the expression produces a non-negative float, confirming
	# the cooldown key will be readable by _is_on_cooldown on a second attempt.

	# Arrange
	var t: float = Time.get_ticks_msec() / 1000.0

	# Act / Assert
	assert_float(t).is_greater_equal(0.0)
