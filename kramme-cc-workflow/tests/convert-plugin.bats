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
  local plugin_name="${2:-fixture-plugin}"
  mkdir -p "$plugin_dir/.claude-plugin"
  cat > "$plugin_dir/.claude-plugin/plugin.json" <<JSON
{
  "name": "$plugin_name",
  "version": "1.0.0",
  "agents": [],
  "commands": [],
  "skills": []
}
JSON
}

create_hook_fixture_plugin() {
  local plugin_dir="$1"
  local plugin_name="$2"
  local script_name="$3"
  local hook_command="${4:-bash \${CLAUDE_PLUGIN_ROOT}/hooks/${script_name}.sh}"
  local script_body="${5:-#!/bin/bash
exit 0}"

  create_fixture_plugin "$plugin_dir" "$plugin_name"
  mkdir -p "$plugin_dir/hooks/lib"

  jq -n --arg cmd "$hook_command" '{
    hooks: {
      PreToolUse: [
        {
          matcher: "Bash",
          hooks: [
            {type: "command", command: $cmd}
          ]
        }
      ]
    }
  }' > "$plugin_dir/hooks/hooks.json"

  printf '%s\n' "$script_body" > "$plugin_dir/hooks/${script_name}.sh"

  cat > "$plugin_dir/hooks/lib/check-enabled.sh" <<'SH'
#!/bin/bash
exit_if_hook_disabled() {
  return 0
}
SH
}

@test "codex conversion creates skills from user-invocable skills" {
  if ! command -v node >/dev/null 2>&1; then
    skip "node is required for converter tests"
  fi

  run node "$SCRIPT" install "$REPO_ROOT" --to codex --codex-home "$TMP_DIR" --agents-home "$TMP_DIR/.agents"
  [ "$status" -eq 0 ]
  [ -f "$TMP_DIR/.codex/skills/kramme:pr:create/SKILL.md" ]
  [ ! -d "$TMP_DIR/.codex/prompts" ] || [ -z "$(ls -A "$TMP_DIR/.codex/prompts" 2>/dev/null)" ]
}

@test "codex conversion preserves user-invocable skill resources" {
  if ! command -v node >/dev/null 2>&1; then
    skip "node is required for converter tests"
  fi

  run node "$SCRIPT" install "$REPO_ROOT" --to codex --codex-home "$TMP_DIR" --agents-home "$TMP_DIR/.agents"
  [ "$status" -eq 0 ]
  [ -f "$TMP_DIR/.codex/skills/kramme:pr:create/references/pre-validation-checks.md" ]
  [ -f "$TMP_DIR/.codex/skills/kramme:pr:create/references/branch-and-platform-handling.md" ]
}

@test "codex conversion rewrites slash-command references inside copied skills" {
  if ! command -v node >/dev/null 2>&1; then
    skip "node is required for converter tests"
  fi

  run node "$SCRIPT" install "$REPO_ROOT" --to codex --codex-home "$TMP_DIR" --agents-home "$TMP_DIR/.agents"
  [ "$status" -eq 0 ]

  run grep -n '/kramme:' "$TMP_DIR/.codex/skills/kramme:siw:issue-implement/SKILL.md"
  [ "$status" -eq 1 ]

  run grep -nE '\$kramme:pr:create' "$TMP_DIR/.codex/skills/kramme:siw:issue-implement/SKILL.md"
  [ "$status" -eq 0 ]
}

@test "codex conversion rewrites slash-command references in copied markdown resources" {
  if ! command -v node >/dev/null 2>&1; then
    skip "node is required for converter tests"
  fi

  FIXTURE_PLUGIN="$TMP_DIR/resource-plugin"
  create_fixture_plugin "$FIXTURE_PLUGIN"
  mkdir -p "$FIXTURE_PLUGIN/skills/demo/references"
  cat > "$FIXTURE_PLUGIN/skills/demo/SKILL.md" <<'MD'
---
name: kramme:demo-skill
description: Demo skill
disable-model-invocation: false
user-invocable: true
---
Use /kramme:demo-skill.
MD
  cat > "$FIXTURE_PLUGIN/skills/demo/references/guide.md" <<'MD'
Run /kramme:demo-skill to continue.
Do not rewrite /usr/bin.
MD

  run node "$SCRIPT" install "$FIXTURE_PLUGIN" --to codex --codex-home "$TMP_DIR" --agents-home "$TMP_DIR/.agents" --yes
  [ "$status" -eq 0 ]

  run grep -n '/kramme:demo-skill' "$TMP_DIR/.codex/skills/kramme:demo-skill/references/guide.md"
  [ "$status" -eq 1 ]

  run grep -nE '\$kramme:demo-skill' "$TMP_DIR/.codex/skills/kramme:demo-skill/references/guide.md"
  [ "$status" -eq 0 ]

  run grep -n '/usr/bin' "$TMP_DIR/.codex/skills/kramme:demo-skill/references/guide.md"
  [ "$status" -eq 0 ]
}

