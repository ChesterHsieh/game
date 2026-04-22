# Smoke Test: Critical Paths

**Purpose**: Run these checks in under 15 minutes before any QA hand-off.
**Run via**: `/smoke-check` (reads this file)
**Update**: Add new entries when new core systems are implemented.

## Core Stability (always run)

1. Game launches to main menu without crash
2. New game / session can be started from the main menu
3. Main menu responds to mouse input without freezing

## Core Mechanic (update per sprint)

4. Card can be dragged with mouse and released
5. Compatible cards snap together (magnetic snap fires)
6. Incompatible cards push away gently

## Data Integrity

7. Save game completes without error (once save system is implemented)
8. Load game restores correct state (once load system is implemented)

## Performance

9. No visible frame rate drops below 60fps on target hardware
10. No memory growth over 5 minutes of play (once core loop is implemented)
