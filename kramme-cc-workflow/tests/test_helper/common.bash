#!/bin/bash
# Common test utilities for BATS tests

# Make hooks path available
export HOOKS_DIR="${BATS_TEST_DIRNAME}/../hooks"
export CLAUDE_PLUGIN_ROOT="${BATS_TEST_DIRNAME}/.."

# Helper: Write stdin to a file, creating its parent directory first.
write_file() {
  local path="$1"
  mkdir -p "$(dirname "$path")"
  cat >"$path"
}

# Helper: Assert that every named guidance contract is registered.
#
# Usage: assert_required_contracts_registered <contract-name>...
#
# Reads scripts/synced-contracts.yaml next to the suite's plugin root and fails with
# "missing required_file_contracts: <names>" naming every unregistered contract.
# Call it directly instead of through `run`, so a suite can still assert on the
# $status of a command that ran before the assertion.
assert_required_contracts_registered() {
  python3 - "${BATS_TEST_DIRNAME}/../scripts/synced-contracts.yaml" "$@" <<'PY'
import json
import pathlib
import sys

registry = json.loads(pathlib.Path(sys.argv[1]).read_text())
registered = {contract["name"] for contract in registry.get("required_file_contracts", [])}
missing = sorted(set(sys.argv[2:]) - registered)
if missing:
    raise SystemExit(f"missing required_file_contracts: {', '.join(missing)}")
PY
}

# Helper: Create a deterministic local Git repository for fixtures.
#
# Usage: init_test_git_repo <work-dir> [--origin <bare-path>] [--file <name>]
#
#   --origin <bare-path>  Initialize a bare repository at <bare-path>, clone it into
#                         <work-dir>, and push the initial commit so main tracks
#                         origin/main. Omit to initialize <work-dir> standalone.
#   --file <name>         File committed by the initial commit (default: tracked.txt).
#
# On success, the result has repository-local user.name/user.email, commit and tag
# signing disabled, and a single "initial" commit on main, so fixtures behave the same
# under a contributor's global commit.gpgsign, tag.gpgsign, and init.defaultBranch.
# Global configuration is never modified, and the caller's working directory is
# unchanged -- cd into <work-dir> before running further Git commands.
init_test_git_repo() {
  local work_dir="$1"
  local origin=""
  local initial_file="tracked.txt"
  shift

  while [ "$#" -gt 0 ]; do
    case "$1" in
    --origin)
      if [ "$#" -lt 2 ]; then
        printf 'init_test_git_repo: option requires a value: %s\n' "$1" >&2
        return 1
      fi
      origin="$2"
      shift 2
      ;;
    --file)
      if [ "$#" -lt 2 ]; then
        printf 'init_test_git_repo: option requires a value: %s\n' "$1" >&2
        return 1
      fi
      initial_file="$2"
      shift 2
      ;;
    *)
      printf 'init_test_git_repo: unknown option: %s\n' "$1" >&2
      return 1
      ;;
    esac
  done

  if [ -n "$origin" ]; then
    git init --bare "$origin" >/dev/null || return 1
    git clone "$origin" "$work_dir" >/dev/null 2>&1 || return 1
  else
    mkdir -p "$work_dir" || return 1
    git init "$work_dir" >/dev/null || return 1
  fi

  git -C "$work_dir" config user.email "test@example.com" || return 1
  git -C "$work_dir" config user.name "Test User" || return 1
  git -C "$work_dir" config commit.gpgsign false || return 1
  git -C "$work_dir" config tag.gpgsign false || return 1

  printf 'base\n' >"$work_dir/$initial_file" || return 1
  git -C "$work_dir" add "$initial_file" || return 1
  git -C "$work_dir" commit -m "initial" >/dev/null || return 1
  git -C "$work_dir" branch -M main || return 1

  if [ -n "$origin" ]; then
    git -C "$work_dir" push -u origin main >/dev/null 2>&1 || return 1
  fi
}

# Helper: Create JSON input for block-rm-rf hook
make_bash_input() {
  local cmd="$1"
  jq -n --arg cmd "$cmd" '{tool_input:{command:$cmd}}'
}

# Helper: Check if output indicates a block decision (exit 2 + stderr message)
is_blocked() {
  [ "$status" -eq 2 ] && [ -n "$output" ]
}

# Helper: Check if output is empty (allowed)
is_allowed() {
  [ -z "$output" ] || [ "$output" = "{}" ]
}

# Helper: Run a command-safety hook with command metadata.
run_safety_hook() {
  local hook="$1"
  local cmd="$2"
  make_bash_input "$cmd" | bash "$hook"
}

_prepare_safety_hook_plugin_root() {
  local plugin_root="$1"
  local include_parser_wrapper="${2:-false}"

  rm -rf "$plugin_root"
  mkdir -p "$plugin_root/hooks/lib"
  cp "$HOOKS_DIR/lib/check-enabled.sh" "$plugin_root/hooks/lib/check-enabled.sh"
  if [ "$include_parser_wrapper" = "true" ]; then
    cp "$HOOKS_DIR/lib/safety-hook-parser.sh" "$plugin_root/hooks/lib/safety-hook-parser.sh"
  fi
  if [ -f "$HOOKS_DIR/confirm-review-artifacts.txt" ]; then
    cp "$HOOKS_DIR/confirm-review-artifacts.txt" "$plugin_root/hooks/confirm-review-artifacts.txt"
  fi
}

