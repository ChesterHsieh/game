# Godot Engine — Version Reference

| Field | Value |
|-------|-------|
| **Engine Version** | Godot 4.3 |
| **Release Date** | August 2024 |
| **Project Pinned** | 2026-03-25 |
| **Last Docs Verified** | 2026-03-25 |
| **LLM Knowledge Cutoff** | May 2025 |
| **Risk Level** | LOW — version is within LLM training data |

## Knowledge Gap Status

Godot 4.3 is within the LLM's training data. API suggestions and code examples
should be reliable without extra cross-referencing. The existing breaking-changes.md
and deprecated-apis.md in this directory cover 4.4–4.6 changes that do NOT apply
to this project.

## Relevant Notes for Moments (2D card game)

- **Tween**: `create_tween()` and chained `.tween_property()` are stable in 4.3 — used extensively in Card Engine, Card Visual, Status Bar UI
- **Signals**: Standard signal syntax (`signal foo(bar: int)`) is fully supported
- **Autoloads**: Singleton autoloads work as expected — EventBus and CardDatabase pattern is valid
- **CanvasItem / Node2D**: 2D rendering stack is stable; z-order via `z_index` property
- **@onready**: Available and stable in 4.3

## Verified Sources

- Official docs: https://docs.godotengine.org/en/4.3/
- Changelog: https://github.com/godotengine/godot/blob/master/CHANGELOG.md
- Release notes: https://godotengine.org/releases/4.3/
