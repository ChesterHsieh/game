# Cross-GDD Review Report — 2026-04-21

> **Date**: 2026-04-21
> **GDDs Reviewed**: 20 system GDDs + `game-concept.md` + `systems-index.md` + ADR-003
> **Skill**: `/review-all-gdds` (full mode)
> **Verdict**: **FAIL** — 6 top-level blockers must be resolved before `/create-architecture`

---

## Summary

The 20 GDDs describe a game that is **design-coherent** — all pillars upheld, no anti-pillar violations, player fantasy reads as one voice across all systems. Creative direction holds. But cross-system **wiring** has drift accumulated from serial per-GDD authoring: startup ordering, signal declarations, and the epilogue handoff chain all show contradictions that individual-GDD reviews (and the earlier `/consistency-check` against an empty registry) could not catch.

None of the issues require system redesigns. They are contract clarifications, missing declarations, and stale cross-references. A focused 2–3 hour cleanup pass resolves them.

---

## Top 6 blocking issues

### 🔴 BLOCKER-1 — ADR-003 signal declarations incomplete

`docs/architecture/ADR-003-signal-bus.md` ends with a placeholder `# ... all signals from GDDs` and visibly declares only ~15 of the ~25 signals referenced across GDDs. Missing (at minimum):

- `scene_loading(scene_id: String)` — Scene Manager
- `scene_started(scene_id: String)` — Scene Manager
- `epilogue_started()` — Scene Manager
- `card_spawned(instance_id, card_id, position)` — Card Spawning System
- `card_removing(instance_id)` — Card Spawning System
- `card_removed(instance_id)` — Card Spawning System
- `merge_animation_complete(a, b, midpoint)` — Card Engine
- `animate_complete(instance_id)` — Card Engine
- `recipe_discovered(recipe_id, card_id_a, card_id_b, scene_id)` — MUT
- `discovery_milestone_reached(milestone_id, count)` — MUT
- `epilogue_conditions_met()` — MUT
- `final_memory_ready()` — MUT
- `epilogue_cover_ready()` — Scene Transition UI

Any emit of an undeclared signal is a runtime error in Godot. Main Menu GDD's own Edge Cases (`design/gdd/main-menu.md`) explicitly warns about this class of failure.

**Fix**: expand ADR-003's code block to the full declaration list. ~20 minute edit; unblocks many downstream paths.

### 🔴 BLOCKER-2 — Epilogue handoff is architecturally contradictory (FES ↔ SM ↔ STUI)

Three GDDs disagree about what happens when the last chapter completes:

- **`scene-manager.md` Core Rule 5**: on `_current_index >= manifest.size()`, SM enters terminal `Epilogue` state, emits `epilogue_started()`, and "Scene Manager's role ends."
- **`final-epilogue-screen.md` Core Rule 2**: SM listens for `final_memory_ready`, then calls `change_scene_to_file("final_epilogue.tscn")`. Implies SM does *not* stop — it swaps the scene.
- **`scene-transition-ui.md` Rule 1 + EPILOGUE state**: STUI is a CanvasLayer child of gameplay.tscn. When SM swaps to FES, gameplay.tscn (and STUI) is freed. But FES Rule 6 gates its reveal on `epilogue_cover_ready` from STUI — which is already dead.

**Result**: FES waits for a signal from a freed node. The 5-second fallback timer in FES masks the bug, but the reveal chain is dangling by design.

**Fix**: resolve in a new ADR — either
(a) FES renders as a CanvasLayer *above* STUI inside the same gameplay.tscn (no scene change; SM just flips state), or
(b) handoff sequence is `epilogue_started → STUI amber rise → epilogue_cover_ready → SM change_scene(FES)`.

### 🔴 BLOCKER-3 — Reset Progress mid-gameplay is broken

