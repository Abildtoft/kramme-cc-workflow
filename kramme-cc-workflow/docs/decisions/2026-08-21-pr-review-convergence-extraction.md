# Extract Shared PR Review Convergence

- Status: ACCEPTED
- Date: 2026-08-21
- Last amended: 2026-08-30
- Deciders: repository maintainers
- First adoption review: 2026-11-21

## Context

`kramme:linear:issue-to-pr` contained implementation intake, a large review convergence loop, final verification, and optional shipping. A hidden archived-plan orchestrator separately ran a smaller version of the same phase for `kramme:code:plan-to-pr` and the former SIW issue-to-PR route. The inputs differed, but the review mechanics did not: validate a prepared branch, preserve authoritative caller requirements, run ordered gates through one bounded remediation budget, isolate reports, and verify the converged tree.

The latest local telemetry was collected on 2026-08-21. In the 30-day window, `kramme:linear:issue-to-pr` recorded 34 invocations in 34 sessions, `kramme:code:plan-to-pr` recorded 6 invocations in 6 sessions, and `kramme:pr:code-review` recorded 7 invocations in 7 sessions. In the 90-day window, their counts were 34 invocations in 34 sessions, 6 invocations in 6 sessions, and 73 invocations in 62 sessions respectively. The new route necessarily begins at zero direct recorded use; adoption is measured through both direct invocation and its callers.

The nearest existing skills are:

- `kramme:linear:review-pr`, which performs a read-only requirements audit of an existing GitHub Pull Request from immutable objects;
- `kramme:pr:code-review`, which supplies one read-only quality gate; and
- `kramme:code:plan-to-pr`, whose archived-plan lifecycle owns new-PR preflight and optional shipping.

## Decision

Create user-invocable `kramme:pr:review-convergence` and delegate to it from `kramme:linear:issue-to-pr` and `kramme:code:plan-to-pr` after each caller establishes its implementation commit boundary and freezes authoritative requirements. Direct invocation accepts a frozen authoritative requirements block and uses a fixed review archive; internal callers retain work identity, source archive, plan scope, and validation-only controls.

The positive route is: converge and verify one caller-prepared local branch against an inert, authoritative requirement block before Pull Request creation. Normal invocations may select one through five automatic remediation cycles with `--rounds`, defaulting to five; the existing diminishing-returns guards can stop the loop earlier. A validation-only mode reruns the same ordered gates once when an authorized CI or review-feedback workflow changes the published tree and rejects an explicit rounds override.

The boundary differs from its neighbors across the catalog policy's five dimensions:

| Dimension | `pr:review-convergence` | Nearest alternatives |
| --- | --- | --- |
| Intent | Converge caller-prepared work before PR creation or validate one caller-authorized post-CI tree. | `linear:review-pr` audits an existing PR; `pr:code-review` supplies one gate; caller workflows own shipping. |
| Input and scope | Work identity, allowlisted archive key, frozen inert requirements, optional validated plan scope, and review mode. | Existing PR selector, an ordinary branch diff, or caller-specific intake and shipping state. |
| Outcome | Clean committed branch, review ledger, isolated reports, and fresh verification evidence; validation-only returns ordered gate evidence without edits. | Inline read-only audit, one gate report, or a created and stabilized PR. |
| Side effects | May edit and commit in-scope review fixes; never pushes, updates Linear, or creates a PR. | `linear:review-pr` is read-only; `pr:code-review` is a read-only gate. |
| Safety and recovery | Requires a clean committed prepared branch, allowlisted archive ownership, inert requirements, optional exact plan-scope proof, bounded cycles, and explicit blocker recovery. | Existing-PR immutable-object review, gate-specific recovery, or caller-owned publication safeguards. |

Keep final project verification inside the extracted skill because a verification defect must consume the same remediation budget and re-enter the same ordered review loop. Returning before that gate would either lose convergence state or let the parent silently reset the budget.

The skill remains platform-neutral and has no Linear or SIW dependency. It is user-invocable but model-disabled because normal mode may edit files and create commits. Internal-only flags remain unavailable in direct mode. No external source inspired or supplied the extracted workflow; it is repository-owned behavior consolidated from the existing orchestrators.

## Consequences

- Linear and plan-to-PR callers share one quality policy while retaining separate intake, scope, and shipping contracts. The SIW caller was removed when SIW's boundary moved to one-way Linear transfer.
- `kramme:linear:issue-to-pr` and `kramme:code:plan-to-pr` remain caller-specific compositions around the shared convergence primitive.
- Review archives stay under each caller's existing `.context/{archive-key}/reviews/` namespace, name `kramme:pr:review-convergence` as producer, and remain registered for workflow-artifact cleanup.
- Normal callers can lower the shared automatic remediation ceiling from its five-cycle default without weakening the existing safety boundary.
- Review adoption on 2026-11-21 should inspect direct and caller usage, convergence failures, cycle exhaustion, and validation-only outcomes.
- `kramme:linear:review-pr` remains separate because its existing-PR, immutable, read-only audit has a different intent, input, outcome, permission boundary, and recovery path.

## Alternatives Considered

### Keep separate loops in each orchestrator

Rejected because caller identity changes the source of requirements, not the ordered gate, remediation, isolation, or verification policy. Parallel copies would drift.

### Add mutating modes to the existing review gates

Rejected because the individual gates are intentionally read-only and do not own cross-gate applicability, remediation cycles, or final verification.

### Keep the richer loop under the Linear namespace

Rejected because the convergence primitive does not perform Linear lookup and also serves archived-plan callers. A Linear namespace would misroute the shared capability and make future reuse look like a cross-domain exception.

## Amendment

The 2026-08-26 SIW boundary decision removed the SIW issue-to-PR caller and its review archive. Linear and archived-plan callers continue to use the shared convergence primitive.

On 2026-08-29, `kramme:code:plan-to-pr` recorded 7 invocations in 7 sessions in both the 30-day and 90-day reports. After its archived-plan lifecycle absorbed prepared-branch preflight, the frozen convergence handoff, final verification, optional shipping, and structured blocker recovery, the hidden caller-specific orchestrator had no remaining runtime caller or distinct outcome. Removing it keeps archived-plan composition in `kramme:code:plan-to-pr` and shared review mechanics in `kramme:pr:review-convergence` without changing the user-facing route.
