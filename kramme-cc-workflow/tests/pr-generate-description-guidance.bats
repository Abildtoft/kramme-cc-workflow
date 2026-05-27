#!/usr/bin/env bats

@test "generate-description distinguishes manual test plans from automated verification" {
	run bash -c '
    set -e
    cd "'"$BATS_TEST_DIRNAME"'/.."
    skill="skills/kramme:pr:generate-description"

    grep -qF "The Test Plan is for future reviewer or QA execution. It is not a transcript" "$skill/assets/section-templates.md"
    grep -qF "NEVER** substitute commands you ran" "$skill/SKILL.md"
    grep -qF "### Automated verification" "$skill/assets/section-templates.md"
    grep -qF "This only proves what the agent already ran" "$skill/references/anti-patterns.md"
  '

	[ "$status" -eq 0 ]
}
