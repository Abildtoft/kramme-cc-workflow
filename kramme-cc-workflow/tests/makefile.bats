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
  cp "$BATS_TEST_DIRNAME/../mypy.ini" "$MAKEFILE_CONTRACT_REPO/plugin/mypy.ini"

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
    "contract_only": {
      "plugin/scripts/contract.py": [
        "plugin/tests/example.bats"
      ]
    }
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
  printf 'VALUE = 2\n' >"$MAKEFILE_CONTRACT_REPO/plugin/scripts/contract.py"
  printf '#!/bin/sh\nexit 0\n' >"$MAKEFILE_CONTRACT_REPO/plugin/hooks/example.sh"
  printf '%s\n' \
    '#!/usr/bin/env bats' \
    '' \
    '@test "example shell contract" {' \
    '  true' \
    '}' \
    >"$MAKEFILE_CONTRACT_REPO/plugin/tests/example.bats"
}

update_fake_inventory() {
  local filter="$1"
  jq "$filter" \
    "$MAKEFILE_CONTRACT_REPO/plugin/config/coverage-production-sources.json" \
    >"$MAKEFILE_CONTRACT_REPO/inventory.json"
  mv "$MAKEFILE_CONTRACT_REPO/inventory.json" \
    "$MAKEFILE_CONTRACT_REPO/plugin/config/coverage-production-sources.json"
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

append_fake_python_coverage_row() {
  local module="$1"
  local relative_path="$2"
  local percent="$3"
  printf '100 %s%% %s (%s/%s)\n' \
    "$percent" \
    "$module" \
    "$MAKEFILE_CONTRACT_REPO" \
    "$relative_path" \
    >>"$MAKEFILE_CONTRACT_REPO/python-coverage.txt"
}

# Registers a second measured module so per-file floor cases can keep the
# aggregate baseline satisfied while one file sits below its floor.
add_low_coverage_python_module() {
  local percent="$1"
  printf 'VALUE = 3\n' >"$MAKEFILE_CONTRACT_REPO/plugin/hooks/low.py"
  update_fake_inventory '.python.measured += ["plugin/hooks/low.py"]'
  write_fake_python_coverage_report 100
  append_fake_python_coverage_row "hooks.low" "plugin/hooks/low.py" "$percent"
}

@test "format dependency check accepts PRETTIER command from PATH" {
  BIN_DIR="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$BIN_DIR"
  create_fake_tool "$BIN_DIR/prettier"

  run env PATH="$BIN_DIR:$PATH" make -C "$BATS_TEST_DIRNAME/.." --no-print-directory check-format-deps PRETTIER=prettier

  [ "$status" -eq 0 ]
}

@test "format-check sends changed Python files to Ruff and propagates failures" {
  setup_check_deps_repo
  mkdir -p "$CHECK_DEPS_REPO/kramme-cc-workflow/scripts"
  printf 'VALUE = 0\n' >"$CHECK_DEPS_REPO/kramme-cc-workflow/scripts/modified.py"
  git -C "$CHECK_DEPS_REPO" add .
  git -C "$CHECK_DEPS_REPO" commit -m "add base Python source" >/dev/null
  git -C "$CHECK_DEPS_REPO" branch -f main HEAD
  printf 'VALUE = 1\n' >"$CHECK_DEPS_REPO/kramme-cc-workflow/scripts/committed.py"
  git -C "$CHECK_DEPS_REPO" add .
  git -C "$CHECK_DEPS_REPO" commit -m "add Python source" >/dev/null
  printf 'VALUE = 2\n' >"$CHECK_DEPS_REPO/kramme-cc-workflow/scripts/modified.py"
  printf 'VALUE = 2\n' >"$CHECK_DEPS_REPO/kramme-cc-workflow/scripts/untracked.py"
  cat >"$CHECK_DEPS_BIN/ruff" <<'SH'
#!/bin/sh
printf 'ruff-args=%s\n' "$*"
exit "${RUFF_EXIT_STATUS:-0}"
SH
  chmod +x "$CHECK_DEPS_BIN/ruff"

  run env PATH="$CHECK_DEPS_BIN:/usr/bin:/bin" make -C "$CHECK_DEPS_REPO/kramme-cc-workflow" --no-print-directory format-check FORMAT_BASE=main RUFF=ruff

  [ "$status" -eq 0 ]
  [[ "$output" == *"ruff-args=format --check --config"*"kramme-cc-workflow/scripts/committed.py"* ]]
  [[ "$output" == *"kramme-cc-workflow/scripts/modified.py"* ]]
  [[ "$output" == *"kramme-cc-workflow/scripts/untracked.py"* ]]

  run env PATH="$CHECK_DEPS_BIN:/usr/bin:/bin" RUFF_EXIT_STATUS=7 make -C "$CHECK_DEPS_REPO/kramme-cc-workflow" --no-print-directory format-check FORMAT_BASE=main RUFF=ruff

  [ "$status" -ne 0 ]
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

@test "check-deps only verifies dependencies" {
  run make -C "$BATS_TEST_DIRNAME/.." --no-print-directory --dry-run check-deps

  [ "$status" -eq 0 ]
  [[ "$output" == *"All verification dependencies installed."* ]]
  [[ "$output" != *"--severity="* ]]
  [[ "$output" != *"--experimental-test-coverage"* ]]
  [[ "$output" != *"run-skillspector.sh --changed"* ]]
}

@test "pr-verify runs every Pull Request gate class including coverage" {
  run make -C "$BATS_TEST_DIRNAME/.." --no-print-directory --dry-run pr-verify

  [ "$status" -eq 0 ]
  [[ "$output" == *"All verification dependencies installed."* ]]
  [[ "$output" == *"--severity="* ]]
  [[ "$output" == *"prettier"*"--check"* ]]
  [[ "$output" == *"lint-skill-contracts.py"* ]]
  [[ "$output" == *"run-skillspector.sh --changed"* ]]
  [[ "$output" == *"--experimental-test-coverage"* ]]
  [[ "$output" == *"trace --count"* ]]
  [[ "$output" == *"Bats contract inventory"* ]]
}

@test "verify adds the standalone skill-review eval to the pr-verify gates" {
  run make -C "$BATS_TEST_DIRNAME/.." --no-print-directory --dry-run verify

  [ "$status" -eq 0 ]
  [[ "$output" == *"--experimental-test-coverage"* ]]
  [[ "$output" == *"evals/skill-review/run-eval.js --split all"* ]]
}

@test "npm aliases resolve to defined Makefile targets" {
  local makefile="$BATS_TEST_DIRNAME/../Makefile"
  local manifest
  local target
  local missing=""

  for manifest in "$BATS_TEST_DIRNAME/../../package.json" "$BATS_TEST_DIRNAME/../package.json"; do
    while IFS= read -r target; do
      grep -Eq "^$target:" "$makefile" || missing="$missing $manifest -> $target"
    done < <(jq -r '.scripts[] | select(test("(^| )make ")) | sub("^.*make (-C [^ ]+ )?"; "") | split(" ")[0]' "$manifest")
  done

  [ -z "$missing" ] || {
    echo "npm scripts without Makefile targets:$missing"
    return 1
  }
}

@test "lint-shell uses the local virtualenv from repository paths containing spaces" {
  setup_makefile_contract_repo "repo with spaces"
  mkdir -p "$MAKEFILE_CONTRACT_REPO/.venv/bin"
  cat >"$MAKEFILE_CONTRACT_REPO/.venv/bin/shellcheck" <<'SH'
#!/bin/sh
printf 'venv-shellcheck=%s\n' "$0"
exit 0
SH
  chmod +x "$MAKEFILE_CONTRACT_REPO/.venv/bin/shellcheck"

  run env PATH="/usr/bin:/bin" \
    make -C "$MAKEFILE_CONTRACT_REPO/plugin" --no-print-directory lint-shell

  [ "$status" -eq 0 ]
  [[ "$output" == *"repo with spaces/.venv/bin/shellcheck"* ]]
}

@test "test-python discovers repository and maintenance tests" {
  run make -C "$BATS_TEST_DIRNAME/.." --no-print-directory --dry-run test-python

  [ "$status" -eq 0 ]
  [[ "$output" == *"unittest discover -s tests/python -p 'test_*.py'"* ]]
  [[ "$output" == *"unittest discover -s ../.agents/skills/kramme:skill:audit-sources/scripts -p 'test_*.py'"* ]]
}

@test "Python static inventory accepts every registered production module" {
  setup_makefile_contract_repo

  run make -C "$MAKEFILE_CONTRACT_REPO/plugin" --no-print-directory check-python-static-inventory

  [ "$status" -eq 0 ]
  [[ "$output" == *"Python static inventory: 2 production files registered."* ]]
}

@test "Python static inventory is independent of the caller's collation locale" {
  setup_makefile_contract_repo
  update_fake_inventory '.python.measured += [
      "plugin/scripts/lint-skill-contracts.py",
      "plugin/scripts/lint_skill_contracts.py"
    ]'
  printf 'VALUE = 3\n' >"$MAKEFILE_CONTRACT_REPO/plugin/scripts/lint-skill-contracts.py"
  printf 'VALUE = 4\n' >"$MAKEFILE_CONTRACT_REPO/plugin/scripts/lint_skill_contracts.py"

  run env -u LC_ALL LANG=en_US.UTF-8 LC_COLLATE=en_US.UTF-8 \
    make -C "$MAKEFILE_CONTRACT_REPO/plugin" --no-print-directory check-python-static-inventory

  [ "$status" -eq 0 ]
  [[ "$output" == *"Python static inventory: 4 production files registered."* ]]
}

@test "Python static inventory rejects an unlisted production module" {
  setup_makefile_contract_repo
  printf 'VALUE = 2\n' >"$MAKEFILE_CONTRACT_REPO/plugin/hooks/unlisted.py"

  run make -C "$MAKEFILE_CONTRACT_REPO/plugin" --no-print-directory check-python-static-inventory

  [ "$status" -ne 0 ]
  [[ "$output" == *"Python production files missing static inventory entries (1): plugin/hooks/unlisted.py"* ]]
}

@test "Python static inventory rejects a registered module that is missing" {
  setup_makefile_contract_repo
  rm "$MAKEFILE_CONTRACT_REPO/plugin/scripts/contract.py"

  run make -C "$MAKEFILE_CONTRACT_REPO/plugin" --no-print-directory check-python-static-inventory

  [ "$status" -ne 0 ]
  [[ "$output" == *"Python static inventory entries missing production files (1): plugin/scripts/contract.py"* ]]
}

@test "Python static inventory rejects invalid data under optimized Python" {
  setup_makefile_contract_repo
  update_fake_inventory '.python.contract_only["plugin/hooks/example.py"] = .python.contract_only["plugin/scripts/contract.py"] |
      .python.measured = []'

  run env PYTHONOPTIMIZE=1 make -C "$MAKEFILE_CONTRACT_REPO/plugin" --no-print-directory check-python-static-inventory

  [ "$status" -ne 0 ]
  [[ "$output" == *"Python static inventory is malformed"* ]]
}

@test "typecheck-python checks the production inventory and reports scoped ratchets" {
  setup_makefile_contract_repo
  cat >"$MAKEFILE_CONTRACT_BIN/mypy" <<'SH'
#!/bin/sh
printf 'mypy-args=%s\n' "$*"
config_path=
while [ "$#" -gt 0 ]; do
  case "$1" in
    --config-file)
      config_path="$2"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done
python3 - "$config_path" <<'PY'
import configparser
import sys

config = configparser.ConfigParser()
config.read(sys.argv[1])
codes = {
    code.strip()
    for code in config["mypy-changelog"]["disable_error_code"].split(",")
}
assert codes == {"assignment"}
print("mypy-ratchet-syntax=valid")
PY
SH
  chmod +x "$MAKEFILE_CONTRACT_BIN/mypy"

  run env PATH="$MAKEFILE_CONTRACT_BIN:/usr/bin:/bin" make -C "$MAKEFILE_CONTRACT_REPO/plugin" --no-print-directory typecheck-python MYPY=mypy

  [ "$status" -eq 0 ]
  [[ "$output" == *"mypy ratchet exceptions (owner: repository maintainers):"*"changelog"* ]]
  [[ "$output" == *"mypy-args=--config-file plugin/mypy.ini plugin/hooks/example.py plugin/scripts/contract.py"* ]]
  [[ "$output" == *"mypy-ratchet-syntax=valid"* ]]
}

