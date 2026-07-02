#!/usr/bin/env bats
# Tests for skill-usage-stats.sh hook and skill-usage.js reporting

load 'test_helper/common'

setup() {
	HOOK="$BATS_TEST_DIRNAME/../hooks/skill-usage-stats.sh"
	SCRIPT="$BATS_TEST_DIRNAME/../scripts/skill-usage.js"
	USAGE_FILE="$BATS_TEST_TMPDIR/skill-usage.jsonl"
	DIAGNOSTIC_FILE="$BATS_TEST_TMPDIR/skill-usage-diagnostics.log"
	export KRAMME_SKILL_USAGE_FILE="$USAGE_FILE"
	export KRAMME_SKILL_USAGE_DIAGNOSTIC_FILE="$DIAGNOSTIC_FILE"
	unset KRAMME_SKILL_USAGE_DIAGNOSTIC_MAX_LINES
	rm -f "$USAGE_FILE" "$DIAGNOSTIC_FILE"
}

run_usage_hook() {
	printf '%s' "$1" | bash "$HOOK"
}

create_usage_plugin_root() {
	local plugin_root="$1"
	mkdir -p "$plugin_root/hooks/lib" "$plugin_root/scripts"
	cp "$HOOK" "$plugin_root/hooks/skill-usage-stats.sh"
	cp "$BATS_TEST_DIRNAME/../hooks/lib/check-enabled.sh" "$plugin_root/hooks/lib/check-enabled.sh"
	cp "$SCRIPT" "$plugin_root/scripts/skill-usage.js"
}

@test "records explicit slash skill invocations from prompts" {
	if ! command -v node >/dev/null 2>&1; then
		skip "node is required for skill usage tests"
	fi

	run run_usage_hook '{"prompt":"Run /kramme:pr:create --draft then /kramme:verify:run","session_id":"session-1","cwd":"/tmp/repo"}'
	[ "$status" -eq 0 ]
	[ "$output" = "{}" ]

	run node "$SCRIPT" report --file "$USAGE_FILE" --json
	[ "$status" -eq 0 ]
	[ "$(echo "$output" | jq -r 'length')" = "2" ]
	[ "$(echo "$output" | jq -r '.[] | select(.skill == "kramme:pr:create") | .explicit')" = "1" ]
	[ "$(echo "$output" | jq -r '.[] | select(.skill == "kramme:verify:run") | .explicit')" = "1" ]
}

@test "deduplicates repeated skill mentions within one prompt" {
	if ! command -v node >/dev/null 2>&1; then
		skip "node is required for skill usage tests"
	fi

	run run_usage_hook '{"prompt":"/kramme:qa and /kramme:qa again","session_id":"session-1"}'
	[ "$status" -eq 0 ]
	[ "$output" = "{}" ]

	run node "$SCRIPT" report --file "$USAGE_FILE" --json
	[ "$status" -eq 0 ]
	[ "$(echo "$output" | jq -r '.[0].skill')" = "kramme:qa" ]
	[ "$(echo "$output" | jq -r '.[0].total')" = "1" ]
}

@test "does not count bare skill names in prompt text" {
	if ! command -v node >/dev/null 2>&1; then
		skip "node is required for skill usage tests"
	fi

	run run_usage_hook '{"prompt":"Discuss kramme:pr:create without invoking it","session_id":"session-1"}'
	[ "$status" -eq 0 ]
	[ "$output" = "{}" ]

	run node "$SCRIPT" report --file "$USAGE_FILE" --json
	[ "$status" -eq 0 ]
	[ "$output" = "[]" ]
}

@test "records skill tool events separately from explicit prompts" {
	if ! command -v node >/dev/null 2>&1; then
		skip "node is required for skill usage tests"
	fi

	run run_usage_hook '{"tool_name":"Skill","tool_input":{"name":"kramme:verify:run"},"session_id":"session-2"}'
	[ "$status" -eq 0 ]
	[ "$output" = "{}" ]

	run node "$SCRIPT" report --file "$USAGE_FILE" --json
	[ "$status" -eq 0 ]
	[ "$(echo "$output" | jq -r '.[0].skill')" = "kramme:verify:run" ]
	[ "$(echo "$output" | jq -r '.[0].tool')" = "1" ]
	[ "$(echo "$output" | jq -r '.[0].explicit')" = "0" ]
}

