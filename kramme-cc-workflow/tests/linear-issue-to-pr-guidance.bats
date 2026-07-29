#!/usr/bin/env bats

@test "linear issue to PR keeps the orchestration and shipping gates ordered" {
	run bash -c '
    set -e
    cd "'"$BATS_TEST_DIRNAME"'/.."
    skill="skills/kramme:linear:issue-to-pr/SKILL.md"
    review="skills/kramme:linear:issue-to-pr/references/review-convergence.md"
    shipping="skills/kramme:linear:issue-to-pr/references/shipping-contract.md"
    readme="../README.md"

    test -f "$skill"
    test -f "$review"
    test -f "$shipping"

    grep -qF "argument-hint: \"<ISSUE-ID> [--strict] [--ship]\"" "$skill"
    grep -qF "disable-model-invocation: true" "$skill"
    grep -qF "kramme:linear:issue-implement" "$skill"
    grep -qF "kramme:code:refactor-opportunities" "$skill"
    grep -qF "kramme:pr:convention-review" "$skill"
    grep -qF "kramme:pr:code-review" "$skill"
    ! grep -qF "kramme:pr:autoreview" "$skill"
    grep -qF "kramme:verify:run" "$skill"
    grep -qF "kramme:workflow-artifacts:cleanup --auto" "$skill"
    grep -qF "kramme:pr:create --auto" "$skill"
    grep -qF "kramme:pr:fix-ci --no-consolidate" "$skill"
    grep -qF "SHIP_MODE=false" "$skill"
    grep -qF "If \`SHIP_MODE=false\`, stop without invoking artifact cleanup or \`kramme:pr:create\`." "$skill"
    grep -qF "\$kramme:pr:create --auto --linear-issue {issue-id}" "$skill"
    grep -qF "Before interpolating \`{issue-branch}\` into any shell command" "$skill"
    grep -qF "Require the whole string to match \`[A-Za-z0-9][A-Za-z0-9._/-]*\`" "$skill"
    grep -qF "git check-ref-format --branch \"{issue-branch}\"" "$skill"
    grep -qF "gh pr list --head \"{issue-branch}\" --state all" "$skill"
    grep -qF "An authentication, network, repository, or API error is a blocker" "$skill"
    grep -qF "git ls-remote --heads origin \"refs/heads/{issue-branch}\"" "$skill"
    grep -qF "Continue only for the zero-line absent result." "$skill"
    grep -qF "stop before delegated branch setup" "$skill"
    grep -qF "Run \`git status --porcelain\` and continue only when it is empty" "$skill"
    grep -qF "an option this entry point never has" "$skill"
    grep -qF "Uncommitted changes at the Step 2 preflight" "$skill"
    grep -qF "Linear issue has no \`branchName\`" "$skill"
    grep -qF "Remote issue branch already exists without a Pull Request" "$skill"
    grep -qF "Invoke every delegated skill through the platform'\''s skill mechanism" "$skill"
    fallback_count=$(grep -cF "locate and read" "$skill")
    [ "$fallback_count" -eq 1 ]
    ! grep -qF "locate and read" "$shipping"
    ! grep -qF "locate and read" "$review"
    next_action_count=$(grep -cF "\$kramme:pr:create --auto --linear-issue {issue-id} --require-generated-description" "$skill")
    [ "$next_action_count" -eq 1 ]
    grep -qF "During normal remediation rounds it runs applicable gates in this order: \`/kramme:pr:code-review\`, \`/kramme:pr:convention-review\`, then \`/kramme:code:refactor-opportunities pr\`." "$readme"
    ! grep -qF "During normal remediation rounds it runs applicable gates in this order: \`/kramme:pr:autoreview\`" "$readme"
    grep -qF "Then: \$kramme:pr:fix-ci --no-consolidate" "$skill"

    preflight_line=$(grep -nF "Before allowing the implementation workflow to mutate a branch" "$skill" | cut -d: -f1)
    branch_validation_line=$(grep -nF "Before interpolating" "$skill" | cut -d: -f1)
    github_preflight_line=$(grep -nF "gh pr list --head \"{issue-branch}\" --state all" "$skill" | cut -d: -f1)
    remote_absence_line=$(grep -nF "git ls-remote --heads origin \"refs/heads/{issue-branch}\"" "$skill" | cut -d: -f1)
    worktree_preflight_line=$(grep -nF "Run \`git status --porcelain\` and continue only when it is empty" "$skill" | cut -d: -f1)
    implement_line=$(grep -nF "## Step 2: Invoke Linear Implementation" "$skill" | cut -d: -f1)
    delegate_line=$(grep -n "Invoke .*kramme:linear:issue-implement" "$skill" | cut -d: -f1)
    implementation_boundary_line=$(grep -nF "### Implementation Commit Boundary" "$skill" | cut -d: -f1)
    review_line=$(grep -nF "## Step 3: Run the Quality Loop" "$skill" | cut -d: -f1)
    verify_line=$(grep -nF "## Step 4: Run Final Verification" "$skill" | cut -d: -f1)
    ship_line=$(grep -nF "## Step 5: Stop or Ship" "$skill" | cut -d: -f1)
    [ "$implement_line" -lt "$preflight_line" ]
    [ "$preflight_line" -lt "$worktree_preflight_line" ]
    [ "$worktree_preflight_line" -lt "$branch_validation_line" ]
    [ "$preflight_line" -lt "$branch_validation_line" ]
    [ "$branch_validation_line" -lt "$github_preflight_line" ]
    [ "$github_preflight_line" -lt "$remote_absence_line" ]
    [ "$remote_absence_line" -lt "$delegate_line" ]
    [ "$preflight_line" -lt "$delegate_line" ]
    [ "$delegate_line" -lt "$implementation_boundary_line" ]
    [ "$implementation_boundary_line" -lt "$review_line" ]
    [ "$review_line" -lt "$verify_line" ]
    [ "$verify_line" -lt "$ship_line" ]
    ! grep -qF "{implementation-boundary}" "$skill"
  '

	[ "$status" -eq 0 ]
}