@test "typecheck-python validates the production inventory before mypy" {
  setup_makefile_contract_repo
  create_fake_tool "$MAKEFILE_CONTRACT_BIN/mypy"
  printf 'VALUE = 3\n' >"$MAKEFILE_CONTRACT_REPO/plugin/hooks/unlisted.py"

  run env PATH="$MAKEFILE_CONTRACT_BIN:/usr/bin:/bin" make -C "$MAKEFILE_CONTRACT_REPO/plugin" --no-print-directory typecheck-python MYPY=mypy

  [ "$status" -ne 0 ]
  [[ "$output" == *"Python production files missing static inventory entries (1): plugin/hooks/unlisted.py"* ]]
}

@test "test-smoke covers representative Node Python and Bats contracts" {
  run make -C "$BATS_TEST_DIRNAME/.." --no-print-directory --dry-run test-smoke

  [ "$status" -eq 0 ]
  [[ "$output" == *"node --test tests/node/frontmatter.test.js tests/node/scorer.test.js"* ]]
  [[ "$output" == *"python3 -m unittest tests/python/test_git_command_parser.py"* ]]
  [[ "$output" == *"bats tests/linear-issue-implement-guidance.bats"* ]]
}

@test "test-node-file requires NODE_TEST_FILE" {
  setup_makefile_contract_repo
  cat >"$MAKEFILE_CONTRACT_BIN/node" <<'SH'
#!/bin/sh
case "$1" in
  -e) exit 0 ;;