# Helper: Exercise the fail-closed path when jq is unavailable.
run_safety_hook_without_jq() {
  local hook="$1"
  local cmd="$2"
  local fake_bin="$BATS_TEST_TMPDIR/no-jq-bin"
  local json_input

  rm -rf "$fake_bin"
  mkdir -p "$fake_bin"
  ln -s "$(command -v bash)" "$fake_bin/bash"
  ln -s "$(command -v cat)" "$fake_bin/cat"
  json_input="$(make_bash_input "$cmd")"
  env PATH="$fake_bin" CLAUDE_PLUGIN_ROOT="$CLAUDE_PLUGIN_ROOT" "$fake_bin/bash" "$hook" <<<"$json_input"
}

# Helper: Exercise the disabled-hook path without requiring jq.
run_disabled_safety_hook_without_jq() {
  local hook="$1"
  local hook_id="$2"
  local cmd="$3"
  local fake_bin="$BATS_TEST_TMPDIR/no-jq-disabled-bin"
  local plugin_root="$BATS_TEST_TMPDIR/no-jq-disabled-plugin"
  local json_input

  rm -rf "$fake_bin"
  mkdir -p "$fake_bin"
  ln -s "$(command -v bash)" "$fake_bin/bash"
  ln -s "$(command -v cat)" "$fake_bin/cat"
  _prepare_safety_hook_plugin_root "$plugin_root"
  printf '%s\n' "{\"disabled\":[\"$hook_id\"]}" >"$plugin_root/hooks/hook-state.json"
  json_input="$(make_bash_input "$cmd")"
  env PATH="$fake_bin" CLAUDE_PLUGIN_ROOT="$plugin_root" "$fake_bin/bash" "$hook" <<<"$json_input"
}

# Helper: Exercise the fail-closed path when python3 is unavailable.
run_safety_hook_without_python() {
  local hook="$1"
  local cmd="$2"
  local git_command="${3:-}"
  local fake_bin="$BATS_TEST_TMPDIR/no-python-bin"
  local command_name command_path

  rm -rf "$fake_bin"
  mkdir -p "$fake_bin"
  for command_name in bash jq cat grep sed; do
    command_path="$(command -v "$command_name")"
    ln -s "$command_path" "$fake_bin/$command_name"
  done
  if [ -n "$git_command" ]; then
    ln -s "$git_command" "$fake_bin/git"
  fi
  make_bash_input "$cmd" | env PATH="$fake_bin" CLAUDE_PLUGIN_ROOT="$CLAUDE_PLUGIN_ROOT" "$fake_bin/bash" "$hook"
}

# Helper: Exercise a hook whose shared shell parser wrapper is unavailable.
run_safety_hook_without_shared_parser() {
  local hook="$1"
  local cmd="$2"
  local plugin_root="$BATS_TEST_TMPDIR/no-safety-parser-plugin"

  _prepare_safety_hook_plugin_root "$plugin_root"
  make_bash_input "$cmd" | env CLAUDE_PLUGIN_ROOT="$plugin_root" bash "$hook"
}

# Helper: Exercise a hook whose Python parser implementation is unavailable.
run_safety_hook_without_python_parser() {
  local hook="$1"
  local cmd="$2"
  local plugin_root="$BATS_TEST_TMPDIR/missing-python-parser-plugin"

  _prepare_safety_hook_plugin_root "$plugin_root" "true"
  make_bash_input "$cmd" | env CLAUDE_PLUGIN_ROOT="$plugin_root" bash "$hook"
}

# Helper: Exercise parser-output validation without invoking the production parser.
run_safety_hook_with_parser_output() {
  local hook="$1"
  local cmd="$2"
  local parser_output="$3"
  local plugin_root="$BATS_TEST_TMPDIR/parser-output-plugin"

  _prepare_safety_hook_plugin_root "$plugin_root" "true"
  printf '%s\n' \
    'import os' \
    '' \
    'print(os.environ["SAFETY_HOOK_TEST_PARSER_OUTPUT"])' \
    >"$plugin_root/hooks/lib/git_command_parser.py"
  make_bash_input "$cmd" |
    env SAFETY_HOOK_TEST_PARSER_OUTPUT="$parser_output" CLAUDE_PLUGIN_ROOT="$plugin_root" bash "$hook"
}

# Helper: Emit the supported cross-policy command-prefix matrix for a payload.
safety_command_prefix_matrix() {
  local payload="$1"

  printf '%s\n' \
    "$payload" \
    "timeout 1 $payload" \
    "timeout -s KILL 1 $payload" \
    "nice -n 10 $payload" \
    "env FOO=bar $payload" \
    "env -S \"$payload\"" \
    "env --split-string=\"$payload\"" \
    "nohup $payload" \
    "exec $payload" \
    "exec -c $payload" \
    "exec -cl $payload" \
    "sudo FOO=bar $payload" \
    "time FOO=bar $payload" \
    "timeout 1 nice -n 10 env FOO=bar bash -c '$payload'"
}

# Helper: Emit malformed command prefixes that every safety policy rejects.
safety_malformed_prefix_matrix() {
  local payload="$1"

  printf '%s\n' \
    "timeout 1 bash -c \$'$payload" \
    "nice -n 10 env FOO=bar bash -c \$'$payload" \
    "env -S '\"$payload'" \
    "env --split-string='\"$payload'"
}

# Helper: Create JSON input for auto-format hook
make_format_input() {
  local path="$1"
  jq -n --arg path "$path" '{tool_input:{file_path:$path}}'
}

# Helper: Check if output contains systemMessage
has_system_message() {
  [[ "$output" == *'"systemMessage"'* ]]
}

# Helper: Check if output indicates no formatter
has_no_formatter() {
  [[ "$output" == *'No formatter'* ]]
}
