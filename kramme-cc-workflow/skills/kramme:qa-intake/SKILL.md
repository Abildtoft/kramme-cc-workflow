---
name: kramme:qa-intake
description: Conversational QA intake session - user describes bugs they encountered, the agent lightly clarifies, explores the codebase in the background for domain language, and files durable Linear or SIW tickets one issue at a time. Use when the user has multiple bugs from a manual QA pass and wants to log them rapidly without per-issue deep interviews. Not for live-app browser testing (use kramme:qa), not for tracing the root cause of a single bug or applying a fix (use kramme:debug:investigate), not for one well-refined ticket with a 5-round interview (use kramme:linear:issue-define).
argument-hint: "[optional starting context]"
disable-model-invocation: true
user-invocable: true
---

# Conversational QA Intake

Run a multi-issue QA-intake session. The user describes bugs they encountered during manual testing; the agent lightly clarifies, explores the codebase in the background to learn the domain language, decides whether each report is one ticket or a breakdown into linked tickets, and files durable issues in Linear (or SIW, or a local folder) one at a time. The session loops until the user says they are done.

**Arguments:** "$ARGUMENTS"

## Workflow Boundaries

**This command ONLY listens to the user and files new tickets.**

- **DOES**: ask short clarifying questions, explore the codebase for domain language, file new Linear/SIW/local tickets, link parent/child and blocker relationships between tickets created during the same intake run.
- **DOES NOT**: write code, modify pre-existing tickets, close tickets, propose or implement fixes, run live-app QA against a URL.

Updating a parent ticket created earlier in the same intake run to add its just-created child links is part of filing the breakdown. It is not permission to edit older tickets.

**Linear Issue Creation Override**: invoking this command IS explicit instruction to create new Linear issues and, for breakdowns, update only the just-created parent issue to add child links. When the user has confirmed an issue scope inside the per-issue loop, proceed directly with `mcp__linear__create_issue` without a separate "may I create the ticket?" gate — the user is in-session and approval is implicit in their continued participation.

## When to Use

- The user has a list of bugs in their head from a manual QA pass and wants to log all of them quickly.
- Some or all of the issues do not have a reproducible URL trace (workflow gaps, missing features, ambiguous design problems, edge cases the user hit but cannot describe as a route).
- The user wants tickets written from a user-perspective viewpoint that will survive future refactors.

## When NOT to Use

- **Live-app browser testing** — the user wants automated probing of a running URL with screenshots, network triage, and an a11y ladder. Use `kramme:qa` instead.
- **Single-bug deep root-cause investigation and fix** — the user wants to reproduce, isolate, trace data flow, and apply a code fix. Use `kramme:debug:investigate` instead.
- **One well-refined ticket** — the user has one issue and wants the full 5-round structured interview that produces a comprehensive, polished Linear issue. Use `kramme:linear:issue-define` instead.
- **Editing or closing pre-existing tickets** — this skill files new tickets only, apart from finalizing child links on a parent created during the same intake run. For improving an existing Linear issue, use `kramme:linear:issue-define` in improve mode.

## Process Overview

```
/kramme:qa-intake
    |
    v
[Step 1: Detect Inputs] -> ticket sink + domain language priming
    |
    v
[Step 2: Open the session] -> ask "What's the first issue?"
    |
    v
[Step 3: Per-issue loop] -- user says "done" --> [Step 4: Close out]
    |     ^                                            |
    |     |                                            v
    |   "Next issue?"                                [End]
    v     |
    +-> 3a Listen + lightly clarify (<= 3 short questions)
    +-> 3b Background Explore agent (domain language)
    +-> 3c Assess scope: single ticket or breakdown
    +-> 3d File ticket(s), apply durability + domain-language rules
    +-> 3e Print URL(s)
```

## Step 1: Detect Inputs

### 1a. Ticket sink (auto-detect, no flag)

Run sink detection silently at session start and emit a single `STACK DETECTED` line announcing the chosen sink. Ask a setup question only when required metadata, such as a Linear team, cannot be inferred.

