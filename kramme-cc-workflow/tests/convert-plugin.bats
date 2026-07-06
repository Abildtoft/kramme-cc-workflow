#!/usr/bin/env bats
# CLI smoke tests for scripts/convert-plugin.js. Converter logic lives in
# tests/node/converter-contracts.test.js.

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
	cat >"$plugin_dir/.claude-plugin/plugin.json" <<JSON
{
  "name": "$plugin_name",
  "version": "1.0.0",
  "agents": [],
  "commands": [],
  "skills": []
}
JSON
}

create_command_fixture_plugin() {
	local plugin_dir="$1"
	local plugin_name="$2"
	local command_name="$3"

	create_fixture_plugin "$plugin_dir" "$plugin_name"
	mkdir -p "$plugin_dir/commands"
	cat >"$plugin_dir/commands/${command_name//:/-}.md" <<MD
---
name: $command_name
description: Temporary command for converter CLI smoke tests
---

Execute temporary command.
MD
}

create_cleanup_fixture_plugin() {
	local plugin_dir="$1"
	local plugin_name="$2"
	local command_name="$3"
	local agent_name="$4"

	create_command_fixture_plugin "$plugin_dir" "$plugin_name" "$command_name"
	mkdir -p "$plugin_dir/agents"
	cat >"$plugin_dir/agents/${agent_name//:/-}.md" <<MD
---
name: $agent_name
description: Temporary agent for converter CLI cleanup tests
---

Review temporary command behavior.
MD
}

add_hook_control_skill_fixtures() {
	local plugin_dir="$1"

	mkdir -p "$plugin_dir/skills/kramme:hooks:toggle" "$plugin_dir/skills/kramme:hooks:configure-links"
	cat >"$plugin_dir/skills/kramme:hooks:toggle/SKILL.md" <<'MD'
---
name: kramme:hooks:toggle
description: Toggle fixture hooks.
disable-model-invocation: true
user-invocable: true
kramme-platforms: [claude-code, codex]
---
Toggle fixture hooks.
MD
	cat >"$plugin_dir/skills/kramme:hooks:configure-links/SKILL.md" <<'MD'
---
name: kramme:hooks:configure-links
description: Configure fixture hook links.
disable-model-invocation: true
user-invocable: true
kramme-platforms: [claude-code, codex]
---
Configure fixture hook links.
MD
}

create_hook_fixture_plugin() {
	local plugin_dir="$1"
	local plugin_name="$2"
	local script_name="$3"
	local hook_command="${4:-}"
	local script_body="${5:-#!/bin/bash
exit 0}"

	if [ -z "$hook_command" ]; then
		hook_command='bash ${CLAUDE_PLUGIN_ROOT}/hooks/'"$script_name"'.sh'
	fi

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
  }' >"$plugin_dir/hooks/hooks.json"

	printf '%s\n' "$script_body" >"$plugin_dir/hooks/${script_name}.sh"

	cat >"$plugin_dir/hooks/lib/check-enabled.sh" <<'SH'
#!/bin/bash
exit_if_hook_disabled() {
  return 0
}
SH

	add_hook_control_skill_fixtures "$plugin_dir"
}

resolve_node_package_dir() {
	node -e '
const fs = require("fs");
const path = require("path");
let current = path.dirname(require.resolve(process.argv[1]));
while (current !== path.dirname(current)) {
  if (fs.existsSync(path.join(current, "package.json"))) {
    console.log(current);
    process.exit(0);
  }
  current = path.dirname(current);
}
process.exit(1);
' "$1"
}

