# kramme-cc-workflow

A Claude Code plugin providing tooling for daily workflow tasks. These are the Claude Code components I use in my daily workflow, developed for my personal use and shared here for inspiration. They may not suit everyone's needs or preferences — feel free to adapt them to your own workflow, or use them as a starting point for your own components.

## Table of Contents

- [Commands](#commands)
- [Agents](#agents)
- [Skills](#skills)
- [Hooks](#hooks)
  - [Toggling Hooks](#toggling-hooks)
  - [block-rm-rf: Blocked Patterns](#block-rm-rf-blocked-patterns)
  - [block-rm-rf: Allowed Commands](#block-rm-rf-allowed-commands)
  - [Why use `trash` instead of `rm -rf`?](#why-use-trash-instead-of-rm--rf)
  - [noninteractive-git: Blocked Commands](#noninteractive-git-blocked-commands)
  - [auto-format: Supported Formatters](#auto-format-supported-formatters)
  - [auto-format: CLAUDE.md Override](#auto-format-claudemd-override)
  - [auto-format: Caching](#auto-format-caching)
  - [auto-format: Skipped Files](#auto-format-skipped-files)
- [Contributing](#contributing)
  - [PR Title Format](#pr-title-format)
- [Testing](#testing)
  - [Setup](#setup)
  - [Running Tests](#running-tests)
  - [Test Structure](#test-structure)
- [Installation & Updating](#installation--updating)
  - [Installation](#installation)
  - [OpenCode + Codex (experimental)](#opencode--codex-experimental)
  - [Updating](#updating)
- [Suggested Permissions](#suggested-permissions)
  - [Core](#core)
  - [Extended](#extended)
- [Recommended MCP Servers](#recommended-mcp-servers)
  - [Linear](#linear)
  - [Context7](#context7)
  - [Nx MCP](#nx-mcp)
  - [Chrome DevTools](#chrome-devtools)
  - [Claude in Chrome](#claude-in-chrome)
  - [Playwright](#playwright)
- [Recommended CLIs](#recommended-clis)
  - [Required](#required)
  - [Verification & Build](#verification--build)
  - [Utilities](#utilities)
- [Plugin Structure](#plugin-structure)
- [Adding Components](#adding-components)
  - [Commands](#commands-1)
  - [Agents](#agents-1)
  - [Skills](#skills-1)
  - [Hooks](#hooks-1)
- [Documentation](#documentation)
- [Releases](#releases)
- [Attribution](#attribution)
- [License](#license)

## Commands

| Command | Description |
|---------|-------------|
| `/kramme:clean-up-artifacts` | Delete workflow artifacts (REVIEW_RESPONSES.md, LOG.md, OPEN_ISSUES.md, specification files). |
| `/kramme:find-bugs` | Find bugs, security vulnerabilities, and code quality issues in branch changes. Performs systematic security review with attack surface mapping and checklist-based analysis. |
| `/kramme:create-pr` | Create a clean PR with narrative-quality commits and comprehensive description. Orchestrates branch setup, commit restructuring, and PR creation. |
| `/kramme:fixup-changes` | Intelligently fixup unstaged changes into existing commits. Maps each changed file to its most recent commit, validates, creates fixup commits, and autosquashes. |
| `/kramme:define-linear-issue` | Create or improve a Linear issue through exhaustive guided refinement. Can start from scratch or refine an existing issue by ID. Supports file references for context. |
| `/kramme:implement-linear-issue` | Start implementing a Linear issue with branch setup, context gathering, and guided workflow. Fetches issue details, explores codebase for patterns, asks clarifying questions, and creates the recommended branch. |
| `/kramme:deslop` | Remove AI-generated code slop from a branch. Uses `kramme:deslop-reviewer` agent to identify slop, then fixes the issues. |
| `/kramme:humanize-text` | Humanize provided text or file content using the `kramme:humanize-text` skill. |
| `/kramme:verify` | Run verification checks (tests, formatting, builds, linting, type checking) for affected code. Automatically detects project type and runs appropriate commands. |
| `/kramme:iterate-pr` | Iterate on a PR until CI passes. Automates the feedback-fix-push-wait cycle for both GitHub and GitLab. |
| `/kramme:rebase-pr` | Rebase current branch onto latest main/master, then force push. Use when your PR is behind the base branch. |
| `/kramme:recreate-commits` | Recreate current branch in-place with narrative-quality commits and logical, reviewer-friendly commit history. |
| `/kramme:resolve-review-findings` | Resolve findings from code reviews. Evaluates each finding for scope and validity, implements fixes, and generates a response document. |
| `/kramme:explore-interview` | Conduct an in-depth interview about a topic/proposal to uncover requirements. Uses structured questioning to explore features, processes, or architecture decisions. |
| `/kramme:extract-learnings` | Extract non-obvious learnings from session to AGENTS.md files. Presents suggestions for approval before making changes. |
| `/kramme:review-pr` | Run comprehensive PR review using specialized agents. Supports reviewing comments, tests, errors, types, and code quality. Can run agents sequentially or in parallel. |
| `/kramme:granola-meeting-notes` | Query meeting notes from Granola (macOS, Windows; Windows is untested). Supports fuzzy search, pattern analysis, transcript stats, and markdown export. |
| `/kramme:toggle-hook` | Enable or disable a plugin hook. Use `status` to list all hooks, or specify a hook name to toggle. |

## Agents

Specialized subagents for PR review tasks. These are invoked by the `/kramme:review-pr` command or can be used directly via the Task tool.

| Agent | Description |
|-------|-------------|
| `kramme:code-reviewer` | Reviews code for bugs, style violations, and CLAUDE.md compliance. Uses confidence scoring (0-100) to filter issues. |
| `kramme:code-simplifier` | Simplifies code for clarity and maintainability while preserving functionality. Applies project standards automatically. |
| `kramme:design-iterator` | Iterative UI/UX design refinement. Takes screenshots, analyzes issues, implements improvements, and repeats N times. Use proactively when design changes don't come together on the first attempt. |
| `kramme:comment-analyzer` | Analyzes code comments for accuracy, completeness, and long-term maintainability. Guards against comment rot. |
| `kramme:deslop-reviewer` | Detects AI-generated code patterns ("slop"). Operates in two modes: code review (scans PR diff) and meta-review (validates other agents' suggestions won't introduce slop). |
| `kramme:pr-relevance-validator` | Validates that review findings are actually caused by the PR. Filters pre-existing issues and out-of-scope problems to prevent scope creep. |
| `kramme:pr-test-analyzer` | Reviews test coverage quality and completeness. Focuses on behavioral coverage and critical gaps. |
| `kramme:silent-failure-hunter` | Identifies silent failures, inadequate error handling, and inappropriate fallbacks. Zero tolerance for swallowed errors. |
| `kramme:type-design-analyzer` | Analyzes type design for encapsulation, invariant expression, usefulness, and enforcement. Rates each dimension 1-10. |
| `kramme:architecture-strategist` | Analyzes code changes from an architectural perspective. Reviews system design decisions, evaluates component boundaries, and ensures alignment with established patterns. |
| `kramme:performance-oracle` | Analyzes code for performance issues, bottlenecks, and scalability. Covers algorithmic complexity, database queries, memory management, caching, and network optimization. |

## Skills

Skills are auto-triggered based on context. Claude will invoke these automatically when the described conditions are met.

| Skill | Trigger Condition |
|-------|-------------------|
| `kramme:agents-md` | Add guidelines to AGENTS.md with structured, keyword-based documentation. Triggers on "update AGENTS.md", "add to AGENTS.md", "maintain agent docs" |
| `kramme:changelog-generator` | Create engaging daily/weekly changelogs from recent merges to main, with contributor shoutouts and audience-aware formatting |
| `kramme:commit` | Creating commits or writing commit messages (plain English, no conventional commits) |
| `kramme:granola-meeting-notes` | Query Granola meetings (macOS, Windows; Windows is untested) with fuzzy search, pattern analysis, transcript stats, and export. Triggers on "meetings", "who do I meet with", "meeting patterns" |
| `kramme:connect-existing-feature-documentation-writer` | Creating or updating documentation for Connect features |
| `kramme:connect-migrate-legacy-store-to-ngrx-component-store` | Migrating legacy CustomStore/FeatureStore to NgRx ComponentStore in Connect monorepo |
| `kramme:connect-extract-to-nx-libraries` | Extracting app code from `apps/connect/` into proper Nx libraries |
| `kramme:connect-modernize-legacy-angular-component` | Modernizing legacy Angular components in Connect monorepo |
| `kramme:humanize-text` | Remove signs of AI-generated writing from text to make it sound more natural and human-written |
| `kramme:markdown-converter` | Converting documents (PDF, Word, Excel, images, audio, etc.) to Markdown using markitdown |
| `kramme:pr-description-generator` | Generating PR descriptions by analyzing git changes, commit history, and Linear issues |
| `kramme:recreate-commits` | Recreating the current branch in-place with narrative-quality commits |
| `kramme:structured-implementation-workflow` | Detecting LOG.md and OPEN_ISSUES.md files to track complex implementations. Uses progressive disclosure - loads lean core (~120 lines) with phase-specific resources read on-demand |
| `kramme:verification-before-completion` | About to claim work is complete/fixed/passing - requires evidence before assertions |

## Hooks

Event handlers that run automatically at specific points in the Claude Code lifecycle.

| Hook | Event | Description |
|------|-------|-------------|
| `block-rm-rf` | PreToolUse (Bash) | Blocks destructive file deletion commands and recommends using `trash` CLI instead. |
| `confirm-review-responses` | PreToolUse (Bash) | Confirms before committing REVIEW_RESPONSES.md to prevent accidental inclusion in commits. |
| `noninteractive-git` | PreToolUse (Bash) | Blocks git commands that would open an interactive editor, guiding the agent to use non-interactive alternatives. |
| `context-links` | Stop | Displays active PR/MR and Linear issue links at the end of messages. Extracts Linear issue ID from branch name (pattern: `{prefix}/{TEAM-ID}-description`) and detects open PRs/MRs for the current branch. |
| `auto-format` | PostToolUse (Write\|Edit) | Auto-formats code after file modifications. Detects project formatter from CLAUDE.md or auto-detects from project files (package.json, pyproject.toml, etc.). |

### Toggling Hooks

Use `/kramme:toggle-hook` to enable or disable hooks:

```bash
# List all hooks and their status
/kramme:toggle-hook status

# Disable a hook
/kramme:toggle-hook auto-format disable

# Enable a hook
/kramme:toggle-hook auto-format enable

# Toggle a hook (enable if disabled, disable if enabled)
/kramme:toggle-hook auto-format

# Reset all hooks to enabled
/kramme:toggle-hook reset
```

State is stored in `hooks/hook-state.json` (gitignored) and persists across sessions.
When a hook is disabled, the hook script drains stdin before exiting to avoid broken-pipe errors if the runner is piping JSON input.

### block-rm-rf: Blocked Patterns

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

### block-rm-rf: Allowed Commands

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

### noninteractive-git: Blocked Commands

Blocks git commands that would open an interactive editor, forcing the agent to use non-interactive alternatives:

| Command | Blocked When | Non-Interactive Alternative |
|---------|--------------|----------------------------|
| `git commit` | Missing `-m`/`--message`/`-C`/`-F` | `git commit -m "message"` |
| `git rebase -i` | Missing `GIT_SEQUENCE_EDITOR=` | `GIT_SEQUENCE_EDITOR=true git rebase -i ...` |
| `git rebase --continue` | Missing `GIT_EDITOR=` | `GIT_EDITOR=true git rebase --continue` |
| `git add -p` / `-i` | Always | `git add <explicit-files>` |
| `git merge` | Missing `--no-edit`/`--squash`/`--ff` | `git merge --no-edit <branch>` |
| `git cherry-pick` | Missing `--no-edit`/`-n` | `git cherry-pick --no-edit <commit>` |

### auto-format: Supported Formatters

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

### auto-format: CLAUDE.md Override

Add a format directive to your project's CLAUDE.md to specify a custom formatter:

```markdown
format: bun run format
```

Or use the `formatter:` key:

```markdown
formatter: npm run format
```

### auto-format: Caching

Detection results are cached in `/tmp/claude-format-cache/` to avoid re-scanning project files on every write. The cache is automatically invalidated when any of these files change:

- `CLAUDE.md`, `package.json`, `pyproject.toml`, `nx.json`, `go.mod`, `Cargo.toml`

To clear the cache manually: `rm -rf /tmp/claude-format-cache/`

### auto-format: Skipped Files

The hook automatically skips:

- **Binary files**: png, jpg, pdf, zip, exe, dll, woff, etc.
- **Generated directories**: node_modules/, dist/, build/, .git/, vendor/, __pycache__/, coverage/
- **Lock files**: *.lock, package-lock.json, pnpm-lock.yaml
- **Source maps**: *.map
- **Minified files**: *.min.js, *.min.css

## Contributing

### PR Title Format

PR titles must follow [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>)?: <description>
```

**Types:** `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`

**Examples:**
- `feat: add new skill for code review`
- `fix(hooks): resolve context detection issue`
- `docs: update installation instructions`

The PR title becomes the merge commit message and is used for automatic changelog generation.

## Testing

The hooks are tested using [BATS](https://github.com/bats-core/bats-core) (Bash Automated Testing System). The test suite also requires `jq` for JSON parsing in hooks.

### Setup

```bash
# Install test dependencies
make install-test-deps
```

### Running Tests

```bash
# Run all tests
make test

# Run with verbose output (show test names)
make test-verbose

# Run only block-rm-rf tests
make test-block

# Run only context-links tests
make test-context

# Run only auto-format tests
make test-format
```

### Test Structure

```
tests/
├── run-tests.sh              # Main test runner
├── test_helper/
│   ├── common.bash           # Shared utilities
│   └── mocks/                # Mock git, gh, glab commands
├── block-rm-rf.bats          # Tests for block-rm-rf hook
├── context-links.bats        # Tests for context-links hook
└── auto-format.bats          # Tests for auto-format hook
```

## Installation & Updating

### Installation

Marketplace install (recommended):

```bash
claude /plugin marketplace add Abildtoft/kramme-cc-workflow
claude /plugin install kramme-cc-workflow@kramme-cc-workflow
```

Direct Git install:

```bash
claude /plugin install git+https://github.com/Abildtoft/kramme-cc-workflow
```

For local development:

```bash
claude /plugin install /path/to/kramme-cc-workflow
```

### OpenCode + Codex (experimental)

This repo includes a converter CLI (Node.js) that installs the plugin into OpenCode or Codex.
Requires Node.js 18+. Use the plugin name from `.claude-plugin/marketplace.json` (here: `kramme-cc-workflow`).

```bash
# OpenCode
node scripts/convert-plugin.js install kramme-cc-workflow --to opencode

# Codex
node scripts/convert-plugin.js install kramme-cc-workflow --to codex
```

Run with npx (no clone):

```bash
# OpenCode
npx --yes github:Abildtoft/kramme-cc-workflow install kramme-cc-workflow --to opencode

# Codex
npx --yes github:Abildtoft/kramme-cc-workflow install kramme-cc-workflow --to codex
```

Local dev from this repo:

```bash
./scripts/install-opencode.sh
./scripts/install-codex.sh
```

Helper scripts forward additional args to the converter (e.g., `--output`, `--codex-home`, `--also codex`).

OpenCode output defaults to `~/.config/opencode` (XDG). Codex output defaults to `~/.codex` (`prompts/` and `skills/`).
Both targets are experimental and may change as the formats evolve.

### Updating

For marketplace installs:

```bash
claude /plugin marketplace update kramme-cc-workflow
```

For Git or local installs, re-run the install command to pull the latest version:

```bash
# Git install
claude /plugin install git+https://github.com/Abildtoft/kramme-cc-workflow

# Local development
claude /plugin install /path/to/kramme-cc-workflow
```

For OpenCode/Codex installs, updating is the same as installing: re-run the converter to regenerate the output (use the commands in the OpenCode + Codex section). This overwrites the generated files in `~/.config/opencode` or `~/.codex`.

Restart Claude Code after updating for changes to take effect.

**Auto-update:** Since Claude Code v2.0.70, auto-update can be enabled per-marketplace.

## Suggested Permissions

For the best experience with this plugin, add these permissions to your Claude Code `settings.json`. This reduces approval prompts for common operations.

### Core

Safe permissions for status checks and analysis only:

```json
{
  "permissions": {
    "allow": [
      "Bash(git status *)",
      "Bash(git diff *)",
      "Bash(git log *)",
      "Bash(git branch *)",
      "Bash(git rev-parse *)",
      "Bash(git show *)",
      "Bash(git show-ref *)",
      "Bash(git show-branch *)",
      "Bash(git ls-files *)",
      "Bash(git ls-remote *)",
      "Bash(git remote *)",
      "Bash(git symbolic-ref *)",
      "Bash(git symbolic-ref * | sed *)",
      "Bash(git merge-base *)",
      "Bash(git rev-list *)",
      "Bash(gh pr view *)",
      "Bash(gh pr checks *)",
      "Bash(gh pr diff *)",
      "Bash(gh run list *)",
      "Bash(gh run view *)",
      "Bash(glab mr view *)",
      "Bash(glab mr list *)",
      "Bash(glab ci status *)",
      "Bash(glab ci list *)",
      "Bash(glab ci view *)",
      "mcp__linear__get_issue",
      "mcp__linear__list_issues",
      "mcp__linear__list_comments",
      "mcp__linear__list_teams",
      "mcp__linear__get_team",
      "mcp__linear__list_projects",
      "mcp__linear__get_project",
      "mcp__linear__list_issue_labels",
      "mcp__linear__list_issue_statuses",
      "mcp__linear__list_cycles",
      "mcp__linear__list_users",
      "mcp__linear__get_user",
      "mcp__linear__get_document",
      "mcp__linear__list_documents",
      "mcp__linear__search_documentation"
    ]
  }
}
```

### Extended

Additional permissions that build on Core. Enables full plugin workflows including PR creation, commit management, and verification. **Add these alongside the Core permissions above.**

> **Warning:** This set gives Claude Code significant autonomy, including destructive git operations (`git push`, `git reset`, `git rebase`). Only use these permissions on projects where you have full control, or scope them to specific projects in your settings.

```json
{
  "permissions": {
    "allow": [
      "Bash(git add *)",
      "Bash(git commit *)",
      "Bash(git checkout *)",
      "Bash(git stash *)",
      "Bash(git fetch *)",
      "Bash(git push *)",
      "Bash(git reset *)",
      "Bash(git rebase *)",
      "Bash(git branch -D *)",
      "Bash(GIT_SEQUENCE_EDITOR=true git rebase *)",
      "Bash(gh pr create *)",
      "Bash(gh api *)",
      "Bash(glab mr create *)",
      "Bash(glab mr note *)",
      "Bash(glab ci trace *)",
      "Bash(glab ci retry *)",
      "Bash(glab ci run *)",
      "Bash(glab api *)",
      "Bash(nx show *)",
      "Bash(nx affected *)",
      "Bash(nx format *)",
      "Bash(nx lint *)",
      "Bash(nx build *)",
      "Bash(nx test *)",
      "Bash(nx typecheck *)",
      "Bash(nx e2e *)",
      "Bash(nx run *)",
      "Bash(yarn exec nx *)",
      "Bash(corepack yarn nx *)",
      "Bash(dotnet restore *)",
      "Bash(dotnet build *)",
      "Bash(dotnet test *)",
      "Bash(dotnet format *)",
      "Bash(dotnet ef *)",
      "Bash(npm run test *)",
      "Bash(npm run lint *)",
      "Bash(npm run format *)",
      "Bash(npm run typecheck *)",
      "Bash(npm run build *)",
      "Bash(prettier *)",
      "Bash(eslint *)",
      "Bash(tsc *)",
      "Bash(cat package.json *)",
      "Bash(find *)",
      "mcp__gitlab__get_merge_request",
      "mcp__gitlab__create_merge_request",
      "mcp__gitlab__list_pipelines",
      "mcp__gitlab__get_pipeline",
      "mcp__gitlab__list_pipeline_jobs",
      "mcp__gitlab__get_pipeline_job_output",
      "mcp__gitlab__mr_discussions",
      "mcp__gitlab__get_branch_diffs",
      "mcp__gitlab__list_commits"
    ]
  }
}
```

## Recommended MCP Servers

These MCP servers enhance the plugin's capabilities.

| Server | Purpose |
|--------|---------|
| **Linear** | Issue tracking for `/kramme:implement-linear-issue` and `/kramme:define-linear-issue` |
| **Context7** | Up-to-date library documentation retrieval |
| **Nx MCP** | Nx monorepo tools for `/kramme:verify` in Nx workspaces |
| **Chrome DevTools** | Browser automation and debugging |
| **Claude in Chrome** | Browser automation via Chrome extension |
| **Playwright** | Browser automation for testing |

### Linear

Official [Linear MCP server](https://linear.app/docs/mcp) for issue tracking integration.

**Claude Code:**
```bash
claude mcp add-json linear '{"command": "npx", "args": ["-y","mcp-remote","https://mcp.linear.app/sse"]}'
```

**Claude Desktop / Cursor:**
```json
{
  "mcpServers": {
    "linear": {
      "command": "npx",
      "args": ["-y", "mcp-remote", "https://mcp.linear.app/mcp"]
    }
  }
}
```

Run `/mcp` in Claude Code to authenticate.

### Context7

[Context7](https://github.com/upstash/context7) provides up-to-date library documentation.

**Claude Code:**
```bash
claude mcp add context7 -s user -- npx -y @upstash/context7-mcp@latest
```

**Claude Desktop / Cursor:**
```json
{
  "mcpServers": {
    "context7": {
      "command": "npx",
      "args": ["-y", "@upstash/context7-mcp@latest"]
    }
  }
}
```

### Nx MCP

[Nx MCP](https://www.npmjs.com/package/nx-mcp) provides deep access to Nx monorepo structure.

**Claude Code:**
```bash
claude mcp add nx -s user -- npx nx-mcp@latest
```

**Claude Desktop / Cursor:**
```json
{
  "mcpServers": {
    "nx": {
      "command": "npx",
      "args": ["nx-mcp@latest"]
    }
  }
}
```

**Tip:** Run `nx init` in your workspace to auto-configure Nx MCP and generate AI agent config files.

### Chrome DevTools

[Chrome DevTools MCP](https://github.com/AiDotNet/chrome-devtools-mcp) for browser debugging and automation.

**Claude Code:**
```bash
claude mcp add chrome-devtools -s user -- npx chrome-devtools-mcp@latest
```

**Claude Desktop / Cursor:**
```json
{
  "mcpServers": {
    "chrome-devtools": {
      "command": "npx",
      "args": ["chrome-devtools-mcp@latest"]
    }
  }
}
```

### Claude in Chrome

Official [Chrome extension](https://claude.com/chrome) for browser automation via Claude Code.

**Installation:**
1. Install the [Claude in Chrome extension](https://chromewebstore.google.com/detail/claude-in-chrome) from Chrome Web Store
2. Restart Chrome after installation
3. Start Claude Code with `claude --chrome`
4. Run `/chrome` and select "Enabled by default" to skip the flag

**Requirements:** Chrome extension v1.0.36+, Claude Code v2.0.73+

### Playwright

[Playwright MCP](https://github.com/AiDotNet/playwright-mcp) for browser automation and testing.

**Claude Code:**
```bash
claude mcp add playwright -s user -- npx -y @playwright/mcp@latest
```

**Claude Desktop / Cursor:**
```json
{
  "mcpServers": {
    "playwright": {
      "command": "npx",
      "args": ["-y", "@playwright/mcp@latest"]
    }
  }
}
```

Browser binaries are installed automatically on first use.

## Recommended CLIs

CLI tools that enhance the plugin experience. Some are required for specific commands.

### Required

| CLI | Purpose | Install |
|-----|---------|---------|
| `git` | Version control (all commands) | Pre-installed on most systems |
| `gh` | GitHub PR workflows | `brew install gh` |
| `glab` | GitLab MR workflows | `brew install glab` |

### Verification & Build

| CLI | Purpose | Install |
|-----|---------|---------|
| `nx` | Nx monorepo commands | `npm install -g nx` |
| `dotnet` | .NET project verification | [dotnet.microsoft.com](https://dotnet.microsoft.com/download) |
| `prettier` | JS/TS formatting | `npm install -g prettier` |
| `eslint` | JS/TS linting | `npm install -g eslint` |
| `tsc` | TypeScript type-checking | `npm install -g typescript` |

### Utilities

| CLI | Purpose | Install |
|-----|---------|---------|
| `trash` | Safe file deletion (used by block-rm-rf hook) | `brew install trash` |
| `jq` | JSON parsing (internal use) | `brew install jq` |
| `markitdown` | Document conversion skill | `uvx markitdown` or `pip install markitdown` |

## Plugin Structure

```
kramme-cc-workflow/
├── .claude-plugin/
│   ├── plugin.json      # Plugin metadata
│   └── marketplace.json # Marketplace definition
├── commands/            # Slash commands
├── agents/              # Specialized subagents
├── skills/              # Auto-triggered skills
├── hooks/               # Event handlers
│   └── hooks.json
└── README.md
```

## Adding Components

### Commands

Create markdown files in `commands/` with this format:

```markdown
---
name: kramme:command-name
description: Brief description shown in command list
argument-hint: [optional-argument]
---
# Command Name

## Your Task
Describe what the command should do.
```

### Agents

Create markdown files in `agents/` with this format:

```markdown
---
name: kramme:agent-name
description: When and how to use this agent (shown in Task tool)
model: sonnet
color: blue
---
# Agent Name

## Mission
Describe the agent's purpose and capabilities.

## Expected Output
Describe what the agent should return.
```

### Skills

Create a subdirectory in `skills/` with a `SKILL.md` file:

```
skills/
└── my-skill/
    └── SKILL.md
```

SKILL.md format:

```markdown
---
name: my-skill
description: When to use this skill (this triggers auto-invocation)
---
# My Skill

Instructions for Claude when this skill is active.
```

### Hooks

Edit `hooks/hooks.json` to add event handlers:

```json
{
  "description": "Hook description",
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "python3 ${CLAUDE_PLUGIN_ROOT}/hooks/my_hook.py"
          }
        ]
      }
    ],
    "SessionStart": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "echo 'Session started'"
          }
        ]
      }
    ]
  }
}
```

Available hook events:
- `PreToolUse` - Before a tool is executed
- `PostToolUse` - After a tool is executed
- `SessionStart` - When Claude Code session begins
- `Stop` - When Claude attempts to stop

## Documentation

- [Plugin Documentation](https://code.claude.com/docs/en/plugins)
- [Plugins Reference](https://code.claude.com/docs/en/plugins-reference)
- [Hooks Reference](https://code.claude.com/docs/en/hooks)
- [Skills Documentation](https://code.claude.com/docs/en/skills)

## Releases

See [CHANGELOG.md](CHANGELOG.md) for version history and [GitHub Releases](https://github.com/Abildtoft/kramme-cc-workflow/releases) for release notes.

For maintainers: see [RELEASE.md](RELEASE.md) for the release process.

## Attribution

- `kramme:agents-md`: Inspired by [getsentry/skills](https://github.com/getsentry/skills/blob/main/plugins/sentry-skills/skills/agents-md/SKILL.md).
- `kramme:architecture-strategist`: Adapted from [EveryInc/compound-engineering-plugin](https://github.com/EveryInc/compound-engineering-plugin).
- `kramme:commit`: From [getsentry/skills](https://github.com/getsentry/skills/blob/main/plugins/sentry-skills/skills/commit/SKILL.md).
- `kramme:design-iterator`: Adapted from [EveryInc/compound-engineering-plugin](https://github.com/EveryInc/compound-engineering-plugin).
- `kramme:humanize-text`: Based on Wikipedia: Signs of AI writing (maintained by WikiProject AI Cleanup) and heavily inspired by [blader/humanizer](https://github.com/blader/humanizer).
- `kramme:granola-meeting-notes`: Inspired by [varadhjain/granola-claude-plugin](https://github.com/varadhjain/granola-claude-plugin) and [nehiljain/granola-ai-mcp-server](https://github.com/nehiljain/granola-ai-mcp-server).
- `kramme:performance-oracle`: From [EveryInc/compound-engineering-plugin](https://github.com/EveryInc/compound-engineering-plugin).
- OpenCode/Codex converter: Inspired by [EveryInc/compound-engineering-plugin](https://github.com/EveryInc/compound-engineering-plugin).

## License

MIT