@test "report filters by kind" {
	if ! command -v node >/dev/null 2>&1; then
		skip "node is required for skill usage tests"
	fi

	run run_usage_hook '{"prompt":"/kramme:verify:run","session_id":"session-1"}'
	[ "$status" -eq 0 ]
	run run_usage_hook '{"tool_name":"Skill","tool_input":{"name":"kramme:verify:run"},"session_id":"session-1"}'
	[ "$status" -eq 0 ]

	run node "$SCRIPT" report --file "$USAGE_FILE" --kind explicit --json
	[ "$status" -eq 0 ]
	[ "$(echo "$output" | jq -r '.[0].total')" = "1" ]
	[ "$(echo "$output" | jq -r '.[0].explicit')" = "1" ]
	[ "$(echo "$output" | jq -r '.[0].tool')" = "0" ]
}

@test "scan summarizes user skill invocations from transcript files" {
	if ! command -v node >/dev/null 2>&1; then
		skip "node is required for skill usage tests"
	fi

	TRANSCRIPT="$BATS_TEST_TMPDIR/transcript.jsonl"
	printf '%s\n' \
		'{"type":"user","message":{"content":"Use /kramme:pr:create"},"session_id":"session-1","timestamp":"2026-05-24T12:00:00.000Z"}' \
		'{"type":"assistant","message":{"content":"Mention /kramme:qa without counting it"},"session_id":"session-1","timestamp":"2026-05-24T12:01:00.000Z"}' \
		>"$TRANSCRIPT"

	run node "$SCRIPT" scan "$TRANSCRIPT" --json
	[ "$status" -eq 0 ]
	[ "$(echo "$output" | jq -r 'length')" = "1" ]
	[ "$(echo "$output" | jq -r '.[0].skill')" = "kramme:pr:create" ]
	[ "$(echo "$output" | jq -r '.[0].total')" = "1" ]
}

@test "scan ignores assistant-only transcript skill references" {
	if ! command -v node >/dev/null 2>&1; then
		skip "node is required for skill usage tests"
	fi

	TRANSCRIPT="$BATS_TEST_TMPDIR/assistant-only.jsonl"
	printf '%s\n' \
		'{"type":"user","message":{"content":"What should I run?"},"session_id":"session-1"}' \
		'{"type":"assistant","message":{"content":"Try /kramme:qa"},"session_id":"session-1"}' \
		>"$TRANSCRIPT"

	run node "$SCRIPT" scan "$TRANSCRIPT" --json
	[ "$status" -eq 0 ]
	[ "$output" = "[]" ]
}

@test "scan ignores user-role tool result content in transcript files" {
	if ! command -v node >/dev/null 2>&1; then
		skip "node is required for skill usage tests"
	fi

	TRANSCRIPT="$BATS_TEST_TMPDIR/tool-result.jsonl"
	printf '%s\n' \
		'{"type":"user","message":{"content":[{"type":"tool_result","content":"Read output mentioned /kramme:qa"}]},"session_id":"session-1"}' \
		'{"type":"user","message":{"content":[{"type":"text","text":"Use /kramme:pr:create"}]},"session_id":"session-1"}' \
		>"$TRANSCRIPT"

	run node "$SCRIPT" scan "$TRANSCRIPT" --json
	[ "$status" -eq 0 ]
	[ "$(echo "$output" | jq -r 'length')" = "1" ]
	[ "$(echo "$output" | jq -r '.[0].skill')" = "kramme:pr:create" ]
}

@test "legacy hooks skill-usage entry delegates to scripts implementation" {
	if ! command -v node >/dev/null 2>&1; then
		skip "node is required for skill usage tests"
	fi

	LEGACY_SCRIPT="$BATS_TEST_DIRNAME/../hooks/skill-usage.js"
	run bash -c 'printf "%s" "$1" | node "$2" record --file "$3"' _ \
		'{"prompt":"/kramme:legacy-wrapper","session_id":"session-legacy"}' \
		"$LEGACY_SCRIPT" \
		"$USAGE_FILE"
	[ "$status" -eq 0 ]
	[ "$output" = "{}" ]

	run node "$SCRIPT" report --file "$USAGE_FILE" --json
	[ "$status" -eq 0 ]
	[ "$(echo "$output" | jq -r '.[0].skill')" = "kramme:legacy-wrapper" ]
}

