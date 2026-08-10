---
name: kramme:code:audit-agent-config
description: "Audits every persistent agent configuration stored in the repository — project instruction files, skills, subagents, hooks, MCP server definitions, permission settings, and repo-persisted memory or rules files — for redundant, outdated, conflicting, or irrelevant entries. Produces a read-only KEEP / IMPROVE / REMOVE list with a one-sentence verdict and evidence per item; never edits files and never inspects global user-scoped configuration. Accepts an optional scope path to re-audit a single surface. Use when asked to audit, clean up, or review agent config, CLAUDE.md/AGENTS.md rules, skills, MCPs, or instruction cruft. Not for scoring how agent-friendly the codebase itself is (use kramme:code:agent-readiness) and not for general code-quality or tech-debt audits (use kramme:code:refactor-opportunities)."
argument-hint: "[scope-path]"
disable-model-invocation: false
user-invocable: true
---

# Audit Agent Configuration

Audit every persistent configuration in the repository that shapes how a coding agent works, and report a KEEP / IMPROVE / REMOVE verdict per item. This skill is strictly read-only: it never edits, deletes, or reorders configuration, and it never audits configuration that lives outside the repository.

Parse the input before Step 1: when a scope path is provided, restrict the audit to configuration surfaces at or under that path, state the restriction in the report header, and keep every other rule unchanged. With no input, audit the full repository.

**Scope rules (apply throughout):**

- **In scope:** configuration persisted inside the repository working tree, whether committed or local-only (for example a gitignored `settings.local.json`). Mark local-only files as such in the report.
- **Out of scope:** global user-scoped configuration (`~/.claude/`, `~/.codex/`, `~/.agents/`, user memory directories, enterprise managed settings) and anything else outside the repository root. Never read or report on these, even when a repo file references them.
- **Read-only:** produce the report only. If the user wants removals applied, that is a separate follow-up they must request explicitly.

---

## Step 1: Inventory Configuration Surfaces

Build the audit inventory by checking each surface below. Use file listing and glob searches from the repository root; record every file found, and record surfaces that came up empty so coverage is explicit.

| Surface | Where to look |
| --- | --- |
| Project instructions | `CLAUDE.md` (root and nested), `AGENTS.md`, `.github/copilot-instructions.md`, `.cursorrules`, `.cursor/rules/`, `.windsurfrules`, `GEMINI.md` |
| Skills and commands | `.claude/skills/`, `.claude/commands/`, `.agents/skills/`, plugin `skills/*/SKILL.md` directories |
| Subagents | `.claude/agents/`, plugin `agents/*.md` directories |
| Hooks | Hook definitions in `.claude/settings.json` / `.claude/settings.local.json`, plugin `hooks/hooks.json` |
| MCP servers | `.mcp.json`, `mcpServers` blocks inside any settings file found above |
| Permissions and settings | `.claude/settings.json`, `.claude/settings.local.json` (allow/deny lists, env vars, model overrides) |
| Repo-persisted memory | Memory, learnings, or rules files stored in the repo (for example `memory/`, `.context/`, learnings files an agent tool writes into the working tree) |
| Plugin manifests | `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json` |
| Other agent runtimes | Any other agent-tool dotfiles or directories found by scanning the repository root (for example `.codex/`, `.gemini/`, `.opencode/`, `.github/instructions/`) — treat this table as a starting set, not a complete list |

Boundary rules:

- When an instruction file `@`-includes or links another file inside the repo, follow it one level and audit the referenced file's directives too.
- Resolve symlinks before itemizing and audit each real file exactly once: when one config path is an alias of another (for example a symlinked skills directory), record the alias in the report instead of auditing it twice or reporting the pair as a redundancy.
- Treat generated files (component catalogs, generated reference tables) as derived output: audit the source that generates them, and flag the generated copy only when it has drifted from its source.

## Step 2: Itemize

Split each file into auditable items rather than judging whole files:

- An instruction file yields one item per rule, convention, or directive (roughly one per bullet or paragraph).
- A skills or agents directory yields one item per skill or agent.
- A settings file yields one item per hook, MCP server, permission entry, or env var.
- A memory store yields one item per remembered fact.

