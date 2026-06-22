#!/usr/bin/env bats
# Tests for hooks/lib/check-enabled.sh toggle behavior.

load 'test_helper/common'

setup() {
	LIB="$BATS_TEST_DIRNAME/../hooks/lib/check-enabled.sh"
	TEST_PLUGIN_ROOT="$BATS_TEST_TMPDIR/plugin"
	mkdir -p "$TEST_PLUGIN_ROOT/hooks"
}

write_hook_state() {
	printf '%s\n' "$1" >"$TEST_PLUGIN_ROOT/hooks/hook-state.json"
}

run_is_hook_enabled() {
	local hook_name="$1"
	run env CLAUDE_PLUGIN_ROOT="$TEST_PLUGIN_ROOT" bash -c \
		'source "$1"; is_hook_enabled "$2"' _ "$LIB" "$hook_name"
}

run_exit_if_hook_disabled() {
	local hook_name="$1"
	local mode="${2:-}"
	if [ -n "$mode" ]; then
		run env CLAUDE_PLUGIN_ROOT="$TEST_PLUGIN_ROOT" bash -c \
			'source "$1"; exit_if_hook_disabled "$2" "$3"; echo continued' _ "$LIB" "$hook_name" "$mode"
	else
		run env CLAUDE_PLUGIN_ROOT="$TEST_PLUGIN_ROOT" bash -c \
		'source "$1"; exit_if_hook_disabled "$2"; echo continued' _ "$LIB" "$hook_name"
	fi
}

run_is_hook_enabled_without_jq() {
	local hook_name="$1"
	local fake_bin
	local bash_path
	fake_bin="$BATS_TEST_TMPDIR/no-jq-bin"
	bash_path="$(command -v bash)"
	mkdir -p "$fake_bin"

	run env PATH="$fake_bin" CLAUDE_PLUGIN_ROOT="$TEST_PLUGIN_ROOT" "$bash_path" -c \
		'source "$1"; is_hook_enabled "$2"' _ "$LIB" "$hook_name"
}

run_exit_if_hook_disabled_without_jq() {
	local hook_name="$1"
	local mode="${2:-}"
	local fake_bin
	local bash_path
	fake_bin="$BATS_TEST_TMPDIR/no-jq-bin"
	bash_path="$(command -v bash)"
	mkdir -p "$fake_bin"
	ln -sf "$(command -v cat)" "$fake_bin/cat"

	if [ -n "$mode" ]; then
		run env PATH="$fake_bin" CLAUDE_PLUGIN_ROOT="$TEST_PLUGIN_ROOT" "$bash_path" -c \
			'source "$1"; exit_if_hook_disabled "$2" "$3"; echo continued' _ "$LIB" "$hook_name" "$mode"
	else
		run env PATH="$fake_bin" CLAUDE_PLUGIN_ROOT="$TEST_PLUGIN_ROOT" "$bash_path" -c \
			'source "$1"; exit_if_hook_disabled "$2"; echo continued' _ "$LIB" "$hook_name"
	fi
}

@test "treats missing hook state as enabled" {
	run_is_hook_enabled "auto-format"

	[ "$status" -eq 0 ]
	[ -z "$output" ]
}

@test "treats hooks absent from disabled state as enabled" {
	write_hook_state '{"disabled":["block-rm-rf"]}'

	run_is_hook_enabled "auto-format"

	[ "$status" -eq 0 ]
	[ -z "$output" ]
}

@test "returns disabled status when hook is listed in disabled state" {
	write_hook_state '{"disabled":["auto-format"]}'

	run_is_hook_enabled "auto-format"

	[ "$status" -eq 1 ]
	[ -z "$output" ]
}

@test "fails open when hook state is malformed" {
	write_hook_state '{"disabled":['

	run_is_hook_enabled "auto-format"

	[ "$status" -eq 0 ]
	[ -z "$output" ]
}

@test "exits silently for disabled plain hooks" {
	write_hook_state '{"disabled":["block-rm-rf"]}'

	run_exit_if_hook_disabled "block-rm-rf"

	[ "$status" -eq 0 ]
	[ -z "$output" ]
}

@test "emits empty json object for disabled json-mode hooks" {
	write_hook_state '{"disabled":["auto-format"]}'

	run_exit_if_hook_disabled "auto-format" "json"

	[ "$status" -eq 0 ]
	[ "$output" = "{}" ]
}

@test "continues for enabled hooks" {
	write_hook_state '{"disabled":["block-rm-rf"]}'

	run_exit_if_hook_disabled "auto-format" "json"

	[ "$status" -eq 0 ]
	[ "$output" = "continued" ]
}

@test "treats hooks absent from disabled state as enabled when jq is unavailable" {
	write_hook_state '{"disabled":["block-rm-rf"]}'

	run_is_hook_enabled_without_jq "auto-format"

	[ "$status" -eq 0 ]
	[ -z "$output" ]
}

@test "returns disabled status when jq is unavailable and hook is listed" {
	write_hook_state '{"disabled":["auto-format"]}'

	run_is_hook_enabled_without_jq "auto-format"

	[ "$status" -eq 1 ]
	[ -z "$output" ]
}

@test "exits silently for disabled plain hooks when jq is unavailable" {
	write_hook_state '{"disabled":["block-rm-rf"]}'

	run_exit_if_hook_disabled_without_jq "block-rm-rf"

	[ "$status" -eq 0 ]
	[ -z "$output" ]
}

@test "fails open for malformed hook state when jq is unavailable" {
	write_hook_state '{"disabled":['

	run_is_hook_enabled_without_jq "auto-format"

	[ "$status" -eq 0 ]
	[ -z "$output" ]
}

@test "fails open for malformed hook state after matching hook when jq is unavailable" {
	write_hook_state '{"disabled":["auto-format",]}'

	run_is_hook_enabled_without_jq "auto-format"

	[ "$status" -eq 0 ]
	[ -z "$output" ]
}

@test "fails open for non-json content containing disabled state when jq is unavailable" {
	write_hook_state 'not-json {"disabled":["auto-format"]}'

	run_is_hook_enabled_without_jq "auto-format"

	[ "$status" -eq 0 ]
	[ -z "$output" ]
}
