---
name: kramme:docs:solution-refresh
description: "Audit docs/solutions/ notes for stale solved-problem knowledge. Compares referenced files, commands, and claims against the current codebase; classifies notes as keep, update, consolidate, or delete; and requires confirmation before stale-note deletion or consolidation. Use when solution notes may have aged, code references moved, or related bugs changed the lesson. Not for creating new solution notes, ADRs, glossary entries, feature specs, or broad documentation rewrites."
argument-hint: "[solution-note-path|--all] [--apply]"
disable-model-invocation: true
user-invocable: true
---

# Solution Refresh

Audit existing solution notes in `docs/solutions/` and classify each as keep, update, consolidate, or delete. Refresh verifies that reusable solved-problem knowledge still matches the codebase.

## When to use

Use this skill when:

- A solution note references files, commands, or behavior that may have changed.
- A related bug, migration, refactor, or review suggests a note is stale or incomplete.
- Several notes may describe the same lesson and need consolidation.
- The team wants to prune or refresh `docs/solutions/` before relying on it.

Route elsewhere if:

- **Creating a new solution note** -> use `/kramme:docs:solution-note`.
- **Architecture decision drift** -> use `/kramme:docs:adr` for new decisions or supersession.
- **Domain vocabulary drift** -> use `/kramme:docs:ubiquitous-language`.
- **General docs rewrite** -> edit the target docs directly or use a docs-specific workflow.

## Artifact lifecycle

- **Produced by**: this skill does not create a separate report by default; it emits an inline refresh report and may update existing `docs/solutions/*.md` notes when confirmed.
- **Consumed by**: maintainers and future agents deciding whether a solution note can be trusted.
- **Refreshed by**: rerun this skill after referenced files move, tests change, repeated bugs invalidate the lesson, or `last_checked` is old enough to reduce confidence.
- **Retired by**: confirmed delete or consolidate actions in Phase 5.

## Argument parsing

1. Parse `$ARGUMENTS` for an optional target and flags.
2. Recognize:
   - `--all`: audit every markdown file under `docs/solutions/` (default when no path is supplied).
   - `--apply`: allow confirmed edits after the classification report.
   - A repo-relative note path under `docs/solutions/`.
3. Reject targets outside `docs/solutions/` with `CONFUSION`.
4. If `docs/solutions/` is missing or has no markdown notes, print `no solution notes found` and stop.

## Classifications

Use exactly one primary classification per note:

- `KEEP`: note still matches referenced files and current behavior. Update only `last_checked` when the user confirms an apply step.
- `UPDATE`: note is still valuable, but referenced files moved, commands changed, verification aged, or reuse cautions need correction.
- `CONSOLIDATE`: note overlaps another note enough that keeping both would split future context.
- `DELETE`: note is obsolete, misleading, or no longer has a live consumer.

Severity guidance:

- Prefer `UPDATE` over `DELETE` when a clear small edit would preserve useful knowledge.
- Prefer `CONSOLIDATE` over `DELETE` when two notes each contain useful unique details.
- Use `DELETE` only when the note's core lesson is no longer true or has no remaining consumer.

## Core workflow

### 1. Select notes

1. Resolve the repository root.
2. List candidate notes in `docs/solutions/`, sorted by path.
3. If a specific path was supplied, audit only that note.
4. Read each selected note and parse frontmatter when present.

If a note lacks the expected solution-note structure, still audit it, but classify as `UPDATE` with a format-normalization reason.

### 2. Verify references

For each note:

1. Extract `related_files` from frontmatter and repo-relative paths from the "Code references" section.
2. Check whether referenced files exist.
3. For missing files, search likely new locations by basename or nearby symbols before marking stale.
4. Search changed code or referenced symbols only as deeply as needed to confirm whether the note still applies.
5. Check tests or commands named in "Tests / verification" when cheap and safe. If running them would be expensive, mark the result `UNVERIFIED:` in the report instead of pretending.

### 3. Detect overlap

Compare selected notes and nearby notes in `docs/solutions/` for:

- Same problem phrased with different slugs.
- Same code references.
- Same final approach.
- One note being a narrower case of another.

When overlap is plausible but not proven, classify as `UPDATE` with a `CONFUSION` note rather than forcing consolidation.

### 4. Emit the refresh report

Emit one inline report with this shape:

```markdown
SOLUTION REFRESH REPORT

- `docs/solutions/example.md` — UPDATE
  Reason: referenced file moved from `old/path.ts` to `new/path.ts`.
  Evidence: `new/path.ts` contains the same helper name.
  Proposed action: update Code references and set `last_checked` to YYYY-MM-DD.
```

Every `UPDATE`, `CONSOLIDATE`, or `DELETE` classification needs a concrete reason and evidence. `KEEP` needs a short confidence note.

### 5. Apply confirmed changes

Do not mutate files unless `--apply` is present or the user explicitly asks to apply the report.

When applying:

1. Emit `PLAN:` listing every file to edit, delete, or consolidate.
2. For `KEEP`, update only `last_checked` if the user wants bookkeeping updates.
3. For `UPDATE`, edit only stale sections and frontmatter. Preserve user-authored detail.
4. For `CONSOLIDATE`, ask with `ASK FIRST` before merging content or deleting either note.
5. For `DELETE`, ask with `ASK FIRST` before deleting. Surface the note path and one-line reason.

Deletion and consolidation always require explicit confirmation, even with `--apply`.

## Markers

Use these markers exactly when they apply:

- `CONFUSION`: target path is invalid, note format is unclear, or overlap is plausible but ambiguous.
- `UNVERIFIED`: a claim, command, or behavior was not checked.
- `NOTICED BUT NOT TOUCHING`: adjacent docs or notes are related but out of scope.
- `PLAN`: any apply step that edits, deletes, or consolidates files.
- `ASK FIRST`: every delete or consolidate action, and any update that rewrites core reuse guidance.

## Verification

Before declaring refresh done, self-check:

- [ ] Every selected note was classified as KEEP, UPDATE, CONSOLIDATE, or DELETE.
- [ ] Every non-KEEP classification includes evidence.
- [ ] Missing file references were searched by basename or symbol before being marked stale.
- [ ] No note outside `docs/solutions/` was edited.
- [ ] No delete or consolidation happened without explicit confirmation.
- [ ] `last_checked` was updated only for notes actually checked.
- [ ] ADR-worthy decisions and glossary changes were routed to their own skills, not silently edited here.
