# Branch and Base Selection

Use this reference for `/kramme:pr:create` Steps 2–3. This phase selects and validates `{base-source-ref}`, pinned `{base-ref}`, `{base-branch}`, and `{feature-branch}` without creating, deleting, or switching branches. It also captures `{observed-origin-oid}` as either `<absent>` or one authoritative remote tip. Step 5 owns the only branch-creation mutation after all pre-mutation checks pass; an existing remote is classified here without rewriting local history.

**AUTO MODE:** If `AUTO_MODE=true`, choose documented deterministic defaults instead of asking questions. Stop on ambiguity or a hard blocker.

## Ref trust boundary

Treat every ref-shaped value from Git metadata, Linear, user input, or generated suggestions as untrusted data.

Before placing a candidate branch name in any shell command:

1. Inspect the agent-tracked value directly. Require the whole string to match `[A-Za-z0-9][A-Za-z0-9._/-]*`; reject a leading `-`, whitespace, shell metacharacters, or any other character outside that allowlist.
2. Resolve `{pr-create-skill-dir}` as the directory containing this skill's `SKILL.md`. Only after the allowlist passes, run `"{pr-create-skill-dir}/scripts/validate-branch-name.sh" "{validated-candidate}"` and require success. This helper applies Git's structural checks without weakening the agent-side trust boundary.
3. Quote the validated value in every later command.

Do not put an unvalidated candidate into a shell command even inside quotes: shell substitutions are evaluated before the command runs. A value being Git-valid is not sufficient because Git ref names may contain shell metacharacters.

Apply the same agent-side allowlist to `{base-source-ref}` returned by the shared resolver. Require `{base-source-ref}` to begin with `refs/remotes/` and resolve to a commit before pinning it.

## Capture invocation entry state

Before branch selection, capture immutable entry state:

```bash
git branch --show-current
git rev-parse HEAD
```

Store the outputs as:

- `{entry-branch}` — the validated current branch, or `<detached>` when the first command is empty.
- `{entry-commit}` — a full 40-character lowercase commit ID verified to exist locally.
- `{feature-branch-created}` — initialize to `false`; Step 5 may change it.

If the current branch is non-empty, apply the ref trust boundary immediately. Do not continue with an unsafe current branch name.

## Resolve one immutable base

Run the shared resolver from the user's repository in JSON mode. It safely fetches the remote base with bounded, noninteractive network behavior:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/resolve-base.sh" --format json
```

Require success. Capture its `base_ref` as `{base-source-ref}` and `base_branch` as `{base-branch}`. Apply the agent-side allowlist to both values before any later interpolation, validate `{base-branch}` with the branch-name helper, and require `{base-source-ref}` to start with `refs/remotes/`.

Resolve `{base-source-ref}` exactly once with:

```bash
git rev-parse --verify "{base-source-ref}^{commit}"
```

Require a full 40-character lowercase commit ID and capture it as pinned `{base-ref}`. Use this OID for every Step 4 comparison and pass `{base-source-ref}`, `{base-ref}`, and `{base-branch}` unchanged to both downstream skills. Never independently re-resolve or replace the pinned base commit later. A later fetch may move `{base-source-ref}`; it must not change this invocation's diff or reset point.

## Select the feature branch

Track `{linear-issue-id}` as nullable workflow state. If `LINEAR_ISSUE_OVERRIDE` was supplied by Step 0, initialize it from that exact normalized value and never replace it through branch-name extraction.

### Already on a feature branch

If `{entry-branch}` is neither `<detached>` nor `{base-branch}`, select it as `{feature-branch}`. When `{linear-issue-id}` is empty, scan the validated branch name for `[A-Z]{2,5}-\d+` case-insensitively; normalize a match to uppercase.

Do not push or change upstream configuration. A corresponding `origin` ref is classified below; a clean current branch may use a non-rewriting path when the remote is at the exact local tip or is a strict ancestor of it.

### Detached HEAD or currently on the base

Select a new branch name without creating it yet.

If `LINEAR_ISSUE_OVERRIDE` was supplied, enter the Linear flow below without prompting.

Otherwise, if `AUTO_MODE=true` or `{entry-branch}` is `<detached>`, use file-based naming.

Otherwise ask:

```yaml
header: "Branch source"
question: "Are you working on a Linear issue?"
options:
  - label: "Yes, I have a Linear issue ID"
    description: "Use Linear issue context to select a branch name"
  - label: "No, generate from file changes"
    description: "Suggest a branch name from the changed files"