@test "install-codex helper bootstraps missing converter dependencies" {
	if ! command -v node >/dev/null 2>&1; then
		skip "node is required for converter tests"
	fi

	local yaml_dir smol_toml_dir
	yaml_dir="$(resolve_node_package_dir yaml)"
	smol_toml_dir="$(resolve_node_package_dir smol-toml)"

	local isolated="$TMP_DIR/isolated"
	mkdir -p "$isolated/.claude-plugin"
	mkdir -p "$isolated/kramme-cc-workflow/.claude-plugin"
	mkdir -p "$isolated/kramme-cc-workflow/scripts"
	cp "$REPO_ROOT/scripts/install-codex.sh" "$isolated/kramme-cc-workflow/scripts/install-codex.sh"
	cp "$REPO_ROOT/scripts/convert-plugin.js" "$isolated/kramme-cc-workflow/scripts/convert-plugin.js"
	cp -R "$REPO_ROOT/scripts/convert-plugin" "$isolated/kramme-cc-workflow/scripts/convert-plugin"
	cp -R "$REPO_ROOT/scripts/schemas" "$isolated/kramme-cc-workflow/scripts/schemas"

	cat >"$isolated/package.json" <<'JSON'
{
  "dependencies": {
    "smol-toml": "^1.7.0",
    "yaml": "^2.9.0"
  }
}
JSON
	cat >"$isolated/.claude-plugin/marketplace.json" <<'JSON'
{
  "plugins": [
    {
      "name": "kramme-cc-workflow",
      "source": "kramme-cc-workflow"
    }
  ]
}
JSON
	cat >"$isolated/kramme-cc-workflow/.claude-plugin/plugin.json" <<'JSON'
{
  "name": "kramme-cc-workflow",
  "version": "1.0.0",
  "agents": [],
  "commands": [],
  "skills": []
}
JSON

	local fakebin="$TMP_DIR/fakebin"
	mkdir -p "$fakebin"
	cat >"$fakebin/npm" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >"$NPM_CALLED"
mkdir -p node_modules
ln -s "$YAML_MODULE_DIR" node_modules/yaml
ln -s "$SMOL_TOML_MODULE_DIR" node_modules/smol-toml
SH
	chmod +x "$fakebin/npm"

	run bash -c 'cd "$1" && PATH="$2:$PATH" NPM_CALLED="$3" YAML_MODULE_DIR="$4" SMOL_TOML_MODULE_DIR="$5" "$1/kramme-cc-workflow/scripts/install-codex.sh" --codex-home "$1/output" --agents-home "$1/.agents" --yes' _ "$isolated" "$fakebin" "$TMP_DIR/npm-called" "$yaml_dir" "$smol_toml_dir"
	[ "$status" -eq 0 ]
	[ -f "$TMP_DIR/npm-called" ]
	run cat "$TMP_DIR/npm-called"
	[ "$status" -eq 0 ]
	[ "$output" = "install --omit=dev --no-audit --no-fund" ]
	[ -d "$isolated/output/.codex" ]
}

@test "codex conversion installs repository plugin to Codex and agents homes" {
	if ! command -v node >/dev/null 2>&1; then
		skip "node is required for converter tests"
	fi

	run node "$SCRIPT" install "$REPO_ROOT" --codex-home "$TMP_DIR" --agents-home "$TMP_DIR/.agents" --yes
	[ "$status" -eq 0 ]

	local plugin_version
	plugin_version="$(jq -r '.version' "$REPO_ROOT/.claude-plugin/plugin.json")"
	local marketplace_root="$TMP_DIR/.codex/.kramme-plugin-marketplaces/kramme-cc-workflow"
	local cache_root="$TMP_DIR/.codex/plugins/cache/kramme-cc-workflow/kramme-cc-workflow/$plugin_version"

	[ -f "$TMP_DIR/.codex/skills/kramme:pr:create/SKILL.md" ]
	[ -f "$TMP_DIR/.agents/skills/kramme:architecture-strategist/SKILL.md" ]
	[ -f "$TMP_DIR/.codex/AGENTS.md" ]
	[ -f "$marketplace_root/plugins/kramme-cc-workflow/scripts/dev-server/detect-url.sh" ]
	[ -f "$marketplace_root/plugins/kramme-cc-workflow/scripts/resolve-base.sh" ]
	[ -f "$marketplace_root/plugins/kramme-cc-workflow/scripts/collect-review-diff.sh" ]
	[ -f "$marketplace_root/plugins/kramme-cc-workflow/scripts/skill-usage.js" ]
	[ ! -f "$marketplace_root/plugins/kramme-cc-workflow/scripts/install-codex.sh" ]
	[ -f "$cache_root/scripts/dev-server/detect-url.sh" ]
	[ -f "$cache_root/scripts/resolve-base.sh" ]
	[ -f "$cache_root/scripts/collect-review-diff.sh" ]
	[ -f "$cache_root/scripts/skill-usage.js" ]
	[ ! -f "$cache_root/scripts/install-codex.sh" ]
	[ -f "$TMP_DIR/.codex/scripts/dev-server/detect-url.sh" ]
	[ -f "$TMP_DIR/.codex/scripts/resolve-base.sh" ]
	[ -f "$TMP_DIR/.codex/scripts/collect-review-diff.sh" ]
	[ -f "$TMP_DIR/.codex/scripts/skill-usage.js" ]

	run grep -n 'TodoWrite/TodoRead: use update_plan' "$TMP_DIR/.codex/AGENTS.md"
	[ "$status" -eq 0 ]
	run grep -RFn '${CLAUDE_PLUGIN_ROOT}/scripts/dev-server' "$TMP_DIR/.codex/skills"
	[ "$status" -eq 1 ]
	run grep -nF "RESOLVED=$('$TMP_DIR/.codex/scripts/collect-review-diff.sh' \"\${COLLECT_ARGS[@]}\")" "$TMP_DIR/.codex/skills/kramme:pr:code-review/SKILL.md"
	[ "$status" -eq 0 ]
	run grep -nF "RESOLVED=$('$TMP_DIR/.codex/scripts/resolve-base.sh' \"\${ARGS[@]}\")" "$TMP_DIR/.codex/skills/kramme:git:recreate-commits/SKILL.md"
	[ "$status" -eq 0 ]
	run grep -nF "DETECTED_PROJECT_TYPE=$('$TMP_DIR/.codex/scripts/dev-server'/detect-project-type.sh 2> /dev/null)" "$TMP_DIR/.codex/skills/kramme:qa/SKILL.md"
	[ "$status" -eq 0 ]
}