- `SaveSystem.clear_save()` (save-progress-system.md Rule 10) unconditionally calls `SceneManager.set_resume_index(0)`.
- `SceneManager.set_resume_index()` (scene-manager.md Rule 7, added 2026-04-21) asserts `_state == WAITING` and rejects the call otherwise.
- `settings.md` Rule 6 commits Reset Progress while SM is `Active`. The `set_resume_index(0)` call is rejected → SM retains its active index.
- Settings then switches scene to Main Menu, but SM is an autoload — it keeps its state. On next Start, Main Menu emits `game_start_requested` → SM's `CONNECT_ONE_SHOT` handler was consumed on the first session's start. **It does not re-fire.** SM is stuck.

**Fix**: add `SceneManager.reset_to_waiting()` API that frees cards, resets state, and re-arms the one-shot. Call it from `SaveSystem.clear_save()` or from Settings commit. Also specify MUT's `load_save_state({})` contract for empty-dict clean wipe. ~1h edit across three GDDs.

### 🔴 BLOCKER-4 — Autoload ordering specified three different ways

| GDD | Claimed ordering |
|---|---|
| Scene Manager Edge Cases | `EventBus → SGS → CSS → TLS → SceneManager` |
| Save/Progress Rule 1 | `... → MUT → SceneManager → SaveSystem` (SaveSystem last) |
| Settings Rule 9 | `EventBus → AudioManager → SettingsManager → SaveSystem → … → SceneManager` (SaveSystem **before** SceneManager) |
| MUT Rule 6 | requires `RecipeDatabase` before `MysteryUnlockTree` (not in any order list) |

No single `project.godot` order can satisfy all three — Save/Progress and Settings directly conflict on SaveSystem's position. `RecipeDatabase` and `CardDatabase` autoloads are omitted from every explicit ordering.

**Fix**: produce one canonical order in a new ADR. Delete the ordering lists from individual GDDs (or reduce to "see ADR-XXX").

### 🔴 BLOCKER-5 — `combination_executed` 4→6 parameter expansion not propagated

MUT Rule 4 + OQ-7 expanded the signal from 4 to 6 params and explicitly requires "every existing consumer must update its handler signature in the same commit." In Godot 4.3, arity mismatch is a runtime dispatch error.

Still using 4-param form:

- `interaction-template-framework.md` — the emitter itself (Signals Emitted section)
- `status-bar-system.md` — handler declaration
- `scene-goal-system.md` — reference in Dependencies
- `hint-system.md` — handler + Dependencies
- `docs/architecture/ADR-003-signal-bus.md` — code block

**Fix**: single coordinated edit across 4 GDDs + ADR-003. ~30 min.

### 🔴 BLOCKER-6 — Save-write vs SM-increment race on `scene_completed`

Both SaveSystem and SceneManager listen to `scene_completed`. Save/Progress Rule 5 says the save captures "`_current_index` **post-increment**" — but SM increments `_current_index` inside its own `scene_completed` handler, and Godot does not guarantee listener order between two autoloads subscribing at `_ready()`.

If SaveSystem runs first, the save captures the pre-increment index — **off by one** — and the resumed session replays the just-completed chapter.

**Fix**: change Save/Progress to trigger on `scene_started` of the next scene (SM has already incremented by then), OR have SM call `SaveSystem.save_now()` synchronously *after* its own increment, bypassing EventBus. ~15 min design edit.

---

## Design theory findings (creative-director)

Verdict: **CONCERNS** — 0 blockers, 3 warnings. The design is broadly coherent. Two systems carry latent risks.

### ⚠️ W-D1 — MUT percentage-milestones are a completionist scaffold

MUT defines `_milestone_pct = [0.15, 0.50, 0.80]` resolving to integer thresholds. The GDD forbids player-visible feedback on `discovery_milestone_reached`, but the *machinery* for scoring exists in the codebase. A future polish pass could hook a tasteful sound to it; the anti-celebration rule has no code-level guard.

Recommended resolution: delete `discovery_milestone_reached` entirely for MVP (carry-forward unlocks can key off explicit `recipe_discovered` ids instead), OR rename to `narrative_beat_reached(beat_id)` keyed by authored ids rather than percent-derived thresholds. Pre-content cleanup, not pre-architecture.

### ⚠️ W-D2 — Scene Transition UI polish budget violates Pillar 4