esac
exit 0
SH
  chmod +x "$MAKEFILE_CONTRACT_BIN/node"

  run env PATH="$MAKEFILE_CONTRACT_BIN:/usr/bin:/bin" make -C "$MAKEFILE_CONTRACT_REPO/plugin" --no-print-directory test-node-file

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

@test "test-python-file requires PYTHON_TEST_FILE" {
  run make -C "$BATS_TEST_DIRNAME/.." --no-print-directory test-python-file

  [ "$status" -eq 2 ]
  [[ "$output" == *"PYTHON_TEST_FILE is required"* ]]
}

@test "test-python-file forwards a path as one argument" {
  setup_makefile_contract_repo
  cat >"$MAKEFILE_CONTRACT_BIN/python3" <<'SH'
#!/bin/sh
printf 'argc=%s\narg1=%s\narg2=%s\narg3=%s\n' "$#" "$1" "$2" "$3"
SH
  chmod +x "$MAKEFILE_CONTRACT_BIN/python3"

  run env PATH="$MAKEFILE_CONTRACT_BIN:/usr/bin:/bin" make -C "$MAKEFILE_CONTRACT_REPO/plugin" --no-print-directory test-python-file PYTHON_TEST_FILE="tests/python/path with spaces.py"

  [ "$status" -eq 0 ]
  [[ "$output" == *"argc=3"* ]]
  [[ "$output" == *"arg1=-m"* ]]
  [[ "$output" == *"arg2=unittest"* ]]
  [[ "$output" == *"arg3=tests/python/path with spaces.py"* ]]
}

