# Direct PR Update

Use this when `DIRECT_UPDATE=true`.

**Skip copy-paste output and save-to-file prompt.** Use this sequence to avoid both shell-interpolation and heredoc-terminator collisions in LLM-generated content:

1. **Anchor to repo root and prepare the workspace directory.** Run this bash block first:

   ```bash
   REPO_ROOT=$(git rev-parse --show-toplevel)
   BACKUP_DIR="$REPO_ROOT/.kramme-cc-workflow/pr-description"
   mkdir -p "$BACKUP_DIR"
   
   # Ensure the namespace is locally excluded so backups and saved descriptions are
   # not accidentally committed. Use git's local exclude file; do not mutate tracked files.
   GIT_EXCLUDE=$(git rev-parse --git-path info/exclude)
   mkdir -p "$(dirname "$GIT_EXCLUDE")"
   touch "$GIT_EXCLUDE"
   if ! grep -qxF ".kramme-cc-workflow/" "$GIT_EXCLUDE"; then
     printf '\n.kramme-cc-workflow/\n' >> "$GIT_EXCLUDE"
   fi
   
   # Snapshot the prior PR body. Real failure leaves no backup; empty backup is discarded.
   PR_BACKUP="$BACKUP_DIR/pr-body.backup.$(date -u +%Y%m%dT%H%M%SZ).$$.md"
   gh pr view --json body --jq '.body' > "$PR_BACKUP" 2> /dev/null
   if [ ! -s "$PR_BACKUP" ]; then
     PR_BACKUP=""
   fi
   echo "BACKUP_DIR=$BACKUP_DIR"
   echo "PR_BACKUP=${PR_BACKUP:-<none>}"
   ```

2. **Write the generated title and body to files using the runtime's file-write capability, keeping generated Markdown out of the shell parser.** Targets:
   - `$BACKUP_DIR/new-title.txt` - the conventional-commit title, single line, no trailing newline.
   - `$BACKUP_DIR/new-body.md` - the full description markdown.

   Prefer a native file-write/edit capability. If unavailable, use an equivalent safe file-write method that does not pass generated Markdown through shell interpolation or a heredoc.

3. **Apply the edit:**

   ```bash
   gh pr edit \
     --title "$(cat "$BACKUP_DIR/new-title.txt")" \
     --body-file "$BACKUP_DIR/new-body.md"
   ```

   - `"$(cat ...)"` substitutes the literal file contents into one argv element; `gh` does not re-evaluate the argument as shell.
   - `--body-file` reads the body straight from disk; nothing in it flows through the shell.

**After updating**, confirm success. Include the backup line only when a backup actually exists:

```
PR updated successfully.

URL: {pr-url}
Title: {title}
{when PR_BACKUP is non-empty: "Previous body backed up to: {PR_BACKUP}"}
```

**If the update fails**, fall back to presenting the description for copy-paste and show the error.
