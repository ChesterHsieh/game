# Settings

> **Status**: In Design
> **Author**: Chester + Claude Code agents
> **Last Updated**: 2026-04-21
> **Implements Pillar**: Pillar 4 (Personal Over Polished) — minimum viable controls, no options-for-options'-sake

## Overview

Settings is a Meta-layer UI system that exposes the three things a player of Moments might actually need to adjust: Master volume, Music volume, SFX volume, and a guarded "Reset Progress" action. It is the smallest possible options menu — no graphics tab, no keybinding remap, no language selector at Full Vision scope. Settings is reachable two ways: a small gear icon in the top-right of the gameplay HUD, and a matching gear on the Main Menu. Activating the gear opens a small modal panel that dims the scene behind it but does not navigate away — card input is suppressed while the panel is open, and dismissing returns the player to exactly where they were.

Mechanically, Settings owns three responsibilities: (1) render the panel UI, (2) route slider changes to `AudioManager.set_bus_volume()`, (3) persist player preferences to `user://moments_settings.json` — an entirely separate file from the save progress JSON. This separation matters: a player who taps "Reset Progress" expects their discoveries to wipe, not their volume preferences.

## Player Fantasy

Settings is not a feature Ju is supposed to enjoy. It is a utility drawer that stays closed almost all the time. The fantasy is absence — she should open it rarely, adjust one thing, close it, forget it exists. The panel should feel like a small bedside lamp switch: visible when she needs it, silent otherwise.

When she opens it mid-scene because the music is louder than she expected at 1 AM, the panel should respond to a slider drag *instantly* (the music dips while she is still moving the slider), so she can dial in the right level with her ear rather than her eye. When she closes the panel, the dim lifts and the card she was dragging is exactly where she left it. She never loses her place.

If she ever needs to press "Reset Progress" — because the game has been gifted onward, or because she wants to replay from scratch once — the confirmation must feel *serious* without being alarming. Two taps, not one, to prevent a slip. After confirmation, the game returns to Main Menu with a clean slate, but her volume preferences persist. The reset targets progress, not her.

Settings is successful when Ju uses it for ten seconds in three months of play, and it does exactly what she expected.

## Detailed Design

### Core Rules

**1. Scene Structure.** Settings is an instanced scene at `res://src/ui/settings/settings_panel.tscn`. It is *not* an autoload. Two gear-icon trigger points instance and add it as a child:
- `main_menu.tscn` adds a `SettingsTrigger` node (a small `TextureButton`) in a top-right corner container. On press, it instances `settings_panel.tscn` as a CanvasLayer child of Main Menu.
- `gameplay.tscn` adds the same `SettingsTrigger` widget in its own top-right corner. On press, it instances `settings_panel.tscn` as a CanvasLayer child of gameplay.

There is only ever one live Settings panel at a time. Re-pressing the gear while the panel is open is ignored (the trigger button itself is disabled while the panel exists — see Rule 5).

**2. Panel Composition.** The panel renders six widgets inside a centered card-shaped `PanelContainer`:
1. Panel title (PNG or label — see UI Requirements).
2. "Master" slider row — label + `HSlider` (range 0.0 – 1.0).
3. "Music" slider row — label + `HSlider`.
4. "SFX" slider row — label + `HSlider`.
5. "Reset Progress" `Button` — separated by a subtle horizontal divider.
6. "Close" `Button` — bottom-right of the panel.

A dim overlay (`ColorRect` at `Color(0, 0, 0, 0.45)`) covers the full viewport beneath the panel. Clicking the overlay outside the panel dismisses the panel (equivalent to Close).

**3. Volume Slider → dB Mapping.** Each `HSlider` has `min_value = 0.0`, `max_value = 1.0`, `step = 0.01`. The slider position `s ∈ [0, 1]` maps to dB via:

```
volume_db = 20 * log10(max(s, 0.0001))     # logarithmic perceptual mapping
# clamped: if s == 0 → -80 dB (fully muted)
```

- `s = 1.0` → `0 dB` (unity gain)
- `s = 0.5` → `−6.02 dB`
- `s = 0.1` → `−20 dB`
- `s = 0.01` → `−40 dB`
- `s = 0.0` → `−80 dB` (muted)

On every slider `value_changed` emission, Settings immediately calls `AudioManager.set_bus_volume(bus_name, volume_db)`. The audio change is live — Ju hears the level adjust while the slider is still moving.

**4. Slider Persistence.** On every slider change:
1. Update the in-memory preferences Dictionary.
2. Schedule a debounced write to `user://moments_settings.json` — 500 ms after the last change. This avoids one disk write per millisecond of drag.
3. On panel Close (Rule 6), flush the debounce timer and write immediately if pending.

