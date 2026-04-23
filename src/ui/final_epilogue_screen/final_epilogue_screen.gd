## FinalEpilogueScreen — terminal presentation layer for Moments.
##
## Pre-instanced as a child of EpilogueLayer (CanvasLayer, layer=20) inside
## gameplay.tscn per ADR-004 §2. Never loaded via change_scene_to_file.
##
## State machine: ARMED → REVEALING → BLACKOUT → HOLDING → QUITTING
## Reveal is gated on EventBus.epilogue_cover_ready (emitted by STUI).
## A COVER_READY_TIMEOUT safety timer begins at _ready() in case STUI never fires.
##
## On reveal entry:
##   - Cursor is hidden
##   - AudioManager.fade_out_all() is called (guarded by has_method)
##   - Illustration texture is loaded (null-safe — background-only fallback on failure)
##   - Tween fades modulate.a 0→1 over FADE_IN_DURATION (quadratic ease-out)
##
## Input is accepted only after BLACKOUT expires. Dismiss calls get_tree().quit().
## FES writes no save state — it is a pure terminal consumer (ADR-004 §6).
##
## Implements: design/gdd/final-epilogue-screen.md
## Governed by: ADR-001 (naming), ADR-003 (EventBus), ADR-004 (scene composition)
class_name FinalEpilogueScreen
extends Control

# ── Tuning knobs (const, not @export — GDD §Tuning Knobs) ───────────────────

## Fade-in duration in milliseconds. Formula F-1: quadratic ease-out 0→1.
## Safe range: 1000–4000 ms.
const FADE_IN_DURATION: float = 2000.0

## Input blackout window in milliseconds after fade-in completes.
## Formula F-2: strict boolean gate. Safe range: 1000–3000 ms.
const INPUT_BLACKOUT_DURATION: float = 1500.0

## Safety fallback timeout in milliseconds. If epilogue_cover_ready has not
## fired within this window, FES begins fade-in anyway (GDD EC-4).
## Safe range: 3000–10000 ms.
const COVER_READY_TIMEOUT: float = 5000.0

## res:// path to the handcrafted epilogue illustration PNG.
## Changing this requires both a code edit and a file on disk (intentional).
const ILLUSTRATION_PATH: String = "res://assets/epilogue/illustration.png"

## Whether to call AudioManager.fade_out_all() on reveal. False = audio-less debug.
const AUDIO_FADE_OUT: bool = true

## Whether to hide the cursor on reveal entry. False = useful for dev screenshots.
const CURSOR_HIDE_ON_REVEAL: bool = true

# ── State machine ─────────────────────────────────────────────────────────────

## Internal state machine per GDD §States and Transitions.
## No backward transitions. HOLDING is the stable-loop state.
enum State { ARMED, REVEALING, BLACKOUT, HOLDING, QUITTING }

var _state: State = State.ARMED

# ── Scene node references ─────────────────────────────────────────────────────

## Solid-color background fill — visible when illustration is absent (EC-3 fallback).
@onready var _background: ColorRect = %Background

## TextureRect inside CenterContainer; null texture → transparent (background only).
@onready var _illustration: TextureRect = %Illustration

## Safety timer — started at _ready(); fires _on_cover_ready_timeout if STUI silent.
@onready var _cover_ready_timeout_timer: Timer = %CoverReadyTimeoutTimer

## One-shot blackout timer — started only after Tween finished signal (EC-13 guard).
@onready var _blackout_timer: Timer = %BlackoutTimer


func _ready() -> void:
	# ── Story 001: _ready() sequence (order is load-bearing per GDD Core Rule 5) ──

	# FES is pre-instanced in gameplay.tscn per ADR-004 §2, so _ready() runs at
	# boot — long before any memory is earned. The earned-guard belongs on the
	# reveal path, not at _ready(). Here we simply enter Armed state (alpha=0)
	# and wait for epilogue_cover_ready. The guard re-runs inside
	# _on_epilogue_cover_ready so an ordering bug still can't produce a visible
	# reveal.

	# Set modulate alpha=0 BEFORE any Tween is created to prevent one-frame flash.
	modulate = Color(1.0, 1.0, 1.0, 0.0)

	# Connect cover-ready with CONNECT_ONE_SHOT — second/third emissions are no-ops
	# at the signal-dispatch level (AC-ONESHOT-1, ADR-003, GDD Core Rule 2).
	EventBus.epilogue_cover_ready.connect(_on_epilogue_cover_ready, CONNECT_ONE_SHOT)

	# ── Story 004: COVER_READY_TIMEOUT safety timer (GDD EC-4) ───────────────────
	# Configure now but do NOT start — the timer arms only when the epilogue
	# sequence is actually requested (via epilogue_started). Starting at _ready()
	# triggers the fallback fade-in during normal gameplay and blacks out the
	# screen after 5s. See `_on_epilogue_started`.
	_cover_ready_timeout_timer.wait_time = COVER_READY_TIMEOUT / 1000.0
	_cover_ready_timeout_timer.one_shot = true
	_cover_ready_timeout_timer.timeout.connect(_on_cover_ready_timeout)
	EventBus.epilogue_started.connect(_on_epilogue_started)

	# ── Story 002: configure blackout timer (not started here — see EC-13) ───────
	_blackout_timer.wait_time = INPUT_BLACKOUT_DURATION / 1000.0
	_blackout_timer.one_shot = true
	_blackout_timer.timeout.connect(_on_blackout_complete)


# ── Story 004: cover-ready fallback timer callback ───────────────────────────

## Arms the cover-ready watchdog when the epilogue handoff actually starts.
## Outside of this signal FES sits dormant (modulate.a == 0) — no watchdog.
func _on_epilogue_started() -> void:
	if _state != State.ARMED:
		return
	_cover_ready_timeout_timer.start()


