#!/usr/bin/env bats
# Tests for skills/kramme:setup/scripts/check-environment.sh.

setup() {
	SCRIPT="$BATS_TEST_DIRNAME/../skills/kramme:setup/scripts/check-environment.sh"
	BASH_PATH="$(command -v bash)"
	REAL_JQ="$(command -v jq)"
	FAKE_BIN="$BATS_TEST_TMPDIR/bin"
	mkdir -p "$FAKE_BIN"
	# Keep host probes off the developer's real Codex, Claude, and plugin state directories.
	export CODEX_HOME="$BATS_TEST_TMPDIR/no-codex"
	export CLAUDE_CONFIG_DIR="$BATS_TEST_TMPDIR/no-claude"
	export XDG_STATE_HOME="$BATS_TEST_TMPDIR/no-state"
	unset CLAUDE_CODE_PLUGIN_CACHE_DIR KRAMME_UPDATE_CHECK_FILE CLAUDE_PROJECT_DIR
	mkdir -p "$BATS_TEST_TMPDIR/repo/.git"
	cd "$BATS_TEST_TMPDIR/repo"
}

link_core_tools() {
	ln -sf "$BASH_PATH" "$FAKE_BIN/bash"
	ln -sf "$(command -v head)" "$FAKE_BIN/head"
	ln -sf "$(command -v sed)" "$FAKE_BIN/sed"
	ln -sf "$(command -v sh)" "$FAKE_BIN/sh"
}

create_fake_git() {
	cat >"$FAKE_BIN/git" <<EOF
#!/bin/sh
if [ "\$1" = "-C" ]; then shift 2; fi
case "\$*" in
  "--version")
    echo "git version 2.99.0"
    ;;
  "rev-parse --show-toplevel")
    echo "$BATS_TEST_TMPDIR/repo"
    ;;
  "symbolic-ref --quiet --short HEAD")
    echo "test-branch"
    ;;
  "rev-parse --git-dir")
    echo ".git"
    ;;
  "worktree list --porcelain")
    echo "worktree $BATS_TEST_TMPDIR/repo"
    ;;
  "diff --quiet"|"diff --cached --quiet")
    exit 0
    ;;
  "ls-files --others --exclude-standard")
    exit 0
    ;;
  *)
    exit 0
    ;;
esac
EOF
	chmod +x "$FAKE_BIN/git"
}

create_fake_tool() {
	local name="$1"
	local version="$2"
	cat >"$FAKE_BIN/$name" <<EOF
#!/bin/sh
echo "$version"
EOF
	chmod +x "$FAKE_BIN/$name"
}

create_fake_probe_failure() {
	local name="$1"
	local version="$2"
	cat >"$FAKE_BIN/$name" <<EOF
#!/bin/sh
if [ "\$1" = "--version" ]; then
  echo "$version"
  exit 0
fi
exit 1
EOF
	chmod +x "$FAKE_BIN/$name"
}

setup_core_path() {
	link_core_tools
	create_fake_git
}

setup_all_tools_path() {
	setup_core_path
	create_fake_tool "gh" "gh version 9.9.9"
	create_fake_tool "jq" "jq-1.7"
	create_fake_tool "python3" "Python 3.12.0"
	create_fake_tool "node" "v22.0.0"
	create_fake_tool "npm" "10.0.0"
	create_fake_tool "bun" "1.1.0"
	create_fake_tool "rtk" "rtk 0.1.0"
	create_fake_tool "bats" "Bats 1.11.0"
	create_fake_tool "trash" "trash 0.9.2"
	create_fake_tool "uvx" "uvx 0.5.0"
	create_fake_tool "markitdown" "markitdown 0.1.0"
	create_fake_tool "surf" "surf 0.2.0"
	create_fake_tool "codex" "codex-cli 0.162.1"
}

assert_json_query() {
	printf '%s' "$output" | "$REAL_JQ" -e "$1" >/dev/null
}

assert_text_row() {
	local expected
	local line
	printf -v expected '%-24s %s' "$1:" "$2"

	while IFS= read -r line; do
		[ "$line" = "$expected" ] && return 0
	done <<<"$output"
	return 1
}

@test "prints usage text for help" {
	run "$BASH_PATH" "$SCRIPT" --help

	[ "$status" -eq 0 ]
	[[ "$output" == *"Usage: check-environment.sh"* ]]
	[[ "$output" == *"--json"* ]]
}

@test "rejects unknown arguments" {
	run "$BASH_PATH" "$SCRIPT" --unknown

	[ "$status" -eq 2 ]
	[[ "$output" == *"Unknown argument: --unknown"* ]]
}

@test "prints valid json with mocked tool availability and repo context" {
	setup_all_tools_path

	run env PATH="$FAKE_BIN" CONDUCTOR_WORKSPACE_PATH="$BATS_TEST_TMPDIR/workspace" "$BASH_PATH" "$SCRIPT" --json

	[ "$status" -eq 0 ]
	assert_json_query '.required[] | select(.name == "bash" and .status == "ok")'
	assert_json_query '.required[] | select(.name == "git" and .status == "ok" and .version == "git version 2.99.0")'
	assert_json_query '.required[] | select(.name == "jq" and .status == "ok" and .version == "jq-1.7")'
	assert_json_query '.required[] | select(.name == "python3" and .status == "ok" and .version == "Python 3.12.0")'
	assert_json_query '.required[] | select(.name == "node" and .status == "ok" and .version == "v22.0.0")'
	assert_json_query '.recommended[] | select(.name == "npm" and .status == "ok" and .version == "10.0.0")'
	assert_json_query '.optional[] | select(.name == "bats" and .status == "ok" and .version == "Bats 1.11.0")'
	assert_json_query '.integrations[] | select(.name == "Linear" and .status == "manual-check")'
	assert_json_query '.integrations[] | select(.name == "Conductor MCP" and .status == "manual-check")'
	assert_json_query '.context[] | select(.key == "branch" and .value == "test-branch")'
	assert_json_query '.context[] | select(.key == "gitState" and .value == "clean")'
	assert_json_query '.context[] | select(.key == "conductor" and .value == "yes ('"$BATS_TEST_TMPDIR"'/workspace)")'
}

@test "reports conductor local mode, root path, default branch, and port range in json" {
	setup_all_tools_path

	run env \
		PATH="$FAKE_BIN" \
		CONDUCTOR_IS_LOCAL=1 \
		CONDUCTOR_WORKSPACE_NAME="local workspace" \
		CONDUCTOR_WORKSPACE_PATH="$BATS_TEST_TMPDIR/workspace" \
		CONDUCTOR_ROOT_PATH="$BATS_TEST_TMPDIR/root checkout" \
		CONDUCTOR_DEFAULT_BRANCH=main \
		CONDUCTOR_PORT=55060 \
		"$BASH_PATH" "$SCRIPT" --json

	[ "$status" -eq 0 ]
	assert_json_query '.context[] | select(.key == "conductorMode" and .value == "local")'
	assert_json_query '.context[] | select(.key == "conductorWorkspaceName" and .value == "local workspace")'
	assert_json_query '.context[] | select(.key == "conductorWorkspacePath" and .value == "'"$BATS_TEST_TMPDIR"'/workspace")'
	assert_json_query '.context[] | select(.key == "conductorRootPath" and .value == "'"$BATS_TEST_TMPDIR"'/root checkout")'
	assert_json_query '.context[] | select(.key == "conductorDefaultBranch" and .value == "main")'
	assert_json_query '.context[] | select(.key == "conductorPortRange" and .value == "55060-55069")'
}

