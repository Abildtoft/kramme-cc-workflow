# Tier: Static Screenshots

Use static screenshots when one or more still states prove the change.

## Web UI

1. Navigate to `TARGET_URL` plus the route inferred from the target.
2. Wait for loading to settle.
3. Capture the smallest useful viewport set:
   - desktop state when the change is layout/content,
   - mobile state only when responsive behavior changed,
   - error/empty/loading state only when that state changed.
4. Save files under `DEMO_REEL_DIR` with descriptive lowercase names, such as `settings-default.png` or `checkout-empty-state.png`.

Use the available browser screenshot tool when possible. If no browser automation can save files directly, save returned image data through the runtime's file-write capability. If neither is available, ask the user to provide a screenshot or use the OS screenshot tool, then place the file in `DEMO_REEL_DIR`.

## CLI or Terminal Output

1. Run the command that exercises the changed behavior.
2. Capture only the output needed to prove the behavior.
3. Save a terminal screenshot or text transcript in `DEMO_REEL_DIR`.

Do not label a transcript of tests as demo evidence. The command must be product usage.

## Report

Return a local-only PR table:

```markdown
| Evidence | What it shows | Local path |
| --- | --- | --- |
| Screenshot | <state proved> | `<path>` |
```
