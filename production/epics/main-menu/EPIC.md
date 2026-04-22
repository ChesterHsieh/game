# Epic: Main Menu

> **Layer**: Presentation
> **GDD**: design/gdd/main-menu.md
> **Architecture Module**: MainMenu — top-level scene (res://src/ui/main_menu/main_menu.tscn)
> **Status**: Ready
> **Stories**: 4 stories

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | Scene setup and no-coupling rule | Logic | Ready | ADR-001, ADR-003 |
| 002 | Start activation and gameplay boot | Integration | Ready | ADR-003, ADR-004 |
| 003 | Esc quit and error recovery | Logic | Ready | ADR-001 |
| 004 | Visual layout and no-DynamicFont rule | UI | Ready | ADR-001 |

## Overview

Main Menu is the initial Godot scene set as `run/main_scene`. It renders two
elements: a hand-drawn title PNG and a hand-lettered Start TextureButton, both
centered on a warm paper background — no other widgets, no animations, no
sound. On Start activation it calls `change_scene_to_file("res://src/scenes/gameplay.tscn")`
and disables the button to block double-press. Esc calls `get_tree().quit()`
only while in Idle state. Main Menu holds no game state, references no
autoloads beyond the SceneTree, and emits no EventBus signals. The `game_start_requested`
signal is emitted by `gameplay.tscn`'s root after Main Menu frees itself.
Scene Manager waits in a `Waiting` state and responds to that signal to begin
scene 0 — a companion edit to SM required at implementation time.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-001: Naming Conventions | snake_case files; PascalCase classes — `main_menu.gd`, `MainMenu`; `%StartButton` unique name | LOW |
| ADR-003: Signal Bus | `game_start_requested` declared on EventBus; emitted by gameplay.tscn root; consumed by Scene Manager with CONNECT_ONE_SHOT | LOW |
| ADR-004: Runtime Scene Composition | gameplay.tscn composition (CardTable + 4 CanvasLayers); gameplay_root.gd owns the game_start_requested emission and save-load sequence | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-main-menu-001 | Instanced scene at res://src/ui/main_menu/main_menu.tscn; set as project run/main_scene | ADR-001 ✅ |
| TR-main-menu-002 | Renders CenterContainer→VBoxContainer with Title TextureRect + Start TextureButton | ADR-001 ✅ |
| TR-main-menu-003 | On _ready(): %StartButton.grab_focus(); enters Idle; emits nothing | ADR-003 ✅ |
| TR-main-menu-004 | Start activation calls get_tree().change_scene_to_file('res://src/scenes/gameplay.tscn') | ADR-004 ✅ |
| TR-main-menu-005 | Disables button on Start press to block double-activation during scene switch | ADR-001 ✅ |
| TR-main-menu-006 | Esc via _unhandled_input calls get_tree().quit() only while _state == IDLE | ADR-001 ✅ |
| TR-main-menu-007 | Rule 6 No Game-State Coupling: no references to SaveSystem/SceneManager/EventBus in main_menu.gd | ADR-003 ✅ |
| TR-main-menu-008 | Synchronous change_scene_to_file non-OK error: re-enable button, log fatal, return to Idle | ADR-001 ✅ |
| TR-main-menu-009 | gameplay_root.gd emits EventBus.game_start_requested() after gameplay.tscn _ready() completes | ADR-004 ✅ |
| TR-main-menu-010 | Scene Manager enters Waiting state on _ready(); subscribes to game_start_requested with CONNECT_ONE_SHOT | ADR-003 ✅ |
| TR-main-menu-011 | Focus recovery: next keyboard event re-focuses %StartButton if focus lost to background | ADR-001 ✅ |
| TR-main-menu-012 | No DynamicFont used; title and button text are single-author PNGs | ADR-001 ✅ |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/main-menu.md` are verified
- All Logic stories have passing test files in `tests/`
- All UI stories have manual walkthrough evidence in `production/qa/evidence/`
- Companion edit to Scene Manager GDD (Waiting state + CONNECT_ONE_SHOT) is committed in the same pass

## Next Step

Run `/create-stories main-menu` to break this epic into implementable stories.