@test "reports conductor local context and integration in text mode" {
	setup_all_tools_path
	local workspace_dir="$BATS_TEST_TMPDIR/workspace"
	mkdir -p "$workspace_dir/.conductor"
	touch "$workspace_dir/.conductor/settings.toml"
	cd "$workspace_dir"

	run env \
		PATH="$FAKE_BIN" \
		CONDUCTOR_IS_LOCAL=1 \
		CONDUCTOR_WORKSPACE_NAME="local workspace" \
		CONDUCTOR_WORKSPACE_PATH="$workspace_dir" \
		CONDUCTOR_ROOT_PATH="$BATS_TEST_TMPDIR/root checkout" \
		CONDUCTOR_DEFAULT_BRANCH=main \
		CONDUCTOR_PORT=55060 \
		"$BASH_PATH" "$SCRIPT"

	[ "$status" -eq 0 ]
	[[ "$output" == *"[manual-check] Conductor MCP"* ]]
	assert_text_row "Conductor mode" "local"
	assert_text_row "Workspace name" "local workspace"
	assert_text_row "Workspace path" "$workspace_dir"
	assert_text_row "Root path" "$BATS_TEST_TMPDIR/root checkout"
	assert_text_row "Default branch" "main"
	assert_text_row "Port range" "55060-55069"
	assert_text_row ".conductor/settings.toml" "present"
}

@test "reports conductor cloud mode without ports or default branch" {
	setup_all_tools_path

	run env \
		-u CONDUCTOR_DEFAULT_BRANCH \
		-u CONDUCTOR_PORT \
		PATH="$FAKE_BIN" \
		CONDUCTOR_IS_LOCAL=0 \
		CONDUCTOR_WORKSPACE_NAME="cloud workspace" \
		CONDUCTOR_WORKSPACE_PATH="$BATS_TEST_TMPDIR/cloud-workspace" \
		CONDUCTOR_ROOT_PATH="$BATS_TEST_TMPDIR/cloud-workspace" \
		"$BASH_PATH" "$SCRIPT" --json

	[ "$status" -eq 0 ]
	assert_json_query '.context[] | select(.key == "conductorMode" and .value == "cloud")'
	assert_json_query '.context[] | select(.key == "conductorDefaultBranch" and .value == "not set")'
	assert_json_query '.context[] | select(.key == "conductorPortRange" and .value == "not set")'
}

@test "reports unknown conductor mode when the local flag is unavailable" {
	setup_all_tools_path

	run env \
		-u CONDUCTOR_IS_LOCAL \
		-u CONDUCTOR_ROOT_PATH \
		-u CONDUCTOR_DEFAULT_BRANCH \
		-u CONDUCTOR_PORT \
		PATH="$FAKE_BIN" \
		CONDUCTOR_WORKSPACE_NAME=-n \
		CONDUCTOR_WORKSPACE_PATH="$BATS_TEST_TMPDIR/workspace" \
		"$BASH_PATH" "$SCRIPT" --json

	[ "$status" -eq 0 ]
	assert_json_query '.context[] | select(.key == "conductorMode" and .value == "unknown (CONDUCTOR_IS_LOCAL unset)")'
	assert_json_query '.context[] | select(.key == "conductorWorkspaceName" and .value == "-n")'
}

@test "reports conductor facts as not set outside conductor" {
	setup_all_tools_path
	local non_conductor_dir="$BATS_TEST_TMPDIR/non-conductor"
	mkdir -p "$non_conductor_dir"
	cd "$non_conductor_dir"

	run env \
		-u CONDUCTOR_IS_LOCAL \
		-u CONDUCTOR_WORKSPACE_NAME \
		-u CONDUCTOR_WORKSPACE_PATH \
		-u CONDUCTOR_ROOT_PATH \
		-u CONDUCTOR_DEFAULT_BRANCH \
		-u CONDUCTOR_PORT \
		PATH="$FAKE_BIN" \
		"$BASH_PATH" "$SCRIPT" --json

	[ "$status" -eq 0 ]
	assert_json_query '.context[] | select(.key == "conductorMode" and .value == "not detected")'
	assert_json_query '.context[] | select(.key == "conductorWorkspaceName" and .value == "not set")'
	assert_json_query '.context[] | select(.key == "conductorWorkspacePath" and .value == "not set")'
	assert_json_query '.context[] | select(.key == "conductorRootPath" and .value == "not set")'
	assert_json_query '.context[] | select(.key == "conductorDefaultBranch" and .value == "not set")'
	assert_json_query '.context[] | select(.key == "conductorPortRange" and .value == "not set")'
	assert_json_query '.context[] | select(.key == ".conductor/settings.toml" and .value == "missing")'
}

@test "reports missing required and recommended tools in text mode" {
	setup_core_path

	run env PATH="$FAKE_BIN" "$BASH_PATH" "$SCRIPT"

	[ "$status" -eq 0 ]
	[[ "$output" == *"[ok]      git"* ]]
	[[ "$output" == *"[missing] jq"* ]]
	[[ "$output" == *"[missing] python3"* ]]
	[[ "$output" == *"install: Install Python 3.10+"* ]]
	[[ "$output" == *"[missing] node"* ]]
	[[ "$output" == *"install: Install Node.js 18+"* ]]
	[[ "$output" == *"[missing] gh"* ]]
	[[ "$output" == *"install: brew install gh"* ]]
	[[ "$output" == *"Branch:                  test-branch"* ]]
	[[ "$output" == *"Git state:               clean"* ]]
}

@test "reports required runtimes below their minimum versions" {
	setup_core_path
	create_fake_tool "jq" "jq-1.7"
	create_fake_tool "python3" "Python 3.9.0"
	create_fake_tool "node" "v17.0.0"

	run env PATH="$FAKE_BIN" "$BASH_PATH" "$SCRIPT" --json

	[ "$status" -eq 0 ]
	assert_json_query '.required[] | select(.name == "python3" and .status == "outdated" and .version == "Python 3.9.0")'
	assert_json_query '.required[] | select(.name == "node" and .status == "outdated" and .version == "v17.0.0")'
}

@test "accepts runtimes at their exact minimum versions" {
	setup_core_path
	create_fake_tool "jq" "jq-1.7"
	create_fake_tool "python3" "Python 3.10.0"
	create_fake_tool "node" "v18.0.0"

	run env PATH="$FAKE_BIN" "$BASH_PATH" "$SCRIPT" --json

	[ "$status" -eq 0 ]
	assert_json_query '.required[] | select(.name == "python3" and .status == "ok" and .version == "Python 3.10.0")'
	assert_json_query '.required[] | select(.name == "node" and .status == "ok" and .version == "v18.0.0")'
}

@test "reports runtime probe failures separately from outdated versions" {
	setup_core_path
	create_fake_tool "jq" "jq-1.7"
	create_fake_tool "python3" "Python 3.12.0"
	create_fake_probe_failure "node" "v24.0.0"

	run env PATH="$FAKE_BIN" "$BASH_PATH" "$SCRIPT" --json

	[ "$status" -eq 0 ]
	assert_json_query '.required[] | select(.name == "node" and .status == "error" and .version == "v24.0.0")'

	run env PATH="$FAKE_BIN" "$BASH_PATH" "$SCRIPT"

	[ "$status" -eq 0 ]
	[[ "$output" == *"[error]    node"* ]]
	[[ "$output" == *"runtime probe failed"* ]]
	[[ "$output" != *"[outdated] node"* ]]
}

