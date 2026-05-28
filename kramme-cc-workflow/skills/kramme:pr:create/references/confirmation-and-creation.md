# Confirmation and Creation

Use this reference for `/kramme:pr:create` Steps 8–9 after the branch is prepared, commits are finalized, and the PR title/body have been generated.

`{base-branch}` is the value captured in Steps 2–3. `{feature-branch}` is the current branch. `{title}` and `{description}` come from Step 7 (the generator skill or its fallback). Substitute literal values when emitting commands and messages — these are agent-tracked, not shell variables.

## Step 8: Confirmation and Creation

### 8.1 Preview Summary

Show the user what will be created.

When `DRAFT_MODE=false`, use:

```
[PR] Ready to Create

Title: {title}
Branch: {feature-branch} -> {base-branch}
Status: Ready for review

Description Preview:
---
{first 300 characters of description}...
---
```

When `DRAFT_MODE=true`, use:

```
Draft [PR] Ready to Create

Title: {title}
Branch: {feature-branch} -> {base-branch}
Status: Draft

Description Preview:
---
{first 300 characters of description}...
---
```

The title follows conventional commit format (`<type>(<scope>): <description>`).

### 8.2 Confirm Creation

If `AUTO_MODE=true`, skip this confirmation and proceed directly to Step 8.3.

Otherwise use AskUserQuestion.

When `DRAFT_MODE=false`, use:

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

When `DRAFT_MODE=true`, use:

```yaml
header: "Confirm"
question: "Ready to create the Draft PR?"
options:
  - label: "Create Draft PR"
    description: "Push branch and create the Draft PR with the generated description"
  - label: "Edit description first"
    description: "Review and modify the description before creating"
  - label: "Abort"
    description: "Cancel and keep local changes without creating PR"
multiSelect: false
```

If **"Abort"** selected:

Execute Step 10 in `references/state-and-rollback.md` (rollback), then stop. Do not push.

If **"Edit description first"** selected, run the edit loop below before re-prompting:

1. Show the full `{description}` (not just the preview).
2. Ask via `AskUserQuestion` how to edit:

   ```yaml
   header: "Edit description"
   question: "How should the description be edited?"
   options:
     - label: "Paste a new description"
       description: "Replace the description with text you paste in the next turn"
     - label: "Describe the changes"
       description: "Tell me what to change and I'll revise the description"
     - label: "Edit title instead"
       description: "Replace only the PR title"
     - label: "Cancel edit"
       description: "Keep the generated description and go back to confirmation"
   multiSelect: false
   ```

3. Apply the chosen edit (capture new `{title}` and/or `{description}`), then return to Step 8.1 to re-preview and re-confirm. Loop until the user selects **"Create PR"** / **"Create Draft PR"** or **"Abort"**.

### 8.3 Push Branch

```bash
git push -u origin {feature-branch}
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

Emit the command below. Include `--draft` on the first line only when `DRAFT_MODE=true`; otherwise omit it entirely (do not emit an empty flag). The whole `gh pr create … EOF` block must run in a single Bash invocation so the heredoc resolves before the shell exits.

```bash
gh pr create \
  --base {base-branch} \
  --assignee @me \
  --title "{title}" \
  --body "$(cat <<'EOF'
{description}
EOF
)"
```

When `DRAFT_MODE=true`, add `--draft \` as the second line.

### 8.5 Handle PR Creation Failure

If `gh pr create` fails (but the push in Step 8.3 succeeded):

```
Warning: Failed to create [PR] automatically.

Error: {error message}

Manual creation:
  1. Your branch is pushed: origin/{feature-branch}
  2. Create manually at: https://github.com/{org}/{repo}/pull/new/{feature-branch}
     (base branch: {base-branch})
  3. Copy this description:

---
{description}
---
```

If `DRAFT_MODE=true`, append a final line: `Remember to mark it as Draft before creating.`

Recover the `{org}/{repo}` portion from `git remote get-url origin` (handle both SSH and HTTPS forms). If parsing fails, drop the URL line — the user can still create the PR via the GitHub UI.

## Step 9: Success Output

On successful creation, emit the message below. When `DRAFT_MODE=true`, substitute `Draft [PR] created successfully!` for the header and `Draft` for the status line, and add `Mark as ready for review when complete` as a fourth next-step.

```
[PR] created successfully!

URL: {pr-url}
Branch: {feature-branch} -> {base-branch}
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
