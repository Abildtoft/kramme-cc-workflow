#!/usr/bin/env bats

setup() {
  cd "$BATS_TEST_DIRNAME/.."
  CONTRACTS=(
    "skills/kramme:pr:code-review/references/output-template.md"
    "skills/kramme:pr:convention-review/references/conductor-diff-comments.md"
    "skills/kramme:pr:overengineering-review/references/conductor-diff-comments.md"
    "skills/kramme:pr:product-review/references/conductor-diff-comments.md"
  )
}

@test "every review producer reports stale diff comments without touching them" {
  local contract
  for contract in "${CONTRACTS[@]}"; do
    grep -qF 'add `Diff comments stale: K — <path> <finding-id>, ...` on its own line' "$contract"
    grep -qF "Never resolve, delete, edit, or repost a stale comment" "$contract"
    grep -qF "keep the count out of the canonical report" "$contract"
  done
  grep -qF 'and the `Diff comments stale:` line when the synced contract reports stale comments' skills/kramme:pr:code-review/SKILL.md
}

@test "optional diff comments say they can be dismissed without a code change" {
  local contract
  for contract in "${CONTRACTS[@]}"; do
    grep -qF "end that paragraph by saying the comment is optional and can be dismissed without a code change" "$contract"
  done
}
