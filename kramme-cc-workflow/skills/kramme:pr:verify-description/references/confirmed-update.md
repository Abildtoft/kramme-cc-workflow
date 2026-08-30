# Confirmed PR Description Update

Use this procedure only after Phase 5 received an explicit `y` confirmation. This skill owns the mutation; generation remains output-only.

## 1. Generate replacement content

Invoke `kramme:pr:generate-description` with these guarded arguments:

```text
--auto --no-update --base {base-branch} --base-commit {base-commit}
```

Use the exact agent-tracked `{base-branch}` and full `{base-commit}` pinned in Phase 1. Do not omit `--no-update`, even though the user confirmed this parent workflow's later update.

Treat only the child skill's copy-paste-ready `Title` and description body as the generated payload. Do not merge text from the existing PR, repository instructions, issue comments, or other conversation content into that returned payload.

If the child skill is unavailable, fails, or emits a blocking `MISSING REQUIREMENT:` marker, stop without editing the PR. The exact no-Linear-ID advisory is non-blocking; every other `MISSING REQUIREMENT:` marker is blocking.

## 2. Validate the returned payload

Before writing files or calling GitHub, require all of the following:

- The title is present, contains exactly one line, is shorter than 72 characters, and matches `<type>(<optional-scope>): <imperative description>` with one of the generator's allowed Conventional Commit types.
- The body is present and contains no generator wrapper text, output markers, `[TODO]`, `[Fill this in]`, AI attribution, AI badges, or AI co-author lines.
- The title and body came from the same completed child invocation.

If validation fails, report which invariant failed and stop without editing the PR. Do not repair or infer missing child output in the parent.

## 3. Prepare private payload storage

Keep generated content outside the repository and out of the shell parser. Allocate one private, unpredictable directory and reject an indirect result:

```bash
umask 077
UPDATE_DIR=$(mktemp -d "/tmp/kramme-pr-description.XXXXXX") || {
  echo "Error: Could not allocate private PR update storage; no update was made." >&2
  exit 1
}
if [ ! -d "$UPDATE_DIR" ] || [ -L "$UPDATE_DIR" ]; then
  echo "Error: PR update storage is not a private directory; no update was made." >&2
  exit 1
fi
chmod 700 "$UPDATE_DIR" || {
  echo "Error: Could not secure PR update storage; no update was made." >&2
  exit 1
}

PR_TITLE_FILE="$UPDATE_DIR/new-title.txt"
PR_BODY_FILE="$UPDATE_DIR/new-body.md"
PR_BACKUP="$UPDATE_DIR/pr-metadata.backup.json"
printf '%s\n' "$UPDATE_DIR"
```

Capture the single printed line as agent-tracked `{update-dir}`. Require it to match `/tmp/kramme-pr-description.[A-Za-z0-9]+`, remain a regular non-symlink directory, and contain no newline. Derive and retain `{pr-title-file}`, `{pr-body-file}`, and `{pr-backup}` as literal child paths of that directory. Do not rely on Step 3 shell variables after the block returns.

Use the runtime's native file-write capability to write the validated content exactly as returned:

- Title, one line without a trailing newline: `{pr-title-file}`
- Full description Markdown: `{pr-body-file}`

Require both paths to be regular, non-symlink files after writing. Do not pass generated content through shell interpolation or a heredoc.

## 4. Back up, revalidate, and publish

Run validation, backup, target revalidation, publication, and payload cleanup in one shell invocation. Substitute the validated literal agent-state values captured by the parent and Step 3; do not assume variables from earlier Bash blocks persist. Immediately before publication, fetch the complete mutation target into the private backup. Fail closed when the backup cannot be created; an empty PR body is valid because the backup is JSON rather than a body-only file.