Skip prose that carries no directive (headings, examples illustrating an adjacent rule).

While itemizing, tag each item's load profile: **always-on** (project instruction files, hooks, permission settings, MCP definitions — loaded or active in every session) or **on-demand** (skill and agent bodies, memory recalled selectively — loaded only when triggered).

Complete the itemization of every surface before starting Step 3: conflict detection compares items across files, so evaluating surfaces one at a time while still reading would miss cross-surface contradictions.

## Step 3: Evaluate Each Item

Test every item against the four defect classes. Each REMOVE verdict must name its class and cite checkable evidence; claims must be verified, not pattern-matched.

1. **Redundant** — duplicates another in-scope item, restates the agent's default behavior, or restates what the code or repo structure already makes obvious. Name the surviving copy that makes it redundant.
2. **Outdated** — references files, commands, components, tools, or workflows that no longer exist, or contradicts the repository's current state. Verify with an existence check (glob, file read, or `--help` on a referenced command) before flagging. Git history is corroborating evidence: compare when the config item last changed (`git log -1 --format=%cs -- <file>`) against the code or paths it governs — a rule untouched since a restructure of what it references is likely stale.
3. **Conflicting** — contradicts another in-scope item so the agent cannot satisfy both. Cite both sides; recommend REMOVE for the weaker or staler side and KEEP for the other.
4. **Irrelevant** — cannot apply to this project (targets a stack, tool, or platform the repo does not use). Verify with a repository-wide search for the tool or pattern before flagging. Where the platform records local usage statistics for skills or commands, zero recorded use is supporting evidence of irrelevance — never sufficient on its own.

Verdict rules:

- Weight scrutiny by context cost: always-on items ship into every session, so hold them to a stricter bar for redundancy and relevance; an on-demand item's defect costs context only when it is triggered.
- An item with no confirmed defect is KEEP.
- An item whose purpose is still valid but whose current form has a confirmed defect is IMPROVE — for example a rule citing one renamed path while the rule itself still applies, two overlapping directives worth consolidating into one, or wording too vague to act on. The sentence must state the defect and the concrete fix.
- An item is REMOVE only when the whole item has no remaining value; if any part is worth keeping, the verdict is IMPROVE, not REMOVE.
- When evidence is ambiguous, verdict is KEEP with the doubt stated in the sentence — never REMOVE or IMPROVE on suspicion.
- Judge relative to the repository's own conventions, not personal preference; style disagreements are not defects.

## Step 4: Report

Output the results directly in the reply (no report file):

```
# Agent Configuration Audit

Scope: {full repository | restricted to <path>}
Surfaces checked: {N} ({list}; empty: {list}; aliases: {symlinked paths resolved, if any})
Items audited: {N} — KEEP {N} / IMPROVE {N} / REMOVE {N}

## KEEP
- `{file}` — {item}: {one sentence: why it still earns its place}
...

## IMPROVE
- {[always-on] }`{file}` — {item}: {one sentence: defect + concrete fix}
...

## REMOVE
- {[always-on] }`{file}` — {item}: {one sentence: defect class + evidence}
...
```

Group items by source file within each section. In IMPROVE and REMOVE, prefix items from always-on surfaces with `[always-on]` and list them first, then order by confidence (strongest evidence first). Exactly one sentence per item.

Close with: no files were changed, and removals or improvements can be applied as a follow-up on request.

---

## Error Handling

| Scenario | Action |
| --- | --- |
| No configuration surfaces found | Report the surfaces checked and state the repository has no repo-persisted agent configuration. |
| Scope path missing or outside the repository | Stop and report the invalid path; never widen a scoped audit or follow the path outside the repo. |
| File unreadable (permissions, binary, malformed YAML/JSON) | Record it as an audit gap in the report; do not guess its contents. |
| Very large surface (hundreds of skills or memory entries) | Audit instruction files item-by-item; for bulk directories, audit per skill/agent/entry but cap quoted evidence to keep the report readable. |
| Item references global user config | Note that the reference exists, but do not open or judge the global target. |
| User asks to apply removals or improvements mid-audit | Finish and deliver the report first, then treat the edit as a separate explicit follow-up. |
