# Cross-GDD Review Report — 2026-04-21 (Re-verification)

> **Date**: 2026-04-21 (fresh session, post-cleanup)
> **GDDs Reviewed**: 20 system GDDs + `game-concept.md` + `systems-index.md` + `ADR-003-signal-bus.md` + `ADR-004-runtime-scene-composition.md`
> **Skill**: `/review-all-gdds` (full mode)
> **Predecessor Report**: `gdd-cross-review-2026-04-21.md` (FAIL — 6 blockers)
> **Verdict**: **PASS** — all 6 blockers from the predecessor report verified resolved. Two design-theory warnings explicitly deferred as creative/production decisions; none block `/create-architecture` or `/create-epics`.

---

## Summary

Independent re-verification of the cleanup pass that followed the 2026-04-21 FAIL report. Every blocker resolution claimed in `production/session-state/active.md` was checked against the actual GDD/ADR text. **Result: every claim holds.** The new ADR-004 is internally consistent, properly cited by every dependent GDD, and resolves the three load-bearing contradictions (epilogue handoff, autoload order, and Main Menu OQ-1) in one document. ADR-003's signal declarations now cover all 25 signals referenced across GDDs with a maintenance rule that prevents the next regression.

The 6-parameter `combination_executed` cascade is consistent across emitter (ITF), all four declared listeners (SBS, SGS, HS, MUT), and the bus declaration (ADR-003). The Reset Progress flow has a correctly-ordered call chain — `clear_save() → reset_to_waiting() → set_resume_index(0) → load_save_state({})` — that does not trip SM's `_state == WAITING` assertion. The save-write race is closed via a documented listener-ordering contract anchored to the autoload order, plus an explicit `save_now()` synchronous path for the epilogue hook where no further `scene_completed` will fire.

What carries forward as known follow-ups (not blockers): W-D1 (`discovery_milestone_reached` rename — creative call) and W-D2 (STUI polish budget — production decision). Both are acknowledged in the original report as deferred and remain so.

---

## Blocker re-verification (6 of 6 resolved)

| ID | Original blocker | Where verified |
|---|---|---|
| **B-1** | ADR-003 signal declarations incomplete | `docs/architecture/ADR-003-signal-bus.md` lines 27–85 — all 25 signals declared, grouped by domain, with maintenance rule (lines 87–91). `combination_executed` is correctly 6 params (lines 42–49). |
| **B-2** | Epilogue handoff contradiction (FES ↔ SM ↔ STUI) | `ADR-004` §4 (lines 149–187) — FES pre-instanced as CanvasLayer sibling at layer 20 inside `gameplay.tscn`; STUI alive when emitting `epilogue_cover_ready`; no `change_scene_to_file` invoked. FES Rule 2 (lines 32–36) carries an explicit supersession note. STUI's downstream FES row cites ADR-004 §4. SM Core Rule 9 handles saved-completed-game resume directly to Epilogue. |
| **B-3** | Reset Progress mid-gameplay broken | SM Core Rule 8 (lines 64–74) — `reset_to_waiting()` clears cards, resets state, re-arms `CONNECT_ONE_SHOT`. SaveSystem Rule 10 (lines 92–99) calls `reset_to_waiting()` *first*, then `set_resume_index(0)` — call ordering is load-bearing and explicitly documented. Settings Rule 6 routes Reset commit through `SaveSystem.clear_save()`. AC-SP-24 captures the full sequence. |
| **B-4** | Autoload ordering contradictory | `ADR-004` §1 (lines 80–100) — single canonical 12-autoload order with rationale for SaveSystem-after-SceneManager. SaveSystem Rule 1 cites ADR-004; Settings Rule 9 cites ADR-004; SM Edge Cases (Godot Lifecycle bullet) cites ADR-004 §1. No GDD restates a competing order. |
| **B-5** | `combination_executed` 4→6 param cascade | ITF Rule 4 + Signals Emitted table + every template execution sequence (Additive/Merge/Animate/Generator) all emit 6 params. SBS Rule 4 + Interactions + Dependencies — 6-param handler explicit. SGS Rule 4 (`find_key`/`sequence`) + Interactions + Dependencies + OQ-2 — all 6-param. HS Rule 3 + Interactions + Dependencies — 6-param handler explicit. ADR-003 declares 6 params with arity-strict warning. |
| **B-6** | Save-write vs SM-increment race | SaveSystem Rule 3 (lines 38–39) documents listener-ordering contract anchored to autoload order. Rule 10b adds `save_now()` synchronous API. ADR-004 §5 makes the contract architectural and §6 wires `final_memory_ready → save_now()` via `gameplay_root.gd`. AC-SP-16 verifies post-increment semantics. |

