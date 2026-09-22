# Tier: Browser Reel

Use a browser reel for web behavior that is clearer as motion or a short interaction sequence.

## Requirements

- Browser automation capable of navigation, interaction, and screenshots.
- `ffmpeg` for GIF/video stitching. If `ffmpeg` is missing, save the screenshot sequence instead.
- A running app URL from an explicit `--url` or the shared dev-server detector.

## Capture Steps

1. Open a fresh browser tab/page for the run.
2. Navigate to `TARGET_URL` plus the inferred route.
3. Capture an initial screenshot.
4. Perform only the interactions needed to show the behavior.
5. Capture a screenshot after each meaningful state transition.
6. Save frames as `frame-001.png`, `frame-002.png`, etc. in `DEMO_REEL_DIR/browser-reel/`.
7. If `ffmpeg` is available, stitch frames into `browser-reel.gif` or `browser-reel.mp4` in `DEMO_REEL_DIR`.

Example stitching command, after frames exist:

```bash
ffmpeg -y -framerate 2 -i "$DEMO_REEL_DIR/browser-reel/frame-%03d.png" "$DEMO_REEL_DIR/browser-reel.gif"
```

## Quality Bar

- Keep the reel under 10 seconds unless the user asked for a longer flow.
- Avoid browser chrome and DevTools unless the product behavior requires them.
- Do not record authentication steps. Show the authenticated product state after safe setup.
- If interaction fails or the captured flow is unclear, fall back to before/after or static screenshots.
