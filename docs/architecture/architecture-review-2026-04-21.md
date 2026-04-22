# Architecture Review Report — 2026-04-21

> **Date**: 2026-04-21
> **Engine**: Godot 4.3 (pinned 2026-03-25; knowledge risk LOW — within LLM training cutoff May 2025)
> **Mode**: Full (coverage + consistency + engine audit)
> **Skill**: `/architecture-review`
> **GDDs Reviewed**: 20 system GDDs + `game-concept.md` + `systems-index.md`
> **ADRs Reviewed**: ADR-001, ADR-002, ADR-003, ADR-004, ADR-005
> **Verdict**: **PASS** — architecture coverage is complete; no blocking cross-ADR conflicts; engine audit clean.

---

## Summary

Architecture review covering the cleanup period between `/review-all-gdds` PASS
(2026-04-21) and the `/gate-check pre-production` request later the same day. The
review validates that the 5-ADR set (001 naming; 002 card pool; 003 signal bus;
004 runtime composition; 005 `.tres` everywhere) covers the 298 active TRs across
all 20 MVP systems, with zero gaps in the Foundation layer.

ADR-005 (accepted this session) resolved the last outstanding architecture condition
by committing all persistent game data to `.tres` Resource classes. This change
rippled through 5 GDDs and `architecture.md` and is fully internally consistent —
no `.json` references remain in the design set except historical review logs.

The architecture is approved for Pre-Production entry. Three retrofit items on
ADR-001/002/003 (missing Engine Compatibility, GDD Requirements Addressed, and ADR
Dependencies sections) are tracked as low-priority tech debt and do not block the
phase transition.

---

## Phase 1 — Inputs Loaded

- **GDDs**: 20 (all `Designed`, cross-review verdict PASS — see `design/gdd/gdd-cross-review-2026-04-21-reverify.md`)
- **ADRs**: 5 (all `Accepted`)
- **Master architecture**: `docs/architecture/architecture.md` (sign-off APPROVED)
- **TR registry**: `docs/architecture/tr-registry.yaml` v1, 298 active TRs
- **Engine reference**: `docs/engine-reference/godot/VERSION.md` (pinned 2026-03-25, risk LOW)

---

## Phase 2 — Technical Requirements Extracted

All extraction deferred to the pre-existing `tr-registry.yaml` — 298 active TRs
stable-keyed, last revised 2026-04-21. No new TRs discovered during this review
that weren't already captured by the October–April authoring pass.

Per-system TR counts:

| System | TRs | System | TRs |
|---|---|---|---|
| audio-manager | 20 | mystery-unlock-tree | 20 |
| card-database | 11 | recipe-database | 12 |
| card-engine | 20 | save-progress-system | 15 |
| card-spawning-system | 18 | scene-goal-system | 12 |
| card-visual | 11 | scene-manager | 20 |
| final-epilogue-screen | 14 | scene-transition-ui | 15 |
| hint-system | 12 | settings | 16 |
| input-system | 14 | status-bar-system | 12 |
| interaction-template-framework | 16 | status-bar-ui | 11 |
| main-menu | 12 | table-layout-system | 17 |

**Total**: 298 active TRs.

---

## Phase 3 — Traceability Matrix

Full matrix lives in `docs/architecture/architecture-traceability.md`. Summary:

| Layer | Systems | TRs | Covered | Partial | Gap |
|---|---|---|---|---|---|
| Foundation | 11 | 166 | 166 | 0 | 0 |
| Core | 3 | 53 | 53 | 0 | 0 |
| Presentation | 5 | 63 | 63 | 0 | 0 |
| Meta | 1 | 16 | 16 | 0 | 0 |
| **Total** | **20** | **298** | **298** | **0** | **0** |

**Zero gaps.** Foundation-layer coverage is 100% — satisfies the load-bearing
requirement for the Technical Setup → Pre-Production gate.

---

## Phase 4 — Cross-ADR Conflict Detection

**No conflicts detected.** The 5 ADRs are horizontal (apply across many systems)
and complementary rather than competing:

- ADR-001 (naming): governs file and symbol names. No overlap with 002/003/004/005.
- ADR-002 (card pool): governs card-lifecycle allocation only. Does not intersect
  with data format (ADR-005) or scene composition (ADR-004).
- ADR-003 (signal bus): governs cross-system communication. ADR-004's composition
  rules explicitly wire EventBus signals in `gameplay.tscn` ready order — consistent,
  not conflicting.
- ADR-004 (composition): defines the 12-autoload order and `gameplay.tscn` structure.
  References ADR-003 for signal wiring. No data-format assumptions beyond ADR-005.
- ADR-005 (`.tres` everywhere): governs persistent data format. Consistent with
  ADR-002 (card pool holds `CardEntry` Resource references) and ADR-004 (SceneManager
  loads `SceneData` Resources per SceneManifest).

### ADR Dependency Graph

