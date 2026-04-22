# Story 001: EventBus autoload — 30-signal contract

> **Epic**: card-database
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Integration
> **Manifest Version**: 2026-04-21

## Context

**GDD**: no dedicated GDD — EventBus is pure architectural infrastructure.
The 30-signal contract lives in `docs/architecture/ADR-003-signal-bus.md`
lines 27–85. `production/epics/index.md` designates EventBus as the first
story inside the first Foundation epic worked on (card-database).

**Requirement**: infrastructure prerequisite — not a numbered TR. All
downstream TRs that involve cross-system signals (input, audio, combination
events, save/load, scene transitions) assume EventBus exists.

**ADR Governing Implementation**: ADR-003 — Signal bus (EventBus)
**ADR Decision Summary**: All cross-system events pass through a single
autoload named `EventBus` that declares every signal used in the project.
Systems `emit` and `connect` through EventBus; no direct node references.

**Engine**: Godot 4.3 | **Risk**: LOW
**Engine Notes**: Typed signal declarations (`signal foo(bar: StringName)`)
are pre-cutoff and stable in 4.3. No post-cutoff APIs used.

**Control Manifest Rules (Foundation layer)**:
- Required: declare every new signal in `res://src/core/event_bus.gd` before
  implementing the emitter; `project.godot` declares 12 autoloads in canonical
  order starting with `EventBus`; every autoload sets
  `process_mode = PROCESS_MODE_ALWAYS`.
- Forbidden: adding signals outside EventBus; direct node references for
  inter-system communication; hardcoded node paths.
- Guardrail: idle cost must be near-zero (signals are declarations only;
  no per-frame work).

---

## Acceptance Criteria

*EventBus has no GDD — these criteria are derived from ADR-003:*

- [ ] `res://src/core/event_bus.gd` exists with `extends Node` and declares
      all 30 signals listed in ADR-003 lines 27–85 with exact names, arity,
      and parameter types
- [ ] `project.godot` registers `EventBus` as the first autoload (position
      #1), with `process_mode = PROCESS_MODE_ALWAYS`
- [ ] Project launches without errors; `EventBus` is reachable from any
      script as a global identifier
- [ ] Connecting a dummy listener and emitting a signal delivers the payload
      unchanged (spot-check 3 representative signals: drag, combination, save)
- [ ] No method definitions in `event_bus.gd` beyond signal declarations and
      Godot's `_ready()` (if used, empty body acceptable)

---

## Implementation Notes

*Derived from ADR-003:*

1. Create `res://src/core/event_bus.gd`:
   ```gdscript
   class_name EventBus extends Node

   # Input domain (5 signals)
   signal drag_started(card_id: StringName, world_pos: Vector2)
   signal drag_moved(card_id: StringName, world_pos: Vector2, delta: Vector2)
   signal drag_released(card_id: StringName, world_pos: Vector2)
   signal proximity_entered(dragged_id: StringName, target_id: StringName)
   signal proximity_exited(dragged_id: StringName, target_id: StringName)

   # … remaining 25 signals per ADR-003 lines 27–85
   ```
2. Use typed parameters throughout. Prefer `StringName` for IDs, `Vector2`
   for world coordinates, `int` for counts, `float` for durations, and
   typed sub-Resources where payloads are structured.
3. `project.godot` → `[autoload]` section: `EventBus="*res://src/core/event_bus.gd"`
   as the FIRST entry. Autoloads in Godot are initialised in declared order.
4. Do not add helper methods, caches, or state. EventBus is a signal hub —
   any logic belongs in the listener.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: CardEntry / CardManifest Resource classes
- Story 003: CardDatabase autoload registration (depends on EventBus existing first)
- Downstream signal emitters (InputSystem, AudioManager, etc.) are separate epics

---

## QA Test Cases

*For this Integration story — automated test specs:*

- **AC-1 (all 30 signals declared)**:
  - Given: `EventBus` autoload is loaded
  - When: the test iterates `EventBus.get_signal_list()` and collects names
  - Then: the collected set equals the 30 ADR-003 signal names exactly
  - Edge cases: extra signals (fail), missing signals (fail), wrong arity (fail)

- **AC-2 (autoload position #1 with PROCESS_MODE_ALWAYS)**:
  - Given: Godot project is running
  - When: the test reads `project.godot` `[autoload]` section AND queries
    `EventBus.process_mode`
  - Then: first autoload entry is `EventBus=...`; `process_mode == PROCESS_MODE_ALWAYS`
  - Edge cases: EventBus present but not first → fail; wrong process_mode → fail

- **AC-3 (EventBus is a global identifier)**:
  - Given: any test script
  - When: the script references `EventBus` without import
  - Then: the reference resolves to the autoload instance (not null)

- **AC-4 (emit/connect round-trip)**:
  - Given: EventBus is running
  - When: a listener connects to `drag_started`, `combination_executed`,
    `save_written` and each is emitted with a payload
  - Then: listener receives each payload unchanged, exactly once per emit
  - Edge cases: double-emit → listener receives twice; listener disconnects
    before emit → listener does not receive

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/event_bus/signal_contract_test.gd`
(gdUnit4 `GdUnitTestSuite`) — must exist and pass.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None (this is the first story in the Foundation layer)
- Unlocks: Story 002 (Resource classes can import / connect to EventBus if needed),
  Story 003 (CardDatabase autoload loads AFTER EventBus per ADR-004 order),
  and every Foundation / Core / Feature story that emits or listens

---

## Completion Notes
**Completed**: 2026-04-22
**Criteria**: 5/5 passing
**Deviations**: None
**Test Evidence**: Integration test at `tests/integration/event_bus/signal_contract_test.gd` (14 test functions)
**Code Review**: Complete (manual `/code-review` — all gaps resolved)
