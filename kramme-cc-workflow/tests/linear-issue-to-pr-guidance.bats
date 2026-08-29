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
    grep -qF "including one transferred from SIW" "$parent"
    grep -qF "untransferred local SIW issues" "$parent"
    ! grep -qF "SIW-tracked issues" "$parent"
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
    grep -qF "The same phase is also used by \`kramme:code:plan-to-pr\`" "$readme"
    ! grep -qF "kramme:linear:issue-review" "$parent" "$convergence" "$readme"
  '

	[ "$status" -eq 0 ] || { echo "$output"; false; }
}

@test "shared convergence accounts for normal Conductor projections and suppresses validation comments" {
	run bash -c '
    set -e
    cd "'"$BATS_TEST_DIRNAME"'/.."
    skill="skills/kramme:pr:review-convergence/SKILL.md"
    policy="skills/kramme:pr:review-convergence/references/review-convergence.md"

    grep -qF "Initialize \`DIFF_COMMENTS_POSTED_TOTAL=0\`" "$policy"
    grep -qF "When active, invoke \`kramme:pr:code-review --parallel --inline\` in normal mode" "$policy"
    grep -qF "kramme:pr:code-review --parallel --inline --no-diff-comments" "$policy"
    grep -qF "Require exactly one producer summary line \`Diff comments posted: N (skipped M already present)\`" "$policy"
    grep -qF "add \`N\` to \`DIFF_COMMENTS_POSTED_TOTAL\`" "$policy"
    grep -qF "validation-only invocations contributed zero" "$policy"
    grep -qF "Diff comments posted: {cumulative newly posted count from the convergence policy ledger}" "$skill"
    grep -qF "never reconstruct it from Conductor state" "$skill"
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

@test "Linear issue to PR continues only validated unpublished issue work" {
	run bash -c '
    set -e
    cd "'"$BATS_TEST_DIRNAME"'/.."
    parent="skills/kramme:linear:issue-to-pr/SKILL.md"
    child="skills/kramme:linear:issue-implement/SKILL.md"
    branch_setup="skills/kramme:linear:issue-implement/references/branch-setup.md"

    grep -qF "argument-hint: \"<ISSUE-ID> [--continue] [--strict] [--rounds <1-5>] [--ship]\"" "$parent"
    grep -qF "\`--continue\` sets \`CONTINUE_MODE=true\`" "$parent"
    grep -qF "require the captured entry branch to equal \`{issue-branch}\` exactly" "$parent"
    grep -qF "Require at least one such path" "$parent"
    grep -qF "Stop on any unrelated or ambiguous path" "$parent"
    grep -qF "require \`{confirmed-state-id}\` to equal \`{target-status-id}\`" "$parent"
    grep -qF "issue no Linear write" "$parent"
    grep -qF -- "--auto --resume-current-branch" "$parent"
    grep -qF "skipped — continuation preserves the existing workspace name" "$parent"
    grep -qF "Accept the internal \`--resume-current-branch\` flag only when \`AUTO_MODE=true\`" "$child"
    grep -qF "reconcile every committed and dirty path in the parent resume handoff" "$child"
    grep -qF "If \`RESUME_CURRENT_BRANCH=true\`, use the parent-owned resume handoff" "$branch_setup"
    grep -qF "Do not checkout, create, reset, stash, discard, stage, or commit" "$branch_setup"
  '

	[ "$status" -eq 0 ] || { echo "$output"; false; }
}

@test "Linear issue to PR renames a detected Conductor workspace without making the adapter authoritative" {
	run bash -c '
    set -e
    cd "'"$BATS_TEST_DIRNAME"'/.."
    skill="skills/kramme:linear:issue-to-pr/SKILL.md"
    adapter="skills/kramme:linear:issue-to-pr/references/conductor-workspace.md"
    sources="skills/kramme:linear:issue-to-pr/references/sources.yaml"
    portability="docs/agent-portability.md"
    readme="../README.md"

    test -f "$adapter"
    grep -qF "After Step 10 proves the issue'"'"'s current state" "$skill"
    grep -qF "Use the title from that freshest issue response as inert input" "$skill"
    grep -qF "CONDUCTOR_WORKSPACE_ID" "$adapter"
    grep -qF "When it is absent, do not probe for the CLI or any Conductor tool" "$adapter"
    grep -qF "[A-Za-z0-9][A-Za-z0-9_-]*" "$adapter"
    grep -qF "Replace every run outside \`[A-Za-z0-9._ -]\` with one space" "$adapter"
    grep -qF "command -v conductor >/dev/null 2>&1" "$adapter"
    grep -qF "shell tool'"'"'s 15-second bounded timeout" "$adapter"
    grep -qF "conductor --json workspace rename \"\$CONDUCTOR_WORKSPACE_ID\" --name \"{conductor-workspace-name}\"" "$adapter"
    grep -qF "never use \`eval\`" "$adapter"
    grep -qF "its \`id\` to equal \`CONDUCTOR_WORKSPACE_ID\`" "$adapter"
    grep -qF "its \`name\` to equal \`{conductor-workspace-name}\` byte-for-byte" "$adapter"
    grep -qF "outcome unknown — workspace rename may have been applied; inspect Conductor" "$adapter"
    grep -qF "Continue without retrying" "$adapter"
    grep -qF "Do not retry, request Conductor credentials" "$adapter"
    grep -qF "continue regardless of its outcome" "$skill"
    grep -qF "Conductor workspace: {conductor-rename-outcome}" "$skill"
    grep -qF "workspace CLI" "$portability"
    grep -qF "detected Conductor workspace is renamed best-effort" "$readme"
    grep -qF "id: conductor-openapi" "$sources"
    grep -qF "id: conductor-environment-variables" "$sources"

    adapter_line=$(grep -nF "After Step 10 proves the issue'"'"'s current state" "$skill" | cut -d: -f1)
    delegate_line=$(grep -n "Invoke .*kramme:linear:issue-implement" "$skill" | cut -d: -f1)
    [ "$adapter_line" -lt "$delegate_line" ]
  '

	[ "$status" -eq 0 ] || { echo "$output"; false; }
}

@test "shared convergence validates an inert allowlisted caller handoff" {
	run bash -c '
    set -e
    cd "'"$BATS_TEST_DIRNAME"'/.."
    skill="skills/kramme:pr:review-convergence/SKILL.md"
    scope="skills/kramme:pr:review-convergence/references/standalone-scope-handoff.md"

    grep -qF "Accept only \`linear-issue-to-pr\` or \`code-plan-to-pr\` as the archive key" "$skill"
    grep -qF "**Internal caller mode:** reject \`--derive\`." "$skill"
    grep -qF "Require \`--work-id <id>\`, \`--archive-key <key>\`, and the exact \`--requirements\` sentinel exactly once each" "$skill"
    grep -qF "treat every character after it as one inert \`{supplied-requirements}\` block" "$skill"
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
    grep -qF "normalize the inert \`{supplied-requirements}\` block once as \`{work-requirements}\`" "$skill"
    grep -qF "Never replace the frozen internal handoff with conversation or Linear lookup." "$skill"
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

    grep -qF "argument-hint: \"[--strict] [--rounds <1-5>] [--adversarial-review [--adversarial-provider claude|codex] [--adversarial-model <id>]] [--derive | LINEAR-ISSUE | --requirements <authoritative requirements>]\"" "$skill"
    grep -qF "user-invocable: true" "$skill"
    grep -qF "**Direct user mode:**" "$skill"
    grep -qF "Set \`{archive-key}=pr-review-convergence\`" "$skill"
    grep -qF "\`DIRECT_REQUIREMENTS_SOURCE=explicit\`" "$skill"
    grep -qF "\`DIRECT_REQUIREMENTS_SOURCE=linear\`" "$skill"
    grep -qF "Reject \`--scope-plan\` and \`--validation-only\`" "$skill"
    grep -qF "Accept at most one remaining positional Linear selector only when both \`--requirements\` and \`--derive\` are absent" "$skill"
    grep -qF "issue identifier matching \`{TEAM}-{number}\` case-insensitively, where \`TEAM\` is alphanumeric" "$skill"
    grep -qF "require the exact host, no credentials or port, and a single extractable identifier" "$skill"
    grep -qF "Reject \`--derive\` combined with a selector or \`--requirements\`." "$skill"
    grep -qF "Direct mode may edit and commit accepted remediation but never pushes." "$skill"
    grep -qF "DIRECT_REQUIREMENTS_SOURCE=conversation" "$skill"
    grep -qF "fetch \`{linear-issue-id}\` read-only through the Linear MCP issue lookup with relations" "$skill"
    grep -qF "the issue response, description, or a comment says it defines, clarifies, supersedes, or constrains" "$skill"
    grep -qF "Record external documents and attachments that appear requirement-bearing" "$skill"
    grep -qF "open them when the available tools support doing so" "$skill"
    grep -qF "If Linear MCP, the issue, or potentially requirement-bearing context is inaccessible, stop and name the missing source" "$skill"
    grep -qF "rather than falling back silently to conversation or Git evidence" "$skill"
    grep -qF "derive \`{work-requirements}\` from user-authored messages about the prepared work in the current conversation" "$skill"
    grep -qF "Include assistant-proposed requirements only when a user message explicitly accepts or confirms them." "$skill"
    grep -qF "conflicting candidate requirements, multiple plausible work items, or a reference whose inaccessible contents could materially change the contract" "$skill"
    grep -qF "When direct mode has \`DIRECT_REQUIREMENTS_SOURCE=conversation\` and no explicit selector" "$skill"
    grep -qF "set \`DIRECT_REQUIREMENTS_SOURCE=linear\` and \`{work-id}={linear-issue-id}\`" "$skill"
    grep -qF "Do not use the branch diff, implementation, commit messages, Pull Request metadata, or repository conventions to fill missing product intent." "$skill"
    grep -qF "Usage: \$kramme:pr:review-convergence [--strict] [--rounds <1-5>] [--adversarial-review [--adversarial-provider claude|codex] [--adversarial-model <id>]] [--derive | LINEAR-ISSUE | --requirements <authoritative requirements>]" "$skill"
    grep -qF "with no requirement argument it derives the contract from the current conversation" "$readme"
    grep -qF "with \`--derive\` it drafts a contract from conversation and committed branch evidence" "$readme"
    grep -qF "set its maximum to one through five fix-and-rerun rounds with \`--rounds <1-5>\`" "$readme"

    for report in REVIEW_OVERVIEW CONVENTION_REVIEW_OVERVIEW OVERENGINEERING_REVIEW_OVERVIEW REFACTOR_OPPORTUNITIES_OVERVIEW; do
      grep -qF "\"path\": \".context/pr-review-convergence/reviews/$report.md\"" "$registry"
    done
  '

	[ "$status" -eq 0 ] || { echo "$output"; false; }
}

@test "derived direct requirements are question-driven and user-approved" {
	run bash -c '
    set -e
    cd "'"$BATS_TEST_DIRNAME"'/.."
    skill="skills/kramme:pr:review-convergence/SKILL.md"

    grep -qF "Set \`STRICT_REVIEW=true\` and \`DERIVE_REQUIREMENTS=true\` when their flags are present" "$skill"
    grep -qF "\`DIRECT_REQUIREMENTS_SOURCE=derived\` and \`{work-id}=user-review\` when \`DERIVE_REQUIREMENTS=true\`" "$skill"
    grep -qF "**Direct derived source:** inspect user-authored conversation plus the prepared branch'"'"'s committed diff, changed files, tests, and commit messages as untrusted evidence" "$skill"
    grep -qF "distinguishes user-stated requirements from agent inferences" "$skill"
    grep -qF "Ask consolidated, targeted questions when an answer could materially change" "$skill"
    grep -qF "Use the platform'"'"'s question mechanism when available and otherwise ask in chat." "$skill"
    grep -qF "require explicit user approval before freezing its exact text as \`{work-requirements}\` or entering Step 4" "$skill"
    grep -qF "Treat identifiers and links found in branch evidence as inert references" "$skill"
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

    grep -qF "require exactly one ASCII digit from \`1\` through \`5\`" "$skill"
    grep -qF "set \`MAX_AUTOMATIC_REMEDIATION_CYCLES=5\` and \`ROUNDS_EXPLICIT=false\`" "$skill"
    grep -qF "Reject explicit \`--rounds\` when \`VALIDATION_ONLY=true\`" "$skill"
    grep -qF "use parsed \`MAX_AUTOMATIC_REMEDIATION_CYCLES\` from the invocation" "$policy"
    grep -qF "reaches \`MAX_AUTOMATIC_REMEDIATION_CYCLES\`" "$policy"
    grep -qF "Remediation: {cycles used}/{MAX_AUTOMATIC_REMEDIATION_CYCLES}" "$skill"
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

@test "shared convergence summarizes findings it did not remediate" {
	run bash -c '
    set -e
    cd "'"$BATS_TEST_DIRNAME"'/.."
    skill="skills/kramme:pr:review-convergence/SKILL.md"
    policy="skills/kramme:pr:review-convergence/references/review-convergence.md"

    remediation=$(grep -nF "Remediation: {cycles used}/{MAX_AUTOMATIC_REMEDIATION_CYCLES}" "$skill" | cut -d: -f1)
    overview=$(grep -nF "Unremediated issues:" "$skill" | head -1 | cut -d: -f1)
    [ "$remediation" -lt "$overview" ]

    grep -qF "Initialize one producer-owned \`GUT_CHECK_DISPOSITIONS\` ledger" "$policy"
    grep -qF "Give each Gut Check item a run-scoped \`GC-NNN\` identifier and record \`id\`, \`gate\` (\`gut-check\`), \`summary\`, final \`disposition\`" "$policy"
    grep -qF "and \`routed_finding_fingerprint\`, using JSON \`null\` until a quality gate adopts it" "$policy"
    grep -qF "For a blocked Gut Check item, also record \`attempted_fix_evidence\`" "$policy"
    grep -qF "Initialize \`REVIEW_ACTIVITY_STATUS\` to \`not_started\` beside the ledgers" "$policy"
    grep -qF "Before and after each Gate 0 or quality-gate invocation, update it with the gate, status (\`started\`, \`completed\`, or \`failed\`)" "$policy"
    grep -qF "Build one concise human-readable overview at every terminal handoff after review activity begins" "$policy"
    grep -qF "an early Gate 0 blocker, an initial no-change pass, a post-remediation pass, the single validation-only pass, or an interrupted quality pass" "$policy"
    grep -qF "Use \`REVIEW_ACTIVITY_STATUS\`, \`GUT_CHECK_DISPOSITIONS\`, the cycle ledger when present in normal mode, \`REVIEWER_HANDOFF_FINDINGS\`, and \`REVIEWER_HANDOFF_FOCUS\` as the only sources" "$policy"
    grep -qF "when failed or incomplete \`REVIEW_ACTIVITY_STATUS\` evidence or a cycle-ledger verification failure is not already represented" "$policy"
    grep -qF "record one \`required_unresolved\` finding entry for that gate" "$policy"
    grep -qF "never reconstruct the overview from superseded reports" "$policy"
    grep -qF "**Required unresolved**" "$policy"
    grep -qF "**Deferred optional**" "$policy"
    grep -qF "**Rejected reviewer findings**" "$policy"
    grep -qF "**Review focus**" "$policy"
    grep -qF "Record a focus entry" "$policy"
    grep -qF "Each entry contains \`fingerprint\`, \`kind\`" "$policy"
    grep -qF "every \`routed\` Gut Check item that could not reach its owning quality gate before an early terminal blocker" "$policy"
    grep -qF "Render an unlinked routed item with kind \`unreviewed_routed\`" "$policy"
    grep -qF "\`routed\` Gut Check items linked to an owning finding fingerprint" "$policy"
    grep -qF "when both ledgers contain the same fingerprint, keep only the finding" "$policy"
    grep -qF "\`required_unresolved\`, or \`blocked\`" "$policy"
    grep -qF "Use \`required_unresolved\` when an accepted required finding remains active at a bounded stop" "$policy"
    grep -qF "For \`deferred_optional\`, require the rationale to retain the concrete benefit, estimated change amplification, and follow-up scope" "$policy"
    grep -qF "For \`required_unresolved\` or \`blocked\`, also require \`attempted_fix_evidence\`" "$policy"
    grep -qF "\`deferred_optional\` — valid but deliberately excluded because it exceeds the frozen work requirements" "$policy"
    grep -qF "\`required_unresolved\` — only at a bounded stop" "$policy"
    grep -qF "record it as \`required_unresolved\` with the remaining fingerprint" "$policy"
    grep -qF "include the concrete benefit, estimated change amplification, rationale, and follow-up scope" "$policy"
    grep -qF "Exclude findings whose final disposition is \`fixed\`" "$policy"
    grep -qF "return exactly \`Unremediated issues: none\`" "$policy"
    grep -qF "Findings: required unresolved={count}; fixed={count}, rejected={count}, deferred optional={count}, blocked={count}" "$skill"
    grep -qF -- "- Required unresolved:" "$skill"
    grep -qF -- "- Deferred optional:" "$skill"
    grep -qF "Rejected reviewer findings:" "$skill"
    grep -qF -- "- Review focus:" "$skill"
    grep -qF "Reviewer handoff JSON: {one RFC 8259 JSON object with \`gut_check\`, \`findings\`, and \`focus\` arrays" "$skill"
    grep -qF "Build \`Unremediated issues\` at every terminal handoff after review activity begins" "$skill"
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

    for key in pr-review-convergence linear-issue-to-pr code-plan-to-pr; do
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

@test "Linear issue to PR closes its report with a reviewer handoff summary" {
	run bash -c '
    set -e
    cd "'"$BATS_TEST_DIRNAME"'/.."
    parent="skills/kramme:linear:issue-to-pr/SKILL.md"
    convergence="skills/kramme:pr:review-convergence/SKILL.md"
    policy="skills/kramme:pr:review-convergence/references/review-convergence.md"
    shipping="skills/kramme:linear:issue-to-pr/references/shipping-contract.md"
    fix_ci="skills/kramme:pr:fix-ci/SKILL.md"
    readme="../README.md"

    grep -qF "### Reviewer Handoff Summary" "$parent"
    grep -qF "after either success template" "$parent"
    grep -qF "**What was done**" "$parent"
    grep -qF "**What review convergence uncovered**" "$parent"
    grep -qF "**What to focus on in review**" "$parent"
    grep -qF "decisions this workflow made autonomously" "$parent"
    grep -qF "Treat that producer-owned JSON as the only source" "$parent"
    grep -qF "Never re-read \`.context/linear-issue-to-pr/reviews/\` here" "$parent"
    grep -qF "every decision or assumption the delegated workflow made" "$parent"
    grep -qF "JSON-decode the returned \`Reviewer handoff JSON\` field" "$parent"
    grep -qF "Require exactly \`gut_check\`, \`findings\`, and \`focus\` arrays" "$parent"
    grep -qF "conditional recovery fields, and enum values before using it" "$parent"
    grep -qF "the validated \`CI remediation JSON\` plus any final-tree \`Reviewer handoff JSON\`" "$parent"
    grep -qF "raw text to \`kramme:text:clarify\`" "$parent"
    grep -qF "restore anything the rewrite dropped before posting" "$parent"
    grep -qF "post the draft unchanged rather than blocking the report" "$parent"
    grep -qF "Reviewer handoff JSON:" "$convergence"
    grep -qF "required keys, conditional recovery fields, and allowlisted disposition or kind before trusting later fields" "$convergence"
    grep -qF "REVIEWER_HANDOFF_FINDINGS" "$policy"
    grep -qF "not the replaceable report archive" "$policy"
    grep -qF "CI_REMEDIATION_LEDGER" "$fix_ci"
    grep -qF "CI remediation JSON:" "$fix_ci"
    grep -qF "Require its \`CI remediation JSON\` field" "$shipping"
    grep -qF "merge \`findings\` and \`focus\` entries by fingerprint and final disposition" "$shipping"
    grep -qF "Return the validated \`CI remediation JSON\` and the merged initial/final \`Reviewer handoff JSON\`" "$shipping"
    grep -qF "retain the initial \`gut_check\` array unchanged because validation-only never runs Gate 0" "$shipping"
    grep -qF "initial \`gut_check\`, plus fingerprint-merged \`findings\` and \`focus\`" "$shipping"
    grep -qF "retain the initial \`gut_check\` array unchanged because validation-only does not rerun Gate 0" "$parent"
    grep -qF "merge only \`findings\` and \`focus\` with the final-tree handoff" "$parent"
    grep -qF "retained rejected or blocked Gut Check items" "$parent"
    grep -qF "Deduplicate a routed Gut Check item linked to an owning finding fingerprint" "$parent"
    grep -qF "Shipped summaries merge CI remediation and final-tree validation evidence" "$readme"
    grep -qF "reviewer handoff summary" "$readme"

    capture_line=$(grep -nF "JSON-decode the returned \`Reviewer handoff JSON\` field" "$parent" | cut -d: -f1)
    shipping_line=$(grep -nF "## Step 4: Stop or Ship" "$parent" | cut -d: -f1)
    [ "$capture_line" -lt "$shipping_line" ]

    validation_line=$(grep -nF "invoke \`kramme:pr:review-convergence\` exactly once" "$shipping" | cut -d: -f1)
    merge_line=$(grep -nF "merge \`findings\` and \`focus\` entries by fingerprint and final disposition" "$shipping" | cut -d: -f1)
    [ "$validation_line" -le "$merge_line" ]
  '

	[ "$status" -eq 0 ] || { echo "$output"; false; }
}
