---
name: kramme:pr:copy-review
description: Review PR and local changes for unnecessary, redundant, or duplicative UI text — labels, descriptions, placeholders, tooltips, and instructions that the UI already communicates through its structure. Supports inline report output with --inline.
argument-hint: "[--base <branch>] [--threshold 0-100] [--inline]"
disable-model-invocation: true
user-invocable: true
---

# Copy Review for Pull Request and Local Changes

Review branch changes and local work for unnecessary UI text. Finds labels, descriptions, placeholders, tooltips, and instructions that duplicate what the UI already communicates through structure, icons, or interaction patterns.

**Arguments:** "$ARGUMENTS"

## Review Workflow

### Step 1: Parse Arguments

1. If `--base <branch>` flag provided, store as explicit base branch override
2. If `--threshold N` flag provided, store as `custom_threshold` (0-100). Only findings with confidence >= N will be reported. Default: 75
3. If `--inline` flag provided, set `INLINE_MODE=true`
4. If neither flag is present, use defaults

### Step 2: Load Project Review Conventions

Before launching agents:

1. Read `CLAUDE.md` from repo root.
2. Discover `AGENTS.md` files in repo (`find . -name AGENTS.md`), then read relevant ones.
3. Extract UI stack, component library, design system, target audience, and content strategy conventions.
4. Pass these conventions to the reviewer agent and instruct it to prioritize documented conventions over generic best practices.

### Step 3: Resolve Base Branch and Identify UI-Relevant Changed Files

Determine the correct base branch using a 3-tier strategy:

**Tier 1: Explicit override**
If `--base <branch>` was provided in Step 1, use that value directly as `BASE_BRANCH`. Skip Tier 2 and 3.

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
  echo "Error: Could not determine base branch. Re-run with --base <branch>." >&2
  exit 1
fi
if ! git check-ref-format --branch "$BASE_BRANCH" >/dev/null 2>&1; then
  echo "Error: Base branch '$BASE_BRANCH' is not a valid branch name. Re-run with --base <branch>." >&2
  exit 1
fi
if ! git fetch origin "refs/heads/${BASE_BRANCH}:refs/remotes/origin/${BASE_BRANCH}" 2>/dev/null; then
  echo "Error: Failed to fetch origin/$BASE_BRANCH. Check remote access and re-run with --base <branch>." >&2
  exit 1
fi
if ! git rev-parse --verify --quiet "origin/$BASE_BRANCH" >/dev/null; then
  echo "Error: Base branch 'origin/$BASE_BRANCH' not found. Re-run with --base <branch>." >&2
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

Filter for UI-relevant files only:
- **Components**: `*.tsx`, `*.jsx`, `*.vue`, `*.svelte`, `*.component.ts`, `*.component.html`
- **Templates**: `*.html`, `*.hbs`, `*.ejs`, `*.pug`
- **Views/Pages**: Files in `pages/`, `views/`, `screens/`, `routes/`, `app/` directories
- **i18n/translations**: `*.json` files in `locales/`, `i18n/`, `translations/` directories

If no UI-relevant files found:

```
No UI-relevant files detected in this PR or local working tree.

Changed files: {list file types}

No UI copy to review.
```

**Action:** Stop.

### Step 4: Check for Previous Review

If `COPY_REVIEW_OVERVIEW.md` exists in the project root:
- Parse previously addressed findings (file path, line number, issue description, action taken)
- Store for filtering in Step 7

### Step 5: Launch Copy Reviewer Agent

Launch **kramme:copy-reviewer** via the Task tool with:
- The resolved `BASE_BRANCH` from Step 3
- Project conventions extracted from `CLAUDE.md`/`AGENTS.md`
- The list of UI-relevant changed files
- Committed PR diff: `git diff $(git merge-base origin/$BASE_BRANCH HEAD)...HEAD`
- Staged local diff: `git diff --cached`
- Unstaged local diff: `git diff`
- Untracked local files list: `git ls-files --others --exclude-standard` (agent should treat these as new files and review full file content)
- If `custom_threshold` was provided: instruct the agent to use this threshold instead of the default (e.g., "Only report findings with confidence >= {custom_threshold}")
- Explicit instruction: **"You are in PR mode. Focus on text redundancy introduced by this diff. For each text element in changed code, evaluate whether the UI already communicates the same information through its structure, icons, or interaction patterns."**

### Step 6: Validate Relevance

After collecting findings from the copy reviewer:
- Launch **kramme:pr-relevance-validator** with all findings and the resolved `BASE_BRANCH`
- Cross-reference each finding against the full review scope (committed PR diff + staged/unstaged/untracked local changes)
- Filter pre-existing issues and out-of-scope problems
- Return only findings caused by this combined scope

### Step 7: Filter Previously Addressed Findings

If `COPY_REVIEW_OVERVIEW.md` was found in Step 4:
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
- **Critical Copy Issues** (must fix before merge) -- only validated findings
- **Important Copy Issues** (should fix) -- only validated findings
- **Copy Suggestions** (nice to have) -- only validated findings
- **Filtered** (pre-existing or out-of-scope) -- shown separately
- **Previously Addressed** -- shown separately
- **Copy Strengths** (what's well-done)

If `INLINE_MODE=true`:
- Reply with the full report inline using the report format from `assets/copy-review-report-format.md`
- Include all sections even if empty (with count of 0)
- Do **not** create or update `COPY_REVIEW_OVERVIEW.md`

Otherwise:
- Write to `COPY_REVIEW_OVERVIEW.md` in the project root using the report format from `assets/copy-review-report-format.md`
- Include all sections even if empty (with count of 0)
- Treat the file as a working artifact that should **not** be committed and can be cleaned up by `/kramme:workflow-artifacts:cleanup`

### Step 9: Provide Action Plan

If Critical or Important findings were found:
- When `INLINE_MODE=false`, suggest running `/kramme:pr:resolve-review`
- When `INLINE_MODE=true`, suggest passing the inline report content to `/kramme:pr:resolve-review`

Organize findings summary in the terminal output:

```
# Copy Review Complete

## Relevance Filter
- X findings validated as in-scope
- X findings filtered (pre-existing or out-of-scope)
- X findings filtered (previously addressed)

## Results
- Critical: X
- Important: X
- Suggestions: X

Report output: {inline reply | COPY_REVIEW_OVERVIEW.md}

To resolve findings: `/kramme:pr:resolve-review`
```

## Usage Examples

```
/kramme:pr:copy-review
```

```
/kramme:pr:copy-review --base develop
```

```
/kramme:pr:copy-review --threshold 85
```

```
/kramme:pr:copy-review --inline
```
