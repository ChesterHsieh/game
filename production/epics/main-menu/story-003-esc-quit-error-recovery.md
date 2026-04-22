# Story 003: Esc quit and error recovery

> **Epic**: Main Menu
> **Status**: Complete
> **Layer**: Presentation
> **Type**: Logic
> **Manifest Version**: 2026-04-21

## Context

**GDD**: `design/gdd/main-menu.md`
**Requirement**: `TR-main-menu-006`, `TR-main-menu-008`, `TR-main-menu-011`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-001: Naming Conventions
**ADR Decision Summary**: ADR-001 mandates snake_case for all variables and functions, SCREAMING_SNAKE_CASE for constants — `ESC_QUIT_ENABLED` is a `const bool` (not `@export`). The GDD Tuning Knobs section explicitly notes `const` and `@export` are mutually exclusive in GDScript; `const` is correct here because the value is a code-level toggle for harnessed playtest sessions, not a runtime inspector value.

**Engine**: Godot 4.3 | **Risk**: LOW
**Engine Notes**: `_unhandled_input(event: InputEvent)` is stable in 4.3 — fires for input events not consumed by the GUI. `get_tree().quit()` terminates the process synchronously. `event.is_action_pressed("ui_cancel")` is the correct pattern for detecting Esc in `_unhandled_input`. `change_scene_to_file` return value is `Error` (int) — compare against `OK` constant. Focus re-acquisition via `%StartButton.grab_focus()` is safe to call from `_unhandled_input`.

**Control Manifest Rules (Presentation Layer)**:
- Required: `gameplay_root.gd` owns boot orchestration: load_from_disk → apply_loaded_state → emit game_start_requested
- Required: All autoloads set process_mode = PROCESS_MODE_ALWAYS
- Required: EventBus declared signals before implementing emitter
- Forbidden: Never use direct node references for inter-system communication
- Forbidden: Never call change_scene_to_file during epilogue handoff

---

## Acceptance Criteria

*From GDD `design/gdd/main-menu.md`, scoped to this story:*

- [ ] **AC-QUIT-1** — GIVEN Main Menu is in `Idle`, WHEN the user presses Esc, THEN `get_tree().quit()` is called and the process terminates. [launch]
- [ ] **AC-QUIT-2** — GIVEN Main Menu is in `Starting` state, WHEN the user presses Esc, THEN `get_tree().quit()` is NOT called and the scene switch proceeds uninterrupted. *(Top priority — Esc guard)* [launch]
- [ ] **AC-QUIT-3** — GIVEN Main Menu is in `Idle` and `ESC_QUIT_ENABLED` is `false`, WHEN the user presses Esc, THEN nothing happens (the menu stays in `Idle`; no quit occurs). [launch / code knob]
- [ ] **AC-FAIL-1** — GIVEN `change_scene_to_file` returns a synchronous non-`OK` error (e.g., empty path — only triggerable if `GAMEPLAY_SCENE_PATH` is malformed), WHEN Start is activated, THEN the error is logged, the Start button is re-enabled, and Main Menu transitions `Starting → Idle`. Note: deferred failures (missing file, parse error, script error in `gameplay.tscn`) are invisible here and are detected by Scene Manager's Waiting-state watchdog (Scene Manager OQ-2). [code / launch-hard-to-trigger]
- [ ] **AC-FAIL-2** — GIVEN a synchronous scene-switch error has recovered Main Menu to `Idle`, WHEN the user clicks Start again, THEN the activation sequence runs again (retry is permitted, not suppressed). [launch-hard-to-trigger]
- [ ] **AC-FOCUS-1** — GIVEN focus has been lost to the empty background (e.g., a mouse click outside the button), WHEN the user presses any keyboard event (`ui_accept`, `ui_focus_next`, or any key delivered to `_unhandled_input`), THEN focus returns to `%StartButton` before the event is further processed. [launch]

---

