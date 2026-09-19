#!/usr/bin/env bats

setup() {
	PLUGIN_ROOT="$BATS_TEST_DIRNAME/.."
	CONVERGENCE="$PLUGIN_ROOT/skills/kramme:pr:review-convergence/SKILL.md"
	POLICY="$PLUGIN_ROOT/skills/kramme:pr:review-convergence/references/review-convergence.md"
	STATE_SCRIPT="$PLUGIN_ROOT/skills/kramme:pr:review-convergence/scripts/convergence-state.py"
	CODE_REVIEW="$PLUGIN_ROOT/skills/kramme:pr:code-review/SKILL.md"
	CONVENTION="$PLUGIN_ROOT/skills/kramme:pr:convention-review/SKILL.md"
	MINING="$PLUGIN_ROOT/skills/kramme:pr:convention-review/references/baseline-mining.md"
	OVERENGINEERING="$PLUGIN_ROOT/skills/kramme:pr:overengineering-review/SKILL.md"
	REFACTOR="$PLUGIN_ROOT/skills/kramme:code:refactor-opportunities/SKILL.md"
	LINEAR_SHIPPING="$PLUGIN_ROOT/skills/kramme:linear:issue-to-pr/references/shipping-contract.md"
	PLAN_SHIPPING="$PLUGIN_ROOT/skills/kramme:code:plan-to-pr/references/shipping-contract.md"
}

require_phrases() {
	local file="$1"
	shift
	run python3 - "$file" "$@" <<'PY'
import pathlib
import sys

text = pathlib.Path(sys.argv[1]).read_text()
missing = [phrase for phrase in sys.argv[2:] if phrase not in text]
raise SystemExit("missing: " + " | ".join(missing) if missing else 0)
PY
	[ "$status" -eq 0 ] || {
		echo "$output"
		false
	}
}

@test "convergence loop batches findings, verifies with delta rounds, and closes on a full pass" {
	require_phrases "$POLICY" \
		"do not remediate between gates" \
		"**Batch remediation.**" \
		"**Delta round.**" \
		"**Confirmation pass.**" \
		"never close the loop on a delta round" \
		"a fingerprint re-emitted by a delta round or confirmation pass after its batch counts as persisting" \
		"Every fingerprint fixed by a batch was confirmed absent by the final full pass"
}

@test "convergence records review cost through the run-state script" {
	test -f "$STATE_SCRIPT"
	require_phrases "$POLICY" \
		"## Run-State Script and Gate Delegation" \
		"validate-archive" \
		"ledger init|record|summary" \
		"commit-boundary" \
		'{"kind":"gate","gate":"<gate>","round":<n>,"agents_launched":<count>}' \
		"never stages with \`git add -A\`" \
		"exits \`3\` because hooks changed content"
	require_phrases "$CONVERGENCE" \
		"validate-archive --archive-key {archive-key}" \
		"Review cost: {the exact \`review_cost_line\` from \`ledger summary\`}" \
		"Review head: {HEAD}"
}

@test "validation-only reviews only the CI remediation when the caller names the verified tree" {
	require_phrases "$CONVERGENCE" \
		"Parse \`--verified-tree <oid>\` at most once, only together with \`--validation-only\`" \
		"select the newest commit whose tree equals \`VERIFIED_TREE\`" \
		"Validation scope: full (verified tree not found on branch)"
	require_phrases "$POLICY" \
		"that pass is a delta round scoped to \`{VALIDATION_BASE_COMMIT}..HEAD\`" \
		"Gate 5, when requested, still attests the full tree"
	require_phrases "$LINEAR_SHIPPING" \
		"--validation-only --verified-tree {verified-tree}" \
		"a \`Validation scope\` line"
	require_phrases "$PLAN_SHIPPING" \
		"--validation-only --verified-tree {verified-tree}" \
		"a \`Validation scope\` line"
}

@test "standard mode defers the advisory refactor scan to the final candidate" {
	require_phrases "$POLICY" \
		"skip — advisory; deferred to the confirmation pass" \
		"Run the gate only in a full pass whose Gates 1–3 triage left nothing to change"
}

@test "delta rounds trim Gate 1 to correctness reviewers and skip an empty slop meta-review" {
	require_phrases "$POLICY" "--no-cleanup --base {pre-batch-commit}"
	require_phrases "$CODE_REVIEW" \
		"[--no-cleanup]" \
		"set \`NO_CLEANUP=true\`" \
		"exclude \`lean\`, \`refactor\`, and \`simplify\` from this default set" \
		"the flag never removes a dimension the user asked for by name" \
		"Slop meta-review: skipped (no findings)" \
		"Always end the run with \`Reviewers launched: N\`"
}

@test "convention review reuses its mined baseline across rounds" {
	require_phrases "$POLICY" "--baseline {review-archive}/convention-baseline.json"
	require_phrases "$CONVENTION" \
		"[--baseline <path>]" \
		"Store it as \`BASELINE_PATH\`" \
		"reuse an entry only when every recorded peer blob is unchanged at \`HEAD\`" \
		"write the merged ledger back to \`BASELINE_PATH\` atomically" \
		"Baseline ledger: {none | path — reused X entries, mined Y}" \
		"Reviewers launched: {N}"
	require_phrases "$MINING" \
		"## Baseline Ledger" \
		'```json mined-baseline' \
		"Reuse never lowers the quorum bar"
}

@test "overengineering review carries unchanged regions forward without re-justifying them" {
	require_phrases "$OVERENGINEERING" \
		"- Region fingerprint: path/to/file.ext@{blob-oid}" \
		"carried forward (unchanged region)" \
		"inherits \`JUSTIFIED\` and its basis without a new justify pass" \
		"\`Agents launched: N\`"
	require_phrases "$REFACTOR" "End the run with \`Agents launched: N\`"
}

@test "gate delegation keeps arguments and producer evidence checks intact" {
	require_phrases "$POLICY" \
		"run each quality gate inside one such delegated agent on the orchestrator's model" \
		"a delegated wrapper does not replace that check" \
		"Delegation changes where a gate runs, never its arguments, model policy, or contract"
}
