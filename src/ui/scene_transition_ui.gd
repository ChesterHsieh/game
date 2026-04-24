## SceneTransitionUI — signal-driven page-turn overlay for Moments (STUI).
##
## Presentation layer that visually brackets every scene change. Listens on
## EventBus for three Scene Lifecycle signals and paints the screen with
## fade-and-breakthrough visuals while blocking mouse/touch input.
##
## Node tree (scene_transition_ui.tscn):
##   SceneTransitionUI  (CanvasLayer, layer=10, process_mode=ALWAYS)
##   ├── InputBlocker   (ColorRect, anchors_preset=PRESET_FULL_RECT, modulate.a=0)
##   ├── Overlay        (Polygon2D, 26-vertex strip, modulate.a=0 initially)
##   └── RustleAudio    (AudioStreamPlayer, bus=SFX_UI)
##
## Signal subscriptions are made in _enter_tree() — not _ready() — to fix the
## first-frame ordering race where SGS could emit scene_completed before STUI's
## _ready() runs (GDD Core Rule 2, ADR-003, AC-001).
##
## References:
##   design/gdd/scene-transition-ui.md
##   docs/architecture/adr-0003-signal-bus.md
##   docs/architecture/adr-0004-runtime-scene-composition.md
extends CanvasLayer


# ── Enums ─────────────────────────────────────────────────────────────────────

## Authoritative FSM states. Transition table in GDD §States and Transitions.
enum State {
	FIRST_REVEAL,  ## Boot: overlay opaque cream, fades out on first scene_started
	IDLE,          ## No transition active; input pass-through
	FADING_OUT,    ## Overlay rising + curl sweeping; input blocked
	HOLDING,       ## Overlay opaque; scene swap in progress; paper-breathe active
	FADING_IN,     ## Overlay alpha 1→0; new scene reveals; input blocked
	EPILOGUE,      ## Amber overlay held open-ended; terminal state
}


# ── Export variables (tuning knobs — GDD §Tuning Knobs) ──────────────────────

## Nominal rise duration in milliseconds.
@export var rise_nominal_ms: float = 400.0
## Per-transition rise variation range in milliseconds.
@export var rise_variation_ms: float = 80.0

## Nominal hold duration in milliseconds.
@export var hold_nominal_ms: float = 1000.0
## Per-transition hold variation range in milliseconds.
@export var hold_variation_ms: float = 150.0

## Nominal fade-out duration in milliseconds.
@export var fade_out_nominal_ms: float = 500.0
## Per-transition fade-out variation range in milliseconds.
@export var fade_out_variation_ms: float = 80.0

## Hard floor for total transition duration (normal path). GDD Formula 1.
@export var total_min_ms: float = 1700.0
## Hard ceiling for total transition duration (normal path). GDD Formula 1.
@export var total_max_ms: float = 2200.0

## Slow fade-out duration on game-boot FIRST_REVEAL state. GDD Core Rule 8.
@export var first_reveal_fade_ms: float = 1200.0

## Multiplier applied to rise and fade-out nominals for the epilogue variant.
@export var epilogue_time_scale: float = 1.35

## Ease-back duration for held card after cancel_drag(). GDD Core Rule 6.
@export var drag_cancel_ease_ms: float = 100.0

## Normal transition overlay tint (cream).
@export var overlay_color_cream: Color = Color(0.98, 0.95, 0.88)
## Epilogue overlay tint (amber). GDD Core Rule 9.
@export var overlay_color_amber: Color = Color(1.0, 0.92, 0.78)

## Nominal peak rotation of overlay Polygon2D at curl peak, degrees. GDD Formula 2.
@export var curl_rotation_nominal_deg: float = 4.0
## Per-transition rotation variation, degrees. GDD Formula 2.
@export var curl_rotation_variation_deg: float = 1.5
## Fraction of rise phase at which curl reaches peak. GDD Tuning Knobs.
@export var curl_peak_time_frac: float = 0.75

