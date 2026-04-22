# Story 005: Animate Template

> **Epic**: Interaction Template Framework
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Manifest Version**: 2026-04-21

## Context

**GDD**: `design/gdd/interaction-template-framework.md`
**Requirements**: `TR-interaction-template-framework-007` (Animate), `TR-interaction-template-framework-010`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-003: Inter-System Communication — EventBus Singleton
**ADR Decision Summary**: All inter-system communication via EventBus. Animate template emits `combination_succeeded(animate, config)` to Card Engine. Card Engine puts the target card in `Executing` state and drives the animation. ITF listens to `animate_complete` only when `duration_sec` is set; for infinite-loop animations ITF has no ongoing state to track.

**Engine**: Godot 4.3 | **Risk**: LOW
**Engine Notes**: `animate_complete(instance_id: String)` is emitted by Card Engine when a timed animation ends. Use typed signal connection: `EventBus.animate_complete.connect(_on_animate_complete)`. For infinite-loop variants (`duration_sec` is null/0), ITF emits `combination_executed` and is done — Card Engine's `Executing` state lasts until `clear_all_cards()` on scene transition.

**Control Manifest Rules (Feature Layer)**:
- Required: Use EventBus for all cross-system events
- Forbidden: Never use `yield()` — use `await signal`

---

## Acceptance Criteria

*From GDD `design/gdd/interaction-template-framework.md`, scoped to this story:*

- [ ] Animate template: emits `combination_succeeded(instance_id_a, instance_id_b, "animate", config)` where `config = {motion, speed, target, duration_sec}` from `recipe.config`
- [ ] Card Engine receives `combination_succeeded` and puts the target card(s) in `Executing` state — cards in Executing cannot be dragged or start a new combination
- [ ] `combination_executed(recipe_id, "animate", ...)` is emitted immediately after `combination_succeeded` (no waiting for animation to complete)
- [ ] When `duration_sec` is set and `animate_complete(instance_id)` fires: card returns to Idle (Card Engine owns this transition); ITF has no ongoing state to clean up for timed animations
- [ ] When `duration_sec` is null/0 (infinite loop): animation runs indefinitely; ITF takes no further action after emitting `combination_executed`

---

## Implementation Notes

*Derived from ADR-003:*

- `_execute_animate(recipe, instance_id_a, instance_id_b)`: emit `combination_succeeded` with `recipe.config` as-is (ITF does not interpret the animate config — it is a passthrough for Card Engine).
- Immediately after emitting `combination_succeeded`: emit `combination_executed` (6-param) — do NOT wait for animation to finish.
- ITF does NOT need to listen to `animate_complete` — Card Engine handles the state transition. The only ITF concern with `animate_complete` is if a future design requires ITF to unlock the recipe cooldown on completion. For now, the cooldown starts when `combination_succeeded` fires (Story 002 already does this).
- Connect `EventBus.animate_complete.connect(_on_animate_complete)` in `_ready()` — the handler is a no-op for now but ensures the signal is wired. This prepares for any future logic.
- The `target` field in `config` specifies which card (`"card_a"`, `"card_b"`, or `"both"`) — Card Engine reads this; ITF passes it through unchanged.
- No Merge-style pending-state tracking needed — Animate is fire-and-forget from ITF's perspective.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 004: Merge template (has async await)
- Story 006: Generator template (timed spawns)
- Card Engine's animation implementation (Executing state, tween, animate_complete emission)

---

## QA Test Cases

**AC-1**: Animate emits combination_succeeded then combination_executed immediately
- Given: recipe `"chester-morning"` is Animate with `config = {motion: "orbit", speed: 1.0, target: "card_a", duration_sec: 5.0}`
- When: `combination_attempted("chester_0", "morning_0")` fires (recipe Available)
- Then: `combination_succeeded("chester_0", "morning_0", "animate", config)` emitted; `combination_executed("chester-morning", "animate", "chester_0", "morning_0", "chester", "morning")` emitted; no `remove_card` call; no `spawn_card` call
- Edge cases: `duration_sec = null` → same behaviour (no special handling)

**AC-2**: Infinite-loop animate — no further ITF state after execution
- Given: recipe is Animate with `duration_sec: null`
- When: `combination_attempted` fires and succeeds
- Then: after `combination_executed` emits, no timer is pending in ITF for this recipe; `animate_complete` can fire or not without affecting ITF state

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/interaction_template_framework/animate_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 003 (combination_executed pattern), Story 002 (cooldown) must be DONE
- Unlocks: Story 006 (Generator template)
