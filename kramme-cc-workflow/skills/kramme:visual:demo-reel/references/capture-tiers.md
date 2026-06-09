# Capture Tiers

Use the lightest evidence tier that proves the observable behavior.

| Tier | Best For | Required Capability | Output |
| --- | --- | --- | --- |
| Static screenshots | One visible UI state, a simple CLI output state, an API response, or a fixed state that cannot reproduce the old bug locally. | Browser screenshot tool, OS screenshot tool, or a terminal/image capture path. | One or more `.png` files. |
| Before/after screenshots | Bug fixes, state changes, visual comparisons, regressions, or changed empty/error/loading states. | Same as static screenshots, plus a safe way to capture both states. | Paired `.png` files with a short comparison note. |
| Browser reel | Web UI flows, animation, multi-step interaction, navigation, drag/drop, toggles, or responsive behavior. | Browser automation for screenshots plus `ffmpeg` for stitching when generating GIF/video. | `.gif`, `.mp4`, or a PNG sequence fallback. |
| Terminal recording | CLI features with prompts, streaming output, progress, or multi-step command behavior. | `vhs` preferred. Static screenshot fallback when recording is unavailable. | `.gif` or terminal frame `.png` files. |

## Selection Rules

1. If the change has no observable behavior, skip evidence and say why.
2. If the change is a bug fix and the old state can be reproduced safely, prefer before/after.
3. If the behavior is web UI with meaningful motion or interaction, prefer browser reel when browser automation and `ffmpeg` are available.
4. If the behavior is CLI motion or multi-step terminal interaction, prefer terminal recording when `vhs` is available.
5. If richer tooling is missing, choose static screenshots or before/after screenshots instead of blocking.
6. If capture requires secrets, private data, paid services, cloud credentials, or destructive actions, stop and ask for a safe capture path.

## Fallback Order

- Browser reel -> before/after screenshots -> static screenshots.
- Terminal recording -> static screenshots.
- Before/after screenshots -> static screenshots.

Do not claim "Demo" for test output. Label static and before/after evidence as "Screenshots"; label browser and terminal recordings as "Demo" only when they show actual product usage.