@test "test-bats-file requires BATS_TEST_FILE" {
  run make -C "$BATS_TEST_DIRNAME/.." --no-print-directory test-bats-file BATS_TEST_FILE=

  [ "$status" -eq 2 ]
  [[ "$output" == *"BATS_TEST_FILE is required"* ]]
}

@test "test-bats-file forwards a path as one argument" {
  setup_makefile_contract_repo
  mkdir -p "$MAKEFILE_CONTRACT_REPO/plugin/tests/test_helper/mocks"
  touch "$MAKEFILE_CONTRACT_REPO/plugin/tests/test_helper/mocks/git"
  create_fake_tool "$MAKEFILE_CONTRACT_BIN/jq"
  cat >"$MAKEFILE_CONTRACT_BIN/bats" <<'SH'
#!/bin/sh
printf 'argc=%s\narg1=%s\n' "$#" "$1"
SH
  chmod +x "$MAKEFILE_CONTRACT_BIN/bats"

  run env PATH="$MAKEFILE_CONTRACT_BIN:/usr/bin:/bin" make -C "$MAKEFILE_CONTRACT_REPO/plugin" --no-print-directory test-bats-file BATS_TEST_FILE="tests/path with spaces.bats"

  [ "$status" -eq 0 ]
  [[ "$output" == *"argc=1"* ]]
  [[ "$output" == *"arg1=tests/path with spaces.bats"* ]]
}

