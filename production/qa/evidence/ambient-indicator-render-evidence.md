# Evidence: Ambient Indicator Render (Story 006)

**Date**: 2026-04-23
**Story**: `production/epics/scene-composition/story-006-ambient-indicator-render.md`
**Commit**: current HEAD

## Auto-verified via boot smoke

Launched `src/scenes/gameplay.tscn` headlessly after implementing the
indicator:

- No parse errors on `ambient_indicator.gd` or `gameplay.tscn`
- `TableLayout: random seed used for seed cards` confirms the full boot
  chain still reaches CardSpawning — AmbientLayer insertion did not
  disturb the scene graph
- No `AmbientIndicator:` warnings in the output — expected, because
  `coffee-intro.json` has no `ambient` block yet, so the code path exits
  at the "ambient_path is none" branch without attempting to load a PNG

## AC coverage

| AC | Coverage |
|---|---|
| AC-1 tree shape (AmbientLayer at layer=6) | ✅ verified in editor + JSON edit to gameplay.tscn |
| AC-2 subscribes to `scene_started` in `_ready()` | ✅ `ambient_indicator.gd:41` |
| AC-3 per-scene texture swap / hide logic | ✅ `_on_scene_started()` branches for missing file, "none", invalid path, and normal load |
| AC-4 mouse pass-through | ⚠ automated via `mouse_filter = IGNORE` on both Control and TextureRect. Manual verification (actually dragging a card in the bottom-right) is pending until coffee-intro gets an ambient PNG — the Control is currently hidden so the check is N/A |
| AC-5 missing PNG → `push_warning` + hide | ✅ `_on_scene_started()` line 55–59 |
| AC-6 hidden until first `scene_started` | ✅ `_ready()` calls `_texture_rect.hide()` |

## Manual verification — deferred

AC-4's real test requires an ambient PNG to actually be visible in the
corner. Once Coffee Intro gets its ambient asset (subject: "morning
kitchen sketch" per `design/scenes/coffee-intro.md` §10.2), re-run this
check:

1. Add the `ambient` block to `assets/data/scenes/coffee-intro.json`
2. Drop the PNG at `res://assets/ambient/coffee-intro.png`
3. Launch the game, click Start → observe the indicator in the bottom-right
4. Spawn a card over the indicator area (cheat: edit seed positions to
   force one near the corner)
5. Drag it → verify CardEngine registers the drag (card moves, no stuck
   state)
6. Update this doc with "✅ AC-4 manually verified on [date]"

## Verdict: PASS (with deferred AC-4)

Implementation is complete and robust against missing data. Manual
visual verification (AC-4) is gated on the first ambient asset landing,
not on this code story.