---

## Consistency warning re-verification (9 of 9 resolved)

| # | Item | Status |
|---|---|---|
| W-C1 | FES "Save/Progress not yet designed" | ✓ FES Dependencies + Save/Progress System now correctly listed as Designed 2026-04-21 |
| W-C2 | MUT stale "FES not yet authored" + OQ-10 + OQ-11 | ✓ OQ-10 RESOLVED (cites ADR-004 §1), OQ-11 RESOLVED (FES consumer named) |
| W-C3 | STUI OQ-5/OQ-7 referencing #17/#19/#20 as undesigned | ✓ OQ-5 RESOLVED, OQ-7 acknowledges Settings Designed (defers reduced_motion intentionally) |
| W-C4 | SM Interactions table stale `scene_loading` listener for STUI | ✓ SM Interactions row for STUI now reads "scene_started + epilogue_started... `scene_loading` subscription was dropped" |
| W-C5 | SBS stale Hint System `bar_values_changed` consumer row | ✓ SBS Interactions + Downstream rows updated; Hint System cross-references "RESOLVED 2026-04-21" |
| W-C6 | ITF stale Card Engine `card_id` cross-system conflict note | ✓ ITF Rule 5 carries strikethrough + RESOLVED note |
| W-C7 | Hint System Overview contradicting Rule 3 | ✓ Overview now correctly states "listens to `combination_executed` from ITF" |
| W-C8 | Audio Manager `fade_out_all` API undeclared | ✓ Tuning Knobs §"Public API" lists `fade_out_all`; AC-AM-17/18/19 added |
| W-C9 | Settings vs STUI `reduced_motion` ownership division | ✓ Settings OQ-3 + STUI OQ-7 explicitly state Settings v1 does NOT expose; STUI continues to read `ProjectSettings.stui/reduced_motion_default`. Migration path noted. |

---

## Design-theory warning re-verification (1 of 3 resolved; 2 deferred)

| # | Item | Status |
|---|---|---|
| **W-D3** | Hint System flat global `stagnation_sec` | ✓ **RESOLVED** — Hint System Tuning Knobs adds per-scene `hint_stagnation_sec` read from `assets/data/scenes/[scene_id].tres` (SceneData Resource per ADR-005) with system-default fallback to 300s |
| W-D1 | MUT `discovery_milestone_reached` percentage-derived signal | ⚠ **DEFERRED** — `_milestone_pct = [0.15, 0.50, 0.80]` machinery still present. The anti-celebration rule remains a documented constraint without a code-level guard. Rename to `narrative_beat_reached(beat_id)` or removal requires a creative-director decision and ripples through ADR-003 + MUT save schema. Explicitly carried forward in the session log. |
| W-D2 | STUI polish budget vs Pillar 4 | ⚠ **DEFERRED** — Polygon2D 12-segment vertex curl + per-vertex y-displacement + semitone pitch math + reduced-motion path remain in spec. r1 trim already applied (45 ACs → 20). Production decision for a later milestone review. |

Both deferrals are appropriate: neither blocks architecture, and both require non-architectural judgment (creative direction / scope-vs-polish trade-off). They should be revisited at appropriate milestones, not in a cleanup pass.

---

## Pillar alignment & player-fantasy coherence

Re-confirmed against the 20 system GDDs and `game-concept.md`:

- **Anti-pillar violations**: NONE.
- **Pillar coverage**: every system maps to at least one of the four pillars; no orphan systems.
- **Player fantasy coherence**: COHERENT. The four pillars (Recognition Over Reward / Interaction Is Expression / Discovery Without Explanation / Personal Over Polished) read as one voice across all 20 systems. Settings, the most utility-focused system, explicitly defers to Pillar 4 ("utility drawer that stays closed almost all the time").
- **MUT W-D1 caveat**: the percentage-milestone machinery does not in itself violate Pillar 3 — the GDD enforces silent-only consumers. The risk is downstream code drift, not present design.

---

## Cross-system scenario re-walkthrough (spot checks)

The original report listed 17 additional cross-system scenario blockers and 11 warnings beyond the top-6. The cleanup pass primarily addressed the top-6; the scenario findings are partially addressed by ADR-004's structural changes. Spot-checked status:

