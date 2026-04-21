# Main Menu — Review Log

## Review — 2026-04-20 — Verdict: NEEDS REVISION (user accepted as-is)
Scope signal: S
Specialists: game-designer, systems-designer, ux-designer, ui-programmer, qa-lead, godot-gdscript-specialist, creative-director (senior synthesis)
Blocking items: 4 | Recommended: 4 | Advisory: 5
Summary: GDD is structurally complete (8/8 sections) and dependency graph resolves cleanly. Creative-director verdict: "one parser error, one pillar compromise, one internal contradiction, and one design-coherence question — all fixable in a single revision pass." User elected to accept as-is and defer fixes to implementation time.
Prior verdict resolved: First review

### Blocking findings (deferred, not fixed)
1. **GDScript parser bug** [ui-programmer + godot-gdscript-specialist] — Tuning Knobs table specifies `GAMEPLAY_SCENE_PATH` and `QUIT_ON_ESC` as "exported const". `@export` and `const` are mutually exclusive in GDScript. Must become `const` (matches the stated testability rationale) before any implementation code is written or the file will not compile.
2. **Pillar 1 gap in Title PNG spec** [game-designer + creative-director] — Visual spec passes every AC but fails Pillar 1 (Recognition Over Reward). A Caveat/Patrick Hand rendering of "Moments" reads as "handwriting font," not "Chester wrote this." OQ-4 resolution must add a Pillar 1 test: asset must read as Chester's actual hand (recommend hand-letter + scan workflow; font fallback allowed only as explicit compromise).
3. **State table contradiction** [systems-designer] — States and Transitions table claims "once Starting is entered, never recovers" but Edge Cases + AC-FAIL-1 specify `Starting → Idle` recovery on scene-load failure. Align on the recovery path (Edge Cases is correct).
4. **Quit button vs doorway fantasy** [game-designer + ux-designer + creative-director] — Player Fantasy promises "nothing else between her and the first chapter." Two equal-rank buttons (Start, Quit) make the menu a lobby, not a doorway. Esc + OS window-close already cover exit. Creative-director verdict: remove on-screen Quit button; keep Esc-to-quit.

### Recommended revisions (deferred)
5. **Rule 8 `_enter_tree` rationale is wrong** [ui-programmer + godot-gdscript-specialist] — `gameplay.tscn` root doesn't exist at autoload init, so the stated risk ("missing a signal during another autoload's `_ready()`") doesn't apply. Real risk is missing `CONNECT_ONE_SHOT` on the long-lived Scene Manager autoload. Rewrite to `_ready()` + `CONNECT_ONE_SHOT`.
6. **AC-FAIL-1 cannot catch deferred failures** [ui-programmer + godot-gdscript-specialist] — `change_scene_to_file` returns `OK` for queued switches; realistic failures (wrong case, parse error, script error) surface asynchronously after Main Menu is freed. Move recovery to Scene Manager OQ-2 (watchdog) or a `gameplay.tscn` `_ready()` guard; narrow AC-FAIL-1 to synchronous-error case only.
7. **Missing Pre-Implementation Checklist** [systems-designer] — Three companion edits (Scene Manager Rule 2 rewrite, EventBus `signal game_start_requested()` declaration, OQ-1 ADR for `gameplay.tscn`) are load-bearing prerequisites. "Bundled commit" is version-control discipline, not a pre-implementation gate. A developer could implement Main Menu and watch AC-START-4 fail silently without knowing which companion edit is missing.
8. **Invisible focus loss** [ux-designer] — Transparent focus ring + color-only state means keyboard user cannot see they've lost focus before pressing a key blindly. Mitigation: declare input primary ("Ju plays with mouse. Keyboard is secondary; focus recovery is best-effort.") in UI Requirements. Collapses several downstream concerns.

### Advisory (dropped for N=1 scope)
- Dev-only AC testability infrastructure (EventBusMonitor, pixel-diff watchdogs, QA export preset) — manual verification by Chester is sufficient.
- Window title for OS-level accessibility, Alt+Tab focus restoration, 1366×768 test point, Shift+Tab coverage — commercial-game overhead.
- `EventBus.game_start_requested.emit()` vs `emit_signal(...)` preferred-idiom citation.
- `display/window/stretch/mode = canvas_items` as hard requirement (not conditional).
- Unique-name `.tscn` flag reminder — catch at implementation, not GDD.

