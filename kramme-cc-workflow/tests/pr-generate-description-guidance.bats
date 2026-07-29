#!/usr/bin/env bats

assert_required_contracts_registered() {
	cd "$BATS_TEST_DIRNAME/.."
	python3 - "$@" <<'PY'
import json
import pathlib
import sys

registry = json.loads(pathlib.Path("scripts/synced-contracts.yaml").read_text())
registered = {contract["name"] for contract in registry.get("required_file_contracts", [])}
missing = sorted(set(sys.argv[1:]) - registered)
if missing:
    raise SystemExit(f"missing required_file_contracts: {', '.join(missing)}")
PY
}

@test "generate-description prose guidance is covered by contracts" {
	run bash -c '
    set -e
    cd "'"$BATS_TEST_DIRNAME"'/.."
    skill="skills/kramme:pr:generate-description"

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
		pr-generate-description-direct-update-safety

	[ "$status" -eq 0 ]
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
