# Story 004: Visual layout and no-DynamicFont rule

> **Epic**: Main Menu
> **Status**: Complete
> **Layer**: Presentation
> **Type**: UI
> **Manifest Version**: 2026-04-21

## Context

**GDD**: `design/gdd/main-menu.md`
**Requirement**: `TR-main-menu-012`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-001: Naming Conventions
**ADR Decision Summary**: ADR-001 mandates snake_case for all `.gd` and `.tscn` file names and PascalCase for class/node names — `main_menu.tscn`, `main_menu.tres` (Theme), `MainMenu`. Visual values (modulate colors, spacing) live in the Theme resource (`res://assets/themes/main_menu.tres`), not hardcoded in `main_menu.gd`, consistent with the GDD Tuning Knobs principle that authored knobs are owned by asset files rather than code.

**Engine**: Godot 4.3 | **Risk**: LOW
**Engine Notes**: `TextureButton` `modulate` property is stable in 4.3 and applies a color multiply over the base texture at render time — the base PNG color is multiplied component-wise by the `modulate` value. `stretch_mode = KEEP_ASPECT_CENTERED` on `TextureRect` is stable. `VBoxContainer` separation is set via the Theme `VBoxContainer/constants/separation` override or directly via `add_theme_constant_override("separation", 48)`. Overriding Godot's default focus rectangle to transparent is done via the Theme's `TextureButton/styles/focus` StyleBox set to an empty `StyleBoxEmpty`. `CanvasItem.modulate` is a `Color` and can be set directly in the inspector or via Theme override for button states in a `Theme` resource.

**Control Manifest Rules (Presentation Layer)**:
- Required: `gameplay_root.gd` owns boot orchestration: load_from_disk → apply_loaded_state → emit game_start_requested
- Required: All autoloads set process_mode = PROCESS_MODE_ALWAYS
- Required: EventBus declared signals before implementing emitter
- Forbidden: Never use direct node references for inter-system communication
- Forbidden: Never call change_scene_to_file during epilogue handoff

---

## Acceptance Criteria

*From GDD `design/gdd/main-menu.md`, scoped to this story:*

