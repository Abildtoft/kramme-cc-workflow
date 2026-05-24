#!/usr/bin/env bats
# Tests for skill-usage-stats.sh hook and skill-usage.js reporting

load 'test_helper/common'

setup() {
	HOOK="$BATS_TEST_DIRNAME/../hooks/skill-usage-stats.sh"
	SCRIPT="$BATS_TEST_DIRNAME/../scripts/skill-usage.js"
	USAGE_FILE="$BATS_TEST_TMPDIR/skill-usage.jsonl"
	export KRAMME_SKILL_USAGE_FILE="$USAGE_FILE"
	rm -f "$USAGE_FILE"
}

run_usage_hook() {
	printf '%s' "$1" | bash "$HOOK"
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
