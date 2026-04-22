# Epic: Status Bar UI

> **Layer**: Presentation
> **GDD**: design/gdd/status-bar-ui.md
> **Architecture Module**: StatusBarUI — scene-instanced HUD
> **Status**: Ready
> **Stories**: 4 stories

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | Scene configure and state machine | Integration | Ready | ADR-003, ADR-001 |
| 002 | Bar fill animation | Visual/Feel | Ready | ADR-001 |
| 003 | Hint arc animation | Visual/Feel | Ready | ADR-003 |
| 004 | Non-bar scenes and signal isolation | Logic | Ready | ADR-001, ADR-003 |

## Overview

Status Bar UI is the visual layer for the two progress bars and their hint arcs.
It is a scene-instanced HUD node that lives in the gameplay scene for the
duration of a play session. On scene load it reads bar count and bar IDs from
Scene Goal System via `get_goal_config()`. It then listens on EventBus for
`bar_values_changed` from Status Bar System (animates bar fill) and
`hint_level_changed` from Hint System (fades the counterclockwise arc). The
bars carry no labels, no numbers, and no win threshold. Status Bar UI renders
exactly what it receives and emits nothing back — a pure display component
and leaf node in the dependency graph.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-001: Naming Conventions | snake_case files/variables; PascalCase classes — `status_bar_ui.gd`, `StatusBarUI` | LOW |
| ADR-003: Signal Bus | Subscribes to `bar_values_changed` and `hint_level_changed` on EventBus; emits nothing | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-status-bar-ui-001 | Reads bar count/IDs via SceneGoalSystem.get_goal_config() on scene load | ADR-001 ✅ |
| TR-status-bar-ui-002 | Subscribes to EventBus bar_values_changed(values: Dictionary) from StatusBarSystem | ADR-003 ✅ |
| TR-status-bar-ui-003 | Subscribes to EventBus hint_level_changed(level: int) from HintSystem | ADR-003 ✅ |
| TR-status-bar-ui-004 | Animates bar fill height bottom-to-top via tween over bar_tween_sec (default 0.15s) | ADR-001 ✅ |
| TR-status-bar-ui-005 | Cancels in-flight fill tween on new bar_values_changed; resumes from current displayed height | ADR-001 ✅ |
| TR-status-bar-ui-006 | Hint arc opacity tween over arc_fade_sec (default 1.5s): L0=0, L1=0.3, L2=1.0 | ADR-001 ✅ |
| TR-status-bar-ui-007 | Arc traces counterclockwise around each bar border starting at top | ADR-001 ✅ |
| TR-status-bar-ui-008 | Dormant/Active/Frozen states drive whether signals are applied or ignored | ADR-003 ✅ |
| TR-status-bar-ui-009 | Non-bar goal scenes render empty panel; no bars, no arcs, no error | ADR-001 ✅ |
| TR-status-bar-ui-010 | Panel resets (bars empty, arcs hidden, Dormant) on scene transition | ADR-003 ✅ |
| TR-status-bar-ui-011 | Emits no signals; pure display component | ADR-003 ✅ |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/status-bar-ui.md` are verified
- All Logic and Integration stories have passing test files in `tests/`
- All Visual/Feel stories have evidence docs with Chester sign-off in `production/qa/evidence/`

## Next Step

Run `/create-stories status-bar-ui` to break this epic into implementable stories.