| Scenario item | Status |
|---|---|
| CanvasLayer z-order collision (Settings/STUI both layer 10) | ✓ ADR-004 §2 + Settings Rule 9 — Settings panel host now layer 15, above STUI's 10, below FES's 20 |
| FES `_enter_tree()` guard race with MUT save-state load | ✓ ADR-004 §2 — FES pre-instanced; one-shot via `CONNECT_ONE_SHOT` on `epilogue_cover_ready`; no `_enter_tree` guard needed (FES Rule 13 RESOLVED note) |
| Quit during FES fade-in leaves `_final_memory_earned` unpersisted | ✓ ADR-004 §6 — `gameplay_root.gd` connects `final_memory_ready → SaveSystem.save_now()`; Save/Progress Rule 3 + Rule 10b implement the synchronous path |
| `clear_all_cards()` during Transitioning may emit spurious `combination_executed` | Partial — ITF `Suspended` state (existing Rule + States table) blocks `combination_attempted` during transition. Mid-`Executing` cards on transition entry are an open ITF concern; not promoted to a blocker. |
| **In-flight card drag on Settings open** | ⚠ **NOT FULLY ADDRESSED** — Settings Rule 5 absorbs *future* clicks via the dim overlay, but does not call `InputSystem.cancel_drag()` on panel open. A card already in `Dragged` state at the moment Settings opens may be left in an ambiguous mid-drag state. Recommendation: add a one-line companion edit to Settings Rule 5: "On gear press, call `InputSystem.cancel_drag()` before instancing the panel." Severity: ADVISORY — does not block architecture; surfaces as a story-time question. |

The remaining cross-system scenario items from the original report are either (a) already covered by ADR-004's structural changes, or (b) judged by the cleanup pass as advisory rather than blocking. None re-promote to BLOCKER status.

---

## Minor advisory observations (not blockers)

1. **Audio Manager status string drift** — `audio-manager.md` header reads "Needs Revision → amended 2026-04-21" while `systems-index.md` lists Audio Manager as "Designed". Cosmetic only; the file is in the correct functional state, but the status string is stale. Recommend a one-character fix when the file is next touched.

2. **Several other GDD status strings** still read "In Design" or "In Review" while the systems-index treats all 20 as "Designed". This drift predates the cleanup pass; the systems-index is authoritative for downstream skills. Worth a sweep at some point.

3. **MUT W-D1 carry-forward visibility** — recommend tracking `discovery_milestone_reached` rename/removal in a TR-registry entry or follow-up GDD task so it does not silently land in code as-is. The original report flagged the risk; deferring is fine if the follow-up is visible.

4. **Settings + in-flight drag** (above) — single-line companion edit recommended.

None of these prevent `/create-epics` or `/create-architecture` from beginning.

---

## Architecture coverage sanity check

`docs/architecture/`:
- ADR-001 (naming conventions) — Accepted
- ADR-002 (card object pooling) — Accepted
- ADR-003 (signal bus, EventBus) — Accepted, expanded 2026-04-21
- ADR-004 (runtime scene composition + autoload order + epilogue handoff) — Accepted 2026-04-21

Four ADRs cover: code style, runtime allocation pattern, signal contract, and runtime composition. The remaining architectural concerns (rendering, save format, content pipeline) are either design-system-owned (Save/Progress GDD specifies its own format) or not yet exercised. `/create-architecture` should be the next pass; this re-verification confirms the GDDs it will read are internally consistent.

---

## GDDs flagged for revision (for systems-index)

| GDD | Reason | Severity |
|-----|--------|----------|
| _(none — all 13 previously-flagged GDDs verified resolved)_ | — | — |

The systems-index can stay at 20/20 Designed.

---

## Verdict: **PASS**

- 6 of 6 BLOCKERS verified resolved with cited evidence in each GDD/ADR.
- 9 of 9 consistency warnings verified resolved.
- 1 of 3 design-theory warnings resolved (W-D3); the other two (W-D1 MUT rename, W-D2 STUI polish budget) are explicitly deferred as non-architectural decisions.
- 1 minor scenario advisory (Settings + in-flight drag) and 1 cosmetic status-string drift (Audio Manager header) do not block architecture.
- 4 ADRs accepted; cross-citations are consistent.

**`/create-epics` is unblocked. `/create-architecture` is also unblocked but lower priority — the existing 4 ADRs cover what the cleanup pass touched; further architecture work is best driven by epic decomposition surfacing the next set of cross-cutting decisions.**

### Carry-forward register (visibility for next sessions)

1. **W-D1** — MUT `discovery_milestone_reached` rename/removal — creative-director call before MVP content authoring locks the signal in.
2. **W-D2** — STUI polish budget review — production decision at first playtest milestone.
3. **Settings + in-flight drag** — one-line companion edit recommended at story time for Settings Rule 5.
4. **Audio Manager status string** — amend file header to match systems-index "Designed" on next touch.
5. **GDD status string drift** — broader sweep (MUT, ITF, SBS, SGS, HS, etc. still say "In Design" / "In Review") — low-priority cosmetic cleanup.
