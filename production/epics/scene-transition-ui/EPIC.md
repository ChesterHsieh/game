# Epic: Scene Transition UI

> **Layer**: Presentation
> **GDD**: design/gdd/scene-transition-ui.md
> **Architecture Module**: SceneTransitionUI — CanvasLayer instance (layer=10) in gameplay.tscn
> **Status**: Ready
> **Stories**: 7 stories

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | Core state machine and signal subscriptions | Logic | Ready | ADR-003, ADR-004 |
| 002 | Scene composition and Polygon2D overlay | Integration | Ready | ADR-004 |
| 003 | Input blocking and drag cancel | Integration | Ready | ADR-003, ADR-004 |
| 004 | Transition timing formulas | Logic | Ready | ADR-004 |
| 005 | Epilogue variant and FIRST_REVEAL | Visual/Feel | Ready | ADR-004, ADR-003 |
| 006 | Config data and reduced-motion path | Logic | Ready | ADR-005, ADR-004 |
| 007 | Interstitial illustration during HOLDING state | Integration | Ready | ADR-004, ADR-005 |

## Overview

Scene Transition UI (STUI) is the signal-driven overlay system that visually
brackets every scene change. It is a CanvasLayer (layer=10) instanced inside
`gameplay.tscn` — not an autoload — and subscribes to three EventBus signals
in `_enter_tree()` to fix first-frame ordering races. On `scene_completed` it
executes a page-turn: a 12-segment Polygon2D rises across the viewport with
per-vertex curl deformation, holds opaque while Scene Manager loads the next
scene, then fades out when `scene_started` fires. The epilogue variant uses an
amber tint, slowed timings, and an open-ended hold — terminating by emitting
`epilogue_cover_ready()` for Final Epilogue Screen. STUI owns no gameplay
state, emits exactly one signal, and is stateless across save/load.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-004: Runtime Scene Composition | STUI is a sibling CanvasLayer in gameplay.tscn (not autoload); layer=10 above gameplay, below epilogue (20) | LOW |
| ADR-001: Naming Conventions | snake_case files; PascalCase classes — `scene_transition_ui.gd`, `SceneTransitionUI` | LOW |
| ADR-003: Signal Bus | Subscribes to `scene_completed`, `scene_started`, `epilogue_started`; emits `epilogue_cover_ready` — all via EventBus | LOW |
| ADR-005: Data File Format Convention | `transition-variants.tres` (TransitionVariants Resource) keyed by scene_id for per-scene knob overrides | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-scene-transition-ui-001 | CanvasLayer (layer=10) scene instanced in gameplay.tscn; not autoload | ADR-004 ✅ |
| TR-scene-transition-ui-002 | Subscribes in _enter_tree() to EventBus scene_completed, scene_started, epilogue_started | ADR-003 ✅ |
| TR-scene-transition-ui-003 | Emits EventBus epilogue_cover_ready() when EPILOGUE overlay reaches full opacity | ADR-003 ✅ |
| TR-scene-transition-ui-004 | State machine: IDLE/FADING_OUT/HOLDING/FADING_IN/EPILOGUE/FIRST_REVEAL | ADR-004 ✅ |
| TR-scene-transition-ui-005 | Polygon2D overlay (12-segment strip, 26 vertices) with per-vertex y-displacement curl | ADR-004 ✅ |
| TR-scene-transition-ui-006 | Phase timings: rise 400ms + hold 1000ms + fade 500ms; total clamped to [1700, 2200] ms | ADR-004 ✅ |
| TR-scene-transition-ui-007 | Calls InputSystem.cancel_drag() at frame of scene_completed | ADR-003 ✅ |
| TR-scene-transition-ui-008 | InputBlocker ColorRect uses MOUSE_FILTER_STOP during non-IDLE; IGNORE in IDLE | ADR-004 ✅ |
| TR-scene-transition-ui-009 | process_mode = PROCESS_MODE_ALWAYS so Tweens run when tree is paused | ADR-004 ✅ |
| TR-scene-transition-ui-010 | Signal-storm guard: ignore scene_completed when not IDLE | ADR-003 ✅ |
| TR-scene-transition-ui-011 | Pitch variation via ratio 2^(r*S_range/12) on AudioStreamPlayer.pitch_scale | ADR-001 ✅ |
| TR-scene-transition-ui-012 | Reads transition-variants.tres keyed by scene_id; fallback to 'default' then hardcoded defaults | ADR-005 ✅ |
| TR-scene-transition-ui-013 | Reads ProjectSettings.stui/reduced_motion_default per transition for reduced-motion path | ADR-004 ✅ |
| TR-scene-transition-ui-014 | Stateless across save/load; persists nothing | ADR-004 ✅ |
| TR-scene-transition-ui-015 | FIRST_REVEAL: begin opaque, fade out over first_reveal_fade_ms (1200ms) on scene_started | ADR-004 ✅ |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/scene-transition-ui.md` are verified
- All Logic and Integration stories have passing test files in `tests/`
- All Visual/Feel stories have evidence docs with Chester sign-off in `production/qa/evidence/`

## Next Step

Run `/create-stories scene-transition-ui` to break this epic into implementable stories.
