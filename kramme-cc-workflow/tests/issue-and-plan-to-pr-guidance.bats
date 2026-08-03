#!/usr/bin/env bats

@test "SIW issue-to-PR prepares one safe branch before autonomous implementation" {
	run bash -c '
    set -e
    cd "'"$BATS_TEST_DIRNAME"'/.."
    skill="skills/kramme:siw:issue-to-pr/SKILL.md"

    test -f "$skill"
    grep -qF "argument-hint: \"<issue-id> [--strict] [--ship]\"" "$skill"
    grep -qF "disable-model-invocation: true" "$skill"
    grep -qF "kramme:siw:issue-implement" "$skill"
    grep -qF "{issue-id} --auto" "$skill"
    grep -qF "kramme:pr:complete-work" "$skill"
    grep -qF -- "--archive-key siw-issue-to-pr" "$skill"
    grep -qF "git status --porcelain" "$skill"
    grep -qF "git check-ref-format --branch \"{issue-branch}\"" "$skill"
    grep -qF "gh pr list --head \"{issue-branch}\" --state all" "$skill"
    grep -qF "git ls-remote --heads origin \"refs/heads/{issue-branch}\"" "$skill"
	    grep -qF "git diff --quiet \"{intake-head}\" \"origin/{base-branch}\" -- siw/" "$skill"
	    grep -qF "requires all committed SIW planning state to be landed on the fetched base" "$skill"
	    grep -qF "git merge-base \"origin/{base-branch}\" HEAD" "$skill"
	    grep -qF "matching only the SIW subtree is insufficient" "$skill"
	    grep -qF "set \`EXECUTION_MODE=complete-resume\`" "$skill"
	    grep -qF "do not invoke \`kramme:siw:issue-implement\` again" "$skill"
	    grep -qF "continue directly to Step 4" "$skill"
	    grep -qF "## Resolution" "$skill"
	    grep -qF "status \`DONE\` or \`IN REVIEW\`" "$skill"
    grep -qF "issue file, \`siw/OPEN_ISSUES_OVERVIEW.md\`, and \`siw/LOG.md\`" "$skill"
    grep -qF "Do not invoke \`kramme:workflow-artifacts:cleanup --auto\`" "$skill"
  '

	[ "$status" -eq 0 ]

	run python3 \
		"$BATS_TEST_DIRNAME/test_helper/guidance_contracts.py" \
		issue-intake-state \
		"$BATS_TEST_DIRNAME/../skills/kramme:siw:issue-to-pr/SKILL.md"
	[ "$status" -eq 0 ] || { echo "$output"; false; }

	run python3 \
		"$BATS_TEST_DIRNAME/test_helper/guidance_contracts.py" \
		issue-stage-order \
		"$BATS_TEST_DIRNAME/../skills/kramme:siw:issue-to-pr/SKILL.md"
	[ "$status" -eq 0 ] || { echo "$output"; false; }
}

