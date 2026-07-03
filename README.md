# kramme-cc-workflow

A Claude Code plugin providing tooling for daily workflow tasks. The plugin source lives in `kramme-cc-workflow/`; this root README is the canonical project documentation.

<!-- prettier-ignore-start -->
> [!IMPORTANT]
> Thanks for checking this out. It is my personal workflow, built primarily for myself. I experiment in the open and ship updates quickly, so skills may change or occasionally be removed. Questions are always welcome. Feel free to fork, "steal" ideas, or jump straight to the [sources of inspiration](#attribution).

> [!NOTE]
> A meaningful part of this plugin's authoring workflow, browser/QA workflow, launch workflow, and output conventions is adapted from [Addy Osmani's `agent-skills`](https://github.com/addyosmani/agent-skills). The [Attribution](#attribution) section calls out the specific skills and conventions that came from Addy's work.
<!-- prettier-ignore-end -->

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
- [SkillOpt Adoption](#skillopt-adoption)
- [Local Repository Maintenance](#local-repository-maintenance)
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
claude /plugin install /path/to/kramme-cc-workflow/kramme-cc-workflow
```

### Codex

This repo includes a converter CLI (Node.js) that installs the plugin into Codex. Requires Node.js 18+. Use the plugin name from `.claude-plugin/marketplace.json` (here: `kramme-cc-workflow`).

```bash
npm install
node kramme-cc-workflow/scripts/convert-plugin.js install kramme-cc-workflow
```

Run with npx (no clone):

```bash
npx --yes github:Abildtoft/kramme-cc-workflow install kramme-cc-workflow
```

Local dev from this repo:

```bash
./kramme-cc-workflow/scripts/install-codex.sh
```

Helper scripts install missing converter runtime dependencies and forward additional args to the converter (e.g., `--codex-home`, `--agents-home`).

Codex output defaults to `~/.codex` (`prompts/` and `skills/`).

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
claude /plugin install /path/to/kramme-cc-workflow/kramme-cc-workflow
```

For Codex installs, updating is the same as installing: re-run the converter to regenerate the output (use the commands in the Codex section). This overwrites the generated files in `~/.codex`.

Restart Claude Code after updating for changes to take effect.

**Auto-update:** Since Claude Code v2.0.70, auto-update can be enabled per-marketplace.

## Getting Started

Three common workflows to try after installation:

For repository work, start with [CONTRIBUTING.md](CONTRIBUTING.md), then use
[docs/architecture.md](kramme-cc-workflow/docs/architecture.md) and
[docs/code-map.md](kramme-cc-workflow/docs/code-map.md) to find the relevant
subsystem and tests.

### Plan and implement with SIW

SIW (Structured Implementation Workflow) breaks non-trivial work into spec-driven issues tracked in local markdown files.

```bash
/kramme:siw:init            # link or create a spec, set up siw/ directory
/kramme:siw:generate-phases # break spec into phased issues
/kramme:siw:issue-implement # implement one issue at a time
/kramme:siw:close           # archive decisions and clean up
```

See [docs/siw.md](kramme-cc-workflow/docs/siw.md) for the full workflow reference.

### Review and ship a PR

```bash
/kramme:pr:code-review         # run specialized review agents on your branch
/kramme:pr:autoreview          # run the closeout code-review loop
/kramme:pr:product-review      # deep product review of your changes
/kramme:pr:resolve-review      # fix the findings
/kramme:pr:github-review       # review someone else's GitHub PR as the assigned reviewer
/kramme:pr:github-review-reply # map and reply to GitHub reviews
/kramme:pr:finalize            # final readiness check before shipping
/kramme:pr:create              # restructure commits and open the PR
/kramme:pr:fix-ci              # iterate until CI passes
```

### Inspect and test a live app

```bash
/kramme:browse http://localhost:3000         # navigate, screenshot, inspect
/kramme:qa http://localhost:3000             # structured QA with evidence
/kramme:product:review http://localhost:3000 # whole-product experience review
```

### Quick utilities

```bash
/kramme:verify:run         # run tests, linting, and type checks for changed code
/kramme:setup              # report missing local workflow dependencies
/kramme:visual:diagram     # generate an HTML diagram from any explanation
/kramme:docs:to-markdown   # convert PDF, Word, Excel, or images to Markdown
/kramme:code:refactor-pass # simplification pass on recent changes
/kramme:code:work-from-plan # route and execute a standalone implementation plan
```

All skills are listed in the reference below. Background skills (commit messages, verification guards) run automatically.

## Skills

All plugin functionality is delivered through skills. Skills can be user-invoked via the `/` menu, auto-triggered by Claude based on context, or both.

- **User-invocable**: Trigger with `/kramme:skill-name`. Skills that should never auto-run set `disable-model-invocation: true`.
- **Auto-triggered**: Claude invokes automatically when context matches the skill description.
- **Background**: Skills with `user-invocable: false` are auto-triggered only and don't appear in the `/` menu.

**Breaking change:** Separate `:team` skills have been removed. Use `--team` on the base skills instead: `/kramme:pr:code-review --team`, `/kramme:pr:resolve-review --team`, `/kramme:pr:ux-review --team`, `/kramme:siw:issue-implement --team`, `/kramme:siw:spec-audit --team`, and `/kramme:siw:implementation-audit --team`.

The skill table rows are generated from `SKILL.md` frontmatter. Run `python3 kramme-cc-workflow/scripts/generate-component-reference.py --write` to refresh them, or `python3 kramme-cc-workflow/scripts/generate-component-reference.py --check` to validate without writing.

<!-- BEGIN SOURCE-SYNCED SKILL ROWS -->

### User-Invocable Skills

#### Structured Implementation Workflow (SIW)

Local issue tracking and structured implementation planning using markdown files. See [docs/siw.md](kramme-cc-workflow/docs/siw.md) for detailed workflow documentation.

| Skill | Invocation | Arguments | Description |
| --- | --- | --- | --- |
| `/kramme:siw:init` | User | `[spec-file(s) \| folder \| discover] [--auto]` | Initialize structured implementation workflow documents in siw/ (spec, LOG.md, issues) |
| `/kramme:siw:continue` | User, Auto | — | Entry point for the Structured Implementation Workflow (SIW) — a local, markdown-based workflow for planning, tracking, and implementing multi-step work. Resumes in-flight SIW runs by reading siw/LOG.md and siw/OPEN_ISSUES_OVERVIEW.md, or routes new work to the right SIW subcommand. Triggers on "SIW", "structured workflow", or when siw/LOG.md and siw/OPEN_ISSUES_OVERVIEW.md files are detected. |
| `/kramme:siw:discovery` | User | `[topic \| spec-file(s) \| 'siw'] [--apply] [--decision-tree]` | Deep discovery interview that uncovers what you actually want, not what you think you should want. Works pre-spec or on existing specs until 90% confident. Pass --decision-tree, or ask to walk depth-first, to resolve tightly coupled decisions one at a time. |
| `/kramme:siw:issue-define` | User | `[ISSUE-G-XXX or ISSUE-P1-XXX] or [description and/or file paths for context]` | Define or improve a local SIW issue file through a guided interview. For Linear or other external trackers use kramme:linear:issue-define. |
| `/kramme:siw:generate-phases` | User | `[spec-file-path] [--auto]` | Break spec into atomic, phase-based issues with tests and validation |
| `/kramme:siw:issue-implement` | User | `<issue-id> \| --team [issue-ids \| 'phase N'] [--auto]` | Start implementing a defined local issue with codebase exploration and planning. Use --team to implement multiple independent SIW issues in parallel. |
| `/kramme:siw:product-audit` | User | `[spec-file-path(s) \| 'siw'] [--auto] [--inline]` | (experimental) Product audit of SIW specs and plans before implementation. Evaluates target user clarity, problem/solution fit, user state modeling, critical moments coverage, scope correctness, success criteria quality, and prioritization quality. Infers likely user goals and non-goals when the spec is incomplete. Not for code review or implementation auditing. Supports inline report output with --inline. |
| `/kramme:siw:spec-audit` | User | `[spec-file-path(s) \| 'siw'] [--auto] [--apply] [--model opus\|sonnet\|haiku] [--inline] [--team]` | Audit specification documents for quality — coherence, completeness, clarity, scope, actionability, testability, value proposition, and technical design. Supports --inline and --apply. Use --team for multi-agent cross-validation and codebase pattern review. |
| `/kramme:siw:spec-audit:auto-fix` | User | `[audit-report-path] [--auto] [--dry-run] [--threshold 60-100] [--allow-dirty]` | Canonical auto-fix procedure for mechanical spec-audit findings and kramme:siw:spec-audit --apply. Fixes only issues with a single obvious resolution — cross-reference errors, terminology inconsistencies, numbering mistakes, formatting issues, and weasel words replaceable with specifics already in the spec. Run after spec-audit. |
| `/kramme:siw:breakdown-findings` | User, Auto | `[audit-report-path] [finding-id(s)]` | Break down unresolved spec-audit or implementation-audit findings into executive summaries, resolution options, and a recommendation without creating SIW issues. Use it after spec-audit, spec-audit:auto-fix, or implementation-audit when you want decision-ready analysis before choosing a follow-up path. Not for product audits or direct issue creation. |
| `/kramme:siw:implementation-audit` | User | `[spec-file-path(s) \| 'siw'] [--auto] [--model opus\|sonnet\|haiku] [--team] [--inline]` | Exhaustively audit codebase implementation against specification. Detects spec divergences, undocumented implementation extensions, contract violations, and spec drift. Supports inline report output and an optional team mode for multi-agent cross-validation. |
| `/kramme:siw:resolve-audit` | User | `[audit-report-path] [finding-id(s)] [--auto]` | Resolve audit findings one-by-one with executive summaries, alternatives, recommendation, and SIW issue creation |
| `/kramme:siw:issue-reindex` | User | `[--auto]` | Remove all DONE issues and renumber remaining issues within each prefix group. Not for editing live issue content, archiving still-open issues, or moving issues between prefix groups. |
| `/kramme:siw:transfer-to-linear` | User | `[siw-dir] [--project <name-or-id>] [--team <team>] [--dry-run] [--skip-done] [--skip-existing\|--retry]` | One-way migration of a local SIW project into Linear. Creates one Linear project, migrates the main spec, supporting specs, selected contract specs, and decision log as Linear Documents, rewrites SIW-local markdown references to Linear Documents where possible, creates milestones from SIW phases and issues from SIW issues (with native blocking relations when supported), writes minimal Linear transfer markers back to migrated source issues for retry safety, then prompts to retire the local siw/ files via /kramme:siw:remove. Linear becomes the source of truth; this is not a two-way sync. Use when moving a planned SIW initiative into Linear for good. Not for implementing issues, defining new SIW issues, or generating an issue breakdown. |
| `/kramme:siw:reset` | User | — | Reset SIW workflow state while preserving the spec - migrates log decisions to spec, clears issues and log |
| `/kramme:siw:close` | User | `[--auto]` | Close an SIW project by generating permanent documentation in docs/<feature>/ and removing temporary workflow files |
| `/kramme:siw:remove` | User | — | Delete SIW workflow files from the current directory. Destructive; use kramme:siw:close first if you want to preserve documentation. |

#### Pull Requests

PR creation, review, iteration, and resolution.

| Skill | Invocation | Arguments | Description |
| --- | --- | --- | --- |
| `/kramme:pr:create` | User | `[--auto] [--draft]` | Use when creating a PR from the current branch with narrative-quality commits and a generated description. Orchestrates branch setup, commit restructuring via kramme:git:recreate-commits, and description generation via kramme:pr:generate-description before pushing and opening the PR via gh. |
| `/kramme:pr:product-review` | User, Auto | `[--base <branch>] [--threshold 0-100] [--inline]` | Deep product review of branch and local changes. Evaluates user-value alignment, flow completeness, missing states, copy/defaults, permission behavior, adjacent-flow regressions, and prioritization quality. Infers likely user goals and non-goals when rationale is missing. Not for UX heuristics, accessibility, or visual consistency -- use pr:ux-review for those. Supports inline report output with --inline. |
| `/kramme:pr:code-review` | User, Auto | `[aspects] [--emphasize <dim>...] [--base <branch>] [--previous-review <path>] [--parallel] [parallel] [--team] [--inline]` | Analyze code quality of branch changes using specialized review agents (tests, errors, types, security, performance, slop, lean deletion, refactor fit, simplification). Outputs REVIEW_OVERVIEW.md with actionable findings, or replies inline with --inline. Use --team for multi-agent cross-validation. Not for UX, visual, or accessibility review -- use kramme:pr:ux-review for those. |
| `/kramme:pr:autoreview` | User | `[code-review args] [--base <branch>] [--inline] [--parallel]` | Runs kramme:pr:code-review as a closeout review loop for local or PR branch changes before commit, ship, or final response. Use when the user asks for autoreview, second-model review, or a final code-review pass after non-trivial edits. Not for UX, visual, accessibility, or product review. |
| `/kramme:pr:resolve-review` | User | `[--team] [--implement-only] [--granular] [--severity ...] [--source local\|online] [review\|url\|instructions]` | Resolve findings from code reviews by implementing fixes and documenting changes. Implements fixes as commits on the current branch. Use --team to resolve independent findings in parallel by file area. |
| `/kramme:pr:github-review-reply` | User | `[--auto] [--implement\|--no-implement] [--post] [--resolve] [--inline] [--human-only\|--include-bots] [--all] [--only <login>] [pr-url\|instructions]` | Maps GitHub PR review feedback from humans, bots, and apps, including inline review threads, review-summary comments, and general PR comments; facilitates needed code changes; drafts and humanizes action-based responses; and optionally posts replies or resolves addressed inline threads with gh. Use when reviewers left GitHub comments that need triage, implementation, or response. Not for fixing CI, generating internal review findings, or resolving local REVIEW_OVERVIEW.md findings. |
| `/kramme:pr:github-review` | User | `[pr-number\|pr-url] [--base <ref>] [--categories a11y,ux,product,visual] [--code-only] [--fresh] [--include-bots] [--all-threads] [--inline] [--keep-worktree]` | Review a GitHub pull request where you are the assigned reviewer, not the author or assignee. Fetches the PR into an isolated git worktree (your branch untouched), runs code-quality agents plus UX/accessibility agents when the PR touches UI, and writes a reviewer-facing report with file:line-anchored findings, draft inline comments phrased as concise, humanized Socratic questions, and a recommended verdict. Supports ongoing reviews: maps existing author and reviewer comments, drafts replies to threads awaiting you (including replies to your own earlier comments), and skips findings already raised in the conversation. Read-only toward GitHub: it does not post comments or review decisions; you submit the review yourself. Triggers on reviewing someone else's PR or a review-requested PR. Not for reviewing your own branch before shipping (use kramme:pr:code-review), responding to reviewers on your own PR (use kramme:pr:github-review-reply), or resolving review findings (use kramme:pr:resolve-review). |
| `/kramme:pr:fix-ci` | User | `[--fixup] [--auto] [--no-consolidate]` | Iterate on a PR until CI passes. Use when you need to fix CI failures, address review feedback, or continuously push fixes until all checks are green. Automates the feedback-fix-push-wait cycle. |
| `/kramme:pr:generate-description` | User | `[--auto] [--no-update] [--visual] [--base <ref>]` | Write a structured PR title and body from git diff, commit log, and Linear context. Outputs markdown for copy-paste or, when explicitly invoked with --auto, updates an existing PR. |
| `/kramme:pr:walkthrough` | User | `[--base <ref>] [--output <path>]` | Generate a local interactive PR walkthrough as a static D3 HTML artifact with guided system overview, data flow, code dependency, and user action views. Use when a reviewer needs orientation to a branch or GitHub PR before review. Not for actionable code review findings, PR description generation, publishing, or live UX audits. |
| `/kramme:pr:verify-description` | User, Auto | `[--fix] [--base <ref>] [--strict]` | Compare an existing PR's title and body against the actual branch diff and report drift — false claims, missing major changes, stale scope, missing risk callouts. Use after pushing changes to a branch with an open PR, or before requesting review. Read-only by default; add --fix to delegate to kramme:pr:generate-description for an updated description. Complements kramme:pr:code-review (which checks description accuracy as one signal among many code-quality checks) by being a fast, focused, single-purpose check that runs in seconds. |
| `/kramme:pr:copy-review` | User, Auto | `[--base <branch>] [--threshold 0-100] [--inline]` | Review PR and local changes for unnecessary, redundant, or duplicative UI text — labels, descriptions, placeholders, tooltips, and instructions that the UI already communicates through its structure. Supports inline report output with --inline. |
| `/kramme:pr:ux-review` | User, Auto | `[app-url\|auto] [--categories a11y,ux,product,visual] [--threshold 0-100] [--base <branch>] [--parallel] [--team] [--inline]` | Audit UI, UX, and product experience of PR and local changes using specialized agents for usability heuristics, product thinking, visual consistency, and accessibility. Supports inline report output with --inline. Use --team for multi-agent cross-validation. |
| `/kramme:pr:finalize` | User | `[--auto] [--fix] [--skip <skill,...>] [--app-url <url>] [--base <branch>]` | (experimental) Final PR readiness orchestration. Coordinates verify:run, pr:code-review, pr:product-review, pr:ux-review, qa, and pr:generate-description. Produces a ready/not-ready/ready-with-caveats verdict. Not for creating PRs, fixing CI, or merging code. |
| `/kramme:pr:rebase` | User | `[--auto] [--force-push] [--base <branch>]` | Rebase current branch onto latest main/master, auto-resolving conflicts with safe defaults unless dangerous --auto is used, then force push with --force-with-lease. Use when your PR is behind the base branch. |
| `/kramme:pr:plan-split` | User | `[--base <branch>] [--auto]` | Analyze the current branch's diff and break it into smaller, independently mergeable PRs. Categorizes changes by feature, layer, and module; detects coupling; and proposes a concrete seam (vertical, stack, by file group, or horizontal — preferring vertical) for each slice with file lists, line counts, dependency order, test plan, and rationale. Hands the slices to kramme:code:breakdown-findings to write the PR_PLAN_*.md artifacts, supplying a worktree-based implementation setup that extracts each slice's changes from the branch the skill is run in. Use before opening a PR that bundles unrelated work, when a reviewer asks for a split, or when a branch has grown too large to review. Plans only; does not edit source code, create branches, or rewrite git history. |
| `/kramme:pr:update-split-plans` | User | `[plan-file ... \| --all] [--worktree <path>] [--source <ref>] [--base <ref>] [--auto]` | Updates existing split-PR planning artifacts (`PR_PLAN_INDEX.md`, `PR_PLAN_REJECTIONS.md`, and `PR_PLAN_W##L_*.md`) after individual slices have been implemented, reviewed, rebased, or had follow-up fixes folded in. Use when split plan files are stale, noisy, or inaccurate relative to current slice branches/worktrees. Not for generating a fresh split; use kramme:pr:plan-split or kramme:code:breakdown-findings for new plan creation. |

#### CI

CI/CD pipeline design and gate planning.

| Skill | Invocation | Arguments | Description |
| --- | --- | --- | --- |
| `/kramme:ci:design-pipeline` | User, Auto | — | Design a CI/CD pipeline with quality gates, a <10-minute budget, feature-flag lifecycle, and an exit checklist. Use when adding a new CI pipeline, changing gate configuration, or planning a rollout for a new service. Complementary to kramme:pr:fix-ci (which fixes failures in an existing pipeline). Covers gate ordering, secrets storage, branch protection, rollback mechanism, and staged-rollout guardrails — not a rollout-execution runbook. |

#### Launch

Post-merge rollout, release communication, canary gates, and rollback discipline.

| Skill | Invocation | Arguments | Description |
| --- | --- | --- | --- |
| `/kramme:launch:rollout` | User | — | Execute a post-merge launch with staged rollout, numeric decision thresholds, and rollback triggers. Sequence — staging → prod (flag OFF) → team enable → 5% canary → 25→50→100% gradual → full rollout + 1-week monitor + flag cleanup. Use after merging a user-facing change that needs safe rollout. Complements kramme:pr:finalize (pre-merge readiness) with post-merge verification, canary gates, and rollback paths. Not for PR creation, CI debugging, or pre-merge checks. |
| `/kramme:launch:announce` | User | `[feature, PR, or release context] [--channels changelog,social,email,demo]` | Drafts user-facing launch announcement copy for a shipped feature from PRs, diffs, changelog notes, or user-provided context. Supports changelog blurbs, short social posts, email snippets, and demo scripts. Use after rollout or when announcement drafts are needed. Drafts only; not for staged rollout, rollback decisions, posting, publishing, or internal changelog summaries. |

#### Browser & QA

Live product inspection and structured testing.

| Skill | Invocation | Arguments | Description |
| --- | --- | --- | --- |
| `/kramme:browse` | User, Auto | `<url\|auto> [--screenshot] [--console] [--network]` | (experimental) Browser operator for live product inspection. Detects available browser MCP tooling (claude-in-chrome, chrome-devtools, playwright) and provides consistent navigation, screenshots, interaction, and evidence capture. Not for code-only analysis. |
| `/kramme:qa` | User, Auto | `<url\|auto> [quick\|diff-aware\|targeted <route>] [--base <branch>] [--regression] [--inline] [--legacy-console]` | Structured QA testing with evidence capture. Runs smoke checks, diff-aware validation, or targeted route testing against a live app. Produces QA_REPORT.md with screenshots, repro steps, severity, and recommended fixes, or replies inline with --inline. Uses browser MCP when available and falls back to code-only analysis otherwise. Not for logging multiple bugs from a manual pass (use kramme:qa:intake) or tracing one bug's root cause (use kramme:debug:investigate). |
| `/kramme:qa:intake` | User | `[optional starting context]` | Conversational QA intake session - user describes bugs they encountered, the agent lightly clarifies, explores the codebase in the background for domain language, and files durable Linear or SIW tickets one issue at a time. Use when the user has multiple bugs from a manual QA pass and wants to log them rapidly without per-issue deep interviews. Not for live-app browser testing (use kramme:qa), not for tracing the root cause of a single bug or applying a fix (use kramme:debug:investigate), not for one well-refined ticket with a 5-round interview (use kramme:linear:issue-define). |
| `/kramme:product:review` | User | `<url\|auto> [--flows <flow1,flow2,...>] [--focus <dimension>] [--inline]` | (experimental) Whole-product review across flows and surfaces. Requires a live app URL or auto-detected local dev server. Evaluates navigation coherence, feature discoverability, onboarding, cross-flow consistency, dead ends, friction, and trust/safety. Produces PRODUCT_AUDIT_OVERVIEW.md, or replies inline with --inline. Not for branch-scoped PR review (use pr:product-review) or pre-implementation spec audit (use siw:product-audit). |

#### Product Strategy

Repo-level product strategy and product health feedback loops.

| Skill | Invocation | Arguments | Description |
| --- | --- | --- | --- |
| `/kramme:product:strategy` | User | `[optional: section or notes to revisit, e.g. 'metrics', 'active tracks']` | Create or update repo-root STRATEGY.md as a concise product anchor covering target problem, approach, users, metrics, active tracks, milestones, and non-goals. Use when starting a product, revisiting direction, grounding discovery/spec/SIW work, or resolving product-context drift. Not for one-off feature specs, roadmaps, or implementation plans. |
| `/kramme:product:pulse` | User | `[lookback window, e.g. 24h, 7d, 1h] [--inline]` | Generate a time-windowed product pulse report in docs/pulse-reports/ covering usage, quality, errors, performance, customer signals, and followups. Use for weekly recaps, launch checks, "how are we doing", or strategy feedback loops. Works with partial or manual sources. Not for QA test reports, PR review, or editing STRATEGY.md directly. |

#### Product Design

Product critique and design-direction skills.

| Skill | Invocation | Arguments | Description |
| --- | --- | --- | --- |
| `/kramme:product:design-critic` | User, Auto | `[file-path, screenshot, URL, or product question]` | (experimental) Sharpen product design judgment for software UI/UX, interaction flows, jobs-to-be-done, hierarchy, trust, governance surfacing, and competitor-informed critique. Use when critiquing or shaping a product surface, card, panel, workflow, chat experience, or design strategy instead of merely suggesting visual polish. |

#### Code Quality & Review

Code cleanup, refactoring, and bug/security review.

| Skill | Invocation | Arguments | Description |
| --- | --- | --- | --- |
| `/kramme:code:cleanup-ai` | User | `[base-branch] [--auto]` | Remove AI-generated code slop from a branch. Use when cleaning up AI-generated code, removing unnecessary comments, defensive checks, or type casts. Checks the branch diff against the resolved base and fixes style inconsistencies. Not for generated, vendored, lockfile, snapshot, or `*.d.ts` files. |
| `/kramme:code:migrate` | User | `<target e.g. 'Angular 19', 'React 19', 'Node 22'> [--auto]` | (experimental) Plan and execute framework or library version migrations with phased upgrades and verification gates. Use when upgrading major framework versions (Angular, React, Node) or migrating between libraries. |
| `/kramme:code:rewrite-clean` | User | — | Scrap a working-but-mediocre fix and reimplement elegantly. Use after making a fix that works but feels hacky. Applies Chesterton's Fence before scrapping, emits SIMPLICITY CHECK at design time, and rejects rewrites that require modifying tests to pass. |
| `/kramme:code:refactor-pass` | User | — | Perform a refactor pass focused on simplicity after recent changes. Use when the user asks for a refactor/cleanup pass, simplification, or dead-code removal on a narrow scope and expects build/tests to verify behavior. Applies Chesterton's Fence before removing code, rejects simplifications that require modifying tests, and works one slice at a time. |
| `/kramme:code:incremental` | User | `[--refactor]` | (experimental) Deliver changes in small, verified slices with scope discipline, incremental verification between slices, and feature-flag guardrails for incomplete work. Use when implementing any change that spans more than one file or commit. Enforces one-thing-at-a-time, rollback-friendly commits, and explicit separation of in-scope work from noticed-but-untouched observations. Includes a refactor mode (opt-in via --refactor or after kramme:code:refactor-opportunities) that adds an interview-driven Decision Document and a Fowler-style tiny-commits plan where every intermediate state leaves the codebase working. |
| `/kramme:code:work-from-plan` | User | `[plan path \| inline plan]` | Routes and executes a standalone markdown implementation plan. Use when the user provides a PR_PLAN_*.md file, pasted plan, or one-off implementation checklist that is not already a Linear or SIW issue. Detects when to delegate to kramme:linear:issue-implement or kramme:siw:issue-implement, gathers codebase context, surfaces MISSING REQUIREMENT blockers, and proceeds directly only for bounded current-branch work. Not for planning from scratch, PR creation, CI watching, or large multi-phase initiatives that should become SIW. |
| `/kramme:code:source-driven` | User, Auto | — | (experimental) Ground framework and library decisions in official documentation with explicit citation. Use when touching any external framework, library, CLI tool, or cloud service — especially recent versions where training data may be stale. Fetches via Context7 MCP or direct URLs, implements against documented patterns, and cites deep links with quoted passages when decisions are non-obvious. |
| `/kramme:code:copy-review` | User, Auto | `[scope — e.g. src/components, or omit for full codebase]` | Scan the codebase (or a specified scope) for unnecessary, redundant, or duplicative UI text. Identifies labels, descriptions, placeholders, tooltips, and instructions that could be removed because the UI already communicates the same information through its structure. |
| `/kramme:code:breakdown-findings` | User | `[source-file-or-content] [--auto] [--resume] [--reconcile]` | Cluster validated review/audit/QA findings into PR-sized implementation plans with index, rejection record, repo recon, sequencing, and reconcile/resume support. Accepts structured findings, report files, current-dialogue findings, or marked/inferred pre-clustered handoffs. Not for raw bug lists, single issues, or unvalidated triage. |
| `/kramme:code:refactor-opportunities` | User, Auto | `[full \| pr \| path <file-or-folder> \| feature <name>]` | Scan the full codebase, current PR, a named file/folder, or a named feature for refactoring candidates. Use when the user asks to find refactor opportunities, audit code quality, identify tech debt, or wants a codebase health check. Flags themes whose combined blast radius exceeds 500 lines as automation candidates. |
| `/kramme:code:weakness-audit` | User | `[full \| path <file-or-folder> \| feature <name>] [--output <path>] [--max-findings N] [--solo]` | Identify the biggest codebase weaknesses across maintainability, readability, and correctness using a multi-agent audit team by default, then write a ranked CODEBASE_WEAKNESS_REPORT.md. Use when the user asks for top weaknesses, codebase health risks, maintainability/readability/correctness audit, or where to invest cleanup effort. Use --solo only for a faster single-threaded fallback. Not for PR-only review, implementation, security-specific audits, or broad refactor opportunity inventories. |
| `/kramme:code:agent-readiness` | User | `[--auto]` | Audit a codebase for agent-nativeness — score how well-optimized it is for AI coding agents across 5 dimensions and generate a prioritized refactoring plan. |
| `/kramme:code:api-design` | User, Auto | `[--design-twice]` | (experimental) Design stable APIs and module boundaries. Covers contract-first approach, Hyrum's Law, validation placement (at boundaries, not between internal functions), consistent error shapes with HTTP status mapping, naming conventions, and TypeScript patterns for interface stability. Use when adding HTTP endpoints, public modules, SDK surfaces, or any interface with external or cross-team callers. Includes a Design It Twice mode (opt-in via --design-twice or the phrase 'design it twice') that drafts radically different shapes — in parallel via sub-agents on Claude Code, sequentially elsewhere — before committing to one. |
| `/kramme:code:harden-security` | User, Auto | — | Apply security-by-default when writing code that handles user input, authentication, data storage, or external integrations. Use when building features that accept untrusted data, manage user sessions, or call third-party services. Complements the review-time auth-reviewer / data-reviewer / injection-reviewer agents with author-time guardrails. |
| `/kramme:code:performance` | User, Auto | — | (experimental) Measure-first performance discipline tied to Core Web Vitals (LCP, INP, CLS). Use when users or monitoring report slowness, CWV scores miss thresholds, performance requirements exist in the spec, you suspect a recent change introduced a regression, or you're building features that handle large datasets or high traffic. Enforces baseline measurement, single-bottleneck fixes, verification, and regression guards. Complements the review-time `performance-oracle` agent. |
| `/kramme:code:optimize` | User | `[spec.yaml \| optimization goal] [--auto]` | (experimental) Run metric-driven optimization experiments. Use when search relevance, clustering quality, prompt quality, build latency, ranking behavior, bundle size, or another measurable outcome needs repeatable variants instead of sequential guess-and-check. Requires a measurement command or judge rubric, persists baselines and experiment logs under `.context/code-optimize/`, and can use serial or worktree-isolated experiments. Not for ordinary one-shot performance fixes, implementation without a harness, or speculative optimization with no metric. |
| `/kramme:code:deprecate` | User | — | Plan and execute deprecation of code, features, APIs, or modules, treating code as a liability. Covers the decision to deprecate (5-question checklist), Hyrum's Law risk assessment, Advisory vs Compulsory deprecation paths, Strangler / Adapter / Feature-Flag migration patterns, and a four-step workflow: build replacement → announce → migrate incrementally → remove old. Emits SIMPLICITY CHECK, NOTICED BUT NOT TOUCHING, UNVERIFIED, and ASK FIRST markers. Use when removing legacy systems, sunsetting features, retiring API versions, or cleaning up zombie code with unknown owners. |

#### Debug

Bug investigation and root cause analysis.

| Skill | Invocation | Arguments | Description |
| --- | --- | --- | --- |
| `/kramme:debug:investigate` | User | `[bug description, error message, or issue reference] [--auto]` | Structured bug investigation workflow: reproduce, isolate, trace root cause, and fix. Use when debugging a bug, investigating an error, or tracking down a regression. |
| `/kramme:debug:triage-to-issue` | User | `[bug description, error message, or Linear/SIW issue ref] [--yes \| --auto]` | (experimental) Triage a bug end-to-end: orchestrate root-cause investigation, design a TDD fix plan with RED-GREEN cycles, and file a refactor-durable Linear or local SIW issue in one mostly-hands-off pass. Use when a bug needs to become an implementation-ready ticket without manually chaining kramme:debug:investigate, kramme:test:tdd, and kramme:linear:issue-define. Composes kramme:debug:investigate and kramme:linear:issue-define via skill invocation (or by reading the sub-skill's SKILL.md when blocked); captures kramme:test:tdd conventions inline in v1. Not for the full interactive investigation with confidence gates (use kramme:debug:investigate alone), not for conversational multi-bug QA-intake sessions (use kramme:qa:intake), not for implementing the fix (use kramme:linear:issue-implement or kramme:siw:issue-implement after this skill files the ticket). |

#### Dependencies

Dependency auditing and management.

| Skill | Invocation | Arguments | Description |
| --- | --- | --- | --- |
| `/kramme:deps:audit` | User | `[--auto]` | (experimental) Audit project dependencies for outdated packages, security vulnerabilities, and staleness. Generates a prioritized upgrade plan with risk assessment. |

#### Testing

Test generation, coverage, and test-first discipline.

| Skill | Invocation | Arguments | Description |
| --- | --- | --- | --- |
| `/kramme:test:tdd` | User, Auto | — | (experimental) Drive implementation with tests. Write a failing test that characterizes the requirement or reproduces the bug, implement the minimum to pass, then refactor with tests green. Use when implementing new logic, fixing a bug (Prove-It pattern), or changing behavior. Complementary to kramme:test:generate, which writes tests for existing untested code. |
| `/kramme:test:generate` | User | `[file-path or directory] [--auto]` | (experimental) Generate tests for existing code by analyzing project test patterns and conventions. Use when adding test coverage to untested files or generating test stubs. |

#### Git

Git history management and commit operations.

| Skill | Invocation | Arguments | Description |
| --- | --- | --- | --- |
| `/kramme:git:fixup` | User | `[--skip-tests\|--skip-build\|--skip-lint\|--skip-all] [--no-confirm] [--base=<branch>] [instructions]` | Intelligently fixup unstaged changes into existing commits on the current branch. Maps each changed file to its most recent commit, validates (build/test/lint), creates fixup commits, and autosquashes. |
| `/kramme:git:recreate-commits` | User | `[--auto\|--granular] [--base <branch>] [--after <commit>] [--force-backup]` | Use when asked to recreate commits with narrative-quality history on the current branch. Not for merged branches or shared branches others have based work on — it rewrites history and force-pushes with --force-with-lease. |
| `/kramme:git:clean-gone-branches` | User | `[--prune] [--delete --yes <branch>...] [--force]` | Find local git branches whose upstream remote branch is gone, list associated worktrees, label Conductor workspace paths, and delete only after explicit confirmation. Use for local branch hygiene after remote branches are merged or deleted. Not for deleting the current branch, deleting active worktrees, pruning without review, or rewriting history. |
| `/kramme:git:worktree` | User | `<list\|create\|remove> [options]` | Safely list, create, and remove git worktrees with checks for existing paths, checked-out branches, and Conductor workspace directories. Use for manual worktree operations during PR splitting or local parallel development. Not for branch cleanup, deleting gone branches, renaming branches, or bypassing Conductor workspace archival. |

#### Linear

Linear issue tracking integration.

`/kramme:linear:issue-implement`: Fetches issue details plus referenced Linear issues/documents when accessible, reports inaccessible referenced assets, and uses that context during planning.

| Skill | Invocation | Arguments | Description |
| --- | --- | --- | --- |
| `/kramme:linear:issue-define` | User | `[issue-id] or [description and/or file paths for context] [--auto]` | Requires the Linear MCP server. Create or improve a well-structured Linear issue through guided refinement. Use with --auto to create one new Linear issue from rough input using light clarification, duplicate checking, metadata selection, and approval instead of the full interview. Not for implementing Linear issues (use kramme:linear:issue-implement), multi-bug QA intake (use kramme:qa:intake), or root-cause bug triage (use kramme:debug:triage-to-issue). |
| `/kramme:linear:issue-implement` | User | `<ISSUE-ID> [--auto]` | Requires Linear MCP. Start implementing a Linear issue with branch setup, planning, and guided or --auto workflows. For SIW-tracked work, use kramme:siw:issue-implement instead. |
| `/kramme:linear:select-next` | User | `[team] [--interest <work preference>] [--mine\|--unassigned\|--both] [--project <name>] [--label <name>] [--limit <n>]` | Requires Linear MCP. Selects the most valuable available issue to start from a Linear team by comparing assigned-to-me and unassigned issues, optional work-interest preferences, and parallel-ready candidates. Use when deciding what to pick up next. Not for creating, editing, implementing, or closing Linear issues. |

#### Visual

Generate styled, self-contained HTML pages with diagrams, data tables, and interactive visualizations. Output opens in the browser.

| Skill | Invocation | Arguments | Description |
| --- | --- | --- | --- |
| `/kramme:visual:diagram` | User, Auto | `[topic or description]` | Generate beautiful, self-contained HTML pages that visually explain systems, code changes, plans, and data. Use when the user asks for a diagram, architecture overview, flowchart, schema, or any visual explanation of technical concepts. Also use proactively when about to render a large ASCII table (4+ rows and 3+ columns) — present it as a styled HTML page instead. |
| `/kramme:visual:demo-reel` | User | `[what to capture] [--url <url>\|auto] [--tier static\|before-after\|browser-reel\|terminal-recording]` | Capture local demo evidence for observable product behavior: screenshots, before/after image sets, browser reels, terminal recordings, and short GIF/video proof. Use when shipping UI changes, CLI features, or any change where PR reviewers would benefit from visual or behavioral evidence. |
| `/kramme:visual:diff-review` | User | `[branch\|commit\|PR#\|range]` | Use when you want a shareable visual walkthrough of an existing branch, PR, commit, or range diff. Generates a self-contained HTML artifact with before/after architecture comparison, KPI dashboard, Mermaid dependency graphs, explanatory review notes, and decision log. Not an actionable PR/code review workflow; use kramme:pr:code-review for inline code findings or kramme:pr:ux-review for live UX/product review. |
| `/kramme:visual:plan-review` | User | `[plan-file-path] [codebase-path]` | Generate a visual HTML plan review comparing current codebase state vs. a proposed implementation plan, with architecture diagrams, blast radius analysis, and risk assessment |
| `/kramme:visual:project-recap` | User | `[time-window: 2w\|30d\|3m]` | Generate a visual HTML project recap to rebuild mental model when returning to a project — architecture snapshot, recent activity timeline, decision log, and cognitive debt hotspots |
| `/kramme:visual:generate-image` | User | `[prompt or editing instructions]` | Generate and edit images using Google's Gemini 3 Pro Image API. Use when the user asks to generate, create, edit, modify, change, alter, or update images. Also use when user references an existing image file and asks to modify it in any way (e.g., "modify this image", "change the background", "replace X with Y"). Supports both text-to-image generation and image-to-image editing with configurable resolution (1K default, 2K, or 4K for high resolution). DO NOT read the image file first - use this skill directly with the --input-image parameter. |
| `/kramme:visual:onboarding` | User, Auto | `[focus-area or audience]` | Generate an interactive HTML onboarding guide for newcomers to a codebase — architecture overview, domain model, key flows, conventions, and getting-started walkthrough. |

**API key setup for `/kramme:visual:generate-image`:**

```bash
# Required for image generation/editing
export GEMINI_API_KEY="your-api-key-here"
```

This works in both Claude Code and Codex. If running the script directly, you can also pass `--api-key` instead of using an environment variable.

#### Discovery & Documentation

Requirements discovery, document conversion, and text processing.

| Skill | Invocation | Arguments | Description |
| --- | --- | --- | --- |
| `/kramme:discovery:interview` | User | `[file-path or topic description] [--ideate] [--decision-tree] [--research]` | Conduct an in-depth interview about a topic/proposal to uncover requirements, priorities, and non-goals, then create a comprehensive plan. Pass --ideate for divergent framing, --decision-tree / depth-first language to resolve tightly coupled decisions one question at a time, or --research to launch topic-specific research agents before the interview. |
| `/kramme:docs:add-greenfield-policy` | User | — | Add the Hard-Cut Greenfield Policy section to AGENTS.md or CLAUDE.md. Use when setting up a new greenfield project or adding the no-compatibility-code policy to an existing project. Not for editing or customizing the policy after it has been added. |
| `/kramme:docs:adr` | User | `[decision title]` | Author Architecture Decision Records for significant, long-lived decisions. Creates ADRs in docs/decisions/ with sequential numbering and lifecycle states (PROPOSED / ACCEPTED / SUPERSEDED / DEPRECATED). Detects and preserves existing ADR format when one is in use; falls back to a Nygard-style template otherwise. Use when adopting a new pattern, committing to a dependency, changing a public interface, changing the data model, or rejecting an alternative a future maintainer might reasonably re-propose. For in-project decisions during a tracked SIW initiative use /kramme:siw:close's decision log instead. |
| `/kramme:docs:feature-spec` | User | `[feature name or brief description] [--synthesize\|--auto]` | Author a lightweight PRD-style feature spec before implementation. Produces a single reviewable markdown artifact covering objective, scope, boundaries, assumptions, non-goals, and testing strategy. Use when starting a feature that needs written alignment before coding but does NOT warrant the full siw/ tracked workflow. Pass --synthesize, --auto, or say "draft straight from context" to skip the assumptions block when the current conversation already grounds enough of the spec. For tracked initiatives (phased issues, LOG, audit) use kramme:siw:init instead. |
| `/kramme:docs:out-of-scope` | User | `<record\|check\|append\|reconsider> <concept>` | (experimental) Record, check, append, or reconsider rejected enhancement concepts in the project's `.out-of-scope/` directory. One markdown file per concept; substantive reason + prior-request list. Use when the team rejects an enhancement and wants to remember why, or when checking whether a new request matches a prior rejection. Not for bug rejections (close as wontfix with a comment), not for deferrals (use issue priority/status instead), not for cross-repo aggregation. |
| `/kramme:docs:review` | User | `[markdown-path] [--inline\|--file\|--output <path>]` | Review one Markdown document outside tracked SIW workflows: requirements, implementation plans, strategy drafts, README/docs drafts, proposals, and decision drafts. Classifies the document, selects focused review lenses, and returns severity-ordered findings inline by default or in a requested report file. Not for source-code review, PR diffs, live-product review, or documents under siw/; use SIW audit skills for tracked SIW artifacts. |
| `/kramme:docs:solution-note` | User | `[problem, lesson, or context]` | Create a reusable solved-problem note in docs/solutions/ after a bug fix, migration, repeated workflow, tricky refactor, or implementation lesson. Captures problem context, failed approaches, final approach, code references, verification, and reuse cautions so future sessions can apply the pattern. Use when the lesson should outlive chat or PR context. Not for long-lived architecture decisions (use kramme:docs:adr), domain vocabulary (use kramme:docs:ubiquitous-language), feature specs, or rejected enhancement scope. |
| `/kramme:docs:solution-refresh` | User | `[solution-note-path\|--all] [--apply]` | Audit docs/solutions/ notes for stale solved-problem knowledge. Compares referenced files, commands, and claims against the current codebase; classifies notes as keep, update, consolidate, or delete; and requires confirmation before stale-note deletion or consolidation. Use when solution notes may have aged, code references moved, or related bugs changed the lesson. Not for creating new solution notes, ADRs, glossary entries, feature specs, or broad documentation rewrites. |
| `/kramme:docs:to-markdown` | User, Auto | — | Convert documents and files to Markdown using markitdown. Use when converting PDF, Word (.docx), PowerPoint (.pptx), Excel (.xlsx, .xls), HTML, CSV, JSON, XML, images (with EXIF/OCR), audio (with transcription), video via Azure Content Understanding, ZIP archives, YouTube URLs, or EPubs to Markdown format for LLM processing or text analysis. |
| `/kramme:docs:ubiquitous-language` | User | — | Extract a DDD-style ubiquitous language glossary from the current conversation, flagging ambiguities and proposing canonical terms. Saves to UBIQUITOUS_LANGUAGE.md at the repo root. Use when the user wants to define domain terms, build a glossary, harden terminology, or mentions 'ubiquitous language' or 'DDD'. Not for general programming concepts (array, function, endpoint), code-level type/class glossaries, or per-feature naming inside a single module. |
| `/kramme:text:humanize` | User, Auto | `[file-path or text]` | Remove signs of AI-generated writing from text to make it sound natural and human-written. Use when editing or reviewing prose for AI-isms. Can write the result back to a source file on confirmation. Not for code, quoted passages, or text that must stay verbatim. |
| `/kramme:skill:create` | User | `[skill-name or description]` | Guide the creation of a new Claude Code plugin skill with best-practice structure, optimized frontmatter, and progressive disclosure. Use when creating a new skill from scratch or scaffolding a skill directory. Not for editing or refactoring existing skills. |
| `/kramme:skill:review` | User, Auto | `[skill-path \| skill-name \| proposed skill text]` | Reviews plugin skills for focused scope, progressive disclosure, portability, safety, retry behavior, and documentation quality. Use when auditing a SKILL.md, skill directory, or proposed skill text against skill-authoring standards. Not for creating new skills, editing skills, or reviewing ordinary application code. |

#### Learning

Human comprehension checks and teach-back workflows.

| Skill | Invocation | Arguments | Description |
| --- | --- | --- | --- |
| `/kramme:learn:verify-understanding` | User | `[topic: PR, branch, feature, document, spec, etc.] [--answer-options\|--choices]` | Guides topic-level understanding verification for a PR, branch, feature, document, spec, design decision, bug fix, or other concrete subject. Use when the user asks to confirm, quiz, drill, teach-and-check, or verify that they understand a topic. Supports optional answer choices for quiz prompts. Maintains a topic-specific checklist artifact and requires demonstrated understanding before marking the topic complete. Not for ordinary explanations without verification, end-of-session summaries, or code/test correctness checks. |

#### Workflow & Configuration

Session management, verification, artifact cleanup, and hook configuration.

| Skill | Invocation | Arguments | Description |
| --- | --- | --- | --- |
| `/kramme:setup` | User, Auto | `[--json\|--help]` | Run a read-only environment health check for this plugin's local workflow tools, repo context, optional CLIs, and detectable Conductor/worktree state. Use after installing the plugin, when a skill fails because a dependency may be missing, or before running a workflow in a new workspace. Not for installing tools, changing config, or repairing broken environments automatically. |
| `/kramme:workflow-artifacts:cleanup` | User | `[--auto]` | Delete workflow artifacts — review and audit overviews, QA reports, generated PR plans, SIW tracking files, visual diagram HTML, and local context evidence — from the working directory and shared artifact folders. Confirms before deleting; SIW specification files are kept unless you explicitly include them. Recoverable via Trash when `trash` is installed, otherwise permanent. |
| `/kramme:changelog:generate` | User | `[daily\|weekly\|plugin-release-notes <question>]` | Produce daily or weekly changelogs from recent PRs merged to main, or answer kramme plugin release-note questions from local changelog and GitHub release data with citations. Use for recent merge summaries, release notes, and "what changed in the plugin?" questions. Returns text only; reads PRs/releases read-only and writes/sends nothing. Not for launch announcement copy, posting, publishing, tagging releases, or editing CHANGELOG.md. |
| `/kramme:hooks:configure-links` | User | `[show\|reset\|KEY=VALUE ...]` | Configure the context-links hook by updating its persistent config file with workspace, team key, and issue regex overrides. Use when end users want to set up or change context-links behavior without manually editing files. |
| `/kramme:hooks:toggle` | User | `<status\|reset\|hook-name> [enable\|disable]` | Enable, disable, list, or reset hook toggles for the kramme-cc-workflow plugin. Use when a hook is firing unwantedly, when a new hook needs to be switched on, or when the user asks about current hook state. |
| `/kramme:session:search` | User, Auto | `[question or topic] [--days N] [--platform claude\|codex\|cursor]` | Searches prior coding-agent sessions across Claude Code, Codex, and Cursor using safe metadata/skeleton extraction before synthesis. Use when the user asks what was tried before, references previous attempts, or needs related prior-session context for a coding task. Not for summarizing the current session, personal retrospectives, git history, or broad non-coding history searches. |
| `/kramme:session:automate-repeats` | User | `[session-paths or --recent N] [--create\|--auto]` | Reviews recent agent session transcripts to find repeated manual workflows or repeated user asks, then proposes and optionally scaffolds only useful new skills or custom subagents. Use when the user asks to inspect recent sessions, find automation opportunities, or create reusable workflows from repeated work. Not for summarizing one session, general retrospectives, or codebase refactoring. |
| `/kramme:session:context-setup` | User, Auto | — | Configure effective agent context at session start or after output quality degrades. Covers rules-file verification (CLAUDE.md / AGENTS.md), pre-task context loading (files to modify + related tests + one similar-pattern example + type definitions), context-window hygiene, and trust-level tagging for inputs. Use when starting a new session, switching major tasks, or when output quality drops. Not for trivial single-file edits or mid-task incremental loads — it is a session-boundary ritual, not a per-edit step. |
| `/kramme:verify:run` | User, Auto | — | Run verification checks (tests, formatting, builds, linting, type checking) for affected code based on the project's configuration. |

#### Nx

Nx workspace tooling and configuration.

| Skill | Invocation | Arguments | Description |
| --- | --- | --- | --- |
| `/kramme:nx:setup-portless` | User | — | Set up portless in an Nx workspace with dev:local/dev:full targets. Use when adding portless to an Nx project or wiring up Nx targets for local HTTPS development. |

### Background Skills

Auto-triggered by Claude based on context. These don't appear in the `/` menu.

| Skill | Invocation | Arguments | Description |
| --- | --- | --- | --- |
| `kramme:docs:update-agents-md` | Background | — | This skill should be used when the user asks to "update AGENTS.md", "add to AGENTS.md", "maintain agent docs", or needs to add guidelines to agent instructions. Guides discovery of local skills and enforces structured, keyword-based documentation style. |
| `kramme:git:commit-message` | Background | — | Create commit messages for branch commits. Use when committing code changes or writing commit messages. Covers plain-English commit format, a pre-commit checklist, and AI-attribution rules. Not for PR titles or merge commits, which use Conventional Commits. |
| `kramme:verify:before-completion` | Background | — | Use when about to claim work is complete, fixed, or passing, before committing or creating PRs - requires running verification commands and confirming output before making any success claims; evidence before assertions always |

<!-- END SOURCE-SYNCED SKILL ROWS -->

## Agents

Specialized subagents for PR review and UX audit tasks. Invoked by `/kramme:pr:code-review`, `/kramme:pr:ux-review`, or directly via the Task tool.

| Agent | Description |
| --- | --- |
| `kramme:code-reviewer` | Reviews code for bugs, style violations, and CLAUDE.md compliance. Uses confidence scoring (0-100) to filter issues. |
| `kramme:code-simplifier` | Simplifies code for clarity and maintainability while preserving functionality. |
| `kramme:lean-reviewer` | Reviews PR changes for code that can be deleted, avoided, or replaced by existing code, standard library, native platform features, or installed dependencies. |
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

Event handlers that run automatically at specific points in the Claude Code lifecycle. For detailed configuration, pattern lists, and formatter tables, see [docs/hooks.md](kramme-cc-workflow/docs/hooks.md).

| Hook | Event | Description |
| --- | --- | --- |
| `block-rm-rf` | PreToolUse (Bash) | Blocks destructive file deletion commands and recommends `trash` instead. |
| `confirm-review-responses` | PreToolUse (Bash) | Confirms before committing review artifact files. |
| `noninteractive-git` | PreToolUse (Bash) | Blocks git commands that open an interactive editor. |
| `skill-usage-stats` | UserPromptSubmit, PreToolUse (Skill) | Records local skill usage statistics. |
| `context-links` | Stop | Displays PR and Linear issue links at end of messages. |
| `auto-format` | PostToolUse (Write\|Edit) | Auto-formats code after file modifications using detected project formatter. |

Use `/kramme:hooks:toggle` to enable/disable hooks. State persists in `${XDG_STATE_HOME:-$HOME/.local/state}/kramme-cc-workflow/hook-state.json` by default, with `KRAMME_HOOK_STATE_FILE` override support and legacy fallback to `kramme-cc-workflow/hooks/hook-state.json`.

## Suggested Permissions

Add these to your Claude Code `settings.json` to reduce approval prompts. Two tiers are available:

- **Core** — read-only git, GitHub, and Linear operations
- **Extended** — adds git write operations, PR creation, and build/test commands

> **Warning:** Extended permissions include destructive git operations (`git push`, `git reset`, `git rebase`). Only use on projects where you have full control.

See [docs/permissions.md](kramme-cc-workflow/docs/permissions.md) for the full JSON configuration.

## Recommended MCP Servers

These MCP servers enhance the plugin's capabilities. See [docs/mcp-servers.md](kramme-cc-workflow/docs/mcp-servers.md) for installation instructions.

| Server | Purpose |
| --- | --- |
| **Linear** | Issue tracking for `/kramme:linear:issue-implement`, `/kramme:linear:issue-define`, and `/kramme:linear:select-next` |
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

| CLI   | Purpose                        | Install                       |
| ----- | ------------------------------ | ----------------------------- |
| `git` | Version control (all commands) | Pre-installed on most systems |
| `gh`  | GitHub PR workflows            | `brew install gh`             |

### Verification & Build

| CLI | Purpose | Install |
| --- | --- | --- |
| `nx` | Nx monorepo commands | `npm install -g nx` |
| `dotnet` | .NET project verification | [dotnet.microsoft.com](https://dotnet.microsoft.com/download) |
| `prettier` | JS/TS formatting | `npm install -g prettier` |
| `eslint` | JS/TS linting | `npm install -g eslint` |
| `tsc` | TypeScript type-checking | `npm install -g typescript` |

### Utilities

| CLI | Purpose | Install |
| --- | --- | --- |
| `trash` | Safe file deletion (used by block-rm-rf hook) | `brew install trash` (macOS) / `apt install trash-cli` (Linux) |
| `jq` | JSON parsing (internal use) | `brew install jq` |
| `markitdown` | Document conversion skill | `uvx markitdown` or `pip install markitdown` |
| `skillspector` | Optional security scanning for local skill directories | [NVIDIA/SkillSpector](https://github.com/NVIDIA/SkillSpector) |
| `surf` | AI-generated illustrations in visual diagrams (optional) | [surf-cli](https://github.com/nicobailon/surf-cli) |

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for the contributor and agent workflow,
including source maps, verification commands, and documentation expectations.

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

The hooks are tested using [BATS](https://github.com/bats-core/bats-core) (Bash Automated Testing System). Pure JavaScript and Python helper modules also have focused unit test runners. The Bats suite requires `jq` for JSON parsing in hooks.

### Setup

```bash
npm ci --no-audit --no-fund
make -C kramme-cc-workflow install-test-deps
```

### Running Tests

```bash
# Run all tests
make -C kramme-cc-workflow test

# Run only Bats integration tests
make -C kramme-cc-workflow test-bats

# Run only Node unit tests
make -C kramme-cc-workflow test-node

# Run only Python unit tests
make -C kramme-cc-workflow test-python

# Run Node/Python unit coverage reports without enforcing thresholds
make -C kramme-cc-workflow unit-coverage

# Backward-compatible alias for the same unit coverage gate
make -C kramme-cc-workflow coverage

# Run with verbose output (show test names)
make -C kramme-cc-workflow test-verbose

# Run only plugin conversion tests
make -C kramme-cc-workflow test-convert

# Run only non-interactive git tests
make -C kramme-cc-workflow test-noninteractive

# Run only block-rm-rf tests
make -C kramme-cc-workflow test-block

# Run only context-links tests
make -C kramme-cc-workflow test-context

# Run only auto-format tests
make -C kramme-cc-workflow test-format

# Run only skill usage stats tests
make -C kramme-cc-workflow test-skill-usage
```

### Pre-PR Verification

`make -C kramme-cc-workflow test` is the fast default suite. It runs the Node
unit tests, Python unit tests, and Bats integration tests. For ordinary Pull
Request verification, run:

```bash
make -C kramme-cc-workflow pr-verify
```

The `pr-verify` target runs dependency preflight checks, shell/Python/JS linting,
format checks, skill-contract linting, changed-skill SkillSpector scanning with
`--fail-on high`, and the fast test suite. It does not add a separate
`skill-eval-skill-review` pass beyond the skill-review eval coverage already
exercised by the Bats suite.

Before a release candidate or before marking a larger Pull Request ready, run the
stronger local gate:

```bash
make -C kramme-cc-workflow verify
```

The `verify` target runs `pr-verify` plus the standalone full skill-review eval
split. These verification targets expect the existing local tools used by those
checks to be installed: `shellcheck`, `ruff`, `skillspector`, `bats`, `jq`,
Python 3, and Node.js.

### Skill Security Scans

SkillSpector scans complement tests, linting, and human review. Run them for new or materially changed skills, before installing third-party skills, and as a full-tree check for release candidates. Static-only scanning is the default; semantic analysis is opt-in.

The GitHub Actions release workflow runs the full-tree static scan before creating a release branch or Pull Request. Release scan findings are advisory for now, but SkillSpector installation or execution errors fail the release workflow. The workflow uploads the full report as the `skillspector-release-report` artifact and includes a concise scan summary in the generated release Pull Request body.

The Pull Request workflow runs a static SkillSpector scan for changed skill directories. Pull Requests with no changed skills exit successfully without running the scanner. Changed-skill scans are blocking: enforceable high and critical findings fail `Skill Lint / SkillSpector static skill scan` and should block merge. Repository branch protection should require that check on `main`; if GitHub lists only the job name, require `SkillSpector static skill scan`.

```bash
# Scan every plugin skill
make -C kramme-cc-workflow skill-security

# Scan only skill directories changed against BASE_REF, defaulting to origin/main
make -C kramme-cc-workflow skill-security-changed

# Scan every plugin skill with SkillSpector semantic analysis enabled.
# Defaults to JSON to avoid running a second LLM-backed companion report.
make -C kramme-cc-workflow skill-security-semantic
```

For third-party skill intake, scan the source before installing it:

```bash
# Scan an external Git URL, zip, directory, or SKILL.md without LLM analysis
skillspector scan <url-or-path> --no-llm
```

Reports are written to `.context/skillspector/` by default, or `$RUNNER_TEMP/skillspector` in CI. Override behavior with `SKILLSPECTOR_FORMAT`, `SKILLSPECTOR_SEMANTIC_FORMAT`, `SKILLSPECTOR_FAIL_ON`, and `SKILLSPECTOR_BASE`.

Triage high and critical findings before installation, release, or merge. In ordinary Pull Requests, fix enforceable high and critical findings or record a specific accepted finding before merging. Enable semantic scanning only when provider credentials are intentionally configured and the skill contents are acceptable to send to that provider; semantic scans remain manual and are not required for ordinary Pull Requests.

Accepted findings live in `kramme-cc-workflow/config/skillspector-accepted-findings.json`. Keep this registry small: add an entry only when a finding has been reviewed and the risk is intentionally accepted or proven to be scanner noise. Each entry must name the exact repo-relative `path`, `rule_id`, `reason`, `owner`, `accepted_at`, and either `expires_at` or `review_after`.

```json
{
  "accepted_findings": [
    {
      "path": "kramme-cc-workflow/skills/kramme:example/SKILL.md",
      "rule_id": "E4",
      "reason": "Reviewed scanner false positive; command is documented-only.",
      "owner": "Security",
      "accepted_at": "2026-06-13",
      "expires_at": "2026-09-13"
    }
  ]
}
```

Accepted findings are excluded from `--fail-on` threshold calculations only when both path and rule match and the entry is still active. They are still counted in runner output as accepted findings, and the JSON reports remain unchanged. Entries past `expires_at` or `review_after` fail blocking scans (`SKILLSPECTOR_FAIL_ON=high` or `critical`) and warn in advisory scans. Use `--accepted-findings <path>` to test a policy file other than the default registry.

### Test Structure

```
kramme-cc-workflow/tests/
├── run-tests.sh              # Main test runner
├── test_helper/
│   ├── common.bash           # Shared utilities
│   └── mocks/                # Mock git, gh commands
├── auto-format.bats          # Tests for auto-format hook
├── block-rm-rf.bats          # Tests for block-rm-rf hook
├── confirm-review-responses.bats # Tests for confirm-review-responses hook
├── convert-plugin.bats       # Tests for plugin conversion script
├── context-links.bats        # Tests for context-links hook
├── agent-description-length.bats # Tests Codex-compatible agent descriptions
├── pr-generate-description-guidance.bats # Tests PR description skill guidance
├── skill-resource-references.bats # Tests skill-local resource references
├── skillspector-runner.bats # Tests SkillSpector scan wrapper
├── skill-usage-stats.bats    # Tests for skill usage stats hook
└── noninteractive-git.bats   # Tests for noninteractive-git hook
```

## SkillOpt Adoption

SkillOpt is currently a conservative pilot for `kramme:skill:review` only. The
deterministic eval split lives in
`kramme-cc-workflow/evals/skill-review/`, and the repo-local SkillOpt bridge
lives in `kramme-cc-workflow/evals/skillopt/`. Keep the external SkillOpt
checkout, model credentials, run output, and candidate review artifacts outside
tracked source under `.context/`.

The entry points are the split check, dry-run or real SkillOpt runner, candidate
export, and candidate review packet documented in
[`evals/skillopt/README.md`](kramme-cc-workflow/evals/skillopt/README.md).
Generated `best_skill.md` output is never auto-applied. A candidate is eligible
for a normal source edit only after the manual review packet under
`.context/skillopt-runs/skill-review/<run-id>/candidate-review/` has been
inspected, the patch applies cleanly, the eval scores do not regress, and the
candidate gate passes:

```bash
make -C kramme-cc-workflow skillopt-candidate-check
```

The candidate gate runs skill contract linting, changed-skill SkillSpector
scanning with JSON output and `--fail-on high`, Node unit tests, Python unit
tests, Bats integration tests, and the full skill-review eval split.

Do not add another skill to the optimization loop until it has a deterministic
train/val/test split, false-positive coverage, a candidate gate, and the same
manual acceptance model. SkillOpt-Sleep is proposal-only: it may suggest
candidate edits from prior sessions, but deterministic held-out evals and the
manual review packet remain the acceptance gate.

## Local Repository Maintenance

This workspace also includes local maintenance skills under `.agents/skills/`, exposed to Claude Code through the `.claude/skills` symlink. These are for maintaining this repository and are not shipped as part of the public plugin.

| Skill | Description |
| --- | --- |
| `/kramme:skill:audit-sources` | Audits one or more skills against declared inspiration sources, bootstraps missing `references/sources.yaml` manifests, compares fetched source snapshots, and writes `.context/skill-source-audit-<timestamp>.md` reports. |

## Plugin Structure

```
.
├── .claude-plugin/
│   └── marketplace.json     # Root marketplace definition
├── kramme-cc-workflow/
│   ├── .claude-plugin/
│   │   └── plugin.json      # Plugin metadata
│   ├── agents/              # Specialized subagents
│   ├── skills/              # Skills (subdirectories with SKILL.md)
│   ├── hooks/               # Event handlers
│   │   └── hooks.json
│   ├── docs/                # Detailed reference docs
│   └── README.md            # Pointer to this root README
├── .agents/skills/          # Local repository-maintenance skills
└── README.md                # Canonical documentation
```

## Adding Components

See [CLAUDE.md](CLAUDE.md) for detailed conventions. Quick reference:

- **Agents**: Create markdown files in `kramme-cc-workflow/agents/` with `name`, `description`, `model`, and `color` frontmatter.
- **Skills**: Create a subdirectory in `kramme-cc-workflow/skills/` with a `SKILL.md` file. Key frontmatter: `name`, `description`, `disable-model-invocation`, `user-invocable`, `kramme-platforms`.
- **Hooks**: Edit `kramme-cc-workflow/hooks/hooks.json` to add event handlers. Available events: `PreToolUse`, `PostToolUse`, `UserPromptSubmit`, `SessionStart`, `Stop`.
- **External sources**: When adapting skills, scripts, docs, or workflows from another project, update the skill's `references/sources.yaml`. Copied scripts or assets must keep upstream source, exact commit or release when known, and license notes in the copied file. Prefer rewriting workflows in local vocabulary and splitting long upstream skills into smaller local skills or references; use `/kramme:skill:create` and `/kramme:skill:review` for the detailed checks.

## Related Plugins

| Plugin | Description |
| --- | --- |
| [Agent Skills for Context Engineering](https://github.com/muratcankoylan/Agent-Skills-for-Context-Engineering) | Agent Skills focused on context engineering principles for building production-grade AI agent systems. |
| [adversarial-spec](https://github.com/zscole/adversarial-spec) | Specification refinement through multi-model debate until consensus is reached. |

## Documentation

- [Plugin Documentation](https://code.claude.com/docs/en/plugins)
- [Plugins Reference](https://code.claude.com/docs/en/plugins-reference)
- [Hooks Reference](https://code.claude.com/docs/en/hooks)
- [Skills Documentation](https://code.claude.com/docs/en/skills)
- [Repository Architecture](kramme-cc-workflow/docs/architecture.md)
- [Repository Code Map](kramme-cc-workflow/docs/code-map.md)
- [Agent Portability Matrix](kramme-cc-workflow/docs/agent-portability.md)
- [Decision Index](kramme-cc-workflow/docs/decisions/README.md)
- [SIW Workflow Reference](kramme-cc-workflow/docs/siw.md)

## Releases

See [CHANGELOG.md](kramme-cc-workflow/CHANGELOG.md) for version history and [GitHub Releases](https://github.com/Abildtoft/kramme-cc-workflow/releases) for release notes.

For maintainers: see [RELEASE.md](kramme-cc-workflow/RELEASE.md) for the release process.

## Attribution

Addy Osmani's [`agent-skills`](https://github.com/addyosmani/agent-skills) is a major upstream influence on this plugin. Several skills below are direct adaptations, and several others reuse core conventions from Addy's prompts and workflows.

Copied scripts and substantial copied assets must preserve upstream source and license notes in the copied file, not only in this README. Adapted workflows should record their source in the skill's `references/sources.yaml`, rewrite the workflow in this plugin's style, and avoid direct ports of long monolithic skill bodies.

- `kramme:docs:update-agents-md`: Inspired by [getsentry/skills](https://github.com/getsentry/skills/blob/main/plugins/sentry-skills/skills/agents-md/SKILL.md).
- `kramme:architecture-strategist`: Adapted from [EveryInc/compound-engineering-plugin](https://github.com/EveryInc/compound-engineering-plugin).
- `kramme:git:commit-message`: From [getsentry/skills](https://github.com/getsentry/skills/blob/main/plugins/sentry-skills/skills/commit/SKILL.md).
- `kramme:design-iterator`: Adapted from [EveryInc/compound-engineering-plugin](https://github.com/EveryInc/compound-engineering-plugin).
- `kramme:text:humanize`: Based on Wikipedia: Signs of AI writing (maintained by WikiProject AI Cleanup) and heavily inspired by [blader/humanizer](https://github.com/blader/humanizer).
- `kramme:performance-oracle`: From [EveryInc/compound-engineering-plugin](https://github.com/EveryInc/compound-engineering-plugin).
- `kramme:product:strategy` and `kramme:product:pulse`: Adapted from [EveryInc/compound-engineering-plugin](https://github.com/EveryInc/compound-engineering-plugin) skills `ce-strategy` and `ce-product-pulse`.
- `kramme:code:optimize`: Adapted from [EveryInc/compound-engineering-plugin — ce-optimize](https://github.com/EveryInc/compound-engineering-plugin/tree/6f9ab03a031c054a8046659926251fb6c149269f/plugins/compound-engineering/skills/ce-optimize), reviewed at commit `6f9ab03a031c054a8046659926251fb6c149269f`.
- `kramme:session:search` and `kramme:session:automate-repeats`: Adapted from [EveryInc/compound-engineering-plugin](https://github.com/EveryInc/compound-engineering-plugin) skill `ce-sessions`, including its safe session discovery and extraction substrate reviewed at commit `6f9ab03a031c054a8046659926251fb6c149269f`.
- `kramme:setup`, `kramme:git:clean-gone-branches`, and `kramme:git:worktree`: Adapted from [EveryInc/compound-engineering-plugin](https://github.com/EveryInc/compound-engineering-plugin) skills `ce-setup`, `ce-clean-gone-branches`, and `ce-worktree`, reviewed at commit `6f9ab03a031c054a8046659926251fb6c149269f`.
- `kramme:docs:solution-note` and `kramme:docs:solution-refresh`: Adapted from [EveryInc/compound-engineering-plugin](https://github.com/EveryInc/compound-engineering-plugin) skills `ce-compound` and `ce-compound-refresh`, reviewed at commit `6f9ab03a031c054a8046659926251fb6c149269f`.
- `kramme:docs:review`: Adapted from [EveryInc/compound-engineering-plugin - ce-doc-review](https://github.com/EveryInc/compound-engineering-plugin/tree/main/plugins/compound-engineering/skills/ce-doc-review).
- `kramme:code:work-from-plan`: Adapted from [EveryInc/compound-engineering-plugin - ce-work](https://github.com/EveryInc/compound-engineering-plugin/tree/main/plugins/compound-engineering/skills/ce-work) and [ce-plan](https://github.com/EveryInc/compound-engineering-plugin/tree/main/plugins/compound-engineering/skills/ce-plan) as a thin routing adapter, not a full autonomous execution pipeline.
- `kramme:launch:announce` and `kramme:changelog:generate` release communication modes: Adapted from [EveryInc/compound-engineering-plugin — ce-promote](https://github.com/EveryInc/compound-engineering-plugin/tree/main/plugins/compound-engineering/skills/ce-promote) and [ce-release-notes](https://github.com/EveryInc/compound-engineering-plugin/tree/main/plugins/compound-engineering/skills/ce-release-notes).
- `kramme:visual:demo-reel` and PR visual evidence delegation: Adapted from [EveryInc/compound-engineering-plugin — ce-demo-reel](https://github.com/EveryInc/compound-engineering-plugin/tree/b6250490bec4c0488d68ad66d72bd99f6edb95fd/plugins/compound-engineering/skills/ce-demo-reel), reviewed at commit `b6250490bec4c0488d68ad66d72bd99f6edb95fd`.
- `kramme:docs:feature-spec`: Adapted from [addyosmani/agent-skills — spec-driven-development](https://github.com/addyosmani/agent-skills/tree/main/skills/spec-driven-development).
- `kramme:docs:adr`: Adapted from [addyosmani/agent-skills — documentation-and-adrs](https://github.com/addyosmani/agent-skills/tree/main/skills/documentation-and-adrs).
- `kramme:code:source-driven`: Adapted from [addyosmani/agent-skills — source-driven-development](https://github.com/addyosmani/agent-skills/tree/main/skills/source-driven-development).
- `kramme:code:deprecate`: Adapted from [addyosmani/agent-skills — deprecation-and-migration](https://github.com/addyosmani/agent-skills/tree/main/skills/deprecation-and-migration).
- Codex converter: Inspired by [EveryInc/compound-engineering-plugin](https://github.com/EveryInc/compound-engineering-plugin).
- Skills authoring patterns: Inspired by [mgechev/skills-best-practices](https://github.com/mgechev/skills-best-practices).
- External-source adaptation policy, copied-script attribution guardrails, and artifact-lifecycle prompts: Informed by [EveryInc/compound-engineering-plugin](https://github.com/EveryInc/compound-engineering-plugin/tree/6f9ab03a031c054a8046659926251fb6c149269f), reviewed at commit `6f9ab03a031c054a8046659926251fb6c149269f`, including representative skills `ce-compound`, `ce-compound-refresh`, `ce-plan`, `ce-code-review`, and `ce-optimize`.
- Shared dev-server detection scripts and browser-facing auto URL detection contract: Adapted from [EveryInc/compound-engineering-plugin — ce-polish](https://github.com/EveryInc/compound-engineering-plugin/tree/6f9ab03a031c054a8046659926251fb6c149269f/plugins/compound-engineering/skills/ce-polish), reviewed at commit `6f9ab03a031c054a8046659926251fb6c149269f`.
- `kramme:visual:*` skills: Adapted from [nicobailon/visual-explainer](https://github.com/nicobailon/visual-explainer).
- `kramme:test:tdd`: Adapted from [addyosmani/agent-skills](https://github.com/addyosmani/agent-skills/tree/main/skills/test-driven-development).
- `kramme:browse` security boundaries, JavaScript constraints, content boundary markers, and Addy marker/epilogue conventions: adapted from [addyosmani/agent-skills — browser-testing-with-devtools](https://github.com/addyosmani/agent-skills/tree/main/skills/browser-testing-with-devtools).
- `kramme:qa` network triage ladder, clean-console standard, accessibility ladder, and Addy marker/epilogue conventions: adapted from [addyosmani/agent-skills — browser-testing-with-devtools](https://github.com/addyosmani/agent-skills/tree/main/skills/browser-testing-with-devtools).
- `kramme:git:commit-message`, `kramme:pr:generate-description`, `kramme:git:recreate-commits`, `kramme:pr:rebase`: Addy output markers, Change Summary triplet (`CHANGES MADE / THINGS I DIDN'T TOUCH / POTENTIAL CONCERNS`), 3-section epilogue, 6-item pre-commit checklist, and "dev branches are costs" framing adapted from [addyosmani/agent-skills — git-workflow-and-versioning](https://github.com/addyosmani/agent-skills/tree/main/skills/git-workflow-and-versioning). Addy's per-commit Conventional Commits rule is explicitly rejected.
- `kramme:pr:github-review-reply`: GitHub review comment listing, review-summary reads, top-level PR comment reads/posts, reply posting, review thread mapping, and thread resolution operations are grounded in official GitHub REST and GraphQL API documentation.
- `kramme:pr:github-review`: review-requested PR discovery, PR-context reads, `pull/<N>/head` fetch, existing-conversation mapping (REST review comments, GraphQL review threads, issue comments, prior reviews), and the optional review-submission/reply appendix are grounded in the GitHub CLI manual and official GitHub REST/GraphQL/search documentation.

## License

MIT