## Implementation Notes

*Derived from governing ADR(s):*

**Esc quit handler** (TR-main-menu-006): Implemented in `_unhandled_input(event: InputEvent) -> void`. Full guard sequence:
1. Check `event.is_action_pressed("ui_cancel")` — if not Esc, fall through to focus recovery logic.
2. Check `ESC_QUIT_ENABLED` — if `false`, consume the event and return.
3. Check `_state == State.IDLE` — if not Idle (Starting or Exiting), ignore Esc entirely.
4. If all guards pass: transition `_state = State.EXITING`, call `get_tree().quit()`.

**ESC_QUIT_ENABLED constant** (ADR-001 SCREAMING_SNAKE_CASE):
```gdscript
const ESC_QUIT_ENABLED: bool = true
```
When set to `false` (e.g., for harnessed playtest sessions), Esc does nothing — the OS window-close (Alt+F4 / Cmd+Q) remains the only quit path. The constant is `const`, not `@export`, per the GDD Tuning Knobs reasoning.

**Why the state guard matters** (GDD Edge Cases / AC-QUIT-2): Pressing Esc during `Starting` would call `get_tree().quit()` while `change_scene_to_file` has already been queued — terminating the process during partial `gameplay.tscn` initialisation. The guard (`_state == State.IDLE`) makes this safe. Pressing Esc during `Exiting` is also ignored (process is already terminating; a double-quit attempt is benign but the guard prevents code duplication).

**Double-Esc edge case** (GDD Edge Cases): If `_unhandled_input` fires twice in the same frame with Esc (buffered input, rare): the first call transitions to `Exiting` and calls `quit()`; the second call sees `_state != State.IDLE` and exits early. No double-quit possible.

**Synchronous error recovery** (TR-main-menu-008 / AC-FAIL-1): This is the non-OK return branch in Story 002's activation sequence. From `_on_start_button_pressed()`:
```gdscript
var err: Error = get_tree().change_scene_to_file(GAMEPLAY_SCENE_PATH)
if err != OK:
    push_error("MainMenu: change_scene_to_file failed with error %d for path: %s" % [err, GAMEPLAY_SCENE_PATH])
    %StartButton.disabled = false
    _state = State.IDLE
    return
```
The error is logged with `push_error` (visible in the Godot console and output log). Button is re-enabled. `_state` returns to `IDLE` so both Start activation and Esc quit work normally again.

**Realistic trigger for AC-FAIL-1**: In production, `GAMEPLAY_SCENE_PATH` is a valid constant — `change_scene_to_file` will return `OK`. The non-OK path is only reachable if the constant is malformed during development (e.g., empty string, incorrect `res://` prefix). Test harnesses can simulate this by temporarily patching the path or mocking `change_scene_to_file` to return `ERR_FILE_NOT_FOUND`.

**Deferred failure class** (not recoverable here): If `gameplay.tscn` exists but fails at parse time or its root script errors before emitting `game_start_requested`, `change_scene_to_file` returns `OK`, Main Menu is freed, and the failure is invisible to this system. Scene Manager's Waiting-state watchdog (OQ-2) is the sole detection mechanism for this class. Declared in AC-FAIL-1's note.

**Focus recovery** (TR-main-menu-011 / AC-FOCUS-1): In `_unhandled_input`, before the Esc check: if the current focus owner is not `%StartButton` and a keyboard event has arrived, re-focus the Start button:
```gdscript
var focus_owner: Control = get_viewport().gui_get_focus_owner()
if focus_owner != %StartButton:
    %StartButton.grab_focus()
    # Do not consume the event — let it be processed after re-focus
```
This keeps keyboard-only navigation recoverable after a mouse click on the empty background, without any visual noise for mouse users (the re-focus happens silently; the focus state only becomes visible if the user continues with keyboard).

---

## Out of Scope