@test "quality rounds evaluate applicability then run broad, convention, and refactor review in order" {
	run bash -c '
    set -e
    cd "'"$BATS_TEST_DIRNAME"'/.."
    review="skills/kramme:linear:issue-to-pr/references/review-convergence.md"

    applicability_line=$(grep -nF "## Applicability Evaluation" "$review" | cut -d: -f1)
    broad_line=$(grep -nF "### Gate 1: Regular Code Review" "$review" | cut -d: -f1)
    convention_line=$(grep -nF "### Gate 2: Convention Review" "$review" | cut -d: -f1)
    refactor_line=$(grep -nF "### Gate 3: PR-Scoped Refactor Opportunities" "$review" | cut -d: -f1)

    [ "$applicability_line" -lt "$broad_line" ]
    [ "$broad_line" -lt "$convention_line" ]
    [ "$convention_line" -lt "$refactor_line" ]
    grep -qF "ACTIVE_QUALITY_GATES" "$review"
    grep -qF "Regular code review: run|skip" "$review"
    grep -qF "Convention review: run|skip" "$review"
    grep -qF "PR-scoped refactor discovery: run|skip" "$review"
    grep -qF "changes finding disposition, not gate applicability" "$review"
    grep -qF "Require its PR relevance gate" "$review"
    grep -qF "refactor-pass" "$review"
    grep -qF "kramme:pr:convention-review --inline" "$review"
    grep -qF "kramme:pr:code-review --parallel --inline" "$review"
    grep -qF "The parent owns all finding triage" "skills/kramme:linear:issue-to-pr/SKILL.md"
    grep -qF "consume exactly one parent cycle" "$review"
    ! grep -qF "delegated autoreview" "$review"
    grep -qF "### Quality-Loop Artifact Isolation" "$review"
    grep -qF ".context/linear-issue-to-pr/" "$review"
    grep -qF "git check-ignore -q -- .context/linear-issue-to-pr/" "$review"
    grep -qF "MISSING REQUIREMENT: unable to create .context/linear-issue-to-pr/" "$review"
    grep -qF "MISSING REQUIREMENT: .context/linear-issue-to-pr/ is not gitignored" "$review"
    grep -qF "Error: git check-ignore failed while validating .context/linear-issue-to-pr/" "$review"
    grep -qF "Treat any other status as a fatal Git error" "$review"
    grep -qF "### Remediation Commit Boundary" "$review"
    grep -qF "git add -- <path>..." "$review"
    grep -qF "The parent owns this transition" "$review"
    grep -qF "During normal remediation rounds" "skills/kramme:linear:issue-to-pr/SKILL.md"
    grep -qF "restart the next round at applicability evaluation followed by Gate 1" "$review"
    grep -qF "standard mode has no accepted unresolved Critical or Important finding" "$review"
    grep -qF "strict mode has a disposition for every emitted finding" "$review"
    ! grep -qF "If the gate changes no code and every emitted finding has a disposition" "$review"
  '

	[ "$status" -eq 0 ]
}

