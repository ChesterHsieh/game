# Story 004: Audio fade and cursor hide

> **Epic**: Final Epilogue Screen
> **Status**: Complete
> **Layer**: Presentation
> **Type**: Integration
> **Manifest Version**: 2026-04-21

## Context

**GDD**: `design/gdd/final-epilogue-screen.md`
**Requirements**: `TR-final-epilogue-screen-008`, `TR-final-epilogue-screen-009`, `TR-final-epilogue-screen-011`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-003: Inter-System Communication — EventBus Singleton; ADR-001: Naming Conventions — snake_case
**ADR Decision Summary**: Direct autoload calls are reserved for read-only queries per ADR-003; `AudioManager.fade_out_all()` is a command (side-effect), not a query, so FES calls it directly on the AudioManager autoload — this is an intentional exception to the EventBus pattern, consistent with how the rest of the codebase calls AudioManager methods directly. The `has_method()` guard is required because AudioManager's `fade_out_all` API may not yet exist at FES implementation time (GDD EC-15).

**Engine**: Godot 4.3 | **Risk**: LOW
**Engine Notes**: `Node.has_method(method_name: StringName)` is stable in 4.3. `Input.mouse_mode = Input.MOUSE_MODE_HIDDEN` is stable in 4.3. `Timer` node with `one_shot = true` and `autostart = false` is stable. `Timer.timeout` signal is stable.

**Control Manifest Rules (Presentation Layer)**:
- Required: EpilogueLayer is CanvasLayer layer=20; FES pre-instanced in Armed state
- Required: STUI emits `epilogue_cover_ready`; FES waits on this before fading in

---

## Acceptance Criteria

*From GDD `design/gdd/final-epilogue-screen.md`, scoped to this story:*

- [ ] **AC-AUDIO-1**: On reveal entry, `AudioManager.fade_out_all(FADE_IN_DURATION / 1000.0)` is called with the correct duration. If AudioManager does not implement the method, FES does not crash.
- [ ] **AC-AUDIO-2**: After fade-out completes, no audio is playing from any bus. (Manual playtest check.)
- [ ] **EC-4 behavior (COVER_READY_TIMEOUT)**: If `epilogue_cover_ready` has not fired within `COVER_READY_TIMEOUT` (5.0s default) of FES `_ready()`, FES begins fade-in anyway and logs the warning: `"FES: epilogue_cover_ready not received within 5000ms; beginning fade-in without STUI handoff"`.

---

## Implementation Notes

*Derived from ADR-003, ADR-001, and GDD Detailed Design §Core Rules 11, EC-4, EC-15; GDD §Tuning Knobs; GDD §Audio:*

