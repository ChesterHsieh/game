# Story 001: Diegetic Progress Visuals (Per-Scene Discrete Art Assets)

> **Epic**: Status Bar Polish
> **Status**: Draft — deferred to Polish phase
> **Layer**: Polish
> **Type**: Visual/Feel
> **Manifest Version**: 2026-04-24

## Context

**GDD**: `design/gdd/status-bar-ui.md`
**Requirement (proposed)**: `TR-status-bar-ui-017`, `TR-status-bar-ui-018`, `TR-status-bar-ui-019`, `TR-status-bar-ui-020`
*(Will be registered in `docs/architecture/tr-registry.yaml` when this story is promoted from Draft to Ready — do not implement during Production.)*

**ADR Governing Implementation**: ADR-001 (Naming Conventions), ADR-003 (Signal Bus — EventBus)
**ADR Decision Summary**: StatusBarUI remains a leaf subscriber (no emits). The discrete
renderer is an internal view swap gated on scene-JSON data; it uses the same
`bar_values_changed` signal the primitive renderer uses, so there is no new
cross-system contract.

**Engine**: Godot 4.3 | **Risk**: LOW
**Engine Notes**: Sprite2D + Tween are stable; ResourceLoader warnings on missing
files are sufficient for graceful fallback — no new API needed.

**Control Manifest Rules (Polish Layer)**:
- Required: No hardcoded asset paths in code — path pattern is scene/bar-id derived
- Required: Missing art must warn-and-fallback, never crash (hits `/asset-audit`)
- Required: Visual changes include screenshot evidence in `production/qa/evidence/`
- Forbidden: Do not add new EventBus signals — reuse existing ones

---

## Motivation

Currently the status bar renders as a universal outlined rectangle with a label
underneath (e.g. "旅程進度 0/3"). It's readable and matches the parchment palette, but
it feels generic — nothing about it says "you are driving across a kingdom". Designer
intent is for the progress indicator to eventually feel *staged* to the scene it sits
in. A journey should show distance covered; a relationship build-up should show
something warmer than a bar. Discrete milestones (instead of a continuous fill) map
naturally onto the small-max bars the game uses (drive's `journey_progress` max=3,
etc.).

## Acceptance Criteria

*From `design/gdd/status-bar-ui.md` §Tuning Knobs and §Acceptance Criteria, scoped:*

- [ ] **AC-1** When a scene JSON includes `goal.bars[*].visual = { "type": "discrete_sprites", "path_prefix": "<scene>/<bar>" }`, StatusBarUI loads `res://assets/status-bar/<scene>/<bar>/1.png` through `N.png` where N = `max_value`, and renders them in a vertical stack inside the left panel in place of the primitive bar
- [ ] **AC-2** Each sprite has an "unlit" appearance (50% opacity) until the bar value reaches its milestone (sprite index i lights up when `bar_value >= i`)
- [ ] **AC-3** When a milestone is crossed, the sprite tweens from unlit to lit over 200ms with a cubic-ease-out curve; other sprites are not affected
- [ ] **AC-4** Missing sprite files (any of 1.png..N.png) trigger a single `push_warning` per load and cause StatusBarUI to fall back to the primitive renderer for that bar only — other bars in the scene are unaffected
- [ ] **AC-5** Scenes without `goal.bars[*].visual` continue to render the existing primitive bar exactly as before (no behavioural regression for `coffee-intro` or any scene authored before this story)
- [ ] **AC-6** The label text ("旅程進度 0/3") is still drawn below the sprite stack in discrete mode, using the same CJK font and colour as the primitive renderer
- [ ] **AC-7** Visual transition to "lit" emits no new signal; existing `bar_values_changed` handler drives the state change

## Out of Scope

- Horizontal sprite layout (this story is vertical-stack only to match the current
  left-panel geometry)
- Looping / idle animations on lit sprites (one-shot tween only)
- Per-bar soundtrack cues tied to individual milestones (basic hook via existing
  `sfx_progress_tick` is acceptable but bespoke per-milestone SFX is a separate story)
- Asset production for shipping scenes (that's a content-authoring task, not this
  story — this story is code + one placeholder asset set for the drive scene)
- Discrete renderer for non-bar goal types (`find_key`, `sequence`) — this story
  covers `reach_value` and `sustain_above` only

## Test Evidence

**Type**: Visual/Feel (per `.claude/docs/coding-standards.md` §Testing Standards)
**Required evidence**:
- Manual walkthrough document with before/after screenshots in
  `production/qa/evidence/story-001-diegetic-progress-evidence.md`
- Lead sign-off (art-director + ux-designer) on the drive scene's milestone asset
  set before this story can be marked Done

**Automated test** (advisory, non-blocking):
- `tests/unit/status_bar_ui/discrete_renderer_fallback_test.gd` — verifies that
  missing art triggers fallback-with-warning and that a scene without the `visual`
  key renders unchanged
- No automated visual regression test — screenshot diffs are not reliable for
  parchment/hand-drawn assets

## Implementation Notes

**From ADR-001 (Naming Conventions):**
- New data key: `goal.bars[i].visual` (nested Dictionary). Lowercase snake_case keys:
  `type`, `path_prefix`. Enum-ish `type` value is `"discrete_sprites"` (lowercase
  snake_case per `.claude/rules/data-files.md`)
- New file path pattern: `res://assets/status-bar/<scene-id>/<bar-id>/<N>.png` where
  N is 1-indexed integer

**From ADR-003 (Signal Bus):**
- Do NOT add new signals — the discrete renderer is purely a view swap driven by the
  same `bar_values_changed` handler that drives the primitive renderer
- When the handler fires, compute which sprite indices crossed a threshold *since the
  previous value* and tween only those; do not re-tween sprites that were already lit

**Render structure** (internal):
- Add `_bar_discrete_sprites: Dictionary` mapping `bar_id → Array[Sprite2D]`
- Add `_bar_render_mode: Dictionary` mapping `bar_id → "primitive" | "discrete"`
- `configure_for_scene()` branches per-bar: if visual config present and art loads,
  set mode to `discrete` and build sprite stack; else keep `primitive`
- `_draw_bar()` branches on `_bar_render_mode[bar_id]`
- Discrete mode uses Sprite2D children (not `_draw` calls) so Godot's built-in
  tween-on-sprite pattern works without custom per-frame interpolation

## Dependencies

- Art pipeline: first-round placeholder art for `drive/journey_progress/1.png` through
  `3.png`. Style: match parchment ink-wash aesthetic. Subject suggestion: three
  progressively more-detailed landmark stamps (signpost → bridge → destination).
  Coordinate with `/img-card` style or a dedicated `/img-progress-marker` skill
  (deferred — not blocking this story)
- Epic: `status-bar-polish/EPIC.md`

## Staging

**Do not implement during Production**. Promote to Ready only when:
1. `production/stage.txt` transitions to `Polish`
2. `/gate-check polish` passes
3. Shipping scenes are locked (so the art production phase knows the full set)
4. Art-director approves the placeholder style direction for the first scene

## Completion Notes

*Filled in by `/story-done` when this story is marked Complete.*
