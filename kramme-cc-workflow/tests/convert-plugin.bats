#!/usr/bin/env bats
# CLI smoke tests for scripts/convert-plugin.js. Converter logic lives in
# tests/node/converter-*.test.js; Codex CLI calls go through the fake `codex`
# in tests/test_helper/mocks.

setup() {
	SCRIPT="$BATS_TEST_DIRNAME/../scripts/convert-plugin.js"
	REPO_ROOT="$BATS_TEST_DIRNAME/.."
	MOCK_BIN="$BATS_TEST_DIRNAME/test_helper/mocks"
	TMP_DIR="$(mktemp -d)"
	CODEX_HOME_DIR="$TMP_DIR/codex-home"
	AGENTS_HOME_DIR="$TMP_DIR/agents-home"
	FAKE_LOG="$TMP_DIR/codex.log"
	PLUGIN_VERSION="$(jq -r '.version' "$REPO_ROOT/.claude-plugin/plugin.json")"
	CACHE_ROOT="$CODEX_HOME_DIR/plugins/cache/kramme-cc-workflow/kramme-cc-workflow/$PLUGIN_VERSION"
	MARKETPLACE_ROOT="$CODEX_HOME_DIR/.kramme-plugin-marketplaces/kramme-cc-workflow"
	chmod +x "$MOCK_BIN/codex"
}

teardown() {
	if [ -n "$TMP_DIR" ] && [ -d "$TMP_DIR" ]; then
		rm -r "$TMP_DIR"
	fi
}

require_node() {
	if ! command -v node >/dev/null 2>&1; then
		skip "node is required for converter tests"
	fi
}

run_with_fake_codex() {
	run env PATH="$MOCK_BIN:$PATH" FAKE_CODEX_LOG="$FAKE_LOG" "$@"
}

install_repo_plugin() {
	run_with_fake_codex node "$SCRIPT" install "$REPO_ROOT" --codex-home "$CODEX_HOME_DIR" --agents-home "$AGENTS_HOME_DIR" --yes "$@"
}

create_isolated_converter() {
	local fixture_root="$1"
	mkdir -p "$fixture_root/scripts"
	cp "$SCRIPT" "$fixture_root/scripts/convert-plugin.js"
}

add_failing_converter_modules() {
	local fixture_root="$1"
	local module_root="$fixture_root/scripts/convert-plugin"
	mkdir -p "$module_root"

	cat >"$module_root/codex-transformer.js" <<'JS'
"use strict";

module.exports = {};
JS
	cat >"$module_root/codex-cli.js" <<'JS'
"use strict";

module.exports = {
  defaultCodexHome() {
    return "/tmp/fixture-codex-home";
  },
};
JS
	cat >"$module_root/loader.js" <<'JS'
"use strict";

module.exports = {
  async resolvePluginInput() {
    if (process.env.FIXTURE_FAILURE === "duplicate") {
      const cause = new Error("yaml package unavailable");
      throw new Error(`Unable to resolve fixture plugin: ${cause.message}`, {
        cause,
      });
    }
    if (process.env.FIXTURE_FAILURE === "duplicate-prefix") {
      const cause = new Error("primary conversion failure");
      throw new Error(`${cause.message} Rollback failed: cleanup failure`, {
        cause,
      });
    }
    if (process.env.FIXTURE_FAILURE === "deep") {
      let failure = new Error("cause-6");
      for (let index = 5; index >= 1; index -= 1) {
        failure = new Error(`cause-${index}`, { cause: failure });
      }
      throw failure;
    }
    if (process.env.FIXTURE_FAILURE === "plain-object") {
      throw { message: "plain object failure", code: "EPLAIN" };
    }
    throw new Error("Unable to resolve fixture plugin", {
      cause: new Error("yaml package unavailable"),
    });
  },
};
JS
}

add_stats_converter_modules() {
	local fixture_root="$1"
	local module_root="$fixture_root/scripts/convert-plugin"
	mkdir -p "$module_root"

	cat >"$module_root/codex-transformer.js" <<'JS'
"use strict";

module.exports = {
  convertClaudeToCodex() {
    return { skillDirs: [{}, {}], generatedSkills: [{}], agentSkills: [{}] };
  },
};
JS
	cat >"$module_root/loader.js" <<'JS'
"use strict";

module.exports = {
  async loadClaudePlugin() {
    return { manifest: {} };
  },
  async resolvePluginInput(pluginInput) {
    return pluginInput;
  },
};
JS
	cat >"$module_root/codex-cli.js" <<'JS'
"use strict";

module.exports = {
  defaultCodexHome() {
    return "/tmp/fixture-codex-home";
  },
};
JS
	for poisoned in codex-plugin-builder legacy-install-cleanup; do
		cat >"$module_root/$poisoned.js" <<'JS'
"use strict";

throw new Error("install-only module loaded by a read-only command");
JS
	done
}

