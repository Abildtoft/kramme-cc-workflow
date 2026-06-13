---
name: kramme:docs:solution-note
description: "Create a reusable solved-problem note in docs/solutions/ after a bug fix, migration, repeated workflow, tricky refactor, or implementation lesson. Captures problem context, failed approaches, final approach, code references, verification, and reuse cautions so future sessions can apply the pattern. Use when the lesson should outlive chat or PR context. Not for long-lived architecture decisions (use kramme:docs:adr), domain vocabulary (use kramme:docs:ubiquitous-language), feature specs, or rejected enhancement scope."
argument-hint: "[problem, lesson, or context]"
disable-model-invocation: true
user-invocable: true
---

# Solution Note

Create a reusable solved-problem note in `docs/solutions/<slug>.md`. A solution note records what failed, what worked, when to reuse it, and when not to.

## When to use

Use this skill when a completed or mostly-understood problem produced a reusable lesson:

- A bug fix revealed a repeatable diagnosis or repair pattern.
- A migration exposed a reliable sequence, compatibility trap, or rollback rule.
- A refactor found a safer implementation approach after failed attempts.
- A repeated manual workflow needs durable, codebase-local memory.
- A PR, incident, or review surfaced "next time, do it this way" knowledge.

Route elsewhere if:

- **Long-lived architecture decision** -> use `/kramme:docs:adr`; ADRs record decisions and alternatives, not repeatable solved-problem playbooks.
- **Domain vocabulary** -> use `/kramme:docs:ubiquitous-language`; glossaries define terms, not implementation lessons.
- **Feature planning** -> use `/kramme:docs:feature-spec`.
- **Rejected enhancement** -> use `/kramme:docs:out-of-scope`.
- **Session progress summary** -> keep it in the active project log or repo-local notes; do not create a solution note for ordinary status.

## Artifact lifecycle

- **Produced by**: Phase 4 writes `docs/solutions/<slug>.md` from `assets/solution-note-template.md`.
- **Consumed by**: future agents, maintainers, review workflows, debugging sessions, migration plans, and refactor passes that search `docs/solutions/` for prior solved problems.
- **Refreshed by**: `/kramme:docs:solution-refresh` when referenced files move, code behavior changes, verification ages, or a related bug proves the note incomplete.
- **Retired by**: `/kramme:docs:solution-refresh` after explicit user confirmation to delete or consolidate stale notes.

## Argument parsing and slug rule

1. Treat `$ARGUMENTS` as the proposed title, problem summary, or source context.
2. If no arguments are provided, infer the candidate topic from the current conversation and recent user request.
3. Derive the slug from the note title: lowercase, replace spaces and underscores with hyphens, strip characters outside `[a-z0-9-]`, collapse repeated hyphens, trim leading/trailing hyphens.
4. Keep slugs short enough to scan. Prefer 3-7 words.
5. If the slug is empty, emit `MISSING REQUIREMENT` and ask for a concrete problem or lesson name before writing.

## Core workflow

### 1. Gather grounded context

Read only the context needed to make the note accurate:

1. Use the current conversation and `$ARGUMENTS` first.
2. Inspect recent local changes when relevant (`git diff --stat`, focused `git diff`, or changed files named by the user).
3. Search existing notes with `ls docs/solutions/` and `rg -n "<key terms>" docs/solutions/` if the directory exists.
4. Read nearby source files only when they are needed to verify code references or understand the final approach.

If the note would rest on unverified claims, mark them inline with `UNVERIFIED:` rather than presenting them as facts.

### 2. Apply the reusable-lesson gate

Before writing, confirm the note has these minimum ingredients:

- The problem or failure mode.
- The context or preconditions where the lesson applies.
- At least one failed or rejected approach, including "do nothing" if that was the real alternative.
- The final approach.
- Relevant code references, commands, docs, or "No code reference; process-only lesson" when appropriate.
- Verification evidence or a clear `UNVERIFIED:` gap.
- Reuse cautions naming when not to apply the pattern.

Emit `MISSING REQUIREMENT` and ask for the missing item when any load-bearing ingredient is absent.

### 3. Prevent duplicates

If `docs/solutions/` already exists:

1. Search for notes with similar slug words, problem names, or code references.
2. If an existing note likely covers the same lesson, emit `CONFUSION` and ask whether to update that note, create a new narrower note, or stop.
3. If the existing note is adjacent but not the same, emit `NOTICED BUT NOT TOUCHING` with its path and why the new note remains separate.

Never overwrite an existing solution note without explicit user confirmation.

### 4. Draft and write

1. Read `assets/solution-note-template.md`.
2. Create `docs/solutions/` if missing.
3. Fill every placeholder with grounded content. Do not leave `TODO`, angle-bracket placeholders, or invented file paths.
4. Set frontmatter:
   - `title`: human-readable note title.
   - `date`: today's absolute date.
   - `status`: `active` for reusable current notes; `draft` only when the user explicitly asks for an incomplete note.
   - `source`: `current-session`, `bug-fix`, `migration`, `review`, `incident`, `refactor`, or another short source label.
   - `related_files`: YAML list of repo-relative files, or `[]`.
   - `last_checked`: today's absolute date.
5. Write to `docs/solutions/<slug>.md`.

Emit a concise `PLAN:` block before writing when the note will touch an existing file or when the lesson spans more than one subsystem.

### 5. Route vocabulary updates separately

If the solution note introduces or clarifies project-specific domain terms, emit an optional handoff:

```
NOTICED BUT NOT TOUCHING: this note introduces domain terms that may belong in UBIQUITOUS_LANGUAGE.md: <terms>
Why skipping: solution notes record repeatable solved-problem knowledge; use /kramme:docs:ubiquitous-language for canonical vocabulary.
```

Do not edit the glossary inside this workflow unless the user explicitly asks.

## Markers

Use these markers exactly when they apply:

- `MISSING REQUIREMENT`: the note lacks a load-bearing section or slug.
- `CONFUSION`: duplicate notes, unclear scope, or "one note or several" ambiguity.
- `UNVERIFIED`: factual claim, command result, metric, or code behavior has not been checked.
- `NOTICED BUT NOT TOUCHING`: related docs, terms, or adjacent lessons are outside this note.
- `PLAN`: multi-file or existing-note edits need an edit plan before writing.
- `ASK FIRST`: updating an existing note, renaming an existing note, or changing committed reuse guidance.

## Verification

Before declaring the note done, self-check:

- [ ] File lives under `docs/solutions/`.
- [ ] Filename slug is readable and non-empty.
- [ ] Frontmatter has `title`, `date`, `status`, `source`, `related_files`, and `last_checked`.
- [ ] Note includes Problem, Context, When this applies, Failed approaches, Final approach, Code references, Tests / verification, and Reuse cautions.
- [ ] No placeholders remain.
- [ ] Every code reference is repo-relative and exists, or the note explicitly says why no code reference applies.
- [ ] Duplicate-note search was performed when `docs/solutions/` already existed.
- [ ] ADR-worthy decisions were routed to `/kramme:docs:adr` instead of being buried only in the note.
- [ ] Glossary updates were only offered, not edited inline.