## Hold-phase alpha pulse nominal amplitude. GDD Formula 4.
@export var breathe_amplitude_nominal: float = 0.03
## Per-transition amplitude variation. GDD Formula 4.
@export var breathe_amplitude_variation: float = 0.01
## Pulse period during HOLD, seconds. GDD Formula 4.
@export var breathe_period_sec: float = 0.7

## Semitone range for audio pitch variation. GDD Formula 3.
@export var pitch_semitone_range: float = 4.0
## Paper rustle SFX gain in dB.
@export var rustle_volume_db: float = -12.0

## Rise duration in reduced-motion path, milliseconds. GDD Core Rule 11.
@export var reduced_motion_rise_ms: float = 400.0
## Hold duration in reduced-motion path, milliseconds.
@export var reduced_motion_hold_ms: float = 600.0
## Fade-out duration in reduced-motion path, milliseconds.
@export var reduced_motion_fade_ms: float = 400.0

## Interstitial fade-in duration in milliseconds (Story 007).
@export var interstitial_fade_in_ms: float = 400.0
## Interstitial fade-out duration in milliseconds (Story 007).
@export var interstitial_fade_out_ms: float = 400.0

## When true, renders current state name in a corner (debug builds only).
@export var debug_draw_state: bool = false


# ── Node references (set in _ready) ──────────────────────────────────────────

var input_blocker: ColorRect
var overlay: Polygon2D
var rustle_audio: AudioStreamPlayer
var interstitial_panel: Control
var illustration_rect: TextureRect
var caption_label: Label

## Debug label — only created in debug builds when debug_draw_state is true.
var _debug_label: Label


# ── Private state ─────────────────────────────────────────────────────────────

## Authoritative FSM state.
var _current_state: State = State.FIRST_REVEAL

## Active rise/fade Tween. Killed before a new one is created.
var _active_tween: Tween

## Whether scene_started arrived while in FADING_OUT (E-5 buffer).
var _scene_started_buffered: bool = false

## Per-transition resolved breathe amplitude (drawn from nominal ± variation).
var _breathe_amplitude: float = 0.03

## Seconds elapsed in HOLDING state, for paper-breathe formula.
var _hold_elapsed_sec: float = 0.0

## Loaded transition variants resource; null if file is missing or wrong type.
var _variants_resource: TransitionVariants

## Pre-allocated polygon array (26 points). Reused each transition (no hot-path alloc).
var _polygon_points: PackedVector2Array

## Current scene_id passed to _begin_fading_out — used to look up interstitial config.
var _current_scene_id: String = ""
## Independent Tween for interstitial fade-in/hold/fade-out sequence.
var _interstitial_tween: Tween
## Guard used by the reduced-motion SceneTreeTimer callback (no cancel() in Godot 4.3).
var _interstitial_active: bool = false

## SceneManager emits `epilogue_started` ~1 frame after `scene_completed`, which
## would cancel the final scene's interstitial before it plays. When that
## happens mid-transition we set this flag and run `_begin_epilogue()` after
## the fade+interstitial+fade-in sequence reaches IDLE.
var _deferred_epilogue: bool = false


# ── Lifecycle ─────────────────────────────────────────────────────────────────

## Subscribe to EventBus signals here — before _ready() — to avoid the
## first-frame ordering race with Scene Goal System (GDD Core Rule 2, AC-001).
func _enter_tree() -> void:
	EventBus.scene_completed.connect(_on_scene_completed)
	EventBus.scene_started.connect(_on_scene_started)
	EventBus.epilogue_started.connect(_on_epilogue_started)
	_load_variants_resource()
	_validate_joint_knob_constraint()