@test "usage hook records through scripts implementation path" {
	if ! command -v node >/dev/null 2>&1; then
		skip "node is required for skill usage tests"
	fi

	PLUGIN_ROOT="$BATS_TEST_TMPDIR/plugin"
	create_usage_plugin_root "$PLUGIN_ROOT"
	printf '%s\n' '#!/usr/bin/env node' 'process.exit(64);' >"$PLUGIN_ROOT/hooks/skill-usage.js"

	run bash -c 'printf "%s" "$1" | env CLAUDE_PLUGIN_ROOT="$2" KRAMME_SKILL_USAGE_FILE="$3" bash "$2/hooks/skill-usage-stats.sh"' _ \
		'{"prompt":"/kramme:script-owner","session_id":"session-script"}' \
		"$PLUGIN_ROOT" \
		"$USAGE_FILE"
	[ "$status" -eq 0 ]
	[ "$output" = "{}" ]

	run node "$SCRIPT" report --file "$USAGE_FILE" --json
	[ "$status" -eq 0 ]
	[ "$(echo "$output" | jq -r '.[0].skill')" = "kramme:script-owner" ]
}

@test "usage hook writes bounded diagnostics when recorder fails" {
	if ! command -v node >/dev/null 2>&1; then
		skip "node is required for skill usage tests"
	fi

	PLUGIN_ROOT="$BATS_TEST_TMPDIR/plugin"
	create_usage_plugin_root "$PLUGIN_ROOT"
	printf '%s\n' '#!/usr/bin/env node' 'process.exit(42);' >"$PLUGIN_ROOT/scripts/skill-usage.js"
	export KRAMME_SKILL_USAGE_DIAGNOSTIC_MAX_LINES=2

	for skill in one two three; do
		run bash -c 'printf "%s" "$1" | env CLAUDE_PLUGIN_ROOT="$2" KRAMME_SKILL_USAGE_FILE="$3" KRAMME_SKILL_USAGE_DIAGNOSTIC_FILE="$4" KRAMME_SKILL_USAGE_DIAGNOSTIC_MAX_LINES="$5" bash "$2/hooks/skill-usage-stats.sh"' _ \
			"{\"prompt\":\"/kramme:$skill\",\"session_id\":\"session-diag\"}" \
			"$PLUGIN_ROOT" \
			"$USAGE_FILE" \
			"$DIAGNOSTIC_FILE" \
			"$KRAMME_SKILL_USAGE_DIAGNOSTIC_MAX_LINES"
		[ "$status" -eq 0 ]
		[ "$output" = "{}" ]
	done

	[ ! -f "$USAGE_FILE" ]
	[ "$(wc -l <"$DIAGNOSTIC_FILE" | tr -d ' ')" = "2" ]
	run grep -F "skill-usage-stats: record failed status=42" "$DIAGNOSTIC_FILE"
	[ "$status" -eq 0 ]
}

@test "scan prunes dependency and generated directories" {
	if ! command -v node >/dev/null 2>&1; then
		skip "node is required for skill usage tests"
	fi

	SCAN_ROOT="$BATS_TEST_TMPDIR/project"
	mkdir -p "$SCAN_ROOT/transcripts" "$SCAN_ROOT/node_modules/pkg" "$SCAN_ROOT/dist"
	printf '%s\n' \
		'{"type":"user","message":{"content":"Use /kramme:pr:create"},"session_id":"session-1"}' \
		>"$SCAN_ROOT/transcripts/session.jsonl"
	printf '%s\n' \
		'{"type":"user","message":{"content":"Use /kramme:ignored-dependency"},"session_id":"session-2"}' \
		>"$SCAN_ROOT/node_modules/pkg/session.jsonl"
	printf '%s\n' \
		'{"type":"user","message":{"content":"Use /kramme:ignored-generated"},"session_id":"session-3"}' \
		>"$SCAN_ROOT/dist/session.jsonl"

	run node "$SCRIPT" scan "$SCAN_ROOT" --json
	[ "$status" -eq 0 ]
	[ "$(echo "$output" | jq -r 'length')" = "1" ]
	[ "$(echo "$output" | jq -r '.[0].skill')" = "kramme:pr:create" ]
}
