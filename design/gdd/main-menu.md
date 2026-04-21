# Main Menu

> **Status**: In Design (post-revision)
> **Author**: Chester + Claude Code agents
> **Last Updated**: 2026-04-21
> **Implements Pillar**: Pillar 3 (Discovery Without Explanation), Pillar 4 (Personal Over Polished)

## Overview

Main Menu is the initial Godot scene that loads at game launch — a minimal entry point showing the game's title and a single Start button. Mechanically, it is a UI-layer presentation node that owns nothing but its own widgets; activating Start instructs Scene Manager to begin the first chapter, after which Main Menu frees itself. Scene Manager's `_ready()` no longer auto-loads scene 0 at startup; it waits for Main Menu (or, later, Save/Progress System) to hand off.

For Ju, Main Menu is the doorway. It is the first thing she sees when the icon on her desktop is clicked — the first breath of a game made entirely for her. Its job is not to display options (there are none) but to set the tone: this is small, this is quiet, this was made by hand. A single soft title, a single soft button, nothing else between her and the first chapter.

The menu contains two visible elements: the game's title and a Start button. There is no Quit button (Esc and the OS window-close already cover exit; a second labeled action would turn a doorway into a lobby), no Settings screen at Vertical Slice (Settings is a Full Vision system), no Continue option (Save/Progress is Alpha), and no branching into scene selection (the story is told in the order Chester wrote it — see Scene Manager). Activating Start triggers a fade via Scene Transition UI, after which the first scene's seed cards appear.

## Player Fantasy

Main Menu is the still object Ju encounters before the game begins. Its job is not to welcome her, not to perform, not to animate itself for attention — its job is to sit there and wait, and trust her to press Start when she is ready.

What she should feel in the five to thirty seconds she lingers here is stillness with a small inward recognition. The title sits like a closed book on a shelf. She reads it, something in it is already familiar (the word, a softness, a color Chester chose knowing she would see it), and the recognition produces a quiet shift in her — not a smile she'd show anyone, just the registration of *oh, this*. The screen does not ask her to do anything. The cursor is motionless. The title does not breathe, sway, or pulse. Thirty seconds pass and nothing changes. This absence of motion is the feature: the menu trusts her to wait.

Underneath that stillness, there is a thin thread of threshold. She is aware, as her hand rests on the mouse, that pressing Start is crossing into somewhere specific — not launching an app but entering a room. The menu gives her the dignity of choosing her own moment to cross. When she presses Start, it is because she has decided to, not because the screen has nudged her.

A single visible action keeps the moment undivided. If the screen offered Start *and* Quit as two equal buttons, the first decision of the game would become "which of these do I click" — a software-utility prompt. The doorway framing depends on there being only one thing to cross through. Exit still exists for completeness (Esc key and the OS window-close are always available), but it is not offered as a peer to Start.

Main Menu is successful when Ju's first contact with the game feels like picking up something handmade rather than launching software. It fails the moment it tries to be cinematic, the moment it tries to reassure her it is running, the moment it puts a "For Ju" text on screen instead of letting the menu's own smallness say it. Restraint is the entire expression.

*Serves*: Pillar 3 (Discovery Without Explanation) — no text instructions, no prompts, the menu teaches its own use by being simple enough to need no teaching. Pillar 4 (Personal Over Polished) — restraint over motion, silence over splash, a single hand-drawn title and a hand-lettered button that make the entire surface read as one author's hand.

## Detailed Design

### Core Rules

**1. Scene Role**
- Main Menu is a self-contained Godot scene at `res://src/ui/main_menu/main_menu.tscn`, set as the project's `run/main_scene` in `project.godot`. It is not an autoload.
- It owns no game-state data, holds no references to other systems, and is freed by Godot when the scene is switched.

**2. Rendered Elements**
- Main Menu renders exactly two visible widgets inside a `CenterContainer → VBoxContainer`:
  1. A `TextureRect` displaying the game's title — a hand-drawn PNG.
  2. A `TextureButton` displaying a hand-lettered "Start" — also a PNG.
