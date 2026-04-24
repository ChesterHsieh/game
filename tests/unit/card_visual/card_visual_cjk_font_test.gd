## Unit tests for CardVisual CJK font rendering capability.
##
## Regression test for the bug where Chinese display_names rendered empty
## because ThemeDB.fallback_font is Latin-only. CardVisual now builds a
## SystemFont with a CJK-capable font_names chain; this test verifies the
## resolved system font can actually draw the CJK glyphs we ship.
extends GdUnitTestSuite

const CardVisualScript := preload("res://src/gameplay/card_visual.gd")

## Sample code-points drawn from drive-scene display_names in cards.tres:
##   駕 (U+99D5) from 駕駛座 / 駕駛 Ju
##   遠 (U+9060) from 遠的要命王國
##   導 (U+5C0E) from 導航資訊
##   麥 (U+9EA5) from 麥當勞
const CJK_SAMPLE_CODEPOINTS := [0x99D5, 0x9060, 0x5C0E, 0x9EA5]


func test_card_visual_cjk_font_is_system_font() -> void:
	# Arrange
	var card_visual := CardVisualScript.new()

	# Act
	var font: SystemFont = card_visual._make_cjk_font()

	# Assert
	assert_that(font).is_not_null()
	assert_that(font is SystemFont).is_true()

	card_visual.free()


func test_card_visual_cjk_font_name_chain_contains_cjk_families() -> void:
	# Arrange
	var card_visual := CardVisualScript.new()

	# Act
	var font: SystemFont = card_visual._make_cjk_font()
	var names := font.font_names

	# Assert — chain must include at least one known CJK family per platform
	assert_that(names.has("PingFang TC")).is_true()
	assert_that(names.has("Microsoft JhengHei")).is_true()
	assert_that(names.has("Noto Sans CJK TC")).is_true()

	card_visual.free()


func test_card_visual_cjk_font_renders_drive_scene_display_name_glyphs() -> void:
	# Arrange
	var card_visual := CardVisualScript.new()
	var font: SystemFont = card_visual._make_cjk_font()

	# Act + Assert — system font resolved on this machine must have glyphs for
	# every CJK codepoint we ship in drive-scene display_names
	for codepoint: int in CJK_SAMPLE_CODEPOINTS:
		var has_glyph := font.has_char(codepoint)
		assert_that(has_glyph) \
			.override_failure_message(
				"SystemFont missing glyph for U+%04X — drive-scene card names will render as tofu" % codepoint
			).is_true()

	card_visual.free()


func test_card_visual_cjk_font_string_size_is_non_zero_for_cjk_text() -> void:
	# Arrange — if glyphs are missing, Godot returns Vector2(0, 0) for the string size
	var card_visual := CardVisualScript.new()
	var font: SystemFont = card_visual._make_cjk_font()
	var sample_text := "駕駛座"
	var font_size := 14

	# Act
	var size: Vector2 = font.get_string_size(sample_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)

	# Assert
	assert_that(size.x).is_greater(0.0)
	assert_that(size.y).is_greater(0.0)

	card_visual.free()