**5. Open / Close Lifecycle.**
- On gear press: instance `settings_panel.tscn` as a child. Disable the gear trigger. The panel's `_ready()` populates slider values from the current in-memory preferences (which were loaded at game start — see Rule 9).
- While open: card-layer input is suppressed. The panel's dim overlay absorbs all clicks that don't hit panel widgets. Keyboard `Escape` dismisses the panel.
- On Close (button, overlay click, or Escape): flush pending debounced save, call `queue_free()` on the panel node, re-enable the gear trigger. Game resumes exactly where it paused.

**6. Reset Progress Flow.**
1. First press of "Reset Progress" → button morphs into "Confirm Reset (3)" with a 3-second countdown. The slider rows and Close button remain interactive (so a nervous Ju can still close the panel to cancel).
2. While the countdown runs, the button displays remaining seconds. It stays pressable. A second press within the countdown window → commit.
3. On commit:
   a. Call `SaveSystem.clear_save()` (defined in Save/Progress GDD Rule 10). This routes through `SceneManager.reset_to_waiting()` → `SM.set_resume_index(0)` → `MUT.load_save_state({})` → disk delete. After this call, SM is back in `Waiting` state with CONNECT_ONE_SHOT re-armed and cards cleared.
   b. Close the Settings panel.
   c. If currently in a gameplay scene: call `get_tree().change_scene_to_file("res://src/ui/main_menu/main_menu.tscn")` — back to Main Menu. Next Start press emits `game_start_requested` → SM (Waiting, re-armed) → `_load_scene_at_index(0)`. Ju begins from chapter 0 cleanly.
   d. If currently on Main Menu: panel simply closes. Next Start press behaves identically to (c)'s post-switch state.
4. If the countdown elapses without a second press: button reverts to "Reset Progress" at default styling. No data changed.

**7. Settings File Envelope (schema v1).**

```json
{
  "schema_version": 1,
  "saved_at_unix": 1744000000,
  "volumes": {
    "Master": 1.0,
    "Music":  1.0,
    "SFX":    1.0
  }
}
```

Fields:
- `schema_version` (int): migration key. v1 at Full Vision release.
- `saved_at_unix` (int): diagnostic only.
- `volumes.Master`, `volumes.Music`, `volumes.SFX` (float): slider values in `[0.0, 1.0]`. Keys match Godot bus names exactly (PascalCase). These are the slider positions, NOT dB — the dB conversion happens at runtime via Rule 3's formula.

The file lives at `user://moments_settings.json`. It is intentionally separate from `user://moments_save.json` so that "Reset Progress" never destroys volume preferences.

**8. Atomic Write.** Same pattern as Save/Progress (see `save-progress-system.md` Rule 7): write to `user://moments_settings.json.tmp`, then `DirAccess.rename_absolute()` to the real path. Failure does not block gameplay — the next slider change will retry.

**9. Load on Startup.** Settings is loaded by an autoload singleton `SettingsManager` (distinct from the panel scene). Autoload order is canonical per `docs/architecture/ADR-004-runtime-scene-composition.md` §1: SettingsManager is position 6 of 12 (after AudioManager, before SaveSystem and SceneManager). Previous versions of this GDD specified a different ordering; ADR-004 supersedes.
- `SettingsManager._ready()` synchronously loads `user://moments_settings.json`.
- If present and valid: apply each volume immediately via `AudioManager.set_bus_volume()` so the first sound Ju hears is at her preferred level.
- If missing or corrupt: apply defaults (all sliders at 1.0 → 0 dB). Rename corrupt files to `moments_settings.json.corrupt.<iso8601>` (same convention as Save/Progress).

The SettingsManager autoload owns: the in-memory preferences Dictionary, the debounced save timer, and the `apply_volumes()` / `get_volume(bus)` / `set_volume(bus, s)` API. The panel scene is a thin UI layer that reads and writes through this autoload.

**10. API Surface (SettingsManager autoload).**

| Method | Signature | Purpose |
|--------|-----------|---------|
| `get_volume(bus: String)` | `→ float` (0.0 – 1.0) | Returns current slider position for `"Master"` / `"Music"` / `"SFX"`. |
| `set_volume(bus: String, value: float)` | `→ void` | Clamps `value` to `[0.0, 1.0]`, stores in memory, calls `AudioManager.set_bus_volume(bus, s_to_db(value))`, schedules debounced save. |
| `apply_all_volumes()` | `→ void` | Pushes all three current values into AudioManager. Called at startup and after `_on_settings_loaded()`. |
| `load_from_disk()` | `→ LoadResult` enum | Reads settings file, validates, applies. Returns OK / NO_FILE / CORRUPT_RECOVERED. |
| `flush_pending_save()` | `→ void` | Forces immediate write if a debounced save is pending. Called on panel close and on application quit. |

### States and Transitions

The **panel** has three states. The **SettingsManager autoload** is stateless beyond its in-memory Dictionary — it does not transition; it always serves the current values.

| State | Entry Condition | Exit Condition | Behavior |
|---|---|---|---|
| `Closed` | Default (no panel instance exists) | Gear pressed | No visible UI; gear trigger enabled |
| `Open` | Gear pressed | Close button, overlay click, or Escape | Panel rendered; card input suppressed; sliders live-bound |
| `ResetConfirm` | "Reset Progress" pressed while `Open` | Second press (commit) OR 3-second timeout OR Close/Escape (cancel) | Button shows countdown; Close still works (cancels the reset) |