- [ ] **AC-VIS-1** — GIVEN Main Menu is rendered at 1920×1080, WHEN inspected against the palette, THEN background is `#F5EFE4` (or the fallback `#F2EBD9`), default button ink (from the PNG) is `#5C4A3E`, and hover/focus effective color is `#2B2420`. [launch]
- [ ] **AC-VIS-2** — GIVEN `%StartButton` is displayed, WHEN the mouse hovers over it, THEN only the modulate color deepens — no scale change, no background fill, no underline. [launch]
- [ ] **AC-VIS-3** — GIVEN `%StartButton` is keyboard-focused, WHEN rendered, THEN no blue focus rectangle is drawn (the Theme overrides Godot's default); focus is communicated by the same color deepening as hover. [launch]
- [ ] **AC-VIS-4** — GIVEN the VBoxContainer is rendered, WHEN measured, THEN the gap between Title and Start is 48 px (Theme value). [launch]
- [ ] **AC-ASSET-1** — GIVEN `res://assets/themes/main_menu.tres` is missing, WHEN Main Menu loads, THEN the button still renders (using its base PNG without modulate state variation) and Start remains functional (click/Enter/Space still activate it). [launch]
- [ ] **AC-ASSET-2** — GIVEN `res://assets/ui/ui_button_start_hand.png` is missing, WHEN Main Menu loads, THEN the TextureButton renders empty but the button still activates Start when clicked, pressed with Enter, or pressed with Space. [launch]
- [ ] **AC-PLAT-2** — GIVEN the window is resized between 1280×720 and 1920×1080, WHEN Main Menu is rendered, THEN the title/button column stays visually centered, the title PNG retains its aspect ratio, and the hand-lettered Start PNG remains legible (strokes clearly readable, no aliasing breakdown). [launch]

---

## Implementation Notes

*Derived from governing ADR(s):*

**No DynamicFont rule** (TR-main-menu-012 / Pillar 4): Neither the title nor the Start button label uses a `Label` node, `DynamicFont`, or `FontFile` resource. Both are single-author PNGs loaded into `TextureRect` (title) and `TextureButton` (Start button). This decision is permanent for Main Menu per the GDD — any future UI elsewhere may use DynamicFont, but Main Menu explicitly does not. Verify at review by searching `main_menu.tscn` for any `Label`, `RichTextLabel`, `FontFile`, or `DynamicFont` node or resource reference.

**Background** (AC-VIS-1): Primary color `#F5EFE4`. Use a `ColorRect` (anchors = `PRESET_FULL_RECT`, `mouse_filter = IGNORE`) as the fallback if the paper-grain texture PNG is missing. If the grain texture is present, use a `TextureRect` at the same anchor with `stretch_mode = SCALE` or `TILE`. The fallback color `#F2EBD9` is acceptable when the texture is unavailable.

**State modulation via `modulate`** (AC-VIS-1, AC-VIS-2, AC-VIS-3): The TextureButton base PNG has ink color `#5C4A3E` baked in. Godot multiplies the node's `modulate` color against the rendered texture pixel-by-pixel. The Theme resource configures per-state modulate values:

| Button State | modulate applied | Effective color |
|---|---|---|
| Default (Normal) | `Color(1, 1, 1, 1)` | `#5C4A3E` (no change) |
| Hover | `~Color(0.75, 0.77, 0.81, 1)` | `#2B2420` (warm ink) |
| Focus | Same as Hover | `#2B2420` |
| Disabled | `~Color(2.0, 2.0, 2.1, 1)` | `#B8A99A` (washed warm gray) |

These values are authored in `res://assets/themes/main_menu.tres` — not hardcoded in `main_menu.gd`. Godot's `TextureButton` applies the Theme's Normal / Hover / Focus / Disabled stylebox modulate overrides automatically based on input state.

**No blue focus rectangle** (AC-VIS-3): Override `TextureButton/styles/focus` in the Theme with a `StyleBoxEmpty`. This suppresses Godot's default blue focus border. Focus state is communicated only by the modulate deepening (matching hover).

**Hover is color-only** (AC-VIS-2): The Theme must not include any scale transform, background fill, or underline for the hover state. Only the `modulate` changes. Verify by inspecting the TextureButton during a hover state in a debug launch — node scale and size must be identical to the default state.

**VBox separation** (AC-VIS-4): Set `VBoxContainer` separation to `48` pixels. Options:
- In the Theme resource: `VBoxContainer/constants/separation = 48`
- Or directly in the `.tscn` via `add_theme_constant_override("separation", 48)` in `_ready()` — acceptable but Theme is preferred to keep all visual values out of code per ADR-001 philosophy.

**KEEP_ASPECT_CENTERED** (AC-PLAT-2): Both `Title` (TextureRect) and `StartButton` (TextureButton) must use `stretch_mode = KEEP_ASPECT_CENTERED`. This prevents letterform distortion on any viewport size. Verify at 1280×720 that strokes remain clearly readable.

**Asset fallbacks** (AC-ASSET-1, AC-ASSET-2): Godot renders an empty `TextureButton` if `texture_normal` is null — the button's `pressed` signal still fires on click, Enter, or Space. The Theme being absent means no modulate state variation, but the button remains functional. These fallbacks are declared as acceptable for development builds; final builds must verify both PNGs are present (tracked in the Epic's Definition of Done pre-release checklist).

**Responsive layout** (AC-PLAT-2): `MainMenu` root `Control` anchors = `PRESET_FULL_RECT` scales to any viewport. `CenterContainer` with anchors = `PRESET_FULL_RECT` keeps the title/button column centered on window resize. No code-level resize handler is needed — `CenterContainer` re-layouts automatically.

**Asset paths** (reference):
- Background texture: `res://assets/ui/env_bg_paper_grain_large.png` (optional; ColorRect fallback)
- Title PNG: `res://assets/ui/ui_title_moments_static_large.png`
- Start button PNG: `res://assets/ui/ui_button_start_hand.png`
- Theme resource: `res://assets/themes/main_menu.tres`

These assets are not yet commissioned at story write time (GDD OQ-4). Stories 001–003 can be implemented and tested without them (fallback behavior verified by AC-ASSET-1 and AC-ASSET-2). This story is blocked for final pass only — placeholder textures are acceptable during development.

---

## Out of Scope