### Dependency graph status
- ✓ scene-manager.md — exists (Rule 2 companion edit required)
- ✓ scene-transition-ui.md — exists (FIRST_REVEAL handoff consumes Main Menu's exit as designed)
- ✓ ADR-003-signal-bus.md — exists (new `signal game_start_requested()` declaration required)
- ✗ `gameplay.tscn` composition — deferred to OQ-1 ADR (acknowledged)

### User disposition
User reviewed all findings and elected to accept GDD as-is without revision. Known-debt acknowledged informally:
- Item 1 (`@export const`) will surface the moment code is written — 10-second fix at implementation time.
- Item 2 (Pillar 1 test) to be handled when OQ-4 is resolved via `/asset-spec`.
- Other items remain documented here for reference during implementation.

---

## Review — 2026-04-21 — Verdict: MAJOR REVISION NEEDED → FULL FIX PASS APPLIED
Scope signal: M
Specialists: game-designer, systems-designer, ux-designer, ui-programmer, qa-lead, godot-gdscript-specialist, creative-director (senior synthesis)
Blocking items resolved: 6 | Recommended applied: 4 | Companion edits: 3
Summary: Re-review upgraded verdict from NEEDS REVISION to MAJOR REVISION NEEDED because cross-document coherence had drifted — Main Menu's Rule 8 mandated a `game_start_requested` signal that neither Scene Manager nor ADR-003 declared. Creative-director framed the accumulated gap as "the document is now actively lying about the rest of the system." User selected "Revise now — full fix pass" to address all blockers plus companion edits together.
Prior verdict resolved: Yes — all 4 blockers and 4 recommended items from 2026-04-20 were addressed.

### Blockers resolved
1. **`@export const` parser bug** — `GAMEPLAY_SCENE_PATH` and (renamed) `ESC_QUIT_ENABLED` are now plain `const`; mutual-exclusion note added in Tuning Knobs.
2. **Pillar 4 coherence (reframed from Pillar 1)** — Start button switched from DynamicFont to hand-lettered PNG (`ui_button_start_hand.png`) via `TextureButton`. Same single-author pipeline as title PNG. No "two-author seam" between handmade title and Google-Font button. OQ-4 broadened to cover both PNGs.
3. **State table contradiction** — `Starting → Idle` recovery transition added explicitly to state table. Narrative qualifier added: recovery applies only to synchronous `change_scene_to_file` failures; deferred failures are invisible to Main Menu and handled by Scene Manager's Loading-timeout watchdog (OQ-2, now load-bearing).
4. **Quit button removed** — Overview, Player Fantasy, Rules 2/4/5, State table, Node tree, Input Actions, and ACs purged of Quit button. Esc-to-quit retained via `_unhandled_input` gated by `ESC_QUIT_ENABLED` const. OS window-close covers the GUI exit case.
5. **Rule 8 rationale rewritten** — `_enter_tree()` → `_ready()` + `CONNECT_ONE_SHOT`. Correct rationale documented: Scene Manager is a long-lived autoload; the one-emission-per-session invariant is guarded by `CONNECT_ONE_SHOT`, not by subscription timing.
6. **AC-FAIL-1 narrowed** — Now targets synchronous empty-path case only. Deferred-failure detection delegated to Scene Manager OQ-2 (watchdog). New "Scene Switch Failures" edge-case section frames synchronous vs deferred classes explicitly.

### Recommended applied
- **AC verification tags** — `[launch] / [code] / [debugger] / [proxy]` tags added to every AC; priority 5-test subset declared.
- **Load-Window Experience subsection** — Expected duration bounded (<200ms SSD typical; >500ms dev-only watchdog). Disabled-button modulate color declared as the intentional player-facing feedback.
- **Pre-Implementation Checklist** — Added at end of Edge Cases section. Three companion edits listed as blocking prerequisites.
- **Input primary declaration** — Mouse primary / keyboard secondary best-effort documented in UI Requirements.

### Cross-GDD companion edits applied in this pass
- **`design/gdd/scene-manager.md`** — Core Rule 2 replaced with `Waiting` state + `CONNECT_ONE_SHOT` subscription to `game_start_requested`. `Waiting` state added to States table with `Waiting → Loading` transition. Main Menu added to Downstream Interactions table. Startup ACs rewritten to validate Waiting-state behavior. OQ-2 note expanded to explicitly cover Main Menu's deferred-failure dependency.
- **`docs/architecture/ADR-003-signal-bus.md`** — `signal game_start_requested()` declared in EventBus code block.
- **`design/gdd/scene-transition-ui.md`** — Main Menu downstream row updated from "(system #17, undesigned)" to "(#17, Approved)" with the full scene-switch → signal → STUI chain documented.

### Residual items (not fixed this pass — deferred by design)
- OQ-1 (`gameplay.tscn` composition) — requires its own ADR when implementation begins.
- OQ-2 (Save/Progress replacing Main Menu as game-start trigger) — deferred until Save/Progress system design.
- OQ-3 (i18n for Start/Quit labels) — dissolved by PNG-based approach; no translation keys used.

### Dependency graph status
- ✓ scene-manager.md — updated (Waiting state + signal subscription documented)
- ✓ scene-transition-ui.md — updated (Main Menu status label refreshed)
- ✓ ADR-003-signal-bus.md — updated (`game_start_requested` declared)
- ✗ `gameplay.tscn` composition — still deferred to OQ-1 ADR (acknowledged)

### User disposition
Full fix pass applied. GDD advances to Designed. Ready for implementation when MVP systems queue reaches #17.
