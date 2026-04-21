# Scene Transition UI — Review Log

Revision history for `design/gdd/scene-transition-ui.md`. Entries are ordered oldest-first.

---

## Review — 2026-04-20 (1st pass) — Verdict: NEEDS REVISION → Revisions applied same session
Scope signal: M (moderate complexity, 4 formulas, 4 dependencies, no new ADR required — uses existing ADR-003 EventBus)
Specialists: game-designer, systems-designer, qa-lead, ux-designer, ui-programmer, godot-specialist, audio-director, creative-director (senior synthesis)
Blocking items: 6 (load-bearing per CD) | Recommended: ~10 | Nice-to-have: ~15
Summary: First-pass adversarial review of the newly-authored STUI GDD. All seven specialists found substantive defects. Cross-specialist convergence highlighted three issues as factually wrong rather than preference: Formula 3 semitone math (claimed ±4 semitones but yielded ±0.68), SGS→STUI `_ready()` ordering race (would silent-fail first transition), and curl-shape dual-path (Polygon2D vs TextureRect coordinate system collision). Creative director's senior synthesis: "STUI delivers Framing B in spirit but the curl spec, Formula 3 math, and SGS ordering race are load-bearing defects; scope should shrink (fewer ACs, no defensive states) rather than grow to match the 1.6s moment's true weight in an N=1 gift." CD overruled qa-lead's request for autoload test infrastructure (recommend cutting AC count instead), audio-director's "optional ambient indefensible" (fine for N=1 playtest), and ux-designer's looked-away/haptic concerns (scope creep for a 1.6s moment in an attentive gift play).

Prior verdict resolved: First review.

**Revisions applied same session — 6 load-bearing blockers + 4 user design decisions:**

- **D-1 (Curl path)**: Polygon2D vertex deformation chosen over TextureRect+shader or downgrade-to-page-lift. Core Rule 4 rewritten: single 12-segment Polygon2D strip, per-vertex y-displacement on leading 4 columns, no child curl shape. TextureRect alternative explicitly documented as rejected (coordinate-collision rationale).
- **D-2 (Formula 3 pitch)**: Widen to true ±4 semitones (ratio-based `2^(r*S/12)`) chosen over linear-soften or ±1.5 compromise. Formula 3 rewritten; example + ranges verified [0.7937, 1.2599]; audio-director's JND concern addressed.
- **D-3 (SGS signal race)**: STUI connects in `_enter_tree()` (local fix, standard Godot pattern) chosen over SGS-defer or belt-and-suspenders. Core Rule 2 rewritten; AC-001 added to verify handler fires when signal is emitted same frame as instancing.
- **D-4 (Scope trim)**: Aggressive cut chosen over moderate/conservative. Removed: focus-loss pause handling, viewport-resize handler, save/load-during-transition, hold_failsafe_ms, RETURN_TO_MENU path, FIRST_REVEAL duplicate-Tween race, scene-ID-mismatch validation, asset-load-failure branches. ACs trimmed 45 → 20. Edge cases 25 → 11. OQs 12 → 8.
- **B-1** (Curl spec): resolved via D-1. Single Polygon2D with vertex deformation pipeline documented.
- **B-2** (Formula 3 math): resolved via D-2. True semitone math; `pitch_semitone_range = 4.0` replaces `pitch_scale_variation = 0.04`.
- **B-3** (SGS ordering race): resolved via D-3.
- **B-4** (Polygon2D vs TextureRect): collapsed to Polygon2D-only per D-1; Visual Requirements and UI Layout updated to match.
- **B-5** (Reduced-motion fantasy): Core Rule 11 rewritten — reduced-motion is now a slowed, simplified page-lift (400ms linear rise + 600ms hold + 400ms linear fade, no curl, no breathe, audio still plays) rather than a crossfade. Preserves Framing B for accessibility users. New tuning knobs `reduced_motion_rise_ms`, `reduced_motion_hold_ms`, `reduced_motion_fade_ms` replace the crossfade/hold pair.
- **B-6** (hold_nominal_ms): raised 700 → 1000 per album-pause fantasy. Phase timing table, Formula 1 nominal table, example calc, and Tuning Knobs all updated. Clamps raised `T_MIN = 1700`, `T_MAX = 2200`. Epilogue clamp excludes hold (documented).

