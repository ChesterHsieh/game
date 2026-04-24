## stui_interstitial_test — Story 007: interstitial illustration during HOLDING state
##
## Verifies:
##   AC-1: schema documented in transition_variants.gd; _get_variant_knob returns Dictionary
##   AC-2: _on_interstitial_done transitions HOLDING → FADING_IN
##   AC-3: no config → _try_begin_interstitial is a no-op
##   AC-4: InterstitialPanel pre-allocated in .tscn, hidden by default
##   AC-5: reduced-motion path guard (_on_interstitial_reduced_motion_hold_done no-op)
##   AC-6: _cancel_interstitial hides panel and clears _interstitial_active flag
extends GdUnitTestSuite


const StuiScript := preload("res://src/ui/scene_transition_ui.gd")
const StuiScene := preload("res://src/ui/scene_transition_ui.tscn")
const TransitionVariantsScript := preload("res://src/data/transition_variants.gd")


## Instantiate the full STUI scene, add to tree, and register for auto_free.
func _make_stui() -> CanvasLayer:
	var stui: CanvasLayer = StuiScene.instantiate()
	add_child(stui)
	auto_free(stui)
	return stui


# ── AC-1: export defaults ─────────────────────────────────────────────────────

func test_interstitial_exports_have_correct_defaults() -> void:
	# Arrange
	var stui: CanvasLayer = auto_free(StuiScript.new())

	# Assert
	assert_that(stui.interstitial_fade_in_ms).is_equal(400.0)
	assert_that(stui.interstitial_fade_out_ms).is_equal(400.0)


# ── AC-4: panel pre-allocated in scene tree ───────────────────────────────────

func test_interstitial_panel_exists_in_scene_tree_preallocated() -> void:
	# Arrange + Act
	var stui: CanvasLayer = _make_stui()
	var panel: Node = stui.get_node("InterstitialPanel")

	# Assert
	assert_that(panel).is_not_null()
	assert_bool(panel is Control).is_true()
	assert_bool(panel.visible).is_false()
	assert_that((panel as Control).modulate.a).is_equal(0.0)


func test_interstitial_panel_has_illustration_and_caption_children() -> void:
	# Arrange + Act
	var stui: CanvasLayer = _make_stui()
	var illustration: Node = stui.get_node("InterstitialPanel/IllustrationRect")
	var caption: Node = stui.get_node("InterstitialPanel/CaptionLabel")

	# Assert
	assert_that(illustration).is_not_null()
	assert_bool(illustration is TextureRect).is_true()
	assert_that(caption).is_not_null()
	assert_bool(caption is Label).is_true()


# ── AC-1: _get_variant_knob returns interstitial Dictionary ──────────────────

func test_get_variant_knob_returns_interstitial_dictionary() -> void:
	# Arrange
	var stui: CanvasLayer = _make_stui()

	var tex: PlaceholderTexture2D = PlaceholderTexture2D.new()
	var interstitial_cfg: Dictionary = {
		"illustration": tex,
		"caption": "hi",
		"hold_ms": 500.0
	}
	var res: TransitionVariants = TransitionVariants.new()
	res.variants = { "scn": { "interstitial": interstitial_cfg } }
	stui._variants_resource = res

	# Act
	var result: Variant = stui._get_variant_knob("scn", "interstitial", null)

	# Assert
	assert_bool(result is Dictionary).is_true()
	var result_dict: Dictionary = result as Dictionary
	assert_bool(result_dict.has("illustration")).is_true()
	assert_bool(result_dict["illustration"] is Texture2D).is_true()
	assert_bool(result_dict.has("caption")).is_true()
	assert_that(result_dict["caption"]).is_equal("hi")
	assert_bool(result_dict.has("hold_ms")).is_true()
	assert_that(float(result_dict["hold_ms"])).is_equal(500.0)


# ── AC-3: no config → panel stays hidden ─────────────────────────────────────

func test_no_interstitial_config_skips_panel_activation() -> void:
	# Arrange
	var stui: CanvasLayer = _make_stui()
	# No variants resource set — _get_variant_knob returns null
	stui._variants_resource = null
	stui._current_scene_id = "no_config_scene"

	# Act
	stui._try_begin_interstitial()

	# Assert
	assert_bool(stui._interstitial_active).is_false()
	assert_bool(stui.interstitial_panel.visible).is_false()


# ── AC-2: _on_interstitial_done transitions HOLDING → FADING_IN ──────────────

func test_on_interstitial_done_transitions_holding_to_fading_in() -> void:
	# Arrange
	var stui: CanvasLayer = _make_stui()
	stui._current_state = stui.State.HOLDING
	stui._interstitial_active = true
	stui.interstitial_panel.visible = true
	stui.interstitial_panel.modulate.a = 1.0

	# Act
	stui._on_interstitial_done()

	# Assert
	assert_that(stui._current_state).is_equal(stui.State.FADING_IN)
	assert_bool(stui._interstitial_active).is_false()
	assert_bool(stui.interstitial_panel.visible).is_false()


# ── AC-6: _cancel_interstitial hides panel and clears flag ───────────────────

func test_cancel_interstitial_hides_panel_and_clears_flag() -> void:
	# Arrange
	var stui: CanvasLayer = _make_stui()
	stui._interstitial_active = true
	stui.interstitial_panel.visible = true
	stui.interstitial_panel.modulate.a = 1.0

	# Act
	stui._cancel_interstitial()

	# Assert
	assert_bool(stui._interstitial_active).is_false()
	assert_bool(stui.interstitial_panel.visible).is_false()


# ── AC-6: reduced-motion timer callback is no-op when cancelled ──────────────

func test_reduced_motion_hold_done_is_noop_when_cancelled() -> void:
	# Arrange
	var stui: CanvasLayer = _make_stui()
	var initial_state: int = stui._current_state
	stui._interstitial_active = false  # already cancelled

	# Act — must not throw, must not change state to FADING_IN
	stui._on_interstitial_reduced_motion_hold_done()

	# Assert
	assert_that(stui._current_state).is_equal(initial_state)
	assert_bool(stui._interstitial_active).is_false()
