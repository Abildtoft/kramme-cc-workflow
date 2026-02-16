# kramme-cc-workflow

A Claude Code plugin providing tooling for daily workflow tasks. Developed for personal use and shared here for inspiration — adapt them to your own workflow, or use them as a starting point.

## Table of Contents

- [Installation & Updating](#installation--updating)
- [Skills](#skills)
- [Agents](#agents)
- [Hooks](#hooks)
- [Suggested Permissions](#suggested-permissions)
- [Recommended MCP Servers](#recommended-mcp-servers)
- [Recommended CLIs](#recommended-clis)
- [Learnings Database](#learnings-database)
- [Contributing](#contributing)
- [Testing](#testing)
- [Plugin Structure](#plugin-structure)
- [Adding Components](#adding-components)
- [Related Plugins](#related-plugins)
- [Documentation](#documentation)
- [Releases](#releases)
- [Attribution](#attribution)
- [License](#license)

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

## Skills

All plugin functionality is delivered through skills. Skills can be user-invoked via the `/` menu, auto-triggered by Claude based on context, or both.

- **User-invocable**: Trigger with `/kramme:skill-name`. Skills that should never auto-run set `disable-model-invocation: true`.
- **Auto-triggered**: Claude invokes automatically when context matches the skill description. Marked with \* below.
- **Background**: Skills with `user-invocable: false` are auto-triggered only and don't appear in the `/` menu.

### Structured Implementation Workflow (SIW)

Local issue tracking and structured implementation planning using markdown files.

| Skill | Description |
|-------|-------------|
| `/kramme:siw:init` | Initialize SIW workflow documents in `siw/`. Accepts file paths, folders, or `discover` as arguments. |
| `/kramme:siw:next` \* | SIW entry point. Triggers on "SIW", "structured workflow", or when SIW files are detected. |
| `/kramme:siw:discovery` | Run a spec-strengthening interview to identify quality gaps. |
| `/kramme:siw:issue-define` | Define a new local issue with guided interview process. |
| `/kramme:siw:phases-generate` | Break spec into atomic, phase-based issues with `P1-001`, `P2-001`, `G-001` numbering. |
| `/kramme:siw:issue-implement` | Implement a defined local issue with codebase exploration and planning. |
| `/kramme:siw:issue-implement:team` | Implement multiple issues in parallel using Agent Teams. |
| `/kramme:siw:spec-audit` | Audit spec quality before implementation. |
| `/kramme:siw:implementation-audit` | Audit codebase against specification files for drift and misalignment. |
| `/kramme:siw:audit-resolve` | Resolve audit findings one-by-one with recommended options. |
| `/kramme:siw:issues-reindex` | Remove DONE issues and renumber remaining from 001. |
| `/kramme:siw:reset` | Reset SIW state while preserving the spec. |
| `/kramme:siw:remove` | Remove all SIW files from current directory. |

### Pull Requests

| Skill | Description |
|-------|-------------|
| `/kramme:pr:create` | Create a PR with narrative-quality commits and comprehensive description. |
| `/kramme:pr:review` | Run PR review using specialized agents (sequential or parallel). |
| `/kramme:pr:review:team` | Team-based PR review where reviewers collaborate and cross-validate findings. |
| `/kramme:pr:resolve-review` | Resolve code review findings with scope validation and fix implementation. |
| `/kramme:pr:resolve-review:team` | Resolve review findings in parallel using Agent Teams. |
| `/kramme:pr:fix-ci` | Iterate on a PR until CI passes (GitHub and GitLab). |
| `/kramme:pr:generate-description` \* | Generate PR descriptions from git changes, commit history, and Linear issues. |
| `/kramme:pr:rebase` | Rebase current branch onto latest main/master and force push. |

### Learnings

Persistent knowledge management across sessions using a SQLite database. See [Learnings Database](#learnings-database) for setup.

| Skill | Description |
|-------|-------------|
| `/kramme:learnings:add` | Add a learning to the database. |
| `/kramme:learnings:extract` | Extract learnings from session to AGENTS.md files. |
| `/kramme:learnings:search` \* | Search learnings with BM25 full-text search. |
| `/kramme:learnings:list` \* | List all learnings, optionally filtered by category or project. Use `--categories` for summary or `--stats` for database statistics. |
| `/kramme:learnings:delete` | Delete learnings by ID, category, project, or age. |
| `/kramme:learnings:setup` | Initialize or verify the learnings database. |

### Code Quality

| Skill | Description |
|-------|-------------|
| `/kramme:code:cleanup-ai` | Remove AI-generated code slop from a branch. |
| `/kramme:code:rewrite-clean` | Scrap a mediocre fix and reimplement elegantly from scratch. |
| `/kramme:code:refactor-pass` \* | Lightweight simplification pass on recent changes. |

### Git

| Skill | Description |
|-------|-------------|
| `/kramme:git:fixup` | Fixup unstaged changes into existing commits with autosquash. |
| `/kramme:git:recreate-commits` | Recreate current branch with narrative-quality commit history. |

### Linear

| Skill | Description |
|-------|-------------|
| `/kramme:linear:issue-define` | Create or refine a Linear issue through guided interview. |
| `/kramme:linear:issue-implement` | Implement a Linear issue with branch setup and context gathering. |

### Discovery & Documentation

| Skill | Description |
|-------|-------------|
| `/kramme:discovery:interview` | In-depth interview about a topic to uncover requirements. |
| `/kramme:docs:to-markdown` \* | Convert documents (PDF, Word, Excel, images, audio) to Markdown. |
| `/kramme:text:humanize` \* | Remove signs of AI-generated writing from text. |

### Workflow & Configuration

| Skill | Description |
|-------|-------------|
| `/kramme:artifacts:cleanup` | Delete workflow artifacts (review reports, audit reports, SIW files). |
| `/kramme:changelog:generate` | Create changelogs from recent merges with contributor shoutouts. |
| `/kramme:hooks:configure-links` | Configure `context-links` hook settings. |
| `/kramme:hooks:toggle` | Enable or disable a plugin hook. |
| `/kramme:session:wrap-up` | End-of-session checklist for progress capture and quality checks. |
| `/kramme:verify:run` \* | Run verification checks (tests, formatting, builds, linting, type checking). |

### Background Skills

Auto-triggered by Claude based on context. These don't appear in the `/` menu.

| Skill | Trigger Condition |
|-------|-------------------|
| `kramme:docs:update-agents-md` | Add guidelines to AGENTS.md with structured, keyword-based documentation. Triggers on "update AGENTS.md", "add to AGENTS.md", "maintain agent docs" |
| `kramme:git:commit-message` | Creating commits or writing commit messages (plain English, no conventional commits) |
| `kramme:verify:before-completion` | About to claim work is complete/fixed/passing — requires evidence before assertions |

## Agents

Specialized subagents for PR review tasks. Invoked by `/kramme:pr:review` or directly via the Task tool.

| Agent | Description |
|-------|-------------|
| `kramme:code-reviewer` | Reviews code for bugs, style violations, and CLAUDE.md compliance. Uses confidence scoring (0-100) to filter issues. |
| `kramme:code-simplifier` | Simplifies code for clarity and maintainability while preserving functionality. |
| `kramme:design-iterator` | Iterative UI/UX design refinement — screenshots, analysis, improvements, repeat N times. |
| `kramme:comment-analyzer` | Analyzes code comments for accuracy, completeness, and maintainability. |
| `kramme:deslop-reviewer` | Detects AI-generated code patterns ("slop") in code review and meta-review modes. |
| `kramme:pr-relevance-validator` | Validates that review findings are caused by the PR, not pre-existing issues. |
| `kramme:pr-test-analyzer` | Reviews test coverage quality and completeness. |
| `kramme:silent-failure-hunter` | Identifies silent failures, inadequate error handling, and swallowed errors. |
| `kramme:type-design-analyzer` | Analyzes type design for encapsulation, invariant expression, and enforcement. |
| `kramme:architecture-strategist` | Reviews code from an architectural perspective — component boundaries and design patterns. |
| `kramme:performance-oracle` | Analyzes performance issues, bottlenecks, and scalability. |
| `kramme:removal-planner` | Identifies dead code and unused dependencies with structured removal plans. |
| `kramme:injection-reviewer` | Reviews for injection vulnerabilities (SQL, command, template, header) and XSS. |
| `kramme:auth-reviewer` | Reviews authentication, authorization, CSRF, and session management. |
| `kramme:data-reviewer` | Reviews for cryptographic misuse, information disclosure, and DoS vulnerabilities. |
| `kramme:logic-reviewer` | Reviews for business logic flaws, race conditions, and TOCTOU bugs. |

## Hooks

Event handlers that run automatically at specific points in the Claude Code lifecycle. For detailed configuration, pattern lists, and formatter tables, see [docs/hooks.md](docs/hooks.md).

| Hook | Event | Description |
|------|-------|-------------|
| `block-rm-rf` | PreToolUse (Bash) | Blocks destructive file deletion commands and recommends `trash` instead. |
| `confirm-review-responses` | PreToolUse (Bash) | Confirms before committing review artifact files. |
| `noninteractive-git` | PreToolUse (Bash) | Blocks git commands that open an interactive editor. |
| `context-links` | Stop | Displays PR/MR and Linear issue links at end of messages. |
| `auto-format` | PostToolUse (Write\|Edit) | Auto-formats code after file modifications using detected project formatter. |

Use `/kramme:hooks:toggle` to enable/disable hooks. State persists in `hooks/hook-state.json` (gitignored).

## Suggested Permissions

Add these to your Claude Code `settings.json` to reduce approval prompts. Two tiers are available:

- **Core** — read-only git, GitHub, GitLab, and Linear operations
- **Extended** — adds git write operations, PR creation, and build/test commands

> **Warning:** Extended permissions include destructive git operations (`git push`, `git reset`, `git rebase`). Only use on projects where you have full control.

See [docs/permissions.md](docs/permissions.md) for the full JSON configuration.

## Recommended MCP Servers

These MCP servers enhance the plugin's capabilities. See [docs/mcp-servers.md](docs/mcp-servers.md) for installation instructions.

| Server | Purpose |
|--------|---------|
| **Linear** | Issue tracking for `/kramme:linear:issue-implement` and `/kramme:linear:issue-define` |
| **Context7** | Up-to-date library documentation retrieval |
| **Nx MCP** | Nx monorepo tools for `/kramme:verify:run` in Nx workspaces |
| **Chrome DevTools** | Browser automation and debugging |
| **Claude in Chrome** | Browser automation via Chrome extension |
| **Playwright** | Browser automation for testing |
| **Magic Patterns** | Design-to-code integration for Magic Patterns designs |
| **Granola** | Query meeting notes from Granola |

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
| `sqlite3` | Learnings database (pre-installed on macOS) | Pre-installed |

## Learnings Database

The plugin includes a persistent SQLite database for storing learnings across sessions.

**Location:** `~/.kramme-cc-workflow/learnings.db`

**Commands:**
- `/kramme:learnings:setup` - Initialize or verify the learnings database
- `/kramme:learnings:add` - Add new learnings
- `/kramme:learnings:search` - Full-text search with BM25 ranking
- `/kramme:learnings:list` - Browse and filter learnings
- `/kramme:learnings:delete` - Remove learnings

**Categories:** Navigation, Editing, Testing, Git, Quality, Context, Architecture, Performance, Prompting, Tooling

The database is initialized automatically on first use. To manually initialize or repair, run `/kramme:learnings:setup` or:
```bash
bash ~/.claude/plugins/kramme-cc-workflow/scripts/init-learnings-db.sh
```

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
├── auto-format.bats          # Tests for auto-format hook
├── block-rm-rf.bats          # Tests for block-rm-rf hook
├── confirm-review-responses.bats # Tests for confirm-review-responses hook
├── convert-plugin.bats       # Tests for plugin conversion script
├── context-links.bats        # Tests for context-links hook
└── noninteractive-git.bats   # Tests for noninteractive-git hook
```

## Plugin Structure

```
kramme-cc-workflow/
├── .claude-plugin/
│   ├── plugin.json      # Plugin metadata
│   └── marketplace.json # Marketplace definition
├── agents/              # Specialized subagents
├── skills/              # Skills (subdirectories with SKILL.md)
├── hooks/               # Event handlers
│   └── hooks.json
├── docs/                # Detailed reference docs
└── README.md
```

## Adding Components

See [CLAUDE.md](CLAUDE.md) for detailed conventions. Quick reference:

- **Agents**: Create markdown files in `agents/` with `name`, `description`, `model`, and `color` frontmatter.
- **Skills**: Create a subdirectory in `skills/` with a `SKILL.md` file. Key frontmatter: `name`, `description`, `disable-model-invocation`, `user-invocable`, `kramme-platforms`.
- **Hooks**: Edit `hooks/hooks.json` to add event handlers. Available events: `PreToolUse`, `PostToolUse`, `SessionStart`, `Stop`.

## Related Plugins

| Plugin | Description |
|--------|-------------|
| [kramme-connect-workflow](../kramme-connect-workflow/) | Skills for [Consensus ApS](https://consensus.dk)'s Connect product — Angular modernization, Nx library extraction, NgRx migration, and Rive documentation |
| [Agent Skills for Context Engineering](https://github.com/muratcankoylan/Agent-Skills-for-Context-Engineering) | Agent Skills focused on context engineering principles for building production-grade AI agent systems. |
| [adversarial-spec](https://github.com/zscole/adversarial-spec) | Specification refinement through multi-model debate until consensus is reached. |

## Documentation

- [Plugin Documentation](https://code.claude.com/docs/en/plugins)
- [Plugins Reference](https://code.claude.com/docs/en/plugins-reference)
- [Hooks Reference](https://code.claude.com/docs/en/hooks)
- [Skills Documentation](https://code.claude.com/docs/en/skills)

## Releases

See [CHANGELOG.md](CHANGELOG.md) for version history and [GitHub Releases](https://github.com/Abildtoft/kramme-cc-workflow/releases) for release notes.

For maintainers: see [RELEASE.md](RELEASE.md) for the release process.

## Attribution

- `kramme:docs:update-agents-md`: Inspired by [getsentry/skills](https://github.com/getsentry/skills/blob/main/plugins/sentry-skills/skills/agents-md/SKILL.md).
- `kramme:architecture-strategist`: Adapted from [EveryInc/compound-engineering-plugin](https://github.com/EveryInc/compound-engineering-plugin).
- `kramme:git:commit-message`: From [getsentry/skills](https://github.com/getsentry/skills/blob/main/plugins/sentry-skills/skills/commit/SKILL.md).
- `kramme:design-iterator`: Adapted from [EveryInc/compound-engineering-plugin](https://github.com/EveryInc/compound-engineering-plugin).
- `kramme:text:humanize`: Based on Wikipedia: Signs of AI writing (maintained by WikiProject AI Cleanup) and heavily inspired by [blader/humanizer](https://github.com/blader/humanizer).
- `kramme:performance-oracle`: From [EveryInc/compound-engineering-plugin](https://github.com/EveryInc/compound-engineering-plugin).
- OpenCode/Codex converter: Inspired by [EveryInc/compound-engineering-plugin](https://github.com/EveryInc/compound-engineering-plugin).

## License

MIT