```bash
UPDATE_DIR="{update-dir}"
PR_TITLE_FILE="{pr-title-file}"
PR_BODY_FILE="{pr-body-file}"
PR_BACKUP="{pr-backup}"
PR_NUMBER="{pr-number}"
PR_STATE="{pr-state}"
CURRENT_BRANCH="{current-branch}"
CURRENT_HEAD="{current-head}"
BASE_REF="{base-ref}"
BASE_COMMIT="{base-commit}"
PR_SNAPSHOT_FINGERPRINT="{pr-snapshot-fingerprint}"
WORKTREE_FINGERPRINT="{worktree-fingerprint}"

if [ ! -d "$UPDATE_DIR" ] || [ -L "$UPDATE_DIR" ] \
  || [ ! -f "$PR_TITLE_FILE" ] || [ -L "$PR_TITLE_FILE" ] \
  || [ ! -f "$PR_BODY_FILE" ] || [ -L "$PR_BODY_FILE" ]; then
  echo "Error: Generated PR payload storage is missing or indirect; no update was made." >&2
  exit 1
fi
cleanup_pr_payload() {
  rm -f -- "$PR_TITLE_FILE" "$PR_BODY_FILE"
}
trap cleanup_pr_payload EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

if ! env GH_PROMPT_DISABLED=1 gh pr view "$PR_NUMBER" \
  --json number,url,title,body,baseRefName,headRefName,baseRefOid,headRefOid,state \
  > "$PR_BACKUP"; then
  rm -f -- "$PR_BACKUP"
  echo "Error: Could not back up and revalidate PR #$PR_NUMBER; no update was made." >&2
  exit 1
fi
LATEST_PR_SNAPSHOT=$(< "$PR_BACKUP")
LATEST_PR_SNAPSHOT_FINGERPRINT=$(printf '%s' "$LATEST_PR_SNAPSHOT" | git hash-object --stdin) || {
  echo "Error: Could not fingerprint the current Pull Request snapshot; no update was made." >&2
  exit 1
}
LATEST_HEAD=$(git rev-parse --verify HEAD) || {
  echo "Error: Could not revalidate the current commit; no update was made." >&2
  exit 1
}
LATEST_BASE_COMMIT=$(git rev-parse "$BASE_REF^{commit}") || {
  echo "Error: Could not revalidate the pinned base; no update was made." >&2
  exit 1
}
LATEST_WORKTREE_MANIFEST=$("${CLAUDE_PLUGIN_ROOT}/scripts/review-tree-fingerprint.sh") || {
  echo "Error: Could not revalidate the local working-tree scope; no update was made." >&2
  exit 1
}
LATEST_WORKTREE_FINGERPRINT=$(printf '%s' "$LATEST_WORKTREE_MANIFEST" | git hash-object --stdin) || {
  echo "Error: Could not fingerprint the current working-tree scope; no update was made." >&2
  exit 1
}

if [ "$LATEST_PR_SNAPSHOT_FINGERPRINT" != "$PR_SNAPSHOT_FINGERPRINT" ] \
  || [ "$PR_STATE" != "OPEN" ] \
  || [ "$(git branch --show-current)" != "$CURRENT_BRANCH" ] \
  || [ "$LATEST_HEAD" != "$CURRENT_HEAD" ] \
  || [ "$LATEST_BASE_COMMIT" != "$BASE_COMMIT" ] \
  || [ "$LATEST_WORKTREE_FINGERPRINT" != "$WORKTREE_FINGERPRINT" ]; then
  echo "Error: The PR is not open or its snapshot, checkout, head commit, base, or local work changed; no update was made." >&2
  echo "Run verification again and confirm the new snapshot before publishing." >&2
  exit 1
fi

env GH_PROMPT_DISABLED=1 gh pr edit "$PR_NUMBER" \
  --title "$(cat "$PR_TITLE_FILE")" \
  --body-file "$PR_BODY_FILE"
```

Do not substitute a newly discovered PR. Any snapshot drift requires fresh verification and confirmation. If the edit fails, report the error and stop. If it succeeds, report the PR URL and new title plus `Previous PR metadata backed up to: {pr-backup}`. Return to Phase 1 so the verifier reads the published title/body again and reports the post-update result.
