# Direct PR Update

Use this when `DIRECT_UPDATE=true`, and for check mode's confirmed update from `references/check-mode.md`. Both paths share steps 1 and 2; a check-mode update replaces step 3 with `Step 3 for a check-mode confirmed update` below, which also revalidates the exact PR target before publishing.

**Skip copy-paste output and save-to-file prompt.** Use this sequence to avoid shell-interpolation, heredoc-terminator, and repository-controlled symlink hazards in LLM-generated content:

1. **Allocate private update storage outside the repository.** Keep this invariant explicit: do not mutate tracked files or use predictable repository-local payload paths.

   ```bash
   umask 077
   UPDATE_DIR=$(mktemp -d "/tmp/kramme-pr-description.XXXXXX") || {
     echo "Error: Could not allocate private PR update storage." >&2
     exit 1
   }
   if [ ! -d "$UPDATE_DIR" ] || [ -L "$UPDATE_DIR" ]; then
     echo "Error: PR update storage is not a private directory." >&2
     exit 1
   fi
   chmod 700 "$UPDATE_DIR" || {
     echo "Error: Could not secure PR update storage." >&2
     exit 1
   }
   printf '%s\n' "$UPDATE_DIR"
   ```

   Capture the single printed line as agent-tracked `{update-dir}`. Require it to match `/tmp/kramme-pr-description.[A-Za-z0-9]+`, remain a regular non-symlink directory, and contain no newline. Derive and retain these literal paths as agent state; shell variables do not persist between tool calls:
   - `{pr-title-file}` = `{update-dir}/new-title.txt`
   - `{pr-body-file}` = `{update-dir}/new-body.md`
   - `{pr-backup}` = `{update-dir}/pr-metadata.backup.json`

2. **Write the generated title and body with the runtime's native file-write capability.** Keep generated Markdown out of the shell parser.
   - `{pr-title-file}` — the conventional-commit title, single line, no trailing newline.
   - `{pr-body-file}` — the full description Markdown.

   Require both paths to be regular, non-symlink files after writing. Do not use shell interpolation or a heredoc to write generated content.

3. **Back up every field the update replaces, then apply the edit in one shell invocation.** A backup failure is a hard stop; do not silently publish without recovery data. JSON preserves an empty body as valid data. Substitute the validated literal agent-state paths below; do not rely on variables from Step 1.

   ```bash
   UPDATE_DIR="{update-dir}"
   PR_TITLE_FILE="{pr-title-file}"
   PR_BODY_FILE="{pr-body-file}"
   PR_BACKUP="{pr-backup}"
   if [ ! -d "$UPDATE_DIR" ] || [ -L "$UPDATE_DIR" ]; then
     echo "Error: PR update storage changed or became indirect; no update was made." >&2
     exit 1
   fi
   if [ ! -f "$PR_TITLE_FILE" ] || [ -L "$PR_TITLE_FILE" ] \
     || [ ! -f "$PR_BODY_FILE" ] || [ -L "$PR_BODY_FILE" ]; then
     echo "Error: Generated PR payload files are missing or indirect; no update was made." >&2
     exit 1
   fi
   cleanup_pr_payload() {
     rm -f -- "$PR_TITLE_FILE" "$PR_BODY_FILE"
   }
   trap cleanup_pr_payload EXIT
   trap 'exit 129' HUP
   trap 'exit 130' INT
   trap 'exit 143' TERM
   if ! env GH_PROMPT_DISABLED=1 gh pr view --json title,body > "$PR_BACKUP"; then
     rm -f -- "$PR_BACKUP"
     echo "Error: Could not back up the existing PR; no update was made." >&2
     exit 1
   fi
   env GH_PROMPT_DISABLED=1 gh pr edit \
     --title "$(cat "$PR_TITLE_FILE")" \
     --body-file "$PR_BODY_FILE"
   ```

   - `"$(cat ...)"` substitutes the literal file contents into one argv element; `gh` does not re-evaluate the argument as shell.
   - `--body-file` reads the body straight from disk; nothing in it flows through the shell.

### Step 3 for a check-mode confirmed update

Run validation, backup, target revalidation, publication, and payload cleanup in one shell invocation. Substitute the validated literal agent-state values captured in check-mode Phase C1 and step 1 above; do not assume variables from earlier Bash blocks persist. Immediately before publication, fetch the complete mutation target into the private backup. Fail closed when the backup cannot be created; an empty PR body is valid because the backup is JSON rather than a body-only file.

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
  echo "Run the check again and confirm the new snapshot before publishing." >&2
  exit 1
fi

env GH_PROMPT_DISABLED=1 gh pr edit "$PR_NUMBER" \
  --title "$(cat "$PR_TITLE_FILE")" \
  --body-file "$PR_BODY_FILE"
```

**After updating**, confirm success and include the private backup path:

```text
PR updated successfully.

URL: {pr-url}
Title: {title}
Previous PR metadata backed up to: {pr-backup}
```

**If backup, revalidation, or update fails**, fall back to presenting the description for copy-paste and show the error. Keep the private backup when it was created so the prior title and body remain recoverable.
