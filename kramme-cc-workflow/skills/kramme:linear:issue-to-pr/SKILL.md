---
name: kramme:linear:issue-to-pr
description: Requires Linear MCP. Implements one Linear issue end to end, selects applicable code-review, convention, and PR-refactor gates, runs them to bounded convergence, verifies, and optionally opens the PR and iterates on CI and review feedback until green. Use when the user wants a single Linear issue taken from implementation through a clean Pull Request. Not for implementation-only work, SIW-tracked issues, stacked PRs, existing PR updates, or post-merge rollout.
argument-hint: "<ISSUE-ID> [--strict] [--ship]"
disable-model-invocation: true
user-invocable: true
---

# Take a Linear Issue to a Pull Request

Orchestrate the established Linear implementation, review, verification, and Pull Request skills as one resumable workflow. Keep each delegated skill's safety and rollback contract intact; this skill owns only their sequencing, convergence criteria, and handoffs.

## Workflow Contract

- Invoke every delegated skill through the platform's skill mechanism. If direct invocation is unavailable, locate and read that skill's installed `SKILL.md` and follow it with the same arguments. This rule covers every delegation below and in both references; they name the skill and its arguments without repeating it.
- Continue from one delegated skill to the next without pausing for a progress summary.
- Pause only for a hard blocker or a decision that the issue, referenced context, repository conventions, and code cannot determine safely.
- Treat a delegated skill failure as a workflow failure. Preserve its recovery information and do not skip ahead.
- Do not broaden the Linear issue's scope to make review findings disappear.
- Never add AI attribution to code, commits, or the Pull Request.
- Do not create, edit, pause, resume, or clear a Codex goal. When invoked inside `/goal`, let the goal layer own persistence while this skill owns the workflow.

## Step 1: Parse Arguments

Parse `$ARGUMENTS` before doing any repository or Linear work.

1. Remove recognized flags in any order:
   - `--strict` sets `STRICT_REVIEW=true`.
   - `--ship` sets `SHIP_MODE=true`.
2. Reject every unknown `--flag` and list the supported flags.
3. Require exactly one remaining positional argument matching `{TEAM}-{number}`, case-insensitively, where `TEAM` is alphanumeric.
4. Normalize the issue identifier to uppercase and store it as `{issue-id}`.

Defaults:

- `STRICT_REVIEW=false`: require no accepted unresolved Critical or Important findings. Report remaining manual or advisory findings.
- `SHIP_MODE=false`: stop after clean review and final verification without rewriting history, pushing, or creating a Pull Request.

`--strict` changes review disposition, not product authority. It does not permit inventing a missing requirement or bypassing a genuine manual blocker.

`--ship` is explicit authorization to retire current-project disposable workflow artifacts through `kramme:workflow-artifacts:cleanup --auto`, let `kramme:pr:create --auto --authorize-history-rewrite` perform the backup-protected local narrative rewrite without a nested reset prompt, create the previously absent remote issue branch once with an exact absence lease, self-assign, and open the Pull Request, then let `kramme:pr:fix-ci --no-consolidate` push validated CI and review-feedback fixes until the checks are green. The cleanup skill keeps permanent specifications and shared diagrams in auto mode. Keeping CI fix commits unconsolidated avoids a post-creation history rewrite. `--ship` does not authorize rewriting an existing remote branch or Pull Request branch, bypassing a lease mismatch, force-pushing unrelated work, merging, or post-merge rollout.

If validation fails, stop with:

```text
Usage: $kramme:linear:issue-to-pr <ISSUE-ID> [--strict] [--ship]
Example: $kramme:linear:issue-to-pr DISC-202 --strict --ship
```

## Step 2: Invoke Linear Implementation

Before allowing the implementation workflow to mutate a branch, perform a read-only new-PR preflight:

1. Run `git status --porcelain` and continue only when it is empty. The delegated implementation workflow runs with `--auto`, which refuses a dirty worktree and tells its caller to rerun without `--auto` — an option this entry point never has. Stop here instead, with the recovery this workflow does support: commit or stash the existing changes, then re-run `$kramme:linear:issue-to-pr {issue-id}`.
2. Fetch `{issue-id}` with the Linear MCP issue lookup and capture its exact `branchName` as `{issue-branch}`. This narrow preflight exists only to enforce this skill's new-PR boundary; the delegated implementation workflow still owns the complete issue lookup and reference mapping. If the issue is unavailable or `branchName` is missing, stop before branch setup because the target PR branch cannot be identified safely. This workflow cannot fall back to the delegated workflow's generated branch name, because it must know the exact branch identity before delegation.
3. Before interpolating `{issue-branch}` into any shell command, validate the agent-tracked value directly. Require the whole string to match `[A-Za-z0-9][A-Za-z0-9._/-]*`; reject a leading `-`, whitespace, shell metacharacters, or any other character outside that allowlist. Only after that check passes, run `git check-ref-format --branch "{issue-branch}"` and require it to succeed. This intentionally conservative boundary may reject an unusual Git-valid branch rather than execute an untrusted Linear value.
4. Query GitHub for Pull Requests whose head is exactly `{issue-branch}`:

   ```bash
   gh pr list --head "{issue-branch}" --state all --limit 100 --json number,url,state,headRefName,headRefOid
   ```

   Require this command to succeed. An authentication, network, repository, or API error is a blocker, not evidence that no Pull Request exists.

5. Continue only when the successful response is an empty list. If any open Pull Request exists, stop and route the later session to `kramme:pr:fix-ci --no-consolidate`; this new-PR workflow does not offer cross-session Step 7 resumption. If a closed or merged Pull Request already used the branch, stop and require a new issue branch.
6. Query the exact remote branch ref before implementation:

   ```bash
   git ls-remote --heads origin "refs/heads/{issue-branch}"
   ```

   Require the query to succeed and parse only a well-formed result containing either zero lines or one line with a full object ID and the exact ref `refs/heads/{issue-branch}`. Continue only for the zero-line absent result. If the ref exists, stop before delegated branch setup: the later `kramme:pr:create` workflow cannot adopt or rewrite an existing remote ref, so neither `--ship` nor the non-shipping handoff can complete safely. Report the existing ref and require coordination or a fresh issue branch. Treat malformed, ambiguous, or failed output as a blocker rather than evidence of absence. A later concurrent branch creation remains protected by the exact absence lease in `kramme:pr:create`.

Invoke `kramme:linear:issue-implement` with `{issue-id} --auto`.

The delegated workflow owns Linear lookup, immediate branch setup, reference mapping, planning, implementation, and implementation verification. It may commit as it goes, but this parent owns the final implementation commit boundary below so review never starts from an ambiguous dirty tree.

After the delegated skill returns, continue immediately only when all of these are true:

- The Linear issue was found and its required context was accessible or explicitly judged non-blocking.
- Autonomous implementation completed rather than ending in context-only mode.
- The current branch is exactly `{issue-branch}` from the preflight and is the issue branch selected by the delegated workflow.
- No unresolved implementation blocker remains.

If any condition is false, stop at that blocker. Do not start review or Pull Request creation for a partial implementation.

### Implementation Commit Boundary

Before starting Step 3, establish one explicit committed implementation boundary:

1. Inspect `git status --porcelain` and classify every remaining path.
2. If the worktree is clean, continue.
3. If paths remain, continue only when every path is an in-scope implementation change produced after the delegated `--auto` workflow's required clean-tree branch setup. Stop on a pre-existing, unrelated, generated-review, or ambiguous path instead of committing it.
4. Run the smallest focused verification that covers the remaining implementation changes. Stage only the classified paths with `git add -- <path>...`; never use `git add -A` at this boundary.
5. Commit the verified batch with a plain-English message that includes `{issue-id}`, and require `git status --porcelain` to be empty. If hooks change content, rerun the focused verification before review.

This boundary does not consume a review-remediation cycle because it closes the delegated implementation phase before any quality gate emits a finding.

## Step 3: Run the Quality Loop

Read the review convergence policy from `references/review-convergence.md` and follow it completely.

During normal remediation rounds, first evaluate which gates apply, then run the active gates in order:

1. Invoke `kramme:pr:code-review` with `--parallel --inline` when regular code review applies.
2. Invoke `kramme:pr:convention-review` with `--inline` when convention review applies.
3. Invoke `kramme:code:refactor-opportunities` with `pr` when PR-scoped refactor discovery applies.

