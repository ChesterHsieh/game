---
name: img-cartoonize
description: "Convert a real photo into a Stacklands-style minimal cartoon card illustration. Reads the prompt from img_generate.md and calls nano-banana edit_image."
argument-hint: "<photo-path> [--out <output-path>]"
user-invocable: true
allowed-tools: Read, mcp__nano-banana__edit_image, mcp__nano-banana__get_configuration_status
---

## Step 0: Check configuration

Call `mcp__nano-banana__get_configuration_status`. If not configured, stop and tell the user to run `/configure_gemini_token`.

## Step 1: Parse arguments

Extract:
- `photo_path` — required. The file path to the source photo.
- `output_path` — optional `--out` argument. Default: same directory as source, with suffix `_cartoon`.

If no `photo_path` provided, fail with:
> "Usage: `/img-cartoonize <photo-path>`
> Example: `/img-cartoonize assets/photos/ju_cooking.jpg`"

## Step 2: Read the prompt

Read `img_generate.md`. Extract the prompt block under `## 真實照片轉卡通`.

## Step 3: Generate

Call `mcp__nano-banana__edit_image` with:
- `imagePath`: the provided `photo_path`
- `prompt`: the extracted prompt text

## Step 4: Report

Tell the user the output path and confirm the image was saved.
