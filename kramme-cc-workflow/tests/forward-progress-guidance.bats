#!/usr/bin/env bats

setup() {
  cd "$BATS_TEST_DIRNAME/.."
}

REFERENCE="shared/implementation/references/forward-progress.md"
CONSUMERS=(
  "skills/kramme:code:plan-to-pr"
  "skills/kramme:code:work-from-plan"
  "skills/kramme:linear:issue-implement"
)

@test "forward progress is a shared advisory reference with explicit safety boundaries" {
  test ! -e "skills/kramme:code:forward-progress"
  grep -qF "# Preserve Forward Progress" "$REFERENCE"
  grep -qF "it never bypasses controls that protect identity, authority, integrity, concurrency, resumability, scope, CI, or publication safety." "$REFERENCE"
  grep -qF "This convention is advisory. It grants no permission" "$REFERENCE"
  grep -qF "Treat workflow control as substantive when getting it wrong could:" "$REFERENCE"
  grep -qF "Follow substantive controls exactly." "$REFERENCE"
  grep -qF "rerun the smallest affected dependency cone" "$REFERENCE"
  grep -qF "Do not run a blocked stage manually, clear a lock, fabricate a receipt" "$REFERENCE"
}

@test "forward progress preserves plan, Linear, resume, verification, and publication controls" {
  direct="skills/kramme:code:work-from-plan/references/direct-execution.md"
  work_from_plan="skills/kramme:code:work-from-plan/SKILL.md"
  linear="skills/kramme:linear:issue-implement/references/implementation-workflows.md"
  linear_skill="skills/kramme:linear:issue-implement/SKILL.md"
  plan_to_pr="skills/kramme:code:plan-to-pr/SKILL.md"
  resolve='Resolve `${CLAUDE_PLUGIN_ROOT}/shared/implementation/references/forward-progress.md` as `{forward-progress-reference}`'

  grep -qF "Read \`{forward-progress-reference}\` before applying it." "$direct"
  grep -qF "scope boundary, user-approval boundary, and verification requirement" "$direct"
  grep -qF "$resolve, or use the resolved path the caller passed, then read \`{forward-progress-reference}\` before applying it in \`references/direct-execution.md\`." "$work_from_plan"
  grep -qF 'Read and follow `references/direct-execution.md`.' "$work_from_plan"
  grep -qF "During Guided or Autonomous implementation, read \`{forward-progress-reference}\` before applying the convention" "$linear"
  grep -qF "Branch identity, Linear requirements, user confirmations, resume proofs" "$linear"
  grep -qF 'Read the implementation workflow for the selected approach from `references/implementation-workflows.md`.' "$linear_skill"
  grep -qF "$resolve, then read it before applying the convention in that workflow." "$linear_skill"
  grep -qF "$resolve and pass it with the implementation handoff" "$plan_to_pr"
  grep -qF "without invoking the convention outside delegation" "$plan_to_pr"
  grep -qF "a valid checkpoint prevents unnecessary reimplementation while preserving every downstream gate" "$plan_to_pr"
}

@test "forward progress consumers declare its rewritten external inspiration" {
  for consumer in "${CONSUMERS[@]}"; do
    sources="$consumer/references/sources.yaml"
    grep -qF "id: vuk97-forward-implementation-first" "$sources"
    grep -qF "baseline_commit: 91fa46a0108ecfc612a55cf587a2086621a31161" "$sources"
    grep -qF "The shared forward-progress reference's context-recovery paragraph retains its idea" "$sources"
    test ! -e "$consumer/references/sources-snapshot"
  done
}
