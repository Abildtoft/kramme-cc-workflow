---
name: kramme:pr:product-review
description: (experimental) Deep product review of branch and local changes. Evaluates user-value alignment, flow completeness, missing states, copy/defaults, permission behavior, and adjacent-flow regressions. Not for UX heuristics, accessibility, or visual consistency -- use pr:ux-review for those.
argument-hint: "[--base <ref>] [--threshold 0-100]"
disable-model-invocation: true
user-invocable: true
---

# Product Review for Pull Request and Local Changes

Deep product review of branch changes and local work. Evaluates user-value alignment, flow completeness, missing states, copy/defaults, permission behavior, and adjacent-flow regressions.

**Arguments:** "$ARGUMENTS"

## Review Workflow

### Step 1: Parse Arguments

1. If `--base <ref>` flag provided, store as explicit base branch override
2. If `--threshold N` flag provided, store as `custom_threshold` (0-100). Only findings with confidence >= N will be reported. Default: 70
3. If neither flag is present, use defaults

### Step 2: Load Project Review Conventions

Before launching agents:

1. Read `CLAUDE.md` from repo root.
2. Discover `AGENTS.md` files in repo (`find . -name AGENTS.md`), then read relevant ones.
3. Extract product and UI constraints, especially:
   - Product domain and target users
   - UI stack and component/design system requirements
   - Platform scope (desktop/mobile/web)
   - Feature flags, permission models, or role-based access rules
4. Pass these conventions to the reviewer agent and instruct it to prioritize documented conventions over generic best practices.

### Step 3: Resolve Base Branch and Identify Changed Files

Determine the correct base branch using a 3-tier strategy:

**Tier 1: Explicit override**
If `--base <ref>` was provided in Step 1, use that value directly as `BASE_BRANCH`. Skip Tier 2 and 3.

**Tier 2: PR/MR target branch detection**
```bash
REMOTE_URL=$(git remote get-url origin 2>/dev/null)
if printf '%s' "$REMOTE_URL" | grep -q 'github.com' && command -v gh >/dev/null 2>&1; then
  BASE_BRANCH=$(gh pr view --json baseRefName --jq '.baseRefName' 2>/dev/null)
elif printf '%s' "$REMOTE_URL" | grep -qi 'gitlab' && command -v glab >/dev/null 2>&1; then
  BASE_BRANCH=$(glab mr view --json target_branch --jq '.target_branch' 2>/dev/null)
elif command -v glab >/dev/null 2>&1; then
  BASE_BRANCH=$(glab mr view --json target_branch --jq '.target_branch' 2>/dev/null)
fi
```
- GitLab MCP alternative if `glab` is unavailable: use `mcp__gitlab__get_merge_request` and extract `target_branch`

**Tier 3: Fallback**
```bash
BASE_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
[ -z "$BASE_BRANCH" ] && BASE_BRANCH=$(git branch -r | grep -E 'origin/(main|master)$' | head -1 | sed 's@.*origin/@@')
```

Normalize before using `origin/$BASE_BRANCH` (handles values like `origin/develop` and `refs/heads/develop`):
```bash
BASE_BRANCH=${BASE_BRANCH#refs/heads/}
BASE_BRANCH=${BASE_BRANCH#refs/remotes/origin/}
BASE_BRANCH=${BASE_BRANCH#origin/}
if [ -z "$BASE_BRANCH" ]; then
  echo "Error: Could not determine base branch. Re-run with --base <ref>." >&2
  exit 1
fi
if ! git rev-parse --verify --quiet "origin/$BASE_BRANCH" >/dev/null; then
  echo "Error: Base branch 'origin/$BASE_BRANCH' not found. Re-run with --base <ref>." >&2
  exit 1
fi
```

Then identify changed files from all four sources:
```bash
BASE_REF=$(git merge-base origin/$BASE_BRANCH HEAD)
{
  git diff --name-only "$BASE_REF"...HEAD      # committed PR diff
  git diff --name-only --cached                # staged local changes
  git diff --name-only                         # unstaged local changes
  git ls-files --others --exclude-standard     # untracked local files
} | sed '/^$/d' | sort -u
```