@test "codex conversion preserves allowed-tools in copied skills" {
  if ! command -v node >/dev/null 2>&1; then
    skip "node is required for converter tests"
  fi

  FIXTURE_PLUGIN="$TMP_DIR/allowed-tools-plugin"
  create_fixture_plugin "$FIXTURE_PLUGIN"
  mkdir -p "$FIXTURE_PLUGIN/skills/demo"
  cat > "$FIXTURE_PLUGIN/skills/demo/SKILL.md" <<'MD'
---
name: demo-skill
description: Demo skill
disable-model-invocation: false
user-invocable: true
allowed-tools:
  - Read
  - Edit(src/**)
---
Use /demo-skill.
MD

  run node "$SCRIPT" install "$FIXTURE_PLUGIN" --to codex --codex-home "$TMP_DIR" --agents-home "$TMP_DIR/.agents" --yes
  [ "$status" -eq 0 ]

  run sed -n '1,20p' "$TMP_DIR/.codex/skills/demo-skill/SKILL.md"
  [ "$status" -eq 0 ]
  [[ "$output" == *"allowed-tools:"* ]]
  [[ "$output" == *"Read"* ]]
  [[ "$output" == *"Edit(src/**)"* ]]
}

@test "codex conversion places agents in agents-home/skills" {
  if ! command -v node >/dev/null 2>&1; then
    skip "node is required for converter tests"
  fi

  run node "$SCRIPT" install "$REPO_ROOT" --to codex --codex-home "$TMP_DIR" --agents-home "$TMP_DIR/.agents"
  [ "$status" -eq 0 ]

  # Agent skills should be in ~/.agents/skills/, not ~/.codex/skills/
  [ -d "$TMP_DIR/.agents/skills" ]
  [ -f "$TMP_DIR/.agents/skills/kramme:architecture-strategist/SKILL.md" ]
  [ -f "$TMP_DIR/.agents/skills/kramme:silent-failure-hunter/SKILL.md" ]

  # Agent skills should NOT be in codex skills
  [ ! -d "$TMP_DIR/.codex/skills/kramme:architecture-strategist" ]
  [ ! -d "$TMP_DIR/.codex/skills/kramme:silent-failure-hunter" ]
}

@test "converter resolves marketplace slug from parent repo root" {
  if ! command -v node >/dev/null 2>&1; then
    skip "node is required for converter tests"
  fi

  run bash -c "cd \"$TMP_DIR\" && node \"$SCRIPT\" install kramme-cc-workflow --to codex --codex-home \"$TMP_DIR/output\" --agents-home \"$TMP_DIR/.agents\" --non-interactive"
  [ "$status" -eq 0 ]
  [ -f "$TMP_DIR/output/.codex/skills/kramme:pr:create/SKILL.md" ]
}

@test "codex conversion cleans stale agent skills when plugin has no agents" {
  if ! command -v node >/dev/null 2>&1; then
    skip "node is required for converter tests"
  fi

  run node "$SCRIPT" install "$REPO_ROOT" --to codex --codex-home "$TMP_DIR" --agents-home "$TMP_DIR/.agents"
  [ "$status" -eq 0 ]
  [ -f "$TMP_DIR/.agents/skills/kramme:architecture-strategist/SKILL.md" ]

  EMPTY_PLUGIN_DIR="$TMP_DIR/empty-plugin"
  create_fixture_plugin "$EMPTY_PLUGIN_DIR" "kramme-cc-workflow"

  run node "$SCRIPT" install "$EMPTY_PLUGIN_DIR" --to codex --codex-home "$TMP_DIR" --agents-home "$TMP_DIR/.agents" --yes
  [ "$status" -eq 0 ]
  [ ! -d "$TMP_DIR/.agents/skills/kramme:architecture-strategist" ]
  [ ! -d "$TMP_DIR/.agents/skills/kramme:silent-failure-hunter" ]
  [ ! -d "$TMP_DIR/.agents/skills/performance-oracle" ]
}

@test "codex conversion skips cleanup in non-interactive mode without --yes" {
  if ! command -v node >/dev/null 2>&1; then
    skip "node is required for converter tests"
  fi

  run node "$SCRIPT" install "$REPO_ROOT" --to codex --codex-home "$TMP_DIR" --agents-home "$TMP_DIR/.agents"
  [ "$status" -eq 0 ]
  [ -f "$TMP_DIR/.agents/skills/kramme:architecture-strategist/SKILL.md" ]

  EMPTY_PLUGIN_DIR="$TMP_DIR/empty-plugin"
  create_fixture_plugin "$EMPTY_PLUGIN_DIR" "kramme-cc-workflow"

  run node "$SCRIPT" install "$EMPTY_PLUGIN_DIR" --to codex --codex-home "$TMP_DIR" --agents-home "$TMP_DIR/.agents" --non-interactive
  [ "$status" -eq 0 ]
  [ -d "$TMP_DIR/.agents/skills/kramme:architecture-strategist" ]
  [[ "$output" == *"non-interactive mode"* ]]
}

@test "codex conversion preserves local markdown files in managed skills when cleanup is skipped" {
  if ! command -v node >/dev/null 2>&1; then
    skip "node is required for converter tests"
  fi

  run node "$SCRIPT" install "$REPO_ROOT" --to codex --codex-home "$TMP_DIR" --agents-home "$TMP_DIR/.agents"
  [ "$status" -eq 0 ]

  printf "Run /kramme:pr:create later\n" > "$TMP_DIR/.codex/skills/kramme:pr:create/LOCAL-NOTES.md"

  run node "$SCRIPT" install "$REPO_ROOT" --to codex --codex-home "$TMP_DIR" --agents-home "$TMP_DIR/.agents" --non-interactive
  [ "$status" -eq 0 ]
  [[ "$output" == *"Skipping skill cleanup."* ]]
  [ -f "$TMP_DIR/.codex/skills/kramme:pr:create/LOCAL-NOTES.md" ]
  run cat "$TMP_DIR/.codex/skills/kramme:pr:create/LOCAL-NOTES.md"
  [ "$status" -eq 0 ]
  [ "$output" = "Run /kramme:pr:create later" ]
}

@test "codex conversion cleans stale skills when commands change" {
  if ! command -v node >/dev/null 2>&1; then
    skip "node is required for converter tests"
  fi

  PLUGIN_DIR="$TMP_DIR/skill-plugin"
  mkdir -p "$PLUGIN_DIR/.claude-plugin" "$PLUGIN_DIR/commands"
  cat > "$PLUGIN_DIR/.claude-plugin/plugin.json" <<'JSON'
{
  "name": "skill-plugin",
  "version": "1.0.0",
  "agents": [],
  "commands": [],
  "skills": []
}
JSON
  cat > "$PLUGIN_DIR/commands/kramme-temp-command.md" <<'MD'
---
name: kramme:temp-command
description: Temporary command for skill cleanup test
---

Execute temporary command.
MD

  run node "$SCRIPT" install "$PLUGIN_DIR" --to codex --codex-home "$TMP_DIR" --agents-home "$TMP_DIR/.agents"
  [ "$status" -eq 0 ]
  [ -f "$TMP_DIR/.codex/skills/kramme:temp-command/SKILL.md" ]

  rm "$PLUGIN_DIR/commands/kramme-temp-command.md"
  cat > "$PLUGIN_DIR/commands/kramme-next-command.md" <<'MD'
---
name: kramme:next-command
description: Replacement command for skill cleanup test
---

Execute replacement command.
MD

  run node "$SCRIPT" install "$PLUGIN_DIR" --to codex --codex-home "$TMP_DIR" --agents-home "$TMP_DIR/.agents" --yes
  [ "$status" -eq 0 ]
  [ ! -f "$TMP_DIR/.codex/skills/kramme:temp-command/SKILL.md" ]
  [ -f "$TMP_DIR/.codex/skills/kramme:next-command/SKILL.md" ]
}

@test "codex conversion cleans stale skills when commands are removed" {
  if ! command -v node >/dev/null 2>&1; then
    skip "node is required for converter tests"
  fi

  PLUGIN_DIR="$TMP_DIR/skill-plugin-empty"
  mkdir -p "$PLUGIN_DIR/.claude-plugin" "$PLUGIN_DIR/commands"
  cat > "$PLUGIN_DIR/.claude-plugin/plugin.json" <<'JSON'
{
  "name": "skill-plugin-empty",
  "version": "1.0.0",
  "agents": [],
  "commands": [],
  "skills": []
}
JSON
  cat > "$PLUGIN_DIR/commands/kramme-temp-command.md" <<'MD'
---
name: kramme:temp-command
description: Temporary command for skill cleanup test
---

Execute temporary command.
MD

  run node "$SCRIPT" install "$PLUGIN_DIR" --to codex --codex-home "$TMP_DIR" --agents-home "$TMP_DIR/.agents"
  [ "$status" -eq 0 ]
  [ -f "$TMP_DIR/.codex/skills/kramme:temp-command/SKILL.md" ]

  rm "$PLUGIN_DIR/commands/kramme-temp-command.md"
  run bash -c "printf 'y\\n' | node \"$SCRIPT\" install \"$PLUGIN_DIR\" --to codex --codex-home \"$TMP_DIR\" --agents-home \"$TMP_DIR/.agents\""
  [ "$status" -eq 0 ]
  [ ! -f "$TMP_DIR/.codex/skills/kramme:temp-command/SKILL.md" ]
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
  [ -f "$TMP_DIR/.codex/skills/kramme:pr:create/SKILL.md" ]
  [ -f "$TMP_DIR/.agents/skills/kramme:architecture-strategist/SKILL.md" ]

  EMPTY_PLUGIN_DIR="$TMP_DIR/empty-plugin-yes"
  create_fixture_plugin "$EMPTY_PLUGIN_DIR" "kramme-cc-workflow"

  run bash -c "set +e; set +o pipefail; yes | node \"$SCRIPT\" install \"$EMPTY_PLUGIN_DIR\" --to codex --codex-home \"$TMP_DIR\" --agents-home \"$TMP_DIR/.agents\"; exit \${PIPESTATUS[1]}"
  [ "$status" -eq 0 ]
  [ ! -f "$TMP_DIR/.codex/skills/kramme:pr:create/SKILL.md" ]
  [ ! -d "$TMP_DIR/.agents/skills/kramme:architecture-strategist" ]
  [ ! -d "$TMP_DIR/.agents/skills/performance-oracle" ]
}

@test "codex conversion cleans old impl- prefixed skills on upgrade" {
  if ! command -v node >/dev/null 2>&1; then
    skip "node is required for converter tests"
  fi

  mkdir -p "$TMP_DIR/.codex/skills/impl-kramme-create-pr"
  echo "old" > "$TMP_DIR/.codex/skills/impl-kramme-create-pr/SKILL.md"

  run node "$SCRIPT" install "$REPO_ROOT" --to codex --codex-home "$TMP_DIR" --agents-home "$TMP_DIR/.agents" --yes
  [ "$status" -eq 0 ]
  [ ! -d "$TMP_DIR/.codex/skills/impl-kramme-create-pr" ]
  [ -f "$TMP_DIR/.codex/skills/kramme:pr:create/SKILL.md" ]
}

@test "codex conversion preserves unknown legacy skills on first stateful install without state" {
  if ! command -v node >/dev/null 2>&1; then
    skip "node is required for converter tests"
  fi

  mkdir -p "$TMP_DIR/.codex/skills/kramme:obsolete-skill"
  echo "old" > "$TMP_DIR/.codex/skills/kramme:obsolete-skill/SKILL.md"

  run node "$SCRIPT" install "$REPO_ROOT" --to codex --codex-home "$TMP_DIR" --agents-home "$TMP_DIR/.agents" --yes
  [ "$status" -eq 0 ]
  [ -d "$TMP_DIR/.codex/skills/kramme:obsolete-skill" ]
  [ -f "$TMP_DIR/.codex/.kramme-install-state.json" ]
}

@test "codex conversion preserves workflow skills and agents when connect plugin is installed" {
  if ! command -v node >/dev/null 2>&1; then
    skip "node is required for converter tests"
  fi

  run node "$SCRIPT" install kramme-cc-workflow --to codex --codex-home "$TMP_DIR" --agents-home "$TMP_DIR/.agents" --yes
  [ "$status" -eq 0 ]
  [ -f "$TMP_DIR/.codex/skills/kramme:pr:create/SKILL.md" ]
  [ -f "$TMP_DIR/.agents/skills/kramme:architecture-strategist/SKILL.md" ]

  run node "$SCRIPT" install kramme-connect-workflow --to codex --codex-home "$TMP_DIR" --agents-home "$TMP_DIR/.agents" --yes
  [ "$status" -eq 0 ]
  [ -f "$TMP_DIR/.codex/skills/kramme:pr:create/SKILL.md" ]
  [ -f "$TMP_DIR/.codex/skills/kramme:connect:migrate-store-ngrx/SKILL.md" ]
  [ -f "$TMP_DIR/.agents/skills/kramme:architecture-strategist/SKILL.md" ]
  [ -f "$TMP_DIR/.agents/skills/performance-oracle/SKILL.md" ]
}

@test "codex conversion preserves existing workflow skills when reinstalling without state" {
  if ! command -v node >/dev/null 2>&1; then
    skip "node is required for converter tests"
  fi

  run node "$SCRIPT" install kramme-cc-workflow --to codex --codex-home "$TMP_DIR" --agents-home "$TMP_DIR/.agents" --yes
  [ "$status" -eq 0 ]
  run node "$SCRIPT" install kramme-connect-workflow --to codex --codex-home "$TMP_DIR" --agents-home "$TMP_DIR/.agents" --yes
  [ "$status" -eq 0 ]

  rm "$TMP_DIR/.codex/.kramme-install-state.json"

  run node "$SCRIPT" install kramme-connect-workflow --to codex --codex-home "$TMP_DIR" --agents-home "$TMP_DIR/.agents" --yes
  [ "$status" -eq 0 ]
  [ -f "$TMP_DIR/.codex/skills/kramme:pr:create/SKILL.md" ]
  [ -f "$TMP_DIR/.codex/skills/kramme:connect:migrate-store-ngrx/SKILL.md" ]
}

@test "codex conversion cleans stale same-plugin skills after state loss" {
  if ! command -v node >/dev/null 2>&1; then
    skip "node is required for converter tests"
  fi

  PLUGIN_DIR="$TMP_DIR/state-loss-plugin"
  mkdir -p "$PLUGIN_DIR/.claude-plugin" "$PLUGIN_DIR/commands"
  cat > "$PLUGIN_DIR/.claude-plugin/plugin.json" <<'JSON'
{
  "name": "state-loss-plugin",
  "version": "1.0.0",
  "agents": [],
  "commands": [],
  "skills": []
}
JSON
  cat > "$PLUGIN_DIR/commands/kramme-old-skill.md" <<'MD'
---
name: kramme:old-skill
description: Old skill
---

Old skill.
MD

  run node "$SCRIPT" install "$PLUGIN_DIR" --to codex --codex-home "$TMP_DIR" --agents-home "$TMP_DIR/.agents"
  [ "$status" -eq 0 ]
  [ -f "$TMP_DIR/.codex/skills/kramme:old-skill/SKILL.md" ]

  rm "$TMP_DIR/.codex/.kramme-install-state.json"
  rm "$PLUGIN_DIR/commands/kramme-old-skill.md"
  cat > "$PLUGIN_DIR/commands/kramme-new-skill.md" <<'MD'
---
name: kramme:new-skill
description: New skill
---

New skill.
MD

  run node "$SCRIPT" install "$PLUGIN_DIR" --to codex --codex-home "$TMP_DIR" --agents-home "$TMP_DIR/.agents" --yes
  [ "$status" -eq 0 ]
  [ ! -f "$TMP_DIR/.codex/skills/kramme:old-skill/SKILL.md" ]
  [ -f "$TMP_DIR/.codex/skills/kramme:new-skill/SKILL.md" ]
}

@test "opencode conversion preserves workflow skills when connect plugin is installed" {
  if ! command -v node >/dev/null 2>&1; then
    skip "node is required for converter tests"
  fi

  run node "$SCRIPT" install kramme-cc-workflow --to opencode --output "$TMP_DIR/opencode" --yes
  [ "$status" -eq 0 ]
  [ -f "$TMP_DIR/opencode/opencode.json" ]
  [ -f "$TMP_DIR/opencode/skills/kramme:pr:create/SKILL.md" ]

  run node "$SCRIPT" install kramme-connect-workflow --to opencode --output "$TMP_DIR/opencode" --yes
  [ "$status" -eq 0 ]
  [ -f "$TMP_DIR/opencode/skills/kramme:pr:create/SKILL.md" ]
  [ -f "$TMP_DIR/opencode/skills/kramme:connect:migrate-store-ngrx/SKILL.md" ]
}

@test "opencode conversion preserves existing workflow skills when reinstalling without state" {
  if ! command -v node >/dev/null 2>&1; then
    skip "node is required for converter tests"
  fi

  run node "$SCRIPT" install kramme-cc-workflow --to opencode --output "$TMP_DIR/opencode" --yes
  [ "$status" -eq 0 ]
  run node "$SCRIPT" install kramme-connect-workflow --to opencode --output "$TMP_DIR/opencode" --yes
  [ "$status" -eq 0 ]

  rm "$TMP_DIR/opencode/.kramme-install-state.json"

  run node "$SCRIPT" install kramme-connect-workflow --to opencode --output "$TMP_DIR/opencode" --yes
  [ "$status" -eq 0 ]
  [ -f "$TMP_DIR/opencode/skills/kramme:pr:create/SKILL.md" ]
  [ -f "$TMP_DIR/opencode/skills/kramme:connect:migrate-store-ngrx/SKILL.md" ]
}

@test "opencode conversion preserves unknown legacy skills on first stateful install without state" {
  if ! command -v node >/dev/null 2>&1; then
    skip "node is required for converter tests"
  fi

  mkdir -p "$TMP_DIR/opencode/skills/kramme:obsolete-skill"
  echo "old" > "$TMP_DIR/opencode/skills/kramme:obsolete-skill/SKILL.md"

  run node "$SCRIPT" install "$REPO_ROOT" --to opencode --output "$TMP_DIR/opencode" --yes
  [ "$status" -eq 0 ]
  [ -d "$TMP_DIR/opencode/skills/kramme:obsolete-skill" ]
  [ -f "$TMP_DIR/opencode/.kramme-install-state.json" ]
}

@test "opencode conversion cleans stale skills when switching between equivalent output roots" {
  if ! command -v node >/dev/null 2>&1; then
    skip "node is required for converter tests"
  fi

  local plugin_v1="$TMP_DIR/alias-plugin-v1"
  local plugin_v2="$TMP_DIR/alias-plugin-v2"
  create_fixture_plugin "$plugin_v1" "alias-plugin"
  create_fixture_plugin "$plugin_v2" "alias-plugin"

  mkdir -p "$plugin_v1/skills/demo"
  cat > "$plugin_v1/skills/demo/SKILL.md" <<'MD'
---
name: kramme:demo
description: Demo skill
disable-model-invocation: false
user-invocable: true
---
Demo.
MD

  run node "$SCRIPT" install "$plugin_v1" --to opencode --output "$TMP_DIR/opencode-root" --yes
  [ "$status" -eq 0 ]
  [ -d "$TMP_DIR/opencode-root/.opencode/skills/kramme:demo" ]

  run node "$SCRIPT" install "$plugin_v2" --to opencode --output "$TMP_DIR/opencode-root/.opencode" --yes
  [ "$status" -eq 0 ]
  [ ! -d "$TMP_DIR/opencode-root/.opencode/skills/kramme:demo" ]
}

@test "opencode conversion falls back to legacy parent-root state when switching to hidden output root" {
  if ! command -v node >/dev/null 2>&1; then
    skip "node is required for converter tests"
  fi

  local plugin_v1="$TMP_DIR/legacy-alias-plugin-v1"
  local plugin_v2="$TMP_DIR/legacy-alias-plugin-v2"
  create_fixture_plugin "$plugin_v1" "legacy-alias-plugin"
  create_fixture_plugin "$plugin_v2" "legacy-alias-plugin"

  mkdir -p "$plugin_v1/skills/demo"
  cat > "$plugin_v1/skills/demo/SKILL.md" <<'MD'
---
name: kramme:demo
description: Demo skill
disable-model-invocation: false
user-invocable: true
---
Demo.
MD

  run node "$SCRIPT" install "$plugin_v1" --to opencode --output "$TMP_DIR/opencode-root" --yes
  [ "$status" -eq 0 ]
  [ -d "$TMP_DIR/opencode-root/.opencode/skills/kramme:demo" ]

  mv "$TMP_DIR/opencode-root/.opencode/.kramme-install-state.json" "$TMP_DIR/opencode-root/.kramme-install-state.json"
  mv "$TMP_DIR/opencode-root/.opencode/.kramme-install-manifests" "$TMP_DIR/opencode-root/.kramme-install-manifests"

  run node "$SCRIPT" install "$plugin_v2" --to opencode --output "$TMP_DIR/opencode-root/.opencode" --yes
  [ "$status" -eq 0 ]
  [ ! -d "$TMP_DIR/opencode-root/.opencode/skills/kramme:demo" ]
  [ -f "$TMP_DIR/opencode-root/.opencode/.kramme-install-state.json" ]
}

@test "--also opencode writes to the requested output root" {
  if ! command -v node >/dev/null 2>&1; then
    skip "node is required for converter tests"
  fi

  run node "$SCRIPT" install kramme-cc-workflow --to codex --also opencode --output "$TMP_DIR/opencode-root" --codex-home "$TMP_DIR/.codex" --agents-home "$TMP_DIR/.agents" --yes
  [ "$status" -eq 0 ]
  [ -f "$TMP_DIR/opencode-root/opencode.json" ]
  [ ! -f "$TMP_DIR/opencode-root/opencode/opencode.json" ]
}

@test "opencode conversion includes command entries from skills" {
  if ! command -v node >/dev/null 2>&1; then
    skip "node is required for converter tests"
  fi

  run node "$SCRIPT" install "$REPO_ROOT" --to opencode --output "$TMP_DIR"
  [ "$status" -eq 0 ]
  [ -f "$TMP_DIR/opencode.json" ]

  run jq -r '.command | has("kramme:pr:create")' "$TMP_DIR/opencode.json"
  [ "$status" -eq 0 ]
  [ "$output" = "true" ]
}

@test "opencode conversion installs hooks and injects plugin root for hook commands" {
  if ! command -v node >/dev/null 2>&1; then
    skip "node is required for converter tests"
  fi

  run node "$SCRIPT" install "$REPO_ROOT" --to opencode --output "$TMP_DIR/opencode" --yes
  [ "$status" -eq 0 ]

  [ -f "$TMP_DIR/opencode/hook-bundles/kramme-cc-workflow/hooks/block-rm-rf.sh" ]
  [ -f "$TMP_DIR/opencode/hook-bundles/kramme-cc-workflow/hooks/lib/check-enabled.sh" ]

  [ -f "$TMP_DIR/opencode/plugins/converted-hooks-kramme-cc-workflow.ts" ]

  run grep -nF 'hook-bundles", "kramme-cc-workflow"' "$TMP_DIR/opencode/plugins/converted-hooks-kramme-cc-workflow.ts"
  [ "$status" -eq 0 ]

  run grep -nE 'CLAUDE_PLUGIN_ROOT="\$\{claudePluginRoot\}" bash "\$\{claudePluginRoot\}"/hooks/block-rm-rf.sh' "$TMP_DIR/opencode/plugins/converted-hooks-kramme-cc-workflow.ts"
  [ "$status" -eq 0 ]

  run grep -n '\${CLAUDE_PLUGIN_ROOT}/hooks/block-rm-rf.sh' "$TMP_DIR/opencode/plugins/converted-hooks-kramme-cc-workflow.ts"
  [ "$status" -eq 1 ]
}

@test "opencode conversion quotes hook script paths when output root contains spaces" {
  if ! command -v node >/dev/null 2>&1; then
    skip "node is required for converter tests"
  fi

  OUTPUT_ROOT="$TMP_DIR/opencode root"

  run node "$SCRIPT" install "$REPO_ROOT" --to opencode --output "$OUTPUT_ROOT" --yes
  [ "$status" -eq 0 ]

  [ -f "$OUTPUT_ROOT/.opencode/plugins/converted-hooks-kramme-cc-workflow.ts" ]

  run grep -nE 'CLAUDE_PLUGIN_ROOT="\$\{claudePluginRoot\}" bash "\$\{claudePluginRoot\}"/hooks/block-rm-rf.sh' "$OUTPUT_ROOT/.opencode/plugins/converted-hooks-kramme-cc-workflow.ts"
  [ "$status" -eq 0 ]

  run grep -nE 'bash \$\{claudePluginRoot\}/hooks/block-rm-rf.sh' "$OUTPUT_ROOT/.opencode/plugins/converted-hooks-kramme-cc-workflow.ts"
  [ "$status" -eq 1 ]
}

@test "opencode conversion preserves already-quoted CLAUDE_PLUGIN_ROOT hook commands" {
  if ! command -v node >/dev/null 2>&1; then
    skip "node is required for converter tests"
  fi

  PLUGIN_DIR="$TMP_DIR/quoted-hook-plugin"
  create_hook_fixture_plugin "$PLUGIN_DIR" "quoted-hook-plugin" "quoted-hook" 'bash "${CLAUDE_PLUGIN_ROOT}"/hooks/quoted-hook.sh'

  OUTPUT_ROOT="$TMP_DIR/opencode root"
  run node "$SCRIPT" install "$PLUGIN_DIR" --to opencode --output "$OUTPUT_ROOT" --yes
  [ "$status" -eq 0 ]

  local converted_plugin="$OUTPUT_ROOT/.opencode/plugins/converted-hooks-quoted-hook-plugin.ts"
  [ -f "$converted_plugin" ]

  run grep -nF 'bash "${claudePluginRoot}"/hooks/quoted-hook.sh' "$converted_plugin"
  [ "$status" -eq 0 ]

  run grep -nF 'bash ""${claudePluginRoot}""/hooks/quoted-hook.sh' "$converted_plugin"
  [ "$status" -eq 1 ]

  run grep -nF 'shellEscapeForDoubleQuotes' "$converted_plugin"
  [ "$status" -eq 1 ]
}

@test "opencode conversion normalizes single-quoted CLAUDE_PLUGIN_ROOT hook commands" {
  if ! command -v node >/dev/null 2>&1; then
    skip "node is required for converter tests"
  fi

  PLUGIN_DIR="$TMP_DIR/single-quoted-hook-plugin"
  create_hook_fixture_plugin "$PLUGIN_DIR" "single-quoted-hook-plugin" "quoted-hook" "bash '\${CLAUDE_PLUGIN_ROOT}'/hooks/quoted-hook.sh"

  OUTPUT_ROOT="$(printf "%s/opencode'root" "$TMP_DIR")"
  run node "$SCRIPT" install "$PLUGIN_DIR" --to opencode --output "$OUTPUT_ROOT" --yes
  [ "$status" -eq 0 ]

  local converted_plugin="$OUTPUT_ROOT/.opencode/plugins/converted-hooks-single-quoted-hook-plugin.ts"
  [ -f "$converted_plugin" ]

  run grep -nF 'bash "${claudePluginRoot}"/hooks/quoted-hook.sh' "$converted_plugin"
  [ "$status" -eq 0 ]

  run grep -nF "bash '\${claudePluginRoot}'/hooks/quoted-hook.sh" "$converted_plugin"
  [ "$status" -eq 1 ]
}

@test "opencode conversion keeps whole single-quoted CLAUDE_PLUGIN_ROOT paths interpolated" {
  if ! command -v node >/dev/null 2>&1; then
    skip "node is required for converter tests"
  fi

  PLUGIN_DIR="$TMP_DIR/single-quoted-whole-path-plugin"
  create_hook_fixture_plugin "$PLUGIN_DIR" "single-quoted-whole-path-plugin" "quoted-hook" "bash '\${CLAUDE_PLUGIN_ROOT}/hooks/quoted-hook.sh'"

  OUTPUT_ROOT="$(printf "%s/opencode'root" "$TMP_DIR")"
  run node "$SCRIPT" install "$PLUGIN_DIR" --to opencode --output "$OUTPUT_ROOT" --yes
  [ "$status" -eq 0 ]

  local converted_plugin="$OUTPUT_ROOT/.opencode/plugins/converted-hooks-single-quoted-whole-path-plugin.ts"
  [ -f "$converted_plugin" ]

  run grep -nF 'bash "${claudePluginRoot}"'\''/hooks/quoted-hook.sh'\''' "$converted_plugin"
  [ "$status" -eq 0 ]

  run grep -nF "bash '\${claudePluginRoot}/hooks/quoted-hook.sh'" "$converted_plugin"
  [ "$status" -eq 1 ]
}

@test "opencode conversion preserves nested single-quoted CLAUDE_PLUGIN_ROOT paths inside double-quoted commands" {
  if ! command -v node >/dev/null 2>&1; then
    skip "node is required for converter tests"
  fi

  PLUGIN_DIR="$TMP_DIR/nested-quoted-path-plugin"
  create_hook_fixture_plugin \
    "$PLUGIN_DIR" \
    "nested-quoted-path-plugin" \
    "quoted-hook" \
    "bash -lc \"printf %s '\${CLAUDE_PLUGIN_ROOT}/hooks/quoted-hook.sh'\""

  OUTPUT_ROOT="$TMP_DIR/opencode root"
  run node "$SCRIPT" install "$PLUGIN_DIR" --to opencode --output "$OUTPUT_ROOT" --yes
  [ "$status" -eq 0 ]

  local converted_plugin="$OUTPUT_ROOT/.opencode/plugins/converted-hooks-nested-quoted-path-plugin.ts"
  [ -f "$converted_plugin" ]

  run grep -nF 'bash -lc "printf %s '\''${claudePluginRoot}/hooks/quoted-hook.sh'\''"' "$converted_plugin"
  [ "$status" -eq 0 ]

  run grep -nF '""${claudePluginRoot}""' "$converted_plugin"
  [ "$status" -eq 1 ]
}

@test "opencode conversion bootstraps copied hook scripts for env -i wrappers" {
  if ! command -v node >/dev/null 2>&1; then
    skip "node is required for converter tests"
  fi

  PLUGIN_DIR="$TMP_DIR/env-plugin"
  create_hook_fixture_plugin \
    "$PLUGIN_DIR" \
    "env-plugin" \
    "env-hook" \
    "env -i bash \${CLAUDE_PLUGIN_ROOT}/hooks/env-hook.sh" \
    $'#!/bin/bash\nsource "${CLAUDE_PLUGIN_ROOT}/hooks/lib/check-enabled.sh"\nexit_if_hook_disabled "env-hook"\necho ok'

  run node "$SCRIPT" install "$PLUGIN_DIR" --to opencode --output "$TMP_DIR/opencode" --yes
  [ "$status" -eq 0 ]

  run grep -nF '# kramme hook bundle bootstrap start' "$TMP_DIR/opencode/hook-bundles/env-plugin/hooks/env-hook.sh"
  [ "$status" -eq 0 ]

  run grep -nF '_claude_hook_source="${BASH_SOURCE:-$0}"' "$TMP_DIR/opencode/hook-bundles/env-plugin/hooks/env-hook.sh"
  [ "$status" -eq 0 ]

  run env -i bash "$TMP_DIR/opencode/hook-bundles/env-plugin/hooks/env-hook.sh"
  [ "$status" -eq 0 ]
  [ "$output" = "ok" ]
}

@test "opencode conversion bootstraps nested hook scripts for env -i wrappers" {
  if ! command -v node >/dev/null 2>&1; then
    skip "node is required for converter tests"
  fi

  PLUGIN_DIR="$TMP_DIR/nested-env-plugin"
  create_hook_fixture_plugin \
    "$PLUGIN_DIR" \
    "nested-env-plugin" \
    "lib/child" \
    "env -i dash \${CLAUDE_PLUGIN_ROOT}/hooks/lib/child.sh" \
    $'#!/bin/sh\n. "${CLAUDE_PLUGIN_ROOT}/hooks/lib/check-enabled.sh"\nexit_if_hook_disabled "child"\necho ok'

  run node "$SCRIPT" install "$PLUGIN_DIR" --to opencode --output "$TMP_DIR/opencode" --yes
  [ "$status" -eq 0 ]

  run grep -nF '# kramme hook bundle bootstrap start' "$TMP_DIR/opencode/hook-bundles/nested-env-plugin/hooks/lib/child.sh"
  [ "$status" -eq 0 ]

  run grep -nF '_claude_hook_source="${BASH_SOURCE:-$0}"' "$TMP_DIR/opencode/hook-bundles/nested-env-plugin/hooks/lib/child.sh"
  [ "$status" -eq 0 ]

  run grep -nF '"$_claude_hook_dir/../.."' "$TMP_DIR/opencode/hook-bundles/nested-env-plugin/hooks/lib/child.sh"
  [ "$status" -eq 0 ]

  run env -i dash "$TMP_DIR/opencode/hook-bundles/nested-env-plugin/hooks/lib/child.sh"
  [ "$status" -eq 0 ]
  [ "$output" = "ok" ]
}

@test "opencode conversion copies root hooks for inline manifest hook configs" {
  if ! command -v node >/dev/null 2>&1; then
    skip "node is required for converter tests"
  fi

  PLUGIN_DIR="$TMP_DIR/inline-hooks-plugin"
  create_fixture_plugin "$PLUGIN_DIR" "inline-hooks-plugin"
  mkdir -p "$PLUGIN_DIR/hooks/lib"

  cat > "$PLUGIN_DIR/.claude-plugin/plugin.json" <<'JSON'
{
  "name": "inline-hooks-plugin",
  "version": "1.0.0",
  "agents": [],
  "commands": [],
  "skills": [],
  "hooks": {
    "hooks": {
      "PreToolUse": [
        {
          "matcher": "Bash",
          "hooks": [
            {
              "type": "command",
              "command": "env -i bash ${CLAUDE_PLUGIN_ROOT}/hooks/inline-hook.sh"
            }
          ]
        }
      ]
    }
  }
}
JSON

  cat > "$PLUGIN_DIR/hooks/inline-hook.sh" <<'SH'
#!/bin/bash
source "${CLAUDE_PLUGIN_ROOT}/hooks/lib/check-enabled.sh"
exit_if_hook_disabled "inline-hook"
echo ok
SH

  cat > "$PLUGIN_DIR/hooks/lib/check-enabled.sh" <<'SH'
#!/bin/bash
exit_if_hook_disabled() {
  return 0
}
SH

  run node "$SCRIPT" install "$PLUGIN_DIR" --to opencode --output "$TMP_DIR/opencode" --yes
  [ "$status" -eq 0 ]

  [ -f "$TMP_DIR/opencode/hook-bundles/inline-hooks-plugin/hooks/inline-hook.sh" ]

  run grep -nF '# kramme hook bundle bootstrap start' "$TMP_DIR/opencode/hook-bundles/inline-hooks-plugin/hooks/inline-hook.sh"
  [ "$status" -eq 0 ]

  run env -i bash "$TMP_DIR/opencode/hook-bundles/inline-hooks-plugin/hooks/inline-hook.sh"
  [ "$status" -eq 0 ]
  [ "$output" = "ok" ]
}

@test "opencode conversion cleans legacy converted-hooks plugin for same hook-enabled plugin upgrades" {
  if ! command -v node >/dev/null 2>&1; then
    skip "node is required for converter tests"
  fi

  FIXTURE_PLUGIN="$TMP_DIR/hook-plugin"
  create_hook_fixture_plugin \
    "$FIXTURE_PLUGIN" \
    "hook-plugin" \
    "alpha-hook" \
    'bash ${CLAUDE_PLUGIN_ROOT}/hooks/alpha-hook.sh'
  mkdir -p "$TMP_DIR/opencode/plugins"
  cat > "$TMP_DIR/opencode/plugins/converted-hooks.ts" <<'TS'
import type { Plugin } from "@opencode-ai/plugin"

export const ConvertedHooks: Plugin = async ({ $ }) => {
  return {
    "tool.execute.before": async (input) => {
      if (input.tool === "bash") { await $`bash \${CLAUDE_PLUGIN_ROOT}/hooks/alpha-hook.sh` }
    }
  }
}

export default ConvertedHooks
TS

  run node "$SCRIPT" install "$FIXTURE_PLUGIN" --to opencode --output "$TMP_DIR/opencode" --yes
  [ "$status" -eq 0 ]

  [ ! -f "$TMP_DIR/opencode/plugins/converted-hooks.ts" ]
  [ -f "$TMP_DIR/opencode/plugins/converted-hooks-hook-plugin.ts" ]
}

@test "opencode conversion preserves legacy converted-hooks plugin for unrelated hook-enabled installs" {
  if ! command -v node >/dev/null 2>&1; then
    skip "node is required for converter tests"
  fi

  PLUGIN_A="$TMP_DIR/plugin-a"
  PLUGIN_B="$TMP_DIR/plugin-b"
  create_hook_fixture_plugin \
    "$PLUGIN_A" \
    "plugin-a" \
    "alpha-hook" \
    'bash ${CLAUDE_PLUGIN_ROOT}/hooks/alpha-hook.sh'
  create_hook_fixture_plugin \
    "$PLUGIN_B" \
    "plugin-b" \
    "beta-hook" \
    'bash ${CLAUDE_PLUGIN_ROOT}/hooks/beta-hook.sh'

  mkdir -p "$TMP_DIR/opencode/plugins"
  cat > "$TMP_DIR/opencode/plugins/converted-hooks.ts" <<'TS'
import type { Plugin } from "@opencode-ai/plugin"

export const ConvertedHooks: Plugin = async ({ $ }) => {
  return {
    "tool.execute.before": async (input) => {
      if (input.tool === "bash") { await $`bash \${CLAUDE_PLUGIN_ROOT}/hooks/alpha-hook.sh` }
    }
  }
}

export default ConvertedHooks
TS

  run node "$SCRIPT" install "$PLUGIN_B" --to opencode --output "$TMP_DIR/opencode" --yes
  [ "$status" -eq 0 ]

  [ -f "$TMP_DIR/opencode/plugins/converted-hooks.ts" ]
  [ -f "$TMP_DIR/opencode/plugins/converted-hooks-plugin-b.ts" ]
}

@test "opencode conversion preserves legacy converted-hooks plugin when hook overlap is only partial" {
  if ! command -v node >/dev/null 2>&1; then
    skip "node is required for converter tests"
  fi

  PLUGIN_A="$TMP_DIR/plugin-a"
  PLUGIN_B="$TMP_DIR/plugin-b"
  create_hook_fixture_plugin "$PLUGIN_A" "plugin-a" "shared"
  create_hook_fixture_plugin "$PLUGIN_B" "plugin-b" "shared"

  jq -n '{
    hooks: {
      PreToolUse: [
        {
          matcher: "Bash",
          hooks: [
            {type: "command", command: "bash ${CLAUDE_PLUGIN_ROOT}/hooks/shared.sh"},
            {type: "command", command: "bash ${CLAUDE_PLUGIN_ROOT}/hooks/a-only.sh"}
          ]
        }
      ]
    }
  }' > "$PLUGIN_A/hooks/hooks.json"
  jq -n '{
    hooks: {
      PreToolUse: [
        {
          matcher: "Bash",
          hooks: [
            {type: "command", command: "bash ${CLAUDE_PLUGIN_ROOT}/hooks/shared.sh"},
            {type: "command", command: "bash ${CLAUDE_PLUGIN_ROOT}/hooks/b-only.sh"}
          ]
        }
      ]
    }
  }' > "$PLUGIN_B/hooks/hooks.json"
  printf '#!/bin/bash\nexit 0\n' > "$PLUGIN_A/hooks/a-only.sh"
  printf '#!/bin/bash\nexit 0\n' > "$PLUGIN_B/hooks/b-only.sh"

  mkdir -p "$TMP_DIR/opencode/plugins"
  cat > "$TMP_DIR/opencode/plugins/converted-hooks.ts" <<'TS'
import type { Plugin } from "@opencode-ai/plugin"

export const ConvertedHooks: Plugin = async ({ $ }) => {
  return {
    "tool.execute.before": async (input) => {
      if (input.tool === "bash") { await $`bash \${CLAUDE_PLUGIN_ROOT}/hooks/shared.sh` }
      if (input.tool === "bash") { await $`bash \${CLAUDE_PLUGIN_ROOT}/hooks/a-only.sh` }
    }
  }
}

export default ConvertedHooks
TS

  run node "$SCRIPT" install "$PLUGIN_B" --to opencode --output "$TMP_DIR/opencode" --yes
  [ "$status" -eq 0 ]

  [ -f "$TMP_DIR/opencode/plugins/converted-hooks.ts" ]
  [ -f "$TMP_DIR/opencode/plugins/converted-hooks-plugin-b.ts" ]
}

@test "opencode conversion preserves legacy converted-hooks plugin when current hook set is a subset of another plugin" {
  if ! command -v node >/dev/null 2>&1; then
    skip "node is required for converter tests"
  fi

  PLUGIN_A="$TMP_DIR/plugin-a"
  PLUGIN_B="$TMP_DIR/plugin-b"
  create_hook_fixture_plugin "$PLUGIN_A" "plugin-a" "shared"
  create_hook_fixture_plugin "$PLUGIN_B" "plugin-b" "shared"

  jq -n '{
    hooks: {
      PreToolUse: [
        {
          matcher: "Bash",
          hooks: [
            {type: "command", command: "bash ${CLAUDE_PLUGIN_ROOT}/hooks/shared.sh"},
            {type: "command", command: "bash ${CLAUDE_PLUGIN_ROOT}/hooks/b-only.sh"}
          ]
        }
      ]
    }
  }' > "$PLUGIN_B/hooks/hooks.json"
  printf '#!/bin/bash\nexit 0\n' > "$PLUGIN_B/hooks/b-only.sh"

  mkdir -p "$TMP_DIR/opencode/plugins"
  cat > "$TMP_DIR/opencode/plugins/converted-hooks.ts" <<'TS'
import type { Plugin } from "@opencode-ai/plugin"

export const ConvertedHooks: Plugin = async ({ $ }) => {
  return {
    "tool.execute.before": async (input) => {
      if (input.tool === "bash") { await $`bash \${CLAUDE_PLUGIN_ROOT}/hooks/shared.sh` }
      if (input.tool === "bash") { await $`bash \${CLAUDE_PLUGIN_ROOT}/hooks/b-only.sh` }
    }
  }
}

export default ConvertedHooks
TS

  run node "$SCRIPT" install "$PLUGIN_A" --to opencode --output "$TMP_DIR/opencode" --yes
  [ "$status" -eq 0 ]

  [ -f "$TMP_DIR/opencode/plugins/converted-hooks.ts" ]
  [ -f "$TMP_DIR/opencode/plugins/converted-hooks-plugin-a.ts" ]
}

@test "opencode conversion cleans legacy converted-hooks plugin for hookless same-plugin upgrades" {
  if ! command -v node >/dev/null 2>&1; then
    skip "node is required for converter tests"
  fi

  FIXTURE_PLUGIN="$TMP_DIR/hookless-plugin"
  create_fixture_plugin "$FIXTURE_PLUGIN" "hookless-plugin"
  mkdir -p "$FIXTURE_PLUGIN/skills/example-skill" "$TMP_DIR/opencode/skills/hookless:example" "$TMP_DIR/opencode/plugins"
  cat > "$FIXTURE_PLUGIN/skills/example-skill/SKILL.md" <<'MD'
---
name: hookless:example
description: Example hookless skill
disable-model-invocation: false
user-invocable: true
---
Example body
MD
  printf 'legacy plugin\n' > "$TMP_DIR/opencode/plugins/converted-hooks.ts"

  run node "$SCRIPT" install "$FIXTURE_PLUGIN" --to opencode --output "$TMP_DIR/opencode" --yes
  [ "$status" -eq 0 ]

  [ ! -f "$TMP_DIR/opencode/plugins/converted-hooks.ts" ]
}

@test "opencode conversion cleans legacy hook artifacts for hook-enabled to hookless same-plugin upgrades" {
  if ! command -v node >/dev/null 2>&1; then
    skip "node is required for converter tests"
  fi

  FIXTURE_PLUGIN="$TMP_DIR/hookless-plugin-from-hooked-upgrade"
  create_fixture_plugin "$FIXTURE_PLUGIN" "hookless-plugin-from-hooked-upgrade"
  mkdir -p "$TMP_DIR/opencode/plugins" "$TMP_DIR/opencode/hook-bundles/hookless-plugin-from-hooked-upgrade/hooks"
  printf '#!/bin/bash\nexit 0\n' > "$TMP_DIR/opencode/hook-bundles/hookless-plugin-from-hooked-upgrade/hooks/alpha-hook.sh"
  printf 'legacy plugin\n' > "$TMP_DIR/opencode/plugins/converted-hooks.ts"

  run node "$SCRIPT" install "$FIXTURE_PLUGIN" --to opencode --output "$TMP_DIR/opencode" --yes
  [ "$status" -eq 0 ]

  [ ! -f "$TMP_DIR/opencode/plugins/converted-hooks.ts" ]
  [ ! -d "$TMP_DIR/opencode/hook-bundles/hookless-plugin-from-hooked-upgrade" ]
}

@test "opencode conversion preserves legacy converted-hooks plugin after tracked hookless reinstall" {
  if ! command -v node >/dev/null 2>&1; then
    skip "node is required for converter tests"
  fi

  FIXTURE_PLUGIN="$TMP_DIR/hookless-plugin-with-state"
  create_fixture_plugin "$FIXTURE_PLUGIN" "hookless-plugin-with-state"
  mkdir -p "$FIXTURE_PLUGIN/skills/example-skill"
  cat > "$FIXTURE_PLUGIN/skills/example-skill/SKILL.md" <<'MD'
---
name: hookless:example
description: Example hookless skill
disable-model-invocation: false
user-invocable: true
---
Example body
MD

  run node "$SCRIPT" install "$FIXTURE_PLUGIN" --to opencode --output "$TMP_DIR/opencode" --yes
  [ "$status" -eq 0 ]

  mkdir -p "$TMP_DIR/opencode/plugins"
  printf 'legacy plugin\n' > "$TMP_DIR/opencode/plugins/converted-hooks.ts"

  run node "$SCRIPT" install "$FIXTURE_PLUGIN" --to opencode --output "$TMP_DIR/opencode" --yes
  [ "$status" -eq 0 ]

  [ -f "$TMP_DIR/opencode/plugins/converted-hooks.ts" ]
}

@test "opencode conversion preserves legacy converted-hooks plugin for unrelated hookless installs" {
  if ! command -v node >/dev/null 2>&1; then
    skip "node is required for converter tests"
  fi

  FIXTURE_PLUGIN="$TMP_DIR/unrelated-hookless-plugin"
  create_fixture_plugin "$FIXTURE_PLUGIN" "unrelated-hookless-plugin"
  mkdir -p "$FIXTURE_PLUGIN/skills/example-skill" "$TMP_DIR/opencode/skills/workflow-example" "$TMP_DIR/opencode/plugins"
  cat > "$FIXTURE_PLUGIN/skills/example-skill/SKILL.md" <<'MD'
---
name: unrelated:example
description: Example unrelated hookless skill
disable-model-invocation: false
user-invocable: true
---
Example body
MD
  printf 'legacy plugin\n' > "$TMP_DIR/opencode/plugins/converted-hooks.ts"

  run node "$SCRIPT" install "$FIXTURE_PLUGIN" --to opencode --output "$TMP_DIR/opencode" --yes
  [ "$status" -eq 0 ]

  [ -f "$TMP_DIR/opencode/plugins/converted-hooks.ts" ]
}

@test "opencode conversion preserves existing hook-enabled plugin installs" {
  if ! command -v node >/dev/null 2>&1; then
    skip "node is required for converter tests"
  fi

  PLUGIN_A="$TMP_DIR/plugin-a"
  PLUGIN_B="$TMP_DIR/plugin-b"
  create_hook_fixture_plugin "$PLUGIN_A" "plugin-a" "alpha-hook"
  create_hook_fixture_plugin "$PLUGIN_B" "plugin-b" "beta-hook"

  run node "$SCRIPT" install "$PLUGIN_A" --to opencode --output "$TMP_DIR/opencode" --yes
  [ "$status" -eq 0 ]

  run node "$SCRIPT" install "$PLUGIN_B" --to opencode --output "$TMP_DIR/opencode" --yes
  [ "$status" -eq 0 ]

  [ -f "$TMP_DIR/opencode/hook-bundles/plugin-a/hooks/alpha-hook.sh" ]
  [ -f "$TMP_DIR/opencode/hook-bundles/plugin-b/hooks/beta-hook.sh" ]
  [ -f "$TMP_DIR/opencode/plugins/converted-hooks-plugin-a.ts" ]
  [ -f "$TMP_DIR/opencode/plugins/converted-hooks-plugin-b.ts" ]

  run grep -n 'alpha-hook\.sh' "$TMP_DIR/opencode/plugins/converted-hooks-plugin-a.ts"
  [ "$status" -eq 0 ]

  run grep -n 'beta-hook\.sh' "$TMP_DIR/opencode/plugins/converted-hooks-plugin-b.ts"
  [ "$status" -eq 0 ]
}

@test "opencode conversion preserves legacy shared hook plugin when ownership is ambiguous" {
  if ! command -v node >/dev/null 2>&1; then
    skip "node is required for converter tests"
  fi

  mkdir -p "$TMP_DIR/opencode/plugins"
  echo "old" > "$TMP_DIR/opencode/plugins/converted-hooks.ts"

  run node "$SCRIPT" install "$REPO_ROOT" --to opencode --output "$TMP_DIR/opencode" --yes
  [ "$status" -eq 0 ]

  [ -f "$TMP_DIR/opencode/plugins/converted-hooks.ts" ]
  [ -f "$TMP_DIR/opencode/plugins/converted-hooks-kramme-cc-workflow.ts" ]
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