create_legacy_install() {
	mkdir -p "$CODEX_HOME_DIR/skills/kramme:legacy:skill" "$AGENTS_HOME_DIR/skills/kramme:legacy-agent" "$CODEX_HOME_DIR/.kramme-install-manifests"
	printf 'legacy\n' >"$CODEX_HOME_DIR/skills/kramme:legacy:skill/SKILL.md"
	printf 'legacy\n' >"$AGENTS_HOME_DIR/skills/kramme:legacy-agent/SKILL.md"
	cat >"$CODEX_HOME_DIR/.kramme-install-state.json" <<'JSON'
{
  "version": 1,
  "plugins": {
    "kramme-cc-workflow": {
      "codex": {
        "skills": ["kramme:legacy:skill"],
        "agentSkills": ["kramme:legacy-agent"],
        "prompts": [],
        "hookMarketplaces": [],
        "pluginCaches": []
      }
    }
  }
}
JSON
	cat >"$CODEX_HOME_DIR/AGENTS.md" <<'MD'
# Keep me

<!-- BEGIN KRAMME CODEX TOOL MAP -->
tool map
<!-- END KRAMME CODEX TOOL MAP -->
MD
}

@test "help documents every command and the stats field names" {
	require_node
	run node "$SCRIPT" --help
	[ "$status" -eq 0 ]
	[[ "$output" == *"build <plugin-name|path> --out <dir>"* ]]
	[[ "$output" == *"install <plugin-name|path> [options]"* ]]
	[[ "$output" == *"uninstall <plugin-name|path> [options]"* ]]
	[[ "$output" == *"stats <plugin-name|path> [--json]"* ]]
	[[ "$output" == *"codex plugin marketplace add"* ]]
	[[ "$output" == *"codex_skills"* ]]
	[[ "$output" == *"agent_skills"* ]]
	[[ "$output" != *"doctor"* ]]
}

@test "help and unknown commands work without converter modules" {
	require_node
	local isolated="$TMP_DIR/isolated"
	create_isolated_converter "$isolated"

	run node "$isolated/scripts/convert-plugin.js" --help
	[ "$status" -eq 0 ]
	[[ "$output" == *"Usage:"* ]]

	run node "$isolated/scripts/convert-plugin.js" bogus
	[ "$status" -eq 1 ]
	[[ "$output" == *"Unknown command: bogus"* ]]
}

@test "missing converter modules render single-line command errors" {
	require_node
	local isolated="$TMP_DIR/isolated"
	create_isolated_converter "$isolated"
	add_failing_converter_modules "$isolated"

	run node "$isolated/scripts/convert-plugin.js" build fixture --out "$TMP_DIR/out"
	[ "$status" -eq 1 ]
	[ "$output" = "Unable to resolve fixture plugin: yaml package unavailable" ]

	run node "$isolated/scripts/convert-plugin.js" stats fixture
	[ "$status" -eq 1 ]
	[ "$output" = "Unable to resolve fixture plugin: yaml package unavailable" ]
}

@test "converter failures render a bounded cause chain without a stack" {
	require_node
	local isolated="$TMP_DIR/isolated"
	create_isolated_converter "$isolated"
	add_failing_converter_modules "$isolated"

	run env FIXTURE_FAILURE=duplicate node "$isolated/scripts/convert-plugin.js" stats fixture
	[ "$status" -eq 1 ]
	[ "$output" = "Unable to resolve fixture plugin: yaml package unavailable" ]

	run env FIXTURE_FAILURE=duplicate-prefix node "$isolated/scripts/convert-plugin.js" stats fixture
	[ "$status" -eq 1 ]
	[ "$output" = "primary conversion failure Rollback failed: cleanup failure" ]

	run env FIXTURE_FAILURE=deep node "$isolated/scripts/convert-plugin.js" stats fixture
	[ "$status" -eq 1 ]
	[ "$output" = "cause-1: cause-2: cause-3: cause-4: cause-5" ]

	run env FIXTURE_FAILURE=plain-object node "$isolated/scripts/convert-plugin.js" stats fixture
	[ "$status" -eq 1 ]
	[[ "$output" == *"plain object failure"* ]]
}

