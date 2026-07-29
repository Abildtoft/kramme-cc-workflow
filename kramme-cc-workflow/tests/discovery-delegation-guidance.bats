#!/usr/bin/env bats

@test "SIW discovery delegates through the shared interview contract without losing caller behavior" {
	run bash -c '
    set -e
    cd "'"$BATS_TEST_DIRNAME"'/.."

    siw_skill="skills/kramme:siw:discovery/SKILL.md"
    interview_dir="skills/kramme:discovery:interview"
    interview_skill="$interview_dir/SKILL.md"
    decision_tree="$interview_dir/references/decision-tree-mode.md"
    probing="$interview_dir/references/probing-techniques.md"
    apply_protocol="skills/kramme:siw:discovery/references/apply-protocol.md"

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
    grep -qF "including initial/final confidence, overall percentage, interview-round count" "$siw_skill"
    grep -qF "payload without the \`INTERVIEW RESULT:\` marker or any required field" "$siw_skill"
    grep -qF "stop without replaying the interview, writing an SIW artifact, or emitting \`PLAN:\`" "$siw_skill"
    grep -qF "cannot invoke \`kramme:discovery:interview\`" "$siw_skill"
    grep -qF "inline substitute" "$siw_skill"
    grep -qF "Artifact readiness: <requirements-only|planning-ready> — <reason>" "$siw_skill"
    grep -qF "EnterPlanMode" "$siw_skill"

    grep -qF "Accept an \`INTERVIEW DELEGATION\` brief" "$interview_skill"
    grep -qF "**Decision-tree context**" "$interview_skill"
    grep -qF "apply any decision-tree context" "$interview_skill"
    grep -qF "Return \`INTERVIEW RESULT:\`" "$interview_skill"
    grep -qF "validated hypothesis and topic classification" "$interview_skill"
    grep -qF "decisions with rationales" "$interview_skill"
    grep -qF "non-goals with rationales and stated-vs-actual divergence" "$interview_skill"
    grep -qF "initial confidence, final confidence with overall percentage, and interview-round count" "$interview_skill"
    grep -qF "an impact map from each decision to affected source file/section" "$interview_skill"
    grep -qF "the evidence ledger for an evidence-confidence profile or topic-coverage status" "$interview_skill"
    grep -qF "unresolved \`MISSING REQUIREMENT\` items, risks, and source references" "$interview_skill"
    grep -qF "Do not ask for a plan path, write a standalone template, or emit \`PLAN:\`" "$interview_skill"
    grep -qF "stop at the invocation boundary" "$interview_skill"
    grep -qF "present the working hypothesis before the first question as a 2–4 sentence \`UNVERIFIED:\` statement" "$interview_skill"
    grep -qF "If the user requests Decision-Tree mode mid-session" "$interview_skill"
    grep -qF "Do not load the other profile'\''s round, progress, or stop contract" "$interview_skill"
    grep -qF "Delegated hand-off includes \`INTERVIEW RESULT:\` and does not emit \`PLAN:\`" "$interview_skill"
    grep -qF "references/confidence-framework.md" "$interview_skill"
    grep -qF "references/probing-techniques.md" "$interview_skill"
    grep -qF "built-in Other path for a free-text answer" "$probing"
    grep -qF "Do not omit the required predefined options" "$probing"
    grep -qF "ADR-offer hook owned by the active progress profile" "$decision_tree"
    grep -qF "validated \`INTERVIEW RESULT:\` and its artifact impact map" "$apply_protocol"
    ! grep -qF "decisions from Step 4" "$apply_protocol"

    result_line=$(grep -nF "Return \`INTERVIEW RESULT:\`" "$interview_skill" | cut -d: -f1)
    standalone_line=$(grep -nF "## Step 5: Output Plan Document" "$interview_skill" | cut -d: -f1)
    [ "$result_line" -lt "$standalone_line" ]

    ! grep -qF "## In SIW Discovery" "$decision_tree"
    ! grep -qF "execute Steps 1–4 inline" "$interview_skill"
    ! grep -qF "execute its delegated-call contract inline" "$siw_skill"
    grep -qF "high-stakes architecture, data-model shape, refactor sequencing, and migration approach" "$siw_skill"
  '

	[ "$status" -eq 0 ]
}
