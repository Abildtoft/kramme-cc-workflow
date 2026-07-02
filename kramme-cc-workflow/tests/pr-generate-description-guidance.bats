#!/usr/bin/env bats

@test "generate-description keeps PR test plans manual-only" {
	run bash -c '
    set -e
    cd "'"$BATS_TEST_DIRNAME"'/.."
    skill="skills/kramme:pr:generate-description"

    grep -qF "When drafting the Test Plan, apply the Test Plan section in \`assets/section-templates.md\` and the Test Plans rules in \`references/best-practices.md\`." "$skill/SKILL.md"
    grep -qF "Read \`references/direct-update.md\` and follow it." "$skill/SKILL.md"
    grep -qF "Run the consolidated checklist in \`references/verification-checklist.md\`." "$skill/SKILL.md"
    grep -qF "GitHub PR Template Analysis" "$skill/SKILL.md"
    grep -qF "Repository PR Template Contract" "$skill/SKILL.md"
    grep -qF "One or more selectable GitHub PR templates are present, no default template is selected" "$skill/SKILL.md"
    grep -qF "ALWAYS** check whether the repository has a GitHub pull request template before drafting" "$skill/references/context-gathering.md"
    grep -qF "GitHub applies PR templates from the repository default branch" "$skill/references/context-gathering.md"
    grep -qF "DEFAULT_TEMPLATE_REF=\"origin/\$DEFAULT_BRANCH\"" "$skill/references/context-gathering.md"
    grep -qF "git cat-file -e \"\$DEFAULT_TEMPLATE_REF:\$path\"" "$skill/references/context-gathering.md"
    grep -qF "git ls-tree -r --name-only \"\$DEFAULT_TEMPLATE_REF\" \"\$dir\"" "$skill/references/context-gathering.md"
    grep -qF "**Default templates**" "$skill/references/context-gathering.md"
    grep -qF "**Selectable templates**" "$skill/references/context-gathering.md"
    ! grep -qF "find . .github docs -maxdepth 2" "$skill/references/context-gathering.md"
    grep -qF "Do not treat a single selectable template as selected merely because it is the only file in the directory" "$skill/references/context-gathering.md"
    grep -qF "MISSING REQUIREMENT: selectable GitHub PR template found but no template selection is available" "$skill/references/context-gathering.md"
    grep -qF "NEVER** skip GitHub PR template lookup" "$skill/references/best-practices.md"
    grep -qF "Repository PR Templates" "$skill/references/best-practices.md"
    grep -qF "PREFER** a single default \`pull_request_template.md\` or \`pull_request_template.txt\`" "$skill/references/best-practices.md"
    grep -qF "NEVER** treat a selectable \`PULL_REQUEST_TEMPLATE/\` file as automatically applied" "$skill/references/best-practices.md"
    grep -qF "map this block into the closest template prompts instead of duplicating headings" "$skill/assets/section-templates.md"
    grep -qF "GitHub PR template lookup completed against the repository default branch" "$skill/references/verification-checklist.md"
    grep -qF "github-pr-template-docs" "$skill/references/sources.yaml"
    grep -qF "The Test Plan is for future reviewer or QA execution. It is not a transcript" "$skill/assets/section-templates.md"
    grep -qF "NEVER** substitute the verification commands you ran" "$skill/references/best-practices.md"
    grep -qF "NEVER** include \`### Automated\`, \`### Automated verification\`, automated testing instructions, command checklists, or unit/lint/build targets in the PR body" "$skill/references/best-practices.md"
    grep -qF "ASSUME** CI reports automated test, lint, typecheck, build, and formatting status" "$skill/references/best-practices.md"
    grep -qF "NEVER** mention local setup or infrastructure failures" "$skill/references/best-practices.md"
    grep -qF "missing \`node_modules\`, missing package installs, unavailable Postgres, absent Docker services, or port conflicts" "$skill/references/best-practices.md"
    grep -qF "NEVER** list missing automated test targets" "$skill/references/best-practices.md"
    grep -qF "placeholder when capture failed or direct-update mode only has local files" "$skill/references/verification-checklist.md"
    grep -qF "Local setup or infrastructure failures such as missing \`node_modules\`, failed package installs, unavailable Postgres, absent Docker services, and port conflicts are omitted from the PR body" "$skill/references/verification-checklist.md"
    grep -qF "blocking for direct update" "$skill/SKILL.md"
    grep -qF "set \`DIRECT_UPDATE=false\` even when \`--auto\` found an existing PR" "$skill/SKILL.md"
    grep -qF "local exclude file" "$skill/SKILL.md"
    grep -qF "do not mutate tracked files" "$skill/references/direct-update.md"
    grep -qF "Final conciseness pass" "$skill/references/verification-checklist.md"
    grep -qF "Removed repeated phrasing or duplicated facts" "$skill/references/verification-checklist.md"
    grep -qF "Do not include automated testing instructions, command checklists, or an automated verification subsection" "$skill/assets/section-templates.md"
    grep -qF "Do not include local setup or infrastructure failure notes" "$skill/assets/section-templates.md"
    grep -qF "Local Environment Noise" "$skill/references/anti-patterns.md"
    grep -qF "CORRECT: Manual Scenarios Only" "$skill/references/anti-patterns.md"
    ! grep -qF "### Automated verification" "$skill/assets/section-templates.md"
    ! grep -qF "add PR-specific signal beyond CI" "$skill/assets/section-templates.md"
    grep -qF "This only proves what the agent already ran" "$skill/references/anti-patterns.md"
    grep -qF "NEVER** skip Linear issue lookup if the branch name contains an issue ID and a Linear integration is available" "$skill/references/best-practices.md"
    grep -qF "run a final conciseness pass" "$skill/references/best-practices.md"
    grep -qF "I ran format and lint locally, so I should include them" "$skill/references/red-flags.md"
    grep -qF "Local tests could not run because dependencies or services were missing" "$skill/references/red-flags.md"
    grep -qF "The body mentions local setup failures" "$skill/references/red-flags.md"
    grep -qF "Local environment failure notes such as missing \`node_modules\`, unavailable Postgres, missing services" "$skill/SKILL.md"
    grep -qF "A longer description is safer" "$skill/references/red-flags.md"
    grep -qF "Never print full env-file contents or any non-port variables" "$skill/references/visual-capture.md"
  '

	[ "$status" -eq 0 ]
}

@test "generate-description base guidance uses canonical resolver contract" {
	run bash -c '
    set -euo pipefail
    cd "'"$BATS_TEST_DIRNAME"'/.."
    base_ref="skills/kramme:pr:generate-description/references/base-branch-resolution.md"

    grep -qF "Synced base/diff scope contract" "$base_ref"
    grep -qF "scripts/resolve-base.sh" "$base_ref"
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
    [ -z "$(discover_templates main)" ]

    mkdir -p .github/PULL_REQUEST_TEMPLATE
    printf "Default\n" > .github/pull_request_template.md
    printf "Release\n" > .github/PULL_REQUEST_TEMPLATE/release.md
    git add .
    git commit -q -m templates
    git switch -q -c feature
    mkdir -p docs
    printf "Unmerged\n" > docs/pull_request_template.md
    output="$(discover_templates main)"
    printf "%s\n" "$output" | grep -qF ".github/pull_request_template.md"
    printf "%s\n" "$output" | grep -qF ".github/PULL_REQUEST_TEMPLATE/release.md"
    ! printf "%s\n" "$output" | grep -qF "docs/pull_request_template.md"
  '

	[ "$status" -eq 0 ]
}
