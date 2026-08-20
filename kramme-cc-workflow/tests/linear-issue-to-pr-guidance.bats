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
    grep -qF "kramme:pr:overengineering-review" "$skill"
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
    grep -qF "During normal remediation rounds it runs applicable gates in this order: \`/kramme:pr:code-review\`, \`/kramme:pr:convention-review\`, \`/kramme:pr:overengineering-review\`, then \`/kramme:code:refactor-opportunities pr\`." "$readme"
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

@test "quality rounds evaluate applicability then run broad, convention, overengineering, and refactor review in order" {
	run bash -c '
    set -e
    cd "'"$BATS_TEST_DIRNAME"'/.."
    review="skills/kramme:linear:issue-to-pr/references/review-convergence.md"

    applicability_line=$(grep -nF "## Applicability Evaluation" "$review" | cut -d: -f1)
    broad_line=$(grep -nF "### Gate 1: Regular Code Review" "$review" | cut -d: -f1)
    convention_line=$(grep -nF "### Gate 2: Convention Review" "$review" | cut -d: -f1)
    overengineering_line=$(grep -nF "### Gate 3: Overengineering Review" "$review" | cut -d: -f1)
    refactor_line=$(grep -nF "### Gate 4: PR-Scoped Refactor Opportunities" "$review" | cut -d: -f1)

    [ "$applicability_line" -lt "$broad_line" ]
    [ "$broad_line" -lt "$convention_line" ]
    [ "$convention_line" -lt "$overengineering_line" ]
    [ "$overengineering_line" -lt "$refactor_line" ]
    grep -qF "ACTIVE_QUALITY_GATES" "$review"
    grep -qF "Regular code review: run|skip" "$review"
    grep -qF "Convention review: run|skip" "$review"
    grep -qF "Overengineering review: run|skip" "$review"
    grep -qF "PR-scoped refactor discovery: run|skip" "$review"
    grep -qF "changes finding disposition, not gate applicability" "$review"
    grep -qF "Require its PR relevance gate" "$review"
    grep -qF "refactor-pass" "$review"
    grep -qF "kramme:pr:convention-review --inline" "$review"
    grep -qF "kramme:pr:code-review --parallel --inline" "$review"
    grep -qF "kramme:pr:overengineering-review --requirements \"{issue-requirements}\"" "$review"
    grep -qF "OVERENGINEERING_REVIEW_OVERVIEW.md" "$review"
    grep -qF "restore the archived \`OVERENGINEERING_REVIEW_OVERVIEW.md\`" "$review"
    grep -qF "Do not pass \`--inline\` during normal rounds" "$review"
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
    grep -qF "standard mode has no accepted unresolved Critical, Important, or \`OVERDONE\` finding" "$review"
    grep -qF "strict mode has a disposition for every emitted finding" "$review"
    ! grep -qF "If the gate changes no code and every emitted finding has a disposition" "$review"
  '

	[ "$status" -eq 0 ]
}

@test "overengineering report lifecycle is run-scoped and fails closed on ambiguous or missing state" {
	run bash -c '
    set -e
    cd "'"$BATS_TEST_DIRNAME"'/.."
    review="skills/kramme:linear:issue-to-pr/references/review-convergence.md"
    skill="skills/kramme:linear:issue-to-pr/SKILL.md"

    isolation_line=$(grep -nF "### Quality-Loop Artifact Isolation" "$review" | cut -d: -f1)
    retire_line=$(grep -nF "Delete it now, before the first quality round" "$review" | cut -d: -f1)
    gate_line=$(grep -nF "### Gate 3: Overengineering Review" "$review" | cut -d: -f1)
    [ "$isolation_line" -lt "$retire_line" ]
    [ "$retire_line" -lt "$gate_line" ]

    grep -qF "belongs to an earlier invocation" "$review"
    grep -qF "must never be inherited here" "$review"
    grep -qF "OVERENGINEERING_LIFECYCLE_ESTABLISHED=false" "$review"
    grep -qF "Stop instead of deleting when that archived path is not a regular, non-symlink file." "$review"

    grep -qF "Continue only when the root path is absent and the archived path is a regular, non-symlink file" "$review"
    grep -qF "stop rather than overwriting either location or copying ambiguous state" "$review"
    grep -qF "The delegated gate independently enforces that the restored root report is untracked and safe to read." "$review"

    grep -qF "Set \`OVERENGINEERING_LIFECYCLE_ESTABLISHED=true\` as soon as the gate'"'"'s first report is archived." "$review"
    grep -qF "Start the gate without a report only while that flag is still \`false\`" "$review"
    grep -qF "if the archived report is missing while the flag is \`true\`, stop" "$review"
    grep -qF "this re-archive is mandatory after every invocation, including one that emits no finding, changes no code, or stops on a blocker" "$review"

    ! grep -qF "If no archived report exists, start the gate without one" "$review"

    grep -qF "retire any archived report left by an earlier invocation before the first round" "$skill"
    grep -qF "a later missing archive is a blocker rather than a fresh start" "$skill"
  '

	[ "$status" -eq 0 ]
}

