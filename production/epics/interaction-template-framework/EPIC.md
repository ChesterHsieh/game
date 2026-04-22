# Epic: Interaction Template Framework

> **Layer**: Feature
> **GDD**: design/gdd/interaction-template-framework.md
> **Architecture Module**: Feature Layer — InteractionTemplateFramework (autoload singleton)
> **Status**: Ready
> **Stories**: 7 stories created

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | Autoload skeleton + EventBus wiring + recipe lookup | Logic | Ready | ADR-003 |
| 002 | Cooldown state machine + combination_succeeded/failed | Logic | Ready | ADR-003, ADR-005 |
| 003 | Additive template + combination_executed signal | Logic | Ready | ADR-003 |
| 004 | Merge template (async await + cancel path) | Integration | Ready | ADR-003 |
| 005 | Animate template (passthrough + fire-and-forget) | Logic | Ready | ADR-003 |
| 006 | Generator template (Timer nodes + max_count + cancel) | Logic | Ready | ADR-003 |
| 007 | Suspend/Resume + system-level state | Logic | Ready | ADR-003, ADR-004 |

## Overview

The Interaction Template Framework is the autoload singleton that bridges the physical card layer and the authored content layer. It listens to Card Engine's `combination_attempted(instance_id_a, instance_id_b)` signal, queries Recipe Database for a matching rule, and executes one of four interaction templates — Additive, Merge, Animate, or Generator. It manages three categories of runtime state (cooldown timers, generator timers, merge listeners), emits the 6-parameter `combination_executed` signal consumed by Status Bar System, Mystery Unlock Tree, and Hint System, and suspends during scene transitions. A new recipe can be authored in Recipe Database without any code change to ITF.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-003: Signal Bus | All inter-system communication via EventBus singleton; ITF emits `combination_succeeded`, `combination_failed`, `combination_executed` | LOW |
| ADR-001: Naming Conventions | snake_case variables/functions, PascalCase class names, SCREAMING_SNAKE for constants | LOW |
| ADR-005: Data File Format | Recipe data (cooldown values, generator config) in `.tres` Resources, not JSON | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-interaction-template-framework-001 | ITF is sole listener of Card Engine `combination_attempted(instance_id_a, instance_id_b)` signal | ADR-003 ✅ |
| TR-interaction-template-framework-002 | Derive base card_id from instance_id by stripping counter suffix | ADR-001 ✅ |
| TR-interaction-template-framework-003 | Query Recipe Database `lookup(card_id_a, card_id_b)` on every combination_attempted | ADR-003 ✅ |
| TR-interaction-template-framework-004 | Emit `combination_failed` on no recipe or cooldown; emit `combination_succeeded` on match | ADR-003 ✅ |
| TR-interaction-template-framework-005 | Execute Additive template: both source cards remain; result card(s) spawn near combination point | ADR-003 ✅ |
| TR-interaction-template-framework-006 | Execute Merge template: both source cards consumed; wait for `merge_animation_complete`; spawn result | ADR-003 ✅ |
| TR-interaction-template-framework-007 | Execute Animate template: target card enters Executing state; supports duration_sec and infinite loop | ADR-003 ✅ |
| TR-interaction-template-framework-008 | Execute Generator template: registers active generator; spawns cards at interval_sec; respects max_count | ADR-003 ✅ |
| TR-interaction-template-framework-009 | Emit `combination_executed(recipe_id, template, instance_id_a, instance_id_b, card_id_a, card_id_b)` (6 params) after every successful template execution | ADR-003 ✅ |
| TR-interaction-template-framework-010 | Manage per-recipe cooldown state (Available / Cooling); `combination_cooldown_sec` tuning knob default 30s | ADR-005 ✅ |
| TR-interaction-template-framework-011 | Manage per-generator state (Generating / Exhausted / Stopped); stop timer on `card_removing` | ADR-003 ✅ |
| TR-interaction-template-framework-012 | System-level state machine: Ready (accepts events) / Suspended (ignores events) | ADR-003 ✅ |
| TR-interaction-template-framework-013 | Scene Manager calls `suspend()` on transition begin; `resume()` on scene load complete | ADR-003 ✅ |
| TR-interaction-template-framework-014 | Handle Merge source card removed mid-animation: cancel merge, no result spawn, log warning | ADR-003 ✅ |
| TR-interaction-template-framework-015 | Handle Additive with no valid spawn position: log warning, emit `combination_executed` anyway | ADR-003 ✅ |
| TR-interaction-template-framework-016 | A new recipe added to Recipe Database requires no code change to ITF | ADR-005 ✅ |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/interaction-template-framework.md` are verified
- All Logic and Integration stories have passing test files in `tests/`
- All four template types (Additive, Merge, Animate, Generator) are exercised by automated unit tests
- `combination_executed` signal emits the 6-parameter form that downstream consumers (SBS, MUT, HS) can connect to

## Next Step

Run `/story-readiness production/epics/interaction-template-framework/story-001-autoload-skeleton.md` to begin implementation. Work stories in order 001 → 007 — each story's `Depends on:` field tells you what must be DONE first.