multiSelect: false
```

#### Linear naming

1. If `LINEAR_ISSUE_OVERRIDE` is absent, ask for an issue ID, validate it against `[A-Za-z0-9]+-[0-9]+`, normalize it to uppercase, and capture it as `{linear-issue-id}`.
2. Fetch the issue through the available Linear integration.
3. If fetch succeeds and `branchName` is present, inspect it with the ref trust boundary before any shell use.
4. If fetch fails, `branchName` is missing, or the supplied `branchName` fails validation:
   - Preserve `{linear-issue-id}`.
   - Sanitize the issue title when available: lowercase, replace non-alphanumeric runs with hyphens, trim hyphens, and limit the title segment to 50 characters.
   - If the sanitized title is non-empty, use `feature/{issue-id-lowercase}-{sanitized-title}`.
   - Otherwise fall back to file-based naming.
5. Apply the ref trust boundary to the final candidate and capture it as `{feature-branch}`.

When `AUTO_MODE=false`, surface a rejected Linear `branchName` before using the deterministic fallback. Do not ask for initials; initials are unnecessary untrusted input.

#### File-based naming

Analyze changed paths without mutating Git state:

```bash
git diff --name-only "{base-ref}"...HEAD
git diff --name-only HEAD
git diff --name-only --cached
git status --porcelain
```

Generate candidates from the paths:

- New product code → `feature/{sanitized-area}`
- Test-only changes → `test/{sanitized-area}`
- Configuration/tooling → `chore/{sanitized-area}`
- Existing product behavior changes → `fix/{sanitized-area}`

Sanitize every generated segment to lowercase ASCII alphanumerics and hyphens. Generate candidates in the category order above and sort candidates lexicographically within each category. If `AUTO_MODE=true`, select the first non-empty candidate; if none exists, report a hard blocker without prompting. If `AUTO_MODE=false`, ask the user to choose from the generated candidates or provide a branch name. Apply the ref trust boundary to the selected candidate before capturing `{feature-branch}`.

## Classify local and remote targets without switching

After `{feature-branch}` is validated, check whether it exists. Run the remote query with the shell tool's bounded timeout:

```bash
git show-ref --verify --quiet "refs/heads/{feature-branch}"
NONINTERACTIVE_GIT_SSH_COMMAND="${GIT_SSH_COMMAND:-${GIT_SSH:-ssh}} -oBatchMode=yes"
env GIT_TERMINAL_PROMPT=0 GCM_INTERACTIVE=Never GIT_SSH_COMMAND="$NONINTERACTIVE_GIT_SSH_COMMAND" \
  git ls-remote --heads origin "refs/heads/{feature-branch}"