@test "overengineering review receives the issue complete bounded requirement set" {
	run bash -c '
    set -e
    cd "'"$BATS_TEST_DIRNAME"'/.."
    review="skills/kramme:linear:issue-to-pr/references/review-convergence.md"
    shipping="skills/kramme:linear:issue-to-pr/references/shipping-contract.md"
    skill="skills/kramme:linear:issue-to-pr/SKILL.md"

    grep -qF "Build \`{issue-requirements}\` once, before the first overengineering invocation" "$review"
    grep -qF "pass that same text to every later invocation in this run" "$review"
    grep -qF "never reads the Linear issue itself" "$review"
    grep -qF "returns as a false \`OVERDONE\`" "$review"
    grep -qF "every acceptance criterion, checklist item, and explicit success condition;" "$review"
    grep -qF "every stated constraint the implementation must satisfy" "$review"
    grep -qF "every stated non-goal or explicit out-of-scope boundary." "$review"
    grep -qF "Keep it bounded" "$review"
    grep -qF "record that absence explicitly rather than omitting the section" "$review"

    grep -qF "complete \`{issue-requirements}\` set as \`--requirements\`" "$skill"
    grep -qF "reusing the same complete requirement set the quality loop built" "$shipping"
    ! grep -qF "{one-line statement of the behavior the Linear issue requests}" "$shipping"
  '

	[ "$status" -eq 0 ]
}

@test "gut check runs once before the rotating gates and stays outside the cycle ledger" {
	run bash -c '
    set -e
    cd "'"$BATS_TEST_DIRNAME"'/.."
    skill="skills/kramme:linear:issue-to-pr/SKILL.md"
    review="skills/kramme:linear:issue-to-pr/references/review-convergence.md"

    grep -qF "kramme:pr:gut-check" "$skill"
    grep -qF "Gut check: {count} items" "$skill"
    grep -qF "Gut check finds work outside the Linear issue" "$skill"

    isolation_line=$(grep -nF "### Quality-Loop Artifact Isolation" "$review" | cut -d: -f1)
    gut_check_line=$(grep -nF "## Gate 0: Gut Check" "$review" | cut -d: -f1)
    applicability_line=$(grep -nF "## Applicability Evaluation" "$review" | cut -d: -f1)
    broad_line=$(grep -nF "### Gate 1: Regular Code Review" "$review" | cut -d: -f1)
    [ "$isolation_line" -lt "$gut_check_line" ]
    [ "$gut_check_line" -lt "$applicability_line" ]
    [ "$applicability_line" -lt "$broad_line" ]

    grep -qF "Run this gate exactly once per workflow" "$review"
    grep -qF "never rerun it in a later remediation round or in the bounded stop" "$review"
    grep -qF "Do not rerun Gate 0 here" "$review"
    grep -qF -- "--intent \"{issue-title}" "$review"
    grep -qF "Do not pass \`--base\`" "$review"
    grep -qF "\`removed\` — the item is residue rather than design" "$review"
    grep -qF "\`routed\` — the item is a regular-review, convention, overengineering, or refactor concern" "$review"
    grep -qF "\`rejected\` — the surrounding code, the repository" "$review"
    grep -qF "\`blocked\` — the item shows the branch doing work the Linear issue did not ask for" "$review"
    grep -qF "the parent dispositions it directly as \`rejected\` with that evidence" "$review"
    grep -qF "A \`removed\` batch does not consume a remediation cycle" "$review"
    grep -qF "ledger step: record the removal commit in run state, not in the cycle ledger" "$review"
    grep -qF "Allow at most one such batch" "$review"
    grep -qF "a gut-check item alone never keeps the standard-mode completion rule open" "$review"
    grep -qF "Gut-check items carry no severity and score nothing" "$review"
    grep -qF "Gate 0 is not evaluated here." "$review"
    grep -qF "never appears in the per-round report below" "$review"
    grep -qF "Gate 0 ran exactly once, before the first applicability evaluation" "$review"
    grep -qF "recorded as \`removed\`, \`routed\`, \`rejected\`, or \`blocked\`" "$review"

    gut_check_report_count=$(grep -cF "Gut check: {count} items" "$skill")
    [ "$gut_check_report_count" -eq 2 ]

    if grep -qF "Gut check: run|skip" "$review"; then echo "Gate 0 leaked into the per-round gate report" >&2; exit 1; fi
    if grep -qF "GUT_CHECK_OVERVIEW.md" "$review"; then echo "Gate 0 gained a report file" >&2; exit 1; fi
    if grep -qF "gut-check --inline" "$review"; then echo "Gate 0 gained an unsupported --inline flag" >&2; exit 1; fi
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
    grep -qF "MAX_AUTOMATIC_REMEDIATION_CYCLES=5" "$review"
    grep -qF "a multi-slice Gate 4 refactor pass is one cycle, not one per slice" "$review"
    grep -qF "Every slice accepted in this gate pass belongs to the same remediation cycle." "$review"
    grep -qF "review-debt score" "$review"
    grep -qF "Two consecutive remediation cycles make no material progress." "$review"
    grep -qF "The shared remediation counter reaches five" "$review"
    grep -qF "run exactly one validation-only round" "$review"
    grep -qF "same read-only \`kramme:pr:code-review --parallel --inline\` regular gate" "$review"
    grep -qF "Do not run a second validation-only round." "$review"
    grep -qF "Do not run final verification, rewrite history, push, or create the Pull Request." "$review"
    grep -qF "A repeated rejected finding never keeps the loop open." "$review"
    grep -qF "starts a new five-cycle budget" "$review"
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
    grep -qF "Standard mode permits reported Judgment Call, advisory, and refactor observations" "$shipping"
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
    grep -qF "kramme:pr:overengineering-review --requirements \"{issue-requirements}\" --inline" "$shipping"
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
    grep -qF "\"path\": \".context/linear-issue-to-pr/OVERENGINEERING_REVIEW_OVERVIEW.md\"" "$registry"
    grep -qF "\"path\": \".context/linear-issue-to-pr/REFACTOR_OPPORTUNITIES_OVERVIEW.md\"" "$registry"
    ! grep -qF "\"path\": \".context/linear-issue-to-pr/\"" "$registry"
  '

	[ "$status" -eq 0 ]
}
