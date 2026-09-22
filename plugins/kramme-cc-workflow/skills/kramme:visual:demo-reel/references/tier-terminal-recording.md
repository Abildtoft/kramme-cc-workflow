# Tier: Terminal Recording

Use terminal recording for CLI behavior that is clearer as a short command sequence.

## Requirements

- `vhs` preferred for GIF terminal recordings.
- A safe command that exercises product behavior, not test output.

If `vhs` is unavailable, fall back to static terminal screenshots or a concise transcript saved in `DEMO_REEL_DIR`.

## Capture Steps

1. Confirm the command does not print secrets, tokens, private data, or destructive prompts.
2. Prefer dry-run, local fixtures, or demo data.
3. Create a `.tape` file under `DEMO_REEL_DIR` with the shortest useful sequence.
4. Use `Hide`/`Show` for setup that should not appear in the recording.
5. Render to `terminal-demo.gif`.

Minimal VHS shape:

```text
Output terminal-demo.gif
Set FontSize 14
Set Width 1000
Set Height 600

Type "<safe product command>"
Enter
Sleep 1s
```

Run from `DEMO_REEL_DIR`:

```bash
vhs terminal-demo.tape
```

## Quality Bar

- The recording should show the feature's result, not setup noise.
- Avoid long scrolling output. Use flags that produce focused output when available.
- If a command needs credentials, set them outside the recording and do not display them.
