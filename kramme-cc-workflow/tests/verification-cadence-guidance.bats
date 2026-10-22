#!/usr/bin/env bats

load 'test_helper/common'

setup() {
  REPO_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  RUN_SKILL="$REPO_DIR/skills/kramme:verify:run/SKILL.md"
  CLAIMS_REF="$REPO_DIR/skills/kramme:verify:run/references/completion-claims.md"
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

@test "verify run gates completion claims on current-tree evidence" {
  grep -qF '## Evidence Before Claims' "$RUN_SKILL"
  grep -qF '"${CLAUDE_PLUGIN_ROOT}/scripts/worktree-tree-id.sh"' "$RUN_SKILL"
  grep -qF 'both IDs are non-empty and equal' "$RUN_SKILL"
  grep -qF '**After the branch is pushed**: CI can supply the full sweep' "$RUN_SKILL"
  grep -qF 'Never run two overlapping full sweeps on the same tree.' "$RUN_SKILL"
  grep -qF 'references/completion-claims.md' "$RUN_SKILL"
  run grep -qF "If you haven't run the verification command in this message, you cannot claim it passes." "$RUN_SKILL"
  [ "$status" -eq 1 ]
  run grep -qF 'git stash pop' "$RUN_SKILL"
  [ "$status" -eq 1 ]
  [ ! -e "$REPO_DIR/skills/kramme:verify:before-completion" ]
}

@test "red-green check restores by commit ID and retains both sessions' stashes" {
  local fixture="$BATS_TEST_TMPDIR/repo"
  local other_worktree="$BATS_TEST_TMPDIR/other-session"
  local blocks_dir="$BATS_TEST_TMPDIR/commands"
  local other_stash_sha

  init_test_git_repo "$fixture" --file fix.txt
  cd "$fixture"
  printf 'unrelated base\n' > unrelated.txt
  git add unrelated.txt
  git commit -m "Add unrelated fixture" >/dev/null
  git worktree add -b other-session "$other_worktree" >/dev/null
  printf 'fixed\n' > fix.txt
  cat > regression-test.sh <<'TEST'
#!/usr/bin/env bash
test "$(cat fix.txt)" = fixed
TEST
  bash regression-test.sh

  mkdir -p "$blocks_dir"
  awk -v directory="$blocks_dir" '
    /^## Red-green check for a regression test$/ { in_section = 1; next }
    in_section && /^```bash$/ { block++; capturing = 1; next }
    capturing && /^```$/ { capturing = 0; next }
    capturing {
      gsub(/<files changed by the fix>/, "fix.txt")
      print > (directory "/" block ".bash")
    }
  ' "$CLAIMS_REF"
  [ -s "$blocks_dir/1.bash" ]
  [ -s "$blocks_dir/2.bash" ]
  [ ! -e "$blocks_dir/3.bash" ]

  source "$blocks_dir/1.bash"
  [ "$(cat fix.txt)" = base ]
  [ -f regression-test.sh ]
  run bash regression-test.sh
  [ "$status" -eq 1 ]

  printf 'other session work\n' > "$other_worktree/unrelated.txt"
  git -C "$other_worktree" stash push --message another-session -- unrelated.txt
  other_stash_sha=$(git rev-parse refs/stash)
  [ "$(git rev-parse 'stash@{1}')" = "$RG_SHA" ]

  git stash apply "$RG_SHA"
  bash regression-test.sh
  run source "$blocks_dir/2.bash"
  [ "$status" -eq 0 ]
  [[ "$output" == *"$RG_TAG"* ]]
  [[ "$output" == *"$RG_SHA"* ]]
  [ "$(cat fix.txt)" = fixed ]
  [ -f regression-test.sh ]
  [ "$(cat unrelated.txt)" = 'unrelated base' ]
  [ "$(git stash list --format='%H')" = "$other_stash_sha"$'\n'"$RG_SHA" ]
  [ "$(git show "$other_stash_sha:unrelated.txt")" = 'other session work' ]
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
