---
name: kramme:pr:autoreview
description: "Runs kramme:pr:code-review as a closeout review loop for local or PR branch changes before commit, ship, or final response. Use when the user asks for autoreview, second-model review, or a final code-review pass after non-trivial edits. Not for UX, visual, accessibility, or product review."
argument-hint: "[code-review args] [--base <branch>] [--inline] [--parallel]"
disable-model-invocation: true
user-invocable: true
---

# Auto Review

Run the local structured PR code review as a closeout check, then verify and handle any actionable findings. This skill adapts the OpenClaw `autoreview` workflow to the Kramme review stack by delegating the review itself to `kramme:pr:code-review`.

## Use When

- The user asks for `autoreview`, a final code-review pass, or second-model review.
- Non-trivial code edits are ready for closeout before final response, commit, push, or PR creation.
- A local branch or PR branch needs another review pass after fixes.

Do not use this for UX, visual, accessibility, or product review. Use `kramme:pr:ux-review`, `kramme:visual:*`, or `kramme:pr:product-review` instead.

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

1. **Prepare arguments**
   - Treat `$ARGUMENTS` as arguments for `kramme:pr:code-review`.
   - Pass through supported review arguments such as aspect names, `--base <branch>`, `--inline`, `--parallel`, `parallel`, and `--emphasize <dimension>`.
   - If no arguments are provided, run the default full `kramme:pr:code-review` workflow.

2. **Run the delegated review**
   - Invoke `/kramme:pr:code-review $ARGUMENTS`.
   - If slash-skill invocation is unavailable, read the sibling skill file at `../kramme:pr:code-review/SKILL.md` and follow that workflow with the same arguments.
   - Do not duplicate the reviewer taxonomy, diff collection, relevance validation, or report formatting here; those belong to `kramme:pr:code-review`.

3. **Read the review result**
   - If `--inline` was used, inspect the inline review response.
   - Otherwise read `REVIEW_OVERVIEW.md` from the project root.
   - If the delegated review reports degraded coverage or failed reviewers, tell the user which dimensions were not covered before acting on findings.

4. **Triage findings**
   - For each Critical or Important finding, verify the evidence in the code before accepting it.
   - Reject findings that are pre-existing, out of scope, already addressed, unverified without a concrete failure path, or inconsistent with local patterns.
   - Keep manual findings as manual unless the missing context can be resolved locally without guessing.
   - Treat Suggestions and FYI as optional unless the user asked for a stricter cleanup pass.

5. **Resolve accepted findings**
   - For verified `gated_auto` Critical or Important findings, use `/kramme:pr:resolve-review` when it fits the report's recommended action.
   - If `--inline` was used, pass the inline review content to `/kramme:pr:resolve-review` or make the smallest scoped fix directly; do not rely on local review-file discovery.
   - For verified findings that need hand edits, make the smallest scoped fix directly.
   - Do not resolve manual findings without enough product, ownership, or reviewer context.

6. **Verify and rerun**
   - Run focused tests, type checks, lint, or build commands that cover the code changed while resolving review findings.
   - Rerun `/kramme:pr:code-review $ARGUMENTS` after review-triggered code changes.
   - Continue until there are no accepted/actionable Critical or Important findings, or report the remaining manual/advisory items clearly.

## Artifact Lifecycle

- `kramme:pr:code-review` produces `REVIEW_OVERVIEW.md` by default unless `--inline` is used.
- `kramme:pr:resolve-review` consumes `REVIEW_OVERVIEW.md` when resolving eligible file-backed findings, or explicit inline review content when `--inline` was used.
- Rerunning this skill refreshes the delegated review report.
- `/kramme:workflow-artifacts:cleanup` retires `REVIEW_OVERVIEW.md` when the review artifact is no longer needed.

## Examples

```text
/kramme:pr:autoreview
/kramme:pr:autoreview --parallel
/kramme:pr:autoreview tests errors --base origin/main
/kramme:pr:autoreview --inline --emphasize security
```