**Transitions:**
- `Closed → Open`: gear pressed. Panel instanced, sliders populated from `SettingsManager.get_volume()`.
- `Open → Closed`: Close button, overlay click, or Escape. Debounced save flushed. Panel `queue_free()`.
- `Open → ResetConfirm`: "Reset Progress" button pressed.
- `ResetConfirm → Open`: 3-second timeout. Button reverts.
- `ResetConfirm → (panel freed + scene change)`: second press. `SaveSystem.clear_save()` called; scene switch to Main Menu if in gameplay.
- `ResetConfirm → Closed`: Close button during countdown. Debounce flushed. Reset is cancelled.

### Interactions with Other Systems

| System | Direction | Interface |
|---|---|---|
| **Audio Manager** | SettingsManager → AudioManager (calls) | `AudioManager.set_bus_volume(bus_name, volume_db)` every time a slider changes OR on startup via `apply_all_volumes()`. |
| **Save/Progress System** | Settings panel → SaveSystem (calls) | On Reset Progress commit: `SaveSystem.clear_save()`. |
| **Main Menu** | Main Menu hosts a `SettingsTrigger` child | Main Menu instances the gear button in its top-right corner. The button instances `settings_panel.tscn` on press. Main Menu is otherwise unaware of Settings internals. |
| **`gameplay.tscn`** | Gameplay scene hosts a `SettingsTrigger` child | Same pattern as Main Menu — a gear widget in a corner container. Composition of `gameplay.tscn` is owned by Main Menu OQ-1's ADR. |
| **Card Engine / Interaction Template Framework** | Settings panel blocks input | The dim overlay absorbs clicks; keyboard `ui_cancel` is consumed by the panel while Open. No direct coupling — Settings does not call Card Engine. |
| **EventBus** (ADR-003) | No signals | Settings uses no EventBus signals. All communication is via direct autoload / method calls. Rationale: settings changes are local-UI events, not game events that cross system boundaries. |

## Formulas

### Slider Position to dB

```
volume_db = 20 * log10(max(slider_value, 0.0001))
# if slider_value == 0 → volume_db = -80
```

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| `slider_value` | `s` | float | [0.0, 1.0] | HSlider position exposed to player |
| `volume_db` | `v` | float | [−80, 0] | dB value sent to `AudioManager.set_bus_volume()` |

**Output Range:** −80 dB to 0 dB. The formula is a standard audio perceptual curve — halving the slider position drops perceived loudness by ~6 dB, which matches human pitch/loudness intuition better than a linear map.

**Example:** `s = 0.25` → `20 * log10(0.25) = 20 * (−0.602) = −12.04 dB`. A quarter-strength slider sounds about as loud as "quiet conversation" relative to unity gain — perceptually meaningful.

### Reset-Confirm Countdown

```
remaining_sec = max(0.0, RESET_CONFIRM_WINDOW_SEC - (current_time - button_pressed_time))
```

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| `RESET_CONFIRM_WINDOW_SEC` | — | const float | 3.0 | Time window in which second press commits |
| `current_time` | `t` | float (seconds) | [0, ∞) | `Time.get_ticks_msec() / 1000.0` |
| `button_pressed_time` | `t0` | float | [0, ∞) | Time of first press |
| `remaining_sec` | `r` | float | [0, 3] | Displayed on the button as "Confirm Reset (⌈r⌉)" |

**Output Range:** 0 to 3. When `r == 0`, revert to default state (`Open`).

### Debounced Save Delay

```
schedule_write(current_time + DEBOUNCE_DELAY_MS)
# If another write is scheduled, cancel the old timer and schedule a new one.
# When the timer fires, write the current in-memory Dictionary to disk.
```

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| `DEBOUNCE_DELAY_MS` | — | const int | 500 | Quiet window after last change before disk write |

**Output Range:** Effectively "one disk write per sustained adjustment episode," regardless of how many `value_changed` signals fire.

**Example:** Ju drags the Music slider for 2 seconds, producing ~120 `value_changed` events. Without debounce: 120 writes. With 500 ms debounce: 1 write, 500 ms after she releases the slider.

## Edge Cases

### Panel Lifecycle

- **If the gear trigger is pressed while a panel already exists**: The trigger is disabled (Rule 5) the moment the panel is instantiated, so this cannot normally happen. If it does (programmer error / rapid double-click race), guard in the panel's handler: check for an existing `settings_panel.tscn` instance in the parent; if found, ignore the second press.

- **If the panel is open during a scene change** (e.g., `scene_completed` triggers gameplay → gameplay transition while panel is open): Scene Manager's transition freezes the table, but the panel is a CanvasLayer child of the scene being freed. On `scene_completed`, `gameplay.tscn` is torn down — the panel is freed with it. This is fine; on re-open after the new scene loads, slider positions re-populate from SettingsManager (which persists across scene changes because it is an autoload).

