# Story 002: SFX pool — allocation, fire-and-forget, pool-full + win priority

> **Epic**: audio-manager
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Integration
> **Manifest Version**: 2026-04-21

## Context

**GDD**: `design/gdd/audio-manager.md`
**Requirement**: `TR-audio-manager-002` — allocate 8 AudioStreamPlayer nodes,
SFX bus. `TR-audio-manager-006` — claim first IDLE, return to IDLE on
finished. `TR-audio-manager-007` — pool-full: drop non-win, win steals
least-remaining.

**ADR Governing Implementation**: ADR-001 — naming conventions
**ADR Decision Summary**: SFX pool uses a fixed-size array of
AudioStreamPlayer nodes allocated at startup. No dynamic allocation.
Fire-and-forget lifecycle: claim → play → finished → release.

**Engine**: Godot 4.3 | **Risk**: LOW
**Engine Notes**: `AudioStreamPlayer.finished` signal is stable.
`AudioStreamPlayer.get_playback_position()` +
`AudioStreamPlayer.stream.get_length()` gives remaining time.

**Control Manifest Rules (Foundation layer)**:
- Required: all pool nodes assigned to `SFX` bus.
- Forbidden: dynamic AudioStreamPlayer creation at runtime.
- Guardrail: pool of 8 — O(n) scan for IDLE node where n = 8.

---

## Acceptance Criteria

*From GDD `design/gdd/audio-manager.md`:*

- [ ] `_ready()` creates exactly 8 `AudioStreamPlayer` child nodes, all
      assigned to the `SFX` bus — AC-AM-01
- [ ] All 8 nodes start in `IDLE` state
- [ ] On SFX playback request: first IDLE node is claimed, stream assigned,
      plays, returns to IDLE on `finished` — AC-AM-02
- [ ] If all 8 nodes are PLAYING and a non-win event fires: silently
      dropped, no error — AC-AM-03
- [ ] If all 8 nodes are PLAYING and `win_condition_met` fires: the node
      with the least remaining playback time is stopped and reassigned to
      the win SFX — AC-AM-04
- [ ] `play_sfx(event_name)` is the internal method that stories 003–005
      call (applies pool claim + randomization + cooldown)
- [ ] In silent-fallback mode (Story 001), pool nodes are still created
      but no streams are assigned (TR-019 — state transitions still run)

---

## Implementation Notes

*Derived from GDD SFX Pool rules and Edge Case "Pool Exhaustion":*

1. Pool initialization in `_ready()` after config load:
   ```gdscript
   const SFX_POOL_SIZE := 8

   var _sfx_pool: Array[AudioStreamPlayer] = []
   var _sfx_pool_state: Array[bool] = []   # true = PLAYING

   func _init_sfx_pool() -> void:
       for i: int in SFX_POOL_SIZE:
           var player := AudioStreamPlayer.new()
           player.bus = &"SFX"
           player.finished.connect(_on_sfx_finished.bind(i))
           add_child(player)
           _sfx_pool.append(player)
           _sfx_pool_state.append(false)

   func _on_sfx_finished(index: int) -> void:
       _sfx_pool_state[index] = false
   ```
2. Node claim logic:
   ```gdscript
   func _claim_sfx_node(is_win: bool) -> int:
       # Try IDLE first
       for i: int in SFX_POOL_SIZE:
           if not _sfx_pool_state[i]:
               return i
       # Pool full
       if not is_win:
           return -1   # silently drop
       # Win steals node with least remaining time
       var best_i: int = 0
       var least_remaining: float = INF
       for i: int in SFX_POOL_SIZE:
           var player: AudioStreamPlayer = _sfx_pool[i]
           var remaining: float = player.stream.get_length() - player.get_playback_position()
           if remaining < least_remaining:
               least_remaining = remaining
               best_i = i
       _sfx_pool[best_i].stop()
       _sfx_pool_state[best_i] = false
       return best_i
   ```
3. This story creates the pool and claim mechanism. Randomization (Story 003),
   cooldown checks (Story 004), and EventBus wiring (Story 005) are layered
   on top.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: autoload + config load (prerequisite)
- Story 003: pitch + volume randomization (applied during claim)
- Story 004: per-event cooldowns (checked before claim)
- Story 005: EventBus signal wiring (triggers the claim)
- Story 006: music players (separate pool)
- Priority tier ordering beyond win-vs-non-win (GDD lists priorities but
  only win stealing is implemented — other priorities are a future refinement)

---

## QA Test Cases

*For this Integration story — automated test specs:*

- **AC-1 (8 pool nodes created on SFX bus)**:
  - Given: AudioManager `_ready()` completes
  - When: test counts AudioStreamPlayer children
  - Then: exactly 8 exist; all have `bus == "SFX"`

- **AC-2 (all nodes start IDLE)**:
  - Given: pool just initialized
  - When: test reads `_sfx_pool_state`
  - Then: all 8 entries are `false` (IDLE)

- **AC-3 (fire-and-forget: claim → play → release)**:
  - Given: an IDLE pool node
  - When: a stream is assigned and plays, then `finished` emits
  - Then: node returns to IDLE (`_sfx_pool_state[i] == false`)

- **AC-4 (pool full: non-win dropped)**:
  - Given: all 8 nodes are PLAYING
  - When: `_claim_sfx_node(false)` is called
  - Then: returns -1; no node is stopped

- **AC-5 (pool full: win steals least-remaining)**:
  - Given: all 8 nodes are PLAYING with known remaining times
  - When: `_claim_sfx_node(true)` is called
  - Then: the node with least remaining time is stopped and returned

- **AC-6 (silent mode: pool still initializes)**:
  - Given: AudioManager in silent-fallback mode
  - When: pool is initialized
  - Then: 8 nodes exist; state array is populated

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/audio_manager/sfx_pool_test.gd`
(gdUnit4) — must exist and pass.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (autoload + config + bus layout)
- Unlocks: Story 003 (randomization applied during play), Story 004
  (cooldown check before play), Story 005 (EventBus wiring triggers play)
