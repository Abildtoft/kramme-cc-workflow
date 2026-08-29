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

	    grep -qF "Local SIW work must be transferred to Linear before using this skill." "$skill/SKILL.md"
	    grep -qF "run \`kramme:siw:transfer-to-linear\` first" "$skill/SKILL.md"
	    ! grep -qF "kramme:siw:issue-implement" "$skill/SKILL.md"
	    grep -qF "Reject direct, incomplete, mismatched, or duplicate use" "$skill/SKILL.md"
	    grep -qF "Require current \`HEAD\`, committed paths, and dirty paths to equal the captured entry handoff" "$skill/references/branch-setup.md"

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
