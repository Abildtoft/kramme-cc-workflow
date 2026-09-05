# Confirmation and Creation

Use this reference for `/kramme:pr:create` Steps 8–9 after the branch is prepared, commits are finalized, and the PR title/body have been generated.

`{base-branch}` is the value captured in Steps 2–3. `{feature-branch}` is the current branch. In the fresh-remote path, `{rollback-origin-ref}` is the remote ref that Step 5 proved absent. In exact-tip recovery, `{entry-commit}` and `{observed-origin-oid}` are identical. In clean remote fast-forward mode, `{publication-commit}` equals `{entry-commit}`. In remote-append mode, `{publication-commit}` is the rewritten local tip captured after Step 6, while `{observed-origin-oid}` remains the immutable published-prefix boundary. Both publishing existing-remote modes use the endpoint encoded by `{origin-push-url-assignment}`, the byte-exact shell-quoted assignment returned by the helper for the endpoint that reported the observed OID. All are immutable values captured before description generation. `{title}` and `{description}` are validated Step 7 generator output or validated user-supplied replacements. `{linear-issue-id}` may be captured during branch handling. `{demo-evidence-manifest}`, `DEMO_ATTACHMENT_COUNT`, and `{demo-evidence-status}` come from Step 7.4 and never enter the PR body as local paths. Substitute literal validated values when emitting commands, but insert `{origin-push-url-assignment}` only as its own assignment line and pass `"$ORIGIN_PUSH_URL"` to Git; never insert the decoded URL into shell source.

## Step 8: Confirmation and Creation

### 8.1 Preview Summary

Show the user what will be created.

When `DRAFT_MODE=false`, use:

```
[PR] Ready to Create

Title: {title}
Branch: {feature-branch} -> {base-branch}
Status: Ready for review
Demo evidence: {demo-evidence-status}

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
Demo evidence: {demo-evidence-status}

Description Preview:
---
{first 300 characters of description}...
---
```

The title follows conventional commit format (`<type>(<scope>): <description>`).

Add the line matching the one active mode below the status line:

- `REMOTE_RECOVERY_MODE=true`: `Publication: Existing remote branch; no history rewrite or push`
- `REMOTE_FAST_FORWARD_MODE=true`: `Publication: Existing remote branch; preserve commits with an OID-leased fast-forward`
- `REMOTE_APPEND_MODE=true`: `Publication: Existing remote branch; append local work with an OID lease`
- `FRESH_REMOTE_MODE=true`: `Publication: Fresh remote branch with an absence-leased push`

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

When `FRESH_REMOTE_MODE=true`, execute Step 10 in `references/state-and-rollback.md` (rollback), then stop. In a clean existing-remote mode, stop without rollback because no mutation occurred. Remote append is auto-only and cannot reach this confirmation. Do not push.

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

When `DEMO_ATTACHMENT_COUNT` is greater than zero, never place `{demo-evidence-manifest}`, an artifact filename, or any local filesystem path in the edited body. `gh pr create --attach` appends only successfully uploaded evidence inline at the end of the body.

### 8.3 Revalidate and Publish the Branch

Before any publication step, validate `{feature-branch}` before using it as a git ref. It must be the current branch captured from `git branch --show-current`, pass `git check-ref-format --branch`, contain no shell metacharacters or whitespace, and must not begin with `-`. Stop if validation fails.

Immediately before publication, re-resolve the local and server-side stack boundary:

```bash
STACK_REVALIDATION_FAILED=false
LATEST_STACK_RESOLVED=$("${CLAUDE_PLUGIN_ROOT}/scripts/resolve-stack-membership.sh") || {
  echo "Stack membership could not be revalidated; stop before publication." >&2
  STACK_REVALIDATION_FAILED=true
}
if [ "$STACK_REVALIDATION_FAILED" = false ] && ! (
  eval "$LATEST_STACK_RESOLVED"
  [ "$STACK_MEMBERSHIP" = none ]
); then
  echo "The branch joined a local or server-side stack after initial validation; stop before publication." >&2
  STACK_REVALIDATION_FAILED=true
fi
```