- **If the application quits with the panel open** (Alt+F4 mid-adjustment): The debounced save fires via `flush_pending_save()` registered on `NOTIFICATION_WM_CLOSE_REQUEST` in SettingsManager. Settings preferences are always flushed to disk on quit.

### Volume Edge Cases

- **If `AudioManager` is not yet initialized when `SettingsManager._ready()` runs** (autoload order bug): `SettingsManager` logs an error and defers `apply_all_volumes()` by one frame. If AudioManager is still null after one frame, a fatal error is logged. Autoload order must be: `EventBus → AudioManager → SettingsManager → SaveSystem → ... → SceneManager`.

- **If `AudioManager.set_bus_volume()` is called with a bus name that doesn't exist** (typo or bus renamed in `default_bus_layout.tres`): AudioManager's own edge case handler covers this (see Audio Manager AC-AM-16). Settings uses canonical PascalCase bus names `"Master"`, `"Music"`, `"SFX"` that match the default Godot audio bus layout and Audio Manager AC-AM-14; if AudioManager ever renames a bus, update Settings in lockstep.

- **If a slider is dragged beyond [0, 1]** (impossible with proper `min_value`/`max_value`, but defensive): `SettingsManager.set_volume()` clamps the value before forwarding to AudioManager.

### Reset Progress Edge Cases

- **If Reset is committed from within a gameplay scene**: Scene switch to Main Menu happens during the same frame as `SaveSystem.clear_save()`. Scene Manager's existing scene-transition guard blocks any in-flight `scene_completed` signals — the `Transitioning` state covers this.

- **If Reset is committed from Main Menu**: The panel closes. No scene switch needed. Next Start press finds an empty save and begins at index 0.

- **If Reset is committed during the 3-second countdown but SaveSystem was never initialized** (very early startup bug): Guard by checking `SaveSystem != null` before calling `clear_save()`. Log an error and treat as cancelled.

- **If the player closes the panel exactly at the moment the countdown elapses** (race): The Close handler and the countdown timer's handler may run in the same frame. Both must converge to the same outcome (cancelled reset). Resolution: the panel's `queue_free()` is the single point of truth — once queued, the countdown timer is freed with it, and neither handler can commit the reset.

### Settings File Edge Cases

- **If `moments_settings.json` is missing on first launch**: Apply defaults (all sliders at 1.0). Do not pre-create an empty file; the first slider change will write the file.

- **If `moments_settings.json` is malformed JSON**: Same recovery as Save/Progress (Rule 9 + Save/Progress Rule 8). Rename to `.corrupt.<iso8601>`, log error, fall back to defaults. Ju does not see an error dialog.

- **If `moments_settings.json` has a future `schema_version`**: Treat as corrupt. Fall back to defaults. Forward compatibility is not provided.

- **If a slider value in the settings file is outside `[0, 1]`** (manual edit or schema drift): Clamp on load. Log a warning. The next slider-driven save will normalize the value.

- **If the settings file exists but `volumes` key is missing**: Treat as corrupt. Rename + defaults + log.

### Multi-Instance

- **If two game instances run simultaneously and both adjust volume**: Last-write-wins on disk. In-memory state is per-process. Not defended against — same stance as Save/Progress.

## Dependencies

### Upstream (this system depends on)

| System | What We Need | Hardness |
|--------|-------------|----------|
| **Audio Manager** | `AudioManager.set_bus_volume(bus_name: String, volume_db: float) -> void`. Already specified in Audio Manager GDD. The three bus names (`"Master"`, `"Music"`, `"SFX"`) must be consistent. | Hard — Settings is useless without audio bus control |
| **Save/Progress System** | `SaveSystem.clear_save() -> void`. Specified in Save/Progress GDD Core Rule 10. | Hard — Reset Progress has no implementation without it |
| **Godot `FileAccess` / `DirAccess` / `JSON`** | Synchronous file I/O, atomic rename, JSON encode/decode. All stable in Godot 4.3. | Hard — engine primitives |
| **Main Menu** | Hosts a `SettingsTrigger` child (gear button in top-right corner container). Main Menu GDD's Rule 2 currently specifies "exactly two visible widgets" — Main Menu will need a minor revision to allow the gear as a third widget, OR the gear is rendered outside the CenterContainer and excluded from Rule 2's count. | Hard — access point |
| **`gameplay.tscn`** | Hosts the same `SettingsTrigger` child. Owned by Main Menu OQ-1's ADR. | Hard — access point |

### Downstream (systems that depend on this)

| System | What They Need | Hardness |
|--------|---------------|----------|
| _(none)_ | Settings is a terminal Meta system. No other system reads settings state or listens to Settings events. Audio changes propagate through `AudioManager.set_bus_volume()`, not through Settings. | — |

### External Data

