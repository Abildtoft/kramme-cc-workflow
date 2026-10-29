---
name: kramme:code:audit-practice
description: "Audits agentic coding practice against eighteen common mistakes, from effort level, skill length, and alignment to review balance, self-verification, babysitting, global steering files, codebase navigation, and strategic thinking. Gathers repository, agent-config, and recent-session evidence and replies inline with the fixes to make first. Read-only. Not for per-entry config audits (kramme:code:audit-agent-config) or agent-readiness scores (kramme:code:agent-readiness)."
argument-hint: "[--recent N] [--no-sessions]"
disable-model-invocation: true
user-invocable: true
permissions:
  - shell
  - file_read
  - env
---

# Audit Agentic Coding Practice

Find which of eighteen common agentic-coding mistakes show up in how the user works with coding agents, and name the few changes worth making first. Evidence comes from the repository, the user's agent configuration, and this repository's recent sessions.

## Contract

- **Read-only.** Never edit, create, or delete files, settings, memory, or Git state, and never run the project's tests, builds, or installs. The report is the whole output; applying a fix is a separate request.
- **Authorized reads.** Invoking this skill authorizes reading the repository, the user-level agent configuration listed in Step 2, and, unless `--no-sessions` is passed, this repository's recent session transcripts through `scripts/session-signals.py`, which prints counts only. Read nothing else outside the repository.
- **Privacy.** Never open a transcript directly. From settings files, report only key names, counts, and effort, model, and permission values; never print `env` values, tokens, credentials, or MCP server commands and arguments. Name files and counts, and quote at most a short fragment of the user's own steering rules.
- **Proportionate cost.** Run in one pass in this session without subagents. Prefer listing, counting, and search commands; read a whole file only when its contents are the evidence. This is a survey: the skills named in the rubric own the deep dives.
- **Evidence first.** Every LIKELY or POSSIBLE verdict cites evidence a reader can check. A mistake with no evidence source is UNOBSERVABLE, never CLEAR.

## Step 1: Parse Arguments

- No arguments: sessions from the last 30 days, at most 30 (`--days 30 --limit 30`).
- `--recent N`: the N most recent sessions from the last year (`--days 365 --limit N`), where N is an integer from 1 to 100.
- `--no-sessions`: skip session evidence; mistakes that only sessions reveal become UNOBSERVABLE.

Reject any other argument, a missing or invalid N, and `--recent` combined with `--no-sessions`: print `Usage: /kramme:code:audit-practice [--recent N] [--no-sessions]` and stop.

Run from the repository root (`git rev-parse --show-toplevel`). Outside a Git repository, use the current directory as the root and record the missing history as an audit gap.

## Step 2: Gather Evidence

Announce the scope in one line, then collect the evidence below. Record a missing file as absent, never as proof of a healthy practice.

### Repository

| Mistakes | Look at |
| --- | --- |
| 2 | `SKILL.md` files under `.claude/skills/`, `.agents/skills/`, and any plugin `skills/` directory: line counts, description lengths, and how many are model-invocable |
| 4, 9, 13, 14 | `AGENTS.md` and `CLAUDE.md` (root, nested, and `@` imports), `.github/copilot-instructions.md`, `.cursor/rules/`: size, pointers to deeper docs, and rules that demand confirmation or a human read of every change |
| 5, 7 | CI configuration (`.github/workflows/`, `.gitlab-ci.yml`, `.circleci/`, `azure-pipelines.yml`, `Jenkinsfile`), hook managers (`.husky/`, `.pre-commit-config.yaml`, `lefthook.yml`), and type-checker and linter settings: which checks block merges, `continue-on-error` or `\|\| true`, strictness, and AI review jobs |
| 11 | Test, lint, type-check, and build commands in `package.json`, `Makefile`, `pyproject.toml`, `justfile`, or similar; whether steering names them; browser automation for UI code |
| 14 | Top-level layout, code maps or architecture docs, and the ten largest tracked source files (`git ls-files` with `wc -l`) |
| 15 | Glossary or domain-language docs (`UBIQUITOUS_LANGUAGE.md`, `GLOSSARY.md`, `CONTEXT.md`, `docs/*glossary*`) and ADR directories |
| 16 | About ten test files sampled across test roots: mocks of first-party modules, imports of internal paths, and assertions on call order or private state |
| 8, 10, 17 | `git log --oneline -50` subjects and `git branch -a` names (prototype, spike, and fix patterns); strategy or roadmap docs; learning notes such as `docs/solutions/`, memory, or retros, with their last change date (`git log -1 --format=%cs -- <path>`) |