@test "codex conversion installs hooks as an enabled plugin bundle" {
	if ! command -v node >/dev/null 2>&1; then
		skip "node is required for converter tests"
	fi

	FIXTURE_PLUGIN="$TMP_DIR/hook-plugin"
	create_hook_fixture_plugin "$FIXTURE_PLUGIN" "hook-plugin" "alpha-hook"

	run node "$SCRIPT" install "$FIXTURE_PLUGIN" --to codex --codex-home "$TMP_DIR" --agents-home "$TMP_DIR/.agents" --yes
	[ "$status" -eq 0 ]

	local marketplace_root="$TMP_DIR/.codex/.kramme-plugin-marketplaces/hook-plugin"
	local cache_root="$TMP_DIR/.codex/plugins/cache/hook-plugin/hook-plugin/1.0.0"

	[ -f "$marketplace_root/.agents/plugins/marketplace.json" ]
	[ -f "$marketplace_root/plugins/hook-plugin/.codex-plugin/plugin.json" ]
	[ -f "$cache_root/.codex-plugin/plugin.json" ]
	[ -f "$cache_root/hooks/alpha-hook.sh" ]
	[ -f "$cache_root/hooks/lib/check-enabled.sh" ]
	[ -f "$TMP_DIR/.codex/skills/kramme:hooks:toggle/SKILL.md" ]
	[ -f "$TMP_DIR/.codex/skills/kramme:hooks:configure-links/SKILL.md" ]

	run jq -r '.hooks' "$cache_root/.codex-plugin/plugin.json"
	[ "$status" -eq 0 ]
	[ "$output" = "./hooks/hooks.json" ]

	run jq -r '.hooks.PreToolUse[0].hooks[0].command' "$cache_root/hooks/hooks.json"
	[ "$status" -eq 0 ]
	[ "$output" = 'bash ${CLAUDE_PLUGIN_ROOT}/hooks/alpha-hook.sh' ]

	local hook_command
	hook_command="$(jq -r '.hooks.PreToolUse[0].hooks[0].command' "$cache_root/hooks/hooks.json")"
	run bash -c 'printf "%s\n" "{\"tool_input\":{\"command\":\"echo ok\"}}" | CLAUDE_PLUGIN_ROOT="$1" bash -lc "$2"' _ "$cache_root" "$hook_command"
	[ "$status" -eq 0 ]

	run grep -nF '[plugins."hook-plugin@hook-plugin"]' "$TMP_DIR/.codex/config.toml"
	[ "$status" -eq 0 ]
	run jq -r '.pluginCaches[0]' "$TMP_DIR/.codex/.kramme-install-manifests/hook-plugin-codex.json"
	[ "$status" -eq 0 ]
	[ "$output" = "cache/hook-plugin/hook-plugin/1.0.0" ]
	run jq -r '.hookMarketplaces[0]' "$TMP_DIR/.codex/.kramme-install-manifests/hook-plugin-codex.json"
	[ "$status" -eq 0 ]
	[ "$output" = ".kramme-plugin-marketplaces/hook-plugin" ]
}

