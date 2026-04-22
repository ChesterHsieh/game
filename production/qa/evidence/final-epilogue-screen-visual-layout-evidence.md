# QA Evidence: FinalEpilogueScreen Visual Layout — Story 005

> **Story**: Story 005 — Visual Layout and Error Fallbacks
> **Epic**: Final Epilogue Screen
> **Type**: UI (Advisory — manual walkthrough required)
> **Status**: Stub — pending manual verification
> **Evidence Required By**: AC-VISUAL-1, AC-VISUAL-2, AC-FAIL-2

---

## Scene Structure (as implemented)

File: `src/ui/final_epilogue_screen/final_epilogue_screen.tscn`

```
FinalEpilogueScreen (Control, anchors=FULL_RECT, mouse_filter=IGNORE)
├── Background (ColorRect, anchors=FULL_RECT, mouse_filter=IGNORE, color=warm dark)
├── IllustrationContainer (CenterContainer, anchors=FULL_RECT, mouse_filter=IGNORE)
│   └── Illustration (TextureRect, expand_mode=KEEP_ASPECT_CENTERED, mouse_filter=IGNORE)
├── CoverReadyTimeoutTimer (Timer, one_shot=true, wait_time=5.0)
└── BlackoutTimer (Timer, one_shot=true, wait_time=1.5)
```

- All Control nodes have `mouse_filter = MOUSE_FILTER_IGNORE` so clicks propagate to `_unhandled_input` (GDD Core Rule 3)
- No `Label`, `Button`, `RichTextLabel`, or any text node is present — enforces the no-UI-chrome rule
- `TextureRect.expand_mode = EXPAND_KEEP_ASPECT_CENTERED` — scales illustration up or down while preserving aspect ratio

---

## AC-VISUAL-1: Illustration centered at all supported resolutions

**Procedure**:
1. Open `gameplay.tscn` (or the FES scene directly) in the Godot editor
2. Override window size to each resolution: 1024×768, 1920×1080, 3840×2160
3. Force-call `_on_epilogue_cover_ready()` in the editor (or emit `EventBus.epilogue_cover_ready` from a test script)
4. Wait for `modulate.a = 1.0`
5. Take a screenshot at each resolution
6. Measure the illustration bounding box center vs. viewport center

**Pass criteria**:
- Illustration bounding box center within ±2 pixels of viewport center horizontally and vertically
- No clipping at any edge
- Illustration aspect ratio delta < 0.5% from source PNG aspect ratio
- Margins present on all sides (illustration fills ~80% of the shorter viewport dimension)

| Resolution  | Screenshot | Center X delta | Center Y delta | Clipping | Aspect OK | PASS/FAIL |
|-------------|------------|---------------|---------------|----------|-----------|-----------|
| 1024×768    | [ ]        | —             | —             | —        | —         | PENDING   |
| 1920×1080   | [ ]        | —             | —             | —        | —         | PENDING   |
| 3840×2160   | [ ]        | —             | —             | —        | —         | PENDING   |

**Screenshots location**: `production/qa/evidence/screenshots/fes-visual-layout-[resolution].png` (to be added)

---

## AC-VISUAL-2: No UI chrome at any state

**Procedure**:
1. Run game to epilogue or instantiate FES directly
2. Take screenshots at: Armed (alpha=0), t=FADE_IN_DURATION/2 (alpha≈0.75), t=FADE_IN_DURATION (alpha=1.0), Holding state
3. Inspect each screenshot for any non-illustration, non-background pixels

**Pass criteria**:
- Armed: no pixels above alpha=0 (black screen or transparent depending on parent)
- Revealing/Holding: only Background ColorRect pixels and Illustration TextureRect pixels visible
- Zero `Label`, `RichTextLabel`, `Button`, or any text pixels at any state
- No watermarks, no frame overlays, no progress indicators

| State    | Screenshot | Chrome pixels | PASS/FAIL |
|----------|------------|---------------|-----------|
| Armed    | [ ]        | —             | PENDING   |
| t=50%    | [ ]        | —             | PENDING   |
| t=100%   | [ ]        | —             | PENDING   |
| Holding  | [ ]        | —             | PENDING   |

---

## AC-FAIL-2: Missing PNG → background color only, no crash

**Procedure**:
1. Temporarily rename `res://assets/epilogue/illustration.png` to `illustration.png.bak`
2. Run the game or instantiate FES directly in the editor
3. Emit `EventBus.epilogue_cover_ready` or call `_on_epilogue_cover_ready()` directly
4. Observe: game must not crash; FES must reach `modulate.a = 1.0` showing background only
5. Check Output panel / stderr for the expected error log line
6. Restore the PNG file after testing

**Pass criteria**:
- No GDScript exception or crash
- `Input.mouse_mode == MOUSE_MODE_HIDDEN`
- Screen shows only the background `ColorRect` color — no error dialog, no placeholder text
- Stderr / Output contains the line:
  ```
  FES: illustration PNG failed to load from 'res://assets/epilogue/illustration.png' — rendering background color only
  ```

| Check                        | Result  |
|-----------------------------|---------|
| No crash                    | PENDING |
| Background color visible    | PENDING |
| Cursor hidden               | PENDING |
| Error logged to stderr      | PENDING |
| No error dialog shown       | PENDING |

---

## Notes

- **Illustration asset**: `res://assets/epilogue/illustration.png` does not exist yet (OQ-1 — content direction deferred). The PNG absence is the expected state for FES during development; AC-FAIL-2 is the nominal code path until the real asset is delivered.
- **Background color**: ColorRect color is set to `Color(0.118, 0.102, 0.090, 1.0)` (warm dark) in the scene. This is a placeholder — final color to be confirmed in the asset spec (GDD OQ-2).
- **Automated screenshot test (advisory)**: AC-VISUAL-1 could be automated with a known test PNG (e.g., solid red 512×512 square) and pixel-check bounding box centering. Not yet implemented — advisory for a future sprint.

---

*Evidence stub created: 2026-04-22. Pending manual walkthrough sign-off.*