If `STACK_REVALIDATION_FAILED=true`, treat the unresolved or non-`none` membership as authorization-invalidating state drift. When `FRESH_REMOTE_MODE=true` or `REMOTE_APPEND_MODE=true`, execute Step 10 before stopping so the local rewrite and preserved user state are restored; in a clean existing-remote mode, stop without rollback because this workflow did not rewrite the branch. Do not publish or create a default-base Pull Request from stale unstacked authorization.

Immediately before any push, repeat the fail-closed open-Pull-Request check. Disable GitHub CLI prompting and run the query with the shell tool's bounded timeout:

```bash
env GH_PROMPT_DISABLED=1 gh pr list --head "{feature-branch}" --state open --limit 100 --json number,url,state,headRefName
```

Require this command to succeed. Continue only when the successful response is an empty list. If an open Pull Request appeared after Step 3.5, execute Step 10 from `state-and-rollback.md` when `FRESH_REMOTE_MODE=true` or `REMOTE_APPEND_MODE=true`; otherwise stop without rollback. In every mode, report the Pull Request URL and stop without pushing. A matching remote head does not prove that this invocation owns the Pull Request, and neither `AUTO_MODE` nor `AUTHORIZE_HISTORY_REWRITE` may adopt or rewrite it.

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

#### Existing remote OID-leased publication

When `REMOTE_FAST_FORWARD_MODE=true` or `REMOTE_APPEND_MODE=true`, revalidate every preservation invariant immediately before pushing:

```bash
{origin-push-url-assignment}
"{pr-create-skill-dir}/scripts/verify-clean-worktree.sh"
git branch --show-current
git rev-parse HEAD
NONINTERACTIVE_GIT_SSH_COMMAND="${GIT_SSH_COMMAND:-${GIT_SSH:-ssh}} -oBatchMode=yes"
env GIT_TERMINAL_PROMPT=0 GCM_INTERACTIVE=Never GIT_SSH_COMMAND="$NONINTERACTIVE_GIT_SSH_COMMAND" \
  git ls-remote --heads -- "$ORIGIN_PUSH_URL" "refs/heads/{feature-branch}"
git merge-base --is-ancestor "{observed-origin-oid}" "{publication-commit}"
```

Require the clean-worktree helper to succeed, the current branch to remain `{feature-branch}`, and `HEAD` to remain exactly `{publication-commit}`. Parse the frozen-endpoint query with the same strict one-line boundary as Step 3 and require its OID to remain exactly `{observed-origin-oid}`. Require `{observed-origin-oid}` to differ from `{publication-commit}` and the ancestry check to succeed, proving the observed remote is still a strict ancestor of the immutable local publication tip. In clean fast-forward mode, also require `{publication-commit}` to equal `{entry-commit}`. In remote-append mode, require it to equal the post-Step-6 OID and leave the local recovery backup intact. A malformed or changed remote response, ancestry failure, or other remote-only error is a hard blocker; when append's local branch, tip, and clean-tree invariants still hold, execute Step 10 before stopping because no push has run. If the worktree is dirty or the checkout/local tip changed, do not roll back: preserve the current local state and recovery refs for manual inspection. Clean fast-forward mode always stops without rollback.

Only after every invariant passes, publish the captured local commit with an explicit destination and an exact OID lease:

```bash
{origin-push-url-assignment}
NONINTERACTIVE_GIT_SSH_COMMAND="${GIT_SSH_COMMAND:-${GIT_SSH:-ssh}} -oBatchMode=yes"
FINAL_STACK_RESOLVED=$("${CLAUDE_PLUGIN_ROOT}/scripts/resolve-stack-membership.sh") || {
  echo "Stack membership could not be revalidated at the fast-forward push boundary; stop before publication." >&2
  exit 1
}
if ! (
  eval "$FINAL_STACK_RESOLVED"
  [ "$STACK_MEMBERSHIP" = none ]
); then
  echo "The branch joined a local or server-side stack before the fast-forward push; stop before publication." >&2
  exit 1
fi
env GIT_TERMINAL_PROMPT=0 GCM_INTERACTIVE=Never GIT_SSH_COMMAND="$NONINTERACTIVE_GIT_SSH_COMMAND" \
  git push --no-follow-tags \
  --force-with-lease="refs/heads/{feature-branch}:{observed-origin-oid}" \
  -- "$ORIGIN_PUSH_URL" "{publication-commit}:refs/heads/{feature-branch}"
```