@test "codex conversion asks before replacing an untracked hook marketplace" {
	if ! command -v node >/dev/null 2>&1; then
		skip "node is required for converter tests"
	fi

	FIXTURE_PLUGIN="$TMP_DIR/untracked-hook-marketplace-plugin"
	create_hook_fixture_plugin "$FIXTURE_PLUGIN" "untracked-hook-marketplace-plugin" "alpha-hook"
	mkdir -p "$TMP_DIR/.codex/.kramme-plugin-marketplaces/untracked-hook-marketplace-plugin"
	printf 'keep\n' >"$TMP_DIR/.codex/.kramme-plugin-marketplaces/untracked-hook-marketplace-plugin/sentinel.txt"

	run node "$SCRIPT" install "$FIXTURE_PLUGIN" --to codex --codex-home "$TMP_DIR" --agents-home "$TMP_DIR/.agents" --non-interactive
	[ "$status" -eq 1 ]
	[[ "$output" == *"Refusing to overwrite existing untracked Codex hook marketplace."* ]]
	[ -f "$TMP_DIR/.codex/.kramme-plugin-marketplaces/untracked-hook-marketplace-plugin/sentinel.txt" ]
}

@test "codex conversion removes managed hook plugin output when hooks are removed" {
	if ! command -v node >/dev/null 2>&1; then
		skip "node is required for converter tests"
	fi

	FIXTURE_PLUGIN="$TMP_DIR/hookless-upgrade-plugin"
	create_hook_fixture_plugin "$FIXTURE_PLUGIN" "hookless-upgrade-plugin" "alpha-hook"

	run node "$SCRIPT" install "$FIXTURE_PLUGIN" --to codex --codex-home "$TMP_DIR" --agents-home "$TMP_DIR/.agents"
	[ "$status" -eq 0 ]
	[ -d "$TMP_DIR/.codex/.kramme-plugin-marketplaces/hookless-upgrade-plugin" ]
	[ -d "$TMP_DIR/.codex/plugins/cache/hookless-upgrade-plugin/hookless-upgrade-plugin/1.0.0" ]

	rm -r "$FIXTURE_PLUGIN/hooks"
	run node "$SCRIPT" install "$FIXTURE_PLUGIN" --to codex --codex-home "$TMP_DIR" --agents-home "$TMP_DIR/.agents" --yes
	[ "$status" -eq 0 ]
	[ ! -d "$TMP_DIR/.codex/.kramme-plugin-marketplaces/hookless-upgrade-plugin" ]
	[ ! -d "$TMP_DIR/.codex/plugins/cache/hookless-upgrade-plugin/hookless-upgrade-plugin/1.0.0" ]

	run grep -nF '[plugins."hookless-upgrade-plugin@hookless-upgrade-plugin"]' "$TMP_DIR/.codex/config.toml"
	[ "$status" -eq 1 ]

	run jq -r '.hookMarketplaces | length' "$TMP_DIR/.codex/.kramme-install-manifests/hookless-upgrade-plugin-codex.json"
	[ "$status" -eq 0 ]
	[ "$output" = "0" ]

	run jq -r '.pluginCaches | length' "$TMP_DIR/.codex/.kramme-install-manifests/hookless-upgrade-plugin-codex.json"
	[ "$status" -eq 0 ]
	[ "$output" = "0" ]
}

@test "codex conversion skips cleanup in non-interactive mode without --yes" {
	if ! command -v node >/dev/null 2>&1; then
		skip "node is required for converter tests"
	fi

	PLUGIN_DIR="$TMP_DIR/skill-plugin"
	create_cleanup_fixture_plugin "$PLUGIN_DIR" "skill-plugin" "kramme:temp-command" "kramme:temp-agent"

	run node "$SCRIPT" install "$PLUGIN_DIR" --to codex --codex-home "$TMP_DIR" --agents-home "$TMP_DIR/.agents"
	[ "$status" -eq 0 ]
	[ -f "$TMP_DIR/.codex/skills/kramme:temp-command/SKILL.md" ]
	[ -f "$TMP_DIR/.agents/skills/kramme:temp-agent/SKILL.md" ]

	rm "$PLUGIN_DIR/commands/kramme-temp-command.md"
	rm "$PLUGIN_DIR/agents/kramme-temp-agent.md"
	run node "$SCRIPT" install "$PLUGIN_DIR" --to codex --codex-home "$TMP_DIR" --agents-home "$TMP_DIR/.agents" --non-interactive
	[ "$status" -eq 0 ]
	[ -f "$TMP_DIR/.codex/skills/kramme:temp-command/SKILL.md" ]
	[ -f "$TMP_DIR/.agents/skills/kramme:temp-agent/SKILL.md" ]
	[[ "$output" == *"non-interactive mode"* ]]
	[[ "$output" == *"Skipping skill cleanup."* ]]
}

