#!/usr/bin/env bats

setup() {
	cd "$BATS_TEST_DIRNAME/.."
}

SKILLS=(
	"skills/kramme:code:agent-readiness/SKILL.md"
	"skills/kramme:code:api-design/SKILL.md"
	"skills/kramme:docs:feature-spec/SKILL.md"
	"skills/kramme:linear:issue-implement/SKILL.md"
	"skills/kramme:pr:resolve-review/SKILL.md"
	"skills/kramme:skill:create/SKILL.md"
	"skills/kramme:skill:review/SKILL.md"
	"skills/kramme:verify:before-completion/SKILL.md"
)

assert_core_principle() {
	local file="$1"

	grep -qi "user experience" "$file"
	grep -qi "developer experience" "$file"
	grep -qi "agent experience" "$file"
	grep -qi "unchanged or inapplicable" "$file"
	grep -qi "outside the intended change" "$file"
	grep -qi "material tradeoffs" "$file"
	grep -qiE "verification|compatibility|regression" "$file"
}

@test "UX DX AX guidance preserves deliberate changes across affected skills" {
	for skill in "${SKILLS[@]}"; do
		assert_core_principle "$skill"
	done
}

@test "public and supporting guidance carries the same compatibility boundary" {
	assert_core_principle "../README.md"

	api_comparison="skills/kramme:code:api-design/references/design-it-twice.md"
	grep -qF "UX/DX/AX" "$api_comparison"
	grep -qi "outside the intended change" "$api_comparison"
	grep -qi "intentional contract change" "$api_comparison"
	grep -qi "compatibility or migration effects" "$api_comparison"
	grep -qi "material tradeoffs" "$api_comparison"

	plan="skills/kramme:linear:issue-implement/assets/technical-plan.md"
	grep -qF "UX/DX/AX" "$plan"
	grep -qi "unchanged or inapplicable" "$plan"
	grep -qi "outside the intended change" "$plan"
	grep -qi "intentional changes" "$plan"
	grep -qi "material tradeoffs" "$plan"
	grep -qi "regression checks" "$plan"
}

@test "shared guidance suite owns the newly covered skill contracts" {
	inventory="config/coverage-production-sources.json"
	registry="scripts/synced-contracts.yaml"
	suite="kramme-cc-workflow/tests/experience-quality-guidance.bats"

	for relative_skill in "${SKILLS[@]}"; do
		skill="kramme-cc-workflow/$relative_skill"
		jq -e --arg suite "$suite" --arg skill "$skill" '
			.skill_contracts[]
			| select(.suite == $suite)
			| .skills
			| index($skill) != null
		' "$inventory" >/dev/null
	done

	for skill in \
		"kramme-cc-workflow/skills/kramme:code:agent-readiness/SKILL.md" \
		"kramme-cc-workflow/skills/kramme:code:api-design/SKILL.md" \
		"kramme-cc-workflow/skills/kramme:verify:before-completion/SKILL.md"; do
		jq -e --arg skill "$skill" \
			'.skill_contract_coverage.mechanical_only | index($skill) == null' \
			"$registry" >/dev/null
	done
}
