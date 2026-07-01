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

@test "codex conversion preserves existing config when adding MCP servers" {
	if ! command -v node >/dev/null 2>&1; then
		skip "node is required for converter tests"
	fi

	FIXTURE_PLUGIN="$TMP_DIR/mcp-plugin"
	create_fixture_plugin "$FIXTURE_PLUGIN" "mcp-plugin"
	cat >"$FIXTURE_PLUGIN/.mcp.json" <<'JSON'
{
  "demo-server": {
    "command": "node",
    "args": ["server.js", "--stdio"],
    "env": {
      "DEMO_TOKEN": "placeholder"
    }
  }
}
JSON

	mkdir -p "$TMP_DIR/.codex"
	cat >"$TMP_DIR/.codex/config.toml" <<'TOML'
model = "gpt-5"

[profiles.dev]
model = "gpt-5-mini"

[mcp_servers.existing]
command = "existing-server"
args = ["--keep"]

[mcp_servers."demo-server"] # old managed table
command = "old-server"

[mcp_servers."demo-server".env] # old managed env table
DEMO_TOKEN = "old-placeholder"

[[history_entries]]
name = "keep-array-table"

[mcp_servers.demo-server-extra]
command = "keep-extra"

[mcp_servers.demo-server.env_extra]
SENTINEL = "keep-prefix"

[profiles.after]
model = "gpt-5"
TOML

	run node "$SCRIPT" install "$FIXTURE_PLUGIN" --to codex --codex-home "$TMP_DIR" --agents-home "$TMP_DIR/.agents" --yes
	[ "$status" -eq 0 ]

	run grep -nF 'model = "gpt-5"' "$TMP_DIR/.codex/config.toml"
	[ "$status" -eq 0 ]
	run grep -nF '[profiles.dev]' "$TMP_DIR/.codex/config.toml"
	[ "$status" -eq 0 ]
	run grep -nF '[profiles.after]' "$TMP_DIR/.codex/config.toml"
	[ "$status" -eq 0 ]
	run grep -nF '[[history_entries]]' "$TMP_DIR/.codex/config.toml"
	[ "$status" -eq 0 ]
	run grep -nF 'name = "keep-array-table"' "$TMP_DIR/.codex/config.toml"
	[ "$status" -eq 0 ]
	run grep -nF '[mcp_servers.existing]' "$TMP_DIR/.codex/config.toml"
	[ "$status" -eq 0 ]
	run grep -nF '[mcp_servers.demo-server-extra]' "$TMP_DIR/.codex/config.toml"
	[ "$status" -eq 0 ]
	run grep -nF 'command = "keep-extra"' "$TMP_DIR/.codex/config.toml"
	[ "$status" -eq 0 ]
	run grep -nF '[mcp_servers.demo-server.env_extra]' "$TMP_DIR/.codex/config.toml"
	[ "$status" -eq 0 ]
	run grep -nF 'SENTINEL = "keep-prefix"' "$TMP_DIR/.codex/config.toml"
	[ "$status" -eq 0 ]
	run grep -nF '[mcp_servers.demo-server]' "$TMP_DIR/.codex/config.toml"
	[ "$status" -eq 0 ]
	run grep -nF 'command = "node"' "$TMP_DIR/.codex/config.toml"
	[ "$status" -eq 0 ]
	run grep -nF 'args = ["server.js", "--stdio"]' "$TMP_DIR/.codex/config.toml"
	[ "$status" -eq 0 ]
	run grep -nF '[mcp_servers.demo-server.env]' "$TMP_DIR/.codex/config.toml"
	[ "$status" -eq 0 ]
	run grep -nF 'DEMO_TOKEN = "placeholder"' "$TMP_DIR/.codex/config.toml"
	[ "$status" -eq 0 ]
	run grep -nF '[mcp_servers."demo-server"]' "$TMP_DIR/.codex/config.toml"
	[ "$status" -eq 1 ]
	run grep -nF '[mcp_servers."demo-server".env]' "$TMP_DIR/.codex/config.toml"
	[ "$status" -eq 1 ]
	run grep -nF 'command = "old-server"' "$TMP_DIR/.codex/config.toml"
	[ "$status" -eq 1 ]
	run grep -nF 'DEMO_TOKEN = "old-placeholder"' "$TMP_DIR/.codex/config.toml"
	[ "$status" -eq 1 ]

	run node "$SCRIPT" install "$FIXTURE_PLUGIN" --to codex --codex-home "$TMP_DIR" --agents-home "$TMP_DIR/.agents" --yes
	[ "$status" -eq 0 ]

	run grep -cFx '[mcp_servers.demo-server]' "$TMP_DIR/.codex/config.toml"
	[ "$status" -eq 0 ]
	[ "$output" = "1" ]
	run grep -cFx '[mcp_servers.demo-server.env]' "$TMP_DIR/.codex/config.toml"
	[ "$status" -eq 0 ]
	[ "$output" = "1" ]
}

