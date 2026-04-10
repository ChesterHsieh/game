# Path-Specific Rules

Rules in `.claude/rules/` are automatically enforced when editing files in matching paths (Claude Code).

**Cursor:** the same rules live under **`.cursor/rules/*.mdc`** with identical content and `globs` matching the path patterns below. Edit either copy in sync, or treat `.mdc` as the Cursor source of truth for path-scoped behavior.

---

| Rule File | Path Pattern | Enforces |
| ---- | ---- | ---- |
| `gameplay-code.md` | `src/gameplay/**` | Data-driven values, delta time, no UI references |
| `engine-code.md` | `src/core/**` | Zero allocs in hot paths, thread safety, API stability |
| `ai-code.md` | `src/ai/**` | Performance budgets, debuggability, data-driven params |
| `network-code.md` | `src/networking/**` | Server-authoritative, versioned messages, security |
| `ui-code.md` | `src/ui/**` | No game state ownership, localization-ready, accessibility |
| `design-docs.md` | `design/gdd/**` | Required 8 sections, formula format, edge cases |
| `narrative.md` | `design/narrative/**` | Lore consistency, character voice, canon levels |
| `data-files.md` | `assets/data/**` | JSON validity, naming conventions, schema rules |
| `test-standards.md` | `tests/**` | Test naming, coverage requirements, fixture patterns |
| `prototype-code.md` | `prototypes/**` | Relaxed standards, README required, hypothesis documented |
| `shader-code.md` | `assets/shaders/**` | Naming conventions, performance targets, cross-platform rules |
