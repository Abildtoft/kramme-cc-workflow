# kramme-cc-workflow

A Claude Code plugin providing tooling for daily workflow tasks.

> [!IMPORTANT]
> Thanks for checking this out. It is my personal workflow, built primarily for myself.
> I experiment in the open and ship updates quickly, so skills may change or occasionally be removed.
> Questions are always welcome. Feel free to fork, "steal" ideas, or jump straight to the [sources of inspiration](#attribution).

## Table of Contents

- [Installation & Updating](#installation--updating)
- [Getting Started](#getting-started)
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
/plugin marketplace add Abildtoft/kramme-cc-workflow
/plugin install kramme-cc-workflow@kramme-cc-workflow
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

## Getting Started

Three common workflows to try after installation:

### Plan and implement with SIW

SIW (Structured Implementation Workflow) breaks non-trivial work into spec-driven issues tracked in local markdown files.

```bash
/kramme:siw:init              # link or create a spec, set up siw/ directory
/kramme:siw:generate-phases   # break spec into phased issues
/kramme:siw:issue-implement   # implement one issue at a time
/kramme:siw:close             # archive decisions and clean up
```

See [docs/siw.md](docs/siw.md) for the full workflow reference.

### Review and ship a PR

```bash
/kramme:pr:code-review        # run specialized review agents on your branch
/kramme:pr:product-review     # deep product review of your changes
/kramme:pr:resolve-review     # fix the findings
/kramme:pr:finalize           # final readiness check before shipping
/kramme:pr:create             # restructure commits and open the PR
/kramme:pr:fix-ci             # iterate until CI passes
```

### Inspect and test a live app

```bash
/kramme:browse http://localhost:3000           # navigate, screenshot, inspect
/kramme:qa http://localhost:3000               # structured QA with evidence
/kramme:product:review http://localhost:3000    # whole-product experience review
```

### Quick utilities

```bash
/kramme:verify:run            # run tests, linting, and type checks for changed code
/kramme:visual:diagram        # generate an HTML diagram from any explanation
/kramme:docs:to-markdown      # convert PDF, Word, Excel, or images to Markdown
/kramme:code:refactor-pass    # simplification pass on recent changes
```

All skills are listed in the reference below. Background skills (commit messages, verification guards) run automatically.

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
| `/kramme:siw:init` | User | `[spec-file(s) \| folder \| discover]` | Initialize structured implementation workflow documents in `siw/` (spec, siw/LOG.md, siw/issues).<br><br>Links existing specs without duplicating content, imports `siw/DISCOVERY_BRIEF.md`, or runs the discovery-brief flow with `discover` before initialization.<br><br>Sets up local issue tracking without requiring Linear. |
| `/kramme:siw:continue` | User, Auto | — | Structured Implementation Workflow (SIW) entry point.<br><br>Triggers on "SIW", "structured workflow", or when siw/LOG.md and siw/OPEN_ISSUES_OVERVIEW.md files are detected.<br><br>Use `/kramme:siw:init` to set up. |
| `/kramme:siw:discovery` | User | `[topic \| spec-file-path(s) \| 'siw'] [--apply]` | Run a deep discovery interview before writing a spec or to strengthen an existing one.<br><br>Greenfield runs write `siw/DISCOVERY_BRIEF.md`; refinement runs produce concrete improvement plans and can apply changes directly. |
| `/kramme:siw:issue-define` | User | `[ISSUE-G-XXX or ISSUE-P1-XXX] or [description and/or file paths]` | Define a new local issue with guided interview process.<br><br>Creates issue files in the `issues/` directory. |
| `/kramme:siw:generate-phases` | User | `[spec-file-path]` | Break spec into atomic, phase-based issues with tests and validation.<br><br>Uses `P1-001`, `P2-001`, `G-001` numbering.<br><br>Reviews breakdown with subagent before creating files. |
| `/kramme:siw:issue-implement` | User | `<G-001 \| P1-001 \| ISSUE-G-XXX>` | Start implementing a defined local issue with codebase exploration and planning.<br><br>Works on current branch. |
| `/kramme:siw:issue-implement:team` | User | `[issue-ids or 'phase N'] [--auto]` | Implement multiple SIW issues in parallel using multi-agent execution.<br><br>Each agent gets a full context window and implements one issue. Best for phases with multiple independent issues.<br><br>Add `--auto` to start the plan immediately.<br><br>Requires Agent Teams in Claude Code or Codex with `multi_agent` enabled. |
| `/kramme:siw:product-audit` | User | `[spec-file-path(s) \| 'siw'] [--auto] [--inline]` | Experimental.<br><br>Product audit of SIW specs/plans before implementation.<br><br>Evaluates target user clarity, problem/solution fit, user state modeling, scope correctness, and success criteria quality.<br><br>Optionally creates SIW issues for product gaps. Add `--auto` to replace prior audit results and create critical/major issues without pausing. Add `--inline` to reply with the report instead of writing `PRODUCT_AUDIT.md`. |
| `/kramme:siw:spec-audit` | User | `[spec-file-path(s) \| 'siw'] [--auto] [--model opus\|sonnet\|haiku] [--inline]` | Audit spec quality (coherence, completeness, clarity, scope, actionability, testability, value proposition, technical design) before implementation.<br><br>Produces a structured report and optionally creates SIW issues. Add `--auto` to replace prior report output and create issues for critical/major findings plus Minor findings that preserve original Critical or Major severity via Work Context capping. Add `--inline` to reply with the report instead of writing `AUDIT_SPEC_REPORT.md`. |
| `/kramme:siw:spec-audit:auto-fix` | User | `[audit-report-path] [--auto] [--dry-run] [--threshold 60-100]` | Auto-fix safe spec-audit findings that can be corrected directly from the spec.<br><br>Handles cross-reference errors, terminology inconsistencies, numbering mistakes, formatting issues, and other deterministic or clearly-best cleanups while leaving decision-heavy findings for `/kramme:siw:resolve-audit`. |
| `/kramme:siw:spec-audit:team` | User | `[spec-file-path(s) \| 'siw'] [--model opus\|sonnet\|haiku] [--inline]` | Team-based spec audit where dimension specialists collaborate, cross-validate findings, and challenge each other's assessments.<br><br>Higher quality than standard spec-audit but uses more tokens.<br><br>Requires Agent Teams in Claude Code or Codex with `multi_agent` enabled.<br><br>Add `--inline` to reply with the report instead of writing `AUDIT_SPEC_REPORT.md`. |
| `/kramme:siw:implementation-audit` | User | `[spec-file-path(s) \| 'siw'] [--auto] [--model opus\|sonnet\|haiku] [--inline]` | Exhaustively audit codebase against specification files.<br><br>Finds naming misalignments, missing implementations, and spec drift.<br><br>Produces a structured report and optionally creates SIW issues. Add `--auto` to replace prior report output and create critical/major issues without pausing. Add `--inline` to reply with the report instead of writing `AUDIT_IMPLEMENTATION_REPORT.md`. |
| `/kramme:siw:implementation-audit:team` | User | `[spec-file-path(s) \| 'siw'] [--model opus\|sonnet\|haiku] [--inline]` | Team-based implementation audit with simultaneous conformance + extension passes and live cross-validation.<br><br>Dedicated reconciler handles conflict resolution and guardrail enforcement.<br><br>Requires Agent Teams in Claude Code (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`) or a Codex runtime with `multi_agent` enabled.<br><br>Add `--inline` to reply with the report instead of writing `AUDIT_IMPLEMENTATION_REPORT.md`. |
| `/kramme:siw:resolve-audit` | User | `[audit-report-path] [finding-id(s)] [--auto]` | Resolve audit findings one-by-one with executive summaries, alternatives, a recommended option, and SIW issue creation. Add `--auto` to let the model choose each resolution without pausing for confirmation. If both audit reports exist, pass the report path to keep the run scoped. |
| `/kramme:siw:issues-reindex` | User | — | Remove all DONE issues and renumber remaining issues from 001.<br><br>Cleans up completed work and provides fresh numbering sequence. |
| `/kramme:siw:reset` | User | — | Reset SIW workflow state while preserving the spec.<br><br>Migrates log decisions to spec, then clears issues and log for fresh start. |
| `/kramme:siw:reverse-engineer-spec` | User | `[branch \| folder \| file(s)] [--base main] [--model opus\|sonnet\|haiku]` | Experimental.<br><br>Reverse engineer an SIW specification from existing code.<br><br>Produces a structured spec compatible with the SIW workflow.<br><br>Use for documenting shipped features, onboarding to unfamiliar code, or bootstrapping SIW from an existing implementation. |
| `/kramme:siw:close` | User | — | Close an SIW project by generating permanent documentation in `docs/<feature>/` capturing decisions, architecture, and implementation summary, then removing temporary workflow files. |
| `/kramme:siw:remove` | User | — | Remove all Structured Implementation Workflow (SIW) files from current directory.<br><br>Cleans up temporary workflow documents. |

#### Pull Requests

PR creation, review, iteration, and resolution.

| Skill | Invocation | Arguments | Description |
|-------|------------|-----------|-------------|
| `/kramme:pr:create` | User | `[--auto]` | Create a clean PR with narrative-quality commits and comprehensive description.<br><br>Orchestrates branch setup, commit restructuring, and PR creation. Add `--auto` to use the recommended path end-to-end without confirmation prompts. |
| `/kramme:pr:product-review` | User | `[--base <ref>] [--threshold 0-100] [--inline]` | Experimental.<br><br>Deep product review of branch and local changes.<br><br>Evaluates user-value alignment, flow completeness, missing states, copy/defaults, permission behavior, and adjacent-flow regressions.<br><br>Outputs `PRODUCT_REVIEW_OVERVIEW.md` by default. Add `--inline` to reply with the report instead. |
| `/kramme:pr:code-review` | User | `[aspects] [--emphasize <dim>...] [--base <ref>] [parallel] [--inline]` | Analyze code quality of branch changes using specialized review agents (tests, errors, types, security, slop).<br><br>Use `--emphasize` to promote selected review dimensions and quiet other important findings; emphasized dimensions must stay in the active review set.<br><br>Outputs `REVIEW_OVERVIEW.md` by default. Add `--inline` to reply with the report instead. |
| `/kramme:pr:code-review:team` | User | `[aspects] [--base <ref>] [--inline]` | Team-based PR review using multi-agent execution where specialized reviewers collaborate, cross-validate findings, and challenge each other's suggestions.<br><br>Higher quality, higher token cost.<br><br>Requires Agent Teams in Claude Code (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`) or a Codex runtime with `multi_agent` enabled.<br><br>Add `--inline` to reply with the report instead of writing `REVIEW_OVERVIEW.md`. |
| `/kramme:pr:resolve-review` | User | `[--auto] [--granular] [--severity critical,important] [--source local\|online\|--local\|--online] [review-content\|instructions\|url]` | Resolve findings from code reviews.<br><br>Evaluates each finding for scope and validity, implements fixes, and generates a response document.<br><br>Use `--source local` (or `--local`) to target `REVIEW_OVERVIEW.md` only, or `--source online` (or `--online`) to target PR/MR review comments.<br><br>Use `--auto` to post replies and resolve addressed review threads/discussions on the current PR/MR (`--reply` and `--answer-and-resolve` are still supported as legacy aliases).<br><br>Use `--granular` to create one commit per finding instead of a single combined commit.<br><br>Use `--severity critical,important` to only address findings matching the specified severity levels (critical=High, important=Medium, suggestion=Low).<br><br>Creates a rollback checkpoint before making changes; offers `git reset --hard` if fixes fail validation.<br><br>When local source is selected, no platform replies or thread resolution are performed even if `--auto` is set. |
| `/kramme:pr:resolve-review:team` | User | `[--auto] [review-content\|instructions\|url]` | Resolve review findings in parallel using multi-agent execution.<br><br>Groups findings by file area and assigns to separate agents for faster resolution.<br><br>Add `--auto` to skip the parallel-plan confirmation and, for external reviews, post replies / resolve addressed threads after the fixes land.<br><br>Requires Agent Teams in Claude Code (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`) or a Codex runtime with `multi_agent` enabled. |
| `/kramme:pr:fix-ci` | User | — | Iterate on a PR until CI passes.<br><br>Automates the feedback-fix-push-wait cycle for both GitHub and GitLab. |
| `/kramme:pr:generate-description` | User | `[--auto] [--visual] [--base <ref>]` | Write a structured PR title and body from git diff, commit log, and Linear context.<br><br>`--auto` is the preferred hands-off mode: it skips prompts and updates the existing PR automatically when one already exists for the branch.<br><br>Optionally auto-detects a running dev server and captures screenshots with `--visual`. |
| `/kramme:pr:copy-review` | User | `[--base <ref>] [--threshold 0-100] [--inline]` | Experimental.<br><br>Review PR and local changes for unnecessary, redundant, or duplicative UI text — labels, descriptions, placeholders, tooltips, and instructions that the UI already communicates through its structure.<br><br>Outputs `COPY_REVIEW_OVERVIEW.md` by default. Add `--inline` to reply with the report instead. |
| `/kramme:pr:ux-review` | User | `[app-url] [--categories a11y,ux,product,visual] [--threshold 0-100] [parallel] [--inline]` | Audit UI, UX, and product experience of PR changes using specialized agents for accessibility, usability heuristics, product thinking, and visual consistency.<br><br>Optionally uses browser automation for visual review. Add `--inline` to reply with the report instead of writing `UX_REVIEW_OVERVIEW.md`. |
| `/kramme:pr:ux-review:team` | User | `[app-url] [--categories a11y,ux,product,visual] [--threshold 0-100] [--inline]` | Team-based UX audit using multi-agent execution where specialized reviewers (usability, product, visual, accessibility) collaborate, cross-validate findings, and challenge each other.<br><br>Higher quality, higher token cost.<br><br>Requires Agent Teams in Claude Code (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`) or a Codex runtime with `multi_agent` enabled.<br><br>Add `--inline` to reply with the report instead of writing `UX_REVIEW_OVERVIEW.md`. |
| `/kramme:pr:finalize` | User | `[--auto] [--fix] [--skip <skill,...>] [--app-url <url>] [--base <ref>]` | Experimental.<br><br>Final PR readiness orchestration.<br><br>Coordinates verify:run, code review, product review, UX review, QA, and description generation. Produces a ready/not-ready/ready-with-caveats verdict.<br><br>Add `--auto` to run the applicable plan, QA, and description generation without pausing.<br><br>Add `--fix` to automatically run `resolve-review` on critical and important findings after the initial verdict, then re-verify and produce an updated assessment.<br><br>Not for creating PRs, fixing CI, or merging code. |
| `/kramme:pr:rebase` | User | — | Rebase current branch onto latest main/master, then force push.<br><br>Use when your PR is behind the base branch. |

#### Browser & QA

Live product inspection and structured testing.

| Skill | Invocation | Arguments | Description |
|-------|------------|-----------|-------------|
| `/kramme:browse` | User | `<url> [--screenshot] [--console] [--network]` | Experimental.<br><br>Browser operator for live product inspection.<br><br>Detects available browser MCP tooling (claude-in-chrome, chrome-devtools, playwright) and provides consistent navigation, screenshot, interaction, and evidence capture. |
| `/kramme:qa` | User | `<url> [quick\|diff-aware\|targeted <route>] [--base <ref>] [--regression] [--inline]` | Experimental.<br><br>Structured QA testing with evidence capture.<br><br>Runs smoke checks, diff-aware validation, or targeted route testing. Produces `QA_REPORT.md` by default. Add `--inline` to reply with the report instead. |
| `/kramme:product:review` | User | `<url> [--flows <flow1,flow2,...>] [--focus <dimension>] [--inline]` | Experimental.<br><br>Whole-product review across flows and surfaces.<br><br>Evaluates navigation coherence, feature discoverability, onboarding, cross-flow consistency, dead ends, friction, and trust/safety. Produces `PRODUCT_AUDIT_OVERVIEW.md` by default. Add `--inline` to reply with the report instead. |

#### Product Design

Product critique and design-direction skills.

| Skill | Invocation | Arguments | Description |
|-------|------------|-----------|-------------|
| `/kramme:product:design-critic` | User | `[file-path, screenshot, URL, or product question]` | Experimental.<br><br>Critique or shape a product surface with strong design judgment.<br><br>Focuses on jobs-to-be-done, surface ownership, hierarchy, trust/governance surfacing, and competitor-informed pattern critique rather than generic visual polish. |

#### Code Quality & Review

Code cleanup, refactoring, and bug/security review.

| Skill | Invocation | Arguments | Description |
|-------|------------|-----------|-------------|
| `/kramme:code:cleanup-ai` | User | — | Remove AI-generated code slop from a branch.<br><br>Uses `kramme:deslop-reviewer` agent to identify slop, then fixes the issues. |
| `/kramme:code:migrate` | User | `<target e.g. 'Angular 19', 'React 19', 'Node 22'> [--auto]` | Experimental.<br><br>Plan and execute framework or library version migrations with phased upgrades and verification gates.<br><br>Use when upgrading major framework versions (Angular, React, Node) or migrating between libraries. Add `--auto` to execute the full plan without review checkpoints. |
| `/kramme:code:rewrite-clean` | User | — | Scrap a working-but-mediocre fix and reimplement elegantly.<br><br>Extracts learnings from the initial attempt, then starts fresh with the elegant solution. |
| `/kramme:code:refactor-pass` | User, Auto | — | Lightweight simplification pass on recent changes — removes dead code, straightens logic, removes excessive parameters, and verifies with build/tests.<br><br>Unlike `kramme:code:rewrite-clean` which scraps and redoes from scratch, this incrementally cleans up working code. |
| `/kramme:code:copy-review` | User | `[scope — e.g. src/components]` | Experimental.<br><br>Scan the codebase for unnecessary, redundant, or duplicative UI text.<br><br>Identifies labels, descriptions, placeholders, tooltips, and instructions that could be removed because the UI already communicates the same information through its structure. Produces `COPY_REVIEW_OVERVIEW.md`. |
| `/kramme:code:breakdown-findings` | User | `[source-file-or-content]` | Cluster validated findings into PR-sized themes and generate self-contained implementation plans.<br><br>Consumes pasted findings or report artifacts such as `REVIEW_OVERVIEW.md` and writes `PR_PLAN_INDEX.md` plus one `PR_PLAN_*.md` file per theme. |
| `/kramme:code:refactor-opportunities` | User, Auto | `[scope — e.g. src/api]` | Experimental.<br><br>Scan the codebase for refactoring candidates (dead code, duplication, complexity, abstraction issues, type safety, error handling, coupling, and more).<br><br>Launches parallel Explore agents by category group, deduplicates findings, and produces a prioritized `REFACTOR_OPPORTUNITIES_OVERVIEW.md` report. |
| `/kramme:code:agent-readiness` | User | `[--auto]` | Experimental.<br><br>Audit a codebase for agent-nativeness — scores 5 dimensions (fully typed, traversable, test coverage, feedback loops, self-documenting) on a 1-5 scale and generates a prioritized refactoring plan.<br><br>Launches 3 parallel Explore agents for thorough analysis. Re-run after improvements to track score changes. Add `--auto` to compare against an existing report without prompting. |

#### Debug

Bug investigation and root cause analysis.

| Skill | Invocation | Arguments | Description |
|-------|------------|-----------|-------------|
| `/kramme:debug:investigate` | User | `[bug description, error message, or issue reference]` | Experimental.<br><br>Structured bug investigation workflow: reproduce, isolate, trace root cause, and fix.<br><br>Use when debugging a bug, investigating an error, or tracking down a regression. |

#### Dependencies

Dependency auditing and management.

| Skill | Invocation | Arguments | Description |
|-------|------------|-----------|-------------|
| `/kramme:deps:audit` | User | `[--auto]` | Experimental.<br><br>Audit project dependencies for outdated packages, security vulnerabilities, and staleness.<br><br>Generates a prioritized upgrade plan with risk assessment. Add `--auto` to write `DEPENDENCY_AUDIT.md` and skip follow-up prompts. |

#### Testing

Test generation and coverage.

| Skill | Invocation | Arguments | Description |
|-------|------------|-----------|-------------|
| `/kramme:test:generate` | User | `[file-path or directory] [--auto]` | Experimental.<br><br>Generate tests for existing code by analyzing project test patterns and conventions.<br><br>Use when adding test coverage to untested files or generating test stubs. Add `--auto` to infer framework/configuration defaults and skip the test-shape prompts. |

#### Git

Git history management and commit operations.

| Skill | Invocation | Arguments | Description |
|-------|------------|-----------|-------------|
| `/kramme:git:fixup` | User | — | Intelligently fixup unstaged changes into existing commits.<br><br>Maps each changed file to its most recent commit, validates, creates fixup commits, and autosquashes. |
| `/kramme:git:recreate-commits` | User | `[--auto] [--after <commit>]` | Recreate current branch in-place with narrative-quality commits and logical, reviewer-friendly commit history. Add `--auto` to choose commit granularity without prompting. Add `--after <commit>` to keep commits up to and including `<commit>` and only recreate commits after it. |

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
| `/kramme:docs:add-greenfield-policy` | User | — | Add Hard-Cut Greenfield Policy to AGENTS.md (or CLAUDE.md).<br><br>Enforces one canonical codepath, no compatibility bridges, and explicit removal tracking for any temporary migration code. For projects with no existing user base. |
| `/kramme:docs:to-markdown` | User, Auto | — | Convert documents (PDF, Word, Excel, images, audio, etc.) to Markdown using markitdown |
| `/kramme:text:humanize` | User, Auto | `[file-path or text]` | Remove signs of AI-generated writing from text. |
| `/kramme:skill:create` | User | `[skill-name or description]` | Guide creation of a new plugin skill with best-practice structure, optimized frontmatter, and progressive disclosure.<br><br>Scaffolds the directory, generates SKILL.md from templates, and runs a validation checklist. Based on [skills-best-practices](https://github.com/mgechev/skills-best-practices). |

#### Workflow & Configuration

Session management, verification, artifact cleanup, and hook configuration.

| Skill | Invocation | Arguments | Description |
|-------|------------|-----------|-------------|
| `/kramme:workflow-artifacts:cleanup` | User | — | Delete workflow artifacts such as review overviews, audit reports, generated PR plans, temporary SIW files, and visual diagram HTML files.<br><br>For SIW-specific cleanup, use `/kramme:siw:remove`. |
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
| `kramme:git:commit-message` | Creating commits or writing commit messages (plain-English branch commits; Conventional Commit PR titles) |
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
| `kramme:product-reviewer` | Reviews product experience in PR mode (diff-scoped), spec mode (plan-scoped), or audit mode (live-product): feature discoverability, user flow completeness, edge cases, copy quality, target user clarity, problem/solution fit, trust/safety, design judgment, and post-action experience. |
| `kramme:copy-reviewer` | Reviews UI text for redundancy — finds labels, descriptions, placeholders, and tooltips that duplicate what the UI already communicates through structure, icons, or interaction patterns. |
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

Regular branch commits should use plain-English commit messages (no Conventional Commit prefix).

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
- Skills authoring patterns: Inspired by [mgechev/skills-best-practices](https://github.com/mgechev/skills-best-practices).
- `kramme:visual:*` skills: Adapted from [nicobailon/visual-explainer](https://github.com/nicobailon/visual-explainer).

## License

MIT