**Audio fade call — guarded direct autoload call (GDD Core Rule interaction / EC-15)**:
```gdscript
func _on_epilogue_cover_ready() -> void:
    # ... state transition and Tween creation (Story 002) ...
    if AudioManager.has_method(&"fade_out_all"):
        AudioManager.fade_out_all(FADE_IN_DURATION / 1000.0)
    # If method absent: audio continues; no crash; EC-15 documented behavior
```
`FADE_IN_DURATION / 1000.0` converts from milliseconds (the const unit) to seconds (AudioManager's `duration` parameter, per GDD §Audio and §Interactions). Using `&"fade_out_all"` (StringName literal) for `has_method()` is consistent with ADR-001's performance note on StringName for frequently compared strings.

**Why not EventBus (ADR-003)**: ADR-003 states direct autoload calls are reserved for read-only queries. `fade_out_all` is a command. However, EventBus does not declare an "audio_fade_out" signal, and adding one solely for FES's one-time terminal call would be inappropriate use of the signal bus. The pattern here — direct call with `has_method` guard — mirrors how other systems are expected to call AudioManager methods. This is consistent with the ADR-003 note that read-only queries use direct autoload calls; a one-time terminal command on a well-known autoload is the closest acceptable deviation.

**Cursor hide (GDD Core Rule 11)**:
```gdscript
Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
```
Called at the start of `_on_epilogue_cover_ready()`, alongside the AudioManager call and Tween creation. Cursor is not restored — FES exits via `get_tree().quit()`, not via scene swap, so restoration is moot (GDD §UI Requirements — Cursor).

**COVER_READY_TIMEOUT safety timer (GDD EC-4)**:
The Timer is started in `_ready()`, immediately after connecting to `epilogue_cover_ready`:
```gdscript
func _ready() -> void:
    # ... MUT guard, modulate=0, epilogue_cover_ready connection (Story 001) ...
    _cover_ready_timeout_timer.wait_time = COVER_READY_TIMEOUT / 1000.0
    _cover_ready_timeout_timer.one_shot = true
    _cover_ready_timeout_timer.timeout.connect(_on_cover_ready_timeout)
    _cover_ready_timeout_timer.start()
```

`_on_cover_ready_timeout()`:
```gdscript
func _on_cover_ready_timeout() -> void:
    if _state != State.ARMED and _state != State.READY:
        return  # epilogue_cover_ready already fired; CONNECT_ONE_SHOT disconnected it
    push_warning("FES: epilogue_cover_ready not received within 5000ms; beginning fade-in without STUI handoff")
    _on_epilogue_cover_ready()
```
If `epilogue_cover_ready` fires normally, `CONNECT_ONE_SHOT` disconnects the handler; the timer timeout still fires but the state guard (`_state != ARMED/READY`) causes an early return. No double-reveal.

**Timer node**: `_cover_ready_timeout_timer` is an `@onready` reference to a `Timer` child node of FES, configured in the scene. Using a Timer node (rather than `get_tree().create_timer()`) makes the timeout testable — a test can advance the Timer manually without waiting real seconds.

**Constants (GDD §Tuning Knobs)**:
```gdscript
const COVER_READY_TIMEOUT: float = 5000.0  # milliseconds
```
Converted to seconds at assignment time (`/ 1000.0`). Same pattern as `FADE_IN_DURATION` and `INPUT_BLACKOUT_DURATION` from Story 002.

---

## Out of Scope

- Story 002: The Tween creation and EASE_OUT + TRANS_QUAD configuration
- Story 003: The `_unhandled_input` filter and `_on_dismiss()` / `get_tree().quit()` path
- Story 001: CONNECT_ONE_SHOT wiring and `is_final_memory_earned()` guard
- Story 005: Visual layout nodes

---

## QA Test Cases

*Integration — automated (`tests/integration/final-epilogue-screen/fes_audio_cursor_test.gd`):*

- **AC-AUDIO-1**: `AudioManager.fade_out_all` called with correct duration on reveal entry
  - Given: FES instantiated with MUT stub (`is_final_memory_earned() = true`); AudioManager spy with `fade_out_all` method recording calls and arguments
  - When: `EventBus.epilogue_cover_ready.emit()` is called
  - Then: `AudioManager.fade_out_all` is called exactly once with argument `FADE_IN_DURATION / 1000.0` (default: `2.0` seconds)
  - Edge cases: verify call happens on the same frame as Tween creation (not deferred); verify argument is in seconds (2.0), not milliseconds (2000.0)

- **AC-AUDIO-1 — missing method (EC-15)**: no crash when `fade_out_all` absent
  - Given: FES instantiated; AudioManager stub that does NOT implement `fade_out_all`
  - When: `EventBus.epilogue_cover_ready.emit()` is called
  - Then: no GDScript error, no crash, no exception raised; Tween still starts normally; cursor is still hidden
  - Edge cases: verify `has_method(&"fade_out_all")` returns false for the stub; verify the Tween proceeds regardless

- **AC-AUDIO-2**: No audio playing after fade-out — manual playtest
  - Setup: run game to epilogue completion; reach FES reveal with audio playing in at least one bus
  - Verify: listen at full volume for 10 seconds after fade-out completes (at `t = FADE_IN_DURATION`)
  - Pass condition: no audio audible from any source; if audio continues, `AudioManager.fade_out_all` is either not being called or not working — check AC-AUDIO-1 automated test first

- **EC-4 (COVER_READY_TIMEOUT)**: fallback fade-in after 5.0s if `epilogue_cover_ready` never fires
  - Given: FES instantiated; `epilogue_cover_ready` NOT emitted; `COVER_READY_TIMEOUT = 5000ms`
  - When: 5.5 seconds elapse (Timer times out)
  - Then: FES logs warning string `"FES: epilogue_cover_ready not received within 5000ms; beginning fade-in without STUI handoff"` to stderr; Tween on `modulate:a` has started; `modulate.a > 0.0`
  - Edge cases: if `epilogue_cover_ready` fires at t=4.9s (just before timeout), Timer timeout at t=5.0s must be a no-op (state guard: `_state != ARMED/READY` because reveal already started); no double-reveal

- **Cursor hidden on reveal entry**
  - Given: FES instantiated; `Input.mouse_mode` is `MOUSE_MODE_VISIBLE` before reveal
  - When: `EventBus.epilogue_cover_ready.emit()` is called
  - Then: `Input.mouse_mode == Input.MOUSE_MODE_HIDDEN` immediately after the call (same frame)
  - Edge cases: cursor must remain hidden throughout Revealing, Blackout, and Holding states; no restore call exists (quit is the exit)

*UI — manual:*

- **AC-AUDIO-2**: Full audio silence after fade-out
  - Setup: reach epilogue; play a scene with ambient music and SFX active; let STUI amber cover complete; FES begins reveal
  - Verify: at `t = FADE_IN_DURATION + 500ms`, mute/unmute system volume and listen; game audio buses report 0.0 amplitude
  - Pass condition: complete silence; room-tone-only is acceptable; any recognizable game audio is a fail

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/final-epilogue-screen/fes_audio_cursor_test.gd`
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002 (Reveal state machine and fade-in — `_on_epilogue_cover_ready()` entry point and `_state` transitions must exist; this story adds to that same handler)
- Unlocks: Story 005 (Visual layout and error fallbacks — no functional dependency, but Story 005's `TextureRect` and `ColorRect` nodes should be present in the scene before integration testing of Stories 001–004 can run end-to-end)
