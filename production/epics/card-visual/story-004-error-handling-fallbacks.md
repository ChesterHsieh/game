# Story 004: Error handling and fallbacks

> **Epic**: Card Visual
> **Status**: Complete
> **Layer**: Presentation
> **Type**: Logic
> **Manifest Version**: 2026-04-21

## Context

**GDD**: `design/gdd/card-visual.md`
**Requirement**: `TR-card-visual-007`, `TR-card-visual-008`, `TR-card-visual-009`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-001: Naming Conventions, ADR-002: Card Object Pooling
**ADR Decision Summary**: All variable and file names follow snake_case; class names PascalCase — consistent naming is required for the fallback nodes and warning/error log messages (ADR-001). Card scenes are pooled — fallback state must be reset correctly on pool return so the next card acquire starts clean (ADR-002).

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

- [ ] A card with a missing art asset renders a fallback placeholder without crashing
- [ ] A card with an invalid `card_id` renders a full placeholder (label = "?", fallback circle) and logs an error
- [ ] Long `display_name` is clipped within the label region and does not overflow into the art area

---

## Implementation Notes

*Derived from governing ADR(s):*

- **Missing art asset (GDD Edge Cases)**: When `art_path` points to a nonexistent file, CardVisual must not crash. It must render a fallback circular placeholder (solid color or a "?" symbol) in place of the art `TextureRect`. It must log a warning via `push_warning()` that includes the `card_id` so content issues are traceable. The label and badge regions render normally using whatever data CardDatabase returned.
- **Invalid card_id (GDD Edge Cases)**: When `CardDatabase.get_card(card_id)` returns null (or an invalid typed cast per the Foundation Layer rule — typed cast + null check is mandatory), CardVisual must render a full placeholder: label text = `"?"`, art region shows the fallback circle, badge is hidden. It must log a clear error via `push_error()` that names the `card_id`. No crash.
- **Typed cast + null check (Control Manifest, Foundation Layer)**: The mandatory rule is `ResourceLoader.load()` (and by extension `CardDatabase.get_card()`) paired with `as <Type>` cast + null check. A bare null check on a generic Resource is insufficient — a schema-drifted `.tres` can pass a bare null check and silently produce wrong data. The invalid `card_id` path must handle the typed-cast-returning-null case.
- **Long display_name (GDD Edge Cases)**: When `display_name` exceeds the label area, CardVisual must clip or truncate the text to fit within the label region. It must not overflow into the art area. Use Godot's built-in `Label` clipping (`clip_contents = true` on the parent container, or `Label.text_overrun_behavior`) rather than manual string truncation. A content warning must be logged via `push_warning()` naming the `card_id` when truncation occurs.
- **Pool reset (ADR-002)**: If a card was rendered in fallback state (missing art or invalid card_id), the pool reset method must clear the fallback state — restore the art `TextureRect` to its normal (empty/ready) state, restore the label to empty, show/hide the badge node correctly — before the next acquire configures it with a valid `card_id`.
- **Fallback design**: The fallback circular placeholder must be defined as a named constant or a `@export` variable (e.g., `fallback_color: Color`) so it can be changed without modifying logic. The "?" string for invalid card_id label is a GDD-specified value and may be a constant (`INVALID_CARD_LABEL: String = "?"`).
- **Naming conventions (ADR-001)**: Log messages must name the `card_id` (snake_case variable) consistently. Fallback constants in SCREAMING_SNAKE_CASE.
- **Unknown state enum fallback (GDD Edge Cases)**: If CardEngine provides an unrecognised state enum value, apply the `Idle` visual config and log a warning. This is adjacent to this story's scope — implement here since it is a defensive fallback, not a state-config feature.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: Normal CardDatabase read and art rendering for valid cards
- Story 002: State-driven visual config (scale, shadow, z-order)
- Story 003: Merge tween animation

---

## QA Test Cases

- **AC-1**: A card with a missing art asset renders a fallback placeholder without crashing
  - Given: A `card_id` exists in CardDatabase with a valid `display_name` but an `art_path` that points to a nonexistent file (e.g., `"res://assets/cards/does_not_exist.png"`)
  - When: Card Spawning System acquires a card and sets that `card_id`; CardVisual initialises
  - Then: The card renders with its label displaying the correct `display_name`; the art region shows a fallback circular placeholder (solid color or "?"); no exception or crash occurs; `push_warning()` is called with a message containing the `card_id`
  - Edge cases: Pool-recycled card previously had valid art — after reset with a missing-art card_id, fallback placeholder must appear (no stale texture from previous use)

- **AC-2**: A card with an invalid `card_id` renders a full placeholder (label = "?", fallback circle) and logs an error
  - Given: A `card_id` string that does not exist in CardDatabase (e.g., `"NONEXISTENT_CARD"`)
  - When: Card Spawning System acquires a card and sets that `card_id`; CardVisual calls `CardDatabase.get_card("NONEXISTENT_CARD")` and receives null (or typed cast returns null)
  - Then: The label node displays the text `"?"`; the art region shows the fallback circular placeholder; the badge node is hidden; `push_error()` is called with a message containing `"NONEXISTENT_CARD"`; no crash occurs
  - Edge cases: Empty string `card_id` (`""`); card_id that was valid on a previous pool use but is now invalid — both must produce the same full-placeholder result

- **AC-3**: Long `display_name` is clipped within the label region and does not overflow into the art area
  - Given: A `card_id` in CardDatabase with `display_name` set to a string longer than the label region can display (e.g., 60+ characters)
  - When: The card renders on screen
  - Then: The rendered label text is visually clipped or truncated to fit within the label region; no text extends into the circular art area; no text extends beyond the card frame; `push_warning()` is called with a message containing the `card_id`
  - Edge cases: A `display_name` that is exactly at the clip boundary (last character clips vs. does not clip); a `display_name` that is one character over the limit

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/card-visual/card_visual_fallbacks_test.gd`
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 003 (Merge tween animation) must be DONE
- Unlocks: None
