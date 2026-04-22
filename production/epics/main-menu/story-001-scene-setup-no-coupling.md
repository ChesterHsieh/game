# Story 001: Scene setup and no-coupling rule

> **Epic**: Main Menu
> **Status**: Complete
> **Layer**: Presentation
> **Type**: Logic
> **Manifest Version**: 2026-04-21

## Context

**GDD**: `design/gdd/main-menu.md`
**Requirement**: `TR-main-menu-001`, `TR-main-menu-002`, `TR-main-menu-003`, `TR-main-menu-007`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-001: Naming Conventions; ADR-003: Signal Bus
**ADR Decision Summary**: ADR-001 mandates snake_case files and PascalCase class names — `main_menu.gd` / `MainMenu`, `%StartButton` unique name. ADR-003 mandates that `main_menu.gd` holds zero EventBus signal connections and zero autoload references beyond the SceneTree; EventBus is for inter-system events, and Main Menu emits none.

**Engine**: Godot 4.3 | **Risk**: LOW
**Engine Notes**: `grab_focus()` is stable in 4.3 and will log a non-fatal warning in headless contexts (declared acceptable). `CenterContainer`, `VBoxContainer`, `TextureRect`, and `TextureButton` are all stable in 4.3. `@onready` and `%UniqueNodeName` access patterns are stable. `PRESET_FULL_RECT` anchor preset behaves correctly under `canvas_items` stretch mode.

**Control Manifest Rules (Presentation Layer)**:
- Required: `gameplay_root.gd` owns boot orchestration: load_from_disk → apply_loaded_state → emit game_start_requested
- Required: All autoloads set process_mode = PROCESS_MODE_ALWAYS
- Required: EventBus declared signals before implementing emitter
- Forbidden: Never use direct node references for inter-system communication
- Forbidden: Never call change_scene_to_file during epilogue handoff

---

## Acceptance Criteria

*From GDD `design/gdd/main-menu.md`, scoped to this story:*

- [ ] **AC-BOOT-1** — GIVEN the game is launched with `run/main_scene = res://src/ui/main_menu/main_menu.tscn`, WHEN Main Menu's `_ready()` completes, THEN pressing Enter immediately activates Start (proxy for `%StartButton.grab_focus()` succeeding). [launch / proxy]
- [ ] **AC-BOOT-2** — GIVEN the game is launched, WHEN the title screen is visible, THEN exactly two widgets are rendered: the Title PNG and the Start button. No other labels, images, or controls appear. [launch]
- [ ] **AC-BOOT-3** — GIVEN Main Menu's `_ready()` has completed, WHEN Scene Manager is inspected via Godot's remote scene debugger, THEN Scene Manager is in the `Waiting` state (no scene has been auto-loaded). [debugger]
- [ ] **AC-BOOT-4** — GIVEN the game is launched, WHEN 30 seconds pass with no input, THEN no visual or audio change occurs on the menu (no idle animation, no auto-focus shift, no ambient sound). [launch]
- [ ] **AC-RULE-1** — GIVEN `main_menu.gd`, WHEN its source is inspected, THEN it holds no references to Scene Manager, Scene Transition UI, Card Engine, Status Bar UI, or any autoload beyond the Godot SceneTree. [code]
- [ ] **AC-RULE-2** — GIVEN `main_menu.gd`, WHEN its source is inspected, THEN no `EventBus.*.emit(...)` or `EventBus.emit_signal(...)` call appears anywhere in the script. [code]
- [ ] **AC-MOTION-1** — GIVEN Main Menu is rendered, WHEN observed for 30 seconds of idle time, THEN no node's position, rotation, scale, or modulate changes. The menu is fully static. [launch]
- [ ] **AC-AUDIO-1** — GIVEN Main Menu is active, WHEN audio output is monitored, THEN no sound is emitted by Main Menu (no ambient, no UI tick, no hover sound, no Start SFX). [launch]

---

## Implementation Notes

*Derived from governing ADR(s):*

**Scene location and project.godot** (TR-main-menu-001): The scene lives at `res://src/ui/main_menu/main_menu.tscn`. In `project.godot`, `[application] run/main_scene` must point to this path. Main Menu is not an autoload — it is the root scene.

**Class and file naming** (ADR-001): File is `main_menu.gd`; class declaration is `class_name MainMenu`. All variables and functions use `snake_case`. The Start button carries Godot's Unique Name flag in the `.tscn` so it is accessible as `%StartButton` — the ADR-001 example `%StartButton` matches this naming.

