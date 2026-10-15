#!/usr/bin/env bats

@test "discovery interview folds SIW discovery in as a mode without a delegation contract" {
	run bash -c '
    set -e
    cd "'"$BATS_TEST_DIRNAME"'/.."

    interview_dir="skills/kramme:discovery:interview"
    interview_skill="$interview_dir/SKILL.md"
    decision_tree="$interview_dir/references/decision-tree-mode.md"
    probing="$interview_dir/references/probing-techniques.md"
    siw_mode="$interview_dir/references/siw-mode.md"
    apply_protocol="$interview_dir/references/siw-apply-protocol.md"

    test ! -e "skills/kramme:siw:discovery"
    test -f "$interview_skill"
    test -f "$interview_dir/references/confidence-framework.md"
    test -f "$probing"
    test -f "$siw_mode"
    test -f "$apply_protocol"
    test -f "$interview_dir/references/siw-synthesis-checklist.md"
    test -f "$interview_dir/assets/siw-discovery-brief-template.md"
    test -f "$interview_dir/assets/siw-spec-strengthening-plan-template.md"
    grep -q "^disable-model-invocation: false$" "$interview_skill"
    grep -qF "argument-hint: \"[topic | file-path(s) | siw] [--siw] [--apply] [--ideate] [--decision-tree] [--research]\"" "$interview_skill"

    # The sibling-skill delegation contract is retired.
    ! grep -qF "INTERVIEW DELEGATION" "$interview_skill"
    ! grep -qF "## Called by Another Skill" "$interview_skill"
    ! grep -qiF "delegated" "$interview_skill"
    ! grep -qF "caller_mode" "$siw_mode"

    # Shared interview engine behavior
    grep -qF "If the user requests Decision-Tree mode mid-session" "$interview_skill"
    grep -qF "apply the SIW decision-tree context when SIW mode is active" "$interview_skill"
    grep -qF "Do not load the other profile'\''s round, progress, or stop contract" "$interview_skill"
    grep -qF "built-in Other path for a free-text answer" "$probing"
    grep -qF "Do not omit the required predefined options" "$probing"
    grep -qF "Ask 1-3 high-value questions per round" "$probing"
    grep -qF "ADR-offer hook owned by the active progress profile" "$decision_tree"
    ! grep -qF "## In SIW Discovery" "$decision_tree"
    grep -qF "Direct standalone hand-off includes the \`PLAN:\` marker." "$interview_skill"

    # SIW mode selection: flags are stripped before the bare siw keyword is detected.
    apply_line=$(grep -nF "If \`--apply\` is present, set \`apply_changes=true\`" "$interview_skill" | cut -d: -f1)
    bare_line=$(grep -nF "Only after every flag above, including \`--apply\`, has been removed: if the only remaining argument is the bare keyword \`siw\`, set \`siw_mode=true\`" "$interview_skill" | cut -d: -f1)
    [ -n "$apply_line" ] && [ -n "$bare_line" ]
    [ "$apply_line" -lt "$bare_line" ]
    grep -qF "If \`--siw\` is present, set \`siw_mode=true\`" "$interview_skill"
    grep -qF "Also set \`siw_mode=true\` when every supplied file path is inside \`siw/\`." "$interview_skill"
    grep -qF "If some but not all paths are in \`siw/\` and \`--siw\` is absent, ask (AskUserQuestion) whether to run SIW mode." "$interview_skill"
    grep -qF "read \`references/siw-mode.md\` now and resolve SIW context" "$interview_skill"
    grep -qF "SIW mode uses the evidence-confidence profile at a 90% target" "$interview_skill"
    grep -qF "In SIW mode, \`--research\` runs Phase R as usual and \`--ideate\` runs Phase 0 only in Greenfield" "$interview_skill"
    grep -qF "so divergent framing never reframes away from the target spec" "$interview_skill"
    grep -qF "In SIW mode, present the working hypothesis before the first question as a 2–4 sentence \`UNVERIFIED:\` statement" "$interview_skill"
    grep -qF "In SIW mode, skip the standalone steps below and follow **Synthesize SIW Artifacts** and **Optional Apply** in \`references/siw-mode.md\`." "$interview_skill"

    # SIW behavior preserved from the former kramme:siw:discovery skill
    grep -qF "Use the **evidence-confidence** profile with a 90% target and the resolved Work Context profile" "$siw_mode"
    grep -qF "high-stakes architecture, data-model shape, refactor sequencing, and migration approach" "$siw_mode"
    grep -qF "Before synthesis, assemble \`INTERVIEW RESULT:\` with all of:" "$siw_mode"
    grep -qF "Any unresolved \`SPEC_STRENGTHENING_PLAN.md\`: stop before a new refinement pass" "$siw_mode"
    grep -qF "\`AUDIT_*.md\`, \`PRODUCT_AUDIT.md\`, \`SIW_*.md\`" "$siw_mode"
    grep -qF "Never overwrite the brief." "$siw_mode"
    grep -qF "PLAN: Written to siw/DISCOVERY_BRIEF.md." "$siw_mode"
    grep -qF "PLAN: Written to siw/SPEC_STRENGTHENING_PLAN.md." "$siw_mode"
    grep -qF "Artifact readiness: <requirements-only|planning-ready> — <reason>" "$siw_mode"
    grep -qF "EnterPlanMode" "$siw_mode"
    grep -qF "When \`kramme:siw:init\` invoked this run for its discover handoff, skip the plan-mode offer and the next-command suggestion" "$siw_mode"
    grep -qF "references/siw-synthesis-checklist.md" "$siw_mode"
    grep -qF "references/siw-apply-protocol.md" "$siw_mode"
    grep -qF "validated \`INTERVIEW RESULT:\` and its artifact impact map" "$apply_protocol"
    ! grep -qF "decisions from Step 4" "$apply_protocol"
  '

	[ "$status" -eq 0 ] || { echo "$output"; false; }

	run python3 \
		"$BATS_TEST_DIRNAME/test_helper/guidance_contracts.py" \
		discovery-result-schema \
		"$BATS_TEST_DIRNAME/../skills/kramme:discovery:interview/references/siw-mode.md"
	[ "$status" -eq 0 ] || { echo "$output"; false; }
}

