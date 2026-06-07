#!/usr/bin/env bats

@test "code optimize helper scripts pass bash syntax checks" {
	run bash -c '
    cd "'"$BATS_TEST_DIRNAME"'/.."
    bash -n "skills/kramme:code:optimize/scripts/measure.sh"
    bash -n "skills/kramme:code:optimize/scripts/parallel-probe.sh"
    bash -n "skills/kramme:code:optimize/scripts/experiment-worktree.sh"
  '

	[ "$status" -eq 0 ]
}

@test "code optimize examples include required schema sections" {
	run bash -c '
    cd "'"$BATS_TEST_DIRNAME"'/.."
    for spec in \
      "skills/kramme:code:optimize/references/example-hard-spec.yaml" \
      "skills/kramme:code:optimize/references/example-judge-spec.yaml"
    do
      grep -q "^name:" "$spec"
      grep -q "^metric:" "$spec"
      grep -q "^measurement:" "$spec"
      grep -q "^scope:" "$spec"
      grep -q "^execution:" "$spec"
      grep -q "degenerate_gates:" "$spec"
      grep -q "command:" "$spec"
      grep -q "mutable:" "$spec"
      grep -q "immutable:" "$spec"
    done
  '

	[ "$status" -eq 0 ]
}

@test "code optimize source manifest cites ce-optimize" {
	run bash -c '
    cd "'"$BATS_TEST_DIRNAME"'/.."
    manifest="skills/kramme:code:optimize/references/sources.yaml"
    grep -q "compound-ce-optimize" "$manifest"
    grep -q "ce-optimize" "$manifest"
    grep -q "6f9ab03a031c054a8046659926251fb6c149269f" "$manifest"
  '

	[ "$status" -eq 0 ]
}

@test "code optimize worktree helper does not copy env files implicitly" {
	run bash -c '
    set -euo pipefail
    repo="$BATS_TEST_TMPDIR/optimize-env-copy-repo"
    mkdir -p "$repo"
    cd "$repo"
    git init -q
    git config user.email "test@example.com"
    git config user.name "Test User"
    touch tracked.txt
    printf "SECRET=value\n" > .env
    git add tracked.txt
    git commit -qm init

    helper="'"$BATS_TEST_DIRNAME"'/../skills/kramme:code:optimize/scripts/experiment-worktree.sh"
    worktree_path=$("$helper" create safe-spec 1 HEAD)

    test ! -e "$worktree_path/.env"
  '

	[ "$status" -eq 0 ]
}

@test "code optimize worktree helper rejects shared files outside repo" {
	run bash -c '
    set -euo pipefail
    repo="$BATS_TEST_TMPDIR/optimize-shared-file-repo"
    mkdir -p "$repo"
    cd "$repo"
    git init -q
    git config user.email "test@example.com"
    git config user.name "Test User"
    touch tracked.txt
    git add tracked.txt
    git commit -qm init

    helper="'"$BATS_TEST_DIRNAME"'/../skills/kramme:code:optimize/scripts/experiment-worktree.sh"
    if "$helper" create safe-spec 1 HEAD ../outside.txt; then
      echo "expected shared file traversal to fail"
      exit 1
    fi
  '

	[ "$status" -eq 0 ]
}
