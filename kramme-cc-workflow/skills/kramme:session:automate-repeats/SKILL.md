---
name: kramme:session:automate-repeats
description: "Reviews recent agent session transcripts to find repeated manual workflows or repeated user asks, then proposes and optionally scaffolds only useful new skills or custom subagents. Use when the user asks to inspect recent sessions, find automation opportunities, or create reusable workflows from repeated work. Not for summarizing one session, general retrospectives, or codebase refactoring."
argument-hint: "[session-paths or --recent N] [--create|--auto]"
disable-model-invocation: true
user-invocable: true
---

# Automate Repeated Session Work

Find repeated work in recent agent sessions and turn only the practical patterns into simple skills or custom subagents.

## Boundaries

- Use this for session-history mining, repeated-ask detection, and automation candidate creation.
- Do not use this to summarize one session, write a personal retrospective, review code, or create broad "do everything" agents.
- Treat session logs as private. Use the shared `kramme:session:search` extraction substrate before reading content. Paraphrase evidence unless a short exact phrase is necessary to justify a candidate. Do not copy secrets, customer data, tokens, raw tool payloads, or long user messages into generated files.

## Workflow

Before Step 1, parse `$ARGUMENTS` for `--auto`. Treat `--auto` as an alias for `--create`: remove it from the remaining source arguments and scaffold the selected candidates after the usefulness gate. It does not bypass missing session-source handling or existing-destination protection.

1. Resolve the shared session-search substrate.
   - Resolve `<skills-root>` as the `skills/` directory containing this skill (this skill lives at `<skills-root>/kramme:session:automate-repeats/`), then use the scripts at `<skills-root>/kramme:session:search/scripts/`. The same pattern works in both the source checkout and an installed plugin.
   - Required scripts: `discover-sessions.sh`, `extract-metadata.py`, `extract-skeleton.py`, and `extract-errors.py`.
   - If the script set is unavailable, stop with `MISSING REQUIREMENT: kramme:session:search scripts are not installed`.

2. Resolve the session source without reading raw transcripts into context.
   - If `$ARGUMENTS` includes files or directories, validate those exact paths. If an explicitly provided path is missing or unreadable, stop and report it instead of falling back to default stores. Expand directories to readable `*.jsonl` files and pass the file list to `extract-metadata.py`.
   - If `$ARGUMENTS` includes `--recent N`, discover sessions for the current repo, sort metadata by `last_ts`/`ts`/mtime, and keep the N most recent readable sessions.
   - Otherwise, discover sessions for the current repo over the last 30 days:
     ```bash
     REPO_NAME=$(basename "$(git rev-parse --show-toplevel)")
     bash <session-search-scripts>/discover-sessions.sh "$REPO_NAME" 30 \
       | tr '\n' '\0' \
       | xargs -0 python3 <session-search-scripts>/extract-metadata.py --cwd-filter "$REPO_NAME"
     ```
   - Prefer JSONL session files sorted by recency. Cap the metadata pass at about 30 sessions and the skeleton deep dive at 10 sessions. Skip parse failures and list them under `UNVERIFIED`.
   - If no session source is readable, ask for an export path and stop.

3. Extract safe skeletons into scratch.
   - Create `.context/session-search/<timestamp>/automate-repeats/`.
   - For each selected session, run:
     ```bash
     python3 <session-search-scripts>/extract-skeleton.py --output "$SCRATCH/<session-id>.skeleton.txt" < "$SESSION_FILE"
     ```
   - Run `extract-errors.py` only for sessions where failed commands appear likely to explain a repeated workflow.
   - Read only the scratch skeleton/error files and metadata for pattern analysis. Never read raw transcript files directly.

4. Build an inventory of existing automation before proposing anything.
   - Read existing skill frontmatter from `skills/*/SKILL.md`, `.claude/skills/*/SKILL.md`, `.agents/skills/*/SKILL.md`, `kramme-cc-workflow/skills/*/SKILL.md`, or any explicit skill directory in the current workspace.
   - Read existing subagent frontmatter from `agents/*.md`, `kramme-cc-workflow/agents/*.md`, `.claude/agents/*.md`, or any explicit agent directory in the current workspace.
   - Record likely overlaps by name, description, and trigger phrases.

