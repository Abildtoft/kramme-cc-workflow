#!/usr/bin/env bats

setup() {
	cd "$BATS_TEST_DIRNAME/.."
}

SKILL="skills/kramme:test:audit/SKILL.md"
RUBRIC="skills/kramme:test:audit/references/audit-rubric.md"

@test "test audit is read-only and separates audit from implementation" {
	test -f "$SKILL"
	test -f "$RUBRIC"
	grep -qF "This skill is strictly read-only for repository contents and the working tree." "$SKILL"
	grep -qF "Treat repository test commands as untrusted code." "$SKILL"
	grep -qF "package scripts, Make or task targets, test-runner configuration, plugins, global setup and teardown, and fixtures or hooks" "$SKILL"
	grep -qF "only when that complete trace proves it cannot modify repository files, persistent environment state, or external services" "$SKILL"
	grep -qF "do not execute it; continue with static analysis and record an audit gap" "$SKILL"
	grep -qF 'strict base resolution contacts the Git remote and may refresh remote-tracking refs and `FETCH_HEAD`' "$SKILL"
	grep -qF "This is the only permitted persistent-state or external-service side effect" "$SKILL"
	grep -qF "Applying a recommendation is a separate follow-up the user must request explicitly." "$SKILL"
	grep -qF "Never update snapshots, rewrite baselines, enable record mode, or install new tools during the audit." "$SKILL"
	grep -qF "no files were changed and that applying selected findings requires a separate request" "$SKILL"
}

@test "test audit treats structural patterns as leads rather than findings" {
	grep -qF "These are leads, not findings." "$SKILL"
	grep -qF "Pattern matching alone may nominate a candidate but never justifies a verdict." "$RUBRIC"
	grep -qF 'Read the audit rubric from `references/audit-rubric.md` before classifying candidates.' "$SKILL"
	grep -qF "Also sample apparently clean test files from each framework or test root" "$SKILL"
	grep -qF "Do not equate line coverage with test value." "$SKILL"
}

@test "test audit requires counterfactual and unique-protection evidence" {
	grep -qF "State the test's strongest plausible protection claim" "$SKILL"
	grep -qF "Apply the counterfactual" "$SKILL"
	grep -qF "The test has no unique protection claim." "$SKILL"
	grep -qF "would fail for the same fault class" "$SKILL"
	grep -qF "REMOVE normally requires high confidence." "$RUBRIC"
}

@test "regression tests are not removed because of age or implementation change" {
	grep -qF "A regression test remains valuable while the behavior or invariant can still regress" "$SKILL"
	grep -qF "Age is never evidence of obsolescence." "$RUBRIC"
	grep -qF "A rewritten implementation can still violate the same invariant." "$RUBRIC"
	grep -qF "Default verdict: REMOVE only with high confidence" "$RUBRIC"
	grep -qF "otherwise reject the lead when the test remains justified" "$RUBRIC"
	! grep -qF "INVESTIGATE or KEEP" "$RUBRIC"
}

@test "test audit uses explicit evidence-backed verdicts and inline output" {
	grep -qF "**REMOVE**" "$SKILL"
	grep -qF "**REPAIR**" "$SKILL"
	grep -qF "**CONSOLIDATE**" "$SKILL"
	grep -qF "**INVESTIGATE**" "$SKILL"
	grep -qF "Return the audit directly in the reply; do not create a report file." "$SKILL"
	grep -qF -- "- Location: `{file:line}`" "$SKILL"
	grep -qF -- "- Protection claim: {strongest plausible fault or contract protected}" "$SKILL"
	grep -qF -- "- Evidence: {system-under-test trace, assertion/oracle analysis, history, and overlapping coverage}" "$SKILL"
	grep -qF -- "- Counterfactual: {realistic defect or conceptual mutation and whether this test catches it}" "$SKILL"
	grep -qF -- "- Recommendation: {smallest safe action}" "$SKILL"
	grep -qF -- "- Later verification: `{focused command}`" "$SKILL"
	grep -qF -- "- Confidence: {high | medium | low} — {reason}" "$SKILL"
	grep -qF "## Rejected leads" "$SKILL"
	grep -qF "## Audit gaps" "$SKILL"
}

