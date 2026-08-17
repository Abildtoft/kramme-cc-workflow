---
name: kramme:session:automate-repeats
description: "Reviews recent agent sessions to find repeated manual workflows, repeated asks, and recurring friction, then reports evidence-backed improvements to the existing skill or subagent that owns the work before proposing or scaffolding a new one. Use when the user asks to inspect recent sessions, find automation opportunities, improve a skill from how recent runs went, or turn repeated work into reusable workflows. Not for summarizing one session, general retrospectives, or codebase refactoring."
argument-hint: "[session-paths or --recent N] [--create|--auto]"
disable-model-invocation: true
user-invocable: true
---

# Automate Repeated Session Work

Find repeated work and recurring friction in recent agent sessions, propose improvements to the existing component that owns the work, and turn only the genuinely uncovered patterns into simple new skills or custom subagents.

## Boundaries

- Use this for session-history mining, repeated-ask detection, existing-component improvement proposals, and automation candidate creation.
- Do not use this to summarize one session, write a personal retrospective, review code, or create broad "do everything" agents.
- Improvements to existing components are report-only. This skill never edits, rewrites, or scaffolds over an existing skill or subagent; applying a proposed improvement is a separate follow-up the user must request explicitly.
- Treat session logs as private. Use the shared `kramme:session:search` extraction substrate before reading content. Paraphrase evidence unless a short exact phrase is necessary to justify a candidate. Do not copy secrets, customer data, tokens, raw tool payloads, or long user messages into generated files.

## Workflow

