# Story 004: Compose gameplay.tscn per ADR-004 CanvasLayer hierarchy

> **Epic**: scene-composition
> **Status**: Complete
> **Layer**: Presentation
> **Type**: Integration
> **Manifest Version**: 2026-04-21

## Context

**GDD**: `design/gdd/scene-manager.md`, `design/gdd/scene-transition-ui.md`,
`design/gdd/final-epilogue-screen.md`
**Requirement**: synthesises TR-scene-transition-ui-001 (CanvasLayer=10),
TR-final-epilogue-screen-001 (CanvasLayer=20), TR-main-menu-004 (change_scene_to_file target)

**ADR Governing Implementation**: ADR-004: Runtime Scene Composition
**ADR Decision Summary**: `gameplay.tscn` is the single top-level scene that
composes all runtime subsystems via sibling CanvasLayers. MainMenu calls
`change_scene_to_file("res://src/scenes/gameplay.tscn")`. `gameplay_root.gd`
(attached to the root node) emits `EventBus.game_start_requested()` once its
`_ready()` completes, and SceneManager's Waiting-state consumes that signal
to load scene 0 from the manifest.

**Engine**: Godot 4.3 | **Risk**: LOW
**Engine Notes**: `CanvasLayer.layer` property controls z-ordering across the
entire screen; use separate CanvasLayers per ADR-004 §2 table. Do not use `z_index`
on Control nodes — that only orders within the same CanvasLayer.

**Control Manifest Rules (Presentation Layer)**:
- Required: `gameplay.tscn` CanvasLayer stack — TransitionLayer=10, EpilogueLayer=20
- Required: STUI emits `epilogue_cover_ready`; FES waits on this; HudLayer hides on `epilogue_started`
- Forbidden: Never change CanvasLayer ordering without a new ADR
- Forbidden: Never call `change_scene_to_file` during epilogue handoff

---

## Acceptance Criteria

- [ ] `src/scenes/gameplay.tscn` exists with a root `Node2D` named `GameplayRoot` and script `res://src/scenes/gameplay_root.gd`
- [ ] Children of `GameplayRoot` (in this order, z-ordering via CanvasLayer.layer):
  - `CardTable` (Node2D, no CanvasLayer — defaults to layer 0) — parent for spawned cards
  - `HudLayer` (CanvasLayer, `layer = 5`) — instances `res://src/ui/status_bar_ui.tscn`
  - `TransitionLayer` (CanvasLayer, `layer = 10`) — instances `res://src/ui/scene_transition_ui.tscn`
  - `SettingsPanelHost` (CanvasLayer, `layer = 15`) — empty placeholder
  - `EpilogueLayer` (CanvasLayer, `layer = 20`) — instances `res://src/ui/final_epilogue_screen/final_epilogue_screen.tscn`
- [ ] `gameplay_root.gd` calls `EventBus.game_start_requested.emit()` once in its `_ready()` — after `await get_tree().process_frame` so SceneManager's `_ready()` has registered its listener
- [ ] `CardSpawningSystem` autoload's `set_parent_node(CardTable)` (or equivalent — see existing API) is called from `gameplay_root.gd._ready()` so spawned cards attach to CardTable
- [ ] Launching `gameplay.tscn` directly (no MainMenu) loads the first scene from `scene-manifest.tres` (coffee-intro) without manual intervention
- [ ] Launching MainMenu, clicking Start, loads gameplay.tscn and reaches the same seeded state
- [ ] No Godot errors or debugger breaks during boot — at most the existing `debug-config.tres missing` push_error is acceptable

---

## Implementation Notes

### gameplay.tscn node tree

```
GameplayRoot (Node2D, script=gameplay_root.gd)
├── CardTable (Node2D)
├── HudLayer (CanvasLayer, layer=5)
│   └── StatusBarUI (instance of status_bar_ui.tscn)
├── TransitionLayer (CanvasLayer, layer=10)
│   └── SceneTransitionUI (instance of scene_transition_ui.tscn)
├── SettingsPanelHost (CanvasLayer, layer=15)
└── EpilogueLayer (CanvasLayer, layer=20)
    └── FinalEpilogueScreen (instance of final_epilogue_screen.tscn)
```