If the final stack guard fails before this push, execute Step 10 when `REMOTE_APPEND_MODE=true`; clean fast-forward mode stops without rollback. Do not classify a guard failure as an ambiguous push outcome because no push ran.

The immutable source prevents a concurrent local checkout, reset, or commit from changing what is published after revalidation. The explicit frozen endpoint, single refspec, and `--no-follow-tags` prevent configured push URLs, refspecs, or tag-following from widening publication. The exact lease rejects every remote change after classification, including a concurrent change that remains an ancestor of local `HEAD`. The immediately preceding strict-ancestor proof ensures this invocation cannot use the force capability to replace remote-only work. In clean fast-forward mode, do not reset, rebase, recreate, or otherwise rewrite the local commits before this push. Remote append may recreate only the unpublished tail before `{publication-commit}` is captured; after capture, do not change it. Do not set or change upstream configuration in either existing-remote publishing mode.

If this push exits non-zero, do not continue to `gh pr create` and do not execute Step 10 when `REMOTE_APPEND_MODE=true`. A non-zero result is an ambiguous publication attempt even when an immediate query still sees the old OID: an in-flight receive may complete after that observation. Preserve the prepared append branch and recovery refs in every outcome. Re-query through `{origin-push-url-assignment}` and `git ls-remote --heads -- "$ORIGIN_PUSH_URL" "refs/heads/{feature-branch}"` with the same bounded, noninteractive, strict procedure, using the result only to report current observed state:

- still at `{observed-origin-oid}` — the update has not been observed; preserve the prepared append state because the failed push may still be in flight. Clean fast-forward mode leaves local commits unchanged
- now at `{publication-commit}` — the update may have landed despite the non-zero status; preserve the published local state, verify the remote, and create the Pull Request manually or rerun for exact-tip recovery
- at any other OID, absent, malformed, or unverified — remote state changed or cannot be proven; preserve the prepared local state and coordinate before retrying

#### Fresh remote publication

The remainder of Step 8.3 applies only when `FRESH_REMOTE_MODE=true`.

Step 5 proved that `{rollback-origin-ref}` was absent. Use the quoted, explicit absence-leased push below and set upstream tracking. Disable Git credential prompting for this network mutation; authentication failure is a hard blocker, never a reason to wait for terminal input. Run the push with the shell tool's bounded timeout. If any actor creates the remote branch after Step 5, the lease fails. If this push succeeds, no Pull Request could have existed for that branch at the moment this workflow created it, so a later Pull Request cannot have been rewritten by this invocation:

```bash
NONINTERACTIVE_GIT_SSH_COMMAND="${GIT_SSH_COMMAND:-${GIT_SSH:-ssh}} -oBatchMode=yes"
FINAL_STACK_RESOLVED=$("${CLAUDE_PLUGIN_ROOT}/scripts/resolve-stack-membership.sh") || {
  echo "Stack membership could not be revalidated at the fresh push boundary; run Step 10 and stop." >&2
  exit 1
}
if ! (
  eval "$FINAL_STACK_RESOLVED"
  [ "$STACK_MEMBERSHIP" = none ]
); then
  echo "The branch joined a local or server-side stack before the fresh push; run Step 10 and stop." >&2
  exit 1
fi
env GIT_TERMINAL_PROMPT=0 GCM_INTERACTIVE=Never GIT_SSH_COMMAND="$NONINTERACTIVE_GIT_SSH_COMMAND" \
  git push --force-with-lease="{rollback-origin-ref}:" -u origin "HEAD:{rollback-origin-ref}"
```

Do not use plain `--force`, an absence lease for a pre-existing remote ref, an implicit destination, or a tracking ref read after the rewrite as the lease baseline. `kramme:git:recreate-commits --no-push` left this fresh remote absent; this is the fresh mode's sole remote update before Pull Request creation. If the final stack guard fails, execute Step 10 before stopping; do not classify that failure as an ambiguous push outcome because no push ran.

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

1. Capture `git rev-parse --verify HEAD` as `{publication-head}` immediately before allocating the temporary files. Require a full 40-character lowercase commit OID. In exact-tip recovery it must still equal `{entry-commit}`; in either existing-remote publishing mode it must equal `{publication-commit}`; in fresh publication it is the rewritten commit that the successful Step 8.3 push published.

