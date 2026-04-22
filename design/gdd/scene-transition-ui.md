# Scene Transition UI

> **Status**: Approved (2nd-pass review applied 2026-04-20; pre-implementation ui-programmer/godot-specialist pass recommended)
> **Author**: chester + game-designer, ux-designer, ui-programmer, creative-director, systems-designer, qa-lead, godot-specialist, audio-director
> **Last Updated**: 2026-04-20 (r2 — 7 blockers from 2nd-pass fixed: 4 stale-artifact contradictions, 3 design fixes)
> **Implements Pillar**: Pillar 3 (Discovery Without Explanation), Pillar 4 (Personal Over Polished), Pillar 1 (Recognition Over Reward)
>
> **Revision note (r1)**: curl pinned to Polygon2D vertex deformation (was dual-path);
> Formula 3 rewritten as true semitone math; SGS ordering race fixed via `_enter_tree()`
> subscription; reduced-motion path rewritten as slowed page-lift (was crossfade —
> broke Framing B for accessibility users); `hold_nominal_ms` 700 → 1000 for
> album-pause fantasy; scope trimmed aggressively (45 ACs → 20).
>
> **Revision note (r2)**: stale-artifact cleanup post r1 — Interactions table, Formula 2
> header, Z-ordering section, and Audio notes corrected to match r1 rules (prior
> revision left four contradictions in place). Formula 1 joint-knob-constraint rule
> added; reduced-motion clamp exemption stated; epilogue V_i-scaling clarified.
> `pitch_semitone_range` ceiling lowered 7.0 → 6.0 to match description. CR 7
> narrowed to mouse/touch (keyboard out of scope pre-Settings). `scene_loading`
> subscription dropped (was never consumed). Duplicate OQ-6 removed. Accessibility
> paragraph corrected (removed wrong claim that paper-breathe reinforces epilogue).

## Overview

Scene Transition UI (STUI) is the presentation layer that visually brackets every scene change in Moments. It is a signal-driven overlay system — an autoloaded `CanvasLayer` that listens on EventBus for three Scene Manager signals (`scene_loading`, `scene_started`, `epilogue_started`) and one Scene Goal System signal (`scene_completed`), and in response paints the screen with fade and breakthrough visuals while blocking input. The player experiences STUI as a moment rather than a notification: when a scene is complete, the table dissolves, the world briefly holds its breath, and the next scene materialises in its place. No text, no "Scene Complete!" banner, no score readout — only a felt beat that marks *something shifted*. STUI owns no gameplay state and makes no decisions; it is a silent witness that turns signal events into the visual punctuation between chapters.

## Player Fantasy

### The feeling

*"Someone made this for me, one page at a time. I'm turning to the next page."*

When Ju completes a scene, STUI plays the moment of a page turning in a handmade photo album. The cards she has just recognised soften and lift slightly, as if a hand is gathering them up. A subtle paper-rustle or fabric-shift carries them away. The table's contents drift aside with a small, deliberate imperfection — a touch of rotational wobble, never geometric — and the next scene settles into place like a photograph being laid down. The whole beat takes 1.5–2 seconds. It should feel like weight: the weight of a hand arranging the page, the weight of someone having made this for her.

### Tone words

handmade, tender, deliberate, intimate, tactile

### Anchor moments

- **Scene complete → next scene**: the page turns. Cards lift, paper rustles, the next table settles in like a photograph being placed.
- **Scene start fade-in (quiet variant)**: not a page turn — a softer arrival, like looking down at the album after the page has already turned.
- **Epilogue transition**: the final page turn reveals something that reads as *the inside cover* — the last scene arrives with a sense of having reached the end of the album. The handmade warmth peaks here; the transition is slightly longer (~3s) and quieter.

### Why this bears repetition

The album metaphor has built-in pacing. Each page turn is the same small ritual, and rituals gain meaning with repetition rather than losing it. By scene 5 or 6, Ju should *anticipate* the page turn the way you anticipate turning the page of a real album — that anticipation is itself part of the gift.

### Anti-patterns (what STUI must NOT do)

- **No digital transitions**: no mask reveals, no radial wipes, no parallax, no shader-driven dissolves that feel algorithmic.
- **No perfect symmetry or perfectly eased timing**: imperfection is the point. A touch of wobble, a slightly uneven fade.
- **No celebration UI**: no "Congratulations!", no checkmarks, no burst VFX, no score summary — Pillar 3 is absolute.
- **No overlay chrome**: no vignettes, no letterboxing, no scene-title text cards.
- **No identical repetition**: the page turn should carry a small organic variation each time (slight timing jitter, sound variation) so it feels hand-performed, not stamped.

## Detailed Design

### Core Rules

1. **Instancing** — STUI is a `CanvasLayer`-rooted scene (`scene_transition_ui.tscn`) instanced as a child of the main game scene. It is **not** an autoload. It dies with the game scene on quit-to-menu.

