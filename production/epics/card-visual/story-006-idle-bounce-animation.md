# Story 006: Idle Rabbit-Jump Animation

> **Epic**: Card Visual
> **Status**: Done
> **Layer**: Presentation
> **Type**: Visual/Feel
> **Manifest Version**: 2026-04-21

## Context

**GDD**: `design/gdd/card-visual.md`
**Requirement**: `TR-card-visual-012`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: [ADR-002: Card Object Pooling](../../../docs/architecture/ADR-002-card-object-pooling.md)
**ADR Decision Summary**: Card scenes are pooled; CardVisual must reset all animation state (including jump tweens and `_jump_dir`) on pool acquire via `reset()`.

**Engine**: Godot 4.3 | **Risk**: LOW
**Engine Notes**: Each hop is a fresh non-looping `Tween`; the landing callback chains the next hop. This avoids `set_loops()` so that random drift can be picked fresh each time. Tween must be `.kill()`-ed explicitly in `_stop_bounce()` — same pattern as `_cancel_merge_tween()`.

**Control Manifest Rules (this layer)**:
- Required: Pure renderer — no game state owned, no signals emitted
- Forbidden: CardVisual must not write to CardEngine or CardDatabase
- Guardrail: x drift moves `CardNode.position.x` (parent) — CardEngine reads `CardNode.position` only during drag, so IDLE drift is safe

---

## Acceptance Criteria

- [x] Cards tagged `"rabbit_jump"` in `CardEntry.tags` hop while in `State.IDLE`
- [x] Each hop: y arc −20 px (rise 0.25 s `EASE_OUT`, fall 0.55 s `EASE_IN`) with simultaneous x drift of ±40–60 px (randomised each landing)
- [x] At viewport edges (< 60 px margin) x direction flips, preventing cards from leaving the table
- [x] Hop sequence pauses (tween killed, `position.y` and drift zeroed) when card enters any non-IDLE state
- [x] Hop sequence resumes from y=0 when card returns to IDLE
- [x] `reset()` on pool acquire kills the jump tween, zeros `position.y`, and resets `_jump_dir = 1.0`
- [x] Non-`rabbit_jump` cards are completely unaffected

---

## Implementation Notes

*Derived from ADR-002 Implementation Guidelines:*

- **No `set_loops()`** — each hop is a single non-looping `Tween`. The landing callback calls `_do_hop()` again, allowing fresh random drift per hop. `_bounce_tween` is cleared to `null` before the callback fires so `_do_hop()` sees no active tween.
- **x drift moves `CardNode.position.x`** (the parent `Node2D`). CardVisual's own `position.y` handles the vertical arc. This keeps the card's table position advancing each hop without fighting CardEngine (which only reads position during drag states).
- **Edge detection** reads `get_viewport_rect().size` and `parent_node.position.x` — no dependency on TableLayoutSystem.
- `_jump_dir` (`+1.0` / `-1.0`) is flipped before the hop when the projected landing would exceed the margin; drift magnitude is re-randomised after the flip.
- All state (`_bounce_tween`, `_is_bouncy`, `_was_idle`, `_jump_dir`) is cleared in `reset()`.

**@export tuning knobs (Inspector-adjustable)**:
| Field | Default | Purpose |
|---|---|---|
| `jump_peak_px` | `-20.0` | Arc height (negative = up) |
| `jump_rise_sec` | `0.25` | Upward stroke duration |
| `jump_fall_sec` | `0.55` | Downward stroke duration |
| `jump_drift_min_px` | `40.0` | Minimum x drift per hop |
| `jump_drift_max_px` | `60.0` | Maximum x drift per hop |
| `jump_edge_margin_px` | `60.0` | Viewport edge buffer before direction flip |

---

## Out of Scope

- Story 003: Merge tween (scale + opacity) — unrelated
- Story 002: State-driven scale/shadow — unrelated; jump is additive

---

## QA Test Cases

*Manual verification — Visual/Feel story.*

- **AC-1**: Rabbit-jump card hops in IDLE
  - Setup: Spawn a card with `CardEntry.tags = ["rabbit_jump"]`. Let it sit idle.
  - Verify: Card arcs upward ~20 px then falls, drifting sideways 40–60 px per hop. Direction varies each landing.
  - Pass condition: Smooth arc with no stutter between hops.

- **AC-2**: Direction reverses at edges
  - Setup: Let the card hop until it approaches the viewport edge.
  - Verify: On the hop before the edge, x direction flips. Card bounces back inward.
  - Pass condition: Card never leaves the 60 px edge margin.

- **AC-3**: Jump stops while dragging
  - Setup: Pick up the jumping card.
  - Verify: Card stops mid-hop; `position.y` resets to 0 cleanly. No oscillation while held.
  - Pass condition: Card follows cursor at correct y with no residual arc.

- **AC-4**: Jump resumes after drop
  - Setup: Drop the card back (IDLE).
  - Verify: Hop sequence restarts from y=0.
  - Pass condition: No y-offset artifact from pre-drag arc position.

- **AC-5**: Non-tagged cards unaffected
  - Setup: Spawn a card without `"rabbit_jump"` tag alongside the hopping card.
  - Verify: Non-tagged card sits perfectly still in IDLE.
  - Pass condition: Zero movement on non-tagged card.

- **AC-6**: Pool reset clears jump
  - Setup: Merge two cards (one with `"rabbit_jump"`). The card is consumed and re-spawned as a different card without the tag.
  - Verify: Re-spawned card does not hop.
  - Pass condition: No residual jump tween on recycled card.

---

## Test Evidence

**Story Type**: Visual/Feel
**Required evidence**: `production/qa/evidence/story-006-rabbit-jump-evidence.md` + Chester sign-off

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (card spawn + data read) — DONE
- Depends on: Story 002 (state-driven visual config, `_apply_state_config`) — DONE
- Unlocks: None