@test "test audit supports full path and changed scopes without becoming PR coverage review" {
	grep -qF 'argument-hint: "[full | path <file-or-folder> | changed [--base <ref>]] [--max-findings N]"' "$SKILL"
	grep -qF "audit the repository's complete test suite" "$SKILL"
	grep -qF "audit tests at or below the path" "$SKILL"
	grep -qF "If the path is production code, include tests that exercise it." "$SKILL"
	grep -qF "This remains a test-quality audit, not a review of whether the Pull Request has enough coverage." "$SKILL"
	grep -qF 'Reject conflicting selectors, missing paths, paths outside the working tree, `--base` without `changed`, invalid finding caps, and unresolved base refs.' "$SKILL"
	grep -qF '"${CLAUDE_PLUGIN_ROOT}/scripts/collect-review-diff.sh" --decode-json' "$SKILL"
	grep -qF "committed PR diff from MERGE_BASE...HEAD plus staged, unstaged, and untracked paths" "$SKILL"
	grep -qF 'Use the newline-delimited `CHANGED_FILES` as the complete changed candidate set, then intersect it with the discovered test inventory.' "$SKILL"
	grep -qF 'Initialize `SCOPE=full`, `BASE_REF_ARG=""`, and `MAX_FINDINGS=20` before parsing.' "$SKILL"
	grep -qF 'Store the selected scope in `SCOPE`, the validated `--base` value in `BASE_REF_ARG`, and the validated finding cap in `MAX_FINDINGS`.' "$SKILL"
	grep -qF 'default `20`, maximum `50` unless the user requests more' "$SKILL"
	grep -qF 'Cap active findings at `MAX_FINDINGS`; summarize additional proven candidates as deferred counts by verdict.' "$SKILL"
	grep -qF "trap 'exit 129' HUP" "$SKILL"
	grep -qF "trap 'exit 130' INT" "$SKILL"
	grep -qF "trap 'exit 143' TERM" "$SKILL"
	grep -qF "trap - EXIT HUP INT TERM" "$SKILL"
}

@test "test audit nominates provider-shaped assertions without condemning boundary doubles" {
	grep -qF -- "- assertions on a third-party payload, schema, status code, or error shape the repository neither owns nor monitors" "$SKILL"
	grep -qF "### Provider Shape Coupling" "$RUBRIC"
	grep -qF "Mocking at an external boundary is correct and is not the defect." "$RUBRIC"
	grep -qF "The defect is asserting the provider's shape rather than the adapter's contract" "$RUBRIC"
	grep -qF "A provider-shaped fixture is justified when it is generated or verified against the provider's published schema, refreshed by a recorded or contract test, or pinned to a provider version the repository declares and monitors." "$RUBRIC"
	grep -qF "Default verdict: REPAIR toward the adapter's own contract." "$RUBRIC"
	grep -qF "provider-shape-coupled" "$SKILL"
}

@test "test audit nominates wiring and existence tests without condemning behavioral UI tests" {
	grep -qF -- "- tests that only prove a symbol, route, command, handler, menu entry, or configuration key exists or is registered rather than exercising what it does" "$SKILL"
	grep -qF -- "- assertions on rendered structure, styling, or copy that no stated contract covers" "$SKILL"
	grep -qF "### Wiring or Existence Only" "$RUBRIC"
	grep -qF "the test would pass against a registered stub that does nothing" "$RUBRIC"
	grep -qF "Registration is worth its own test when registration is itself the contract and can break silently" "$RUBRIC"
	grep -qF "Assertions on user-visible behavior, accessible names and roles, state transitions, and error and empty states are ordinary behavioral tests; this category does not apply to them." "$RUBRIC"
	grep -qF "Default verdict: REMOVE when an existing behavioral test already depends on the registration" "$RUBRIC"
	grep -qF -- "- assertions target private methods, internal call order, intermediate data, exact logs, or non-contractual markup, styling, or copy" "$RUBRIC"
	grep -qF "Assertions on non-contractual markup, styling, or copy belong to Implementation Coupling, which defaults to REPAIR rather than REMOVE." "$RUBRIC"
	grep -qF "unless not throwing is the complete public contract and the harness would fail when that contract breaks" "$RUBRIC"
	grep -qF "For a rendering assertion, where there is no registration to weigh, default to REPAIR toward the user-visible behavior the mount stands in for." "$RUBRIC"
}

@test "test audit routing preserves the report-only permission boundary" {
	grep -qF "Use to find poor-quality tests across a repository or path." "$SKILL"
	grep -qF "editing or pruning tests" "$SKILL"
	! grep -qF "Use when asked to clean up, prune" "$SKILL"
}