@test "strict mode converges by disposition without guessing through manual blockers" {
	run bash -c '
    set -e
    cd "'"$BATS_TEST_DIRNAME"'/.."
    review="skills/kramme:linear:issue-to-pr/references/review-convergence.md"

    grep -qF "Zero active findings" "$review"
    grep -qF "Strict mode requires a disposition, not blind compliance." "$review"
    grep -qF "permission to guess through a genuine manual blocker" "$review"
    grep -qF "MAX_AUTOMATIC_REMEDIATION_CYCLES=3" "$review"
    grep -qF "a multi-slice Gate 3 refactor pass is one cycle, not one per slice" "$review"
    grep -qF "Every slice accepted in this gate pass belongs to the same remediation cycle." "$review"
    grep -qF "review-debt score" "$review"
    grep -qF "Two consecutive remediation cycles make no material progress." "$review"
    grep -qF "run exactly one validation-only round" "$review"
    grep -qF "same read-only \`kramme:pr:code-review --parallel --inline\` regular gate" "$review"
    grep -qF "Do not run a second validation-only round." "$review"
    grep -qF "Do not run final verification, rewrite history, push, or create the Pull Request." "$review"
    grep -qF "A repeated rejected finding never keeps the loop open." "$review"
    grep -qF "Do not reset the budget, edit again, or ship" "skills/kramme:linear:issue-to-pr/SKILL.md"
  '

	[ "$status" -eq 0 ]
}

@test "ship mode preserves the verified tree then stabilizes CI and review feedback" {
	run bash -c '
    set -e
    cd "'"$BATS_TEST_DIRNAME"'/.."
    shipping="skills/kramme:linear:issue-to-pr/references/shipping-contract.md"

    existing_pr_line=$(grep -nF "## Step 1: Detect an Existing Pull Request" "$shipping" | cut -d: -f1)
    cleanup_line=$(grep -nF "## Step 2: Retire Workflow Artifacts" "$shipping" | cut -d: -f1)
    tree_line=$(grep -nF "## Step 4: Record the Verified Tree" "$shipping" | cut -d: -f1)
    create_line=$(grep -nF "## Step 5: Create the Pull Request" "$shipping" | cut -d: -f1)
    initial_prove_line=$(grep -nF "## Step 6: Prove the Initial Shipped Result" "$shipping" | cut -d: -f1)
    fix_ci_line=$(grep -nF "## Step 7: Stabilize CI and Review Feedback" "$shipping" | cut -d: -f1)
    final_prove_line=$(grep -nF "## Step 8: Prove the Final Pull Request State" "$shipping" | cut -d: -f1)

    [ "$existing_pr_line" -lt "$cleanup_line" ]
    [ "$cleanup_line" -lt "$tree_line" ]
    [ "$tree_line" -lt "$create_line" ]
    [ "$create_line" -lt "$initial_prove_line" ]
    [ "$initial_prove_line" -lt "$fix_ci_line" ]
    [ "$fix_ci_line" -lt "$final_prove_line" ]
    grep -qF "REFACTOR_OPPORTUNITIES_OVERVIEW.md" "$shipping"
    grep -qF "kramme:workflow-artifacts:cleanup --auto" "$shipping"
    grep -qF "git rev-parse '\''HEAD^{tree}'\''" "$shipping"
    grep -qF "headRefOid" "$shipping"
    grep -qF "remote head equals local" "$shipping"
    grep -qF "Standard mode permits reported advisory" "$shipping"
    grep -qF "Authentication, network, repository, rate-limit, and API errors are blockers" "$shipping"
    grep -qF "kramme:pr:create --auto --linear-issue {issue-id} --require-generated-description" "$shipping"
    grep -qF "\`--ship\` authorizes these actions for the current Linear issue branch only" "$shipping"
    grep -qF "\`--auto\` carries the invocation through the backup-protected local reset without prompting" "$shipping"
    grep -qF "recreate-commits delegate runs with \`--no-push\`" "$shipping"
    grep -qF "kramme:pr:fix-ci --no-consolidate" "$shipping"
    grep -qF "Do not combine it with \`--auto\`." "$shipping"
    grep -qF "gh pr checks --json name,state,bucket,link,workflow" "$shipping"
    grep -qF "Exit status is not a query result here" "$shipping"
    grep -qF "exits \`1\` when a check failed, \`8\` while checks are pending" "$shipping"
    grep -qF "no checks reported" "$shipping"
    grep -qF "Record \`Checks: none configured\` and continue" "$shipping"
    ! grep -qF "Require this command to succeed before evaluating its output." "$shipping"
    base_field_count=$(grep -cF "gh pr view --json number,url,state,baseRefName,headRefName,headRefOid" "$shipping")
    [ "$base_field_count" -eq 3 ]
    grep -qF "Capture its validated \`{base-branch}\` as \`{expected-base-branch}\`" "$shipping"
    grep -qF "baseRefName\` to equal \`{expected-base-branch}" "$shipping"
    grep -qF "gh pr view --json reviewDecision" "$shipping"
    grep -qF "gh api --paginate \"repos/{owner}/{repo}/pulls/{pr-number}/reviews\"" "$shipping"
    grep -qF "gh api --paginate \"repos/{owner}/{repo}/pulls/{pr-number}/comments\"" "$shipping"
    grep -qF "gh api --paginate \"repos/{owner}/{repo}/issues/{pr-number}/comments\"" "$shipping"
    grep -qF "reviewThreads(first: 100, after: \$endCursor)" "$shipping"
    grep -qF "include each thread'\''s \`id\` and \`isResolved\`" "$shipping"
    grep -qF "pageInfo { hasNextPage endCursor }" "$shipping"
    grep -qF "For each collected thread, paginate its \`comments(first: 100, after: \$endCursor)\` connection" "$shipping"
    grep -qF "unavailable \`isResolved\`" "$shipping"
    grep -qF "no \`CHANGES_REQUESTED\`" "$shipping"
    grep -qF "After feedback collection, take the final publication snapshot" "$shipping"
    grep -qF "Require both GitHub queries to succeed, reading the check query under the exit-status rules in item 2" "$shipping"
    grep -qF "direct the next invocation to \`kramme:pr:fix-ci --no-consolidate\`" "$shipping"
    grep -qF "invoke \`kramme:verify:run\`" "$shipping"
    grep -qF "run exactly one validation-only final quality round before verification" "$shipping"
    grep -qF "kramme:pr:code-review --parallel --inline" "$shipping"
    grep -qF "kramme:pr:convention-review --inline" "$shipping"
    grep -qF "kramme:code:refactor-opportunities pr" "$shipping"
    grep -qF "Do not edit code, re-enter \`kramme:pr:fix-ci\`, or start another quality round" "$shipping"
    final_review_line=$(grep -nF "run exactly one validation-only final quality round before verification" "$shipping" | cut -d: -f1)
    final_verify_line=$(grep -nF "after the validation-only quality round passes, invoke \`kramme:verify:run\`" "$shipping" | cut -d: -f1)
    [ "$final_review_line" -lt "$final_verify_line" ]
    grep -qF "invoke \`kramme:pr:fix-ci --no-consolidate\` directly as the existing-PR workflow" "$shipping"
    grep -qF "do not rerun \`kramme:linear:issue-to-pr\` or claim a cross-session Step 7 resume" "$shipping"
    grep -qF "placeholder publication is forbidden" "skills/kramme:pr:create/SKILL.md"
    grep -qF "Never force-push under this skill." "$shipping"
    grep -qF "Pull Request already exists" "$shipping"
    grep -qF "has no invocation-owned creation provenance" "$shipping"
  '

	[ "$status" -eq 0 ]
}