@test "test-convert composes Node contracts and the Bats CLI smoke" {
  run make -C "$BATS_TEST_DIRNAME/.." --no-print-directory --dry-run test-convert

  [ "$status" -eq 0 ]
  [[ "$output" == *"node --test tests/node/converter-core.test.js tests/node/converter-install.test.js tests/node/converter-output.test.js tests/node/converter-integration.test.js"* ]]
  [[ "$output" == *"bats tests/convert-plugin.bats"* ]]
}

@test "test-convert fails before the Bats smoke when Node contracts fail" {
  setup_makefile_contract_repo
  mkdir -p "$MAKEFILE_CONTRACT_REPO/plugin/tests/test_helper/mocks"
  touch "$MAKEFILE_CONTRACT_REPO/plugin/tests/test_helper/mocks/git"
  create_fake_tool "$MAKEFILE_CONTRACT_BIN/jq"
  cat >"$MAKEFILE_CONTRACT_BIN/node" <<'SH'
#!/bin/sh
case "$1" in
  -e) exit 0 ;;
  --test)
    echo "NODE_CONTRACT_FAILED"
    exit 1
    ;;
esac
exit 0
SH
  cat >"$MAKEFILE_CONTRACT_BIN/bats" <<'SH'
#!/bin/sh
echo "BATS_SMOKE_RAN"
exit 0
SH
  chmod +x "$MAKEFILE_CONTRACT_BIN/node" "$MAKEFILE_CONTRACT_BIN/bats"

  run env PATH="$MAKEFILE_CONTRACT_BIN:/usr/bin:/bin" make -C "$MAKEFILE_CONTRACT_REPO/plugin" --no-print-directory test-convert

  [ "$status" -ne 0 ]
  [[ "$output" == *"NODE_CONTRACT_FAILED"* ]]
  [[ "$output" != *"BATS_SMOKE_RAN"* ]]
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
  update_fake_inventory '.javascript.measured += ["plugin/scripts/unloaded.js"]'
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
  update_fake_inventory '.javascript.contract_only["plugin/scripts/contract.js"] = ["plugin/tests/example.bats"]'
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
  update_fake_inventory '.python.measured += ["plugin/hooks/unloaded.py"]'
  write_fake_python_coverage_report 35

  run env PATH="$MAKEFILE_CONTRACT_BIN:/usr/bin:/bin" PYTHON_COVERAGE_FIXTURE="$MAKEFILE_CONTRACT_REPO/python-coverage.txt" make -C "$MAKEFILE_CONTRACT_REPO/plugin" --no-print-directory coverage-python

  [ "$status" -ne 0 ]
  [[ "$output" == *"Python coverage missing inventory files (1): plugin/hooks/unloaded.py"* ]]
}