@test "converter resolves marketplace slug from parent repo root" {
	if ! command -v node >/dev/null 2>&1; then
		skip "node is required for converter tests"
	fi

	run bash -c "cd \"$TMP_DIR\" && node \"$SCRIPT\" install kramme-cc-workflow --to codex --codex-home \"$TMP_DIR/output\" --agents-home \"$TMP_DIR/.agents\" --non-interactive"
	[ "$status" -eq 0 ]
	[ -f "$TMP_DIR/output/.codex/skills/kramme:pr:create/SKILL.md" ]
}

@test "codex conversion accepts streaming yes input for cleanup confirmations" {
	if ! command -v node >/dev/null 2>&1; then
		skip "node is required for converter tests"
	fi
	if ! command -v yes >/dev/null 2>&1; then
		skip "yes is required for converter tests"
	fi

	PLUGIN_DIR="$TMP_DIR/yes-plugin"
	create_cleanup_fixture_plugin "$PLUGIN_DIR" "yes-plugin" "kramme:temp-command" "kramme:temp-agent"

	run node "$SCRIPT" install "$PLUGIN_DIR" --to codex --codex-home "$TMP_DIR" --agents-home "$TMP_DIR/.agents"
	[ "$status" -eq 0 ]
	[ -f "$TMP_DIR/.codex/skills/kramme:temp-command/SKILL.md" ]
	[ -f "$TMP_DIR/.agents/skills/kramme:temp-agent/SKILL.md" ]

	rm "$PLUGIN_DIR/commands/kramme-temp-command.md"
	rm "$PLUGIN_DIR/agents/kramme-temp-agent.md"
	run bash -c "set +e; set +o pipefail; yes | node \"$SCRIPT\" install \"$PLUGIN_DIR\" --to codex --codex-home \"$TMP_DIR\" --agents-home \"$TMP_DIR/.agents\"; exit \${PIPESTATUS[1]}"
	[ "$status" -eq 0 ]
	[ ! -f "$TMP_DIR/.codex/skills/kramme:temp-command/SKILL.md" ]
	[ ! -d "$TMP_DIR/.agents/skills/kramme:temp-agent" ]
}

@test "opencode-only install options are rejected" {
	if ! command -v node >/dev/null 2>&1; then
		skip "node is required for converter tests"
	fi

	run env HOME="$TMP_DIR/home" node "$SCRIPT" install "$REPO_ROOT" --output "$TMP_DIR/opencode" --non-interactive
	[ "$status" -ne 0 ]
	[[ "$output" == *"--output/-o is no longer supported"* ]]
	[ ! -d "$TMP_DIR/home/.codex" ]

	run env HOME="$TMP_DIR/home" node "$SCRIPT" install "$REPO_ROOT" -o "$TMP_DIR/opencode" --non-interactive
	[ "$status" -ne 0 ]
	[[ "$output" == *"--output/-o is no longer supported"* ]]

	run env HOME="$TMP_DIR/home" node "$SCRIPT" install "$REPO_ROOT" --permissions from-commands --non-interactive
	[ "$status" -ne 0 ]
	[[ "$output" == *"--permissions is no longer supported"* ]]

	run env HOME="$TMP_DIR/home" node "$SCRIPT" install "$REPO_ROOT" --agent-mode primary --non-interactive
	[ "$status" -ne 0 ]
	[[ "$output" == *"--agent-mode is no longer supported"* ]]

	run env HOME="$TMP_DIR/home" node "$SCRIPT" install "$REPO_ROOT" --infer-temperature false --non-interactive
	[ "$status" -ne 0 ]
	[[ "$output" == *"--infer-temperature is no longer supported"* ]]
}

@test "opencode target is no longer supported for install and stats" {
	if ! command -v node >/dev/null 2>&1; then
		skip "node is required for converter tests"
	fi

	run node "$SCRIPT" install "$REPO_ROOT" --to opencode --codex-home "$TMP_DIR" --agents-home "$TMP_DIR/.agents" --yes
	[ "$status" -ne 0 ]
	[[ "$output" == *"Unknown target: opencode"* ]]

	run node "$SCRIPT" stats "$REPO_ROOT" --to opencode
	[ "$status" -ne 0 ]
	[[ "$output" == *"Unknown target: opencode"* ]]
	[[ "$output" != *"codex_skills="* ]]
}