## _ready() is for initial state setup only — not subscriptions (GDD Core Rule 2).
func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS

	input_blocker = $InputBlocker
	overlay = $Overlay
	rustle_audio = $RustleAudio
	interstitial_panel = $InterstitialPanel
	illustration_rect = $InterstitialPanel/IllustrationRect
	caption_label = $InterstitialPanel/CaptionLabel
	# CaptionLabel's default font is Latin-only — apply CJK-capable SystemFont
	# so the drive interstitial "予天地山水 與妳" (and any future CJK caption)
	# renders instead of tofu. Font size is preserved from the scene file.
	var cjk_font := SystemFont.new()
	cjk_font.font_names = PackedStringArray([
		"PingFang TC", "Heiti TC", "Microsoft JhengHei",
		"Noto Sans CJK TC", "Noto Sans TC",
	])
	caption_label.add_theme_font_override("font", cjk_font)
	caption_label.add_theme_font_size_override("font_size", 48)
	caption_label.add_theme_color_override("font_color", Color(0.20, 0.14, 0.09, 1.0))
	interstitial_panel.visible = false
	interstitial_panel.modulate.a = 0.0
	interstitial_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Pre-allocate polygon array — 26 points for 12-segment strip.
	_polygon_points.resize(26)

	# FIRST_REVEAL: start fully opaque cream (GDD Core Rule 8).
	overlay.modulate = overlay_color_cream
	overlay.modulate.a = 1.0
	overlay.visible = true
	input_blocker.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if OS.is_debug_build() and debug_draw_state:
		_setup_debug_label()


## Paper-breathe alpha modulation runs in _process during HOLDING (GDD Formula 4).
func _process(delta: float) -> void:
	if _current_state != State.HOLDING:
		_hold_elapsed_sec = 0.0
		return
	_hold_elapsed_sec += delta
	overlay.modulate.a = _compute_breathe_alpha(_hold_elapsed_sec, _breathe_amplitude, breathe_period_sec)

	if OS.is_debug_build() and debug_draw_state and _debug_label:
		_debug_label.text = State.keys()[_current_state]


# ── EventBus signal handlers ──────────────────────────────────────────────────

## Primary trigger for the page turn (GDD Core Rule 3).
## Signal-storm guard: ignored if not in IDLE (GDD Core Rule 13, AC-007).
func _on_scene_completed(scene_id: String) -> void:
	if _current_state != State.IDLE:
		push_warning("STUI: scene_completed ignored in state %s (signal-storm guard)" % State.keys()[_current_state])
		return

	# cancel_drag same frame — before any Tween (GDD Core Rule 6, AC-009).
	InputSystem.cancel_drag()

	_begin_fading_out(scene_id)


## Triggers fade-out of overlay once new scene is placed (GDD States table).
## Ignored if not in a state that expects it; buffered if in FADING_OUT (E-5).
func _on_scene_started(_scene_id: String) -> void:
	match _current_state:
		State.FIRST_REVEAL:
			_begin_first_reveal_fade()
		State.HOLDING:
			if _interstitial_active:
				_cancel_interstitial()
			_begin_fading_in()
		State.FADING_OUT:
			# Buffer — will skip HOLDING when FADING_OUT Tween completes (E-5, AC-008).
			_scene_started_buffered = true
		State.IDLE:
			push_warning("STUI: scene_started received while IDLE — handshake mismatch (E-4)")
		_:
			pass  # FADING_IN, EPILOGUE — ignored


## Epilogue variant trigger (GDD Core Rule 9, GDD Edge Case E-7).
func _on_epilogue_started() -> void:
	if _current_state == State.EPILOGUE:
		return
	# Mid-transition of the previous scene: let the page-turn and interstitial
	# finish, then run epilogue when we drop back to IDLE. Without this guard
	# SceneManager's same-frame epilogue emit cancels the final interstitial.
	if _current_state in [State.FADING_OUT, State.HOLDING, State.FADING_IN] or _interstitial_active:
		_deferred_epilogue = true
		return
	_begin_epilogue()


# ── State transition methods ──────────────────────────────────────────────────

