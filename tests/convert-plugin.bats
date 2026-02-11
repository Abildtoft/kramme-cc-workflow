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

create_fixture_plugin() {
  local plugin_dir="$1"
  mkdir -p "$plugin_dir/.claude-plugin"
  cat > "$plugin_dir/.claude-plugin/plugin.json" <<'JSON'
{
  "name": "fixture-plugin",
  "version": "1.0.0",
  "agents": [],
  "commands": [],
  "skills": []
}
JSON
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

  run node "$SCRIPT" install "$EMPTY_PLUGIN_DIR" --to codex --codex-home "$TMP_DIR" --agents-home "$TMP_DIR/.agents" --yes
  [ "$status" -eq 0 ]
  [ ! -d "$TMP_DIR/.agents/skills/kramme-architecture-strategist" ]
  [ ! -d "$TMP_DIR/.agents/skills/kramme-silent-failure-hunter" ]
}

@test "codex conversion skips cleanup in non-interactive mode without --yes" {
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

  run node "$SCRIPT" install "$EMPTY_PLUGIN_DIR" --to codex --codex-home "$TMP_DIR" --agents-home "$TMP_DIR/.agents" --non-interactive
  [ "$status" -eq 0 ]
  [ -d "$TMP_DIR/.agents/skills/kramme-architecture-strategist" ]
  [[ "$output" == *"non-interactive mode"* ]]
}

@test "codex conversion cleans stale prompts when commands change" {
  if ! command -v node >/dev/null 2>&1; then
    skip "node is required for converter tests"
  fi

  PROMPT_PLUGIN_DIR="$TMP_DIR/prompt-plugin"
  mkdir -p "$PROMPT_PLUGIN_DIR/.claude-plugin" "$PROMPT_PLUGIN_DIR/commands"
  cat > "$PROMPT_PLUGIN_DIR/.claude-plugin/plugin.json" <<'JSON'
{
  "name": "prompt-plugin",
  "version": "1.0.0",
  "agents": [],
  "commands": [],
  "skills": []
}
JSON
  cat > "$PROMPT_PLUGIN_DIR/commands/kramme-temp-command.md" <<'MD'
---
name: kramme:temp-command
description: Temporary command for prompt cleanup test
---

Execute temporary command.
MD

  run node "$SCRIPT" install "$PROMPT_PLUGIN_DIR" --to codex --codex-home "$TMP_DIR" --agents-home "$TMP_DIR/.agents"
  [ "$status" -eq 0 ]
  [ -f "$TMP_DIR/.codex/prompts/kramme-temp-command.md" ]
  [ -f "$TMP_DIR/.codex/skills/kramme-temp-command/SKILL.md" ]

  rm "$PROMPT_PLUGIN_DIR/commands/kramme-temp-command.md"
  cat > "$PROMPT_PLUGIN_DIR/commands/kramme-next-command.md" <<'MD'
---
name: kramme:next-command
description: Replacement command for prompt cleanup test
---

Execute replacement command.
MD

  run node "$SCRIPT" install "$PROMPT_PLUGIN_DIR" --to codex --codex-home "$TMP_DIR" --agents-home "$TMP_DIR/.agents" --yes
  [ "$status" -eq 0 ]
  [ ! -f "$TMP_DIR/.codex/prompts/kramme-temp-command.md" ]
  [ -f "$TMP_DIR/.codex/prompts/kramme-next-command.md" ]
  [ ! -f "$TMP_DIR/.codex/skills/kramme-temp-command/SKILL.md" ]
  [ -f "$TMP_DIR/.codex/skills/kramme-next-command/SKILL.md" ]
}

@test "codex conversion cleans stale prompts when commands are removed" {
  if ! command -v node >/dev/null 2>&1; then
    skip "node is required for converter tests"
  fi

  PROMPT_PLUGIN_DIR="$TMP_DIR/prompt-plugin-empty"
  mkdir -p "$PROMPT_PLUGIN_DIR/.claude-plugin" "$PROMPT_PLUGIN_DIR/commands"
  cat > "$PROMPT_PLUGIN_DIR/.claude-plugin/plugin.json" <<'JSON'
{
  "name": "prompt-plugin-empty",
  "version": "1.0.0",
  "agents": [],
  "commands": [],
  "skills": []
}
JSON
  cat > "$PROMPT_PLUGIN_DIR/commands/kramme-temp-command.md" <<'MD'
---
name: kramme:temp-command
description: Temporary command for prompt cleanup test
---

Execute temporary command.
MD

  run node "$SCRIPT" install "$PROMPT_PLUGIN_DIR" --to codex --codex-home "$TMP_DIR" --agents-home "$TMP_DIR/.agents"
  [ "$status" -eq 0 ]
  [ -f "$TMP_DIR/.codex/prompts/kramme-temp-command.md" ]
  [ -f "$TMP_DIR/.codex/skills/kramme-temp-command/SKILL.md" ]

  rm "$PROMPT_PLUGIN_DIR/commands/kramme-temp-command.md"
  run bash -c "printf 'y\\n' | node \"$SCRIPT\" install \"$PROMPT_PLUGIN_DIR\" --to codex --codex-home \"$TMP_DIR\" --agents-home \"$TMP_DIR/.agents\""
  [ "$status" -eq 0 ]
  [ ! -f "$TMP_DIR/.codex/prompts/kramme-temp-command.md" ]
  [ ! -f "$TMP_DIR/.codex/skills/kramme-temp-command/SKILL.md" ]
}

