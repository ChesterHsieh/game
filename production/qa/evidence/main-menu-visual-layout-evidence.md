# Main Menu — Visual Layout Evidence
## Story 004: Visual layout and no-DynamicFont rule

> **Story**: `production/epics/main-menu/story-004-visual-layout-no-dynamicfont.md`
> **Story Type**: UI (manual walkthrough)
> **Status**: Pending launch — assets not yet commissioned (GDD OQ-4)
> **Created**: 2026-04-22
> **Reviewer**: (Chester, on first playable build)

---

## Pre-Flight Checklist (complete before walkthrough)

- [ ] `res://assets/ui/ui_title_moments_static_large.png` present in project
- [ ] `res://assets/ui/ui_button_start_hand.png` present in project
- [ ] `res://assets/themes/main_menu.tres` present in project
- [ ] Game launched at 1920×1080 (check `display/window/size` in project.godot)
- [ ] Godot remote debugger connected for inspector checks

---

## AC-VIS-1: Background and button color palette

**Test steps:**
1. Launch game at 1920×1080.
2. Take a screenshot; open in a color-picker tool.
3. Sample the background (center of screen, away from widgets).
4. Sample the Start button in its default (no-hover) state.
5. Move mouse over button; sample again.

**Expected:**

| Sample point | Target hex | Acceptable tolerance |
|---|---|---|
| Background | `#F5EFE4` (or `#F2EBD9` if texture missing) | ±5 per channel |
| Button default | `#5C4A3E` (baked into PNG) | ±5 per channel |
| Button hover | `#2B2420` (modulate-deepened) | ±5 per channel |

**Result:** [ ] Pass / [ ] Fail

**Notes / screenshots:**

_(attach screenshot filenames or inline images here)_

---

## AC-VIS-2: Hover is color-only — no scale, fill, or underline

**Test steps:**
1. Launch game.
2. Observe Start button at rest; note bounding box position and size.
3. Hover mouse over Start button; observe same properties.

**Expected:**
- Bounding box is pixel-identical at rest and on hover.
- No background rectangle appears behind the button.
- No underline or border appears.
- Only ink color deepens (from `#5C4A3E` to `#2B2420`).

**Result:** [ ] Pass / [ ] Fail

**Notes:**

---

## AC-VIS-3: Keyboard focus — no blue rectangle; color deepens same as hover

**Test steps:**
1. Launch game; ensure Start button has focus (grab_focus() in _ready()).
2. Observe the button without pressing anything.
3. Optionally: press Tab to cycle away then Tab back to confirm focus ring behavior.

**Expected:**
- No blue or colored rectangle drawn around the button.
- Color appearance matches the hover state.

**Result:** [ ] Pass / [ ] Fail

**Notes:**

---

## AC-VIS-4: Title → Start gap = 48 px

**Test steps:**
1. Launch game.
2. Open Godot remote scene inspector (`Debug → Remote Scene Inspector`).
3. Select `CenterContainer/VBoxContainer`.
4. Check `separation` constant in Theme or node properties.

**Expected:**
- Inspector shows `separation = 48`.
- Visually, the gap between Title bottom edge and Start button top edge reads as approximately 48 px.

**Result:** [ ] Pass / [ ] Fail

**Notes:**

---

## AC-ASSET-1: Missing Theme — button renders and activates

**Test steps:**
1. Temporarily rename `res://assets/themes/main_menu.tres` (e.g. append `.bak`).
2. Launch game.
3. Verify Main Menu renders (no crash, no error dialog).
4. Click Start — scene switch should proceed normally.
5. Restore theme file after test.

**Expected:**
- Main Menu loads without crash.
- Button is visible (using base PNG, no modulate state variation).
- Clicking Start triggers `change_scene_to_file` normally.

**Result:** [ ] Pass / [ ] Fail

**Notes:**

---

## AC-ASSET-2: Missing Start PNG — button renders empty but activates

**Test steps:**
1. Temporarily rename `res://assets/ui/ui_button_start_hand.png` (e.g. append `.bak`).
2. Launch game.
3. Verify Main Menu renders without crash.
4. Click in the area where the button would be (or press Enter with focus).
5. Restore PNG after test.

**Expected:**
- TextureButton renders as empty area (no texture, but no crash).
- Clicking or pressing Enter in that area activates Start.

**Result:** [ ] Pass / [ ] Fail

**Notes:**

---

## AC-PLAT-2: Layout integrity at 1280×720 and 1920×1080

**Test steps:**
1. Launch at 1920×1080; observe title/button column centering.
2. Resize window to 1280×720 (or set viewport in project.godot for testing).
3. At both sizes, observe:
   - Column stays horizontally centered.
   - Title PNG aspect ratio is preserved (no squash/stretch).
   - Start button PNG strokes are clearly readable.

**Expected:**
- Title/button column centered at both resolutions.
- Title letterforms not distorted.
- Start button strokes clearly readable (no aliasing breakdown).

**Result at 1920×1080:** [ ] Pass / [ ] Fail
**Result at 1280×720:** [ ] Pass / [ ] Fail

**Notes / screenshots:**

---

## No-DynamicFont Rule Verification

**Inspection method:** Search `main_menu.tscn` and `main_menu.gd` for any of:
`Label`, `RichTextLabel`, `FontFile`, `DynamicFont`

```
grep -n "Label\|RichTextLabel\|FontFile\|DynamicFont" \
  src/ui/main_menu/main_menu.tscn \
  src/ui/main_menu/main_menu.gd
```

**Expected:** Zero matches in both files.

**Result:** [ ] Pass / [ ] Fail (zero matches)

---

## Sign-off

| Item | Status |
|---|---|
| All ACs passed | [ ] |
| Screenshots attached (VIS-1, PLAT-2) | [ ] |
| No-DynamicFont grep result: 0 matches | [ ] |

**Signed off by:** _______________  **Date:** _______________

> **Note**: This document is a stub for pre-asset development. Complete all
> sections after `ui_title_moments_static_large.png` and `ui_button_start_hand.png`
> are commissioned and in-tree (GDD OQ-4). The button and title PNG paths are
> already wired in `main_menu.tscn` — placeholder null textures will show empty
> nodes until art arrives.
