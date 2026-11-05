# Closeout Convergence Loop

Apply this workflow only when `LOOP_MODE` is true, which requires the user's own `--loop` request under the rule in `SKILL.md`. The review this skill just produced is the first pass; do not launch a separate wrapper skill.

## Contract

- Reuse the reviewer model selected under `${CLAUDE_PLUGIN_ROOT}/shared/pr-review/references/model-selection.md` for review reruns and the independent termination verifier. Do not step down again or apply this policy to implementation/resolver agents.
- Treat review output as advisory. Never apply a finding blindly.
- Verify every accepted finding against the real code path and adjacent files before changing code.
- Weigh each finding's likelihood, how severe and reversible its harm would be, and how much complexity its fix adds. Fix probable defects, and improbable ones whose harm would be severe or hard to undo, such as lost or corrupted data, a security exposure, or wrong monetary amounts. Decline a finding only when its failure is improbable, its harm can be undone, and its fix costs more complexity than the risk is worth.
- Reject broad rewrites and fixes that do not fit the local codebase.
- Prefer the smallest fix at the correct ownership boundary.
- If an accepted finding reveals a repeated bug class, inspect the current review scope for sibling instances before fixing.
- If a review-triggered fix changes code, rerun focused verification and rerun the review.
- The agent that applied the fixes is not the sole judge of loop termination. Delegate the accept/terminate assessment to an independent verifier as described in step 4.
- Stop when the rerun has no accepted/actionable Critical or Important findings, or when remaining findings are clearly manual/advisory and reported as such.
- Do not push changes unless the user explicitly asked for push, ship, or PR update.

## Workflow

1. **Read the review result**
   - Before acting or declaring termination, run the producer execution helper's `check` against the exact latest report and normalized aspects as defined in `references/execution-contract.md`. Missing, incomplete, filtered-to-a-different-scope, or stale evidence blocks this loop, even when no findings remain. Report the incomplete run and recovery needed; do not certify termination from a partial review. Every rerun needs a fresh run directory and seal.
   - If `--inline` was used, inspect the inline review response.
   - Otherwise, read `REVIEW_OVERVIEW.md` from the project root.
   - If the review reports degraded coverage or failed reviewers, tell the user which dimensions were not covered before acting on findings.

2. **Triage findings**
   - For each Critical or Important finding, verify the evidence in the code before accepting it.
   - Reject findings that are pre-existing, out of scope, already addressed, unverified without a concrete failure path, or inconsistent with local patterns.
   - Check each finding against the task intent, meaning the PR description or stated requirements, as well as the code path. A finding that contradicts an explicit scope decision can be declined for that reason.
   - Decline a protected-subject finding only with the refuting evidence that `Protected-subject findings` in `references/review-discipline.md` requires.
   - Record a one-sentence reason, keyed by finding ID, for every Critical or Important finding you decline. Step 4 passes these to the verifier, and step 5 reports them.
   - Keep manual findings as manual unless the missing context can be resolved locally without guessing.
   - Treat Suggestions and FYI as optional unless the user asked for a stricter cleanup pass.

3. **Resolve accepted findings**
   - Fix each verified `gated_auto` Critical or Important finding with the smallest scoped change that follows its recommended action. Leave Suggestion and FYI findings this loop never triaged untouched.
   - Do not invoke `trackbed:pr:resolve-review` from this loop; it is not an authorized model parent of that skill. When eligible findings remain for a later pass, recommend `/trackbed:pr:resolve-review` to the user in the final report.
   - Do not resolve manual findings without enough product, ownership, or reviewer context.

4. **Verify, rerun, and gate termination**
   - Run focused tests, type checks, lint, or build commands that cover the code changed while resolving review findings.
   - After review-triggered code changes, rerun this skill's review phase with the same normalized review arguments. Restore `--subagent-model <model>` from a non-empty `SUBAGENT_MODEL_OVERRIDE` in every nested review invocation; preserve explicit `inherit` as well. Do not add `--loop` to the nested review invocation; return to this workflow after the new result is ready.
   - Before stopping the loop, delegate the accept/terminate assessment to an independent verifier with its own context window. This gate runs on every termination path, including when step 2 rejected every finding and no rerun happened. Skip it only when the latest review reported no Critical or Important findings at all, since there is no accept/reject judgment to check.
     - **Claude Code:** run the assessment in a subagent.
     - **Codex:** run the assessment in an equivalent task sub-agent.
     - **Fallback:** if neither mechanism is available, perform the assessment yourself and state in the final output that loop termination was self-certified because independent verification was unavailable. Do not present a self-certified stop as an independently verified one.
     - **Failed verifier:** self-certification is only for a host with no independent mechanism. If a launched verifier fails, times out, or returns a cut-off or unfinished assessment, report loop termination as unverified, never as clean. Do not substitute your own assessment, and do not switch to another mechanism or relaunch just to get a different answer; one retry of the same mechanism after a launch failure is fine.
   - Give the verifier the current diff, the PR description or stated requirements, the prior findings, every finding you rejected in step 2 with the evidence behind each rejection, and the latest review result; do not give it your justification for each fix or your own recommendation to stop. Ask it to state what it assessed and what it could not, and treat a reply without that statement as unfinished.
   - Continue until the independent verifier reports no accepted/actionable Critical or Important findings, or report the remaining manual/advisory items clearly.
   - If the verifier re-raises a finding you already rejected and re-rejected on the evidence, stop the loop and report it as an unresolved reviewer disagreement with both positions. Do not keep looping on a finding neither side will move on.

5. **Report the loop outcome**
   - End every loop run with a three-block summary in the final chat response, after the verifier's verdict and before the closing `Reviewers launched` lines that `SKILL.md` Step 12b requires. Keep it out of `REVIEW_OVERVIEW.md`, because the seal covers the exact report bytes.
   - `CHANGES MADE`: each file the loop edited, the finding ID it resolves, the focused verification that ran, and whether the edits are still uncommitted.
   - `THINGS I DIDN'T TOUCH`: every declined Critical or Important finding with its step 2 reason, manual findings left for a human, Suggestions and FYI the loop never triaged, and any push it did not make.
   - `POTENTIAL CONCERNS`: how termination was decided (independent verifier, labeled self-certification, unverified because the verifier failed, or an unresolved reviewer disagreement), degraded coverage, remaining `UNVERIFIED` findings, and eligible findings left for `/trackbed:pr:resolve-review`.
   - Include no reviewer transcripts and no replay of the execution ledger; the sealed report's `## Coverage Status` stays the evidence record.

## Artifact Lifecycle

- This skill produces `REVIEW_OVERVIEW.md` by default unless `--inline` is used.
- `/trackbed:pr:resolve-review` consumes `REVIEW_OVERVIEW.md` when resolving eligible file-backed findings, or explicit inline review content when `--inline` was used.
- Each rerun refreshes the review report.
- `/trackbed:workflow:cleanup-artifacts` retires `REVIEW_OVERVIEW.md` when the review artifact is no longer needed.