Before Step 1, parse `$ARGUMENTS` for `--auto`. Treat `--auto` as an alias for `--create`: remove it from the remaining source arguments and scaffold the selected candidates after the usefulness gate. It does not bypass missing session-source handling or existing-destination protection, and it grants no authority to edit an existing skill or subagent.

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
     bash "<session-search-scripts>/discover-sessions.sh" "$REPO_NAME" 30 \
       | tr '\n' '\0' \
       | xargs -0 python3 "<session-search-scripts>/extract-metadata.py" --cwd-filter "$REPO_NAME"
     ```
   - Prefer JSONL session files sorted by recency. Cap the metadata pass at about 30 sessions and the skeleton deep dive at 10 sessions. Skip parse failures and list them under `UNVERIFIED`.
   - If no session source is readable, ask for an export path and stop.

3. Extract safe skeletons into scratch.
   - Create `.context/session-search/<timestamp>/automate-repeats/`.
   - For each selected session, run:
     ```bash
     python3 "<session-search-scripts>/extract-skeleton.py" --output "$SCRATCH/<session-id>.skeleton.txt" < "$SESSION_FILE"
     ```
   - Run `extract-errors.py` only for sessions where failed commands appear likely to explain a repeated workflow.
   - Read only the scratch skeleton/error files and metadata for pattern analysis. Never read raw transcript files directly.

4. Build an inventory of existing automation before proposing anything.
   - Read existing skill frontmatter from `skills/*/SKILL.md`, `.claude/skills/*/SKILL.md`, `.agents/skills/*/SKILL.md`, `kramme-cc-workflow/skills/*/SKILL.md`, or any explicit skill directory in the current workspace.
   - Read existing subagent frontmatter from `agents/*.md`, `kramme-cc-workflow/agents/*.md`, `.claude/agents/*.md`, or any explicit agent directory in the current workspace.
   - Record likely overlaps by name, description, and trigger phrases.

5. Extract repeated patterns and recurring friction from the safe skeletons.
   - Group similar user asks, manual command sequences, review rituals, debugging loops, release steps, docs updates, CI-fix loops, test triage, changelog work, and PR-prep tasks.
   - Group friction signals that recur while an existing component is already in use: the user having to clarify or re-steer the same point, failed commands and wrong tool or path assumptions, steps the user repeatedly skips or undoes as unnecessary, stale paths, commands, or versions, and context the agent had to be handed every run.
   - Treat a prompt-footprint or contract warning from the destination repo's own skill linter, where one exists, as corroborating evidence for a friction signal, never as a candidate on its own.
   - Count independent evidence by session, not just repeated messages inside one session.
   - Preserve the user's phrasing as labels in private notes, but report paraphrased evidence.
   - Ignore one-off tasks, vague preferences, personal style notes, and work an existing skill or agent already handles without recurring friction.

6. Classify each candidate, asking whether an existing component already owns the work before considering a new one.
   - Recommend **IMPROVE EXISTING** when one existing skill or subagent clearly owns the behavior and the recurring friction points at a defect in that component's contract, or at a small variation of it, rather than at a missing entry point. Name the single owning component; if two or more components could own the work, or none does, do not use this classification.
   - Before recording `IMPROVE EXISTING`, read the owning component's file body, not just the frontmatter collected in Step 4, so the contract defect and proposed change name real steps, boundaries, or fields.
   - Recommend a **skill** when the repeated work is a reusable workflow with ordered steps, decision gates, side effects, or orchestration across tools, and no existing component owns it.
   - Recommend a **custom subagent** when the repeated work is a bounded role or investigation lens with a stable mission, clear inputs, and a repeatable output format, and no existing component owns it.
   - Reject candidates that need broad judgment across many domains, duplicate existing components, depend on unavailable tools, or cannot be explained in a short trigger description.

7. Apply the usefulness gate.
   - A candidate is useful only if it has evidence from at least 2 independent sessions or at least 3 clearly separate asks, a clear trigger, a narrow scope, low overlap with existing automation, and a simple implementation.
   - Hold `IMPROVE EXISTING` to the same evidence bar. Never propose an improvement from a single session or a single model failure, however severe that one run looked.
   - Cap and rank the two classes separately: keep the default to 1-3 new skill or subagent candidates and 1-3 `IMPROVE EXISTING` proposals, ranking within each class by time saved and frequency. Never drop a qualified improvement to make room for a new component.
   - Mark weaker ideas as `NOT CREATED` with a one-line reason instead of scaffolding or proposing them.

8. Report qualified existing-component improvements instead of applying them.
   - Report each one under `IMPROVE EXISTING` with six fields: affected component name and path, independent evidence count, paraphrased symptom, likely contract defect, proposed change, and how to verify the change worked.
   - State the proposed change as a concrete contract edit to that component, not as a wish. Name the step, boundary, or field to change and what it should say instead.
   - Paraphrase every symptom and name only components, files, and paths. Never quote private session content, secrets, customer data, tokens, or raw tool payloads in a proposal.
   - This report is the whole output for these candidates under every flag, including `--create` and `--auto`. Do not edit the affected component, and tell the user that applying the improvement is a separate follow-up they must request explicitly.

9. Present a compact plan before writing files unless the user explicitly requested hands-off creation.
   - Include: candidate name, skill vs subagent, evidence count, destination path, and why it passes the usefulness gate.
   - If the user asked only to "suggest", stop after the report.
   - If the user said "create", passed `--create` or `--auto`, or confirms the plan, scaffold the selected new candidates. `IMPROVE EXISTING` candidates are never scaffolded or applied here.

10. Scaffold skills simply.
    - Use `skills/{skill-name}/SKILL.md` when the current workspace's skill root is `skills/`; use `kramme-cc-workflow/skills/{skill-name}/SKILL.md` when that plugin layout exists.
    - If the destination path already exists, do not overwrite it. Skip the candidate and report it under `NOT CREATED` with reason `already exists`.
    - Use names in the form `kramme:{domain}:{action}` when adding to this plugin-style tree.
    - Include frontmatter fields: `name`, `description`, `disable-model-invocation`, and `user-invocable`; add `argument-hint` only when useful. Set `disable-model-invocation: true` for any generated skill with side effects (file writes, git, network, deletion); otherwise `false`.
    - Keep each generated `SKILL.md` focused on the workflow. Avoid placeholder docs, READMEs, and large reference files unless the candidate truly needs them.

11. Scaffold subagents simply.
    - Use `agents/{agent-name}.md` when the current workspace's agent root is `agents/`; use `kramme-cc-workflow/agents/{agent-name}.md` when that plugin layout exists.
    - If the destination path already exists, do not overwrite it. Skip the candidate and report it under `NOT CREATED` with reason `already exists`.
    - Include frontmatter fields: `name`, `description`, `model`, and `color`.
    - Keep the body to mission, scope boundaries, analysis process, and output format.
    - Make the agent read-only by default unless the role explicitly requires edits and the user's request authorizes side effects.

12. Update local indexes only when required by the destination repo's own instructions.
    - If a README or published skill index already lists all skills or agents, add concise rows for new components.
    - Update any visible skill or agent count in the same file when it is clearly maintained by hand.
    - Do not add extra documentation files inside the new skill or agent directories.

13. Close with an audit-style summary that keeps the four outcomes separate.
    - `REVIEWED`: session source count and date range if known.
    - `IMPROVE EXISTING`: proposed improvements to existing components, each with its owning component and evidence count, reported as proposals only.
    - `CREATED`: paths for any new skills or agents.
    - `NOT CREATED`: rejected repeated ideas and improvement proposals, with one-line reasons.
    - `UNVERIFIED`: any session stores, counts, or assumptions that could not be checked.

## Source Tracking

`references/sources.yaml` records the upstream `ce-compound` session-history scripts for the shared discovery/extraction substrate and routing model, plus the PostHog agent-skills post for the run-evidence improvement framing. Do not load it during normal use unless auditing or updating source attribution.
