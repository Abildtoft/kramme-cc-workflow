#!/usr/bin/env bats

@test "code review modes and consumers require execution evidence" {
  local root="$BATS_TEST_DIRNAME/.."
  local skill="$root/skills/kramme:pr:code-review"
  run node --test "$root/tests/node/review-completion-eval.test.js"
  [ "$status" -eq 0 ]
  [[ "$(cat "$skill/SKILL.md")" == *'references/execution-contract.md'* ]]
  [[ "$(cat "$skill/references/team-mode.md")" == *'seal the exact temporary'* ]]
  [[ "$(cat "$skill/references/closeout-loop.md")" == *'Missing, incomplete, filtered-to-a-different-scope, or stale evidence blocks this loop'* ]]
  [[ "$(cat "$skill/references/output-template.md")" != *'Coverage Status (omit when complete)'* ]]
  [[ "$(cat "$root/skills/kramme:pr:review-convergence/references/review-convergence.md")" == *'--report <saved-report> --aspects all'* ]]
}

@test "execution helper rejects malformed commands without completing review" {
  run node "$BATS_TEST_DIRNAME/../skills/kramme:pr:code-review/scripts/review-execution.js" check
  [ "$status" -ne 0 ]
  [[ "$output" == *'INCOMPLETE:'* ]]
}

@test "review modes freeze no-cleanup without narrowing default aspect scope" {
  local skill="$BATS_TEST_DIRNAME/../skills/kramme:pr:code-review"
  local contract
  contract="$(cat "$skill/references/execution-contract.md")"
  [[ "$(cat "$skill/SKILL.md")" == *'Save this boolean as `noCleanup` in the execution plan while retaining `["all"]`'* ]]
  [[ "$(cat "$skill/references/team-mode.md")" == *'as `noCleanup` and `emphasizedDimensions` per `references/execution-contract.md`'* ]]
  [[ "$contract" == *'"noCleanup": false'* ]]
  [[ "$contract" == *'"emphasizedDimensions": []'* ]]
  [[ "$contract" == *'retain `aspects: ["all"]` for default scope'* ]]
  [[ "$contract" == *'still evaluates `removal` independently'* ]]
  [[ "$contract" == *'including convergence delta reviews with `noCleanup: true`'* ]]
}
