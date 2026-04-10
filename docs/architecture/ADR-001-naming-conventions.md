# ADR-001: Naming Conventions — snake_case

> **Status**: Accepted
> **Date**: 2026-03-25
> **Decider**: Chester

## Context

Moments is written in GDScript. GDScript's official style guide recommends
snake_case for variables, functions, signals, and file names, and PascalCase for
classes and node types. Chester has a Python background, so snake_case is natural
and consistent with existing instincts.

## Decision

Use the following conventions throughout the codebase:

| Element | Convention | Example |
|---------|------------|---------|
| Variables | `snake_case` | `card_value`, `bar_id`, `decay_rate` |
| Functions | `snake_case` | `get_goal_config()`, `on_drag_started()` |
| Signals | `snake_case` | `bar_values_changed`, `hint_level_changed` |
| Files (.gd / .tscn) | `snake_case` | `card_visual.gd`, `status_bar_ui.tscn` |
| Classes / Nodes | `PascalCase` | `CardVisual`, `StatusBarSystem` |
| Autoloads (singletons) | `PascalCase` | `EventBus`, `CardDatabase` |
| Constants | `SCREAMING_SNAKE_CASE` | `MAX_VALUE`, `SNAP_RADIUS`, `STAGNATION_SEC` |

## Consequences

- Aligns with GDScript style guide — no friction with Godot editor tooling
- Consistent with Chester's Python background — no context-switching
- All GDD signal names already written in snake_case (e.g. `bar_values_changed`,
  `combination_executed`, `seed_cards_ready`) — no renaming required
