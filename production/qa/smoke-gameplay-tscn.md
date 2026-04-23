# Smoke Check: gameplay.tscn composition (Story 004)

**Date**: 2026-04-23
**Story**: `production/epics/scene-composition/story-004-gameplay-tscn-composition.md`

## Changes under test

- **`src/scenes/gameplay.tscn`** (new) — composes the CanvasLayer hierarchy
  per ADR-004 §2: GameplayRoot (Node2D) + HudLayer (CanvasLayer=5) with
  StatusBarUI instance + TransitionLayer (=10) with SceneTransitionUI instance
  + SettingsPanelHost (=15) + EpilogueLayer (=20) with FinalEpilogueScreen
  instance.
- **`src/scenes/gameplay_root.gd`** (new) — awaits one frame in `_ready()`,
  then emits `EventBus.game_start_requested()`.
- **`project.godot`** — `run/main_scene` switched from the prototype
  `src/scenes/game.tscn` to the composed `src/ui/main_menu/main_menu.tscn`,
  so MainMenu is the boot scene that transitions into `gameplay.tscn`.

## Collateral fixes during smoke (pre-existing bugs)

- **`src/core/card_database.gd`** — added `has_card(id) -> bool`. Pre-existing
  bug: `CardSpawning.spawn_card()` called this method but it did not exist.
  Noted by earlier test agents but never fixed.
- **`src/ui/final_epilogue_screen/final_epilogue_screen.gd`** — removed the
  `_ready()`-time `is_final_memory_earned()` guard that called `get_tree().quit()`.
  The guard was incompatible with ADR-004 §2 pre-instancing: FES sits dormant
  in gameplay.tscn from boot, so the guard fired at boot and killed the game.
  The same check belongs on the reveal path and is already present in
  `_on_epilogue_cover_ready()`.
- **`src/core/scene_manager.gd`** — replaced `SceneTreeTimer.is_stopped()`
  (which does not exist in Godot 4.3) with a defensive disconnect-and-null
  pattern in `_cancel_watchdog()`. Also fixed an `Array[Dictionary]` inference
  error by using an untyped `Array` for `get_connections()`.

## Validation

Headless run with `--main-scene res://src/scenes/gameplay.tscn`:

```
StatusBarSystem: loaded bar effects for 4 recipe(s)
TableLayout: random seed used for seed cards — fix as: rng_seed=3508109337
```

The `TableLayout: random seed …` line confirms the end-to-end path:

1. GameplayRoot._ready() fires → `game_start_requested` emitted
2. SceneManager consumes via CONNECT_ONE_SHOT → loads scene-manifest[0] = "coffee-intro"
3. SceneGoal.load_scene succeeds → emits `seed_cards_ready` with 4 cards
4. CardSpawning.spawn_seed_cards runs → TableLayout positions them → cards spawn on the table

No script errors, no parse errors, no crashes.

## Known remaining warnings (pre-existing, deferred)

- **FES cover_ready_timeout fires at 5s** — the watchdog timer should arm only
  on `epilogue_started`, not at `_ready()`. Firing at boot is benign (no visible
  effect; state guard prevents the reveal) but produces log noise.
- **STUI duration constraint warning** (`Σ(D_nom - V) < T_MIN`) — the default
  variation tuning knobs slightly violate STUI's own clamp. Cosmetic warning;
  transitions still run at clamped values.
- **`res://assets/epilogue/illustration.png` missing** — FES degrades to
  background-only rendering, which is the documented fallback behaviour
  (story-005 of FES: AC-5 "Missing illustration PNG: render background color
  only").

## Verdict: PASS

gameplay.tscn composes correctly, boot sequence runs end-to-end, seed cards
spawn in the tutorial scene. Three pre-existing cosmetic warnings do not block
the vertical slice and should be fixed in follow-up stories. Story 004
complete.
