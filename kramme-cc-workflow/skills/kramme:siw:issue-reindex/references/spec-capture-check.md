# Spec Capture Check

Use this check after the user confirms the reindex plan and before deleting any DONE issue files.

## Inputs

- The confirmed reindex scope.
- The original issue-id map, including every DONE issue selected for deletion.
- The DONE issue files from `siw/issues/`.
- `siw/LOG.md` when present.
- Active specification files directly under `siw/`, excluding the synced SIW spec-exclusion contract: `siw/LOG.md`, `siw/OPEN_ISSUES_OVERVIEW.md`, `siw/DISCOVERY_BRIEF.md`, `siw/SPEC_STRENGTHENING_PLAN.md`, `siw/AUDIT_*.md`, `siw/PRODUCT_AUDIT.md`, and `siw/SIW_*.md`.
- Supporting specification files under `siw/supporting-specs/` when present.

## Capture Procedure

1. Read each DONE issue file selected for deletion.
2. Read every `siw/LOG.md` entry that references a DONE issue id or its full issue filename.
3. Extract durable information:
   - accepted requirements or acceptance-criteria outcomes
   - design decisions and rationale
   - product, API, data model, workflow, migration, or rollout changes
   - constraints, non-goals, or follow-up work that still applies
4. Ignore transient implementation notes:
   - stale todo lists
   - progress updates with no lasting decision
   - verification command output unless it documents a permanent requirement
5. Compare each durable item with the active spec files.
6. Mark each item as one of:
   - `captured` - already represented in a spec
   - `migrated` - added to the appropriate spec during this check
   - `skip-confirmed` - intentionally not spec material, with a short reason
   - `uncertain` - unclear target, unclear durability, or conflicting spec language

## Spec Update Rules

- Update spec content where the fact belongs; do not create a history dump of completed issue notes.
- Prefer the most specific supporting spec when one exists.
- Use the main spec for cross-cutting decisions, scope boundaries, and unresolved open questions.
- Preserve existing headings, terminology, and formatting style.
- Keep migrated text concise and current-tense.
- If a DONE issue contradicts an active spec, stop and ask the user whether the spec or the completed issue reflects the intended state.

## Stop Conditions

Do not delete DONE issue files until every durable item is `captured`, `migrated`, or `skip-confirmed`.

Stop and ask the user before deletion when:

- no active spec file exists
- a durable item has no clear spec destination
- the DONE issue and spec disagree
- the DONE issue contains unresolved follow-up work that is not represented by an active issue
- a referenced DONE issue file is missing

## Reporting

Report the result before deletion:

```text
Spec Capture:
- {N} items migrated
- {M} items already captured
- {K} items skipped with confirmation
- {spec_file}: {count} migrated item(s)
```

If no durable items are found, report `All items already captured` or `No durable spec items found`.
