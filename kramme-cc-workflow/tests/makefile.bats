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

  for tool in python3 shellcheck ruff mypy bats jq node npm; do
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
  local repo_name="${1:-makefile-contract}"
  MAKEFILE_CONTRACT_REPO="$BATS_TEST_TMPDIR/$repo_name"
  MAKEFILE_CONTRACT_BIN="$MAKEFILE_CONTRACT_REPO/bin"
  mkdir -p \
    "$MAKEFILE_CONTRACT_REPO/.agents/skills" \
    "$MAKEFILE_CONTRACT_REPO/plugin/config" \
    "$MAKEFILE_CONTRACT_REPO/plugin/evals" \
    "$MAKEFILE_CONTRACT_REPO/plugin/hooks" \
    "$MAKEFILE_CONTRACT_REPO/plugin/scripts" \
    "$MAKEFILE_CONTRACT_REPO/plugin/skills" \
    "$MAKEFILE_CONTRACT_REPO/plugin/tests" \
    "$MAKEFILE_CONTRACT_BIN"
  cp "$BATS_TEST_DIRNAME/../Makefile" "$MAKEFILE_CONTRACT_REPO/plugin/Makefile"

  cat >"$MAKEFILE_CONTRACT_REPO/plugin/config/coverage-production-sources.json" <<'JSON'
{
  "javascript": {
    "measured": [
      "plugin/scripts/example.js"
    ],
    "contract_only": {}
  },
  "python": {
    "measured": [
      "plugin/hooks/example.py"
    ],
    "contract_only": {}
  },
  "shell": {
    "contract_only": {
      "plugin/hooks/example.sh": [
        "plugin/tests/example.bats"
      ]
    }
  }
}
JSON
  printf '"use strict";\n' >"$MAKEFILE_CONTRACT_REPO/plugin/scripts/example.js"
  printf 'VALUE = 1\n' >"$MAKEFILE_CONTRACT_REPO/plugin/hooks/example.py"
  printf '#!/bin/sh\nexit 0\n' >"$MAKEFILE_CONTRACT_REPO/plugin/hooks/example.sh"
  printf '%s\n' \
    '#!/usr/bin/env bats' \
    '' \
    '@test "example shell contract" {' \
    '  true' \
    '}' \
    >"$MAKEFILE_CONTRACT_REPO/plugin/tests/example.bats"
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