Inline mode is required for the regular and convention reviews so this orchestration does not intentionally create their overview files; keep finding dispositions in current run state and prefer direct, scoped fixes when the delegated workflow permits them. When active, `kramme:code:refactor-opportunities pr` writes or refreshes `REFACTOR_OPPORTUNITIES_OVERVIEW.md`. Consume it, then move it into `.context/linear-issue-to-pr/` before collecting another unified scope so generated review output never becomes PR input. Apply the same isolation rule to any overview file created by a delegated resolver.

Apply the standard or strict completion rule from the reference based on `STRICT_REVIEW`. The parent owns all finding triage, review-triggered edits, cycle accounting, remediation commits, and reruns. After any accepted review change, follow the reference's remediation commit boundary: isolate generated artifacts, run focused verification, commit only the in-scope workflow-owned changes, and restart the next round at applicability evaluation followed by regular review.

Bound all review-triggered edits to the reference policy's single parent-owned remediation budget. Delegated review skills are read-only gates and never own a nested remediation loop in this workflow. At diminishing returns, allow only the policy's final validation-only round, which must not edit code. Defer optional polish with evidence, but stop before verification or shipping when any required finding remains.

## Step 4: Run Final Verification

Invoke `kramme:verify:run` for a fresh, project-configured verification pass.

- Require every applicable check to pass.
- Treat a missing tool or skipped destructive integration/E2E check according to `kramme:verify:run`; report the gap instead of claiming it ran.
- If verification exposes an in-scope defect and remediation budget remains, count its fix as a remediation cycle, apply the remediation commit boundary after focused verification, return to Step 3 for another review pass, and then rerun Step 4.
- If verification fails after the loop reached diminishing returns or exhausted its budget, stop with the failure evidence. Do not reset the budget, edit again, or ship without explicit user approval to resume.
- If verification cannot pass without a missing dependency, external service, or user decision, stop with that blocker.

Capture the successful verification evidence for the final output. Do not make further code changes before Pull Request creation unless the workflow returns through Steps 3 and 4. After the Pull Request exists, `kramme:pr:fix-ci --no-consolidate` owns CI and review-feedback changes, and shipping-contract Step 8 re-reviews and re-verifies any tree it produces.

## Step 5: Stop or Ship

If `SHIP_MODE=false`, stop without invoking artifact cleanup or `kramme:pr:create`. Report that implementation, review, and verification are complete using the Step 6 review-ready template, whose `Next:` and `Then:` lines carry the exact handoff commands.

If `SHIP_MODE=true`, read the shipping contract from `references/shipping-contract.md` and follow it completely. That reference owns the complete order; in summary:

1. Recheck that no Pull Request appeared for the issue branch.
2. Retire current-project disposable workflow artifacts with `kramme:workflow-artifacts:cleanup --auto`.
3. Require a clean, unambiguous worktree.
4. Record the verified tree identity.
5. Invoke `kramme:pr:create --auto --linear-issue {issue-id} --require-generated-description --authorize-history-rewrite`.
6. Prove that the initial remote Pull Request head matches the verified tree.
7. Invoke `kramme:pr:fix-ci --no-consolidate` until CI is green and review feedback is addressed.
8. Prove that the final remote Pull Request head matches the clean local result, and rerun project verification if CI remediation changed the tree.

Never invoke `kramme:pr:create` before the review loop and final verification both pass.

## Step 6: Report the Outcome

For a review-ready result without `--ship`, report:

```text
Linear issue: {issue-id}
Implementation: complete
Quality gates: complete ({standard|strict}; {active gates})
Skipped gates: {gate + evidence-based reason | none}
Remediation: {cycles used}/{cycle budget}; stop={converged|diminishing returns}
Findings: 0 blocking unresolved; fixed={count}, rejected={count}, deferred optional={count}, blocked=0
Verification: passed
Pull Request: not created (--ship was not supplied)
Next: $kramme:pr:create --auto --linear-issue {issue-id} --require-generated-description
Then: $kramme:pr:fix-ci --no-consolidate
```

For a shipped result, report:

