# ADR-002: Card Scene Structure — Object Pool

> **Status**: Accepted
> **Date**: 2026-03-25
> **Decider**: Chester

## Context

Cards are the primary game object in Moments. A scene can have ~20 cards on the
table at once. Combinations can spawn new cards and remove old ones — potentially
many times per session. Two approaches:

1. **Create/destroy**: Instantiate a new card scene on spawn, free it on removal.
   Simple, but GC pressure and instantiation cost can cause hitches.
2. **Object pool**: Pre-instantiate N card scenes at startup, recycle them via a
   free-list. Zero allocation cost at runtime; no GC pressure.

## Decision

Use an **object pool** managed by Card Spawning System.

- At startup, Card Spawning System instantiates `pool_size` card scenes and hides them.
- On spawn: take a card from the free list, configure it (set `card_id`, show it).
- On removal: reset the card (clear data, hide it), return it to the free list.
- Pool size: `pool_size = 30` (safe ceiling for any scene; tunable).

Card scenes are pre-instantiated as children of a pool container node, not added
to the scene tree dynamically. Only their visibility and position change at runtime.

## Consequences

- Zero instantiation cost during gameplay — no frame hitches on combination spawn
- Fixed memory footprint — all card memory allocated at startup
- Card Spawning System owns the pool; other systems never call `queue_free()` on cards
- Pool exhaustion (>30 cards simultaneously) logs a warning and falls back to
  dynamic instantiation — not expected in normal play
