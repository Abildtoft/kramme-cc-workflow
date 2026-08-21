#!/usr/bin/env bats

load 'test_helper/common'

setup() {
	CHECKER="$BATS_TEST_DIRNAME/test_helper/guidance_contracts.py"
}

assert_contract_passes() {
	local check="$1"
	local fixture="$2"

	run python3 "$CHECKER" "$check" "$fixture"
	[ "$status" -eq 0 ] || { echo "$output"; false; }
}

assert_contract_fails_with() {
	local check="$1"
	local fixture="$2"
	local diagnostic="$3"

	run python3 "$CHECKER" "$check" "$fixture"
	[ "$status" -eq 1 ]
	[[ "$output" == *"$diagnostic"* ]]
}

@test "delegated result schema accepts paraphrased fields and rejects relocated vocabulary" {
	passing="$BATS_TEST_TMPDIR/result-passing.md"
	broken="$BATS_TEST_TMPDIR/result-broken.md"
	unvalidated="$BATS_TEST_TMPDIR/result-unvalidated.md"
	negated="$BATS_TEST_TMPDIR/result-negated.md"

	write_file "$passing" <<'EOF'
## Called by Another Skill

For delegated calls:

6. Return `INTERVIEW RESULT:` with all of:
   - topic classification together with the validated
     hypothesis,
   - each decision, its rationale, and an impact map to the affected source file or section,
   - each non-goal, its rationale, and either stated-vs-actual divergence or explicit alignment,
   - initial and final confidence, including the overall percentage and interview round count,
   - the evidence ledger and its evidence-confidence profile, or the topic-coverage status,
   - risks, source references, and unresolved `MISSING REQUIREMENT` items.

## Next Section
EOF

	write_file "$negated" <<'EOF'
## Called by Another Skill

6. Return `INTERVIEW RESULT:` with all of:
   - do not include the validated hypothesis or topic classification,
   - decisions with rationales and an impact map to each affected source,
   - non-goals with rationales, divergence, and explicit alignment,
   - initial and final confidence with percentage and round count,
   - an evidence ledger and topic-coverage status,
   - missing requirement items, risks, and source references.
EOF

	write_file "$broken" <<'EOF'
## Called by Another Skill

6. Return `INTERVIEW RESULT:` after the interview.

## Historical Field Vocabulary

- validated hypothesis and topic classification,
- decisions with rationales and an impact map to an affected source file,
- non-goals with rationales and stated-vs-actual divergence or alignment,
- initial and final confidence with percentage and round count,
- evidence ledger and topic-coverage status,
- unresolved `MISSING REQUIREMENT` items, risks, and source references.
EOF

	write_file "$unvalidated" <<'EOF'
## Called by Another Skill

6. Return `INTERVIEW RESULT:` with all of:
   - an unvalidated hypothesis and topic classification,
   - decisions with rationales and an impact map to each affected source,
   - non-goals with rationales, divergence, and explicit alignment,
   - initial and final confidence with percentage and round count,
   - an evidence ledger and topic-coverage status,
   - missing requirement items, risks, and source references.
EOF

	assert_contract_passes discovery-result-schema "$passing"
	assert_contract_fails_with \
		discovery-result-schema \
		"$broken" \
		"missing the numbered INTERVIEW RESULT return block"
	assert_contract_fails_with \
		discovery-result-schema \
		"$unvalidated" \
		"missing field 'hypothesis'"
	assert_contract_fails_with \
		discovery-result-schema \
		"$negated" \
		"missing field 'hypothesis'"
}

