# Base Branch Resolution

Use this in Phase 1 to compute `BASE_BRANCH`.

1. **ALWAYS** confirm the current branch:

   ```bash
   git branch --show-current
   ```

2. **ALWAYS** detect and identify the base/target branch dynamically using a 3-tier strategy:

   **Tier 1: Explicit override** If `BASE_BRANCH_OVERRIDE` was set from `--base`, use that value directly.

   **Tier 2: PR target branch detection**

   ```bash
   BASE_BRANCH=$(gh pr view --json baseRefName --jq '.baseRefName' 2> /dev/null)
   ```

   **Tier 3: Fallback**

   ```bash
   BASE_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2> /dev/null | sed 's@^refs/remotes/origin/@@')
   [ -z "$BASE_BRANCH" ] && BASE_BRANCH=$(git branch -r | grep -E 'origin/(main|master)$' | head -1 | sed 's@.*origin/@@')
   ```

   Normalize before using `origin/$BASE_BRANCH`:

   ```bash
   BASE_BRANCH=${BASE_BRANCH#refs/heads/}
   BASE_BRANCH=${BASE_BRANCH#refs/remotes/origin/}
   BASE_BRANCH=${BASE_BRANCH#origin/}
   if [ -z "$BASE_BRANCH" ]; then
     echo "Error: Could not determine base branch. Re-run with --base <ref>." >&2
     exit 1
   fi
   if ! git check-ref-format --branch "$BASE_BRANCH" > /dev/null 2>&1; then
     echo "Error: Base branch '$BASE_BRANCH' is not a valid branch name. Re-run with --base <ref>." >&2
     exit 1
   fi
   if ! git fetch origin "refs/heads/${BASE_BRANCH}:refs/remotes/origin/${BASE_BRANCH}" 2> /dev/null; then
     echo "Error: Failed to fetch origin/$BASE_BRANCH. Check remote access and re-run with --base <ref>." >&2
     exit 1
   fi
   if ! git rev-parse --verify --quiet "origin/$BASE_BRANCH" > /dev/null; then
     echo "Error: Base branch 'origin/$BASE_BRANCH' not found. Re-run with --base <ref>." >&2
     exit 1
   fi
   echo "Base branch: $BASE_BRANCH"
   ```

   - **NOTE**: Tier 2 ensures correct scope when the PR targets a non-default branch (e.g., a feature branch stacked on another PR)
   - **CAN** ask user if unclear or override needed