@test "generated plan-to-PR enforces dependency drift scope and artifact isolation" {
	run bash -c '
    set -e
    cd "'"$BATS_TEST_DIRNAME"'/.."
    skill="skills/kramme:code:plan-to-pr/SKILL.md"

    test -f "$skill"
    grep -qF "argument-hint: \"<PR_PLAN_W##L_*.md> [--strict] [--ship]\"" "$skill"
    grep -qF "PR_PLAN_INDEX.md" "$skill"
    grep -qF "PR_PLAN_REJECTIONS.md" "$skill"
    grep -qF "For \`BLOCKED\`, require every named blocker row in the index to be \`DONE\`" "$skill"
	    grep -qF "**Archived input:** \`.context/code-plan-to-pr/{plan-set-id}/plans/\`" "$skill"
	    grep -qF "Build a deterministic binary manifest from every root \`PR_PLAN_*.md\` artifact" "$skill"
	    grep -qF "git hash-object --no-filters -- \"{basename}\"" "$skill"
	    grep -qF "Hash the manifest with \`git hash-object --stdin\`" "$skill"
	    grep -qF "any index, plan-body, rejection-record, filename, or inventory change creates a different set identity" "$skill"
	    grep -qF "Use the full \`{plan-set-id}\` for storage" "$skill"
	    grep -qF "Store \`{plan-input-mode}\` as \`root\` or \`archived\`." "$skill"
    grep -qF "kramme:code:breakdown-findings --reconcile" "$skill"
    grep -qF "Reject plans containing an \`## Implementation Setup\` section." "$skill"
    grep -qF "Do not execute the plan'\''s command blocks." "$skill"
    grep -qF "build a Git pathspec as \`:(literal){path}\`" "$skill"
    grep -qF "git diff --stat \"{planned-at}\" -- \"\${GIT_PATHS[@]}\"" "$skill"
    grep -qF "git status --short -- \"\${GIT_PATHS[@]}\"" "$skill"
    grep -qF "Keep the established archive in place." "$skill"
    grep -qF "never retain the pre-move root path" "$skill"
    grep -qF "preserves the complete plan set and rejection record for retries and later waves" "$skill"
    grep -qF "every dirty path is a root-level \`PR_PLAN_*.md\` file" "$skill"
    grep -qF "git ls-files --error-unmatch -- \":(literal){path}\"" "$skill"
	    grep -qF "gh pr view \"{url}\" --json state,mergedAt,baseRefName,mergeCommit" "$skill"
	    grep -qF "git check-ref-format --branch \"{final-branch}\"" "$skill"
	    grep -qF "gh pr list --head \"{final-branch}\" --state all" "$skill"
	    grep -qF "require an exact same-repository GitHub Pull Request URL with a numeric identifier" "$skill"
    grep -qF "Reject symbolic refs, abbreviated OIDs, and leading \`-\`." "$skill"
    grep -qF "git merge-base --is-ancestor \"{landing-commit}\" \"origin/{base-branch}\"" "$skill"
    grep -qF "require its tip to equal the fetched \`origin/{base-branch}\` tip exactly" "$skill"
	    grep -qF "never adopt, reset, delete, or rewrite an uncheckpointed local branch with commits" "$skill"
	    grep -qF "git diff --name-only \"{base-commit}\"..\"{checkpoint-head}\"" "$skill"
	    grep -qF "When \`COMPLETION_RESUME=true\`, do not invoke \`kramme:code:work-from-plan\` again" "$skill"
	    grep -qF "Stage: IMPLEMENTED" "$skill"
	    grep -qF "Stage: QUALITY_BLOCKED" "$skill"
	    grep -qF "Stage: PUBLISHED_BLOCKED" "$skill"
	    grep -qF "structured disposition to be \`prepublication_blocked\` or \`published_blocked\`" "$skill"
	    grep -qF "The mere appearance of a concurrent remote branch is never evidence" "$skill"
	    grep -qF "out-of-scope post-publication path" "$skill"
    grep -qF "kramme:code:work-from-plan" "$skill"
    grep -qF "route \`direct\`" "$skill"
    grep -qF -- "--archive-key code-plan-to-pr" "$skill"
    grep -qF -- "--scope-plan {active-plan}" "$skill"
    grep -qF "Require the delegated work branch and local head/tree to equal the observed branch" "$skill"
    grep -qF "stop without advancing plan state on the first mismatch" "$skill"
    grep -qF "Set the selected plan header and matching index row to \`DONE\`." "$skill"
    grep -qF "full completion commit OID" "$skill"
    grep -qF "Do not record a \`Landed commit\` merely because implementation or Pull Request creation completed." "$skill"
    grep -qF "Later plan input: pass the selected \`PR_PLAN_W##L_*.md\` file from this archive" "$skill"
    grep -qF "never invoke broad workflow-artifact cleanup" "$skill"

    validate_line=$(grep -nF "## Step 2: Validate the Plan Set" "$skill" | cut -d: -f1)
    archive_line=$(grep -nF "## Step 3: Archive Planning Artifacts" "$skill" | cut -d: -f1)
    branch_line=$(grep -nF "## Step 4: Establish the Plan Branch" "$skill" | cut -d: -f1)
    implement_line=$(grep -nF "## Step 5: Implement the Plan" "$skill" | cut -d: -f1)
    complete_line=$(grep -nF "## Step 6: Complete the Pull Request Workflow" "$skill" | cut -d: -f1)
    [ "$validate_line" -lt "$archive_line" ]
    [ "$archive_line" -lt "$branch_line" ]
    [ "$branch_line" -lt "$implement_line" ]
    [ "$implement_line" -lt "$complete_line" ]
  '

	[ "$status" -eq 0 ]
}