1. **Linear** — if `mcp__linear__create_issue` is available in the tool surface, use Linear. Resolve a `LINEAR_TEAM` before the first issue is filed: use an obvious default if the workspace exposes one, use the only team if there is exactly one, otherwise ask one short session-level question for the team and reuse that answer for every issue in the intake run. If no team can be resolved, treat Linear as unavailable and continue to the next sink. (`STACK DETECTED: Linear`)
2. **SIW fallback** — else, if `siw/OPEN_ISSUES_OVERVIEW.md` and `siw/issues/` exist at the project root, file each issue as a normal General SIW issue: `siw/issues/ISSUE-G-{NNN}-qa-{slug}.md`, where `{NNN}` is the next free real `G-` issue number across both `siw/issues/ISSUE-G-*.md` and `siw/OPEN_ISSUES_OVERVIEW.md`. When scanning the overview, count only real issue rows and ignore placeholder/example text such as the `_None_` row's `(G-001)` hint. Add a matching row to the `## General` section in `siw/OPEN_ISSUES_OVERVIEW.md`, preserving the existing table schema and any section-level metadata rules below. (`STACK DETECTED: SIW (siw/issues/)`)
3. **Local fallback** — else, file each issue as `intake-issues/{NNN}-{slug}.md` at the project root, creating the `intake-issues/` directory if it does not exist. `{NNN}` is the next free number across existing `intake-issues/*.md` files; pad to 3 digits. (`STACK DETECTED: local intake-issues/`)

If none of the three sinks is writable (no Linear MCP with a resolved team, no complete SIW tracker, working tree is read-only), stop and emit `MISSING REQUIREMENT: no writable ticket sink — Linear MCP unavailable or no Linear team, no complete siw/ tracker, and project root is read-only`.

### 1b. Domain-language priming

1. Look for `UBIQUITOUS_LANGUAGE.md` at the project root and one level up. If present, read it and treat its canonical terms as the first source of vocabulary.
2. If absent, do not invent one. Domain language will instead be inferred per-issue by the background Explore agent in Step 3b.

### 1c. Optional starting context

If `$ARGUMENTS` is non-empty, treat it as the user's first issue description and skip directly to Step 3a for the first iteration. Otherwise, proceed to Step 2.

## Step 2: Open the Session

Print a one-line greeting and ask:

> What's the first issue?

Do not ask for a list, do not ask the user to pre-categorize. One issue at a time keeps the loop tight and the tickets clean.

## Step 3: Per-Issue Loop

Run this loop until the user says they are done.

### 3a. Listen and lightly clarify

Read the user's description. Ask **at most 2-3 short clarifying questions**, drawn only from this list:

- **Expected vs actual** — "What did you expect to happen, and what happened instead?" (skip if the description already states both.)
- **Steps to reproduce** — "What were you doing right before you saw it?" or "Can you reproduce it on demand, or did it happen once?"
- **Consistency** — "Does it happen every time, only sometimes, or only in one specific state?"

**Skip questions when the description already covers them.** A user who says "the save button on /settings/profile shows a green toast but the page still shows the old name on reload — every time, in Chrome and Firefox" needs zero questions.

If you find yourself wanting a fourth question, stop. Note in your head that the issue may need follow-up after filing, and proceed to file with the information you have. Emit `UNVERIFIED` for any assumption baked into the ticket.

### 3b. Explore in the background

While the user is describing or answering questions, kick off a single Explore agent **in parallel** (single Task tool call, `subagent_type=Explore`). The Explore agent's job is to learn — not to fix.

Brief it with:
- The user's description verbatim.
- The repo path.
- The instruction to report back, in under 200 words: feature purpose, the user-visible boundary of that feature, and 3-5 domain terms used in the codebase for the area in question. Explicit instruction: do **not** propose a fix and do **not** quote internal helper names that the user would not recognize.

Use the agent's report only as a vocabulary aid for the ticket body. If the report is slow or unhelpful, file the ticket using the user's own phrasing and emit `UNVERIFIED: domain-language exploration did not return in time`.

### 3c. Assess scope: single ticket or breakdown

