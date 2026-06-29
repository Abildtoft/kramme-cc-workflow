# Issue Numbering Reference

Use phase-prefixed numbering for clear organization:

- Phase 1 tasks: `ISSUE-P1-001`, `ISSUE-P1-002`, `ISSUE-P1-003`, ...
- Phase 2 tasks: `ISSUE-P2-001`, `ISSUE-P2-002`, ...
- General tasks: `ISSUE-G-001`, `ISSUE-G-002`, ... for cross-cutting concerns like setup, tooling, and documentation.

## Identifier Stability

Issue IDs are stable once issue files are written.

- During draft planning before Phase 6 writes files, proposed IDs may be reshaped as the plan is reviewed.
- After files exist, ordinary append, refinement, deletion, splitting, or deepening must not renumber existing issues just to close gaps.
- When splitting an existing concept, keep the original ID on the original concept and assign the next unused number in that prefix group to the split-out concept.
- When deleting or replacing a concept outside the explicit Replace flow, leave numbering gaps in place.
- Intentional cleanup and renumbering belongs to `/kramme:siw:issue-reindex`; do not duplicate that workflow here.

