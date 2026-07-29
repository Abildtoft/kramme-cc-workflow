# Closeout Convergence Loop

Apply this workflow only when the caller passed `--loop`. The review this skill just produced is the first pass; do not launch a separate wrapper skill.

## Contract

- Treat review output as advisory. Never apply a finding blindly.
- Verify every accepted finding against the real code path and adjacent files before changing code.
- Reject speculative risks, unrealistic edge cases, broad rewrites, and fixes that do not fit the local codebase.
- Prefer the smallest fix at the correct ownership boundary.
- If an accepted finding reveals a repeated bug class, inspect the current review scope for sibling instances before fixing.
- If a review-triggered fix changes code, rerun focused verification and rerun the review.
- Stop when the rerun has no accepted/actionable Critical or Important findings, or when remaining findings are clearly manual/advisory and reported as such.
- Do not push changes unless the user explicitly asked for push, ship, or PR update.

## Workflow

1. **Read the review result**
   - If `--inline` was used, inspect the inline review response.
   - Otherwise, read `REVIEW_OVERVIEW.md` from the project root.
   - If the review reports degraded coverage or failed reviewers, tell the user which dimensions were not covered before acting on findings.

2. **Triage findings**
   - For each Critical or Important finding, verify the evidence in the code before accepting it.
   - Reject findings that are pre-existing, out of scope, already addressed, unverified without a concrete failure path, or inconsistent with local patterns.
   - Keep manual findings as manual unless the missing context can be resolved locally without guessing.
   - Treat Suggestions and FYI as optional unless the user asked for a stricter cleanup pass.

3. **Resolve accepted findings**
   - For verified `gated_auto` Critical or Important findings, use `/kramme:pr:resolve-review --severity critical,important` when it fits the report's recommended action. The severity filter keeps this loop from processing suggestion-severity advisory findings it never triaged.
   - If `--inline` was used, pass the inline review content to `/kramme:pr:resolve-review` or make the smallest scoped fix directly; do not rely on local review-file discovery.
   - For verified findings that need hand edits, make the smallest scoped fix directly.
   - Do not resolve manual findings without enough product, ownership, or reviewer context.

4. **Verify and rerun**
   - Run focused tests, type checks, lint, or build commands that cover the code changed while resolving review findings.
   - After review-triggered code changes, rerun this skill's review phase with the same normalized review arguments. Do not add `--loop` to the nested review invocation; return to this workflow after the new result is ready.
   - Continue until there are no accepted/actionable Critical or Important findings, or report the remaining manual/advisory items clearly.

## Artifact Lifecycle

- This skill produces `REVIEW_OVERVIEW.md` by default unless `--inline` is used.
- `/kramme:pr:resolve-review` consumes `REVIEW_OVERVIEW.md` when resolving eligible file-backed findings, or explicit inline review content when `--inline` was used.
- Each rerun refreshes the review report.
- `/kramme:workflow-artifacts:cleanup` retires `REVIEW_OVERVIEW.md` when the review artifact is no longer needed.
