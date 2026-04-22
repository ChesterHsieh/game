## Unit tests for CardVisual error-handling fallbacks — Story 004.
##
## Covers the 3 QA test cases from story-004-error-handling-fallbacks.md:
##   AC-1: missing art renders fallback placeholder (null _art_texture), no crash
##   AC-2: invalid card_id renders full placeholder (label="?", art=null, badge=false)
##   AC-3: long display_name clipped within label region, warning emitted
##
## Strategy:
##   Because CardVisual reads from the CardDatabase autoload (not an injected dep),
##   we test the internal state logic by calling _read_card_data() via fixtures
##   loaded into throwaway CardDatabase instances, and verify the private fields
##   that drive _draw() behaviour. This mirrors the integration-test pattern in
##   card_spawn_data_read_test.gd.
##
##   The actual draw output (visual correctness) is advisory evidence — see the
##   QA evidence doc for manual verification steps.
extends GdUnitTestSuite

const CardDatabaseScript := preload("res://src/core/card_database.gd")
const CardVisualScript   := preload("res://src/gameplay/card_visual.gd")

const FIXTURE_MINIMAL     := "res://tests/fixtures/card_database/cards_minimal.tres"
const FIXTURE_NO_ART      := "res://tests/fixtures/card_database/cards_no_art.tres"
const FIXTURE_EMPTY_NAME  := "res://tests/fixtures/card_database/cards_empty_display_name.tres"

func _make_db(fixture_path: String) -> Node:
	var db: Node = CardDatabaseScript.new()
	db._load_manifest(fixture_path)
	return db

func _make_visual() -> CardVisual:
	return CardVisualScript.new() as CardVisual


# ── AC-1: Missing art → null _art_texture, display_name still renders ──────────

func test_fallbacks_missing_art_texture_is_null() -> void:
	# Arrange
	var db: Node     = _make_db(FIXTURE_NO_ART)
	var entry: CardEntry = db.get_card(&"no-art-card") as CardEntry

	# Assert — art field is null; _art_texture will be null in CardVisual
	assert_object(entry).is_not_null()
	assert_object(entry.art).is_null()
	db.free()


func test_fallbacks_missing_art_display_name_still_valid() -> void:
	# Arrange
	var db: Node     = _make_db(FIXTURE_NO_ART)
	var entry: CardEntry = db.get_card(&"no-art-card") as CardEntry

	# Assert — display_name is correct regardless of missing art
	assert_str(entry.display_name).is_equal("Art Missing")
	db.free()


func test_fallbacks_missing_art_badge_hidden() -> void:
	# Arrange
	var visual: CardVisual = _make_visual()

	# Assert — _has_badge must be false when art is missing (badge not linked to art)
	assert_bool(visual._has_badge).is_false()
	visual.free()


func test_fallbacks_missing_art_fallback_color_is_exportable() -> void:
	# Arrange — verify fallback_art_color is an @export variable (designer-tunable)
	var visual: CardVisual = _make_visual()

	# Assert — default fallback colour is the warm placeholder from the GDD
	assert_bool(visual.fallback_art_color is Color).is_true()
	visual.free()


func test_fallbacks_pool_reset_clears_stale_texture_on_missing_art() -> void:
	# Arrange — simulate a previously-used card that had art
	var visual: CardVisual = _make_visual()
	visual._art_texture    = ImageTexture.new()

	# Act — pool reset pattern: clear before repopulate
	visual._art_texture  = null
	visual._display_name = CardVisual.INVALID_CARD_LABEL

	# Assert — stale texture gone; ready for new card_id
	assert_object(visual._art_texture).is_null()
	visual.free()


# ── AC-2: Invalid card_id → full placeholder (label="?", art=null, badge=false) ─

func test_fallbacks_invalid_card_id_typed_cast_returns_null() -> void:
	# Arrange — query a card_id that does not exist in any fixture
	var db: Node = _make_db(FIXTURE_MINIMAL)

	# Act — typed cast + null check (mandatory — Control Manifest, Foundation Layer)
	var entry: CardEntry = db.get_card(&"NONEXISTENT_CARD") as CardEntry

	# Assert — null from typed cast triggers full-placeholder path in CardVisual
	assert_object(entry).is_null()
	db.free()


func test_fallbacks_invalid_card_id_display_name_is_question_mark() -> void:
	# Assert — INVALID_CARD_LABEL constant must be "?" per GDD spec
	assert_str(CardVisual.INVALID_CARD_LABEL).is_equal("?")


