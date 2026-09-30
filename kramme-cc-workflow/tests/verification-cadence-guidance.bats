#!/usr/bin/env bats

load 'test_helper/common'

setup() {
  REPO_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  RUN_SKILL="$REPO_DIR/skills/kramme:verify:run/SKILL.md"
  COMPLETION_SKILL="$REPO_DIR/skills/kramme:verify:before-completion/SKILL.md"
  CONVERGENCE_SKILL="$REPO_DIR/skills/kramme:pr:review-convergence/SKILL.md"
  IMPLEMENT_SKILL="$REPO_DIR/skills/kramme:linear:issue-implement/SKILL.md"
  IMPLEMENT_WORKFLOWS="$REPO_DIR/skills/kramme:linear:issue-implement/references/implementation-workflows.md"
  ISSUE_SHIPPING="$REPO_DIR/skills/kramme:linear:issue-to-pr/references/shipping-contract.md"
  PLAN_SHIPPING="$REPO_DIR/skills/kramme:code:plan-to-pr/references/shipping-contract.md"
}

@test "verify run selects a tier and reports the verified tree" {
  grep -qF 'argument-hint: "[--fast | --full] [--force]"' "$RUN_SKILL"
  grep -qF '### 4. Select the Tier' "$RUN_SKILL"
  grep -qF 'Without either flag, run the full tier for compatibility with callers that require a complete verification battery.' "$RUN_SKILL"
  grep -qF 'TREE_ID=$("${CLAUDE_PLUGIN_ROOT}/scripts/worktree-tree-id.sh") || TREE_ID=""' "$RUN_SKILL"
  grep -qF 'Verified tree: <TREE_ID> (merge-base <MERGE_BASE>)' "$RUN_SKILL"
}

@test "verify run reuses only green runs on the same tree and reruns failures narrowly" {
  grep -qF 'Unless `--force` is present, do not run the checks again' "$RUN_SKILL"
  grep -qF 'An empty `TREE_ID` never matches.' "$RUN_SKILL"
  grep -qF 'Never reuse a failed or partial run as a green tier result.' "$RUN_SKILL"
  grep -qF 'Narrowed Retry by the Caller' "$RUN_SKILL"
  grep -qF 'Rerun the exact failed check commands' "$RUN_SKILL"
  grep -qF 'PASS (carried from <tree ID>)' "$RUN_SKILL"
}

@test "verify run keeps long checks from losing their exit status" {
  grep -qF '### Long-Running Checks' "$RUN_SKILL"
  grep -qF 'reports the filter'"'"'s exit status instead of the check'"'"'s' "$RUN_SKILL"
  grep -qF 'Let a running check finish before editing the tree for an unrelated fix.' "$RUN_SKILL"
}

@test "before-completion accepts a green run on an unchanged tree" {
  grep -qF '## Reusing a Green Run' "$COMPLETION_SKILL"
  grep -qF '"${CLAUDE_PLUGIN_ROOT}/scripts/worktree-tree-id.sh"' "$COMPLETION_SKILL"
  grep -qF 'both IDs are non-empty and equal' "$COMPLETION_SKILL"
  grep -qF '**After the branch is pushed**: CI can supply the full sweep' "$COMPLETION_SKILL"
  grep -qF 'Never run two overlapping full sweeps on the same tree.' "$COMPLETION_SKILL"
  run grep -qF "If you haven't run the verification command in this message, you cannot claim it passes." "$COMPLETION_SKILL"
  [ "$status" -eq 1 ]
}

@test "review convergence skips its final sweep on an already verified tree" {
  grep -qF 'Invoke `kramme:verify:run --full`.' "$CONVERGENCE_SKILL"
  grep -qF 'same resolved `BASE_REF` commit OID and `MERGE_BASE`' "$CONVERGENCE_SKILL"
  grep -qF 'Narrowed Retry by the Caller procedure' "$CONVERGENCE_SKILL"
}

@test "issue implement uses the fast tier and leaves the full sweep to publication" {
  grep -qF 'Use `kramme:verify:run --fast`' "$IMPLEMENT_SKILL"
  grep -qF 'Do not run the full pre-push or pre-PR sweep here.' "$IMPLEMENT_SKILL"
  grep -qF 'Invoke `kramme:verify:run --fast`' "$IMPLEMENT_WORKFLOWS"
  run grep -qF 'for full verification' "$IMPLEMENT_WORKFLOWS"
  [ "$status" -eq 1 ]
}

@test "shipping contracts reuse green CI instead of a local final-tree sweep" {
  for shipping in "$ISSUE_SHIPPING" "$PLAN_SHIPPING"; do
    grep -qF 'Passing check buckets alone do not prove full verification coverage.' "$shipping"
    grep -qF 'Map every applicable check from the project'"'"'s full verification tier' "$shipping"
    grep -qF 'invoke `kramme:verify:run` with `--full` on the final tree' "$shipping"
  done
}
