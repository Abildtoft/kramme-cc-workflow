#!/usr/bin/env bats

create_fake_tool() {
  local path="$1"
  mkdir -p "$(dirname "$path")"
  cat >"$path" <<'SH'
#!/bin/sh
exit 0
SH
  chmod +x "$path"
}

setup_check_deps_repo() {
  CHECK_DEPS_REPO="$BATS_TEST_TMPDIR/repo"
  CHECK_DEPS_BIN="$BATS_TEST_TMPDIR/bin"
  mkdir -p \
    "$CHECK_DEPS_REPO/kramme-cc-workflow/skills/kramme:test" \
    "$CHECK_DEPS_REPO/node_modules/.bin" \
    "$CHECK_DEPS_BIN"
  cp "$BATS_TEST_DIRNAME/../Makefile" "$CHECK_DEPS_REPO/kramme-cc-workflow/Makefile"

  for tool in python3 shellcheck ruff bats jq node npm; do
    create_fake_tool "$CHECK_DEPS_BIN/$tool"
  done
  create_fake_tool "$CHECK_DEPS_REPO/node_modules/.bin/prettier"
  create_fake_tool "$CHECK_DEPS_REPO/node_modules/.bin/tsc"

  cat >"$CHECK_DEPS_REPO/kramme-cc-workflow/skills/kramme:test/SKILL.md" <<'MD'
---
name: kramme:test
description: Test skill
---
MD

  git -C "$CHECK_DEPS_REPO" init >/dev/null
  git -C "$CHECK_DEPS_REPO" config user.email "test@example.com"
  git -C "$CHECK_DEPS_REPO" config user.name "Test User"
  git -C "$CHECK_DEPS_REPO" add .
  git -C "$CHECK_DEPS_REPO" commit -m "initial" >/dev/null
  git -C "$CHECK_DEPS_REPO" branch -M main
  git -C "$CHECK_DEPS_REPO" switch -c feature >/dev/null
}

setup_makefile_contract_repo() {
  MAKEFILE_CONTRACT_REPO="$BATS_TEST_TMPDIR/makefile-contract"
  MAKEFILE_CONTRACT_BIN="$MAKEFILE_CONTRACT_REPO/bin"
  mkdir -p "$MAKEFILE_CONTRACT_REPO/plugin" "$MAKEFILE_CONTRACT_BIN"
  cp "$BATS_TEST_DIRNAME/../Makefile" "$MAKEFILE_CONTRACT_REPO/plugin/Makefile"
}

create_fake_node_coverage_tool() {
  cat >"$MAKEFILE_CONTRACT_BIN/node" <<'SH'
#!/bin/sh
cat "$NODE_COVERAGE_FIXTURE"
SH
  chmod +x "$MAKEFILE_CONTRACT_BIN/node"
}

create_fake_python_coverage_tool() {
  cat >"$MAKEFILE_CONTRACT_BIN/python3" <<'SH'
#!/bin/sh
case "$*" in
  *--summary*) cat "$PYTHON_COVERAGE_FIXTURE" ;;
esac
exit 0
SH
  chmod +x "$MAKEFILE_CONTRACT_BIN/python3"
}

@test "format dependency check accepts PRETTIER command from PATH" {
  BIN_DIR="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$BIN_DIR"
  create_fake_tool "$BIN_DIR/prettier"

  run env PATH="$BIN_DIR:$PATH" make -C "$BATS_TEST_DIRNAME/.." --no-print-directory check-format-deps PRETTIER=prettier

  [ "$status" -eq 0 ]
}

@test "check-deps does not require skillspector without changed skill directories" {
  setup_check_deps_repo

  run env PATH="$CHECK_DEPS_BIN:/usr/bin:/bin" make -C "$CHECK_DEPS_REPO/kramme-cc-workflow" --no-print-directory check-deps SKILLSPECTOR_BASE=main

  [ "$status" -eq 0 ]
  [[ "$output" == *"All verification dependencies installed."* ]]
}

@test "check-deps requires skillspector when a skill directory changed" {
  setup_check_deps_repo
  printf '\nChanged.\n' >>"$CHECK_DEPS_REPO/kramme-cc-workflow/skills/kramme:test/SKILL.md"

  run env PATH="$CHECK_DEPS_BIN:/usr/bin:/bin" make -C "$CHECK_DEPS_REPO/kramme-cc-workflow" --no-print-directory check-deps SKILLSPECTOR_BASE=main

  [ "$status" -eq 2 ]
  [[ "$output" == *"skillspector not found. Install SkillSpector before running skill-security or verify."* ]]
}

@test "test-python discovers repository and maintenance tests" {
  run make -C "$BATS_TEST_DIRNAME/.." --no-print-directory --dry-run test-python

  [ "$status" -eq 0 ]
  [[ "$output" == *"unittest discover -s tests/python -p 'test_*.py'"* ]]
  [[ "$output" == *"unittest discover -s ../.agents/skills/kramme:skill:audit-sources/scripts -p 'test_*.py'"* ]]
}

@test "test-smoke covers representative Node Python and Bats contracts" {
  run make -C "$BATS_TEST_DIRNAME/.." --no-print-directory --dry-run test-smoke

  [ "$status" -eq 0 ]
  [[ "$output" == *"node --test tests/node/frontmatter.test.js tests/node/scorer.test.js"* ]]
  [[ "$output" == *"python3 -m unittest tests/python/test_git_command_parser.py"* ]]
  [[ "$output" == *"bats tests/linear-issue-implement-guidance.bats"* ]]
}