@test "delegation failure boundary accepts a paraphrase and rejects behavior moved out of Step 2" {
	passing="$BATS_TEST_TMPDIR/failure-passing.md"
	broken="$BATS_TEST_TMPDIR/failure-broken.md"
	missing_triggers="$BATS_TEST_TMPDIR/failure-missing-triggers.md"
	inverted="$BATS_TEST_TMPDIR/failure-inverted.md"

	write_file "$passing" <<'EOF'
## Step 2: Delegate the Interview

On delegation errors, timeouts, an absent `INTERVIEW RESULT:` marker, or missing required fields, report the failure and stop. Do not replay the interview, write an SIW artifact, or emit `PLAN:`.

## Step 3: Synthesize
EOF

	write_file "$inverted" <<'EOF'
## Step 2: Delegate the Interview

On delegation errors, timeouts, a missing `INTERVIEW RESULT:` marker, or missing required fields, do not stop; replay the interview, write an SIW artifact, and emit `PLAN:`.

## Step 3: Synthesize
EOF

	write_file "$broken" <<'EOF'
## Step 2: Delegate the Interview

On a failed delegation, follow generic error handling.

## Historical Delegation Note

On delegation errors, timeouts, an absent `INTERVIEW RESULT:` marker, or missing required fields, report the failure and stop. Do not replay the interview, write an SIW artifact, or emit `PLAN:`.
EOF

	write_file "$missing_triggers" <<'EOF'
## Step 2: Delegate the Interview

On delegation errors or timeouts, report the failure and stop without replaying the interview, writing an SIW artifact, or emitting `PLAN:`. The `INTERVIEW RESULT:` required fields are documented by the caller.

## Step 3: Synthesize
EOF

	assert_contract_passes discovery-failure-boundary "$passing"
	assert_contract_fails_with \
		discovery-failure-boundary \
		"$broken" \
		"INTERVIEW RESULT required-field validation paragraph"
	assert_contract_fails_with \
		discovery-failure-boundary \
		"$missing_triggers" \
		"missing result marker trigger"
	assert_contract_fails_with \
		discovery-failure-boundary \
		"$inverted" \
		"affirmative malformed-payload stop clause"
}

@test "issue intake accepts equivalent recording language and rejects later state capture" {
	passing="$BATS_TEST_TMPDIR/intake-passing.md"
	broken="$BATS_TEST_TMPDIR/intake-broken.md"
	negated="$BATS_TEST_TMPDIR/intake-negated.md"
	delayed="$BATS_TEST_TMPDIR/intake-delayed.md"

	write_file "$passing" <<'EOF'
## Step 2: Resolve the Issue and Branch

1. Require `git status --porcelain` to be empty. Record the current branch in `{intake-branch}` and the entry commit in `{intake-head}`.
2. Find the issue file.

## Step 3: Implement
EOF

	write_file "$delayed" <<'EOF'
## Step 2: Resolve the Issue and Branch

1. Require `git status --porcelain` to be empty. Switch to the issue branch. Capture the current commit and branch as `{intake-head}` and `{intake-branch}`.
2. Find the issue file.

## Step 3: Implement
EOF

	write_file "$broken" <<'EOF'
## Step 2: Resolve the Issue and Branch

1. Require `git status --porcelain` to be empty.
2. Find the issue file.

Capture the current commit and branch as `{intake-head}` and `{intake-branch}`.

## Step 3: Implement
EOF

	write_file "$negated" <<'EOF'
## Step 2: Resolve the Issue and Branch

1. Require `git status --porcelain` to be empty. Never record the current commit in `{intake-head}` or the current branch in `{intake-branch}`.
2. Find the issue file.

## Step 3: Implement
EOF

	assert_contract_passes issue-intake-state "$passing"
	assert_contract_fails_with issue-intake-state "$broken" "item 1 does not affirmatively record its entry state"
	assert_contract_fails_with issue-intake-state "$negated" "item 1 does not affirmatively record its entry state"
	assert_contract_fails_with issue-intake-state "$delayed" "item 1 does not affirmatively record its entry state"
}