## Enter FADING_OUT: rise Tween + input block (GDD Core Rule 5).
func _begin_fading_out(scene_id: String) -> void:
	_current_scene_id = scene_id
	var reduced_motion: bool = ProjectSettings.get_setting("stui/reduced_motion_default", false)
	var durations := _resolve_phase_durations(reduced_motion, false)

	_set_state(State.FADING_OUT)
	_scene_started_buffered = false

	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	_build_polygon_flat(vp_size)

	var r_theta: float = randf_range(-1.0, 1.0)
	var peak_rot: float = _compute_curl_rotation(r_theta, curl_rotation_nominal_deg, curl_rotation_variation_deg)
	if reduced_motion:
		peak_rot = 0.0

	var pitch: float = _compute_pitch_scale(randf_range(-1.0, 1.0), pitch_semitone_range, reduced_motion)
	rustle_audio.volume_db = rustle_volume_db
	rustle_audio.pitch_scale = pitch
	rustle_audio.play()

	# Apply per-scene fold_duration_scale from variants config.
	var fold_scale: float = _get_variant_knob(scene_id, "fold_duration_scale", 1.0)
	var rise_sec: float = (durations[0] * fold_scale) / 1000.0

	_kill_active_tween()
	_active_tween = create_tween()
	_active_tween.set_parallel(false)

	if reduced_motion:
		_active_tween.tween_property(overlay, "modulate:a", 1.0, rise_sec) \
			.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_LINEAR)
	else:
		var curl_peak_sec: float = rise_sec * curl_peak_time_frac
		var post_peak_sec: float = rise_sec - curl_peak_sec
		_active_tween.tween_property(overlay, "modulate:a", 1.0, rise_sec) \
			.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)
		_active_tween.parallel().tween_property(overlay, "rotation_degrees", peak_rot, curl_peak_sec) \
			.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)
		_active_tween.tween_property(overlay, "rotation_degrees", 0.0, post_peak_sec) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

	_active_tween.tween_callback(_on_fading_out_complete)


## Called when the FADING_OUT rise Tween completes.
func _on_fading_out_complete() -> void:
	overlay.modulate.a = 1.0
	overlay.rotation_degrees = 0.0

	if _scene_started_buffered:
		# E-5: skip HOLDING, go directly to FADING_IN.
		_scene_started_buffered = false
		_begin_fading_in()
	else:
		_enter_holding()


## Enter HOLDING: paper-breathe begins (GDD Core Rule 5, Formula 4).
func _enter_holding() -> void:
	_set_state(State.HOLDING)
	_hold_elapsed_sec = 0.0
	var r_a: float = randf_range(-1.0, 1.0)
	_breathe_amplitude = clampf(breathe_amplitude_nominal + r_a * breathe_amplitude_variation, 0.0, 1.0)
	# _process drives the alpha oscillation each frame.
	_try_begin_interstitial()


## Enter FADING_IN: overlay alpha 1→0 reveals new scene (GDD Core Rule 5).
func _begin_fading_in() -> void:
	var reduced_motion: bool = ProjectSettings.get_setting("stui/reduced_motion_default", false)
	var durations := _resolve_phase_durations(reduced_motion, false)
	var fade_sec: float = durations[2] / 1000.0

	_set_state(State.FADING_IN)

	_kill_active_tween()
	_active_tween = create_tween()
	if reduced_motion:
		_active_tween.tween_property(overlay, "modulate:a", 0.0, fade_sec) \
			.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_LINEAR)
	else:
		_active_tween.tween_property(overlay, "modulate:a", 0.0, fade_sec) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_active_tween.tween_callback(_on_fading_in_complete)


## Called when FADING_IN Tween completes — transition to IDLE (AC-005).
func _on_fading_in_complete() -> void:
	overlay.modulate.a = 0.0
	_set_state(State.IDLE)
	if _deferred_epilogue:
		_deferred_epilogue = false
		_begin_epilogue()


## Fade out the initial opaque overlay on game boot (GDD Core Rule 8, AC-015).
func _begin_first_reveal_fade() -> void:
	# Only fires once — FIRST_REVEAL is a one-shot state.
	if _active_tween and _active_tween.is_running():
		return
	# No SFX, no curl, linear ease (GDD Core Rule 8).
	_kill_active_tween()
	_active_tween = create_tween()
	_active_tween.tween_property(overlay, "modulate:a", 0.0, first_reveal_fade_ms / 1000.0) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_LINEAR)
	_active_tween.tween_callback(_on_first_reveal_complete)


