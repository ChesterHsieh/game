# Story 003: Merge tween animation

> **Epic**: Card Visual
> **Status**: Complete
> **Layer**: Presentation
> **Type**: Visual/Feel
> **Manifest Version**: 2026-04-21

## Context

**GDD**: `design/gdd/card-visual.md`
**Requirement**: `TR-card-visual-005`, `TR-card-visual-010`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-002: Card Object Pooling
**ADR Decision Summary**: Card scenes are pooled — Card Spawning System owns removal; CardVisual must never call `queue_free()` directly. After the merge tween completes, CardVisual signals completion via the expected mechanism so Card Spawning System can return the card to the pool.

**Engine**: Godot 4.3 | **Risk**: LOW
**Engine Notes**: Tween API (`create_tween()`, chained `.tween_property()`, `Tween.kill()` for cancel) stable in 4.3. `z_index` property stable. `@onready` stable.

**Control Manifest Rules (Presentation Layer)**:
- Required: Card visuals use `Tween` via `create_tween()` + chained `tween_property()` for all card motion
- Required: CanvasLayer stack in gameplay.tscn — CardTable at z_index 0, HudLayer at layer 5
- Forbidden: Never change CanvasLayer ordering without a new ADR
- Guardrail: < 50 draw calls per frame; < 256 MB memory

---

## Acceptance Criteria

*From GDD `design/gdd/card-visual.md`, scoped to this story:*

- [ ] Merge animation: card scale tweens from 100% to 0% and opacity from 100% to 0% over `merge_duration_sec`, then card is removed from scene
- [ ] If merge tween is interrupted (scene transition): tween cancels cleanly, no partial-scale or partial-opacity artifact remains

---

## Implementation Notes

*Derived from governing ADR(s):*

- **Tween API (Control Manifest, Presentation Layer)**: The merge animation must use `create_tween()` with chained `.tween_property()` calls — one for `scale` and one for `modulate.a`. This is the mandatory card-motion pattern for this project. Do not use `AnimationPlayer` or manual lerp in `_process()`.
- **Merge formula (GDD Formulas)**:
  ```
  tween.scale      = lerp(Vector2(1.0, 1.0), Vector2(0.0, 0.0), t)
  tween.modulate.a = lerp(1.0, 0.0, t)
  // t: 0.0 → 1.0 over merge_duration_sec
  ```
  Both properties run in parallel over the same duration. Easing: linear by default; `ease_in` is a candidate for prototype — resolve during implementation.
- **`merge_duration_sec` ownership (GDD Formulas note)**: This value is owned by Card Engine. CardVisual reads it — it does not define it. At implementation time, confirm how Card Engine exposes this value (direct property, method, or resource field) and read it there. Do not duplicate the constant in `card_visual.gd`.
- **Tween cancel on interruption (GDD Edge Cases)**: When Card Engine cancels a merge (e.g., scene transition fires during the tween), CardVisual must call `Tween.kill()` on the active tween. After killing the tween, the card's `scale` and `modulate.a` must be restored to their pre-tween authored values (`Vector2(1.0, 1.0)` and `1.0`) before the card is returned to the pool. No partial-scale or partial-opacity artifact must remain.
- **No `queue_free()` (ADR-002)**: CardVisual must not call `queue_free()` after the tween completes. The tween's `finished` signal (or the equivalent callback) must notify Card Spawning System, which then returns the card to the pool via its own API.
- **Pool reset (ADR-002)**: When the card re-enters the pool after a merge, CardVisual's `_on_pool_reset()` (or equivalent reset method) must set `scale = Vector2(1.0, 1.0)` and `modulate.a = 1.0` to ensure the next acquire starts clean.
- **Tween reference storage**: Store the active `Tween` in a private variable (e.g., `_merge_tween: Tween`) so it can be killed cleanly if interrupted. Do not create a new tween without killing the previous one.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: Reading CardDatabase on spawn, rendering label/art/badge
- Story 002: State-driven visual config (instant scale/shadow/z-order changes for non-Merge states)
- Story 004: Error handling for missing art / invalid card_id

---

## QA Test Cases

*Visual/Feel story — manual verification steps:*

- **AC-1**: Merge animation: card scale tweens from 100% to 0% and opacity from 100% to 0% over `merge_duration_sec`, then card is removed from scene
  - Setup: Set up a valid Merge combination on the table. Execute the combination so Card Engine drives both cards to the midpoint and transitions them to `Executing` (Merge template).
  - Verify: Both cards simultaneously shrink from full size to a point and fade from fully opaque to fully transparent. The animation takes the configured `merge_duration_sec` (default 0.25 s). After the animation completes, both cards are no longer visible on the table.
  - Pass condition: Scale reaches `Vector2(0.0, 0.0)` and `modulate.a` reaches `0.0` at the same moment. No card geometry remains after completion. Duration matches `merge_duration_sec` within one frame.

- **AC-2**: If merge tween is interrupted (scene transition): tween cancels cleanly, no partial-scale or partial-opacity artifact remains
  - Setup: Trigger a Merge combination, then immediately trigger a scene transition (or manually force a scene change in testing) before `merge_duration_sec` has elapsed — i.e., while the card is at an intermediate scale/opacity such as 50%/50%.
  - Verify: The tween stops immediately. The card is either removed cleanly from the table or returned to the pool with `scale = Vector2(1.0, 1.0)` and `modulate.a = 1.0`. No "ghost" card is visible at partial scale or partial opacity.
  - Pass condition: After the interruption, no card geometry at a non-zero partial scale or partial opacity is visible anywhere on screen. Checking the scene tree shows no orphaned card node at abnormal visual state.

---

## Test Evidence

**Story Type**: Visual/Feel
**Required evidence**: `production/qa/evidence/card-visual-merge-tween-evidence.md`
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002 (State-driven visual config) must be DONE
- Unlocks: Story 004 (Error handling and fallbacks)