- Both the title and the button label are single-author PNGs (Chester's hand). This is a deliberate Pillar 4 decision: the Start button uses the same authoring pipeline as the title so the two elements read as one person's hand, not "title = personal, buttons = UI font." No DynamicFont is used for menu text.
- No additional widgets, no background animations, no particles, no decorative elements. Restraint is the design (see Player Fantasy).
- **Full Vision exception**: a small gear icon (Settings trigger, per `design/gdd/settings.md`) is added in a separate top-right corner container — *outside* the `CenterContainer` — at Full Vision tier. The gear is not counted among the "two widgets" of this rule because it is not part of the centered composition; it is a corner affordance. At Vertical Slice / Alpha, the gear does not exist.

**3. Boot Behavior**
- On `_ready()`, Main Menu:
  1. Calls `%StartButton.grab_focus()` so the keyboard has a default target.
  2. Enters `Idle` state.
  3. Emits no signals and performs no game logic.

**4. Start Activation**
- The Start button is activated by mouse click, keyboard `Enter` (on focused button), or `Space` (Godot default `ui_accept` for focused buttons).
- When Start is activated:
  1. Main Menu enters `Starting` state.
  2. The Start button is disabled (`disabled = true`) to block double-press during the scene switch.
  3. Main Menu calls `get_tree().change_scene_to_file("res://src/scenes/gameplay.tscn")` and captures the synchronous return value.
  4. If the return is non-`OK` (realistically only an empty-path or argument-rejection case — see Edge Cases), Main Menu logs a fatal error, re-enables the button, and returns to `Idle`.
  5. On `OK` (the overwhelming majority of real execution paths), Godot queues the scene switch and will free Main Menu on the next frame. Main Menu's role ends.
- `gameplay.tscn` (owned by a future architecture decision — see Open Questions) contains the runtime UI hosts: Scene Transition UI, Card Table, Status Bar UI, and any other scene-scoped presentation nodes. Its root `_ready()` emits `EventBus.game_start_requested()` after its children finish `_ready()`.
- Scene Manager, in its `Waiting` state, responds by calling `_load_scene_at_index(0)` — which emits `scene_loading(scene_id)` as Step 1 of the existing load sequence. Scene Transition UI (now in the tree) handles the visual fade via its `FIRST_REVEAL` state.

**5. Quit via Esc (only)**
- There is no visible Quit button. The only Main-Menu-owned quit path is the `Esc` key, bound via `_unhandled_input` on the Main Menu root.
- Esc triggers `get_tree().quit()` only while Main Menu is in `Idle`. Pressing Esc during `Starting` or `Exiting` is ignored (guarded by the state check — see Edge Cases).
- OS-level window-close (Alt+F4, Cmd+Q, red X) is handled by Godot's default and is unrelated to Main Menu's logic. This is the canonical exit affordance for users who expect a GUI way to quit.

**6. No Game-State Coupling**
- Main Menu does not read or write any game state (no card data, no scene manifest, no save data). It does not instantiate Scene Transition UI, Card Engine, Status Bar UI, or any gameplay node. It also does not instance Scene Manager or any other autoload (they exist independently via `project.godot`).

**7. EventBus Signal Declaration**
- `EventBus` must declare a new parameterless signal: `signal game_start_requested()`. This is used only once per session (for the initial transition into chapter one). The declaration is applied in ADR-003's EventBus code block as part of this GDD's bundled commit.

**8. Scene Manager Behavioral Change (required companion edit)**
- Scene Manager's existing Core Rule 2 ("On `_ready()`, Scene Manager calls `_load_scene_at_index(0)`") must be replaced with a `Waiting` state. The exact Scene Manager rule text is owned by `design/gdd/scene-manager.md`; this GDD only states the contract:
  - SM enters a new `Waiting` state on `_ready()`.
  - SM connects to `EventBus.game_start_requested` in `_ready()` using `CONNECT_ONE_SHOT` so the connection is consumed by the first and only emission and cannot accumulate across any hypothetical later re-emission.
  - On receipt of `game_start_requested`: SM transitions `Waiting → Loading` and calls `_load_scene_at_index(0)`.
- Rationale for `_ready()` + `CONNECT_ONE_SHOT` (not `_enter_tree`): `gameplay.tscn` does not exist at autoload initialization, so there is no early-signal race to protect against with `_enter_tree`. The real concern is that Scene Manager is a long-lived autoload that must accept exactly one `game_start_requested` per session; `CONNECT_ONE_SHOT` makes that invariant explicit in code.
- This edit is a cross-GDD dependency and must ship in the same commit as Main Menu implementation. Tracked in session state and in Scene Manager's revision log.

### States and Transitions

| State | Entry Condition | Exit Condition | Behavior |
|---|---|---|---|
| `Idle` | `_ready()` completes, or `Starting → Idle` recovery on synchronous scene-switch error | Start activated, or Esc pressed | Start button focused and enabled; input accepted |
| `Starting` | Start activated | Godot frees this scene during `change_scene_to_file` (normal path), or `change_scene_to_file` returns a synchronous error (recovery path) | Start button disabled; scene switch in progress; input to Esc is ignored |
| `Exiting` | Esc pressed while in `Idle` | `get_tree().quit()` returns | `get_tree().quit()` called; application terminates |

**Transitions:**
- `Idle → Starting`: Start button pressed (mouse, Enter, or Space).
- `Idle → Exiting`: Esc pressed while in `Idle`.
- `Starting → (gone)`: `change_scene_to_file()` frees Main Menu's node tree (the expected path for all realistic cases; see Edge Cases on deferred failures).
- `Starting → Idle`: `change_scene_to_file()` returns a synchronous non-`OK` error (e.g., empty path). The Start button is re-enabled and focus is returned.
- `Exiting → (gone)`: OS closes the process.

The `Idle` recovery from `Starting` applies only to synchronous failures visible in the return value. Deferred failures (missing `.tscn` file, parse errors, script errors in `gameplay.tscn`) are not visible here and are detected by Scene Manager's `Waiting`-state watchdog (see Scene Manager OQ-2 / Edge Cases below).

### Interactions with Other Systems

| System | Direction | Interface |
|---|---|---|
| **Godot Scene Tree** | Main Menu → Tree | `get_tree().change_scene_to_file(...)` on Start. `get_tree().quit()` on Esc. `grab_focus()` on Start button at `_ready()`. |
| **EventBus** (ADR-003) | Indirect — no direct emission from Main Menu | Main Menu itself emits nothing. The `game_start_requested` signal is emitted by `gameplay.tscn`'s root after Main Menu has freed itself. Main Menu subscribes to no signals. |
| **Scene Manager** | No direct coupling | SM's `Waiting` state and its subscription to `game_start_requested` live entirely within the SM GDD. Main Menu does not call SM methods or read SM state. |
| **Scene Transition UI** | No direct coupling | STUI is not instanced in `main_menu.tscn`. It exists only after `gameplay.tscn` loads. The visual handoff is handled by STUI's existing `FIRST_REVEAL` state — Main Menu is unaware of STUI. |
| **Audio Manager** | No coupling at Vertical Slice | No menu music is specified for Vertical Slice. If menu ambient audio is added later, Main Menu would emit a new signal (e.g., `menu_entered`) — out of scope here. |
| **gameplay.tscn** (downstream container) | Main Menu → Godot → gameplay.tscn (via `change_scene_to_file`) | Main Menu names the target scene path. `gameplay.tscn`'s root script is responsible for emitting `game_start_requested` after its `_ready()` completes. The definition of `gameplay.tscn`'s composition is an architecture concern (see Open Questions). |

**Cross-reference note**: Scene Manager GDD is revised to remove Core Rule 2's auto-load behavior, add the `Waiting` state, and list Main Menu as a caller via EventBus in its Downstream table. ADR-003's EventBus code block declares `signal game_start_requested()`.

## Formulas

Main Menu performs no calculations. It is a presentation-layer scene whose entire behavior is input-driven state switching. There are no scoring values, balance parameters, scaling curves, timers, or numeric thresholds.

Cross-references (math owned by other systems):
- Fade-in/out timing for the transition to chapter 1 → Scene Transition UI (`design/gdd/scene-transition-ui.md`)
- Scene load sequence timing → Scene Manager (`design/gdd/scene-manager.md`)
- Color values for button states → Visual/Audio Requirements section below (Godot Theme values, not design formulas)

## Edge Cases

### Input Races

- **If Start is pressed twice in rapid succession (double-click or held Enter):** The second press is ignored — Rule 4 step 2 disables the button on the first press before `change_scene_to_file` is called. Rationale: Godot processes input events in the same frame as the button handler, so the disabled state is in effect before any queued second event fires.

- **If Esc is pressed while in `Starting` or `Exiting` state:** The `_unhandled_input` handler must check `_state == State.IDLE` before calling `get_tree().quit()`. Pressing Esc mid-scene-switch would terminate the process during `change_scene_to_file`, abandoning partial initialisation of `gameplay.tscn`. Resolution: guard Esc on state.

- **If `_unhandled_input` fires twice in the same frame with Esc (unlikely but theoretically possible with buffered input):** The first call transitions to `Exiting` and calls `quit()`; the second call sees `_state != IDLE` and exits early via the guard above. No double-quit possible; the process is already terminating.

### Scene Switch Failures

`change_scene_to_file` in Godot 4.3 returns `OK` synchronously for all well-formed, non-empty path arguments and queues the actual load for the next frame. A realistic class of failures (missing `.tscn`, case-mismatched path, parse error, script error in `gameplay.tscn`) therefore surfaces *asynchronously* — after Main Menu is already freed — and cannot be caught by this system.

- **If `change_scene_to_file` returns a synchronous non-`OK` error (empty path, or other argument-level rejection):** Main Menu captures the error value, logs a fatal error naming the path, re-enables the Start button, and transitions `Starting → Idle` so the user can retry or press Esc. This is the only recoverable failure visible to Main Menu — it represents a code bug (the constant path is malformed) rather than a deployment issue.

- **If the hardcoded path `res://src/scenes/gameplay.tscn` is missing, misspelled, case-mismatched, or contains a malformed script:** `change_scene_to_file` returns `OK`, Main Menu is freed on the next frame, and `gameplay.tscn` fails to instantiate or its root script never emits `game_start_requested`. Main Menu cannot detect or recover from this class of failure. Detection belongs to Scene Manager's `Waiting`-state watchdog (tracked as Scene Manager OQ-2, minimum 30-second dev-only timeout with a loud log). Cross-platform deployment must verify exact casing before release.

- **If `gameplay.tscn` loads successfully but its root script errors before emitting `game_start_requested`:** Same class as above — invisible to Main Menu. Scene Manager's watchdog catches it.

### OS and Window Events

- **If the OS fires a window close event (Alt+F4, red X, Cmd+Q, dock quit) in any state:** Godot's default window-close handler calls `get_tree().quit()` regardless of Main Menu state. This is expected behavior — declared, not suppressed. Any partial initialisation mid-`Starting` is abandoned by the OS.

- **If the window is resized or the display DPI changes while on the menu:** `Control` anchors (`PRESET_FULL_RECT`) and `CenterContainer` re-layout automatically. No code-level reaction needed. The title and Start PNGs scale via their `stretch_mode` settings, preserving aspect ratio.

- **If the window loses focus (Alt+Tab):** Standard Godot behavior — keyboard events are not delivered to the window. Main Menu remains in `Idle`; the player resumes where they left off when focus returns. No handling required.

### Input and Focus

- **If the game is launched in a headless context (CI, test runner) where `grab_focus()` has no effect:** Godot logs a warning and proceeds. Declared as acceptable non-behavior — headless launches are not player-facing.

- **If the user clicks away from the Start button (focus lost to the empty background):** `Control` nodes can lose focus when clicked outside any button. Resolution: when `_unhandled_input` receives any keyboard event (`ui_accept`, `ui_focus_next`, or any other key press) while no focus owner exists, re-focus the Start button before processing the event. Keeps keyboard-only navigation recoverable without visual noise on mouse users.

### Data and Assets

- **If the Start-button PNG or Title PNG is missing:** Godot renders an empty TextureRect / TextureButton. The button still activates on click, Enter, or Space because the `pressed` signal fires regardless of texture. Declared as acceptable fallback for dev-environment build failures; final builds must verify both PNGs are present (added to pre-release checklist).

- **If EventBus has not declared the `game_start_requested` signal:** The failure surfaces inside `gameplay.tscn`, not Main Menu — the emit call raises a runtime error. Caught at first run during implementation. Declared as a companion-edit risk, tracked in the Rule 7 reminder and verified by the Pre-Implementation Checklist below.

### Load-Window Experience

- **Expected duration from Start press to `gameplay.tscn` `_ready()` completion:** under 200 ms on a modern SSD. During this window, Main Menu shows its disabled Start-button state (faded color, see Visual/Audio Requirements) — this is the intentional feedback for "the press was received and the doorway is opening." No additional motion, sound, or progress indicator is introduced; the color fade *is* the confirmation.
- **If load exceeds 500 ms:** the disabled-button state continues to hold; Scene Manager's watchdog (tracked as Scene Manager OQ-2) is responsible for any developer-visible error if load never completes. Player-facing behavior remains "button stays faded" — no timeout spinner is shown.

### Pre-Implementation Checklist

Before writing the first line of Main Menu code, verify:
1. `design/gdd/scene-manager.md` Core Rule 2 has been replaced with the `Waiting` state (this revision — completed).
2. `docs/architecture/ADR-003-signal-bus.md` declares `signal game_start_requested()` (this revision — completed).
3. `res://src/scenes/gameplay.tscn` exists, with a root script that emits `EventBus.game_start_requested()` after its children finish `_ready()` (blocked on OQ-1 ADR).
4. `res://assets/ui/ui_title_moments_static_large.png` and `res://assets/ui/ui_button_start_hand.png` both exist in-tree (blocked on OQ-4 asset commission).

AC-START-4's end-to-end pass depends on all four being in place. A story that begins Main Menu implementation without checking these will watch AC-START-4 fail silently with no single file to blame.

## Dependencies

### Upstream (this system depends on)

| System | What We Need | Hardness |
|--------|-------------|----------|
| **Scene Manager** | A Scene Manager instance that listens for `EventBus.game_start_requested` in its new `Waiting` state and begins scene 0 on receipt. Without the Scene Manager GDD edit removing the `_ready()` auto-load, Main Menu would never reach a usable gameplay state. | Hard — Main Menu's exit path requires Scene Manager's `Waiting`→`Loading` transition to exist |
| **EventBus** (ADR-003) | A declared `signal game_start_requested()` on the EventBus autoload. Emitted by `gameplay.tscn`, consumed by Scene Manager. | Hard — companion edit to ADR-003 is required for `gameplay.tscn` to emit the signal |
| **gameplay.tscn** (container scene) | A `.tscn` at `res://src/scenes/gameplay.tscn` whose root script emits `EventBus.game_start_requested()` after `_ready()` completes. The scene must contain Scene Transition UI, Card Table, Status Bar UI, and any other scene-scoped runtime nodes. | Hard — Main Menu's Start action calls `change_scene_to_file` on this path; the scene must exist and behave correctly |
| **Godot Control/Theme** | Functional `Control`, `CenterContainer`, `VBoxContainer`, `TextureRect`, and `TextureButton` nodes. Minimal Theme resource for button focus/disabled color modulation. | Soft — falls back to Godot defaults if Theme is missing |

### Downstream (systems that depend on this)

| System | What They Need | Hardness |
|--------|---------------|----------|
| _(none)_ | Main Menu is a terminal presentation node. No other system listens to it, reads its state, or calls its methods. Its only output is the scene switch to `gameplay.tscn`, which triggers downstream chains indirectly. | — |

### External Data

| Asset | Path | Description |
|-------|------|-------------|
| **Main Menu scene** | `res://src/ui/main_menu/main_menu.tscn` | The scene itself. Set as `run/main_scene` in `project.godot`. |
| **Gameplay container scene** | `res://src/scenes/gameplay.tscn` | Loaded via `change_scene_to_file` on Start. Owns all runtime UI/gameplay hosts. Architecture TBD — see Open Questions. |
| **Title PNG** | `res://assets/ui/ui_title_moments_static_large.png` | Hand-drawn title, single-author. See Visual/Audio Requirements. |
| **Start button PNG** | `res://assets/ui/ui_button_start_hand.png` | Hand-lettered "Start," single author, same pipeline as title. See Visual/Audio Requirements. |
| **Main Menu Theme** | `res://assets/themes/main_menu.tres` (proposed path) | Godot Theme resource for button-state modulation (normal, hover, focus, disabled colors applied over the base PNG). |

### Signals Emitted

| Signal | Parameters | Fired When |
|--------|------------|-----------|
| _(none)_ | — | Main Menu emits no EventBus signals. The `game_start_requested` signal is owned by `gameplay.tscn`. |

### Signals Listened To

| Signal | Source | Handled When |
|--------|--------|-------------|
| _(none)_ | — | Main Menu subscribes to no EventBus signals. All input is local Godot UI input (button `pressed`, `_unhandled_input`). |

**Companion edits bundled with Main Menu implementation (this revision applies all of them):**
1. **Scene Manager GDD** (`design/gdd/scene-manager.md`): Core Rule 2 replaced with `Waiting` state; subscription via `_ready()` + `CONNECT_ONE_SHOT`; Main Menu added to Downstream table.
2. **ADR-003** (`docs/architecture/ADR-003-signal-bus.md`): `signal game_start_requested()` declared in the EventBus code block.
3. **Scene Transition UI GDD** (`design/gdd/scene-transition-ui.md`): downstream reference to Main Menu de-staled (no longer "undesigned").
4. **Systems Index** (`design/gdd/systems-index.md`): after approval, row 17 marked Designed/Approved.

## Tuning Knobs

Main Menu has minimal runtime-tunable values. Its behavior is almost entirely authored — the only code-level knobs are the target scene path and the Esc-to-quit enable flag, kept as constants for testability.

| Knob | Type | Default | Safe Range | Too Low / Too High |
|------|------|---------|------------|---------------------|
| `GAMEPLAY_SCENE_PATH` | `const String` | `"res://src/scenes/gameplay.tscn"` | Any valid resource path | Wrong path → deferred scene-load failure; caught by Scene Manager watchdog (OQ-2), not here |
| `ESC_QUIT_ENABLED` | `const bool` | `true` | `true` / `false` | If `false`, Esc does nothing — OS window-close (Alt+F4 / Cmd+Q) remains the only quit path. Useful for harnessed playtest sessions |

*Both knobs are declared as `const` (not `@export`). `@export` and `const` are mutually exclusive in GDScript; `const` is the correct choice for values that should not be live-editable from the inspector. If inspector-editability is ever wanted, convert to `@export var` with a default.*

**Authored knobs (not runtime — owned by asset files):**

| Knob | Owner | Description |
|------|-------|-------------|
| Title artwork | `res://assets/ui/ui_title_moments_static_large.png` | The game's displayed title — hand-drawn PNG. Content, not config. |
| Start button artwork | `res://assets/ui/ui_button_start_hand.png` | Hand-lettered "Start" PNG. Content, not config. |
| Button state modulation (hover, focus, disabled colors) | `res://assets/themes/main_menu.tres` (Theme resource) | Color `modulate` values applied over the base PNG to signal state. Exact values owned by art direction. |
| VBox separation (title → button) | Same Theme resource | Controls the breathing room between title and button. |

**Notes:**
- No numeric gameplay parameter lives in Main Menu. All "feel" knobs are Theme values, edited in the Godot editor rather than code.
- Because button text is baked into a PNG (single-author Pillar 4 decision), there are no translation keys for menu text. Multi-locale support, if ever scoped, is an OQ — see Open Questions.

## Visual/Audio Requirements

All visual values here originate from the art-director's direction for this system. They double as seed principles for the future Art Bible.

### Background

Full-viewport static texture: **warm off-white watercolor paper wash**, matte, no gradient, no vignette, no edge glow.

- Primary color: `#F5EFE4` (aged linen white, warm lean)
- Fallback (solid, if texture unavailable): `#F2EBD9`
- Asset: `res://assets/ui/env_bg_paper_grain_large.png` — high-resolution paper scan (≥ 2048×2048) tiled or scaled to fill the viewport
- Subtle paper tooth visible on close inspection, invisible at a glance

### Title

The title is a **hand-drawn static PNG**, not a Label node.

- Rationale: Moments is authored for one player; the title should look like Chester wrote it. A PNG avoids locale/font substitution and keeps the letterform as character.
- Asset: `res://assets/ui/ui_title_moments_static_large.png`
- Letterform style: casual handwritten, Sharpie-on-cardstock weight — not calligraphic, not brush-pen
- Size: ~30–35% of viewport width; height follows natural letter proportions
- Color baked into the PNG: `#2B2420` (dark brown-black — warm, not pure black)
- Kerning: slightly looser than default type; baked into the asset

### Start Button

The button label is a **hand-lettered static PNG**, authored in the same pipeline as the title so the full menu reads as a single hand.

- Rationale (Pillar 4): if the title is Chester's actual letterform and the button is a Google Font, the two elements sit six inches apart on screen and the eye reads "personal" vs "interface." Treating the button as a PNG keeps the surface single-author and preserves Pillar 4 coherence.
- Asset: `res://assets/ui/ui_button_start_hand.png`
- Letterform: visually subordinate to the title — slightly lighter weight, same ink color, smaller scale (~55–65% of the title's visual weight)
- Color baked into the PNG: `#5C4A3E` (faded ink — default state)
- Node type: `TextureButton` so the button retains Godot's focus/hover/press semantics
- **No DynamicFont is used anywhere in this menu.** Any future labeled UI elsewhere in the game may use DynamicFont; Main Menu explicitly does not.

**State modulation** (applied as `modulate` color on the TextureButton — the base PNG color `#5C4A3E` is multiplied by this):

| Button State | Applied modulate | Effective color | Notes |
|---|---|---|---|
| Default | `Color(1, 1, 1, 1)` (no change) | `#5C4A3E` (faded ink) | Clearly readable against paper, softer than the title |
| Hover | ~`Color(0.75, 0.77, 0.81, 1)` | `#2B2420` (warm ink — same as title) | Color-only deepening, no scale, no underline, no background change |
| Focus | Same as Hover | `#2B2420` | Keyboard-focused state matches hover. Override Godot's default focus rectangle to transparent in the Theme. |
| Pressed-but-not-released | Same as Hover | `#2B2420` | Godot cancels the press if the mouse leaves the button before release; visually identical to hover during the press window. Declared as intentional, not an oversight. |
| Disabled | ~`Color(2.0, 2.0, 2.1, 1)` | `#B8A99A` (washed warm gray) | Visible during the `Starting` state window after Start is pressed, while the scene switch is in flight. Serves as the load-window feedback (see Edge Cases). |

**Spacing** (VBoxContainer separation):
- Title → Start button: `48 px`

With Quit removed, the VBox no longer needs a second separation value. Title sits above, Start sits below, 48 px of paper between them.

### Color Palette (reference)

| Role | Name | Hex |
|---|---|---|
| Background | Linen paper | `#F5EFE4` |
| Primary text (title + button hover/focus/pressed) | Warm ink | `#2B2420` |
| Button default | Faded ink | `#5C4A3E` |
| Button disabled | Washed warm gray | `#B8A99A` |

No accent color. Hierarchy emerges from scale and spacing, not highlight.

### Motion

- **No animations.** No title breathe, no button scale on hover, no fade-in on `_ready()`, no particles, no ambient motion of any kind.
- State feedback is **color-only**. A hover is a color deepening. A disable is a color fading. That is the full motion vocabulary of this menu.
- On Start, the visual transition away from Main Menu is owned by Scene Transition UI (not this system). Main Menu simply disappears when Godot switches scenes. The disabled-button color fade during the brief `Starting` window is the only local visual feedback.

### Audio

- **Menu music: silence.** No ambient audio at Vertical Slice. A closed book does not hum. Silence here also ensures that the first sound in gameplay lands with weight.
- **UI SFX: none.** No hover tick, no click confirm, no Start "whoosh". Paper does not click. The color deepen on hover is the entire feedback.
- If a single soft transition sound (e.g., a page turn) is added to the Start action later, it is a future revision — out of scope for Vertical Slice.

### Art Bible Seed (this menu establishes these principles for all subsequent UI)

1. **Paper is the default surface.** All UI lives on warm off-white (`#F5EFE4` family). Cold whites, dark backgrounds, and high-contrast interfaces are excluded unless a scene explicitly requires them.
2. **Written, not designed.** Typography that *must* read as handmade is delivered as single-author PNG, not DynamicFont. Machine-precision spacing and geometric sharpness are anti-targets; imperfection is the signal of care.
3. **Color depth replaces motion.** All state changes (hover, focus, pressed, disabled) use color-value shifts, not animation.
4. **Hierarchy through weight and spacing, not decoration.** No dividers, borders, or drop shadows as decoration. Importance = larger, or more surrounding space.
5. **Silence is a valid choice.** The bar for adding a sound is: does its absence make the interaction ambiguous? If no, omit it.

> **📌 Asset Spec** — Visual/Audio requirements are defined. After the Art Bible is approved, run `/asset-spec system:main-menu` to produce per-asset visual descriptions, dimensions, and generation prompts for both the Title and the Start-button PNG.

## UI Requirements

### Node Tree

```
MainMenu (Control, anchors = PRESET_FULL_RECT)
├── Background (TextureRect or ColorRect, anchors = PRESET_FULL_RECT, mouse_filter = IGNORE)
└── CenterContainer (anchors = PRESET_FULL_RECT)
    └── VBoxContainer (alignment = CENTER, separation 48 px via Theme)
        ├── Title (TextureRect — hand-drawn PNG, stretch_mode = KEEP_ASPECT_CENTERED)
        └── StartButton (TextureButton, unique name %StartButton, texture_normal = ui_button_start_hand.png)
```

- No `CanvasLayer` — unnecessary for an initial scene with no game world beneath
- `mouse_filter = IGNORE` on Background so it never captures clicks intended for the button
- `StartButton` must have the **Unique Name** flag enabled in the `.tscn` (the `%StartButton` access pattern requires it); the node-tree annotation above is a reminder

### Input Actions

| Action | Input Map | Effect |
|--------|-----------|--------|
| `ui_accept` (Enter, Space) | Godot default | Activates the focused Start button |
| `ui_cancel` (Esc) | Godot default | In `Idle` state only: triggers quit via `_unhandled_input` (gated by `ESC_QUIT_ENABLED`) |
| Mouse click on button | Godot default | Activates Start |

Tab cycling is irrelevant at Vertical Slice — there is only one focusable widget. If a later milestone adds more focusable elements, a `focus_neighbor_*` chain would be added then.

### Focus Behavior

- `%StartButton.grab_focus()` is called in `_ready()` so keyboard users can press Enter immediately
- Focus ring (Godot's default blue rectangle) is overridden in the Theme to transparent — focus is communicated by the button's modulate deepening, matching hover
- If focus is lost (e.g., mouse click on empty background), the next keyboard event (`ui_accept`, `ui_focus_next`, or any key) re-focuses `%StartButton` before processing

### Responsive Layout

- `Control` root with `PRESET_FULL_RECT` scales to any viewport
- `CenterContainer` keeps the title/button column centered on window resize
- Title and Start PNGs use `KEEP_ASPECT_CENTERED` stretch so letterforms never distort
- Image sizing in the Theme scales automatically with the viewport if `display/window/stretch/mode = canvas_items` is set in `project.godot`

### Accessibility

- **Color contrast**: button-default ink (`#5C4A3E`) on paper (`#F5EFE4`) is a measured contrast ratio of ~7.6:1 — passes WCAG AA for normal text and AAA for large text. Hover/focus state (`#2B2420` on `#F5EFE4`) is ~12.5:1 — AAA across the board. Disabled state (`#B8A99A` on `#F5EFE4`) is deliberately low contrast (~2.2:1) because disabled is meant to read as inactive.
- **No animation** — reduced-motion users experience no change; the menu is already still for everyone
- **Keyboard-only navigation** works end-to-end: Enter/Space activates Start, Esc quits
- **Screen reader** — Godot 4.3 has no built-in screen-reader support (added in 4.5 via AccessKit). At Vertical Slice, Main Menu is unreadable to screen readers. Additionally, because the button label is a PNG (not a Label with `tr()`-keyed text), screen-reader support — if ever added — would need an `accessibility_name` override. Declared as a known limitation for N=1.
- **Legibility at low resolution** — at 1280×720 with `canvas_items` stretch, the hand-lettered Start PNG renders at ~86% of its nominal size. The PNG must be authored at 2× the effective minimum pixel size so downscaling preserves stroke edges.

### Platform Notes

- **Target platform**: PC (Windows / macOS). No touch, no gamepad support at Vertical Slice.
- **Resolution**: designed for 1920×1080 nominal; tested down to 1280×720. Anything smaller requires a manual check.
- **No multi-monitor or ultrawide handling** — CenterContainer stays centered regardless, no special layout for widescreen aspect ratios.

> **📌 UX Flag — Main Menu**: This system is a UI screen. In Phase 4 (Pre-Production), run `/ux-design main-menu` to produce a detailed UX spec (wireframe, interaction states, annotated behaviors) at `design/ux/main-menu.md` **before** writing stories. Stories that touch this menu should cite the UX spec, not this GDD directly.

## Acceptance Criteria

Criteria are written in GIVEN/WHEN/THEN form. Verification method is noted for each AC:
- **[launch]** = verify by launching the game and observing
- **[code]** = verify by static code inspection of `main_menu.gd`
- **[debugger]** = verify via Godot's remote scene inspector during a debug launch
- **[proxy]** = AC tests an underlying behavior via an observable player-facing proxy

### Boot

- **AC-BOOT-1** — **GIVEN** the game is launched with `run/main_scene = res://src/ui/main_menu/main_menu.tscn`, **WHEN** Main Menu's `_ready()` completes, **THEN** pressing Enter immediately activates Start (proxy for `%StartButton.grab_focus()` succeeding). **[launch / proxy]**
- **AC-BOOT-2** — **GIVEN** the game is launched, **WHEN** the title screen is visible, **THEN** exactly two widgets are rendered: the Title PNG and the Start button. No other labels, images, or controls appear. **[launch]**
- **AC-BOOT-3** — **GIVEN** Main Menu's `_ready()` has completed, **WHEN** Scene Manager is inspected via Godot's remote scene debugger, **THEN** Scene Manager is in the `Waiting` state (no scene has been auto-loaded). **[debugger]**
- **AC-BOOT-4** — **GIVEN** the game is launched, **WHEN** 30 seconds pass with no input, **THEN** no visual or audio change occurs on the menu (no idle animation, no auto-focus shift, no ambient sound). **[launch]**

### Start Activation (happy path)

- **AC-START-1** — **GIVEN** Main Menu is in `Idle`, **WHEN** the user clicks `%StartButton`, **THEN** the button becomes disabled (fades to `#B8A99A` modulate) and `change_scene_to_file("res://src/scenes/gameplay.tscn")` is called exactly once. **[launch / code]**
- **AC-START-2** — **GIVEN** Main Menu is in `Idle` with `%StartButton` focused, **WHEN** the user presses Enter, **THEN** Start activates identically to AC-START-1. **[launch]**
- **AC-START-3** — **GIVEN** Main Menu is in `Idle` with `%StartButton` focused, **WHEN** the user presses Space, **THEN** Start activates identically to AC-START-1. **[launch]**
- **AC-START-4** — **GIVEN** Start has been activated successfully, **WHEN** `gameplay.tscn` finishes loading, **THEN** the first scene's seed cards appear on the table (proxy for `EventBus.game_start_requested` emission and Scene Manager's `Waiting → Loading` transition). *(Top priority — end-to-end happy path)* **[launch / proxy]**
- **AC-START-5** — **GIVEN** `gameplay.tscn` is loaded, **WHEN** the Main Menu node is inspected via the remote debugger, **THEN** it no longer exists in the scene tree (freed by Godot). **[debugger]**

### Esc / Quit

- **AC-QUIT-1** — **GIVEN** Main Menu is in `Idle`, **WHEN** the user presses Esc, **THEN** `get_tree().quit()` is called and the process terminates. **[launch]**
- **AC-QUIT-2** — **GIVEN** Main Menu is in `Starting` state, **WHEN** the user presses Esc, **THEN** `get_tree().quit()` is NOT called and the scene switch proceeds uninterrupted. *(Top priority — Esc guard)* **[launch]**
- **AC-QUIT-3** — **GIVEN** Main Menu is in `Idle` and `ESC_QUIT_ENABLED` is `false`, **WHEN** the user presses Esc, **THEN** nothing happens (the menu stays in `Idle`; no quit occurs). **[launch / code knob]**

### Scene Switch Failure Recovery

- **AC-FAIL-1** — **GIVEN** `change_scene_to_file` returns a synchronous non-`OK` error (e.g., empty path — only triggerable if `GAMEPLAY_SCENE_PATH` is malformed), **WHEN** Start is activated, **THEN** the error is logged, the Start button is re-enabled, and Main Menu transitions `Starting → Idle`. **Note:** deferred failures (missing file, parse error, script error in `gameplay.tscn`) are invisible here and are detected by Scene Manager's `Waiting`-state watchdog (Scene Manager OQ-2). **[code / launch-hard-to-trigger]**
- **AC-FAIL-2** — **GIVEN** a synchronous scene-switch error has recovered Main Menu to `Idle`, **WHEN** the user clicks Start again, **THEN** the activation sequence runs again (retry is permitted, not suppressed). **[launch-hard-to-trigger]**

### Focus Recovery

- **AC-FOCUS-1** — **GIVEN** focus has been lost to the empty background (e.g., a mouse click outside the button), **WHEN** the user presses any keyboard event (`ui_accept`, `ui_focus_next`, or any key delivered to `_unhandled_input`), **THEN** focus returns to `%StartButton` before the event is further processed. **[launch]**

### Rule Enforcement

- **AC-RULE-1** — **GIVEN** `main_menu.gd`, **WHEN** its source is inspected, **THEN** it holds no references to Scene Manager, Scene Transition UI, Card Engine, Status Bar UI, or any autoload beyond the Godot `SceneTree`. **[code]**
- **AC-RULE-2** — **GIVEN** `main_menu.gd`, **WHEN** its source is inspected, **THEN** no `EventBus.*.emit(...)` or `EventBus.emit_signal(...)` call appears anywhere in the script. **[code]**
- **AC-RULE-3** — **GIVEN** Start is pressed twice in rapid succession, **WHEN** the handlers resolve, **THEN** `change_scene_to_file` has been called exactly once. **[launch]**

### Visual / Theme

- **AC-VIS-1** — **GIVEN** Main Menu is rendered at 1920×1080, **WHEN** inspected against the palette, **THEN** background is `#F5EFE4` (or the fallback `#F2EBD9`), default button ink (from the PNG) is `#5C4A3E`, and hover/focus effective color is `#2B2420`. **[launch]**
- **AC-VIS-2** — **GIVEN** `%StartButton` is displayed, **WHEN** the mouse hovers over it, **THEN** only the modulate color deepens — no scale change, no background fill, no underline. **[launch]**
- **AC-VIS-3** — **GIVEN** `%StartButton` is keyboard-focused, **WHEN** rendered, **THEN** no blue focus rectangle is drawn (the Theme overrides Godot's default); focus is communicated by the same color deepening as hover. **[launch]**
- **AC-VIS-4** — **GIVEN** the VBoxContainer is rendered, **WHEN** measured, **THEN** the gap between Title and Start is 48 px (Theme value). **[launch]**

### Motion & Audio Discipline

- **AC-MOTION-1** — **GIVEN** Main Menu is rendered, **WHEN** observed for 30 seconds of idle time, **THEN** no node's position, rotation, scale, or modulate changes. The menu is fully static. **[launch]**
- **AC-AUDIO-1** — **GIVEN** Main Menu is active, **WHEN** audio output is monitored, **THEN** no sound is emitted by Main Menu (no ambient, no UI tick, no hover sound, no Start SFX). **[launch]**

### Asset Fallbacks

- **AC-ASSET-1** — **GIVEN** `res://assets/themes/main_menu.tres` is missing, **WHEN** Main Menu loads, **THEN** the button still renders (using its base PNG without modulate state variation) and Start remains functional (click/Enter/Space still activate it). **[launch]**
- **AC-ASSET-2** — **GIVEN** `res://assets/ui/ui_button_start_hand.png` is missing, **WHEN** Main Menu loads, **THEN** the TextureButton renders empty but the button still activates Start when clicked, pressed with Enter, or pressed with Space. **[launch]**

### Platform

- **AC-PLAT-1** — **GIVEN** the game is launched on macOS, **WHEN** the user presses Cmd+Q, **THEN** the application quits cleanly regardless of Main Menu state (default OS window-close behavior). **[launch]**
- **AC-PLAT-2** — **GIVEN** the window is resized between 1280×720 and 1920×1080, **WHEN** Main Menu is rendered, **THEN** the title/button column stays visually centered, the title PNG retains its aspect ratio, and the hand-lettered Start PNG remains legible (strokes clearly readable, no aliasing breakdown). **[launch]**

### Priority subset (if Chester runs only 5 tests before ship)

Ranked by failure consequence:
1. **AC-START-4** — end-to-end: click icon → first chapter cards appear.
2. **AC-FAIL-1** (code inspection) — synchronous recovery path exists; frozen-screen avoidance is covered downstream by Scene Manager watchdog.
3. **AC-QUIT-2** — Esc during `Starting` does not quit mid-scene-switch.
4. **AC-BOOT-2** — exactly two widgets; Pillar 4 restraint held.
5. **AC-VIS-2** — hover is color-only; the rule that distinguishes "handmade" from "generic UI."

## Open Questions

These are issues surfaced during Main Menu design that are explicitly *out of scope* for this GDD. Each is routed to a later document or milestone.

### OQ-1 — `gameplay.tscn` composition (architecture) — RESOLVED 2026-04-21

**Question**: What nodes does `res://src/scenes/gameplay.tscn` contain, and which script is responsible for emitting `EventBus.game_start_requested()` after its `_ready()` completes?

**Resolution**: See `docs/architecture/ADR-004-runtime-scene-composition.md`. §2 specifies the gameplay.tscn child composition (CardTable + 4 CanvasLayers: HudLayer=5 / TransitionLayer=10 / SettingsPanelHost=15 / EpilogueLayer=20). §3 specifies `gameplay_root.gd` as the orchestrator owning the save-load sequence and the `game_start_requested` emission. §6 adds the `final_memory_ready → SaveSystem.save_now()` hook.

**Status**: Closed. Main Menu remains save-agnostic per Rule 6; orchestration lives in `gameplay_root.gd`.

### OQ-2 — Scene Manager `Waiting` timeout (cross-GDD)

**Question**: If `gameplay.tscn` loads successfully but its root script errors before emitting `game_start_requested`, or if the scene file is missing/misspelled/parse-errored, Scene Manager stays in `Waiting` forever with no player feedback and no log. How is this failure mode detected?

**Why open**: Main Menu is already freed at this point and cannot recover. The resolution belongs to Scene Manager, not here. This OQ is load-bearing — it is the *only* detection mechanism for the deferred-failure class that AC-FAIL-1 cannot catch.

**Resolution path**: Add to Scene Manager's next GDD revision a developer-only timeout (suggested: 30 seconds) in the `Waiting` state that logs a fatal error naming the expected signal. Not a shipping feature — a debug safety net.

**Owner**: Scene Manager GDD (next revision).

### OQ-3 — Menu audio for post-Vertical-Slice milestones

**Question**: Does Main Menu remain fully silent through Alpha / Beta / Full Vision, or are subtle audio cues (e.g., a soft page-turn on Start, low-volume ambient room tone) added later?

**Why open**: Vertical Slice is deliberately silent per Player Fantasy. Revisiting this belongs to a later milestone, not the current scope.

**Resolution path**: Revisit during Alpha planning. Any addition must pass the Player Fantasy test ("does its absence make the interaction ambiguous?"). If audio is added, emit a signal (e.g., `menu_entered`) rather than calling an audio autoload directly.

**Owner**: audio-director, on Alpha milestone.

### OQ-4 — Title and Start-button PNG asset commission

**Question**: Who draws `ui_title_moments_static_large.png` and `ui_button_start_hand.png`, and when?

**Why open**: The GDD locks the decision (hand-drawn/hand-lettered PNGs for both the title and the Start button, single-author pipeline). Neither asset exists yet. Paths are placeholders.

**Resolution path**: Run `/asset-spec system:main-menu` after Art Bible approval to produce commission-ready specs for both assets (size, style reference, generation prompt if AI-assisted). Both must be in-tree before the first Main Menu implementation story is marked Done. The button PNG must match the title's hand and stroke weight so the two elements read as one author.

**Owner**: art-director (spec), Chester (production).

### OQ-5 — Multi-locale handling

**Question**: If Moments is ever localised beyond its initial locale, how are the title and button PNGs handled? (PNGs cannot be `tr()`-swapped like Label text.)

**Why open**: Vertical Slice ships a single locale; because the menu text is PNG, there are no translation keys at all for Main Menu. Multi-language support is a Full Vision concern.

**Resolution path**: If multi-locale is scoped in, produce per-locale PNG variants (`ui_title_moments_static_large_[locale].png`, `ui_button_start_hand_[locale].png`) and switch via `TranslationServer.get_locale()` in `_ready()`. Alternatively, fall back to Label + locale-specific handwritten font (at the cost of Pillar 4 coherence — this trade-off would need creative-director sign-off).

**Owner**: localization-lead, only if multi-locale is committed.
