# Epic: Final Epilogue Screen

> **Layer**: Presentation
> **GDD**: design/gdd/final-epilogue-screen.md
> **Architecture Module**: FinalEpilogueScreen — pre-instanced at CanvasLayer=20 in gameplay.tscn
> **Status**: Ready
> **Stories**: 5 stories

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | Pre-instancing and CONNECT_ONE_SHOT | Integration | Ready | ADR-004, ADR-003 |
| 002 | Reveal state machine and fade-in | Logic | Ready | ADR-004 |
| 003 | Input filter and dismiss | Logic | Ready | ADR-001 |
| 004 | Audio fade and cursor hide | Integration | Ready | ADR-003, ADR-001 |
| 005 | Visual layout and error fallbacks | UI | Ready | ADR-001 |

## Overview

The Final Epilogue Screen (FES) is the emotional terminus of the game — a
one-shot, full-screen illustrated reveal shown when Ju has discovered every
required memory. It is pre-instanced as a sibling CanvasLayer (layer=20) inside
`gameplay.tscn` and sits in Armed state with alpha=0. When Scene Transition UI
emits `epilogue_cover_ready()` (amber overlay at full opacity), FES begins a
2-second quadratic-ease-out fade-in of the sole illustration. After the fade
completes, a 1.5-second input blackout protects against accidental dismiss.
Then any key or click (except Esc) calls `get_tree().quit()`. FES calls
`AudioManager.fade_out_all()` on reveal entry so the room goes quiet as the
image rises. FES owns no save state and emits no signals; it is a terminal
leaf node.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-004: Runtime Scene Composition | FES pre-instanced at CanvasLayer=20 in gameplay.tscn; connects to epilogue_cover_ready with CONNECT_ONE_SHOT in _ready(); STUI layer=10 sits below | LOW |
| ADR-001: Naming Conventions | snake_case files; PascalCase classes — `final_epilogue_screen.gd`, `FinalEpilogueScreen` | LOW |
| ADR-003: Signal Bus | Listens to EventBus.epilogue_cover_ready (CONNECT_ONE_SHOT); depends on final_memory_ready and epilogue_conditions_met being declared | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-final-epilogue-screen-001 | Pre-instanced as CanvasLayer=20 child in gameplay.tscn (ADR-004 §2); not autoload | ADR-004 ✅ |
| TR-final-epilogue-screen-002 | Subscribes to EventBus.epilogue_cover_ready with CONNECT_ONE_SHOT in _ready() | ADR-003 ✅ |
| TR-final-epilogue-screen-003 | State machine: Dormant/Preloading/Armed/Loading/Ready/Revealing/Blackout/Holding/Quitting | ADR-004 ✅ |
| TR-final-epilogue-screen-004 | On epilogue_cover_ready: fade-in modulate:a 0→1 over FADE_IN_DURATION (2000ms) quadratic ease-out | ADR-004 ✅ |
| TR-final-epilogue-screen-005 | Input blackout gate: INPUT_BLACKOUT_DURATION (1500ms) Timer starts on Tween finished signal | ADR-001 ✅ |
| TR-final-epilogue-screen-006 | Dismiss filter: accept pressed non-echo keys (except KEY_ESCAPE) and mouse button press; reject motion/release/echo | ADR-001 ✅ |
| TR-final-epilogue-screen-007 | Dismiss calls get_tree().quit(); no scene swap, no return to main menu | ADR-004 ✅ |
| TR-final-epilogue-screen-008 | Calls AudioManager.fade_out_all(FADE_IN_DURATION) on reveal entry; guards with has_method | ADR-003 ✅ |
| TR-final-epilogue-screen-009 | Mouse cursor hidden on reveal entry: Input.mouse_mode = MOUSE_MODE_HIDDEN | ADR-001 ✅ |
| TR-final-epilogue-screen-010 | Illustration TextureRect in CenterContainer with KEEP_ASPECT_CENTERED expand_mode | ADR-001 ✅ |
| TR-final-epilogue-screen-011 | Fallback safety timer (COVER_READY_TIMEOUT = 5s) begins fade-in if epilogue_cover_ready never fires | ADR-003 ✅ |
| TR-final-epilogue-screen-012 | MUT.is_final_memory_earned() guard in _ready(); quit if false (ordering bug) | ADR-004 ✅ |
| TR-final-epilogue-screen-013 | CONNECT_ONE_SHOT on epilogue_cover_ready enforces one-shot; no persistent save state written | ADR-003 ✅ |
| TR-final-epilogue-screen-014 | Missing illustration PNG: render background color only (no crash); log error | ADR-001 ✅ |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/final-epilogue-screen.md` are verified
- All Logic and Integration stories have passing test files in `tests/`
- All Visual/Feel stories have evidence docs with Chester sign-off in `production/qa/evidence/`
- Companion edits completed: EventBus declares `final_memory_ready`, `epilogue_conditions_met`, `epilogue_cover_ready`; AudioManager exposes `fade_out_all(duration)`

## Next Step

Run `/create-stories final-epilogue-screen` to break this epic into implementable stories.