assert_context_value() {
	printf '%s' "$output" | "$REAL_JQ" -e --arg key "$1" --arg value "$2" \
		'.context[] | select(.key == $key and .value == $value)' >/dev/null
}

@test "reports the optional codex CLI and its version in both formats" {
	setup_all_tools_path

	run env PATH="$FAKE_BIN" "$BASH_PATH" "$SCRIPT" --json

	[ "$status" -eq 0 ]
	assert_json_query '.optional[] | select(.name == "codex" and .status == "ok" and .version == "codex-cli 0.162.1")'

	run env PATH="$FAKE_BIN" "$BASH_PATH" "$SCRIPT"

	[ "$status" -eq 0 ]
	[[ "$output" == *"[ok]      codex"*"(codex-cli 0.162.1)"* ]]
}

@test "reports a missing codex CLI with its install hint in both formats" {
	setup_core_path

	run env PATH="$FAKE_BIN" "$BASH_PATH" "$SCRIPT" --json

	[ "$status" -eq 0 ]
	assert_json_query '.optional[] | select(.name == "codex" and .status == "missing" and .install == "npm install -g @openai/codex")'

	run env PATH="$FAKE_BIN" "$BASH_PATH" "$SCRIPT"

	[ "$status" -eq 0 ]
	[[ "$output" == *"[missing] codex"*"install: npm install -g @openai/codex"* ]]
}

@test "reports a cached native codex plugin without exposing or changing config" {
	setup_all_tools_path
	local codex_home="$BATS_TEST_TMPDIR/codex home"
	local cache_dir="$codex_home/plugins/cache/kramme-cc-workflow/kramme-cc-workflow"
	mkdir -p "$cache_dir/0.88.0"
	printf 'api_key = "setup-test-decoy"\n' >"$codex_home/config.toml"
	cp "$codex_home/config.toml" "$BATS_TEST_TMPDIR/config.before"
	local before_listing
	before_listing="$(find "$codex_home" -print | LC_ALL=C sort)"

	run env PATH="$FAKE_BIN" CODEX_HOME="$codex_home" "$BASH_PATH" "$SCRIPT" --json

	[ "$status" -eq 0 ]
	assert_context_value codexPlugin "installed (cached 0.88.0)"
	[[ "$output" != *"setup-test-decoy"* ]]

	run env PATH="$FAKE_BIN" CODEX_HOME="$codex_home" "$BASH_PATH" "$SCRIPT"

	[ "$status" -eq 0 ]
	assert_text_row "Codex plugin" "installed (cached 0.88.0)"
	[[ "$output" != *"setup-test-decoy"* ]]
	cmp -s "$codex_home/config.toml" "$BATS_TEST_TMPDIR/config.before"
	[ "$(find "$codex_home" -print | LC_ALL=C sort)" = "$before_listing" ]
}

@test "reports no native codex plugin for missing, empty, or file-only caches" {
	setup_all_tools_path
	local codex_home="$BATS_TEST_TMPDIR/codex"
	local cache_dir="$codex_home/plugins/cache/kramme-cc-workflow/kramme-cc-workflow"

	run env PATH="$FAKE_BIN" CODEX_HOME="$codex_home" "$BASH_PATH" "$SCRIPT" --json
	[ "$status" -eq 0 ]
	assert_context_value codexPlugin "not installed"
	[ ! -e "$codex_home" ]

	mkdir -p "$cache_dir"
	run env PATH="$FAKE_BIN" CODEX_HOME="$codex_home" "$BASH_PATH" "$SCRIPT" --json
	[ "$status" -eq 0 ]
	assert_context_value codexPlugin "not installed"

	touch "$cache_dir/not-a-version"
	run env PATH="$FAKE_BIN" CODEX_HOME="$codex_home" "$BASH_PATH" "$SCRIPT"
	[ "$status" -eq 0 ]
	assert_text_row "Codex plugin" "not installed"
}

@test "lists native codex cache versions in glob order through the HOME fallback" {
	setup_all_tools_path
	local test_home="$BATS_TEST_TMPDIR/home"
	local cache_dir="$test_home/.codex/plugins/cache/kramme-cc-workflow/kramme-cc-workflow"
	mkdir -p "$cache_dir/0.88.0" "$cache_dir/0.87.0"
	touch "$cache_dir/not-a-version"

	run env -u CODEX_HOME HOME="$test_home" PATH="$FAKE_BIN" "$BASH_PATH" "$SCRIPT" --json

	[ "$status" -eq 0 ]
	assert_context_value codexPlugin "installed (cached 0.87.0, 0.88.0)"
}

@test "skips native plugin probes when both host homes are unavailable" {
	setup_all_tools_path

	run env -u CODEX_HOME -u CLAUDE_CONFIG_DIR -u HOME PATH="$FAKE_BIN" "$BASH_PATH" "$SCRIPT" --json

	[ "$status" -eq 0 ]
	assert_context_value codexPlugin "not checked (HOME and CODEX_HOME unset)"
	assert_context_value claudePluginCache "not checked (HOME, CLAUDE_CONFIG_DIR, and CLAUDE_CODE_PLUGIN_CACHE_DIR unset)"
	assert_context_value claudeAutoUpdate "not checked (HOME, CLAUDE_CONFIG_DIR, and CLAUDE_CODE_PLUGIN_CACHE_DIR unset)"

	run env -u CODEX_HOME -u CLAUDE_CONFIG_DIR -u HOME PATH="$FAKE_BIN" "$BASH_PATH" "$SCRIPT"

	[ "$status" -eq 0 ]
	assert_text_row "Codex plugin" "not checked (HOME and CODEX_HOME unset)"
	assert_text_row "Claude plugin cache" "not checked (HOME, CLAUDE_CONFIG_DIR, and CLAUDE_CODE_PLUGIN_CACHE_DIR unset)"
}

@test "lists Claude cache versions and registrations without changing the cache" {
	setup_all_tools_path
	ln -sf "$REAL_JQ" "$FAKE_BIN/jq"
	local claude_root="$BATS_TEST_TMPDIR/claude home"
	local cache_dir="$claude_root/plugins/cache/kramme-cc-workflow/kramme-cc-workflow"
	mkdir -p "$cache_dir/0.88.0/.in_use" "$cache_dir/0.87.0/.in_use"
	touch "$cache_dir/0.87.0/.in_use/1234" "$cache_dir/not-a-version"
	printf '{"plugins":{"kramme-cc-workflow@kramme-cc-workflow":[{"installPath":"%s/0.88.0","version":"0.88.0"}]}}\n' \
		"$cache_dir" >"$claude_root/plugins/installed_plugins.json"
	cp "$claude_root/plugins/installed_plugins.json" "$BATS_TEST_TMPDIR/installed.before"
	local before_listing
	before_listing="$(find "$claude_root" -print | LC_ALL=C sort)"

	run env PATH="$FAKE_BIN" CLAUDE_CONFIG_DIR="$claude_root" "$BASH_PATH" "$SCRIPT" --json

	[ "$status" -eq 0 ]
	assert_context_value claudePluginCache "0.87.0, 0.88.0 (registered 0.88.0)"

	run env PATH="$FAKE_BIN" CLAUDE_CONFIG_DIR="$claude_root" "$BASH_PATH" "$SCRIPT"

	[ "$status" -eq 0 ]
	assert_text_row "Claude plugin cache" "0.87.0, 0.88.0 (registered 0.88.0)"
	cmp -s "$claude_root/plugins/installed_plugins.json" "$BATS_TEST_TMPDIR/installed.before"
	[ "$(find "$claude_root" -print | LC_ALL=C sort)" = "$before_listing" ]
}

