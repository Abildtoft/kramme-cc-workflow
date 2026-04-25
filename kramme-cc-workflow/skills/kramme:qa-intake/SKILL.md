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

- **DOES**: ask short clarifying questions, explore the codebase for domain language, file new Linear/SIW/local tickets, link blockers in compound breakdowns.
- **DOES NOT**: write code, modify existing tickets, close tickets, propose or implement fixes, run live-app QA against a URL.

**Linear Issue Creation Override**: invoking this command IS explicit instruction to create new Linear issues. When the user has confirmed an issue scope inside the per-issue loop, proceed directly with `mcp__linear__create_issue` without a separate "may I create the ticket?" gate — the user is in-session and approval is implicit in their continued participation.

## When to Use

- The user has a list of bugs in their head from a manual QA pass and wants to log all of them quickly.
- Some or all of the issues do not have a reproducible URL trace (workflow gaps, missing features, ambiguous design problems, edge cases the user hit but cannot describe as a route).
- The user wants tickets written from a user-perspective viewpoint that will survive future refactors.

## When NOT to Use

- **Live-app browser testing** — the user wants automated probing of a running URL with screenshots, network triage, and an a11y ladder. Use `kramme:qa` instead.
- **Single-bug deep root-cause investigation and fix** — the user wants to reproduce, isolate, trace data flow, and apply a code fix. Use `kramme:debug:investigate` instead.
- **One well-refined ticket** — the user has one issue and wants the full 5-round structured interview that produces a comprehensive, polished Linear issue. Use `kramme:linear:issue-define` instead.
- **Editing or closing tickets** — this skill files new tickets only. For improving an existing Linear issue, use `kramme:linear:issue-define` in improve mode.

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

### 1a. Ticket sink (auto-detect, no flag, no per-session prompt)

Run this detection silently at session start and emit a single `STACK DETECTED` line announcing the chosen sink.

1. **Linear** — if `mcp__linear__create_issue` is available in the tool surface, use Linear. (`STACK DETECTED: Linear`)
2. **SIW fallback** — else, if a `siw/` directory exists at the project root, file each issue as `siw/issues/ISSUE-QA-{NNN}-{slug}.md`, where `{NNN}` is the next free number across `siw/issues/ISSUE-QA-*.md`. (`STACK DETECTED: SIW (siw/issues/)`)
3. **Local fallback** — else, file each issue as `intake-issues/{NNN}-{slug}.md` at the project root, creating the `intake-issues/` directory if it does not exist. Same numbering rule. (`STACK DETECTED: local intake-issues/`)

If none of the three sinks is writable (no Linear MCP, no `siw/`, working tree is read-only), stop and emit `MISSING REQUIREMENT: no writable ticket sink — Linear MCP unavailable, no siw/ folder, and project root is read-only`.

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

For a breakdown, file in **dependency order**: file the blocker first, capture its URL or ticket ID, then file each dependent with a `Blocked by: <ticket-id>` line in its body.

### 3d. File the ticket(s)

Apply the **Durability Rule** and the **Domain-Language Rule** (below) when composing each body.

- **Linear**: call `mcp__linear__create_issue` with `title`, `description` (the markdown body from the templates below), and any priority label suggested by the user (`low`, `medium`, `high`, `urgent`). If the user said the issue is "minor" or "not urgent" and did not give an explicit priority, attach a low-priority label or marker — do not file unlabeled.
- **SIW**: write `siw/issues/ISSUE-QA-{NNN}-{slug}.md` with the body. The `{NNN}` is the next free number across existing `ISSUE-QA-*.md` files; pad to 3 digits.
- **Local**: write `intake-issues/{NNN}-{slug}.md`.

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

## Children
- <ticket-id>: [one-line summary of failure mode 1]
- <ticket-id>: [one-line summary of failure mode 2]
- <ticket-id>: [one-line summary of failure mode 3]
```

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
- A breakdown has been drafted without a parent issue **or** without `Parent issue` lines on the children.
- The user described an issue as "minor" or "not urgent" but the draft ticket has no low-priority label or marker.
- The session has produced more than 10 tickets in one sitting and the user has not paused — confirm the user is still doing intentional intake, not piling on.
- The skill is about to call `mcp__linear__update_issue`, close a ticket, or write code — this skill files new tickets only.
- No writable ticket sink has been resolved and the loop is about to start anyway.

## Verification

Before ending each session, self-check:

- [ ] `STACK DETECTED` was emitted at session start with the resolved sink.
- [ ] Each issue triggered at most 3 clarifying questions.
- [ ] Each filed body passes the durability grep: no `:\d+`, no `src/`, no file extensions, no internal helper names.
- [ ] Each filed body uses domain language from `UBIQUITOUS_LANGUAGE.md` (if present) or the user's own phrasing (if not).
- [ ] Every breakdown has a parent issue and `Parent issue` lines on the children.
- [ ] Every "minor"/"not urgent" issue has a low-priority label or marker.
- [ ] No existing ticket was modified or closed.
- [ ] The end-of-run epilogue lists `CHANGES MADE`, `THINGS I DIDN'T TOUCH`, and `POTENTIAL CONCERNS`.
