# Technical Preferences

<!-- Populated by /setup-engine. Updated as the user makes decisions throughout development. -->
<!-- All agents reference this file for project-specific standards and conventions. -->

## Engine & Language

- **Engine**: Godot 4.3
- **Language**: GDScript
- **Rendering**: Godot 2D (CanvasItem / Node2D)
- **Physics**: Not used — card positions are code-driven (Card Engine owns all motion via Tween)

## Input & Platform

<!-- Written by /setup-engine. Read by /ux-design, /ux-review, /test-setup, /team-ui, and /dev-story -->
<!-- to scope interaction specs, test helpers, and implementation to the correct input methods. -->

- **Target Platforms**: [TO BE CONFIGURED — e.g., PC, Console, Mobile, Web]
- **Input Methods**: [TO BE CONFIGURED — e.g., Keyboard/Mouse, Gamepad, Touch, Mixed]
- **Primary Input**: [TO BE CONFIGURED — the dominant input for this game]
- **Gamepad Support**: [TO BE CONFIGURED — Full / Partial / None]
- **Touch Support**: [TO BE CONFIGURED — Full / Partial / None]
- **Platform Notes**: [TO BE CONFIGURED — any platform-specific UX constraints]

## Naming Conventions

- **Classes / Nodes**: `PascalCase` — `CardVisual`, `StatusBarSystem`
- **Variables / Functions**: `snake_case` — `card_value`, `get_goal_config()`
- **Signals**: `snake_case` — `bar_values_changed`, `hint_level_changed`
- **Files (.gd / .tscn)**: `snake_case` — `card_visual.gd`, `status_bar_system.tscn`
- **Constants**: `SCREAMING_SNAKE_CASE` — `MAX_VALUE`, `SNAP_RADIUS`
- **Autoloads (singletons)**: `PascalCase` — `EventBus`, `CardDatabase`

> Rationale: Chester has a Python background. GDScript snake_case aligns with both
> Python conventions and Godot's own style guide. See ADR-001.

## Performance Budgets

- **Target Framerate**: 60 fps
- **Frame Budget**: 16.7ms — card physics is Tween-based, not simulation; budget is generous
- **Draw Calls**: < 50 per frame (2D card game with ~20 cards on screen max)
- **Memory Ceiling**: < 256MB (desktop/Mac target)

## Testing

- **Framework**: [TO BE CONFIGURED — GUT or gdUnit4; decide before first test]
- **Minimum Coverage**: Core gameplay systems (Card Engine, Status Bar System, Hint System)
- **Required Tests**: Card Engine state machine, bar math formulas, hint timer logic

## Forbidden Patterns

<!-- Add patterns that should never appear in this project's codebase -->
- [None configured yet — add as architectural decisions are made]

## Allowed Libraries / Addons

<!-- Add approved third-party dependencies here -->
- [None configured yet — add as dependencies are approved]

## Architecture Decisions Log

<!-- Quick reference linking to full ADRs in docs/architecture/ -->
- [ADR-001](../../docs/architecture/ADR-001-naming-conventions.md) — Naming conventions: snake_case (GDScript / Python alignment)
- [ADR-002](../../docs/architecture/ADR-002-card-object-pooling.md) — Card scene structure: object pool over create/destroy
- [ADR-003](../../docs/architecture/ADR-003-signal-bus.md) — Inter-system communication: EventBus singleton over direct node references
