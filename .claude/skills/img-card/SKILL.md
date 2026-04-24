---
name: img-card
description: "Generate a Stacklands-style card illustration from a text concept. Reads the prompt from img_generate.md and calls nano-banana generate_image."
argument-hint: "<concept>"
user-invocable: true
allowed-tools: Read, mcp__nano-banana__generate_image, mcp__nano-banana__get_configuration_status
---

## Step 0: Check configuration

Call `mcp__nano-banana__get_configuration_status`. If not configured, stop and tell the user to run `/configure_gemini_token`.

## Step 1: Parse arguments

Extract:
- `concept` — required. The concept or card name to illustrate (e.g. `駕駛座`, `coffee machine`, `steering wheel`).

If no argument provided, fail with:
> "Usage: `/img-card <concept>`
> Example: `/img-card 駕駛座`"

## Step 2: Read the prompt

Read `img_generate.md`. Extract the prompt block under `## 概念轉卡片圖`.

Replace every occurrence of `{CONCEPT}` with the provided concept.

## Step 3: Generate

Call `mcp__nano-banana__generate_image` with the filled prompt.

## Step 4: Report

Tell the user the output path and confirm the image was saved.
Suggest: if the result needs refinement, run `/img-cartoonize` on the output with a reference photo.
