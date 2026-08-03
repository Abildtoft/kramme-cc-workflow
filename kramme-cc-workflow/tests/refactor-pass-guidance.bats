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

@test "default scope uses the canonical review diff collector" {
  local skill="skills/kramme:code:refactor-pass/SKILL.md"

  grep -qF "Synced base/diff scope contract (keep aligned across base-aware and diff-aware skills)" "$skill"
  grep -qF '"${CLAUDE_PLUGIN_ROOT}/scripts/collect-review-diff.sh" --strict --format json' "$skill"
  grep -qF 'pass `BASE_REF`, `MERGE_BASE`, and `CHANGED_FILES`' "$skill"
}

@test "AI slop candidates use the normal refactor safety loop" {
  local skill="skills/kramme:code:refactor-pass/SKILL.md"

  grep -qF "AI-slop findings enter the same one-slice loop, Fence, verification, commit, and recovery contract as every other candidate." "$skill"
  grep -qF "Confidence makes it a candidate, not a command." "$skill"
  grep -qF "Verify and commit one at a time." "$skill"
}

@test "uncommitted input gets a separate verified recovery checkpoint" {
  local skill="skills/kramme:code:refactor-pass/SKILL.md"
  local discovery_line
  local checkpoint_line

  grep -qF 'Run `kramme:verify:run` on the unchanged starting tree.' "$skill"
  grep -qF "Create one clearly labeled recovery checkpoint commit containing the exact pre-existing changes inside the resolved scope and no cleanup." "$skill"
  grep -qF "The checkpoint is a recovery boundary, not a simplification slice." "$skill"
  grep -qF "Never fold the first cleanup into it." "$skill"
  discovery_line="$(grep -n '^## Discover default-mode candidates$' "$skill" | cut -d: -f1)"
  checkpoint_line="$(grep -n '^## Establish a commit baseline$' "$skill" | cut -d: -f1)"
  test "$discovery_line" -lt "$checkpoint_line"
  grep -qF "stop without verifying, checkpointing, editing, or committing" "$skill"
}

@test "AI slop discovery keeps generated-like files out of its candidates" {
  local skill="skills/kramme:code:refactor-pass/SKILL.md"

  grep -qF 'generated files, vendored code, lockfiles, snapshots, or `*.d.ts` files' "$skill"
  grep -qF "These exclusions apply to the AI-slop aspect" "$skill"
}

@test "AI slop discovery fails closed and excludes visual redesign" {
  local skill="skills/kramme:code:refactor-pass/SKILL.md"

  grep -qF "Do not treat a failed reviewer call as an empty finding set or report the scope clean." "$skill"
  grep -qF "Visual redesign findings are not behavior-preserving simplifications." "$skill"
  grep -qF 'suggest `kramme:pr:ux-review` instead' "$skill"
  ! grep -qF "Generic AI-aesthetic UI defaults" "$skill"
}

@test "README documents the cleanup command migration" {
  grep -qF '/kramme:code:cleanup-ai' ../README.md
  grep -qF 'does not preserve the old arguments or side effects' ../README.md
}