| Asset | Path | Description |
|-------|------|-------------|
| **Settings file** | `user://moments_settings.json` | Canonical settings file. Created on first slider change. |
| **Atomic write staging** | `user://moments_settings.json.tmp` | Temporary file during write. Renamed to real path on success. |
| **Corruption backups** | `user://moments_settings.json.corrupt.<iso8601>` | Written on parse failure. Never read automatically. |
| **Settings panel scene** | `res://src/ui/settings/settings_panel.tscn` | The modal panel UI. |
| **Gear icon asset** | `res://assets/ui/ui_icon_gear_hand.png` | Hand-drawn gear icon (single-author, same pipeline as Main Menu per Pillar 4). |
| **Panel background asset** | `res://assets/ui/ui_panel_card_paper.png` | Card-shape panel background — matches Main Menu's paper-wash palette. |

### Signals Emitted

| Signal | Parameters | Fired When |
|--------|------------|-----------|
| _(none)_ | — | Settings does not use EventBus. All communication is direct method calls. |

### Signals Listened To

| Signal | Source | Handled When |
|--------|--------|-------------|
| _(none)_ | — | Settings does not subscribe to EventBus. |

**Cross-reference notes:**
- **Audio Manager GDD** (`design/gdd/audio-manager.md`): Downstream table already lists Settings as the caller of `set_bus_volume()`. Bus name casing (`"Master"` / `"Music"` / `"SFX"`) must be locked between the two GDDs — post-design update confirms.
- **Save/Progress System GDD** (`design/gdd/save-progress-system.md`): Core Rule 10 specifies `clear_save()`; OQ-1 in that GDD asks how Reset Progress is exposed — this GDD is the answer (two-tap 3-second countdown, per the recommended confirmation).
- **Main Menu GDD** (`design/gdd/main-menu.md`): Rule 2's "exactly two widgets" language must be amended at Full Vision to permit a gear button as a third widget in a separate corner container (not inside the CenterContainer). Post-design update applies.

## Tuning Knobs

| Knob | Type | Default | Safe Range | Too Low | Too High |
|------|------|---------|------------|---------|----------|
| `RESET_CONFIRM_WINDOW_SEC` | const float | `3.0` | 2.0–5.0 | Too brief — Ju can't reliably second-press | Too long — feels like the button "hung" |
| `DEBOUNCE_DELAY_MS` | const int | `500` | 200–1000 | Near-realtime disk writes (wasteful) | Perceptible gap before preference persists |
| `CURRENT_SETTINGS_SCHEMA_VERSION` | const int | `1` | 1–N | N/A | Never decrement |
| `SETTINGS_FILE_NAME` | const String | `"moments_settings.json"` | — | Changing breaks existing preferences | — |
| `DIM_OVERLAY_OPACITY` | float (Theme) | `0.45` | 0.3–0.6 | Hard to see panel separation from scene | Too dark — obscures the scene behind |
| Slider steps | const float | `0.01` (100 positions) | 0.01–0.05 | Zeno's drag — slider feels jittery | Coarse steps — can't dial in precisely |
| Default volume per bus | float | `1.0` (all) | 0.0–1.0 | Quiet first launch | N/A (cap at 1.0 = 0 dB) |

**Design stance**: Like Save/Progress, Settings favors rigidity over flexibility. The three volume knobs and one destructive action are the entire surface; adding options later (Fullscreen toggle, Keybinding remap, Accessibility modes) must pass an explicit need test against Pillar 4's "Personal Over Polished."

## Visual/Audio Requirements

### Gear Trigger (Main Menu + Gameplay)

- **Asset**: `res://assets/ui/ui_icon_gear_hand.png` — hand-drawn gear icon, single-author (same pipeline as Main Menu title/Start button per Pillar 4).
- **Size**: ~32×32 px at 1920×1080 reference. Scales via the same `canvas_items` stretch mode as the rest of the game.
- **Color**: baked into the PNG at `#5C4A3E` (faded ink, matching the Start button default state).
- **Hover modulate**: `Color(0.75, 0.77, 0.81, 1)` → effective `#2B2420` (warm ink). Matches Main Menu hover behavior for visual consistency.
- **Position**: top-right of the viewport, 16 px padding from both edges. Uses a right-anchored `MarginContainer` with a `TextureButton` child. Mouse-filter-stop so clicks behind the gear (e.g., on cards in gameplay) don't bleed through.
- **No animation**. No rotation on hover, no tooltip, no label. The icon is its own affordance.

### Settings Panel

