# Hook Reference

Detailed documentation for each hook. See the [README](../README.md#hooks) for a summary.

## Toggling Hooks

Use `/kramme:hooks:toggle` to enable or disable hooks:

```bash
# List all hooks and their status
/kramme:hooks:toggle status

# Disable a hook
/kramme:hooks:toggle auto-format disable

# Enable a hook
/kramme:hooks:toggle auto-format enable

# Toggle a hook (enable if disabled, disable if enabled)
/kramme:hooks:toggle auto-format

# Reset all hooks to enabled
/kramme:hooks:toggle reset
```

State is stored in `hooks/hook-state.json` (gitignored) and persists across sessions.
When a hook is disabled, the hook script drains stdin before exiting to avoid broken-pipe errors if the runner is piping JSON input.

For `confirm-review-responses`, edit `hooks/confirm-review-artifacts.txt` to configure which staged files should trigger confirmation.

## context-links Configuration

`context-links` supports org-specific configuration via environment variables or an optional config file.

```bash
# Optional: create local hook config overrides
cp hooks/context-links.config.example hooks/context-links.config
```

You can also configure this via skill:

```bash
/kramme:hooks:configure-links show
/kramme:hooks:configure-links CONTEXT_LINKS_LINEAR_WORKSPACE_SLUG=acme
/kramme:hooks:configure-links CONTEXT_LINKS_LINEAR_TEAM_KEYS=ENG,OPS,PLAT
```

Supported variables:
- `CONTEXT_LINKS_LINEAR_WORKSPACE_SLUG` - Linear workspace slug used in issue URLs (default: `consensusaps`)
- `CONTEXT_LINKS_LINEAR_TEAM_KEYS` - Comma/space separated team keys used for branch parsing (default: `WAN,HEA,MEL,POT,FIR,FEG`)
- `CONTEXT_LINKS_LINEAR_ISSUE_REGEX` - Optional regex override for issue extraction (takes precedence over team keys)
- `CONTEXT_LINKS_GITLAB_REMOTE_REGEX` - Regex used to identify GitLab remotes (default: `(gitlab\\.com|consensusaps)`)
- `CONTEXT_LINKS_CONFIG_FILE` - Optional path to a config file (default: `${CLAUDE_PLUGIN_ROOT}/hooks/context-links.config`)

## block-rm-rf

### Blocked Patterns

**Direct commands:**
- `rm -rf` (and variants: `-fr`, `-r -f`, `--recursive --force`)
- `shred`, `unlink`

**Path variants:**
- `/bin/rm -rf`, `/usr/bin/rm -rf`, `./rm -rf`

**Bypass attempts:**
- `command rm -rf`, `env rm -rf`, `\rm -rf`
- `sudo rm -rf`, `xargs rm -rf`

**Subshell execution:**
- `sh -c "rm -rf ..."`, `bash -c "rm -rf ..."`, `zsh -c "rm -rf ..."`

**Find commands:**
- `find . -delete`
- `find . -exec rm -rf {} \;`

### Allowed Commands

- `git rm` (tracked by git, recoverable)
- `echo "rm -rf"` (quoted strings are safe)
- `rm file.txt` (no recursive+force)
- `rm -r dir/` (recursive but no force)

### Why use `trash` instead of `rm -rf`?

The `trash` command moves files to the system Trash instead of permanently deleting them:
- **Recoverable**: Files can be restored from Trash if deleted accidentally
- **Safe**: No risk of catastrophic data loss from typos or glob expansion errors
- **Familiar**: Works just like `rm` but with a safety net

Install: `brew install trash`

> **Note:** This is a best-effort defense, not a comprehensive security barrier. There will always be edge cases that aren't covered.

## noninteractive-git

Blocks git commands that would open an interactive editor, forcing the agent to use non-interactive alternatives:

| Command | Blocked When | Non-Interactive Alternative |
|---------|--------------|----------------------------|
| `git commit` | Missing message source (`-m`/`--message`/`-C`/`--reuse-message`/`-F`/`--file`) and no `--no-edit` (`-c`/`--reedit-message` still block) | `git commit -m "message"` or `git commit --amend --no-edit` |
| `git rebase -i` | Missing `GIT_SEQUENCE_EDITOR=` | `GIT_SEQUENCE_EDITOR=true git rebase -i ...` |
| `git rebase --continue` | Missing `GIT_EDITOR=` | `GIT_EDITOR=true git rebase --continue` |
| `git add -p` / `-i` | Always | `git add <explicit-files>` |
| `git merge` | Missing `--no-edit`/`--no-commit`/`--squash`/`--ff`/`--ff-only` and not a control flow (`--abort`/`--quit`) | `git merge --no-edit <branch>` or `git merge --abort` |
| `git cherry-pick` | Missing `--no-edit`/`--no-commit`/`-n` and not a control flow (`--continue`/`--abort`/`--skip`/`--quit`) | `git cherry-pick --no-edit <commit>` or `git cherry-pick --continue` |

## auto-format

### Supported Formatters

| Language | Formatter | Detection |
|----------|-----------|-----------|
| JavaScript/TypeScript | Prettier | `"prettier"` in package.json |
| JavaScript/TypeScript | Biome | `"@biomejs/biome"` in package.json |
| CSS/SCSS/JSON/HTML/MD | Prettier | `"prettier"` in package.json |
| Python | Black | `black` in pyproject.toml |
| Python | Ruff | `ruff` in pyproject.toml |
| Go | gofmt | go.mod exists |
| Rust | rustfmt | Cargo.toml exists |
| C# | dotnet format | *.csproj exists |
| Shell | shfmt | globally available |
| Nx workspace | nx format | nx.json exists |

**Priority**: CLAUDE.md override > Biome > Prettier > global tools

### CLAUDE.md Override

Add a format directive to your project's CLAUDE.md to specify a custom formatter:

```markdown
format: bun run format
```

Or use the `formatter:` key:

```markdown
formatter: npm run format
```

### Caching

Detection results are cached in `/tmp/claude-format-cache/` to avoid re-scanning project files on every write. The cache is automatically invalidated when any of these files change:

- `CLAUDE.md`, `package.json`, `pyproject.toml`, `nx.json`, `go.mod`, `Cargo.toml`

To clear the cache manually: `trash /tmp/claude-format-cache`

### Skipped Files

The hook automatically skips:

- **Binary files**: png, jpg, pdf, zip, exe, dll, woff, etc.
- **Generated directories**: node_modules/, dist/, build/, .git/, vendor/, __pycache__/, coverage/
- **Lock files**: *.lock, package-lock.json, pnpm-lock.yaml
- **Source maps**: *.map
- **Minified files**: *.min.js, *.min.css
