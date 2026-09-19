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

	    grep -qF "Local SIW work must be transferred to Linear first." "$skill/SKILL.md"
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

@test "linear issue implement transitions Linear only under --set-in-progress" {
	run bash -c '
    set -e
    cd "'"$BATS_TEST_DIRNAME"'/.."
    skill="skills/kramme:linear:issue-implement/SKILL.md"
    transition="skills/kramme:linear:issue-implement/references/status-transition.md"
    templates="skills/kramme:linear:issue-implement/references/display-templates.md"
    parent="skills/kramme:linear:issue-to-pr/SKILL.md"

    test -f "$transition"

    grep -qF "argument-hint: \"<ISSUE-ID> [--auto] [--set-in-progress]\"" "$skill"
    grep -qF "If \`--set-in-progress\` is present, set \`SET_IN_PROGRESS=true\`" "$skill"
    grep -qF "reject it together with \`--resume-current-branch\`" "$skill"
    grep -qF "Default \`SET_IN_PROGRESS=false\`, which leaves every Linear workflow status untouched." "$skill"
    grep -qF "A model caller may pass \`--set-in-progress\` only as that exact gated parent" "$skill"
    grep -qF "### 1.4 Apply the Authorized Status Transition" "$skill"
    grep -qF "read \`references/status-transition.md\` and follow it completely before Step 2" "$skill"
    grep -qF "The Step 1.4 status transition is the only Linear write this skill performs" "$skill"
    grep -qF "Linear transition: {transition-outcome}" "$templates"

    grep -qF "It is the only Linear write this skill performs." "$transition"
    grep -qF "never edit the title, description, labels, assignee, project, estimate, or any other mutable field" "$transition"
    grep -qF "In delegated mode, skip this section" "$transition"
    grep -qF "\`AUTO_MODE=true\` does not remove this confirmation." "$transition"
    grep -qF "Classify the invocation by the presence of a parent-owned status handoff, never by \`AUTO_MODE\`" "$transition"
    grep -qF "In direct invocation, prove the worktree can still reach branch setup before writing" "$transition"
    grep -qF "so a moved issue is never left without its branch" "$transition"
    grep -qF "the parent treats a delegated failure as a workflow failure" "$transition"
    grep -qF "Capture \`{transition-outcome}\` for Step 8'"'"'s success output" "$transition"
    grep -qF "set \`{transition-outcome}\` to \`not requested (--set-in-progress was not supplied)\`" "$skill"
    grep -qF "already {target-status-name} (continuation; no transition performed)" "$parent"

    grep -qF -- "{issue-id} --auto --set-in-progress" "$parent"

    transition_line=$(grep -nF "### 1.4 Apply the Authorized Status Transition" "$skill" | head -n1 | cut -d: -f1)
    branch_line=$(grep -nF "## Step 2: Branch Setup (MANDATORY - DO IMMEDIATELY)" "$skill" | head -n1 | cut -d: -f1)
    [ "$transition_line" -lt "$branch_line" ]

    diagram_transition=$(grep -nF "[Status Transition] -> ONLY with --set-in-progress" "$skill" | head -n1 | cut -d: -f1)
    diagram_branch=$(grep -nF "[Branch Setup] -> IMMEDIATELY create/switch" "$skill" | head -n1 | cut -d: -f1)
    [ "$diagram_transition" -lt "$diagram_branch" ]
  '

	assert_required_contracts_registered linear-issue-implement-status-transition

	[ "$status" -eq 0 ] || { echo "$output"; false; }
}