**CD-endorsed Recommended Revisions applied:**
- paper_tint JSON parse validation (clamp to [0,1] per channel, fallback on out-of-range) → E-10
- Tween.kill() named explicitly in engine-assumptions block
- E-5 (buffered scene_started during FADING_OUT) preserved as named edge case
- Scene-load mechanism note added: Scene Manager's responsibility, documented in scene-manager.md

**Cut from scope (explicit anti-scope, per CD):**
- Automated AC-harness infrastructure; manual sign-off + AC-017 integration smoke
- `hold_failsafe_ms` and the 8s force-fade branch (CD: "honest frozen page is better signal than defensive stretch")
- RETURN_TO_MENU / scene-restart handling
- Focus-loss / Alt-Tab pause handling
- Viewport resize during transition
- Save-mid-transition persistence hook
- Skip-transition affordance for replays
- Haptic analog
- Onboarding hint for first-time transition meaning
- Reference-track curation, spectral/reverb/weight audio specs (deferred to playtest)

**Specialist disagreements ruled by CD:**
- qa-lead (wanted autoload test infrastructure + AC rewrites for testability) → CD: cut AC count instead, manual sign-off suffices for N=1
- audio-director ("optional ambient indefensible") → CD: fine to decide during Ju playtest
- ux-designer (looked-away failure, skip for replays) → CD: non-issues for attentive N=1 gift

**Counts after revision:** 13 Core Rules (was 14), 6 States (unchanged), 4 Formulas (unchanged, Formula 3 rewritten), 11 Edge Cases (was 25), 20 ACs (was 45), 8 OQs (was 12). File length reduced ~30%.

Status moved to **In Review** in systems-index.md pending 2nd-pass fresh-session re-review. Recommend `/clear` before next review — this session spawned 7 specialists and applied extensive revisions; clean context needed for the re-review to be independent.

---

## Review — 2026-04-20 (2nd pass, r2) — Verdict: NEEDS REVISION → Revisions applied same session
Scope signal: M (unchanged — no new ADR, no formula-count change)
Specialists: game-designer ✓, systems-designer ✓ | qa-lead, ux-designer, ui-programmer, godot-specialist — **timed out / auth-errored** (infrastructure instability); gap-filled by main-review structural analysis.
Blocking items: 7 (4 stale-artifact editorial + 3 design) | Recommended: ~8 | Nice-to-have: ~3

Summary: r1 landed correct decisions in the rules that matter (CR 2, CR 4, CR 11, Formula 3, timing table) but left four stale-artifact contradictions scattered through supporting sections — Interactions table (line 133 said `_ready()`), Formula 2 header (said "TextureRect"), Z-ordering (said "CurlShape is a child of Overlay"), and Audio notes (said "±4% of nominal"). Each silently re-introduces the pre-r1 bug that the rule above had corrected. Systems-designer surfaced two genuine design defects introduced by the r1 tuning knobs: uncoordinated safe ranges that collapse Formula 1's narrative under joint minima (worst-case clamp stretch ~2.83×) and a `pitch_semitone_range` ceiling (7.0) that self-contradicts its own description ('>7 loses paper identity'). Main-review caught a Godot factual error: CR 7 claimed `MOUSE_FILTER_STOP` swallows keyboard events — it does not in Godot 4.3. Game-designer flagged two design concerns (1000ms hold with imperceptible breathe reading as dead-air; FIRST_REVEAL silent cream fade as wrong opening) — both deferred to playtest per Chester's decision, not applied.

Prior verdict resolved: Yes. All 6 r1 blockers verified intact in the rules; the 4 stale artifacts were contradictions in supporting text only, not reversions of the r1 logic.