@test "stats reports skill counts as text and JSON without loading install modules" {
	require_node
	local isolated="$TMP_DIR/isolated"
	create_isolated_converter "$isolated"
	add_stats_converter_modules "$isolated"

	run node "$isolated/scripts/convert-plugin.js" stats fixture
	[ "$status" -eq 0 ]
	[ "${lines[0]}" = "codex_skills=3" ]
	[ "${lines[1]}" = "agent_skills=1" ]

	run node "$isolated/scripts/convert-plugin.js" stats fixture --json
	[ "$status" -eq 0 ]
	[ "$output" = '{"codex_skills":3,"agent_skills":1}' ]
}

@test "stats resolves the marketplace slug from the repository root" {
	require_node
	run bash -c 'cd "$1" && node "$2" stats kramme-cc-workflow --json' _ "$REPO_ROOT/.." "$SCRIPT"
	[ "$status" -eq 0 ]
	[ "$(printf '%s' "$output" | jq -r '.codex_skills > 0 and .agent_skills > 0')" = "true" ]
}

@test "build writes a Codex marketplace for the repository plugin" {
	require_node
	local out="$TMP_DIR/marketplace"
	run node "$SCRIPT" build "$REPO_ROOT" --out "$out"
	[ "$status" -eq 0 ]
	[[ "$output" == "Built kramme-cc-workflow $PLUGIN_VERSION ("*" skills) to $out" ]]

	local plugin_root="$out/plugins/kramme-cc-workflow"
	[ "$(jq -r '.name' "$out/.agents/plugins/marketplace.json")" = "kramme-cc-workflow" ]
	[ "$(jq -r '.plugins[0].source.path' "$out/.agents/plugins/marketplace.json")" = "./plugins/kramme-cc-workflow" ]
	[ "$(jq -r '.version' "$plugin_root/.codex-plugin/plugin.json")" = "$PLUGIN_VERSION" ]
	[ "$(jq -r '.skills' "$plugin_root/.codex-plugin/plugin.json")" = "./skills/" ]
	[ "$(jq -r '.hooks' "$plugin_root/.codex-plugin/plugin.json")" = "./hooks/hooks.json" ]
	[ -f "$plugin_root/hooks/hooks.json" ]
	[ ! -e "$plugin_root/hooks/hook-state.json" ]
	[ ! -e "$plugin_root/hooks/context-links.config" ]
	[ -x "$plugin_root/scripts/collect-review-diff.sh" ]
	[ -f "$plugin_root/skills/kramme:pr:create/SKILL.md" ]
	[ -x "$plugin_root/skills/kramme:pr:adversarial-review/scripts/run-adversarial-review.sh" ]
	[ -f "$plugin_root/skills/kramme:a11y-auditor/SKILL.md" ]

	eval "$(node "$SCRIPT" stats "$REPO_ROOT" | sed 's/^/EXPECTED_/')"
	local skill_count
	skill_count="$(find "$plugin_root/skills" -name SKILL.md | wc -l | tr -d '[:space:]')"
	[ "$skill_count" -eq $((EXPECTED_codex_skills + EXPECTED_agent_skills)) ]

	run grep -rl '\${CLAUDE_PLUGIN_ROOT' "$plugin_root/skills" --include='*.md'
	[ "$status" -eq 1 ]
	run grep -c 'plugins/cache/kramme-cc-workflow/kramme-cc-workflow/'"$PLUGIN_VERSION"'/scripts/collect-review-diff.sh' "$plugin_root/skills/kramme:pr:code-review/SKILL.md"
	[ "$status" -eq 0 ]
	[ ! -e "$out/AGENTS.md" ]
}

@test "build requires --out and refuses a non-empty output directory" {
	require_node
	run node "$SCRIPT" build "$REPO_ROOT"
	[ "$status" -eq 1 ]
	[ "$output" = "build requires --out <dir>." ]

	mkdir -p "$TMP_DIR/occupied"
	printf 'mine\n' >"$TMP_DIR/occupied/keep.txt"
	run node "$SCRIPT" build "$REPO_ROOT" --out "$TMP_DIR/occupied"
	[ "$status" -eq 1 ]
	[[ "$output" == *"is not empty"* ]]
	[ "$(cat "$TMP_DIR/occupied/keep.txt")" = "mine" ]
	[ ! -e "$TMP_DIR/occupied/plugins" ]
}