@test "coverage-python accepts a registered contract-only file in the report" {
  setup_makefile_contract_repo
  create_fake_python_coverage_tool
  printf 'VALUE = 2\n' >"$MAKEFILE_CONTRACT_REPO/plugin/hooks/contract.py"
  update_fake_inventory '.python.contract_only["plugin/hooks/contract.py"] = ["plugin/tests/example.bats"]'
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

@test "coverage-python reads the decimal percentages newer Python trace emits" {
  setup_makefile_contract_repo
  create_fake_python_coverage_tool
  write_fake_python_coverage_report "35.4"

  run env PATH="$MAKEFILE_CONTRACT_BIN:/usr/bin:/bin" PYTHON_COVERAGE_FIXTURE="$MAKEFILE_CONTRACT_REPO/python-coverage.txt" make -C "$MAKEFILE_CONTRACT_REPO/plugin" --no-print-directory coverage-python

  [ "$status" -eq 0 ]
  [[ "$output" == *"Python production aggregate: 35.40%"* ]]
}

@test "coverage-python ignores package __init__ modules" {
  setup_makefile_contract_repo
  create_fake_python_coverage_tool
  write_fake_python_coverage_report 35
  append_fake_python_coverage_row "hooks" "plugin/hooks/__init__.py" 100

  run env PATH="$MAKEFILE_CONTRACT_BIN:/usr/bin:/bin" PYTHON_COVERAGE_FIXTURE="$MAKEFILE_CONTRACT_REPO/python-coverage.txt" make -C "$MAKEFILE_CONTRACT_REPO/plugin" --no-print-directory coverage-python

  [ "$status" -eq 0 ]
  [[ "$output" != *"unregistered production files"* ]]
}

@test "coverage-python ignores modules outside the repository" {
  setup_makefile_contract_repo
  create_fake_python_coverage_tool
  write_fake_python_coverage_report 35
  printf '100 100%% argparse (/opt/homebrew/lib/python3.14/argparse.py)\n' \
    >>"$MAKEFILE_CONTRACT_REPO/python-coverage.txt"

  run env PATH="$MAKEFILE_CONTRACT_BIN:/usr/bin:/bin" PYTHON_COVERAGE_FIXTURE="$MAKEFILE_CONTRACT_REPO/python-coverage.txt" make -C "$MAKEFILE_CONTRACT_REPO/plugin" --no-print-directory coverage-python

  [ "$status" -eq 0 ]
  [[ "$output" != *"unregistered production files"* ]]
  [[ "$output" == *"Python production aggregate: 35.00%"* ]]
}

@test "coverage-python reports per-file coverage against the floor" {
  setup_makefile_contract_repo
  create_fake_python_coverage_tool
  add_low_coverage_python_module 45

  run env PATH="$MAKEFILE_CONTRACT_BIN:/usr/bin:/bin" PYTHON_COVERAGE_FIXTURE="$MAKEFILE_CONTRACT_REPO/python-coverage.txt" make -C "$MAKEFILE_CONTRACT_REPO/plugin" --no-print-directory coverage-python

  [ "$status" -eq 0 ]
  [[ "$output" == *"Python per-file coverage (2 lowest of 2 measured files, floor 20%)"* ]]
  [[ "$output" == *"45.00% (floor 20%) plugin/hooks/low.py"* ]]
}

@test "coverage-python rejects a measured file the tests never exercise" {
  setup_makefile_contract_repo
  create_fake_python_coverage_tool
  add_low_coverage_python_module 0

  run env PATH="$MAKEFILE_CONTRACT_BIN:/usr/bin:/bin" PYTHON_COVERAGE_FIXTURE="$MAKEFILE_CONTRACT_REPO/python-coverage.txt" make -C "$MAKEFILE_CONTRACT_REPO/plugin" --no-print-directory coverage-python

  [ "$status" -ne 0 ]
  [[ "$output" == *"Python files below the per-file coverage floor"*"plugin/hooks/low.py (0.00% < 20%)"* ]]
}

@test "coverage-python rejects a measured file just below the per-file floor" {
  setup_makefile_contract_repo
  create_fake_python_coverage_tool
  add_low_coverage_python_module 19

  run env PATH="$MAKEFILE_CONTRACT_BIN:/usr/bin:/bin" PYTHON_COVERAGE_FIXTURE="$MAKEFILE_CONTRACT_REPO/python-coverage.txt" make -C "$MAKEFILE_CONTRACT_REPO/plugin" --no-print-directory coverage-python

  [ "$status" -ne 0 ]
  [[ "$output" == *"plugin/hooks/low.py (19.00% < 20%)"* ]]
}

@test "coverage-python accepts a seeded per-file floor" {
  setup_makefile_contract_repo
  create_fake_python_coverage_tool
  add_low_coverage_python_module 19
  update_fake_inventory '.python.measured_floors = {"plugin/hooks/low.py": 10}'

  run env PATH="$MAKEFILE_CONTRACT_BIN:/usr/bin:/bin" PYTHON_COVERAGE_FIXTURE="$MAKEFILE_CONTRACT_REPO/python-coverage.txt" make -C "$MAKEFILE_CONTRACT_REPO/plugin" --no-print-directory coverage-python

  [ "$status" -eq 0 ]
  [[ "$output" == *"19.00% (floor 10%) plugin/hooks/low.py"* ]]
}

@test "coverage-python rejects a seeded per-file floor the source has outgrown" {
  setup_makefile_contract_repo
  create_fake_python_coverage_tool
  add_low_coverage_python_module 35
  update_fake_inventory '.python.measured_floors = {"plugin/hooks/low.py": 10}'

  run env PATH="$MAKEFILE_CONTRACT_BIN:/usr/bin:/bin" PYTHON_COVERAGE_FIXTURE="$MAKEFILE_CONTRACT_REPO/python-coverage.txt" make -C "$MAKEFILE_CONTRACT_REPO/plugin" --no-print-directory coverage-python

  [ "$status" -ne 0 ]
  [[ "$output" == *"Python per-file floors are obsolete"*"plugin/hooks/low.py (35.00%)"* ]]
}

@test "coverage-bats-contract accepts a complete shell source mapping" {
  setup_makefile_contract_repo

  run env PATH="$MAKEFILE_CONTRACT_BIN:/usr/bin:/bin" make -C "$MAKEFILE_CONTRACT_REPO/plugin" --no-print-directory coverage-bats-contract

  [ "$status" -eq 0 ]
  [[ "$output" == *"Shell source-to-contract inventory proxy: 1 production file mapped"* ]]
  [[ "$output" == *"not measured execution coverage"* ]]
}

@test "coverage-bats-contract rejects a per-file Python floor for an unmeasured source" {
  setup_makefile_contract_repo
  update_fake_inventory '.python.measured_floors = {"plugin/scripts/contract.py": 10}'

  run env PATH="$MAKEFILE_CONTRACT_BIN:/usr/bin:/bin" make -C "$MAKEFILE_CONTRACT_REPO/plugin" --no-print-directory coverage-bats-contract

  [ "$status" -ne 0 ]
  [[ "$output" == *"Production coverage inventory is malformed"* ]]
}

@test "coverage-bats-contract rejects a mapped Bats file outside the discovered suite" {
  setup_makefile_contract_repo
  mkdir -p "$MAKEFILE_CONTRACT_REPO/plugin/tests/nested"
  mv \
    "$MAKEFILE_CONTRACT_REPO/plugin/tests/example.bats" \
    "$MAKEFILE_CONTRACT_REPO/plugin/tests/nested/example.bats"
  update_fake_inventory '.shell.contract_only["plugin/hooks/example.sh"] = ["plugin/tests/nested/example.bats"]'

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
  [[ "$output" == *"Python static inventory is malformed"* ]]
}
