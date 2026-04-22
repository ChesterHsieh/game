# Story 002: Start activation and gameplay boot

> **Epic**: Main Menu
> **Status**: Complete
> **Layer**: Presentation
> **Type**: Integration
> **Manifest Version**: 2026-04-21

## Context

**GDD**: `design/gdd/main-menu.md`
**Requirement**: `TR-main-menu-004`, `TR-main-menu-005`, `TR-main-menu-009`, `TR-main-menu-010`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-003: Signal Bus; ADR-004: Runtime Scene Composition
**ADR Decision Summary**: ADR-003 declares `signal game_start_requested()` on EventBus — emitted by `gameplay_root.gd`, consumed by Scene Manager with `CONNECT_ONE_SHOT`; Main Menu itself emits nothing. ADR-004 §3 defines `gameplay_root.gd` as the boot orchestrator: its `_ready()` runs `SaveSystem.load_from_disk()` → `apply_loaded_state()` (on OK) → `EventBus.game_start_requested.emit()`. Scene Manager connects to `game_start_requested` in its own `_ready()` using `CONNECT_ONE_SHOT` and transitions Waiting → Loading → calls `_load_scene_at_index(0)` on receipt.

**Engine**: Godot 4.3 | **Risk**: LOW
**Engine Notes**: `get_tree().change_scene_to_file()` returns `OK` synchronously for all well-formed, non-empty path arguments and queues the actual load for the next frame — deferred failures (missing file, parse error, script error in `gameplay.tscn`) are invisible to Main Menu. `CONNECT_ONE_SHOT` flag is stable in 4.3 (`signal.connect(callable, CONNECT_ONE_SHOT)`). `TextureButton.disabled = true` takes effect in the same frame before any queued second event fires. `ui_accept` (Enter + Space) is the Godot default action for a focused button.

**Control Manifest Rules (Presentation Layer)**:
- Required: `gameplay_root.gd` owns boot orchestration: load_from_disk → apply_loaded_state → emit game_start_requested
- Required: All autoloads set process_mode = PROCESS_MODE_ALWAYS
- Required: EventBus declared signals before implementing emitter
- Forbidden: Never use direct node references for inter-system communication
- Forbidden: Never call change_scene_to_file during epilogue handoff

---

## Acceptance Criteria

*From GDD `design/gdd/main-menu.md`, scoped to this story:*

- [ ] **AC-START-1** — GIVEN Main Menu is in `Idle`, WHEN the user clicks `%StartButton`, THEN the button becomes disabled (fades to `#B8A99A` modulate) and `change_scene_to_file("res://src/scenes/gameplay.tscn")` is called exactly once. [launch / code]
- [ ] **AC-START-2** — GIVEN Main Menu is in `Idle` with `%StartButton` focused, WHEN the user presses Enter, THEN Start activates identically to AC-START-1. [launch]
- [ ] **AC-START-3** — GIVEN Main Menu is in `Idle` with `%StartButton` focused, WHEN the user presses Space, THEN Start activates identically to AC-START-1. [launch]
- [ ] **AC-START-4** — GIVEN Start has been activated successfully, WHEN `gameplay.tscn` finishes loading, THEN the first scene's seed cards appear on the table (proxy for `EventBus.game_start_requested` emission and Scene Manager's `Waiting → Loading` transition). *(Top priority — end-to-end happy path)* [launch / proxy]
- [ ] **AC-START-5** — GIVEN `gameplay.tscn` is loaded, WHEN the Main Menu node is inspected via the remote debugger, THEN it no longer exists in the scene tree (freed by Godot). [debugger]
- [ ] **AC-RULE-3** — GIVEN Start is pressed twice in rapid succession, WHEN the handlers resolve, THEN `change_scene_to_file` has been called exactly once. [launch]

---

## Implementation Notes

*Derived from governing ADR(s):*

**Start activation sequence** (TR-main-menu-004, TR-main-menu-005): When `%StartButton.pressed` fires (or `_unhandled_input` detects `ui_accept` while in Idle):
1. Transition `_state = State.STARTING`.
2. Set `%StartButton.disabled = true` — blocks double-press (Godot processes the disabled state before any queued second event fires in the same frame).
3. Call `get_tree().change_scene_to_file(GAMEPLAY_SCENE_PATH)` and capture the return value as `Error`.
4. If return is not `OK`: log a fatal error, re-enable button (`%StartButton.disabled = false`), transition `_state = State.IDLE`. This is the Story 003 recovery path — it originates in the activation sequence.
5. If return is `OK`: Main Menu's role ends. Godot will free this node on the next frame.

**`GAMEPLAY_SCENE_PATH` constant** (ADR-001 SCREAMING_SNAKE_CASE):
```gdscript
const GAMEPLAY_SCENE_PATH: String = "res://src/scenes/gameplay.tscn"
```
Declared as `const`, not `@export` — the GDD Tuning Knobs section explicitly notes that `const` and `@export` are mutually exclusive in GDScript and `const` is correct for this value.

**Input sources** (TR-main-menu-004): Three activation paths all funnel into the same `_on_start_button_pressed()` handler:
- Mouse click: `%StartButton.pressed` signal connected in `_ready()`
- Enter: Godot's `ui_accept` fires `pressed` on a focused `TextureButton` automatically
- Space: Same as Enter — `ui_accept` covers both Enter and Space by default in Godot's input map

