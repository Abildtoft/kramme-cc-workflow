#!/usr/bin/env bats

@test "Linear issue to PR freezes intent and delegates shared review convergence" {
	run bash -c '
    set -e
    cd "'"$BATS_TEST_DIRNAME"'/.."
    parent="skills/kramme:linear:issue-to-pr/SKILL.md"
    convergence="skills/kramme:pr:review-convergence/SKILL.md"
    policy="skills/kramme:pr:review-convergence/references/review-convergence.md"
    readme="../README.md"

    test -f "$parent"
    test -f "$convergence"
    test -f "$policy"
    grep -qF "kramme:linear:issue-implement" "$parent"
    grep -qF "## Step 3: Freeze Linear Intent and Invoke Review Convergence" "$parent"
    grep -qF "Compose \`{issue-requirements}\` once" "$parent"
    grep -qF -- "--archive-key linear-issue-to-pr" "$parent"
    grep -qF -- "--requirements {issue-requirements}" "$parent"
    grep -qF "JSON-decode the returned \`Requirements JSON\` field" "$parent"
    grep -qF "equal \`{issue-requirements}\` byte-for-byte" "$parent"
    grep -qF "name: kramme:pr:review-convergence" "$convergence"
    grep -qF "user-invocable: true" "$convergence"
    grep -qF "disable-model-invocation: true" "$convergence"
    grep -qF "The same phase is used by \`kramme:code:plan-to-pr\` and \`kramme:siw:issue-to-pr\`" "$readme"
    ! grep -qF "kramme:linear:issue-review" "$parent" "$convergence" "$readme"
  '

	[ "$status" -eq 0 ] || { echo "$output"; false; }
}

