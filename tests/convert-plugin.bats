#!/usr/bin/env bats
# Regression tests for scripts/convert-plugin.js

setup() {
  SCRIPT="$BATS_TEST_DIRNAME/../scripts/convert-plugin.js"
  REPO_ROOT="$BATS_TEST_DIRNAME/.."
  TMP_DIR="$(mktemp -d)"
}

teardown() {
  if [ -n "$TMP_DIR" ] && [ -d "$TMP_DIR" ]; then
    rm -r "$TMP_DIR"
  fi
}

@test "codex conversion creates prompts from user-invocable skills" {
  if ! command -v node >/dev/null 2>&1; then
    skip "node is required for converter tests"
  fi

  run node "$SCRIPT" install "$REPO_ROOT" --to codex --codex-home "$TMP_DIR"
  [ "$status" -eq 0 ]
  [ -f "$TMP_DIR/.codex/prompts/kramme-create-pr.md" ]

  run find "$TMP_DIR/.codex/prompts" -type f
  [ "$status" -eq 0 ]
  [ -n "$output" ]
}

@test "opencode conversion includes command entries from skills" {
  if ! command -v node >/dev/null 2>&1; then
    skip "node is required for converter tests"
  fi

  run node "$SCRIPT" install "$REPO_ROOT" --to opencode --output "$TMP_DIR"
  [ "$status" -eq 0 ]
  [ -f "$TMP_DIR/opencode.json" ]

  run jq -r '.command | has("kramme:create-pr")' "$TMP_DIR/opencode.json"
  [ "$status" -eq 0 ]
  [ "$output" = "true" ]
}

@test "from-commands permissions fall back when no allowed-tools are declared" {
  if ! command -v node >/dev/null 2>&1; then
    skip "node is required for converter tests"
  fi

  run node "$SCRIPT" install "$REPO_ROOT" --to opencode --output "$TMP_DIR" --permissions from-commands
  [ "$status" -eq 0 ]
  [ -f "$TMP_DIR/opencode.json" ]

  run jq -r '.tools.read' "$TMP_DIR/opencode.json"
  [ "$status" -eq 0 ]
  [ "$output" = "true" ]

  run jq -r '.permission.read' "$TMP_DIR/opencode.json"
  [ "$status" -eq 0 ]
  [ "$output" = "allow" ]
}
