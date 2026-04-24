---
name: img-background
description: "Generate a full-viewport ornamental parchment background plate for a scene. Reads the prompt from img_generate.md and calls nano-banana generate_image. Output saved to assets/ambient/<scene-id>.png."
argument-hint: "<scene-id> \"<scene-concept>\" \"<corner-motifs>\""
user-invocable: true
allowed-tools: Read, mcp__nano-banana__generate_image, mcp__nano-banana__get_configuration_status
---

## Step 0: Check configuration

Call `mcp__nano-banana__get_configuration_status`. If not configured, stop and tell the user to run `/configure_gemini_token`.

## Step 1: Parse arguments

Extract:
- `scene_id` — required. Used to name the output file (e.g. `drive`, `coffee-intro`).
- `scene_concept` — required. Theme keyword for the scene (e.g. `car-road-trip`, `kitchen-morning`).
- `corner_motifs` — required. Description of the four corner ornament hints.

If any argument is missing, fail with:
> "Usage: `/img-background <scene-id> \"<scene-concept>\" \"<corner-motifs>\"`
> Example: `/img-background drive \"car-road-trip\" \"steering wheel curl (top-left), map fold line (top-right), road sign silhouette (bottom-left), destination flag (bottom-right)\"`
>
> See `img_generate.md` for the full example table."

## Step 2: Read the prompt

Read `img_generate.md`. Extract the prompt block under `## 概念產生背景圖`.

Replace:
- `{SCENE_CONCEPT}` → the provided `scene_concept`
- `{CORNER_MOTIFS}` → the provided `corner_motifs`

## Step 3: Generate

Call `mcp__nano-banana__generate_image` with the filled prompt.

Output path: `assets/ambient/<scene-id>.png`

## Step 4: Report

Confirm the output path. Remind the user to wire it in the scene spec's Section 10.2:
```
ambient.path = res://assets/ambient/<scene-id>.png
ambient.anchor = full_viewport
ambient.alpha = 0.9
```