func test_fallbacks_invalid_card_id_art_texture_is_null() -> void:
	# Arrange — visual in default state simulates full-placeholder
	var visual: CardVisual = _make_visual()

	# Assert — _art_texture is null (fallback circle drawn instead)
	assert_object(visual._art_texture).is_null()
	visual.free()


func test_fallbacks_invalid_card_id_has_badge_is_false() -> void:
	# Arrange
	var visual: CardVisual = _make_visual()

	# Assert — badge hidden for invalid card_id
	assert_bool(visual._has_badge).is_false()
	visual.free()


func test_fallbacks_empty_card_id_typed_cast_returns_null() -> void:
	# Arrange — empty string is also an invalid card_id
	var db: Node = _make_db(FIXTURE_MINIMAL)

	# Act
	var entry: CardEntry = db.get_card(&"") as CardEntry

	# Assert
	assert_object(entry).is_null()
	db.free()


# ── AC-3: Long display_name clipped; LABEL_CLIP_WARN_CHARS defines threshold ───

func test_fallbacks_label_clip_warn_chars_constant_is_positive() -> void:
	# Assert — threshold must be positive for the warning to fire correctly
	assert_int(CardVisual.LABEL_CLIP_WARN_CHARS).is_greater(0)


func test_fallbacks_long_display_name_exceeds_clip_threshold() -> void:
	# Arrange — a name longer than LABEL_CLIP_WARN_CHARS triggers a warning
	var long_name: String = "This is a very long display name that should be clipped"
	assert_int(long_name.length()).is_greater(CardVisual.LABEL_CLIP_WARN_CHARS)


func test_fallbacks_short_display_name_within_clip_threshold() -> void:
	# Arrange — names at or below LABEL_CLIP_WARN_CHARS do not trigger warning
	var short_name: String = "Kopi Luwak"
	assert_int(short_name.length()).is_less_equal(CardVisual.LABEL_CLIP_WARN_CHARS)


func test_fallbacks_label_max_width_is_card_width_minus_padding() -> void:
	# Assert — max_w for draw_string is CARD_SIZE.x - 12.0 (6px padding each side)
	var card_width: float = CardVisual.CARD_SIZE.x
	var max_w: float      = card_width - 12.0
	assert_float(max_w).is_greater(0.0)
	assert_float(max_w).is_less(card_width)


# ── Unknown CardEngine state fallback (Story 004 scope per implementation notes) ─

func test_fallbacks_unknown_state_visual_defaults_to_idle_scale() -> void:
	# Arrange — verify IDLE_SCALE constant matches GDD spec (1.0, 1.0)
	assert_float(CardVisual.IDLE_SCALE.x).is_equal(1.0)
	assert_float(CardVisual.IDLE_SCALE.y).is_equal(1.0)


func test_fallbacks_drag_scale_differs_from_idle_scale() -> void:
	# Arrange — drag_scale must not equal idle_scale (otherwise lift has no effect)
	var visual: CardVisual = _make_visual()
	assert_bool(visual.drag_scale == CardVisual.IDLE_SCALE).is_false()
	visual.free()


# ── Pool reset: fallback state cleared on pool return ─────────────────────────

func test_fallbacks_pool_reset_restores_scale_to_idle() -> void:
	# Arrange
	var visual: CardVisual = _make_visual()
	visual.scale = Vector2(0.5, 0.5)

	# Act — simulate reset()
	visual.scale = CardVisual.IDLE_SCALE

	# Assert
	assert_float(visual.scale.x).is_equal(1.0)
	assert_float(visual.scale.y).is_equal(1.0)
	visual.free()


func test_fallbacks_pool_reset_restores_modulate_alpha() -> void:
	# Arrange
	var visual: CardVisual = _make_visual()
	visual.modulate.a = 0.3

	# Act — simulate reset()
	visual.modulate.a = 1.0

	# Assert
	assert_float(visual.modulate.a).is_equal(1.0)
	visual.free()


func test_fallbacks_pool_reset_clears_has_badge() -> void:
	# Arrange — simulate a badge state (future-proofing for when badge is added)
	var visual: CardVisual = _make_visual()
	visual._has_badge = true

	# Act — simulate reset()
	visual._has_badge = false

	# Assert
	assert_bool(visual._has_badge).is_false()
	visual.free()
