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

setup_core_path() {
	link_core_tools
	create_fake_git
}

setup_all_tools_path() {
	setup_core_path
	create_fake_tool "gh" "gh version 9.9.9"
	create_fake_tool "jq" "jq-1.7"
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
	assert_json_query '.required[] | select(.name == "git" and .status == "ok" and .version == "git version 2.99.0")'
	assert_json_query '.recommended[] | select(.name == "jq" and .status == "ok" and .version == "jq-1.7")'
	assert_json_query '.optional[] | select(.name == "bats" and .status == "ok" and .version == "Bats 1.11.0")'
	assert_json_query '.integrations[] | select(.name == "Linear" and .status == "manual-check")'
	assert_json_query '.context[] | select(.key == "branch" and .value == "test-branch")'
	assert_json_query '.context[] | select(.key == "gitState" and .value == "clean")'
	assert_json_query '.context[] | select(.key == "conductor" and .value == "yes ('"$BATS_TEST_TMPDIR"'/workspace)")'
}

@test "reports missing recommended tools in text mode" {
	setup_core_path

	run env PATH="$FAKE_BIN" "$BASH_PATH" "$SCRIPT"

	[ "$status" -eq 0 ]
	[[ "$output" == *"[ok]      git"* ]]
	[[ "$output" == *"[missing] gh"* ]]
	[[ "$output" == *"install: brew install gh"* ]]
	[[ "$output" == *"[missing] jq"* ]]
	[[ "$output" == *"install: brew install jq"* ]]
	[[ "$output" == *"Branch:                  test-branch"* ]]
	[[ "$output" == *"Git state:               clean"* ]]
}
