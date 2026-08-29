# Hook Reference

Detailed documentation for each hook. See the root [README](../../README.md#hooks) for a summary.

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

State is stored in `${XDG_STATE_HOME:-$HOME/.local/state}/kramme-cc-workflow/hook-state.json` by default, with `KRAMME_HOOK_STATE_FILE` override support and legacy fallback to `hooks/hook-state.json`. When a hook is disabled, the hook script drains stdin before exiting to avoid broken-pipe errors if the runner is piping JSON input.

For `confirm-review-responses`, edit `hooks/confirm-review-artifacts.txt` to configure which staged files should trigger confirmation. Entries support shell-style glob patterns, so generated artifacts like `PR_PLAN_*.md` can be guarded without listing every file explicitly.

## Codex Hook Command Support

Current generated Codex hook commands are POSIX shell command strings. Windows compatibility is not promised until `commandWindows` support is added to the converter and covered by tests.

Generated bootstrap code does not read from stdin. Hooks that parse or drain JSON input expect the runner to close stdin after writing the payload; a deliberately open pipe is outside the broad non-hang contract for those hook bodies.

## Bash Hook Invocation Benchmark

Run the reusable process-level benchmark for the three hooks registered against the `Bash` matcher:

```bash
./scripts/benchmark-hook-overhead.sh
./scripts/benchmark-hook-overhead.sh --iterations 50 --warmups 5
```

The benchmark uses temporary hook-state files to run enabled and disabled arms through the normal toggle mechanism. It launches the three hook processes concurrently to mirror [Claude Code's matching-hook execution model](https://code.claude.com/docs/en/hooks#hook-handler-fields) and measures them for `echo hi` and `git status --short`; it does not include the hook dispatcher or execution of the user's command. Samples are interleaved, and added gating overhead is the median of the paired enabled-minus-disabled samples.

### 2026-07-29 measurement and decision

The baseline and optimized versions were each measured twice with 30 samples per arm after three warmups on an x86_64 Vercel cloud sandbox running Linux 6.12.76 with glibc 2.34 and Python 3.11.15. The bare `python3 -c pass` startup median was 8.9-9.5 ms. Values below are the ranges across the two consecutive runs:

| Command | Version | Enabled parallel set | Disabled parallel set | Added gating overhead |
| --- | --- | --: | --: | --: |
| `echo hi` | Before | 62.981-64.495 ms | 6.573-6.962 ms | 56.013-57.814 ms |
| `echo hi` | After | 48.402-50.104 ms | 7.024-7.078 ms | 41.249-42.447 ms |
| `git status --short` | Before | 63.428-64.167 ms | 7.017-7.098 ms | 56.135-57.182 ms |
| `git status --short` | After | 48.843-49.459 ms | 6.643-6.697 ms | 42.021-42.035 ms |

The default acceptance threshold was 150 ms of median added gating latency. The corrected parallel baseline was already below that threshold for both command shapes; the earlier serial experiment had incorrectly summed three handlers that Claude Code runs concurrently. Component timing still showed no dominant hook: all three baseline hooks took roughly 55-60 ms.

The shared safety wrapper now launches the parser as the `git_command_parser` module from its own directory with an explicit `PYTHONPATH=.`, allowing normal Python bytecode caching while preventing safe-path mode or an inherited module path from redirecting the import. The repeated measurement reduced steady-state added gating latency by roughly 24-29%. The 174 `block-rm-rf` cases, 149 `noninteractive-git` cases, the parallel benchmark contract test, and manual missing-`python3` checks continued to block or allow the expected commands.

## skill-usage-stats

`skill-usage-stats` records local JSONL usage events when a prompt contains a `/kramme:*` skill invocation or when a Skill tool event names a `kramme:*` skill.

Records are stored outside the repository at:

```text
~/.local/state/kramme-cc-workflow/skill-usage.jsonl
```

Set `KRAMME_SKILL_USAGE_FILE` to override the path, for example in tests or when keeping separate per-platform stats.

Generate a report:

```bash
node scripts/skill-usage.js report --since 30d
node scripts/skill-usage.js report --kind explicit --json
node scripts/skill-usage.js report --json --strict
```

Scan existing transcript files for historical explicit invocations:

```bash
node scripts/skill-usage.js scan ~/.claude/projects --json
```

Reports and scans tolerate degraded input by default. They retain valid totals, write skipped-line and read-failure diagnostics to stderr, and exit successfully. Healthy `--json` output remains an array. When diagnostics occur, JSON output is an object with `summary` and `diagnostics` fields instead. Add `--strict` to render the same result but exit nonzero when any input was skipped or could not be read. Individual JSONL records larger than 1 MiB are skipped with diagnostics so malformed or truncated lines cannot make memory use unbounded.

Scan treats JSONL as its canonical streaming format. Whole-document JSON and plaintext use a compatibility fallback limited to 1 MiB per file. Larger non-JSONL files are skipped with diagnostics; `--strict` makes that condition fail the command after rendering the degraded result.

The hook is silent and fail-open. If Node.js is unavailable, if the payload cannot be parsed, or if recording fails, the hook returns `{}` and does not block the session.

## context-links Configuration

`context-links` supports org-specific configuration via environment variables or an optional config file.

```bash
# Optional: create local hook config overrides
mkdir -p "${XDG_CONFIG_HOME:-$HOME/.config}/kramme-cc-workflow"
cp hooks/context-links.config.example "${XDG_CONFIG_HOME:-$HOME/.config}/kramme-cc-workflow/context-links.config"
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
- `CONTEXT_LINKS_CONFIG_FILE` - Optional path to a config file (default: `${XDG_CONFIG_HOME:-$HOME/.config}/kramme-cc-workflow/context-links.config`, with legacy fallback to `${CLAUDE_PLUGIN_ROOT}/hooks/context-links.config`)

## block-rm-rf

`block-rm-rf` requires both `jq` and `python3` at runtime. If either binary is missing, the hook fails closed and blocks the Bash tool call until the dependency is installed or the hook is explicitly disabled.

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

### Analysis Bound

The hook follows supported nested shell commands, `eval`, shell functions, executable heredocs, and command/process substitutions through analysis depth 5. A command that would require deeper analysis is blocked with the generic `rm -rf` reason, even when the hidden payload would ultimately be safe. This fail-closed bound prevents extra nesting from turning an unclassified destructive command into an allow decision; simplify an over-nested command so the hook can classify it.

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
| --- | --- | --- |
| `git commit` | Missing message source (`-m`/`--message`/`-C`/`--reuse-message`/`-F`/`--file`) and no `--no-edit` (`-c`/`--reedit-message` still block) | `git commit -m "message"` or `git commit --amend --no-edit` |
| `git rebase -i` | Missing `GIT_SEQUENCE_EDITOR=` | `GIT_SEQUENCE_EDITOR=true git rebase -i ...` |
| `git rebase --continue` | Missing `GIT_EDITOR=` | `GIT_EDITOR=true git rebase --continue` |
| `git add -p` / `-i` | Always | `git add <explicit-files>` |
| `git merge` | Missing `--no-edit`/`--no-commit`/`--squash`/`--ff`/`--ff-only` and not a control flow (`--abort`/`--quit`) | `git merge --no-edit <branch>` or `git merge --abort` |
| `git cherry-pick` | Missing `--no-edit`/`--no-commit`/`-n` and not a control flow (`--continue`/`--abort`/`--skip`/`--quit`) | `git cherry-pick --no-edit <commit>` or `git cherry-pick --continue` |

## auto-format

### Supported Formatters

| Language              | Formatter     | Detection                          |
| --------------------- | ------------- | ---------------------------------- |
| JavaScript/TypeScript | Prettier      | `"prettier"` in package.json       |
| JavaScript/TypeScript | Biome         | `"@biomejs/biome"` in package.json |
| CSS/SCSS/JSON/HTML/MD | Prettier      | `"prettier"` in package.json       |
| Python                | Black         | `black` in pyproject.toml          |
| Python                | Ruff          | `ruff` in pyproject.toml           |
| Go                    | gofmt         | go.mod exists                      |
| Rust                  | rustfmt       | Cargo.toml exists                  |
| C#                    | dotnet format | \*.csproj exists                   |
| Shell                 | shfmt         | globally available                 |
| Nx workspace          | nx format     | nx.json exists                     |

**Priority**: trusted CLAUDE.md override > Biome > Prettier > global tools

### CLAUDE.md Override

Add a format directive to your project's CLAUDE.md to specify a custom formatter:

```markdown
format: bun run format
```

Or use the `formatter:` key:

```markdown
formatter: npm run format
```

Because this directive is executable project-controlled code, the hook only runs it when the project root is listed in a user-side trust file outside the repository.

Default trust file: `${XDG_CONFIG_HOME:-$HOME/.config}/kramme-cc-workflow/autoformat-trusted-roots`

Override the trust file location with `KRAMME_AUTOFORMAT_TRUST_FILE`.

The trust file format is one absolute project root per line. Blank lines and `#` comments are ignored:

```text
# auto-format trusts
/Users/me/src/my-project
```

If a CLAUDE.md directive exists but the project is not trusted, the hook skips that directive, falls through to detected formatters, and reports how to enable the directive in the system message. Project-wide npm format scripts are also skipped in this case because they are executable project-controlled code.

### Caching

Detection results are cached in `${XDG_CACHE_HOME:-$HOME/.cache}/claude-format` to avoid re-scanning project files on every write. The cache is automatically invalidated when any of these files change:

- `CLAUDE.md`, `package.json`, `pyproject.toml`, `nx.json`, `go.mod`, `Cargo.toml`

To clear the default cache manually: `trash ~/.cache/claude-format`

If you install or remove a global formatter binary after the first run, clear the cache manually unless one of the watched project config files also changed.

### Skipped Files

The hook automatically skips:

- **Binary files**: png, jpg, pdf, zip, exe, dll, woff, etc.
- **Generated directories**: node_modules/, dist/, build/, .git/, vendor/, **pycache**/, coverage/
- **Lock files**: \*.lock, package-lock.json, pnpm-lock.yaml
- **Source maps**: \*.map
- **Minified files**: _.min.js, _.min.css