@test "reports all registered scopes without choosing an active Claude version" {
	setup_all_tools_path
	ln -sf "$REAL_JQ" "$FAKE_BIN/jq"
	local claude_root="$BATS_TEST_TMPDIR/claude"
	local cache_dir="$claude_root/plugins/cache/kramme-cc-workflow/kramme-cc-workflow"
	mkdir -p "$cache_dir/0.87.0" "$cache_dir/0.88.0" "$cache_dir/0.89.0"
	"$REAL_JQ" -n --arg cache "$cache_dir" '{plugins: {
		"kramme-cc-workflow@kramme-cc-workflow": [
			{scope: "project", projectPath: "/another/project", installPath: ($cache + "/0.87.0")},
			{scope: "user", installPath: ($cache + "/0.88.0")},
			{scope: "local", projectPath: "/another/project", installPath: ($cache + "/0.88.0")}
		],
		"unrelated@other-marketplace": [{installPath: ($cache + "/0.89.0")}]
	}}' >"$claude_root/plugins/installed_plugins.json"

	run env CLAUDE_CONFIG_DIR="$claude_root" PATH="$FAKE_BIN" "$BASH_PATH" "$SCRIPT" --json
	[ "$status" -eq 0 ]
	assert_context_value claudePluginCache "0.87.0, 0.88.0, 0.89.0 (registered 0.87.0, 0.88.0)"

	run env CLAUDE_CONFIG_DIR="$claude_root" PATH="$FAKE_BIN" "$BASH_PATH" "$SCRIPT"
	[ "$status" -eq 0 ]
	assert_text_row "Claude plugin cache" "0.87.0, 0.88.0, 0.89.0 (registered 0.87.0, 0.88.0)"
}

@test "honors the Claude plugin-root override for cache and registration probes" {
	setup_all_tools_path
	ln -sf "$REAL_JQ" "$FAKE_BIN/jq"
	local plugins_root="$BATS_TEST_TMPDIR/custom plugins"
	local cache_dir="$plugins_root/cache/kramme-cc-workflow/kramme-cc-workflow"
	local default_cache="$CLAUDE_CONFIG_DIR/plugins/cache/kramme-cc-workflow/kramme-cc-workflow"
	mkdir -p "$cache_dir/0.88.0" "$default_cache/0.87.0"
	printf '{"plugins":{"kramme-cc-workflow@kramme-cc-workflow":[{"installPath":"%s/0.88.0"}]}}\n' \
		"$cache_dir" >"$plugins_root/installed_plugins.json"
	printf '{"plugins":{"kramme-cc-workflow@kramme-cc-workflow":[{"installPath":"%s/0.87.0"}]}}\n' \
		"$default_cache" >"$CLAUDE_CONFIG_DIR/plugins/installed_plugins.json"
	local before_listing
	before_listing="$(find "$plugins_root" -print | LC_ALL=C sort)"
	cp "$plugins_root/installed_plugins.json" "$BATS_TEST_TMPDIR/installed.before"

	run env CLAUDE_CODE_PLUGIN_CACHE_DIR="$plugins_root/" PATH="$FAKE_BIN" "$BASH_PATH" "$SCRIPT" --json
	[ "$status" -eq 0 ]
	assert_context_value claudePluginCache "0.88.0 (registered 0.88.0)"

	run env -u HOME -u CLAUDE_CONFIG_DIR CLAUDE_CODE_PLUGIN_CACHE_DIR="$plugins_root" PATH="$FAKE_BIN" "$BASH_PATH" "$SCRIPT"
	[ "$status" -eq 0 ]
	assert_text_row "Claude plugin cache" "0.88.0 (registered 0.88.0)"
	cmp -s "$plugins_root/installed_plugins.json" "$BATS_TEST_TMPDIR/installed.before"
	[ "$(find "$plugins_root" -print | LC_ALL=C sort)" = "$before_listing" ]
}

@test "still lists Claude cache versions when jq is missing or registration JSON is invalid" {
	setup_core_path
	local plugins_root="$BATS_TEST_TMPDIR/plugins"
	local cache_dir="$plugins_root/cache/kramme-cc-workflow/kramme-cc-workflow"
	mkdir -p "$cache_dir/0.88.0"
	printf '{"plugins":{"kramme-cc-workflow@kramme-cc-workflow":[{"installPath":"%s/0.88.0"}]}}\n' \
		"$cache_dir" >"$plugins_root/installed_plugins.json"

	run env CLAUDE_CODE_PLUGIN_CACHE_DIR="$plugins_root" PATH="$FAKE_BIN" "$BASH_PATH" "$SCRIPT" --json
	[ "$status" -eq 0 ]
	assert_context_value claudePluginCache "0.88.0"

	ln -sf "$REAL_JQ" "$FAKE_BIN/jq"
	printf 'invalid json\n' >"$plugins_root/installed_plugins.json"
	run env CLAUDE_CODE_PLUGIN_CACHE_DIR="$plugins_root" PATH="$FAKE_BIN" "$BASH_PATH" "$SCRIPT" --json
	[ "$status" -eq 0 ]
	assert_context_value claudePluginCache "0.88.0"
}

@test "uses HOME for Claude cache versions and requires an exact registered path" {
	setup_all_tools_path
	ln -sf "$REAL_JQ" "$FAKE_BIN/jq"
	local test_home="$BATS_TEST_TMPDIR/home"
	local cache_dir="$test_home/.claude/plugins/cache/kramme-cc-workflow/kramme-cc-workflow"
	mkdir -p "$cache_dir/0.88.0"

	run env -u CLAUDE_CONFIG_DIR HOME="$test_home" PATH="$FAKE_BIN" "$BASH_PATH" "$SCRIPT" --json

	[ "$status" -eq 0 ]
	assert_context_value claudePluginCache "0.88.0"

	printf '{"plugins":{"kramme-cc-workflow@kramme-cc-workflow":[{"installPath":"%s/0.88.0-superseded"}]}}\n' "$cache_dir" >"$test_home/.claude/plugins/installed_plugins.json"
	run env -u CLAUDE_CONFIG_DIR HOME="$test_home" PATH="$FAKE_BIN" "$BASH_PATH" "$SCRIPT" --json

	[ "$status" -eq 0 ]
	assert_context_value claudePluginCache "0.88.0"
}

@test "reports no Claude cache versions for missing, empty, or file-only caches" {
	setup_all_tools_path
	local claude_root="$BATS_TEST_TMPDIR/claude"
	local cache_dir="$claude_root/plugins/cache/kramme-cc-workflow/kramme-cc-workflow"

	run env PATH="$FAKE_BIN" CLAUDE_CONFIG_DIR="$claude_root" "$BASH_PATH" "$SCRIPT" --json
	[ "$status" -eq 0 ]
	assert_context_value claudePluginCache "none"
	[ ! -e "$claude_root" ]

	mkdir -p "$cache_dir"
	run env PATH="$FAKE_BIN" CLAUDE_CONFIG_DIR="$claude_root" "$BASH_PATH" "$SCRIPT" --json
	[ "$status" -eq 0 ]
	assert_context_value claudePluginCache "none"

	touch "$cache_dir/not-a-version"
	run env PATH="$FAKE_BIN" CLAUDE_CONFIG_DIR="$claude_root" "$BASH_PATH" "$SCRIPT"
	[ "$status" -eq 0 ]
	assert_text_row "Claude plugin cache" "none"
}

