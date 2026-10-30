# kramme-cc-workflow

A cross-host agent workflow plugin for Claude Code and Codex that automates the daily development lifecycle:

- **Plan** — requirements discovery, feature specs, and initial issue definition with SIW (Structured Implementation Workflow)
- **Build** — guided implementation of Linear issues, up to a full issue-to-PR pipeline
- **Review** — specialized review agents for code quality, conventions, product, UX, and accessibility
- **Test & verify** — browser-driven QA with evidence capture and project-aware verification runs
- **Explain** — self-contained HTML diagrams, PR walkthroughs, and codebase onboarding guides

Claude Code is the canonical source, and Codex is a first-class native plugin generated from that same source. Install the host you use, or install both when you want to move between them.

<!-- prettier-ignore-start -->
> [!IMPORTANT]
> Thanks for checking this out. It is my personal workflow, built primarily for myself. It is also a practice arena and showcase: the release, security, CI, portability, and documentation machinery are intentionally maintained as part of the work. I experiment in the open and ship updates quickly, so skills may change or occasionally be removed. Questions are always welcome. Feel free to fork, "steal" ideas, or jump straight to the [sources of inspiration](#attribution).

> [!NOTE]
> Meaningful parts of this plugin are adapted from projects and practitioners across the agent-tooling community. The [Attribution](#attribution) section credits the specific sources behind individual skills, workflows, and conventions.
<!-- prettier-ignore-end -->

## Table of Contents

Using the plugin:

- [Quick Start](#quick-start)
- [Requirements](#requirements)
- [Installation & Updating](#installation--updating)
- [Workflows](#workflows)
- [Configuration](#configuration)

Reference:

- [Skills](#skills)
- [Agents](#agents)
- [Hooks](#hooks)
- [Renamed and Removed Commands](#renamed-and-removed-commands)
- [Documentation](#documentation)
- [Related Plugins](#related-plugins)
- [Releases](#releases)

Contributing & maintenance:

- [Contributing](#contributing)
- [Development](#development)
- [Plugin Structure](#plugin-structure)
- [Adding Components](#adding-components)
- [Local Repository Maintenance](#local-repository-maintenance)
- [Attribution](#attribution)
- [License](#license)

## Quick Start

Install in Claude Code, inside a session:

```bash
/plugin marketplace add Abildtoft/kramme-cc-workflow
/plugin install kramme-cc-workflow@kramme-cc-workflow
```

Or install in Codex, from your terminal:

```bash
codex plugin marketplace add Abildtoft/kramme-cc-workflow --ref codex-plugin
codex plugin add kramme-cc-workflow@kramme-cc-workflow
```

Then check your environment and try a first workflow:

```bash
/kramme:setup           # read-only check of tools, repository context, and plugin updates
/kramme:pr:code-review  # review the changes on your current branch
/kramme:verify:run      # run tests, linting, and type checks for changed code
```

In Codex, start skills with `$` instead of `/`, for example `$kramme:setup`. See [Installation & Updating](#installation--updating) for other install methods and auto-update.

## Requirements

The plugin needs no other plugin and no MCP server for basic use. Use a current release of [Claude Code](https://code.claude.com/docs/en/installation#system-requirements) or the Codex CLI; the plugin does not pin a minimum host version. Prefer macOS, Linux, or WSL.

### Core Tools

| Tool | Used for | Install |
| --- | --- | --- |
| `bash` | Hook runtime | Pre-installed on macOS and Linux. On native Windows, use Git Bash; PowerShell alone cannot run the hooks. |
| `git` | Version control | Pre-installed on most systems |
| `jq` | Safety-hook JSON parsing | `brew install jq` (macOS) / `apt install jq` (Linux) |
| `python3` | Safety-hook command parsing | Install Python 3.10+ |
| `node` | Local skill-usage recording | Install Node.js 18+ |

The enabled safety hooks fail closed when `jq` or Python is unavailable. Without Node.js, the usage-recording hook records a diagnostic and otherwise stays silent. The `update-check` hook uses `curl` and Python file locking, and stays silent when they are unavailable. If hooks cannot run in your environment, disable them with `/kramme:hooks:toggle`.

### Optional Tools by Capability

| Capability | Needs |
| --- | --- |
| GitHub Pull Request, review, CI, and changelog workflows | Authenticated GitHub CLI: `brew install gh` or [cli.github.com](https://cli.github.com/), then `gh auth login` |
| Linear workflows | Authenticated Linear MCP server |
| Browser QA and live product review | Claude in Chrome, Chrome DevTools, or Playwright MCP |
| Document conversion | `uv`/`uvx`; MarkItDown dependencies download on demand |
| Recoverable cleanup in autonomous workflows, and the `trash` alternative that `block-rm-rf` recommends | `brew install trash` (macOS) / `apt install trash-cli` (Linux) |
| Codex checkout installs | Node.js 18+, npm, and the Codex CLI (`npm install -g @openai/codex`) |
| Project verification and formatting | The target project's own build, test, type-check, and formatter tools, such as `nx`, `dotnet`, `prettier`, `eslint`, or `tsc` |
| Nx workspace tools in `/kramme:verify:run` | Nx MCP |
| Up-to-date library documentation | Context7 MCP |
| Magic Patterns designs and Granola meeting notes | Magic Patterns MCP, Granola MCP |
| Security scans of local skill directories | [SkillSpector](https://github.com/NVIDIA/SkillSpector) |
| AI-generated illustrations in visual diagrams | [surf-cli](https://github.com/nicobailon/surf-cli) |

The Claude Code marketplace install does not need Node.js, and Codex marketplace installs need no checkout. [docs/mcp-servers.md](kramme-cc-workflow/docs/mcp-servers.md) covers MCP server setup. After installing on either host, run `/kramme:setup` for a read-only environment check. Contributors need the broader toolchain described in [Development](#development).

## Installation & Updating

Both hosts expose the same skills and workflows. Choose the install and update commands for the host where you work:

| Host | Install | Update |
| --- | --- | --- |
| Claude Code | `/plugin marketplace add` then `/plugin install` | Turn on auto-update, run `/plugin marketplace update`, or rerun the Git/local install |
| Codex | `codex plugin marketplace add` then `codex plugin add` | `codex plugin marketplace upgrade` then `codex plugin add` |

### Claude Code

Marketplace install (recommended) — run inside a Claude Code session:

```bash
/plugin marketplace add Abildtoft/kramme-cc-workflow
/plugin install kramme-cc-workflow@kramme-cc-workflow
```

Then turn on auto-update so new releases install themselves: run `/plugin`, open **Marketplaces**, select `kramme-cc-workflow`, and choose **Enable auto-update**. Claude Code leaves auto-update off for third-party marketplaces until you do.

Other installs — run from your terminal:

```bash
# Direct Git install
claude /plugin install git+https://github.com/Abildtoft/kramme-cc-workflow

# Local development
claude /plugin install /path/to/kramme-cc-workflow/kramme-cc-workflow
```

### Codex

The plugin ships to Codex as a native Codex plugin. A converter builds a Codex marketplace from the Claude plugin source, and Codex installs the plugin from that marketplace into its own plugin cache, where it also owns updates and removal.

Install the published plugin without a clone (requires the Codex CLI):

```bash
codex plugin marketplace add Abildtoft/kramme-cc-workflow --ref codex-plugin
codex plugin add kramme-cc-workflow@kramme-cc-workflow
```

Or build and install it yourself:

```bash
# From a checkout
npm install
node kramme-cc-workflow/scripts/convert-plugin.js install kramme-cc-workflow

# With npx, without a clone
npx --yes github:Abildtoft/kramme-cc-workflow install kramme-cc-workflow

# Local development from this repository
./kramme-cc-workflow/scripts/install-codex.sh
```

Checkout installs build the marketplace under the Codex home (`$CODEX_HOME` or `~/.codex`; override it with `--codex-home`) and offer to remove output left by earlier converter releases. The [Agent Portability Matrix](kramme-cc-workflow/docs/agent-portability.md#installing-from-a-checkout) covers installer options, build output, and publishing.

To uninstall:

```bash
# Published install
codex plugin remove kramme-cc-workflow@kramme-cc-workflow
codex plugin marketplace remove kramme-cc-workflow

# Checkout install, including the marketplace and any legacy output
node kramme-cc-workflow/scripts/convert-plugin.js uninstall kramme-cc-workflow
```

### Updating

When a new release is out, the `update-check` hook tells you at the start of a session and gives the update commands for your host. It checks at most once a day, so the notice can arrive up to a day after the release. After you update, the next session names the new version and, in Claude Code, how many breaking changes it includes. To turn the hook off or keep it offline, see [update-check](kramme-cc-workflow/docs/hooks.md#update-check).

| Install | How to update |
| --- | --- |
| Claude Code marketplace | Auto-update, `/plugin marketplace update kramme-cc-workflow` in a session, or `claude plugin update kramme-cc-workflow@kramme-cc-workflow` from a terminal |
| Claude Code Git or local | Re-run the install command |
| Codex published | `codex plugin marketplace upgrade kramme-cc-workflow`, then `codex plugin add kramme-cc-workflow@kramme-cc-workflow` |
| Codex checkout | Re-run the install command; it rebuilds the marketplace and reinstalls the plugin into the Codex cache |

Codex update notices include both paths. `marketplace upgrade` requires a Git marketplace; local installs made from a checkout or through `npx` must re-run their original install command.

Restart the host you updated, or run `/reload-plugins` in Claude Code, for changes to take effect.

Claude Code auto-update needs v2.0.70 or later. When a release lands, Claude Code shows `Plugin updated` with a `/reload-plugins` prompt. `/kramme:setup` reports the auto-update policy from local settings and the marketplace record, but it does not inspect session flags, remote or OS-managed policy, or workspace trust; confirm the effective policy under `/plugin`.

### Checking Your Installation

- **Claude Code:** open `/plugin` to see the marketplace registration and installed version.
- **Codex:** run `codex plugin list`; the plugin appears as `kramme-cc-workflow@kramme-cc-workflow` with its status, version, and marketplace source.
- **Either host:** run `/kramme:setup` for a read-only report of missing tools, cached plugin versions, and update status. It never installs plugins or changes host configuration.

With a non-default Codex home, keep `CODEX_HOME` exported in shells Codex runs, because converted skills locate their files through it. If skills from an earlier converter release appear twice, run the checkout install again with `--yes` to remove the legacy copy.

## Workflows

These skills cover the full lifecycle of a change. Most work runs through the middle phases; the situational **Chart** phase up front is for tasks too big or foggy to plan in one pass.

| Phase | When to use it | Skills |
| --- | --- | --- |
| **Chart** (situational) | Huge or foggy initiatives whose route can't fit in one session | `/kramme:discovery:wayfinder` |
| **Clarify** | Requirements are vague, contested, or half-formed | `/kramme:discovery:interview` (`--siw` for tracked SIW work) |
| **Spec** | Turn intent into a written source of truth | `/kramme:docs:feature-spec`, `/kramme:siw:init` |
| **Break down** | Split the spec into tracked issues | `/kramme:siw:generate-phases` |
| **Transfer** | Make Linear the implementation source of truth | `/kramme:siw:transfer-to-linear` |
| **Implement** | Build one issue at a time | `/kramme:linear:issue-implement`, `/kramme:linear:issue-to-pr` |
| **Review & verify** | Check quality before shipping | `/kramme:pr:code-review`, `/kramme:verify:run` |

Most tasks begin at Clarify or Spec and flow into SIW, the local Markdown-based workflow for refining a specification and its first issue set. Approved work then transfers one way to Linear for implementation and Pull Requests. Use `/kramme:research` whenever a phase needs a cited answer from primary sources, and ask for a throwaway prototype when a disposable experiment would settle one design question.

Feature specs, API design, Linear implementation planning, review resolution, agent-readiness recommendations, skill authoring and review, and completion verification weigh user experience (UX), developer experience (DX), and agent experience (AX) together. They:

- preserve established behavior and contracts outside the intended change;
- make intentional changes and material tradeoffs explicit;
- support regression claims with relevant checks.

Unchanged or inapplicable dimensions are fine; the principle never requires extra scope.

### Prepare with SIW, implement with Linear

SIW refines non-trivial work into a spec-driven initial issue set, then migrates the durable planning context into Linear.

```bash
/kramme:siw:init                         # link or create a spec, set up siw/ directory
/kramme:siw:spec-audit                   # validate and refine the specification
/kramme:siw:generate-phases              # break the spec into phased issues
/kramme:siw:transfer-to-linear           # migrate specs, decisions, milestones, and issues
/kramme:workflow:cleanup-artifacts --siw # retire local SIW files after verified transfer
```

See [docs/siw.md](kramme-cc-workflow/docs/siw.md) for the full workflow reference.

### Implement and ship a Linear issue

```bash
/kramme:linear:issue-to-pr DISC-202 --strict --ship    # implement, review, verify, and open the PR
/kramme:linear:issue-to-pr DISC-202 --continue --ship  # resume after an interrupted session
```

1. **Preflight:** checks Linear's target branch and confirms there is no existing Pull Request or remote branch for it. Needs a clean tree unless you pass `--continue`.
2. **Start:** moves a Backlog issue to the team's started status, preferring In Progress; any other state asks first. Renames a detected Conductor workspace, best-effort.
3. **Implement** the issue with `/kramme:linear:issue-implement`.
4. **Review:** freezes the issue's requirements and runs [review convergence](kramme-cc-workflow/docs/review.md#review-convergence) on the branch.
5. **Ship** (`--ship` only): opens the PR and runs `/kramme:pr:fix-ci` until CI and review feedback are clear.
6. **Hand off:** summarizes what was built, what review found, and what to check when you review it.

| Flag | Effect |
| --- | --- |
| `--ship` | Open the PR and stabilize CI; without it, the run stops after verification |
| `--strict` | Give every review finding an evidence-based disposition; forces the `full` review profile |
| `--cycles <1-5>` | Fix-and-rerun budget for review convergence (default 2) |
| `--depth balanced\|full` | Raise the review profile above the branch's risk floor; it never lowers it |
| `--continue` | Resume on the issue's exact unpublished branch; the issue must already be started and every changed path must belong to it |

`/kramme:code:plan-to-pr` runs the same pipeline for one `PR_PLAN_*.md` file. The [shipping guide](kramme-cc-workflow/docs/shipping.md) covers preconditions, status changes, and the handoff in full.

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
| How much review the branch needs, which review commands to run, and which decisions need a human | `/kramme:pr:triage-risk` |
| Anything in the branch that looks strange, unusual, or unnecessary | `/kramme:pr:gut-check` |
| Independent review by a provider different from the active Claude Code or Codex host | `/kramme:pr:adversarial-review` |
| Code-quality findings on your local branch | `/kramme:pr:code-review` |
| Final code-review pass before commit, ship, or closeout | `/kramme:pr:code-review --loop` |
| Convention drift and overcaution vs. established codebase practice | `/kramme:pr:convention-review` |
| Needless complexity and unlikely-edge-case hedging vs. what the task requires | `/kramme:pr:overengineering-review` |
| Product-value, flow, copy, and edge-case review, plus UX, visual, and accessibility review when UI files changed | `/kramme:pr:product-review` |
| Review someone else's GitHub PR as the assigned reviewer | `/kramme:pr:github-review` |
| Triage and respond to review comments on your own PR | `/kramme:pr:github-review-reply` |
| Implement fixes from local review findings | `/kramme:pr:resolve-review` |
| Whether an open PR's title and body still match the branch diff | `/kramme:pr:generate-description --check` |

`/kramme:pr:github-review` is report-only by default; it writes a pending review or submits one only when you explicitly ask. Review skills handle stacked Pull Requests one layer at a time, and interrupted reviews resume within 24 hours. The [review guide](kramme-cc-workflow/docs/review.md) covers reviewer models, review convergence, stacks, and GitHub write rules.

New work starts from the repository's workbench branch. Set it with `git config --local kramme.baseBranch <branch>` when it differs from the remote default; the [shipping guide](kramme-cc-workflow/docs/shipping.md#base-branch) explains how the skills choose it.

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
/kramme:visual:explain      # generate an HTML diagram or explainer page
/kramme:docs:to-markdown    # convert PDF, Word, Excel, or images to Markdown
/kramme:code:refactor-pass  # simplification + AI-slop pass on recent changes
/kramme:code:work-from-plan # route and execute a standalone implementation plan
```

All skills are listed in the [reference below](#skills). Background skills, such as commit-message guidance, run automatically.

## Configuration

| Setting | Where | Effect |
| --- | --- | --- |
| `kramme.baseBranch` | `git config --local`, per repository | The workbench branch new work starts from, when it differs from the remote default. `--base <branch>` overrides it for one run. See [Base Branch](kramme-cc-workflow/docs/shipping.md#base-branch). |
| `KRAMME_REVIEW_SUBAGENT_LEVEL` | The `env` block of Claude Code's `settings.json`, or the shell environment Codex inherits | `same` (default) keeps review subagents on the orchestrator's model; `lower` steps them down one model class. See [Reviewer Models](kramme-cc-workflow/docs/review.md#reviewer-models). |
| `--subagent-model <model>` | Flag on review skills and codebase audits | Picks the reviewer model for one run and wins over `KRAMME_REVIEW_SUBAGENT_LEVEL`. |
| Hook toggles | `/kramme:hooks:toggle` | Enable, disable, or reset hooks. State lives in `${XDG_STATE_HOME:-$HOME/.local/state}/kramme-cc-workflow/hook-state.json` unless `KRAMME_HOOK_STATE_FILE` points elsewhere. See [Toggling Hooks](kramme-cc-workflow/docs/hooks.md#toggling-hooks). |
| `KRAMME_AUTOFORMAT_DEBUG=1` | Environment | Keeps the latest failed auto-format attempt's stderr in a private local file. Off by default. See [Failure Diagnostics](kramme-cc-workflow/docs/hooks.md#failure-diagnostics). |
| `CODEX_HOME` | Environment | A non-default Codex home. Keep it exported in shells Codex runs. |
| `.context/` in `.gitignore` | Your repository | Required to resume interrupted GitHub reviews and codebase audits, which save their progress there. |

### Auto Mode

Instead of maintaining a static permission allowlist, use the host's built-in auto mode to reduce approval prompts while retaining its automatic safety checks:

- **Claude Code** — start a session with `claude --permission-mode auto`
- **Codex** — start a session with `codex --approve-for-me`

Enable auto mode only in repositories you trust, and review changes before publishing them.

## Skills

All plugin functionality is delivered through skills. The Invocation column shows who can start each one:

- **User:** only you, from the host's `/` menu (`$` in Codex). These skills set `disable-model-invocation: true` and never auto-run.
- **User, Auto:** you, or the host when the context matches the skill.
- **Background:** only the host, automatically. These skills set `user-invocable: false` and don't appear in the menu.

Each row gives a one-line summary. The full description lives in the skill's `SKILL.md`, and the generated [component catalog](kramme-cc-workflow/docs/component-catalog.json) indexes every skill, agent, and hook by name, invocation mode, and source path.

### Find a Skill by Task

| I want to… | Use |
| --- | --- |
| Turn a vague idea into clear requirements | `/kramme:discovery:interview` |
| Chart an initiative too big or foggy to plan in one session | `/kramme:discovery:wayfinder` |
| Get a cited answer from primary sources | `/kramme:research` |
| Write a feature spec | `/kramme:docs:feature-spec`, or `/kramme:siw:init` for tracked work |
| Write a PRD for the prototype I'm shipping | `/kramme:product:prd` |
| Record an architecture decision | `/kramme:docs:adr` |
| Create or refine a Linear issue | `/kramme:linear:issue-define` |
| Pick the next Linear issue to work on | `/kramme:linear:next` |
| Implement and ship a Linear issue | `/kramme:linear:issue-to-pr` |
| Implement a saved plan | `/kramme:code:plan-to-pr` or `/kramme:code:work-from-plan` |
| Review my branch | `/kramme:pr:code-review`, or see [which review to use](#review-and-ship-a-pr) |
| Open a PR | `/kramme:pr:create` |
| Fix failing CI on my PR | `/kramme:pr:fix-ci` |
| Review someone else's PR | `/kramme:pr:github-review` |
| Respond to review comments on my PR | `/kramme:pr:github-review-reply` |
| Run tests, linting, and type checks | `/kramme:verify:run` |
| Investigate a bug | `/kramme:debug:investigate` |
| Test a running app | `/kramme:qa` |
| Find refactoring candidates or tech debt | `/kramme:code:refactor-opportunities`, or add `--for <spec>` before building a planned change |
| Stop agents from repeating a mistake by turning it into a type, lint rule, or check | `/kramme:code:encode-constraint` |
| Upgrade a framework or library | `/kramme:code:migrate` |
| Explain a system or change visually | `/kramme:visual:explain` |
| Make a document easier to read | `/kramme:text:clarify` |

<!-- BEGIN SOURCE-SYNCED SKILL ROWS -->

### User-Invocable Skills

#### Structured Implementation Workflow (SIW)

Local specification refinement and initial issue planning before a one-way Linear transfer. See [docs/siw.md](kramme-cc-workflow/docs/siw.md).

| Skill | Invocation | Arguments | Description |
| --- | --- | --- | --- |
| `/kramme:siw:init` | User | `[spec-file(s) \| folder \| discover] [--auto]` | Initialize SIW documents in `siw/`: the spec, `LOG.md`, and issues. |
| `/kramme:siw:generate-phases` | User | `[spec-file-path] [--auto]` | Break the spec into atomic, phase-based issues with tests and validation. |
| `/kramme:siw:spec-audit` | User | `[spec-file-path(s) \| 'siw' \| audit-report-path] [--product] [--auto] [--apply [--dry-run] [--threshold 60-100] [--allow-dirty]] [--model opus\|sonnet\|haiku] [--inline] [--team]` | Audit specs for implementation readiness; `--product` adds product checks and `--apply` fixes mechanical findings. |
| `/kramme:siw:resolve-audit` | User | `[audit-report-path] [finding-id(s)] [--auto]` | Resolve spec-audit findings one by one with summaries, alternatives, a recommendation, and SIW issue creation. |
| `/kramme:siw:transfer-to-linear` | User | `[siw-dir] [--project <name-or-id>] [--team <team>] [--dry-run] [--skip-done] [--skip-existing\|--retry]` | Move a planned SIW initiative into Linear for good: one project with its documents, milestones, and issues. One-way. |

#### Discovery, Research & Learning

Requirements discovery, primary-source research, and checks that you understand a topic.

| Skill | Invocation | Arguments | Description |
| --- | --- | --- | --- |
| `/kramme:research` | User, Auto | `[research question or topic] [--output <path>]` | Answer a question from primary sources, such as official docs, specs, or source code, and save one cited Markdown artifact. |
| `/kramme:discovery:wayfinder` | User | `[initiative description \| map-path [ticket-id]]` | Chart a huge or foggy initiative as a local decision map and resolve one open question per session until it is ready for planning. |
| `/kramme:discovery:interview` | User, Auto | `[topic \| file-path(s) \| siw] [--siw] [--apply] [--ideate] [--decision-tree] [--research]` | Interview you about a topic, proposal, or spec to uncover requirements, priorities, and non-goals, then write a plan; `--siw` feeds an SIW spec. |
| `/kramme:discovery:strategic-inquiry` | User | `[focus, e.g. 'onboarding', src/auth, or omit for whole repo] [--max-questions N] [--output <path>] [--inline]` | Generate ranked strategic questions about hidden assumptions, contradictions, and load-bearing decisions in a codebase or area. |
| `/kramme:learn:verify-understanding` | User | `[topic: PR, branch, feature, document, spec, etc.] [--answer-options\|--choices]` | Confirm that you understand a PR, feature, spec, or other topic through questions and a checklist before calling it done. |

#### Product

Product direction, demand validation, post-prototype PRDs, behavior documentation, and design critique.

| Skill | Invocation | Arguments | Description |
| --- | --- | --- | --- |
| `/kramme:product:strategy` | User | `[optional: section or notes to revisit, e.g. 'metrics', 'active tracks']` | Create or update `STRATEGY.md`, a concise product anchor covering problem, users, metrics, active tracks, and non-goals. |
| `/kramme:product:validate-demand` | User, Auto | `[idea or evidence] [--output <repo-relative-path>]` | Judge whether a product idea has enough demand evidence to justify more work: GO, PIVOT, KILL, or INSUFFICIENT EVIDENCE. |
| `/kramme:product:prd` | User | `[feature name or path to an existing PRD]` | Write a PRD after prototyping that records which candidate ships and why, how success is measured, and when to roll back; log results after launch. |
| `/kramme:product:describe-behavior` | User | `[product or surface] [--source <path>] [--output <path>] [--resume]` | Document how an existing product behaves from the user's perspective, grounded in code, tests, and the running app. |
| `/kramme:product:design-critic` | User, Auto | `[file-path, screenshot, URL, or product question]` | (experimental) Critique product UI and UX, including flows, hierarchy, trust, and jobs-to-be-done, rather than visual polish alone. |
| `/kramme:product:review` | User | `<url\|auto> [--flows <flow1,flow2,...>] [--focus <dimension>] [--inline]` | (experimental) Review a live product across flows for navigation, discoverability, onboarding, consistency, dead ends, and trust. |

#### Linear

Linear issue tracking. These skills need an authenticated Linear MCP server; `issue-to-pr` and `review-pr` also use the GitHub CLI. See the [shipping guide](kramme-cc-workflow/docs/shipping.md#linear-issue-to-pull-request).

| Skill | Invocation | Arguments | Description |
| --- | --- | --- | --- |
| `/kramme:linear:backlog-refine` | User | `[team] [--project <name>] [--label <name>] [--stale-days <n>] [--limit <n>] [--apply]` | Grade a Linear team's open backlog and propose completing, cancelling, merging, splitting, or rewriting issues. Read-only unless `--apply`. |
| `/kramme:linear:breakdown-findings` | User | `[--auto] [--ask] [--dry-run] [--resume <partial-report-path>] [--team <team>] [--project <project>] [--label <label>] [--] [source ...]` | Turn reviewed audit, review, scan, or QA findings into coordinated, PR-sized Linear issues. |
| `/kramme:linear:issue-define` | User, Auto | `[--auto [--ask]] [--] [issue-id or description and/or file paths for context]` | Create or improve a Linear issue that fits one PR; larger work becomes a parent with sub-issues. `--auto` drafts from rough input. |
| `/kramme:linear:issue-implement` | User, Auto | `<ISSUE-ID> [--auto] [--set-in-progress]` | Implement one Linear issue: branch setup, reference mapping, planning, coding, and fast verification. |
| `/kramme:linear:issue-to-pr` | User | `<ISSUE-ID> [--continue] [--strict] [--cycles <1-5>] [--depth <balanced\|full>] [--ship]` | Take one Linear issue through implementation, review convergence, and verification; `--ship` also opens the PR and fixes CI. |
| `/kramme:linear:next` | User | `[team or selection query] [--state <name>] [--agent-ready] [--interest <preference>] [--mine\|--unassigned\|--both] [--project <name>] [--label <name>] [--count <n>] [--limit <n>]` | Find up to 10 valuable, unstarted Linear issues by default, with plain-language summaries, when deciding what to pick up next. |
| `/kramme:linear:review-pr` | User, Auto | `[PR-number\|PR-url] [ISSUE-ID]` | Check that an existing PR implements its Linear issue, tracing each requirement to diff, code, and test evidence. Read-only. |

#### Pull Requests

PR creation, review, iteration, and resolution. See the [review guide](kramme-cc-workflow/docs/review.md) and the [shipping guide](kramme-cc-workflow/docs/shipping.md).

| Skill | Invocation | Arguments | Description |
| --- | --- | --- | --- |
| `/kramme:pr:create` | User, Auto | `[--auto] [--draft] [--rebase] [--base <branch>] [--linear-issue <ISSUE-ID>] [--require-generated-description] [--authorize-history-rewrite]` | Publish a new PR: narrative commits, a generated title and body, and a lease-protected first push. |
| `/kramme:pr:stack` | User | `[init [--base <trunk>] <branches...> \| submit \| sync \| merge <pr-number> \| adopt [--base <trunk>] <branches...> \| status]` | Create and manage GitHub stacked PRs with gh-stack when a change should land as a chain of small dependent PRs. |
| `/kramme:pr:adversarial-review` | User, Auto | `[--provider claude\|codex] [--model <id>] [--base <branch>] [--requirements <authoritative requirements>]` | Get one read-only review of your branch from a different model provider than the host you are using. |
| `/kramme:pr:code-review` | User, Auto | `[--subagent-model <model>] [aspects] [--emphasize <dim>...] [--base <branch>] [--previous-review <path>] [--no-cleanup] [--parallel] [parallel] [--team] [--inline] [--loop] [--no-diff-comments]` | Review branch changes for bugs, tests, errors, types, architecture, security, performance, and cleanup; writes `REVIEW_OVERVIEW.md`. |
| `/kramme:pr:review-convergence` | User, Auto | `[--subagent-model <model>] [--strict] [--rounds <1-5>] [--depth <balanced\|full>] [--adversarial-review [--adversarial-provider claude\|codex] [--adversarial-model <id>]] [--derive \| LINEAR-ISSUE \| --requirements <authoritative requirements>]` | Take a clean committed branch through ordered review gates, bounded fixes, and verification against frozen requirements. |
| `/kramme:pr:resolve-review` | User, Auto | `[--team] [--implement-only] [--granular] [--severity ...] [--source local\|online\|conductor] [review\|url\|instructions]` | Implement fixes for code-review or Conductor diff-comment findings as commits on the current branch. |
| `/kramme:pr:github-review-reply` | User | `[--auto] [--implement\|--no-implement] [--post] [--resolve] [--inline] [--humanize] [--human-only\|--include-bots] [--all] [--only <login>] [pr-url\|instructions]` | Triage review comments on your own PR, make the needed changes, and draft or post replies. |
| `/kramme:pr:github-review` | User | `[--subagent-model <model>] [pr-number\|pr-url] [--draft-review] [--clarity-check\|--no-clarity-check] [--base <ref>] [--categories a11y,ux,product,visual] [--code-only] [--sequential] [--fresh] [--include-bots] [--all-threads] [--inline] [--keep-worktree]` | Review someone else's GitHub PR, including linked Linear issues. Report-only unless you ask for a pending review. |
| `/kramme:pr:fix-ci` | User, Auto | `[--fixup] [--auto] [--no-consolidate] [--rebase] [--scope-plan <archived-plan>]` | Repair failing CI checks and reviewer feedback on an open PR with targeted pushes until checks pass. |
| `/kramme:pr:generate-description` | User, Auto | `[--auto] [--no-update] [--check [--strict]] [--base <ref>] [--base-commit <oid>] [--linear-issue <ISSUE-ID>]` | Write a PR title and body from the diff, commits, and Linear context; `--check` reports drift in an open PR's description. |
| `/kramme:pr:walkthrough` | User | `[--report [branch\|commit\|PR#\|range] \| --report --base <ref> \| --base <ref>] [--output <path>]` | Generate a visual HTML walkthrough of a branch or PR; `--report` produces a shareable before/after architecture report. |
| `/kramme:pr:gut-check` | User, Auto | `[--base <branch>] [--intent <text>]` | Get a fast first-reader reaction: does anything on this branch look strange, unusual, or unnecessary? |
| `/kramme:pr:triage-risk` | User, Auto | `[--base <branch>]` | Decide how much review the branch needs: a low, medium, or high risk tier and the review commands to run. Read-only. |
| `/kramme:pr:convention-review` | User, Auto | `[--subagent-model <model>] [--base <branch>] [--threshold 0-100] [--baseline <path>] [--inline] [--no-diff-comments]` | Flag drift from documented rules and established codebase practice, plus overcautious code, with evidence for every finding. |
| `/kramme:pr:overengineering-review` | User, Auto | `[--subagent-model <model>] [--base <branch>] [--inline] [--no-diff-comments] [--requirements <text>]` | Flag speculative generality and unlikely edge-case handling that the requirements do not need. |
| `/kramme:pr:product-review` | User, Auto | `[--subagent-model <model>] [app-url\|auto] [--categories a11y,ux,product,visual] [--threshold 0-100] [--base <branch>] [--parallel] [--team] [--inline] [--no-diff-comments]` | Review the product value, UX, visual consistency, and accessibility of your changes with specialist agents. |
| `/kramme:pr:rebase` | User, Auto | `[--auto] [--force-push] [--fix-ci] [--base <branch>] [--all-open]` | Rebase onto the PR's target branch, resolve conflicts safely, and force-push with a lease; cascades through stacks. |

#### Code Changes

Plan-driven implementation, migrations, deprecations, design and security guidance, and cleanup.

| Skill | Invocation | Arguments | Description |
| --- | --- | --- | --- |
| `/kramme:code:plan-to-pr` | User | `<attached plan \| PR_PLAN_W##L_*.md> [--continue] [--strict] [--cycles <1-5>] [--depth <balanced\|full>] [--ship]` | Implement one self-contained `PR_PLAN_*.md` on a fresh branch, then review, verify, and optionally ship it as a PR. |
| `/kramme:code:work-from-plan` | User, Auto | `[plan path \| inline plan]` | Execute one standalone implementation plan, such as a `PR_PLAN_*.md` file or a pasted checklist, as bounded work on the current branch. |
| `/kramme:code:breakdown-findings` | User | `[--auto] [--resume\|--reconcile\|--split] [--all \| plan-file ...] [--worktree <path>] [--source <ref>] [--base <ref>] [--] [source ...]` | Cluster validated review, audit, or QA findings into PR-sized `PR_PLAN_*.md` files; `--split` plans slices of a branch and `--reconcile` updates plan sets. |
| `/kramme:code:api-design` | User, Auto | `[--design-twice]` | (experimental) Design stable APIs and module boundaries for endpoints, public modules, and SDKs; `--design-twice` compares alternative shapes first. |
| `/kramme:code:harden-security` | User, Auto | — | Apply secure defaults when code handles untrusted input, authentication, sessions, dependencies, or personal data. |
| `/kramme:code:migrate` | User | `<target e.g. 'Angular 19', 'React 19', 'Node 22'> [--auto]` | (experimental) Plan and run framework or library version upgrades, such as Angular, React, or Node, in phases with verification gates. |
| `/kramme:code:deprecate` | User | — | Plan and run the deprecation of code, features, APIs, or persistent data shapes: build the replacement, announce, migrate incrementally, then remove. |
| `/kramme:code:optimize` | User | `[spec.yaml \| optimization goal] [--auto]` | (experimental) Run repeatable, metric-driven optimization experiments when a measurable outcome needs variants instead of guess-and-check. |
| `/kramme:code:refactor-pass` | User | `[scope ... \| --rewrite]` | Simplify recent changes and clean up AI slop slice by slice without changing behavior; `--rewrite` redoes mediocre recent work properly. |
| `/kramme:code:encode-constraint` | User | `[mistake description \| path:line example \| review comment]` | Turn an observed agent mistake or review nit into a type, lint rule, or check that rejects it, proven to fail on the mistake and pass on the repository. |

#### Audits

Codebase, dependency, test-suite, and agent-practice audits that report findings without changing code.

| Skill | Invocation | Arguments | Description |
| --- | --- | --- | --- |
| `/kramme:code:refactor-opportunities` | User, Auto | `[--subagent-model <model>] [full \| pr \| path <file-or-folder> \| feature <name>] [--for <spec-file \| description>] [--ranked [--solo] [--output <path>] [--max-findings N] [--base <ref>]]` | Find refactoring candidates and tech debt in a codebase, PR, path, or feature, or before a planned change (`--for`); `--ranked` ranks the biggest weaknesses. |
| `/kramme:code:outside-view` | User | `[--subagent-model <model>] [--raters N] [--output <path>] [--compare <report-path>] [--cross-model]` | Rate a codebase with unprimed raters to surface unknown-unknown quality problems, especially in AI-engineered code. |
| `/kramme:code:agent-readiness` | User | `[--subagent-model <model>] [--auto]` | Score how well a codebase suits AI coding agents across five dimensions and get a prioritized refactoring plan. |
| `/kramme:code:audit-agent-config` | User, Auto | `[scope-path]` | Audit the repository's agent instructions, skills, hooks, MCP servers, and permissions for redundant, outdated, or conflicting entries. Read-only. |
| `/kramme:code:audit-practice` | User | `[--recent N] [--no-sessions]` | Check how you work with coding agents against 18 common mistakes, from effort and alignment to review and steering, and get the fixes to make first. |
| `/kramme:code:audit-security` | User | `[--output <repo-relative-path>]` | Audit a repository's security posture and attack surfaces before remediation, producing an evidence-ranked report with coverage gaps. |
| `/kramme:code:copy-review` | User, Auto | `[--pr] [--base <branch>] [--threshold 0-100] [--inline] [--all \| <scope-path>]` | Find unnecessary, redundant, or duplicated UI text across the codebase, or in the branch diff when run on a feature branch. |
| `/kramme:deps:audit` | User | `[--auto]` | (experimental) Audit dependencies for outdated packages, vulnerabilities, and staleness, and get a prioritized upgrade plan. |
| `/kramme:test:audit` | User, Auto | `[full \| path <file-or-folder> \| changed [--base <ref>]] [--max-findings N]` | Find low-value, brittle, obsolete, or duplicated tests and get a read-only report of what to remove, repair, or consolidate. |

#### Git

Git history management and commit operations. History rewrites are covered in the [shipping guide](kramme-cc-workflow/docs/shipping.md#rewriting-history).

| Skill | Invocation | Arguments | Description |
| --- | --- | --- | --- |
| `/kramme:git:fixup` | User | `[--skip-tests\|--skip-build\|--skip-lint\|--skip-all] [--no-confirm] [--base=<branch>] [instructions]` | Fold unstaged changes into the commits they belong to on the current branch, validate, and autosquash. |
| `/kramme:git:recreate-commits` | User, Auto | `[--auto] [--coarse\|--granular] [--base <branch>] [--base-commit <oid>] [--backup-ref <branch>] [--after <commit>] [--force-backup] [--require-unstacked] [--no-push] [--authorize-history-rewrite]` | Rewrite unpublished branch history into narrative commits behind a backup ref. Not for merged or shared branches. |

#### Debug

Bug investigation and root cause analysis.

| Skill | Invocation | Arguments | Description |
| --- | --- | --- | --- |
| `/kramme:debug:find-sibling-bugs` | User, Auto | `[--base <branch>] [--intent <text>]` | Use a bug-fix branch as a worked example and search the codebase for other places with the same flaw. |
| `/kramme:debug:investigate` | User | `[bug description, error message, or issue reference] [--auto]` | Investigate a bug step by step: reproduce it, isolate it, trace the root cause, and fix it. |
| `/kramme:debug:triage-to-issue` | User | `[bug description, error message, or Linear/SIW issue ref] [--yes \| --auto]` | (experimental) Turn a bug into an implementation-ready Linear or SIW issue with root-cause evidence and a red-green TDD fix plan. |

#### Browser & QA

Live product inspection and structured testing.

| Skill | Invocation | Arguments | Description |
| --- | --- | --- | --- |
| `/kramme:browse` | User, Auto | `<url\|auto> [--screenshot] [--console] [--network]` | (experimental) Drive a live app through whichever browser MCP is available: navigate, screenshot, interact, and capture evidence. |
| `/kramme:qa` | User, Auto | `<url\|auto> [quick\|diff-aware\|targeted <route>] [--base <branch>] [--regression] [--inline] [--legacy-console]` | Test a running app with smoke, diff-aware, or targeted checks and get `QA_REPORT.md` with screenshots, repro steps, and severity. |
| `/kramme:qa:intake` | User | `[optional starting context]` | Log several bugs from a manual QA pass as Linear or SIW tickets through a light, quick conversation. |

#### Visual

Generate and inspect visual output, including self-contained HTML pages, UI checks, and diagrams.

| Skill | Invocation | Arguments | Description |
| --- | --- | --- | --- |
| `/kramme:visual:check-slop` | User | `<file-or-directory> [--fix]` | Run a deterministic check for AI-style UI patterns in HTML screens; `--fix` applies safe fixes. |
| `/kramme:visual:explain` | User, Auto | `[topic or description \| --onboarding [focus-area or audience]]` | Generate a self-contained HTML page that explains a system, change, plan, or data visually; `--onboarding` builds a codebase guide. |

#### Documentation & Writing

Decision records, specs, solution notes, document review and conversion, and plain-language editing.

| Skill | Invocation | Arguments | Description |
| --- | --- | --- | --- |
| `/kramme:docs:adr` | User | `[decision title]` | Write an Architecture Decision Record for a significant, long-lived decision, following the project's existing ADR format. |
| `/kramme:docs:feature-spec` | User | `[feature name or brief description] [--synthesize\|--auto]` | Write a lightweight PRD-style feature spec before coding, for features that need written alignment but not the full SIW workflow. |
| `/kramme:docs:track-rejected-enhancements` | User | `<record\|check\|append\|reconsider> <concept>` | (experimental) Record rejected enhancement ideas in `.out-of-scope/` and check new requests against them. |
| `/kramme:docs:review` | User | `[markdown-path] [--inline\|--file\|--output <path>]` | Review one Markdown document, such as a plan, proposal, or README draft, and get severity-ordered findings. |
| `/kramme:docs:solution-note` | User | `[problem, lesson, or context] \| --refresh [solution-note-path\|--all] [--apply]` | Record a solved problem in `docs/solutions/` after a fix, migration, or lesson; `--refresh` audits existing notes against the code. |
| `/kramme:docs:sync-release` | User | `[<base>...<ref>\|--base <rev> [--ref <rev>]\|--current] [--apply]` | Compare install, usage, architecture, and contract docs against a release range and report drift; `--apply` fixes it. |
| `/kramme:docs:to-markdown` | User, Auto | — | Convert PDF, Office, HTML, image, audio, and other files to Markdown with MarkItDown. |
| `/kramme:docs:ubiquitous-language` | User | — | Extract a DDD-style glossary of domain terms from the conversation into `UBIQUITOUS_LANGUAGE.md`, flagging ambiguous terms. |
| `/kramme:docs:update-agents-md` | User | — | Add or update guidelines in AGENTS.md, such as a no-compatibility-code policy, in a structured, keyword-based style. |
| `/kramme:text:clarify` | User, Auto | `[--humanize] [file-path or text]` | Rewrite prose so readers can understand and act on it quickly; `--humanize` removes AI-writing patterns instead. |

#### Skill Authoring

Create and review plugin skills.

| Skill | Invocation | Arguments | Description |
| --- | --- | --- | --- |
| `/kramme:skill:create` | User | `[skill-name or description]` | Scaffold a new plugin skill with best-practice structure, frontmatter, and progressive disclosure. |
| `/kramme:skill:review` | User, Auto | `[skill-path \| skill-name \| proposed skill text]` | Review a skill for focused scope, progressive disclosure, portability, safety, and documentation quality. |

#### Workflow & Configuration

Environment checks, verification, artifact cleanup, guided setup scripts, session review, and hook configuration.

| Skill | Invocation | Arguments | Description |
| --- | --- | --- | --- |
| `/kramme:setup` | User, Auto | `[--json\|--help]` | Run a read-only health check of the tools, repository context, plugin version, and workspace this plugin depends on. |
| `/kramme:verify:run` | User, Auto | `[--fast \| --full] [--force] [--base <branch> [--base-commit <oid>]]` | Run the project's tests, linting, formatting, builds, and type checks for affected code; `--fast` runs the quick tier. |
| `/kramme:workflow:cleanup-artifacts` | User, Auto | `[--auto \| --siw]` | Delete disposable workflow artifacts such as review, audit, and QA reports, plans, and diagrams; `--siw` retires the `siw/` workspace. |
| `/kramme:workflow:wizard` | User | `[procedure description or target script path]` | Generate an interactive Bash wizard for manual procedures such as third-party setup, one-off migrations, or CI secrets. |
| `/kramme:hooks:toggle` | User | `<status\|reset\|hook-name> [enable\|disable]` | Enable, disable, list, or reset this plugin's hooks. |
| `/kramme:session:automate-repeats` | User | `[session-paths or --recent N] [--effectiveness] [--create\|--auto]` | Review recent agent sessions for repeated work and friction, and suggest skill improvements or new automation. |

### Background Skills

Auto-triggered by the host based on context. These don't appear in the `/` menu.

| Skill | Invocation | Arguments | Description |
| --- | --- | --- | --- |
| `kramme:git:commit-message` | Background | — | Write commit messages that follow the repository's commit convention, with a pre-commit checklist and AI-attribution rules. |

<!-- END SOURCE-SYNCED SKILL ROWS -->

## Agents

Specialized subagents for PR review and UX audit tasks. Review skills such as `/kramme:pr:code-review` and `/kramme:pr:product-review` invoke them, and you can also call them directly through the Task tool. Code review records completion evidence for every reviewer run; see [Completion Evidence](kramme-cc-workflow/docs/review.md#completion-evidence).

<!-- prettier-ignore-start -->
<!-- BEGIN SOURCE-SYNCED AGENT ROWS -->
| Agent | Description |
| --- | --- |
| `kramme:a11y-auditor` | Audits UI code for WCAG 2.1 AA issues: semantics, ARIA, keyboard and focus handling, screen readers, and contrast. |
| `kramme:architecture-strategist` | Reviews module design: deep modules, use of public interfaces, change locality, and whether new seams have real variation. |
| `kramme:cleanup-reviewer` | Reviews changes for code to delete, replace with existing tools, reuse, or simplify, and checks that removals are safe. |
| `kramme:code-reviewer` | Reviews recent code against project guidelines, CLAUDE.md conventions, and established patterns. |
| `kramme:codebase-pattern-reviewer` | Checks a spec or design for new patterns, dependencies, or abstractions introduced without rationale. |
| `kramme:comment-analyzer` | Reviews code comments for accuracy, necessity, completeness, and long-term maintainability. |
| `kramme:convention-drift-reviewer` | Flags drift from the codebase's established practice and overly defensive code, citing peer-file evidence. |
| `kramme:copy-reviewer` | Flags UI text that merely restates what the interface already communicates. |
| `kramme:design-iterator` | Refines a design over several screenshot-review rounds when it still feels off. |
| `kramme:deslop-reviewer` | Detects AI-generated slop in code changes, or in review suggestions that would introduce it. |
| `kramme:overengineering-reviewer` | Asks whether a change is overdone, needlessly complex, or hedging against unlikely edge cases, then defends or confirms each finding. |
| `kramme:performance-oracle` | Reviews code for performance and scalability risks: complexity, queries, memory, caching, and contention. |
| `kramme:pr-relevance-validator` | Filters review findings down to those the current changes caused, dropping pre-existing issues. |
| `kramme:pr-test-analyzer` | Reviews a PR's test coverage for untested behavior, edge cases, and regressions. |
| `kramme:product-reviewer` | Reviews PRs, specs, or live flows from a product perspective: discoverability, flows, edge cases, copy, and fit. |
| `kramme:security-reviewer` | Reviews changes for exploitable flaws: injection, authentication and access control, secrets and crypto, and business-logic bugs. |
| `kramme:silent-failure-hunter` | Finds swallowed errors, weak error propagation, and misleading fallbacks. |
| `kramme:type-design-analyzer` | Reviews new or changed types for encapsulation, invariants, usefulness, and enforcement. |
| `kramme:ux-reviewer` | Reviews changes for usability with Nielsen's heuristics: missing states, confusing flows, poor feedback, and weak recovery. |
| `kramme:visual-reviewer` | Reviews visual consistency and responsive behavior: design tokens, spacing, typography, color, and breakpoints. |
<!-- END SOURCE-SYNCED AGENT ROWS -->
<!-- prettier-ignore-end -->

## Hooks

Event handlers defined once in the plugin source and packaged for both hosts. Each host maps them to its own lifecycle events. Toggle them with `/kramme:hooks:toggle`; [docs/hooks.md](kramme-cc-workflow/docs/hooks.md) covers configuration, pattern lists, and formatter tables.

<!-- prettier-ignore-start -->
<!-- BEGIN SOURCE-SYNCED HOOK ROWS -->
| Hook | Event | Description |
| --- | --- | --- |
| `block-rm-rf` | PreToolUse (Bash) | Blocks destructive file deletion commands and recommends `trash` instead. |
| `confirm-review-responses` | PreToolUse (Bash) | Confirms before committing review artifact files. |
| `skill-usage-stats` | PreToolUse (Skill), UserPromptSubmit | Records local skill usage statistics. |
| `auto-format` | PostToolUse (Write\|Edit) | Auto-formats code after file modifications using detected project formatter. |
| `update-check` | SessionStart (startup) | Checks GitHub at most once a day and shows a notice when a newer plugin version is available, then names the new version once after an update. |
<!-- END SOURCE-SYNCED HOOK ROWS -->
<!-- prettier-ignore-end -->

## Renamed and Removed Commands

Update saved prompts and automation before upgrading; the old names no longer resolve. [CHANGELOG.md](kramme-cc-workflow/CHANGELOG.md) has the release-by-release detail.

### Renamed

| Old → new | What to change |
| --- | --- |
| `/kramme:siw:spec-audit:auto-fix` and `/kramme:siw:apply-spec-audit-fixes` → `/kramme:siw:spec-audit --apply <report>` | Pass the report path after `--apply`; `--auto`, `--dry-run`, `--threshold 60-100`, and `--allow-dirty` still work. `--apply` without a path audits first, then fixes the new report. `--dry-run` needs an existing report (`--apply <report> --dry-run`); audit-first dry runs are rejected before auditing or writing files. For a read-only audit, use `--inline` without `--apply`. |
| `/kramme:docs:out-of-scope` → `/kramme:docs:track-rejected-enhancements` | Nothing; arguments and behavior are unchanged. |
| `/kramme:code:cleanup-ai` → `/kramme:code:refactor-pass` | The replacement does not preserve the old arguments or side effects. Remove `--auto`; omit arguments to use the canonical branch review scope, or pass file and directory scope tokens instead of a base branch. When cleanup candidates exist, it verifies and checkpoints scoped uncommitted input, then verifies and commits each simplification separately. |
| `/kramme:pr:ux-review` → `/kramme:pr:product-review` | Arguments are unchanged. It also runs the product reviewer over every changed file by default (`--categories product` gives the former product-only review) and writes `PRODUCT_REVIEW_OVERVIEW.md` with `PROD-NNN` finding IDs. It no longer reads, cleans up, or guards `UX_REVIEW_OVERVIEW.md`, so delete leftover copies by hand. |
| `/kramme:siw:discovery` → `/kramme:discovery:interview --siw` | Pass `--siw` (or a bare `siw`, or `siw/` paths); plain topic text no longer starts an SIW run. `--apply` now works only on a direct user request and confirms the edits in-session. |
| `/kramme:siw:remove` → `/kramme:workflow:cleanup-artifacts --siw` | Keeps the SIW-only scope, the transfer-to-Linear-first warning, and the temporary-only, all-SIW, or abort confirmation. It cannot be combined with `--auto`, skips directories instead of force-deleting them when `trash` is missing, and skips `siw/issues/` or `siw/qa-intake/` when they hold unexpected files. |
| `/kramme:pr:verify-description` → `/kramme:pr:generate-description --check` | Keeps `--base`, `--strict`, the drift rubric, and the report shape; the report heading is now `PR Description Check`. `--strict` also reports two clarity Suggestions: an opening that doesn't say what changes, and an untestable behavior change or risk without a Test plan scenario. Remove `--fix`: after Important or Critical drift, `--check` asks once (y/N) before regenerating and updating the PR; add `--no-update` for a report with no prompt. |
| `/kramme:siw:product-audit` → `/kramme:siw:spec-audit --product` | Keeps `--auto` and `--inline` and adds the readiness dimensions. Product findings keep `PROD-NNN` IDs but are written to `AUDIT_SPEC_REPORT.md` alongside `SPEC-NNN` findings, are never auto-fixed by `--apply`, and resolve through `/kramme:siw:resolve-audit`. No skill reads or commit-guards `PRODUCT_AUDIT.md` anymore; SIW spec detection still ignores it, and `/kramme:workflow:cleanup-artifacts` removes leftover copies. |
| `/kramme:visual:diagram` → `/kramme:visual:explain` | Nothing; the topic argument, behavior, and `~/.kramme-cc-workflow/diagrams/` output directory are unchanged. |
| `/kramme:visual:onboarding` → `/kramme:visual:explain --onboarding` | Nothing; the focus-area or audience argument, behavior, and `onboarding-{project-name}.html` output are unchanged. |
| `/kramme:docs:solution-refresh` → `/kramme:docs:solution-note --refresh` | The note-path and `--all` targets and `--apply` now follow `--refresh`; deletion and consolidation still ask first. |
| `/kramme:code:weakness-audit` → `/kramme:code:refactor-opportunities --ranked` | Add `--ranked` and drop `--team`. The `full`, `path`, and `feature` scopes, `--output`, `--max-findings`, `--solo`, and `--base` are kept, and it still writes `CODEBASE_WEAKNESS_REPORT.md` with `WA-NNN` IDs. Ranked mode is user-only, so a model or another skill never starts it; automation must ask the user to run it. |
| `/kramme:text:humanize` → `/kramme:text:clarify --humanize` | Takes one file or one text block per run, and treats a single-line argument that merely contains a slash, such as `Fixed in src/api/orders.ts`, as text. The pattern catalog, opt-in voice pass, and confirm-before-write flow are kept. `/kramme:pr:github-review` keeps its humanize pass, and `/kramme:pr:github-review-reply` now humanizes drafted replies only with `--humanize`. |
| `/kramme:pr:plan-split` → `/kramme:code:breakdown-findings --split` | Keeps `--base <branch>`, `--auto`, the seam strategies, and the SPLIT or KEEP AS ONE decision. It now writes the `PR_PLAN_*.md` set itself instead of printing a handoff. Split plans still carry the worktree Implementation Setup; implement them by hand, then reconcile with `--reconcile`. |
| `/kramme:pr:update-split-plans` → `/kramme:code:breakdown-findings --reconcile` | Pass the same plan paths, `--all`, `--worktree`, `--source`, `--base`, and `--auto` options. Former no-scope calls must add `--all` to preserve the removed command's active-plan-only default; zero-scope reconcile intentionally retains `kramme:code:breakdown-findings`'s existing all-indexed behavior. |
| `/kramme:workflow-artifacts:cleanup` → `/kramme:workflow:cleanup-artifacts` | Nothing; every argument, mode, and safety gate is unchanged. |
| `/kramme:linear:select-next` → `/kramme:linear:next` | Pass `--agent-ready` instead of `--agent-ready-only`; other arguments and behavior are unchanged. |

### Removed

| Removed | Use instead |
| --- | --- |
| `/kramme:siw:issue-define` | Before transfer, update the spec and run `/kramme:siw:generate-phases`, choosing Append when issues exist. For a standalone issue or after transfer, use `/kramme:linear:issue-define`. Existing local issue files stay valid; edit them directly and keep `siw/OPEN_ISSUES_OVERVIEW.md` and `siw/LOG.md` in sync. |
| `/kramme:ci:design-pipeline` | Ask directly for CI/CD pipeline design or gate planning. `/kramme:pr:fix-ci` still handles failures in an existing Pull Request pipeline. |
| `/kramme:product:pulse` | Ask directly for a time-windowed product health recap. `/kramme:product:strategy`, `/kramme:product:review`, and `/kramme:siw:spec-audit --product` still read existing reports under `docs/pulse-reports/`, but nothing generates them anymore. |
| `/kramme:code:incremental` | Use ordinary implementation requests for small verified slices and `/kramme:code:refactor-pass` for narrow behavior-preserving cleanup. For structural refactors, survey candidates with `/kramme:code:refactor-opportunities`, then ask for planning and implementation directly. No replacement keeps the interview-driven Decision Document and tiny-commit workflow. |
| `/kramme:code:source-driven` | Use `/kramme:code:migrate` for version migrations, `/kramme:research` for cited research artifacts, and the host's source tools to verify unstable third-party facts during implementation. |
| `/kramme:test:generate` | Ask directly for tests that follow the project's existing conventions, and use `/kramme:test:audit` to assess an existing suite. |
| `/kramme:git:worktree` and `/kramme:git:clean-gone-branches` | Use Conductor workspace management, or run `git worktree` and `git branch` directly. Their helper scripts are gone too, and no replacement keeps their Conductor-path guards or confirmation-gated branch deletion. |
| `/kramme:visual:plan-review` and `/kramme:visual:project-recap` | Use `/kramme:pr:walkthrough --report` to explain a branch or Pull Request, `/kramme:visual:explain` to visualize a plan or architecture, and `/kramme:visual:explain --onboarding` for a codebase overview. |
| `/kramme:visual:generate-image` | Use the image tools in your host. The Gemini image-generation script and its API-key setup are no longer bundled. |
| `/kramme:visual:demo-reel` | `/kramme:pr:generate-description` no longer accepts `--visual`, and `/kramme:pr:create` no longer captures or attaches screenshots or video; both leave a Screenshots/Videos placeholder on changes with visible UI. Ask directly for a screenshot or recording, or use `/kramme:browse` or `/kramme:qa`. No replacement keeps tiered capture, the secret preflight, or bounded environment startup. Earlier captures under `.context/demo-reels/` remain eligible for `/kramme:workflow:cleanup-artifacts`. |
| `/kramme:session:context-setup` | `/kramme:code:work-from-plan`, `/kramme:code:plan-to-pr`, and `/kramme:linear:issue-implement` keep a shared preparation checklist with focused context loading, and a shared forward-progress reference covers context recovery. Ask directly for rules-file updates; the setup ritual, markers, and mandatory repair gate are retired. |
| `/kramme:nx:setup-portless` and the `nx` skill domain | Ask directly for portless setup or Nx `dev:local`/`dev:full` target wiring. No replacement keeps its target templates or certificate-trust steps. |

## Documentation

Guides in this repository:

- [Review Workflows](kramme-cc-workflow/docs/review.md) — reviewer models, review convergence, stacked PRs, GitHub review rules, and resuming runs
- [Implementing and Shipping](kramme-cc-workflow/docs/shipping.md) — base-branch selection, Linear issue and plan to PR, PR creation, and history rewrites
- [SIW Workflow Reference](kramme-cc-workflow/docs/siw.md)
- [Hook Reference](kramme-cc-workflow/docs/hooks.md)
- [Recommended MCP Servers](kramme-cc-workflow/docs/mcp-servers.md)
- [Agent Autonomy Model](kramme-cc-workflow/docs/agent-autonomy.md)
- [Agent Portability Matrix](kramme-cc-workflow/docs/agent-portability.md)
- [Repository Architecture](kramme-cc-workflow/docs/architecture.md)
- [Repository Code Map](kramme-cc-workflow/docs/code-map.md)
- [Development Guide](kramme-cc-workflow/docs/development.md)
- [Decision Index](kramme-cc-workflow/docs/decisions/README.md)
- [Component Catalog](kramme-cc-workflow/docs/component-catalog.json) (generated compact index of skills, agents, and hooks)

Host documentation:

- Claude Code: [Plugin Documentation](https://code.claude.com/docs/en/plugins), [Plugins Reference](https://code.claude.com/docs/en/plugins-reference), [Hooks Reference](https://code.claude.com/docs/en/hooks), and [Skills Documentation](https://code.claude.com/docs/en/skills)
- Codex: [Plugins](https://developers.openai.com/codex/plugins), [CLI Reference](https://developers.openai.com/codex/cli), and [Skills](https://developers.openai.com/codex/skills)

## Related Plugins

| Plugin | Description |
| --- | --- |
| [Agent Skills for Context Engineering](https://github.com/muratcankoylan/Agent-Skills-for-Context-Engineering) | Agent Skills focused on context engineering principles for building production-grade AI agent systems. |
| [adversarial-spec](https://github.com/zscole/adversarial-spec) | Specification refinement through multi-model debate until consensus is reached. |

## Releases

See [CHANGELOG.md](kramme-cc-workflow/CHANGELOG.md) for version history and [GitHub Releases](https://github.com/Abildtoft/kramme-cc-workflow/releases) for release notes.

For maintainers: see [RELEASE.md](kramme-cc-workflow/RELEASE.md) for the release process.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for the contributor and agent workflow, including source maps, verification commands, and documentation expectations. For repository work, start there, then use [docs/architecture.md](kramme-cc-workflow/docs/architecture.md) and [docs/code-map.md](kramme-cc-workflow/docs/code-map.md) to find the relevant subsystem and tests.

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

[CONTRIBUTING.md](CONTRIBUTING.md) covers local setup, and the [development guide](kramme-cc-workflow/docs/development.md) has the complete test-target catalog, coverage baselines, pre-PR verification, skill security scans, and the SkillOpt eval pilot. The short version:

```bash
# Read-only prerequisite check
bash kramme-cc-workflow/scripts/bootstrap-dev.sh --check

# Explicit macOS, Debian 12+, or Ubuntu 22.04+ setup
bash kramme-cc-workflow/scripts/bootstrap-dev.sh --install

# Closest focused test for a documentation change
make -C kramme-cc-workflow test-bats-file BATS_TEST_FILE=tests/repository-instructions.bats

# Representative cross-language feedback
make -C kramme-cc-workflow test-smoke

# Complete default suite (Node + Python + Bats)
make -C kramme-cc-workflow test

# Ordinary Pull Request gate
make -C kramme-cc-workflow pr-verify

# Stronger release-candidate gate
make -C kramme-cc-workflow verify
```

Skill changes also need a separate SkillSpector installation for the changed-skill security gate. [CONTRIBUTING.md](CONTRIBUTING.md#optional-pre-commit-check) describes the optional managed pre-commit hook, and the [skill-review eval guide](kramme-cc-workflow/evals/skill-review/README.md#live-provider-adapters) covers the optional live evals that spend Anthropic or OpenAI API credits.

## Plugin Structure

The shared plugin source lives in `kramme-cc-workflow/`; this root README is the canonical entry point for both Claude Code and Codex. Claude Code source files are canonical, and Codex output is generated from them at build time.

```
.
├── .claude-plugin/
│   └── marketplace.json     # Root marketplace definition
├── kramme-cc-workflow/
│   ├── .claude-plugin/
│   │   └── plugin.json      # Plugin metadata
│   ├── agents/              # Specialized subagents
│   ├── skills/              # Skills (subdirectories with SKILL.md)
│   ├── shared/              # References and assets used by more than one skill
│   ├── hooks/               # Event handlers
│   │   └── hooks.json
│   ├── docs/                # Usage guides and reference docs
│   │   └── component-catalog.json  # Generated compact component index
│   └── README.md            # Pointer to this root README
├── .agents/skills/          # Local repository-maintenance skills
└── README.md                # Canonical entry point
```

The source tree above feeds both host packages. Claude Code reads the plugin metadata, skills, agents, and hooks directly; the converter packages the same behavior as the native Codex plugin described in [the portability matrix](kramme-cc-workflow/docs/agent-portability.md).

## Adding Components

See [AGENTS.md](AGENTS.md) for detailed conventions. Quick reference:

- **Agents**: Create markdown files in `kramme-cc-workflow/agents/` with `name`, `description`, `model`, and `color` frontmatter.
- **Skills**: Create a subdirectory in `kramme-cc-workflow/skills/` with a `SKILL.md` file. Key frontmatter: `name`, `description`, `disable-model-invocation`, `user-invocable`, `kramme-platforms`.
- **Hooks**: Edit `kramme-cc-workflow/hooks/hooks.json` to add event handlers. Available events: `PreToolUse`, `PostToolUse`, `UserPromptSubmit`, `SessionStart`, `Stop`.
- **README summaries**: Give each new skill or agent a one-line summary of at most 160 characters under `summaries` in `readme_skill_sync` or `readme_agent_sync` in [synced-contracts.yaml](kramme-cc-workflow/scripts/synced-contracts.yaml). Hooks use `readme_hook_sync.descriptions`.
- **External sources**: Record every adapted source in the skill's `references/sources.yaml` as `usage: inspiration` or `usage: copied`, following [External Sources and Rights](AGENTS.md#external-sources-and-rights). Use `/kramme:skill:create` and `/kramme:skill:review` for the detailed checks.

The skill, agent, and hook table rows in this README and the compact [component catalog](kramme-cc-workflow/docs/component-catalog.json) are generated from component source metadata and the README summaries. Run `python3 kramme-cc-workflow/scripts/generate-component-reference.py --write` to refresh both, or `python3 kramme-cc-workflow/scripts/generate-component-reference.py --check` to validate without writing. `make -C kramme-cc-workflow skill-contracts` fails on drift and warns on README paragraphs of 500 characters or more.

## Local Repository Maintenance

This workspace also includes local maintenance skills under `.agents/skills/`, exposed to Claude Code through the `.claude/skills` symlink. These are for maintaining this repository and are not shipped as part of the public plugin.

| Skill | Description |
| --- | --- |
| `/kramme:skill:audit-sources` | Audits one or more skills against declared inspiration sources, bootstraps missing `references/sources.yaml` manifests, compares normalized source hashes without retaining fetched source bodies, and writes `.context/skill-source-audit-<timestamp>.md` reports. |

Run `/kramme:skill:audit-sources` monthly and again before each quarterly catalog review. The audit stays manual because fetching upstream content and trusting its contents are deliberate decisions.

A reported upstream change is a prompt to review a skill, never permission to change it. Fold suggestions into a `SKILL.md` only after human review, and refresh a `baseline_hash` only from a fetch that returned the real source rather than a redirect, login, or error page.

## Attribution

This plugin is shaped by work shared across the agent-tooling community. The sections below credit the projects, practitioners, standards, and official documentation behind specific skills, workflows, and conventions.

Copied prose, scripts, templates, and substantial assets must be permitted by a verified upstream license and ship with its complete required notice, not only an attribution in this README. Adapted workflows should record their source in the skill's `references/sources.yaml`, rewrite the workflow in this plugin's style, and avoid direct ports of long monolithic skill bodies. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for retained third-party material and its skill-local notices.

### From [addyosmani/agent-skills](https://github.com/addyosmani/agent-skills)

- `kramme:code:work-from-plan`, `kramme:code:plan-to-pr`, and `kramme:linear:issue-implement` context preparation, plus the shared forward-progress reference's context recovery: Adapted from [context-engineering](https://github.com/addyosmani/agent-skills/tree/main/skills/context-engineering).
- `kramme:docs:feature-spec`: Adapted from [spec-driven-development](https://github.com/addyosmani/agent-skills/tree/main/skills/spec-driven-development).
- `kramme:docs:adr`: Adapted from [documentation-and-adrs](https://github.com/addyosmani/agent-skills/tree/main/skills/documentation-and-adrs).
- `kramme:code:deprecate`: Adapted from [deprecation-and-migration](https://github.com/addyosmani/agent-skills/tree/main/skills/deprecation-and-migration).
- `kramme:debug:triage-to-issue` Prove-It regression-test conventions: Adapted from [test-driven-development](https://github.com/addyosmani/agent-skills/tree/main/skills/test-driven-development).
- `kramme:debug:investigate` and `kramme:debug:triage-to-issue` shared root-cause procedure (reproduce, isolate, trace, and bisect guidance): Adapted from [debugging-and-error-recovery](https://github.com/addyosmani/agent-skills/tree/main/skills/debugging-and-error-recovery).
- `kramme:browse` security boundaries, JavaScript constraints, content boundary markers, and Addy marker conventions: adapted from [browser-testing-with-devtools](https://github.com/addyosmani/agent-skills/tree/main/skills/browser-testing-with-devtools).
- `kramme:qa` network triage ladder, clean-console standard, accessibility ladder, and Addy marker conventions: adapted from [browser-testing-with-devtools](https://github.com/addyosmani/agent-skills/tree/main/skills/browser-testing-with-devtools).
- `kramme:git:commit-message`, `kramme:pr:generate-description`, `kramme:git:recreate-commits`, `kramme:pr:rebase`: Addy output markers, the Change Summary triplet (`CHANGES MADE / THINGS I DIDN'T TOUCH / POTENTIAL CONCERNS`) in `kramme:git:recreate-commits`, 6-item pre-commit checklist, and "dev branches are costs" framing adapted from [git-workflow-and-versioning](https://github.com/addyosmani/agent-skills/tree/main/skills/git-workflow-and-versioning). Addy's per-commit Conventional Commits rule is explicitly rejected.

### From [EveryInc/compound-engineering-plugin](https://github.com/EveryInc/compound-engineering-plugin)

- `kramme:architecture-strategist`, `kramme:design-iterator`, and `kramme:performance-oracle`: Adapted from the plugin's review agents.
- `kramme:product:strategy`: Adapted from skill `ce-strategy`.
- `kramme:code:optimize`: Adapted from [ce-optimize](https://github.com/EveryInc/compound-engineering-plugin/tree/6f9ab03a031c054a8046659926251fb6c149269f/plugins/compound-engineering/skills/ce-optimize), reviewed at commit `6f9ab03a031c054a8046659926251fb6c149269f`.
- `kramme:session:automate-repeats`: Adapted from skill `ce-sessions`, including its safe session discovery and extraction scripts reviewed at commit `6f9ab03a031c054a8046659926251fb6c149269f`.
- `kramme:setup`: Adapted from skill `ce-setup`, reviewed at commit `6f9ab03a031c054a8046659926251fb6c149269f`.
- `kramme:docs:solution-note` (including `--refresh`): Adapted from skills `ce-compound` and `ce-compound-refresh`, reviewed at commit `6f9ab03a031c054a8046659926251fb6c149269f`.
- `kramme:docs:review`: Adapted from [ce-doc-review](https://github.com/EveryInc/compound-engineering-plugin/tree/main/plugins/compound-engineering/skills/ce-doc-review).
- `kramme:code:work-from-plan`: Adapted from [ce-work](https://github.com/EveryInc/compound-engineering-plugin/tree/main/plugins/compound-engineering/skills/ce-work) and [ce-plan](https://github.com/EveryInc/compound-engineering-plugin/tree/main/plugins/compound-engineering/skills/ce-plan) as a thin routing adapter, not a full autonomous execution pipeline.
- Codex converter: Inspired by the plugin's converter approach.
- External-source adaptation policy, copied-script attribution guardrails, and artifact-lifecycle prompts: Informed by [the repository at commit `6f9ab03a031c054a8046659926251fb6c149269f`](https://github.com/EveryInc/compound-engineering-plugin/tree/6f9ab03a031c054a8046659926251fb6c149269f), including representative skills `ce-compound`, `ce-compound-refresh`, `ce-plan`, `ce-code-review`, and `ce-optimize`.
- Shared dev-server detection scripts and browser-facing auto URL detection contract: Adapted from [ce-polish](https://github.com/EveryInc/compound-engineering-plugin/tree/6f9ab03a031c054a8046659926251fb6c149269f/plugins/compound-engineering/skills/ce-polish), reviewed at commit `6f9ab03a031c054a8046659926251fb6c149269f`.

### Other sources

- `kramme:verify:run` evidence-before-claims rule and red-green check: Inspired by [obra/superpowers](https://github.com/obra/superpowers)' verification-before-completion skill.
- `kramme:debug:triage-to-issue`: The hands-off bug-to-issue workflow is adapted from Matt Pocock's [triage-issue](https://github.com/mattpocock/skills/tree/383b6a06d59c4ce0ffcb14112bfd91265a86cf91/skills/triage-issue), while its vertical RED-GREEN cycle guidance is adapted from Pocock's [TDD skill](https://github.com/mattpocock/skills/tree/main/skills/engineering/tdd).
- Module-depth guidance in `kramme:code:agent-readiness`, `kramme:code:refactor-opportunities`, `kramme:code:api-design`, `kramme:pr:code-review` with `kramme:architecture-strategist`, `kramme:pr:triage-risk`, and the spec, issue, and plan templates: Informed by AI Hero's [How To Make Codebases AI Agents Love](https://www.aihero.dev/how-to-make-codebases-ai-agents-love). The shared architecture glossary adapts the vocabulary of Matt Pocock's [codebase-design skill](https://github.com/mattpocock/skills/tree/main/skills/engineering/codebase-design).
- `kramme:code:refactor-opportunities` hot-spot seeding, deepening patterns, planned-change mode (`--for`), and one-item hand-off: Informed by Matt Pocock's [improve-codebase-architecture skill](https://github.com/mattpocock/skills/tree/main/skills/engineering/improve-codebase-architecture) and AI Hero's [guide to it](https://www.aihero.dev/skills-improve-codebase-architecture).
- Name-collision guidance in the shared implementation context checklist that `kramme:linear:issue-implement`, `kramme:code:work-from-plan`, and `kramme:code:plan-to-pr` apply, and the search-uniqueness checks in `kramme:code:agent-readiness`: Informed by Modem's [How AI coding agents read your code](https://modem.ai/blog/how-coding-agents-read-your-code).
- `kramme:code:audit-practice`: The eighteen mistakes it checks for are adapted from Matt Pocock's [post on agentic coding mistakes](https://x.com/mattpocockuk/status/2109973273924579720), with terms read through AI Hero's [AI Coding Dictionary](https://www.aicodingdictionary.com/).
- `kramme:code:encode-constraint`: Inspired by [@poteto's X post](https://x.com/poteto/status/2109699980248408574) on treating the codebase as agent memory and turning each observed agent mistake into a constraint.
- `kramme:product:prd`: The PRD written after prototyping as a decision record, with its behavior contract, golden-set evals, rollout gates, kill switch, and change log, is adapted from Aakash Gupta's [post on an AI-era PRD template](https://x.com/aakashgupta/status/2112951808050245874).
- `kramme:docs:update-agents-md`: Inspired by [getsentry/skills](https://github.com/getsentry/skills/blob/main/plugins/sentry-skills/skills/agents-md/SKILL.md).
- `kramme:git:commit-message`: From [getsentry/skills](https://github.com/getsentry/skills/blob/main/plugins/sentry-skills/skills/commit/SKILL.md).
- `kramme:text:clarify` and the shared plain-language rubric that `kramme:pr:generate-description` also applies: Inspired by [fofr's GOV.UK style skill](https://gist.github.com/fofr/505e225f9bf5e839d30c12ba6bfa0be2) and official GOV.UK guidance on [identifying user needs](https://guidance.publishing.service.gov.uk/writing-to-gov-uk-standards/plan-manage-content/identify-user-needs/) and [using clear language](https://guidance.publishing.service.gov.uk/writing-to-gov-uk-standards/writing-guidelines/clear-language/), adapted into a locale-neutral reader-task workflow.
- `kramme:text:clarify --humanize`: Based on Wikipedia: Signs of AI writing (maintained by WikiProject AI Cleanup) and heavily inspired by [blader/humanizer](https://github.com/blader/humanizer).
- `kramme:visual:explain`, including its `--onboarding` mode: Adapted from [nicobailon/visual-explainer](https://github.com/nicobailon/visual-explainer).
- `kramme:visual:check-slop`: Vendors and adapts Gesso Build's MIT-licensed anti-slop detector and 73-rule registry at commit [`1c3908b7efb56ec24624436dea5c32a371eb487c`](https://github.com/Gesso-Build/skills/tree/1c3908b7efb56ec24624436dea5c32a371eb487c). Complete notices for Gesso and bundled parser dependencies ship with the skill.
- Skills authoring patterns: Inspired by [mgechev/skills-best-practices](https://github.com/mgechev/skills-best-practices).
- `kramme:session:automate-repeats` effectiveness evidence, counterfactual improvement gate, and explicit skill-use extraction: Inspired by Warp's [skill-doctor workflow, rubrics, guidance, and collector at commit `737129f`](https://github.com/warpdotdev/common-skills/tree/737129fae58e1feb4ec956c0f0bfa597b5c6ee89/.agents/skills/skill-doctor).
- `kramme:pr:github-review-reply`: GitHub review comment listing, review-summary reads, top-level PR comment reads/posts, reply posting, review thread mapping, and thread resolution operations are grounded in official GitHub REST and GraphQL API documentation.
- `kramme:pr:github-review`: review-requested PR discovery, PR-context reads, `pull/<N>/head` fetch, existing-conversation mapping (REST review comments, GraphQL review threads, issue comments, prior reviews), and the optional review-submission/reply appendix are grounded in the GitHub CLI manual and official GitHub REST/GraphQL/search documentation.

## License

MIT