Default to **one ticket per user report**. Break down into multiple linked tickets only when:

- The report covers two or more **independent failure modes** (e.g., "save fails AND the toast color is wrong AND keyboard navigation skips the form" — three independent things).
- The fixes would land in clearly separable parts of the system (different surfaces, different ownership, different release timing).
- The user explicitly distinguishes them ("there are kind of three things going on here").

Do **not** break down because:
- The fix has multiple steps. (Fix steps are an engineering concern, not a ticket-shape concern.)
- The bug touches two files. (File count is irrelevant to ticket shape.)
- The description is long. (Length alone does not imply multiple issues.)

For a breakdown, file the parent first, then file child issues in **dependency order**: file any blocker child before a dependent child, capture its URL or ticket ID, then file each dependent with a `Blocked by: <ticket-id>` line in its body. Before close-out, update only the parent created for this breakdown so its final body lists the child ticket IDs or URLs. Do not update pre-existing tickets.

### 3d. File the ticket(s)

Apply the **Durability Rule** and the **Domain-Language Rule** (below) when composing each body.

- **Linear**: call `mcp__linear__create_issue` with `title`, `description` (the markdown body from the templates below), `team: LINEAR_TEAM`, and any priority label suggested by the user (`low`, `medium`, `high`, `urgent`). If the user said the issue is "minor" or "not urgent" and did not give an explicit priority, attach a low-priority label or marker — do not file unlabeled. For a breakdown, after all child IDs exist, call `mcp__linear__update_issue` only for the just-created parent to add the final `## Child issues` list.
- **SIW**: write `siw/issues/ISSUE-G-{NNN}-qa-{slug}.md` using a SIW-compatible wrapper around the body:
  - Header: `# ISSUE-G-{NNN}: QA: {title}`
  - Status line: `**Status:** Ready | **Priority:** {Low|Medium|High|Urgent} | **Size:** XS | **Phase:** General | **Parallelization:** {Safe to parallelize | Must be sequential after <ticket-id> | Needs coordination} | **Related:** QA intake`. Use `Safe to parallelize` only when the ticket can start without blockers; dependent child issues with a `Blocked by` line must use `Must be sequential after <ticket-id>`.
  - Sections: include the user-visible intake body under `## Problem`, and add acceptance criteria only when they follow directly from the user's expected behavior.
  - Overview row: add `G-{NNN}` to the `## General` table in `siw/OPEN_ISSUES_OVERVIEW.md`; if the existing General section is the empty placeholder, replace it. If the section has a `**Parallelization:**` summary, recompute it from all non-placeholder `G-*` issue files: use the shared guidance when they agree, or `Mixed — see issue files for exact guidance` when they differ. If a legacy General section has no summary line, keep it absent.
  - Breakdown parent: after child files are written, update the newly-created parent file so it contains the final `## Child issues` list.
- **Local**: write `intake-issues/{NNN}-{slug}.md`. For a breakdown, apply the same final parent-child link rule as SIW.

### 3e. Continue

Print the new ticket URL(s) (or file paths for SIW/local). Then ask:

> Next issue, or are we done?

If the user says they are done — even informally ("that's it", "no more", "yeah that's the lot") — go to Step 4.

## Step 4: Close Out

Emit the end-of-run epilogue, using the plugin's standard markers:

```
CHANGES MADE: filed N tickets in <sink> — <comma-separated URLs or paths>
THINGS I DIDN'T TOUCH: existing tickets (no edits, no closes); no code changes
POTENTIAL CONCERNS: <UNVERIFIED items, breakdown links the user should sanity-check, any "minor" tickets that need a priority pass>
```

End the session.

## Issue Body Templates

### Single-issue template

```markdown
## What happened
[1-2 sentences in user-visible terms — what the user observed]

## What I expected
[1 sentence — the behavior the user was expecting]

## Steps to reproduce
1. [Step 1 in user-visible terms]
2. [Step 2 in user-visible terms]
3. **Bug:** [what happens instead]

## Additional context
- **Consistency:** [every time / sometimes / only in state X]
- **Environment:** [browser, OS, device, account type — only if mentioned]
- **Domain area:** [one or two terms from UBIQUITOUS_LANGUAGE.md or the user's own phrasing]
```