@test "reports the running plugin directory and Claude manifest version" {
	setup_all_tools_path
	local plugin_root
	local version
	plugin_root="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
	version="$("$REAL_JQ" -r '.version' "$plugin_root/.claude-plugin/plugin.json")"

	run env PATH="$FAKE_BIN" "$BASH_PATH" "$SCRIPT" --json

	[ "$status" -eq 0 ]
	assert_context_value pluginCopy "$plugin_root ($version)"

	run env PATH="$FAKE_BIN" "$BASH_PATH" "$SCRIPT"

	[ "$status" -eq 0 ]
	assert_text_row "Plugin copy" "$plugin_root ($version)"
}

@test "falls back to the Codex manifest or an unknown plugin copy version" {
	setup_all_tools_path
	local plugin_root="$BATS_TEST_TMPDIR/plugin copy"
	local copied_script="$plugin_root/skills/kramme:setup/scripts/check-environment.sh"
	mkdir -p "${copied_script%/*}" "$plugin_root/.claude-plugin" "$plugin_root/.codex-plugin"
	cp "$SCRIPT" "$copied_script"

	run env PATH="$FAKE_BIN" "$BASH_PATH" "$copied_script" --json
	[ "$status" -eq 0 ]
	assert_context_value pluginCopy "$plugin_root (version unknown)"

	printf '{}' >"$plugin_root/.claude-plugin/plugin.json"
	printf '{"version":"1.2.3"}' >"$plugin_root/.codex-plugin/plugin.json"
	run env PATH="$FAKE_BIN" "$BASH_PATH" "$copied_script" --json
	[ "$status" -eq 0 ]
	assert_context_value pluginCopy "$plugin_root (1.2.3)"

	printf '{"version":"4.5.6"}' >"$plugin_root/.claude-plugin/plugin.json"
	run env PATH="$FAKE_BIN" "$BASH_PATH" "$copied_script" --json
	[ "$status" -eq 0 ]
	assert_context_value pluginCopy "$plugin_root (4.5.6)"
}

@test "reports the Claude auto-update toggle for this marketplace without changing it" {
	setup_all_tools_path
	ln -sf "$REAL_JQ" "$FAKE_BIN/jq"
	local plugins_root="$BATS_TEST_TMPDIR/claude plugins"
	local record="$plugins_root/known_marketplaces.json"
	mkdir -p "$plugins_root"

	run env PATH="$FAKE_BIN" CLAUDE_CODE_PLUGIN_CACHE_DIR="$plugins_root" "$BASH_PATH" "$SCRIPT" --json
	[ "$status" -eq 0 ]
	assert_context_value claudeAutoUpdate "not registered"

	printf '{"kramme-cc-workflow":{"source":{"source":"github","repo":"Abildtoft/kramme-cc-workflow"},"autoUpdate":true}}\n' >"$record"
	cp "$record" "$BATS_TEST_TMPDIR/record.before"
	run env PATH="$FAKE_BIN" CLAUDE_CODE_PLUGIN_CACHE_DIR="$plugins_root" "$BASH_PATH" "$SCRIPT" --json
	[ "$status" -eq 0 ]
	assert_context_value claudeAutoUpdate "on (local files; confirm session policy in /plugin)"
	cmp -s "$record" "$BATS_TEST_TMPDIR/record.before"

	for entry in '{"autoUpdate":false}' '{"autoUpdate":null}' '{}'; do
		printf '{"kramme-cc-workflow":%s}\n' "$entry" >"$record"
		run env PATH="$FAKE_BIN" CLAUDE_CODE_PLUGIN_CACHE_DIR="$plugins_root" "$BASH_PATH" "$SCRIPT"
		[ "$status" -eq 0 ]
		assert_text_row "Claude auto-update" "off (local files; confirm session policy in /plugin)"
	done

	printf '{"other-marketplace":{"autoUpdate":true}}\n' >"$record"
	run env PATH="$FAKE_BIN" CLAUDE_CODE_PLUGIN_CACHE_DIR="$plugins_root" "$BASH_PATH" "$SCRIPT" --json
	[ "$status" -eq 0 ]
	assert_context_value claudeAutoUpdate "not registered"

	printf 'invalid json\n' >"$record"
	run env PATH="$FAKE_BIN" CLAUDE_CODE_PLUGIN_CACHE_DIR="$plugins_root" "$BASH_PATH" "$SCRIPT" --json
	[ "$status" -eq 0 ]
	assert_context_value claudeAutoUpdate "unknown (unreadable: $record)"
}

@test "honors Claude settings overrides before the known marketplace record" {
	setup_all_tools_path
	ln -sf "$REAL_JQ" "$FAKE_BIN/jq"
	local claude_root="$BATS_TEST_TMPDIR/claude home"
	local project_root="$BATS_TEST_TMPDIR/repo"
	local settings_dir="$project_root/.claude"
	local record="$claude_root/plugins/known_marketplaces.json"
	mkdir -p "$claude_root/plugins" "$settings_dir"
	printf '{"kramme-cc-workflow":{"autoUpdate":true}}\n' >"$record"

	printf '{"extraKnownMarketplaces":{"kramme-cc-workflow":{"autoUpdate":false}}}\n' >"$settings_dir/settings.local.json"
	run env PATH="$FAKE_BIN" CLAUDE_CONFIG_DIR="$claude_root" "$BASH_PATH" "$SCRIPT" --json
	[ "$status" -eq 0 ]
	assert_context_value claudeAutoUpdate "off (local files; confirm session policy in /plugin)"

	printf '{"extraKnownMarketplaces":{"kramme-cc-workflow":{"autoUpdate":true}}}\n' >"$settings_dir/settings.json"
	run env PATH="$FAKE_BIN" CLAUDE_CONFIG_DIR="$claude_root" "$BASH_PATH" "$SCRIPT" --json
	[ "$status" -eq 0 ]
	assert_context_value claudeAutoUpdate "off (local files; confirm session policy in /plugin)"

	rm "$settings_dir/settings.local.json"
	run env PATH="$FAKE_BIN" CLAUDE_CONFIG_DIR="$claude_root" "$BASH_PATH" "$SCRIPT" --json
	[ "$status" -eq 0 ]
	assert_context_value claudeAutoUpdate "on (local files; confirm session policy in /plugin)"

	rm "$settings_dir/settings.json"
	printf '{"extraKnownMarketplaces":{"kramme-cc-workflow":{"autoUpdate":false}}}\n' >"$claude_root/settings.json"
	run env PATH="$FAKE_BIN" CLAUDE_CONFIG_DIR="$claude_root" "$BASH_PATH" "$SCRIPT" --json
	[ "$status" -eq 0 ]
	assert_context_value claudeAutoUpdate "off (local files; confirm session policy in /plugin)"
}

@test "a marketplace entry without autoUpdate masks lower settings and uses the recorded toggle" {
	setup_all_tools_path
	ln -sf "$REAL_JQ" "$FAKE_BIN/jq"
	local settings_dir="$BATS_TEST_TMPDIR/repo/.claude"
	local record="$CLAUDE_CONFIG_DIR/plugins/known_marketplaces.json"
	mkdir -p "$settings_dir" "${record%/*}"
	printf '{"kramme-cc-workflow":{"autoUpdate":true}}\n' >"$record"
	printf '{"extraKnownMarketplaces":{"kramme-cc-workflow":{"autoUpdate":false}}}\n' >"$CLAUDE_CONFIG_DIR/settings.json"
	printf '{"extraKnownMarketplaces":{"kramme-cc-workflow":{"source":{"source":"directory","path":"/example"}}}}\n' >"$settings_dir/settings.local.json"
	cp "$settings_dir/settings.local.json" "$BATS_TEST_TMPDIR/settings.before"

	run env PATH="$FAKE_BIN" "$BASH_PATH" "$SCRIPT" --json
	[ "$status" -eq 0 ]
	assert_context_value claudeAutoUpdate "on (local files; confirm session policy in /plugin)"
	cmp -s "$settings_dir/settings.local.json" "$BATS_TEST_TMPDIR/settings.before"
}