## Called when FIRST_REVEAL fade completes.
func _on_first_reveal_complete() -> void:
	overlay.modulate.a = 0.0
	_set_state(State.IDLE)


## Enter EPILOGUE state with amber tint and scaled timings (GDD Core Rule 9, AC-006).
func _begin_epilogue() -> void:
	_cancel_interstitial()
	var reduced_motion: bool = ProjectSettings.get_setting("stui/reduced_motion_default", false)
	var durations := _resolve_phase_durations(reduced_motion, true)
	var rise_sec: float = durations[0] / 1000.0

	_set_state(State.EPILOGUE)
	_breathe_amplitude = 0.0  # Paper-breathe disabled in epilogue (AC-016).

	# Amber tint applied when rise completes, not now (Implementation Notes Story 005).
	_kill_active_tween()
	_active_tween = create_tween()
	if reduced_motion:
		_active_tween.tween_property(overlay, "modulate:a", 1.0, rise_sec) \
			.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_LINEAR)
	else:
		_active_tween.tween_property(overlay, "modulate:a", 1.0, rise_sec) \
			.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)
	_active_tween.tween_callback(_on_epilogue_rise_complete)


## Called when the epilogue rise Tween reaches full opacity.
## Applies amber tint and emits epilogue_cover_ready exactly once (AC-006).
func _on_epilogue_rise_complete() -> void:
	overlay.modulate.a = 1.0
	overlay.modulate = overlay_color_amber
	overlay.modulate.a = 1.0
	# Hold is open-ended; no auto-fade. Paper-breathe is disabled (AC-016).
	EventBus.epilogue_cover_ready.emit()


# ── State helper ──────────────────────────────────────────────────────────────

## Set FSM state and update InputBlocker mouse_filter accordingly.
func _set_state(new_state: State) -> void:
	_current_state = new_state
	match new_state:
		State.IDLE, State.FIRST_REVEAL:
			input_blocker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_:
			input_blocker.mouse_filter = Control.MOUSE_FILTER_STOP

	if OS.is_debug_build() and debug_draw_state and _debug_label:
		_debug_label.text = State.keys()[new_state]


# ── Formula implementations ───────────────────────────────────────────────────

## Formula 1 — Per-Transition Phase Duration with clamp (GDD Formula 1, AC-011).
##
## Returns [rise_ms, hold_ms, fade_ms] as floats.
## [param reduced_motion] When true, returns fixed reduced-motion durations — not clamped.
## [param is_epilogue] When true, rise and fade nominals scale by epilogue_time_scale.
##
## Example: rise=440, hold=955, fade=564 → total=1959, within [1700,2200], no scaling.
func _resolve_phase_durations(reduced_motion: bool, is_epilogue: bool) -> Array[float]:
	if reduced_motion:
		return [reduced_motion_rise_ms, reduced_motion_hold_ms, reduced_motion_fade_ms]

	var r_rise: float = randf_range(-1.0, 1.0)
	var r_hold: float = randf_range(-1.0, 1.0)
	var r_fade: float = randf_range(-1.0, 1.0)

	var rise_nom: float = rise_nominal_ms
	var fade_nom: float = fade_out_nominal_ms
	if is_epilogue:
		rise_nom *= epilogue_time_scale
		fade_nom *= epilogue_time_scale

	var d_rise: float = rise_nom + r_rise * rise_variation_ms
	var d_hold: float = hold_nominal_ms + r_hold * hold_variation_ms
	var d_fade: float = fade_nom + r_fade * fade_out_variation_ms

	if is_epilogue:
		# Epilogue hold is open-ended — excluded from clamp (GDD Formula 1, Epilogue section).
		var rf_total: float = d_rise + d_fade
		if rf_total > total_max_ms:
			var scale: float = total_max_ms / rf_total
			d_rise *= scale
			d_fade *= scale
		elif rf_total < total_min_ms:
			var scale: float = total_min_ms / rf_total
			d_rise *= scale
			d_fade *= scale
		return [d_rise, d_hold, d_fade]

	var t_total: float = d_rise + d_hold + d_fade
	if t_total > total_max_ms:
		var scale: float = total_max_ms / t_total
		d_rise *= scale
		d_hold *= scale
		d_fade *= scale
	elif t_total < total_min_ms:
		var scale: float = total_min_ms / t_total
		d_rise *= scale
		d_hold *= scale
		d_fade *= scale

	return [d_rise, d_hold, d_fade]