2. **Signal subscriptions** — In **`_enter_tree()`** (not `_ready()`), STUI connects to three EventBus signals. Subscribing in `_enter_tree()` fixes the first-frame ordering race where SGS could emit `scene_completed` before STUI's `_ready()` runs when both are instanced in the same frame. `_ready()` is used only for initial state setup (tween root creation, blocker anchors) — not for subscription.
   - `scene_completed(scene_id: String)` — primary trigger for the page turn
   - `scene_started(scene_id: String)` — signals that new seed cards are placed; triggers fade-out of overlay
   - `epilogue_started()` — triggers the epilogue variant

   STUI does **not** subscribe to `scene_loading` — it has no behavioural response to the signal and Scene Manager's internal loading is not STUI's concern. (Systems-index note: Scene Manager's downstream table lists STUI as a listener of `scene_loading`; that entry should be removed when Scene Manager is next touched. Tracked as a cross-GDD edit.)

3. **Trigger rule** — The page turn fires on `scene_completed`, not on `scene_loading`. Rationale: the peak of the page turn must overlap the satisfaction peak of scene completion; starting later perceptually reads as latency.

4. **Page-turn visual** — A single full-screen `Polygon2D` (textured with the cream paper image) rises from the trailing edge across the viewport. The Polygon2D is a **12-segment vertical strip** (13 columns of vertex pairs, top and bottom); per-vertex y-displacement over time produces the curl. This is a single node with a single transform pipeline — **not** a composite of TextureRect + separate curl shape. The overall `modulate.a` animates 0 → 1 during the rise phase; simultaneously, a curl envelope function (Formula 2) displaces the vertices along the leading edge so the paper rolls rather than slides. The curl reaches peak deformation at ~300ms after `scene_completed`.

   *Note: Polygon2D is the single authoritative visual node. A TextureRect-based alternative was considered and rejected because UV-rect coordinates collided with Node2D world coordinates when the curl shape was a child, breaking full-viewport geometry guarantees.*

5. **Canonical phase timings (nominal)** — Total: 1.9s. Phase budgets draw per-instance variation from Tuning Knobs (see Tuning Knobs section). Hold was raised from 700 → 1000ms to honour the album-pause fantasy (a real album lingers ~1.2–1.8s on a page; 700ms was perfunctory).

   | Phase | Start (ms) | Duration (ms) | Behavior |
   |---|---|---|---|
   | Drag-cancel | 0 | 100 | `InputSystem.cancel_drag()` fires; any held card eases back to last stable position |
   | Overlay rise + curl sweep | 0 | 400 | Polygon2D alpha 0 → 1, curl envelope deforms leading edge; fantasy peak at ~300ms |
   | Hold (scene swap) | 400 | 1000 | Overlay opaque; Scene Manager performs sync load. Hold stretches if load exceeds 1000ms |
   | Overlay fade-out | 1400 | 500 | Alpha 1 → 0, new scene revealed behind fading overlay |
   | Total | — | 1900 | Input unlocks when alpha reaches 0 |

6. **Drag cancellation** — At frame of `scene_completed`, STUI calls `InputSystem.cancel_drag()`. Any card being dragged eases back to its last stable position over 100ms. The drag never completes; the card is cleared with the rest of the old scene behind the opaque overlay.

7. **Input blocking** — STUI's `InputBlocker` is a full-screen `ColorRect` with `modulate.a = 0`. During any transition state (FADING_OUT, HOLDING, FADING_IN, EPILOGUE), `mouse_filter = MOUSE_FILTER_STOP`. In IDLE, `mouse_filter = MOUSE_FILTER_IGNORE`. **Scope: mouse and touch only.** In Godot 4.3, `MOUSE_FILTER_STOP` blocks only mouse/touch events; keyboard events (including Escape) flow through `_input`/`_unhandled_input` independent of the mouse-filter pipeline. Keyboard interception is intentionally out of scope for STUI — pre-Settings (system #20), the game has no pause affordance and no keyboard action has gameplay consequence during a transition, so keyboard-through is a non-issue. When Settings ships, pause/Escape handling is Settings' concern, not STUI's.

8. **First scene arrival** — The first scene (on game boot, before any transition has occurred) uses a simplified entry: STUI begins fully opaque and fades out over 1200ms on `scene_started`. No curl, no paper pulse, no drag-cancel (no prior drag exists). This is the only time STUI is opaque without a preceding `scene_completed`.

9. **Epilogue variant** — On `epilogue_started()`:
   - All normal phase timings scale by 1.35× (overlay rise slightly slower, hold longer)
   - The overlay color modulate shifts to a warmer amber tint (`Color(1.0, 0.92, 0.78)` vs the normal cream)
   - Hold is **open-ended**: STUI does not auto-fade-out. When the overlay reaches full opacity, STUI emits `EventBus.epilogue_cover_ready()` and waits. Final Epilogue Screen (system #18) is responsible for rendering above STUI or signalling STUI to hand off.
   - Paper-breathe pulse during the hold is disabled (stillness instead of animation)

10. **Organic variation** — Each transition instance draws variation values from tuning ranges (see Tuning Knobs section). Variation is seeded *per transition*, not per game — each page turn is distinct but controlled. What varies: phase durations (within ±100ms of nominal), curl peak deformation amplitude (±1.5 of nominal curl height), audio pitch (±4 semitones via ratio, see Formula 3), paper-breathe amplitude. What does **not** vary: ease curves (always ease-in-quad rise, ease-out-cubic fall), curl sweep direction (always trailing edge), cream color.

11. **Reduced-motion path** — If `GameSettings.reduced_motion == true`, STUI preserves Framing B at reduced intensity. It does **not** degrade to a crossfade — a crossfade is a different fantasy, and accessibility users deserve the page-turn too. The reduced-motion path is a **slowed, simplified page-lift**:
    - Rise: 400ms linear ease (not ease-in-quad), full overlay alpha 0 → 1, no curl vertex deformation (Polygon2D stays flat), no rotation
    - Hold: 600ms (reduced from 1000ms; the pause is still perceivable)
    - Fade-out: 400ms linear ease
    - Paper-breathe pulse disabled (stillness)
    - Audio pitch variation disabled (pitch locked to 1.0); rustle + settle SFX still play (the audio IS the fantasy carrier for this path)
    - Epilogue variant: same reduced path, with amber tint and open-ended hold

12. **Stateless across save/load** — STUI persists nothing. Save system does not touch STUI. On load, STUI begins in IDLE; Scene Manager drives whatever transition the loaded state requires.

13. **Signal-storm guard** — Once STUI leaves IDLE, it ignores further `scene_completed` signals until it returns to IDLE. Duplicate emits are silently dropped.

### States and Transitions

| State | Entry Condition | Rendering | Exit Condition |
|---|---|---|---|
| `IDLE` | Initial / after FADING_IN completes | Overlay `visible = false`, alpha 0, `mouse_filter = IGNORE` | `scene_completed` or `epilogue_started` |
| `FADING_OUT` | `scene_completed` received | Overlay rising, curl sweeping, input blocked | Overlay alpha = 1 (Tween complete) → auto |
| `HOLDING` | FADING_OUT Tween complete | Overlay opaque, paper-breathe pulse active | `scene_started` received |
| `FADING_IN` | `scene_started` received while in HOLDING | Overlay alpha 1 → 0, new scene reveals | Tween complete → auto |
| `EPILOGUE` | `epilogue_started` received from any state | Amber overlay rising then held indefinitely | N/A — terminal (Final Epilogue Screen takes over) |
| `FIRST_REVEAL` | Game boot, initial scene load | Overlay begins opaque (cream), slow 1200ms fade-out on `scene_started` | Tween complete → auto → IDLE |

Transition table:

| From | Trigger | To | Notes |
|---|---|---|---|
| (initial) | game boot | FIRST_REVEAL | STUI starts opaque |
| FIRST_REVEAL | `scene_started` → fade complete | IDLE | one-shot only |
| IDLE | `scene_completed` | FADING_OUT | cancel any active drag |
| IDLE | `epilogue_started` | EPILOGUE | amber tint, slowed timings |
| FADING_OUT | Tween complete | HOLDING | paper-breathe begins |
| HOLDING | `scene_started` | FADING_IN | |
| FADING_IN | Tween complete | IDLE | input unlocks at alpha=0 |
| FADING_OUT / HOLDING / FADING_IN | `epilogue_started` | EPILOGUE | finish current rise if rising, then switch to amber tint and open-ended hold |
| Any except EPILOGUE | `scene_completed` while not IDLE | (no-op) | signal-storm guard |

### Interactions with Other Systems

| System | Direction | Contract |
|---|---|---|
| **EventBus** (autoload) | STUI listens | Subscribes to `scene_completed`, `scene_started`, `epilogue_started` in `_enter_tree()` (see Core Rule 2 for rationale). Emits `epilogue_cover_ready()` when EPILOGUE overlay reaches full opacity. |
| **Scene Goal System** | upstream | Provides `scene_completed(scene_id)`. STUI does not read any SGS state directly. |
| **Scene Manager** | upstream + coordinated | Provides `scene_loading(scene_id)`, `scene_started(scene_id)`, `epilogue_started()`. STUI holds the screen opaque while Scene Manager performs the sync load; Scene Manager guarantees `scene_started` within a reasonable budget. If load exceeds hold budget, STUI stretches HOLDING until `scene_started` arrives. |
| **Input System** | downstream (one call) | STUI calls `InputSystem.cancel_drag()` at frame of `scene_completed`. This is the only cross-system call STUI makes (all other communication is signal-based). |
| **Final Epilogue Screen** (system #18) | downstream | Listens for `EventBus.epilogue_cover_ready()` to know the canvas is clear. FES is responsible for rendering its content above STUI or signalling STUI to fade. |
| **Card Engine** | indirect | STUI's `InputBlocker` with `MOUSE_FILTER_STOP` prevents any mouse events reaching cards during transitions. Card Engine does nothing STUI-specific. |
| **Transition variants config** | reads | `assets/data/ui/transition-variants.tres` keyed by `scene_id` provides per-scene knobs (fold duration scale, paper tint). Missing keys fall back to `"default"`. |
| **ProjectSettings** (provisional) | reads | Reads `ProjectSettings.get_setting("stui/reduced_motion_default", false)` at the start of each transition. Settings v1 (2026-04-21) intentionally defers exposing reduced-motion as a player-facing toggle (Settings OQ-3) — STUI continues to source from ProjectSettings until a Settings schema v2 bump adds a UI toggle. |

## Formulas

### Formula 1 — Per-Transition Phase Duration

Each transition draws phase durations from nominal ± variation. Total transition length is then clamped to the design budget so long tails don't accumulate.

**Variables:**
- `D_i_nom` : nominal duration for phase `i`, in ms (see Core Rule 5)
- `V_i` : variation range for phase `i`, in ms (from Tuning Knobs)
- `r_i` : per-transition random draw, uniform in `[-1.0, 1.0]`, seeded fresh each transition
- `D_i` : resolved duration for phase `i`
- `T_total` : summed transition duration
- `T_MIN`, `T_MAX` : hard clamps (1500, 2000 ms)

**Formula:**
```
D_i      = D_i_nom + r_i * V_i                             for each phase i
T_total  = Σ D_i
if T_total > T_MAX: scale = T_MAX / T_total; D_i *= scale
if T_total < T_MIN: scale = T_MIN / T_total; D_i *= scale
```

**Nominal values and ranges (normal transition):**

| Phase | `D_i_nom` (ms) | `V_i` (ms) | Range after draw |
|---|---|---|---|
| Overlay rise + curl | 400 | 80 | 320–480 |
| Hold | 1000 | 150 | 850–1150 |
| Overlay fade-out | 500 | 80 | 420–580 |

Nominal total: 1900 ms. Variation bounds total: [1590, 2210] ms before clamping. Clamps: `T_MIN = 1700`, `T_MAX = 2200`.

**Joint knob constraint.** Tuning knobs for per-phase nominals and variations are declared with independent safe ranges (see Tuning Knobs), but knobs with at-or-near-floor nominals combined with at-or-near-ceiling variations can pull `Σ(D_i_nom − V_i)` well below `T_MIN`, forcing the clamp to stretch every phase 2–3×. This collapses the narrative-intended variation character. **Rule:** any combination of knob overrides must satisfy `Σ(D_i_nom − V_i) ≥ T_MIN` and `Σ(D_i_nom + V_i) ≤ T_MAX + 100` — tuning that violates either is a misconfiguration. Large clamp factors (>1.3×) are a red flag; the per-phase `r_i` signature is not preserved under heavy scaling.

**Clamp applies only to the standard path.** The reduced-motion path (Core Rule 11) uses fixed durations `reduced_motion_rise_ms + reduced_motion_hold_ms + reduced_motion_fade_ms` and is not subject to `T_MIN`/`T_MAX`. The default reduced-motion total (400+600+400 = 1400 ms) is intentionally below `T_MIN` and does not trigger up-scaling.

**Example calculation (one transition):**
- `r_rise = 0.5` → `D_rise = 400 + 0.5*80 = 440` ms
- `r_hold = -0.3` → `D_hold = 1000 + (-0.3)*150 = 955` ms
- `r_fade = 0.8` → `D_fade = 500 + 0.8*80 = 564` ms
- `T_total = 440 + 955 + 564 = 1959` ms — within [1700, 2200], no scaling

**Epilogue variant scaling (rise and fade-out only):** The rise and fade-out phase nominals (`D_i_nom`) scale by 1.35× before variation. Variation ranges (`V_i`) do **not** scale — variation magnitude should feel the same in either path. Hold is **not scaled** — epilogue hold is open-ended (runs until FES handoff), so clamping it is meaningless. T_MIN/T_MAX apply to `rise + fade` only in the epilogue path; the hold is excluded from the clamp. Epilogue rise+fade nominal: `(400 + 500) × 1.35 = 1215 ms`, well under T_MAX.

### Formula 2 — Curl Peak Rotation

Rotation angle of the overlay Polygon2D at the curl sweep peak (~300ms into the rise phase).

**Variables:**
- `θ_nom` : nominal peak rotation, degrees (default 4.0)
- `V_θ` : variation range, degrees (default 1.5)
- `r_θ` : per-transition random draw, uniform `[-1.0, 1.0]`
- `θ` : resolved peak rotation

**Formula:**
```
θ = θ_nom + r_θ * V_θ
```

**Example:** `r_θ = -0.4` → `θ = 4.0 + (-0.4)*1.5 = 3.4°`

**Ranges:** at default knobs, resolved `θ ∈ [2.5°, 5.5°]` — below vestibular sensitivity threshold at 2D canvas scale and nominal viewing distance. The vestibular-safe claim holds only at defaults; the knob safe ceilings (`curl_rotation_nominal_deg = 7.0`, `curl_rotation_variation_deg = 3.0`) permit θ_max = 10° and tuning toward that ceiling must be validated visually before shipping.

**Reduced-motion path:** `θ = 0.0` (forced, formula not evaluated).

### Formula 3 — Audio Pitch Scale (true semitone math)

Per-transition pitch variation for the paper-rustle SFX, applied as `AudioStreamPlayer.pitch_scale`. Computed as a true semitone ratio, not linear interpolation — linear pitch interpolation produces asymmetric perceived pitch intervals (prior revision had ±0.04 linear = ±0.68 semitones, factually wrong per spec intent of ±4).

**Variables:**
- `S_range` : nominal semitone range, semitones (default 4.0)
- `r_p` : per-transition random draw, uniform `[-1.0, 1.0]`
- `p` : resolved pitch scale (ratio)

**Formula:**
```
p = 2^(r_p * S_range / 12)
```

**Example:** `r_p = 0.7`, `S_range = 4.0` → `p = 2^(0.7 * 4 / 12) = 2^(0.2333) ≈ 1.175`

**Ranges:** with `S_range = 4.0`, resolved `p ∈ [2^(-4/12), 2^(4/12)] = [0.7937, 1.2599]` — true ±4 semitones, audibly distinct per transition without losing the paper identity of the source.

**Reduced-motion path:** `p = 1.0` (forced; `r_p` not drawn).

**Note on prior variation widths:** A `±4%` linear pitch variation (previously specified) is below the perceptual just-noticeable-difference for most listeners. The true semitone form above crosses JND cleanly.

### Formula 4 — Paper-Breathe Alpha Modulation

During the HOLD phase, the overlay's alpha oscillates subtly to evoke a paper-like breathing texture.

**Variables:**
- `α_base` : hold-phase base alpha (always 1.0)
- `A` : breathe amplitude (default 0.03; per-transition variation ±0.01)
- `P` : breathe period in seconds (default 0.7)
- `t` : seconds since entering HOLD state
- `α(t)` : overlay alpha at time `t`

**Formula:**
```
α(t) = α_base - A * (1 - cos(2π * t / P)) / 2
```

The `(1 - cos)/2` form keeps the pulse nonnegative and anchored at 1.0 on entry (no jump when HOLD begins).

**Example:** at `t = 0.35s`, `A = 0.03`, `P = 0.7`:
- `α(0.35) = 1.0 - 0.03 * (1 - cos(π)) / 2 = 1.0 - 0.03 * 1.0 = 0.97`

**Ranges:** `α(t) ∈ [0.97, 1.0]` at nominal amplitude — imperceptible except over the full pulse.

**Reduced-motion path:** `A = 0` → `α(t) = 1.0` (no modulation).

**Epilogue variant:** `A = 0` (stillness during epilogue hold, as per Core Rule 9).

## Edge Cases

Scope trimmed per CD guidance (r1): save/load-during-transition, viewport-resize handling, focus-loss pause, asset-load failure branches, and duplicate FIRST_REVEAL races were cut as defensive coverage inappropriate for an N=1 gift. What remains are the behaviours the game actually exercises in the happy path plus the epilogue handoff.

| # | Scenario | STUI Response |
|---|---|---|
| E-1 | `scene_completed` fires while STUI is in IDLE, no drag active | Normal path: enter FADING_OUT, begin overlay rise, begin input block. |
| E-2 | `scene_completed` fires while player is mid-drag | Same frame: call `InputSystem.cancel_drag()`. Card eases back to last stable position over 100ms, cleared behind the opaque overlay at t=400ms. No dangling drag ghost. |
| E-3 | `scene_completed` fires while STUI is not IDLE | Ignored (signal-storm guard, Core Rule 13). Logged at debug level. |
| E-4 | `scene_started` fires while STUI is in IDLE | Ignored (handshake mismatch). Logged as warning. |
| E-5 | `scene_started` arrives during FADING_OUT (before hold begins) | Buffered. When FADING_OUT completes, transition directly to FADING_IN, skipping HOLDING. Hold duration = 0 for this transition. |
| E-6 | `scene_started` does not arrive within nominal hold budget | STUI stays in HOLDING; paper-breathe continues; overlay remains opaque until `scene_started` fires. No failsafe timeout — Scene Manager's sync load is authoritative; if it hangs, the real bug is upstream and a frozen page is the honest signal. |
| E-7 | `epilogue_started` fires from any non-EPILOGUE state | If in IDLE: normal epilogue entry. If mid-transition: finish the current rise to full opacity (don't restart), then swap tint to amber, suppress paper-breathe, and enter EPILOGUE. Terminal state — no auto-fade. |
| E-8 | First scene load (boot) — `scene_started` with no prior `scene_completed` | STUI is in FIRST_REVEAL from boot (opaque cream). `scene_started` triggers slow `first_reveal_fade_ms` fade-out, then IDLE. |
| E-9 | `ProjectSettings.stui/reduced_motion_default` changes mid-transition (dev-time only; not player-facing at v1) | Takes effect on the *next* transition. Current transition completes in its original mode. |
| E-10 | `transition-variants.tres` is missing or wrong `class_name` (`as TransitionVariants` cast returns null) | STUI uses hardcoded default tuning knobs and logs a warning at `_enter_tree()`. Color values are validated (clamped to [0,1] per channel); out-of-range entries fall back to default tint. |
| E-11 | `epilogue_cover_ready` is emitted but no FES exists | STUI holds indefinitely in EPILOGUE. Acceptable — FES wiring is a milestone concern, not a runtime failure. |

## Dependencies

### Upstream (STUI depends on these)

| System | Nature | Required Contract |
|---|---|---|
| **EventBus** (autoload) | Signal bus (ADR-003) | Must exist in autoload list before STUI's scene is instanced. Must expose signals: `scene_completed(scene_id: String)`, `scene_loading(scene_id: String)`, `scene_started(scene_id: String)`, `epilogue_started()`. Must also support adding new signals; STUI emits `epilogue_cover_ready()`. |
| **Scene Goal System** (`design/gdd/scene-goal-system.md`) | Signal emitter | Must emit `scene_completed(scene_id)` via EventBus when hidden goal is satisfied. Emission must happen on the same frame the goal transitions to satisfied; STUI relies on this for the satisfaction-peak alignment (Core Rule 3). |
| **Scene Manager** (`design/gdd/scene-manager.md`) | Signal emitter + loader | Must emit `scene_loading(scene_id)` before despawning old cards, `scene_started(scene_id)` after seed cards are placed, and `epilogue_started()` for the terminal scene. Scene Manager owns the load; STUI assumes synchronous load during the HOLDING phase. |
| **Input System** (`design/gdd/input-system.md`) | Method call | Must expose `cancel_drag() -> void` — safe to call when no drag is active (no-op). STUI calls this at frame of `scene_completed` (Core Rule 6). |
| **assets/data/ui/transition-variants.tres** | Config file (optional) | Dictionary keyed by `scene_id`; each value is a dict of per-scene knobs (e.g., `fold_duration_scale`, `paper_tint`). Missing key → `"default"` fallback. Missing file → hardcoded defaults from Tuning Knobs (E-22). |
| **assets/ui/paper_texture.png** (or similar) | Art asset | Seamless cream paper texture used as overlay fill. Missing asset → solid cream ColorRect fallback (E-20). |
| **assets/audio/sfx/page_turn_*.ogg** | Audio assets | Paper rustle / page turn SFX. Multiple variants recommended for non-identical repetition. Missing → no SFX, transition plays silently. |
| **Settings** (system #20, Designed — `design/gdd/settings.md`) | Config read | Settings v1 does NOT expose `reduced_motion` (Settings OQ-3 defers). STUI reads `ProjectSettings.stui/reduced_motion_default` as the authoritative source at v1. Migration: when a schema-v2 Settings bump adds a player-facing reduced-motion toggle, STUI's read-site moves to `SettingsManager.get_reduced_motion()`. |

### Downstream (these systems consume STUI)

| System | Nature | Contract |
|---|---|---|
| **Final Epilogue Screen** (system #18, Designed) | Signal consumer | FES subscribes directly to `EventBus.epilogue_cover_ready()` per ADR-004 §4. STUI's EPILOGUE state holds the amber overlay at full opacity; FES reveals above STUI at layer 20 (ADR-004 §2) without requiring STUI to hand off. STUI and FES are sibling CanvasLayers in the same `gameplay.tscn` — no scene swap occurs. |
| **Save/Progress System** (system #19, Designed) | Observer (no persistence) | Save system does NOT persist STUI state. STUI is stateless across save/load (Core Rule 12). Resume-loaded scenes arrive via the normal `scene_started` path; STUI plays a fresh transition. |
| **Main Menu** (system #17, Designed) | Coordinator | Main Menu presses Start → scene-switches to `gameplay.tscn`. Per ADR-004 §3, `gameplay_root.gd` orchestrates `SaveSystem.load_from_disk` + `apply_loaded_state`, then emits `game_start_requested`. Scene Manager then begins the first (or resumed) scene's load, which STUI picks up normally. Main Menu does not interact with STUI directly. |

### Engine / platform assumptions

- **Godot 4.3** — Tween API (`create_tween()`, chained `.tween_property()`, `Tween.kill()` for cancellation), `CanvasLayer`, `Polygon2D` (with `polygon` vertex array write), `ColorRect`, `AudioStreamPlayer`, `MOUSE_FILTER_STOP`/`MOUSE_FILTER_IGNORE`. All stable in 4.3 per `docs/engine-reference/godot/VERSION.md`.
- **Process mode** — `process_mode = PROCESS_MODE_ALWAYS` on the STUI root so Tweens run even if the game tree is paused. Note: `PROCESS_MODE_ALWAYS` propagates to children — including `RustleAudio` — which is intentional (audio must continue during any future pause overlay).
- **Scene load mechanism** — Scene Manager's responsibility, not STUI's. STUI assumes synchronous load within the HOLDING budget; the mechanism (`ResourceLoader` per ADR-005) is specified in `scene-manager.md`.

### Systems-index note (bidirectional consistency)

This GDD adds STUI as a consumer to the downstream sections of:
- Scene Goal System — already lists STUI in its downstream table (verified in `design/gdd/scene-goal-system.md`)
- Scene Manager — already lists STUI in its downstream section (verified in `design/gdd/scene-manager.md`)

And STUI is referenced by (systems that will list STUI upstream when designed):
- Final Epilogue Screen (system #18)
- Save/Progress System (system #19) — only for the stateless contract assertion

## Tuning Knobs

### Timing knobs

| Knob | Default | Safe range | Effect |
|---|---|---|---|
| `rise_nominal_ms` | 400 | 250–600 | Overlay rise + curl sweep duration. Below 250 feels rushed; above 600 blunts the satisfaction-peak alignment. |
| `rise_variation_ms` | 80 | 0–150 | Per-transition rise variation. 0 = identical each time (fails anti-pattern "no identical repetition"); >150 = feels inconsistent. |
| `hold_nominal_ms` | 1000 | 600–1500 | Hold duration between overlay opaque and fade-out. Below 600 feels perfunctory (album-pause fantasy demands lingering); above 1500 feels like a stall. |
| `hold_variation_ms` | 150 | 0–250 | Per-transition hold variation. Same bounds rationale as rise. |
| `fade_out_nominal_ms` | 500 | 300–800 | Overlay fade-out duration. Below 300 snaps the reveal; above 800 blurs the arrival. |
| `fade_out_variation_ms` | 80 | 0–150 | Per-transition fade-out variation. |
| `total_min_ms` | 1700 | 1400–2000 | Hard floor for total transition duration. Clamped by Formula 1. |
| `total_max_ms` | 2200 | 1900–2600 | Hard ceiling for total transition duration (normal variant). Clamped by Formula 1. Epilogue hold is excluded from this clamp. |
| `first_reveal_fade_ms` | 1200 | 800–2000 | Slow fade-out on game-boot FIRST_REVEAL state (Core Rule 8). Longer here is acceptable — only fires once. |
| `epilogue_time_scale` | 1.35 | 1.1–1.8 | Multiplier applied to rise and fade-out durations for epilogue variant (Core Rule 9). Hold is open-ended. |
| `drag_cancel_ease_ms` | 100 | 50–200 | Time for held card to ease back to stable position after `cancel_drag()`. |

### Visual knobs

| Knob | Default | Safe range | Effect |
|---|---|---|---|
| `overlay_color_cream` | `Color(0.98, 0.95, 0.88)` | warm near-white | Normal transition overlay tint. |
| `overlay_color_amber` | `Color(1.00, 0.92, 0.78)` | warmer cream | Epilogue overlay tint (Core Rule 9). |
| `curl_rotation_nominal_deg` | 4.0 | 2.0–7.0 | Nominal peak rotation of overlay at curl peak. Below 2° is imperceptible; above 7° feels tilted. |
| `curl_rotation_variation_deg` | 1.5 | 0–3.0 | Per-transition rotation variation. |
| `curl_peak_time_frac` | 0.75 | 0.5–0.9 | Fraction of rise phase at which curl reaches peak. 0.75 → peak at ~300ms of 400ms rise. |
| `breathe_amplitude_nominal` | 0.03 | 0–0.08 | Hold-phase alpha pulse amplitude. Above 0.08 the pulse becomes visible as a flicker. |
| `breathe_amplitude_variation` | 0.01 | 0–0.03 | Per-transition amplitude variation. |
| `breathe_period_sec` | 0.7 | 0.4–1.5 | Pulse period during HOLD. Harmonically paired with nominal hold duration. |
| `rise_ease_curve` | `EASE_IN_OUT` + `TRANS_QUAD` | — | Overlay rise Tween curve. Fixed by design — do not vary. |
| `fade_ease_curve` | `EASE_OUT` + `TRANS_CUBIC` | — | Overlay fade-out Tween curve. Fixed by design — do not vary. |

### Audio knobs

| Knob | Default | Safe range | Effect |
|---|---|---|---|
| `pitch_semitone_range` | 4.0 | 0.0–6.0 | Per-transition pitch range in semitones (Formula 3). 0 disables variation; at 6.0 the rustle reaches a tritone spread (p ∈ [0.707, 1.414]) — still reads as paper but near the identity edge; values above 6.0 are outside safe range. |
| `rustle_volume_db` | -12.0 | -24.0 – 0.0 | Paper rustle SFX gain. Subtle by default. |
| `sfx_variant_count` | 3 | 1–8 | Number of paper-rustle audio variants. Higher = less identical repetition. |

### Accessibility knobs

| Knob | Default | Safe range | Effect |
|---|---|---|---|
| `reduced_motion_rise_ms` | 400 | 250–600 | Rise duration in the reduced-motion page-lift path (Core Rule 11). Linear ease. |
| `reduced_motion_hold_ms` | 600 | 300–1000 | Hold duration in reduced-motion path. |
| `reduced_motion_fade_ms` | 400 | 250–600 | Fade-out duration in reduced-motion path. Linear ease. |

### Input & structural knobs

| Knob | Default | Safe range | Effect |
|---|---|---|---|
| `input_block_scope` | `all` (mouse + keyboard) | `all` or `mouse_only` | Scope of input swallowed during transitions (Core Rule 7). `mouse_only` would let Escape/keyboard through — NOT recommended until Settings is designed. |
| `canvas_layer_value` | 10 | 5–15 | Godot `CanvasLayer.layer`. 10 places STUI above gameplay (layer 0) but below reserved HUD/debug range (20+). |

### Per-scene override (transition-variants.tres)

Per-scene knobs keyed by `scene_id`. Only names listed here may be overridden; any other keys are ignored.

| Per-scene knob | Type | Overrides |
|---|---|---|
| `fold_duration_scale` | float (0.6–1.5) | Multiplier applied to `rise_nominal_ms`, `hold_nominal_ms`, `fade_out_nominal_ms` for that scene's outgoing transition |
| `paper_tint` | `[r, g, b]` float array | Overrides `overlay_color_cream` for this scene's outgoing transition |
| `sfx_variant_id` | string | Selects a specific rustle SFX variant by name, e.g., `"page_turn_paper_heavy"` |

The `transition-variants.tres` file is a `TransitionVariants` Resource per ADR-005:

```gdscript
class_name TransitionVariants extends Resource
@export var variants: Dictionary = {}
# variants = { "scene_id": { "fold_duration_scale": float, "paper_tint": Color, ... }, ... }
```

Example content (authored in the Godot inspector or `.tres` file):
```
variants = {
  "home":    { "fold_duration_scale": 1.0, "paper_tint": Color(0.98, 0.95, 0.88) },
  "park":    { "fold_duration_scale": 0.9, "paper_tint": Color(0.95, 0.98, 0.90) },
  "default": { "fold_duration_scale": 1.0, "paper_tint": Color(0.98, 0.95, 0.88) }
}
```

## Visual/Audio Requirements

### Visual requirements

| Asset | Purpose | Spec |
|---|---|---|
| `paper_texture.png` | Overlay fill during rise/hold/fade | Seamless (tileable) cream paper texture. Grain subtle but present — should read as handmade paper, not cardstock. Resolution ≥ 1024×1024 to avoid visible tiling at 1080p. Sample color `(0.98, 0.95, 0.88)` as base tone. |
| ~~`paper_curl_shape`~~ | Removed | The curl is now produced by per-vertex y-displacement on the `Overlay` Polygon2D itself (Core Rule 4). No separate curl asset. If a drop-shadow is desired under the leading edge, bake it into `paper_texture.png`'s right-hand column. |
| `paper_texture_amber.png` (or tint) | Epilogue variant | Either a distinct amber paper asset OR the same `paper_texture.png` with `modulate = Color(1.00, 0.92, 0.78)`. Single asset + tint is preferred (saves asset work; matches Core Rule 9). |

### Visual direction notes

- Paper grain must read as **hand-felt**, not industrial. Avoid sharp noise; prefer soft, slightly irregular fiber texture.
- No sharp edges on the curl shape — a real page turn has a soft rolling leading edge.
- No drop shadows that imply a separate UI layer on top of the world. The overlay is *the page*, not *above the page*.
- Color palette: stay in warm cream/amber family. Cold or pure white reads as loading-screen UI chrome — violates Pillar 3.
- No logo, no brand marks, no text on the overlay.

### Audio requirements

| Asset | Purpose | Spec |
|---|---|---|
| `page_turn_rustle_A.ogg` | Primary paper rustle (rise phase) | 600–900ms, gentle paper movement. Low-frequency rumble minimal; mid/high-frequency rustle prominent. No music, no instrumentation. |
| `page_turn_rustle_B.ogg` | Variant | Different paper fold, same duration band. Provides non-identical repetition (Core Rule 10, Pillar 4). |
| `page_turn_rustle_C.ogg` | Variant | Third variant, slightly heavier (e.g., thicker paper stock feel). |
| `page_settle_A.ogg` | Page lands (end of rise phase, ~400ms mark) | Short (150–300ms), soft settle/thud. The sound of a page arriving in its final position. |
| `page_settle_B.ogg` | Variant | Alternate settle. |
| `epilogue_paper_breath.ogg` (optional) | Epilogue hold ambient | Very low-level sustained paper/fabric ambient. Fills the silence during the open-ended epilogue hold. Looped, tempo-neutral. |

### Audio direction notes

- **Synchronous with animation phase**, not ambient under the whole beat. Rustle fires at t=0 and plays through the rise; settle fires at t=~400ms (rise completion).
- **No musical sting, no chime, no whoosh.** A chime on scene complete would collapse the entire fantasy into a celebration UI cue.
- **No mouth sounds, no human voice.** Even a breath-like sample would pull toward "spirit/soul" territory which overreaches for this design.
- **Pitch variation per Formula 3** — each transition draws a new pitch within ±4 semitones of nominal (ratio form `2^(r * S_range / 12)`, default `S_range = 4`). Combined with variant cycling (`sfx_variant_count`), gives 3×variants × continuous pitch = effectively non-repeating.
- **Audio bus routing**: paper rustle and settle on an `SFX_UI` bus; epilogue ambient on its own `AMBIENT` bus so volume can be independently controlled.

### First-reveal audio

The FIRST_REVEAL fade-out plays **no SFX** — no rustle, no settle. The boot moment is silent except for whatever ambient the game scene itself brings in. This protects the first moment from feeling mechanical.

### Reduced-motion audio

In reduced-motion mode:
- Rustle plays at nominal pitch only (no variation) — Core Rule 11
- Settle may be omitted entirely (short crossfade does not warrant a settle beat)
- Epilogue ambient still plays

## UI Requirements

### UI layout

STUI renders into a single `CanvasLayer` (layer=10) with the following structure:

```
SceneTransitionUI (CanvasLayer, layer=10, process_mode=ALWAYS)
├── InputBlocker      (ColorRect, full_rect, modulate.a=0)
├── Overlay           (Polygon2D, textured with paper_texture.png, 12-segment strip, modulate.a=0 initially)
└── RustleAudio       (AudioStreamPlayer, bus=SFX_UI)
```

**Overlay geometry (Polygon2D)**: 13 top-edge vertices + 13 bottom-edge vertices = 26 polygon points forming a 12-segment vertical strip that spans the viewport. The leading edge is segment 0 (rightmost column of vertex pairs when paper enters from right); the trailing edge is segment 12. The curl is produced by animating the y-displacement of vertices in segments 0–3 (the leading 4 columns) as a function of the curl envelope (Formula 2). No child curl shape — the single Polygon2D owns the deformation.

- No HUD elements, no labels, no buttons, no widgets.
- No ability to skip, no progress indicator, no "tap to continue" affordance.
- No cursor change during transitions (the existing system cursor remains; input-swallow handles interaction).

### Z-ordering contract

- `CanvasLayer.layer = 10` — above gameplay layer (0), below reserved HUD range (20+)
- Within STUI: `InputBlocker` and `Overlay` are siblings under the CanvasLayer. Because `InputBlocker` is a Control and `Overlay` is a Node2D (Polygon2D), z-ordering between them is implementation-defined in Godot — set `z_index` explicitly: `InputBlocker.z_index = 0`, `Overlay.z_index = 1`. No CurlShape exists (see Core Rule 4).
- The Final Epilogue Screen (system #18, Designed) renders at `CanvasLayer = 20` per ADR-004 §2 — above STUI's `CanvasLayer = 10`. FES and STUI coexist inside the same `gameplay.tscn`; no scene swap occurs when FES reveals.

### Viewport responsiveness

- `anchors_preset = PRESET_FULL_RECT` on `InputBlocker`.
- Polygon2D `Overlay` vertex positions are computed from `get_viewport().size` at each transition start — no hardcoded pixel coordinates.
- Mid-transition viewport resize handling was cut from scope (r1): the target player is not expected to resize the window mid-page-turn, and defensive coverage adds complexity without proportional gift value.

### Input affordance

- During transitions (any state except IDLE): `InputBlocker.mouse_filter = MOUSE_FILTER_STOP`. All clicks and drags are absorbed; no visual feedback.
- During IDLE: `InputBlocker.mouse_filter = MOUSE_FILTER_IGNORE`. Input passes through untouched.
- No keyboard focus is ever taken by STUI. It does not intercept `_input()` or `_gui_input()` callbacks — the ColorRect + MOUSE_FILTER_STOP pattern is sufficient and doesn't steal focus from any underlying game UI.

### Text, localization, accessibility

- **No text content anywhere in STUI.** This is load-bearing: Pillar 3 (Discovery Without Explanation) forbids explanatory chrome, and a text-free overlay localizes for free.
- **Screen reader**: STUI has no aria-role equivalent. It's a purely visual moment. A visually-impaired player anchor for the transition should come from the audio layer (rustle + settle SFX), not from STUI-authored accessibility text.
- **Colorblind considerations**: the cream/amber distinction between normal and epilogue variants is small. The only non-color reinforcement is **timing** — normal transitions run ~1.9s (bounded [1700, 2200] ms), while the epilogue rise runs ~1.35× longer and the hold is open-ended. Paper-breathe is **not** a discrimination cue for epilogue because it is explicitly disabled in the epilogue variant (Core Rule 9). For deuteranopia/protanopia viewers, timing alone is the cue — acceptable for an N=1 gift but flagged as a thin accessibility surface. If epilogue readability matters later, consider a distinctly different overlay color (not just warm-shift) or an audio-layer signal.
- **Reduced motion** per Core Rule 11 and Tuning Knobs — covered elsewhere.

### Debug / inspector affordances

- A debug-only `@export var debug_draw_state: bool = false` — when true, renders current state name (e.g., "FADING_OUT") as small text in a corner. Stripped from release builds via Godot export filter.
- A debug-only method `_debug_force_transition(scene_id: String)` that simulates `scene_completed` for that scene without requiring SGS to fire. Test seam only; not exposed to gameplay.

## Acceptance Criteria

Scope trimmed to 20 testable behavioural assertions per CD guidance (r1). Previous 45-AC surface included untestable predicates and brittle internal-node introspection; for an N=1 gift game, manual Ju-facing sign-off beats autoload test infrastructure.

### State machine & signals (happy path)

- **AC-001** `[Logic]` STUI subscribes to EventBus signals in `_enter_tree()` — verifiable by emitting `scene_completed` in the same frame STUI is instanced and asserting the handler ran. This is the SGS-ordering-race fix.
- **AC-002** `[Logic]` `scene_completed` in IDLE → STUI transitions to FADING_OUT same frame; `InputBlocker.mouse_filter` becomes `MOUSE_FILTER_STOP`.
- **AC-003** `[Logic]` FADING_OUT Tween completion → HOLDING with `Overlay.modulate.a == 1.0`.
- **AC-004** `[Logic]` `scene_started` in HOLDING → FADING_IN.
- **AC-005** `[Logic]` FADING_IN Tween completion → IDLE with `Overlay.modulate.a == 0.0` and `InputBlocker.mouse_filter == MOUSE_FILTER_IGNORE`.
- **AC-006** `[Logic]` `epilogue_started` in IDLE → EPILOGUE; after the rise Tween completes, `Overlay.modulate` carries amber tint and `EventBus.epilogue_cover_ready` is emitted exactly once.
- **AC-007** `[Logic]` Signal-storm guard: `scene_completed` or `scene_loading` emitted while STUI is not IDLE produces no state change and no new Tween.
- **AC-008** `[Logic]` `scene_started` arriving during FADING_OUT is buffered; on FADING_OUT completion, STUI transitions directly to FADING_IN without entering HOLDING (E-5).

### Input behaviour

- **AC-009** `[Logic]` `scene_completed` while a drag is active → `InputSystem.cancel_drag()` called exactly once, same frame.
- **AC-010** `[Logic]` In any non-IDLE state, a mouse-button `InputEvent` is absorbed by `InputBlocker` and does not reach underlying controls.

### Timings & formulas

- **AC-011** `[Logic]` Formula 1 clamp: when `Σ D_i < T_MIN` (1700ms) all phases scale up to reach T_MIN; when `Σ D_i > T_MAX` (2200ms) scale down to T_MAX. Epilogue hold is excluded from the clamp.
- **AC-012** `[Logic]` Formula 3: with `S_range = 4.0` and `r_p = 1.0`, resolved pitch equals `2^(4/12) ≈ 1.2599` (±0.001 tolerance). With `r_p = -1.0`, resolved pitch equals `2^(-4/12) ≈ 0.7937`. With `reduced_motion = true`, pitch is exactly 1.0.
- **AC-013** `[Logic]` Formula 4 anchor: paper-breathe alpha at `t = 0` in HOLDING equals exactly 1.0; alpha remains in `[1.0 - A, 1.0]` for all t.
- **AC-014** `[Logic]` Reduced-motion path: when `reduced_motion == true`, transition total equals `reduced_motion_rise_ms + reduced_motion_hold_ms + reduced_motion_fade_ms` (400+600+400 = 1400ms default), curl vertex displacement is zero, and paper-breathe is disabled.

### First-reveal & epilogue

- **AC-015** `[Logic]` On first `scene_started` of a new session, STUI fades opaque cream to `alpha == 0.0` over `first_reveal_fade_ms` with no SFX, then enters IDLE.
- **AC-016** `[Logic]` In EPILOGUE, paper-breathe is not applied (alpha constant at 1.0 throughout the open-ended hold).

### Integration

- **AC-017** `[Integration]` With a real EventBus autoload, emitting `scene_completed("home")` then `scene_started("park")` drives IDLE → FADING_OUT → HOLDING → FADING_IN → IDLE within total_min_ms..total_max_ms wall-clock budget. This is the full happy-path smoke test.

### Visual/feel (advisory — Ju-facing sign-off)

- **AC-018** `[Visual/Feel]` The epilogue transition reads as heavier and warmer than a normal transition without using any text, burst VFX, chime, or celebration cue. Chester's sign-off required before Alpha; Ju's reaction is the ultimate test.
- **AC-019** `[Visual/Feel]` No transition reads as a loading screen. Anti-pattern check: no spinner, no progress bar, no "Loading…", no percentage indicator appears at any point in the STUI visual.

### Negative assertions

- **AC-020** `[Logic]` STUI never writes save-state, never calls `get_tree().change_scene_to_*`, never emits `scene_loading`/`scene_started`/`scene_completed`, and never creates a text-bearing Node in release builds. (The only signal STUI emits is `epilogue_cover_ready`; debug builds may render `debug_draw_state`.)

## Open Questions

- **OQ-1** **Art asset pipeline handoff for paper texture** — Who authors `paper_texture.png` and the `paper_curl_shape`? Chester as art-director, or a commissioned asset? Either way, the texture must land before Vertical Slice milestone. Blocking-for-slice, not blocking-for-design.

- **OQ-2** **SFX variant sourcing** — Three rustle variants + two settle variants needed per Visual/Audio Requirements. Source options: (a) royalty-free foley libraries (fast, may lack handmade feel); (b) Chester self-record (fits Pillar 4 "Personal Over Polished"); (c) commission. Recommendation: (b) — rustle sounds are trivial to self-record and carry Ju-facing authenticity. Resolve before Vertical Slice.

- **OQ-3** **Epilogue ambient audio — required or optional?** `epilogue_paper_breath.ogg` is listed as optional. If the epilogue hold is 3+ seconds of silence, does that land as "reverence" (intended) or "did the game freeze"? Resolve through playtest with Ju once Final Epilogue Screen (system #18) is designed — without FES, the hold is open-ended and silence is unbounded, which may actually read as a bug.

- **OQ-4** **Scene Manager OQ-4 cross-reference** — Scene Manager's Open Question 4 asks whether `scene_completed` payload should be enriched (reward card? animation variant?). STUI's position is **no enrichment** — STUI looks up per-scene config via `transition-variants.tres`. This should be formalised as a Scene Manager GDD edit: close SM's OQ-4 with "enrichment rejected; presentation systems own their own config data" and cross-reference this GDD. Action item when this GDD is approved.

- **OQ-5** ~~**First-reveal edge case on New Game vs Load**~~ **RESOLVED 2026-04-21**: Main Menu (#17) and Save/Progress (#19) are now Designed. FIRST_REVEAL fires on the first `scene_started` of a session regardless of whether the session is a new game or a resumed save. A loaded save does not "feel different" — Ju presses Start, a scene reveals, whether from index 0 or index 4. This aligns with Settings GDD's framing (no "Continue" button — Start always resumes).

- **OQ-6** **EPILOGUE handoff contract with FES** — When FES GDD (#18) is authored, formalise the handoff: does STUI fade out when FES signals completion, or does FES cover STUI and STUI never fades? Currently STUI holds indefinitely after emitting `epilogue_cover_ready`. Must be resolved when FES is designed.

- **OQ-7** **GameSettings provisional source** — Settings (#20) is now Designed but intentionally does NOT expose `reduced_motion` at v1 (see Settings OQ-3). STUI continues to read `ProjectSettings.stui/reduced_motion_default` as the authoritative source. When a future Settings schema v2 bump adds a player-facing reduced-motion toggle, STUI's read-site should be migrated to call `SettingsManager.get_reduced_motion()`. Tracked as a migration task only if motion scope expands enough to warrant player exposure.
