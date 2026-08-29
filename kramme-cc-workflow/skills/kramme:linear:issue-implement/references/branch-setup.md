# Branch Setup

Use this during Step 2. Complete every required branch action before issue parsing or planning.

## Extract Branch Name from Linear

The Linear MCP `get_issue` response includes a `branchName` field - this is Linear's recommended branch name.

**Priority:**

1. **FIRST**: Use `branchName` from Linear if present and non-empty.
2. **FALLBACK ONLY**: If `branchName` is empty or missing, generate one using pattern: `{user-initials}/{ISSUE_ID}-{sanitized-title}`.

**If generating fallback:**

- Ask user for their initials if not known. If `AUTO_MODE=true` and initials are not known, use `auto` as the prefix instead of asking.
- Sanitize title: lowercase, replace spaces with hyphens, max 50 chars for description.

## Check Current Git State

```bash
git status --porcelain
git branch --show-current
```

If `RESUME_CURRENT_BRANCH=true`, use the parent-owned resume handoff instead of the ordinary dirty-worktree choice below:

1. Require its issue identifier and exact branch to equal the freshly fetched Linear issue and its `branchName`.
2. Require the current branch to equal that exact branch, `HEAD` to descend from the captured base, the remote branch still to be absent, and no merge, rebase, cherry-pick, revert, bisect, or unmerged path to be in progress.
3. Require current `HEAD`, committed paths, and dirty paths to equal the captured entry handoff before continuing. Do not checkout, create, reset, stash, discard, stage, or commit in this branch-setup phase.
4. Preserve the changes for the reference mapping, technical-plan reconciliation, implementation, and verification steps. A mismatch is a hard blocker; never fall through to the choices below.

**If uncommitted changes exist:**

If `AUTO_MODE=true`, stop with `MISSING REQUIREMENT: uncommitted changes exist; rerun without --auto to choose stash, commit, discard, or abort`.

Otherwise use AskUserQuestion:

```yaml
header: "Uncommitted Changes"
question: "You have uncommitted changes. How should I handle them?"
options:
  - label: "Stash changes"
    description: "Save changes to stash, can be restored later"
  - label: "Commit changes"
    description: "Commit current changes before switching branches"
  - label: "Discard changes"
    description: "Warning: This will lose your uncommitted work"
  - label: "Abort"
    description: "Cancel and let me handle it manually"
```

## Create and Switch to Branch

**If branch doesn't exist locally or remotely:**

```bash
# Determine base branch
BASE=$(git symbolic-ref refs/remotes/origin/HEAD 2> /dev/null | sed 's|refs/remotes/origin/||' || true)
[ -n "$BASE" ] || BASE="main"

# Fetch latest
git fetch origin $BASE

# Create branch from latest base
git checkout -b "{branchName}" "origin/$BASE"
```

**If branch exists locally:**

```bash
git checkout "{branchName}"
```

**If branch exists only on remote:**

```bash
git checkout -b "{branchName}" "origin/{branchName}"
```

## Verify Branch Creation

Always run:

```bash
git branch --show-current
```

The output must match the target `branchName`. If not, report to the user and abort.

## Confirm Branch to User

Display confirmation:

```text
Branch: {branchName}
  Source: {Linear's suggested name | Generated from issue}

Proceeding with issue analysis...
```

Only after this confirmation may you proceed to the next step.