2. Create and capture temp file paths. Use the fixed `/tmp` templates so every captured path is shell-safe. Allocate the attachment-values file only when `DEMO_ATTACHMENT_COUNT` is greater than zero. If a later allocation fails, remove the files already allocated before stopping:

   ```bash
   if ! PR_TITLE_FILE=$(mktemp "/tmp/kramme-pr-title.XXXXXX"); then
     exit 1
   fi
   if ! PR_BODY_FILE=$(mktemp "/tmp/kramme-pr-body.XXXXXX"); then
     rm -f -- "$PR_TITLE_FILE"
     exit 1
   fi
   PR_ATTACHMENTS_FILE=""
   if [ "{demo-attachment-count}" -gt 0 ]; then
     if ! PR_ATTACHMENTS_FILE=$(mktemp "/tmp/kramme-pr-attachments.XXXXXX"); then
       rm -f -- "$PR_TITLE_FILE" "$PR_BODY_FILE"
       exit 1
     fi
   fi
   echo "$PR_TITLE_FILE"
   echo "$PR_BODY_FILE"
   [ -z "$PR_ATTACHMENTS_FILE" ] || echo "$PR_ATTACHMENTS_FILE"
   ```

3. Require each captured path to match `/tmp/kramme-pr-(title|body|attachments).[A-Za-z0-9]+`, then write `{title}` and `{description}` to the corresponding payload paths using the runtime's file-write capability. Do not use `cat <<EOF`, `printf "{description}"`, or any other shell-parsed form for generated Markdown. When attachments are expected, run the command below. It revalidates every evidence file at the creation boundary and emits values separated by NUL bytes so none become shell source. If it fails, empty the attachment-values file, set the effective attachment count to zero, record the diagnostic in `{demo-evidence-status}`, and continue without attachments.

   ```bash
   python3 "{pr-create-skill-dir}/scripts/prepare-demo-attachments.py" \
     --repo-root "{repo-root}" \
     --manifest "{demo-evidence-manifest}" \
     --format nul > "{pr-attachments-file}"
   ```

4. Emit the command below with the shell tool's bounded timeout. `GH_PROMPT_DISABLED=1` makes authentication or other interaction requirements fail closed. Include `--draft` on the first line only when `DRAFT_MODE=true`; otherwise omit it entirely (do not emit an empty flag). Substitute the validated captured paths and expected attachment count. The trap removes all temporary payload files on success, failure, or interruption; captured evidence remains under `.context/demo-reels/`.

