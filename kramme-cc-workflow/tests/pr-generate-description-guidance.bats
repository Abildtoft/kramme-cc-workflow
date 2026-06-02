#!/usr/bin/env bats

@test "generate-description distinguishes manual test plans from automated verification" {
	run bash -c '
    set -e
    cd "'"$BATS_TEST_DIRNAME"'/.."
    skill="skills/kramme:pr:generate-description"

    grep -qF "The Test Plan is for future reviewer or QA execution. It is not a transcript" "$skill/assets/section-templates.md"
    grep -qF "NEVER** substitute commands you ran" "$skill/SKILL.md"
    grep -qF "OMIT** \`### Automated verification\` when it would only repeat routine checks already covered by CI" "$skill/SKILL.md"
    grep -qF "NEVER** list missing command targets under \`### Automated verification\`" "$skill/SKILL.md"
    grep -qF "placeholder when capture failed or direct-update mode only has local files" "$skill/SKILL.md"
    grep -qF "blocking for direct update" "$skill/SKILL.md"
    grep -qF "set \`DIRECT_UPDATE=false\` even when \`--auto\` found an existing PR" "$skill/SKILL.md"
    grep -qF "local exclude file" "$skill/SKILL.md"
    grep -qF "do not mutate tracked files" "$skill/SKILL.md"
    grep -qF "Final conciseness pass" "$skill/SKILL.md"
    grep -qF "Removed repeated phrasing or duplicated facts" "$skill/SKILL.md"
    grep -qF "### Automated verification" "$skill/assets/section-templates.md"
    grep -qF "add PR-specific signal beyond CI" "$skill/assets/section-templates.md"
    grep -qF "This only proves what the agent already ran" "$skill/references/anti-patterns.md"
    grep -qF "NEVER** skip Linear issue lookup if the branch name contains an issue ID and a Linear integration is available" "$skill/references/best-practices.md"
    grep -qF "run a final conciseness pass" "$skill/references/best-practices.md"
    grep -qF "I ran format and lint locally, so I should include them" "$skill/references/red-flags.md"
    grep -qF "A longer description is safer" "$skill/references/red-flags.md"
    grep -qF "Never print full env-file contents or any non-port variables" "$skill/references/visual-capture.md"
  '

	[ "$status" -eq 0 ]
}