@test "resolves shared settings in the session directory and root local settings first" {
	setup_all_tools_path
	ln -sf "$REAL_JQ" "$FAKE_BIN/jq"
	local session_dir="$BATS_TEST_TMPDIR/repo/app"
	local root_settings="$BATS_TEST_TMPDIR/repo/.claude"
	local record="$CLAUDE_CONFIG_DIR/plugins/known_marketplaces.json"
	mkdir -p "$session_dir/.claude" "$root_settings" "${record%/*}"
	printf '{"kramme-cc-workflow":{"autoUpdate":true}}\n' >"$record"
	printf '{"extraKnownMarketplaces":{"kramme-cc-workflow":{"autoUpdate":true}}}\n' >"$root_settings/settings.json"
	printf '{"extraKnownMarketplaces":{"kramme-cc-workflow":{"autoUpdate":false}}}\n' >"$session_dir/.claude/settings.json"

	cd "$session_dir"
	run env PATH="$FAKE_BIN" "$BASH_PATH" "$SCRIPT" --json
	[ "$status" -eq 0 ]
	assert_context_value claudeAutoUpdate "off (local files; confirm session policy in /plugin)"

	# CLAUDE_PROJECT_DIR keeps settings anchored to the session if the shell moves.
	cd "$BATS_TEST_TMPDIR/repo"
	run env PATH="$FAKE_BIN" CLAUDE_PROJECT_DIR="$session_dir" "$BASH_PATH" "$SCRIPT" --json
	[ "$status" -eq 0 ]
	assert_context_value claudeAutoUpdate "off (local files; confirm session policy in /plugin)"

	printf '{"extraKnownMarketplaces":{"kramme-cc-workflow":{"autoUpdate":true}}}\n' >"$session_dir/.claude/settings.local.json"
	run env PATH="$FAKE_BIN" CLAUDE_PROJECT_DIR="$session_dir" "$BASH_PATH" "$SCRIPT" --json
	[ "$status" -eq 0 ]
	assert_context_value claudeAutoUpdate "on (local files; confirm session policy in /plugin)"

	printf '{"extraKnownMarketplaces":{"kramme-cc-workflow":{"autoUpdate":false}}}\n' >"$root_settings/settings.local.json"
	run env PATH="$FAKE_BIN" CLAUDE_PROJECT_DIR="$session_dir" "$BASH_PATH" "$SCRIPT" --json
	[ "$status" -eq 0 ]
	assert_context_value claudeAutoUpdate "off (local files; confirm session policy in /plugin)"
}

@test "reads worktree local settings from the main checkout without changing either copy" {
	local real_git="$(command -v git)"
	setup_all_tools_path
	ln -sf "$REAL_JQ" "$FAKE_BIN/jq"
	ln -sf "$real_git" "$FAKE_BIN/git"
	create_fake_tool "uname" "Linux"
	local main_checkout="$BATS_TEST_TMPDIR/repo"
	local worktree="$BATS_TEST_TMPDIR/linked worktree"
	"$real_git" init -q "$main_checkout"
	"$real_git" -C "$main_checkout" -c user.name=Test -c user.email=test@example.com -c core.hooksPath=/dev/null commit -qm 'Initial test commit' --allow-empty
	"$real_git" -C "$main_checkout" worktree add -q --detach "$worktree"
	mkdir -p "$main_checkout/.claude" "$worktree/.claude"
	printf '{"extraKnownMarketplaces":{"kramme-cc-workflow":{"autoUpdate":false}}}\n' >"$main_checkout/.claude/settings.local.json"
	printf '{"extraKnownMarketplaces":{"kramme-cc-workflow":{"autoUpdate":true}}}\n' >"$worktree/.claude/settings.local.json"
	cp "$main_checkout/.claude/settings.local.json" "$BATS_TEST_TMPDIR/main.before"
	cp "$worktree/.claude/settings.local.json" "$BATS_TEST_TMPDIR/worktree.before"

	cd "$worktree"
	run env PATH="$FAKE_BIN" "$BASH_PATH" "$SCRIPT" --json
	[ "$status" -eq 0 ]
	assert_context_value claudeAutoUpdate "off (local files; confirm session policy in /plugin)"
	cmp -s "$main_checkout/.claude/settings.local.json" "$BATS_TEST_TMPDIR/main.before"
	cmp -s "$worktree/.claude/settings.local.json" "$BATS_TEST_TMPDIR/worktree.before"

	# Windows and repositories rooted at HOME keep local settings by the session.
	create_fake_tool "uname" "MINGW64_NT"
	run env PATH="$FAKE_BIN" "$BASH_PATH" "$SCRIPT" --json
	[ "$status" -eq 0 ]
	assert_context_value claudeAutoUpdate "on (local files; confirm session policy in /plugin)"
	create_fake_tool "uname" "Linux"
	run env PATH="$FAKE_BIN" HOME="$main_checkout" "$BASH_PATH" "$SCRIPT" --json
	[ "$status" -eq 0 ]
	assert_context_value claudeAutoUpdate "on (local files; confirm session policy in /plugin)"
}

@test "keeps local and shared settings together outside Git" {
	local real_git="$(command -v git)"
	setup_all_tools_path
	ln -sf "$REAL_JQ" "$FAKE_BIN/jq"
	ln -sf "$real_git" "$FAKE_BIN/git"
	local session_dir="$BATS_TEST_TMPDIR/plain"
	mkdir -p "$session_dir/.claude"
	printf '{"extraKnownMarketplaces":{"kramme-cc-workflow":{"autoUpdate":false}}}\n' >"$session_dir/.claude/settings.local.json"
	printf '{"extraKnownMarketplaces":{"kramme-cc-workflow":{"autoUpdate":true}}}\n' >"$session_dir/.claude/settings.json"
	cd "$session_dir"
	run env PATH="$FAKE_BIN" "$BASH_PATH" "$SCRIPT" --json
	[ "$status" -eq 0 ]
	assert_context_value claudeAutoUpdate "off (local files; confirm session policy in /plugin)"
}

@test "reports an unavailable session directory as unknown instead of using the registry" {
	setup_all_tools_path
	ln -sf "$REAL_JQ" "$FAKE_BIN/jq"
	mkdir -p "$CLAUDE_CONFIG_DIR/plugins"
	printf '{"kramme-cc-workflow":{"autoUpdate":true}}\n' >"$CLAUDE_CONFIG_DIR/plugins/known_marketplaces.json"
	run env PATH="$FAKE_BIN" CLAUDE_PROJECT_DIR="$BATS_TEST_TMPDIR/missing" "$BASH_PATH" "$SCRIPT" --json
	[ "$status" -eq 0 ]
	assert_context_value claudeAutoUpdate "unknown (session settings directory unavailable; check /plugin)"
}

