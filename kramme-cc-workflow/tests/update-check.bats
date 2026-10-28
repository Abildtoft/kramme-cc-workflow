#!/usr/bin/env bats
# Tests for hooks/update-check.sh. A fake curl stands in for GitHub, so no test
# touches the network.

load 'test_helper/common'

CHANGELOG_URL="https://github.com/Abildtoft/kramme-cc-workflow/blob/main/kramme-cc-workflow/CHANGELOG.md"

setup() {
	TEST_PLUGIN_ROOT="$BATS_TEST_TMPDIR/plugin"
	HOOK="$TEST_PLUGIN_ROOT/hooks/update-check.sh"
	mkdir -p "$TEST_PLUGIN_ROOT/.claude-plugin" "$TEST_PLUGIN_ROOT/hooks/lib"
	cp "$BATS_TEST_DIRNAME/../hooks/update-check.sh" "$HOOK"
	cp "$BATS_TEST_DIRNAME/../hooks/lib/check-enabled.sh" "$TEST_PLUGIN_ROOT/hooks/lib/check-enabled.sh"
	write_installed_version "0.89.0"

	FAKE_BIN="$BATS_TEST_TMPDIR/bin"
	CURL_LOG="$BATS_TEST_TMPDIR/curl.log"
	REMOTE_MANIFEST="$BATS_TEST_TMPDIR/remote-plugin.json"
	STATE_FILE="$BATS_TEST_TMPDIR/xdg-state/kramme-cc-workflow/update-check.json"
	mkdir -p "$FAKE_BIN"
	cat >"$FAKE_BIN/curl" <<EOF
#!/bin/sh
printf '%s\n' "\$*" >>"$CURL_LOG"
if [ -n "\${CURL_GATE:-}" ]; then
  touch "\$CURL_GATE.started"
  attempt=0
  while [ ! -e "\$CURL_GATE.release" ] && [ "\$attempt" -lt 200 ]; do
    sleep 0.02
    attempt=\$((attempt + 1))
  done
  [ -e "\$CURL_GATE.release" ] || exit 28
fi
[ -f "$REMOTE_MANIFEST" ] || exit 22
cat "$REMOTE_MANIFEST"
EOF
	chmod +x "$FAKE_BIN/curl"

	export CLAUDE_PLUGIN_ROOT="$TEST_PLUGIN_ROOT"
	export XDG_STATE_HOME="$BATS_TEST_TMPDIR/xdg-state"
	export KRAMME_HOOK_STATE_FILE="$BATS_TEST_TMPDIR/hook-state.json"
	export PATH="$FAKE_BIN:$PATH"
	unset KRAMME_UPDATE_CHECK_FILE CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC CURL_GATE
}

write_installed_version() {
	printf '{"name":"kramme-cc-workflow","version":"%s"}\n' "$1" >"$TEST_PLUGIN_ROOT/.claude-plugin/plugin.json"
}

write_remote_version() {
	printf '{"name":"kramme-cc-workflow","version":"%s"}\n' "$1" >"$REMOTE_MANIFEST"
}

write_state() {
	mkdir -p "$(dirname "$STATE_FILE")"
	printf '%s\n' "$1" >"$STATE_FILE"
}

# Epoch seconds one hour ago and 25 hours ago, either side of the daily check.
recent_check() {
	echo $(($(date +%s) - 3600))
}

stale_check() {
	echo $(($(date +%s) - 90000))
}

run_hook() {
	printf '%s' '{"hook_event_name":"SessionStart","source":"startup"}' | bash "$HOOK"
}

curl_calls() {
	if [ -f "$CURL_LOG" ]; then
		wc -l <"$CURL_LOG" | tr -d ' '
	else
		echo 0
	fi
}

system_message() {
	printf '%s' "$output" | jq -r '.systemMessage'
}

state_value() {
	jq -r ".$1" "$STATE_FILE"
}