write_fake_python_coverage_report() {
  local percent="$1"
  printf '100 %s%% hooks.example (%s/plugin/hooks/example.py)\n' \
    "$percent" \
    "$MAKEFILE_CONTRACT_REPO" \
    >"$MAKEFILE_CONTRACT_REPO/python-coverage.txt"
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

@test "check-deps requires mypy" {
  setup_check_deps_repo
  rm "$CHECK_DEPS_BIN/mypy"

  run env PATH="$CHECK_DEPS_BIN:/usr/bin:/bin" make -C "$CHECK_DEPS_REPO/kramme-cc-workflow" --no-print-directory check-deps SKILLSPECTOR_BASE=main

  [ "$status" -eq 2 ]
  [[ "$output" == *"mypy not found. Install development dependencies from requirements-dev.txt before running lint or verify."* ]]
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
  cat >"$MAKEFILE_CONTRACT_REPO/node-coverage.txt" <<'REPORT'
ℹ scripts          |       |       |       |
ℹ  example.js      | 80.00 | 70.00 | 80.00 |
ℹ all files        | 80.00 | 70.00 | 80.00 |
REPORT

  run env PATH="$MAKEFILE_CONTRACT_BIN:/usr/bin:/bin" NODE_COVERAGE_FIXTURE="$MAKEFILE_CONTRACT_REPO/node-coverage.txt" make -C "$MAKEFILE_CONTRACT_REPO/plugin" --no-print-directory coverage-node

  [ "$status" -eq 0 ]
}

@test "coverage-node accepts Node 20 TAP rows and ignores test files" {
  setup_makefile_contract_repo
  create_fake_node_coverage_tool
  cat >"$MAKEFILE_CONTRACT_REPO/node-coverage.txt" <<'REPORT'
# file                         | line % | branch % | funcs % |
# scripts/example.js           |  80.00 |    70.00 |   80.00 |
# tests/node/example.test.js   | 100.00 |   100.00 |  100.00 |
# all files                    |  80.00 |    70.00 |   80.00 |
REPORT

  run env PATH="$MAKEFILE_CONTRACT_BIN:/usr/bin:/bin" NODE_COVERAGE_FIXTURE="$MAKEFILE_CONTRACT_REPO/node-coverage.txt" make -C "$MAKEFILE_CONTRACT_REPO/plugin" --no-print-directory coverage-node

  [ "$status" -eq 0 ]
}

@test "coverage-node rejects values below a baseline" {
  setup_makefile_contract_repo
  create_fake_node_coverage_tool
  cat >"$MAKEFILE_CONTRACT_REPO/node-coverage.txt" <<'REPORT'
ℹ scripts          |       |       |       |
ℹ  example.js      | 79.99 | 70.00 | 80.00 |
ℹ all files        | 79.99 | 70.00 | 80.00 |
REPORT

  run env PATH="$MAKEFILE_CONTRACT_BIN:/usr/bin:/bin" NODE_COVERAGE_FIXTURE="$MAKEFILE_CONTRACT_REPO/node-coverage.txt" make -C "$MAKEFILE_CONTRACT_REPO/plugin" --no-print-directory coverage-node

  [ "$status" -ne 0 ]
  [[ "$output" == *"Node coverage below baseline"* ]]
}

@test "coverage-node rejects an inventoried production file absent from the report" {
  setup_makefile_contract_repo
  create_fake_node_coverage_tool
  printf '"use strict";\n' >"$MAKEFILE_CONTRACT_REPO/plugin/scripts/unloaded.js"
  jq '.javascript.measured += ["plugin/scripts/unloaded.js"]' \
    "$MAKEFILE_CONTRACT_REPO/plugin/config/coverage-production-sources.json" \
    >"$MAKEFILE_CONTRACT_REPO/inventory.json"
  mv "$MAKEFILE_CONTRACT_REPO/inventory.json" \
    "$MAKEFILE_CONTRACT_REPO/plugin/config/coverage-production-sources.json"
  cat >"$MAKEFILE_CONTRACT_REPO/node-coverage.txt" <<'REPORT'
ℹ scripts          |       |       |       |
ℹ  example.js      | 80.00 | 70.00 | 80.00 |
ℹ all files        | 80.00 | 70.00 | 80.00 |
REPORT

  run env PATH="$MAKEFILE_CONTRACT_BIN:/usr/bin:/bin" NODE_COVERAGE_FIXTURE="$MAKEFILE_CONTRACT_REPO/node-coverage.txt" make -C "$MAKEFILE_CONTRACT_REPO/plugin" --no-print-directory coverage-node

  [ "$status" -ne 0 ]
  [[ "$output" == *"Node coverage missing inventory files (1): plugin/scripts/unloaded.js"* ]]
}

@test "coverage-node accepts a registered contract-only file in the report" {
  setup_makefile_contract_repo
  create_fake_node_coverage_tool
  printf '"use strict";\n' >"$MAKEFILE_CONTRACT_REPO/plugin/scripts/contract.js"
  jq '.javascript.contract_only["plugin/scripts/contract.js"] = ["plugin/tests/example.bats"]' \
    "$MAKEFILE_CONTRACT_REPO/plugin/config/coverage-production-sources.json" \
    >"$MAKEFILE_CONTRACT_REPO/inventory.json"
  mv "$MAKEFILE_CONTRACT_REPO/inventory.json" \
    "$MAKEFILE_CONTRACT_REPO/plugin/config/coverage-production-sources.json"
  cat >"$MAKEFILE_CONTRACT_REPO/node-coverage.txt" <<'REPORT'
ℹ scripts          |       |       |       |
ℹ  contract.js     | 80.00 | 70.00 | 80.00 |
ℹ  example.js      | 80.00 | 70.00 | 80.00 |
ℹ all files        | 80.00 | 70.00 | 80.00 |
REPORT

  run env PATH="$MAKEFILE_CONTRACT_BIN:/usr/bin:/bin" NODE_COVERAGE_FIXTURE="$MAKEFILE_CONTRACT_REPO/node-coverage.txt" make -C "$MAKEFILE_CONTRACT_REPO/plugin" --no-print-directory coverage-node

  [ "$status" -eq 0 ]
}

@test "coverage-node rejects an unregistered production file in the report" {
  setup_makefile_contract_repo
  create_fake_node_coverage_tool
  printf '"use strict";\n' >"$MAKEFILE_CONTRACT_REPO/plugin/scripts/unregistered.js"
  cat >"$MAKEFILE_CONTRACT_REPO/node-coverage.txt" <<'REPORT'
ℹ scripts          |       |       |       |
ℹ  example.js      | 80.00 | 70.00 | 80.00 |
ℹ  unregistered.js | 80.00 | 70.00 | 80.00 |
ℹ all files        | 80.00 | 70.00 | 80.00 |
REPORT

  run env PATH="$MAKEFILE_CONTRACT_BIN:/usr/bin:/bin" NODE_COVERAGE_FIXTURE="$MAKEFILE_CONTRACT_REPO/node-coverage.txt" make -C "$MAKEFILE_CONTRACT_REPO/plugin" --no-print-directory coverage-node

  [ "$status" -ne 0 ]
  [[ "$output" == *"Node coverage report has unregistered production files (1): plugin/scripts/unregistered.js"* ]]
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
  write_fake_python_coverage_report 35

  run env PATH="$MAKEFILE_CONTRACT_BIN:/usr/bin:/bin" PYTHON_COVERAGE_FIXTURE="$MAKEFILE_CONTRACT_REPO/python-coverage.txt" make -C "$MAKEFILE_CONTRACT_REPO/plugin" --no-print-directory coverage-python

  [ "$status" -eq 0 ]
  [[ "$output" == *"Python production aggregate: 35.00%"* ]]
}

@test "coverage-python rejects values below the baseline" {
  setup_makefile_contract_repo
  create_fake_python_coverage_tool
  write_fake_python_coverage_report 34

  run env PATH="$MAKEFILE_CONTRACT_BIN:/usr/bin:/bin" PYTHON_COVERAGE_FIXTURE="$MAKEFILE_CONTRACT_REPO/python-coverage.txt" make -C "$MAKEFILE_CONTRACT_REPO/plugin" --no-print-directory coverage-python

  [ "$status" -ne 0 ]
  [[ "$output" == *"Python coverage below baseline"* ]]
}

@test "coverage-python rejects an inventoried production file absent from the report" {
  setup_makefile_contract_repo
  create_fake_python_coverage_tool
  printf 'VALUE = 2\n' >"$MAKEFILE_CONTRACT_REPO/plugin/hooks/unloaded.py"
  jq '.python.measured += ["plugin/hooks/unloaded.py"]' \
    "$MAKEFILE_CONTRACT_REPO/plugin/config/coverage-production-sources.json" \
    >"$MAKEFILE_CONTRACT_REPO/inventory.json"
  mv "$MAKEFILE_CONTRACT_REPO/inventory.json" \
    "$MAKEFILE_CONTRACT_REPO/plugin/config/coverage-production-sources.json"
  write_fake_python_coverage_report 35

  run env PATH="$MAKEFILE_CONTRACT_BIN:/usr/bin:/bin" PYTHON_COVERAGE_FIXTURE="$MAKEFILE_CONTRACT_REPO/python-coverage.txt" make -C "$MAKEFILE_CONTRACT_REPO/plugin" --no-print-directory coverage-python

  [ "$status" -ne 0 ]
  [[ "$output" == *"Python coverage missing inventory files (1): plugin/hooks/unloaded.py"* ]]
}

@test "coverage-python accepts a registered contract-only file in the report" {
  setup_makefile_contract_repo
  create_fake_python_coverage_tool
  printf 'VALUE = 2\n' >"$MAKEFILE_CONTRACT_REPO/plugin/hooks/contract.py"
  jq '.python.contract_only["plugin/hooks/contract.py"] = ["plugin/tests/example.bats"]' \
    "$MAKEFILE_CONTRACT_REPO/plugin/config/coverage-production-sources.json" \
    >"$MAKEFILE_CONTRACT_REPO/inventory.json"
  mv "$MAKEFILE_CONTRACT_REPO/inventory.json" \
    "$MAKEFILE_CONTRACT_REPO/plugin/config/coverage-production-sources.json"
  printf '100 35%% hooks.example (%s/plugin/hooks/example.py)\n100 100%% hooks.contract (%s/plugin/hooks/contract.py)\n' \
    "$MAKEFILE_CONTRACT_REPO" \
    "$MAKEFILE_CONTRACT_REPO" \
    >"$MAKEFILE_CONTRACT_REPO/python-coverage.txt"

  run env PATH="$MAKEFILE_CONTRACT_BIN:/usr/bin:/bin" PYTHON_COVERAGE_FIXTURE="$MAKEFILE_CONTRACT_REPO/python-coverage.txt" make -C "$MAKEFILE_CONTRACT_REPO/plugin" --no-print-directory coverage-python

  [ "$status" -eq 0 ]
  [[ "$output" == *"Python production aggregate: 35.00%"* ]]
}

@test "coverage-python rejects an unregistered production file in the report" {
  setup_makefile_contract_repo
  create_fake_python_coverage_tool
  printf 'VALUE = 2\n' >"$MAKEFILE_CONTRACT_REPO/plugin/hooks/unregistered.py"
  write_fake_python_coverage_report 35
  printf '100 100%% hooks.unregistered (%s/plugin/hooks/unregistered.py)\n' \
    "$MAKEFILE_CONTRACT_REPO" \
    >>"$MAKEFILE_CONTRACT_REPO/python-coverage.txt"

  run env PATH="$MAKEFILE_CONTRACT_BIN:/usr/bin:/bin" PYTHON_COVERAGE_FIXTURE="$MAKEFILE_CONTRACT_REPO/python-coverage.txt" make -C "$MAKEFILE_CONTRACT_REPO/plugin" --no-print-directory coverage-python

  [ "$status" -ne 0 ]
  [[ "$output" == *"Python coverage report has unregistered production files (1): plugin/hooks/unregistered.py"* ]]
}

@test "coverage-python accepts a checkout path containing spaces" {
  setup_makefile_contract_repo "makefile contract"
  create_fake_python_coverage_tool
  write_fake_python_coverage_report 35

  run env PATH="$MAKEFILE_CONTRACT_BIN:/usr/bin:/bin" PYTHON_COVERAGE_FIXTURE="$MAKEFILE_CONTRACT_REPO/python-coverage.txt" make -C "$MAKEFILE_CONTRACT_REPO/plugin" --no-print-directory coverage-python

  [ "$status" -eq 0 ]
  [[ "$output" == *"Python production aggregate: 35.00%"* ]]
}

@test "coverage-python rejects a missing production summary" {
  setup_makefile_contract_repo
  create_fake_python_coverage_tool
  printf 'no production rows\n' >"$MAKEFILE_CONTRACT_REPO/python-coverage.txt"

  run env PATH="$MAKEFILE_CONTRACT_BIN:/usr/bin:/bin" PYTHON_COVERAGE_FIXTURE="$MAKEFILE_CONTRACT_REPO/python-coverage.txt" make -C "$MAKEFILE_CONTRACT_REPO/plugin" --no-print-directory coverage-python

  [ "$status" -ne 0 ]
  [[ "$output" == *"Python production coverage summary not found"* ]]
}

@test "coverage-bats-contract accepts a complete shell source mapping" {
  setup_makefile_contract_repo

  run env PATH="$MAKEFILE_CONTRACT_BIN:/usr/bin:/bin" make -C "$MAKEFILE_CONTRACT_REPO/plugin" --no-print-directory coverage-bats-contract

  [ "$status" -eq 0 ]
  [[ "$output" == *"Shell source-to-contract inventory proxy: 1 production file mapped"* ]]
  [[ "$output" == *"not measured execution coverage"* ]]
}

@test "coverage-bats-contract rejects a mapped Bats file outside the discovered suite" {
  setup_makefile_contract_repo
  mkdir -p "$MAKEFILE_CONTRACT_REPO/plugin/tests/nested"
  mv \
    "$MAKEFILE_CONTRACT_REPO/plugin/tests/example.bats" \
    "$MAKEFILE_CONTRACT_REPO/plugin/tests/nested/example.bats"
  jq '.shell.contract_only["plugin/hooks/example.sh"] = ["plugin/tests/nested/example.bats"]' \
    "$MAKEFILE_CONTRACT_REPO/plugin/config/coverage-production-sources.json" \
    >"$MAKEFILE_CONTRACT_REPO/inventory.json"
  mv "$MAKEFILE_CONTRACT_REPO/inventory.json" \
    "$MAKEFILE_CONTRACT_REPO/plugin/config/coverage-production-sources.json"

  run env PATH="$MAKEFILE_CONTRACT_BIN:/usr/bin:/bin" make -C "$MAKEFILE_CONTRACT_REPO/plugin" --no-print-directory coverage-bats-contract

  [ "$status" -ne 0 ]
  [[ "$output" == *"Production contract is not discovered by tests/run-tests.sh: plugin/tests/nested/example.bats"* ]]
}

@test "coverage-bats-contract rejects an unmapped production shell file" {
  setup_makefile_contract_repo
  printf '#!/bin/sh\nexit 0\n' >"$MAKEFILE_CONTRACT_REPO/plugin/scripts/unmapped.sh"

  run env PATH="$MAKEFILE_CONTRACT_BIN:/usr/bin:/bin" make -C "$MAKEFILE_CONTRACT_REPO/plugin" --no-print-directory coverage-bats-contract

  [ "$status" -ne 0 ]
  [[ "$output" == *"Shell production files missing inventory entries (1): plugin/scripts/unmapped.sh"* ]]
}

@test "coverage-bats-contract rejects malformed production inventory" {
  setup_makefile_contract_repo
  printf '{\n' >"$MAKEFILE_CONTRACT_REPO/plugin/config/coverage-production-sources.json"

  run env PATH="$MAKEFILE_CONTRACT_BIN:/usr/bin:/bin" make -C "$MAKEFILE_CONTRACT_REPO/plugin" --no-print-directory coverage-bats-contract

  [ "$status" -ne 0 ]
  [[ "$output" == *"Production coverage inventory is malformed"* ]]
}
