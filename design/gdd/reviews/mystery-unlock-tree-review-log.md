# Mystery Unlock Tree — Review Log

Revision history for `design/gdd/mystery-unlock-tree.md`. Entries are ordered oldest-first.

---

## Review — 2026-04-18 — Verdict: MAJOR REVISION NEEDED
Scope signal: L (multi-system integration, 3+ formulas, cross-GDD edits to ITF + SGS required)
Specialists: game-designer, systems-designer, qa-lead, godot-specialist, creative-director (synthesis)
Blocking items: 9 | Recommended: 6+
Summary: First-pass review flagged the GDD as structurally strong but insufficiently guarded against silent authoring failures (divide-by-zero in Discovery Percentage, vacuous-truth epilogue cliff, binary completion gate brutal for N=1 audience) and at risk of pillar violation (milestone signals named in ways that invited celebration UI/audio — contradicting Pillar 3 "Discovery Without Explanation"). Additional findings: `force_unlock_all` in a production file is a release-safety landmine; absolute milestone thresholds don't survive content-count changes; signal-parameter expansion (4→6 params) is NOT silently backwards-compatible in Godot 4.3's typed dispatch and requires lockstep consumer updates; several ACs were too vague to test.
Prior verdict resolved: First review

**Revision applied same session** — 9 blockers + 4 user design decisions addressed:
- D-1: Milestones kept + constrained to silent internal use (Pillar-3 constraint paragraphs on Rule 7, Rule 8, Interactions table, Tuning Knobs)
- D-2: `partial_threshold` knob added (default 1.0, recommend 0.80) — softens binary epilogue cliff
- D-3: `epilogue-requirements.json` replaces per-recipe `epilogue_required` flag — single source of truth
- D-4: `milestone_pct` percentages replace absolute `milestone_thresholds` — content-count-robust
- B-1: Discovery Percentage formula guards `R_authored == 0` (AC-048)
- B-5: `force_unlock_all` relocated to `debug-config.json`, excluded from release exports (AC-046/047)
- B-7: Godot 4.3 signal-compatibility edge case documented; AC-037 split into 037a/037b; OQ-7 expanded
- B-8: AC-036 rewritten with concrete `EventBus.is_connected(...)` assertions
- B-9: AC-042/044/045 retagged [Config] → [Logic] with behavioural assertions
- Plus: Inactive→Epilogue and Active→Epilogue transitions formalised (AC-049); OQ-9 (per-memory display names) and OQ-10 (combined autoload manifest) added; ACs grew 47 → 51

Status moved to **In Review** in systems-index.md pending fresh-session re-review.

---

## Review — 2026-04-18 (2nd pass, post-1st-revision) — Verdict: NEEDS REVISION
Scope signal: L (multi-system integration, 4 formulas, cross-GDD ITF edit still required)
Specialists: game-designer, systems-designer, qa-lead, godot-specialist, creative-director (synthesis)
Blocking items: 8 | Recommended: 11 | Nice-to-have: 5
Summary: The 1st-pass revision landed **9 of 9 prior blockers cleanly** — structural spec is now sound. However, the tighter specificity exposed second-order gaps the earlier hand-waves had concealed: (1) ITF signal-compatibility mitigation was partly wrong (`.bind()` cannot absorb trailing args; Godot 4.3 errors at emit-time not connect-time); (2) resolved milestone thresholds could collide post-ceil when `R_authored` is small; (3) `force_unlock_all` bulk-mark asserted signal suppression without specifying the bypass mechanism; (4) `_epilogue_conditions_emitted` one-shot flag was described behaviourally but never declared as a save-state field; (5) `partial_threshold = 0.80` recommendation contradicted the N=1 gift's Pillar-3 player fantasy; (6) `epilogue_conditions_met()` signal had no named downstream consumer; (7) `milestone_id` string derivation was never pinned (AC-008 and Formulas example used different values); (8) RecipeDatabase synchronous-load constraint was implicit. Plus AC-level testability issues (file-fixture [Logic] ACs, brittle handler-name assertions, composite AC-049).
Prior verdict resolved: Yes — all 9 prior blockers landed cleanly; new blockers are second-order, not regressions.