- **Size**: ~480×360 px at 1920×1080 reference. Centered via `CenterContainer`.
- **Background**: card-shape paper texture (`ui_panel_card_paper.png`) with subtle rounded corners. Palette consistent with Main Menu (`#F5EFE4` base, warm ink for text).
- **Dim overlay**: full-viewport `ColorRect` at `Color(0, 0, 0, 0.45)`, mouse-filter-stop so clicks outside the panel hit the overlay (which dismisses the panel).
- **Title**: "Settings" — hand-lettered PNG (Pillar 4 consistency with Main Menu).
- **Slider rows**: label on the left (hand-lettered PNG or DynamicFont TBD — see Open Questions), `HSlider` on the right. No numeric readout on the slider — the audio itself is the feedback.
- **Divider between SFX and Reset Progress**: thin `ColorRect` at `#5C4A3E` with low alpha, 1 px tall. Creates visual separation between the "preferences" cluster and the "destructive action" cluster.
- **Reset Progress button**: styled slightly larger than the Close button, with text color shifted toward warning-warm (`#8B5A3E`) to signal severity without using an alarming red.
- **Countdown state**: button text changes to "Confirm Reset (3)" → "(2)" → "(1)"; styling otherwise unchanged. No pulsing, no scale animation.
- **Close button**: bottom-right of the panel, smaller than Reset Progress. Default ink color.

### Audio

- **Panel open**: silence. No whoosh, no chime.
- **Panel close**: silence.
- **Slider drag**: silence from the panel itself — but the *audio bus being adjusted* is already making sound, so Ju hears the change directly. This is the only "UI feedback" that exists, and it's the correct one.
- **Reset Progress commit**: silence. The scene switch to Main Menu carries its own transition (if any) owned by Scene Transition UI.

**Rationale**: Settings is a utility drawer (Player Fantasy). Utility drawers in physical life make no sound. Adding a "click" or "whoosh" would make the panel feel like marketing material, not a quiet bedside-lamp switch.

> **📌 Asset Spec** — Visual requirements are defined. After the Art Bible is approved, run `/asset-spec system:settings` to produce generation prompts for the gear icon, panel background, and title PNG.

## UI Requirements

### Panel Node Tree

```
SettingsPanel (CanvasLayer, layer = 15) — per ADR-004 §2 `SettingsPanelHost`. Above STUI (layer 10), below Final Epilogue Screen (layer 20).
├── DimOverlay (ColorRect, anchors = PRESET_FULL_RECT, Color(0, 0, 0, 0.45), mouse_filter = STOP)
└── CenterContainer (anchors = PRESET_FULL_RECT)
    └── PanelContainer (custom Theme — paper texture, rounded corners)
        └── VBoxContainer (separation = 16 px)
            ├── TitlePng (TextureRect — "Settings" hand-lettered)
            ├── MasterRow (HBoxContainer)
            │   ├── MasterLabel (TextureRect — "Master")
            │   └── MasterSlider (HSlider, min=0, max=1, step=0.01)
            ├── MusicRow  (HBoxContainer)
            │   ├── MusicLabel  (TextureRect — "Music")
            │   └── MusicSlider (HSlider)
            ├── SfxRow    (HBoxContainer)
            │   ├── SfxLabel    (TextureRect — "SFX")
            │   └── SfxSlider   (HSlider)
            ├── Divider (ColorRect, 1 px tall)
            ├── ResetButton (Button — unique name %ResetButton)
            └── CloseButton (Button — unique name %CloseButton)
```

### Gear Trigger Node (in Main Menu and gameplay.tscn)

```
SettingsTrigger (MarginContainer, anchors = top-right, margin = 16 px)
└── GearButton (TextureButton, texture_normal = ui_icon_gear_hand.png)
```

### Input Actions

| Action | Input | Effect |
|--------|-------|--------|
| Gear click / tap | Mouse / touch | Instance the Settings panel |
| `ui_cancel` (Escape) | Keyboard | Close the panel (while Open); cancel Reset Progress countdown (while ResetConfirm) |
| Slider drag | Mouse / touch / arrow keys while focused | Adjust volume |
| Click on dim overlay (outside panel) | Mouse / touch | Close the panel |

### Focus Behavior

- On panel open, `%MasterSlider.grab_focus()`.
- Tab cycles: Master → Music → SFX → Reset → Close → Master.
- Close button is always reachable via Escape regardless of focus state.

### Accessibility

- **Color contrast**: all button and label text uses `#5C4A3E` (faded ink) or `#2B2420` (warm ink) on paper — same contrast ratios as Main Menu (7.6:1 and 12.5:1, AA/AAA compliant).
- **Reduced motion**: the panel has no motion. The reset countdown updates text in-place without animation — compliant by default.
- **Keyboard-only**: every control is reachable via Tab and activatable via Enter/Space.
- **Screen reader**: same Godot 4.3 limitation as Main Menu. Sliders and buttons would need `accessibility_name` overrides if a screen reader is ever added (post-Godot-4.5).
- **No audio cues on UI**: deliberate — see Audio. A player using the game on mute will not miss any state information.

### Platform

- **Target**: PC (macOS primary, Windows verified). Touch is theoretically supported via `HSlider.mouse_filter` but not designed for.
- **Resolution**: designed for 1920×1080; tested at 1280×720.

> **📌 UX Flag — Settings**: This system has UI. In Phase 4 (Pre-Production), run `/ux-design settings` to produce a detailed UX spec at `design/ux/settings.md` (wireframes, interaction state diagrams, slider feedback behaviors) **before** writing stories.

