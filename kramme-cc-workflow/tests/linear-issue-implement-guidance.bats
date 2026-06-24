#!/usr/bin/env bats

@test "linear issue implement maps referenced Linear context into research and plan" {
	run bash -c '
    set -e
    cd "'"$BATS_TEST_DIRNAME"'/.."
    skill="skills/kramme:linear:issue-implement"

    grep -qF "[Reference Mapping] -> Fetch linked Linear issues/docs and record inaccessible assets" "$skill/SKILL.md"
    branch_line=$(grep -nF "[Branch Setup] -> IMMEDIATELY create/switch to Linear'\''s branchName" "$skill/SKILL.md" | head -n1 | cut -d: -f1)
    reference_line=$(grep -nF "[Reference Mapping] -> Fetch linked Linear issues/docs and record inaccessible assets" "$skill/SKILL.md" | head -n1 | cut -d: -f1)
    [ "$branch_line" -lt "$reference_line" ]
    grep -qF "includeRelations: true" "$skill/SKILL.md"
    grep -qF "### 3.2 Map Referenced Linear Context" "$skill/SKILL.md"
    grep -qF "Build a \`REFERENCE_MAP\` from the issue response, issue description, and comments before planning" "$skill/SKILL.md"
    grep -qF "Do not silently ignore inaccessible referenced context" "$skill/SKILL.md"
    grep -qF "Referenced Context:" "$skill/SKILL.md"
    grep -qF "Treat inaccessible referenced documents/assets as explicit research gaps" "$skill/SKILL.md"
    grep -qF "Referenced documents or assets that could not be accessed and might change implementation" "$skill/SKILL.md"

    grep -qF "Referenced Linear Context Used:" "$skill/references/display-templates.md"
    grep -qF "Inaccessible Referenced Context:" "$skill/references/display-templates.md"
    grep -qF "## Referenced Linear Context" "$skill/assets/technical-plan.md"
    grep -qF "Fetches issue details plus referenced Linear issues/documents when accessible, reports inaccessible referenced assets" ../README.md
  '

	[ "$status" -eq 0 ]
}
