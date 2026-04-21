# Final Epilogue Screen

> **Status**: In Design
> **Author**: Chester + design-system skill
> **Last Updated**: 2026-04-20
> **Implements Pillar**: Pillar 1 (Recognition Over Reward) — primary; Pillar 4 (Personal Over Polished) — secondary

## Overview

The Final Epilogue Screen is a one-shot, full-screen illustrated reveal shown a single time when Ju has discovered every required memory in the game. It is the emotional terminus of the core loop — not a scene, not a recipe animation, but a dedicated screen whose entire job is to present one handcrafted picture that exists nowhere else in the game. Mechanically, it is a passive presentation layer that listens for `EventBus.final_memory_ready()` (emitted by Mystery Unlock Tree per ADR-003's signal bus pattern) and, on receipt, Scene Manager swaps the current scene to `final_epilogue.tscn`. The screen has no interactive goals, no bars, no hints — only the illustration, a dismiss input, and the quiet that earns the picture. Its existence is the reason the discovery loop is worth running: everything the player does in Moments is a slow walk toward this single moment of recognition, which is why Pillar 1 ("Recognition Over Reward") is load-bearing here rather than decorative.

## Player Fantasy

This is the last page of a book Ju didn't know was a book. For an hour — two hours, however long — she has been turning cards, watching memories surface, noticing which ones Chester took the time to draw. The Final Epilogue Screen is the moment the game puts down its mechanisms and hands her the one page she hasn't seen: a single illustration that exists nowhere else in Moments, addressed to her specifically, drawn knowing she would be the one to find it.

The intended feeling is recognition — not of the image (though she may recognize what's in it), but of the author behind it. The beat we're anchoring to is the quiet half-second where the cards fall away, one picture resolves, and Ju understands *this was always where I was headed. He drew this last page for me to find.* Not "I won." Not "good job." The fantasy is being witnessed: the feeling of opening something a specific person made for a specific person, and realizing you are that specific person.

Because Moments is N=1 by design, this screen is allowed to be illegible to anyone else. A reference only Ju would catch, an in-joke rendered in ink, a shared shorthand — the picture can do what a public ending cannot. The screen must protect that. No fanfare, no "Congratulations," no credits roll on top of the image. The room goes quiet. The picture holds. Ju closes it when she's ready.

**Reference feel**: the last page of a handmade zine; the moment at the end of a long letter where the writer signs their name; the sleeve photo in a mixtape someone made for you in high school. Not cinema, not credits, not victory.

**What this section is not serving**: spectacle, scoring, replayability, or any framing where the game evaluates Ju's performance. FES does not congratulate. FES acknowledges.

**Pillar alignment**:
- Pillar 1 (Recognition Over Reward) — *primary*; the entire design exists to deliver the recognition beat without slipping into reward framing
- Pillar 4 (Personal Over Polished) — *secondary*; polish would be a fanfare, which this screen explicitly refuses

## Detailed Design

### Core Rules

1. **FES is a scene, not an autoload.** It exists only as `res://scenes/final_epilogue.tscn` and is instantiated exactly once per save-lifetime by Scene Manager.

> **⚠️ Superseded by ADR-004 (2026-04-21).** FES is now pre-instanced as a sibling CanvasLayer (layer 20) inside `gameplay.tscn`. Rules 2 and 13 below, plus the "Armed/Loading" transitions in the state table, describe an earlier scene-swap model that is no longer the chosen approach. The authoritative flow is in `docs/architecture/ADR-004-runtime-scene-composition.md` §4: FES is pre-instanced in `Armed` state; it connects to `EventBus.epilogue_cover_ready` directly; STUI (same scene, still alive) emits that signal after its amber cover reaches full opacity; FES then fades its texture in above STUI. No `change_scene_to_file` is invoked. Treat the scene-swap language throughout this GDD as historical — all ACs and edge cases that assume a scene swap should be read through the lens of "state transition within the same tree" instead.

2. **FES subscribes to `EventBus.epilogue_cover_ready` directly** (superseding the Scene-Manager-mediated scene swap). FES is pre-instanced at game launch per ADR-004 §2 as a child of `gameplay.tscn` → `EpilogueLayer (CanvasLayer, layer = 20)`. In its `_ready()`, FES connects to `EventBus.epilogue_cover_ready` with `CONNECT_ONE_SHOT`. On receipt (emitted by STUI when its amber overlay reaches full opacity), FES transitions `Armed → Loading` and preloads the illustrated memory texture. The `final_memory_ready` signal from MUT is used by `gameplay_root.gd` to trigger `SaveSystem.save_now()` (ADR-004 §6); it is not FES's reveal gate.

3. **FES uses `Control` with `PRESET_FULL_RECT` as its scene root.** Not `CanvasLayer`, not `Node2D`. All presentational Control nodes set `mouse_filter = MOUSE_FILTER_IGNORE` so clicks propagate to `_unhandled_input`.

4. **Illustration preload uses `epilogue_conditions_met`.** A dedicated preloader (owned by `gameplay_root.gd` per ADR-004 §2, or equivalently by Scene Manager's preloader subsystem) subscribes to `EventBus.epilogue_conditions_met` and calls `ResourceLoader.load_threaded_request("res://assets/epilogue/illustration.png")` at that moment. By the time `epilogue_cover_ready` fires, the texture is resident in memory — no hitch at the emotional beat.

5. **FES `_ready()` sequence:**
   - Query `MysteryUnlockTree.is_final_memory_earned()`. If `false`: log error, call `get_tree().quit()` (the screen should not exist in this state).
   - Set root `modulate = Color(1.0, 1.0, 1.0, 0.0)` **before** creating any Tween (prevents one-frame flash).
   - Connect to `EventBus.epilogue_cover_ready` with `CONNECT_ONE_SHOT`.

6. **FES reveals on `epilogue_cover_ready`, not on `final_memory_ready`.** Scene Transition UI emits `epilogue_cover_ready` after its amber overlay reaches full opacity (per STUI GDD). This is the architecturally correct reveal gate — the table has cleared, the final recipe's animation has completed under the amber rise, and the canvas is clean. FES's `_on_epilogue_cover_ready` begins the Tween: `modulate:a` 0 → 1 over `FADE_IN_DURATION` (default 2000ms).

7. **Input is blackout-gated.** After the fade-in Tween finishes, a 1500ms `Timer` (`INPUT_BLACKOUT_DURATION`) starts. Until the Timer times out, `_unhandled_input` returns immediately without processing. This prevents accidental dismissal during the reveal landing.

8. **Input acceptance filter** (post-blackout):
   ```gdscript
   func _unhandled_input(event: InputEvent) -> void:
       if not _input_armed: return
       if event is InputEventMouseMotion: return
       if event is InputEventMouseButton and not event.pressed: return
       if event is InputEventKey:
           if not event.pressed or event.echo: return
           if event.keycode == KEY_ESCAPE: return  # Esc is explicitly ignored on FES
       _on_dismiss()
   ```

9. **Dismiss quits the application.** `_on_dismiss` calls `get_tree().quit()`. No scene swap. No return to Main Menu. No scene-tree teardown visible to the user. The game window closes.

10. **If no input is received, the image holds indefinitely.** FES has no timeout, no auto-dismiss. "The picture holds. Ju closes it when she's ready" is literally implemented — she can close the window via OS controls (Cmd+Q / Alt+F4 / window X), or she can press any key/click and the game will quit for her.

11. **Mouse cursor is hidden on reveal.** `Input.mouse_mode = Input.MOUSE_MODE_HIDDEN` is set at the start of the fade-in Tween. Books do not have cursors on them.

12. **Signal declarations required in EventBus before ship:**
    - `signal final_memory_ready()` — emitted by MUT
    - `signal epilogue_conditions_met()` — emitted by MUT (MVP may defer until preloader is built)
    - `signal epilogue_cover_ready()` — emitted by Scene Transition UI

13. **One-shot enforcement delegates to MUT** (per ADR-004 model; Scene Manager's `_enter_tree` guard is no longer required). MUT owns `_final_memory_earned: bool` (already designed, already included in MUT's `get_save_state()` / `load_save_state()`). On session resume, if MUT's restored state already has `_final_memory_earned == true` AND `resume_index == manifest.size()`, SM enters Epilogue immediately on `game_start_requested` per SM Core Rule 9. STUI emits `epilogue_cover_ready` in response to `epilogue_started`, and FES (pre-instanced with `CONNECT_ONE_SHOT` on `epilogue_cover_ready`) reveals cleanly on first receipt. The one-shot is enforced by the `CONNECT_ONE_SHOT` on FES's `epilogue_cover_ready` subscription, not by an `_enter_tree` guard elsewhere. **FES does not own any persistent state.**

### States and Transitions

| State | Description | Enters on | Exits on |
|-------|-------------|-----------|----------|
| Dormant | FES scene not loaded; texture not in memory | Session start (default) | `epilogue_conditions_met` → Preloading |
| Preloading | `ResourceLoader.load_threaded_request` in flight for illustration PNG | Preloader receives `epilogue_conditions_met` | PNG load complete → Armed |
| Armed | FES pre-instanced in `gameplay.tscn` at layer 20 (ADR-004 §2); modulate alpha = 0; rendering nothing; subscribed to `epilogue_cover_ready` via `CONNECT_ONE_SHOT` | Pre-instancing complete at gameplay scene load | `epilogue_cover_ready` received → Loading |
| Loading | Preloading the illustrated memory texture; no scene swap, just a `load()` call on FES's own TextureRect | Synchronous preload completes | Preload returns → Ready |
| Ready | FES `_ready()` has run; modulate alpha = 0; awaiting STUI cover-ready | Scene instantiation | `epilogue_cover_ready` → Revealing |
| Revealing | Fade-in Tween running (alpha 0 → 1); input blocked | Cover-ready received | Tween completes → Blackout |
| Blackout | Image fully visible; input blackout timer running (1500ms); input blocked | Fade-in complete | Blackout timer timeout → Holding |
| Holding | Image visible; input accepted (any key/click except Esc, motion, and release) | Blackout timeout | Accepted input → Quitting |
| Quitting | `get_tree().quit()` called; Godot tears down | Dismiss input | App exit |

Illegal transitions: No state transitions backward. FES has no retry, no pause, no sub-modes. `Holding → Holding` is the stable-loop state if no input arrives.

### Interactions with Other Systems

**Mystery Unlock Tree (upstream)**
- FES depends on MUT's `_final_memory_earned` flag as the session-scope one-shot guard.
- FES depends on MUT emitting `final_memory_ready()` via EventBus exactly once per session.
- FES depends on MUT emitting `epilogue_conditions_met()` as the preload hook (resolves MUT OQ-11 — Scene Manager's preloader is the named consumer).
- FES does not call MUT directly except `is_final_memory_earned()` in `_ready()` (defensive guard — should always be `true` at this point).

**Scene Manager (peer/upstream)**
- Scene Manager no longer listens to `final_memory_ready` (per ADR-004). It emits `epilogue_started` when entering the Epilogue state; STUI listens and drives the amber cover; FES listens to STUI's `epilogue_cover_ready` directly.
- Scene Manager owns the illustration preloader (consumer of `epilogue_conditions_met`).
- Scene Manager does not receive any signal back from FES. FES terminates the application; no handoff.

**Scene Transition UI (peer/upstream)**
- FES waits for `epilogue_cover_ready()` before beginning its fade-in. STUI's amber overlay covers the transition from gameplay; FES reveals under a clean canvas.

**EventBus (infrastructure)**
- Requires three signal declarations: `final_memory_ready()`, `epilogue_conditions_met()`, `epilogue_cover_ready()`.
- Companion edit: this is additional debt on top of the Main Menu GDD's existing `game_start_requested` declaration. All four signals should be added to EventBus in a single bundled edit.

**Save/Progress System (`design/gdd/save-progress-system.md` — Designed 2026-04-21)**
- Save/Progress persists MUT's `_epilogue_conditions_emitted` flag via MUT's `get_save_state()` / `load_save_state()` API.
- Save/Progress triggers `save_now()` on `final_memory_ready` (per ADR-004 §6), so MUT's Epilogue-state flags are captured even though no `scene_completed` fires during Epilogue.
- On relaunch after completion, MUT restores the flags, and SM reads `resume_index == manifest.size()` → enters Epilogue directly per SM Core Rule 9. FES is pre-instanced (ADR-004 §2) and receives `epilogue_started` on re-launch, triggering a fresh reveal.
- FES itself writes no save state — it is a pure consumer.

**Audio Manager (downstream)**
- FES does not play music or SFX during the reveal. On reveal entry, FES calls `AudioManager.fade_out_all(duration)` with `duration = FADE_IN_DURATION` so the existing ambient bed decays as the image rises. After fade-out, audio is silent — "the room goes quiet" is enforced, not implicit. `fade_out_all(duration: float)` is specified in `design/gdd/audio-manager.md` Interactions + AC-AM-17 (added 2026-04-21).

## Formulas

FES has no gameplay math. Three time-based behaviors are parameterized.

### F-1: Fade-in alpha over time (quadratic ease-out)

```
alpha(t) = 1.0 - (1.0 - t / FADE_IN_DURATION)^2        for 0 ≤ t ≤ FADE_IN_DURATION
```

Variables:
- `t` — elapsed time since `epilogue_cover_ready` received (ms)
- `FADE_IN_DURATION` — fade-in window in ms; default **2000**, tunable

Output range: `alpha` ∈ [0.0, 1.0]. At `t = 0`, `alpha = 0`. At `t = FADE_IN_DURATION`, `alpha = 1`. Curve decelerates — ~75% of total opacity is reached by 50% of elapsed time.

Example values (at default 2000ms):

| t (ms) | alpha |
|--------|-------|
| 0      | 0.000 |
| 500    | 0.438 |
| 1000   | 0.750 |
| 1500   | 0.938 |
| 2000   | 1.000 |

Godot 4.3 implementation:
```gdscript
var tween: Tween = create_tween()
tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
tween.tween_property(self, "modulate:a", 1.0, FADE_IN_DURATION / 1000.0)
```

### F-2: Input blackout gate

```
_input_armed = (t_since_fade_complete ≥ INPUT_BLACKOUT_DURATION)
```

Variables:
- `t_since_fade_complete` — elapsed time since the fade-in Tween's `finished` signal (ms)
- `INPUT_BLACKOUT_DURATION` — blackout window in ms; default **1500**, tunable

No easing — strict boolean gate. Before threshold, `_unhandled_input` early-returns. At or after threshold, input is evaluated against the filter in Core Rule 8.

### F-3: Total time-to-interactive

```
T_interactive = FADE_IN_DURATION + INPUT_BLACKOUT_DURATION
              = 2000 + 1500
              = 3500 ms
```

The image is fully visible at 2000ms post-`cover_ready`. Input is accepted no earlier than 3500ms post-`cover_ready`. Combined with Scene Transition UI's amber rise (upstream of `cover_ready`), the protected window from the final recipe firing to input-accepted is ~5–6 seconds. Rationale: Ju must have time to register what she is looking at before any input counts.

## Edge Cases

**EC-1: `final_memory_ready()` fires but `final_epilogue.tscn` fails to load.**
`change_scene_to_file` returns `OK` for queued swaps; asynchronous load errors surface later as a parse error or missing resource. Handled by: Scene Manager watches for scene-load completion (per Scene Manager OQ-2 watchdog); on failure, logs to stderr and calls `get_tree().quit()` to prevent a stuck state. MVP acceptable — the failure is a build error Chester will catch on first run.

**EC-2: Ju quits the app during the reveal (crash, Alt+F4, power loss).**
No save write occurs during FES. MUT's `_final_memory_earned` is set on `final_memory_ready` emission — *before* FES instantiation. Handled by: if Save/Progress System is present (Alpha+), the flag is already persisted; re-launch loads save state, `MUT.is_final_memory_earned()` returns `true`, Scene Manager skips the subscription, and nothing triggers. Pre-Alpha: session-only, so closing reverts to scene 0 on next launch — she can replay and re-earn. Documented as intentional per Core Rule 13.

**EC-3: Preload fails (PNG missing, decode error, disk read error).**
`ResourceLoader.load_threaded_request` can fail. Handled by: Scene Manager's preloader checks `ResourceLoader.load_threaded_get_status` before FES instantiation. If preload fails, FES still loads but displays a fallback state (solid-color background, no illustration). Worst-case; Chester should never ship with a missing asset. Logged to stderr.

**EC-4: `epilogue_cover_ready` never fires (Scene Transition UI bug or missing).**
FES would sit at alpha = 0 forever — black screen, no reveal. Handled by: FES starts a fallback safety timer of 5000ms at `_ready()`. If `epilogue_cover_ready` has not fired by then, FES begins fade-in anyway. This masks a STUI bug but prevents a hung game at the most important moment. Logged: `FES: epilogue_cover_ready not received within 5000ms; beginning fade-in without STUI handoff`.

**EC-5: Ju's mouse moves during the reveal.**
`InputEventMouseMotion` is explicitly filtered in Core Rule 8. Mouse cursor is also hidden (Core Rule 11). No dismiss triggered.

**EC-6: Ju holds down a key during the input-blackout window.**
During blackout, `_unhandled_input` early-returns (Core Rule 7). After blackout, `event.echo == true` is filtered (Core Rule 8). No dismiss until she performs a fresh key-press.

**EC-7: Ju clicks repeatedly during the reveal.**
Each `InputEventMouseButton` with `pressed == false` is filtered (button-release rejection). During blackout, even press events are rejected. No dismiss until the first press-event after blackout expires.

**EC-8: Ju presses Esc.**
`event.keycode == KEY_ESCAPE` is explicitly rejected in Core Rule 8. No dismiss. Esc has no effect on FES. Prevents the double-tap-to-quit failure mode (Esc on Main Menu quits the app).

**EC-9: Ju Alt+Tabs away during the reveal.**
Godot continues running; Tween proceeds; blackout timer proceeds. When she returns, whatever state FES is in continues. No special handling — commercial-game focus-loss handling is out of scope (consistent with Main Menu GDD).

**EC-10: `final_memory_ready` emits twice in one session.**
Scene Manager's connection uses `CONNECT_ONE_SHOT` (Core Rule 2). The first emission disconnects the handler. A second emission is a no-op. No second scene swap. If MUT has a bug that emits twice, it is invisible to FES.

**EC-11: Ju completes the game a second time on a fresh save.**
Only possible if she manually deletes save data. On the new save, MUT's `_final_memory_earned` is `false` again, so the epilogue triggers normally. Intended — the epilogue is per-save, not per-install.

**EC-12: Game window is very small (800×600) or very large (4K).**
FES root is `Control` with `PRESET_FULL_RECT`. The illustration is centered in a `CenterContainer` with `expand_mode = KEEP_ASPECT_CENTERED` on the `TextureRect`. Small windows letterbox; large windows scale up and center. No layout bug.

**EC-13: Dwell-timer expires before fade-in completes (defensive).**
`INPUT_BLACKOUT_DURATION` Timer starts on the Tween's `finished` signal, not on `_ready()`. The Timer cannot start before the Tween completes. Cannot occur with current formula. Documented in case future edits move the Timer start earlier.

**EC-14: Ju resizes the window during the reveal.**
Godot's Control layout recomputes. Tween continues on `modulate:a` (a scalar, unaffected by size). Illustration re-centers. No visible glitch.

**EC-15: Audio Manager fade-out call fails (method doesn't exist yet).**
FES calls `AudioManager.fade_out_all(duration)` per Interactions. Guarded by `if AudioManager.has_method("fade_out_all")`. If absent, audio continues to play — not ideal but not blocking. Audio Manager GDD must add this method (see Acceptance Criteria).

**EC-16: `is_final_memory_earned()` returns false at FES `_ready()`.**
Defensive guard (Core Rule 5). Indicates an ordering bug upstream. Handled by: log error, call `get_tree().quit()`. The screen should not exist in this state; quitting is cleaner than showing a partial state.

## Dependencies

### Upstream (FES depends on)

- **Mystery Unlock Tree** (`design/gdd/mystery-unlock-tree.md`) — Approved. Provides `_final_memory_earned` flag, `is_final_memory_earned()` query, and emits `final_memory_ready()` and `epilogue_conditions_met()` via EventBus.
- **Scene Manager** (`design/gdd/scene-manager.md`) — Designed. Per ADR-004, SM no longer listens to `final_memory_ready` and does not call `change_scene_to_file` for FES; SM emits `epilogue_started()` on terminal state entry and STUI drives the amber cover. The illustration preloader responsibility lives in `gameplay_root.gd` (or a small helper inside the EpilogueLayer node).
- **Scene Transition UI** (`design/gdd/scene-transition-ui.md`) — Approved. Emits `epilogue_cover_ready()` — FES's actual reveal gate.
- **EventBus / ADR-003** — Must declare three new signals: `final_memory_ready()`, `epilogue_conditions_met()`, `epilogue_cover_ready()`. Bundled companion-edit debt with Main Menu's `game_start_requested()`.
- **Audio Manager** (`design/gdd/audio-manager.md`) — Designed. Must expose `fade_out_all(duration: float)` method for FES to silence the ambient bed during reveal.

### Downstream (depends on FES)

None. FES is a terminal leaf node in the dependency graph. After FES, the application exits.

### Reverse-references (other GDDs that mention FES)

- **Mystery Unlock Tree** — emits `final_memory_ready()` specifically for FES to consume (via Scene Manager as listener). MUT OQ-11 (`epilogue_conditions_met` consumer) is resolved by this GDD naming Scene Manager's preloader as the named consumer.
- **Scene Manager** — expected to perform the final scene swap into FES and own the preloader.
- **Scene Transition UI** — signal `epilogue_cover_ready` specifically exists for FES's reveal gating.

### Companion edits owed when FES is implemented

1. **EventBus**: add three signal declarations (`final_memory_ready`, `epilogue_conditions_met`, `epilogue_cover_ready`).
2. **Scene Manager** (per ADR-004): does NOT add a `final_memory_ready` listener and does NOT call `change_scene_to_file`. SM's role is to emit `epilogue_started()` on terminal-state entry. The illustration preloader subscription to `epilogue_conditions_met` is owned by `gameplay_root.gd` (ADR-004 §3). No `_enter_tree` guard is needed because FES is pre-instanced and uses `CONNECT_ONE_SHOT` on `epilogue_cover_ready` for its one-shot enforcement.
3. **Audio Manager**: add `fade_out_all(duration: float)` method to the public API.
4. **MUT GDD**: close OQ-11 referencing this GDD's decision (Scene Manager preloader is the named consumer).
5. **MUT OQ-9** (per-memory display names) does *not* affect FES — FES shows only the final illustration, not individual memory names. OQ-9 can remain open and independent.

## Tuning Knobs

| Knob | Type | Default | Safe Range | Affects |
|------|------|---------|-----------|---------|
| `FADE_IN_DURATION` | `const float` (seconds) | `2.0` | `1.0 – 4.0` | Pace of reveal. Below 1.0s feels cinematic/sudden; above 4.0s feels like a loading screen. |
| `INPUT_BLACKOUT_DURATION` | `const float` (seconds) | `1.5` | `1.0 – 3.0` | Protection against accidental dismiss. Below 1.0s risks reflex-click skipping; above 3.0s feels unresponsive. |
| `COVER_READY_TIMEOUT` | `const float` (seconds) | `5.0` | `3.0 – 10.0` | Fallback safety timer (EC-4) if STUI's `epilogue_cover_ready` never fires. |
| `ILLUSTRATION_PATH` | `const String` | `"res://assets/epilogue/illustration.png"` | Single valid file path | Which asset FES loads. Changes require both code and file on disk. |
| `AUDIO_FADE_OUT` | `const bool` | `true` | `true` or `false` | Whether FES calls `AudioManager.fade_out_all()` on reveal. `false` for audio-less debugging. |
| `CURSOR_HIDE_ON_REVEAL` | `const bool` | `true` | `true` or `false` | Whether to set `Input.mouse_mode = MOUSE_MODE_HIDDEN` on reveal entry. `false` useful for dev screenshots. |

**`const` over `@export`, explicitly:**
Per the Main Menu GDD lesson: `@export` and `const` are mutually exclusive in GDScript. These values are frozen-once-tuned game-feel constants, not per-scene designer knobs. `const` gives compile-time reference checking, static-analysis visibility, and protects against runtime mutation. None of these values should vary between playthroughs or be editable in the Godot Inspector.

**Not tunable (deliberately):**
- The easing curve (`TRANS_QUAD + EASE_OUT`) — changing the easing changes the *feel* of the reveal, which is designed, not tuned.
- The Esc rejection in Core Rule 8 — a design decision, not a knob.
- The "quit on dismiss" behavior — no Main Menu fallback, no scene swap option. Structural, not tunable.

## Visual/Audio Requirements

### Visual

**The illustration asset:**
- **Format**: PNG with alpha channel, single file
- **Size**: 2048 × 2048 px, RGBA — ~16MB in VRAM, acceptable for desktop target per `technical-preferences.md`'s 256MB ceiling
- **Content**: one handcrafted illustration unique to this ending. The image exists nowhere else in the game — not as a card back, not as a memory reveal, not as a Main Menu element. Singular by design (Pillar 1: Recognition Over Reward — the image *is* the recognition).
- **Style**: consistent with the game's hand-drawn art bible (Pillar 4: Personal Over Polished). Rough line work, visible pencil/pen texture, the aesthetic of "Chester drew this" rather than "a studio produced this."
- **Content direction**: intentionally deferred to a future `/asset-spec system:final-epilogue-screen` invocation. The Art Bible and Chester's hand-lettering workflow (referenced in Main Menu OQ-4) must resolve before this asset can be speced.
- **Placement**: centered on a neutral background. Background color TBD in asset spec — candidates: off-white paper texture, warm cream, or soft dark. Must NOT be pure black or pure white (clinical).

**Screen composition:**
- Root: `Control` (`PRESET_FULL_RECT`), modulate-driven fade-in
- Background: a single-color `ColorRect` filling the viewport; color matches the illustration's background tone
- Illustration: `TextureRect` inside a `CenterContainer`; `expand_mode = KEEP_ASPECT_CENTERED`; max display size ~80% of the smaller viewport dimension (framing space on all sides)
- **No UI chrome of any kind over the image.** No "Press any key" prompt, no title, no credits, no watermark, no logo, no frame. The image is alone. Hard rule — any text overlay appears in screenshots and breaks the fantasy forever.
- **No post-processing effects.** No vignette, no bloom, no color grade. The illustration is what was drawn; the screen presents it without filter.

**Transition pattern:**
- Fade in from alpha 0 → 1 over `FADE_IN_DURATION` (default 2.0s), quadratic ease-out.
- Image resolves from a clean dark canvas (STUI's amber overlay must complete its fade-out before FES begins its fade-in — otherwise the two overlap visibly; see Scene Transition UI companion concern).

### Audio

**Silence is the design.**

- FES plays **no music, no SFX, no stingers.**
- On reveal entry, FES calls `AudioManager.fade_out_all(FADE_IN_DURATION)` — existing gameplay audio fades out in lockstep with the image fading in. By full opacity, audio is at zero.
- After fade-out, the application is fully silent until dismiss.
- **Room-tone fallback (REJECTED)**: UX review proposed a near-inaudible room-tone bed to reassure users that speakers aren't broken. Rejected for Pillar 4 reasons — a recorded "room" in a game about handmade intimacy feels like a studio affectation. Silence is stated here as intentional so QA does not file it as a bug.
- **Accessibility**: no audio means no audio-based dismiss cue. Acceptable for N=1; Ju has no hearing considerations we need to accommodate.

**Audio Manager API requirement:**
- `AudioManager.fade_out_all(duration: float)` — fades all active audio buses to silence over `duration` seconds.
- If the method does not yet exist, FES guards the call with `has_method` (EC-15); audio continues as a non-blocking defect. Audio Manager GDD must add this method before FES ships.

## UI Requirements

**Input primary: mouse.** Ju plays with mouse per Main Menu GDD. Keyboard is secondary; any single press accepted. Gamepad is out of scope.

**Focus handling:** FES has no focusable controls. No buttons, no menus, no widgets. `_unhandled_input` catches events at the scene root. No `grab_focus()` call needed.

### Dismiss inputs accepted (post-blackout)

- Any `InputEventKey.pressed == true and not echo` — **except `KEY_ESCAPE`**
- Any `InputEventMouseButton.pressed == true` (left, right, middle, side buttons)

### Dismiss inputs rejected (always)

- `InputEventMouseMotion` (any hover movement)
- `InputEventKey.echo == true` (key-held auto-repeat)
- `InputEventKey.pressed == false` (key release)
- `InputEventMouseButton.pressed == false` (button release)
- `InputEventKey.keycode == KEY_ESCAPE` (explicit rebind — Esc is inert on FES; prevents the double-tap-to-quit failure mode)
- Any input during `Revealing` or `Blackout` states (per the state table)

### Cursor

- Hidden on reveal entry (`Input.mouse_mode = MOUSE_MODE_HIDDEN`)
- Not restored — FES exits via `get_tree().quit()`, not via scene swap, so cursor restoration is moot

### Accessibility (N=1 calibrated)

- No screen reader support — FES has no text to read
- No subtitles — FES has no audio
- Color contrast / colorblindness — moot (the illustration is the content; color is aesthetic direction, not functional)
- Input remapping — not provided; any key / any click is the most forgiving possible scheme
- Reduced motion — not provided as a toggle; the 2.0s fade-in is already gentle. If Ju has motion sensitivity, Chester adjusts `FADE_IN_DURATION` directly in code

### Internationalization

- No strings. Zero `tr()` calls required. FES is language-free by design — the illustration carries the message.

### Layout / viewport

- Responds to window resize via Godot's Control layout — no custom handling
- Minimum supported viewport: 1024 × 768 (illustration scales to ~768 × 768 with 128px margin)
- Maximum tested viewport: 4K (3840 × 2160) — illustration scales up to 1728 × 1728 centered
- Fullscreen and windowed both supported. Whatever mode Ju is in when the epilogue triggers, FES inherits.

### Window state

- FES does not modify window title, window icon, or fullscreen state
- FES does not disable Alt+Tab, Cmd+Q, or window close button — all standard OS window behaviors remain active

## Acceptance Criteria

**AC-TRIGGER-1** (superseded per ADR-004): Given a save state where `MUT.is_final_memory_earned() == false` and Ju completes the final required recipe during the final chapter, when `EventBus.final_memory_ready` is emitted, `gameplay_root.gd` calls `SaveSystem.save_now()` exactly once (to persist MUT's flag against crash/quit during Epilogue). The FES reveal is triggered separately by `epilogue_cover_ready` from STUI, not by `final_memory_ready`.
*Test:* integration test with a pre-built MUT save state at `discovered_count == required_count - 1`, trigger the final recipe, assert `SaveSystem.save_now()` is called exactly once. Assert STUI's `epilogue_cover_ready` listener on FES fires within 100ms of STUI entering its full-opacity state.

**AC-TRIGGER-2** (per ADR-004): Given a save state where `MUT.is_final_memory_earned() == true` AND `resume_index == manifest.size()`, when the app starts, Scene Manager enters Epilogue state directly on `game_start_requested` (per SM Core Rule 9) and emits `epilogue_started()` exactly once. STUI begins its amber cover, emits `epilogue_cover_ready`, and FES reveals — this is the intended relaunch-after-completion path.
*Test:* integration test — preload save state with `_final_memory_earned = true`, start app, assert `EventBus.final_memory_ready.get_connections()` contains no Scene Manager callback. Assert current scene is Main Menu.

**AC-REVEAL-1**: Given FES has loaded (`_ready()` completed) and `EventBus.epilogue_cover_ready` is received, the Tween on `modulate:a` starts within 1 frame (16.7ms) and completes over `FADE_IN_DURATION ± 50ms`.
*Test:* unit test with mocked EventBus; record Tween start time and duration; assert bounds. Alternatively, screenshot diff at 25%, 50%, 75%, 100% of elapsed `FADE_IN_DURATION`.

**AC-REVEAL-2**: If `epilogue_cover_ready` does not fire within `COVER_READY_TIMEOUT` (5.0s default) of FES `_ready()`, FES begins fade-in anyway.
*Test:* integration test — instantiate FES, do NOT emit `epilogue_cover_ready`, wait 5.5s, assert Tween has started and `modulate:a > 0`.

**AC-INPUT-1**: During the `Revealing` state (fade-in in progress), any input event is ignored. `get_tree().quit()` is NOT called.
*Test:* unit test — instantiate FES, begin reveal, simulate `InputEventKey` / `InputEventMouseButton` events, assert FES does not call quit.

**AC-INPUT-2**: During the `Blackout` state (first 1500ms after fade-in completes), any input event is ignored.
*Test:* unit test — instantiate FES, run fade-in to completion, simulate inputs at 100ms, 500ms, 1400ms after fade-in finished; assert FES does not call quit.

**AC-INPUT-3**: During `Holding` state (post-blackout), a valid dismiss input triggers `get_tree().quit()` exactly once.
*Test:* unit test — advance to `Holding`, simulate a single `InputEventKey.pressed = true, keycode = KEY_SPACE, echo = false`, assert `get_tree().quit()` is called exactly once.

**AC-INPUT-4**: `InputEventMouseMotion` never triggers dismiss in any state.
*Test:* unit test — advance to `Holding`, simulate `InputEventMouseMotion` for 5 seconds, assert `get_tree().quit()` is never called.

**AC-INPUT-5**: `KEY_ESCAPE` never triggers dismiss in any state.
*Test:* unit test — advance to `Holding`, simulate `InputEventKey.pressed = true, keycode = KEY_ESCAPE, echo = false`, assert `get_tree().quit()` is never called.

**AC-INPUT-6**: Button-release events (`pressed == false`) never trigger dismiss.
*Test:* unit test — advance to `Holding`, simulate `InputEventMouseButton.pressed = false`, assert no quit.

**AC-INPUT-7**: Key-echo events (`echo == true`) never trigger dismiss.
*Test:* unit test — advance to `Holding`, simulate `InputEventKey.pressed = true, echo = true`, assert no quit.

**AC-ONESHOT-1** (per ADR-004): A single triggering session results in exactly one FES reveal, regardless of how many times `epilogue_cover_ready` is emitted.
*Test:* integration test — emit `epilogue_cover_ready` three times in succession, assert FES transitions `Armed → Loading` exactly once (`CONNECT_ONE_SHOT` disconnects after first).

**AC-ONESHOT-2**: FES writes no files and modifies no persistent state. A crash or force-quit during FES leaves save state unchanged relative to pre-FES.
*Test:* integration test — snapshot `user://save.dat` (or equivalent) before FES triggers, force-terminate FES mid-reveal, re-read save file, assert bitwise identical to snapshot.

**AC-VISUAL-1**: The illustration is centered in the viewport at all supported resolutions (1024×768, 1920×1080, 3840×2160). No clipping, no stretching beyond aspect ratio.
*Test:* automated screenshot test at three resolutions; pixel-check that the illustration's bounding box is horizontally and vertically centered within ±2 pixels.

**AC-VISUAL-2**: The image is fully visible at alpha = 1.0 at `t = FADE_IN_DURATION` post-cover-ready. No UI chrome, text, or overlay is rendered at any time during or after FES.
*Test:* automated screenshot at `t = FADE_IN_DURATION + 100ms`; pixel-diff against a reference image of the illustration on the configured background color. Any text or UI element pixels fail the test.

**AC-AUDIO-1**: On reveal entry, `AudioManager.fade_out_all(FADE_IN_DURATION)` is called. If Audio Manager does not yet implement the method, FES does not crash.
*Test:* unit test — spy on AudioManager; trigger reveal; assert `fade_out_all` is called with correct duration. Repeat with AudioManager stub missing the method; assert FES does not crash.

**AC-AUDIO-2**: After fade-out completes, no audio is playing from any bus.
*Test:* manual playtest — listen at full volume for 10s after fade-out; no audio should be audible.

**AC-FAIL-1**: If `MUT.is_final_memory_earned()` returns `false` when FES `_ready()` runs, FES logs an error and calls `get_tree().quit()` within 1 frame. No partial screen render.
*Test:* integration test — force-load FES scene with MUT in a state where `_final_memory_earned = false`; assert stderr contains the error string; assert `get_tree().quit()` is called.

**AC-FAIL-2**: If the illustration PNG fails to load, FES renders the background color only (no crash, no placeholder text). Stderr log produced.
*Test:* integration test — remove or corrupt the illustration PNG; instantiate FES; assert no crash, no exception, stderr contains load-failure message.

## Open Questions

**OQ-1: Illustration content direction.**
The image itself is undefined in this GDD. Composition, color palette, hand-lettering style — deferred to a future `/asset-spec system:final-epilogue-screen` invocation. Resolution prerequisite: Art Bible must be approved and Main Menu OQ-4 (hand-letter vs. font) must be resolved first — FES should match the title-card's authorial register.
*Blocker for:* final asset delivery. Not a blocker for code implementation (ship with placeholder, swap real asset in at any time).

**OQ-2: Background color of the FES scene.**
Currently `ColorRect` color is TBD. Three candidates: off-white paper texture, warm cream, or soft dark. Choice depends on what the illustration itself needs as a ground. Deferred to asset spec.
*Blocker for:* final visual ship. Not a blocker for code implementation.

**OQ-3: Coordination with STUI amber overlay fade-out.**
Visual/Audio Requirements notes that STUI's amber overlay must complete its fade-out before FES begins its fade-in — otherwise they overlay visibly. STUI GDD describes the amber overlay's entry but the exit timing may need a companion edit.
*Resolution:* review STUI's Detailed Design for epilogue-cover-ready timing and amber-overlay-exit timing. If not explicitly sequenced, add a companion edit to STUI ensuring amber fades out BEFORE emitting `epilogue_cover_ready`.

**OQ-4: Session-only vs. save-persistent one-shot — timeline for Save/Progress System.**
FES ships in Alpha. Save/Progress System also ships in Alpha. If FES is implemented first, session-only enforcement is acceptable (Edge Cases documented). If Save/Progress ships first, FES inherits persistent enforcement for free.
*Resolution:* sequencing decision for sprint planning. Not a GDD question.

**OQ-5: `COVER_READY_TIMEOUT` default (5.0s).**
Fallback safety timer (EC-4) for defense-in-depth. 5.0s is a guess. If STUI's cover rise is routinely longer than 4s (not currently the case), 5s is too aggressive. If STUI's rise is ~2s typical, 5s is generous and reasonable.
*Resolution:* after STUI is implemented, measure actual cover-rise duration on target hardware; set timeout to 2× measured maximum. Tuning, not design.

**OQ-6: `AudioManager.fade_out_all(duration)` method signature.**
FES assumes this method exists with this exact signature. Audio Manager GDD may design a different API (e.g., per-bus fades with different names). If so, FES's call needs adjustment.
*Resolution:* when Audio Manager GDD is reviewed, confirm the exact signature. Update FES Core Interaction and EC-15 to match.
