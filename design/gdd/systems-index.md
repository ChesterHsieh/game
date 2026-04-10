# Systems Index: Moments

> **Status**: Draft
> **Created**: 2026-03-23
> **Last Updated**: 2026-03-23
> **Source Concept**: design/gdd/game-concept.md

---

## Overview

Moments is a 2D card-discovery game with a fully handcrafted content layer. The
mechanical scope is focused — no combat, no AI, no procedural generation — but the
card interaction engine must feel physically satisfying and the template framework
must be data-driven enough to author 150+ unique combinations without code changes.

The system stack has three load-bearing layers: the Card Engine (feel), the
Interaction Template Framework (behavior variety), and the Scene Goal System
(structure). Everything else is either data, UI, or wrapper. Prototype the Card
Engine first — if the magnetic snap doesn't feel right, nothing else matters.

---

## Systems Enumeration

| # | System Name | Category | Priority | Status | Design Doc | Depends On |
|---|-------------|----------|----------|--------|------------|------------|
| 1 | Card Database | Core | MVP | Designed | design/gdd/card-database.md | — |
| 2 | Recipe Database | Core | MVP | Designed | design/gdd/recipe-database.md | Card Database |
| 3 | Input System | Core | MVP | Designed | design/gdd/input-system.md | — |
| 4 | Audio Manager | Core | Vertical Slice | Not Started | — | — |
| 5 | Card Engine | Gameplay | MVP | Designed | design/gdd/card-engine.md | Input System, Card Database |
| 6 | Table Layout System | Gameplay | MVP | Designed | design/gdd/table-layout-system.md | Card Database |
| 7 | Card Spawning System | Gameplay | MVP | Designed | design/gdd/card-spawning-system.md | Card Database, Table Layout System |
| 8 | Interaction Template Framework | Gameplay | MVP | Designed | design/gdd/interaction-template-framework.md | Card Engine, Recipe Database, Card Spawning System |
| 9 | Status Bar System | Gameplay | MVP | Designed | design/gdd/status-bar-system.md | Interaction Template Framework |
| 10 | Scene Goal System | Gameplay | MVP | Designed | design/gdd/scene-goal-system.md | Status Bar System |
| 11 | Hint System | Gameplay | MVP | Designed | design/gdd/hint-system.md | Scene Goal System, Status Bar System, Interaction Template Framework |
| 12 | Card Visual | UI | MVP | Designed | design/gdd/card-visual.md | Card Database, Card Engine |
| 13 | Status Bar UI | UI | MVP | Designed | design/gdd/status-bar-ui.md | Status Bar System, Hint System |
| 14 | Scene Manager | Core | Vertical Slice | Not Started | — | Card Spawning System, Table Layout System, Scene Goal System |
| 15 | Mystery Unlock Tree | Gameplay | Vertical Slice | Not Started | — | Interaction Template Framework, Scene Manager |
| 16 | Scene Transition UI | UI | Vertical Slice | Not Started | — | Scene Goal System, Scene Manager |
| 17 | Main Menu | UI | Vertical Slice | Not Started | — | Scene Manager |
| 18 | Final Epilogue Screen | UI | Alpha | Not Started | — | Mystery Unlock Tree |
| 19 | Save/Progress System | Persistence | Alpha | Not Started | — | Mystery Unlock Tree, Scene Manager |
| 20 | Settings | Meta | Full Vision | Not Started | — | Audio Manager |

---

## Categories

| Category | Description | Systems in Moments |
|----------|-------------|-------------------|
| **Core** | Foundation systems everything depends on | Card Database, Recipe Database, Input System, Audio Manager, Scene Manager |
| **Gameplay** | Systems that make the game function | Card Engine, Table Layout, Card Spawning, Interaction Template Framework, Status Bar System, Scene Goal System, Hint System, Mystery Unlock Tree |
| **UI** | Player-facing displays | Card Visual, Status Bar UI, Scene Transition UI, Main Menu, Final Epilogue Screen |
| **Persistence** | Save state | Save/Progress System |
| **Meta** | Outside the core loop | Settings |

---

## Priority Tiers

| Tier | Definition | Systems Count |
|------|------------|--------------|
| **MVP** | One complete scene (Home), ~20 cards, magnetic snap, sustain goal, hint arcs | 12 |
| **Vertical Slice** | Multiple scenes, scene-to-scene progression, transitions, main menu, audio | 5 |
| **Alpha** | Full game: epilogue, save/progress | 2 |
| **Full Vision** | Settings and polish | 1 |

---

## Dependency Map

### Foundation Layer (no dependencies)

1. **Card Database** — all card definitions; every other system references card IDs; design this before touching any code
2. **Recipe Database** — all combination rules; pure data that the Interaction Template Framework reads at runtime
3. **Input System** — mouse drag and hover detection; thin wrapper over Godot's built-in input
4. **Audio Manager** — sound bus management; standalone; called by other systems via signal or direct call

