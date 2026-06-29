# Implementation Audit Error Handling

Load this reference only when one of these error cases occurs.

## Spec File Errors

- File not found: Warn and skip, continue with remaining files.
- File empty or unreadable: Warn, suggest checking file path.

## No Requirements Extracted

- If spec has no clear structure: Offer best-effort scan or abort.
- If all requirements fall into a single group: Proceed with one agent instead of many.

## Explore Agent Failures

- If an agent returns incomplete results: Note affected requirements as "Uncertain" in the report.
- If an agent times out: Report which spec section was affected, suggest re-running with narrower scope.
- If Pass B2 is required but fails to run: mark audit BLOCKED and do not write report.

## Conflicting Findings

If contradictions remain after tie-break, mark audit BLOCKED and do not write report.

## Incomplete Coverage Matrix

If any section row is incomplete, mark audit BLOCKED and do not write report.

## SIW Workflow Not Active

- Skip issue creation in Step 9.
- Report file goes to the project root instead of `siw/`.
- All other steps work the same.
