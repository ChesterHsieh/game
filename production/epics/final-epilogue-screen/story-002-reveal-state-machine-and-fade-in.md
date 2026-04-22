# Story 002: Reveal state machine and fade-in

> **Epic**: Final Epilogue Screen
> **Status**: Complete
> **Layer**: Presentation
> **Type**: Logic
> **Manifest Version**: 2026-04-21

## Context

**GDD**: `design/gdd/final-epilogue-screen.md`
**Requirements**: `TR-final-epilogue-screen-003`, `TR-final-epilogue-screen-004`, `TR-final-epilogue-screen-005`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-004: Runtime Scene Composition, Autoload Order, and Epilogue Handoff
**ADR Decision Summary**: FES stays inside `gameplay.tscn` for the full epilogue; no scene swap occurs. STUI emits `epilogue_cover_ready` once its amber overlay reaches full opacity; this is FES's reveal gate — not `final_memory_ready`. FES manages its own state machine internally, transitioning through Armed → Loading → Ready → Revealing → Blackout → Holding → Quitting.

**Engine**: Godot 4.3 | **Risk**: LOW
**Engine Notes**: `create_tween()` with `.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)` and `.tween_property(self, "modulate:a", 1.0, duration)` are stable in 4.3 per `VERSION.md`. `Tween.finished` signal is stable. `Timer` node with `one_shot = true` started via `start()` is stable. `_unhandled_input` early-return pattern is the standard Godot input-blocking idiom.

**Control Manifest Rules (Presentation Layer)**:
- Required: EpilogueLayer is CanvasLayer layer=20; FES pre-instanced in Armed state
- Required: STUI emits `epilogue_cover_ready`; FES waits on this before fading in
- Forbidden: Never make FES its own autoload or use `change_scene_to_file` to reach it

---

## Acceptance Criteria

*From GDD `design/gdd/final-epilogue-screen.md`, scoped to this story:*

- [ ] **AC-REVEAL-1**: Given FES has loaded (`_ready()` completed) and `EventBus.epilogue_cover_ready` is received, the Tween on `modulate:a` starts within 1 frame (16.7ms) and completes over `FADE_IN_DURATION ± 50ms`.
- [ ] **AC-INPUT-1**: During the `Revealing` state (fade-in in progress), any input event is ignored. `get_tree().quit()` is NOT called.
- [ ] **AC-INPUT-2**: During the `Blackout` state (first 1500ms after fade-in completes), any input event is ignored. Inputs at 100ms, 500ms, and 1400ms after fade-in finished do not call `get_tree().quit()`.

---

## Implementation Notes

*Derived from ADR-004 §4 and GDD Detailed Design §States and Transitions, §Formulas:*

**State machine enum (GDD §States and Transitions)**:
```gdscript
enum State { ARMED, LOADING, READY, REVEALING, BLACKOUT, HOLDING, QUITTING }
var _state: State = State.ARMED
```
No backward transitions are legal. `HOLDING` is the stable-loop state.

**`_on_epilogue_cover_ready()` — entry into Revealing (GDD Core Rule 6)**:
1. Transition `_state` from Armed/Ready → Revealing.
2. Create Tween: `create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)`.
3. Call `.tween_property(self, "modulate:a", 1.0, FADE_IN_DURATION / 1000.0)` — duration converted from ms to seconds as required by `tween_property`.
4. Connect `tween.finished.connect(_on_fade_in_complete)`.

**Formula F-1 (GDD §Formulas)**: `alpha(t) = 1.0 - (1.0 - t / FADE_IN_DURATION)^2`. The `EASE_OUT + TRANS_QUAD` combination on `tween_property` produces this exact curve natively — no manual math required.

**`_on_fade_in_complete()` — entry into Blackout (GDD Core Rule 7)**:
1. Transition `_state` → Blackout.
2. Start the input blackout Timer: `_blackout_timer.start()`. The Timer must be configured with `wait_time = INPUT_BLACKOUT_DURATION / 1000.0` and `one_shot = true`.
3. **Critical**: the Timer MUST be started here, on `tween.finished`, NOT in `_ready()` or `_on_epilogue_cover_ready()`. GDD EC-13 documents this explicitly: starting the timer before the Tween finishes is an illegal state (the blackout would expire before the fade completes).
4. Connect `_blackout_timer.timeout.connect(_on_blackout_complete)`.

**`_on_blackout_complete()` — entry into Holding**:
1. Transition `_state` → Holding.
2. Set `_input_armed = true` (or rely on state check in `_unhandled_input`).

