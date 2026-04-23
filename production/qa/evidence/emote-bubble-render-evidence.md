# Evidence: Emote Bubble Render (Story 007)

**Date**: 2026-04-23
**Story**: `production/epics/scene-composition/story-007-emote-bubble-render.md`
**Commit**: current HEAD

## Implementation summary

- `EventBus.emote_requested(emote_name, world_pos)` declared in
  `src/core/event_bus.gd` under the Combination section.
- `interaction_template_framework.gd::_on_merge_complete` emits
  `emote_requested(emote_name, midpoint)` before `_fire_executed` when
  `recipe.config.emote` is set and not `"none"`.
- `EmoteLayer` (CanvasLayer, layer=7) + `EmoteHandler` (Node2D) mounted
  in `src/scenes/gameplay.tscn` between HudLayer (5) and TransitionLayer
  (10).
- `EmoteBubble` scene + script at `src/ui/emote_bubble.{tscn,gd}` with a
  static `spawn()` factory; `EmoteHandler` is the sole subscriber.

## AC coverage

| AC | Coverage |
|---|---|
| AC-1 signal exists | ✅ auto — `emote_bubble_signal_test.gd::test_event_bus_emote_requested_signal_exists` |
| AC-2 ITF emits on config.emote | ⏳ manual (coffee-intro smoke below) — auto-testing ITF requires CardEngine + RecipeDatabase fixtures, out of scope for this story |
| AC-3 EmoteHandler spawns bubble | ✅ auto — `test_emote_handler_spawns_bubble_on_signal` |
| AC-4 bubble self-frees | ✅ auto — `test_emote_bubble_self_frees_after_animation` |
| AC-5 timing knobs | ✅ auto — `test_emote_bubble_timing_knobs_match_spec` |
| AC-6 missing PNG tolerated | ✅ auto — `test_emote_bubble_missing_png_self_frees_without_crash` |
| AC-7 multiple emotes coexist | ✅ auto — `test_emote_handler_supports_multiple_concurrent_bubbles` |
| AC-8 mouse pass-through | ✅ static — `TextureRect.mouse_filter = 2` (IGNORE) in `emote_bubble.tscn`; Node2D root has no input surface. Manual drag-through verification folded into AC-9. |
| AC-9 coffee-intro smoke | ⏳ manual — see checklist below |

## Manual smoke checklist (AC-2 + AC-9 + drag-through)

Run from the coffee-intro scene, once per verify:

1. Launch the game, click Start → land in Coffee Intro
2. Drag **beans** onto **grinder** → merge completes, `ground-coffee`
   card appears. **Expected**: `spark` bubble pops at the merge midpoint,
   grows past 1.0, holds ~1.2s, fades cleanly, leaves no node behind.
3. Drag **cup-of-coffee** onto **ju** → merge completes, delivery plays.
   **Expected**: `heart` bubble pops at the merge midpoint, same shape
   curve as above.
4. While a bubble is on screen, drag any card underneath it. **Expected**:
   CardEngine registers the drag — no stuck state, bubble does not block
   the drag.
5. (Optional negative test) Temporarily edit one recipe's `config.emote`
   to `"missing_emote_xyz"` and fire it. **Expected**: no crash, one
   `push_warning("EmoteBubble: missing ...")` line in the editor output,
   no visible bubble.

Record observations here after the next hands-on launch:

- Step 2 (spark on brew-coffee): [ ] verified — date: ____
- Step 3 (heart on deliver-coffee): [ ] verified — date: ____
- Step 4 (drag-through): [ ] verified — date: ____
- Step 5 (missing PNG): [ ] verified — date: ____

## Verdict: PASS (auto), manual smoke pending

Code + automated tests are complete and cover 7 of 9 ACs directly. The
two deferred ACs (AC-2 ITF emission, AC-9 coffee-intro visual smoke) are
best verified by hands-on play since they exercise the full merge
pipeline + visual feel. Flip the checklist above on next launch.
