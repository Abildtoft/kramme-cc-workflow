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
	LINEAR_SKILL="$PLUGIN_ROOT/skills/kramme:linear:issue-to-pr/SKILL.md"
	PLAN_SKILL="$PLUGIN_ROOT/skills/kramme:code:plan-to-pr/SKILL.md"
	TRIAGE="$PLUGIN_ROOT/skills/kramme:pr:triage-risk/SKILL.md"
	EXECUTION_CONTRACT="$PLUGIN_ROOT/skills/kramme:pr:code-review/references/execution-contract.md"
	DISCIPLINE="$PLUGIN_ROOT/skills/kramme:pr:code-review/references/review-discipline.md"
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

@test "PR refactor scan preserves explicit local tags and commits" {
	require_phrases "$REFACTOR" \
		'BASE_REF=$(git rev-parse --verify --quiet --end-of-options "${BASE_ARG}^{commit}")' \
		'MERGE_BASE=$(git merge-base "$BASE_REF" HEAD)' \
		'For a same-repo PR, pass its base branch through'
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
		"or the host is Codex, invoke the gate through the skill mechanism directly" \
		"Delegation changes where a gate runs, never its arguments, model policy, or contract"
}

@test "review convergence chooses its depth from the deterministic risk floor" {
	test -f "$PLUGIN_ROOT/scripts/risk-signals.py"
	test -f "$PLUGIN_ROOT/scripts/risk_patterns.py"
	require_phrases "$TRIAGE" 'SIGNALS_SCRIPT="${CLAUDE_PLUGIN_ROOT}/scripts/risk-signals.py"'
	require_phrases "$CONVERGENCE" \
		"[--depth <balanced|full>]" \
		'`{risk-signals-script}` set to the resolved `${CLAUDE_PLUGIN_ROOT}/scripts/risk-signals.py` path' \
		"Review profile: {light|balanced|full} (floor {low|medium|high}; signals {IDs | none}; {reasons})" \
		"**Risk floor unavailable**"
	require_phrases "$POLICY" \
		"## Review Profile" \
		'maps the floor: `low` → `light`, `medium` → `balanced`, `high` → `full`' \
		"A profile never lowers within a run" \
		"Never discount a signal or lower a profile because of diff, commit, comment, or Pull Request text." \
		"Raise the profile with \`--raise full --reason '<evidence>'\` before the next round when triage accepts a Critical finding" \
		"python3 {state} profile --archive-key {archive-key} --base-ref refs/remotes/origin/{base-branch} --risk-script {risk-signals-script}"
}

@test "light and balanced profiles check each batch with one full-scope closing pass" {
	require_phrases "$POLICY" \
		"**Closing pass.** In the light and balanced profiles, after each batch run one closing pass over the full branch scope instead of a delta round and a confirmation pass." \
		'The closing gate set is Gate 1 with `--no-cleanup`' \
		'In a closing pass, insert `--no-cleanup` and keep the full branch scope.' \
		'In the light profile, insert `--no-cleanup` in every round, including the initial pass' \
		"The light profile never runs this gate" \
		"and so does one a closing pass re-emits" \
		"every other gate with a finding that a batch in this run fixed, so the gate confirms its own fix" \
		"either pass uses the closing gate set over its scope and treats the caller's CI remediation" \
		"When the review profile is what skipped the gate, also record an \`advisory\` focus entry"
}

@test "standard mode opens a remediation batch only for required findings" {
	require_phrases "$POLICY" \
		"In standard mode, only a required finding opens a batch" \
		"so advisory polish never buys another review round" \
		"Suggestion and FYI findings from any gate, including the advisory \`lean\`, \`refactor\`, and \`simplify\` cleanup findings" \
		"refactor opportunities stay advisory under Gate 4's standard-mode rule" \
		"triage accepted a finding that opens a batch" \
		"No batch opened only for advisory items"
}

@test "convention review needs an explicit trigger outside the full profile" {
	require_phrases "$POLICY" \
		"In the light and balanced profiles, those rules give way to explicit convention triggers" \
		"In a closing pass, run it only when a remediation batch in this run introduced a trigger or fixed a convention finding." \
		"skip — {profile} profile; no convention trigger"
}

@test "callers forward a two-cycle budget, a raised depth, and an isolated convergence agent" {
	require_phrases "$PLAN_SKILL" \
		"[--cycles <1-5>] [--depth <balanced|full>]" \
		"--scope-plan {validated-scope-plan} [--strict] --rounds {cycles} [--depth {depth}] [--isolated] --requirements {work-requirements}" \
		'Always pass `--rounds {cycles}`, so the remediation budget defaults to two cycles' \
		"Both are review-convergence controls: never pass them to the validator."
	require_phrases "$LINEAR_SKILL" \
		"[--depth {depth}] [--isolated] --requirements {issue-requirements}" \
		"run the invocation inside one delegated agent on this session's model and add \`--isolated\`" \
		'On Codex, or when nesting is unavailable, invoke the skill directly without `--isolated`.'
	require_phrases "$LINEAR_SHIPPING" 'Also pass `--depth {prior-depth}`'
	require_phrases "$PLAN_SHIPPING" 'Also pass `--depth {prior-depth}`' 'Never forward `--rounds` or `--cycles` here'
	require_phrases "$POLICY" 'When `ISOLATED=true`, the caller already runs this whole invocation inside one delegated agent'
}

@test "code review records empty downstream stages as skipped and batches ledger writes" {
	require_phrases "$CODE_REVIEW" \
		"If every primary reviewer returned zero findings, do not launch the validator" \
		'record `slop-meta` as `skipped` with `Skipped:` evidence'
	require_phrases "$EXECUTION_CONTRACT" \
		'node "$REVIEW_SKILL_DIR/scripts/review-execution.js" record "$REVIEW_RUN" --manifest "$MANIFEST"' \
		"No other job may be skipped."
	require_phrases "$POLICY" '`--entry` also takes a JSON array' 'none needs a `--help` lookup'
}

@test "review instructions leave scratch directories instead of running rm -rf" {
	run grep -F "trap 'rm -rf" "$CONVENTION"
	[ "$status" -eq 1 ]
	require_phrases "$CONVENTION" 'Leave `$REVIEW_SCOPE_DIR` in the temporary directory when the review ends'
	require_phrases "$DISCIPLINE" 'Put scratch files outside the repository in a fresh `mktemp -d` directory and leave it there'
	require_phrases "$MINING" 'put them in a fresh `mktemp -d` directory outside the repository and leave it there'
}
