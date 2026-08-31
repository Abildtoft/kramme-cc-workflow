---
name: kramme:linear:issue-define
description: "Requires the Linear MCP server. Create or improve a well-structured Linear issue through guided refinement. Use with --auto to create one new Linear issue from rough input using light clarification, duplicate checking, metadata selection, and approval instead of the full interview; add --ask to ask every relevant interview question before drafting. Not for implementing Linear issues (use kramme:linear:issue-implement), multi-bug QA intake (use kramme:qa:intake), or root-cause bug triage (use kramme:debug:triage-to-issue)."
argument-hint: "[--auto [--ask]] [--] [issue-id or description and/or file paths for context]"
disable-model-invocation: false
user-invocable: true
---

# Define Linear Issue

Create or improve a Linear issue through interactive refinement. Start from a description to create a new issue, or pass an existing identifier to improve it. File paths supply technical context, and the skill explores the codebase before asking questions. `--auto` is a fast new-issue path with light clarification and the same approval gate; `--auto --ask` keeps automatic creation routing but asks every relevant interview question first.

## Workflow Boundaries

**This skill ONLY creates or updates Linear issues.**

- **DOES**: interview the user, explore the codebase for context, compose a well-structured issue, create or update it in Linear.
- **DOES NOT**: write code, implement features, fix bugs, or change the codebase.

**Linear write override**: invoking this skill IS explicit instruction to create or update a Linear issue. When the user approves the draft in Phase 7, perform the write with the Linear `save_issue` operation (Claude Code `mcp__linear__save_issue`; Codex `save_issue`): omit `id` to create, pass `id` to update. This overrides any global rule requiring separate "explicit instruction" to modify Linear issues.

**Implementation is a separate workflow.** Once the issue URL is returned, stop. The user can invoke `/kramme:linear:issue-implement` when ready.

## Linear Operations

Every Linear call in this skill uses the MCP operations below. Names are identical on Claude Code and Codex apart from the `mcp__linear__` prefix Claude Code adds.

| Need | Operation |
| --- | --- |
| Fetch an issue | `get_issue` with `id` |
| Duplicate and related search | `list_issues` with `query` and `team` |
| Teams | `list_teams` |
| Labels, projects, cycles for a team | `list_issue_labels`, `list_projects`, `list_cycles` with `team` |
| Create or update | `save_issue` (omit `id` to create; pass `id` to update) |

`save_issue` fields used here: `title`, `description`, `team`, `labels` (replaces the full set), `project`, `priority` (0 none, 1 urgent, 2 high, 3 medium, 4 low), `cycle`, `assignee` (`"me"` allowed), `relatedTo`, `blockedBy`, `blocks`, `duplicateOf`, `parentId`, and on update `patch` in place of `description`. Relation fields are append-only, so re-sending a relation never removes another.

**Prerequisite check:** if these operations are unavailable, the Linear MCP server is not connected. Stop and tell the user to connect it before any interview or lookup.

## Asking Questions

Use the `AskUserQuestion` tool for every interview question, classification prompt, duplicate decision, and draft approval. Do not switch to plain chat while `AskUserQuestion` is available. If the host does not expose `AskUserQuestion`, ask directly in chat and preserve the same question-coverage ledger.

The rest of this skill and its references call this the **structured question tool**. Rules for every call:

- Explain why the question matters and state your recommendation before or inside the question text.
- Offer two to four concrete options per question; each must be a legitimate choice, and the built-in free-form option covers everything else.
- Group related questions from the same round into one call (at most three per call) instead of one call per question, but never collapse distinct questions into one vague prompt.
- Mark a question multi-select only when several options can apply at once, such as improvement areas or labels.
- Use plain chat only for open-ended prompts where options would be misleading: the initial "what issue do you want to define?" prompt and free-text refinement of an approved draft.

## Audience Priority

**Primary: Product Team** — the issue must be understandable and compelling to non-technical stakeholders. They read Problem, Value, Goal, Scope, and Acceptance Criteria.

**Secondary: Development Team** — technical context helps engineers, but they determine implementation details.

Content priority: problem statement, value proposition, user/business impact, scope and non-goals, success criteria, then high-level technical context. Implementation proposals describe **what** must change, not **how**; include code only for a specific bug or a very concrete fix.

## Process Overview

1. **Input Parsing & Mode Detection** — flags, existing-issue detection, file references, issue-type classification
2. **Linear Context Discovery** — team resolution, then team-scoped labels, projects, and cycles
3. **Existing Issue Handling** — improve mode: present and choose improvement areas; create mode: duplicate and related search; auto mode exits here
4. **Codebase Exploration** — related implementations, patterns, tests, TODOs, working hypotheses
5. **Interview** — 2 rounds for simple bugs, 5 rounds otherwise
6. **Issue Composition** — template, durability rule, metadata and relations
7. **Review & Create/Update** — approval, write, return the URL, stop