**game_start_requested signal** (TR-main-menu-009 / ADR-003): `EventBus` already declares `signal game_start_requested()` (confirmed in ADR-003 code block, added in the 2026-04-21 revision). The emitter is `gameplay_root.gd` — not Main Menu. The exact `_ready()` sequence per ADR-004 §3:
```gdscript
# gameplay_root.gd
func _ready() -> void:
    var load_result: int = SaveSystem.load_from_disk()
    if load_result == SaveSystem.LoadResult.OK:
        SaveSystem.apply_loaded_state()
    EventBus.game_start_requested.emit()
```
Main Menu is already freed before this runs — it has zero knowledge of this sequence (preserves Rule 6 no-coupling).

**Scene Manager Waiting state** (TR-main-menu-010 / ADR-003): SM connects in its own `_ready()`:
```gdscript
EventBus.game_start_requested.connect(_on_game_start_requested, CONNECT_ONE_SHOT)
```
On receipt: SM transitions Waiting → Loading → calls `_load_scene_at_index(0)`. `CONNECT_ONE_SHOT` ensures the connection is consumed by the first emission and cannot accumulate across any hypothetical later re-emission.

**Companion edit required at implementation time**: Scene Manager's Core Rule 2 ("auto-load scene 0 on `_ready()`") must be replaced with the Waiting state described above. This is a cross-GDD dependency noted in the Main Menu GDD §8 and tracked in the Epic's Definition of Done. The story is NOT blocked on this edit being merged first — it only needs to be in the same commit as Main Menu implementation.

**Double-press guard** (AC-RULE-3): `%StartButton.disabled = true` is set as step 2 — before `change_scene_to_file` is called. Because Godot processes all input events for the current frame before advancing, any second `pressed` event queued in the same frame sees the button as disabled and does not re-fire the handler.

**Deferred failure class** (note for AC-START-4): If `gameplay.tscn` is missing, misspelled, or its root script errors — `change_scene_to_file` returns `OK`, Main Menu is freed, and `game_start_requested` is never emitted. Scene Manager stays in Waiting indefinitely. Detection belongs to Scene Manager's Waiting-state watchdog (GDD OQ-2, tracked in SM's next revision). AC-START-4 passing implicitly verifies the companion edits are all in place.

---

## Out of Scope

- Story 001: Scene structure, `_ready()` setup, grab_focus, and the no-coupling static rule.
- Story 003: Esc-during-Starting guard, synchronous error recovery path, and focus recovery logic.
- Story 004: Visual modulate values, button color states, VBox separation, and DynamicFont enforcement.

---

## QA Test Cases

*Integration — automated (`tests/integration/main-menu/main_menu_start_flow_test.gd`):*

- **AC-START-1**: Mouse click → button disabled + change_scene called once
  - Given: MainMenu in `State.IDLE` with a mock/spy on `get_tree().change_scene_to_file`
  - When: `%StartButton.pressed` signal is emitted programmatically (simulating a click)
  - Then: `%StartButton.disabled == true` AND the spy records exactly one call to `change_scene_to_file` with argument `"res://src/scenes/gameplay.tscn"`
  - Edge cases: spy must capture the call before the scene actually switches; use a mock SceneTree or stub method to intercept

- **AC-START-2**: Enter key activates identically to click
  - Given: MainMenu in `State.IDLE`, `%StartButton` is the focus owner
  - When: `ui_accept` input event (Enter) is injected via `Input.parse_input_event`
  - Then: same assertions as AC-START-1 — `disabled == true` and `change_scene_to_file` called once
  - Edge cases: focus must be confirmed before injecting input; verify `get_viewport().gui_get_focus_owner() == %StartButton`

- **AC-START-3**: Space key activates identically to click
  - Given: same as AC-START-2
  - When: `ui_accept` input event (Space) injected
  - Then: same assertions as AC-START-1
  - Edge cases: same as AC-START-2

- **AC-RULE-3**: Double-press calls change_scene exactly once
  - Given: MainMenu in `State.IDLE`, spy on `change_scene_to_file`
  - When: `%StartButton.pressed` is emitted twice in the same frame (two rapid programmatic emissions)
  - Then: spy records exactly one call (the second press sees `disabled == true` and the handler guards on `_state != State.IDLE`)
  - Edge cases: if state guard is the only protection (not disabled), test that `_state == State.STARTING` after first press prevents the second handler from running

- **AC-START-4**: End-to-end — seed cards appear after Start
  - Given: full integration environment with all autoloads, a valid `gameplay.tscn`, and a valid `gameplay_root.gd`
  - When: Start is activated and `gameplay.tscn` finishes loading (await `EventBus.game_start_requested`)
  - Then: Scene Manager is in `Loading` state AND at least one card instance is visible in the scene tree (proxy for `_load_scene_at_index(0)` completing)
  - Edge cases: this test depends on SM's Waiting state companion edit being in place; if SM still auto-loads in `_ready()`, this test will likely fail with a double-load error

- **AC-START-5**: Main Menu node freed after gameplay.tscn loads
  - Given: same integration environment as AC-START-4
  - When: `gameplay.tscn` is fully loaded
  - Then: `is_instance_valid(main_menu_node)` returns `false`
  - Edge cases: capture the node reference before Start activation; check validity after awaiting the scene switch

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/main-menu/main_menu_start_flow_test.gd` — all test methods must pass in the gdUnit4 runner. AC-START-4 and AC-START-5 require the companion Scene Manager edit and a valid `gameplay.tscn` to be in the tree.
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (scene structure, state enum, `%StartButton` unique-name reference, and `GAMEPLAY_SCENE_PATH` constant must exist)
- Unlocks: Story 003 (Esc guard and error recovery are branches off the activation sequence established here)
