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

  run node "$SCRIPT" install "$REPO_ROOT" --to codex --codex-home "$TMP_DIR" --agents-home "$TMP_DIR/.agents"
  [ "$status" -eq 0 ]
  [ -f "$TMP_DIR/.codex/prompts/kramme-create-pr.md" ]

  run find "$TMP_DIR/.codex/prompts" -type f
  [ "$status" -eq 0 ]
  [ -n "$output" ]
}

@test "codex conversion places agents in agents-home/skills" {
  if ! command -v node >/dev/null 2>&1; then
    skip "node is required for converter tests"
  fi

  run node "$SCRIPT" install "$REPO_ROOT" --to codex --codex-home "$TMP_DIR" --agents-home "$TMP_DIR/.agents"
  [ "$status" -eq 0 ]

  # Agent skills should be in ~/.agents/skills/, not ~/.codex/skills/
  [ -d "$TMP_DIR/.agents/skills" ]
  [ -f "$TMP_DIR/.agents/skills/kramme-architecture-strategist/SKILL.md" ]
  [ -f "$TMP_DIR/.agents/skills/kramme-silent-failure-hunter/SKILL.md" ]

  # Agent skills should NOT be in codex skills
  [ ! -d "$TMP_DIR/.codex/skills/kramme-architecture-strategist" ]
  [ ! -d "$TMP_DIR/.codex/skills/kramme-silent-failure-hunter" ]
}

@test "codex conversion cleans stale agent skills when plugin has no agents" {
  if ! command -v node >/dev/null 2>&1; then
    skip "node is required for converter tests"
  fi

  run node "$SCRIPT" install "$REPO_ROOT" --to codex --codex-home "$TMP_DIR" --agents-home "$TMP_DIR/.agents"
  [ "$status" -eq 0 ]
  [ -f "$TMP_DIR/.agents/skills/kramme-architecture-strategist/SKILL.md" ]

  EMPTY_PLUGIN_DIR="$TMP_DIR/empty-plugin"
  mkdir -p "$EMPTY_PLUGIN_DIR/.claude-plugin"
  cat > "$EMPTY_PLUGIN_DIR/.claude-plugin/plugin.json" <<'JSON'
{
  "name": "empty-plugin",
  "version": "1.0.0",
  "agents": [],
  "commands": [],
  "skills": []
}
JSON

  run bash -c "printf 'y\\n' | node \"$SCRIPT\" install \"$EMPTY_PLUGIN_DIR\" --to codex --codex-home \"$TMP_DIR\" --agents-home \"$TMP_DIR/.agents\""
  [ "$status" -eq 0 ]
  [ ! -d "$TMP_DIR/.agents/skills/kramme-architecture-strategist" ]
  [ ! -d "$TMP_DIR/.agents/skills/kramme-silent-failure-hunter" ]
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
