---
name: kramme:session:automate-repeats
description: "Reviews recent agent session transcripts to find repeated manual workflows or repeated user asks, then proposes and optionally scaffolds only useful new skills or custom subagents. Use when the user asks to inspect recent sessions, find automation opportunities, or create reusable workflows from repeated work. Not for summarizing one session, general retrospectives, or codebase refactoring."
argument-hint: "[session-paths or --recent N] [--create]"
disable-model-invocation: true
user-invocable: true
---

# Automate Repeated Session Work

Find repeated work in recent agent sessions and turn only the practical patterns into simple skills or custom subagents.

## Boundaries

- Use this for session-history mining, repeated-ask detection, and automation candidate creation.
- Do not use this to summarize one session, write a personal retrospective, review code, or create broad "do everything" agents.
- Treat session logs as private. Paraphrase evidence unless a short exact phrase is necessary to justify a candidate. Do not copy secrets, customer data, tokens, or long user messages into generated files.

## Workflow

1. Resolve the session source.
   - If `$ARGUMENTS` includes files or directories, use those. If an explicitly provided path is missing or unreadable, stop and report the exact path instead of falling back to the default stores.
   - If `$ARGUMENTS` includes `--recent N`, inspect the N most recent readable session files. An explicit `N` overrides the default cap below.
   - Otherwise, search likely local session stores in this order, using the first store that yields readable sessions: `.context/`, `~/.codex/sessions/`, `~/.claude/projects/`.
   - Prefer JSONL session files sorted by modification time. Cap the first pass at about 30 recent files or the last 30 days, whichever is smaller. Skip files that cannot be parsed and list them under `UNVERIFIED`.
   - If no session source is readable, ask for an export path and stop.

2. Build an inventory of existing automation before proposing anything.
   - Read existing skill frontmatter from `skills/*/SKILL.md`, `.claude/skills/*/SKILL.md`, `.agents/skills/*/SKILL.md`, `kramme-cc-workflow/skills/*/SKILL.md`, or any explicit skill directory in the current workspace.
   - Read existing subagent frontmatter from `agents/*.md`, `kramme-cc-workflow/agents/*.md`, `.claude/agents/*.md`, or any explicit agent directory in the current workspace.
   - Record likely overlaps by name, description, and trigger phrases.

3. Extract repeated patterns from the sessions.
   - Group similar user asks, manual command sequences, review rituals, debugging loops, release steps, docs updates, CI-fix loops, test triage, changelog work, and PR-prep tasks.
   - Count independent evidence by session, not just repeated messages inside one session.
   - Preserve the user's phrasing as labels in private notes, but report paraphrased evidence.
   - Ignore one-off tasks, vague preferences, personal style notes, and work already well covered by an existing skill or agent.

4. Classify each candidate.
   - Recommend a **skill** when the repeated work is a reusable workflow with ordered steps, decision gates, side effects, or orchestration across tools.
   - Recommend a **custom subagent** when the repeated work is a bounded role or investigation lens with a stable mission, clear inputs, and a repeatable output format.
   - Prefer extending an existing component when the repeated work is a small variation of it.
   - Reject candidates that need broad judgment across many domains, duplicate existing components, depend on unavailable tools, or cannot be explained in a short trigger description.

5. Apply the usefulness gate.
   - A candidate is useful only if it has evidence from at least 2 independent sessions or at least 3 clearly separate asks, a clear trigger, a narrow scope, low overlap with existing automation, and a simple implementation.
   - Keep the default output to 1-3 candidates. If more qualify, rank by time saved and frequency, then create only the top candidates.
   - Mark weaker ideas as `NOT CREATED` with a one-line reason instead of scaffolding them.

6. Present a compact plan before writing files unless the user explicitly requested hands-off creation.
   - Include: candidate name, skill vs subagent, evidence count, destination path, and why it passes the usefulness gate.
   - If the user asked only to "suggest", stop after the report.
   - If the user said "create", passed `--create`, or confirms the plan, scaffold the selected candidates.

7. Scaffold skills simply.
   - Use `skills/{skill-name}/SKILL.md` when the current workspace's skill root is `skills/`; use `kramme-cc-workflow/skills/{skill-name}/SKILL.md` when that plugin layout exists.
   - If the destination path already exists, do not overwrite it. Skip the candidate and report it under `NOT CREATED` with reason `already exists`.
   - Use names in the form `kramme:{domain}:{action}` when adding to this plugin-style tree.
   - Include frontmatter fields: `name`, `description`, `disable-model-invocation`, and `user-invocable`; add `argument-hint` only when useful. Set `disable-model-invocation: true` for any generated skill with side effects (file writes, git, network, deletion); otherwise `false`.
   - Keep each generated `SKILL.md` focused on the workflow. Avoid placeholder docs, READMEs, and large reference files unless the candidate truly needs them.

8. Scaffold subagents simply.
   - Use `agents/{agent-name}.md` when the current workspace's agent root is `agents/`; use `kramme-cc-workflow/agents/{agent-name}.md` when that plugin layout exists.
   - If the destination path already exists, do not overwrite it. Skip the candidate and report it under `NOT CREATED` with reason `already exists`.
   - Include frontmatter fields: `name`, `description`, `model`, and `color`.
   - Keep the body to mission, scope boundaries, analysis process, and output format.
   - Make the agent read-only by default unless the role explicitly requires edits and the user's request authorizes side effects.

9. Update local indexes only when required by the destination repo's own instructions.
   - If a README or published skill index already lists all skills or agents, add concise rows for new components.
   - Update any visible skill or agent count in the same file when it is clearly maintained by hand.
   - Do not add extra documentation files inside the new skill or agent directories.

10. Close with an audit-style summary.
    - `REVIEWED`: session source count and date range if known.
    - `CREATED`: paths for any new skills or agents.
    - `NOT CREATED`: rejected repeated ideas with one-line reasons.
    - `UNVERIFIED`: any session stores, counts, or assumptions that could not be checked.
