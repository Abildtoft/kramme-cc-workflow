---
name: kramme:visual:generate-image
description: Generate and edit images using Google's Gemini 3 Pro Image API. Use when the user asks to generate, create, edit, modify, change, alter, or update images. Also use when user references an existing image file and asks to modify it in any way (e.g., "modify this image", "change the background", "replace X with Y"). Supports both text-to-image generation and image-to-image editing with configurable resolution (1K default, 2K, or 4K for high resolution). DO NOT read the image file first - use this skill directly with the --input-image parameter.
argument-hint: "[prompt or editing instructions]"
disable-model-invocation: true
user-invocable: true
kramme-platforms: [claude-code, codex]
---

# Image Generation & Editing

Generate new images or edit existing ones using Google's Gemini 3 Pro Image API.

**Arguments:** "$ARGUMENTS"

**Side effects:** Calls Google's paid Gemini API over the network and writes a PNG to disk. Every run consumes API quota, and higher resolutions cost more.

**Not for:** generating diagrams, charts, or data visualizations from structured input, and not for analyzing or describing an existing image — this skill only writes image files.

## Usage

**Requires:** `uv`, network access, and a Gemini API key (see the API Key section below).

Run the script by absolute path from the user's current working directory, so images save where the user is working — do not `cd` into the skill directory first.

Set plugin root once (works in both Claude Code and Codex):

```bash
export PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$CODEX_HOME}"
```

If your environment does not set either variable, replace `${PLUGIN_ROOT}` in the commands below with your plugin root path manually.

**Generate new image:**

```bash
uv run ${PLUGIN_ROOT}/skills/kramme:visual:generate-image/scripts/generate_image.py --prompt "your image description" --filename "output-name.png" [--resolution 1K | 2K | 4K]
```

**Edit existing image:**

```bash
uv run ${PLUGIN_ROOT}/skills/kramme:visual:generate-image/scripts/generate_image.py --prompt "editing instructions" --filename "output-name.png" --input-image "path/to/input.png" [--resolution 1K | 2K | 4K]
```

## Resolution Options

The Gemini 3 Pro Image API supports three resolutions (uppercase K required):

- **1K** (default) - ~1024px resolution
- **2K** - ~2048px resolution
- **4K** - ~4096px resolution

Map user requests to API parameters:

- No mention of resolution → `1K`
- "low resolution", "1080", "1080p", "1K" → `1K`
- "2K", "2048", "normal", "medium resolution" → `2K`
- "high resolution", "high-res", "hi-res", "4K", "ultra" → `4K`

**Editing:** when no resolution is specified, the script matches the output to the input image's dimensions (≥3000px → 4K, ≥1500px → 2K, otherwise 1K). Pass `--resolution` explicitly to override this and control cost.

## API Key

The script reads the key from the `--api-key` argument first, then the `GEMINI_API_KEY` environment variable. **Prefer the environment variable** — values passed as command arguments are visible in process listings, shell history, and logs.

If `GEMINI_API_KEY` is already set in the environment, run the command with no key argument or prefix at all — never echo the literal key into a command when the environment variable exists.

If the key is not in the environment (e.g., the user pastes it in chat), set it as an inline prefix for the single command. This keeps the key out of `ps` process listings, but like any command it still appears in shell history and the session transcript:

```bash
GEMINI_API_KEY="<key>" uv run ${PLUGIN_ROOT}/skills/kramme:visual:generate-image/scripts/generate_image.py --prompt "..." --filename "..."
```

Use `--api-key` only when neither of the above is possible.

If no key is available, the script exits with an error.

## Filename Generation

Generate filenames with the pattern: `yyyy-mm-dd-hh-mm-ss-name.png`

**Format:** `{timestamp}-{descriptive-name}.png`

- Timestamp: Current date/time in format `yyyy-mm-dd-hh-mm-ss` (24-hour format)
- Name: Descriptive lowercase text with hyphens
- Keep the descriptive part concise (1-5 words typically)
- Use context from user's prompt or conversation
- If unclear, use random identifier (e.g., `x9k2`, `a7b3`)

Examples:

- Prompt "A serene Japanese garden" → `2025-11-23-14-23-05-japanese-garden.png`
- Prompt "sunset over mountains" → `2025-11-23-15-30-12-sunset-mountains.png`
- Prompt "create an image of a robot" → `2025-11-23-16-45-33-robot.png`
- Unclear context → `2025-11-23-17-12-48-x9k2.png`

## Image Editing

When the user wants to modify an existing image:

1. Check if they provide an image path or reference an image in the current directory
2. Use `--input-image` parameter with the path to the image
3. The prompt should contain editing instructions (e.g., "make the sky more dramatic", "remove the person", "change to cartoon style")
4. Common editing tasks: add/remove elements, change style, adjust colors, blur background, etc.

## Prompt Handling

**For generation:** Pass user's image description as-is to `--prompt`. Only rework if clearly insufficient.

**For editing:** Pass editing instructions in `--prompt` (e.g., "add a rainbow in the sky", "make it look like a watercolor painting")

Preserve user's creative intent in both cases.

## Output

- Saves PNG to current directory (or specified path if filename includes directory)
- Script outputs the full path to the generated image
- **Do not read the image back** - just inform the user of the saved path
- An existing file at the target filename is overwritten without warning. The timestamped naming pattern avoids collisions for generated images; when editing with an explicit filename, choose a new name to preserve the original.
- If the script exits non-zero, surface its stderr to the user instead of retrying blindly — common causes are a missing API key, no network, or a prompt rejected by the model.