**Node tree** (TR-main-menu-002): Exactly:
```
MainMenu (Control, anchors = PRESET_FULL_RECT)
├── Background (TextureRect or ColorRect, anchors = PRESET_FULL_RECT, mouse_filter = IGNORE)
└── CenterContainer (anchors = PRESET_FULL_RECT)
    └── VBoxContainer (alignment = CENTER, separation 48 px via Theme)
        ├── Title (TextureRect — hand-drawn PNG, stretch_mode = KEEP_ASPECT_CENTERED)
        └── StartButton (TextureButton, unique name %StartButton)
```
No CanvasLayer. Background `mouse_filter = IGNORE` so it never swallows clicks.

**_ready() behavior** (TR-main-menu-003):
1. Call `%StartButton.grab_focus()`.
2. Set `_state = State.IDLE`.
3. Emit nothing — no EventBus calls, no autoload calls.

**State enum** (ADR-001 SCREAMING_SNAKE_CASE constants): Declare as:
```gdscript
enum State { IDLE, STARTING, EXITING }
var _state: State = State.IDLE
```

**No-coupling rule** (TR-main-menu-007 / ADR-003): `main_menu.gd` must not import, reference, or call any of: `SceneManager`, `SceneTransitionUI`, `CardEngine`, `StatusBarUI`, `EventBus`. The only global objects the script may access are `get_tree()` (SceneTree) and `%StartButton` (local node reference via unique name). This is validated statically by AC-RULE-1 and AC-RULE-2.

**Headless context note**: If `grab_focus()` is called in a headless CI run (no display), Godot 4.3 logs a warning and proceeds — this is declared acceptable behavior per the GDD Edge Cases section.

---

## Out of Scope

- Story 002: Start button activation, state transitions to Starting, and the `change_scene_to_file` call.
- Story 003: Esc quit logic, error recovery, and focus re-acquisition on keyboard events.
- Story 004: Visual theme values, modulate colors, VBox separation pixel value, and no-DynamicFont enforcement.

---

## QA Test Cases

*Logic — automated (`tests/unit/main-menu/main_menu_setup_test.gd`):*

- **AC-BOOT-1**: `%StartButton.grab_focus()` called in `_ready()`
  - Given: MainMenu scene instantiated in a test harness with a valid SceneTree
  - When: `_ready()` executes
  - Then: `%StartButton` is the current focus owner (`get_viewport().gui_get_focus_owner() == %StartButton`)
  - Edge cases: headless context — `grab_focus()` no-ops with a warning; test may assert the call was made via a mock or skip the focus assertion in `--headless` mode

- **AC-BOOT-2**: Exactly two visible widgets
  - Given: MainMenu scene instantiated
  - When: scene tree is traversed
  - Then: exactly two `CanvasItem` children with `visible = true` and non-zero size exist inside the VBoxContainer (Title TextureRect and StartButton TextureButton)
  - Edge cases: Background node exists but is outside VBoxContainer — must not be counted in the two-widget check

- **AC-BOOT-4 / AC-MOTION-1**: No state changes over 30 simulated seconds
  - Given: MainMenu in Idle, `_state == State.IDLE`
  - When: `_process` and `_physics_process` are called for 30 simulated seconds with no input events
  - Then: no signal emitted, no node property mutated, `_state` remains `State.IDLE`
  - Edge cases: confirm `set_process(false)` / `set_physics_process(false)` are not needed because Idle does nothing in process callbacks — verify by checking the test's mutation detector reports zero changes

- **AC-RULE-1**: No forbidden autoload references in source
  - Given: `main_menu.gd` source text
  - When: source is scanned for the strings `SceneManager`, `SceneTransitionUI`, `CardEngine`, `StatusBarUI`, `EventBus`
  - Then: zero matches found
  - Edge cases: scan must include comments and string literals — any occurrence is a fail

- **AC-RULE-2**: No EventBus emit calls in source
  - Given: `main_menu.gd` source text
  - When: source is scanned for `EventBus.` and `emit_signal(`
  - Then: zero matches found
  - Edge cases: same as AC-RULE-1 — scan includes comments

- **AC-BOOT-3**: Scene Manager in Waiting state
  - Given: full autoload stack initialized (integration-adjacent, but verifiable via a stubbed SM in unit context)
  - When: Main Menu `_ready()` completes
  - Then: `SceneManager._state == SceneManager.State.WAITING` (or equivalent)
  - Edge cases: this AC also validates that SM's Core Rule 2 auto-load behavior has been replaced — if SM still auto-loads scene 0, this test fails

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/main-menu/main_menu_setup_test.gd` — automated test file; all test methods must pass in the gdUnit4 runner.
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None (this is the first story; it only requires `project.godot` to name the scene as `run/main_scene`)
- Unlocks: Story 002 (Start activation requires the scene, state enum, and `%StartButton` reference established here)
