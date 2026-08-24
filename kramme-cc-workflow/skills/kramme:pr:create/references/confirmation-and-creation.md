# Confirmation and Creation

Use this reference for `/kramme:pr:create` Steps 8–9 after the branch is prepared, commits are finalized, and the PR title/body have been generated.

`{base-branch}` is the value captured in Steps 2–3. `{feature-branch}` is the current branch. In the fresh-remote path, `{rollback-origin-ref}` is the remote ref that Step 5 proved absent. In exact-tip recovery, `{entry-commit}` and `{observed-origin-oid}` are the identical immutable local and remote tips captured before description generation. `{title}` and `{description}` are validated Step 7 generator output or validated user-supplied replacements. `{linear-issue-id}` may be captured during branch handling. Substitute literal values when emitting commands and messages — these are agent-tracked, not shell variables.

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

When `REMOTE_RECOVERY_MODE=true`, add `Publication: Existing remote branch; no history rewrite or push` below the status line. Otherwise add `Publication: Fresh remote branch with an absence-leased push`.

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

When `REMOTE_RECOVERY_MODE=false`, execute Step 10 in `references/state-and-rollback.md` (rollback), then stop. When `REMOTE_RECOVERY_MODE=true`, stop without rollback because no mutation occurred. Do not push.

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

3. Apply the chosen edit (capture new `{title}` and/or `{description}`), rerun the Step 7.2 title/body validation, then return to Step 8.1 to re-preview and re-confirm. Do not preview or publish invalid edited content. Loop until the user selects **"Create PR"** / **"Create Draft PR"** or **"Abort"**.

After each description edit, if `{linear-issue-id}` is present, keep the default Linear closing line as `Closes {linear-issue-id}`. Replace `Fixes {linear-issue-id}` or `Resolves {linear-issue-id}` with `Closes {linear-issue-id}` unless the user explicitly asked for that alternative keyword in the edit request. If the edited description links the same issue with a non-closing keyword (`Related to`, `Refs`, or `References`), preserve that link and do not add a separate closing line.

### 8.3 Revalidate and Publish the Branch

Before any publication step, validate `{feature-branch}` before using it as a git ref. It must be the current branch captured from `git branch --show-current`, pass `git check-ref-format --branch`, contain no shell metacharacters or whitespace, and must not begin with `-`. Stop if validation fails.

Immediately before any push, repeat the fail-closed open-Pull-Request check. Disable GitHub CLI prompting and run the query with the shell tool's bounded timeout:

```bash
env GH_PROMPT_DISABLED=1 gh pr list --head "{feature-branch}" --state open --limit 100 --json number,url,state,headRefName
```

Require this command to succeed. Continue only when the successful response is an empty list. If an open Pull Request appeared after Step 3.5, execute Step 10 from `state-and-rollback.md` when `REMOTE_RECOVERY_MODE=false`, or stop without rollback when `REMOTE_RECOVERY_MODE=true`. In either case, report the Pull Request URL and stop without pushing. A matching remote head does not prove that this invocation owns the Pull Request, and neither `AUTO_MODE` nor `AUTHORIZE_HISTORY_REWRITE` may adopt or rewrite it.

#### Existing exact-tip recovery

When `REMOTE_RECOVERY_MODE=true`, revalidate every no-mutation invariant immediately before Step 8.4:

```bash
"{pr-create-skill-dir}/scripts/verify-clean-worktree.sh"
git branch --show-current
git rev-parse HEAD
NONINTERACTIVE_GIT_SSH_COMMAND="${GIT_SSH_COMMAND:-${GIT_SSH:-ssh}} -oBatchMode=yes"
env GIT_TERMINAL_PROMPT=0 GCM_INTERACTIVE=Never GIT_SSH_COMMAND="$NONINTERACTIVE_GIT_SSH_COMMAND" \
  git ls-remote --heads origin "refs/heads/{feature-branch}"
```

Require the clean-worktree helper to succeed before running the remaining commands, and require the current branch to remain `{feature-branch}`. Require `HEAD` to remain exactly `{entry-commit}`. Parse the remote query with the same strict one-line boundary as Step 3. Require the authoritative remote OID to remain exactly `{observed-origin-oid}`. Also require `{entry-commit}` and `{observed-origin-oid}` to remain equal as captured. A clean-tree inspection failure, malformed output, missing ref, dirty tree, checkout change, local-tip change, query failure, or remote-tip change is a hard blocker. Do not run `git push` in this mode; continue directly to Step 8.4 only after every invariant passes. Because this path does not mutate the branch, a concurrent Pull Request creation can only cause `gh pr create` to fail or return an existing-PR error—it cannot cause this invocation to rewrite that Pull Request's commits.

#### Fresh remote publication

The remainder of Step 8.3 applies only when `REMOTE_RECOVERY_MODE=false`.

Step 5 proved that `{rollback-origin-ref}` was absent. Use the quoted, explicit absence-leased push below and set upstream tracking. Disable Git credential prompting for this network mutation; authentication failure is a hard blocker, never a reason to wait for terminal input. Run the push with the shell tool's bounded timeout. If any actor creates the remote branch after Step 5, the lease fails. If this push succeeds, no Pull Request could have existed for that branch at the moment this workflow created it, so a later Pull Request cannot have been rewritten by this invocation:

```bash
NONINTERACTIVE_GIT_SSH_COMMAND="${GIT_SSH_COMMAND:-${GIT_SSH:-ssh}} -oBatchMode=yes"
env GIT_TERMINAL_PROMPT=0 GCM_INTERACTIVE=Never GIT_SSH_COMMAND="$NONINTERACTIVE_GIT_SSH_COMMAND" \
  git push --force-with-lease="{rollback-origin-ref}:" -u origin "HEAD:{rollback-origin-ref}"
```

