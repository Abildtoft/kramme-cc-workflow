#!/usr/bin/env bats

load 'test_helper/common'

@test "generate-description prose guidance is covered by contracts" {
	run bash -c '
	    set -e
    cd "'"$BATS_TEST_DIRNAME"'/.."
    skill="skills/kramme:pr:generate-description"
    direct="$skill/references/direct-update.md"
    checklist="$skill/references/verification-checklist.md"

    test -f "$skill/SKILL.md"
    test -f "$skill/references/context-gathering.md"
    test -f "$skill/references/best-practices.md"
    test -f "$skill/assets/section-templates.md"
    test -f "$skill/references/verification-checklist.md"
    test -f "$skill/references/anti-patterns.md"
    test -f "$skill/references/red-flags.md"
    test -f "$skill/references/direct-update.md"
    test -f "$skill/references/visual-capture.md"

    ! grep -qF "find . .github docs -maxdepth 2" "$skill/references/context-gathering.md"
    grep -qF "github-pr-template-docs" "$skill/references/sources.yaml"
    grep -qF "The \"no Linear ID\" condition is the only non-blocking \`MISSING REQUIREMENT:\` marker." "$skill/SKILL.md"
    grep -qF "Treat every other \`MISSING REQUIREMENT:\` marker" "$skill/SKILL.md"
    grep -qF "including future marker types not yet listed here" "$skill/SKILL.md"
    grep -qF "almost ELI10" "$skill/SKILL.md"
    grep -qF "intelligent ten-year-old who does not know the codebase" "$skill/assets/section-templates.md"
    grep -qF "env GH_PROMPT_DISABLED=1 gh repo view" "$skill/references/context-gathering.md"
    grep -qF "GIT_TERMINAL_PROMPT=0 GCM_INTERACTIVE=Never" "$skill/references/context-gathering.md"
    grep -qF "NONINTERACTIVE_GIT_SSH_COMMAND=\"\${GIT_SSH_COMMAND:-\${GIT_SSH:-ssh}} -oBatchMode=yes\"" "$skill/references/context-gathering.md"
    grep -qF "GIT_SSH_COMMAND=\"\$NONINTERACTIVE_GIT_SSH_COMMAND\"" "$skill/references/context-gathering.md"
    grep -qF "credential or timeout failures must return control without asking for terminal input" "$skill/references/context-gathering.md"
    grep -qF "[--base-commit <oid>]" "$skill/SKILL.md"
    grep -qF "BASE_COMMIT_OVERRIDE=<oid>" "$skill/SKILL.md"
    grep -qF -- "--base-commit \"\$BASE_COMMIT_OVERRIDE\"" "$skill/references/base-branch-resolution.md"
    ! grep -qF "DEFAULT_TEMPLATE_REF=\"\$BASE_REF\"" "$skill/references/context-gathering.md"
    ! grep -qF "### Automated verification" "$skill/assets/section-templates.md"
    ! grep -qF "add PR-specific signal beyond CI" "$skill/assets/section-templates.md"
    [ "$(grep -cF "\`references/red-flags.md\`" "$skill/SKILL.md")" -eq 1 ]
    grep -qF "Apply the \`Red Flags — STOP\` section from the already-loaded reference" "$skill/SKILL.md"
    ! grep -qF "use proper heading hierarchy" "$skill/SKILL.md"
    ! grep -qF "using tables for structured data" "$skill/SKILL.md"
    grep -qF "mktemp -d \"/tmp/kramme-pr-description.XXXXXX\"" "$direct"
    grep -qF "Capture the single printed line as agent-tracked `{update-dir}`" "$direct"
    grep -qF "UPDATE_DIR=\"{update-dir}\"" "$direct"
    grep -qF "gh pr view --json title,body > \"\$PR_BACKUP\"" "$direct"
    grep -qF "Generated PR payload files are missing or indirect" "$direct"
    grep -qF "mandatory title/body JSON backup" "$checklist"
    grep -qF "same shell invocation as validation and cleanup" "$checklist"
    grep -qF "self-contained local-exclude and symlink-rejection procedure" "$checklist"
    ! grep -qF "repo-root anchored backup, local git exclude update" "$checklist"
    grep -qF "SAVE_NAMESPACE=\"\$REPO_ROOT/.kramme-cc-workflow\"" "$skill/SKILL.md"
    grep -qF "Could not update Git'\''s local exclude file; the description was not saved." "$skill/SKILL.md"
    ! grep -qF "same idempotent check as step 1" "$skill/SKILL.md"
    ! grep -qF "\$REPO_ROOT/.kramme-cc-workflow/pr-description" "$direct"
  '

	assert_required_contracts_registered \
		pr-generate-description-main-guidance \
		pr-generate-description-template-discovery \
		pr-generate-description-template-and-test-plan-rules \
		pr-generate-description-section-template-rules \
		pr-generate-description-output-cleanliness \
		pr-generate-description-antipattern-examples \
		pr-generate-description-red-flag-examples \
		pr-generate-description-visual-capture-safety \
		pr-generate-description-direct-update-safety \
		pr-generate-description-save-and-checklist-contract \
		pr-generate-description-direct-update-checklist

	[ "$status" -eq 0 ] || { echo "$output"; false; }
}

@test "verify-description owns confirmed publication after output-only generation" {
	run bash -c '
	    set -euo pipefail
    cd "'"$BATS_TEST_DIRNAME"'/.."
    skill="skills/kramme:pr:verify-description/SKILL.md"
    update="skills/kramme:pr:verify-description/references/confirmed-update.md"

    test -f "$update"
    grep -qF "disable-model-invocation: true" "$skill"
    grep -qF "kramme:pr:generate-description --auto --no-update" "$skill"
    grep -qF "read \`references/confirmed-update.md\` and follow it" "$skill"
    grep -qF -- "--auto --no-update --base {base-branch} --base-commit {base-commit}" "$update"
    grep -qF "This skill owns the mutation; generation remains output-only." "$update"
    grep -qF "Do not omit \`--no-update\`" "$update"
    grep -qF "PR_SNAPSHOT=\$(env GH_PROMPT_DISABLED=1 gh pr view" "$skill"
    grep -qF "PR_MATCH_COUNT=\$(env GH_PROMPT_DISABLED=1 gh pr list" "$skill"
    grep -qF "if [ \"\$PR_MATCH_COUNT\" = 0 ]; then" "$skill"
    grep -qF "MISSING REQUIREMENT: no PR found for the current branch." "$skill"
    grep -qF "[[ ! \"\$CURRENT_BRANCH\" =~ ^[A-Za-z0-9][A-Za-z0-9._/-]*\$ ]]" "$skill"
    grep -qF "[[ ! \"\$BASE_REF\" =~ ^[A-Za-z0-9][A-Za-z0-9._/-]*\$ ]]" "$skill"
    grep -qF "Current branch is not safe for later shell substitution." "$skill"
    grep -qF "Resolved base ref is not safe for later shell substitution." "$skill"
    grep -qF "fix mode requires the generated base to match the Pull Request target" "$skill"
    grep -qF "Could not inspect a Pull Request for the current branch; preserve the gh diagnostic above." "$skill"
	    grep -qF "PR_SNAPSHOT_FINGERPRINT=" "$skill"
	    grep -qF "git hash-object --stdin" "$skill"
    grep -qF "WORKTREE_MANIFEST=\$(\"\${CLAUDE_PLUGIN_ROOT}/scripts/review-tree-fingerprint.sh\")" "$skill"
    grep -qF -- "--fix is unavailable for a <PR_STATE> Pull Request" "$skill"
    grep -qF "mktemp -d \"/tmp/kramme-pr-description.XXXXXX\"" "$update"
    grep -qF "Capture the single printed line as agent-tracked `{update-dir}`" "$update"
    grep -qF "UPDATE_DIR=\"{update-dir}\"" "$update"
    grep -qF "Could not back up and revalidate PR #\$PR_NUMBER; no update was made." "$update"
    grep -qF "LATEST_PR_SNAPSHOT_FINGERPRINT\" != \"\$PR_SNAPSHOT_FINGERPRINT" "$update"
    grep -qF "PR_STATE\" != \"OPEN" "$update"
    grep -qF "LATEST_HEAD\" != \"\$CURRENT_HEAD" "$update"
    grep -qF "LATEST_BASE_COMMIT\" != \"\$BASE_COMMIT" "$update"
    grep -qF "LATEST_WORKTREE_FINGERPRINT\" != \"\$WORKTREE_FINGERPRINT" "$update"
    grep -qF "Generated PR payload storage is missing or indirect" "$update"
    grep -qF "gh pr edit \"\$PR_NUMBER\"" "$update"
    grep -qF -- "--body-file \"\$PR_BODY_FILE\"" "$update"
    ! grep -qF "\$REPO_ROOT/.kramme-cc-workflow/pr-description" "$update"
    confirmation_line=$(grep -nF "Found <N> finding(s). Generate a replacement title and body" "$skill" | cut -d: -f1)
    no_pr_line=$(grep -nF "MISSING REQUIREMENT: no PR found for the current branch." "$skill" | head -1 | cut -d: -f1)
    generic_pr_failure_line=$(grep -nF "Could not inspect a Pull Request for the current branch" "$skill" | cut -d: -f1)
    base_match_line=$(grep -nF "fix mode requires the generated base to match the Pull Request target" "$skill" | cut -d: -f1)
    non_open_line=$(grep -nF -- "--fix is unavailable for a <PR_STATE> Pull Request" "$skill" | cut -d: -f1)
    delegation_line=$(grep -nF "read \`references/confirmed-update.md\` and follow it" "$skill" | cut -d: -f1)
    storage_line=$(grep -nF "UPDATE_DIR=\$(mktemp -d" "$update" | cut -d: -f1)
    backup_line=$(grep -nF "if ! env GH_PROMPT_DISABLED=1 gh pr view" "$update" | cut -d: -f1)
    snapshot_line=$(grep -nF "LATEST_PR_SNAPSHOT_FINGERPRINT\" != \"\$PR_SNAPSHOT_FINGERPRINT" "$update" | cut -d: -f1)
    payload_line=$(grep -nF "Generated PR payload storage is missing or indirect" "$update" | cut -d: -f1)
    cleanup_line=$(grep -nF "trap cleanup_pr_payload EXIT" "$update" | cut -d: -f1)
    edit_line=$(grep -nF "gh pr edit \"\$PR_NUMBER\"" "$update" | cut -d: -f1)
    [ "$non_open_line" -lt "$confirmation_line" ]
    [ "$base_match_line" -lt "$confirmation_line" ]
    [ "$no_pr_line" -lt "$generic_pr_failure_line" ]
    [ "$confirmation_line" -lt "$delegation_line" ]
    [ "$storage_line" -lt "$payload_line" ]
    [ "$payload_line" -lt "$cleanup_line" ]
    [ "$cleanup_line" -lt "$backup_line" ]
    [ "$payload_line" -lt "$backup_line" ]
    [ "$backup_line" -lt "$snapshot_line" ]
    [ "$snapshot_line" -lt "$edit_line" ]
    ! grep -qF "it will detect the existing PR and update it directly" "$skill"
  '

	assert_required_contracts_registered \
		pr-verify-description-confirmed-update \
		pr-verify-description-snapshot-baseline

	[ "$status" -eq 0 ] || { echo "$output"; false; }
}

@test "generate-description base guidance uses canonical resolver contract" {
	run bash -c '
    set -euo pipefail
    cd "'"$BATS_TEST_DIRNAME"'/.."
    base_ref="skills/kramme:pr:generate-description/references/base-branch-resolution.md"

    grep -qF "Synced base/diff scope contract" "$base_ref"
    grep -qF "shared resolve-base.sh script" "$base_ref"
    grep -qF "BASE_REF" "$base_ref"
    grep -qF "BASE_BRANCH" "$base_ref"
    grep -qF "MERGE_BASE" "$base_ref"
    ! grep -qF "git symbolic-ref refs/remotes/origin/HEAD" "$base_ref"
    ! grep -qF "gh pr view --json baseRefName" "$base_ref"
  '

	[ "$status" -eq 0 ]
}

@test "generate-description PR template discovery reads default branch tree" {
	run bash -c '
    set -euo pipefail
    discover_templates() {
      DEFAULT_TEMPLATE_REF="$1"
      {
        for path in pull_request_template.md pull_request_template.txt .github/pull_request_template.md .github/pull_request_template.txt docs/pull_request_template.md docs/pull_request_template.txt; do
          git cat-file -e "$DEFAULT_TEMPLATE_REF:$path" 2> /dev/null && printf "%s\n" "$path"
        done
        for dir in PULL_REQUEST_TEMPLATE .github/PULL_REQUEST_TEMPLATE docs/PULL_REQUEST_TEMPLATE; do
          git ls-tree -r --name-only "$DEFAULT_TEMPLATE_REF" "$dir" 2> /dev/null |
            awk -v dir="$dir/" '"'"'index($0, dir) == 1 { name = substr($0, length(dir) + 1); if (name !~ /\// && tolower(name) ~ /\.(md|txt)$/) print $0 }'"'"'
        done
      } | sort -u
    }

    tmp=$(mktemp -d)
    trap "rm -rf \"$tmp\"" EXIT
    cd "$tmp"
    git init -q -b main
    git config user.email test@example.com
    git config user.name Test
    git commit --allow-empty -q -m init
    git branch release
    [ -z "$(discover_templates main)" ]

    mkdir -p .github/PULL_REQUEST_TEMPLATE
    printf "Default\n" > .github/pull_request_template.md
    printf "Release\n" > .github/PULL_REQUEST_TEMPLATE/release.md
    git add .
    git commit -q -m templates
    git switch -q -c feature
    mkdir -p docs
    printf "Unmerged\n" > docs/pull_request_template.md
    pinned_base="$(git rev-parse release)"
    [ "$pinned_base" != "$(git rev-parse main)" ]
    [ -z "$(discover_templates "$pinned_base")" ]
    output="$(discover_templates main)"
    printf "%s\n" "$output" | grep -qF ".github/pull_request_template.md"
    printf "%s\n" "$output" | grep -qF ".github/PULL_REQUEST_TEMPLATE/release.md"
    ! printf "%s\n" "$output" | grep -qF "docs/pull_request_template.md"
  '

	[ "$status" -eq 0 ]
}
