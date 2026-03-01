# kramme-cc-workflow

A Claude Code plugin providing tooling for daily workflow tasks. Developed for personal use and shared here for inspiration — adapt them to your own workflow, or use them as a starting point.

## Table of Contents

- [Installation & Updating](#installation--updating)
- [Skills](#skills)
  - [User-Invocable Skills](#user-invocable-skills)
  - [Background Skills](#background-skills)
- [Agents](#agents)
- [Hooks](#hooks)
- [Suggested Permissions](#suggested-permissions)
- [Recommended MCP Servers](#recommended-mcp-servers)
- [Recommended CLIs](#recommended-clis)
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
- **Auto-triggered**: Claude invokes automatically when context matches the skill description.
- **Background**: Skills with `user-invocable: false` are auto-triggered only and don't appear in the `/` menu.

### User-Invocable Skills

#### Structured Implementation Workflow (SIW)

Local issue tracking and structured implementation planning using markdown files.
See [docs/siw.md](docs/siw.md) for detailed workflow documentation.

| Skill | Invocation | Arguments | Description |
|-------|------------|-----------|-------------|
| `/kramme:siw:init` | User | `[spec-file(s) \| folder \| discover]` | Initialize structured implementation workflow documents in `siw/` (spec, siw/LOG.md, siw/issues).<br><br>Links existing specs without duplicating content, or runs an in-depth interview with `discover`.<br><br>Sets up local issue tracking without requiring Linear. |
| `/kramme:siw:continue` | User, Auto | — | Structured Implementation Workflow (SIW) entry point.<br><br>Triggers on "SIW", "structured workflow", or when siw/LOG.md and siw/OPEN_ISSUES_OVERVIEW.md files are detected.<br><br>Use `/kramme:siw:init` to set up. |
| `/kramme:siw:discovery` | User | `[spec-file-path(s) \| 'siw'] [--apply]` | Run a focused SIW spec-strengthening interview.<br><br>Identifies quality gaps and produces concrete spec improvements. |
| `/kramme:siw:issue-define` | User | `[ISSUE-G-XXX or ISSUE-P1-XXX] or [description and/or file paths]` | Define a new local issue with guided interview process.<br><br>Creates issue files in the `issues/` directory. |
| `/kramme:siw:generate-phases` | User | `[spec-file-path]` | Break spec into atomic, phase-based issues with tests and validation.<br><br>Uses `P1-001`, `P2-001`, `G-001` numbering.<br><br>Reviews breakdown with subagent before creating files. |
| `/kramme:siw:issue-implement` | User | `<G-001 \| P1-001 \| ISSUE-G-XXX>` | Start implementing a defined local issue with codebase exploration and planning.<br><br>Works on current branch. |
| `/kramme:siw:issue-implement:team` | User | `[issue-ids or 'phase N']` | Implement multiple SIW issues in parallel using multi-agent execution.<br><br>Each agent gets a full context window and implements one issue. Best for phases with multiple independent issues.<br><br>Requires Agent Teams in Claude Code or Codex with `multi_agent` enabled. |
| `/kramme:siw:spec-audit` | User | `[spec-file-path(s) \| 'siw'] [--model opus\|sonnet\|haiku]` | Audit spec quality (coherence, completeness, clarity, scope, actionability, testability, value proposition, technical design) before implementation.<br><br>Produces a structured report and optionally creates SIW issues. |
| `/kramme:siw:spec-audit:team` | User | `[spec-file-path(s) \| 'siw'] [--model opus\|sonnet\|haiku]` | Team-based spec audit where dimension specialists collaborate, cross-validate findings, and challenge each other's assessments.<br><br>Higher quality than standard spec-audit but uses more tokens.<br><br>Requires Agent Teams in Claude Code or Codex with `multi_agent` enabled. |
| `/kramme:siw:implementation-audit` | User | `[spec-file-path(s) \| 'siw'] [--model opus\|sonnet\|haiku]` | Exhaustively audit codebase against specification files.<br><br>Finds naming misalignments, missing implementations, and spec drift.<br><br>Produces a structured report and optionally creates SIW issues. |
| `/kramme:siw:implementation-audit:team` | User | `[spec-file-path(s) \| 'siw'] [--model opus\|sonnet\|haiku]` | Team-based implementation audit with simultaneous conformance + extension passes and live cross-validation.<br><br>Dedicated reconciler handles conflict resolution and guardrail enforcement.<br><br>Requires Agent Teams in Claude Code (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`) or a Codex runtime with `multi_agent` enabled. |
| `/kramme:siw:resolve-audit` | User | `[audit-report-path] [finding-id(s)]` | Resolve audit findings one-by-one with executive summaries, alternatives, a recommended option, and SIW issue creation based on user preference. |
| `/kramme:siw:issues-reindex` | User | — | Remove all DONE issues and renumber remaining issues from 001.<br><br>Cleans up completed work and provides fresh numbering sequence. |
| `/kramme:siw:reset` | User | — | Reset SIW workflow state while preserving the spec.<br><br>Migrates log decisions to spec, then clears issues and log for fresh start. |
| `/kramme:siw:reverse-engineer-spec` | User | `[branch \| folder \| file(s)] [--base main] [--model opus\|sonnet\|haiku]` | Experimental.<br><br>Reverse engineer an SIW specification from existing code.<br><br>Produces a structured spec compatible with the SIW workflow.<br><br>Use for documenting shipped features, onboarding to unfamiliar code, or bootstrapping SIW from an existing implementation. |
| `/kramme:siw:close` | User | — | Close an SIW project by generating permanent documentation in `docs/<feature>/` capturing decisions, architecture, and implementation summary, then removing temporary workflow files. |
| `/kramme:siw:remove` | User | — | Remove all Structured Implementation Workflow (SIW) files from current directory.<br><br>Cleans up temporary workflow documents. |

#### Pull Requests

PR creation, review, iteration, and resolution.

| Skill | Invocation | Arguments | Description |
|-------|------------|-----------|-------------|
| `/kramme:pr:create` | User | — | Create a clean PR with narrative-quality commits and comprehensive description.<br><br>Orchestrates branch setup, commit restructuring, and PR creation. |
| `/kramme:pr:code-review` | User | — | Analyze code quality of branch changes using specialized review agents (tests, errors, types, security, slop).<br><br>Outputs REVIEW_OVERVIEW.md with actionable findings. |
| `/kramme:pr:code-review:team` | User | — | Team-based PR review using multi-agent execution where specialized reviewers collaborate, cross-validate findings, and challenge each other's suggestions.<br><br>Higher quality, higher token cost.<br><br>Requires Agent Teams in Claude Code (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`) or a Codex runtime with `multi_agent` enabled. |
| `/kramme:pr:resolve-review` | User | — | Resolve findings from code reviews.<br><br>Evaluates each finding for scope and validity, implements fixes, and generates a response document. |
| `/kramme:pr:resolve-review:team` | User | — | Resolve review findings in parallel using multi-agent execution.<br><br>Groups findings by file area and assigns to separate agents for faster resolution.<br><br>Requires Agent Teams in Claude Code (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`) or a Codex runtime with `multi_agent` enabled. |
| `/kramme:pr:fix-ci` | User | — | Iterate on a PR until CI passes.<br><br>Automates the feedback-fix-push-wait cycle for both GitHub and GitLab. |
| `/kramme:pr:generate-description` | User | `[--non-interactive] [--direct] [--visual]` | Write a structured PR title and body from git diff, commit log, and Linear context.<br><br>Optionally auto-detects a running dev server and captures screenshots with `--visual`. |
| `/kramme:pr:ux-review` | User | `[app-url] [--categories a11y,ux,product,visual] [--threshold 0-100] [parallel]` | Audit UI, UX, and product experience of PR changes using specialized agents for accessibility, usability heuristics, product thinking, and visual consistency.<br><br>Optionally uses browser automation for visual review. |
| `/kramme:pr:ux-review:team` | User | `[app-url] [--categories a11y,ux,product,visual] [--threshold 0-100]` | Team-based UX audit using multi-agent execution where specialized reviewers (usability, product, visual, accessibility) collaborate, cross-validate findings, and challenge each other.<br><br>Higher quality, higher token cost.<br><br>Requires Agent Teams in Claude Code (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`) or a Codex runtime with `multi_agent` enabled. |
| `/kramme:pr:rebase` | User | — | Rebase current branch onto latest main/master, then force push.<br><br>Use when your PR is behind the base branch. |

#### Code Quality & Review

Code cleanup, refactoring, and bug/security review.

| Skill | Invocation | Arguments | Description |
|-------|------------|-----------|-------------|
| `/kramme:code:cleanup-ai` | User | — | Remove AI-generated code slop from a branch.<br><br>Uses `kramme:deslop-reviewer` agent to identify slop, then fixes the issues. |
| `/kramme:code:migrate` | User | `<target e.g. 'Angular 19', 'React 19', 'Node 22'>` | Experimental.<br><br>Plan and execute framework or library version migrations with phased upgrades and verification gates.<br><br>Use when upgrading major framework versions (Angular, React, Node) or migrating between libraries. |
| `/kramme:code:rewrite-clean` | User | — | Scrap a working-but-mediocre fix and reimplement elegantly.<br><br>Extracts learnings from the initial attempt, then starts fresh with the elegant solution. |
| `/kramme:code:refactor-pass` | User, Auto | — | Lightweight simplification pass on recent changes — removes dead code, straightens logic, removes excessive parameters, and verifies with build/tests.<br><br>Unlike `kramme:code:rewrite-clean` which scraps and redoes from scratch, this incrementally cleans up working code. |
| `/kramme:code:agent-readiness` | User | — | Experimental.<br><br>Audit a codebase for agent-nativeness — scores 5 dimensions (fully typed, traversable, test coverage, feedback loops, self-documenting) on a 1-5 scale and generates a prioritized refactoring plan.<br><br>Launches 3 parallel Explore agents for thorough analysis. Re-run after improvements to track score changes. |

#### Debug

Bug investigation and root cause analysis.

| Skill | Invocation | Arguments | Description |
|-------|------------|-----------|-------------|
| `/kramme:debug:investigate` | User | `[bug description, error message, or issue reference]` | Experimental.<br><br>Structured bug investigation workflow: reproduce, isolate, trace root cause, and fix.<br><br>Use when debugging a bug, investigating an error, or tracking down a regression. |

#### Dependencies

Dependency auditing and management.

| Skill | Invocation | Arguments | Description |
|-------|------------|-----------|-------------|
| `/kramme:deps:audit` | User | — | Experimental.<br><br>Audit project dependencies for outdated packages, security vulnerabilities, and staleness.<br><br>Generates a prioritized upgrade plan with risk assessment. |

#### Testing

Test generation and coverage.

| Skill | Invocation | Arguments | Description |
|-------|------------|-----------|-------------|
| `/kramme:test:generate` | User | `[file-path or directory]` | Experimental.<br><br>Generate tests for existing code by analyzing project test patterns and conventions.<br><br>Use when adding test coverage to untested files or generating test stubs. |

#### Git

Git history management and commit operations.

| Skill | Invocation | Arguments | Description |
|-------|------------|-----------|-------------|
| `/kramme:git:fixup` | User | — | Intelligently fixup unstaged changes into existing commits.<br><br>Maps each changed file to its most recent commit, validates, creates fixup commits, and autosquashes. |
| `/kramme:git:recreate-commits` | User | — | Recreate current branch in-place with narrative-quality commits and logical, reviewer-friendly commit history. |

#### Linear

Linear issue tracking integration.

| Skill | Invocation | Arguments | Description |
|-------|------------|-----------|-------------|
| `/kramme:linear:issue-define` | User | `[issue-id] or [description and/or file paths]` | Create or improve a Linear issue through exhaustive guided refinement.<br><br>Can start from scratch or refine an existing issue by ID. |
| `/kramme:linear:issue-implement` | User | — | Start implementing a Linear issue with branch setup, context gathering, and guided workflow.<br><br>Fetches issue details, explores codebase for patterns, asks clarifying questions, and creates the recommended branch. |

#### Visual

Generate styled, self-contained HTML pages with diagrams, data tables, and interactive visualizations. Output opens in the browser.

| Skill | Invocation | Arguments | Description |
|-------|------------|-----------|-------------|
| `/kramme:visual:diagram` | User, Auto | — | Experimental.<br><br>Generate beautiful HTML diagrams for architecture overviews, flowcharts, schemas, data tables, and any visual explanation.<br><br>Also auto-triggers for complex ASCII tables (4+ rows or 3+ columns). |
| `/kramme:visual:diff-review` | User | — | Experimental.<br><br>Visual HTML diff review with executive summary, KPI dashboard, Mermaid architecture graphs, before/after panels, code review analysis, and decision log. |
| `/kramme:visual:plan-review` | User | — | Experimental.<br><br>Visual plan review comparing current codebase against a proposed implementation plan, with blast radius analysis, current/planned architecture Mermaid diagrams, and risk assessment. |
| `/kramme:visual:project-recap` | User | — | Experimental.<br><br>Mental model recap for context-switching back to a project.<br><br>Architecture snapshot, recent activity timeline, decision log, and cognitive debt hotspots. |
| `/kramme:visual:generate-image` | User, Auto | — | Generate or edit images using Gemini 3 Pro Image API.<br><br>Supports text-to-image generation, image-to-image editing, and configurable resolution (1K/2K/4K). |
| `/kramme:visual:onboarding` | User | `[focus-area or audience]` | Experimental.<br><br>Generate an interactive HTML onboarding guide for newcomers to a codebase — architecture overview, domain model, key flows, conventions, and getting-started walkthrough. |

**API key setup for `/kramme:visual:generate-image`:**

```bash
# Required for image generation/editing
export GEMINI_API_KEY="your-api-key-here"
```

This works in both Claude Code and Codex. If running the script directly, you can also pass `--api-key` instead of using an environment variable.

#### Discovery & Documentation

Requirements discovery, document conversion, and text processing.

| Skill | Invocation | Arguments | Description |
|-------|------------|-----------|-------------|
| `/kramme:discovery:interview` | User | `[file-path or topic description]` | Conduct an in-depth interview about a topic/proposal to uncover requirements.<br><br>Uses structured questioning to explore features, processes, or architecture decisions. |
| `/kramme:docs:to-markdown` | User, Auto | — | Convert documents (PDF, Word, Excel, images, audio, etc.) to Markdown using markitdown |
| `/kramme:text:humanize` | User, Auto | `[file-path or text]` | Remove signs of AI-generated writing from text. |
| `/kramme:skill:create` | User | `[skill-name or description]` | Guide creation of a new plugin skill with best-practice structure, optimized frontmatter, and progressive disclosure.<br><br>Scaffolds the directory, generates SKILL.md from templates, and runs a validation checklist. Based on [skills-best-practices](https://github.com/mgechev/skills-best-practices). |

#### Workflow & Configuration

Session management, verification, artifact cleanup, and hook configuration.

| Skill | Invocation | Arguments | Description |
|-------|------------|-----------|-------------|
| `/kramme:workflow-artifacts:cleanup` | User | — | Delete workflow artifacts (REVIEW_OVERVIEW.md, UX_REVIEW_OVERVIEW.md, AUDIT_IMPLEMENTATION_REPORT.md, AUDIT_SPEC_REPORT.md, siw/AUDIT_IMPLEMENTATION_REPORT.md, siw/AUDIT_SPEC_REPORT.md, siw/LOG.md, siw/OPEN_ISSUES_OVERVIEW.md, specification files, visual diagram HTML files).<br><br>For SIW-specific cleanup, use `/kramme:siw:remove`. |
| `/kramme:changelog:generate` | User | — | Create engaging daily/weekly changelogs from recent merges to main, with contributor shoutouts and audience-aware formatting |
| `/kramme:hooks:configure-links` | User | `[show\|reset\|KEY=VALUE ...]` | Configure `context-links` hook settings by writing local overrides to `hooks/context-links.config` (workspace slug, team keys, regexes). |
| `/kramme:hooks:toggle` | User | `<hook-name\|status> [enable\|disable]` | Enable or disable a plugin hook.<br><br>Use `status` to list all hooks, or specify a hook name to toggle. |
| `/kramme:session:wrap-up` | User | — | End-of-session checklist to capture progress, ensure quality, and document next steps.<br><br>Audits uncommitted changes, runs quality checks, and prompts for session summary and next steps. |
| `/kramme:verify:run` | User, Auto | — | Run verification checks (tests, formatting, builds, linting, type checking) for affected code.<br><br>Automatically detects project type and runs appropriate commands. |

#### Nx

Nx workspace tooling and configuration.

| Skill | Invocation | Arguments | Description |
|-------|------------|-----------|-------------|
| `/kramme:nx:setup-portless` | User | — | Experimental.<br><br>Set up portless in an Nx workspace for stable HTTPS localhost URLs instead of port numbers.<br><br>Guides workspace-level proxy setup, per-app `dev:local`/`dev:full` targets, and troubleshooting. |

### Background Skills

Auto-triggered by Claude based on context. These don't appear in the `/` menu.

| Skill | Trigger Condition |
|-------|-------------------|
| `kramme:docs:update-agents-md` | Add guidelines to AGENTS.md with structured, keyword-based documentation. Triggers on "update AGENTS.md", "add to AGENTS.md", "maintain agent docs" |
| `kramme:git:commit-message` | Creating commits or writing commit messages (plain English, no conventional commits) |
| `kramme:verify:before-completion` | About to claim work is complete/fixed/passing — requires evidence before assertions |

## Agents

Specialized subagents for PR review and UX audit tasks. Invoked by `/kramme:pr:code-review`, `/kramme:pr:ux-review`, or directly via the Task tool.

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
| `kramme:a11y-auditor` | Audits accessibility (WCAG 2.1 AA): ARIA, semantic HTML, color contrast, keyboard nav, focus management. |
| `kramme:ux-reviewer` | Reviews usability (Nielsen's 10 heuristics) and interaction states (loading, error, empty, feedback). |
| `kramme:product-reviewer` | Reviews product experience: feature discoverability, user flow completeness, edge cases, copy quality. |
| `kramme:visual-reviewer` | Reviews visual consistency (design tokens, spacing, typography, color) and responsive design. |

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
| `surf` | AI-generated illustrations in visual diagrams (optional) | [surf-cli](https://github.com/nicobailon/surf-cli) |

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
- [SIW Workflow Reference](docs/siw.md)

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
- `kramme:siw:reverse-engineer-spec`: Inspired by [blader/schematic](https://github.com/blader/schematic).
- OpenCode/Codex converter: Inspired by [EveryInc/compound-engineering-plugin](https://github.com/EveryInc/compound-engineering-plugin).
- `kramme:visual:*` skills: Adapted from [nicobailon/visual-explainer](https://github.com/nicobailon/visual-explainer).

## License

MIT