## Acceptance Criteria

### Autoload & Startup (AC-SET-01 – AC-SET-05)

**AC-SET-01 [Logic] — SettingsManager autoload order.**
GIVEN `project.godot`, WHEN inspected, THEN `SettingsManager` is registered as an autoload AND its `_ready()` runs after `AudioManager` AND before `SaveSystem`.

**AC-SET-02 [Logic] — Defaults applied when no settings file exists.**
GIVEN `user://moments_settings.json` does not exist, WHEN `SettingsManager._ready()` completes, THEN `get_volume("Master") == 1.0` AND `get_volume("Music") == 1.0` AND `get_volume("SFX") == 1.0` AND `AudioManager.set_bus_volume()` was called three times (once per bus) with dB = 0.

**AC-SET-03 [Logic] — Valid settings file loads and applies.**
GIVEN a valid settings file with `volumes = {Master: 0.5, Music: 0.1, SFX: 1.0}`, WHEN `SettingsManager._ready()` completes, THEN `AudioManager` has received: `set_bus_volume("Master", -6.02)`, `set_bus_volume("Music", -20.0)`, `set_bus_volume("SFX", 0.0)` (within ±0.1 dB tolerance).

**AC-SET-04 [Logic] — Malformed settings file recovered.**
GIVEN `user://moments_settings.json` contains `"not json"`, WHEN load runs, THEN the file is renamed to `moments_settings.json.corrupt.<iso8601>` AND defaults are applied AND an error is logged.

**AC-SET-05 [Logic] — Future schema version rejected.**
GIVEN the file has `schema_version: 99`, WHEN load runs, THEN it is treated as corrupt (renamed, defaults applied, error logged).

### Slider Behavior (AC-SET-06 – AC-SET-09)

**AC-SET-06 [Integration] — Slider change calls AudioManager immediately.**
GIVEN the Settings panel is Open, WHEN the Master slider changes from 1.0 to 0.5, THEN `AudioManager.set_bus_volume("Master", -6.02)` is called before the next frame (no debounce on the audio side; debounce applies only to disk writes).

**AC-SET-07 [Logic] — Slider position ↔ dB mapping is correct.**
GIVEN the formula `v = 20 * log10(max(s, 0.0001))`, WHEN tested at s ∈ {0.0, 0.01, 0.1, 0.5, 1.0}, THEN v ∈ {−80, −40, −20, −6.02, 0.0} respectively (±0.1 dB).

**AC-SET-08 [Logic] — Out-of-range slider values are clamped.**
GIVEN `SettingsManager.set_volume("Master", 1.5)`, WHEN processed, THEN the stored value is `1.0` AND `AudioManager.set_bus_volume("Master", 0.0)` is called.

**AC-SET-09 [Logic] — Debounced save fires 500 ms after last change.**
GIVEN the Master slider changes at t=0, 100 ms, 200 ms, 300 ms, WHEN the final change settles, THEN exactly one disk write occurs at approximately t=800 ms (300 ms + 500 ms debounce).

### Panel Lifecycle (AC-SET-10 – AC-SET-14)

**AC-SET-10 [Integration] — Gear opens panel and disables trigger.**
GIVEN the gear is visible and the panel is Closed, WHEN the gear is clicked, THEN a `settings_panel.tscn` instance exists as a CanvasLayer child of the parent scene AND the gear button is disabled.

**AC-SET-11 [Integration] — Panel populates sliders from SettingsManager on open.**
GIVEN `SettingsManager.get_volume("Music") == 0.3`, WHEN the panel opens, THEN `%MusicSlider.value == 0.3` before any user interaction.

**AC-SET-12 [Integration] — Close button dismisses panel and flushes save.**
GIVEN the panel is Open with a pending debounced save, WHEN the Close button is pressed, THEN the panel is freed AND the pending save is written immediately to disk AND the gear trigger is re-enabled.

**AC-SET-13 [Integration] — Overlay click dismisses panel.**
GIVEN the panel is Open, WHEN a click lands on the dim overlay (outside the panel rect), THEN the panel closes identically to AC-SET-12.

**AC-SET-14 [Integration] — Escape dismisses panel.**
GIVEN the panel is Open, WHEN `ui_cancel` is pressed, THEN the panel closes identically to AC-SET-12.

### Reset Progress Flow (AC-SET-15 – AC-SET-20)

**AC-SET-15 [Logic] — First press enters countdown.**
GIVEN the panel is Open, WHEN the Reset Progress button is pressed once, THEN the button text changes to "Confirm Reset (3)" AND a 3-second timer starts AND the button remains pressable.

**AC-SET-16 [Logic] — Second press within window commits.**
GIVEN the button shows "Confirm Reset (N)" with N > 0, WHEN it is pressed again, THEN `SaveSystem.clear_save()` is called exactly once.

**AC-SET-17 [Logic] — Countdown timeout cancels.**
GIVEN the first press happened at t=0, WHEN 3.0 seconds pass without a second press, THEN the button reverts to "Reset Progress" AND `SaveSystem.clear_save()` is NOT called.

