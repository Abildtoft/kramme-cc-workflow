# Tier: Before/After Screenshots

Use before/after screenshots when the reviewer needs to compare two visible states.

## Safe Baseline

Capture the "before" state only when it can be reproduced safely without destructive actions or branch churn. Good baselines include:

- an existing screenshot from a bug report,
- a running baseline app provided by the user,
- a safe old-state fixture or feature flag,
- a reproducible invalid/input state that still exists in the current app.

Do not reset the user's worktree, switch branches, or start a separate baseline server unless the user explicitly asks.

If the old state cannot be reproduced, capture the fixed/current state and state what the old behavior was based on the issue, commit, or diff evidence.

## Capture Steps

1. Capture `before-<target>.png` if a safe baseline exists.
2. Capture `after-<target>.png` from the current fixed behavior.
3. Use matching viewport size, route, test data, and interaction depth for both images.
4. Write `comparison.md` in `DEMO_REEL_DIR` with:
   - what changed,
   - where to look,
   - any missing before-state limitation.

## Report

Return paired paths and a one-sentence comparison:

```markdown
| State | What it shows | Local path |
| --- | --- | --- |
| Before | <old state> | `<path>` |
| After | <new state> | `<path>` |
```