write_changelog() {
	cat >"$TEST_PLUGIN_ROOT/CHANGELOG.md" <<'EOF'
# Changelog

## Unreleased

### Changed

- **Breaking:** An unreleased change that no installed version contains yet.

## [0.90.0] - 2026-11-03

### Added

- **BREAKING:** Rename a command (#2)
- Add a flag (#3)

## [0.89.0] - 2026-10-27

### Changed

- **BREAKING:** Remove a skill (#1)
- Breaking: Change a default.
  - A nested bullet that mentions breaking.

## [0.88.0] - 2026-10-20

### Changed

- **BREAKING:** A change the user already had.
EOF
}

@test "registers the hook for new sessions only" {
	run jq -e '.hooks.SessionStart[] | select(.matcher == "startup") | .hooks[] | select(.type == "command" and .command == "bash ${CLAUDE_PLUGIN_ROOT}/hooks/update-check.sh")' \
		"$BATS_TEST_DIRNAME/../hooks/hooks.json"

	[ "$status" -eq 0 ]
}

@test "records the installed version silently on the first run" {
	write_remote_version "0.89.0"

	run run_hook

	[ "$status" -eq 0 ]
	[ "$output" = "{}" ]
	[ "$(state_value seenVersion)" = "0.89.0" ]
	[ "$(state_value latestVersion)" = "0.89.0" ]
	[ "$(state_value checkedAt)" -gt "$(stale_check)" ]
	[ "$(curl_calls)" = "1" ]
	grep -F -- "--max-time 2" "$CURL_LOG"
	grep -F -- "https://raw.githubusercontent.com/Abildtoft/kramme-cc-workflow/main/kramme-cc-workflow/.claude-plugin/plugin.json" "$CURL_LOG"
}

@test "announces a newer release with the Claude Code update commands" {
	write_remote_version "0.90.0"

	run run_hook

	[ "$status" -eq 0 ]
	printf '%s' "$output" | jq -e 'keys == ["systemMessage"]'
	[ "$(system_message)" = "kramme-cc-workflow 0.90.0 is available (you have 0.89.0). Run /plugin marketplace update kramme-cc-workflow, then /reload-plugins. Turning on auto-update in /plugin → Marketplaces keeps it current. Changelog: $CHANGELOG_URL" ]
	[ "$(state_value latestVersion)" = "0.90.0" ]
}

@test "uses the Codex update commands in a Codex plugin package" {
	rm -rf "$TEST_PLUGIN_ROOT/.claude-plugin"
	mkdir -p "$TEST_PLUGIN_ROOT/.codex-plugin"
	printf '{"name":"kramme-cc-workflow","version":"0.89.0"}\n' >"$TEST_PLUGIN_ROOT/.codex-plugin/plugin.json"
	write_remote_version "0.90.0"

	run run_hook

	[ "$status" -eq 0 ]
	[ "$(system_message)" = "kramme-cc-workflow 0.90.0 is available (you have 0.89.0). Run codex plugin marketplace upgrade kramme-cc-workflow, then codex plugin add kramme-cc-workflow@kramme-cc-workflow, and restart Codex. Changelog: $CHANGELOG_URL" ]
}

@test "checks GitHub at most once a day" {
	write_remote_version "0.90.0"
	write_state "{\"checkedAt\":$(recent_check),\"latestVersion\":\"0.90.0\",\"seenVersion\":\"0.89.0\"}"

	run run_hook

	[ "$status" -eq 0 ]
	[ "$output" = "{}" ]
	[ "$(curl_calls)" = "0" ]

	write_state "{\"checkedAt\":$(stale_check),\"latestVersion\":\"0.90.0\",\"seenVersion\":\"0.89.0\"}"

	run run_hook

	[ "$status" -eq 0 ]
	[ "$(curl_calls)" = "1" ]
	[[ "$(system_message)" == "kramme-cc-workflow 0.90.0 is available (you have 0.89.0)."* ]]
}

wait_for_fetch() {
	local gate="$1"
	local attempt
	for ((attempt = 0; attempt < 200; attempt++)); do
		[ ! -e "$gate.started" ] || return 0
		sleep 0.02
	done
	return 1
}

@test "concurrent startups leave state and fetches to the lock owner" {
	write_installed_version "0.90.0"
	write_remote_version "0.90.0"
	write_state '{"checkedAt":0,"latestVersion":"0.89.0","seenVersion":"0.89.0"}'
	cp "$STATE_FILE" "$BATS_TEST_TMPDIR/state.before"
	local gate="$BATS_TEST_TMPDIR/fetch"
	CURL_GATE="$gate" bash "$HOOK" </dev/null >"$BATS_TEST_TMPDIR/first.out" &
	local first_pid=$!
	wait_for_fetch "$gate"

	write_installed_version "0.89.0"
	run run_hook
	[ "$status" -eq 0 ]
	[ "$output" = "{}" ]
	[ "$(curl_calls)" = "1" ]
	cmp -s "$STATE_FILE" "$BATS_TEST_TMPDIR/state.before"

	touch "$gate.release"
	wait "$first_pid"
	[ "$(state_value seenVersion)" = "0.90.0" ]
	jq -e '.systemMessage | contains("updated from 0.89.0 to 0.90.0")' "$BATS_TEST_TMPDIR/first.out"

	run run_hook
	[ "$output" = "{}" ]
	[ "$(state_value seenVersion)" = "0.90.0" ]
	[ "$(curl_calls)" = "1" ]
}

@test "a newer session retries its update notice after a competing older session" {
	write_remote_version "0.90.0"
	write_state '{"checkedAt":0,"latestVersion":"0.88.0","seenVersion":"0.88.0"}'
	local gate="$BATS_TEST_TMPDIR/fetch"
	CURL_GATE="$gate" bash "$HOOK" </dev/null >"$BATS_TEST_TMPDIR/first.out" &
	local first_pid=$!
	wait_for_fetch "$gate"

	write_installed_version "0.90.0"
	run run_hook
	[ "$status" -eq 0 ]
	[ "$output" = "{}" ]
	[ "$(curl_calls)" = "1" ]

	touch "$gate.release"
	wait "$first_pid"
	run run_hook
	[[ "$(system_message)" == *"updated from 0.89.0 to 0.90.0."* ]]
	[ "$(state_value seenVersion)" = "0.90.0" ]
	[ "$(curl_calls)" = "1" ]
	run run_hook
	[ "$output" = "{}" ]
}

@test "fails open when Python or a writable lock path is unavailable" {
	local no_python_bin="$BATS_TEST_TMPDIR/no-python-bin"
	mkdir -p "$no_python_bin"
	ln -s "$(command -v cat)" "$no_python_bin/cat"
	ln -s "$(command -v jq)" "$no_python_bin/jq"
	run env PATH="$no_python_bin" "$(command -v bash)" "$HOOK" </dev/null
	[ "$status" -eq 0 ]
	[ "$output" = "{}" ]
	[ ! -e "$STATE_FILE" ]

	printf 'not a directory\n' >"$BATS_TEST_TMPDIR/blocked"
	run env KRAMME_UPDATE_CHECK_FILE="$BATS_TEST_TMPDIR/blocked/state.json" bash "$HOOK" </dev/null
	[ "$status" -eq 0 ]
	[ "$output" = "{}" ]
	[ "$(curl_calls)" = "0" ]
}

@test "stays quiet when the release is not newer than the installed copy" {
	write_remote_version "0.88.0"

	run run_hook

	[ "$status" -eq 0 ]
	[ "$output" = "{}" ]
	[ "$(state_value latestVersion)" = "0.88.0" ]
}

@test "records a failed check and waits a day before retrying" {
	write_state '{"checkedAt":0,"latestVersion":"0.89.0","seenVersion":"0.89.0"}'

	run run_hook

	[ "$status" -eq 0 ]
	[ "$output" = "{}" ]
	[ "$(curl_calls)" = "1" ]
	[ "$(state_value latestVersion)" = "0.89.0" ]
	[ "$(state_value checkedAt)" -gt "$(stale_check)" ]

	write_remote_version "0.90.0"
	run run_hook

	[ "$output" = "{}" ]
	[ "$(curl_calls)" = "1" ]
}

@test "ignores a remote manifest without a release version" {
	write_state '{"checkedAt":0,"latestVersion":"0.89.0","seenVersion":"0.89.0"}'
	for remote in '{"version":"1.0"}' '{"version":"latest"}' '{"name":"no version"}' 'not json'; do
		printf '%s\n' "$remote" >"$REMOTE_MANIFEST"
		write_state '{"checkedAt":0,"latestVersion":"0.89.0","seenVersion":"0.89.0"}'

		run run_hook

		[ "$status" -eq 0 ]
		[ "$output" = "{}" ]
		[ "$(state_value latestVersion)" = "0.89.0" ]
	done
}

@test "never fetches when nonessential traffic is disabled" {
	write_remote_version "0.90.0"
	write_changelog
	write_state '{"checkedAt":0,"latestVersion":"","seenVersion":"0.88.0"}'

	run env CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1 bash -c 'printf "{}" | bash "$1"' _ "$HOOK"

	[ "$status" -eq 0 ]
	[ "$(curl_calls)" = "0" ]
	[ "$(system_message)" = "kramme-cc-workflow updated from 0.88.0 to 0.89.0 (2 breaking changes). Changelog: $CHANGELOG_URL" ]
	[ "$(state_value checkedAt)" = "0" ]
}

@test "names the new version once after an update with its breaking-change count" {
	write_installed_version "0.90.0"
	write_changelog
	write_state "{\"checkedAt\":$(recent_check),\"latestVersion\":\"0.90.0\",\"seenVersion\":\"0.88.0\"}"

	run run_hook

	[ "$status" -eq 0 ]
	[ "$(system_message)" = "kramme-cc-workflow updated from 0.88.0 to 0.90.0 (3 breaking changes). Changelog: $CHANGELOG_URL" ]
	[ "$(state_value seenVersion)" = "0.90.0" ]

	run run_hook

	[ "$status" -eq 0 ]
	[ "$output" = "{}" ]
}

@test "uses the singular for one breaking change and omits the count without a changelog" {
	write_installed_version "0.90.0"
	write_changelog
	write_state "{\"checkedAt\":$(recent_check),\"latestVersion\":\"0.90.0\",\"seenVersion\":\"0.89.0\"}"

	run run_hook

	[ "$(system_message)" = "kramme-cc-workflow updated from 0.89.0 to 0.90.0 (1 breaking change). Changelog: $CHANGELOG_URL" ]

	rm "$TEST_PLUGIN_ROOT/CHANGELOG.md"
	write_state "{\"checkedAt\":$(recent_check),\"latestVersion\":\"0.90.0\",\"seenVersion\":\"0.89.0\"}"

	run run_hook

	[ "$(system_message)" = "kramme-cc-workflow updated from 0.89.0 to 0.90.0. Changelog: $CHANGELOG_URL" ]
}

@test "does not announce an older copy from another scope or project" {
	write_state "{\"checkedAt\":$(recent_check),\"latestVersion\":\"0.90.0\",\"seenVersion\":\"0.90.0\"}"

	run run_hook

	[ "$status" -eq 0 ]
	[ "$output" = "{}" ]
	[ "$(state_value seenVersion)" = "0.90.0" ]
}

@test "puts the update and availability notices on separate lines" {
	write_changelog
	write_remote_version "0.90.0"
	write_state '{"checkedAt":0,"latestVersion":"0.89.0","seenVersion":"0.88.0"}'

	run run_hook

	[ "$status" -eq 0 ]
	[ "$(system_message | sed -n 1p)" = "kramme-cc-workflow updated from 0.88.0 to 0.89.0 (2 breaking changes). Changelog: $CHANGELOG_URL" ]
	[[ "$(system_message | sed -n 2p)" == "kramme-cc-workflow 0.90.0 is available (you have 0.89.0)."* ]]
}

@test "emits an empty object without side effects when toggled off" {
	write_remote_version "0.90.0"
	printf '{"disabled":["update-check"]}\n' >"$KRAMME_HOOK_STATE_FILE"

	run run_hook

	[ "$status" -eq 0 ]
	[ "$output" = "{}" ]
	[ "$(curl_calls)" = "0" ]
	[ ! -e "$STATE_FILE" ]
}

@test "fails open without jq or a release version in the installed manifest" {
	local no_jq_bin="$BATS_TEST_TMPDIR/no-jq-bin"
	mkdir -p "$no_jq_bin"
	ln -sf "$(command -v cat)" "$no_jq_bin/cat"
	write_remote_version "0.90.0"

	run env PATH="$no_jq_bin" "$(command -v bash)" -c 'printf "{}" | "$0" "$1"' "$(command -v bash)" "$HOOK"

	[ "$status" -eq 0 ]
	[ "$output" = "{}" ]

	for manifest in '{"version":"local"}' '{"name":"kramme-cc-workflow"}' 'not json'; do
		printf '%s\n' "$manifest" >"$TEST_PLUGIN_ROOT/.claude-plugin/plugin.json"

		run run_hook

		[ "$status" -eq 0 ]
		[ "$output" = "{}" ]
	done
	[ "$(curl_calls)" = "0" ]
	[ ! -e "$STATE_FILE" ]
}

@test "replaces malformed state as if it were the first run" {
	write_remote_version "0.89.0"
	write_state 'not json'

	run run_hook

	[ "$status" -eq 0 ]
	[ "$output" = "{}" ]
	[ "$(state_value seenVersion)" = "0.89.0" ]
	[ "$(curl_calls)" = "1" ]
}

@test "KRAMME_UPDATE_CHECK_FILE overrides the state path" {
	write_remote_version "0.89.0"
	local override="$BATS_TEST_TMPDIR/custom/update-check.json"

	run env KRAMME_UPDATE_CHECK_FILE="$override" bash -c 'printf "{}" | bash "$1"' _ "$HOOK"

	[ "$status" -eq 0 ]
	[ "$(jq -r '.seenVersion' "$override")" = "0.89.0" ]
	[ ! -e "$STATE_FILE" ]
}
