#!/usr/bin/env bats
# Tests for skills/kramme:setup/scripts/check-environment.sh.

setup() {
	SCRIPT="$BATS_TEST_DIRNAME/../skills/kramme:setup/scripts/check-environment.sh"
	BASH_PATH="$(command -v bash)"
	REAL_JQ="$(command -v jq)"
	FAKE_BIN="$BATS_TEST_TMPDIR/bin"
	mkdir -p "$FAKE_BIN"
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