## Formula 2 — Curl Peak Rotation (GDD Formula 2).
## [param r_theta] Random draw in [-1.0, 1.0].
## Returns resolved rotation in degrees.
## Example: r_theta=-0.4 → 4.0 + (-0.4)*1.5 = 3.4°
func _compute_curl_rotation(r_theta: float, theta_nom: float, v_theta: float) -> float:
	return theta_nom + r_theta * v_theta


## Formula 3 — Audio Pitch Scale via true semitone math (GDD Formula 3, AC-012).
## [param r_p] Random draw in [-1.0, 1.0].
## [param s_range] Semitone range (default 4.0).
## [param reduced_motion] When true, returns exactly 1.0.
## Example: r_p=0.7, s_range=4.0 → 2^(0.7*4/12) ≈ 1.175
func _compute_pitch_scale(r_p: float, s_range: float, reduced_motion: bool) -> float:
	if reduced_motion:
		return 1.0
	return pow(2.0, r_p * s_range / 12.0)


## Formula 4 — Paper-Breathe Alpha Modulation (GDD Formula 4, AC-013).
## [param t] Seconds since entering HOLDING state.
## [param amplitude] Breathe amplitude (A).
## [param period] Breathe period in seconds (P).
## Returns overlay alpha in [1.0 - A, 1.0]. α(0) = 1.0 exactly.
## Example: t=0.35, A=0.03, P=0.7 → 1.0 - 0.03*(1-cos(π))/2 = 0.97
func _compute_breathe_alpha(t: float, amplitude: float, period: float) -> float:
	if amplitude <= 0.0 or period <= 0.0:
		return 1.0
	return 1.0 - amplitude * (1.0 - cos(2.0 * PI * t / period)) / 2.0


# ── Polygon2D geometry ────────────────────────────────────────────────────────

## Build a flat 12-segment vertical strip spanning the full viewport.
## 13 top-edge vertices (y=0) + 13 bottom-edge vertices (y=height) = 26 points.
## Vertex positions are computed from viewport size — no hardcoded pixels (GDD UI Req).
## Reuses the pre-allocated _polygon_points array (zero hot-path allocation).
func _build_polygon_flat(vp_size: Vector2) -> void:
	for col in range(13):
		var x: float = vp_size.x * col / 12.0
		_polygon_points[col] = Vector2(x, 0.0)           # Top edge
		_polygon_points[13 + col] = Vector2(x, vp_size.y) # Bottom edge
	overlay.polygon = _polygon_points


# ── Config loading (ADR-005, Story 006) ──────────────────────────────────────

## Load transition-variants.tres at _enter_tree(). Null on missing/wrong type (E-10).
func _load_variants_resource() -> void:
	var path: String = "res://assets/data/ui/transition-variants.tres"
	_variants_resource = ResourceLoader.load(path) as TransitionVariants
	if _variants_resource == null:
		push_warning("STUI: could not load '%s' as TransitionVariants — using hardcoded defaults (E-10)" % path)


## Get a per-scene knob value from the variants config.
## Falls back to "default" key, then to [param fallback_value].
## Only the keys documented in GDD §Tuning Knobs — Per-scene override are consumed.
func _get_variant_knob(scene_id: String, knob_name: String, fallback_value: Variant) -> Variant:
	if _variants_resource == null:
		return fallback_value
	var scene_dict: Variant = _variants_resource.variants.get(scene_id)
	if scene_dict == null:
		scene_dict = _variants_resource.variants.get("default")
	if scene_dict == null or not scene_dict is Dictionary:
		return fallback_value
	return (scene_dict as Dictionary).get(knob_name, fallback_value)