### Core Layer (depends on Foundation)

1. **Card Engine** — depends on: Input System, Card Database — the drag/magnetic/push physics; the 30-second loop
2. **Table Layout System** — depends on: Card Database — spatial card management, z-ordering, where new cards land
3. **Card Spawning System** — depends on: Card Database, Table Layout System — creating and removing cards from the table

### Feature Layer (depends on Core)

1. **Interaction Template Framework** — depends on: Card Engine, Recipe Database, Card Spawning System — executes the 4 template types; load-bearing system
2. **Status Bar System** — depends on: Interaction Template Framework — tracks bar values, detects win condition
3. **Scene Goal System** — depends on: Status Bar System — per-scene goal type + parameters, completion logic
4. **Hint System** — depends on: Scene Goal System, Status Bar System — timer + delayed arc fade-in; no text ever
5. **Scene Manager** — depends on: Card Spawning System, Table Layout System, Scene Goal System — scene loading, seed card setup, transition trigger
6. **Mystery Unlock Tree** — depends on: Interaction Template Framework, Scene Manager — tracks discovered combinations, unlocks scenes

### Presentation Layer (depends on Feature)

1. **Card Visual** — depends on: Card Database, Card Engine — card rendering, labels, art display
2. **Status Bar UI** — depends on: Status Bar System, Hint System — bars + counterclockwise arc indicators
3. **Scene Transition UI** — depends on: Scene Goal System, Scene Manager — breakthrough animation on scene complete
4. **Main Menu** — depends on: Scene Manager — minimal start screen
5. **Final Epilogue Screen** — depends on: Mystery Unlock Tree — special illustrated memory reveal

### Polish Layer

1. **Save/Progress System** — depends on: Mystery Unlock Tree, Scene Manager — scene completion and discovery persistence
2. **Settings** — depends on: Audio Manager — volume controls

---

## Recommended Design Order

| Order | System | Priority | Layer | Est. Effort |
|-------|--------|----------|-------|-------------|
| 1 | Card Database | MVP | Foundation | S |
| 2 | Recipe Database | MVP | Foundation | S |
| 3 | Input System | MVP | Foundation | S |
| 4 | Audio Manager | MVP | Foundation | S |
| 5 | Card Engine | MVP | Core | M |
| 6 | Table Layout System | MVP | Core | S |
| 7 | Card Spawning System | MVP | Core | S |
| 8 | Interaction Template Framework | MVP | Feature | M |
| 9 | Status Bar System | MVP | Feature | S |
| 10 | Scene Goal System | MVP | Feature | M |
| 11 | Hint System | MVP | Feature | S |
| 12 | Card Visual | MVP | Presentation | S |
| 13 | Status Bar UI | MVP | Presentation | S |
| 14 | Scene Manager | Vertical Slice | Feature | M |
| 15 | Mystery Unlock Tree | Vertical Slice | Feature | M |
| 16 | Scene Transition UI | Vertical Slice | Presentation | S |
| 17 | Main Menu | Vertical Slice | Presentation | S |
| 18 | Final Epilogue Screen | Alpha | Presentation | M |
| 19 | Save/Progress System | Alpha | Polish | S |
| 20 | Settings | Full Vision | Polish | S |

*Effort: S = 1 session, M = 2–3 sessions. A session = one focused design conversation producing a complete GDD.*

*Independent systems at the same layer can be designed in parallel.*

---

## Circular Dependencies

None found.

---

## High-Risk Systems

| System | Risk Type | Risk Description | Mitigation |
|--------|-----------|-----------------|------------|
| Card Engine | Technical | Magnetic snap feel is subtle — too strong feels sticky, too weak feels loose | Prototype this before designing anything else; iterate on feel before writing content |
| Interaction Template Framework | Design + Technical | Load-bearing data-driven system; must be extensible enough to add new template types without code changes | Design the data schema carefully; prototype all 4 templates early with placeholder cards |
| Scene Goal System | Design | Hidden goals can feel frustrating if too opaque; calibrating the discovery curve is guesswork until playtested | Design the Hint System in parallel; build in a fallback reveal timer from day one |
| Card Database | Scope | ~150 cards means ~150 memories to write — content creation is the dominant workload | Start writing card content early, parallel to code; the database schema must be locked before content work begins |

---

## Progress Tracker

| Metric | Count |
|--------|-------|
| Total systems identified | 20 |
| Design docs started | 12 |
| Design docs reviewed | 0 |
| Design docs approved | 0 |
| MVP systems designed | 12 / 12 |
| Vertical Slice systems designed | 0 / 4 |

---

## Next Steps

- [ ] Design MVP systems in order (use `/design-system [system-name]`)
- [ ] **Prototype Card Engine first** — validate magnetic feel before writing content
- [ ] Start writing card content in parallel — the memories are the game
- [ ] Run `/design-review` on each completed GDD
- [ ] Run `/gate-check pre-production` when MVP systems are designed
