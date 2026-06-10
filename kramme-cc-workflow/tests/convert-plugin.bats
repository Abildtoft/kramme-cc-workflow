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

create_skill_fixture_plugin() {
	local plugin_dir="$1"
	local plugin_name="$2"
	local skill_name="$3"
	local description="${4:-Fixture skill}"

	create_fixture_plugin "$plugin_dir" "$plugin_name"
	mkdir -p "$plugin_dir/skills/fixture-skill"
	cat >"$plugin_dir/skills/fixture-skill/SKILL.md" <<MD
---
name: $skill_name
description: $description
disable-model-invocation: false
user-invocable: true
---
Fixture skill body.
MD
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
  }' >"$plugin_dir/hooks/hooks.json"

	printf '%s\n' "$script_body" >"$plugin_dir/hooks/${script_name}.sh"

	cat >"$plugin_dir/hooks/lib/check-enabled.sh" <<'SH'
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

@test "codex conversion installs hooks as an enabled plugin bundle" {
	if ! command -v node >/dev/null 2>&1; then
		skip "node is required for converter tests"
	fi

	run node "$SCRIPT" install "$REPO_ROOT" --to codex --codex-home "$TMP_DIR" --agents-home "$TMP_DIR/.agents"
	[ "$status" -eq 0 ]

	local plugin_version
	plugin_version="$(jq -r '.version' "$REPO_ROOT/.claude-plugin/plugin.json")"
	local marketplace_root="$TMP_DIR/.codex/.kramme-plugin-marketplaces/kramme-cc-workflow"
	local cache_root="$TMP_DIR/.codex/plugins/cache/kramme-cc-workflow/kramme-cc-workflow/$plugin_version"

	[ -f "$marketplace_root/.agents/plugins/marketplace.json" ]
	[ -f "$marketplace_root/plugins/kramme-cc-workflow/.codex-plugin/plugin.json" ]
	[ -f "$marketplace_root/plugins/kramme-cc-workflow/hooks/block-rm-rf.sh" ]
	[ -f "$marketplace_root/plugins/kramme-cc-workflow/scripts/dev-server/detect-url.sh" ]
	[ -f "$marketplace_root/plugins/kramme-cc-workflow/scripts/resolve-base.sh" ]
	[ -f "$marketplace_root/plugins/kramme-cc-workflow/scripts/collect-review-diff.sh" ]
	[ ! -f "$marketplace_root/plugins/kramme-cc-workflow/scripts/install-codex.sh" ]
	[ -f "$cache_root/.codex-plugin/plugin.json" ]
	[ -f "$cache_root/hooks/block-rm-rf.sh" ]
	[ -f "$cache_root/hooks/lib/check-enabled.sh" ]
	[ -f "$cache_root/scripts/dev-server/detect-url.sh" ]
	[ -f "$cache_root/scripts/resolve-base.sh" ]
	[ -f "$cache_root/scripts/collect-review-diff.sh" ]
	[ ! -f "$cache_root/scripts/install-codex.sh" ]
	[ -f "$TMP_DIR/.codex/scripts/dev-server/detect-url.sh" ]
	[ -f "$TMP_DIR/.codex/scripts/resolve-base.sh" ]
	[ -f "$TMP_DIR/.codex/scripts/collect-review-diff.sh" ]

	run grep -RFn '${CLAUDE_PLUGIN_ROOT}/scripts/dev-server' "$TMP_DIR/.codex/skills"
	[ "$status" -eq 1 ]

	run grep -RFn '${CLAUDE_PLUGIN_ROOT}/scripts/resolve-base.sh' "$TMP_DIR/.codex/skills"
	[ "$status" -eq 1 ]

	run grep -RFn '${CLAUDE_PLUGIN_ROOT}/scripts/collect-review-diff.sh' "$TMP_DIR/.codex/skills"
	[ "$status" -eq 1 ]

	run grep -RFn "'$TMP_DIR/.codex/scripts/dev-server'/detect-url.sh auto" "$TMP_DIR/.codex/skills"
	[ "$status" -eq 0 ]

	run grep -nF "RESOLVED=$('$TMP_DIR/.codex/scripts/collect-review-diff.sh' \"\${COLLECT_ARGS[@]}\")" "$TMP_DIR/.codex/skills/kramme:pr:code-review/SKILL.md"
	[ "$status" -eq 0 ]

	run grep -nF "RESOLVED=$('$TMP_DIR/.codex/scripts/resolve-base.sh' \"\${ARGS[@]}\")" "$TMP_DIR/.codex/skills/kramme:git:recreate-commits/SKILL.md"
	[ "$status" -eq 0 ]

	run grep -nF "DETECTED_PROJECT_TYPE=$('$TMP_DIR/.codex/scripts/dev-server'/detect-project-type.sh 2> /dev/null)" "$TMP_DIR/.codex/skills/kramme:qa/SKILL.md"
	[ "$status" -eq 0 ]

	run jq -r '.hooks' "$cache_root/.codex-plugin/plugin.json"
	[ "$status" -eq 0 ]
	[ "$output" = "./hooks/hooks.json" ]

	run jq -r '.hooks.PreToolUse[0].hooks[0].command' "$cache_root/hooks/hooks.json"
	[ "$status" -eq 0 ]
	[ "$output" = 'bash ${CLAUDE_PLUGIN_ROOT}/hooks/block-rm-rf.sh' ]

	run grep -RFn 'CLAUDE_PLUGIN_ROOT' "$cache_root/hooks/hooks.json"
	[ "$status" -eq 0 ]

	local hook_command
	hook_command="$(jq -r '.hooks.PreToolUse[0].hooks[0].command' "$cache_root/hooks/hooks.json")"
	run bash -c 'cd "$1" && printf "%s\n" "{\"tool_input\":{\"command\":\"echo ok\"}}" | CLAUDE_PLUGIN_ROOT="$2" bash -lc "$3"' _ "$TMP_DIR" "$cache_root" "$hook_command"
	[ "$status" -eq 0 ]

	run grep -nF '[plugins."kramme-cc-workflow@kramme-cc-workflow"]' "$TMP_DIR/.codex/config.toml"
	[ "$status" -eq 0 ]

	run awk '
		$0 == "[plugins.\"kramme-cc-workflow@kramme-cc-workflow\"]" { in_table = 1; next }
		in_table && /^\[/ { exit }
		in_table && $0 == "enabled = true" { found = 1 }
		END { exit found ? 0 : 1 }
	' "$TMP_DIR/.codex/config.toml"
	[ "$status" -eq 0 ]

	run jq -r '.pluginCaches[0]' "$TMP_DIR/.codex/.kramme-install-manifests/kramme-cc-workflow-codex.json"
	[ "$status" -eq 0 ]
	[ "$output" = "cache/kramme-cc-workflow/kramme-cc-workflow/$plugin_version" ]

	run jq -r '.hookMarketplaces[0]' "$TMP_DIR/.codex/.kramme-install-manifests/kramme-cc-workflow-codex.json"
	[ "$status" -eq 0 ]
	[ "$output" = ".kramme-plugin-marketplaces/kramme-cc-workflow" ]

	run jq -r 'has("plugins") or has("hooks")' "$TMP_DIR/.codex/.kramme-install-manifests/kramme-cc-workflow-codex.json"
	[ "$status" -eq 0 ]
	[ "$output" = "false" ]
}

@test "codex hook plugin manifest description is sanitized" {
	if ! command -v node >/dev/null 2>&1; then
		skip "node is required for converter tests"
	fi

	FIXTURE_PLUGIN="$TMP_DIR/hook-description-plugin"
	create_hook_fixture_plugin "$FIXTURE_PLUGIN" "hook-description-plugin" "alpha-hook"
	node -e '
const fs = require("fs");
const manifestPath = process.argv[1];
const manifest = JSON.parse(fs.readFileSync(manifestPath, "utf8"));
manifest.description = `First line\nsecond line ${"x".repeat(1100)}`;
fs.writeFileSync(manifestPath, `${JSON.stringify(manifest, null, 2)}\n`);
' "$FIXTURE_PLUGIN/.claude-plugin/plugin.json"

	run node "$SCRIPT" install "$FIXTURE_PLUGIN" --to codex --codex-home "$TMP_DIR" --agents-home "$TMP_DIR/.agents"
	[ "$status" -eq 0 ]

	run jq -r '.description' "$TMP_DIR/.codex/plugins/cache/hook-description-plugin/hook-description-plugin/1.0.0/.codex-plugin/plugin.json"
	[ "$status" -eq 0 ]
	[[ "$output" == "First line second line "* ]]
	[[ "$output" == *"..." ]]
	[[ "$output" != *$'\n'* ]]
	[ "${#output}" -le 1024 ]
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

@test "codex conversion preserves user-invocable skill resources" {
	if ! command -v node >/dev/null 2>&1; then
		skip "node is required for converter tests"
	fi

	run node "$SCRIPT" install "$REPO_ROOT" --to codex --codex-home "$TMP_DIR" --agents-home "$TMP_DIR/.agents"
	[ "$status" -eq 0 ]
	[ -f "$TMP_DIR/.codex/skills/kramme:pr:create/references/pre-validation-checks.md" ]
	[ -f "$TMP_DIR/.codex/skills/kramme:pr:create/references/branch-and-platform-handling.md" ]
}

@test "codex conversion maps todo tools to update_plan in AGENTS.md" {
	if ! command -v node >/dev/null 2>&1; then
		skip "node is required for converter tests"
	fi

	run node "$SCRIPT" install "$REPO_ROOT" --to codex --codex-home "$TMP_DIR" --agents-home "$TMP_DIR/.agents"
	[ "$status" -eq 0 ]
	[ -f "$TMP_DIR/.codex/AGENTS.md" ]
	[ ! -f "$TMP_DIR/AGENTS.md" ]

	run grep -n 'TodoWrite/TodoRead: use update_plan' "$TMP_DIR/.codex/AGENTS.md"
	[ "$status" -eq 0 ]

	run grep -n 'file-todos skill' "$TMP_DIR/.codex/AGENTS.md"
	[ "$status" -eq 1 ]
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
	cat >"$FIXTURE_PLUGIN/skills/demo/SKILL.md" <<'MD'
---
name: kramme:demo-skill
description: Demo skill
disable-model-invocation: false
user-invocable: true
---
Use /kramme:demo-skill.
MD
	cat >"$FIXTURE_PLUGIN/skills/demo/references/guide.md" <<'MD'
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

@test "codex conversion rewrites agent markdown references inside copied skills" {
	if ! command -v node >/dev/null 2>&1; then
		skip "node is required for converter tests"
	fi

	run node "$SCRIPT" install "$REPO_ROOT" --to codex --codex-home "$TMP_DIR" --agents-home "$TMP_DIR/.agents"
	[ "$status" -eq 0 ]

	run grep -REn 'agents/kramme:.*\.md' "$TMP_DIR/.codex/skills"
	if [ "$status" -ne 1 ]; then
		printf 'Unexpected stale agent references (status=%s):\n%s\n' "$status" "$output" >&2
	fi
	[ "$status" -eq 1 ]

	run grep -nE '\$kramme:code-reviewer skill' "$TMP_DIR/.codex/skills/kramme:pr:code-review/references/team-mode.md"
	[ "$status" -eq 0 ]
}

@test "codex conversion rewrites agent markdown references in copied markdown resources" {
	if ! command -v node >/dev/null 2>&1; then
		skip "node is required for converter tests"
	fi

	FIXTURE_PLUGIN="$TMP_DIR/agent-ref-resource-plugin"
	create_fixture_plugin "$FIXTURE_PLUGIN"
	mkdir -p "$FIXTURE_PLUGIN/agents" "$FIXTURE_PLUGIN/skills/demo/references"
	cat >"$FIXTURE_PLUGIN/agents/kramme:reviewer.md" <<'MD'
---
name: kramme:reviewer
description: Fixture reviewer
---
Review the code.
MD
	cat >"$FIXTURE_PLUGIN/skills/demo/SKILL.md" <<'MD'
---
name: kramme:demo-skill
description: Demo skill
disable-model-invocation: false
user-invocable: true
---
Use the mission from `agents/kramme:reviewer.md`.
Use linked mission via [reviewer mission](agents/kramme:reviewer.md).
Keep plugin-root paths like `${CLAUDE_PLUGIN_ROOT}/agents/kramme:reviewer.md`.
MD
	cat >"$FIXTURE_PLUGIN/skills/demo/references/guide.md" <<'MD'
Use the mission from agents/kramme:reviewer.md in copied resources.
Use colon punctuation agents/kramme:reviewer.md: copied resources.
Use semicolon punctuation agents/kramme:reviewer.md; copied resources.
Use autolink <agents/kramme:reviewer.md> in copied resources.
Keep anchored paths like agents/kramme:reviewer.md#usage.
Keep query paths like agents/kramme:reviewer.md?plain=1.
Keep parent paths like ../agents/kramme:reviewer.md.
MD

	run node "$SCRIPT" install "$FIXTURE_PLUGIN" --to codex --codex-home "$TMP_DIR" --agents-home "$TMP_DIR/.agents" --yes
	[ "$status" -eq 0 ]

	run grep -nE '\$kramme:reviewer skill' "$TMP_DIR/.codex/skills/kramme:demo-skill/SKILL.md"
	[ "$status" -eq 0 ]

	run grep -nE '\$kramme:reviewer skill' "$TMP_DIR/.codex/skills/kramme:demo-skill/references/guide.md"
	[ "$status" -eq 0 ]

	run grep -nF 'Use linked mission via $kramme:reviewer skill.' "$TMP_DIR/.codex/skills/kramme:demo-skill/SKILL.md"
	[ "$status" -eq 0 ]

	run grep -nF 'Use autolink $kramme:reviewer skill in copied resources.' "$TMP_DIR/.codex/skills/kramme:demo-skill/references/guide.md"
	[ "$status" -eq 0 ]

	run grep -nF 'Use colon punctuation $kramme:reviewer skill: copied resources.' "$TMP_DIR/.codex/skills/kramme:demo-skill/references/guide.md"
	[ "$status" -eq 0 ]

	run grep -nF 'Use semicolon punctuation $kramme:reviewer skill; copied resources.' "$TMP_DIR/.codex/skills/kramme:demo-skill/references/guide.md"
	[ "$status" -eq 0 ]

	run grep -nF '${CLAUDE_PLUGIN_ROOT}/agents/kramme:reviewer.md' "$TMP_DIR/.codex/skills/kramme:demo-skill/SKILL.md"
	[ "$status" -eq 0 ]

	run grep -nF '../agents/kramme:reviewer.md' "$TMP_DIR/.codex/skills/kramme:demo-skill/references/guide.md"
	[ "$status" -eq 0 ]

	run grep -nF 'agents/kramme:reviewer.md#usage' "$TMP_DIR/.codex/skills/kramme:demo-skill/references/guide.md"
	[ "$status" -eq 0 ]

	run grep -nF 'agents/kramme:reviewer.md?plain=1' "$TMP_DIR/.codex/skills/kramme:demo-skill/references/guide.md"
	[ "$status" -eq 0 ]

	run grep -RFn '${CLAUDE_PLUGIN_ROOT}/$kramme:reviewer skill' "$TMP_DIR/.codex/skills"
	[ "$status" -eq 1 ]

	run grep -RFn '../$kramme:reviewer skill' "$TMP_DIR/.codex/skills"
	[ "$status" -eq 1 ]

	run grep -RFn ']($kramme:reviewer skill)' "$TMP_DIR/.codex/skills"
	[ "$status" -eq 1 ]

	run grep -RFn '$kramme:reviewer skill#usage' "$TMP_DIR/.codex/skills"
	[ "$status" -eq 1 ]

	run grep -RFn '$kramme:reviewer skill?plain=1' "$TMP_DIR/.codex/skills"
	[ "$status" -eq 1 ]
}

@test "codex conversion preserves allowed-tools in copied skills" {
	if ! command -v node >/dev/null 2>&1; then
		skip "node is required for converter tests"
	fi

	FIXTURE_PLUGIN="$TMP_DIR/allowed-tools-plugin"
	create_fixture_plugin "$FIXTURE_PLUGIN"
	mkdir -p "$FIXTURE_PLUGIN/skills/demo"
	cat >"$FIXTURE_PLUGIN/skills/demo/SKILL.md" <<'MD'
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

@test "codex conversion preserves allowed-tools for generated command skills" {
	if ! command -v node >/dev/null 2>&1; then
		skip "node is required for converter tests"
	fi

	FIXTURE_PLUGIN="$TMP_DIR/command-allowed-tools-plugin"
	create_fixture_plugin "$FIXTURE_PLUGIN"
	mkdir -p "$FIXTURE_PLUGIN/commands"
	cat >"$FIXTURE_PLUGIN/commands/demo-command.md" <<'MD'
---
name: kramme:demo-command
description: Demo command
disable-model-invocation: true
allowed-tools:
  - Read
  - Edit(src/**)
---
Use /kramme:demo-command.
MD

	run node "$SCRIPT" install "$FIXTURE_PLUGIN" --to codex --codex-home "$TMP_DIR" --agents-home "$TMP_DIR/.agents" --yes
	[ "$status" -eq 0 ]

	run sed -n '1,20p' "$TMP_DIR/.codex/skills/kramme:demo-command/SKILL.md"
	[ "$status" -eq 0 ]
	[[ "$output" == *"allowed-tools:"* ]]
	[[ "$output" == *"Read"* ]]
	[[ "$output" == *"Edit(src/**)"* ]]
	[[ "$output" == *"user-invocable: true"* ]]
}

@test "codex conversion rewrites Claude-only tool references across converted skill tree" {
	if ! command -v node >/dev/null 2>&1; then
		skip "node is required for converter tests"
	fi

	run node "$SCRIPT" install "$REPO_ROOT" --to codex --codex-home "$TMP_DIR" --agents-home "$TMP_DIR/.agents"
	[ "$status" -eq 0 ]

	run grep -REn '\bAskUserQuestion\b|\bTask tool\b|\bSkill tool\b|\bTodoWrite\b|\bTodoRead\b|\bsubagent_type[[:space:]]*[:=][[:space:]]*Explore\b' "$TMP_DIR/.codex/skills"
	if [ "$status" -ne 1 ]; then
		printf 'Unexpected matches (status=%s):\n%s\n' "$status" "$output" >&2
	fi
	[ "$status" -eq 1 ]

	run grep -REn 'direct chat questions`|direct chat question`' "$TMP_DIR/.codex/skills"
	if [ "$status" -ne 1 ]; then
		printf 'Unexpected matches (status=%s):\n%s\n' "$status" "$output" >&2
	fi
	[ "$status" -eq 1 ]

	run grep -REn 'direct chat question tool' "$TMP_DIR/.codex/skills"
	if [ "$status" -ne 1 ]; then
		printf 'Unexpected matches (status=%s):\n%s\n' "$status" "$output" >&2
	fi
	[ "$status" -eq 1 ]
}

@test "codex conversion rewrites operational AskUserQuestion phrases without mangling markdown" {
	if ! command -v node >/dev/null 2>&1; then
		skip "node is required for converter tests"
	fi

	FIXTURE_PLUGIN="$TMP_DIR/ask-user-question-plugin"
	create_fixture_plugin "$FIXTURE_PLUGIN"
	mkdir -p "$FIXTURE_PLUGIN/skills/demo"
	cat >"$FIXTURE_PLUGIN/skills/demo/SKILL.md" <<'MD'
---
name: demo-skill
description: Demo skill
disable-model-invocation: false
user-invocable: true
---
**Present classification to user via `AskUserQuestion`:**
Use `AskUserQuestion` to confirm the topic.
Conduct a multi-round interview using `AskUserQuestion`.
Use the AskUserQuestion tool throughout to gather decisions.
Surface the offer with `AskUserQuestion`.
MD

	run node "$SCRIPT" install "$FIXTURE_PLUGIN" --to codex --codex-home "$TMP_DIR" --agents-home "$TMP_DIR/.agents" --yes
	[ "$status" -eq 0 ]

	run sed -n '1,20p' "$TMP_DIR/.codex/skills/demo-skill/SKILL.md"
	[ "$status" -eq 0 ]
	[[ "$output" == *"**Present classification to user by asking the user directly in chat:**"* ]]
	[[ "$output" == *"Ask the user directly in chat to confirm the topic."* ]]
	[[ "$output" == *"Conduct a multi-round interview by asking the user directly in chat."* ]]
	[[ "$output" == *"Ask the user directly in chat throughout to gather decisions."* ]]
	[[ "$output" == *"Surface the offer by asking the user directly in chat."* ]]
	[[ "$output" != *'direct chat questions`'* ]]
	[[ "$output" != *'direct chat question`'* ]]
	[[ "$output" != *"direct chat question tool"* ]]
}

@test "codex conversion rewrites AskUserQuestion blocks into direct-chat prompts" {
	if ! command -v node >/dev/null 2>&1; then
		skip "node is required for converter tests"
	fi

	FIXTURE_PLUGIN="$TMP_DIR/ask-user-question-blocks-plugin"
	create_fixture_plugin "$FIXTURE_PLUGIN"
	mkdir -p "$FIXTURE_PLUGIN/skills/demo"
	cat >"$FIXTURE_PLUGIN/skills/demo/SKILL.md" <<'MD'
---
name: demo-skill
description: Demo skill
disable-model-invocation: false
user-invocable: true
---
Use AskUserQuestion:

```yaml
header: "Existing Workflow Files Found"
question: "Workflow files already exist in this directory. How would you like to proceed?"
options:
  - label: "Resume existing workflow"
    description: "Continue with current files"
  - label: "Start fresh"
    description: "Delete existing workflow files and create new ones"
```

```text
AskUserQuestion
header: Bug Description
question: What bug should I investigate?
options:
  - (freeform) Describe the bug, paste an error message, or provide a Linear issue ID
```
MD

	run node "$SCRIPT" install "$FIXTURE_PLUGIN" --to codex --codex-home "$TMP_DIR" --agents-home "$TMP_DIR/.agents" --yes
	[ "$status" -eq 0 ]

	run sed -n '1,40p' "$TMP_DIR/.codex/skills/demo-skill/SKILL.md"
	[ "$status" -eq 0 ]
	[[ "$output" == *"Ask the user directly in chat:"* ]]
	[[ "$output" == *"Question label: Existing Workflow Files Found"* ]]
	[[ "$output" == *"Question: Workflow files already exist in this directory. How would you like to proceed?"* ]]
	[[ "$output" == *"- Resume existing workflow — Continue with current files"* ]]
	[[ "$output" == *"Question label: Bug Description"* ]]
	[[ "$output" == *"Question: What bug should I investigate?"* ]]
	[[ "$output" != *"header:"* ]]
	[[ "$output" != *'```'* ]]
	[[ "$output" != *"AskUserQuestion"* ]]
}

@test "codex conversion preserves multiline AskUserQuestion question bodies" {
	if ! command -v node >/dev/null 2>&1; then
		skip "node is required for converter tests"
	fi

	FIXTURE_PLUGIN="$TMP_DIR/ask-user-question-multiline-plugin"
	create_fixture_plugin "$FIXTURE_PLUGIN"
	mkdir -p "$FIXTURE_PLUGIN/skills/demo"
	cat >"$FIXTURE_PLUGIN/skills/demo/SKILL.md" <<'MD'
---
name: demo-skill
description: Demo skill
disable-model-invocation: false
user-invocable: true
---
```yaml
AskUserQuestion
header: "ADR offer"
question: |
  This decision looks ADR-worthy:
  - Hard to reverse: Routing will be hard to unwind later.
  - Surprising without context: Maintainers will not infer this from code alone.
  - Result of a real tradeoff: We rejected a simpler local-only option.

  Record as an ADR?
options:
  - label: "Author ADR"
    description: "Invoke /kramme:docs:adr now"
  - label: "Skip"
    description: "Don't author, and don't ask again about this decision"
  - label: "Defer"
    description: "Don't author now; allow re-offer if the decision recurs"
multiSelect: false
```
MD

	run node "$SCRIPT" install "$FIXTURE_PLUGIN" --to codex --codex-home "$TMP_DIR" --agents-home "$TMP_DIR/.agents" --yes
	[ "$status" -eq 0 ]

	run sed -n '1,40p' "$TMP_DIR/.codex/skills/demo-skill/SKILL.md"
	[ "$status" -eq 0 ]
	[[ "$output" == *"Question label: ADR offer"* ]]
	[[ "$output" == *$'Question: This decision looks ADR-worthy:\n  - Hard to reverse: Routing will be hard to unwind later.\n  - Surprising without context: Maintainers will not infer this from code alone.\n  - Result of a real tradeoff: We rejected a simpler local-only option.\n\n  Record as an ADR?'* ]]
	[[ "$output" == *"- Author ADR — Invoke /kramme:docs:adr now"* ]]
	[[ "$output" != *"Question: |"* ]]
	[[ "$output" != *$'Suggested options:\n- Hard to reverse'* ]]
	[[ "$output" != *"AskUserQuestion"* ]]
}

@test "codex conversion preserves indentation for rewritten AskUserQuestion blocks" {
	if ! command -v node >/dev/null 2>&1; then
		skip "node is required for converter tests"
	fi

	FIXTURE_PLUGIN="$TMP_DIR/ask-user-question-indentation-plugin"
	create_fixture_plugin "$FIXTURE_PLUGIN"
	mkdir -p "$FIXTURE_PLUGIN/skills/demo"
	cat >"$FIXTURE_PLUGIN/skills/demo/SKILL.md" <<'MD'
---
name: demo-skill
description: Demo skill
disable-model-invocation: false
user-invocable: true
---
1. Ask for the issue ID:
   ```yaml
   header: "Linear issue"
   question: "Enter the Linear issue ID (e.g., WAN-521):"
   options: []
   ```
MD

	run node "$SCRIPT" install "$FIXTURE_PLUGIN" --to codex --codex-home "$TMP_DIR" --agents-home "$TMP_DIR/.agents" --yes
	[ "$status" -eq 0 ]

	run sed -n '1,20p' "$TMP_DIR/.codex/skills/demo-skill/SKILL.md"
	[ "$status" -eq 0 ]
	[[ "$output" == *$'1. Ask for the issue ID:\n   Ask the user directly in chat:\n   Question label: Linear issue\n   Question: Enter the Linear issue ID (e.g., WAN-521):'* ]]
	[[ "$output" != *$'\nQuestion label: Linear issue'* ]]
}

@test "codex conversion rewrites AskUserQuestion blocks when closing fence indentation differs" {
	if ! command -v node >/dev/null 2>&1; then
		skip "node is required for converter tests"
	fi

	FIXTURE_PLUGIN="$TMP_DIR/ask-user-question-closing-indent-plugin"
	create_fixture_plugin "$FIXTURE_PLUGIN"
	mkdir -p "$FIXTURE_PLUGIN/skills/demo"
	cat >"$FIXTURE_PLUGIN/skills/demo/SKILL.md" <<'MD'
---
name: demo-skill
description: Demo skill
disable-model-invocation: false
user-invocable: true
---
1. Ask for the issue ID:
   ```yaml
   header: "Linear issue"
   question: "Enter the Linear issue ID (e.g., WAN-521):"
   options: []
  ```
MD

	run node "$SCRIPT" install "$FIXTURE_PLUGIN" --to codex --codex-home "$TMP_DIR" --agents-home "$TMP_DIR/.agents" --yes
	[ "$status" -eq 0 ]

	run sed -n '1,20p' "$TMP_DIR/.codex/skills/demo-skill/SKILL.md"
	[ "$status" -eq 0 ]
	[[ "$output" == *$'1. Ask for the issue ID:\n   Ask the user directly in chat:\n   Question label: Linear issue\n   Question: Enter the Linear issue ID (e.g., WAN-521):'* ]]
	[[ "$output" != *'```yaml'* ]]
	[[ "$output" != *'AskUserQuestion'* ]]
}

@test "codex conversion does not terminate AskUserQuestion blocks on deeper-indented fences" {
	if ! command -v node >/dev/null 2>&1; then
		skip "node is required for converter tests"
	fi

	FIXTURE_PLUGIN="$TMP_DIR/ask-user-question-deeper-fence-plugin"
	create_fixture_plugin "$FIXTURE_PLUGIN"
	mkdir -p "$FIXTURE_PLUGIN/skills/demo"
	cat >"$FIXTURE_PLUGIN/skills/demo/SKILL.md" <<'MD'
---
name: demo-skill
description: Demo skill
disable-model-invocation: false
user-invocable: true
---
1. Ask for the issue ID:
   ```yaml
   header: "Linear issue"
   question: "Enter the Linear issue ID (e.g., WAN-521):"
    ```
   options: []
   ```
MD

	run node "$SCRIPT" install "$FIXTURE_PLUGIN" --to codex --codex-home "$TMP_DIR" --agents-home "$TMP_DIR/.agents" --yes
	[ "$status" -eq 0 ]

	run sed -n '1,20p' "$TMP_DIR/.codex/skills/demo-skill/SKILL.md"
	[ "$status" -eq 0 ]
	[[ "$output" == *$'1. Ask for the issue ID:\n   Ask the user directly in chat:\n   Question label: Linear issue\n   Question: Enter the Linear issue ID (e.g., WAN-521):'* ]]
	[[ "$output" != *'options: []'* ]]
	[[ "$output" != *'```'* ]]
}

@test "codex conversion rewrites AskUserQuestion blocks with longer Markdown fences" {
	if ! command -v node >/dev/null 2>&1; then
		skip "node is required for converter tests"
	fi

	FIXTURE_PLUGIN="$TMP_DIR/ask-user-question-longer-fence-plugin"
	create_fixture_plugin "$FIXTURE_PLUGIN"
	mkdir -p "$FIXTURE_PLUGIN/skills/demo"
	cat >"$FIXTURE_PLUGIN/skills/demo/SKILL.md" <<'MD'
---
name: demo-skill
description: Demo skill
disable-model-invocation: false
user-invocable: true
---
1. Ask for the issue ID:
   ````yaml
   header: "Linear issue"
   question: "Enter the Linear issue ID (e.g., WAN-521):"
   options: []
   ````
MD

	run node "$SCRIPT" install "$FIXTURE_PLUGIN" --to codex --codex-home "$TMP_DIR" --agents-home "$TMP_DIR/.agents" --yes
	[ "$status" -eq 0 ]

	run sed -n '1,20p' "$TMP_DIR/.codex/skills/demo-skill/SKILL.md"
	[ "$status" -eq 0 ]
	[[ "$output" == *$'1. Ask for the issue ID:\n   Ask the user directly in chat:\n   Question label: Linear issue\n   Question: Enter the Linear issue ID (e.g., WAN-521):'* ]]
	[[ "$output" != *'````yaml'* ]]
	[[ "$output" != *'AskUserQuestion'* ]]
}

@test "codex conversion rewrites AskUserQuestion schema docs for Codex" {
	if ! command -v node >/dev/null 2>&1; then
		skip "node is required for converter tests"
	fi

	FIXTURE_PLUGIN="$TMP_DIR/ask-user-question-docs-plugin"
	create_fixture_plugin "$FIXTURE_PLUGIN"
	mkdir -p "$FIXTURE_PLUGIN/skills/demo"
	cat >"$FIXTURE_PLUGIN/skills/demo/SKILL.md" <<'MD'
---
name: demo-skill
description: Demo skill
disable-model-invocation: false
user-invocable: true
---
### Using AskUserQuestion Correctly

The AskUserQuestion tool requires **2-4 predefined options** per question.

Users can always select "Other" to provide free-text input.

- `header`: Short label
- `question`: The full question text
- `multiSelect`: Set `true` for non-exclusive choices
MD

	run node "$SCRIPT" install "$FIXTURE_PLUGIN" --to codex --codex-home "$TMP_DIR" --agents-home "$TMP_DIR/.agents" --yes
	[ "$status" -eq 0 ]

	run sed -n '1,20p' "$TMP_DIR/.codex/skills/demo-skill/SKILL.md"
	[ "$status" -eq 0 ]
	[[ "$output" == *"### Asking Questions in Codex"* ]]
	[[ "$output" == *"When asking directly in chat, offer a small set of concrete options when that helps the user answer quickly."* ]]
	[[ "$output" == *"Users can always ignore the suggested options and reply freely in chat."* ]]
	[[ "$output" == *'- `Label`: Short label'* ]]
	[[ "$output" == *'- `Question`: The full question text'* ]]
	[[ "$output" == *'- `Multi-select`: Use this style only when multiple options can apply at once'* ]]
	[[ "$output" != *"AskUserQuestion"* ]]
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

	printf "Run /kramme:pr:create later\n" >"$TMP_DIR/.codex/skills/kramme:pr:create/LOCAL-NOTES.md"

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
	cat >"$PLUGIN_DIR/.claude-plugin/plugin.json" <<'JSON'
{
  "name": "skill-plugin",
  "version": "1.0.0",
  "agents": [],
  "commands": [],
  "skills": []
}
JSON
	cat >"$PLUGIN_DIR/commands/kramme-temp-command.md" <<'MD'
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
	cat >"$PLUGIN_DIR/commands/kramme-next-command.md" <<'MD'
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
	cat >"$PLUGIN_DIR/.claude-plugin/plugin.json" <<'JSON'
{
  "name": "skill-plugin-empty",
  "version": "1.0.0",
  "agents": [],
  "commands": [],
  "skills": []
}
JSON
	cat >"$PLUGIN_DIR/commands/kramme-temp-command.md" <<'MD'
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
	echo "old" >"$TMP_DIR/.codex/skills/impl-kramme-create-pr/SKILL.md"

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
	echo "old" >"$TMP_DIR/.codex/skills/kramme:obsolete-skill/SKILL.md"

	run node "$SCRIPT" install "$REPO_ROOT" --to codex --codex-home "$TMP_DIR" --agents-home "$TMP_DIR/.agents" --yes
	[ "$status" -eq 0 ]
	[ -d "$TMP_DIR/.codex/skills/kramme:obsolete-skill" ]
	[ -f "$TMP_DIR/.codex/.kramme-install-state.json" ]
}

@test "codex conversion preserves workflow skills and agents when another plugin is installed" {
	if ! command -v node >/dev/null 2>&1; then
		skip "node is required for converter tests"
	fi

	FIXTURE_PLUGIN="$TMP_DIR/fixture-plugin"
	create_skill_fixture_plugin "$FIXTURE_PLUGIN" "fixture-plugin" "kramme:fixture:review"

	run node "$SCRIPT" install "$REPO_ROOT" --to codex --codex-home "$TMP_DIR" --agents-home "$TMP_DIR/.agents" --yes
	[ "$status" -eq 0 ]
	[ -f "$TMP_DIR/.codex/skills/kramme:pr:create/SKILL.md" ]
	[ -f "$TMP_DIR/.agents/skills/kramme:architecture-strategist/SKILL.md" ]

	run node "$SCRIPT" install "$FIXTURE_PLUGIN" --to codex --codex-home "$TMP_DIR" --agents-home "$TMP_DIR/.agents" --yes
	[ "$status" -eq 0 ]
	[ -f "$TMP_DIR/.codex/skills/kramme:pr:create/SKILL.md" ]
	[ -f "$TMP_DIR/.codex/skills/kramme:fixture:review/SKILL.md" ]
	[ -f "$TMP_DIR/.agents/skills/kramme:architecture-strategist/SKILL.md" ]
	[ -f "$TMP_DIR/.agents/skills/performance-oracle/SKILL.md" ]
}

@test "codex conversion preserves existing workflow skills when reinstalling another plugin without state" {
	if ! command -v node >/dev/null 2>&1; then
		skip "node is required for converter tests"
	fi

	FIXTURE_PLUGIN="$TMP_DIR/fixture-plugin"
	create_skill_fixture_plugin "$FIXTURE_PLUGIN" "fixture-plugin" "kramme:fixture:review"

	run node "$SCRIPT" install "$REPO_ROOT" --to codex --codex-home "$TMP_DIR" --agents-home "$TMP_DIR/.agents" --yes
	[ "$status" -eq 0 ]
	run node "$SCRIPT" install "$FIXTURE_PLUGIN" --to codex --codex-home "$TMP_DIR" --agents-home "$TMP_DIR/.agents" --yes
	[ "$status" -eq 0 ]

	rm "$TMP_DIR/.codex/.kramme-install-state.json"

	run node "$SCRIPT" install "$FIXTURE_PLUGIN" --to codex --codex-home "$TMP_DIR" --agents-home "$TMP_DIR/.agents" --yes
	[ "$status" -eq 0 ]
	[ -f "$TMP_DIR/.codex/skills/kramme:pr:create/SKILL.md" ]
	[ -f "$TMP_DIR/.codex/skills/kramme:fixture:review/SKILL.md" ]
}

@test "codex conversion cleans stale same-plugin skills after state loss" {
	if ! command -v node >/dev/null 2>&1; then
		skip "node is required for converter tests"
	fi

	PLUGIN_DIR="$TMP_DIR/state-loss-plugin"
	mkdir -p "$PLUGIN_DIR/.claude-plugin" "$PLUGIN_DIR/commands"
	cat >"$PLUGIN_DIR/.claude-plugin/plugin.json" <<'JSON'
{
  "name": "state-loss-plugin",
  "version": "1.0.0",
  "agents": [],
  "commands": [],
  "skills": []
}
JSON
	cat >"$PLUGIN_DIR/commands/kramme-old-skill.md" <<'MD'
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
	cat >"$PLUGIN_DIR/commands/kramme-new-skill.md" <<'MD'
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

@test "codex conversion is the default install target" {
	if ! command -v node >/dev/null 2>&1; then
		skip "node is required for converter tests"
	fi

	run node "$SCRIPT" install "$REPO_ROOT" --codex-home "$TMP_DIR" --agents-home "$TMP_DIR/.agents" --yes
	[ "$status" -eq 0 ]
	[ -f "$TMP_DIR/.codex/skills/kramme:pr:create/SKILL.md" ]
	[ -f "$TMP_DIR/.agents/skills/kramme:architecture-strategist/SKILL.md" ]
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

@test "opencode target is no longer supported" {
	if ! command -v node >/dev/null 2>&1; then
		skip "node is required for converter tests"
	fi

	run node "$SCRIPT" install "$REPO_ROOT" --to opencode --codex-home "$TMP_DIR" --agents-home "$TMP_DIR/.agents" --yes
	[ "$status" -ne 0 ]
	[[ "$output" == *"Unknown target: opencode"* ]]
}

@test "opencode target is no longer supported for stats" {
	if ! command -v node >/dev/null 2>&1; then
		skip "node is required for converter tests"
	fi

	run node "$SCRIPT" stats "$REPO_ROOT" --to opencode
	[ "$status" -ne 0 ]
	[[ "$output" == *"Unknown target: opencode"* ]]
	[[ "$output" != *"codex_skills="* ]]
}
