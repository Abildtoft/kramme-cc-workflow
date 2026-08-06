#!/usr/bin/env bats

load 'test_helper/common'

@test "linear issue implement maps referenced Linear context into research and plan" {
	run bash -c '
    set -e
    cd "'"$BATS_TEST_DIRNAME"'/.."
    skill="skills/kramme:linear:issue-implement"

    test -f "$skill/SKILL.md"
    test -f "$skill/references/display-templates.md"
    test -f "$skill/assets/technical-plan.md"

    branch_line=$(grep -nF "[Branch Setup] -> IMMEDIATELY create/switch to Linear'\''s branchName" "$skill/SKILL.md" | head -n1 | cut -d: -f1)
    reference_line=$(grep -nF "[Reference Mapping] -> Fetch linked Linear issues/docs and record inaccessible assets" "$skill/SKILL.md" | head -n1 | cut -d: -f1)
    [ "$branch_line" -lt "$reference_line" ]
  '

	assert_required_contracts_registered \
		linear-issue-implement-reference-mapping \
		linear-issue-implement-display-template \
		linear-issue-implement-plan-template \
		linear-issue-implement-readme-note

	[ "$status" -eq 0 ]
}
