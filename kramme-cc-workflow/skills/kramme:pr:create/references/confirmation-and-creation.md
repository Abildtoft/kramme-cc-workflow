# Confirmation and Creation

Use this reference for `/kramme:pr:create` Steps 8–9 after the branch is prepared, commits are finalized, and the PR title/body have been generated.

`{base-branch}` is the value captured in Steps 2–3. `{feature-branch}` is the current branch. `{title}` and `{description}` come from Step 7 (the generator skill or its fallback). `{linear-issue-id}` may be captured during branch handling. Substitute literal values when emitting commands and messages — these are agent-tracked, not shell variables.

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

After each description edit, if `{linear-issue-id}` is present, keep the default Linear closing line as `Closes {linear-issue-id}`. Replace `Fixes {linear-issue-id}` or `Resolves {linear-issue-id}` with `Closes {linear-issue-id}` unless the user explicitly asked for that alternative keyword in the edit request. If the edited description links the same issue with a non-closing keyword (`Related to`, `Refs`, or `References`), preserve that link and do not add a separate closing line.

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

Create the PR body through a temporary file. Do not pass generated Markdown through shell interpolation or a heredoc; body content can legally contain shell metacharacters or a literal `EOF` line.

1. Create and capture temp file paths:

   ```bash
   PR_TITLE_FILE=$(mktemp "${TMPDIR:-/tmp}/pr-title.XXXXXX")
   PR_BODY_FILE=$(mktemp "${TMPDIR:-/tmp}/pr-body.XXXXXX")
   echo "$PR_TITLE_FILE"
   echo "$PR_BODY_FILE"
   ```

2. Write `{title}` to the captured title path and `{description}` to the captured body path using the runtime's file-write capability. Do not use `cat <<EOF`, `printf "{description}"`, or any other shell-parsed form for generated Markdown.

3. Emit the command below. Include `--draft` on the first line only when `DRAFT_MODE=true`; otherwise omit it entirely (do not emit an empty flag). Substitute the captured temp file paths for `{pr-title-file}` and `{pr-body-file}` and remove both files after the command finishes.

```bash
gh pr create \
  --base {base-branch} \
  --assignee @me \
  --title "$(cat "{pr-title-file}")" \
  --body-file "{pr-body-file}"
PR_CREATE_STATUS=$?
rm -f "{pr-title-file}" "{pr-body-file}"
exit "$PR_CREATE_STATUS"
```

When `DRAFT_MODE=true`, add `--draft \` as the second line.

### 8.5 Handle PR Creation Failure

If `gh pr create` fails (but the push in Step 8.3 succeeded):

Before showing manual creation instructions, execute Step 9.0 from `references/state-and-rollback.md` so any excluded uncommitted changes are restored locally or explicitly reported for manual conflict resolution. Do not run Step 10 here: the branch was already pushed, and the failure output should preserve that manual-creation path.

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
Uncommitted work: {none | committed and included before history rewrite | excluded from PR and restored locally | excluded from PR but restore needs manual conflict resolution}

Commits included:
  - {commit 1 summary}
  - {commit 2 summary}
  - ...

Next steps:
  1. Review the PR description for accuracy
  2. Add screenshots or videos if applicable
  3. Run tests and ensure CI passes
```