```bash
PR_TITLE_FILE="{pr-title-file}"
PR_BODY_FILE="{pr-body-file}"
PR_ATTACHMENTS_FILE="{pr-attachments-file-or-empty}"
cleanup_pr_files() {
  rm -f -- "$PR_TITLE_FILE" "$PR_BODY_FILE"
  [ -z "$PR_ATTACHMENTS_FILE" ] || rm -f -- "$PR_ATTACHMENTS_FILE"
}
trap cleanup_pr_files EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM
FINAL_STACK_RESOLVED=$("${CLAUDE_PLUGIN_ROOT}/scripts/resolve-stack-membership.sh") || {
  echo "Stack membership could not be revalidated at the Pull Request creation boundary; stop before creation." >&2
  exit 1
}
if ! (
  eval "$FINAL_STACK_RESOLVED"
  [ "$STACK_MEMBERSHIP" = none ]
); then
  echo "The branch joined a local or server-side stack before Pull Request creation; stop before creation." >&2
  exit 1
fi
ATTACH_ARGS=()
EFFECTIVE_DEMO_ATTACHMENT_COUNT={demo-attachment-count}
DEMO_ATTACHMENT_RETRY_WITHOUT_EVIDENCE=false
if [ "{demo-attachment-count}" -gt 0 ]; then
  ATTACHMENT_READ_COUNT=0
  while IFS= read -r -d '' ATTACHMENT_VALUE; do
    ATTACH_ARGS+=(--attach "$ATTACHMENT_VALUE")
    ATTACHMENT_READ_COUNT=$((ATTACHMENT_READ_COUNT + 1))
  done < "$PR_ATTACHMENTS_FILE"
  if [ "$ATTACHMENT_READ_COUNT" -ne "{demo-attachment-count}" ]; then
    echo "Validated demo attachment count changed; creating the Pull Request without attachments." >&2
    ATTACH_ARGS=()
    EFFECTIVE_DEMO_ATTACHMENT_COUNT=0
  fi
fi
run_pr_create() {
  env GH_PROMPT_DISABLED=1 gh pr create \
    --base "{base-branch}" \
    --head "{feature-branch}" \
    --assignee @me \
    --title "$(cat "$PR_TITLE_FILE")" \
    --body-file "$PR_BODY_FILE" \
    "$@"
}
attachment_failure_proves_no_pr() {
  case "$1" in
    "attaching files is not supported on GitHub Enterprise Server" | \
      "unsupported authentication type" | \
      "could not determine which repository to attach files to" | \
      "could not determine your permission on the repository to attach files" | \
      "attaching files requires write access to the repository") return 0 ;;
  esac
  printf '%s\n' "$1" | grep -qxF "no pull request was created"
}
if PR_CREATE_OUTPUT=$(run_pr_create "${ATTACH_ARGS[@]}" 2>&1); then
  PR_CREATE_STATUS=0
else
  PR_CREATE_STATUS=$?
fi
if [ "$PR_CREATE_STATUS" -ne 0 ] \
  && [ "$EFFECTIVE_DEMO_ATTACHMENT_COUNT" -gt 0 ] \
  && attachment_failure_proves_no_pr "$PR_CREATE_OUTPUT"; then
  INITIAL_ATTACHMENT_FAILURE=$PR_CREATE_OUTPUT
  ATTACH_ARGS=()
  EFFECTIVE_DEMO_ATTACHMENT_COUNT=0
  DEMO_ATTACHMENT_RETRY_WITHOUT_EVIDENCE=true
  printf '%s\n' "$INITIAL_ATTACHMENT_FAILURE" >&2
  printf '%s\n' "Attachment upload failed before Pull Request creation; retried once without demo evidence." >&2
  if RETRY_OUTPUT=$(run_pr_create 2>&1); then
    PR_CREATE_OUTPUT=$RETRY_OUTPUT
    PR_CREATE_STATUS=0
  else
    PR_CREATE_STATUS=$?
    PR_CREATE_OUTPUT=$RETRY_OUTPUT
  fi
fi
printf '%s\n' "$PR_CREATE_OUTPUT"
printf '%s\n' \
  "PR_CREATE_STATUS=$PR_CREATE_STATUS" \
  "EFFECTIVE_DEMO_ATTACHMENT_COUNT=$EFFECTIVE_DEMO_ATTACHMENT_COUNT" \
  "DEMO_ATTACHMENT_RETRY_WITHOUT_EVIDENCE=$DEMO_ATTACHMENT_RETRY_WITHOUT_EVIDENCE"
exit "$PR_CREATE_STATUS"
```

If this final stack guard fails, the trap removes the payload files and no Pull Request is created. When `FRESH_REMOTE_MODE=true`, execute Step 10 before stopping. Every existing-remote publication already completed in Step 8.3, so preserve that published state and stop without rollback. Do not treat a guard failure as a `gh pr create` failure because the creation command did not run.