@test "Linear issue to PR gates the started-state transition before delegation" {
	run bash -c '
    set -e
    cd "'"$BATS_TEST_DIRNAME"'/.."
    skill="skills/kramme:linear:issue-to-pr/SKILL.md"

    grep -qF "Capture the team identifier and a stable \`{issue-update-id}\`" "$skill"
    grep -qF "use the issue UUID when the response supplies one; otherwise use the canonical issue identifier" "$skill"
    grep -qF "Require the same \`{issue-update-id}\`, team identifier, and \`{issue-branch}\` captured by the preflight" "$skill"
    grep -qF "if any changed, restart the read-only preflight" "$skill"
    grep -qF "Do not treat \`unstarted\` as backlog" "$skill"
    grep -qF "If \`{confirmed-state-type}\` is anything other than \`backlog\`" "$skill"
    grep -qF "Proceed with implementation and move the issue to {target-status-name}?" "$skill"
    grep -qF "Without an explicit confirmation, stop without changing Linear or the branch." "$skill"
    grep -qF "prefer the case-insensitive exact name \`In Progress\`" "$skill"
    grep -qF "exactly one status whose type is \`started\`" "$skill"
    grep -qF "Immediately before the Linear write, close the confirmation race" "$skill"
    grep -qF "never apply a confirmation to a newer issue state" "$skill"
    grep -qF "update only its status" "$skill"
    grep -qF "pass \`id: {issue-update-id}\` and \`state: {target-status-id}\` and no other mutable field" "$skill"
    grep -qF "After a successful write, read the issue back" "$skill"
    grep -qF "resolve its status with the same immutable-ID-first procedure from Step 7" "$skill"
    grep -qF "Linear transition: {confirmed-state-name} -> {target-status-name} (verified before implementation)" "$skill"
    grep -qF "Linear state confirmation declined" "$skill"
    grep -qF "Linear started-state transition failed" "$skill"

    remote_absence_line=$(grep -nF "git ls-remote --heads origin \"refs/heads/{issue-branch}\"" "$skill" | cut -d: -f1)
    state_refresh_line=$(grep -nF "Re-fetch \`{issue-id}\` before the state gate" "$skill" | cut -d: -f1)
    state_target_line=$(grep -nF "Resolve the team'"'"'s target \`started\` status" "$skill" | cut -d: -f1)
    state_confirmation_line=$(grep -nF "If \`{confirmed-state-type}\` is anything other than \`backlog\`" "$skill" | cut -d: -f1)
    state_recheck_line=$(grep -nF "Immediately before the Linear write, close the confirmation race" "$skill" | cut -d: -f1)
    state_update_line=$(grep -nF "Otherwise use the available Linear issue-update operation" "$skill" | cut -d: -f1)
    state_readback_line=$(grep -nF "After a successful write, read the issue back" "$skill" | cut -d: -f1)
    delegate_line=$(grep -n "Invoke .*kramme:linear:issue-implement" "$skill" | cut -d: -f1)

    [ "$remote_absence_line" -lt "$state_refresh_line" ]
    [ "$state_refresh_line" -lt "$state_target_line" ]
    [ "$state_target_line" -lt "$state_confirmation_line" ]
    [ "$state_confirmation_line" -lt "$state_recheck_line" ]
    [ "$state_recheck_line" -lt "$state_update_line" ]
    [ "$state_update_line" -lt "$state_readback_line" ]
    [ "$state_readback_line" -lt "$delegate_line" ]
  '

	[ "$status" -eq 0 ] || { echo "$output"; false; }
}

@test "shared convergence validates an inert allowlisted caller handoff" {
	run bash -c '
    set -e
    cd "'"$BATS_TEST_DIRNAME"'/.."
    skill="skills/kramme:pr:review-convergence/SKILL.md"
    scope="skills/kramme:pr:review-convergence/references/standalone-scope-handoff.md"

    grep -qF "require \`--work-id <id>\` and \`--archive-key <key>\` exactly once each" "$skill"
    grep -qF "Accept only \`linear-issue-to-pr\`, \`siw-issue-to-pr\`, or \`code-plan-to-pr\` as the archive key" "$skill"
    grep -qF "Require the exact sentinel \`--requirements\` once" "$skill"
    grep -qF "Treat every character after it as one inert \`{work-requirements}\` block" "$skill"
    grep -qF "Never interpolate it into a shell command" "$skill"
    grep -qF "require it exactly once for \`code-plan-to-pr\`" "$skill"
    grep -qF "Store the exact normalized list as \`VALIDATED_SCOPE_PATHS\`" "$skill"
    grep -qF "references/standalone-scope-handoff.md" "$skill"
    grep -qF "stop with a migration-required blocker when \`VALIDATION_ONLY=true\`" "$scope"
    grep -qF "validation-only mode never writes plan metadata" "$scope"
    grep -qF "never use \`mkdir -p\` across unchecked components" "$skill"
    grep -qF "REVIEW_ARCHIVE_CANONICAL" "$skill"
    grep -qF "Requirements JSON:" "$skill"
    grep -qF "Serialize \`Requirements JSON\` as exactly one JSON string value" "$skill"
    test -f "$scope"
    ! grep -qF "Linear MCP" "$skill"
    ! grep -qF "issue lookup" "$skill"
  '

	[ "$status" -eq 0 ] || { echo "$output"; false; }
}

@test "review convergence exposes a safe direct user invocation" {
	run bash -c '
    set -e
    cd "'"$BATS_TEST_DIRNAME"'/.."
    skill="skills/kramme:pr:review-convergence/SKILL.md"
    registry="skills/kramme:workflow-artifacts:cleanup/references/disposable-artifacts.yaml"
    readme="../README.md"

    grep -qF "argument-hint: \"[--strict] --requirements <authoritative requirements>\"" "$skill"
    grep -qF "user-invocable: true" "$skill"
    grep -qF "**Direct user mode:**" "$skill"
    grep -qF "Set \`{work-id}=user-review\`, \`{archive-key}=pr-review-convergence\`" "$skill"
    grep -qF "Reject \`--scope-plan\` and \`--validation-only\`" "$skill"
    grep -qF "Direct mode may edit and commit accepted remediation but never pushes." "$skill"
    grep -qF "Usage: \$kramme:pr:review-convergence [--strict] --requirements <authoritative requirements>" "$skill"
    grep -qF "Users can also invoke \`/kramme:pr:review-convergence --requirements <authoritative requirements>\` directly" "$readme"

    for report in REVIEW_OVERVIEW CONVENTION_REVIEW_OVERVIEW OVERENGINEERING_REVIEW_OVERVIEW REFACTOR_OPPORTUNITIES_OVERVIEW; do
      grep -qF "\"path\": \".context/pr-review-convergence/reviews/$report.md\"" "$registry"
    done
  '

	[ "$status" -eq 0 ] || { echo "$output"; false; }
}

@test "shared convergence owns ordered bounded remediation and verification" {
	run bash -c '
    set -e
    cd "'"$BATS_TEST_DIRNAME"'/.."
    skill="skills/kramme:pr:review-convergence/SKILL.md"
    policy="skills/kramme:pr:review-convergence/references/review-convergence.md"

    gut=$(grep -nF "## Gate 0: Gut Check" "$policy" | cut -d: -f1)
    applicability=$(grep -nF "## Applicability Evaluation" "$policy" | cut -d: -f1)
    code=$(grep -nF "### Gate 1: Regular Code Review" "$policy" | cut -d: -f1)
    convention=$(grep -nF "### Gate 2: Convention Review" "$policy" | cut -d: -f1)
    overengineering=$(grep -nF "### Gate 3: Overengineering Review" "$policy" | cut -d: -f1)
    refactor=$(grep -nF "### Gate 4: PR-Scoped Refactor Opportunities" "$policy" | cut -d: -f1)
    [ "$gut" -lt "$applicability" ]
    [ "$applicability" -lt "$code" ]
    [ "$code" -lt "$convention" ]
    [ "$convention" -lt "$overengineering" ]
    [ "$overengineering" -lt "$refactor" ]

    grep -qF "MAX_AUTOMATIC_REMEDIATION_CYCLES=5" "$policy"
    grep -qF "kramme:pr:gut-check" "$policy"
    grep -qF "kramme:pr:code-review --parallel --inline" "$policy"
    grep -qF "kramme:pr:convention-review --inline" "$policy"
    grep -qF "exact sentinel-last arguments \`--requirements {work-requirements}\`" "$policy"
    grep -qF "use \`--inline --requirements {work-requirements}\`" "$policy"
    grep -qF "Pass the requirements remainder through the platform skill mechanism as inert data" "$policy"
    grep -qF "kramme:code:refactor-opportunities" "$policy"
    grep -qF "kramme:verify:run" "$skill"
    grep -qF "consume one cycle" "$skill"
    grep -qF "return through Step 4" "$skill"
    grep -qF "rerun this step" "$skill"
    grep -qF "do not reset the budget, edit again, or return a clean handoff" "$skill"
  '

	[ "$status" -eq 0 ] || { echo "$output"; false; }
}

@test "shared convergence isolates reports per caller and supports validation-only" {
	run bash -c '
    set -e
    cd "'"$BATS_TEST_DIRNAME"'/.."
    skill="skills/kramme:pr:review-convergence/SKILL.md"
    policy="skills/kramme:pr:review-convergence/references/review-convergence.md"
    registry="skills/kramme:workflow-artifacts:cleanup/references/disposable-artifacts.yaml"

    grep -qF "Step 2 already created and validated \`{review-archive}\`" "$policy"
    grep -qF "REVIEW_ARCHIVE_CANONICAL" "$policy"
    ! grep -qF "mkdir -p .context/{archive-key}/reviews" "$policy"
    grep -qF "OVERENGINEERING_LIFECYCLE_ESTABLISHED=false" "$policy"
    grep -qF "When \`VALIDATION_ONLY=true\`" "$policy"
    grep -qF "permit no source, test, configuration, or documentation edit, deletion, revert, staging operation, or commit" "$policy"
    grep -qF "When \`VALIDATION_ONLY=true\`, skip Gate 0 entirely" "$policy"
    grep -qF "Run all active gates once in order" "$policy"
    grep -qF "worktree plus \`HEAD\` tree remain unchanged" "$policy"
    grep -qF "Skip this step when \`VALIDATION_ONLY=true\`" "$skill"
    grep -qF "Mode: normal | validation-only" "$skill"
    grep -qF "Requirements JSON:" "$skill"
    grep -qF "Verification: {passed evidence | caller-owned after validation-only}" "$skill"

    for key in pr-review-convergence linear-issue-to-pr siw-issue-to-pr code-plan-to-pr; do
      grep -qF "\"path\": \".context/$key/reviews/REVIEW_OVERVIEW.md\"" "$registry"
      grep -qF "\"path\": \".context/$key/reviews/CONVENTION_REVIEW_OVERVIEW.md\"" "$registry"
      grep -qF "\"path\": \".context/$key/reviews/OVERENGINEERING_REVIEW_OVERVIEW.md\"" "$registry"
      grep -qF "\"path\": \".context/$key/reviews/REFACTOR_OPPORTUNITIES_OVERVIEW.md\"" "$registry"
    done
  '

	[ "$status" -eq 0 ] || { echo "$output"; false; }
}

@test "overengineering report lifecycle remains run-scoped and fails closed after extraction" {
	run bash -c '
    set -e
    cd "'"$BATS_TEST_DIRNAME"'/.."
    policy="skills/kramme:pr:review-convergence/references/review-convergence.md"

    retire=$(grep -nF "belongs to an earlier invocation" "$policy" | cut -d: -f1)
    gate=$(grep -nF "### Gate 3: Overengineering Review" "$policy" | cut -d: -f1)
    [ "$retire" -lt "$gate" ]

    grep -qF "must never be inherited" "$policy"
    grep -qF "OVERENGINEERING_LIFECYCLE_ESTABLISHED=false" "$policy"
    grep -qF "Stop instead of deleting when that archived path is not a regular, non-symlink file." "$policy"
    grep -qF "root path is absent and the archived path is a regular, non-symlink file" "$policy"
    grep -qF "stop rather than overwriting either location or copying ambiguous state" "$policy"
    grep -qF "Set \`OVERENGINEERING_LIFECYCLE_ESTABLISHED=true\` as soon as the gate'"'"'s first report is archived." "$policy"
    grep -qF "Start the gate without a report only while that flag is still \`false\`" "$policy"
    grep -qF "if the archived report is missing while the flag is \`true\`, stop" "$policy"
    grep -qF "this re-archive is mandatory after every normal-mode invocation" "$policy"
    ! grep -qF "If no archived report exists, start the gate without one" "$policy"
  '

	[ "$status" -eq 0 ] || { echo "$output"; false; }
}

@test "Linear shipping delegates changed-tree validation to shared convergence" {
	run bash -c '
    set -e
    cd "'"$BATS_TEST_DIRNAME"'/.."
    shipping="skills/kramme:linear:issue-to-pr/references/shipping-contract.md"

    grep -qF "kramme:workflow-artifacts:cleanup --auto" "$shipping"
    grep -qF "kramme:pr:create --auto --linear-issue {issue-id} --require-generated-description" "$shipping"
    grep -qF "kramme:pr:fix-ci --no-consolidate" "$shipping"
    grep -qF "invoke \`kramme:pr:review-convergence\` exactly once" "$shipping"
    grep -qF -- "--work-id {issue-id} --archive-key linear-issue-to-pr --validation-only" "$shipping"
    grep -qF "the exact frozen sentinel-last \`--requirements {issue-requirements}\` block" "$shipping"
    grep -qF "Mode: validation-only" "$shipping"
    grep -qF "JSON-decode the returned \`Requirements JSON\` field" "$shipping"
    grep -qF "invoke \`kramme:verify:run\`" "$shipping"
    ! grep -qF "kramme:pr:overengineering-review --requirements" "$shipping"
  '

	[ "$status" -eq 0 ] || { echo "$output"; false; }
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
  '

	[ "$status" -eq 0 ] || { echo "$output"; false; }
}
