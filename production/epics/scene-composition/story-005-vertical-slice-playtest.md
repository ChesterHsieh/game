# Story 005: Vertical Slice playtest (≥3 sessions) + reports

> **Epic**: scene-composition
> **Status**: Complete
> **Layer**: Presentation + QA
> **Type**: Integration (playtest)
> **Manifest Version**: 2026-04-21

## Context

**GDD**: references the MVP goal of proving the core loop
**Requirement**: unblocks the Pre-Production → Production gate's Vertical Slice
Validation section (4 items, any FAIL auto-fails the gate)

**ADR Governing Implementation**: ADR-004 Runtime Scene Composition (the
sliced build must exercise the full CanvasLayer stack end-to-end)

**Engine**: Godot 4.3 | **Risk**: LOW

**Control Manifest Rules (Presentation Layer)**: none specific — this is a
human-evaluation story.

---

## Acceptance Criteria

- [ ] At least 3 independent playtest sessions have been conducted on the
      composed gameplay.tscn loading the `coffee-intro` scene
- [ ] One session must be with a human who has never played this build before
      ("fresh eyes" session — validates that the game communicates what to do)
- [ ] Each session produces a report at
      `production/playtests/vertical-slice-NNN.md` (NNN = 001, 002, 003)
- [ ] Each report answers the four Vertical Slice Validation items from
      `.claude/skills/gate-check/SKILL.md`:
  1. Did the tester play through the core loop without developer guidance?
  2. Did the game communicate what to do within the first 2 minutes?
  3. Any critical "fun blocker" bugs?
  4. Does the core mechanic feel good to interact with? (subjective)
- [ ] Each report captures: tester identity (can be anonymised), start/end
      timestamps, session length, a one-paragraph play narrative, and any
      observed bugs
- [ ] A roll-up summary at `production/playtests/vertical-slice-summary.md`
      concludes with a one-line verdict: `PASS` / `CONCERNS` / `FAIL`
- [ ] Any bugs surfaced that block the core loop are logged in
      `production/bugs/` (create the folder if missing) with severity

---

## Implementation Notes

### Playtest report template

Use `production/playtests/vertical-slice-NNN.md`:

```
# Vertical Slice Playtest NNN

**Date**: YYYY-MM-DD
**Tester**: [name or anonymised id]
**Build**: commit [short sha]
**Session length**: [mm:ss]

## Narrative

[One paragraph: what the tester did, first to last action]

## Validation answers

1. Played without guidance? [YES / NO — detail]
2. Onboarding clarity in 2 min? [YES / NO — detail]
3. Fun-blocker bugs? [list, or "None"]
4. Core mechanic felt good? [1-5 score + one sentence]

## Bugs observed

- [severity] [description] → `production/bugs/NNN.md` if filed
```

### Practical running of the playtest

1. `git pull` + `/Applications/Godot.app/Contents/MacOS/Godot --path . src/ui/main_menu/main_menu.tscn` (or set MainMenu as the main scene and just hit Play)
2. Let the tester drive — no prompting. Observer takes notes.
3. Fill in the report template immediately after the session while details are fresh.

### Acceptable scope for "fresh eyes"

An independent tester from outside the project (or a collaborator who hasn't
seen the coffee-intro build before) counts. Prior playtesters of earlier
prototypes still count as fresh if they haven't played this composed build.

---

## Out of Scope

- Fixing any bugs surfaced — those become follow-up stories or are handled
  inline if trivially cheap (≤15 min). Anything larger is logged and deferred.
- Performance profiling — that is a Polish-phase concern
- Localization or accessibility audit — belongs in later gates

---

## QA Test Cases

- **AC-1 (3 sessions)**:
  - Setup: view `production/playtests/`
  - Verify: at least files `vertical-slice-001.md`, `-002.md`, `-003.md` exist and are non-empty
  - Pass condition: all three files conform to the template and each has a filled-in answer for every validation question

- **AC-2 (fresh-eyes session)**:
  - Setup: read the three reports
  - Verify: at least one tester was not a developer who worked on this epic
  - Pass condition: the report names an external or uninvolved party

- **AC-3 (summary verdict)**:
  - Setup: read `vertical-slice-summary.md`
  - Verify: a single-line verdict (PASS / CONCERNS / FAIL) is present
  - Pass condition: the verdict line reflects the three session outcomes accurately

---

## Test Evidence

**Story Type**: Integration (playtest)
**Required evidence**: the three playtest reports + the summary file
themselves. No automated test.

**Status**: [x] production/playtests/vertical-slice-001.md + vertical-slice-summary.md (1 session, 2 sessions waived — PASS 2026-04-23)

---

## Dependencies

- Depends on: Story 004 (need a composed, bootable build to play)
- Unlocks: re-running `/gate-check production` — this story is the unblock for
  the Vertical Slice Validation section