When `DRAFT_MODE=true`, add `--draft \` as the second line.

Always pass the validated explicit `--head` value. This prevents `gh pr create` from offering to push or fork when exact-tip recovery is using a remote branch without local upstream configuration; the skill's own mode-specific publication step remains the only allowed push. `ATTACH_ARGS` contains one separate repeatable `--attach` pair per validated image or video. Because the body does not contain local paths, GitHub appends only successful uploads inline and a failed upload cannot leave an inaccessible path in the PR.

5. Capture the final three labeled result lines from the creation command. Require exactly one of each, a decimal `PR_CREATE_STATUS`, a non-negative decimal `EFFECTIVE_DEMO_ATTACHMENT_COUNT`, and `DEMO_ATTACHMENT_RETRY_WITHOUT_EVIDENCE=true|false`; treat missing, duplicated, or malformed result state as an unproven creation failure. The shell tool's exit status must equal `PR_CREATE_STATUS`. When the retry marker is `true`, require effective attachment count zero and preserve the separately printed first upload diagnostic. A zero status means the attachment-free retry succeeded; set `{demo-evidence-status}` to `skipped — every upload failed before creation; Pull Request creation retried once without evidence`. A non-zero status belongs only to the attachment-free retry because `PR_CREATE_OUTPUT` is replaced rather than concatenated with the first failure.

   Query the created Pull Request through the same GitHub repository context with the shell tool's bounded timeout when `PR_CREATE_STATUS=0`. Also run the query when `PR_CREATE_STATUS` is non-zero and either `EFFECTIVE_DEMO_ATTACHMENT_COUNT` is greater than zero or `DEMO_ATTACHMENT_RETRY_WITHOUT_EVIDENCE=true`. The former may mean GitHub CLI created the PR after only some attachments uploaded; the latter may mean the attachment-free retry created the PR before a later metadata failure:

   ```bash
   env GH_PROMPT_DISABLED=1 gh pr list \
     --head "{feature-branch}" \
     --base "{base-branch}" \
     --state open \
     --limit 2 \
     --json number,url,state,baseRefName,headRefName,headRefOid
   ```

   Require this query to succeed and return exactly one record. Require `state` to be `OPEN`, `baseRefName` to equal `{base-branch}`, `headRefName` to equal `{feature-branch}`, and `headRefOid` to equal `{publication-head}` exactly. Capture its `url` as `{pr-url}` for Step 9. A missing, malformed, duplicate, or mismatched result means GitHub did not prove that the created Pull Request contains the commit this invocation inspected. Report the creation result and observed metadata, but do not run Step 9 or claim success; do not roll back, close, or delete the Pull Request or branch automatically.

   When `PR_CREATE_STATUS` is non-zero, require `PR_CREATE_OUTPUT` to contain `{pr-url}` as a standalone line. Explicitly reject the `a pull request ... already exists:` diagnostic; matching head/base/OID metadata does not prove this invocation created that Pull Request. For that race, report the concurrently created Pull Request and stop without Step 9 or manual-creation guidance. When `DEMO_ATTACHMENT_RETRY_WITHOUT_EVIDENCE=true`, require effective attachment count zero, preserve the retry diagnostic, set `{demo-evidence-status}` to `skipped — uploads failed before creation; attachment-free creation completed with a warning`, and continue to Step 9 without applying attachment-specific partial-success rules to the first failure. Otherwise require effective attachment count greater than zero. When that output contains an attachment-specific diagnostic beginning `could not upload ` or `failed to upload ` that names one of the validated artifact paths, treat the PR as created with partially attached evidence, preserve every CLI diagnostic, set `{demo-evidence-status}` to `partially attached`, and continue to Step 9 with a warning. If the output proves a created PR but lacks the attachment-specific diagnostic, preserve the diagnostic, set `{demo-evidence-status}` to `created with warning — attachment status unclassified`, and continue to Step 9 without claiming partial attachment or concealing a metadata-update failure. Do not retry attachments automatically after possible creation: successful uploads cannot be rolled back, and a blind retry could duplicate them. The creation block's exact allowlist covers only attachment failures that GitHub CLI reports before Pull Request submission, and it retries once without attachments. Continue to Step 8.5 only when no created Pull Request was proven.

### 8.5 Handle PR Creation Failure

If `gh pr create` fails after a successful fresh, clean fast-forward, or remote-append push, or while reusing the verified exact-tip remote branch, and Step 8.4 did not prove the partial-attachment success case:

Before showing manual creation instructions, execute Step 9.0 from `references/state-and-rollback.md` only in the fresh-remote path so any excluded uncommitted changes are restored locally or explicitly reported for manual conflict resolution. Existing-remote modes skip Step 9.0: clean modes created no stash, while remote append committed and published all dirty work. Do not run Step 10 here: the branch already exists remotely, and the failure output should preserve that manual-creation path.

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
Uncommitted work: {none | committed and included before history rewrite | committed and included as appended narrative commits | excluded from PR and restored locally | excluded from PR but restore needs manual conflict resolution}
Demo evidence: {attached N files | partially attached — inspect the reported upload failure | created with warning — attachment status unclassified | skipped/unavailable with reason}

Commits included:
  - {commit 1 summary}
  - {commit 2 summary}
  - ...

Next steps:
  1. Review the PR description for accuracy
  2. Review the attached demo evidence and add only any missing state noted above
  3. Run tests and ensure CI passes
```
