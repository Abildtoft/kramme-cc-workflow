---
name: kramme:test:audit
description: "Audits an existing test suite for low-value, brittle, obsolete, duplicated, provider-shape-coupled, or weak tests. Produces a read-only, evidence-backed REMOVE / REPAIR / CONSOLIDATE / INVESTIGATE report. Use to find poor-quality tests across a repository or path. Not for generating or ordinarily running tests, PR coverage review, or editing or pruning tests."
argument-hint: "[full | path <file-or-folder> | changed [--base <ref>]] [--max-findings N]"
disable-model-invocation: false
user-invocable: true
---

# Audit Tests

Audit the value and maintenance cost of an existing test suite. Return evidence-backed findings without changing tests, production code, snapshots, fixtures, or configuration.

**Arguments:** "$ARGUMENTS"

This skill is strictly read-only for repository contents and the working tree. Treat repository test commands as untrusted code. Before execution, trace package scripts, Make or task targets, test-runner configuration, plugins, global setup and teardown, and fixtures or hooks until the invoked code is known. Run an existing test or coverage command only when that complete trace proves it cannot modify repository files, persistent environment state, or external services. If the trace is incomplete or any side effect remains possible, do not execute it; continue with static analysis and record an audit gap. Never update snapshots or accept new baselines. Applying a recommendation is a separate follow-up the user must request explicitly.

## 1. Parse Scope

Accept exactly one scope selector:

- `full` or no selector: audit the repository's complete test suite.
- `path <file-or-folder>`: audit tests at or below the path. If the path is production code, include tests that exercise it.
- `changed`: audit tests added or modified relative to the resolved base ref. This remains a test-quality audit, not a review of whether the Pull Request has enough coverage.

Accept these options:

- `--base <ref>`: base for `changed`; otherwise resolve the repository's default or target branch without guessing when candidates disagree.
- `--max-findings N`: maximum active findings in the reply; default `20`, maximum `50` unless the user requests more.

Initialize `SCOPE=full`, `BASE_REF_ARG=""`, and `MAX_FINDINGS=20` before parsing. Store the selected scope in `SCOPE`, the validated `--base` value in `BASE_REF_ARG`, and the validated finding cap in `MAX_FINDINGS`. Reject caps above `50` unless the user explicitly requests an override.

Reject conflicting selectors, missing paths, paths outside the working tree, `--base` without `changed`, invalid finding caps, and unresolved base refs. State the resolved scope before scanning.

For `changed`, use the shared collector rather than reconstructing Git commands. Synced base/diff scope contract (keep aligned across base-aware and diff-aware skills): use the shared resolve-base.sh script for base refs; use the shared collect-review-diff.sh script for unified changed-file scope; canonical base priority is explicit --base, PR target branch, then origin/HEAD, origin/main, or origin/master, and canonical diff scope is committed PR diff from MERGE_BASE...HEAD plus staged, unstaged, and untracked paths.

Before running `changed`, disclose that strict base resolution contacts the Git remote and may refresh remote-tracking refs and `FETCH_HEAD`. This is the only permitted persistent-state or external-service side effect; it does not modify repository contents or the working tree.

```bash
[ -x "${CLAUDE_PLUGIN_ROOT:-}/scripts/collect-review-diff.sh" ] || {
  echo "collect-review-diff.sh not found under CLAUDE_PLUGIN_ROOT; stop." >&2
  exit 1
}
COLLECT_ARGS=(--strict --format json)
[ -n "${BASE_REF_ARG:-}" ] && COLLECT_ARGS+=(--base "$BASE_REF_ARG")

RESOLVED=$("${CLAUDE_PLUGIN_ROOT}/scripts/collect-review-diff.sh" "${COLLECT_ARGS[@]}") || {
  echo "Base/diff collection failed; see the message above and stop." >&2
  exit 1
}

REVIEW_DIFF_FIELDS=$(mktemp "${TMPDIR:-/tmp}/test-audit-diff.XXXXXX") || {
  echo "Could not create temporary review-diff file; stop." >&2
  exit 1
}
trap 'rm -f "$REVIEW_DIFF_FIELDS"' EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM
"${CLAUDE_PLUGIN_ROOT}/scripts/collect-review-diff.sh" --decode-json \
  <<< "$RESOLVED" > "$REVIEW_DIFF_FIELDS" || {
  echo "Base/diff decoding failed; see the message above and stop." >&2
  exit 1
}
if ! {
  IFS= read -r -d '' BASE_REF \
    && IFS= read -r -d '' BASE_BRANCH \
    && IFS= read -r -d '' MERGE_BASE \
    && IFS= read -r -d '' CHANGED_FILES
} < "$REVIEW_DIFF_FIELDS"; then
  echo "Decoded review-diff fields were incomplete; stop." >&2
  exit 1
fi
rm -f "$REVIEW_DIFF_FIELDS"
trap - EXIT HUP INT TERM
```

