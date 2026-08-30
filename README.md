# kramme-cc-workflow

A Claude Code plugin that automates the daily development lifecycle:

- **Plan** — requirements discovery, feature specs, and initial issue definition with SIW (Structured Implementation Workflow)
- **Build** — guided implementation of Linear issues, up to a full issue-to-PR pipeline
- **Review** — specialized review agents for code quality, conventions, product, UX, and accessibility
- **Test & verify** — browser-driven QA with evidence capture and project-aware verification runs
- **Explain** — self-contained HTML diagrams, PR walkthroughs, and codebase onboarding guides

The plugin also runs on Codex: a converter CLI installs the same skills, hooks, and agents there (see [Codex](#codex)).

<!-- prettier-ignore-start -->
> [!IMPORTANT]
> Thanks for checking this out. It is my personal workflow, built primarily for myself. It is also a practice arena and showcase: the release, security, CI, portability, and documentation machinery are intentionally maintained as part of the work. I experiment in the open and ship updates quickly, so skills may change or occasionally be removed. Questions are always welcome. Feel free to fork, "steal" ideas, or jump straight to the [sources of inspiration](#attribution).

> [!NOTE]
> Meaningful parts of this plugin are adapted from projects and practitioners across the agent-tooling community. The [Attribution](#attribution) section credits the specific sources behind individual skills, workflows, and conventions.
<!-- prettier-ignore-end -->

## Table of Contents

Using the plugin:

- [System Requirements & Dependencies](#system-requirements--dependencies)
- [Installation & Updating](#installation--updating)
- [Getting Started](#getting-started)
- [Skills](#skills)
- [Agents](#agents)
- [Hooks](#hooks)
- [Recommended Auto Modes](#recommended-auto-modes)
- [Recommended MCP Servers](#recommended-mcp-servers)
- [Recommended CLIs](#recommended-clis)

Reference:

- [Plugin Structure](#plugin-structure)
- [Documentation](#documentation)
- [Related Plugins](#related-plugins)
- [Releases](#releases)

Contributing & maintenance:

- [Contributing](#contributing)
- [Development](#development)
- [Adding Components](#adding-components)
- [Local Repository Maintenance](#local-repository-maintenance)
- [Attribution](#attribution)
- [License](#license)

## System Requirements & Dependencies

The plugin does not declare dependencies on other Claude Code plugins, and no MCP server is required for basic use. For the full default experience:

- Use a current Claude Code release on a [supported platform](https://code.claude.com/docs/en/installation#system-requirements). The plugin does not pin a minimum Claude Code version.
- Install Bash, Git, `jq`, Python 3.10+, and Node.js 18+. The bundled hooks invoke Bash directly, and the enabled safety hooks fail closed when `jq` or Python is unavailable. Node powers the enabled local skill-usage recording hook; without it, that hook records a diagnostic and otherwise remains silent. Disable hooks explicitly with `/kramme:hooks:toggle` if they cannot run in your environment.
- Prefer macOS, Linux, or WSL. On native Windows, install Git Bash and make the required tools available in that shell; PowerShell-only use does not support the plugin's Bash hooks.

Additional dependencies are capability-specific:

| Capability | Dependency |
| --- | --- |
| GitHub Pull Request, review, CI, and changelog workflows | Authenticated GitHub CLI (`gh auth login`) |
| Linear workflows | Authenticated Linear MCP server |
| Browser QA and live product review | Claude in Chrome, Chrome DevTools, or Playwright MCP |
| Document conversion | `uv`/`uvx`; MarkItDown dependencies are downloaded on demand |
| Image generation | `uv`, network access, and `GEMINI_API_KEY` |
| Recoverable cleanup in autonomous workflows | `trash` on macOS or `trash-cli` on Linux |
| Codex conversion | Node.js 18+ and npm |
| Project verification and formatting | The target project's own build, test, type-check, and formatter tools |

Node.js is not required to install the Claude Code plugin from its marketplace. Context7, Nx, Magic Patterns, Granola, and other MCP integrations are optional enhancements unless a selected skill says otherwise. After installation, run `/kramme:setup` for a read-only environment check. Contributors need the broader toolchain described in [Development](#development).

## Installation & Updating

### Installation

Marketplace install (recommended) — run inside a Claude Code session:

```bash
/plugin marketplace add Abildtoft/kramme-cc-workflow
/plugin install kramme-cc-workflow@kramme-cc-workflow
```

Direct Git install — run from your terminal:

```bash
claude /plugin install git+https://github.com/Abildtoft/kramme-cc-workflow
```

For local development — run from your terminal:

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

Codex output defaults to `~/.codex`. Beyond `prompts/` and `skills/`, the converter also generates agent skills (under the agents home, set with `--agents-home`), a converted hook plugin, and a managed tool-map block in the Codex `AGENTS.md`. For plugins that declare MCP servers, it also writes managed MCP config tables. See the [Agent Portability Matrix](kramme-cc-workflow/docs/agent-portability.md) for the exact source-to-output mapping.

When `.kramme-install-state.json` is unavailable or invalid, installation continues by rebuilding it from managed manifests and prints one stderr warning with the reason: `missing`, `malformed-json`, or `invalid-shape`. The `missing` reason is expected on a first install, and the warning never includes state-file contents.

Inspect the generated skill counts without installing:

```bash
node kramme-cc-workflow/scripts/convert-plugin.js stats kramme-cc-workflow
node kramme-cc-workflow/scripts/convert-plugin.js stats kramme-cc-workflow --json
```

The default output contains `codex_skills=<integer>` followed by `agent_skills=<integer>`. JSON output contains the same two integer fields in an object. `codex_skills` counts converted skill directories plus generated command skills; `agent_skills` counts generated Codex agent skills.

Inspect the resolved plugin and managed install state without changing either output root:

```bash
node kramme-cc-workflow/scripts/convert-plugin.js doctor kramme-cc-workflow
node kramme-cc-workflow/scripts/convert-plugin.js doctor kramme-cc-workflow --json
```

Doctor output is a stable schema-versioned record with `plugin_name`, `plugin_version`, and `plugin_source`; `codex_root` and `agents_root`; `install_state_path`, `install_state_status`, `install_state_from_disk`, and `install_state_recovery_reason`. The status is `loaded` when valid state came from disk and `reconstructed` when manifests were inspected after a `missing`, `malformed-json`, or `invalid-shape` state file. Human output uses one `key=value` field per line and escapes control characters as `\uNNNN`; `--json` returns the same fields with a JSON `null` recovery reason for healthy state.

The command is read-only: it does not install, repair, lock, or create output directories, and it never prints environment values or state-file contents. Paths below the current home directory use `~` to avoid exposing the local username. Other resolved paths remain absolute, so review them before pasting diagnostics into a public issue.

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

**Auto-update:** Since Claude Code v2.0.70, auto-update can be enabled per-marketplace from the `/plugin` marketplace settings.

## Getting Started

These skills cover the full lifecycle of a change. Most work runs through the middle phases; only the situational **Chart** phase up front is reached for when a task is too big or foggy to plan in one pass.

| Phase | When to use it | Skills |
| --- | --- | --- |
| **Chart** (situational) | Huge or foggy initiatives whose route can't fit in one session | `/kramme:discovery:wayfinder` |
| **Clarify** | Requirements are vague, contested, or half-formed | `/kramme:siw:discovery`, `/kramme:discovery:interview` |
| **Spec** | Turn intent into a written source of truth | `/kramme:docs:feature-spec`, `/kramme:siw:init` |
| **Break down** | Split the spec into tracked issues | `/kramme:siw:generate-phases` |
| **Transfer** | Make Linear the implementation source of truth | `/kramme:siw:transfer-to-linear` |
| **Implement** | Build one issue at a time | `/kramme:linear:issue-implement`, `/kramme:linear:issue-to-pr` |
| **Review & verify** | Check quality before shipping | `/kramme:pr:code-review`, `/kramme:verify:run` |

Most tasks begin at Clarify or Spec and flow into SIW — the local markdown-based preparation workflow for refining specifications and the first issue set. Approved work then transfers one way to Linear for implementation and Pull Requests. Two supporting primitives slot in wherever a phase needs them, not as required gates: `/kramme:research` produces a cited answer from primary sources before you commit to an approach, and `/kramme:prototype` builds throwaway code to settle one design question.

For repository work, start with [CONTRIBUTING.md](CONTRIBUTING.md), then use [docs/architecture.md](kramme-cc-workflow/docs/architecture.md) and [docs/code-map.md](kramme-cc-workflow/docs/code-map.md) to find the relevant subsystem and tests.

The workflows below walk through the hands-on parts:

### Prepare with SIW, implement with Linear

SIW refines non-trivial work into a spec-driven initial issue set, then migrates the durable planning context into Linear.

```bash
/kramme:siw:init               # link or create a spec, set up siw/ directory
/kramme:siw:spec-audit         # validate and refine the specification
/kramme:siw:generate-phases    # break the spec into phased issues
/kramme:siw:transfer-to-linear # migrate specs, decisions, milestones, and issues
/kramme:siw:remove             # retire local SIW files after verified transfer
```

See [docs/siw.md](kramme-cc-workflow/docs/siw.md) for the full workflow reference.

### Implement and ship a Linear issue

```bash
/kramme:linear:issue-to-pr DISC-202 --strict --ship # implement, review code/conventions/necessity, refactor where useful, verify, and open the PR
```

Before implementation, `issue-to-pr` validates Linear's target branch and verifies that it has no existing Pull Request or remote branch on `origin`. A Backlog issue is then moved automatically to the team's resolved started status, preferring a status named In Progress; any other current state requires explicit confirmation before the status changes or implementation starts. Once that transition is verified, a detected Conductor workspace is renamed best-effort to `ISSUE-ID: normalized issue title`; missing CLI access, authentication, or rename support is reported without blocking canonical work. After implementation it freezes the Linear issue's bounded requirements and delegates the prepared branch to `kramme:pr:review-convergence`. The shared convergence phase opens with one `/kramme:pr:gut-check` pass, then runs applicable gates in this order: `/kramme:pr:code-review`, `/kramme:pr:convention-review`, `/kramme:pr:overengineering-review`, and `/kramme:code:refactor-opportunities pr`. One bounded remediation budget prevents churn; direct and normal internal invocations can set its maximum to one through five fix-and-rerun rounds with `--rounds <1-5>`, which `issue-to-pr` forwards from its own `--rounds` flag, defaulting to five and stopping early on convergence or diminishing returns. A caller-only validation mode instead reruns the applicable gates once when authorized CI or review-feedback fixes change the tree. Users can also invoke `/kramme:pr:review-convergence` directly on a clean committed feature branch: with no requirement argument it derives the contract from the current conversation; with `--derive` it drafts a contract from conversation and committed branch evidence, asks targeted questions, and requires explicit user approval; with one Linear issue identifier or URL it performs a read-only Linear MCP lookup; and with `--requirements <authoritative requirements>` it uses the supplied block. Add `--adversarial-review` to require a final review from the opposite model provider after the ordinary gates reach a no-change candidate; optional `--adversarial-provider` and `--adversarial-model` values select that reviewer explicitly, and any unavailable provider, malformed result, degraded coverage, or tree mutation blocks convergence. The same phase is also used by `kramme:code:plan-to-pr`, which preserves its own requirements and scope contract. With `--ship`, `issue-to-pr` opens the Pull Request against the validated base branch and runs `/kramme:pr:fix-ci --no-consolidate` until CI and review feedback are clear; omit `--ship` to stop after implementation, review, and verification. With `--strict`, every review finding receives an evidence-based disposition rather than blind implementation. When the workflow finishes successfully, its report closes with a reviewer handoff summary: what was implemented, what the convergence review uncovered, and what to focus on when reviewing the result — open questions, decisions the workflow made autonomously, and deferred optional findings. Shipped summaries merge CI remediation and final-tree validation evidence when publication fixes changed the branch, then pass the complete prose through `kramme:text:clarify` for plain-language editing. The [review-convergence definition](kramme-cc-workflow/skills/kramme:pr:review-convergence/SKILL.md) owns convergence; the [issue-to-pr definition](kramme-cc-workflow/skills/kramme:linear:issue-to-pr/SKILL.md) owns Linear sequencing and shipping safeguards.

### Review and ship a PR

```bash
/kramme:pr:code-review    # run specialized review agents on your branch
/kramme:pr:resolve-review # fix the findings
/kramme:pr:create         # restructure commits and open the PR
/kramme:pr:fix-ci         # iterate until CI passes
```

More review skills cover product, convention, UX, and GitHub-reviewer flows. Which one should you use?

| Need | Use |
| --- | --- |
| Anything in the branch that looks strange, unusual, or unnecessary | `/kramme:pr:gut-check` |
| Independent review by a provider different from the active Claude Code or Codex host | `/kramme:pr:adversarial-review` |
| Code-quality findings on your local branch | `/kramme:pr:code-review` |
| Final code-review pass before commit, ship, or closeout | `/kramme:pr:code-review --loop` |
| Product-value, flow, copy, and edge-case review | `/kramme:pr:product-review` |
| Convention drift and overcaution vs. established codebase practice | `/kramme:pr:convention-review` |
| Needless complexity and unlikely-edge-case hedging vs. what the task requires | `/kramme:pr:overengineering-review` |
| UI, UX, visual, and accessibility review | `/kramme:pr:ux-review` |
| Review someone else's GitHub PR as the assigned reviewer | `/kramme:pr:github-review` |
| Triage and respond to review comments on your own PR | `/kramme:pr:github-review-reply` |
| Implement fixes from local review findings | `/kramme:pr:resolve-review` |

### Inspect and test a live app

```bash
/kramme:browse http://localhost:3000         # navigate, screenshot, inspect
/kramme:qa http://localhost:3000             # structured QA with evidence
/kramme:product:review http://localhost:3000 # whole-product experience review
```

### Quick utilities

```bash
/kramme:verify:run          # run tests, linting, and type checks for changed code
/kramme:setup               # report missing local workflow dependencies
/kramme:visual:diagram      # generate an HTML diagram from any explanation
/kramme:docs:to-markdown    # convert PDF, Word, Excel, or images to Markdown
/kramme:code:refactor-pass  # simplification + AI-slop pass on recent changes
/kramme:code:work-from-plan # route and execute a standalone implementation plan
```

All skills are listed in the reference below. Background skills (commit messages, verification guards) run automatically.

## Skills

All plugin functionality is delivered through skills. Skills can be user-invoked via the `/` menu, auto-triggered by Claude based on context, or both.

- **User-invocable**: Trigger with `/kramme:skill-name`. Skills that should never auto-run set `disable-model-invocation: true`.
- **Auto-triggered**: Claude invokes automatically when context matches the skill description.
- **Background**: Skills with `user-invocable: false` are auto-triggered only and don't appear in the `/` menu.

The tables below are the canonical component reference. For a compact lookup by name, invocation mode, and source path, see the generated [component catalog](kramme-cc-workflow/docs/component-catalog.json).

<!-- BEGIN SOURCE-SYNCED SKILL ROWS -->

### User-Invocable Skills

#### Structured Implementation Workflow (SIW)

Local specification refinement and initial issue planning before a one-way Linear transfer. See [docs/siw.md](kramme-cc-workflow/docs/siw.md) for detailed workflow documentation.

| Skill | Invocation | Arguments | Description |
| --- | --- | --- | --- |
| `/kramme:siw:init` | User | `[spec-file(s) \| folder \| discover] [--auto]` | Initialize structured implementation workflow documents in siw/ (spec, LOG.md, issues) |
| `/kramme:siw:discovery` | User | `[topic \| spec-file(s) \| 'siw'] [--apply] [--decision-tree]` | Deep discovery interview that uncovers what you actually want, not what you think you should want. Works pre-spec or on existing specs until 90% confident. Pass --decision-tree, or ask to walk depth-first, to resolve tightly coupled decisions one at a time. |
| `/kramme:siw:issue-define` | User | `[ISSUE-G-XXX or ISSUE-P1-XXX] or [description and/or file paths for context]` | Define or improve a local SIW issue file through a guided interview. For Linear or other external trackers use kramme:linear:issue-define. |
| `/kramme:siw:generate-phases` | User | `[spec-file-path] [--auto]` | Break spec into atomic, phase-based issues with tests and validation |
| `/kramme:siw:product-audit` | User | `[spec-file-path(s) \| 'siw'] [--auto] [--inline]` | (experimental) Product audit of SIW specs and plans before implementation. Evaluates target user clarity, problem/solution fit, user state modeling, critical moments coverage, scope correctness, success criteria quality, and prioritization quality. Infers likely user goals and non-goals when the spec is incomplete. Not for code review or implementation auditing. Supports inline report output with --inline. |
| `/kramme:siw:spec-audit` | User | `[spec-file-path(s) \| 'siw'] [--auto] [--apply] [--model opus\|sonnet\|haiku] [--inline] [--team]` | Audit specification documents for quality — coherence, completeness, clarity, scope, actionability, testability, value proposition, and technical design. Supports --inline and --apply. Use --team for multi-agent cross-validation and codebase pattern review. |
| `/kramme:siw:apply-spec-audit-fixes` | User | `[audit-report-path] [--auto] [--dry-run] [--threshold 60-100] [--allow-dirty]` | Canonical auto-fix procedure for mechanical spec-audit findings and kramme:siw:spec-audit --apply. Fixes only issues with a single obvious resolution — cross-reference errors, terminology inconsistencies, numbering mistakes, formatting issues, and weasel words replaceable with specifics already in the spec. Run after spec-audit. |
| `/kramme:siw:resolve-audit` | User | `[audit-report-path] [finding-id(s)] [--auto]` | Resolve audit findings one-by-one with executive summaries, alternatives, recommendation, and SIW issue creation |
| `/kramme:siw:transfer-to-linear` | User | `[siw-dir] [--project <name-or-id>] [--team <team>] [--dry-run] [--skip-done] [--skip-existing\|--retry]` | One-way migration of a local SIW project into Linear. Creates one Linear project, migrates the main spec, supporting specs, selected contract specs, and decision log as Linear Documents, rewrites SIW-local markdown references to Linear Documents where possible, creates milestones from SIW phases and issues from SIW issues (with native blocking relations when supported), writes minimal Linear transfer markers back to migrated source issues for retry safety, then prompts to retire the local siw/ files via /kramme:siw:remove. Linear becomes the source of truth; this is not a two-way sync. Use when moving a planned SIW initiative into Linear for good. Not for implementing issues, defining new SIW issues, or generating an issue breakdown. |
| `/kramme:siw:remove` | User | — | Delete SIW workflow files from the current directory. Destructive; transfer durable specifications and issues to Linear first when they must be preserved. |

#### Pull Requests

PR creation, review, iteration, and resolution.

`/kramme:pr:create --auto` is fully non-interactive, including the backup-protected local history rewrite when applicable and final publication. It chooses documented deterministic branch defaults or stops on a hard blocker without asking a question or opening a terminal credential prompt. It never publishes placeholder title/body content and preserves the invocation's entry checkout on failure. Fresh branches require remote absence and an absence-leased publication. A clean current branch that already exists remotely can preserve its local commits: an exact-tip remote skips the push, while a remote tip that is a strict ancestor of local `HEAD` receives one OID-leased fast-forward through one frozen push endpoint. Dirty or non-current branches, open Pull Requests, ambiguous push destinations, remote-only commits, genuine divergence, and any remote change after classification remain hard blockers.

| Skill | Invocation | Arguments | Description |
| --- | --- | --- | --- |
| `/kramme:pr:create` | User | `[--auto] [--draft] [--linear-issue <ISSUE-ID>] [--require-generated-description] [--authorize-history-rewrite]` | Use when creating a PR from the current branch with a generated description. Rewrites unpublished work into narrative commits, recovers an exact-tip remote, or safely fast-forwards an existing remote that is a strict ancestor of clean local HEAD without rewriting local commits. |
| `/kramme:pr:stack` | User | `[init <branches...> \| submit \| sync \| merge <pr-number> \| adopt <branches...> \| status]` | Create and manage GitHub stacked PRs with gh-stack v0.1.0 or newer. Build an ordered chain of dependent branches, submit chained draft PRs, make mid-stack edits safely, merge or sync stacks, and adopt existing branch chains. Use when a change should land as a sequence of small dependent PRs instead of one large PR. Requires a repository with stacked PRs enabled (private preview); degrades to a manual chain otherwise. |
| `/kramme:pr:product-review` | User | `[--base <branch>] [--threshold 0-100] [--inline] [--no-diff-comments]` | Deep product review of branch and local changes. Evaluates user-value alignment, flow completeness, missing states, copy/defaults, permission behavior, adjacent-flow regressions, and prioritization quality. Infers likely user goals and non-goals when rationale is missing. Not for UX heuristics, accessibility, or visual consistency -- use pr:ux-review for those. Supports inline report output with --inline. |
| `/kramme:pr:adversarial-review` | User | `[--provider claude\|codex] [--model <id>] [--base <branch>] [--requirements <authoritative requirements>]` | Runs one explicitly requested, read-only Pull Request review through a model provider different from the active Claude Code or Codex host, validates the returned findings against the prepared committed diff, and reports normalized inline results with provider and tree identity. Use for an independent cross-provider challenge before merge or as the final gate in review convergence. Not for same-provider subagent review, implementation, dirty working trees, or automatic background review. |
| `/kramme:pr:code-review` | User, Auto | `[aspects] [--emphasize <dim>...] [--base <branch>] [--previous-review <path>] [--parallel] [parallel] [--team] [--inline] [--loop] [--no-diff-comments]` | Review branch changes for tests, errors, types, security, performance, slop, lean deletion, refactor fit, and simplification. Outputs REVIEW_OVERVIEW.md with actionable findings, or replies inline with --inline. --team cross-validates; --loop applies fixes and verifies convergence. Not for UX, visual, or accessibility; use kramme:pr:ux-review. |
| `/kramme:pr:review-convergence` | User | `[--strict] [--rounds <1-5>] [--adversarial-review [--adversarial-provider claude\|codex] [--adversarial-model <id>]] [--derive \| LINEAR-ISSUE \| --requirements <authoritative requirements>]` | Converges a clean committed feature branch through gut-check, code-review, convention, overengineering, and PR-refactor gates with bounded remediation and final verification. An explicit --adversarial-review option adds a required final review from a different model provider. Invoke directly with conversation, Linear, supplied, or user-confirmed derived requirements; also used internally by issue-to-PR workflows. Not for implementation, Pull Request creation, CI repair, or read-only audits. |
| `/kramme:pr:resolve-review` | User | `[--team] [--implement-only] [--granular] [--severity ...] [--source local\|online\|conductor] [review\|url\|instructions]` | Resolve findings from code reviews or Conductor diff comments by implementing fixes and documenting changes. Implements fixes as commits on the current branch. Manual-class findings are deferred with a recommended resolution and any genuinely distinct alternatives, not a bare deferral. Use --team to resolve independent findings in parallel by file area. |
| `/kramme:pr:github-review-reply` | User | `[--auto] [--implement\|--no-implement] [--post] [--resolve] [--inline] [--human-only\|--include-bots] [--all] [--only <login>] [pr-url\|instructions]` | Maps GitHub PR review feedback from humans, bots, and apps, including inline review threads, review-summary comments, and general PR comments; facilitates needed code changes; drafts and humanizes action-based responses; and optionally posts replies or resolves addressed inline threads with gh. Use when reviewers left GitHub comments that need triage, implementation, or response. Not for fixing CI, generating internal review findings, or resolving local REVIEW_OVERVIEW.md findings. |
| `/kramme:pr:github-review` | User | `[pr-number\|pr-url] [--draft-review] [--base <ref>] [--categories a11y,ux,product,visual] [--code-only] [--fresh] [--include-bots] [--all-threads] [--inline] [--keep-worktree]` | Review a GitHub pull request where you are the assigned reviewer, not the author or assignee. Fetches the PR into an isolated worktree, runs code-quality plus UI review agents, maps existing conversations, skips duplicate findings, and drafts concise inline comments, replies, and a recommended verdict. Writes the Markdown report before offering to create one unsubmitted pending GitHub review; --draft-review skips that confirmation but still writes the report first. Not for reviewing your own branch before shipping (use kramme:pr:code-review), responding to reviewers on your own PR (use kramme:pr:github-review-reply), or resolving review findings (use kramme:pr:resolve-review). |
| `/kramme:pr:fix-ci` | User | `[--fixup] [--auto] [--no-consolidate] [--scope-plan <archived-plan>]` | Iterate on a PR until CI passes. Use when you need to fix CI failures, address review feedback, or continuously push fixes until all checks are green. Automates the feedback-fix-push-wait cycle and accepts a validated archived plan for scope-bound plan-to-PR shipping or recovery. |
| `/kramme:pr:generate-description` | User, Auto | `[--auto] [--no-update] [--visual] [--base <ref>] [--base-commit <oid>] [--linear-issue <ISSUE-ID>]` | Write a structured PR title and body from git diff, commit log, and Linear context when requested or delegated by a PR workflow. Model callers use output-only mode; a direct --auto invocation may update an existing PR. |
| `/kramme:pr:walkthrough` | User | `[--report [branch\|commit\|PR#\|range] \| --report --base <ref> \| --base <ref>] [--output <path>]` | Generate a local visual walkthrough as a self-contained HTML artifact. Use the default guided D3 style for current-branch or open-PR orientation through system, data-flow, code-dependency, and user-action views; use --report with an optional branch, commit, PR, or range for a shareable before/after architecture comparison, KPI dashboard, Mermaid graphs, explanatory review notes, and decision log. Not for actionable code review findings, PR descriptions, publishing, or live UX audits. |
| `/kramme:pr:verify-description` | User, Auto | `[--fix] [--base <ref>] [--strict]` | Compare an existing PR's title and body against the actual branch diff and report drift — false claims, missing major changes, stale scope, missing risk callouts. Use after pushing changes to a branch with an open PR, or before requesting review. Read-only by default; add --fix to delegate to kramme:pr:generate-description for an updated description. Complements kramme:pr:code-review (which checks description accuracy as one signal among many code-quality checks) by being a fast, focused, single-purpose check that runs in seconds. |
| `/kramme:pr:gut-check` | User, Auto | `[--base <branch>] [--intent <text>]` | Asks one question about the current branch and answers it plainly: does anything here jump out as strange, unusual, or unnecessary? A fast first-reader reaction with no rubric, scores, or report file. Use it before deeper review, or when a branch feels off but you cannot name why. Not for systematic code quality (use kramme:pr:code-review), complexity judged against requirements (use kramme:pr:overengineering-review), or drift from codebase practice (use kramme:pr:convention-review). |
| `/kramme:pr:convention-review` | User | `[--base <branch>] [--threshold 0-100] [--inline] [--no-diff-comments]` | Reviews PR and local changes for convention drift and overcaution against documented rules and mined peer-file practice. Use for new patterns, dependencies, abstractions, or defensive complexity that departs from established practice; every finding cites evidence. Supports --inline. Not for general code quality (use kramme:pr:code-review) or spec review (use kramme:siw:spec-audit --team). |
| `/kramme:pr:overengineering-review` | User | `[--base <branch>] [--inline] [--no-diff-comments] [--requirements <text>]` | Single-lens review that asks whether branch and local changes are overdoing things: needless complexity, speculative generality, or hedging against very unlikely edge cases. Judges necessity against the task's actual requirements, not codebase baseline practice; a loose full-recall finder is followed by an adversarial justify pass, and surviving judgment calls are reported instead of dropped. Use --requirements when PR and commit context cannot supply task intent. Supports --inline. Not for baseline-relative drift or overcaution (use kramme:pr:convention-review) or general code quality (use kramme:pr:code-review). |
| `/kramme:pr:ux-review` | User | `[app-url\|auto] [--categories a11y,ux,product,visual] [--threshold 0-100] [--base <branch>] [--parallel] [--team] [--inline] [--no-diff-comments]` | Audit UI, UX, and product experience of PR and local changes using specialized agents for usability heuristics, product thinking, visual consistency, and accessibility. Supports inline report output with --inline. Use --team for multi-agent cross-validation. |
| `/kramme:pr:rebase` | User | `[--auto] [--force-push] [--base <branch>]` | Rebase current branch onto latest main/master, auto-resolving conflicts with safe defaults unless dangerous --auto is used, then force push with --force-with-lease. Detects GitHub stacks (gh-stack) and cascade-rebases the whole stack instead of the single branch. Use when your PR is behind the base branch. |
| `/kramme:pr:plan-split` | User | `[--base <branch>] [--auto]` | Analyze the current branch diff and plan mergeable PR slices with seams, file scope, dependency order, rationale, and tests. Uses kramme:code:breakdown-findings to write PR_PLAN_*.md artifacts. Use for oversized or unrelated PRs, or when a reviewer asks for a split. Plans only; never edits source, creates branches, or rewrites history. |

Migration: `/kramme:pr:update-split-plans` has moved to `/kramme:code:breakdown-findings --reconcile`. Update saved prompts and automation to pass the same plan paths, `--all`, `--worktree`, `--source`, `--base`, and `--auto` options to the replacement command. Former no-scope calls must add `--all` to preserve the removed command's active-plan-only default; zero-scope reconcile intentionally retains `kramme:code:breakdown-findings`'s existing all-indexed behavior.

#### CI

CI/CD pipeline design and gate planning.

| Skill | Invocation | Arguments | Description |
| --- | --- | --- | --- |
| `/kramme:ci:design-pipeline` | User, Auto | — | Design a CI/CD pipeline with quality gates, a <10-minute budget, feature-flag lifecycle, and an exit checklist. Use when adding a new CI pipeline, changing gate configuration, or planning a rollout for a new service. Complementary to kramme:pr:fix-ci (which fixes failures in an existing pipeline). Covers gate ordering, secrets storage, branch protection, rollback mechanism, and staged-rollout guardrails — not a rollout-execution runbook. |

#### Launch

Post-merge rollout, release communication, canary gates, and rollback discipline.

| Skill | Invocation | Arguments | Description |
| --- | --- | --- | --- |
| `/kramme:launch:rollout` | User | — | Execute a post-merge launch with contextual staged rollout, evidence-based decision gates, and rollback triggers. Apply explicit user or organization policy first, observed system evidence second, and a confirmed fallback profile only when neither defines the rollout. Supports feature flags or equivalent reversible controls. Use after merging a user-facing change that needs safe rollout. Not for PR creation, CI debugging, or pre-merge checks. |
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

Product direction, demand validation, and product health feedback loops.

| Skill | Invocation | Arguments | Description |
| --- | --- | --- | --- |
| `/kramme:product:strategy` | User | `[optional: section or notes to revisit, e.g. 'metrics', 'active tracks']` | Create or update repo-root STRATEGY.md as a concise product anchor covering target problem, approach, users, metrics, active tracks, milestones, and non-goals. Use when starting a product, revisiting direction, grounding discovery/spec/SIW work, or resolving product-context drift. Not for one-off feature specs, roadmaps, or implementation plans. |
| `/kramme:product:validate-demand` | User, Auto | `[idea or evidence] [--output <repo-relative-path>]` | Evaluate whether one concrete product idea has enough demand evidence to justify more work. Use when testing willingness to pay, the urgent first user, the status quo to displace, or the smallest paid wedge. Produces an evidence-labeled GO, PIVOT, KILL, or INSUFFICIENT EVIDENCE verdict and one falsifiable action. Inline by default; writes a repository-scoped report only on request. Not for strategic inquiry, strategy, spec audits, design, promotion, or implementation. |
| `/kramme:product:pulse` | User | `[lookback window, e.g. 24h, 7d, 1h] [--inline]` | Generate a time-windowed product pulse report in docs/pulse-reports/ covering usage, quality, errors, performance, customer signals, and followups. Use for weekly recaps, launch checks, "how are we doing", or strategy feedback loops. Works with partial or manual sources. Not for QA test reports, PR review, or editing STRATEGY.md directly. |

#### Product Documentation

Outside-in behavioral documentation grounded in implementation evidence and runtime observation.

| Skill | Invocation | Arguments | Description |
| --- | --- | --- | --- |
| `/kramme:product:describe-behavior` | User | `[product or surface] [--source <path>] [--output <path>] [--resume]` | Creates or resumes a repository-scoped product behavior corpus that describes an existing software surface from the user's perspective, grounds claims in source code and tests, verifies observable behavior against the running product, and triages discrepancies. Use when asked to document how a product, app, CLI, or workflow behaves feature by feature or to continue an existing behavior corpus. Not for preimplementation feature specs, one-off live-product reviews, API reference docs, or implementation. |

#### Product Design

Product critique and design-direction skills.

| Skill | Invocation | Arguments | Description |
| --- | --- | --- | --- |
| `/kramme:product:design-critic` | User, Auto | `[file-path, screenshot, URL, or product question]` | (experimental) Sharpen product design judgment for software UI/UX, interaction flows, jobs-to-be-done, hierarchy, trust, governance surfacing, and competitor-informed critique. Use when critiquing or shaping a product surface, card, panel, workflow, chat experience, or design strategy instead of merely suggesting visual polish. |
| `/kramme:prototype` | User | `[design question or prototype goal]` | Builds a clearly throwaway logic/state or UI prototype to answer one design question before implementation hardens. Use when the user wants to sanity-check a state model, data shape, API surface, page layout, component direction, or interaction idea with disposable code. Not for production implementation, polished demos, visual diff reports, permanent routes, or broad design-system work. |

#### Code Quality & Review

Code cleanup, refactoring, and bug/security review.

| Skill | Invocation | Arguments | Description |
| --- | --- | --- | --- |
| `/kramme:code:migrate` | User | `<target e.g. 'Angular 19', 'React 19', 'Node 22'> [--auto]` | (experimental) Plan and execute framework or library version migrations with phased upgrades and verification gates. Use when upgrading major framework versions (Angular, React, Node) or migrating between libraries. |
| `/kramme:code:refactor-pass` | User | `[scope ... \| --rewrite]` | Perform a refactor pass focused on simplicity after recent changes, including AI-slop cleanup for unnecessary comments, defensive noise, weak typing, over-engineering, and style drift. Use for a narrow cleanup, simplification, dead-code removal, suspected AI-generated code, or an explicit request to redo mediocre recent work properly with --rewrite. Applies Chesterton's Fence, rejects changes that require modifying tests, and keeps the default mode slice-by-slice. |
| `/kramme:code:incremental` | User | `[--refactor]` | (experimental) Deliver changes in small, verified slices with scope discipline, incremental verification between slices, and feature-flag guardrails for incomplete work. Use when implementing any change that spans more than one file or commit. Enforces one-thing-at-a-time, rollback-friendly commits, and explicit separation of in-scope work from noticed-but-untouched observations. Includes a refactor mode (opt-in via --refactor or after kramme:code:refactor-opportunities) that adds an interview-driven Decision Document and a Fowler-style tiny-commits plan where every intermediate state leaves the codebase working. |
| `/kramme:code:work-from-plan` | User | `[plan path \| inline plan]` | Routes and executes a standalone markdown implementation plan. Use when the user provides a `PR_PLAN_*.md` file, pasted plan, or one-off implementation checklist that is not already a Linear issue or local SIW preparation artifact. Delegates Linear work, stops local SIW issues with a transfer recommendation, gathers codebase context, surfaces MISSING REQUIREMENT blockers, and proceeds directly only for bounded current-branch work. Not for planning from scratch, PR creation, CI watching, or large multi-phase initiatives that should become SIW. |
| `/kramme:code:plan-to-pr` | User | `<attached plan \| PR_PLAN_W##L_*.md> [--strict] [--ship]` | Implements one self-contained `PR_PLAN_*.md`, either from an indexed kramme:code:breakdown-findings set or as a `.context/attachments/` file, on a deterministic unpublished branch. Attached `W##L` plans retain dependency metadata and prove prerequisite readiness from embedded evidence without the sibling index; drifted attachments can refresh after approval through a new immutable snapshot and content-derived archive. Enforces drift and scope checks, archives disposable inputs, delegates shared review convergence and verification, and optionally opens the Pull Request and stabilizes CI/review feedback. Not for inline plans, SIW/Linear issues, split-worktree plans, stacked PRs, existing PRs, or multi-plan batches. |
| `/kramme:code:source-driven` | User, Auto | — | (experimental) Ground framework and library decisions in official documentation with explicit citation. Use when touching any external framework, library, CLI tool, or cloud service — especially recent versions where training data may be stale. Fetches via Context7 MCP or direct URLs, implements against documented patterns, and cites deep links with quoted passages when decisions are non-obvious. |
| `/kramme:code:copy-review` | User, Auto | `[--pr] [--base <branch>] [--threshold 0-100] [--inline] [--all \| <scope-path>]` | Review unnecessary, redundant, or duplicative UI text across a codebase or the current branch diff. Defaults to a full-codebase audit on the base branch and automatically uses PR/local diff review on non-base branches; use --pr to force diff review. Supports scoped audits, confidence thresholds, and inline output. |
| `/kramme:code:breakdown-findings` | User | `[--auto] [--resume\|--reconcile] [--all \| plan-file ...] [--worktree <path>] [--source <ref>] [--base <ref>] [--] [source ...]` | Cluster validated review/audit/QA findings into PR-sized implementation plans with index, rejection record, repo recon, sequencing, and reconcile/resume support. Reconcile generic or split/worktree plan sets against working-tree or named-ref evidence. Accepts structured findings, report files, current-dialogue findings, or marked/inferred pre-clustered handoffs. Not for raw bug lists, single issues, or unvalidated triage. |
| `/kramme:code:refactor-opportunities` | User, Auto | `[full \| pr \| path <file-or-folder> \| feature <name>]` | Scan the full codebase, current PR, a named file/folder, or a named feature for refactoring candidates. Use when the user asks to find refactor opportunities, audit code quality, identify tech debt, or wants a codebase health check. Flags themes whose combined blast radius exceeds 500 lines as automation candidates. |
| `/kramme:code:weakness-audit` | User | `[full \| path <file-or-folder> \| feature <name>] [--output <path>] [--max-findings N] [--solo]` | Identify the biggest codebase weaknesses across maintainability, readability, and correctness using a multi-agent audit team by default, then write a ranked CODEBASE_WEAKNESS_REPORT.md. Use when the user asks for top weaknesses, codebase health risks, maintainability/readability/correctness audit, or where to invest cleanup effort. Use --solo only for a faster single-threaded fallback. Not for PR-only review, implementation, security-specific audits, or broad refactor opportunity inventories. |
| `/kramme:code:outside-view` | User | `[--raters N] [--output <path>] [--compare <report-path>] [--cross-model]` | Rate a codebase with unprimed raters; cluster complaints, compare with CODEBASE_WEAKNESS_REPORT.md, and track gestalt in OUTSIDE_VIEW_REPORT.md. Cross-model is opt-in and isolated. Use for unknown-unknown quality issues, especially in AI-engineered code. Not for evidence-ranked findings (kramme:code:weakness-audit), PR review, or implementation. |
| `/kramme:code:agent-readiness` | User | `[--auto]` | Audit a codebase for agent-nativeness — score how well-optimized it is for AI coding agents across 5 dimensions and generate a prioritized refactoring plan. |
| `/kramme:code:audit-agent-config` | User, Auto | `[scope-path]` | Audit repository-persisted agent instructions, skills, subagents, hooks, MCP servers, permissions, and memory for redundant, outdated, conflicting, or irrelevant entries; return read-only KEEP / IMPROVE / REMOVE verdicts. Never edits files or inspects global config. Not for codebase agent-readiness (kramme:code:agent-readiness) or general code-quality audits (kramme:code:refactor-opportunities). |
| `/kramme:code:audit-security` | User | `[--output <repo-relative-path>]` | Audit a repository's security posture before remediation by inventorying attack surfaces and trust boundaries across code, identity, data, CI/CD, infrastructure, integrations, dependencies, secrets, and agent or LLM tooling. Produces a secret-safe, evidence-ranked report with coverage gaps and remediation routes. Use for whole-repository posture or threat-surface audits. Not for fixes, dependency-only audits, author-time hardening, penetration tests, compliance claims, or PR-diff review. |
| `/kramme:code:api-design` | User, Auto | `[--design-twice]` | (experimental) Design stable APIs and module boundaries. Covers contract-first approach, Hyrum's Law, validation placement (at boundaries, not between internal functions), consistent error shapes with HTTP status mapping, naming conventions, and TypeScript patterns for interface stability. Use when adding HTTP endpoints, public modules, SDK surfaces, or any interface with external or cross-team callers. Includes a Design It Twice mode (opt-in via --design-twice or the phrase 'design it twice') that drafts radically different shapes — in parallel via sub-agents on Claude Code, sequentially elsewhere — before committing to one. |
| `/kramme:code:harden-security` | User, Auto | — | Apply security-by-default to code handling user input, authentication, dependency or lockfile changes, installer/build inputs, personal-data lifecycles, external integrations, or personal-data sharing with LLM providers. Use when accepting untrusted data, managing sessions, adding, upgrading, or remediating packages, or designing sensitive-data collection, retention, deletion, or third-party sharing. Complements the review-time auth-reviewer / data-reviewer / injection-reviewer agents. |
| `/kramme:code:performance` | User, Auto | — | (experimental) Measure-first performance discipline tied to Core Web Vitals (LCP, INP, CLS). Use when users or monitoring report slowness, CWV scores miss thresholds, performance requirements exist in the spec, you suspect a recent change introduced a regression, or you're building features that handle large datasets or high traffic. Enforces baseline measurement, single-bottleneck fixes, verification, and regression guards; when explicitly authorized, can persist immutable repository-scoped baseline artifacts for later comparisons. Complements the review-time `kramme:performance-oracle` agent. |
| `/kramme:code:optimize` | User | `[spec.yaml \| optimization goal] [--auto]` | (experimental) Run metric-driven optimization experiments. Use when search relevance, clustering quality, prompt quality, build latency, ranking behavior, bundle size, or another measurable outcome needs repeatable variants instead of sequential guess-and-check. Requires a measurement command or judge rubric, persists baselines and experiment logs under `.context/code-optimize/`, and can use serial or worktree-isolated experiments. Not for ordinary one-shot performance fixes, implementation without a harness, or speculative optimization with no metric. |
| `/kramme:code:deprecate` | User | — | Plan and execute deprecation of code, features, APIs, modules, or persistent data shapes, treating code as a liability. Covers the decision to deprecate (5-question checklist), Hyrum's Law risk assessment, Advisory vs Compulsory paths, Strangler / Adapter / Feature-Flag / Database Expand-Migrate-Contract patterns, and a four-step workflow: build replacement → announce → migrate incrementally → remove old. Emits SIMPLICITY CHECK, NOTICED BUT NOT TOUCHING, UNVERIFIED, and ASK FIRST markers. Use when removing legacy systems, evolving database schemas, sunsetting features, retiring API versions, or cleaning up zombie code with unknown owners. |

#### Debug

Bug investigation and root cause analysis.

| Skill | Invocation | Arguments | Description |
| --- | --- | --- | --- |
| `/kramme:debug:find-sibling-bugs` | User, Auto | `[--base <branch>] [--intent <text>]` | Finds sibling bugs by treating the current bug-fix branch as a worked example: infers the problem, isolates the code, UX, or UI pattern that caused it, and audits the codebase for other occurrences with evidence and confidence. Use after a branch contains a fix or mitigation and recurrence analysis is needed. Not for diagnosing an unfixed bug, reviewing general branch quality, or changing code. |
| `/kramme:debug:investigate` | User | `[bug description, error message, or issue reference] [--auto]` | Structured bug investigation workflow: reproduce, isolate, trace root cause, and fix. Use when debugging a bug, investigating an error, or tracking down a regression. |
| `/kramme:debug:triage-to-issue` | User | `[bug description, error message, or Linear/SIW issue ref] [--yes \| --auto]` | (experimental) Turn a bug into an implementation-ready Linear or local SIW issue with root-cause evidence and a RED-GREEN TDD fix plan. Not for full interactive investigation with multiple confidence gates (kramme:debug:investigate), multi-bug QA intake (kramme:qa:intake), or fix implementation (use kramme:linear:issue-implement after transferring local SIW tickets). |

#### Dependencies

Dependency auditing and management.

| Skill | Invocation | Arguments | Description |
| --- | --- | --- | --- |
| `/kramme:deps:audit` | User | `[--auto]` | (experimental) Audit project dependencies for outdated packages, security vulnerabilities, and staleness. Generates a prioritized upgrade plan with risk assessment. |

#### Testing

Test generation, coverage, and test-first discipline.

| Skill | Invocation | Arguments | Description |
| --- | --- | --- | --- |
| `/kramme:test:audit` | User, Auto | `[full \| path <file-or-folder> \| changed [--base <ref>]] [--max-findings N]` | Audits an existing test suite for low-value, brittle, obsolete, duplicated, provider-shape-coupled, or weak tests. Produces a read-only, evidence-backed REMOVE / REPAIR / CONSOLIDATE / INVESTIGATE report. Use to find poor-quality tests across a repository or path. Not for generating or ordinarily running tests, PR coverage review, or editing or pruning tests. |
| `/kramme:test:tdd` | User, Auto | — | (experimental) Drive implementation with tests. Write a failing test that characterizes the requirement or reproduces the bug, implement the minimum to pass, then refactor with tests green. Use when implementing new logic, fixing a bug (Prove-It pattern), or changing behavior. Complementary to kramme:test:generate, which writes tests for existing untested code. |
| `/kramme:test:generate` | User | `[file-path or directory] [--auto]` | (experimental) Generate tests for existing code by analyzing project test patterns and conventions. Use when adding test coverage to untested files or generating test stubs. |

#### Git

Git history management and commit operations.

| Skill | Invocation | Arguments | Description |
| --- | --- | --- | --- |
| `/kramme:git:fixup` | User | `[--skip-tests\|--skip-build\|--skip-lint\|--skip-all] [--no-confirm] [--base=<branch>] [instructions]` | Intelligently fixup unstaged changes into existing commits on the current branch. Maps each changed file to its most recent commit, validates (build/test/lint), creates fixup commits, and autosquashes. |
| `/kramme:git:recreate-commits` | User, Auto | `[--auto] [--coarse\|--granular] [--base <branch>] [--base-commit <oid>] [--backup-ref <branch>] [--after <commit>] [--force-backup] [--require-unstacked] [--no-push] [--authorize-history-rewrite]` | Recreate commits with narrative-quality history when the user asks or kramme:pr:create delegates its guarded rewrite phase. Not for merged or shared branches — it rewrites history and uses --force-with-lease unless remote synchronization is disabled. |
| `/kramme:git:clean-gone-branches` | User | `[--prune] [--delete --yes <branch>...] [--force]` | Find local git branches whose upstream remote branch is gone, list associated worktrees, label Conductor workspace paths, and delete only after explicit confirmation. Use for local branch hygiene after remote branches are merged or deleted. Not for deleting the current branch, deleting active worktrees, pruning without review, or rewriting history. |
| `/kramme:git:worktree` | User | `<list\|create\|remove> [options]` | Safely list, create, and remove git worktrees with checks for existing paths, checked-out branches, and Conductor workspace directories. Use for manual worktree operations during PR splitting or local parallel development. Not for branch cleanup, deleting gone branches, renaming branches, or bypassing Conductor workspace archival. |

`/kramme:git:recreate-commits --auto` authorizes one backup-protected unstacked history rewrite and any required lease-protected force-push. It rejects visible or assume-unchanged tracked edits, ordinary untracked work, and reset-colliding ignored work; refuses mismatched or base-branch upstreams, renamed push destinations, and effective push-destination commits missing locally; honors `branch.<name>.pushRemote` and `remote.pushDefault`; freezes one push URL, branch, and lease; disables tag following; and revalidates the checkout immediately before reset. Automatic stack-wide rewriting additionally requires `--authorize-history-rewrite`. A non-auto stacked invocation may instead use separate interactive confirmations that enumerate the full stack before authorizing the local reset/restack and the atomic whole-stack force-push.

#### Linear

Linear issue tracking integration.

`/kramme:linear:issue-implement`: Fetches issue details plus referenced Linear issues/documents when accessible, reports inaccessible referenced assets, and uses that context during planning.

| Skill | Invocation | Arguments | Description |
| --- | --- | --- | --- |
| `/kramme:linear:backlog-refine` | User | `[team] [--project <name>] [--label <name>] [--stale-days <n>] [--limit <n>] [--apply]` | Requires Linear MCP. Refines a Linear team's backlog toward issues an autonomous agent can pick up and deliver well: grades open backlog issues for clarity, scope, agent-readiness, and staleness, groups duplicates and oversized items, then proposes per-issue actions such as rewrite, split, merge, archive, or keep. Read-only by default: applies approved changes to Linear only with --apply and per-batch approval. Use for backlog grooming or pre-planning cleanup. Not for picking the next issue (use kramme:linear:select-next), writing one issue from scratch (use kramme:linear:issue-define), or implementing issues. |
| `/kramme:linear:breakdown-findings` | User | `[--auto] [--ask] [--dry-run] [--resume] [--team <team>] [--project <project>] [--label <label>] [--] [source ...]` | Requires Linear MCP and kramme:linear:issue-define. Turns a reviewed audit, review, scan, or QA findings set into a coordinated batch of PR-sized Linear issues. Owns repository grounding, clustering, sequencing, exclusions, and resumable batch state, while delegating each ticket's duplicate check, refinement, metadata, approval, and creation to the issue-define flow. Use --ask to require the full relevant question set for every delegated issue. Accepts report paths, structured inline or current-dialogue input, and pre-grouped handoffs. Not for local PR_PLAN files, one rough issue, SIW migration, raw unvalidated lists, or implementation. |
| `/kramme:linear:issue-define` | User | `[--auto [--ask]] [--] [issue-id or description and/or file paths for context]` | Requires the Linear MCP server. Create or improve a well-structured Linear issue through guided refinement. Use with --auto to create one new Linear issue from rough input using light clarification, duplicate checking, metadata selection, and approval instead of the full interview; add --ask to ask every relevant interview question before drafting. Not for implementing Linear issues (use kramme:linear:issue-implement), multi-bug QA intake (use kramme:qa:intake), or root-cause bug triage (use kramme:debug:triage-to-issue). |
| `/kramme:linear:issue-implement` | User | `<ISSUE-ID> [--auto]` | Requires Linear MCP. Start implementing a Linear issue with branch setup, planning, and guided or --auto workflows. Local SIW work must be transferred to Linear before using this skill. |
| `/kramme:linear:issue-to-pr` | User | `<ISSUE-ID> [--strict] [--rounds <1-5>] [--ship]` | Requires Linear MCP and the GitHub gh CLI. Implements one Linear issue end to end, optionally renames the detected Conductor workspace for the issue, freezes its requirements, delegates pre-PR quality convergence to kramme:pr:review-convergence, then optionally opens a new Pull Request and iterates on CI and review feedback until green. Use when a single Linear issue, including one transferred from SIW, should go from implementation to a clean new Pull Request. Not for implementation-only or review-only work, untransferred local SIW issues, stacked PRs, existing PR updates, or post-merge rollout. |
| `/kramme:linear:review-pr` | User | `[PR-number\|PR-url] [ISSUE-ID]` | Requires Linear MCP and the GitHub CLI. Reviews an existing Pull Request against the Linear issue it implements, tracing requirements to diff, code, and test evidence and reporting omissions, deviations, undocumented additions, and unverifiable criteria. Use before merge to validate issue-to-implementation completeness. Not for general code quality, PR-description accuracy, or implementing the issue. |
| `/kramme:linear:select-next` | User | `[team] [--interest <work preference>] [--mine\|--unassigned\|--both] [--project <name>] [--label <name>] [--limit <n>]` | Requires Linear MCP. Selects the most valuable available issue to start from a Linear team by comparing assigned-to-me and unassigned issues, optional work-interest preferences, and parallel-ready candidates. Use when deciding what to pick up next. Not for creating, editing, implementing, or closing Linear issues. |

#### Visual

Generate, inspect, and capture visual output, including self-contained HTML pages, UI checks, diagrams, and demo evidence.

| Skill | Invocation | Arguments | Description |
| --- | --- | --- | --- |
| `/kramme:visual:check-slop` | User | `<file-or-directory> [--fix]` | Runs a bundled deterministic 73-guard check over HTML screens, reports exact AI-style UI findings, and optionally applies safe idempotent fixes with --fix. Use before generated or hand-written HTML is shown, exported, shipped, or committed, or when asked to check a screen for visual slop. Not for broad UX, accessibility, product-value, or screenshot critique; use kramme:pr:ux-review or kramme:product:design-critic. |
| `/kramme:visual:diagram` | User, Auto | `[topic or description]` | Generate beautiful, self-contained HTML pages that visually explain systems, code changes, plans, and data. Use when the user asks for a diagram, architecture overview, flowchart, schema, or any visual explanation of technical concepts. Also use proactively when about to render a large ASCII table (4+ rows and 3+ columns) — present it as a styled HTML page instead. |
| `/kramme:visual:demo-reel` | User | `[what to capture] [--url <url>\|auto] [--tier static\|before-after\|browser-reel\|terminal-recording]` | Capture local demo evidence for observable product behavior: screenshots, before/after image sets, browser reels, terminal recordings, and short GIF/video proof. Use when shipping UI changes, CLI features, or any change where PR reviewers would benefit from visual or behavioral evidence. |
| `/kramme:visual:plan-review` | User | `[plan-file-path] [codebase-path]` | Generate a visual HTML plan review comparing current codebase state vs. a proposed implementation plan, with architecture diagrams, blast radius analysis, and risk assessment |
| `/kramme:visual:project-recap` | User | `[time-window: 2w\|30d\|3m]` | Generate a visual HTML project recap to rebuild mental model when returning to a project — architecture snapshot, recent activity timeline, decision log, and cognitive debt hotspots |
| `/kramme:visual:generate-image` | User | `[prompt or editing instructions]` | Generate and edit images using Google's Gemini 3 Pro Image API. Use when the user asks to generate, create, edit, modify, change, alter, or update images. Also use when user references an existing image file and asks to modify it in any way (e.g., "modify this image", "change the background", "replace X with Y"). Supports both text-to-image generation and image-to-image editing with configurable resolution (1K default, 2K, or 4K for high resolution). DO NOT read the image file first - use this skill directly with the --input-image parameter. |
| `/kramme:visual:onboarding` | User, Auto | `[focus-area or audience]` | Generate an interactive HTML onboarding guide for newcomers to a codebase — architecture overview, domain model, key flows, conventions, and getting-started walkthrough. |

`/kramme:visual:generate-image` requires a Gemini API key: `export GEMINI_API_KEY="your-api-key-here"`. This works in both Claude Code and Codex; when running the script directly you can pass `--api-key` instead.

#### Discovery & Documentation

Requirements discovery, document conversion, and text processing.

| Skill | Invocation | Arguments | Description |
| --- | --- | --- | --- |
| `/kramme:research` | User, Auto | `[research question or topic] [--output <path>]` | Investigates a question against primary sources and saves one cited Markdown artifact. Use for reading legwork: official docs/API facts, source-code or spec checks, standards, and first-party service behavior before planning or implementation. Not for making product or architecture decisions, implementing code, broad web search, secondary blog summaries, or uncited answers. |
| `/kramme:discovery:wayfinder` | User | `[initiative description \| map-path [ticket-id]]` | Charts huge or foggy initiatives into a local `.context` decision map and resolves one typed frontier ticket per session until the work is ready for SIW or another execution workflow. Use when the route to a destination cannot fit in one agent session or parallel workspaces need coordinated planning state. Not for clear specs, ordinary issue decomposition, implementation, or Linear-native tracking. |
| `/kramme:discovery:interview` | User, Auto | `[file-path or topic description] [--ideate] [--decision-tree] [--research]` | Conduct an in-depth interview about a topic/proposal to uncover requirements, priorities, and non-goals, then create a comprehensive plan. Pass --ideate for divergent framing, --decision-tree / depth-first language to resolve tightly coupled decisions one question at a time, or --research to launch topic-specific research agents before the interview. |
| `/kramme:discovery:strategic-inquiry` | User | `[focus, e.g. 'onboarding', src/auth, or omit for whole repo] [--max-questions N] [--output <path>] [--inline]` | Generate ranked strategic questions and evidence-backed briefs on hidden assumptions, contradictions, absences, and load-bearing decisions. Writes STRATEGIC_INQUIRY.md or returns inline. Use to surface blind spots. Not for defect or quality audits; use kramme:code:weakness-audit, kramme:pr:code-review, or kramme:product:review. |
| `/kramme:docs:adr` | User | `[decision title]` | Author Architecture Decision Records for significant, long-lived decisions. Creates ADRs in docs/decisions/ with sequential numbering and lifecycle states (PROPOSED / ACCEPTED / SUPERSEDED / DEPRECATED). Detects and preserves existing ADR format when one is in use; falls back to a Nygard-style template otherwise. Use when adopting a new pattern, committing to a dependency, changing a public interface, changing the data model, or rejecting an alternative a future maintainer might reasonably re-propose. Initiative-local SIW decisions stay in the spec and LOG for transfer to Linear. |
| `/kramme:docs:feature-spec` | User | `[feature name or brief description] [--synthesize\|--auto]` | Author a lightweight PRD-style feature spec before implementation. Produces a single reviewable markdown artifact covering objective, scope, boundaries, assumptions, non-goals, and testing strategy. Use when starting a feature that needs written alignment before coding but does NOT warrant the full siw/ tracked workflow. Pass --synthesize, --auto, or say "draft straight from context" to skip the assumptions block when the current conversation already grounds enough of the spec. For tracked initiatives (phased issues, LOG, audit) use kramme:siw:init instead. |
| `/kramme:docs:track-rejected-enhancements` | User | `<record\|check\|append\|reconsider> <concept>` | (experimental) Record, check, append, or reconsider rejected enhancement concepts in the project's `.out-of-scope/` directory. One markdown file per concept; substantive reason + prior-request list. Use when the team rejects an enhancement and wants to remember why, or when checking whether a new request matches a prior rejection. Not for bug rejections (close as wontfix with a comment), not for deferrals (use issue priority/status instead), not for cross-repo aggregation. |
| `/kramme:docs:review` | User | `[markdown-path] [--inline\|--file\|--output <path>]` | Review one Markdown document outside tracked SIW workflows: requirements, implementation plans, strategy drafts, README/docs drafts, proposals, and decision drafts. Classifies the document, selects focused review lenses, and returns severity-ordered findings inline by default or in a requested report file. Not for source-code review, PR diffs, live-product review, or documents under siw/; use SIW audit skills for tracked SIW artifacts. |
| `/kramme:docs:solution-note` | User | `[problem, lesson, or context]` | Create a reusable solved-problem note in docs/solutions/ after a bug fix, migration, repeated workflow, tricky refactor, or implementation lesson. Captures problem context, failed approaches, final approach, code references, verification, and reuse cautions so future sessions can apply the pattern. Use when the lesson should outlive chat or PR context. Not for long-lived architecture decisions (use kramme:docs:adr), domain vocabulary (use kramme:docs:ubiquitous-language), feature specs, or rejected enhancement scope. |
| `/kramme:docs:solution-refresh` | User | `[solution-note-path\|--all] [--apply]` | Audit docs/solutions/ notes for stale solved-problem knowledge. Compares referenced files, commands, and claims against the current codebase; classifies notes as keep, update, consolidate, or delete; and requires confirmation before stale-note deletion or consolidation. Use when solution notes may have aged, code references moved, or related bugs changed the lesson. Not for creating new solution notes, ADRs, glossary entries, feature specs, or broad documentation rewrites. |
| `/kramme:docs:sync-release` | User | `[<base>...<ref>\|--base <rev> [--ref <rev>]\|--current] [--apply]` | Compare a named Git base/ref or confirmed current checkout with installation, usage, architecture, testing, and public-contract docs. Returns an evidence-linked drift report by default; with --apply or an explicit apply request, previews and applies bounded local doc corrections and reverifies them. Use for release-scoped documentation drift. Not for one-document review, solution-note refresh, ADRs, changelogs, versions, Git or Pull Request mutations, deployment, or publication. |
| `/kramme:docs:to-markdown` | User, Auto | — | Convert documents and files to Markdown using markitdown. Use when converting PDF, Word (.docx), PowerPoint (.pptx), Excel (.xlsx, .xls), HTML, CSV, JSON, XML, images (with EXIF/OCR), audio (with transcription), video via Azure Content Understanding, ZIP archives, YouTube URLs, or EPubs to Markdown format for LLM processing or text analysis. |
| `/kramme:docs:ubiquitous-language` | User | — | Extract a DDD-style ubiquitous language glossary from the current conversation, flagging ambiguities and proposing canonical terms. Saves to UBIQUITOUS_LANGUAGE.md at the repo root. Use when the user wants to define domain terms, build a glossary, harden terminology, or mentions 'ubiquitous language' or 'DDD'. Not for general programming concepts (array, function, endpoint), code-level type/class glossaries, or per-feature naming inside a single module. |
| `/kramme:text:clarify` | User, Auto | `[file-path or text]` | Rewrites prose so readers can understand and act on it quickly by front-loading the outcome, improving structure, and using concrete active language while preserving technical meaning. Use for reports, guidance, documentation, research notes, and summaries that need plain-language editing. Not for removing AI-writing patterns, marketing voice, code, quoted or legal text, or content that must remain verbatim. |
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
| `/kramme:workflow:wizard` | User | `[procedure description or target script path]` | Generates an interactive Bash wizard script for human-run manual procedures: third-party setup, one-off migrations, A-to-B state transitions, local environment values, and GitHub Actions secrets or variables. Use when the user wants a guided setup script that opens URLs, captures values, confirms irreversible steps, and writes local or CI config. Not for running the procedure yourself, ordinary shell automation, or long-lived application code. |
| `/kramme:hooks:configure-links` | User | `[show\|reset\|KEY=VALUE ...]` | Configure the context-links hook by updating its persistent config file with workspace, team key, and issue regex overrides. Use when end users want to set up or change context-links behavior without manually editing files. |
| `/kramme:hooks:toggle` | User | `<status\|reset\|hook-name> [enable\|disable]` | Enable, disable, list, or reset hook toggles for the kramme-cc-workflow plugin. Use when a hook is firing unwantedly, when a new hook needs to be switched on, or when the user asks about current hook state. |
| `/kramme:session:search` | User, Auto | `[question or topic] [--days N] [--platform claude\|codex\|cursor]` | Searches prior coding-agent sessions across Claude Code, Codex, and Cursor using safe metadata/skeleton extraction before synthesis. Use when the user asks what was tried before, references previous attempts, or needs related prior-session context for a coding task. Not for summarizing the current session, personal retrospectives, git history, or broad non-coding history searches. |
| `/kramme:session:automate-repeats` | User | `[session-paths or --recent N] [--effectiveness] [--create\|--auto]` | Reviews recent agent sessions for repeated work, recurring friction, and evidence-backed skill effectiveness, then reports improvements to the existing owner before proposing or scaffolding new automation. Use when asked to inspect recent sessions, find automation opportunities, improve a skill from its runs, determine which skills are working, or turn repeated work into reusable workflows. Not for summarizing one session, general retrospectives, or codebase refactoring. |
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
| `kramme:pr:complete-work` | Hidden | — | Internal post-implementation orchestrator for kramme:code:plan-to-pr. Rechecks the new-PR boundary, delegates caller-scoped review convergence and verification to kramme:pr:review-convergence, and optionally opens the Pull Request and iterates on CI and review feedback until green. Not a standalone implementation or review workflow. |
| `kramme:docs:update-agents-md` | Background | — | This skill should be used when the user asks to "update AGENTS.md", "add to AGENTS.md", "maintain agent docs", add the Hard-Cut Greenfield Policy or no-compatibility-code policy, or otherwise add guidelines to agent instructions. Guides discovery of local skills and enforces structured, keyword-based documentation style. |
| `kramme:git:commit-message` | Background | — | Create commit messages for branch commits. Use when committing code changes or writing commit messages. Covers plain-English commit format, a pre-commit checklist, and AI-attribution rules. Not for PR titles or merge commits, which use Conventional Commits. |
| `kramme:verify:before-completion` | Background | — | Use when about to claim work is complete, fixed, or passing, before committing or creating PRs - requires running verification commands and confirming output before making any success claims; evidence before assertions always |

<!-- END SOURCE-SYNCED SKILL ROWS -->

### Skill Command Migrations

These user-invocable skill names have changed. Update saved prompts and automation before upgrading:

- `/kramme:siw:spec-audit:auto-fix` → `/kramme:siw:apply-spec-audit-fixes`
- `/kramme:docs:out-of-scope` → `/kramme:docs:track-rejected-enhancements`
- `/kramme:code:cleanup-ai` → `/kramme:code:refactor-pass`

The first two replacement skills preserve the existing arguments and behavior. The `cleanup-ai` replacement does not preserve the old arguments or side effects: remove `--auto`; omit arguments to use the canonical branch review scope, or pass file and directory scope tokens instead of a base branch. When cleanup candidates exist, `refactor-pass` verifies and checkpoints scoped uncommitted input, then verifies and commits each simplification separately. The old identifiers no longer resolve.

## Agents

Specialized subagents for PR review and UX audit tasks. Invoked by `/kramme:pr:code-review`, `/kramme:pr:ux-review`, or directly via the Task tool.

<!-- prettier-ignore-start -->
<!-- BEGIN SOURCE-SYNCED AGENT ROWS -->
| Agent | Description |
| --- | --- |
| `kramme:a11y-auditor` | Use this agent to audit UI code for WCAG 2.1 AA accessibility issues, including semantics, ARIA, keyboard navigation, focus handling, screen reader support, and contrast. Use it when accessibility is an explicit requirement or when reviewing forms, dialogs, and other interactive flows; not for general UX or visual consistency review. |
| `kramme:architecture-strategist` | Use this agent to review code changes from an architectural perspective, focusing on system boundaries, dependency direction, layering, abstractions, service interfaces, and alignment with existing patterns. Best for structural refactors, new services, or cross-cutting features; not for style-only or narrowly local implementation feedback. |
| `kramme:auth-reviewer` | Use this agent to review code for authentication, authorization, CSRF, and session management vulnerabilities. Checks that protected operations have proper auth checks, access control is enforced, and sessions are securely managed. |
| `kramme:code-reviewer` | Use this agent to review recent code against project guidelines, CLAUDE.md conventions, and established patterns. It is best used after writing or modifying code, especially before commits or PRs, and should be pointed at the relevant files or diff scope; not for deep product, accessibility, or performance-specific review. |
| `kramme:code-simplifier` | Use this agent after writing or modifying code to simplify the recent changes for clarity, consistency, and maintainability while preserving behavior. It focuses on the modified files or diff scope and is best for cleanup after a working implementation; not for semantic rewrites or feature changes. |
| `kramme:codebase-pattern-reviewer` | Use this agent during spec or design review to detect whether a proposed implementation introduces new codebase patterns, conventions, dependencies, file structures, or abstractions without rationale. Best for pre-implementation SIW spec audits; not for line-level code review or implementation conformance checks. |
| `kramme:comment-analyzer` | Use this agent to review code comments for accuracy, necessity, completeness, and long-term maintainability. Use it after adding or editing docstrings, inline comments, or PR documentation changes; not for reviewing code behavior unrelated to comments. |
| `kramme:convention-drift-reviewer` | Use this agent to review implemented branch changes for convention drift and overcaution relative to the codebase's own established practice. It mines a peer-file baseline with quorum evidence before judging, flags new patterns, conventions, dependencies, or abstractions introduced without rationale, and flags code that is more defensive or complicated than comparable existing sites, citing exemplar file:line evidence or documented rules for every finding. Also supports a refute mode that adversarially re-checks findings against wider sampling. Not for spec-level pattern review (use kramme:codebase-pattern-reviewer) or absolute AI-slop pattern detection (use kramme:deslop-reviewer). |
| `kramme:copy-reviewer` | Use this agent to review UI text for redundancy and remove labels, helper copy, tooltips, and instructions that merely restate what the interface already communicates. Use it for PRs or audits where copy minimalism matters; not for grammar, tone, brand voice, or broader UX review. |
| `kramme:data-reviewer` | Use this agent to review code for cryptographic misuse, information disclosure, and denial-of-service vulnerabilities. Checks for proper use of cryptographic primitives, prevention of sensitive data leaks, and protection against resource exhaustion. |
| `kramme:design-iterator` | Use this agent when a design still feels off after an initial pass or two and needs iterative refinement. It reviews screenshots, applies improvements, and repeats for multiple rounds to improve hierarchy, spacing, color balance, and overall polish; not for one-off code changes that are already visually solid. |
| `kramme:deslop-reviewer` | Use this agent to detect AI-generated code slop in code changes or in review findings. In code-review mode it flags unnecessary comments, defensive noise, weak typing, and style inconsistencies in the diff; in meta-review mode it flags review suggestions that would introduce the same patterns. |
| `kramme:injection-reviewer` | Use this agent to review code for injection vulnerabilities (SQL, command, template, header injection) and cross-site scripting (XSS). Checks that all user inputs are properly sanitized and all outputs are correctly escaped. |
| `kramme:lean-reviewer` | Use this agent to review PR changes for code that can be deleted, avoided, or replaced by existing code, the standard library, native platform features, or installed dependencies. It is a deletion-focused review pass, not a general correctness or style review. |
| `kramme:logic-reviewer` | Use this agent to review code for business logic flaws and race conditions. Checks for state machine violations, numeric overflow, edge cases in validation, and TOCTOU (time-of-check-time-of-use) bugs. |
| `kramme:overengineering-reviewer` | Use this agent to answer one question about branch changes with full recall - are we overdoing things, needlessly complicating things, or hedging against very unlikely edge cases. In necessity-review mode it judges the diff against what the task actually requires (never against codebase baseline practice), is explicitly allowed to make probability judgments, and reports every plausible candidate without confidence thresholds or evidence gates. In justify mode it adversarially defends candidate findings by hunting for the requirement, documented rule, concrete failure path, or stated rationale that warrants the complexity, and returns JUSTIFIED, OVERDONE, or JUDGMENT CALL verdicts. Not for relative baseline measurement (use kramme:convention-drift-reviewer), AI-slop pattern detection (use kramme:deslop-reviewer), or reuse/deletion review (use kramme:lean-reviewer). |
| `kramme:performance-oracle` | Use this agent to review code for performance and scalability risks, including algorithmic complexity, query efficiency, memory use, caching, contention, and bottlenecks. Use it after implementing data-heavy features or when investigating slow paths; not for general code quality review. |
| `kramme:pr-relevance-validator` | Validates that review findings are actually caused by the current review scope (committed PR diff + staged/unstaged/untracked local changes, plus PR description findings when PR metadata is provided). Use this agent after collecting findings from other review agents to filter out pre-existing issues and problems outside the in-scope changes. This prevents scope creep in code reviews by ensuring reviewers only see issues they should address. |
| `kramme:pr-test-analyzer` | Use this agent to review a pull request for test coverage quality and important gaps. It checks whether new behavior, edge cases, and regressions are exercised before a PR is marked ready; not for writing tests or doing general code review. |
| `kramme:product-reviewer` | Use this agent to review PRs, specs, or live-product flows from a product perspective. It checks discoverability, flow completeness, edge cases, information architecture, copy, target user clarity, problem-solution fit, prioritization, trust and safety, and post-action experience, and makes autonomous product calls when context is incomplete. |
| `kramme:removal-planner` | Use this agent to identify dead code, unused dependencies, deprecated paths, and leftover migration artifacts that can be removed safely. It produces structured removal plans with verification steps; not for broad refactors where the code still serves an active purpose. |
| `kramme:silent-failure-hunter` | Use this agent to review recent code for silent failures, swallowed errors, weak error propagation, and misleading fallback behavior. Use it for PRs or recent changes involving try-catch blocks, retries, fallbacks, or error-handling refactors; not for general logic review. |
| `kramme:type-design-analyzer` | Use this agent to review new or changed types for encapsulation, invariant expression, usefulness, and enforcement. Best for PRs that add data models, domain types, or type-heavy refactors; not for general code review when type design is not the main concern. |
| `kramme:ux-reviewer` | Use this agent to review code changes for usability issues using Nielsen's heuristics and interaction design best practices. It looks for missing states, confusing flows, poor feedback, preventable errors, and weak recovery paths; not for accessibility compliance or visual consistency checks. |
| `kramme:visual-reviewer` | Use this agent to review code changes for visual consistency and responsive behavior, including design token usage, spacing, typography, color, component-library conformance, layout reflow, and breakpoint behavior. Use it for UI PRs with custom styling or layout changes; not for accessibility or product strategy review. |
<!-- END SOURCE-SYNCED AGENT ROWS -->
<!-- prettier-ignore-end -->

## Hooks

Event handlers that run automatically at specific points in the Claude Code lifecycle. For detailed configuration, pattern lists, and formatter tables, see [docs/hooks.md](kramme-cc-workflow/docs/hooks.md).

<!-- prettier-ignore-start -->
<!-- BEGIN SOURCE-SYNCED HOOK ROWS -->
| Hook | Event | Description |
| --- | --- | --- |
| `block-rm-rf` | PreToolUse (Bash) | Blocks destructive file deletion commands and recommends `trash` instead. |
| `confirm-review-responses` | PreToolUse (Bash) | Confirms before committing review artifact files. |
| `noninteractive-git` | PreToolUse (Bash) | Blocks git commands that open an interactive editor. |
| `skill-usage-stats` | PreToolUse (Skill), UserPromptSubmit | Records local skill usage statistics. |
| `auto-format` | PostToolUse (Write\|Edit) | Auto-formats code after file modifications using detected project formatter. |
| `context-links` | Stop | Displays PR and Linear issue links at end of messages. |
<!-- END SOURCE-SYNCED HOOK ROWS -->
<!-- prettier-ignore-end -->

Use `/kramme:hooks:toggle` to enable/disable hooks. State persists in `${XDG_STATE_HOME:-$HOME/.local/state}/kramme-cc-workflow/hook-state.json` by default, with `KRAMME_HOOK_STATE_FILE` override support and legacy fallback to `kramme-cc-workflow/hooks/hook-state.json`.

## Recommended Auto Modes

Instead of maintaining a static permission allowlist, use the host's built-in auto mode to reduce approval prompts while retaining its automatic safety checks:

- **Claude Code** — start a session with `claude --permission-mode auto`
- **Codex** — start a session with `codex --approve-for-me`

Enable auto mode only in repositories you trust, and review changes before publishing them.

## Recommended MCP Servers

These MCP servers enhance the plugin's capabilities. See [docs/mcp-servers.md](kramme-cc-workflow/docs/mcp-servers.md) for installation instructions.

| Server | Purpose |
| --- | --- |
| **Linear** | Issue tracking for `/kramme:linear:backlog-refine`, `/kramme:linear:breakdown-findings`, `/kramme:linear:issue-to-pr`, `/kramme:linear:issue-implement`, `/kramme:linear:issue-define`, `/kramme:linear:review-pr`, `/kramme:linear:select-next`, and the optional Linear requirements source in `/kramme:pr:review-convergence` |
| **Context7** | Up-to-date library documentation retrieval |
| **Nx MCP** | Nx monorepo tools for `/kramme:verify:run` in Nx workspaces |
| **Chrome DevTools** | Browser automation and debugging |
| **Claude in Chrome** | Browser automation via Chrome extension |
| **Playwright** | Browser automation for testing |
| **Magic Patterns** | Design-to-code integration for Magic Patterns designs |
| **Granola** | Query meeting notes from Granola |

## Recommended CLIs

CLI tools that enhance the plugin experience. Some are required for specific commands.

### Core and GitHub Workflows

| CLI | Purpose | Install |
| --- | --- | --- |
| `bash` | Hook runtime | Pre-installed on macOS/Linux; use Git Bash on Windows |
| `git` | Version control | Pre-installed on most systems |
| `jq` | Safety-hook JSON parsing | `brew install jq` (macOS) / `apt install jq` (Linux) |
| `python3` | Safety-hook command parsing | Install Python 3.10+ |
| `node` | Local skill-usage recording and Codex conversion | Install Node.js 18+; Codex conversion also requires npm |
| `gh` | GitHub Pull Request workflows | `brew install gh` or follow [cli.github.com](https://cli.github.com/) |

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
| `markitdown` | Document conversion skill | `uvx markitdown` or `pip install markitdown` |
| `skillspector` | Optional security scanning for local skill directories | [NVIDIA/SkillSpector](https://github.com/NVIDIA/SkillSpector) |
| `surf` | AI-generated illustrations in visual diagrams (optional) | [surf-cli](https://github.com/nicobailon/surf-cli) |

## Plugin Structure

The plugin source lives in `kramme-cc-workflow/`; this root README is the canonical project documentation.

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
│   │   └── component-catalog.json  # Generated compact component index
│   └── README.md            # Pointer to this root README
├── .agents/skills/          # Local repository-maintenance skills
└── README.md                # Canonical documentation
```

## Documentation

- [Plugin Documentation](https://code.claude.com/docs/en/plugins)
- [Plugins Reference](https://code.claude.com/docs/en/plugins-reference)
- [Hooks Reference](https://code.claude.com/docs/en/hooks)
- [Skills Documentation](https://code.claude.com/docs/en/skills)
- [Repository Architecture](kramme-cc-workflow/docs/architecture.md)
- [Agent Autonomy Model](kramme-cc-workflow/docs/agent-autonomy.md)
- [Repository Code Map](kramme-cc-workflow/docs/code-map.md)
- [Component Catalog](kramme-cc-workflow/docs/component-catalog.json) (generated compact index of skills, agents, and hooks)
- [Agent Portability Matrix](kramme-cc-workflow/docs/agent-portability.md)
- [Decision Index](kramme-cc-workflow/docs/decisions/README.md)
- [SIW Workflow Reference](kramme-cc-workflow/docs/siw.md)
- [Development Guide](kramme-cc-workflow/docs/development.md)

## Related Plugins

| Plugin | Description |
| --- | --- |
| [Agent Skills for Context Engineering](https://github.com/muratcankoylan/Agent-Skills-for-Context-Engineering) | Agent Skills focused on context engineering principles for building production-grade AI agent systems. |
| [adversarial-spec](https://github.com/zscole/adversarial-spec) | Specification refinement through multi-model debate until consensus is reached. |

## Releases

See [CHANGELOG.md](kramme-cc-workflow/CHANGELOG.md) for version history and [GitHub Releases](https://github.com/Abildtoft/kramme-cc-workflow/releases) for release notes.

For maintainers: see [RELEASE.md](kramme-cc-workflow/RELEASE.md) for the release process.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for the contributor and agent workflow, including source maps, verification commands, and documentation expectations.

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

## Development

The full contributor reference — the complete test-target catalog, coverage baselines and the production-source inventory, pre-PR verification, skill security scans, and the SkillOpt eval pilot — lives in [docs/development.md](kramme-cc-workflow/docs/development.md). The short version:

```bash
# Read-only prerequisite check
bash kramme-cc-workflow/scripts/bootstrap-dev.sh --check

# Explicit macOS, Debian 12+, or Ubuntu 22.04+ setup
bash kramme-cc-workflow/scripts/bootstrap-dev.sh --install

# Fast default suite (Node + Python + Bats)
make -C kramme-cc-workflow test

# Ordinary Pull Request gate
make -C kramme-cc-workflow pr-verify

# Stronger release-candidate gate
make -C kramme-cc-workflow verify
```

The bootstrap covers Make, Bats, `jq`, ShellCheck, Ruff, mypy, Python 3.10+, Node.js 20+, and locked Node dependencies. It uses Homebrew on macOS; on Debian 12+ and Ubuntu 22.04+, Node.js 20+ with npm and Python 3.10+ are prerequisites before the remaining host packages use `apt-get`. It installs pinned Python tools in `.venv` and does not modify Git hooks. Skill changes also require a separate SkillSpector installation for the changed-skill security gate.

The repository also provides an optional managed pre-commit configuration. After installing `pre-commit`, run `npm run hooks:install` to delegate commits to the existing `npm run check:pre-commit` gate; remove it with `npm run hooks:uninstall`. See [CONTRIBUTING.md](CONTRIBUTING.md#optional-pre-commit-check) for platform prerequisites.

## Adding Components

See [AGENTS.md](AGENTS.md) for detailed conventions. Quick reference:

- **Agents**: Create markdown files in `kramme-cc-workflow/agents/` with `name`, `description`, `model`, and `color` frontmatter.
- **Skills**: Create a subdirectory in `kramme-cc-workflow/skills/` with a `SKILL.md` file. Key frontmatter: `name`, `description`, `disable-model-invocation`, `user-invocable`, `kramme-platforms`.
- **Hooks**: Edit `kramme-cc-workflow/hooks/hooks.json` to add event handlers. Available events: `PreToolUse`, `PostToolUse`, `UserPromptSubmit`, `SessionStart`, `Stop`.
- **External sources**: When adapting skills, scripts, docs, or workflows from another project, update the skill's `references/sources.yaml` and classify each entry as `usage: inspiration` or `usage: copied`. Conceptual inspiration must be rewritten in original local language. Copied expression requires a verified compatible license, a complete skill-local notice, the exact upstream path, and an immutable commit, revision, release, or version; public availability and attribution alone are not permission. Fetched source bodies and `references/sources-snapshot/` directories must never be committed. Use `/kramme:skill:create` and `/kramme:skill:review` for the detailed checks.

The skill, agent, and hook table rows in this README and the compact [component catalog](kramme-cc-workflow/docs/component-catalog.json) are generated from component source metadata. Run `python3 kramme-cc-workflow/scripts/generate-component-reference.py --write` to refresh both, or `python3 kramme-cc-workflow/scripts/generate-component-reference.py --check` to validate without writing. `make -C kramme-cc-workflow skill-contracts` fails on drift.

## Local Repository Maintenance

This workspace also includes local maintenance skills under `.agents/skills/`, exposed to Claude Code through the `.claude/skills` symlink. These are for maintaining this repository and are not shipped as part of the public plugin.

| Skill | Description |
| --- | --- |
| `/kramme:skill:audit-sources` | Audits one or more skills against declared inspiration sources, bootstraps missing `references/sources.yaml` manifests, compares normalized source hashes without retaining fetched source bodies, and writes `.context/skill-source-audit-<timestamp>.md` reports. |

Run `/kramme:skill:audit-sources` monthly and again before each quarterly catalog review. The audit stays manual because fetching upstream content and trusting its contents are deliberate decisions. A reported upstream change is a prompt to review a skill, never permission to change it: fold suggestions into a `SKILL.md` only after human review, and refresh a `baseline_hash` only from a fetch that returned the real source rather than a redirect, login, or error page.

## Attribution

This plugin is shaped by work shared across the agent-tooling community. The
sections below credit the projects, practitioners, standards, and official
documentation behind specific skills, workflows, and conventions.

Copied prose, scripts, templates, and substantial assets must be permitted by a
verified upstream license and ship with its complete required notice, not only
an attribution in this README. Adapted workflows should record their source in
the skill's `references/sources.yaml`, rewrite the workflow in this plugin's
style, and avoid direct ports of long monolithic skill bodies. See
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for retained third-party
material and its skill-local notices.

### From [addyosmani/agent-skills](https://github.com/addyosmani/agent-skills)

- `kramme:docs:feature-spec`: Adapted from [spec-driven-development](https://github.com/addyosmani/agent-skills/tree/main/skills/spec-driven-development).
- `kramme:docs:adr`: Adapted from [documentation-and-adrs](https://github.com/addyosmani/agent-skills/tree/main/skills/documentation-and-adrs).
- `kramme:code:source-driven`: Adapted from [source-driven-development](https://github.com/addyosmani/agent-skills/tree/main/skills/source-driven-development).
- `kramme:code:deprecate`: Adapted from [deprecation-and-migration](https://github.com/addyosmani/agent-skills/tree/main/skills/deprecation-and-migration).
- `kramme:test:tdd`: Adapted from [test-driven-development](https://github.com/addyosmani/agent-skills/tree/main/skills/test-driven-development).
- `kramme:browse` security boundaries, JavaScript constraints, content boundary markers, and Addy marker/epilogue conventions: adapted from [browser-testing-with-devtools](https://github.com/addyosmani/agent-skills/tree/main/skills/browser-testing-with-devtools).
- `kramme:qa` network triage ladder, clean-console standard, accessibility ladder, and Addy marker/epilogue conventions: adapted from [browser-testing-with-devtools](https://github.com/addyosmani/agent-skills/tree/main/skills/browser-testing-with-devtools).
- `kramme:git:commit-message`, `kramme:pr:generate-description`, `kramme:git:recreate-commits`, `kramme:pr:rebase`: Addy output markers, Change Summary triplet (`CHANGES MADE / THINGS I DIDN'T TOUCH / POTENTIAL CONCERNS`), 3-section epilogue, 6-item pre-commit checklist, and "dev branches are costs" framing adapted from [git-workflow-and-versioning](https://github.com/addyosmani/agent-skills/tree/main/skills/git-workflow-and-versioning). Addy's per-commit Conventional Commits rule is explicitly rejected.

### From [EveryInc/compound-engineering-plugin](https://github.com/EveryInc/compound-engineering-plugin)

- `kramme:architecture-strategist`, `kramme:design-iterator`, and `kramme:performance-oracle`: Adapted from the plugin's review agents.
- `kramme:product:strategy` and `kramme:product:pulse`: Adapted from skills `ce-strategy` and `ce-product-pulse`.
- `kramme:code:optimize`: Adapted from [ce-optimize](https://github.com/EveryInc/compound-engineering-plugin/tree/6f9ab03a031c054a8046659926251fb6c149269f/plugins/compound-engineering/skills/ce-optimize), reviewed at commit `6f9ab03a031c054a8046659926251fb6c149269f`.
- `kramme:session:search` and `kramme:session:automate-repeats`: Adapted from skill `ce-sessions`, including its safe session discovery and extraction substrate reviewed at commit `6f9ab03a031c054a8046659926251fb6c149269f`.
- `kramme:setup`, `kramme:git:clean-gone-branches`, and `kramme:git:worktree`: Adapted from skills `ce-setup`, `ce-clean-gone-branches`, and `ce-worktree`, reviewed at commit `6f9ab03a031c054a8046659926251fb6c149269f`.
- `kramme:docs:solution-note` and `kramme:docs:solution-refresh`: Adapted from skills `ce-compound` and `ce-compound-refresh`, reviewed at commit `6f9ab03a031c054a8046659926251fb6c149269f`.
- `kramme:docs:review`: Adapted from [ce-doc-review](https://github.com/EveryInc/compound-engineering-plugin/tree/main/plugins/compound-engineering/skills/ce-doc-review).
- `kramme:code:work-from-plan`: Adapted from [ce-work](https://github.com/EveryInc/compound-engineering-plugin/tree/main/plugins/compound-engineering/skills/ce-work) and [ce-plan](https://github.com/EveryInc/compound-engineering-plugin/tree/main/plugins/compound-engineering/skills/ce-plan) as a thin routing adapter, not a full autonomous execution pipeline.
- `kramme:launch:announce`: Adapted from [ce-promote](https://github.com/EveryInc/compound-engineering-plugin/tree/main/plugins/compound-engineering/skills/ce-promote).
- `kramme:visual:demo-reel` and PR visual evidence delegation: Adapted from [ce-demo-reel](https://github.com/EveryInc/compound-engineering-plugin/tree/b6250490bec4c0488d68ad66d72bd99f6edb95fd/plugins/compound-engineering/skills/ce-demo-reel), reviewed at commit `b6250490bec4c0488d68ad66d72bd99f6edb95fd`.
- Codex converter: Inspired by the plugin's converter approach.
- External-source adaptation policy, copied-script attribution guardrails, and artifact-lifecycle prompts: Informed by [the repository at commit `6f9ab03a031c054a8046659926251fb6c149269f`](https://github.com/EveryInc/compound-engineering-plugin/tree/6f9ab03a031c054a8046659926251fb6c149269f), including representative skills `ce-compound`, `ce-compound-refresh`, `ce-plan`, `ce-code-review`, and `ce-optimize`.
- Shared dev-server detection scripts and browser-facing auto URL detection contract: Adapted from [ce-polish](https://github.com/EveryInc/compound-engineering-plugin/tree/6f9ab03a031c054a8046659926251fb6c149269f/plugins/compound-engineering/skills/ce-polish), reviewed at commit `6f9ab03a031c054a8046659926251fb6c149269f`.

### Other sources

- `kramme:docs:update-agents-md`: Inspired by [getsentry/skills](https://github.com/getsentry/skills/blob/main/plugins/sentry-skills/skills/agents-md/SKILL.md).
- `kramme:git:commit-message`: From [getsentry/skills](https://github.com/getsentry/skills/blob/main/plugins/sentry-skills/skills/commit/SKILL.md).
- `kramme:text:clarify`: Inspired by [fofr's GOV.UK style skill](https://gist.github.com/fofr/505e225f9bf5e839d30c12ba6bfa0be2) and official GOV.UK guidance on [identifying user needs](https://guidance.publishing.service.gov.uk/writing-to-gov-uk-standards/plan-manage-content/identify-user-needs/) and [using clear language](https://guidance.publishing.service.gov.uk/writing-to-gov-uk-standards/writing-guidelines/clear-language/), adapted into a locale-neutral reader-task workflow.
- `kramme:text:humanize`: Based on Wikipedia: Signs of AI writing (maintained by WikiProject AI Cleanup) and heavily inspired by [blader/humanizer](https://github.com/blader/humanizer).
- `kramme:visual:diagram`, `kramme:visual:generate-image`, `kramme:visual:onboarding`, `kramme:visual:plan-review`, and `kramme:visual:project-recap`: Adapted from [nicobailon/visual-explainer](https://github.com/nicobailon/visual-explainer).
- `kramme:visual:check-slop`: Vendors and adapts Gesso Build's MIT-licensed anti-slop detector and 73-rule registry at commit [`ab68f1878dd5f19ac8dee9d55d2f4313060cac83`](https://github.com/Gesso-Build/skills/tree/ab68f1878dd5f19ac8dee9d55d2f4313060cac83). Complete notices for Gesso and bundled parser dependencies ship with the skill.
- Skills authoring patterns: Inspired by [mgechev/skills-best-practices](https://github.com/mgechev/skills-best-practices).
- `kramme:session:automate-repeats` effectiveness evidence, counterfactual improvement gate, and `kramme:session:search` explicit skill-use extraction: Inspired by Warp's [skill-doctor workflow, rubrics, guidance, and collector at commit `737129f`](https://github.com/warpdotdev/common-skills/tree/737129fae58e1feb4ec956c0f0bfa597b5c6ee89/.agents/skills/skill-doctor).
- `kramme:pr:github-review-reply`: GitHub review comment listing, review-summary reads, top-level PR comment reads/posts, reply posting, review thread mapping, and thread resolution operations are grounded in official GitHub REST and GraphQL API documentation.
- `kramme:pr:github-review`: review-requested PR discovery, PR-context reads, `pull/<N>/head` fetch, existing-conversation mapping (REST review comments, GraphQL review threads, issue comments, prior reviews), and the optional review-submission/reply appendix are grounded in the GitHub CLI manual and official GitHub REST/GraphQL/search documentation.

## License

MIT
