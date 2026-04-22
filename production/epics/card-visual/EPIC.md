# Epic: Card Visual

> **Layer**: Presentation
> **GDD**: design/gdd/card-visual.md
> **Architecture Module**: CardVisual — per-card instance rendering
> **Status**: Ready
> **Stories**: 4 stories

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | Card spawn and data read | Integration | Ready | ADR-002, ADR-003 |
| 002 | State-driven visual config | Visual/Feel | Ready | ADR-002, ADR-001 |
| 003 | Merge tween animation | Visual/Feel | Ready | ADR-002 |
| 004 | Error handling and fallbacks | Logic | Ready | ADR-001, ADR-002 |

## Overview

Card Visual is the per-card rendering component that every card instance on the
table carries. It reads content (display_name, art_path, optional badge) from
Card Database on spawn and caches it. Each frame it reads the card's current
state enum from Card Engine and applies the matching visual configuration:
scale, drop shadow, z-order, and merge tween. Card Visual owns no game state —
it is a pure renderer. Nothing reads from it; it is a leaf node in the
dependency graph.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-002: Card Object Pooling | Card scenes are pooled rather than created/destroyed; CardVisual is part of the pooled card scene and resets state on acquire | LOW |
| ADR-001: Naming Conventions | snake_case files/variables; PascalCase classes — `card_visual.gd`, `CardVisual` node | LOW |
| ADR-003: Signal Bus | Inter-system communication via EventBus autoload; CardVisual emits no signals and subscribes to none — pure frame-read from CardEngine state | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-card-visual-001 | Per-card rendering node; reads display_name/art_path/badge from CardDatabase on spawn and caches | ADR-002 ✅ |
| TR-card-visual-002 | Reads card state enum from CardEngine each frame to apply visual config | ADR-002 ✅ |
| TR-card-visual-003 | Renders label, circular-masked art, optional badge inside bordered frame | ADR-001 ✅ |
| TR-card-visual-004 | Dragged/Attracting/Snapping states: scale 1.05 + drop shadow + top z-order | ADR-002 ✅ |
| TR-card-visual-005 | Merge execute: tween scale 1.0→0.0 and modulate.a 1.0→0.0 over merge_duration_sec (Godot Tween) | ADR-002 ✅ |
| TR-card-visual-006 | Z-order restored to authored position on transition to Idle/Pushed/Executing | ADR-002 ✅ |
| TR-card-visual-007 | Missing art asset: render fallback circular placeholder and log warning with card_id | ADR-001 ✅ |
| TR-card-visual-008 | Invalid card_id: render full placeholder (label='?', fallback circle) and log error | ADR-001 ✅ |
| TR-card-visual-009 | Long display_name clipped/truncated to label region; does not overflow art area | ADR-001 ✅ |
| TR-card-visual-010 | Cancel active merge tween cleanly on scene transition; no partial-scale artifact | ADR-002 ✅ |
| TR-card-visual-011 | Emits no signals; pure consumer of CardDatabase + CardEngine | ADR-003 ✅ |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/card-visual.md` are verified
- All Logic and Integration stories have passing test files in `tests/`
- All Visual/Feel stories have evidence docs with Chester sign-off in `production/qa/evidence/`

## Next Step

Run `/create-stories card-visual` to break this epic into implementable stories.