@test "discovery interview keeps SIW --apply user-only and confirmed in-session" {
	run bash -c '
    set -e
    cd "'"$BATS_TEST_DIRNAME"'/.."

    interview_skill="skills/kramme:discovery:interview/SKILL.md"
    siw_mode="skills/kramme:discovery:interview/references/siw-mode.md"
    apply_protocol="skills/kramme:discovery:interview/references/siw-apply-protocol.md"
    handoff="skills/kramme:siw:init/references/greenfield-discovery-handoff.md"

    grep -qF "Honor \`apply_changes=true\` only when the user'\''s own message typed \`--apply\` or explicitly asked in this session to apply the strengthening plan." "$interview_skill"
    grep -qF "A model-initiated invocation, including a call from another skill such as \`kramme:siw:init\`, must not add \`--apply\`" "$interview_skill"
    grep -qF "If \`apply_changes=true\` but the run is not SIW Refinement (no SIW mode, or SIW context resolves to Greenfield), tell the user \`--apply\` only applies to SIW Refinement, ignore it, and continue." "$interview_skill"
    grep -qF "\`--apply\` has no effect in Greenfield" "$siw_mode"
    grep -qF "Proceed only on explicit approval in this session; otherwise stop and leave the plan in place." "$apply_protocol"
    grep -qF "If \`trash\` is installed, run \`trash siw/SPEC_STRENGTHENING_PLAN.md\` without suppressing errors." "$apply_protocol"

    grep -qF "Invoke \`kramme:discovery:interview\` through the Skill tool with exactly \`--siw <topic>\`" "$handoff"
    grep -qF "skips its plan-mode offer and next-command suggestion" "$handoff"
    grep -qF "Never pass \`--apply\`." "$handoff"
    grep -qF "If the runtime cannot invoke the skill, stop and tell the user to run \`/kramme:discovery:interview --siw <topic>\` and then \`/kramme:siw:init siw/DISCOVERY_BRIEF.md\`." "$handoff"
    grep -qF "If the discovery run does not create \`siw/DISCOVERY_BRIEF.md\`, stop without creating SIW workflow files." "$handoff"
    ! grep -qF "kramme:siw:discovery" "$handoff"
  '

	[ "$status" -eq 0 ] || { echo "$output"; false; }
}