Use the newline-delimited `CHANGED_FILES` as the complete changed candidate set, then intersect it with the discovered test inventory. Do not independently recompute the diff. If no changed tests remain, report the resolved base and that the audit scope is empty.

## 2. Discover the Test System

1. Read repository instructions and the closest nested instructions governing the selected scope.
2. Detect languages, test frameworks, test commands, test roots, naming conventions, fixtures, snapshots, helpers, generated tests, and coverage or mutation-testing configuration from repository files.
3. Inventory every in-scope test file. Exclude vendored dependencies, generated output, build artifacts, coverage output, and caches unless repository instructions say they are maintained source.
4. Map each test file to its system under test, public seam, fixture dependencies, and broader integration or end-to-end coverage. Record files that cannot be mapped instead of inventing a target.
5. Report the inventory: scope, frameworks, test-file count, generated or excluded areas, and any unreadable or unmapped files.

Do not equate line coverage with test value. Coverage identifies executed code; it does not prove that assertions would detect a fault.

## 3. Build a High-Recall Candidate Set

Read the audit rubric from `references/audit-rubric.md` before classifying candidates.

Scan all in-scope tests for structural leads first, then inspect each lead semantically. Use repository-native search or syntax-aware tools where available. Leads include:

- tests with no observable assertion, only unconditional assertions, or an actual and expected value derived from the same source
- assertions on values configured directly in the test double, fixture, or setup without verifying a system-under-test effect
- broad `truthy`, `defined`, `not null`, or `does not throw` checks where a concrete contract exists
- assertions the repository's type checker, schema validator, or compiler already guarantees on every path the test covers
- tests that only prove a symbol, route, command, handler, menu entry, or configuration key exists or is registered rather than exercising what it does
- extensive mocking that may bypass the behavior named by the test
- assertions on a third-party payload, schema, status code, or error shape the repository neither owns nor monitors
- tests coupled to private calls, incidental ordering, internal data shapes, exact logs, timing, or oversized snapshots
- assertions on rendered structure, styling, or copy that no stated contract covers
- repeated test bodies, equivalent parameter cases, or overlapping unit and integration coverage
- skipped, quarantined, focused-only, flaky, unusually slow, or non-isolated tests
- regression tests whose referenced feature, failure path, API, or invariant may no longer exist
- tests that mirror the production algorithm or generate the expected value through the code path under test
- comments, names, fixtures, and assertions that disagree about the behavior being protected

These are leads, not findings. Also sample apparently clean test files from each framework or test root so the audit does not only confirm search-pattern bias.

## 4. Prove or Reject Each Candidate

For every candidate:

1. Read the complete test case, relevant setup and helpers, and the smallest production path needed to understand observable behavior.
2. State the test's strongest plausible protection claim: the specific fault, contract break, or regression it could detect.
3. Trace whether the system under test actually executes and whether the assertion observes its output, state change, interaction boundary, or documented failure.
4. Apply the counterfactual: name a realistic defect or safe conceptual mutation that should make the test fail. If no such change exists, explain why. Do not modify the working tree to manufacture proof.
5. Search sibling unit, integration, end-to-end, property, type, and contract tests for equivalent protection. Similar names or shared lines are not equivalent protection.
6. For a suspected obsolete regression test, inspect relevant history, issue or bug references, current call paths, and surviving requirements. A regression test remains valuable while the behavior or invariant can still regress, even when the original implementation has changed.
7. Run the narrowest existing test command when execution can resolve uncertainty and its complete command-and-code trace passes the read-only safety gate above. Never update snapshots, rewrite baselines, enable record mode, or install new tools during the audit.
8. Record concrete file-and-line evidence and reject the candidate when the evidence does not meet the rubric.