## Get the paper_tint for a scene, with per-channel clamping (E-10).
func _get_validated_paper_tint(scene_id: String) -> Color:
	var raw: Variant = _get_variant_knob(scene_id, "paper_tint", overlay_color_cream)
	if not raw is Color:
		return overlay_color_cream
	var c: Color = raw as Color
	return Color(clampf(c.r, 0.0, 1.0), clampf(c.g, 0.0, 1.0), clampf(c.b, 0.0, 1.0), c.a)


## Validate joint knob constraint at startup (GDD Formula 1, Joint knob constraint).
## Logs a warning if current knobs would produce heavy clamp factors.
func _validate_joint_knob_constraint() -> void:
	var sigma_min: float = rise_nominal_ms - rise_variation_ms \
		+ hold_nominal_ms - hold_variation_ms \
		+ fade_out_nominal_ms - fade_out_variation_ms
	var sigma_max: float = rise_nominal_ms + rise_variation_ms \
		+ hold_nominal_ms + hold_variation_ms \
		+ fade_out_nominal_ms + fade_out_variation_ms
	if sigma_min < total_min_ms:
		push_warning("STUI: joint knob constraint violated — Σ(D_nom - V) = %.0f < T_MIN = %.0f" % [sigma_min, total_min_ms])
	if sigma_max > total_max_ms + 100.0:
		push_warning("STUI: joint knob constraint violated — Σ(D_nom + V) = %.0f > T_MAX + 100 = %.0f" % [sigma_max, total_max_ms + 100.0])


# ── Interstitial illustration (Story 007) ────────────────────────────────────

## Queued slides for a multi-slide interstitial sequence. Each entry is a
## Dictionary with keys `illustration` (Texture2D), `caption` (String),
## `hold_ms` (float). Consumed one-by-one by `_play_next_slide()`.
var _interstitial_queue: Array[Dictionary] = []


## If the current scene has an interstitial config, show it and drive the
## fade/hold sequence. No-op when config is missing or malformed (AC-3).
## Accepts two config shapes:
##   (a) Single-slide (legacy):
##       { illustration: Texture2D, caption: String, hold_ms: float }
##   (b) Multi-slide:
##       { slides: [ { illustration, caption, hold_ms }, ... ] }
##   Slides play back-to-back; each fades in, holds, and fades out using the
##   same `interstitial_fade_in_ms` / `_fade_out_ms` knobs.
func _try_begin_interstitial() -> void:
	var cfg_variant: Variant = _get_variant_knob(_current_scene_id, "interstitial", null)
	if cfg_variant == null or not cfg_variant is Dictionary:
		return
	var cfg: Dictionary = cfg_variant as Dictionary

	_interstitial_queue = _build_interstitial_queue(cfg)
	if _interstitial_queue.is_empty():
		push_warning("STUI: interstitial config for '%s' has no playable slides — skipping" % _current_scene_id)
		return

	interstitial_panel.visible = true
	interstitial_panel.modulate.a = 0.0
	_interstitial_active = true

	_play_next_slide()


## Normalize the scene's interstitial config into a flat list of slides.
## Single-slide configs (legacy `illustration`/`caption`/`hold_ms` keys at
## top level) are promoted to a one-element list. Malformed slide entries
## are skipped with a warning.
func _build_interstitial_queue(cfg: Dictionary) -> Array[Dictionary]:
	var queue: Array[Dictionary] = []
	var raw_slides: Variant = cfg.get("slides", null)
	if raw_slides is Array:
		for entry_variant: Variant in raw_slides:
			if entry_variant is Dictionary and _is_valid_slide(entry_variant):
				queue.append(entry_variant)
			else:
				push_warning("STUI: invalid slide in interstitial for '%s' — skipped" % _current_scene_id)
	elif _is_valid_slide(cfg):
		queue.append(cfg)
	else:
		push_warning("STUI: interstitial config for '%s' has invalid types — skipping" % _current_scene_id)
	return queue


