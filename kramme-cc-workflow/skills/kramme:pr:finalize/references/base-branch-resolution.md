# Base Branch Resolution

Use this in Step 2.3 to compute `BASE_BRANCH`.

Resolve the base branch with the shared plugin script. It uses a 3-tier strategy: explicit `BASE_BRANCH_OVERRIDE` from `--base`, PR target branch, then `origin/HEAD`/`origin/main`/`origin/master`. It runs in strict mode, so fetch failures stop the workflow with the script's stderr message.

```bash
RESOLVE_ARGS=(--strict)
[ -n "${BASE_BRANCH_OVERRIDE:-}" ] && RESOLVE_ARGS+=(--base "$BASE_BRANCH_OVERRIDE")

RESOLVED=$(${CLAUDE_PLUGIN_ROOT}/scripts/resolve-base.sh "${RESOLVE_ARGS[@]}") || {
  echo "Base resolution failed; see the message above and stop." >&2
  exit 1
}
eval "$RESOLVED"
```

The script exports `BASE_REF`, `BASE_BRANCH`, and `MERGE_BASE` for later finalize steps.
