# Confirmation and Creation

Use this reference for `/kramme:pr:create` Steps 8-9 after the branch is prepared, commits are finalized, and the PR title/body have been generated.

## Step 8: Confirmation and Creation

### 8.1 Preview Summary

Show the user what will be created. When `DRAFT_MODE=true`, use `Draft [PR] Ready to Create` / `Status: Draft`; otherwise use `[PR] Ready to Create` / `Status: Ready for review`.

```
[PR] Ready to Create

Title: [Generated conventional commit title from pr-description-generator]
Branch: {feature-branch} -> main
Status: Ready for review

Description Preview:
---
{first 300 characters of description}...
---
```

The title comes from the pr-description-generator skill output and follows conventional commit format (`<type>(<scope>): <description>`).

### 8.2 Confirm Creation

If `AUTO_MODE=true`, skip this confirmation and proceed directly to Step 8.3.

Otherwise use AskUserQuestion. When `DRAFT_MODE=true`, substitute "Draft PR" for "PR" in the question and the first option's label/description.

```yaml
header: "Confirm"
question: "Ready to create the PR?"
options:
  - label: "Create PR"
    description: "Push branch and create the PR with the generated description"
  - label: "Edit description first"
    description: "Review and modify the description before creating"
  - label: "Abort"
    description: "Cancel and keep local changes without creating PR"
multiSelect: false
```

If "Abort" selected:

```
Operation cancelled.

Your changes remain local:
  - Branch: {current-branch}
  - Commits: {number} commits ready
  - Status: Not pushed, no PR created

You can run /kramme:pr:create again when ready.
```

Action: Abort. No rollback is needed because commits are preserved.

If "Edit description first" selected, allow the user to provide edits, then continue.

### 8.3 Push Branch

```bash
git push -u origin $(git branch --show-current)
```

If push fails:

```
Warning: Failed to push branch to remote.

Possible causes:
  - No push access to repository
  - Branch name conflicts with existing remote branch
  - Network connectivity issues

Manual push command:
  git push -u origin {branch-name}

If branch exists remotely:
  git push -u origin {branch-name} --force-with-lease

The generated description is saved. You can create the PR manually.
```

Action: Show the full description for copy/paste, then abort.

### 8.4 Create PR

Include the `--draft` flag only when `DRAFT_MODE=true`. The snippet below builds a `DRAFT_FLAG` variable that is empty by default.

```bash
DRAFT_FLAG=""
[ "$DRAFT_MODE" = "true" ] && DRAFT_FLAG="--draft"

gh pr create $DRAFT_FLAG \
  --assignee @me \
  --title "{title}" \
  --body "$(cat <<'EOF'
{generated description}
EOF
)"
```

### 8.5 Handle PR Creation Failure

If creation fails:

```
Warning: Failed to create [PR] automatically.

Error: {error message}

Manual creation:
  1. Your branch is pushed: origin/{branch-name}
  2. Create manually at: https://github.com/{org}/{repo}/pull/new/{branch}
  3. Copy this description:

---
{full generated description}
---
```

If `DRAFT_MODE=true`, append a final line: `Remember to mark it as Draft before creating.`

## Step 9: Success Output

On successful creation, use this message. When `DRAFT_MODE=true`, use `Draft [PR] created successfully!` / `Status: Draft` and keep the final "Mark as ready for review when complete" next-step. Otherwise use:

```
[PR] created successfully!

URL: {pr-url}
Branch: {branch} -> main
Status: Ready for review

Commits included:
  - {commit 1 summary}
  - {commit 2 summary}
  - ...

Next steps:
  1. Review the PR description for accuracy
  2. Add screenshots or videos if applicable
  3. Run tests and ensure CI passes
```
