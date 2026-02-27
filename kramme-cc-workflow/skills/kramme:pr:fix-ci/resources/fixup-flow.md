# Fixup Commit Flow (Step 7b)

**Goal:** Amend existing branch commits instead of adding new commits, keeping history clean during iteration.

## 7b.1: Determine Base Branch (from PR)

Use the PR's base branch from Step 1 so fixups stay scoped to the actual target branch.

```bash
# GitHub
BASE=$(gh pr view --json baseRefName --jq .baseRefName)
```

```bash
# GitLab (glab CLI — preferred)
BASE=$(glab mr view --json target_branch --jq .target_branch)
```

```bash
# GitLab MCP (alternative if glab is unavailable)
# Use target_branch from mcp__gitlab__get_merge_request
```

If the PR base branch can't be determined, fall back to `origin/HEAD`, then `main`, then `master`.

```bash
if [ -z "$BASE" ]; then
  BASE=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
fi
if [ -z "$BASE" ]; then
  if git show-ref --verify --quiet refs/remotes/origin/main; then
    BASE=main
  else
    BASE=master
  fi
fi
BASE_REF="origin/$BASE"
```

Before using `BASE_REF`, ensure the remote ref exists and is up to date:

```bash
git fetch origin $BASE
git show-ref --verify --quiet refs/remotes/origin/$BASE
```

If the ref is missing, re-run base detection or `git fetch origin` and try again.

Derive the branch fork point from the resolved base ref. This keeps fixup autosquash scoped to branch commits even when the base branch has advanced:

```bash
FIXUP_BASE=$(git merge-base HEAD "$BASE_REF")
```

## 7b.2: Map Changed Files to Commits

For each changed file (from `git diff --name-only`, `git diff --cached --name-only`, and untracked files from `git ls-files --others --exclude-standard`), find which branch commit last touched it:

```bash
git log $BASE_REF..HEAD -n 1 --format=%H -- <file_path>
```

Combine and de-dupe those file lists before mapping. Group files by their target commit SHA. Files with no matching commit are "orphans" (files not touched by any branch commit, including files last modified on the base branch).

## 7b.3: Create Fixup Commits

For each target commit (from the mapping):

```bash
git add -A -- <matched_files...>
git commit --fixup=<commit_sha>
```

## 7b.4: Handle Orphan Files

If any files were not touched by branch commits (orphans), create a regular commit for them:

```bash
git add -A -- <orphan_files...>
git commit -m "<descriptive message of what was fixed>"
```

## 7b.5: Autosquash Rebase

```bash
GIT_SEQUENCE_EDITOR=true git rebase -i --autosquash "$FIXUP_BASE"
```

**If rebase fails (conflicts):**

1. Abort the rebase:
   ```bash
   git rebase --abort
   ```
2. Log a warning:
   > "Autosquash rebase failed due to conflicts. Falling back to regular commit mode for this iteration. The fixup commits remain on the branch and can be manually squashed later."
3. Fall back to regular commit (Step 7 default behavior) for any remaining uncommitted changes
4. Continue to push step

## 7b.6: Push with Force

After successful rebase (or fallback), push with force:

```bash
git push --force-with-lease origin $(git branch --show-current)
```

**Note:** `--force-with-lease` is required because the rebase rewrites history. It refuses to overwrite remote commits you haven't fetched, but you should still coordinate with other contributors before forcing.
