## Unit tests for the `keeps` config field normalization — dual-catalyst support.
##
## Covers both parsers (ITF and CardEngine) that independently interpret
## recipe config["keeps"]:
##   - Absent → empty list
##   - Single String → one-element list
##   - Single StringName → one-element list
##   - Array of Strings/StringNames → multi-element list
##   - Empty string entries filtered out
##
## Why two parsers: ITF owns consume/keep decisions in _on_merge_complete;
## CardEngine owns animation-skip decisions in _begin_merge. Both must agree
## on the shape of the input.
extends GdUnitTestSuite

const ITFScript        := preload("res://src/gameplay/interaction_template_framework.gd")
const CardEngineScript := preload("res://src/gameplay/card_engine.gd")


# ── ITF._keeps_list ───────────────────────────────────────────────────────────

func test_itf_keeps_list_absent_returns_empty_array() -> void:
	var result: Array[String] = ITFScript._keeps_list({})
	assert_int(result.size()).is_equal(0)


func test_itf_keeps_list_single_string_returns_single_entry() -> void:
	var result: Array[String] = ITFScript._keeps_list({"keeps": "ju_driving"})
	assert_int(result.size()).is_equal(1)
	assert_str(result[0]).is_equal("ju_driving")


func test_itf_keeps_list_single_stringname_returns_single_entry() -> void:
	var result: Array[String] = ITFScript._keeps_list({"keeps": &"chester_backseat"})
	assert_int(result.size()).is_equal(1)
	assert_str(result[0]).is_equal("chester_backseat")


func test_itf_keeps_list_array_of_two_returns_two_entries() -> void:
	var result: Array[String] = ITFScript._keeps_list({
		"keeps": [&"kingdom_far_away", &"chester_backseat"]
	})
	assert_int(result.size()).is_equal(2)
	assert_str(result[0]).is_equal("kingdom_far_away")
	assert_str(result[1]).is_equal("chester_backseat")


func test_itf_keeps_list_filters_empty_entries() -> void:
	var result: Array[String] = ITFScript._keeps_list({"keeps": [&"ju_driving", &""]})
	assert_int(result.size()).is_equal(1)
	assert_str(result[0]).is_equal("ju_driving")


# ── CardEngine._parse_keeps (shape parity with ITF) ───────────────────────────

func test_card_engine_parse_keeps_absent_returns_empty_array() -> void:
	var result: Array[String] = CardEngineScript._parse_keeps({})
	assert_int(result.size()).is_equal(0)


func test_card_engine_parse_keeps_single_string_returns_single_entry() -> void:
	var result: Array[String] = CardEngineScript._parse_keeps({"keeps": "ju_driving"})
	assert_int(result.size()).is_equal(1)
	assert_str(result[0]).is_equal("ju_driving")


func test_card_engine_parse_keeps_array_of_two_returns_two_entries() -> void:
	var result: Array[String] = CardEngineScript._parse_keeps({
		"keeps": [&"kingdom_far_away", &"chester_backseat"]
	})
	assert_int(result.size()).is_equal(2)
	assert_str(result[0]).is_equal("kingdom_far_away")
	assert_str(result[1]).is_equal("chester_backseat")


func test_card_engine_parse_keeps_agrees_with_itf_on_dual_catalyst() -> void:
	var config: Dictionary = {
		"result_card": &"nav_info",
		"keeps": [&"kingdom_far_away", &"chester_backseat"],
	}
	var itf_out: Array[String] = ITFScript._keeps_list(config)
	var ce_out:  Array[String] = CardEngineScript._parse_keeps(config)

	assert_int(itf_out.size()).is_equal(ce_out.size())
	for i: int in range(itf_out.size()):
		assert_str(itf_out[i]).is_equal(ce_out[i])