@test "shared completion workflow preserves ordered bounded review and shipping proof" {
	run bash -c '
    set -e
    cd "'"$BATS_TEST_DIRNAME"'/.."
    skill="skills/kramme:pr:complete-work/SKILL.md"
    review="skills/kramme:pr:complete-work/references/review-convergence.md"
    shipping="skills/kramme:pr:complete-work/references/shipping-contract.md"

    test -f "$skill"
    test -f "$review"
    test -f "$shipping"
    grep -qF "user-invocable: false" "$skill"
    grep -qF "Accept only \`siw-issue-to-pr\` or \`code-plan-to-pr\`" "$skill"
    grep -qF "Require it exactly once when \`{archive-key}\` is \`code-plan-to-pr\`" "$skill"
    grep -qF "Store the exact normalized list as \`VALIDATED_SCOPE_PATHS\`" "$skill"
    grep -qF "every proposed edit, dirty path, staged path, and committed remediation path" "$skill"
    grep -qF "Stop before publication on the first out-of-scope path." "$skill"
    grep -qF "gh pr list --head \"{work-branch}\" --state all" "$skill"
    grep -qF "git ls-remote --heads origin \"refs/heads/{work-branch}\"" "$skill"
    grep -qF "kramme:pr:code-review --parallel --inline" "$skill"
    grep -qF "kramme:pr:convention-review --inline" "$skill"
    grep -qF "kramme:code:refactor-opportunities pr" "$skill"
	    grep -qF "kramme:verify:run" "$skill"
	    grep -qF "Completion disposition: success | prepublication_blocked | published_blocked" "$skill"
	    grep -qF "Pre-publication quality and verification: passed" "$skill"
	    grep -qF "Publication state: absent | remote branch only | open Pull Request" "$skill"
	    grep -qF "Work branch: {work-branch}" "$skill"

    grep -qF "MAX_AUTOMATIC_REMEDIATION_CYCLES=3" "$review"
    grep -qF "run exactly one validation-only round" "$review"
    grep -qF "Do not run a second validation-only round." "$review"
    grep -qF ".context/{archive-key}/reviews/" "$review"

    grep -qF "kramme:pr:create --auto --require-generated-description --authorize-history-rewrite" "$shipping"
    grep -qF "kramme:pr:fix-ci --no-consolidate" "$shipping"
	    grep -qF "Do not combine it with \`--auto\`." "$shipping"
	    grep -qF "Completion disposition: published_blocked" "$shipping"
	    grep -qF "Work branch: {work-branch}" "$shipping"
	    grep -qF "Blocker: {exact delegated blocker}" "$shipping"
	    grep -qF "Publication state: remote branch only" "$shipping"
	    grep -qF "callers must persist their implementation-complete source state" "$shipping"
    grep -qF "git rev-parse '\''HEAD^{tree}'\''" "$shipping"
    grep -qF "headRefOid" "$shipping"
    grep -qF "gh pr checks --json name,state,bucket,link,workflow" "$shipping"
    grep -qF "no checks reported" "$shipping"
    grep -qF "reviewThreads(first: 100, after: \$endCursor)" "$shipping"
    grep -qF "kramme:verify:run" "$shipping"
  '

	[ "$status" -eq 0 ]

	run python3 \
		"$BATS_TEST_DIRNAME/test_helper/guidance_contracts.py" \
		review-gate-order \
		"$BATS_TEST_DIRNAME/../skills/kramme:pr:complete-work/references/review-convergence.md"
	[ "$status" -eq 0 ] || { echo "$output"; false; }
}