### Breakdown variant (parent + dependents)

For a parent issue that scopes the overall report:

```markdown
## What happened
[Summary of the user's report in user-visible terms]

## Scope
This intake report covers N independent failure modes. Each is filed as a separate ticket below for tracking.

## Child issues
- <ticket-id-or-url>: [one-line summary of failure mode 1]
- <ticket-id-or-url>: [one-line summary of failure mode 2]
- <ticket-id-or-url>: [one-line summary of failure mode 3]
```

For Linear, create the parent without `## Child issues` if child IDs are not known yet, then update that just-created parent with the final child list before close-out. For SIW/local, either reserve the child IDs up front or update the newly-created parent file after child files are written.

For each child issue (file these **after** the parent so the parent ID is known):

```markdown
## What happened
[1-2 sentences specific to this failure mode]

## What I expected
[1 sentence]

## Steps to reproduce
1. [Step 1]
2. [Step 2]
3. **Bug:** [what happens instead]

## Additional context
- **Parent issue:** <parent-ticket-id>
- **Blocked by:** <other-child-ticket-id> (only if there is a real ordering dependency)
- **Scope:** one slice of the parent — does not cover [the other failure modes]
```

A breakdown without a parent issue and without `Parent issue` lines on the children is invalid (see Red Flags).

## Durability Rule

Ticket bodies must survive future refactors. **Never include in the body**:

- File paths (`src/components/Foo.tsx`, `app/api/users/route.ts`).
- Line numbers or `:\d+` patterns.
- Internal helper names (private function names, internal types, generated identifiers).
- Module or package import paths.
- Branch names, commit hashes, or PR numbers from the implementation side.

**Why**: file paths and helper names move. A ticket pinned to `UserListV2.tsx:147` becomes nonsense the day someone renames the file or extracts the helper. Tickets should describe **what the user sees** and **at what user-visible boundary** — both of which outlive any given implementation.

If the user volunteers a file path, acknowledge it conversationally but do not write it into the ticket body. The Linear/SIW ticket goes into the engineering queue weeks or months later; file paths in it are misleading by then.

## Domain-Language Rule

1. If `UBIQUITOUS_LANGUAGE.md` exists, prefer its canonical terms over any aliases the user or codebase uses.
2. If no `UBIQUITOUS_LANGUAGE.md` exists, prefer the **user's own phrasing** over internal jargon pulled from the background Explore agent's report. The user's words are user-perspective by construction; internal jargon is a leak.
3. When the user uses a term and the codebase uses a different term for the same thing, write the user's term in the body and add the codebase term in `Additional context > Domain area`. The user's term is canonical for the ticket; the codebase term is the cross-reference.
4. When in doubt, repeat the user's phrasing verbatim. A ticket that uses the user's words will at worst need a rename later; a ticket that invents internal-jargon shorthand will mislead a future reader.

## Output Markers

Use these markers verbatim. One per line, uppercase, no decoration.

- **STACK DETECTED** — announce the resolved ticket sink at session start. `STACK DETECTED: Linear`.
- **PLAN** — announce the per-issue plan when an issue triggers a breakdown. `PLAN: file 1 parent + 3 children for the save / toast / a11y report`.
- **UNVERIFIED** — any claim in the ticket body that was not confirmed by the user. `UNVERIFIED: assumed the issue happens on the production tier; user only confirmed staging`.
- **MISSING REQUIREMENT** — the session cannot proceed (no writable ticket sink, user gave a description that names no observable behavior, etc.). `MISSING REQUIREMENT: no writable ticket sink available`.
- **CONFUSION** — the user's two clarifying answers contradict each other. Surface this back to the user before filing. `CONFUSION: user said "every time" and then "only after a refresh" — ask which`.
- **NOTICED BUT NOT TOUCHING** — the user mentioned an issue that is out of scope for this skill (an existing ticket, a code-level concern, a request to fix something now). `NOTICED BUT NOT TOUCHING: user asked me to fix the toast color directly — qa-intake only files tickets, deferring`.
- **CHANGES MADE / THINGS I DIDN'T TOUCH / POTENTIAL CONCERNS** — end-of-run epilogue (see Step 4).

