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

@test "code optimize measurement runner forwards environment assignments" {
	run bash -c '
    cd "'"$BATS_TEST_DIRNAME"'/.."
    skills/kramme:code:optimize/scripts/measure.sh \
      "printf \"%s\\n\" \"\$OPTIMIZE_MEASURE_TOKEN\"" \
      5 \
      . \
      OPTIMIZE_MEASURE_TOKEN=forwarded
  '

	[ "$status" -eq 0 ]
	[ "$output" = "forwarded" ]
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

@test "code optimize skill declares shell permissions" {
	run bash -c '
    cd "'"$BATS_TEST_DIRNAME"'/.."
    skill="skills/kramme:code:optimize/SKILL.md"
    grep -q "^permissions:" "$skill"
    grep -q "^  - shell$" "$skill"
  '

	[ "$status" -eq 0 ]
}

@test "code optimize worktree helper avoids force deletion patterns" {
	run bash -c '
    cd "'"$BATS_TEST_DIRNAME"'/.."
    helper="skills/kramme:code:optimize/scripts/experiment-worktree.sh"
    ! grep -Eq "rm[[:space:]]+-[^[:space:]]*f" "$helper"
    ! grep -Fq "rmdir \"\$worktree_dir\"" "$helper"
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

@test "code optimize worktree cleanup rejects unsafe names and indexes" {
	run bash -c '
    set -euo pipefail
    repo="$BATS_TEST_TMPDIR/optimize-cleanup-invalid-repo"
    mkdir -p "$repo"
    cd "$repo"
    git init -q
    git config user.email "test@example.com"
    git config user.name "Test User"
    touch tracked.txt
    git add tracked.txt
    git commit -qm init

    helper="'"$BATS_TEST_DIRNAME"'/../skills/kramme:code:optimize/scripts/experiment-worktree.sh"
    for spec_name in "*" "safe/spec" "../safe"; do
      if "$helper" cleanup "$spec_name" 1; then
        echo "expected cleanup to reject spec_name: $spec_name"
        exit 1
      fi
    done

    for exp_index in abc "1/../../main"; do
      if "$helper" cleanup safe-spec "$exp_index"; then
        echo "expected cleanup to reject exp_index: $exp_index"
        exit 1
      fi
    done

    for spec_name in "*" "safe/spec" "../safe"; do
      if "$helper" cleanup-all "$spec_name"; then
        echo "expected cleanup-all to reject spec_name: $spec_name"
        exit 1
      fi
    done
  '

	[ "$status" -eq 0 ]
}

@test "code optimize worktree cleanup-all does not expand wildcard specs" {
	run bash -c '
    set -euo pipefail
    repo="$BATS_TEST_TMPDIR/optimize-cleanup-wildcard-repo"
    mkdir -p "$repo"
    cd "$repo"
    git init -q
    git config user.email "test@example.com"
    git config user.name "Test User"
    touch tracked.txt
    git add tracked.txt
    git commit -qm init

    helper="'"$BATS_TEST_DIRNAME"'/../skills/kramme:code:optimize/scripts/experiment-worktree.sh"
    worktree_path=$("$helper" create safe-spec 1 HEAD)

    if "$helper" cleanup-all "*"; then
      echo "expected wildcard cleanup-all to fail"
      exit 1
    fi

    test -d "$worktree_path"
    git show-ref --verify --quiet refs/heads/optimize-exp/safe-spec/exp-001
  '

	[ "$status" -eq 0 ]
}

@test "code optimize worktree cleanup removes one registered experiment" {
	run bash -c '
    set -euo pipefail
    repo="$BATS_TEST_TMPDIR/optimize-cleanup-one-repo"
    mkdir -p "$repo"
    cd "$repo"
    git init -q
    git config user.email "test@example.com"
    git config user.name "Test User"
    touch tracked.txt
    git add tracked.txt
    git commit -qm init

    helper="'"$BATS_TEST_DIRNAME"'/../skills/kramme:code:optimize/scripts/experiment-worktree.sh"
    worktree_path=$("$helper" create safe-spec 1 HEAD)

    test -d "$worktree_path"
    git show-ref --verify --quiet refs/heads/optimize-exp/safe-spec/exp-001

    "$helper" cleanup safe-spec 1

    test ! -e "$worktree_path"
    ! git show-ref --verify --quiet refs/heads/optimize-exp/safe-spec/exp-001
  '

	[ "$status" -eq 0 ]
}

@test "code optimize worktree cleanup-all removes only registered matching experiments" {
	run bash -c '
    set -euo pipefail
    repo="$BATS_TEST_TMPDIR/optimize-cleanup-all-repo"
    mkdir -p "$repo"
    cd "$repo"
    git init -q
    git config user.email "test@example.com"
    git config user.name "Test User"
    touch tracked.txt
    git add tracked.txt
    git commit -qm init

    helper="'"$BATS_TEST_DIRNAME"'/../skills/kramme:code:optimize/scripts/experiment-worktree.sh"
    first_path=$("$helper" create safe-spec 1 HEAD)
    second_path=$("$helper" create safe-spec 2 HEAD)
    other_path=$("$helper" create other-spec 1 HEAD)
    unregistered_path="$repo/.worktrees/optimize-safe-spec-exp-999"
    mkdir -p "$unregistered_path"

    "$helper" cleanup-all safe-spec

    test ! -e "$first_path"
    test ! -e "$second_path"
    test -d "$other_path"
    test -d "$unregistered_path"
    ! git show-ref --verify --quiet refs/heads/optimize-exp/safe-spec/exp-001
    ! git show-ref --verify --quiet refs/heads/optimize-exp/safe-spec/exp-002
    git show-ref --verify --quiet refs/heads/optimize-exp/other-spec/exp-001
  '

	[ "$status" -eq 0 ]
}

@test "code optimize worktree cleanup fails closed when git removal fails" {
	run bash -c '
    set -euo pipefail
    repo="$BATS_TEST_TMPDIR/optimize-cleanup-remove-failure-repo"
    mkdir -p "$repo"
    cd "$repo"
    git init -q
    git config user.email "test@example.com"
    git config user.name "Test User"
    touch tracked.txt
    git add tracked.txt
    git commit -qm init

    helper="'"$BATS_TEST_DIRNAME"'/../skills/kramme:code:optimize/scripts/experiment-worktree.sh"
    worktree_path=$("$helper" create safe-spec 1 HEAD)
    git worktree lock "$worktree_path"

    if "$helper" cleanup safe-spec 1; then
      echo "expected cleanup to fail for locked worktree"
      exit 1
    fi

    test -d "$worktree_path"
    git show-ref --verify --quiet refs/heads/optimize-exp/safe-spec/exp-001
  '

	[ "$status" -eq 0 ]
}