All changed files are relevant for product review -- no file-type filtering.

If no changed files at all:

```
No changes detected in this branch or local working tree.
Nothing to review.
```

**Action:** Stop.

### Step 4: Check for Previous Review

If `PRODUCT_REVIEW_OVERVIEW.md` exists in the project root:
- Parse previously addressed findings (file path, line number, issue description, action taken)
- Store for filtering in Step 7

Previously addressed findings have the format:
- **File:** `path/to/file.ts:123`
- **Issue/Finding:** [description]
- **Action taken:** [what was done]

### Step 5: Launch Product Reviewer Agent

Launch **kramme:product-reviewer** via the Task tool with:
- The resolved `BASE_BRANCH` from Step 3
- Project conventions extracted from `CLAUDE.md`/`AGENTS.md`
- All changed files (full list, no filtering)
- Committed PR diff: `git diff $(git merge-base origin/$BASE_BRANCH HEAD)...HEAD`
- Staged local diff: `git diff --cached`
- Unstaged local diff: `git diff`
- Untracked local files list: `git ls-files --others --exclude-standard` (agent should treat these as new files and review full file content)
- If `custom_threshold` was provided: instruct the agent to use this threshold instead of the default (e.g., "Only report findings with confidence >= {custom_threshold}")
- Explicit instruction: **"You are in PR mode. Focus on changes introduced by this diff. Evaluate: user-value alignment, flow completeness, missing states (loading, error, empty, edge), copy quality and defaults, permission/role behavior, and adjacent-flow regressions."**

### Step 6: Validate Relevance

After collecting findings from the product reviewer:
- Launch **kramme:pr-relevance-validator** with all findings and the resolved `BASE_BRANCH`
- Cross-reference each finding against the full review scope (committed PR diff + staged/unstaged/untracked local changes)
- Filter pre-existing issues and out-of-scope problems
- Return only findings caused by this combined scope

### Step 7: Filter Previously Addressed Findings

If `PRODUCT_REVIEW_OVERVIEW.md` was found in Step 4:
- Cross-reference validated findings against previously addressed findings
- **Only filter** if the finding is essentially the same issue:
  - Same file
  - Similar line number (within ~10 lines, accounting for code shifts)
  - Same underlying issue (semantic match on root cause)
- **Do NOT filter** (keep as active finding) if:
  - The issue description is substantively different (different root cause)
  - The severity escalated (was suggestion, now critical)
  - The finding identifies a problem with the previous fix
  - The previous action was "No action" or a deferral
- When uncertain, err on the side of keeping the finding active
- Add filtered findings to "Previously Addressed" section

### Step 8: Aggregate and Write Results

After validation and filtering, organize findings into severity tiers:
- **Critical Product Issues** (must fix before merge) -- only validated findings
- **Important Product Issues** (should fix) -- only validated findings
- **Product Suggestions** (nice to have) -- only validated findings
- **Open Questions** (need product owner input)
- **Filtered** (pre-existing or out-of-scope) -- shown separately
- **Previously Addressed** -- shown separately
- **Product Strengths** (what's well-done)

Write to `PRODUCT_REVIEW_OVERVIEW.md` in the project root using the report format from `assets/product-review-report-format.md`. Include all sections even if empty (with count of 0).

This file is a working artifact -- it should NOT be committed. It will be cleaned up by `/kramme:workflow-artifacts:cleanup`.

### Step 9: Provide Action Plan

If Critical or Important findings were found, suggest running `/kramme:pr:resolve-review --local` to address them.

Organize findings summary in the terminal output:

```
# Product Review Complete

## Relevance Filter
- X findings validated as in-scope
- X findings filtered (pre-existing or out-of-scope)
- X findings filtered (previously addressed)

## Results
- Critical: X
- Important: X
- Suggestions: X
- Open Questions: X

Full report: PRODUCT_REVIEW_OVERVIEW.md

To resolve findings, run: /kramme:pr:resolve-review --local
```

## Usage Examples

```
/kramme:pr:product-review
```

```
/kramme:pr:product-review --base develop
```

```
/kramme:pr:product-review --threshold 85
```