**Revisions applied same session** — 8 blockers + 4 user design decisions + 11 recommended + 5 nice-to-haves:
- D-5: `partial_threshold` default stays `1.0`; `0.80` repositioned as OQ-2-reachability-only recovery
- D-6: `epilogue_conditions_met()` retained as reserved engine-prep hook with pending-consumer note; OQ-11 added
- D-7: `milestone_id` pinned as `"milestone_" + str(i)` (0-indexed); AC-008 + Formulas example aligned
- D-9: `_inject_config()` + `_inject_debug_config()` test seams added; AC-044/045/046/047 rewritten to use them, kept [Logic]
- B-1: Godot 4.3 signal-compat edge block rewritten — emit-time dispatch error; removed incorrect `.bind()` option; OQ-7 migration-path note updated
- B-2: Rule 8 + Formulas + Edge Cases document post-resolution dedup for colliding milestones; AC-052 added
- B-3: New Rule 9 specifies `force_unlock_all` bulk-load bypass with `_suppress_signals` flag; AC-047 rewritten
- B-4: `_epilogue_conditions_emitted` flag defined, persisted in save state, guarded in Rule 3 Step 9; AC-053 added
- B-8: Hard RecipeDatabase synchronous-load constraint added to Dependencies
- Plus: AC-014 observability rewrite; AC-021 warning names scene_id; AC-032 round-trip extended; AC-036 callable-agnostic + [Integration]-only constraint; AC-049 split into 049a/049b; AC-050 deferred to OQ-2; AC-054 mid-session suppression at threshold=0.0; AC-055 experiential playtest AC; OQ-3 scope expanded to cycles; typed-array write discipline; threading caveat; `_enter_tree()` rationale; per-preset export filter note; milestone-before-epilogue ordering contract; `requires_recipes: []` authoring guidance.
- ACs grew 51 → 55; OQs grew 10 → 11; file length 623 → 690 lines.

Status remains **In Review** in systems-index.md pending 3rd-pass fresh-session re-review.

---

## Review — 2026-04-20 (3rd pass, post-2nd-revision) — Verdict: NEEDS REVISION (minor) → Accepted as Approved
Scope signal: L (unchanged — multi-system integration, 4 formulas, cross-GDD ITF + SGS edits still pending per OQ-7 / OQ-8)
Specialists: game-designer, systems-designer, qa-lead, godot-specialist, creative-director (synthesis)
Blocking items: 5 (deferred as advisory by user decision) | Recommended: 16 | Nice-to-have: 5
Summary: The 2nd-pass revision closed all 8 prior blockers cleanly. The 3rd pass found five additional schema-specificity and AC-correctness gaps — not regressions, further exposure of sub-specificity the tighter document made testable. Creative director's synthesis: "This is a well-converged document — the 3rd pass is finding schema-specificity gaps, not design flaws." Chester chose to accept the GDD and advance to the next system rather than apply another revision pass; the 5 blockers are documented here for resolution at implementation time.

**Blockers deferred to implementation (advisory):**
- B-1: AC-036 GDScript API error — `c.callable.get_object()` fails on Dictionary (must be `c["callable"].get_object()`); class-vs-autoload-instance comparison also wrong. Flagged by both qa-lead and godot-specialist.
- B-2: `get_save_state()` schema never tabulated — blocks AC-032 and AC-053 testability; no key names, types, or restoration rules defined.
- B-3: No [Logic] AC for malformed `carry_forward` non-Array input — `get_carry_forward_cards()` will crash on bad scene JSON.
- B-4: No [Logic] AC for `load_save_state()` with non-Dictionary input — corrupted save crashes on first key access.
- B-5: No persisted `_fired_milestone_indices` — AC-035's "no re-fire after load" only coincidentally protected by equality-check `D == T_i`.

**Closed design-decision challenges (creative-director ruled D-5 and D-6 stand):**
- game-designer argued `partial_threshold=1.0` risks silent gift failure if Ju naturally misses one Chester-chosen recipe, and that milestones + `epilogue_conditions_met()` lack named consumers. Creative director ruled these were deliberate 2nd-pass decisions made with full trade-off awareness; Pillar 3 + N=1 context make "every authored memory matters" a legitimate player-experience rationale. Reopening closed decisions on 3rd pass would create churn that undermines the pillar structure.

**Notable non-blocking findings documented for future passes:**
- Line 386 contains two doc errors: the `_enter_tree()` autoload-ordering rationale is factually wrong (MUT's `_enter_tree()` fires *after* EventBus `_ready()` returns, not before all autoload `_ready()`s); and "Scene Manager uses `call_deferred`" contradicts scene-manager.md which uses `await get_tree().process_frame`.
- AC-055 is structurally unfalsifiable ("fails only if system disrupts the moment") — creative director recommended relocating to Player Fantasy section as a design test, not an AC. Left in place per user decision.
- systems-designer identified 15 sub-specificity gaps (milestone dedup-vs-ascending sequencing, duplicate `requires_recipes`, `partial_threshold` degeneracy at R_total=1, stale-prune contiguity, `scene_started(same_scene_id)`, `get_carry_forward_cards()` behavior in Epilogue) — all Recommended, none blocking.
- godot-specialist flagged `_suppress_signals` exception-safety (no GDScript try-finally), unspecified JSON load mechanism (`FileAccess + JSON.parse_string` vs `ResourceLoader`), and no enforcing AC for RecipeDB synchronous-load constraint.
- qa-lead flagged signal-spy helper undefined in `tests/`, AC-032 fixture not pinned, AC-047 9-assertion composite, AC-043 not CI-executable as written.

Prior verdict resolved: Yes — all 8 prior blockers closed; new findings are additive specificity and one unfalsifiable AC, not regressions. Game-designer's re-challenge to D-5/D-6 ruled closed by creative director; Chester did not override.

Status moved to **Approved** in systems-index.md. The 5 advisory blockers are tracked here; re-visit at implementation hand-off.

---
