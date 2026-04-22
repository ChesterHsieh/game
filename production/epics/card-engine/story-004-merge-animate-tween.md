# Story 004: Merge and Animate template animations + tween cancellation

> **Epic**: Card Engine
> **Status**: Complete
> **Layer**: Core
> **Type**: Visual/Feel
> **Manifest Version**: 2026-04-21

## Context

**GDD**: `design/gdd/card-engine.md`
**Requirements**: `TR-card-engine-013`, `TR-card-engine-014`, `TR-card-engine-016`

**ADR Governing Implementation**: ADR-002 (Tween-based motion, cancellable; CardEngine drives card node positions) + ADR-003 (signals back to ITF)
**ADR Decision Summary**: All card motion uses cancellable Godot Tween nodes (ADR-002). CardEngine emits `merge_animation_complete` and `animate_complete` to ITF via EventBus (ADR-003) so ITF knows when to proceed with spawning or stopping animation.

**Engine**: Godot 4.3 | **Risk**: LOW
**Engine Notes**: Chained `tween_property()` for position + scale + modulate.a on the same Tween is stable in 4.3. `tween.tween_callback()` fires after the final step. `create_tween().set_parallel(true)` allows simultaneous property tweens.

**Control Manifest Rules (Core layer + Presentation)**:
- Required: All card motion uses `Tween` via `create_tween()` + chained `tween_property()` — code-driven, not physics
- Required: EventBus for `merge_animation_complete` and `animate_complete` signals
- Forbidden: Never call `queue_free()` on card nodes directly — that is CardSpawningSystem's authority

---

## Acceptance Criteria

*From GDD `design/gdd/card-engine.md`, scoped to this story:*

- [ ] On `combination_succeeded` with `template="merge"`: both source cards tween their position to midpoint, scale to `Vector2.ZERO`, and `modulate.a` to `0.0` over `merge_duration_sec` (default 0.25s)
- [ ] After merge tweens complete: `merge_animation_complete(instance_id_a, instance_id_b, midpoint)` emits on EventBus
- [ ] On `combination_succeeded` with `template="animate"`: card enters EXECUTING state and applies looping motion from `config`; `animate_complete(instance_id)` emits when the animation is stopped by ITF
- [ ] Any in-flight Tween for a card is killed when `card_removing` fires for that card (before the node is freed)

---

## Implementation Notes

*Derived from ADR-002 + GDD card-engine.md post-combination sections:*

- On `combination_succeeded(a, b, template, config)` where `template == "merge"`:
  - Compute `midpoint = (card_a.position + card_b.position) / 2.0`
  - Create one Tween per card. Use `set_parallel(true)` to animate position + scale + modulate.a simultaneously:
    ```gdscript
    var t = create_tween().set_parallel(true)
    t.tween_property(card_node, "position", midpoint, MERGE_DURATION_SEC)
    t.tween_property(card_node, "scale", Vector2.ZERO, MERGE_DURATION_SEC)
    t.tween_property(card_node, "modulate:a", 0.0, MERGE_DURATION_SEC)
    ```
  - After both tweens complete: emit `EventBus.merge_animation_complete(a, b, midpoint)`. Use a counter or `await` pattern to detect both-done.
  - Transition both cards to EXECUTING during the animation.
- On `combination_succeeded` with `template == "animate"`:
  - Card enters EXECUTING; apply looping motion described in `config` each `_process` frame (e.g. circular orbit, oscillation). Config format TBD by ITF — implement a dispatch on `config.get("motion_type", "")`.
  - Store the active Tween/motion reference. When ITF emits a stop signal (design TBD), emit `animate_complete(instance_id)` and return card to IDLE.
- **Tween cancellation on `card_removing`** (TR-016): in the `_on_card_removing(instance_id)` handler (already registered in story-001), kill the stored Tween: `_cards[instance_id].active_tween.kill()` if not null.
- **Additive template**: both cards remain in place → transition to IDLE. No animation code needed here (handled by absence of merge/animate path).
- Constant: `MERGE_DURATION_SEC := 0.25`.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- [Story 003]: Snap tween and push-away (combination_failed path)
- [Interaction Template Framework epic]: ITF orchestrates what card is spawned after merge — CardEngine only animates the removal

---

## QA Test Cases

*Visual/Feel story — manual verification steps.*

- **AC-1**: Merge animation plays correctly
  - Setup: Trigger a Merge combination (two matching cards snap and produce a merge result). Observe in the Godot editor running the game.
  - Verify: Both source cards move toward their midpoint; they shrink and fade out over approximately 0.25 seconds; a new result card appears nearby (via ITF).
  - Pass condition: Both cards fully disappear (scale = 0, alpha = 0) within 0.25s ± 0.05s; no lingering ghost at the merge site; no frame hitch during the animation.

- **AC-2**: merge_animation_complete signal fires
  - Setup: Connect a test listener to `EventBus.merge_animation_complete` before the combination.
  - Verify: After merge tween finishes, the listener receives `(instance_id_a, instance_id_b, midpoint: Vector2)`.
  - Pass condition: Signal fires exactly once per merge; midpoint is correct.

- **AC-3**: Tween cancelled on card_removing
  - Setup: Start a merge animation, then immediately fire `card_removing` for one of the cards (simulating a scene transition).
  - Verify: The merge tween stops immediately; the card does not continue shrinking after `card_removing` fires.
  - Pass condition: No console errors about freed nodes; no null-access crash.

---

## Test Evidence

**Story Type**: Visual/Feel
**Required evidence**: `production/qa/evidence/card-engine-merge-animate-evidence.md` + sign-off

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: story-003-snap-combination-pushaway must be DONE
- Unlocks: None (final CardEngine story)