@test "install builds the marketplace and registers it through the Codex CLI" {
	require_node
	install_repo_plugin
	[ "$status" -eq 0 ]
	[[ "$output" == *"Installed kramme-cc-workflow $PLUGIN_VERSION to $CACHE_ROOT"* ]]

	[ -f "$MARKETPLACE_ROOT/.agents/plugins/marketplace.json" ]
	[ -f "$MARKETPLACE_ROOT/plugins/kramme-cc-workflow/.codex-plugin/plugin.json" ]
	[ -f "$CACHE_ROOT/skills/kramme:pr:create/SKILL.md" ]
	[ ! -e "$CODEX_HOME_DIR/skills" ]
	[ ! -e "$AGENTS_HOME_DIR/skills" ]
	[ ! -e "$CODEX_HOME_DIR/AGENTS.md" ]
	[ ! -e "$MARKETPLACE_ROOT.build-"* ]
	[ "$(cat "$FAKE_LOG")" = "plugin marketplace add $MARKETPLACE_ROOT
plugin add kramme-cc-workflow@kramme-cc-workflow --json" ]

	# Reinstalling replaces the generated marketplace in place.
	printf 'stale\n' >"$MARKETPLACE_ROOT/stale.txt"
	install_repo_plugin
	[ "$status" -eq 0 ]
	[ ! -e "$MARKETPLACE_ROOT/stale.txt" ]
	[ -f "$MARKETPLACE_ROOT/.agents/plugins/marketplace.json" ]
}

@test "install removes legacy converter output only with confirmation" {
	require_node
	create_legacy_install
	run_with_fake_codex node "$SCRIPT" install "$REPO_ROOT" --codex-home "$CODEX_HOME_DIR" --agents-home "$AGENTS_HOME_DIR" --non-interactive
	[ "$status" -eq 0 ]
	[[ "$output" == *"defaulting to No"* ]]
	[ -f "$CODEX_HOME_DIR/skills/kramme:legacy:skill/SKILL.md" ]
	[ -f "$CODEX_HOME_DIR/.kramme-install-state.json" ]

	install_repo_plugin
	[ "$status" -eq 0 ]
	[[ "$output" == *"Removed "*" legacy Codex install paths."* ]]
	[ ! -e "$CODEX_HOME_DIR/skills/kramme:legacy:skill" ]
	[ ! -e "$AGENTS_HOME_DIR/skills/kramme:legacy-agent" ]
	[ ! -e "$CODEX_HOME_DIR/.kramme-install-state.json" ]
	[ ! -e "$CODEX_HOME_DIR/.kramme-install-manifests" ]
	[ "$(cat "$CODEX_HOME_DIR/AGENTS.md")" = "# Keep me" ]
}

@test "install refuses to replace a marketplace directory it did not generate" {
	require_node
	mkdir -p "$TMP_DIR/foreign"
	printf 'mine\n' >"$TMP_DIR/foreign/notes.txt"
	install_repo_plugin --marketplace-dir "$TMP_DIR/foreign"
	[ "$status" -eq 1 ]
	[[ "$output" == *"Refusing to replace $TMP_DIR/foreign"* ]]
	[ "$(cat "$TMP_DIR/foreign/notes.txt")" = "mine" ]
	[ ! -e "$FAKE_LOG" ]
}

@test "install reports a missing Codex CLI after building the marketplace" {
	require_node
	# A PATH with node but no codex, regardless of what the host has installed.
	mkdir -p "$TMP_DIR/node-only-bin"
	ln -s "$(command -v node)" "$TMP_DIR/node-only-bin/node"
	run env PATH="$TMP_DIR/node-only-bin:/usr/bin:/bin" node "$SCRIPT" install "$REPO_ROOT" --codex-home "$CODEX_HOME_DIR" --yes
	[ "$status" -eq 1 ]
	[[ "$output" == *"codex CLI was not found on PATH"* ]]
	[ -f "$MARKETPLACE_ROOT/.agents/plugins/marketplace.json" ]
}

@test "uninstall removes the registration, marketplace, and legacy output" {
	require_node
	install_repo_plugin
	[ "$status" -eq 0 ]
	create_legacy_install
	: >"$FAKE_LOG"

	run_with_fake_codex node "$SCRIPT" uninstall "$REPO_ROOT" --codex-home "$CODEX_HOME_DIR" --agents-home "$AGENTS_HOME_DIR" --yes
	[ "$status" -eq 0 ]
	[[ "$output" == *"Uninstalled kramme-cc-workflow from $CODEX_HOME_DIR"* ]]
	[ "$(cat "$FAKE_LOG")" = "plugin remove kramme-cc-workflow@kramme-cc-workflow
plugin marketplace remove kramme-cc-workflow" ]
	[ ! -e "$MARKETPLACE_ROOT" ]
	[ ! -e "$CACHE_ROOT" ]
	[ ! -e "$CODEX_HOME_DIR/skills/kramme:legacy:skill" ]
	[ ! -e "$CODEX_HOME_DIR/.kramme-install-state.json" ]
}

@test "install-codex helper bootstraps missing converter dependencies" {
	require_node
	local yaml_dir
	yaml_dir="$(resolve_node_package_dir yaml)"

	local isolated="$TMP_DIR/isolated"
	mkdir -p "$isolated/.claude-plugin" "$isolated/kramme-cc-workflow/.claude-plugin" "$isolated/kramme-cc-workflow/scripts"
	cp "$REPO_ROOT/scripts/install-codex.sh" "$isolated/kramme-cc-workflow/scripts/install-codex.sh"
	cp "$REPO_ROOT/scripts/convert-plugin.js" "$isolated/kramme-cc-workflow/scripts/convert-plugin.js"
	cp -R "$REPO_ROOT/scripts/convert-plugin" "$isolated/kramme-cc-workflow/scripts/convert-plugin"
	cp -R "$REPO_ROOT/scripts/schemas" "$isolated/kramme-cc-workflow/scripts/schemas"

	cat >"$isolated/package.json" <<'JSON'
{
  "dependencies": {
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
	cp "$MOCK_BIN/codex" "$fakebin/codex"
	cat >"$fakebin/npm" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >"$NPM_CALLED"
mkdir -p node_modules
ln -s "$YAML_MODULE_DIR" node_modules/yaml
SH
	chmod +x "$fakebin/npm" "$fakebin/codex"

	run bash -c 'cd "$1" && PATH="$2:$PATH" NPM_CALLED="$3" YAML_MODULE_DIR="$4" FAKE_CODEX_LOG="$5" "$1/kramme-cc-workflow/scripts/install-codex.sh" --codex-home "$6" --yes' _ "$isolated" "$fakebin" "$TMP_DIR/npm-called" "$yaml_dir" "$FAKE_LOG" "$CODEX_HOME_DIR"
	[ "$status" -eq 0 ]
	[ "$(cat "$TMP_DIR/npm-called")" = "install --omit=dev --no-audit --no-fund" ]
	[ -f "$MARKETPLACE_ROOT/.agents/plugins/marketplace.json" ]
	[ -f "$CODEX_HOME_DIR/plugins/cache/kramme-cc-workflow/kramme-cc-workflow/1.0.0/.codex-plugin/plugin.json" ]
	[[ "$output" == *"Installed kramme-cc-workflow 1.0.0 to"* ]]
}

@test "every command rejects malformed or unsupported options before loading converter modules" {
	require_node
	local isolated="$TMP_DIR/isolated"
	create_isolated_converter "$isolated"
	add_failing_converter_modules "$isolated"

	run node "$isolated/scripts/convert-plugin.js" install fixture --codex-home
	[ "$status" -eq 1 ]
	[ "$output" = "--codex-home requires a directory." ]

	run node "$isolated/scripts/convert-plugin.js" install fixture --yes=maybe
	[ "$status" -eq 1 ]
	[ "$output" = "--yes requires a boolean value when one is provided." ]

	run node "$isolated/scripts/convert-plugin.js" stats fixture --json=maybe
	[ "$status" -eq 1 ]
	[ "$output" = "--json requires a boolean value when one is provided." ]

	run node "$isolated/scripts/convert-plugin.js" build fixture --out "$TMP_DIR/out" --agents-home "$TMP_DIR/a"
	[ "$status" -eq 1 ]
	[ "$output" = "build does not support --agents-home." ]

	run node "$isolated/scripts/convert-plugin.js" stats fixture --to opencode
	[ "$status" -eq 1 ]
	[ "$output" = "Unknown target: opencode" ]

	run node "$isolated/scripts/convert-plugin.js" uninstall one two
	[ "$status" -eq 1 ]
	[ "$output" = "uninstall accepts at most one plugin name or path." ]
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