- Story 001: Scene structure, node tree, `grab_focus`, no-coupling rule.
- Story 002: Start activation logic, `change_scene_to_file`, Scene Manager Waiting state.
- Story 003: Esc quit, error recovery, focus re-acquisition on keyboard events.
- Full Vision: gear icon (Settings trigger) in the top-right corner — explicitly excluded at Vertical Slice per GDD Core Rule 2.

---

## QA Test Cases

*UI — manual (evidence: `production/qa/evidence/main-menu-visual-layout-evidence.md`):*

- **AC-VIS-1**: Background and button color palette
  - Setup: Launch game at 1920×1080; open a color-picker tool (OS screenshot + picker, or browser DevTools)
  - Verify: Sample the background color — should read `#F5EFE4` (±2 per channel acceptable for paper grain texture). Sample the Start button in its default state — effective color should read approximately `#5C4A3E`. Move mouse over button — effective color should read approximately `#2B2420`
  - Pass condition: All three sampled colors fall within ±5 of their target hex values; no unexpected colors visible (no blue rectangles, no pure-white backgrounds)

- **AC-VIS-2**: Hover is color-only — no scale, no fill, no underline
  - Setup: Launch game; hover mouse over Start button
  - Verify: Observe the button at rest and during hover. The button's visual bounds (bounding box) must not change. No background rectangle appears behind the button. No underline or border appears. Only the ink color deepens
  - Pass condition: Button bounding box is pixel-identical at rest and on hover. Only modulate color differs

- **AC-VIS-3**: Keyboard focus — no blue rectangle; color deepens same as hover
  - Setup: Launch game; press Tab or navigate to ensure Start button is keyboard-focused (or press Enter once to confirm focus, then observe before pressing Enter again)
  - Verify: No blue or colored rectangle is drawn around the button. The button's color appearance matches the hover state
  - Pass condition: No focus border visible. Color deepening matches hover state exactly

- **AC-VIS-4**: Title → Start gap = 48 px
  - Setup: Launch game; use Godot's remote scene inspector (Debug → Remote Scene Inspector) to select the VBoxContainer
  - Verify: `separation` constant is `48` in the Theme override or node properties
  - Pass condition: Inspector shows `48` for `separation`. Visually, the gap between Title bottom edge and Start button top edge is approximately 48 px (cross-check by counting pixels in a screenshot at 1:1 zoom)

- **AC-ASSET-1**: Missing Theme — button renders and activates
  - Setup: Temporarily rename or remove `res://assets/themes/main_menu.tres`; launch game
  - Verify: Main Menu renders with its background and both PNG widgets. Start button is clickable. Click Start — scene switch proceeds
  - Pass condition: No crash, no error dialog, Start activates normally. Restore Theme file after test

- **AC-ASSET-2**: Missing Start PNG — button renders empty but activates
  - Setup: Temporarily rename or remove `res://assets/ui/ui_button_start_hand.png`; launch game
  - Verify: TextureButton renders as an empty/invisible area in the VBoxContainer. Clicking in that area (or pressing Enter with focus) still activates Start
  - Pass condition: No crash, button activates, scene switch proceeds. Restore PNG after test

- **AC-PLAT-2**: Layout integrity at 1280×720 and 1920×1080
  - Setup: Launch game at 1920×1080; verify title/button column is centered. Resize window to 1280×720 (or set `display/window/size/viewport_width = 1280` and `viewport_height = 720` in project settings for testing)
  - Verify: At both resolutions, the title/button column remains horizontally centered. Title PNG letterforms are not distorted (aspect ratio preserved). Start button PNG strokes are clearly readable (no aliasing breakdown, no pixelation that obscures letterforms)
  - Pass condition: No visible distortion or off-center column at either tested resolution

---

## Test Evidence

**Story Type**: UI
**Required evidence**: `production/qa/evidence/main-menu-visual-layout-evidence.md` — manual walkthrough document with screenshots at 1920×1080 and 1280×720, color-picker readings for all three palette roles, and sign-off note.
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (node tree must exist for Theme to be applied; scene structure is the canvas for visual values), Story 002 and Story 003 (button activation and error states must work before the disabled modulate color can be observed as intended)
- Unlocks: None (this is the final story in the Main Menu epic)
