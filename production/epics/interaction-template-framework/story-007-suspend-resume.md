# Story 007: Suspend/Resume & System-Level State

> **Epic**: Interaction Template Framework
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Manifest Version**: 2026-04-21

## Context

**GDD**: `design/gdd/interaction-template-framework.md`
**Requirements**: `TR-interaction-template-framework-014`, `TR-interaction-template-framework-015`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-003: Inter-System Communication — EventBus Singleton; ADR-004: Runtime Scene Composition
**ADR Decision Summary**: Scene Manager calls `InteractionTemplateFramework.suspend()` at scene transition begin and `InteractionTemplateFramework.resume()` at scene load complete. These are direct autoload method calls (read-write, not queries) — an acceptable exception to the EventBus-for-events rule because they are lifecycle commands from an orchestrator to a subsystem. All generator timers must be paused during `Suspended` state.

**Engine**: Godot 4.3 | **Risk**: LOW
**Engine Notes**: Pause timers via `timer.paused = true` / `timer.paused = false` on all active generator Timer nodes during `suspend()`/`resume()`. The system-level `process_mode = PROCESS_MODE_ALWAYS` set in Story 001 ensures ITF itself is not paused by the scene tree — the Suspended state is an ITF-internal guard, not a Godot pause.

**Control Manifest Rules (Feature Layer)**:
- Required: `process_mode = PROCESS_MODE_ALWAYS` — ITF must process even when scene tree is paused (set in Story 001)
- Required: Scene Manager orchestrates the suspend/resume lifecycle

---

## Acceptance Criteria

*From GDD `design/gdd/interaction-template-framework.md`, scoped to this story:*

- [ ] `suspend()` public method: sets ITF to `Suspended` state
- [ ] `resume()` public method: sets ITF back to `Ready` state
- [ ] While in `Suspended` state: `combination_attempted` signals are silently ignored (no recipe lookup, no signals emitted)
- [ ] While in `Suspended` state: all active generator timers are paused (`timer.paused = true`)
- [ ] On `resume()`: all previously-paused generator timers are unpaused (`timer.paused = false`)
- [ ] Cooldown timers (Dictionary-based timestamps) are effectively paused by ignoring all `combination_attempted` events during Suspended — no active pause mechanism needed since they're passive timestamps

---

## Implementation Notes

*Derived from ADR-003 and ADR-004:*

- Add `enum State { READY, SUSPENDED }` and `var _state: State = State.READY`.
- `suspend() -> void`: `_state = State.SUSPENDED`; for each entry in `_active_generators`: `entry.timer.paused = true`.
- `resume() -> void`: `_state = State.READY`; for each entry in `_active_generators`: `entry.timer.paused = false`.
- In `_on_combination_attempted(...)`: add guard at the top: `if _state == State.SUSPENDED: return`.
- Cooldown timestamps (`_last_fired_msec`) use wall-clock time (`Time.get_ticks_msec()`). During Suspended, no `combination_attempted` is processed so no cooldown entries are written. The timestamps do NOT freeze — a recipe that was on cooldown before suspension will have elapsed more real time when ITF resumes, which may make it available sooner than intended. This is acceptable: the GDD's edge case notes that Suspended events are simply ignored; there is no requirement to freeze cooldown time.
- Scene Manager calls `InteractionTemplateFramework.suspend()` and `InteractionTemplateFramework.resume()` directly (not via EventBus) — these are imperative lifecycle commands, not events.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 006: Generator timer creation and management (this story only pauses/resumes existing timers)
- Scene Manager's implementation of calling suspend/resume (handled in the Scene Manager epic)

---

## QA Test Cases

**AC-1**: combination_attempted silently ignored while Suspended
- Given: ITF is in Suspended state; valid recipe exists for `("chester", "ju")`
- When: `combination_attempted("chester_0", "ju_0")` fires
- Then: no signal emitted (neither `combination_succeeded` nor `combination_failed`); `RecipeDatabase.lookup` NOT called
- Edge cases: resume → same attempt → `combination_succeeded` fires normally

**AC-2**: Generator timers paused on suspend, resumed on resume
- Given: an active generator timer exists for `"chester_0"` (from Story 006)
- When: `suspend()` is called
- Then: `timer.paused == true`; no spawn_card calls fire during suspension
- When: `resume()` is called
- Then: `timer.paused == false`; generator resumes spawning

**AC-3**: suspend()/resume() are idempotent
- Given: ITF is already in Suspended state
- When: `suspend()` is called again
- Then: no error; state remains Suspended

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/interaction_template_framework/suspend_resume_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 006 (all templates + _active_generators populated) must be DONE
- Unlocks: None (final story in ITF epic — all stories done → run `/story-done` and start next epic)