**Input blocking in `_unhandled_input` (GDD Core Rule 7)**:
```gdscript
func _unhandled_input(event: InputEvent) -> void:
    if _state == State.REVEALING or _state == State.BLACKOUT:
        return
    # filter logic handled in Story 003
```
During `REVEALING` and `BLACKOUT`, the early-return ensures no dismiss path is reachable. This covers AC-INPUT-1 and AC-INPUT-2 without any additional guard.

**Constants (GDD §Tuning Knobs — `const` not `@export`)**:
```gdscript
const FADE_IN_DURATION: float = 2000.0       # milliseconds
const INPUT_BLACKOUT_DURATION: float = 1500.0 # milliseconds
```
These are frozen-once-tuned values. Per GDD §Tuning Knobs note: `const` gives compile-time reference checking and prevents runtime mutation. `@export` and `const` are mutually exclusive in GDScript 4.x — do not attempt to `@export` a `const`.

---

## Out of Scope

- Story 001: Pre-instancing, CONNECT_ONE_SHOT wiring, and `_ready()` guard sequence
- Story 003: Full `_unhandled_input` filter rules and `_on_dismiss()` / `get_tree().quit()` call
- Story 004: AudioManager.fade_out_all() call and COVER_READY_TIMEOUT safety timer
- Story 005: Visual layout nodes (ColorRect, TextureRect, CenterContainer)

---

## QA Test Cases

*Logic — automated (`tests/unit/final-epilogue-screen/fes_state_machine_test.gd`):*

- **AC-REVEAL-1**: Tween starts within 1 frame of `epilogue_cover_ready`; completes over `FADE_IN_DURATION ± 50ms`
  - Given: FES instantiated with MUT stub returning `is_final_memory_earned() = true`; `_ready()` completed; FES in Armed/Ready state
  - When: `EventBus.epilogue_cover_ready.emit()` is called
  - Then: Tween on `modulate:a` is created within 16.7ms; `modulate.a` is 0.0 at t=0; `modulate.a` is 1.0 at `t = FADE_IN_DURATION ± 50ms`; intermediate alpha at `t = FADE_IN_DURATION * 0.5` is ≈ 0.75 (±0.05) per formula F-1
  - Edge cases: Tween must use `EASE_OUT + TRANS_QUAD`; verify via `Tween.get_transition()` and `Tween.get_ease()` if accessible, otherwise screenshot-diff at 25%/50%/75%/100% of `FADE_IN_DURATION`

- **AC-INPUT-1**: During `Revealing`, any input is ignored
  - Given: FES in Revealing state (Tween started, not yet finished)
  - When: simulate `InputEventKey` with `pressed=true, echo=false, keycode=KEY_SPACE`; simulate `InputEventMouseButton` with `pressed=true`
  - Then: `get_tree().quit()` is NOT called; FES state remains Revealing; `modulate.a` continues increasing
  - Edge cases: simulate input at t=0ms, t=500ms, t=1999ms into fade; all must be ignored

- **AC-INPUT-2**: During `Blackout`, inputs at 100ms / 500ms / 1400ms are ignored
  - Given: FES has completed fade-in (`modulate.a == 1.0`); FES state is Blackout; blackout Timer running with `INPUT_BLACKOUT_DURATION = 1500ms`
  - When: simulate `InputEventKey` with `pressed=true, echo=false, keycode=KEY_SPACE` at 100ms, 500ms, 1400ms after Tween `finished` signal
  - Then: at each interval, `get_tree().quit()` is NOT called; FES state remains Blackout; blackout Timer has not timed out yet
  - Edge cases: simulate input at exactly `INPUT_BLACKOUT_DURATION - 1ms` (1499ms) — must still be rejected; at `INPUT_BLACKOUT_DURATION + 1ms` (1501ms), state should be Holding and input should be accepted (tested in Story 003)

- **State machine — blackout Timer starts on Tween finished, not on `_ready()`**
  - Given: FES instantiated; `_ready()` completed; blackout Timer not yet started
  - When: `epilogue_cover_ready` is emitted; Tween runs
  - Then: blackout Timer `time_left` is 0.0 (not running) while Tween is in progress; blackout Timer `time_left` is `INPUT_BLACKOUT_DURATION / 1000.0` immediately after Tween `finished` fires
  - Edge cases: if `_on_fade_in_complete()` is somehow called before Tween completes (defensive), Timer must not have started early

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/final-epilogue-screen/fes_state_machine_test.gd`
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (Pre-instancing and CONNECT_ONE_SHOT — `_ready()` sequence and `_on_epilogue_cover_ready` entry point must exist)
- Unlocks: Story 003 (Input filter and dismiss — `_unhandled_input` state guard implemented here is the gating mechanism Story 003 builds on)