STUI specifies a 12-segment Polygon2D with per-vertex y-displacement over time, semitone pitch math, reduced-motion path, and amber-cover variant for epilogue. The r1 revision trimmed 45 → 20 ACs but the spec is still the polish-heaviest system in the game for a presentational feature.

Pillar 4 ("Write 10 more combinations"): every hour on STUI vertex curl is an hour not writing cards. Recommend textured modulate-alpha tween for MVP; defer vertex curl to Alpha+ only if playtest demands.

### ⚠️ W-D3 — Hint System flat global `stagnation_sec`

`stagnation_sec = 300s` is a single constant. Late chapters have larger card trees and longer time-to-insight; flat hint timing risks the "stuck with no way forward" turn-away Ju specifically flags in game-concept §Target Player Profile.

**Fix**: promote to per-scene JSON config before scene authoring begins. Trivial now, painful after 5 scenes exist.

### Pillar alignment table (✅ all 20 systems)

| System | Primary pillar | Secondary | OK? |
|---|---|---|---|
| Card Database | P4 Personal | P1 Recognition | ✓ |
| Recipe Database | P2 Interaction | P4 Personal | ✓ |
| Input System | P3 Discovery | — | ✓ |
| Audio Manager | P3 Discovery | P4 Personal | ✓ |
| Card Engine | P3 Discovery | P2 Interaction | ✓ |
| Table Layout System | P3 Discovery | — | ✓ |
| Card Spawning System | P3 Discovery | — | ✓ |
| Interaction Template Framework | P2 Interaction | — | ✓ |
| Status Bar System | P3 Discovery | — | ✓ |
| Scene Goal System | P3 Discovery | — | ✓ |
| Hint System | P3 Discovery | — | ✓ (W-D3) |
| Card Visual | P4 Personal | P1 Recognition | ✓ |
| Status Bar UI | P3 Discovery | — | ✓ |
| Scene Manager | P3 Discovery | — | ✓ |
| Mystery Unlock Tree | P3 Discovery | P1 Recognition | ✓ (W-D1) |
| Scene Transition UI | P3 Discovery | P4 + P1 | ✓ (W-D2) |
| Main Menu | P3 Discovery | P4 Personal | ✓ |
| Final Epilogue Screen | P1 Recognition | P4 Personal | ✓ |
| Save/Progress System | P3 Discovery (indirect) | — | ✓ |
| Settings | P4 Personal | — | ✓ |

**Anti-pillar violations**: NONE FOUND.
**Player fantasy coherence**: COHERENT across all 20 systems.

---

## Consistency findings (9 warnings)

Most are stale cross-references from the 2026-04-20/21 content burst — ~30-second edits each:

| # | GDD | Stale item |
|---|---|---|
| W-C1 | `final-epilogue-screen.md` line ~110 | "Save/Progress System (not yet designed)" — SP now Designed |
| W-C2 | `mystery-unlock-tree.md` Rule 7 + OQ-11 | "As of 2026-04-18 FES not authored" — FES Designed 2026-04-20 |
| W-C3 | `scene-transition-ui.md` OQ-5, OQ-7 | References #17/#19/#20 as undesigned — all Designed |
| W-C4 | `scene-manager.md` Interactions table | Still lists STUI as `scene_loading` listener (STUI dropped this) |
| W-C5 | `status-bar-system.md` Interactions | Lists Hint System as `bar_values_changed` consumer (Hint now triggers on `combination_executed`) |
| W-C6 | `interaction-template-framework.md` | Contains "Cross-system conflict" note about Card Engine `card_id` naming — already corrected |
| W-C7 | `hint-system.md` Overview | First line says "listens to `bar_values_changed`" — contradicts Rule 3 |
| W-C8 | `audio-manager.md` | `fade_out_all(duration)` used by FES but not declared — add to Interactions + ACs |
| W-C9 | `settings.md` vs `scene-transition-ui.md` | STUI OQ-7 expects Settings to expose `reduced_motion`; Settings OQ-3 defers it. Clarify division in one of them. |

---

## Cross-system scenario findings