@test "honors the marketplace alias and prefers its canonical spelling in user settings" {
	setup_all_tools_path
	ln -sf "$REAL_JQ" "$FAKE_BIN/jq"
	local test_home="$BATS_TEST_TMPDIR/home"
	local settings="$test_home/.claude/settings.json"
	mkdir -p "${settings%/*}"
	printf '{"additionalMarketplaces":{"kramme-cc-workflow":{"autoUpdate":true}}}\n' >"$settings"

	# User settings use HOME even with a separate plugin-cache override, and a
	# settings declaration can exist before known_marketplaces.json is written.
	run env -u CLAUDE_CONFIG_DIR HOME="$test_home" CLAUDE_CODE_PLUGIN_CACHE_DIR="$BATS_TEST_TMPDIR/cache" PATH="$FAKE_BIN" "$BASH_PATH" "$SCRIPT" --json
	[ "$status" -eq 0 ]
	assert_context_value claudeAutoUpdate "on (local files; confirm session policy in /plugin)"

	printf '{"additionalMarketplaces":{"kramme-cc-workflow":{"autoUpdate":true}},"extraKnownMarketplaces":{"kramme-cc-workflow":{"autoUpdate":false}}}\n' >"$settings"
	run env -u CLAUDE_CONFIG_DIR HOME="$test_home" PATH="$FAKE_BIN" "$BASH_PATH" "$SCRIPT" --json
	[ "$status" -eq 0 ]
	assert_context_value claudeAutoUpdate "off (local files; confirm session policy in /plugin)"
}

@test "managed settings override local files and managed fragments report unknown" {
	setup_all_tools_path
	ln -sf "$REAL_JQ" "$FAKE_BIN/jq"
	create_fake_tool "uname" "MINGW64_NT"
	local program_files="$BATS_TEST_TMPDIR/Program Files"
	local managed="$program_files/ClaudeCode/managed-settings.json"
	mkdir -p "${managed%/*}" "$CLAUDE_CONFIG_DIR"
	printf '{"extraKnownMarketplaces":{"kramme-cc-workflow":{"autoUpdate":true}}}\n' >"$CLAUDE_CONFIG_DIR/settings.json"
	printf '{"extraKnownMarketplaces":{"kramme-cc-workflow":{"autoUpdate":false}}}\n' >"$managed"
	cp "$managed" "$BATS_TEST_TMPDIR/managed.before"

	run env PROGRAMFILES="$program_files" PATH="$FAKE_BIN" "$BASH_PATH" "$SCRIPT" --json
	[ "$status" -eq 0 ]
	assert_context_value claudeAutoUpdate "off (local files; confirm session policy in /plugin)"
	cmp -s "$managed" "$BATS_TEST_TMPDIR/managed.before"

	mkdir -p "${managed%/*}/managed-settings.d"
	printf '{"extraKnownMarketplaces":{"kramme-cc-workflow":{"autoUpdate":true}}}\n' >"${managed%/*}/managed-settings.d/10-policy.json"
	run env PROGRAMFILES="$program_files" PATH="$FAKE_BIN" "$BASH_PATH" "$SCRIPT" --json
	[ "$status" -eq 0 ]
	assert_context_value claudeAutoUpdate "unknown (managed settings fragments; check /plugin)"
}

@test "unreadable or malformed settings report unknown instead of trusting a cached toggle" {
	setup_all_tools_path
	ln -sf "$REAL_JQ" "$FAKE_BIN/jq"
	local settings_dir="$BATS_TEST_TMPDIR/repo/.claude"
	local record="$CLAUDE_CONFIG_DIR/plugins/known_marketplaces.json"
	mkdir -p "$settings_dir" "${record%/*}"
	local resolved_settings_dir="$(cd "$settings_dir" && pwd -P)"
	printf '{"kramme-cc-workflow":{"autoUpdate":true}}\n' >"$record"
	for content in 'invalid json' '{"extraKnownMarketplaces":{"kramme-cc-workflow":{"autoUpdate":"false"}}}'; do
		printf '%s\n' "$content" >"$settings_dir/settings.local.json"
		run env PATH="$FAKE_BIN" "$BASH_PATH" "$SCRIPT" --json
		[ "$status" -eq 0 ]
		assert_context_value claudeAutoUpdate "unknown (unreadable: $resolved_settings_dir/settings.local.json)"
	done
}

@test "reports the last update-check result without fetching or changing it" {
	setup_all_tools_path
	ln -sf "$REAL_JQ" "$FAKE_BIN/jq"
	local plugin_root="$BATS_TEST_TMPDIR/plugin copy"
	local copied_script="$plugin_root/skills/kramme:setup/scripts/check-environment.sh"
	local state_file="$XDG_STATE_HOME/kramme-cc-workflow/update-check.json"
	mkdir -p "${copied_script%/*}" "$plugin_root/.claude-plugin" "${state_file%/*}"
	cp "$SCRIPT" "$copied_script"
	printf '{"version":"0.89.0"}\n' >"$plugin_root/.claude-plugin/plugin.json"

	run env PATH="$FAKE_BIN" "$BASH_PATH" "$copied_script" --json
	[ "$status" -eq 0 ]
	assert_context_value pluginUpdate "not checked yet"

	# 1793176010 is 2026-10-28 in UTC.
	printf '{"checkedAt":1793176010,"latestVersion":"0.90.0","seenVersion":"0.89.0"}\n' >"$state_file"
	cp "$state_file" "$BATS_TEST_TMPDIR/state.before"
	run env PATH="$FAKE_BIN" "$BASH_PATH" "$copied_script" --json
	[ "$status" -eq 0 ]
	assert_context_value pluginUpdate "0.90.0 available, last checked 2026-10-28"
	cmp -s "$state_file" "$BATS_TEST_TMPDIR/state.before"

	printf '{"checkedAt":1793176010,"latestVersion":"0.89.0","seenVersion":"0.89.0"}\n' >"$state_file"
	run env PATH="$FAKE_BIN" "$BASH_PATH" "$copied_script"
	[ "$status" -eq 0 ]
	assert_text_row "Plugin update" "up to date (0.89.0), last checked 2026-10-28"

	printf '{"checkedAt":0,"latestVersion":"","seenVersion":"0.89.0"}\n' >"$state_file"
	run env PATH="$FAKE_BIN" "$BASH_PATH" "$copied_script" --json
	[ "$status" -eq 0 ]
	assert_context_value pluginUpdate "not checked yet"

	printf 'invalid json\n' >"$state_file"
	run env PATH="$FAKE_BIN" "$BASH_PATH" "$copied_script" --json
	[ "$status" -eq 0 ]
	assert_context_value pluginUpdate "unknown (unreadable: $state_file)"
}

@test "resolves the update-check state file the way the hook does" {
	setup_all_tools_path
	ln -sf "$REAL_JQ" "$FAKE_BIN/jq"
	local plugin_root="$BATS_TEST_TMPDIR/plugin copy"
	local copied_script="$plugin_root/skills/kramme:setup/scripts/check-environment.sh"
	local override="$BATS_TEST_TMPDIR/custom/update-check.json"
	local home_state="$BATS_TEST_TMPDIR/home/.local/state/kramme-cc-workflow/update-check.json"
	mkdir -p "${copied_script%/*}" "${override%/*}" "${home_state%/*}"
	cp "$SCRIPT" "$copied_script"
	printf '{"checkedAt":1793176010,"latestVersion":"0.90.0"}\n' >"$override"
	printf '{"latestVersion":"0.91.0"}\n' >"$home_state"

	run env PATH="$FAKE_BIN" KRAMME_UPDATE_CHECK_FILE="$override" "$BASH_PATH" "$copied_script" --json
	[ "$status" -eq 0 ]
	assert_context_value pluginUpdate "latest release 0.90.0, last checked 2026-10-28"

	run env -u XDG_STATE_HOME PATH="$FAKE_BIN" HOME="$BATS_TEST_TMPDIR/home" "$BASH_PATH" "$copied_script" --json
	[ "$status" -eq 0 ]
	assert_context_value pluginUpdate "latest release 0.91.0"

	run env -u XDG_STATE_HOME -u HOME PATH="$FAKE_BIN" "$BASH_PATH" "$copied_script" --json
	[ "$status" -eq 0 ]
	assert_context_value pluginUpdate "not checked (HOME, XDG_STATE_HOME, and KRAMME_UPDATE_CHECK_FILE unset)"
}

