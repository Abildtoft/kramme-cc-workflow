# Base Branch Resolution

Use this in Phase 1 to confirm the current branch and compute `BASE_BRANCH`.

1. **ALWAYS** confirm the current branch:

   ```bash
   git branch --show-current
   ```

2. **ALWAYS** resolve the base/target branch with the shared plugin script. It uses a 3-tier strategy: explicit `BASE_BRANCH_OVERRIDE` from `--base`, PR target branch, then `origin/HEAD`/`origin/main`/`origin/master`. It runs in strict mode, so fetch failures stop the workflow with the script's stderr message.

   ```bash
   RESOLVE_ARGS=(--strict)
   [ -n "${BASE_BRANCH_OVERRIDE:-}" ] && RESOLVE_ARGS+=(--base "$BASE_BRANCH_OVERRIDE")

   RESOLVED=$(${CLAUDE_PLUGIN_ROOT}/scripts/resolve-base.sh "${RESOLVE_ARGS[@]}") || {
     echo "Base resolution failed; see the message above and stop." >&2
     exit 1
   }
   eval "$RESOLVED"
   echo "Base branch: $BASE_BRANCH"
   ```

   The script exports `BASE_REF`, `BASE_BRANCH`, and `MERGE_BASE` for later context gathering.

   - **NOTE**: PR target branch detection ensures correct scope when the PR targets a non-default branch (e.g., a feature branch stacked on another PR)
   - **CAN** ask user if unclear or override needed