Do not use plain `--force`, an OID lease for a pre-existing remote ref, an implicit destination, or a tracking ref read after the rewrite as the lease baseline. `kramme:git:recreate-commits --no-push` left the remote absent; this is the workflow's sole remote update before Pull Request creation.

If the push command exits non-zero, its remote outcome is ambiguous. Execute Step 10 from `state-and-rollback.md`; that rollback restores local state and re-queries `{rollback-origin-ref}` without modifying it. Then show the full generated description directly in the conversation for copy/paste and use the rollback's observed remote classification:

```
Warning: Failed to push branch to remote.

Local state: {restored to the invocation entry checkout | restoration needs manual recovery}
Remote state: {still absent — it is safe to rerun the workflow | now exists at observed OID — the push may have landed; do not rewrite or delete it automatically | unverified — inspect origin before retrying}

PR description for copy/paste:
---
{description}
---
```

When the remote now exists, provide the manual Pull Request URL when it can be derived and tell the user to verify that remote tip before creating the Pull Request. Never claim the description was saved to disk, never suggest blindly repeating the push, and never continue to `gh pr create` after a non-zero push status.

### 8.4 Create PR

Create the PR body through a temporary file. Do not pass generated Markdown through shell interpolation or a heredoc; body content can legally contain shell metacharacters or a literal `EOF` line.

1. Capture `git rev-parse --verify HEAD` as `{publication-head}` immediately before allocating the temporary files. Require a full 40-character lowercase commit OID. In exact-tip recovery it must still equal `{entry-commit}`; in fresh publication it is the rewritten commit that the successful Step 8.3 push published.

2. Create and capture temp file paths. Use the fixed `/tmp` templates so every captured path is shell-safe. If the second allocation fails, remove the first file before stopping:

   ```bash
   if ! PR_TITLE_FILE=$(mktemp "/tmp/kramme-pr-title.XXXXXX"); then
     exit 1
   fi
   if ! PR_BODY_FILE=$(mktemp "/tmp/kramme-pr-body.XXXXXX"); then
     rm -f -- "$PR_TITLE_FILE"
     exit 1
   fi
   echo "$PR_TITLE_FILE"
   echo "$PR_BODY_FILE"
   ```

3. Require each captured path to match `/tmp/kramme-pr-(title|body).[A-Za-z0-9]+`, then write `{title}` and `{description}` to the corresponding path using the runtime's file-write capability. Do not use `cat <<EOF`, `printf "{description}"`, or any other shell-parsed form for generated Markdown.

4. Emit the command below with the shell tool's bounded timeout. `GH_PROMPT_DISABLED=1` makes authentication or other interaction requirements fail closed. Include `--draft` on the first line only when `DRAFT_MODE=true`; otherwise omit it entirely (do not emit an empty flag). Substitute the validated captured paths for `{pr-title-file}` and `{pr-body-file}`. The trap removes both files on success, failure, or interruption.

```bash
PR_TITLE_FILE="{pr-title-file}"
PR_BODY_FILE="{pr-body-file}"
cleanup_pr_files() {
  rm -f -- "$PR_TITLE_FILE" "$PR_BODY_FILE"
}
trap cleanup_pr_files EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM
env GH_PROMPT_DISABLED=1 gh pr create \
  --base "{base-branch}" \
  --head "{feature-branch}" \
  --assignee @me \
  --title "$(cat "$PR_TITLE_FILE")" \
  --body-file "$PR_BODY_FILE"
```

When `DRAFT_MODE=true`, add `--draft \` as the second line.

Always pass the validated explicit `--head` value. This prevents `gh pr create` from offering to push or fork when exact-tip recovery is using a remote branch without local upstream configuration; the skill's own fresh-branch publication step remains the only allowed push.

5. After `gh pr create` succeeds, query the created Pull Request through the same GitHub repository context with the shell tool's bounded timeout:

   ```bash
   env GH_PROMPT_DISABLED=1 gh pr list \
     --head "{feature-branch}" \
     --base "{base-branch}" \
     --state open \
     --limit 2 \
     --json number,url,state,baseRefName,headRefName,headRefOid
   ```

   Require this query to succeed and return exactly one record. Require `state` to be `OPEN`, `baseRefName` to equal `{base-branch}`, `headRefName` to equal `{feature-branch}`, and `headRefOid` to equal `{publication-head}` exactly. Capture its `url` as `{pr-url}` for Step 9. A missing, malformed, duplicate, or mismatched result means GitHub did not prove that the created Pull Request contains the commit this invocation inspected. Report the creation result and observed metadata, but do not run Step 9 or claim success; do not roll back, close, or delete the Pull Request or branch automatically.

### 8.5 Handle PR Creation Failure

If `gh pr create` fails after the fresh-remote push or while reusing the verified exact-tip remote branch:

Before showing manual creation instructions, execute Step 9.0 from `references/state-and-rollback.md` in the fresh-remote path so any excluded uncommitted changes are restored locally or explicitly reported for manual conflict resolution. Exact-tip recovery skips Step 9.0 because it required a clean tree. Do not run Step 10 here: the branch already exists remotely, and the failure output should preserve that manual-creation path.

```
Warning: Failed to create [PR] automatically.

Error: {error message}

Manual creation:
  1. Your branch is available unchanged at: origin/{feature-branch}
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
