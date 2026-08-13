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

@test "test audit routing preserves the report-only permission boundary" {
	grep -qF "Use to find poor-quality tests across a repository or path." "$SKILL"
	grep -qF "editing or pruning tests" "$SKILL"
	! grep -qF "Use when asked to clean up, prune" "$SKILL"
}