@test "single SIW issue auto mode remains evidence gated" {
	run bash -c '
    set -e
    cd "'"$BATS_TEST_DIRNAME"'/.."
    skill="skills/kramme:siw:issue-implement/SKILL.md"
    closeout="skills/kramme:siw:issue-implement/references/issue-closeout.md"

    grep -qF "argument-hint: \"<issue-id> [--auto] | --team [issue-ids | '\''phase N'\''] [--auto]\"" "$skill"
    grep -qF "set \`AUTO_MODE=true\`" "$skill"
    grep -qF "auto mode never assumes ownership of pre-existing work" "$skill"
    grep -qF "Gate Existing Status Before Implementation" "$skill"
    grep -qF "standard auto mode must not reset it to \`IN PROGRESS\`" "$skill"
    grep -qF "The closeout idempotency check remains as a final race-safe guard" "$skill"
    grep -qF "AUTO: proceeding with autonomous implementation" "$skill"
    grep -qF "skip the approach question and choose **Autonomous Implementation**" "$skill"
    grep -qF "never bypasses dirty-worktree handling, HITL confirmation" "$skill"
    grep -qF "If \`AUTO_MODE=true\`, do not ask the confidence question." "$closeout"
    grep -qF "\`DONE\` only when every acceptance criterion is satisfied" "$closeout"
    grep -qF "\`IN REVIEW\` when implementation and automated verification are complete" "$closeout"

    status_gate=$(grep -nF "### 1.3 Gate Existing Status Before Implementation" "$skill" | cut -d: -f1)
    git_state=$(grep -nF "## Step 2: Verify Git State" "$skill" | cut -d: -f1)
    auto_approach=$(grep -nF "If \`AUTO_MODE=true\`, skip the approach question" "$skill" | cut -d: -f1)
    [ "$status_gate" -lt "$git_state" ]
    [ "$git_state" -lt "$auto_approach" ]
  '

	[ "$status" -eq 0 ]
}

@test "new review archives are registered without deleting plan handoff state" {
	run bash -c '
    set -e
    cd "'"$BATS_TEST_DIRNAME"'/.."
    registry="skills/kramme:workflow-artifacts:cleanup/references/disposable-artifacts.yaml"

    grep -qF "\"path\": \".context/siw-issue-to-pr/reviews/REVIEW_OVERVIEW.md\"" "$registry"
    grep -qF "\"path\": \".context/siw-issue-to-pr/reviews/CONVENTION_REVIEW_OVERVIEW.md\"" "$registry"
    grep -qF "\"path\": \".context/siw-issue-to-pr/reviews/REFACTOR_OPPORTUNITIES_OVERVIEW.md\"" "$registry"
    grep -qF "\"path\": \".context/code-plan-to-pr/reviews/REVIEW_OVERVIEW.md\"" "$registry"
    grep -qF "\"path\": \".context/code-plan-to-pr/reviews/CONVENTION_REVIEW_OVERVIEW.md\"" "$registry"
    grep -qF "\"path\": \".context/code-plan-to-pr/reviews/REFACTOR_OPPORTUNITIES_OVERVIEW.md\"" "$registry"
    ! grep -qF "\"path\": \".context/code-plan-to-pr/\"" "$registry"
    ! grep -qF "\"path\": \".context/siw-issue-to-pr/\"" "$registry"
  '

	[ "$status" -eq 0 ]
}