- Story 001: Scene structure, grab_focus in `_ready()`, no-coupling static rule.
- Story 002: Start button activation happy path, `change_scene_to_file` call, `CONNECT_ONE_SHOT` on Scene Manager.
- Story 004: Visual theme values, modulate colors, VBox separation, DynamicFont enforcement.

---

## QA Test Cases

*Logic — automated (`tests/unit/main-menu/main_menu_quit_recovery_test.gd`):*

- **AC-QUIT-1**: Esc in Idle → quit called
  - Given: MainMenu with `_state == State.IDLE` and `ESC_QUIT_ENABLED == true`; spy on `get_tree().quit()`
  - When: `_unhandled_input` is called with a mock `ui_cancel` press event
  - Then: spy records one call to `quit()` AND `_state == State.EXITING`
  - Edge cases: confirm `_state` transitions to `EXITING` before `quit()` is called so no re-entrant Esc fires

- **AC-QUIT-2**: Esc in Starting → quit NOT called
  - Given: MainMenu with `_state == State.STARTING`; spy on `get_tree().quit()`
  - When: `_unhandled_input` is called with a mock `ui_cancel` press event
  - Then: spy records zero calls to `quit()` AND `_state` remains `State.STARTING`
  - Edge cases: verify the event is consumed (not re-delivered) so no accidental propagation to another handler

- **AC-QUIT-3**: ESC_QUIT_ENABLED = false → nothing happens
  - Given: MainMenu subclass or test double with `ESC_QUIT_ENABLED` overridden to `false`; `_state == State.IDLE`; spy on `get_tree().quit()`
  - When: `_unhandled_input` called with `ui_cancel` press event
  - Then: spy records zero calls AND `_state` remains `State.IDLE`
  - Edge cases: since `ESC_QUIT_ENABLED` is a `const`, the test must either subclass MainMenu to override it or use a test-specific flag injection pattern; document the chosen approach in the test file

- **AC-FAIL-1**: Non-OK sync error → logged + button re-enabled + back to Idle
  - Given: MainMenu in `State.IDLE`; `change_scene_to_file` mocked to return `ERR_FILE_NOT_FOUND`; spy on `push_error`
  - When: `_on_start_button_pressed()` is called
  - Then: `push_error` spy records one call containing the path string AND `%StartButton.disabled == false` AND `_state == State.IDLE`
  - Edge cases: verify `_state` passes through `STARTING` (not skips it) before returning to `IDLE` — the transition sequence matters for the state invariant

- **AC-FAIL-2**: Retry after recovery runs activation again
  - Given: MainMenu recovered to `State.IDLE` via AC-FAIL-1 path; spy on `change_scene_to_file` (now returning `OK`)
  - When: `%StartButton.pressed` is emitted again
  - Then: spy records one additional call to `change_scene_to_file` AND `%StartButton.disabled == true`
  - Edge cases: confirm button is not stuck in a disabled state from the first attempt

- **AC-FOCUS-1**: Focus lost → next keyboard event re-focuses StartButton
  - Given: MainMenu in `State.IDLE`; focus owner is NOT `%StartButton` (simulate by calling `%StartButton.release_focus()`)
  - When: any keyboard event is delivered to `_unhandled_input` (e.g., a mock `KEY_A` press)
  - Then: `get_viewport().gui_get_focus_owner() == %StartButton`
  - Edge cases: if the keyboard event is `ui_accept` (Enter), verify that after re-focusing, Start is activated (focus then event processing — not event then focus); if the keyboard event is `ui_cancel` (Esc), verify focus is restored AND Esc is still processed with the state guard

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/main-menu/main_menu_quit_recovery_test.gd` — automated test file; all test methods must pass in the gdUnit4 runner.
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002 (Esc guard references `State.STARTING` which is entered by the Start activation flow; error recovery is the non-OK branch of the activation sequence established in Story 002)
- Unlocks: Story 004 (visual layout is independent of state logic but logically follows complete behavior coverage)