17 additional blockers and 11 warnings surfaced from walking 6 key scenarios step-by-step. Highlights not already in the top-level blockers above:

- **CanvasLayer z-order collision** — Settings panel and STUI both use `CanvasLayer.layer = 10`. If Ju opens Settings during a transition, the panel may render *behind* STUI's opaque overlay. **Fix**: bump Settings to `layer = 15`.
- **In-flight card drag on Settings open** — Card Engine has no observer of panel state. Drag stalls mid-air, snaps to cursor on Close. Needs `InputSystem.cancel_drag()` call on panel open.
- **`clear_all_cards()` during Transitioning may emit spurious `combination_executed`** — if a card was mid-`Executing`, combination completes non-deterministically against stale state.
- **FES `_enter_tree()` guard check races MUT save-state load** — SM's `_enter_tree` runs before MUT's `_ready()` can load save state. `MUT.is_final_memory_earned()` returns default `false`, so SM subscribes to `final_memory_ready` even on resume-after-completion → FES re-triggers on relaunch.
- **Quit during FES fade-in leaves `_final_memory_earned` unpersisted** — no `scene_completed` fires during Epilogue (terminal state), so SaveSystem never writes the flag.

---

## GDDs flagged for revision

| GDD | Reason | Severity |
|---|---|---|
| `docs/architecture/ADR-003-signal-bus.md` | Signal declarations incomplete (B-1, B-5) | Blocking |
| `design/gdd/scene-manager.md` | Needs `reset_to_waiting()` API (B-3); epilogue handoff (B-2); stale `scene_loading` listener row (W-C4) | Blocking |
| `design/gdd/final-epilogue-screen.md` | Epilogue handoff contradiction (B-2); stale SP-not-designed reference (W-C1) | Blocking |
| `design/gdd/scene-transition-ui.md` | Epilogue handoff contradiction (B-2); stale OQs (W-C3); polish budget (W-D2) | Blocking |
| `design/gdd/save-progress-system.md` | `scene_completed` race (B-6); `set_resume_index` call path for Reset (B-3) | Blocking |
| `design/gdd/settings.md` | Reset Progress path (B-3); CanvasLayer=10 collision; `reduced_motion` division (W-C9) | Blocking |
| `design/gdd/interaction-template-framework.md` | `combination_executed` 6-param cascade (B-5); stale cross-note (W-C6) | Blocking |
| `design/gdd/status-bar-system.md` | `combination_executed` 6-param cascade (B-5); stale Hint downstream row (W-C5) | Blocking |
| `design/gdd/scene-goal-system.md` | `combination_executed` 6-param cascade (B-5) | Blocking |
| `design/gdd/hint-system.md` | 6-param cascade (B-5); stale Overview (W-C7); per-scene `stagnation_sec` (W-D3) | Blocking/Warning |
| `design/gdd/mystery-unlock-tree.md` | Stale "FES not yet authored" (W-C2); milestone vocabulary (W-D1) | Warning |
| `design/gdd/audio-manager.md` | Add `fade_out_all(duration)` (W-C8) | Warning |
| `design/gdd/main-menu.md` | `gameplay.tscn` composition still lives in OQ-1 — promote to ADR | Warning |

---

## Recommended cleanup order

1. **ADR-003 full signal list** — resolves B-1 and part of B-5. ~20 min.
2. **New ADR: "Runtime scene composition & autoload order"** — resolves B-2 and B-4 in one document. ~1h.
3. **4-file `combination_executed` 6-param cascade** — resolves B-5. ~30 min.
4. **`reset_to_waiting()` + Reset Progress path** — resolves B-3. ~1h across SM/SaveSystem/Settings.
5. **Save-write ordering fix** — resolves B-6. ~15 min.
6. **Stale cross-reference sweep** — W-C1 through W-C9 in one pass. ~15 min.
7. **Design-theory warnings** — W-D1 (MUT rename) and W-D3 (Hint per-scene) are pre-content cleanups worth doing now; W-D2 (STUI polish) is a production decision.

Total: ~4–5 hours of focused editing. Re-run `/review-all-gdds` after to confirm FAIL → PASS/CONCERNS.