5. Extract repeated patterns from the safe skeletons.
   - Group similar user asks, manual command sequences, review rituals, debugging loops, release steps, docs updates, CI-fix loops, test triage, changelog work, and PR-prep tasks.
   - Count independent evidence by session, not just repeated messages inside one session.
   - Preserve the user's phrasing as labels in private notes, but report paraphrased evidence.
   - Ignore one-off tasks, vague preferences, personal style notes, and work already well covered by an existing skill or agent.

6. Classify each candidate.
   - Recommend a **skill** when the repeated work is a reusable workflow with ordered steps, decision gates, side effects, or orchestration across tools.
   - Recommend a **custom subagent** when the repeated work is a bounded role or investigation lens with a stable mission, clear inputs, and a repeatable output format.
   - Prefer extending an existing component when the repeated work is a small variation of it.
   - Reject candidates that need broad judgment across many domains, duplicate existing components, depend on unavailable tools, or cannot be explained in a short trigger description.

7. Apply the usefulness gate.
   - A candidate is useful only if it has evidence from at least 2 independent sessions or at least 3 clearly separate asks, a clear trigger, a narrow scope, low overlap with existing automation, and a simple implementation.
   - Keep the default output to 1-3 candidates. If more qualify, rank by time saved and frequency, then create only the top candidates.
   - Mark weaker ideas as `NOT CREATED` with a one-line reason instead of scaffolding them.

8. Present a compact plan before writing files unless the user explicitly requested hands-off creation.
   - Include: candidate name, skill vs subagent, evidence count, destination path, and why it passes the usefulness gate.
   - If the user asked only to "suggest", stop after the report.
   - If the user said "create", passed `--create` or `--auto`, or confirms the plan, scaffold the selected candidates.

9. Scaffold skills simply.
   - Use `skills/{skill-name}/SKILL.md` when the current workspace's skill root is `skills/`; use `kramme-cc-workflow/skills/{skill-name}/SKILL.md` when that plugin layout exists.
   - If the destination path already exists, do not overwrite it. Skip the candidate and report it under `NOT CREATED` with reason `already exists`.
   - Use names in the form `kramme:{domain}:{action}` when adding to this plugin-style tree.
   - Include frontmatter fields: `name`, `description`, `disable-model-invocation`, and `user-invocable`; add `argument-hint` only when useful. Set `disable-model-invocation: true` for any generated skill with side effects (file writes, git, network, deletion); otherwise `false`.
   - Keep each generated `SKILL.md` focused on the workflow. Avoid placeholder docs, READMEs, and large reference files unless the candidate truly needs them.

10. Scaffold subagents simply.
   - Use `agents/{agent-name}.md` when the current workspace's agent root is `agents/`; use `kramme-cc-workflow/agents/{agent-name}.md` when that plugin layout exists.
   - If the destination path already exists, do not overwrite it. Skip the candidate and report it under `NOT CREATED` with reason `already exists`.
   - Include frontmatter fields: `name`, `description`, `model`, and `color`.
   - Keep the body to mission, scope boundaries, analysis process, and output format.
   - Make the agent read-only by default unless the role explicitly requires edits and the user's request authorizes side effects.

11. Update local indexes only when required by the destination repo's own instructions.
   - If a README or published skill index already lists all skills or agents, add concise rows for new components.
   - Update any visible skill or agent count in the same file when it is clearly maintained by hand.
   - Do not add extra documentation files inside the new skill or agent directories.

12. Close with an audit-style summary.
    - `REVIEWED`: session source count and date range if known.
    - `CREATED`: paths for any new skills or agents.
    - `NOT CREATED`: rejected repeated ideas with one-line reasons.
    - `UNVERIFIED`: any session stores, counts, or assumptions that could not be checked.

## Source Tracking

`references/sources.yaml` records the upstream `ce-sessions` source for the shared discovery/extraction substrate and routing model. Do not load it during normal use unless auditing or updating source attribution.
