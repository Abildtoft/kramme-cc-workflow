# Diff Scope Resolution

Use this during `diff-aware` mode before filtering for UI-relevant files.

## Base Branch

Resolve the base branch using a 3-tier strategy:

**Tier 1: Explicit override** If `--base <branch>` was provided, use that value directly as `BASE_BRANCH`. Skip Tier 2 and 3.

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
  echo "Error: Could not determine base branch. Re-run with --base <branch>." >&2
  exit 1
fi
if ! git check-ref-format --branch "$BASE_BRANCH" > /dev/null 2>&1; then
  echo "Error: Base branch '$BASE_BRANCH' is not a valid branch name. Re-run with --base <branch>." >&2
  exit 1
fi
if ! git fetch origin "refs/heads/${BASE_BRANCH}:refs/remotes/origin/${BASE_BRANCH}" 2> /dev/null; then
  echo "Error: Failed to fetch origin/$BASE_BRANCH. Check remote access and re-run with --base <branch>." >&2
  exit 1
fi
if ! git rev-parse --verify --quiet "origin/$BASE_BRANCH" > /dev/null; then
  echo "Error: Base branch 'origin/$BASE_BRANCH' not found. Re-run with --base <branch>." >&2
  exit 1
fi
```

## Changed Files

Identify changed UI files:

```bash
BASE_REF=$(git merge-base origin/$BASE_BRANCH HEAD)
{
  git diff --name-only "$BASE_REF"...HEAD  # committed PR diff
  git diff --name-only --cached            # staged local changes
  git diff --name-only                     # unstaged local changes
  git ls-files --others --exclude-standard # untracked local files
} | sed '/^$/d' | sort -u
```