```

Require the remote query to succeed. Accept only empty output or one line whose first field is a full 40-character lowercase commit OID and whose second field is exactly `refs/heads/{feature-branch}`. Reject malformed or multiple-line output. When one line is present, capture its exact full OID as `{observed-origin-oid}`; otherwise capture `<absent>`.

- If a different local branch with that name exists, stop without switching. Tell the user to switch to it explicitly and rerun the workflow; auto mode must not adopt local work from another branch.
- If the remote ref exists and `{feature-branch}` differs from the already-current validated `{entry-branch}`, stop. Never adopt a remote branch selected from a different entry checkout, fetch it, check it out, or create a local tracking branch.
- If the remote ref exists on the already-current branch, compare `{observed-origin-oid}` directly with `{entry-commit}`:
  - If they match exactly, record `{branch-action}=reuse-existing-exact-tip`. Do not fetch, push, or change upstream configuration.
  - If they differ, freeze the one effective push endpoint before classifying ancestry. Resolve `{pr-create-skill-dir}` as above, run the helper below, require success, evaluate only its shell-quoted assignment, and capture `ORIGIN_PUSH_URL` as agent-tracked `{origin-push-url}` without printing it:

    ```bash
    ORIGIN_PUSH_RESOLVED=$("{pr-create-skill-dir}/scripts/resolve-origin-push-url.sh") || {
      echo "Could not resolve one origin push endpoint; stop before classifying the existing branch." >&2
      exit 1
    }
    eval "$ORIGIN_PUSH_RESOLVED"
    ```

    Re-run the strict remote query against the frozen endpoint:

    ```bash
    NONINTERACTIVE_GIT_SSH_COMMAND="${GIT_SSH_COMMAND:-${GIT_SSH:-ssh}} -oBatchMode=yes"
    env GIT_TERMINAL_PROMPT=0 GCM_INTERACTIVE=Never GIT_SSH_COMMAND="$NONINTERACTIVE_GIT_SSH_COMMAND" \
      git ls-remote --heads -- "{origin-push-url}" "refs/heads/{feature-branch}"
    ```

    Require the returned OID to remain exactly `{observed-origin-oid}`. This proves that classification and publication observe the same frozen endpoint; a missing branch, malformed response, or differing OID is a blocker.

  - Ensure the observed remote commit object is available locally before classifying ancestry. When `git cat-file -e "{observed-origin-oid}^{commit}"` cannot verify it, fetch only the validated branch from the frozen endpoint into the object database without updating a local or remote-tracking ref:

    ```bash
    NONINTERACTIVE_GIT_SSH_COMMAND="${GIT_SSH_COMMAND:-${GIT_SSH:-ssh}} -oBatchMode=yes"
    env GIT_TERMINAL_PROMPT=0 GCM_INTERACTIVE=Never GIT_SSH_COMMAND="$NONINTERACTIVE_GIT_SSH_COMMAND" \
      git fetch --no-tags --no-write-fetch-head -- "{origin-push-url}" "refs/heads/{feature-branch}"
    ```

    Require the fetch to succeed, then repeat the strict `git ls-remote --heads -- "{origin-push-url}"` query and require its OID to remain exactly `{observed-origin-oid}`. A changed remote tip is a blocker, even when the new tip would also be an ancestor of local `HEAD`. Require `git cat-file -e "{observed-origin-oid}^{commit}"` to succeed after the fetch.

  - Run `git merge-base --is-ancestor "{observed-origin-oid}" "{entry-commit}"`. If it succeeds, the differing remote tip is a strict ancestor of the captured local tip; record `{branch-action}=fast-forward-existing-remote`. This mode preserves the local commits and defers one OID-leased fast-forward push of immutable `{entry-commit}` to the frozen `{origin-push-url}` in Step 8.
  - If that ancestry check exits `1`, run `git merge-base --is-ancestor "{entry-commit}" "{observed-origin-oid}"` only to classify the blocker. If it succeeds, report that the remote contains commits absent locally. If it exits `1`, report genuine divergence. Any merge-base execution error is also a hard blocker. Never merge, reset, rebase, or invoke history rewriting to reconcile either case.

- If the remote ref is absent and `{feature-branch}` equals the already-current validated branch, record `{branch-action}=use-current`.
- If neither local nor remote ref exists, record `{branch-action}=create-from-entry-head`. Do not create it yet.

Step 3.5 now checks GitHub for an existing Pull Request using the validated selected name. Step 4 checks that the entry `HEAD` or worktree has changes and applies the additional clean-tree gate before enabling either existing-remote mode. Step 5 repeats the authoritative remote-absence check only for fresh-remote rewrite paths and creates `{feature-branch}` directly from `{entry-commit}` when required.