**r2 revisions applied (7 blockers):**
- **r2-B1** (line 133): `_ready()` → `_enter_tree()` in Interactions table EventBus row, matching CR 2. `scene_loading` dropped from subscription list (see r2-R3).
- **r2-B2** (line 184): Formula 2 header rewritten to "overlay Polygon2D" — stale TextureRect reference removed.
- **r2-B3** (line 454): Z-ordering section rewritten — CurlShape reference deleted; explicit `z_index` assignment (InputBlocker=0, Overlay=1) added to address Control↔Node2D sibling ordering under one CanvasLayer.
- **r2-B4** (line 418): Audio direction note rewritten from "±4% of nominal" to "±4 semitones of nominal (ratio form `2^(r * S_range / 12)`)" — matches rewritten Formula 3.
- **r2-B5** (Formula 1): joint-knob-constraint rule added (`Σ(D_i_nom − V_i) ≥ T_MIN` must hold after overrides); reduced-motion clamp exemption explicitly stated.
- **r2-B6** (pitch knob): `pitch_semitone_range` safe ceiling 7.0 → 6.0; description updated to name the tritone-spread boundary at 6.0.
- **r2-B7** (CR 7): keyboard-intercept claim retracted. CR 7 narrowed to "mouse and touch only" with rationale that Godot's `MOUSE_FILTER_STOP` blocks only mouse/touch, and that pre-Settings there is no gameplay consequence for keyboard passthrough during transitions.

**r2 recommended revisions applied:**
- **r2-R1** (OQ-6): duplicate of OQ-3 removed; OQs renumbered (was 8, now 7).
- **r2-R2** (epilogue variation scaling): Formula 1 clarified — 1.35× applies to `D_i_nom` only; `V_i` unchanged.
- **r2-R3** (`scene_loading` dead hookup): subscription dropped. CR 2 updated, state-machine transition table row removed, E-3 narrowed, Interactions row amended. Cross-GDD note flagged: Scene Manager's downstream table still lists STUI as a `scene_loading` listener — requires a separate SM edit.
- **r2-R4** (accessibility paragraph, line 473): corrected. Removed wrong claim that paper-breathe reinforces epilogue discrimination (breathe is disabled in epilogue per CR 9); timing named as the only non-color cue.
- **r2-R5** (Formula 2 vestibular claim): annotated as default-only; knob-ceiling caveat added.

**Deferred per Chester (not applied, recorded):**
- Game-designer P-1 (1000ms hold dead-air with A=0.03) — defer to playtest; may raise breathe amplitude or add hold-phase audio cue later.
- Game-designer P-3 (FIRST_REVEAL silent cream fade) — defer to playtest; may add a soft page-settle SFX later.
- Per-scene tint delta subperceptual in example JSON (recommend intentional reauthor) — defer.
- `breathe_amplitude_nominal` knob ceiling 0.08 above "imperceptible" claim — defer.
- Input System `cancel_drag()` contract drift (100ms ease lives in Card Engine, not Input System) — note in session state; address when next touching Input System or Card Engine GDD.
- AC coverage gaps (curl peak timing, organic variation, FIRST_REVEAL no-SFX, E-7 finish-current-rise) — not added; preserving r1's 20-AC aggressive trim per CD.

**Specialist timeouts:** qa-lead, ux-designer, ui-programmer, godot-specialist did not return. Main-review structural pass caught the Godot keyboard-input factual error and the stale-artifact contradictions, but an independent ui-programmer or godot-specialist pass before implementation is warranted.

**Pending cross-GDD edits (carried forward):**
- Scene Manager downstream table to remove STUI from `scene_loading` listeners (r2-R3)
- Scene Manager OQ-4 close-out — "enrichment rejected; presentation systems own their own config data" (STUI OQ-4)

**Counts after r2:** 13 Core Rules (unchanged), 6 States (unchanged), 4 Formulas (unchanged), 11 Edge Cases (unchanged), 20 ACs (unchanged), 7 OQs (was 8 — duplicate removed). Net content change: corrections and clarifications, no new rules or ACs.

Status remains **In Review** in systems-index.md pending Chester approval. A 3rd full-specialist re-review is likely overkill; recommend either `[Accept revisions and mark Approved]` or a targeted ui-programmer/godot-specialist pass in a clean session before implementation.

**Chester's decision:** Accept revisions, mark Approved. Pre-implementation ui-programmer/godot-specialist pass becomes a pre-sprint task.

---