@test "issue stage order follows actions instead of heading labels" {
	passing="$BATS_TEST_TMPDIR/stage-passing.md"
	broken="$BATS_TEST_TMPDIR/stage-broken.md"
	decoy="$BATS_TEST_TMPDIR/stage-decoy.md"
	prohibited="$BATS_TEST_TMPDIR/stage-prohibited.md"

	write_file "$passing" <<'EOF'
## Resolve the Prepared Branch

Run `git ls-remote --heads origin "refs/heads/{issue-branch}"` and require absence.

## Run Issue Implementation

Otherwise call `kramme:siw:issue-implement` with `{issue-id} --auto`.

### Commit the Prepared Implementation

4. Stage only classified paths with `git add -- <path>...`.

## Hand Off to Completion

Invoke `kramme:pr:complete-work` once with the prepared arguments.
EOF

	write_file "$broken" <<'EOF'
## Step 2: Resolve the Issue and Branch

Run `git ls-remote --heads origin "refs/heads/{issue-branch}"` and require absence.

## Step 3: Implement the SIW Issue

Otherwise invoke `kramme:pr:complete-work` with `{issue-id} --auto`.

### Implementation Commit Boundary

4. Stage only classified paths with `git add -- <path>...`.

## Step 4: Complete the Pull Request Workflow

Invoke `kramme:siw:issue-implement` once with the prepared arguments.
EOF

	write_file "$decoy" <<'EOF'
## Historical Example Only

Run `git ls-remote --heads origin "refs/heads/{issue-branch}"` and require absence.

Otherwise call `kramme:siw:issue-implement` with `{issue-id} --auto`.

4. Stage only classified paths with `git add -- <path>...`.

Invoke `kramme:pr:complete-work` once with the prepared arguments.

## Current Workflow

Complete the Pull Request before running issue implementation.
EOF

	write_file "$prohibited" <<'EOF'
## Resolve the Prepared Branch

Run `git ls-remote --heads origin "refs/heads/{issue-branch}"` and require absence.

## Run Issue Implementation

Otherwise call `kramme:siw:issue-implement` with `{issue-id} --auto`.

### Commit the Prepared Implementation

4. Stage only classified paths with `git add -- <path>...`.

## Hand Off to Completion

Do not invoke `kramme:pr:complete-work` once; this workflow is not ready.
EOF

	assert_contract_passes issue-stage-order "$passing"
	assert_contract_fails_with issue-stage-order "$broken" "missing anchor 'implementation delegation'"
	assert_contract_fails_with issue-stage-order "$decoy" "missing anchor 'branch boundary resolution'"
	assert_contract_fails_with issue-stage-order "$prohibited" "missing anchor 'completion delegation'"
}

@test "review gate order follows invocations instead of numbered headings" {
	passing="$BATS_TEST_TMPDIR/gates-passing.md"
	broken="$BATS_TEST_TMPDIR/gates-broken.md"
	prohibited="$BATS_TEST_TMPDIR/gates-prohibited.md"

	write_file "$passing" <<'EOF'
## Applicability Evaluation

### First Gate — Regular Review
When active, invoke `kramme:pr:code-review --parallel --inline`.

### Second Gate — Convention Review
When active, invoke `kramme:pr:convention-review --inline`.

### Third Gate — Overengineering Review
When active in normal mode, invoke `kramme:pr:overengineering-review` with the exact sentinel-last arguments `--requirements {work-requirements}`.

### Fourth Gate — Refactor Discovery
When active, invoke `kramme:code:refactor-opportunities` with `pr`.

## Completion Rules
EOF

	write_file "$broken" <<'EOF'
## Applicability Evaluation

The commands used here are kramme:pr:code-review, kramme:pr:convention-review, kramme:pr:overengineering-review, and kramme:code:refactor-opportunities.

### Gate 1: Regular Code Review
When active, invoke `kramme:code:refactor-opportunities` with `pr`.

### Gate 2: Convention Review
When active, invoke `kramme:pr:convention-review --inline`.

### Gate 3: Overengineering Review
When active in normal mode, invoke `kramme:pr:overengineering-review` with the exact sentinel-last arguments `--requirements {work-requirements}`.

### Gate 4: PR-Scoped Refactor Discovery
When active, invoke `kramme:pr:code-review --parallel --inline`.

## Completion Rules
EOF

	write_file "$prohibited" <<'EOF'
## Applicability Evaluation

Do not invoke `kramme:pr:code-review --parallel --inline`.
Do not invoke `kramme:pr:convention-review --inline`.
Do not invoke `kramme:pr:overengineering-review` with the exact sentinel-last arguments `--requirements {work-requirements}`.
Do not invoke `kramme:code:refactor-opportunities` with `pr`.
EOF

	assert_contract_passes review-gate-order "$passing"
	assert_contract_fails_with review-gate-order "$broken" "ordered gate invocations is wrong"
	assert_contract_fails_with review-gate-order "$prohibited" "missing anchor 'regular code-review invocation'"
}