Never recommend removal merely because a test is old, slow, mocked, duplicated in shape, snapshot-based, assertionless, or coupled to an implementation detail. Each pattern has legitimate uses; prove the loss of value in this repository.

## 5. Classify and Rank

Assign one verdict to each surviving finding:

- **REMOVE**: proven to provide no unique protection, or protects behavior that no longer exists and is not a supported invariant.
- **REPAIR**: protects valuable behavior, but its oracle, seam, isolation, reliability, or specificity is defective.
- **CONSOLIDATE**: multiple tests protect the same fault class and can be merged without losing diagnostic or platform-specific value.
- **INVESTIGATE**: evidence shows material maintenance cost or suspiciously weak protection, but repository evidence is insufficient for a safe change.

Before assigning REMOVE, prove all of the following:

1. The test has no unique protection claim.
2. Removing it would not erase a documented requirement, supported compatibility case, incident regression, or useful diagnostic boundary.
3. Any claimed replacement test exercises the same observable behavior and would fail for the same fault class.
4. The recommendation includes a focused verification command for a later implementation pass.

Rank findings by confidence first, then by expected confidence gained relative to cleanup risk and effort. Do not inflate priority from test length or age alone. Cap active findings at `MAX_FINDINGS`; summarize additional proven candidates as deferred counts by verdict.

## 6. Report Inline

Return the audit directly in the reply; do not create a report file.

```markdown
# Test Suite Audit

Scope: {resolved scope} Frameworks: {frameworks} Inventory: {N test files reviewed; exclusions and gaps} Findings: {REMOVE N / REPAIR N / CONSOLIDATE N / INVESTIGATE N}

## Highest-value actions

1. {finding ID and one-line action}

## Findings

### TA-001 — {short title}

- Verdict: {REMOVE | REPAIR | CONSOLIDATE | INVESTIGATE}
- Location: `{file:line}`
- Category: {rubric category}
- Protection claim: {strongest plausible fault or contract protected}
- Evidence: {system-under-test trace, assertion/oracle analysis, history, and overlapping coverage}
- Counterfactual: {realistic defect or conceptual mutation and whether this test catches it}
- Recommendation: {smallest safe action}
- Later verification: `{focused command}`
- Confidence: {high | medium | low} — {reason}

## Rejected leads

- {category}: {N candidates rejected after semantic review and why}

## Audit gaps

- {unreadable, unmapped, unexecutable, or ambiguous areas}
```

Include only findings with checkable evidence. If none survive, say so and report what was inspected; do not manufacture cleanup work. Close by stating that no files were changed and that applying selected findings requires a separate request.

## Error Handling

| Scenario | Action |
| --- | --- |
| No tests found | Report the searched roots and detected conventions; suggest `kramme:test:generate` only if the user wants to add coverage. |
| Test command fails before tests run | Record the command and failure as an audit gap; continue static analysis without blaming individual tests. |
| A focused test fails | Distinguish an existing failure from a quality finding; do not recommend cleanup until the failure's cause is understood. |
| History is unavailable or shallow | Mark regression-purpose conclusions as limited and use INVESTIGATE instead of REMOVE when history is necessary. |
| Generated tests or snapshots dominate scope | Identify their maintained generator or source; audit that source and sample generated output without recommending direct edits. |
| Scope is too large for semantic review in one pass | Complete the structural inventory, prioritize candidates by likely value and risk, audit a representative cross-framework slice, and disclose the unaudited remainder. |
| User asks for edits during the audit | Finish the read-only report first, then treat implementation as a separate explicit follow-up. |