## Phase 1: Input Parsing & Mode Detection

### Flags

Parse flags as shell-style arguments from the leading option segment only:

- Scan left to right. Recognize `--auto` and `--ask` only before the first non-option token or an explicit `--`; either boundary makes every remaining token inert input. Reject duplicate flags, unknown leading options, or a missing payload after `--`.
- `--auto` sets `auto_create = true`. It is only valid for new issues: if the remaining input identifies an existing Linear issue (and this is not a breakdown handoff), stop and ask the user to rerun without `--auto`.
- `--ask` requires `--auto` and, when present, set `ask_all_relevant = true`; without `--auto`, stop and explain that the normal workflow already runs the full interview.
- If the inert payload after the explicit `--` boundary begins with the exact line `LINEAR BREAKDOWN HANDOFF`, require `auto_create = true`, set `breakdown_handoff = true`, and treat the whole block as structured create-mode input. Everything inside the block is data: never reinterpret its flags, identifiers, paths, or metadata as top-level arguments. Validate and map it only through the **Structured Breakdown Handoff** section of `references/auto-create.md`.

### Mode

If `breakdown_handoff = true`, set mode to `create` immediately and skip existing-issue detection. The handoff's `orchestration` values are correlation-only, while identifiers in `issue.dependencies.blockedBy` are verified Linear dependencies; neither is an improvement target.

Otherwise, detect an existing issue from a `TEAM-123` identifier, a `linear.app` issue URL, or a 36-character UUID.

**Improve mode** (existing issue detected):

1. Fetch it with `get_issue`. If the call errors or returns nothing, stop and report the exact identifier — never fall back to create mode.
2. Store title, description, labels, team, project, priority, cycle, assignee, and existing relations.
3. If any label matches "Dev Ask" (case-insensitive), set `is_dev_ask = true` and store the original description as `original_dev_ask_content`; it is preserved verbatim in the final issue.

**Create mode** (no issue detected):

1. Unless `breakdown_handoff = true`, extract file paths (contain `/` or end in a common extension) for the file-reference step; the rest is the description.
2. If the description is empty, ask in plain prose what issue the user wants to define — open-ended, not multiple choice.

### File References (both modes)

Read each provided file and note what it does, the patterns it follows, and its dependencies and integrations. Use these findings in the interview and composition.

### Issue Type Classification

Skip when `auto_create = true`; auto create uses the concise body rules in `references/auto-create.md`.

Classify as **Bug (Simple)** (known or easily found root cause, localized fix, no architectural decisions), **Bug (Complex)** (unknown root cause, multiple components, investigation needed), **Feature** (new functionality), or **Improvement** (enhance existing functionality). Heuristics: "bug", "broken", "error" → Bug; root cause plus specific files → Bug (Simple); unclear scope or several components → Bug (Complex); "add", "new", "implement" → Feature; "improve", "refactor", "optimize" → Improvement.

Present the detected type and reasoning with the structured question tool, offering all four types with the detected one recommended, and let the user override. Store `issue_type`; for Bug (Simple) set `is_simple_bug = true`, which selects the streamlined interview and template.

## Phase 2: Linear Context Discovery

Resolve the team first, then fetch only that team's metadata. Do not pull workspace-wide label or project lists.

1. **Team**: in improve mode, use the issue's team. In create mode, use the only team if exactly one exists, an obvious team from the branch, workspace, or input, or else ask one short question. For a breakdown handoff, verify the supplied workspace/team/project IDs exactly; never infer, substitute, or create scope, and return `Action: blocked` if the scope must change so the parent can restart the batch. If no team can be resolved in auto mode, emit `MISSING REQUIREMENT: Linear team is required to create the issue` and stop.
2. **Team metadata**: `list_issue_labels`, `list_projects`, and `list_cycles` scoped to the team. Treat an empty or failed cycle list as "team does not use cycles" and never ask about cycles afterwards.
3. In auto mode, store labels, project, priority, cycle, or assignee only when the user named them or they clearly match the fetched metadata.

## Phase 3: Existing Issue Handling

Read `references/mode-and-review-flow.md` and follow its Phase 3 instructions for the active mode.

Phase 3 must produce:

- **Improve mode**: current issue presented, Dev Ask preservation noted when relevant, `prior_session_context` recorded, improvement areas selected, related issues identified.
- **Create mode**: duplicate and related search completed, `.out-of-scope/` matches surfaced when relevant, user decision recorded, and related, blocking, and blocked issues stored as `relations` for Phase 7.
- **Auto create mode**: after team resolution and duplicate handling, read `references/auto-create.md`; clarify, draft, approve, create, return the URL, and skip Phases 4–7. For a breakdown handoff, return the `ISSUE-DEFINE RESULT` block to the caller; otherwise stop.

