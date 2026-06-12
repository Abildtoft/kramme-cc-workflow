#!/usr/bin/env bats

@test "workflow cleanup includes generated review and planning artifacts" {
	cd "$BATS_TEST_DIRNAME/.."

	grep -qF ".context/github-review-replies/" "skills/kramme:workflow-artifacts:cleanup/SKILL.md"
	grep -qF "DEPRECATION_PLAN.md" "skills/kramme:workflow-artifacts:cleanup/SKILL.md"
	grep -qF "DEPRECATION_PLAN_*.md" "skills/kramme:workflow-artifacts:cleanup/SKILL.md"
}