@test "test-node-file requires NODE_TEST_FILE" {
  run make -C "$BATS_TEST_DIRNAME/.." --no-print-directory test-node-file

  [ "$status" -eq 2 ]
  [[ "$output" == *"NODE_TEST_FILE is required"* ]]
}

@test "test-node-file forwards a path as one argument" {
  setup_makefile_contract_repo
  cat >"$MAKEFILE_CONTRACT_BIN/node" <<'SH'
#!/bin/sh
printf 'argc=%s\narg1=%s\narg2=%s\n' "$#" "$1" "$2"
SH
  chmod +x "$MAKEFILE_CONTRACT_BIN/node"

  run env PATH="$MAKEFILE_CONTRACT_BIN:/usr/bin:/bin" make -C "$MAKEFILE_CONTRACT_REPO/plugin" --no-print-directory test-node-file NODE_TEST_FILE="tests/node/path with spaces.test.js"

  [ "$status" -eq 0 ]
  [[ "$output" == *"argc=2"* ]]
  [[ "$output" == *"arg1=--test"* ]]
  [[ "$output" == *"arg2=tests/node/path with spaces.test.js"* ]]
}

@test "coverage-node accepts values exactly at the baselines" {
  setup_makefile_contract_repo
  create_fake_node_coverage_tool
  printf 'all files | 80.00 | 70.00 | 80.00 |\n' >"$MAKEFILE_CONTRACT_REPO/node-coverage.txt"

  run env PATH="$MAKEFILE_CONTRACT_BIN:/usr/bin:/bin" NODE_COVERAGE_FIXTURE="$MAKEFILE_CONTRACT_REPO/node-coverage.txt" make -C "$MAKEFILE_CONTRACT_REPO/plugin" --no-print-directory coverage-node

  [ "$status" -eq 0 ]
}

@test "coverage-node rejects values below a baseline" {
  setup_makefile_contract_repo
  create_fake_node_coverage_tool
  printf 'all files | 79.99 | 70.00 | 80.00 |\n' >"$MAKEFILE_CONTRACT_REPO/node-coverage.txt"

  run env PATH="$MAKEFILE_CONTRACT_BIN:/usr/bin:/bin" NODE_COVERAGE_FIXTURE="$MAKEFILE_CONTRACT_REPO/node-coverage.txt" make -C "$MAKEFILE_CONTRACT_REPO/plugin" --no-print-directory coverage-node

  [ "$status" -ne 0 ]
  [[ "$output" == *"Node coverage below baseline"* ]]
}

@test "coverage-node rejects a missing summary" {
  setup_makefile_contract_repo
  create_fake_node_coverage_tool
  printf 'no coverage rows\n' >"$MAKEFILE_CONTRACT_REPO/node-coverage.txt"

  run env PATH="$MAKEFILE_CONTRACT_BIN:/usr/bin:/bin" NODE_COVERAGE_FIXTURE="$MAKEFILE_CONTRACT_REPO/node-coverage.txt" make -C "$MAKEFILE_CONTRACT_REPO/plugin" --no-print-directory coverage-node

  [ "$status" -ne 0 ]
  [[ "$output" == *"Node coverage summary not found"* ]]
}

@test "coverage-python accepts values exactly at the baseline" {
  setup_makefile_contract_repo
  create_fake_python_coverage_tool
  printf '100 35%% hooks/example.py\n' >"$MAKEFILE_CONTRACT_REPO/python-coverage.txt"

  run env PATH="$MAKEFILE_CONTRACT_BIN:/usr/bin:/bin" PYTHON_COVERAGE_FIXTURE="$MAKEFILE_CONTRACT_REPO/python-coverage.txt" make -C "$MAKEFILE_CONTRACT_REPO/plugin" --no-print-directory coverage-python

  [ "$status" -eq 0 ]
  [[ "$output" == *"Python production aggregate: 35.00%"* ]]
}

@test "coverage-python rejects values below the baseline" {
  setup_makefile_contract_repo
  create_fake_python_coverage_tool
  printf '100 34%% hooks/example.py\n' >"$MAKEFILE_CONTRACT_REPO/python-coverage.txt"

  run env PATH="$MAKEFILE_CONTRACT_BIN:/usr/bin:/bin" PYTHON_COVERAGE_FIXTURE="$MAKEFILE_CONTRACT_REPO/python-coverage.txt" make -C "$MAKEFILE_CONTRACT_REPO/plugin" --no-print-directory coverage-python

  [ "$status" -ne 0 ]
  [[ "$output" == *"Python coverage below baseline"* ]]
}

@test "coverage-python rejects a missing production summary" {
  setup_makefile_contract_repo
  create_fake_python_coverage_tool
  printf 'no production rows\n' >"$MAKEFILE_CONTRACT_REPO/python-coverage.txt"

  run env PATH="$MAKEFILE_CONTRACT_BIN:/usr/bin:/bin" PYTHON_COVERAGE_FIXTURE="$MAKEFILE_CONTRACT_REPO/python-coverage.txt" make -C "$MAKEFILE_CONTRACT_REPO/plugin" --no-print-directory coverage-python

  [ "$status" -ne 0 ]
  [[ "$output" == *"Python production coverage summary not found"* ]]
}