## Called if epilogue_cover_ready has not fired within COVER_READY_TIMEOUT.
## Guards against re-entry: if reveal already started the state is no longer
## ARMED, so the timer callback is a safe no-op (GDD EC-4).
func _on_cover_ready_timeout() -> void:
	if _state != State.ARMED:
		return
	push_warning(
		"FES: epilogue_cover_ready not received within 5000ms; beginning fade-in without STUI handoff"
	)
	_on_epilogue_cover_ready()


# ── Story 001 / 002 / 004: reveal entry ──────────────────────────────────────

## Called on first (and only) receipt of EventBus.epilogue_cover_ready.
## CONNECT_ONE_SHOT ensures this handler is disconnected after first call;
## subsequent emissions are silently discarded at the signal level.
##
## Sequence per GDD Core Rule 6 and Story 004:
##   1. Transition state → REVEALING
##   2. Hide cursor (Story 004, GDD Core Rule 11)
##   3. Fade out audio (Story 004, GDD EC-15 has_method guard)
##   4. Load illustration texture (Story 005, null-safe fallback)
##   5. Create Tween (Story 002, GDD F-1)
func _on_epilogue_cover_ready() -> void:
	_state = State.REVEALING

	# ── Story 004: cursor hide ────────────────────────────────────────────────
	if CURSOR_HIDE_ON_REVEAL:
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

	# ── Story 004: audio fade — direct autoload call, guarded by has_method ──
	# has_method guard per GDD EC-15: method may not yet exist at FES ship time.
	# StringName literal (&"fade_out_all") used for efficient comparison (ADR-001).
	if AUDIO_FADE_OUT and AudioManager.has_method(&"fade_out_all"):
		AudioManager.fade_out_all(FADE_IN_DURATION / 1000.0)

	# ── Story 005: load illustration (before Tween so texture is ready as alpha rises)
	_load_illustration()

	# ── Story 002: fade-in Tween (GDD F-1, quadratic ease-out) ──────────────
	var tween: Tween = create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(self, "modulate:a", 1.0, FADE_IN_DURATION / 1000.0)
	tween.finished.connect(_on_fade_in_complete)


# ── Story 005: illustration load with null-safe fallback ─────────────────────

## Attempts to load the illustration PNG. On failure: logs to stderr and returns
## early. TextureRect with null texture renders transparent — ColorRect (Background)
## remains visible as the solid-color fallback (GDD EC-3, AC-FAIL-2).
func _load_illustration() -> void:
	var texture: Texture2D = ResourceLoader.load(ILLUSTRATION_PATH, "Texture2D") as Texture2D
	if texture == null:
		push_error(
			"FES: illustration PNG failed to load from '%s' — rendering background color only"
			% ILLUSTRATION_PATH
		)
		return
	_illustration.texture = texture


# ── Story 002: post-fade-in transition → BLACKOUT ────────────────────────────

## Connected to Tween.finished. Starts the input blackout timer.
## Critical: Timer must start here (on Tween.finished), NOT in _ready() or
## _on_epilogue_cover_ready(). Starting it earlier would let the blackout expire
## before the fade completes (GDD EC-13).
func _on_fade_in_complete() -> void:
	_state = State.BLACKOUT
	_blackout_timer.start()


# ── Story 002: post-blackout transition → HOLDING ────────────────────────────

## Connected to _blackout_timer.timeout. Arms input acceptance.
func _on_blackout_complete() -> void:
	_state = State.HOLDING


# ── Story 003: input filter ───────────────────────────────────────────────────

## Input acceptance filter per GDD Core Rule 8.
##
## State guard:
##   - REVEALING / BLACKOUT: all input rejected (AC-INPUT-1, AC-INPUT-2)
##   - QUITTING: reject (prevents double-quit on theoretical re-entrance)
##   - ARMED: reject (no input before reveal)
##   - HOLDING: proceed to filter rules below
##
## Filter rules (HOLDING only):
##   - InputEventMouseMotion: always rejected (GDD EC-5, AC-INPUT-4)
##   - InputEventMouseButton.pressed==false: rejected (GDD EC-7, AC-INPUT-6)
##   - InputEventKey.pressed==false: rejected (release event)
##   - InputEventKey.echo==true: rejected (GDD EC-6, AC-INPUT-7)
##   - InputEventKey.keycode==KEY_ESCAPE: rejected (GDD EC-8, AC-INPUT-5)
##   - All other events: dismiss (AC-INPUT-3)
func _unhandled_input(event: InputEvent) -> void:
	if _state != State.HOLDING:
		return
	if event is InputEventMouseMotion:
		return
	if event is InputEventMouseButton and not event.pressed:
		return
	if event is InputEventKey:
		if not event.pressed or event.echo:
			return
		if event.keycode == KEY_ESCAPE:
			return
	_on_dismiss()


# ── Story 003: dismiss ────────────────────────────────────────────────────────

## Test seam: called instead of `get_tree().quit()` when non-null.
## Production code leaves this null; tests assign a no-op callable to verify
## that _state == QUITTING is reached without terminating the runner.
var _quit_override: Callable = Callable()


## Terminal dismiss handler. Sets state to QUITTING first as a re-entrant guard,
## then calls get_tree().quit(). No scene swap. No signal emitted.
## FES is a terminal leaf node — application exit is the complete dismiss action
## (GDD Core Rule 9, GDD §Dependencies — Downstream: None).
func _on_dismiss() -> void:
	_state = State.QUITTING
	if _quit_override.is_valid():
		_quit_override.call()
	else:
		get_tree().quit()