### Agent Configuration

Resolve the Claude Code home from `CLAUDE_CONFIG_DIR` (default `~/.claude`) and the Codex home from `CODEX_HOME` (default `~/.codex`). Read only these files:

| Source | Files | Extract |
| --- | --- | --- |
| Claude Code, user level | `CLAUDE.md` and every file it imports with `@path`, `settings.json`, `skills/*/SKILL.md` | Steering lines and words including imports; `effortLevel`, `model`, `permissions.defaultMode`, the size of `permissions.allow`, hook and enabled-plugin counts; skill line counts |
| Codex, user level | `AGENTS.md`, `config.toml` | Steering lines and words; `model_reasoning_effort`, `plan_mode_reasoning_effort`, `approval_policy`, `sandbox_mode`, and the number of `[mcp_servers.*]` tables |
| Project | `.claude/settings.json`, `.claude/settings.local.json`, `.mcp.json`, `.codex/config.toml` | The same keys, and the number of MCP servers |

### Sessions

Skip this subsection with `--no-sessions`.

1. Collect session prefixes: the repository root and every `worktree` path from `git worktree list --porcelain`. When the root matches `*/conductor/workspaces/<repo>/<workspace>`, use `*/conductor/workspaces/<repo>` instead, so sessions from archived Conductor workspaces of the same repository count.
2. Run the extractor with one `--cwd-prefix` per prefix and the window from Step 1:

   ```bash
   python3 "${CLAUDE_PLUGIN_ROOT}/skills/kramme:code:audit-practice/scripts/session-signals.py" \
     --cwd-prefix "<prefix>" --days <days> --limit <limit>
   ```

3. Use only the JSON it prints. If the script fails or analyzes zero sessions, record an audit gap and continue; mistakes that only sessions reveal become UNOBSERVABLE.

## Step 3: Judge Each Mistake

Read the rubric from `references/mistakes.md` now. If it cannot be read, stop and report the missing path; never judge from memory.

Give each of the eighteen mistakes one verdict:

- **LIKELY:** the evidence meets the rubric's LIKELY signal.
- **POSSIBLE:** the evidence is partial or mixed, or session-only evidence comes from fewer than five sessions.
- **CLEAR:** the evidence meets the rubric's CLEAR signal.
- **UNOBSERVABLE:** no evidence source exists; the rubric's self-check question goes to the user instead.

Treat rubric thresholds as defaults, and state the reason in the evidence cell when departing from one. Apply the rubric's pairing rules before recommending a change. Describe settings, files, and patterns, not the person.

## Step 4: Report

Reply inline; do not write a report file.

```markdown
# Agentic Practice Audit

Scope: {repository} · Config: {files read, or none found} · Sessions: {N} ({platforms}, {first date} to {last date}), skipped (--no-sessions), or none found

Verdicts: LIKELY {n} · POSSIBLE {n} · CLEAR {n} · UNOBSERVABLE {n}

## Fix First

1. **{Mistake}:** {evidence}. **Change:** {one concrete change}. **Then:** {next skill or setting, if any}

## All Checks

| #   | Mistake             | Verdict   | Evidence       |
| --- | ------------------- | --------- | -------------- |
| 1   | Effort set too high | {verdict} | {one sentence} |

## Self-Check

- {the rubric's question for each UNOBSERVABLE mistake}

## Audit Gaps

- {unreadable files, failed or empty session extraction, missing history}

No files were changed.
```

Fill `Fix First` with up to three LIKELY mistakes, topping up with POSSIBLE ones when fewer than three are LIKELY. Order them by:

1. **Reach:** costs paid in every session (effort, global steering, skill and tool context) before costs paid occasionally.
2. **Leverage:** changes that unlock others, such as self-verification and checks before babysitting and human review.
3. **Cost to fix:** cheapest first.

List all eighteen mistakes in numeric order in `All Checks`, one sentence per evidence cell. Omit `Self-Check` or `Audit Gaps` when empty.

## Source Tracking

`references/sources.yaml` records the post this rubric adapts and the companion glossary that defines its terms. Do not load it during normal use.
