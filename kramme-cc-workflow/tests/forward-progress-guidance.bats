#!/usr/bin/env bats

setup() {
  cd "$BATS_TEST_DIRNAME/.."
}

SKILL="skills/kramme:code:forward-progress/SKILL.md"
SOURCES="skills/kramme:code:forward-progress/references/sources.yaml"

@test "forward progress is a hidden advisory convention with explicit safety boundaries" {
  grep -qF "name: kramme:code:forward-progress" "$SKILL"
  grep -qF "disable-model-invocation: false" "$SKILL"
  grep -qF "user-invocable: false" "$SKILL"
  grep -qF "This convention is advisory. It grants no permission" "$SKILL"
  grep -qF "Treat workflow control as substantive when getting it wrong could:" "$SKILL"
  grep -qF "Follow substantive controls exactly." "$SKILL"
  grep -qF "rerun the smallest affected dependency cone" "$SKILL"
  grep -qF "Do not run a blocked stage manually, clear a lock, fabricate a receipt" "$SKILL"
}

@test "forward progress preserves plan, Linear, resume, verification, and publication controls" {
  direct="skills/kramme:code:work-from-plan/references/direct-execution.md"
  work_from_plan="skills/kramme:code:work-from-plan/SKILL.md"
  linear="skills/kramme:linear:issue-implement/references/implementation-workflows.md"
  linear_skill="skills/kramme:linear:issue-implement/SKILL.md"
  plan_to_pr="skills/kramme:code:plan-to-pr/SKILL.md"

  grep -qF "apply \`kramme:code:forward-progress\`" "$direct"
  grep -qF "scope boundary, user-approval boundary, and verification requirement" "$direct"
  grep -qF 'Read and follow `references/direct-execution.md`.' "$work_from_plan"
  grep -qF "During Guided or Autonomous implementation, apply \`kramme:code:forward-progress\`" "$linear"
  grep -qF "Branch identity, Linear requirements, user confirmations, resume proofs" "$linear"
  grep -qF 'Read the implementation workflow for the selected approach from `references/implementation-workflows.md`.' "$linear_skill"
  grep -qF "Apply \`kramme:code:forward-progress\` inside the delegated implementation work below" "$plan_to_pr"
  grep -qF "without invoking the convention outside delegation" "$plan_to_pr"
  grep -qF "a valid checkpoint prevents unnecessary reimplementation while preserving every downstream gate" "$plan_to_pr"
}

@test "forward progress declares rewritten external inspiration" {
  grep -qF "id: vuk97-forward-implementation-first" "$SOURCES"
  grep -qF "usage: inspiration" "$SOURCES"
  grep -qF "baseline_commit: 91fa46a0108ecfc612a55cf587a2086621a31161" "$SOURCES"
  grep -qF "baseline_hash:" "$SOURCES"
  test ! -e "skills/kramme:code:forward-progress/references/sources-snapshot"
}