```
ADR-001 (no deps)
ADR-002 (no deps)
ADR-003 (no deps)
ADR-004 → ADR-003 (signals wired by composition root)
ADR-005 → ADR-001 (naming for class_name Resource classes)
```

**No cycles.** No references to `Proposed` ADRs. Recommended implementation order:
ADR-001, ADR-002, ADR-003 (parallel, any order) → ADR-005 → ADR-004.

---

## Phase 5 — Engine Compatibility Audit

### Version Consistency
All 5 ADRs target Godot 4.3. No stale version references. Matches
`docs/engine-reference/godot/VERSION.md` pinned value.

### Deprecated API Check
Spot-checked all ADRs against `docs/engine-reference/godot/deprecated-apis.md`
(which tracks 4.4/4.5/4.6 deprecations not applicable to 4.3). **No deprecated
API references in any ADR.**

### Missing Engine Compatibility Sections

| ADR | Engine Compatibility | GDD Requirements Addressed | ADR Dependencies |
|---|---|---|---|
| ADR-001 | ❌ missing | ❌ missing | ❌ missing |
| ADR-002 | ❌ missing | ❌ missing | ❌ missing |
| ADR-003 | ❌ missing | ❌ missing | ❌ missing |
| ADR-004 | ✅ present | ✅ present | ✅ present |
| ADR-005 | ✅ present | ✅ present | ✅ present |

**Classification**: documentation debt, not an engine risk. Godot 4.3 is within
LLM training cutoff and engine-reference docs confirm no risky APIs are in play.
The Engine Compatibility sections would all state "LOW risk, no post-cutoff APIs"
if retrofitted. Tracked in `architecture.md` §7.4.

### Post-Cutoff APIs
None used. All APIs (`Node`, `CanvasLayer`, `Tween`, `AudioStreamPlayer`,
`FileAccess`, `DirAccess.rename_absolute()`, `ResourceLoader.load_threaded_request`,
autoload singletons, `CONNECT_ONE_SHOT`) are pre-cutoff and stable in 4.3.

### HIGH RISK Domains
None. No engine-specialist consultation required.

---

## Phase 5b — Design Revision Flags (Architecture → GDD Feedback)

**No GDD revision flags.** All GDD assumptions are consistent with verified engine
behaviour. The recent `.json` → `.tres` sweep (ADR-005) confirmed the last
architecture-driven GDD revision round.

---

## Phase 6 — Architecture Document Coverage

`docs/architecture/architecture.md` reviewed against `systems-index.md`:

- **Systems mapped in architecture layers**: 20/20 ✅
- **Data flow section**: covers all cross-system EventBus signals ✅
- **API boundaries**: consistent with ADR-003 + ADR-004 wiring ✅
- **Orphaned architecture** (systems in arch doc without GDD): none ✅

Architecture.md §6 audit table now includes ADR-005 row. §7 blockers are RESOLVED.
§9 open questions are resolved. §10 handoff checklist shows all items DONE.

---

## Phase 7 — Output

### Verdict: **PASS**

- **Traceability**: 298 / 298 TRs covered. 0 gaps.
- **Conflicts**: 0 detected.
- **Engine**: clean. No deprecated APIs. No post-cutoff APIs.
- **Architecture document**: complete coverage of all 20 systems.

### Blocking Issues
**None.**

### Advisory (non-blocking, carry-forward)

1. **ADR-001/002/003 retrofit** — add Engine Compatibility (LOW risk stamp),
   GDD Requirements Addressed (reference TR-registry sections), and ADR
   Dependencies (most will be "None") sections. Tracked in architecture.md §7.4.
2. **MUT W-D1** (`discovery_milestone_reached` rename/removal) — creative-director
   call before MVP content authoring locks the signal in. Carried from
   cross-review report.
3. **STUI W-D2** (polish budget vs Pillar 4) — production decision at first
   playtest milestone. Carried from cross-review report.
4. **Settings + in-flight drag** — one-line companion edit recommended at story
   time for Settings Rule 5. Carried from cross-review report.

### Required Next ADRs
None. Current 5-ADR set is sufficient to enter Pre-Production. Additional ADRs
will emerge from epic decomposition (`/create-epics`) surfacing cross-cutting
decisions not yet encountered — none are required as a prerequisite.

---

## Phase 8 — Artifacts Written

| File | Status |
|---|---|
| `docs/architecture/architecture-traceability.md` | Written (new) — the traceability index |
| `docs/architecture/tr-registry.yaml` | No changes — 298 TRs stable |
| `docs/architecture/architecture-review-2026-04-21.md` | This file — written |

---

## History

| Date | Event |
|---|---|
| 2026-04-21 | `/review-all-gdds` ran, verdict PASS (6 blockers resolved via ADR-004 + ADR-003 expansion) |
| 2026-04-21 | ADR-005 authored and Accepted (`.tres` everywhere) |
| 2026-04-21 | GDD sweep applied — all `.json` data refs converted to `.tres` (5 GDDs + architecture.md) |
| 2026-04-21 | `/architecture-review` run — verdict **PASS** (this report) |