@test "frontmatter module parses and formats converter metadata" {
	if ! command -v node >/dev/null 2>&1; then
		skip "node is required for converter tests"
	fi

	run node -e '
const assert = require("assert");
const {
  codexName,
  formatFrontmatter,
  normalizeName,
  parseFrontmatter,
  sanitizeDescription,
} = require(process.argv[1]);

const parsed = parseFrontmatter(`---
name: Demo Skill
description: |
  First line
  Usage: keep exactly
  second line
argument-hint: [aspects] [--base <branch>]
summary: [experimental] Capture local behavior: screenshots, terminal output
allowed-tools:
  - Read
  - Edit(src/**)
examples:
  - Capture: screenshots
user-invocable: true
---
Body`);

assert.deepStrictEqual(parsed.data["allowed-tools"], ["Read", "Edit(src/**)"]);
assert.deepStrictEqual(parsed.data.examples, ["Capture: screenshots"]);
assert.strictEqual(
  parsed.data.description,
  "First line\nUsage: keep exactly\nsecond line",
);
assert.strictEqual(
  parsed.data.summary,
  "[experimental] Capture local behavior: screenshots, terminal output",
);
assert.strictEqual(parsed.data["argument-hint"], "[aspects] [--base <branch>]");
assert.strictEqual(parsed.data["user-invocable"], true);
assert.strictEqual(parsed.body, "Body");
assert.strictEqual(normalizeName("Kramme: Demo/Skill!"), "kramme-demo-skill");
assert.strictEqual(codexName("Demo Skill!"), "demo-skill");
assert.strictEqual(sanitizeDescription(" First\n\nSecond "), "First Second");

const bracketHint = parseFrontmatter(`---
name: Demo Skill
argument-hint: [path]
disable-model-invocation: { true|false }
---
Body`);
assert.strictEqual(bracketHint.data["argument-hint"], "[path]");
assert.strictEqual(
  bracketHint.data["disable-model-invocation"],
  "{ true|false }",
);

const formatted = formatFrontmatter(
  {
    name: "demo-skill",
    "argument-hint": bracketHint.data["argument-hint"],
    "allowed-tools": ["Read", "Edit(src/**)"],
    metadata: { owner: "platform" },
    "user-invocable": true,
  },
  "Body",
);
assert.match(formatted, /argument-hint: "\[path\]"/);
assert.match(formatted, /allowed-tools:\n  - Read\n  - Edit\(src\/\*\*\)/);
assert.match(formatted, /metadata:\n  owner: platform/);
assert.match(formatted, /user-invocable: true/);
console.log("ok");
' "$REPO_ROOT/scripts/convert-plugin/frontmatter"
	[ "$status" -eq 0 ]
	[ "$output" = "ok" ]
}

@test "frontmatter module parses supported YAML shapes and nested metadata" {
	if ! command -v node >/dev/null 2>&1; then
		skip "node is required for converter tests"
	fi

	run node -e '
const assert = require("assert");
const { parseFrontmatter } = require(process.argv[1]);

const parsed = parseFrontmatter(`---
name: "Quoted Skill"
description: >
  First line
  second line
enabled: false
attempts: 3
ratio: -2.5
empty: null
fallback: ~
tags: [alpha, "beta:two", false, 2]
allowed-tools:
  - Read
  - Edit(src/**)
metadata:
  owner: platform
  channels:
    - cli
    - codex
examples:
  - name: Capture
    description: Capture local behavior: screenshots
  - name: Replay
    description: Replay terminal output
---

Body line one
---
Body line two`);

assert.strictEqual(parsed.data.name, "Quoted Skill");
assert.strictEqual(parsed.data.description, "First line second line");
assert.strictEqual(parsed.data.enabled, false);
assert.strictEqual(parsed.data.attempts, 3);
assert.strictEqual(parsed.data.ratio, -2.5);
assert.strictEqual(parsed.data.empty, null);
assert.strictEqual(parsed.data.fallback, null);
assert.deepStrictEqual(parsed.data.tags, ["alpha", "beta:two", false, 2]);
assert.deepStrictEqual(parsed.data["allowed-tools"], ["Read", "Edit(src/**)"]);
assert.deepStrictEqual(parsed.data.metadata, {
  owner: "platform",
  channels: ["cli", "codex"],
});
assert.deepStrictEqual(parsed.data.examples, [
  {
    name: "Capture",
    description: "Capture local behavior: screenshots",
  },
  {
    name: "Replay",
    description: "Replay terminal output",
  },
]);
assert.ok(!Object.hasOwn(parsed.data, "owner"));
assert.strictEqual(parsed.body, "\nBody line one\n---\nBody line two");
console.log("ok");
' "$REPO_ROOT/scripts/convert-plugin/frontmatter"
	[ "$status" -eq 0 ]
	[ "$output" = "ok" ]
}

@test "codex transformer rewrites task calls and known references directly" {
	if ! command -v node >/dev/null 2>&1; then
		skip "node is required for converter tests"
	fi

	run node -e '
const assert = require("assert");
const { transformContentForCodex } = require(process.argv[1]);

const knownCommands = new Set(["kramme:pr:create", "demo-command"]);
const knownAgentSkills = new Map([
  ["kramme:reviewer", "kramme:reviewer"],
  ["support-reviewer", "support-reviewer"],
]);
const input = [
  "Task support-reviewer(review this parser)",
  "Run /kramme:pr:create, then /unknown, and keep /usr/bin.",
  "Ask @support-reviewer to inspect the output.",
  "Use `agents/kramme:reviewer.md` and [reviewer](agents/kramme:reviewer.md).",
].join("\n");

const output = transformContentForCodex(input, {
  knownCommands,
  knownAgentSkills,
});

assert.match(output, /Use the \$support-reviewer skill to: review this parser/);
assert.match(output, /Run \$kramme:pr:create, then \/unknown, and keep \/usr\/bin\./);
assert.match(output, /Ask \$support-reviewer skill to inspect the output\./);
assert.match(output, /Use \$kramme:reviewer skill and \$kramme:reviewer skill\./);
console.log("ok");
' "$REPO_ROOT/scripts/convert-plugin/codex-transformer"
	[ "$status" -eq 0 ]
	[ "$output" = "ok" ]
}

