# Epic: Status Bar Polish

> **Layer**: Polish
> **GDD**: `design/gdd/status-bar-ui.md` (existing) — this epic proposes polish-phase extensions, not a new GDD
> **Architecture Module**: `StatusBarUI` (existing) — rendering extensions only; state machine and signal contract unchanged
> **Status**: Draft
> **Stories**: 1 story drafted 2026-04-24 — see table below
> **Production Stage Gate**: Not for implementation during Production; deferred to Polish phase

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | Diegetic progress visuals (per-scene discrete art assets) | Visual/Feel | Draft | ADR-001, ADR-003 |

## Overview

The current StatusBarUI (completed in `production/epics/status-bar-ui/` Stories 001–004)
renders progress using a universal geometric primitive — an ink-outlined vertical track
with amber fill and an integer-count label. It works, and after the 2026-04-24 parchment
polish pass it blends with the overall aesthetic, but it is **scene-agnostic**: the same
rectangle shows whether you are brewing coffee or driving across the kingdom. The
designer's stated intent is for the progress indicator to eventually feel *staged* to
each scene — a journey in the car should feel like distance travelled, not a liquid
gauge filling up.

This epic is the polish-phase upgrade path. Each scene gets its own **discrete**,
narrative-aligned progress asset set — N sprites that light up one at a time as the
bar advances through integer milestones — wired through the existing StatusBarUI state
machine and signal contract. No new systems are introduced; StatusBarUI gains an
optional data-driven rendering mode that replaces the primitive bar with per-scene art
when a scene declares one.

The geometric fallback (current behaviour) remains for scenes that haven't been authored
a bespoke visual, so this epic never blocks content authoring.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-001: Naming conventions | snake_case files and scene JSON keys; new data-file fields follow `.claude/rules/data-files.md` enum-ish rule | LOW |
| ADR-003: Signal bus (EventBus) | No new signals. StatusBarUI continues to subscribe to `bar_values_changed` only — the discrete renderer is a swap-in view, not a new data source | LOW |

## GDD Requirements

New requirements that will be registered in `docs/architecture/tr-registry.yaml` when
this epic moves from Draft to Ready:

| TR-ID (proposed) | Requirement |
|------------------|-------------|
| TR-status-bar-ui-017 | Optional per-scene discrete-renderer mode: when `goal.bars[*].visual` is present in scene JSON, StatusBarUI replaces the default bar primitive with N sprite instances (N = `max_value`) per that bar |
| TR-status-bar-ui-018 | Each sprite has two states — "unlit" (muted/outline) and "lit" (fully rendered). Sprites light up in order as the bar value crosses each integer milestone |
| TR-status-bar-ui-019 | Discrete assets load from `res://assets/status-bar/<scene-id>/<bar-id>/<N>.png` where N ∈ {1..max_value}; missing art files fall back to the geometric primitive with a warning |
| TR-status-bar-ui-020 | Visual transition when a milestone is crossed: unlit → lit tween (200ms ease-out) with optional SFX hook (reuse `sfx_progress_tick` or scene-specific cue) |

## Engine Risk

- **Engine**: Godot 4.3 | **Risk**: LOW
- No new APIs beyond already-proven patterns (Sprite2D, Tween, ResourceLoader)
- Asset pipeline unchanged — just a new conventional path under `assets/status-bar/`
- `StatusBarUI` already has the state machine and signal wiring; this is a rendering-layer extension

## Dependencies

**Inbound** (this epic depends on):
- `status-bar-ui` epic — Stories 001–004 must be Complete (they are)
- Art pipeline for producing per-scene discrete assets — coordinate with `/img-card`
  style system so visuals match the game's parchment/ink aesthetic
- Scene authoring pass — each scene must decide whether it wants a bespoke visual or
  accepts the geometric fallback

**Outbound** (depends on this epic):
- No downstream code dependencies. Content authoring can proceed without this epic
  completing.

## Stage Gating

This epic is **deferred from Production** per the producer's Polish-phase plan. It must
NOT be worked on during Production sprints because:
1. The geometric fallback is already functional and readable
2. Discrete per-scene art is polish-tier value — it deepens immersion but does not
   unblock gameplay
3. Creating the art assets requires the full set of shipping scenes to be locked so
   the visual language stays consistent across them

Move to Ready when `stage.txt` transitions to `Polish` and `/gate-check polish` passes.

## Out of Scope

- Horizontal bar layout variants (deferred to a separate feature epic if needed)
- Animated/looping sprites (unlit → lit is one-shot tween only; full animation is out)
- Per-bar color theming beyond what the assets themselves encode
- Localization of bar labels (already covered by existing scene JSON `label` field)

## Untraced Requirements

None at Draft time. When promoted to Ready, ensure the four TR-IDs above are added to
`docs/architecture/tr-registry.yaml` and cross-referenced here.