```text
Linear issue: {issue-id}
Implementation: complete
Quality gates: complete ({standard|strict}; {active gates})
Skipped gates: {gate + evidence-based reason | none}
Remediation: {cycles used}/{cycle budget}; stop={converged|diminishing returns}
Findings: 0 blocking unresolved; fixed={count}, rejected={count}, deferred optional={count}, blocked=0
Verification: initial tree {verified-tree} passed; final tree {final-tree} {unchanged|passed fresh verification}
CI: {green|none configured}; review feedback addressed; final tree {final-tree}
Pull Request: {url}
History: narrative rewrite completed before PR creation; CI fix commits retained separately; final remote head matches the clean local tree
```

If coverage was degraded, a check was skipped, or the workflow stopped on a blocker, replace the success wording with the exact limitation. Never describe a partial or degraded run as clean.

## Artifact Lifecycle

- **Implementation commits and source changes** are produced by `kramme:linear:issue-implement` and review resolution, consumed by review and `kramme:pr:create`, refreshed by accepted fixes, and retired through the repository's normal merge or branch-archive process.
- **Quality-loop review reports** are produced by the active gates or their resolvers, consumed during triage, then moved under `.context/linear-issue-to-pr/` before another scope is collected. The archived report is refreshed whenever its gate reruns and retired before shipping by `kramme:workflow-artifacts:cleanup --auto`. Without `--ship`, retain the archive as the review-ready handoff artifact; it stays gitignored so it never enters the Pull Request, and it is retired by the later shipping run's cleanup or by an explicit `kramme:workflow-artifacts:cleanup` if the branch is abandoned.
- **Inline convention and broad-review state** is produced and consumed inside Step 3 and refreshed on every quality rerun. It is retired when the run reaches a final disposition; any file-backed resolver output follows the same `.context/linear-issue-to-pr/` isolation rule.
- **Pull Request** is produced only by `kramme:pr:create` after `--ship` authorization, then consumed and refreshed by `kramme:pr:fix-ci --no-consolidate` until CI and review feedback are clear. It is retired by merge or close.

## Error Handling

- **Uncommitted changes at the Step 2 preflight** — stop before the Linear lookup. The delegated `--auto` implementation workflow refuses a dirty worktree and suggests rerunning without `--auto`, which this entry point never does. Ask the user to commit or stash the changes, then re-run this skill.
- **Linear MCP unavailable or issue not found** — stop with the delegated issue workflow's connection or lookup guidance.
- **Linear issue has no `branchName`** — stop at the Step 2 preflight. This workflow must know the exact branch identity before delegation to prove its new-PR boundary, so it cannot use the delegated workflow's generated-name fallback. Set a branch name on the Linear issue, or run `kramme:linear:issue-implement` and `kramme:pr:create` as separate steps.
- **Remote issue branch already exists without a Pull Request** — stop before delegated branch setup. `kramme:pr:create` never adopts or rewrites an existing remote ref, so neither `--ship` nor the non-shipping handoff can complete. Report the existing ref and require coordination or a fresh issue branch.
- **Implementation incomplete** — stop on the implementation blocker; do not review or ship partial work.
- **Refactor, convention, or broad-review coverage degraded** — identify failed dimensions and do not call the result clean until required coverage succeeds.
- **Genuine manual review blocker** — ask once for the exact missing decision, approval, ownership, or access; resume the same finding after the answer.
- **Review loop makes no progress** — apply the convergence guard in `references/review-convergence.md`; do not loop on repeated rejected advice.
- **Review loop reaches diminishing returns** — enter the reference policy's bounded stop, which permits only the one validation-only review round. Defer optional findings with evidence. If a required finding remains, require explicit user approval before starting a new remediation cycle; do not verify, rewrite history, push, or create the Pull Request while it remains unresolved.
- **Verification failure** — fix and return through review, or stop with full failure evidence.
- **Artifact cleanup unsafe or unavailable** — stop before history rewriting or push.
- **Existing Pull Request found before implementation or shipping** — stop before further mutation and route a later session to `kramme:pr:fix-ci --no-consolidate`. The new-Pull-Request workflow never adopts an existing Pull Request because it has no invocation-owned creation provenance at either preflight.
- **Initial shipped tree differs from the pre-PR verified tree** — report both tree identities and the Pull Request state, and do not start CI stabilization or claim verified completion.
- **CI stabilization failure** — preserve the Pull Request URL and the exact `kramme:pr:fix-ci` blocker; do not claim that checks or review feedback are clear.