@test "reports auto-update and update state as unknown without jq" {
	setup_core_path
	local plugins_root="$BATS_TEST_TMPDIR/plugins"
	local state_file="$XDG_STATE_HOME/kramme-cc-workflow/update-check.json"
	mkdir -p "$plugins_root" "${state_file%/*}"
	printf '{"kramme-cc-workflow":{"autoUpdate":true}}\n' >"$plugins_root/known_marketplaces.json"
	printf '{"latestVersion":"0.90.0"}\n' >"$state_file"

	run env PATH="$FAKE_BIN" CLAUDE_CODE_PLUGIN_CACHE_DIR="$plugins_root" "$BASH_PATH" "$SCRIPT" --json
	[ "$status" -eq 0 ]
	assert_context_value claudeAutoUpdate "unknown (jq unavailable)"
	assert_context_value pluginUpdate "unknown (jq unavailable)"
}

@test "reports legacy codex install records and tool map block without changing them" {
	setup_all_tools_path
	codex_home="$BATS_TEST_TMPDIR/codex home"
	mkdir -p "$codex_home/.kramme-install-manifests"
	printf '{}\n' >"$codex_home/.kramme-install-state.json"
	printf '# Mine\n\n<!-- BEGIN KRAMME CODEX TOOL MAP -->\nold map\n<!-- END KRAMME CODEX TOOL MAP -->\n' >"$codex_home/AGENTS.md"
	before="$(cat "$codex_home/AGENTS.md")"

	run env PATH="$FAKE_BIN" CODEX_HOME="$codex_home" "$BASH_PATH" "$SCRIPT" --json

	[ "$status" -eq 0 ]
	assert_context_value codexLegacyRecords "present (.kramme-install-state.json, .kramme-install-manifests/ in $codex_home)"
	assert_context_value codexToolMapBlock "present ($codex_home/AGENTS.md)"
	[ "$(cat "$codex_home/AGENTS.md")" = "$before" ]
	[ -f "$codex_home/.kramme-install-state.json" ]
	[ -d "$codex_home/.kramme-install-manifests" ]
}

@test "reports no codex leftovers for a clean codex home" {
	setup_all_tools_path
	codex_home="$BATS_TEST_TMPDIR/codex"
	mkdir -p "$codex_home"
	printf '# My instructions\n' >"$codex_home/AGENTS.md"

	run env PATH="$FAKE_BIN" CODEX_HOME="$codex_home" "$BASH_PATH" "$SCRIPT" --json

	[ "$status" -eq 0 ]
	assert_context_value codexLegacyRecords "none"
	assert_context_value codexToolMapBlock "absent"
}

@test "reports a tool map start marker without its end marker" {
	setup_all_tools_path
	codex_home="$BATS_TEST_TMPDIR/codex"
	mkdir -p "$codex_home"
	printf 'intro\n<!-- BEGIN KRAMME CODEX TOOL MAP -->\nleftover\n' >"$codex_home/AGENTS.md"

	run env PATH="$FAKE_BIN" CODEX_HOME="$codex_home" "$BASH_PATH" "$SCRIPT"

	[ "$status" -eq 0 ]
	assert_text_row "Codex tool map block" "incomplete: start marker without end ($codex_home/AGENTS.md)"
	assert_text_row "Codex legacy records" "none"
}

@test "falls back to HOME/.codex when CODEX_HOME is unset" {
	setup_all_tools_path
	home="$BATS_TEST_TMPDIR/home"
	mkdir -p "$home/.codex"
	printf '{}\n' >"$home/.codex/.kramme-install-state.json"

	run env -u CODEX_HOME HOME="$home" PATH="$FAKE_BIN" "$BASH_PATH" "$SCRIPT" --json

	[ "$status" -eq 0 ]
	assert_context_value codexLegacyRecords "present (.kramme-install-state.json in $home/.codex)"
	assert_context_value codexToolMapBlock "absent"
}

@test "skips the codex probes when HOME and CODEX_HOME are both unset" {
	setup_all_tools_path

	run env -u CODEX_HOME -u HOME PATH="$FAKE_BIN" "$BASH_PATH" "$SCRIPT"

	[ "$status" -eq 0 ]
	assert_text_row "Codex legacy records" "not checked (HOME and CODEX_HOME unset)"
	assert_text_row "Codex tool map block" "not checked (HOME and CODEX_HOME unset)"
}

@test "matches tool map markers by order, including both on one line" {
	setup_all_tools_path
	codex_home="$BATS_TEST_TMPDIR/codex"
	mkdir -p "$codex_home"

	printf '<!-- BEGIN KRAMME CODEX TOOL MAP --> map <!-- END KRAMME CODEX TOOL MAP -->\n' >"$codex_home/AGENTS.md"
	run env PATH="$FAKE_BIN" CODEX_HOME="$codex_home" "$BASH_PATH" "$SCRIPT" --json
	[ "$status" -eq 0 ]
	assert_context_value codexToolMapBlock "present ($codex_home/AGENTS.md)"

	printf '<!-- END KRAMME CODEX TOOL MAP -->\nlater\n<!-- BEGIN KRAMME CODEX TOOL MAP -->\n' >"$codex_home/AGENTS.md"
	run env PATH="$FAKE_BIN" CODEX_HOME="$codex_home" "$BASH_PATH" "$SCRIPT" --json
	[ "$status" -eq 0 ]
	assert_context_value codexToolMapBlock "incomplete: start marker without end ($codex_home/AGENTS.md)"
}

@test "reports whether .context is ignored and which rule ignores it" {
	link_core_tools
	ln -sf "$(command -v git)" "$FAKE_BIN/git"
	isolated_git=(HOME="$BATS_TEST_TMPDIR/home" XDG_CONFIG_HOME="$BATS_TEST_TMPDIR/xdg" GIT_CONFIG_NOSYSTEM=1)
	ignored_repo="$BATS_TEST_TMPDIR/ignored-repo"
	plain_repo="$BATS_TEST_TMPDIR/plain-repo"
	env "${isolated_git[@]}" git init -q "$ignored_repo"
	env "${isolated_git[@]}" git init -q "$plain_repo"
	printf '.context/\n' >"$ignored_repo/.gitignore"

	cd "$ignored_repo"
	run env "${isolated_git[@]}" PATH="$FAKE_BIN" CODEX_HOME="$BATS_TEST_TMPDIR/no-codex" "$BASH_PATH" "$SCRIPT" --json
	[ "$status" -eq 0 ]
	assert_context_value contextIgnored "yes (.gitignore:1:.context/)"
	[ ! -e "$ignored_repo/.context" ]

	cd "$plain_repo"
	run env "${isolated_git[@]}" PATH="$FAKE_BIN" CODEX_HOME="$BATS_TEST_TMPDIR/no-codex" "$BASH_PATH" "$SCRIPT"
	[ "$status" -eq 0 ]
	assert_text_row ".context ignored" "no"
}
