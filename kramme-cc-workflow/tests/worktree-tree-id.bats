#!/usr/bin/env bats

load 'test_helper/common'

setup() {
  REPO_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  TREE_ID="$REPO_DIR/scripts/worktree-tree-id.sh"
  TMP_DIR="$(mktemp -d)"
  WORK="$TMP_DIR/work"
  init_test_git_repo "$WORK"
  cd "$WORK"
}

teardown() {
  if [ -n "$TMP_DIR" ] && [ -d "$TMP_DIR" ]; then
    rm -rf "$TMP_DIR"
  fi
}

@test "tree id equals HEAD tree for a clean worktree" {
  run "$TREE_ID"

  [ "$status" -eq 0 ]
  [ "$output" = "$(git rev-parse 'HEAD^{tree}')" ]
}

@test "tree id covers staged, unstaged, and untracked changes" {
  local clean_id staged_id unstaged_id untracked_id
  clean_id="$("$TREE_ID")"

  printf 'staged\n' > staged.txt
  git add staged.txt
  staged_id="$("$TREE_ID")"
  [ "$staged_id" != "$clean_id" ]

  printf 'changed\n' >> tracked.txt
  unstaged_id="$("$TREE_ID")"
  [ "$unstaged_id" != "$staged_id" ]

  printf 'new\n' > untracked.txt
  untracked_id="$("$TREE_ID")"
  [ "$untracked_id" != "$unstaged_id" ]

  [ "$("$TREE_ID")" = "$untracked_id" ]
}

@test "tree id survives committing the same content" {
  local dirty_id
  printf 'changed\n' >> tracked.txt
  printf 'new\n' > untracked.txt
  dirty_id="$("$TREE_ID")"

  git add --all
  git commit -m "commit verified content" > /dev/null

  [ "$("$TREE_ID")" = "$dirty_id" ]
  [ "$(git rev-parse 'HEAD^{tree}')" = "$dirty_id" ]
}

@test "tree id leaves the real index untouched" {
  local index_before
  printf 'changed\n' >> tracked.txt
  printf 'new\n' > untracked.txt
  index_before="$(git ls-files --stage)"

  run "$TREE_ID"

  [ "$status" -eq 0 ]
  [ "$(git ls-files --stage)" = "$index_before" ]
  [ "$(git status --porcelain)" = "$(printf ' M tracked.txt\n?? untracked.txt')" ]
}

@test "tree id ignores gitignored files" {
  local clean_id
  printf 'build/\n' > .gitignore
  git add .gitignore
  git commit -m "ignore build output" > /dev/null
  clean_id="$("$TREE_ID")"

  mkdir build
  printf 'artifact\n' > build/out.txt

  [ "$("$TREE_ID")" = "$clean_id" ]
}

@test "tree id is independent of the invoking subdirectory" {
  local root_id
  mkdir -p nested/dir
  printf 'nested\n' > nested/dir/file.txt
  root_id="$("$TREE_ID")"

  cd nested/dir
  [ "$("$TREE_ID")" = "$root_id" ]
}

@test "tree id rejects arguments and non-repositories" {
  run "$TREE_ID" --unexpected
  [ "$status" -eq 2 ]
  [[ "$output" == *"unknown argument: --unexpected"* ]]

  run "$TREE_ID" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage: worktree-tree-id.sh"* ]]

  cd "$TMP_DIR"
  run "$TREE_ID"
  [ "$status" -eq 1 ]
  [[ "$output" == *"not inside a git working tree"* ]]
}
