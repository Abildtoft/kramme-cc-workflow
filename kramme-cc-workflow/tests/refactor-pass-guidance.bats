#!/usr/bin/env bats

setup() {
  cd "$BATS_TEST_DIRNAME/.."
}

@test "refactor pass discovers AI slop by default" {
  local skill="skills/kramme:code:refactor-pass/SKILL.md"

  test -f "$skill"
  test ! -e "skills/kramme:code:cleanup-ai/SKILL.md"
  grep -qF "Default mode includes AI-slop review without a separate flag." "$skill"
  grep -qF "Rewrite mode skips this discovery step" "$skill"
  grep -qF 'Launch `kramme:deslop-reviewer` in code review mode against `REFACTOR_SCOPE_PATHS`.' "$skill"
  grep -qF "Treat every reported slop finding as a candidate, not an instruction." "$skill"
}

@test "default scope uses the canonical review diff collector" {
  local skill="skills/kramme:code:refactor-pass/SKILL.md"

  grep -qF "Synced base/diff scope contract (keep aligned across base-aware and diff-aware skills)" "$skill"
  grep -qF '"${CLAUDE_PLUGIN_ROOT}/scripts/collect-review-diff.sh" --strict --format json' "$skill"
  grep -qF 'pass `BASE_REF`, `MERGE_BASE`, and filtered `REFACTOR_SCOPE_PATHS`' "$skill"
}

@test "AI slop candidates use the normal refactor safety loop" {
  local skill="skills/kramme:code:refactor-pass/SKILL.md"

  grep -qF "AI-slop findings enter the same one-slice loop, Fence, verification, commit, and recovery contract as every other candidate." "$skill"
  grep -qF "again after each verified slice" "$skill"
  grep -qF "Revalidate every remaining finding against current lines" "$skill"
  grep -qF "Confidence makes it a candidate, not a command." "$skill"
  grep -qF "Verify and commit one at a time." "$skill"
}

@test "uncommitted input gets a separate verified recovery checkpoint" {
  local skill="skills/kramme:code:refactor-pass/SKILL.md"
  local discovery_line
  local checkpoint_line

  grep -qF 'Run `kramme:verify:run` on the unchanged starting tree.' "$skill"
  grep -qF 'references/protected-workflow-artifacts.txt' "$skill"
  grep -qF "must never enter the checkpoint path set" "$skill"
  grep -qF 'Create one clearly labeled recovery checkpoint commit containing the exact pre-existing changes in `REFACTOR_SCOPE_PATHS` and no cleanup.' "$skill"
  grep -qF 'CHECKPOINT_INDEX_TREE=$(git write-tree)' "$skill"
  grep -qF 'git read-tree "$CHECKPOINT_INDEX_TREE"' "$skill"
  grep -qF "Do not continue after a failed checkpoint commit." "$skill"
  grep -qF 'SLICE_INDEX_TREE=$(git write-tree)' "$skill"
  grep -qF "do not refresh discovery against an uncreated baseline" "$skill"
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
  grep -qF '**Breaking:** Replace `/kramme:code:cleanup-ai` with `/kramme:code:refactor-pass`.' CHANGELOG.md
  grep -qF 'Ship this command removal only in the next major release.' CHANGELOG.md
}

@test "protected workflow artifacts stay synchronized with the commit guard" {
  cmp -s \
    "skills/kramme:code:refactor-pass/references/protected-workflow-artifacts.txt" \
    "hooks/confirm-review-artifacts.txt"
}
