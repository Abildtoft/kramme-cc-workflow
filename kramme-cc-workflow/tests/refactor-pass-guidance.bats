#!/usr/bin/env bats

setup() {
  cd "$BATS_TEST_DIRNAME/.."
}

@test "refactor pass discovers AI slop by default" {
  local skill="skills/kramme:code:refactor-pass/SKILL.md"

  test -f "$skill"
  test ! -e "skills/kramme:code:cleanup-ai/SKILL.md"
  grep -qF "Default mode includes AI-slop review without a separate flag." "$skill"
  grep -qF 'Launch `kramme:deslop-reviewer` in code review mode against the resolved scope.' "$skill"
  grep -qF "Treat every reported slop finding as a candidate, not an instruction." "$skill"
}

@test "AI slop candidates use the normal refactor safety loop" {
  local skill="skills/kramme:code:refactor-pass/SKILL.md"

  grep -qF "AI-slop findings enter the same one-slice loop, Fence, verification, commit, and recovery contract as every other candidate." "$skill"
  grep -qF "Confidence makes it a candidate, not a command." "$skill"
  grep -qF "Verify and commit one at a time." "$skill"
}

@test "uncommitted input gets a separate verified recovery checkpoint" {
  local skill="skills/kramme:code:refactor-pass/SKILL.md"

  grep -qF 'Run `kramme:verify:run` on the unchanged starting tree.' "$skill"
  grep -qF "Create one clearly labeled recovery checkpoint commit containing the exact pre-existing changes inside the resolved scope and no cleanup." "$skill"
  grep -qF "The checkpoint is a recovery boundary, not a simplification slice." "$skill"
  grep -qF "Never fold the first cleanup into it." "$skill"
}

@test "AI slop discovery keeps generated-like files out of its candidates" {
  local skill="skills/kramme:code:refactor-pass/SKILL.md"

  grep -qF 'generated files, vendored code, lockfiles, snapshots, or `*.d.ts` files' "$skill"
  grep -qF "These exclusions apply to the AI-slop aspect" "$skill"
}