## Common Rationalizations

Watch for these excuses — they signal the intake rubric is about to be softened.

| Excuse | Reality |
|---|---|
| "The user gave me everything I need; let me ask three more for completeness." | The skill's value is rapid intake. Three "for completeness" questions per issue is the heavy interview the user explicitly opted out of by choosing this skill over `kramme:linear:issue-define`. |
| "I'll just paste the helper name into the ticket — it's faster than translating." | The ticket lives for months; the helper name lives until the next refactor. Translate now. |
| "It's all one report from the user, so it's one ticket." | The user's report shape is not the ticket shape. Three independent failure modes means three tickets even if the user described them in one breath. |
| "The user said it's minor, so I'll skip the priority label." | Unlabeled minor issues become noise in the queue. Either tag low-priority explicitly or do not file. |
| "Linear is unreachable, but I can describe the bug clearly enough — I'll skip filing." | Skipping defeats the skill's purpose. Fall back to SIW or `intake-issues/`; do not silently drop the report. |
| "The user mentioned a file path, so I should keep it — it's helpful." | It is helpful for ten minutes and misleading for the next six months. Keep it out of the body. |

## Red Flags — STOP

Pause and resolve before filing if any of these are true:

- More than 3 clarifying questions have been asked on a single issue.
- A draft ticket body contains `:\d+`, a `src/` path, a file extension (`.ts`, `.tsx`, `.py`, `.go`, `.js`, `.jsx`), an import path, or a private helper name.
- A breakdown has been drafted without a parent issue, with child ID placeholders in the final parent body, without final child links on the parent, **or** without `Parent issue` lines on the children.
- The user described an issue as "minor" or "not urgent" but the draft ticket has no low-priority label or marker.
- The Linear sink is selected but no `LINEAR_TEAM` has been resolved.
- The SIW sink is selected but the issue file will not have a matching row in `siw/OPEN_ISSUES_OVERVIEW.md`, or the General section's existing `**Parallelization:**` summary will be left stale.
- A dependent child issue has a `Blocked by` line but its SIW status line still says `**Parallelization:** Safe to parallelize`.
- The session has produced more than 10 tickets in one sitting and the user has not paused — confirm the user is still doing intentional intake, not piling on.
- The skill is about to call `mcp__linear__update_issue` for anything except adding child links to the just-created breakdown parent, close a ticket, or write code — this skill files new tickets only.
- No writable ticket sink has been resolved and the loop is about to start anyway.

## Verification

Before ending each session, self-check:

- [ ] `STACK DETECTED` was emitted at session start with the resolved sink.
- [ ] If the sink is Linear, `LINEAR_TEAM` was resolved before the first issue was filed.
- [ ] If the sink is SIW, every new issue file has a matching `G-{NNN}` row in `siw/OPEN_ISSUES_OVERVIEW.md`, and any existing General `**Parallelization:**` summary was updated or intentionally preserved as absent.
- [ ] Each issue triggered at most 3 clarifying questions.
- [ ] Each filed body passes the durability grep: no `:\d+`, no `src/`, no file extensions, no internal helper names.
- [ ] Each filed body uses domain language from `UBIQUITOUS_LANGUAGE.md` (if present) or the user's own phrasing (if not).
- [ ] Every breakdown has a parent issue with final child links and no child ID placeholders, plus `Parent issue` lines on the children.
- [ ] Every dependent child issue with a `Blocked by` line has non-`Safe to parallelize` SIW parallelization metadata.
- [ ] Every "minor"/"not urgent" issue has a low-priority label or marker.
- [ ] No pre-existing ticket was modified or closed; any parent update only touched a ticket created during this same intake run.
- [ ] The end-of-run epilogue lists `CHANGES MADE`, `THINGS I DIDN'T TOUCH`, and `POTENTIAL CONCERNS`.
