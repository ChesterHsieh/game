---
name: fetch-google-photo
description: "Download a publicly-shared Google Photos image to a local path. Follows the photos.app.goo.gl → photos.google.com/share redirect, parses the HTML for the googleusercontent.com CDN URL, and downloads the full-resolution image via curl. Use when a user provides a Google Photos share link and wants the image file locally (e.g. for use as a game asset)."
argument-hint: "<google_photos_url> <output_path>"
user-invocable: true
allowed-tools: Bash, Read
---

## Why this skill exists

Google Photos short links (`photos.app.goo.gl/...`) do NOT serve the image directly.
They redirect to an HTML share page (`photos.google.com/share/...`) whose HTML
embeds the actual CDN URL (`lh3.googleusercontent.com/pw/...`). The WebFetch tool
cannot see through this redirect reliably, and the CDN URL carries a sizing
suffix (`=w600-h315-p-k`) that must be rewritten to get the full-resolution
original. This skill captures the working flow so it is repeatable and robust.

## Prerequisites

- The Google Photos link MUST be publicly shared (viewable by "anyone with the
  link"). Private or account-locked photos will fail — `curl` will receive a
  sign-in page with no CDN URL.
- `curl` is available on macOS / Linux by default — no extra install needed.

## Step 0: Parse arguments

Extract:
- `google_photos_url` — required. Either a `photos.app.goo.gl/...` short link OR
  a full `photos.google.com/share/...` URL.
- `output_path` — required. Absolute path where the image should be saved,
  including extension (`.jpg` is correct — Google Photos serves JPEG even when
  the path says `.png`).

If either argument is missing, fail with:
> "Usage: `/fetch-google-photo <google_photos_url> <output_path>`
> Example: `/fetch-google-photo https://photos.app.goo.gl/xxxxx assets/epilogue/photo.jpg`"

## Step 1: Extract the CDN URL

Run this Bash one-liner — it follows redirects, greps the HTML for the first
`lh[0-9].googleusercontent.com` URL, and trims any trailing sizing param:

```bash
CDN_URL=$(curl -sL -A "Mozilla/5.0" "<google_photos_url>" \
  | grep -oE 'https://lh[0-9]\.googleusercontent\.com/pw/[A-Za-z0-9_-]+' \
  | head -1)
```

If `$CDN_URL` is empty after this step, STOP. The link is private, expired, or
the HTML structure changed. Tell the user and ask them to confirm the share
is publicly accessible.

## Step 2: Download full-resolution

Append `=w2048-no` to the CDN URL to request a 2048px-wide version (suitable
for all game asset use). The `-no` suffix disables watermark overlays. Use
`-o` to write to the requested output path:

```bash
mkdir -p "$(dirname <output_path>)"
curl -sL -A "Mozilla/5.0" "${CDN_URL}=w2048-no" -o "<output_path>"
```

## Step 3: Verify the download

Confirm the file is a real image and report file info:

```bash
file "<output_path>"
ls -la "<output_path>"
```

If `file` reports anything other than `JPEG image data` / `PNG image data`,
the download failed — probably an HTML error page was saved. Delete the file
and retry, or ask the user to verify the share link.

## Step 4: (Optional) Trigger Godot import

If the output path is under `res://assets/`, the PNG import sidecar won't
exist until Godot rescans. Suggest the user run:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --import
```

(Non-macOS: adjust `GODOT_BIN` accordingly.) Or let the editor regenerate it
on next open.

## Step 5: Report

Tell the user:
- The output path
- Image dimensions (from `file` output)
- Whether the Godot import sidecar was generated (check for `<output_path>.import`)

## Resolution tuning

The `=w2048-no` suffix is a reasonable default for 2D game art. Alternatives:
- `=w4096-no` — original resolution for large assets (max ~4K on typical phone captures)
- `=w1024-no` — thumbnail / preview / lower VRAM target
- `=d` — raw download, highest available resolution, strips all processing

Change the suffix in Step 2 if the user asks for a specific size.

## Failure modes

- **Sign-in page served**: link is private. `grep` returns no match. Ask user.
- **HTTP 403 / 404**: link expired or deleted. Same response — ask user.
- **Empty file written**: curl redirect chain broken. Rerun with `-v` flag to
  inspect; usually means the CDN URL was rewritten or the `=w2048-no` suffix
  was malformed.
- **Stale Godot import**: `.import` sidecar exists but points to old UID. Delete
  the sidecar and let `--headless --import` regenerate.

## Security note

Only follow share links the user explicitly provided. Do not accept arbitrary
URLs — the skill downloads to the user's filesystem and executes `curl`. The
user's intent must be clear (they pasted a link and asked for it locally).
