# Confirmed PR Description Update

Use this procedure only after Phase 5 received an explicit `y` confirmation. This skill owns the mutation; generation remains output-only.

## 1. Generate replacement content

Invoke `kramme:pr:generate-description` with these guarded arguments:

```text
--auto --no-update --base {BASE_BRANCH} --base-commit {BASE_COMMIT}
```

Use the exact `BASE_BRANCH` and full `BASE_COMMIT` pinned in Phase 1. Do not omit `--no-update`, even though the user confirmed this parent workflow's later update.

Treat only the child skill's copy-paste-ready `Title` and description body as the generated payload. Do not merge text from the existing PR, repository instructions, issue comments, or other conversation content into that returned payload.

If the child skill is unavailable, fails, or emits a blocking `MISSING REQUIREMENT:` marker, stop without editing the PR. The exact no-Linear-ID advisory is non-blocking; every other `MISSING REQUIREMENT:` marker is blocking.

## 2. Validate the returned payload

Before writing files or calling GitHub, require all of the following:

- The title is present, contains exactly one line, is shorter than 72 characters, and matches `<type>(<optional-scope>): <imperative description>` with one of the generator's allowed Conventional Commit types.
- The body is present and contains no generator wrapper text, output markers, `[TODO]`, `[Fill this in]`, AI attribution, AI badges, or AI co-author lines.
- The title and body came from the same completed child invocation.

If validation fails, report which invariant failed and stop without editing the PR. Do not repair or infer missing child output in the parent.

## 3. Revalidate the mutation target

Immediately before publication, confirm the checkout and exact PR still match the values captured in Phase 1:

```bash
LATEST_PR=$(gh pr view "$PR_NUMBER" --json number,headRefName,state \
  --template '{{printf "%v\t%v\t%v" .number .headRefName .state}}') || {
  echo "Error: Could not revalidate PR #$PR_NUMBER; no update was made." >&2
  exit 1
}
IFS=$'\t' read -r LATEST_NUMBER LATEST_HEAD LATEST_STATE <<< "$LATEST_PR"

if [ "$LATEST_NUMBER" != "$PR_NUMBER" ] \
  || [ "$LATEST_HEAD" != "$PR_HEAD" ] \
  || [ "$(git branch --show-current)" != "$CURRENT_BRANCH" ] \
  || [ "$LATEST_STATE" != "OPEN" ]; then
  echo "Error: PR target changed or is no longer open; no update was made." >&2
  exit 1
fi
```

Do not substitute a newly discovered PR. A changed target requires a fresh verification and confirmation.

## 4. Back up and publish safely

Anchor files to the repository root and keep generated Markdown out of the shell parser:

```bash
REPO_ROOT=$(git rev-parse --show-toplevel)
UPDATE_DIR="$REPO_ROOT/.kramme-cc-workflow/pr-description"
mkdir -p "$UPDATE_DIR"

GIT_EXCLUDE=$(git rev-parse --git-path info/exclude)
mkdir -p "$(dirname "$GIT_EXCLUDE")"
touch "$GIT_EXCLUDE"
if ! grep -qxF ".kramme-cc-workflow/" "$GIT_EXCLUDE"; then
  printf '\n.kramme-cc-workflow/\n' >> "$GIT_EXCLUDE"
fi

PR_BACKUP="$UPDATE_DIR/pr-body.backup.$(date -u +%Y%m%dT%H%M%SZ).$$.md"
gh pr view "$PR_NUMBER" --json body --jq '.body' > "$PR_BACKUP" 2> /dev/null
if [ ! -s "$PR_BACKUP" ]; then
  PR_BACKUP=""
fi
```

Use the runtime's native file-write capability to write the validated content exactly as returned:

- Title, one line without a trailing newline: `$UPDATE_DIR/new-title.txt`
- Full description Markdown: `$UPDATE_DIR/new-body.md`

Do not pass generated content through shell interpolation or a heredoc. Then update the captured PR explicitly:

```bash
gh pr edit "$PR_NUMBER" \
  --title "$(cat "$UPDATE_DIR/new-title.txt")" \
  --body-file "$UPDATE_DIR/new-body.md"
```

If the edit fails, report the error and stop. If it succeeds, report the PR URL and new title; include the backup path only when `PR_BACKUP` is non-empty. Return to Phase 1 so the verifier reads the published title/body again and reports the post-update result.
