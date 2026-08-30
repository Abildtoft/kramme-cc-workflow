# Direct PR Update

Use this when `DIRECT_UPDATE=true`.

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
   PR_TITLE_FILE="$UPDATE_DIR/new-title.txt"
   PR_BODY_FILE="$UPDATE_DIR/new-body.md"
   PR_BACKUP="$UPDATE_DIR/pr-metadata.backup.json"
   ```

2. **Write the generated title and body with the runtime's native file-write capability.** Keep generated Markdown out of the shell parser.
   - `$PR_TITLE_FILE` — the conventional-commit title, single line, no trailing newline.
   - `$PR_BODY_FILE` — the full description Markdown.

   Require both paths to be regular, non-symlink files after writing. Do not use shell interpolation or a heredoc to write generated content.

3. **Back up every field the update replaces, then apply the edit.** A backup failure is a hard stop; do not silently publish without recovery data. JSON preserves an empty body as valid data.

   ```bash
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

**After updating**, confirm success and include the private backup path:

```text
PR updated successfully.

URL: {pr-url}
Title: {title}
Previous PR metadata backed up to: {PR_BACKUP}
```

**If backup or update fails**, fall back to presenting the description for copy-paste and show the error. Keep the private backup when it was created so the prior title and body remain recoverable.