@test "ask user question parser reads structured prompt blocks" {
	if ! command -v node >/dev/null 2>&1; then
		skip "node is required for converter tests"
	fi

	run node -e '
const assert = require("assert");
const { parseAskUserQuestionBlock } = require(process.argv[1]);

const parsed = parseAskUserQuestionBlock(`
AskUserQuestion
header: "Release scope"
question: |
  Which release scopes should this include?
  Choose every applicable area.
multiSelect: "true"
options:
  - label: "Converter"
    description: "Converter behavior and tests"
  - (freeform) Something else
`);

assert.deepStrictEqual(parsed, {
  header: "Release scope",
  question: "Which release scopes should this include?\nChoose every applicable area.",
  multiSelect: true,
  options: [
    {
      label: "Converter",
      description: "Converter behavior and tests",
    },
    {
      label: "Something else",
      description: "",
    },
  ],
});

const folded = parseAskUserQuestionBlock(`
question: >
  Pick the route
  for this plan.
options: []
`);
assert.strictEqual(folded.question, "Pick the route for this plan.");
assert.strictEqual(parseAskUserQuestionBlock("plain markdown"), null);
console.log("ok");
' "$REPO_ROOT/scripts/convert-plugin/ask-user-question-parser"
	[ "$status" -eq 0 ]
	[ "$output" = "ok" ]
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

@test "codex conversion normalizes quoted boolean skill frontmatter" {
	if ! command -v node >/dev/null 2>&1; then
		skip "node is required for converter tests"
	fi

	FIXTURE_PLUGIN="$TMP_DIR/boolean-plugin"
	create_fixture_plugin "$FIXTURE_PLUGIN" "boolean-plugin"

	mkdir -p "$FIXTURE_PLUGIN/skills/quoted-hidden"
	cat >"$FIXTURE_PLUGIN/skills/quoted-hidden/SKILL.md" <<'MD'
---
name: quoted-hidden
description: Quoted hidden skill
disable-model-invocation: "true"
user-invocable: "false"
---
Hidden body.
MD

	mkdir -p "$FIXTURE_PLUGIN/skills/literal-hidden"
	cat >"$FIXTURE_PLUGIN/skills/literal-hidden/SKILL.md" <<'MD'
---
name: literal-hidden
description: Literal hidden skill
disable-model-invocation: true
user-invocable: false
---
Hidden body.
MD

	mkdir -p "$FIXTURE_PLUGIN/skills/quoted-enabled"
	cat >"$FIXTURE_PLUGIN/skills/quoted-enabled/SKILL.md" <<'MD'
---
name: quoted-enabled
description: Quoted enabled skill
disable-model-invocation: "false"
user-invocable: "true"
---
Enabled body.
MD

	mkdir -p "$FIXTURE_PLUGIN/skills/literal-enabled"
	cat >"$FIXTURE_PLUGIN/skills/literal-enabled/SKILL.md" <<'MD'
---
name: literal-enabled
description: Literal enabled skill
disable-model-invocation: false
user-invocable: true
---
Enabled body.
MD

	run node -e '
const assert = require("assert");
const { loadClaudePlugin } = require(process.argv[1]);

(async () => {
  const plugin = await loadClaudePlugin(process.argv[2]);
  const commandNames = plugin.commands.map((command) => command.name).sort();
  assert.deepStrictEqual(commandNames, ["literal-enabled", "quoted-enabled"]);

  const skills = Object.fromEntries(
    plugin.skills.map((skill) => [skill.name, skill]),
  );
  assert.strictEqual(skills["quoted-hidden"].userInvocable, false);
  assert.strictEqual(skills["literal-hidden"].userInvocable, false);
  assert.strictEqual(skills["quoted-enabled"].userInvocable, true);
  assert.strictEqual(skills["literal-enabled"].userInvocable, true);
  assert.strictEqual(skills["quoted-hidden"].disableModelInvocation, true);
  assert.strictEqual(skills["quoted-enabled"].disableModelInvocation, false);
  console.log("ok");
})().catch((error) => {
  console.error(error);
  process.exit(1);
});
' "$REPO_ROOT/scripts/convert-plugin/loader" "$FIXTURE_PLUGIN"
	[ "$status" -eq 0 ]
	[ "$output" = "ok" ]

	run node "$SCRIPT" install "$FIXTURE_PLUGIN" --to codex --codex-home "$TMP_DIR" --agents-home "$TMP_DIR/.agents"
	[ "$status" -eq 0 ]

	run grep -nF 'disable-model-invocation: true' "$TMP_DIR/.codex/skills/quoted-hidden/SKILL.md"
	[ "$status" -eq 0 ]
	run grep -nF 'user-invocable: false' "$TMP_DIR/.codex/skills/quoted-hidden/SKILL.md"
	[ "$status" -eq 0 ]
	run grep -nF 'disable-model-invocation: false' "$TMP_DIR/.codex/skills/quoted-enabled/SKILL.md"
	[ "$status" -eq 0 ]
	run grep -nF 'user-invocable: true' "$TMP_DIR/.codex/skills/quoted-enabled/SKILL.md"
	[ "$status" -eq 0 ]
	run grep -RFn 'user-invocable: "false"' "$TMP_DIR/.codex/skills"
	[ "$status" -eq 1 ]
	run grep -RFn 'disable-model-invocation: "true"' "$TMP_DIR/.codex/skills"
	[ "$status" -eq 1 ]
}

@test "converter normalizes boolean frontmatter fields from shared schema" {
	if ! command -v node >/dev/null 2>&1; then
		skip "node is required for converter tests"
	fi

	run node -e '
const assert = require("assert");
const schema = require(process.argv[1]);
const { normalizeFrontmatterField } = require(process.argv[2]);

const fields = schema.skill_frontmatter.fields;
for (const [field, contract] of Object.entries(fields)) {
  if (contract.type === "boolean") {
    assert.strictEqual(normalizeFrontmatterField(field, "true"), true, field);
    assert.strictEqual(normalizeFrontmatterField(field, "false"), false, field);
  } else {
    assert.strictEqual(normalizeFrontmatterField(field, "true"), "true", field);
  }
}
console.log("ok");
' "$REPO_ROOT/scripts/schemas/skill-contracts.json" "$REPO_ROOT/scripts/convert-plugin/loader"
	[ "$status" -eq 0 ]
	[ "$output" = "ok" ]
}

@test "codex conversion preserves representative skill contracts" {
	if ! command -v node >/dev/null 2>&1; then
		skip "node is required for converter tests"
	fi

	run node "$SCRIPT" install "$REPO_ROOT" --to codex --codex-home "$TMP_DIR" --agents-home "$TMP_DIR/.agents"
	[ "$status" -eq 0 ]

	local work_from_plan="$TMP_DIR/.codex/skills/kramme:code:work-from-plan/SKILL.md"
	local siw_issue_implement="$TMP_DIR/.codex/skills/kramme:siw:issue-implement/SKILL.md"
	local pr_code_review="$TMP_DIR/.codex/skills/kramme:pr:code-review/SKILL.md"
	local breakdown_findings="$TMP_DIR/.codex/skills/kramme:code:breakdown-findings/SKILL.md"
	local cleanup="$TMP_DIR/.codex/skills/kramme:workflow-artifacts:cleanup/SKILL.md"

	[ -f "$work_from_plan" ]
	[ -f "$siw_issue_implement" ]
	[ -f "$pr_code_review" ]
	[ -f "$breakdown_findings" ]
	[ -f "$cleanup" ]

	run grep -nF 'argument-hint: "[plan path | inline plan]"' "$work_from_plan"
	[ "$status" -eq 0 ]
	run grep -nF "PLAN ROUTE:" "$work_from_plan"
	[ "$status" -eq 0 ]
	run grep -nF "MISSING REQUIREMENT" "$work_from_plan"
	[ "$status" -eq 0 ]

	run grep -nF "argument-hint: <issue-id> | --team [issue-ids | 'phase N'] [--auto]" "$siw_issue_implement"
	[ "$status" -eq 0 ]
	run grep -nF "siw/issues/ISSUE-{prefix}-{number}-*.md" "$siw_issue_implement"
	[ "$status" -eq 0 ]
	run grep -nF "siw/OPEN_ISSUES_OVERVIEW.md" "$siw_issue_implement"
	[ "$status" -eq 0 ]

	run grep -nF "argument-hint: \"[aspects] [--emphasize <dim>...] [--base <branch>] [--previous-review <path>] [--parallel] [parallel] [--team] [--inline]\"" "$pr_code_review"
	[ "$status" -eq 0 ]
	run grep -nF "REVIEW_OVERVIEW.md" "$pr_code_review"
	[ "$status" -eq 0 ]

	run grep -nF "PR_PLAN_{EXECUTION_LABEL}_{SLUG}.md" "$breakdown_findings"
	[ "$status" -eq 0 ]
	run grep -nF "PR_PLAN_*.md" "$cleanup"
	[ "$status" -eq 0 ]
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

@test "codex hook conversion excludes local hook state and config files" {
	if ! command -v node >/dev/null 2>&1; then
		skip "node is required for converter tests"
	fi

	FIXTURE_PLUGIN="$TMP_DIR/hook-local-state-plugin"
	create_hook_fixture_plugin "$FIXTURE_PLUGIN" "hook-local-state-plugin" "alpha-hook"
	printf '%s\n' '{"disabled":["alpha-hook"]}' >"$FIXTURE_PLUGIN/hooks/hook-state.json"
	printf '%s\n' 'CONTEXT_LINKS_LINEAR_WORKSPACE_SLUG="local"' >"$FIXTURE_PLUGIN/hooks/context-links.config"
	printf '%s\n' 'CONTEXT_LINKS_LINEAR_WORKSPACE_SLUG="example"' >"$FIXTURE_PLUGIN/hooks/context-links.config.example"

	run node "$SCRIPT" install "$FIXTURE_PLUGIN" --to codex --codex-home "$TMP_DIR" --agents-home "$TMP_DIR/.agents"
	[ "$status" -eq 0 ]

	local marketplace_hooks="$TMP_DIR/.codex/.kramme-plugin-marketplaces/hook-local-state-plugin/plugins/hook-local-state-plugin/hooks"
	local cache_hooks="$TMP_DIR/.codex/plugins/cache/hook-local-state-plugin/hook-local-state-plugin/1.0.0/hooks"

	[ -f "$cache_hooks/alpha-hook.sh" ]
	[ -f "$cache_hooks/context-links.config.example" ]
	[ ! -f "$cache_hooks/hook-state.json" ]
	[ ! -f "$cache_hooks/context-links.config" ]
	[ ! -f "$marketplace_hooks/hook-state.json" ]
	[ ! -f "$marketplace_hooks/context-links.config" ]

	printf '%s\n' '{"disabled":["alpha-hook"]}' >"$cache_hooks/hook-state.json"
	printf '%s\n' 'CONTEXT_LINKS_LINEAR_WORKSPACE_SLUG="stale-cache"' >"$cache_hooks/context-links.config"
	printf '%s\n' '{"disabled":["alpha-hook"]}' >"$marketplace_hooks/hook-state.json"
	printf '%s\n' 'CONTEXT_LINKS_LINEAR_WORKSPACE_SLUG="stale-marketplace"' >"$marketplace_hooks/context-links.config"

	run node "$SCRIPT" install "$FIXTURE_PLUGIN" --to codex --codex-home "$TMP_DIR" --agents-home "$TMP_DIR/.agents"
	[ "$status" -eq 0 ]

	[ ! -f "$cache_hooks/hook-state.json" ]
	[ ! -f "$cache_hooks/context-links.config" ]
	[ ! -f "$marketplace_hooks/hook-state.json" ]
	[ ! -f "$marketplace_hooks/context-links.config" ]
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

	run grep -nE '\$kramme:codebase-pattern-reviewer skill' "$TMP_DIR/.codex/skills/kramme:siw:spec-audit/references/team-mode.md"
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

	run grep -REn '\bAskUserQuestion\b|\bTask (tool|subagent|sub-agent|agent)\b|\bSkill tool\b|\bTodoWrite\b|\bTodoRead\b|\bsubagent_type\b|\bmodel=opus\b|\bmodel=sonnet\b' "$TMP_DIR/.codex/skills"
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
Surface matches via the same `AskUserQuestion` prompt in step 3.
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
	[[ "$output" == *"Surface matches via the same direct chat prompt in step 3."* ]]
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

@test "codex writer removes stale managed skill files when cleanup is skipped" {
	if ! command -v node >/dev/null 2>&1; then
		skip "node is required for converter tests"
	fi

	cat >"$TMP_DIR/stale-managed-skill-files.js" <<'JS'
const assert = require("assert");
const fs = require("fs");
const path = require("path");

const outputRoot = process.argv[2];
const agentsHome = process.argv[3];
const writerPath = process.argv[4];
const { writeCodexBundle } = require(writerPath);

const sourceDir = path.join(outputRoot, "source-skill");
const options = {
  pluginName: "managed-file-plugin",
  agentsHome,
  confirm: { yes: true },
};

function writeSourceSkill(files) {
  fs.rmSync(sourceDir, { recursive: true, force: true });
  for (const [relativePath, content] of Object.entries(files)) {
    const filePath = path.join(sourceDir, relativePath);
    fs.mkdirSync(path.dirname(filePath), { recursive: true });
    fs.writeFileSync(filePath, content);
  }
}

function bundle() {
  return {
    prompts: [],
    skillDirs: [
      {
        name: "fixture-managed",
        sourceDir,
        content: null,
      },
    ],
    generatedSkills: [{ name: "fixture-generated", content: "Generated" }],
    agentSkills: [{ name: "fixture-agent", content: "Agent" }],
    mcpServers: {},
    codexPlugin: null,
    knownCommands: [],
    knownAgentSkills: [],
  };
}

function readManifest() {
  return JSON.parse(
    fs.readFileSync(
      path.join(
        outputRoot,
        ".codex",
        ".kramme-install-manifests",
        "managed-file-plugin-codex.json",
      ),
      "utf8",
    ),
  );
}

(async () => {
  writeSourceSkill({
    "SKILL.md": "Managed v1\n",
    "references/OLD.md": "old managed file\n",
  });

  await writeCodexBundle(outputRoot, bundle(), options);

  const skillDir = path.join(outputRoot, ".codex", "skills", "fixture-managed");
  const oldManagedFile = path.join(skillDir, "references", "OLD.md");
  const newManagedFile = path.join(skillDir, "references", "NEW.md");
  const localNotes = path.join(skillDir, "LOCAL-NOTES.md");
  assert.strictEqual(fs.existsSync(oldManagedFile), true);

  let manifest = readManifest();
  assert.deepStrictEqual(manifest.skillFiles["fixture-managed"], [
    "SKILL.md",
    "references/OLD.md",
  ]);
  assert.deepStrictEqual(manifest.skillFiles["fixture-generated"], [
    "SKILL.md",
  ]);
  assert.deepStrictEqual(manifest.agentSkillFiles["fixture-agent"], [
    "SKILL.md",
  ]);

  fs.writeFileSync(localNotes, "keep local notes\n");
  writeSourceSkill({
    "SKILL.md": "Managed v2\n",
    "references/NEW.md": "new managed file\n",
  });

  await writeCodexBundle(outputRoot, bundle(), {
    ...options,
    confirm: { nonInteractive: true },
  });

  assert.strictEqual(fs.existsSync(oldManagedFile), false);
  assert.strictEqual(fs.existsSync(newManagedFile), true);
  assert.strictEqual(fs.readFileSync(localNotes, "utf8"), "keep local notes\n");

  manifest = readManifest();
  assert.deepStrictEqual(manifest.skillFiles["fixture-managed"], [
    "SKILL.md",
    "references/NEW.md",
  ]);
  assert.deepStrictEqual(manifest.skillFiles["fixture-generated"], [
    "SKILL.md",
  ]);
  assert.deepStrictEqual(manifest.agentSkillFiles["fixture-agent"], [
    "SKILL.md",
  ]);
})();
JS

	run node "$TMP_DIR/stale-managed-skill-files.js" "$TMP_DIR" "$TMP_DIR/.agents" "$REPO_ROOT/scripts/convert-plugin/codex-writer"
	[ "$status" -eq 0 ]
}

@test "codex writer preserves previous skill files when stale pruning preflight fails" {
	if ! command -v node >/dev/null 2>&1; then
		skip "node is required for converter tests"
	fi

	cat >"$TMP_DIR/stale-prune-conflict.js" <<'JS'
const assert = require("assert");
const fs = require("fs");
const path = require("path");

const outputRoot = process.argv[2];
const agentsHome = process.argv[3];
const writerPath = process.argv[4];
const { writeCodexBundle } = require(writerPath);

const sourceDir = path.join(outputRoot, "source-skill");
const options = {
  pluginName: "managed-prune-conflict-plugin",
  agentsHome,
  confirm: { yes: true },
};

function writeSourceSkill(files) {
  fs.rmSync(sourceDir, { recursive: true, force: true });
  for (const [relativePath, content] of Object.entries(files)) {
    const filePath = path.join(sourceDir, relativePath);
    fs.mkdirSync(path.dirname(filePath), { recursive: true });
    fs.writeFileSync(filePath, content);
  }
}

function bundle() {
  return {
    prompts: [],
    skillDirs: [
      {
        name: "fixture-managed",
        sourceDir,
        content: null,
      },
    ],
    generatedSkills: [],
    agentSkills: [],
    mcpServers: {},
    codexPlugin: null,
    knownCommands: [],
    knownAgentSkills: [],
  };
}

(async () => {
  writeSourceSkill({
    "SKILL.md": "Managed v1\n",
    "OLD.md": "old managed file\n",
  });

  await writeCodexBundle(outputRoot, bundle(), options);

  const skillDir = path.join(outputRoot, ".codex", "skills", "fixture-managed");
  const oldManagedFile = path.join(skillDir, "OLD.md");
  const blockingFile = path.join(skillDir, "conflict");
  const statePath = path.join(outputRoot, ".codex", ".kramme-install-state.json");
  const manifestPath = path.join(
    outputRoot,
    ".codex",
    ".kramme-install-manifests",
    "managed-prune-conflict-plugin-codex.json",
  );
  const stateBefore = fs.readFileSync(statePath, "utf8");
  const manifestBefore = fs.readFileSync(manifestPath, "utf8");
  fs.writeFileSync(blockingFile, "local blocker\n");

  writeSourceSkill({
    "SKILL.md": "Managed v2\n",
    "conflict/NEW.md": "new managed file\n",
  });

  let failed = false;
  try {
    await writeCodexBundle(outputRoot, bundle(), {
      ...options,
      confirm: { nonInteractive: true },
    });
  } catch (error) {
    failed = true;
    assert.match(error.message, /conflicts with staged directory conflict/);
  }

  assert.strictEqual(failed, true, "replacement install should fail");
  assert.strictEqual(fs.existsSync(oldManagedFile), true);
  assert.strictEqual(
    fs.readFileSync(path.join(skillDir, "SKILL.md"), "utf8"),
    "Managed v1\n",
  );
  assert.strictEqual(fs.readFileSync(blockingFile, "utf8"), "local blocker\n");
  assert.strictEqual(fs.readFileSync(statePath, "utf8"), stateBefore);
  assert.strictEqual(fs.readFileSync(manifestPath, "utf8"), manifestBefore);
})();
JS

	run node "$TMP_DIR/stale-prune-conflict.js" "$TMP_DIR" "$TMP_DIR/.agents" "$REPO_ROOT/scripts/convert-plugin/codex-writer"
	[ "$status" -eq 0 ]
}

@test "install staging does not prune stale files through symlinked ancestors" {
	if ! command -v node >/dev/null 2>&1; then
		skip "node is required for converter tests"
	fi

	cat >"$TMP_DIR/prune-symlink-ancestor.js" <<'JS'
const assert = require("assert");
const fs = require("fs");
const path = require("path");

const outputRoot = process.argv[2];
const stagingPath = process.argv[3];
const { pruneStaleManagedFiles } = require(stagingPath);

(async () => {
  const skillDir = path.join(outputRoot, "skill");
  const outsideDir = path.join(outputRoot, "outside");
  fs.mkdirSync(skillDir, { recursive: true });
  fs.mkdirSync(outsideDir, { recursive: true });

  const outsideFile = path.join(outsideDir, "OLD.md");
  fs.writeFileSync(outsideFile, "outside\n");
  fs.symlinkSync(outsideDir, path.join(skillDir, "references"), "dir");

  await pruneStaleManagedFiles(
    skillDir,
    ["references/OLD.md"],
    ["SKILL.md"],
  );

  assert.strictEqual(fs.readFileSync(outsideFile, "utf8"), "outside\n");
  assert.strictEqual(
    fs.lstatSync(path.join(skillDir, "references")).isSymbolicLink(),
    true,
  );
})();
JS

	run node "$TMP_DIR/prune-symlink-ancestor.js" "$TMP_DIR" "$REPO_ROOT/scripts/convert-plugin/install-staging"
	[ "$status" -eq 0 ]
}

@test "codex writer preserves untracked same-name skill directories on first install" {
	if ! command -v node >/dev/null 2>&1; then
		skip "node is required for converter tests"
	fi

	cat >"$TMP_DIR/preserve-untracked-skill-dirs.js" <<'JS'
const assert = require("assert");
const fs = require("fs");
const path = require("path");

const outputRoot = process.argv[2];
const agentsHome = process.argv[3];
const writerPath = process.argv[4];
const { writeCodexBundle } = require(writerPath);

(async () => {
  const codexSkillDir = path.join(
    outputRoot,
    ".codex",
    "skills",
    "collision-skill",
  );
  const agentSkillDir = path.join(agentsHome, "skills", "collision-agent");
  fs.mkdirSync(codexSkillDir, { recursive: true });
  fs.mkdirSync(agentSkillDir, { recursive: true });
  fs.writeFileSync(path.join(codexSkillDir, "LOCAL-NOTES.md"), "keep codex\n");
  fs.writeFileSync(path.join(agentSkillDir, "LOCAL-NOTES.md"), "keep agent\n");

  await writeCodexBundle(
    outputRoot,
    {
      prompts: [],
      skillDirs: [],
      generatedSkills: [{ name: "collision-skill", content: "Generated" }],
      agentSkills: [{ name: "collision-agent", content: "Agent" }],
      mcpServers: {},
      codexPlugin: null,
      knownCommands: [],
      knownAgentSkills: [],
    },
    {
      pluginName: "collision-plugin",
      agentsHome,
      confirm: { yes: true },
    },
  );

  assert.strictEqual(
    fs.readFileSync(path.join(codexSkillDir, "LOCAL-NOTES.md"), "utf8"),
    "keep codex\n",
  );
  assert.strictEqual(
    fs.readFileSync(path.join(agentSkillDir, "LOCAL-NOTES.md"), "utf8"),
    "keep agent\n",
  );
  assert.strictEqual(
    fs.readFileSync(path.join(codexSkillDir, "SKILL.md"), "utf8"),
    "Generated\n",
  );
  assert.strictEqual(
    fs.readFileSync(path.join(agentSkillDir, "SKILL.md"), "utf8"),
    "Agent\n",
  );
})();
JS

	run node "$TMP_DIR/preserve-untracked-skill-dirs.js" "$TMP_DIR" "$TMP_DIR/.agents" "$REPO_ROOT/scripts/convert-plugin/codex-writer"
	[ "$status" -eq 0 ]
}

@test "codex writer preserves previous install when replacement bundle fails" {
	if ! command -v node >/dev/null 2>&1; then
		skip "node is required for converter tests"
	fi

	cat >"$TMP_DIR/failed-replacement-install.js" <<'JS'
const assert = require("assert");
const fs = require("fs");
const path = require("path");

const outputRoot = process.argv[2];
const agentsHome = process.argv[3];
const writerPath = process.argv[4];
const { writeCodexBundle } = require(writerPath);

function bundleWithGeneratedSkill(skill) {
  return {
    prompts: [],
    skillDirs: [],
    generatedSkills: [skill],
    agentSkills: [],
    mcpServers: {},
    codexPlugin: null,
    knownCommands: [],
    knownAgentSkills: [],
  };
}

(async () => {
  const options = {
    pluginName: "transactional-plugin",
    agentsHome,
    confirm: { yes: true },
  };
  const stableSkill = path.join(
    outputRoot,
    ".codex",
    "skills",
    "stable-skill",
    "SKILL.md",
  );
  const statePath = path.join(outputRoot, ".codex", ".kramme-install-state.json");
  const manifestPath = path.join(
    outputRoot,
    ".codex",
    ".kramme-install-manifests",
    "transactional-plugin-codex.json",
  );

  await writeCodexBundle(
    outputRoot,
    bundleWithGeneratedSkill({ name: "stable-skill", content: "Stable v1" }),
    options,
  );
  assert.strictEqual(fs.readFileSync(stableSkill, "utf8"), "Stable v1\n");
  const stateBefore = fs.readFileSync(statePath, "utf8");
  const manifestBefore = fs.readFileSync(manifestPath, "utf8");

  let failed = false;
  try {
    await writeCodexBundle(
      outputRoot,
      bundleWithGeneratedSkill({ name: "../invalid-skill", content: "Broken" }),
      options,
    );
  } catch (error) {
    failed = true;
    assert.match(error.message, /Invalid skill name/);
  }

  assert.strictEqual(failed, true, "replacement install should fail");
  assert.strictEqual(fs.readFileSync(stableSkill, "utf8"), "Stable v1\n");
  assert.strictEqual(fs.readFileSync(statePath, "utf8"), stateBefore);
  assert.strictEqual(fs.readFileSync(manifestPath, "utf8"), manifestBefore);
})();
JS

	run node "$TMP_DIR/failed-replacement-install.js" "$TMP_DIR" "$TMP_DIR/.agents" "$REPO_ROOT/scripts/convert-plugin/codex-writer"
	[ "$status" -eq 0 ]
}

@test "codex writer preserves previous install when finalization is blocked" {
	if ! command -v node >/dev/null 2>&1; then
		skip "node is required for converter tests"
	fi

	cat >"$TMP_DIR/blocked-finalization-install.js" <<'JS'
const assert = require("assert");
const fs = require("fs");
const path = require("path");

const outputRoot = process.argv[2];
const agentsHome = process.argv[3];
const writerPath = process.argv[4];
const { writeCodexBundle } = require(writerPath);

function bundleWithGeneratedSkills(skills) {
  return {
    prompts: [],
    skillDirs: [],
    generatedSkills: skills,
    agentSkills: [],
    mcpServers: {},
    codexPlugin: null,
    knownCommands: [],
    knownAgentSkills: [],
  };
}

(async () => {
  const options = {
    pluginName: "finalization-plugin",
    agentsHome,
    confirm: { yes: true },
  };
  const skillsRoot = path.join(outputRoot, ".codex", "skills");
  const stableSkill = path.join(skillsRoot, "stable-skill", "SKILL.md");
  const blockedSkill = path.join(skillsRoot, "blocked-skill");
  const statePath = path.join(outputRoot, ".codex", ".kramme-install-state.json");
  const manifestPath = path.join(
    outputRoot,
    ".codex",
    ".kramme-install-manifests",
    "finalization-plugin-codex.json",
  );

  await writeCodexBundle(
    outputRoot,
    bundleWithGeneratedSkills([{ name: "stable-skill", content: "Stable v1" }]),
    options,
  );
  assert.strictEqual(fs.readFileSync(stableSkill, "utf8"), "Stable v1\n");
  const stateBefore = fs.readFileSync(statePath, "utf8");
  const manifestBefore = fs.readFileSync(manifestPath, "utf8");

  fs.writeFileSync(blockedSkill, "blocking file\n");

  let failed = false;
  try {
    await writeCodexBundle(
      outputRoot,
      bundleWithGeneratedSkills([
        { name: "blocked-skill", content: "Blocked" },
        { name: "stable-skill", content: "Stable v2" },
      ]),
      options,
    );
  } catch (error) {
    failed = true;
    assert.match(error.message, /not a directory/);
  }

  assert.strictEqual(failed, true, "finalization should fail before cleanup");
  assert.strictEqual(fs.readFileSync(stableSkill, "utf8"), "Stable v1\n");
  assert.strictEqual(fs.readFileSync(blockedSkill, "utf8"), "blocking file\n");
  assert.strictEqual(fs.readFileSync(statePath, "utf8"), stateBefore);
  assert.strictEqual(fs.readFileSync(manifestPath, "utf8"), manifestBefore);
})();
JS

	run node "$TMP_DIR/blocked-finalization-install.js" "$TMP_DIR" "$TMP_DIR/.agents" "$REPO_ROOT/scripts/convert-plugin/codex-writer"
	[ "$status" -eq 0 ]
}

@test "codex writer removes agent staging when agent skill staging fails" {
	if ! command -v node >/dev/null 2>&1; then
		skip "node is required for converter tests"
	fi

	cat >"$TMP_DIR/failed-agent-staging.js" <<'JS'
const assert = require("assert");
const fs = require("fs");
const path = require("path");

const outputRoot = process.argv[2];
const agentsHome = process.argv[3];
const writerPath = process.argv[4];
const { writeCodexBundle } = require(writerPath);

(async () => {
  let failed = false;
  try {
    await writeCodexBundle(
      outputRoot,
      {
        prompts: [],
        skillDirs: [],
        generatedSkills: [],
        agentSkills: [{ name: "../invalid-agent-skill", content: "Broken" }],
        mcpServers: {},
        codexPlugin: null,
        knownCommands: [],
        knownAgentSkills: [],
      },
      {
        pluginName: "agent-staging-plugin",
        agentsHome,
        confirm: { yes: true },
      },
    );
  } catch (error) {
    failed = true;
    assert.match(error.message, /Invalid agent skill name/);
  }

  assert.strictEqual(failed, true, "agent skill staging should fail");
  const stagingRoot = path.join(agentsHome, ".kramme-install-staging");
  assert.strictEqual(fs.existsSync(stagingRoot), false);
})();
JS

	run node "$TMP_DIR/failed-agent-staging.js" "$TMP_DIR" "$TMP_DIR/.agents" "$REPO_ROOT/scripts/convert-plugin/codex-writer"
	[ "$status" -eq 0 ]
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
