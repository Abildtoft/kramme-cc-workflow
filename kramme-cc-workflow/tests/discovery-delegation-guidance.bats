#!/usr/bin/env bats

@test "SIW discovery delegates through the shared interview contract without losing caller behavior" {
	run bash -c '
    set -e
    cd "'"$BATS_TEST_DIRNAME"'/.."

    siw_skill="skills/kramme:siw:discovery/SKILL.md"
    interview_dir="skills/kramme:discovery:interview"
    interview_skill="$interview_dir/SKILL.md"
    decision_tree="$interview_dir/references/decision-tree-mode.md"

    test -f "$siw_skill"
    test -f "$interview_skill"
    test -f "$interview_dir/references/confidence-framework.md"
    test -f "$interview_dir/references/probing-techniques.md"
    test ! -e "skills/kramme:siw:discovery/references/confidence-framework.md"
    test ! -e "skills/kramme:siw:discovery/references/probing-techniques.md"

    grep -qF "INTERVIEW DELEGATION" "$siw_skill"
    grep -qF "\`confidence_target\`: 90% with the resolved Work Context profile" "$siw_skill"
    grep -qF "\`interview_mode\`: decision-tree when requested, otherwise coverage" "$siw_skill"
    grep -qF "\`decision_tree_context\`:" "$siw_skill"
    grep -qF "without the \`INTERVIEW RESULT:\` marker or its required fields" "$siw_skill"
    grep -qF "stop without writing an SIW artifact or emitting \`PLAN:\`" "$siw_skill"
    grep -qF "EnterPlanMode" "$siw_skill"

    grep -qF "Accept an \`INTERVIEW DELEGATION\` brief" "$interview_skill"
    grep -qF "Return \`INTERVIEW RESULT:\`" "$interview_skill"
    grep -qF "Do not ask for a plan path or write a standalone template" "$interview_skill"
    grep -qF "references/confidence-framework.md" "$interview_skill"
    grep -qF "references/probing-techniques.md" "$interview_skill"

    result_line=$(grep -nF "Return \`INTERVIEW RESULT:\`" "$interview_skill" | cut -d: -f1)
    standalone_line=$(grep -nF "## Step 5: Output Plan Document" "$interview_skill" | cut -d: -f1)
    [ "$result_line" -lt "$standalone_line" ]

    ! grep -qF "## In SIW Discovery" "$decision_tree"
    grep -qF "high-stakes architecture, data-model shape, refactor sequencing, and migration approach" "$siw_skill"
  '

	[ "$status" -eq 0 ]
}