@test "codex conversion accepts streaming yes input for non-interactive confirmations" {
  if ! command -v node >/dev/null 2>&1; then
    skip "node is required for converter tests"
  fi
  if ! command -v yes >/dev/null 2>&1; then
    skip "yes is required for converter tests"
  fi

  run node "$SCRIPT" install "$REPO_ROOT" --to codex --codex-home "$TMP_DIR" --agents-home "$TMP_DIR/.agents"
  [ "$status" -eq 0 ]
  [ -f "$TMP_DIR/.codex/prompts/kramme-create-pr.md" ]
  [ -f "$TMP_DIR/.agents/skills/kramme-architecture-strategist/SKILL.md" ]

  EMPTY_PLUGIN_DIR="$TMP_DIR/empty-plugin-yes"
  mkdir -p "$EMPTY_PLUGIN_DIR/.claude-plugin"
  cat > "$EMPTY_PLUGIN_DIR/.claude-plugin/plugin.json" <<'JSON'
{
  "name": "empty-plugin-yes",
  "version": "1.0.0",
  "agents": [],
  "commands": [],
  "skills": []
}
JSON

  run bash -c "set +e; set +o pipefail; yes | node \"$SCRIPT\" install \"$EMPTY_PLUGIN_DIR\" --to codex --codex-home \"$TMP_DIR\" --agents-home \"$TMP_DIR/.agents\"; exit \${PIPESTATUS[1]}"
  [ "$status" -eq 0 ]
  [ ! -f "$TMP_DIR/.codex/prompts/kramme-create-pr.md" ]
  [ ! -d "$TMP_DIR/.agents/skills/kramme-architecture-strategist" ]
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

@test "from-commands permissions stay strict when command allowed-tools are declared" {
  if ! command -v node >/dev/null 2>&1; then
    skip "node is required for converter tests"
  fi

  FIXTURE_PLUGIN="$TMP_DIR/strict-command-plugin"
  create_fixture_plugin "$FIXTURE_PLUGIN"
  mkdir -p "$FIXTURE_PLUGIN/commands"
  cat > "$FIXTURE_PLUGIN/commands/strict-command.md" <<'MD'
---
name: strict-command
allowed-tools:
  - Read
  - Bash(npm:test)
---
Run strict permission checks.
MD

  run node "$SCRIPT" install "$FIXTURE_PLUGIN" --to opencode --output "$TMP_DIR" --permissions from-commands
  [ "$status" -eq 0 ]

  run jq -r '.tools.read' "$TMP_DIR/opencode.json"
  [ "$status" -eq 0 ]
  [ "$output" = "true" ]

  run jq -r '.permission.read' "$TMP_DIR/opencode.json"
  [ "$status" -eq 0 ]
  [ "$output" = "allow" ]

  run jq -r '.tools.bash' "$TMP_DIR/opencode.json"
  [ "$status" -eq 0 ]
  [ "$output" = "true" ]

  run jq -r '.tools.write' "$TMP_DIR/opencode.json"
  [ "$status" -eq 0 ]
  [ "$output" = "false" ]

  run jq -r '.permission.bash["*"]' "$TMP_DIR/opencode.json"
  [ "$status" -eq 0 ]
  [ "$output" = "deny" ]

  run jq -r '.permission.bash["npm test"]' "$TMP_DIR/opencode.json"
  [ "$status" -eq 0 ]
  [ "$output" = "allow" ]

  run jq -r '.permission.write' "$TMP_DIR/opencode.json"
  [ "$status" -eq 0 ]
  [ "$output" = "deny" ]
}

@test "from-commands uses only user-invocable skills for allowed-tools" {
  if ! command -v node >/dev/null 2>&1; then
    skip "node is required for converter tests"
  fi

  FIXTURE_PLUGIN="$TMP_DIR/skill-permission-plugin"
  create_fixture_plugin "$FIXTURE_PLUGIN"
  mkdir -p "$FIXTURE_PLUGIN/skills/invocable" "$FIXTURE_PLUGIN/skills/non-invocable"
  cat > "$FIXTURE_PLUGIN/skills/invocable/SKILL.md" <<'MD'
---
name: invocable-skill
user-invocable: true
allowed-tools:
  - Grep
---
User invocable skill.
MD
  cat > "$FIXTURE_PLUGIN/skills/non-invocable/SKILL.md" <<'MD'
---
name: internal-skill
user-invocable: false
allowed-tools:
  - Read
---
Internal skill.
MD

  run node "$SCRIPT" install "$FIXTURE_PLUGIN" --to opencode --output "$TMP_DIR" --permissions from-commands
  [ "$status" -eq 0 ]

  run jq -r '.tools.grep' "$TMP_DIR/opencode.json"
  [ "$status" -eq 0 ]
  [ "$output" = "true" ]

  run jq -r '.tools.read' "$TMP_DIR/opencode.json"
  [ "$status" -eq 0 ]
  [ "$output" = "false" ]

  run jq -r '.permission.read' "$TMP_DIR/opencode.json"
  [ "$status" -eq 0 ]
  [ "$output" = "deny" ]
}

@test "from-commands does not fall back when allowed-tools are unrecognized" {
  if ! command -v node >/dev/null 2>&1; then
    skip "node is required for converter tests"
  fi

  FIXTURE_PLUGIN="$TMP_DIR/unknown-tool-plugin"
  create_fixture_plugin "$FIXTURE_PLUGIN"
  mkdir -p "$FIXTURE_PLUGIN/commands"
  cat > "$FIXTURE_PLUGIN/commands/unknown-tool.md" <<'MD'
---
name: unknown-tool
allowed-tools:
  - UnknownTool
---
Unknown tool declaration.
MD

  run node "$SCRIPT" install "$FIXTURE_PLUGIN" --to opencode --output "$TMP_DIR" --permissions from-commands
  [ "$status" -eq 0 ]

  run jq -r '.tools.read' "$TMP_DIR/opencode.json"
  [ "$status" -eq 0 ]
  [ "$output" = "false" ]

  run jq -r '.tools.bash' "$TMP_DIR/opencode.json"
  [ "$status" -eq 0 ]
  [ "$output" = "false" ]

  run jq -r '.tools.write' "$TMP_DIR/opencode.json"
  [ "$status" -eq 0 ]
  [ "$output" = "false" ]

  run jq -r '.tools.edit' "$TMP_DIR/opencode.json"
  [ "$status" -eq 0 ]
  [ "$output" = "false" ]

  run jq -r '.permission.read' "$TMP_DIR/opencode.json"
  [ "$status" -eq 0 ]
  [ "$output" = "deny" ]

  run jq -r '.permission.bash' "$TMP_DIR/opencode.json"
  [ "$status" -eq 0 ]
  [ "$output" = "deny" ]

  run jq -r '.permission.write' "$TMP_DIR/opencode.json"
  [ "$status" -eq 0 ]
  [ "$output" = "deny" ]

  run jq -r '.permission.edit' "$TMP_DIR/opencode.json"
  [ "$status" -eq 0 ]
  [ "$output" = "deny" ]
}

@test "from-commands merges write and edit pattern permissions" {
  if ! command -v node >/dev/null 2>&1; then
    skip "node is required for converter tests"
  fi

  FIXTURE_PLUGIN="$TMP_DIR/write-edit-patterns-plugin"
  create_fixture_plugin "$FIXTURE_PLUGIN"
  mkdir -p "$FIXTURE_PLUGIN/commands"
  cat > "$FIXTURE_PLUGIN/commands/write-edit.md" <<'MD'
---
name: write-edit
allowed-tools:
  - Write(src/**)
  - Edit(docs/**)
---
Write and edit pattern constraints.
MD

  run node "$SCRIPT" install "$FIXTURE_PLUGIN" --to opencode --output "$TMP_DIR" --permissions from-commands
  [ "$status" -eq 0 ]

  run jq -r '.tools.write' "$TMP_DIR/opencode.json"
  [ "$status" -eq 0 ]
  [ "$output" = "true" ]

  run jq -r '.tools.edit' "$TMP_DIR/opencode.json"
  [ "$status" -eq 0 ]
  [ "$output" = "true" ]

  run jq -r '.permission.write["*"]' "$TMP_DIR/opencode.json"
  [ "$status" -eq 0 ]
  [ "$output" = "deny" ]

  run jq -r '.permission.write["src/**"]' "$TMP_DIR/opencode.json"
  [ "$status" -eq 0 ]
  [ "$output" = "allow" ]

  run jq -r '.permission.write["docs/**"]' "$TMP_DIR/opencode.json"
  [ "$status" -eq 0 ]
  [ "$output" = "allow" ]

  run jq -r '.permission.edit["src/**"]' "$TMP_DIR/opencode.json"
  [ "$status" -eq 0 ]
  [ "$output" = "allow" ]

  run jq -r '.permission.edit["docs/**"]' "$TMP_DIR/opencode.json"
  [ "$status" -eq 0 ]
  [ "$output" = "allow" ]

  run jq -r '.permission.edit["*"]' "$TMP_DIR/opencode.json"
  [ "$status" -eq 0 ]
  [ "$output" = "deny" ]
}