**AC-SET-18 [Integration] — Commit from gameplay switches to Main Menu.**
GIVEN the player is in gameplay scene "park" AND presses Reset Progress twice, WHEN the commit resolves, THEN the active scene changes to `res://src/ui/main_menu/main_menu.tscn` AND the panel is freed.

**AC-SET-19 [Logic] — Commit from Main Menu stays on Main Menu.**
GIVEN the player is on Main Menu AND presses Reset Progress twice, WHEN the commit resolves, THEN no scene change occurs AND the panel is freed AND `user://moments_save.json` no longer exists.

**AC-SET-20 [Logic] — Close during countdown cancels reset.**
GIVEN the button shows "Confirm Reset (2)", WHEN the Close button is pressed, THEN the panel closes AND `SaveSystem.clear_save()` is NOT called AND on next panel open, the Reset Progress button shows default text (state reset on panel re-instantiation).

### Persistence Contract (AC-SET-21 – AC-SET-23)

**AC-SET-21 [Logic] — Settings file round-trips intact.**
GIVEN Master=0.6, Music=0.3, SFX=0.9 are set AND written, WHEN the game is restarted, THEN `SettingsManager.get_volume()` returns the same three values within ±0.01 AND `AudioManager` was called with the matching dB values at startup.

**AC-SET-22 [Integration] — Reset Progress does NOT wipe settings.**
GIVEN the settings file holds Master=0.3, WHEN Reset Progress is committed, THEN `user://moments_settings.json` is unchanged AND `user://moments_save.json` is deleted.

**AC-SET-23 [Logic] — Quit with pending debounce flushes on close.**
GIVEN a slider change occurred 100 ms ago (within the 500 ms debounce window), WHEN the application receives `NOTIFICATION_WM_CLOSE_REQUEST`, THEN `flush_pending_save()` is called AND the disk file reflects the most recent change.

### Cross-System Contracts (AC-SET-24 – AC-SET-25)

**AC-SET-24 [Integration] — Bus-name casing matches Audio Manager.**
GIVEN Settings uses PascalCase bus names `"Master"`, `"Music"`, `"SFX"` matching the Godot `default_bus_layout.tres` and Audio Manager AC-AM-14, WHEN `set_bus_volume()` is called, THEN the bus resolves successfully AND no warning about unknown bus names is logged. This AC passes only when bus-name casing is identical between Settings source and Audio Manager expectations.

**AC-SET-25 [Integration] — Reset commit calls the public SaveSystem API only.**
GIVEN Reset Progress is committed, WHEN inspected, THEN the panel calls `SaveSystem.clear_save()` AND nothing else (no direct file deletion, no MUT call, no SceneManager call). Single source of truth preserved.

## Open Questions

| ID | Question | Owner | Target |
|----|----------|-------|--------|
| OQ-1 | **Slider labels — PNG or DynamicFont?** Main Menu uses single-author PNGs for all text (Pillar 4). Settings has three labels ("Master", "Music", "SFX") plus the title. Keeping PNG consistency is visually correct but authoring cost is low. Recommendation: PNG for title (consistency with Main Menu), DynamicFont for the three slider labels (small, utilitarian). Decide during Art Bible step. | art-director | During Art Bible |
| OQ-2 | **Fullscreen toggle.** Deferred out of Full Vision scope per the design decision. If Chester ever adds it, it goes in this panel above the Reset Progress divider. Requires a `CheckBox` widget and `DisplayServer.window_set_mode()` call. | game-designer | Post-launch only if requested |
| OQ-3 | **Reduced-motion accessibility setting.** STUI currently reads its `reduced_motion_default` from `ProjectSettings` (per its OQ-7). When Settings schema bumps to v2 to expose a player-facing reduced-motion toggle, the source-of-truth should move to `SettingsManager` and STUI should read it from there. At Full Vision v1, `reduced_motion` remains a ProjectSettings value; Settings does not expose it. This split is intentional — escalation only if playtest surfaces motion that violates reduced-motion preferences. | accessibility-specialist + systems-designer | Settings schema v2 (deferred until justified by playtest) |
| OQ-4 | **Panel behavior during transitions.** If the panel is open while Scene Manager enters `Transitioning`, what happens to card input suppression? Current answer: Scene Manager blocks card input independently of Settings. The two suppressions are redundant but don't conflict. Verify during integration testing. | qa-lead | Integration test phase |
| OQ-5 | **Hover sound on gear icon (future).** Would a subtle paper-rustle sound on gear hover add warmth without violating Pillar 4? Current stance: silence. Revisit only if audio director has strong feeling. | audio-director | Post-MVP revisit |
| OQ-6 | **Settings schema v2 candidates.** If Fullscreen, Reduced Motion, or Analytics Opt-in are ever added, schema bumps to v2. Migration from v1 is trivial (additive fields with defaults). Deferred. | systems-designer | Reactive |
