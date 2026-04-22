# Story 001: Card spawn and data read

> **Epic**: Card Visual
> **Status**: Complete
> **Layer**: Presentation
> **Type**: Integration
> **Manifest Version**: 2026-04-21

## Context

**GDD**: `design/gdd/card-visual.md`
**Requirement**: `TR-card-visual-001`, `TR-card-visual-003`, `TR-card-visual-011`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-002: Card Object Pooling, ADR-003: Signal Bus
**ADR Decision Summary**: Card scenes are pooled — CardVisual is part of the pooled card scene and resets state on acquire (ADR-002). CardVisual emits no signals and subscribes to none; it is a pure frame-reader of CardEngine state, not an EventBus participant (ADR-003).

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

- [ ] A card at rest displays: `display_name` in the label region, circular cropped art in the center, and badge at bottom (if card has one in Card Database)
- [ ] A card with no `badge` field renders correctly with no badge region visible
- [ ] Art image is visually circular regardless of source image aspect ratio

---

## Implementation Notes

*Derived from governing ADR(s):*

- **Pool reset on acquire (ADR-002)**: When Card Spawning System hands a card from the free list, CardVisual must re-read CardDatabase for the new `card_id` in `_ready()` (or a dedicated `reset(card_id)` method called by Card Spawning System on acquire). Cached data from the previous use must be cleared before populating with the new card's data.
- **No signals emitted (ADR-003)**: CardVisual must not emit any signal via EventBus. It is a pure consumer. Any temptation to signal "card rendered" or "art loaded" is out of scope — Card Spawning System tracks pool state independently.
- **Direct autoload query (ADR-003)**: Reading from CardDatabase uses a direct autoload call (`CardDatabase.get_card(card_id)`) — not an EventBus event. This is correct; EventBus is for events, not queries.
- **Typed cast + null check (Control Manifest, Foundation Layer)**: The result of `CardDatabase.get_card(card_id)` must be cast to the appropriate `CardData` type and null-checked. A bare null check on a generic Resource is insufficient.
- **Circular art via mask**: The circular crop is achieved in the Godot scene via a `TextureRect` clipped by a circular `StyleBox` or `ClipChildren`/shader — not by manipulating the source texture. Source aspect ratio must not affect the circle's dimensions.
- **Badge visibility**: The badge `Node` (or `TextureRect`) must be shown/hidden based on whether the `CardData.badge` field is non-null/non-empty. Not having a badge is the normal case for most cards — hiding must produce no error.
- **Naming conventions (ADR-001)**: File is `card_visual.gd`; class is `CardVisual`. All variables snake_case; all constants SCREAMING_SNAKE_CASE.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: State-driven visual config (scale, shadow, z-order per Card Engine state)
- Story 003: Merge tween animation
- Story 004: Error handling and fallbacks for missing art / invalid card_id

---

## QA Test Cases

- **AC-1**: A card at rest displays `display_name` in the label region, circular cropped art in the center, and badge at bottom (if card has one in Card Database)
  - Given: A valid `card_id` exists in CardDatabase with `display_name = "Kopi Luwak"`, a valid `art_path`, and a non-null `badge` field
  - When: Card Spawning System acquires a card from the pool and sets the `card_id`
  - Then: The label node displays `"Kopi Luwak"`, the art `TextureRect` loads the texture from `art_path`, and the badge node is visible
  - Edge cases: `display_name` is an empty string (label shows empty string, no crash); `art_path` is valid but image is non-square (circle mask still produces circular result)

- **AC-2**: A card with no `badge` field renders correctly with no badge region visible
  - Given: A valid `card_id` exists in CardDatabase with `display_name = "First Morning"`, a valid `art_path`, and no `badge` field (null or absent)
  - When: Card Spawning System acquires the card and CardVisual reads CardDatabase in its initialisation
  - Then: The badge node is hidden (`visible = false`); label and art render correctly; no error is logged
  - Edge cases: Pool-recycled card previously showed a badge — after reset with a no-badge card_id, the badge node must be hidden

- **AC-3**: Art image is visually circular regardless of source image aspect ratio
  - Given: A card whose `art_path` points to a landscape (e.g. 512×256) image
  - When: The card renders on screen
  - Then: The art region displays as a circle clipped to center; no letterboxing or stretching is visible; label and badge regions are unaffected
  - Edge cases: Portrait image (256×512); square image (256×256); all must produce the same circular clip

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/card-visual/card_spawn_data_read_test.gd`
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None
- Unlocks: Story 002 (State-driven visual config) must wait for this story to be DONE