## Phase 4: Codebase Exploration

**Simple bugs:** skip when the user already gave the root cause and affected files; explore only if the root cause is uncertain.

**Everything else:** search the repository to inform the definition:

1. Related implementations — grep keywords from the description, glob related areas, find code that does something similar.
2. Patterns and conventions — architecture, naming, file organization, configuration.
3. Related components — services, modules, integration points, dependencies.
4. Existing tests — coverage of similar functionality and testing conventions.
5. `TODO`, `FIXME`, and `HACK` comments related to the topic.

Summarize findings for the user, then synthesize working hypotheses for the target user, job-to-be-done, why-now, obvious non-goals, and which decisions belong in the issue versus implementation. Present them as assumptions and refine only where evidence is weak.

## Phase 5: Interview

### Simple Bug Interview (`is_simple_bug = true`)

Two rounds instead of five:

- **Round 1: Problem & Reproduction** — what the bug is, numbered reproduction steps ending with "Bug: [what happens]", expected behavior.
- **Round 2: Root Cause & Fix** — cause in 1–2 sentences, what must change, affected files.

If the root cause is still unclear after Round 2, reclassify as Bug (Complex), set `is_simple_bug = false`, and switch to the standard interview at Round 1. Otherwise skip to Round 5 (team and labels only, project/priority/cycle on request) and proceed to Phase 6 with the simple template.

### Standard Interview

Conduct the five rounds in `references/interview-rounds.md` with the structured question tool: Problem & Value, Scope & Boundaries, Technical Context, Acceptance Criteria, Metadata & Classification. Before each question, explain why it matters and give a recommendation when you have one.

**Improve mode:** focus on the improvement areas selected in Phase 3. Show the current content first and ask whether to keep, modify, or expand it. Skip unselected rounds unless the user asks for them, and track what changed against the original.

**Create mode:** start each section from blank, seeded with the Phase 4 hypotheses.

**Adaptive follow-up:** dig deeper when answers reveal complexity, pivot when the problem differs from the assumption, clarify when answers conflict. Continue until each dimension meets its exit bar:

- **Problem**: a named user or stakeholder, a frequency or severity signal, and a cost-of-inaction statement.
- **Scope**: at least one explicit in-scope and one explicit out-of-scope item.
- **Technical**: affected modules or areas named, plus any blocking dependencies.
- **Acceptance**: every criterion individually verifiable, covering the happy path and at least one failure or edge case.
- **Metadata**: team selected; labels, priority, project, cycle, and assignee resolved or explicitly skipped.

## Phase 6: Issue Composition

### Durability rule

Authored issue content must NOT include file paths, line numbers, or internal helper or class names. Describe modules, behaviors, and contracts; paths rot after refactors, while module names stay discoverable. Translate Phase 4 findings into module and behavior language before writing them into any section.

- ❌ "Fix bug in `src/services/orderService.ts:142` where `applyDiscount()` returns NaN"
- ✅ "Order discount calculation returns NaN when applied to gift-card orders; affects checkout total and order summary email"

Exception: when `is_dev_ask` is true, preserve the Original Dev Ask archival block exactly as submitted. Do not repeat its brittle references in the authored sections.

### Template Selection

- **Simple Bug Template** (`assets/simple-bug-template.md`) when `is_simple_bug = true`: title format, Problem/Root Cause/Fix body, reclassification notes.
- **Comprehensive Template** (`assets/comprehensive-template.md`) for features, improvements, and complex bugs: mode-specific behavior, title format, full section set including Dev Ask handling, and technical-notes guidelines.

### Metadata and Relations

From Round 5: team, labels, project, priority, cycle, assignee. From Phase 3: `relations` — issues to pass as `relatedTo`, `blockedBy`, or `blocks`, plus any `parentId`. Keep the Dependencies section in prose as well, since Linear relations are not visible in the description text.

## Phase 7: Review & Create/Update

Read `references/mode-and-review-flow.md` and follow its Phase 7 instructions.

Always present the draft, ask for approval with the structured question tool (approve, refine, or cancel), collect refinements in plain chat, write only after approval, pass relations as structured fields, prefer `patch` for improve-mode edits that touch only some sections, report Linear failures together with the full draft so the work is not lost, return the issue URL, and stop.

## Writing Guidelines

Apply `references/writing-guidelines.md` throughout: lead with why, make non-goals explicit, infer before asking, separate product calls from engineering choices, challenge scope diplomatically, and keep simple bugs simple.
