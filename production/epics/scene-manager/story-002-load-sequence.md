# Story 002: Scene Load Sequence + seed_cards_ready watchdog

> **Epic**: Scene Manager
> **Status**: Complete
> **Layer**: Feature
> **Type**: Integration
> **Manifest Version**: 2026-04-21

## Context

**GDD**: `design/gdd/scene-manager.md`
**Requirements**: `TR-scene-manager-003`, `TR-004`, `TR-009`, `TR-019`

**ADR Governing Implementation**: ADR-003 (EventBus — connect `seed_cards_ready` before calling `SGS.load_scene()` to guard against synchronous signal) + ADR-004 (5-second watchdog timer; SM emits `scene_loading`, `scene_started`)
**ADR Decision Summary**: `seed_cards_ready` must be connected before `SGS.load_scene()` is called — if the signal fires synchronously during `load_scene()`, an `await` registered afterward would hang. A `SceneTreeTimer` watchdog emits `scene_started` with zero cards if `seed_cards_ready` never fires within 5 seconds.

**Engine**: Godot 4.3 | **Risk**: LOW
**Engine Notes**: In Godot 4, signals connected with `await` register the resume continuation at the time of the `await` keyword — if the signal already fired before `await`, the continuation never runs. Connect-then-call ordering is the correct defensive pattern.

---

## Acceptance Criteria

- [ ] `game_start_requested` handler calls `_load_scene_at_index(0)` → transitions to Loading state → emits `EventBus.scene_loading(scene_id)`
- [ ] Connect `EventBus.seed_cards_ready` BEFORE calling `SceneGoalSystem.load_scene(scene_id)` (ordering guarantee)
- [ ] On `seed_cards_ready(seed_cards)` while Loading: get positions via `TableLayoutSystem.get_seed_card_positions()`; spawn each seed card via `CardSpawningSystem.spawn_card()`; emit `EventBus.scene_started(scene_id)`; enter Active state
- [ ] Start `seed_cards_ready_timeout_sec` (5.0s) watchdog timer after calling `SGS.load_scene()`; on timeout: log error, emit `scene_started` with zero cards, enter Active
- [ ] `seed_cards_ready` received while not in Loading state: silently ignore
- [ ] `scene_completed` with mismatched scene_id: ignore, log warning with both IDs (received vs. expected)

---

## Implementation Notes

*Derived from ADR-003 + ADR-004 + GDD scene-manager.md:*

```gdscript
var _watchdog_timer: SceneTreeTimer

func _load_scene_at_index(index: int) -> void:
    if _state == _State.LOADING:
        push_warning("SceneManager: _load_scene_at_index re-entrant call — aborting second call")
        return
    if _state == _State.EPILOGUE:
        push_error("SceneManager: _load_scene_at_index called in Epilogue — aborting")
        return
    var scene_id: String = _manifest.scene_ids[index]
    _state = _State.LOADING
    EventBus.scene_loading.emit(scene_id)
    # Connect BEFORE load_scene to guard against synchronous signal
    EventBus.seed_cards_ready.connect(_on_seed_cards_ready, CONNECT_ONE_SHOT)
    _watchdog_timer = get_tree().create_timer(_seed_cards_ready_timeout_sec)
    _watchdog_timer.timeout.connect(_on_seed_cards_ready_timeout.bind(scene_id))
    SceneGoalSystem.load_scene(scene_id)

func _on_seed_cards_ready(seed_cards: Array) -> void:
    if _state != _State.LOADING:
        return
    _cancel_watchdog()
    var positions := TableLayoutSystem.get_seed_card_positions(seed_cards)
    for i in seed_cards.size():
        if i < positions.size():
            CardSpawningSystem.spawn_card(seed_cards[i], positions[i])
        else:
            push_warning("SceneManager: no position for seed card '%s'" % seed_cards[i])
    var scene_id := _manifest.scene_ids[_current_index]
    _state = _State.ACTIVE
    EventBus.scene_started.emit(scene_id)

func _on_seed_cards_ready_timeout(scene_id: String) -> void:
    if _state != _State.LOADING:
        return
    push_error("SceneManager: seed_cards_ready timeout for scene '%s' — entering Active with 0 cards" % scene_id)
    EventBus.seed_cards_ready.disconnect(_on_seed_cards_ready)
    _state = _State.ACTIVE
    EventBus.scene_started.emit(scene_id)

func _cancel_watchdog() -> void:
    if _watchdog_timer != null and not _watchdog_timer.is_stopped():
        _watchdog_timer.timeout.disconnect()  # prevent deferred fire
```

- `scene_completed` handler: guard `_state == _State.ACTIVE`; guard scene_id match; log warning on mismatch with both IDs.
- `spawn_card()` returning `""` (unknown card_id): log warning, continue with remaining cards.

---

## Out of Scope

- [Story 001]: Manifest loading and Waiting state setup
- [Story 003]: Scene completion, table clearing, epilogue entry
- [Story 004]: Resume Index API and reset_to_waiting()

---

## QA Test Cases

- **AC-1**: Load sequence emits scene_loading then scene_started
  - Given: SM in Waiting state; valid manifest with scene_id="home"; mock SGS.load_scene callable; mock CSS.spawn_card; mock TLS.get_seed_card_positions returns [(100,100)]
  - When: `game_start_requested` fires
  - Then: `scene_loading("home")` emitted; `scene_started("home")` emitted; `_state == ACTIVE`

- **AC-2**: seed_cards_ready connected before load_scene called
  - Given: SGS.load_scene fires seed_cards_ready synchronously
  - When: `_load_scene_at_index(0)` called
  - Then: seed cards are still received and processed (connection was made before the call)

- **AC-3**: Watchdog fires on timeout
  - Given: SM in Loading; SGS never emits seed_cards_ready
  - When: 5 seconds elapse
  - Then: `scene_started("home")` emitted with zero cards; `_state == ACTIVE`; error logged

- **AC-4**: Mismatched scene_completed ignored with warning
  - Given: SM Active; `_current_index` points to "home"
  - When: `scene_completed("park")` received
  - Then: state unchanged; warning logged with both scene_ids

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/scene_manager/load_sequence_test.gd` — must exist and pass

**Status**: BLOCKED — `SceneManager` autoload script does not exist in `src/`. Production code is missing; test file cannot be written.

---

## Dependencies

- Depends on: story-001-manifest-waiting must be DONE; scene-goal-system `story-002` must be DONE; card-spawning-system `story-002` must be DONE; table-layout-system `story-001` must be DONE
- Unlocks: story-003-completion-epilogue
