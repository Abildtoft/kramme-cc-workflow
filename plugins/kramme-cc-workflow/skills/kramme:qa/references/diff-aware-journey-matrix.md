# Diff-Aware Journey Matrix

Use this matrix in `diff-aware` QA before running browser or code-only checks. It turns changed UI files into explicit user journeys, and it prevents route selection from becoming implicit or speculative.

## Matrix columns

| Column | Meaning |
| --- | --- |
| Route / screen | URL path or named screen under test. Use `UNVERIFIED: {guess}` when mapping is uncertain. |
| Journey | User task or flow to exercise, such as "open detail view", "submit settings form", or "empty-state list". |
| Changed files | Files that made this route or journey relevant. |
| State / data setup | Required auth state, feature flag, seeded data, empty state, error state, or external condition. |
| Expected behavior | Observable behavior that proves the changed code works. |
| Evidence | Screenshot, console/network notes, accessibility tree note, static-code note, or skipped reason. |
| Result | Pass, fail, blocked, skipped, or code-only. |
| Follow-up | Finding ID, issue reference, or "none". |

## Rules

- Start with changed files, then map to routes, screens, or components. Do not choose routes only because they are easy to load.
- Mark uncertain file-to-route mappings as `UNVERIFIED` and test them only after stating the assumption.
- Include at least one normal state and one likely edge state for each changed user-facing surface when practical.
- Ask before destructive journeys such as deleting production-like data, sending emails, charging cards, changing billing, or mutating shared records.
- If browser MCP is unavailable, keep the matrix and set results to `code-only` with evidence from the source files that were inspected.
- Do not auto-fix or auto-commit QA findings by default. Record follow-up issues or recommended fixes in the report.