@test "drift self-update guidance keeps explanation offer and approval in one ordered block" {
	passing="$BATS_TEST_TMPDIR/drift-update-passing.md"
	negated="$BATS_TEST_TMPDIR/drift-update-negated.md"
	relocated="$BATS_TEST_TMPDIR/drift-update-relocated.md"
	reordered="$BATS_TEST_TMPDIR/drift-update-reordered.md"
	dirty_update="$BATS_TEST_TMPDIR/drift-update-dirty.md"
	modal_negation="$BATS_TEST_TMPDIR/drift-update-modal-negation.md"
	dirty_contradiction="$BATS_TEST_TMPDIR/drift-update-dirty-contradiction.md"

	write_file "$passing" <<'EOF'
If staged, unstaged, or untracked in-scope changes exist, stop before plan edits. Once the worktree is clean and committed drift remains, explain the affected paths and stale assumptions first. Then offer to update the plan in place and wait for explicit approval before changing it. Do not ask the user for a replacement plan.
EOF

	write_file "$negated" <<'EOF'
If staged, unstaged, or untracked in-scope changes exist, stop before plan edits. Once the worktree is clean and committed drift remains, explain the affected paths and stale assumptions first. Then offer to update the plan in place, but do not wait for explicit approval before changing it. Do not ask the user for a replacement plan.
EOF

	write_file "$relocated" <<'EOF'
If staged, unstaged, or untracked in-scope changes exist, stop before plan edits. Once the worktree is clean and committed drift remains, explain the affected paths and stale assumptions. Explicit approval is important.

Offer to update the plan in place. Do not ask the user for a replacement plan.
EOF

	write_file "$reordered" <<'EOF'
If staged, unstaged, or untracked in-scope changes exist, stop before plan edits. Once the worktree is clean and committed drift remains, offer to update the plan in place and wait for explicit approval before changing it. Afterwards, explain the affected paths and stale assumptions. Do not ask the user for a replacement plan.
EOF

	write_file "$dirty_update" <<'EOF'
If staged, unstaged, or untracked in-scope changes exist, continue from that evidence. Once the worktree is clean and committed drift remains, explain the affected paths and stale assumptions first. Then offer to update the plan in place and wait for explicit approval before changing it. Do not ask the user for a replacement plan.
EOF

	write_file "$modal_negation" <<'EOF'
If staged, unstaged, or untracked in-scope changes exist, stop before plan edits. Once the worktree is clean and committed drift remains, explain the affected paths and stale assumptions first. Then offer to update the plan in place, but should not wait for explicit approval before changing it. Do not ask the user for a replacement plan.
EOF

	write_file "$dirty_contradiction" <<'EOF'
If staged, unstaged, or untracked in-scope changes exist, stop before plan edits, then update the plan from those uncommitted changes. Once the worktree is clean and committed drift remains, explain the affected paths and stale assumptions first. Then offer to update the plan in place and wait for explicit approval before changing it. Do not ask the user for a replacement plan.
EOF

	assert_contract_passes drift-self-update-guidance "$passing"
	assert_contract_fails_with \
		drift-self-update-guidance \
		"$negated" \
		"ordered approval-gated in-place update contract"
	assert_contract_fails_with \
		drift-self-update-guidance \
		"$relocated" \
		"ordered approval-gated in-place update contract"
	assert_contract_fails_with \
		drift-self-update-guidance \
		"$reordered" \
		"ordered approval-gated in-place update contract"
	assert_contract_fails_with \
		drift-self-update-guidance \
		"$dirty_update" \
		"ordered approval-gated in-place update contract"
	assert_contract_fails_with \
		drift-self-update-guidance \
		"$modal_negation" \
		"ordered approval-gated in-place update contract"
	assert_contract_fails_with \
		drift-self-update-guidance \
		"$dirty_contradiction" \
		"ordered approval-gated in-place update contract"
}

