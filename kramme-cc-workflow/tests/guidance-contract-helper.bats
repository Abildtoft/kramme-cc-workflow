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

	write_file "$passing" <<'EOF'
## Ordered Gates

### First Gate — Regular Review
Invoke `kramme:pr:code-review --parallel --inline`.

### Second Gate — Convention Review
Invoke `kramme:pr:convention-review --inline`.

### Third Gate — Refactor Discovery
Invoke `kramme:code:refactor-opportunities pr`.

## Completion Rules
EOF

	write_file "$broken" <<'EOF'
## Ordered Gates

The commands used here are kramme:pr:code-review --parallel --inline, kramme:pr:convention-review --inline, and kramme:code:refactor-opportunities pr.

### Gate 1: Regular Code Review
Invoke `kramme:code:refactor-opportunities pr`.

### Gate 2: Convention Review
Invoke `kramme:pr:convention-review --inline`.

### Gate 3: PR-Scoped Refactor Discovery
Invoke `kramme:pr:code-review --parallel --inline`.

## Completion Rules
EOF

	assert_contract_passes review-gate-order "$passing"
	assert_contract_fails_with review-gate-order "$broken" "ordered gate invocations is wrong"
}