### gameplay_root.gd skeleton

```gdscript
extends Node2D

@onready var _card_table: Node2D = $CardTable

func _ready() -> void:
    # Wire CardSpawning to parent new cards under CardTable
    if CardSpawning.has_method("set_parent_node"):
        CardSpawning.set_parent_node(_card_table)
    # Wait one frame so SceneManager's Waiting-state subscription is live
    await get_tree().process_frame
    EventBus.game_start_requested.emit()
```

If `CardSpawning` doesn't expose `set_parent_node`, inspect
`src/gameplay/card_spawning_system.gd` and either add a setter (one-line) or
call the existing field directly — track that as a micro-scope exception, do
not redesign CardSpawning.

### Entry sequence (what happens on play)

1. User clicks MainMenu Start → `change_scene_to_file("res://src/scenes/gameplay.tscn")`
2. MainMenu frees itself; `gameplay.tscn` instantiates
3. All autoloads are already live (EventBus, SceneManager, etc.)
4. `GameplayRoot._ready()` wires CardTable and emits `game_start_requested`
5. SceneManager (in Waiting state since boot) consumes the signal via CONNECT_ONE_SHOT
6. SceneManager loads `scene-manifest.tres` → first scene id = `coffee-intro`
7. SceneManager calls `SceneGoal.load_scene(&"coffee-intro")`
8. SceneGoal emits `seed_cards_ready` with the 4 tutorial cards
9. CardSpawning spawns them into CardTable at positions from TableLayoutSystem
10. Player can drag-combine; STUI is ready for the win-transition when it fires

### Input testing

Because the scene is composed of real autoloads + real systems, the best test
is a launch smoke. This story's `Integration` type mandates either an
integration test or a documented playtest (Story 005 covers the latter).

---

## Out of Scope

- Writing the actual coffee-intro data (Stories 001–003)
- Three playtest sessions with reports (Story 005)
- SettingsPanel implementation (intentionally empty)
- Any VFX, audio, or polish pass
- Art assets beyond the existing placeholder

---

## QA Test Cases

- **AC-SCENE-1 (tree shape)**:
  - Given: `gameplay.tscn` is loaded at edit time
  - When: the editor inspector shows the root node's children
  - Then: the five children are present in the specified order with the specified layer values

- **AC-BOOT-1 (autoplay from gameplay.tscn)**:
  - Given: project `run/main_scene` is set to `gameplay.tscn` (temporary override for the test)
  - When: the project runs
  - Then: 4 cards appear on screen (chester, ju, coffee_machine, coffee_beans) and the affection bar is visible at 0

- **AC-BOOT-2 (MainMenu path)**:
  - Given: project `run/main_scene` is MainMenu
  - When: user clicks Start
  - Then: gameplay.tscn loads and the same 4 cards are seeded

- **AC-GAMEPLAY-1 (win flow)**:
  - Given: 4 cards seeded
  - When: user drags coffee_machine onto coffee_beans (brew_coffee fires) then coffee onto ju (deliver_coffee fires)
  - Then: affection bar reaches 100, STUI begins the page-turn transition, no crashes

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: either an integration test or a documented playtest.
For this story the playtest doc (covered by Story 005) satisfies this.
Optionally, a lightweight headless test at `tests/integration/scene_composition/gameplay_boot_test.gd`
can verify the node tree shape using `load().instantiate()` + child lookup.

**Status**: [x] production/qa/smoke-gameplay-tscn.md — PASS 2026-04-23 (3 pre-existing warnings deferred)

---

## Dependencies

- Depends on: Stories 001 + 002 + 003 (the data must exist or SceneManager fails to load the first scene)
- Unlocks: Story 005 (playtest requires a composed, playable build)