static func _is_valid_slide(slide: Dictionary) -> bool:
	return slide.get("illustration") is Texture2D \
		and slide.get("caption") is String \
		and (slide.get("hold_ms") is float or slide.get("hold_ms") is int)


## Pop the next slide off the queue and play its fade-in / hold / fade-out
## sequence. When the queue is empty, hand control to `_on_interstitial_done`
## which completes the overall sequence.
func _play_next_slide() -> void:
	if _interstitial_queue.is_empty():
		_on_interstitial_done()
		return

	var slide: Dictionary = _interstitial_queue.pop_front()
	illustration_rect.texture = slide["illustration"] as Texture2D
	caption_label.text = slide["caption"] as String
	var hold_ms: float = float(slide["hold_ms"])

	var reduced_motion: bool = ProjectSettings.get_setting("stui/reduced_motion_default", false)
	_kill_interstitial_tween()

	if reduced_motion:
		interstitial_panel.modulate.a = 1.0
		var timer: SceneTreeTimer = get_tree().create_timer(hold_ms / 1000.0)
		timer.timeout.connect(_on_interstitial_slide_reduced_motion_done)
	else:
		_interstitial_tween = create_tween()
		_interstitial_tween.tween_property(interstitial_panel, "modulate:a", 1.0, interstitial_fade_in_ms / 1000.0) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		_interstitial_tween.tween_interval(hold_ms / 1000.0)
		_interstitial_tween.tween_property(interstitial_panel, "modulate:a", 0.0, interstitial_fade_out_ms / 1000.0) \
			.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		_interstitial_tween.tween_callback(_play_next_slide)


## Reduced-motion path: after the hold timer for one slide, advance queue.
func _on_interstitial_slide_reduced_motion_done() -> void:
	if not _interstitial_active:
		return
	interstitial_panel.modulate.a = 0.0
	_play_next_slide()


## Completes the interstitial sequence and transitions to FADING_IN (AC-2).
## Called by `_play_next_slide()` once the queue is empty.
func _on_interstitial_done() -> void:
	_interstitial_active = false
	_interstitial_queue.clear()
	interstitial_panel.visible = false
	interstitial_panel.modulate.a = 0.0
	if _current_state == State.HOLDING:
		_begin_fading_in()


## Cancel the interstitial immediately (AC-6 / AC-7 safety).
func _cancel_interstitial() -> void:
	if not _interstitial_active:
		return
	_interstitial_active = false
	_interstitial_queue.clear()
	_kill_interstitial_tween()
	interstitial_panel.visible = false
	interstitial_panel.modulate.a = 0.0


## Kill and null the interstitial Tween to prevent orphaned callbacks.
func _kill_interstitial_tween() -> void:
	if _interstitial_tween:
		_interstitial_tween.kill()
		_interstitial_tween = null


# ── Tween lifecycle helper ────────────────────────────────────────────────────

## Kill and null the active Tween to prevent orphaned callbacks.
func _kill_active_tween() -> void:
	if _active_tween:
		_active_tween.kill()
		_active_tween = null


# ── Debug seam ────────────────────────────────────────────────────────────────

## Simulate scene_completed for a given scene_id without requiring SGS to fire.
## Test seam only — not exposed to gameplay (GDD UI Requirements, Debug section).
func _debug_force_transition(scene_id: String) -> void:
	if not OS.is_debug_build():
		return
	_on_scene_completed(scene_id)


## Create a debug label that renders current FSM state name.
## Only called in debug builds when debug_draw_state is true.
func _setup_debug_label() -> void:
	_debug_label = Label.new()
	_debug_label.name = "DebugStateLabel"
	_debug_label.position = Vector2(8.0, 8.0)
	_debug_label.modulate = Color(1.0, 0.2, 0.2)
	_debug_label.text = State.keys()[_current_state]
	add_child(_debug_label)