@test "validated Linear issue IDs flow through PR creation without branch re-parsing" {
	run bash -c '
    set -e
    cd "'"$BATS_TEST_DIRNAME"'/.."
    parent="skills/kramme:linear:issue-to-pr/references/shipping-contract.md"
    create="skills/kramme:pr:create/SKILL.md"
    branch="skills/kramme:pr:create/references/branch-and-platform-handling.md"
    generate="skills/kramme:pr:generate-description/SKILL.md"
    context="skills/kramme:pr:generate-description/references/context-gathering.md"
    registry="skills/kramme:workflow-artifacts:cleanup/references/disposable-artifacts.yaml"

    grep -qF -- "--linear-issue {issue-id}" "$parent"
    grep -qF "[--linear-issue <ISSUE-ID>]" "$create"
    grep -qF "LINEAR_ISSUE_OVERRIDE" "$create"
    grep -qF "also pass \`--linear-issue {linear-issue-id}\`" "$create"
    grep -qF "never replace it through branch-name extraction" "$branch"
    grep -qF "enter the Linear flow below without prompting" "$branch"
    grep -qF "If \`LINEAR_ISSUE_OVERRIDE\` was supplied" "$branch"
    grep -qF "[--linear-issue <ISSUE-ID>]" "$generate"
    grep -qF "LINEAR_ISSUE_OVERRIDE" "$generate"
    grep -qF "skip branch-name extraction" "$context"
    grep -qF "never replace or truncate" "$context"
    grep -qF "\"path\": \".context/linear-issue-to-pr/REVIEW_OVERVIEW.md\"" "$registry"
    grep -qF "\"path\": \".context/linear-issue-to-pr/CONVENTION_REVIEW_OVERVIEW.md\"" "$registry"
    grep -qF "\"path\": \".context/linear-issue-to-pr/REFACTOR_OPPORTUNITIES_OVERVIEW.md\"" "$registry"
    ! grep -qF "\"path\": \".context/linear-issue-to-pr/\"" "$registry"
  '

	[ "$status" -eq 0 ]
}
