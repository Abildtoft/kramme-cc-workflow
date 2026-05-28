---
name: kramme:docs:update-agents-md
description: This skill should be used when the user asks to "update AGENTS.md", "add to AGENTS.md", "maintain agent docs", or needs to add guidelines to agent instructions. Guides discovery of local skills and enforces structured, keyword-based documentation style.
user-invocable: false
disable-model-invocation: false
---

# Adding to AGENTS.md

AGENTS.md is the canonical agent-facing documentation. If a project uses `CLAUDE.md` or another equivalent instruction file instead, apply the same structure there. Many rules are OK.

## Context Pointer Model

Use `AGENTS.md` as a routing map, not a warehouse. A Context Pointer is a concise link from an agent-facing rule to deeper context: a skill, doc, script, module, test suite, schema, runbook, ADR, or example file.

A strong Context Pointer includes:

- **Target** — the exact file, command, module, or skill to open or run
- **Trigger** — when the agent should follow it
- **Purpose** — what the target answers or governs

Prefer Context Pointers when the detail would make `AGENTS.md` long, duplicate another source of truth, or apply only to a subset of tasks.

## Before Writing

Resolve the target file first:

- Detect existing instruction files: `AGENTS.md`, `CLAUDE.md`, or another equivalent.
- If several exist, prefer `AGENTS.md`; mirror rules into the others only when the project already keeps them in sync.
- If none exists, create `AGENTS.md`.
- **ALWAYS** read the chosen file in full before proposing edits, so additions reconcile with what is already there.
- **ALWAYS** show the planned additions (or a diff) and apply them after confirmation — this file governs all future agent behavior.

Discover local skills to reference (skill directories vary by harness — adjust paths to the local layout):

```bash
find .claude/skills .agents -name "SKILL.md" 2> /dev/null
ls plugins/*/skills/*/SKILL.md 2> /dev/null
```

Read each skill's frontmatter to understand when to reference it.

Map existing context before editing:

```bash
find . -maxdepth 3 \
  \( -type d \( -name ".git" -o -name ".context" -o -name "node_modules" -o -name "dist" -o -name "build" -o -name ".next" -o -name ".nuxt" -o -name "coverage" -o -name ".venv" -o -name "venv" -o -name "target" \) -prune \) -o \
  -type f \( -name "*.md" \) -print 2> /dev/null
find . -maxdepth 3 \
  \( -type d \( -name ".git" -o -name ".context" -o -name "node_modules" -o -name "dist" -o -name "build" -o -name ".next" -o -name ".nuxt" -o -name "coverage" -o -name ".venv" -o -name "venv" -o -name "target" \) -prune \) -o \
  -type f \( -name "*schema*" -o -name "*registry*" -o -name "*routes*" -o -name "index.*" \) -print 2> /dev/null
```

Identify existing docs, scripts, modules, examples, and skills that should be pointed to instead of duplicated.

## Guideline Keywords

Use these keywords to indicate requirement strength:

- **ALWAYS** — Mandatory requirement
- **NEVER** — Strong prohibition
- **PREFER** — Strong recommendation, exceptions allowed
- **CAN** — Optional, developer's discretion
- **NOTE** — Context or clarification
- **EXAMPLE** — Illustrative example

Strictness hierarchy: ALWAYS/NEVER > PREFER > CAN > NOTE/EXAMPLE

## Writing Rules

- **Existing sections first** - Only propose new sections if no appropriate existing section exists
- **Reconcile, don't append** - Before adding a rule or Context Pointer, check whether an equivalent already exists; update it in place instead of duplicating. Re-running this skill must not create duplicate rules or sections
- **One rule per bullet** - Keep each guideline minimal and atomic
- **Start with keyword** - Every rule begins with ALWAYS/NEVER/PREFER/CAN/NOTE
- **Headers + bullets** - No paragraphs
- **Code blocks** - For commands and templates
- **Reference, don't duplicate** - Point to skills: "See `.claude/skills/db-migrate/SKILL.md`"
- **Context Pointers over pasted detail** - Point to deeper docs, scripts, modules, tests, schemas, or ADRs with a clear when/why cue
- **One hop** - Important pointers should be directly visible from the active agent instruction file; avoid chains of documents that only point to more documents
- **No filler** - No intros, conclusions, or pleasantries

## After Writing

- Re-read the edited region.
- **ALWAYS** confirm each new bullet starts with a keyword and states exactly one rule.
- **ALWAYS** confirm no rule or section was duplicated.

## Common Sections

Add sections as needed for the project:

### Context Map

Use this when the repo has multiple important docs, skills, scripts, or subsystems:

```markdown
## Context Map

- **ALWAYS** read `docs/architecture.md` before changing module boundaries
- **ALWAYS** run `scripts/verify.sh` before claiming local verification; see `docs/testing.md` only for suite-specific details
- **PREFER** `packages/api/src/routes/index.ts` as the entry point for API route discovery
- **CAN** use `.claude/skills/db-migrate/SKILL.md` when changing database migrations
```

### When Stuck

```markdown
## When Stuck

- **ALWAYS** ask a clarifying question or propose alternatives
- **NEVER** initiate large speculative changes without confirmation
```

### Git Commits

```markdown
## Git Commits

- **ALWAYS** write succinct commit messages in imperative mood
- **ALWAYS** keep the first line short
- **NEVER** mention that you are an AI
```

### Issue Management

```markdown
## Linear Issues

- **NEVER** change issue status without explicit instruction
- **NEVER** create issues without explicit instruction
```

### Package Manager

```markdown
## Package Manager

Use **pnpm**: `pnpm install`, `pnpm dev`, `pnpm test`
```

### Local Skills

Reference each discovered skill:

```markdown
## Database

Use `db-migrate` skill. See `.claude/skills/db-migrate/SKILL.md`
```

### Domain-Specific Sections

Add sections for each tech stack (Frontend, Backend, etc.) with domain-specific guidelines.

## Anti-Patterns

Omit these:

- "Welcome to..." or "This document explains..."
- Obvious instructions ("run tests", "write clean code")
- Explanations of why (just say what)
- Long prose paragraphs
- Content duplicated from skills (reference instead)
- Link dumps without a trigger or purpose
- Deep pointer chains where the active agent instruction file points to a doc that only points elsewhere