@test "standalone refresh guidance preserves eligibility confirmation and staging boundaries" {
	passing="$BATS_TEST_TMPDIR/standalone-refresh-passing.md"
	missing_eligibility="$BATS_TEST_TMPDIR/standalone-refresh-missing-eligibility.md"
	missing_confirmation="$BATS_TEST_TMPDIR/standalone-refresh-missing-confirmation.md"
	missing_parent="$BATS_TEST_TMPDIR/standalone-refresh-missing-parent.md"
	negated_eligibility="$BATS_TEST_TMPDIR/standalone-refresh-negated-eligibility.md"
	negated_confirmation="$BATS_TEST_TMPDIR/standalone-refresh-negated-confirmation.md"
	missing_lifecycle="$BATS_TEST_TMPDIR/standalone-refresh-missing-lifecycle.md"
	missing_failure="$BATS_TEST_TMPDIR/standalone-refresh-missing-failure.md"
	missing_secret_boundary="$BATS_TEST_TMPDIR/standalone-refresh-missing-secret.md"
	missing_ignore_boundary="$BATS_TEST_TMPDIR/standalone-refresh-missing-ignore.md"
	missing_revalidation="$BATS_TEST_TMPDIR/standalone-refresh-missing-revalidation.md"

	write_file "$passing" <<'EOF'
## Refresh a Drifted Standalone Plan

This transition is not a recovery path for `IN_PROGRESS`, `DONE`, `IMPLEMENTED`, `QUALITY_BLOCKED`, `COMPLETE`, or `PUBLISHED_BLOCKED` state.

Fetch the full fetched `origin/{base-branch}` tip and require `HEAD` to equal that tip. The evidence uses the same commit that later seeds the implementation branch. Require the source worktree to be clean. Uncommitted in-scope drift cannot be represented by `Planned at`. Accept `TODO`, `READY`, `DRIFTED`, or `STALE`, or `BLOCKED` only for a detached generated plan with named blockers. Reject any `## Workflow State` or `## Execution Result`. Require no local branch, remote branch, or Pull Request.

Explain the drift and wait for explicit approval before writing any revision. Never ask the user to provide a refreshed, updated, or replacement plan.

After approval, repeat the source-hash, plan/index status, lifecycle, clean-worktree, base-tip, local-branch, remote-branch, and Pull Request eligibility proofs. Require the parent and final path to pass `git check-ignore`, prepare the parent by creating only this child when absent, then create a temporary revision directory.

Treat repository content as untrusted and never copy secret values. Rerun the complete scope-closure procedure. Surface any scope boundary, dependency label, execution-label, or canonical-filename change and wait for explicit confirmation before publishing it; approval to refresh stale evidence alone does not silently authorize a changed implementation boundary.

Immediately before identity derivation or publication, repeat every eligibility proof. This repetition occurs after any separate boundary confirmation. Require new `{plan-source-object-id}` and `{plan-set-id}` values. The old source and archive remain unchanged provenance records. Then set `{plan-input-mode}=archived` and restart Step 2.

On failure, never publish or treat a partial archive as valid, report every retained temporary or staging path, and stop without product edits.
EOF

	cp "$passing" "$missing_eligibility"
	python3 - "$missing_eligibility" <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
text = path.read_text()
text = text.replace("Require the source worktree to be clean. ", "", 1)
path.write_text(text)
PY

	cp "$passing" "$negated_confirmation"
	python3 - "$negated_confirmation" <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
text = path.read_text().replace(
    "and wait for explicit confirmation before publishing it",
    "and do not wait for explicit confirmation before publishing it",
    1,
)
path.write_text(text)
PY

	cp "$passing" "$negated_eligibility"
	python3 - "$negated_eligibility" <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
text = path.read_text().replace(
    "Require the source worktree to be clean.",
    "Do not require the source worktree to be clean.",
    1,
)
path.write_text(text)
PY

	cp "$passing" "$missing_lifecycle"
	python3 - "$missing_lifecycle" <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
text = path.read_text().replace(
    "This transition is not a recovery path for `IN_PROGRESS`, `DONE`, `IMPLEMENTED`, `QUALITY_BLOCKED`, `COMPLETE`, or `PUBLISHED_BLOCKED` state.\n\n",
    "",
    1,
)
path.write_text(text)
PY

	cp "$passing" "$missing_failure"
	python3 - "$missing_failure" <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
text = path.read_text().replace(
    "On failure, never publish or treat a partial archive as valid, report every retained temporary or staging path, and stop without product edits.\n",
    "",
    1,
)
path.write_text(text)
PY

	cp "$passing" "$missing_secret_boundary"
	python3 - "$missing_secret_boundary" <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
text = path.read_text().replace(" and never copy secret values", "", 1)
path.write_text(text)
PY

	cp "$passing" "$missing_ignore_boundary"
	python3 - "$missing_ignore_boundary" <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
text = path.read_text().replace("Require the parent and final path to pass `git check-ignore`, ", "", 1)
path.write_text(text)
PY

	cp "$passing" "$missing_revalidation"
	python3 - "$missing_revalidation" <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
text = path.read_text().replace(
    "After approval, repeat the source-hash, plan/index status, lifecycle, clean-worktree, base-tip, local-branch, remote-branch, and Pull Request eligibility proofs. ",
    "After approval, ",
    1,
)
path.write_text(text)
PY

	cp "$passing" "$missing_confirmation"
	python3 - "$missing_confirmation" <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
text = path.read_text()
text = text.replace(
    " and wait for explicit confirmation before publishing it; approval to refresh stale evidence alone does not silently authorize a changed implementation boundary",
    " before publishing",
    1,
)
path.write_text(text)
PY

	cp "$passing" "$missing_parent"
	python3 - "$missing_parent" <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
text = path.read_text().replace("creating only this child when absent", "requiring the child to exist", 1)
path.write_text(text)
PY

	assert_contract_passes standalone-refresh-guidance "$passing"
	assert_contract_fails_with \
		standalone-refresh-guidance \
		"$missing_eligibility" \
		"standalone attachment self-update is missing concepts"
	assert_contract_fails_with \
		standalone-refresh-guidance \
		"$missing_confirmation" \
		"standalone attachment self-update is missing concepts"
	assert_contract_fails_with \
		standalone-refresh-guidance \
		"$missing_parent" \
		"standalone attachment self-update is missing concepts"
	assert_contract_fails_with \
		standalone-refresh-guidance \
		"$negated_eligibility" \
		"must affirmatively require a clean source worktree"
	assert_contract_fails_with \
		standalone-refresh-guidance \
		"$negated_confirmation" \
		"must affirmatively wait for boundary confirmation"
	assert_contract_fails_with \
		standalone-refresh-guidance \
		"$missing_lifecycle" \
		"standalone attachment self-update is missing concepts"
	assert_contract_fails_with \
		standalone-refresh-guidance \
		"$missing_failure" \
		"standalone attachment self-update is missing concepts"
	assert_contract_fails_with \
		standalone-refresh-guidance \
		"$missing_secret_boundary" \
		"standalone attachment self-update is missing concepts"
	assert_contract_fails_with \
		standalone-refresh-guidance \
		"$missing_ignore_boundary" \
		"standalone attachment self-update is missing concepts"
	assert_contract_fails_with \
		standalone-refresh-guidance \
		"$missing_revalidation" \
		"standalone attachment self-update is missing concepts"
}
