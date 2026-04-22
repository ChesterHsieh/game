# Story 002: State-driven visual config

> **Epic**: Card Visual
> **Status**: Complete
> **Layer**: Presentation
> **Type**: Visual/Feel
> **Manifest Version**: 2026-04-21

## Context

**GDD**: `design/gdd/card-visual.md`
**Requirement**: `TR-card-visual-002`, `TR-card-visual-004`, `TR-card-visual-006`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-002: Card Object Pooling, ADR-001: Naming Conventions
**ADR Decision Summary**: Card scenes are pooled — CardVisual resets visual state (scale, shadow, z-order) when a card is returned to and re-acquired from the pool (ADR-002). All variable and file names follow snake_case; class names PascalCase (ADR-001).

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

- [ ] Dragging a card: scale increases to `drag_scale` and drop shadow appears instantly on state change to `Dragged`
- [ ] Releasing a card outside snap zone: scale returns to 100% and shadow disappears instantly on transition to `Idle`
- [ ] A card in `Attracting` state: same visual as `Dragged` (105% scale, shadow on)
- [ ] A card in `Pushed` state: renders at 100% scale, no shadow, at the position Card Engine provides
- [ ] The dragged card renders above all other cards (highest z-order)
- [ ] Z-order restores after the card transitions to `Idle` or `Pushed`

---

## Implementation Notes

*Derived from governing ADR(s):*

- **Frame-read pattern (GDD Core Rule 4)**: Each frame, CardVisual reads the card state enum from CardEngine and applies the matching visual config from the state table. Use `_process()` or a state-change callback — whichever CardEngine exposes. Do not cache the previous state in a way that prevents the correct config from being applied after a pool reset.
- **Instant value changes (GDD Detailed Design)**: State transitions apply scale, shadow, and z-order instantly — no cross-fade or tween between states. The only tween in CardVisual is the Merge animation (Story 003). Use direct property assignment: `scale = drag_scale`, `z_index = TOP_Z_INDEX`.
- **State table (GDD States and Transitions)**:
  - `Idle`: scale `Vector2(1.0, 1.0)`, shadow off, z-order restored to authored position
  - `Dragged`: scale `Vector2(1.05, 1.05)`, shadow on, z-order top
  - `Attracting`: scale `Vector2(1.05, 1.05)`, shadow on, z-order top
  - `Snapping`: scale `Vector2(1.05, 1.05)`, shadow on, z-order top
  - `Pushed`: scale `Vector2(1.0, 1.0)`, shadow off, z-order restored
  - `Executing` (Additive/Generator): scale `Vector2(1.0, 1.0)`, shadow off, z-order restored
- **Z-order restore**: CardVisual must store the card's authored `z_index` at spawn time. On transition to `Idle`, `Pushed`, or `Executing` (non-Merge), restore that stored value. On transition to `Dragged`/`Attracting`/`Snapping`, set `z_index` to a constant `TOP_Z_INDEX` that is above all other cards.
- **Pool reset (ADR-002)**: On card return-to-pool, CardVisual must reset scale to `Vector2(1.0, 1.0)`, shadow off, and z-order to authored value. The next card acquire must start from a clean visual state.
- **Tuning knobs as `@export` (GDD Tuning Knobs)**: `drag_scale`, `shadow_offset`, `shadow_opacity` must all be `@export` variables so they can be changed without modifying any other system.
- **Unknown state fallback (GDD Edge Cases)**: If CardEngine provides a state enum value CardVisual does not recognise, apply the `Idle` visual config and log a warning. Do not crash.
- **Naming conventions (ADR-001)**: Constants such as `TOP_Z_INDEX` in SCREAMING_SNAKE_CASE; variables such as `_authored_z_index` (private, prefixed) in snake_case.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: Reading CardDatabase on spawn, rendering label/art/badge
- Story 003: Merge tween animation (scale-to-zero, opacity-to-zero)
- Story 004: Error handling for missing art / invalid card_id

---

## QA Test Cases

*Visual/Feel story — manual verification steps:*

- **AC-1**: Dragging a card: scale increases to `drag_scale` and drop shadow appears instantly on state change to `Dragged`
  - Setup: Launch gameplay scene; observe a card at rest (Idle). Click and hold a card to begin dragging.
  - Verify: The moment the drag starts, the card visibly enlarges to ~105% of its resting size and a drop shadow appears beneath it.
  - Pass condition: Scale and shadow change occur on the same frame as drag start; no animation delay is visible.

- **AC-2**: Releasing a card outside snap zone: scale returns to 100% and shadow disappears instantly on transition to `Idle`
  - Setup: Drag a card; release it away from any snap target.
  - Verify: On release, the card immediately returns to its original size (100%) and the drop shadow disappears.
  - Pass condition: No gradual scale-down or shadow fade is visible; the change is instant.

- **AC-3**: A card in `Attracting` state: same visual as `Dragged` (105% scale, shadow on)
  - Setup: Drag a card close enough to another card to trigger magnetic attraction (card enters Attracting state).
  - Verify: The dragged card's scale and shadow remain identical to the Dragged state — no additional visual indicator appears.
  - Pass condition: No secondary ring, glow, or indicator appears on either card beyond the existing drag scale and shadow.

- **AC-4**: A card in `Pushed` state: renders at 100% scale, no shadow, at the position Card Engine provides
  - Setup: Trigger a combination that pushes a card to a new position.
  - Verify: The pushed card renders at 100% scale with no shadow throughout and after the push.
  - Pass condition: Pushed card is visually identical to an Idle card except for its position.

- **AC-5**: The dragged card renders above all other cards (highest z-order)
  - Setup: Drag a card so that it overlaps at least two other cards on the table.
  - Verify: The dragged card is fully visible above all other cards it crosses.
  - Pass condition: No other card's art, label, or border is drawn on top of the dragged card at any point during the drag.

- **AC-6**: Z-order restores after the card transitions to `Idle` or `Pushed`
  - Setup: Drag a card over another card, then release it (Idle transition).
  - Verify: After release, the card's z-order returns to its original authored table position — other cards that were below it may now render in front if their authored z-order is higher.
  - Pass condition: The released card's rendering order matches its pre-drag authored position.

---

## Test Evidence

**Story Type**: Visual/Feel
**Required evidence**: `production/qa/evidence/card-visual-state-config-evidence.md`
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (Card spawn and data read) must be DONE
- Unlocks: Story 003 (Merge tween animation)
