# QA Evidence: Card Engine — Merge and Animate Template Animations

**Story**: `story-004-merge-animate-tween.md`
**Story Type**: Visual/Feel
**Epic**: Card Engine
**Tester**: <!-- fill in name -->
**Build**: <!-- fill in build hash or version -->

---

## Setup

1. Launch the project in the Godot 4.3 editor.
2. Open and run the development scene that includes `CardEngine`, `CardSpawningSystem`, `InputSystem`, and the `InteractionTemplateFramework` (ITF) autoloads.
3. Ensure at least two cards with a known **Merge** recipe are spawned on the table (e.g., the `morning-light` + `chester` pair if configured).
4. Connect a debug listener to `EventBus.merge_complete` before the test — use the Godot remote debugger or an inline `print` in a test scene script.
5. Set the `MERGE_DURATION_SEC` constant to `0.25` (default) for the primary run. Run a second pass with `0.55` (current implementation value) if the constant differs.

---

## Verify

### AC-1 — Merge animation plays correctly

1. Drag one Merge-recipe card onto its partner until the snap tween fires.
2. Observe the two source cards after `combination_succeeded` is received by `CardEngine`.

Expected observations:
- Both source cards begin moving toward their geometric midpoint simultaneously.
- Both cards scale down smoothly from `Vector2(1, 1)` toward `Vector2(0, 0)`.
- Both cards fade out (alpha 1.0 → 0.0) during the animation.
- No visible "pop" or instant position jump at the start of the animation.
- Animation completes within the configured `MERGE_DURATION_SEC` ± 0.05 s.

### AC-2 — merge_complete signal fires

1. Confirm the debug listener (connected in Setup step 4) receives a call.
2. Print and verify the three parameters: `instance_id_a`, `instance_id_b`, `midpoint: Vector2`.

Expected observations:
- Signal fires exactly once per merge.
- `midpoint` equals `(pos_a + pos_b) / 2.0` — verify by logging both card positions before the merge.
- Signal fires only after both card tweens have completed (not before).

### AC-3 — Tween cancelled on card_removing

1. Start a merge animation (trigger a Merge combination).
2. Immediately — before the animation completes — trigger a scene transition or call `EventBus.card_removing.emit(instance_id_a)` via the debugger.

Expected observations:
- The merge tween stops immediately; the card no longer animates.
- No `null` dereference or `Object was freed` errors appear in the Output panel.
- No "ghost" card continues shrinking or fading after `card_removing` fires.

---

## Pass Condition

| Check | Pass | Notes |
|---|---|---|
| Both source cards reach scale `(0, 0)` and alpha `0.0` | [ ] | |
| Animation duration within `MERGE_DURATION_SEC ± 0.05 s` | [ ] | |
| `merge_complete` signal fires exactly once with correct midpoint | [ ] | |
| No lingering ghost at merge site after animation | [ ] | |
| No console errors during normal merge | [ ] | |
| Tween stops cleanly on `card_removing` mid-animation | [ ] | |
| No console errors when `card_removing` fires mid-merge | [ ] | |

All seven checks must pass for this story to be marked Complete.

---

## Screenshots / Screen Recordings

<!-- Attach or link evidence files here. Minimum: one screenshot per AC. -->

- AC-1 screenshot: <!-- path or link -->
- AC-2 debugger output: <!-- path or link -->
- AC-3 console output (no errors): <!-- path or link -->

---

## Sign-off

**Lead sign-off**: <!-- name + date -->
**Notes**: <!-- any conditional passes, known quirks, or follow-up items -->

---

## Date

**Evidence recorded**: <!-- YYYY-MM-DD -->
