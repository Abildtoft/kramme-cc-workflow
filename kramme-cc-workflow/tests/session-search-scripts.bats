#!/usr/bin/env bats

setup() {
	SCRIPTS="$BATS_TEST_DIRNAME/../skills/kramme:session:search/scripts"
	TEST_DIR=$(mktemp -d)
}

teardown() {
	rm -rf "$TEST_DIR"
}

write_codex_session() {
	cat >"$TEST_DIR/codex.jsonl" <<'JSONL'
{"timestamp":"2026-06-06T10:00:00Z","type":"session_meta","payload":{"cwd":"/tmp/demo-repo","id":"codex-test-session","timestamp":"2026-06-06T10:00:00Z","source":"codex"}}
{"timestamp":"2026-06-06T10:01:00Z","type":"turn_context","payload":{"cwd":"/tmp/demo-repo","model":"gpt-test"}}
{"timestamp":"2026-06-06T10:02:00Z","type":"event_msg","payload":{"type":"user_message","message":"Please debug the auth script. API_KEY=sk-abcdefghijklmnopqrstuvwxyz123456"}}
{"timestamp":"2026-06-06T10:03:00Z","type":"response_item","payload":{"type":"message","role":"assistant","content":[{"type":"output_text","text":"I will inspect the failing auth command and avoid exposing secrets."}]}}
{"timestamp":"2026-06-06T10:04:00Z","type":"event_msg","payload":{"type":"exec_command_end","command":["zsh","-lc","curl -H 'Authorization: Bearer supersecret1234567890' https://example.invalid"],"aggregated_output":"Process exited with code 1\nAuthorization: Bearer supersecret1234567890 failed","stderr":"Authorization: Bearer supersecret1234567890 failed"}}
JSONL
}

@test "discover-sessions exits cleanly when no session stores exist" {
	mkdir -p "$TEST_DIR/home"

	run env HOME="$TEST_DIR/home" bash "$SCRIPTS/discover-sessions.sh" demo-repo 1

	[ "$status" -eq 0 ]
	[ "$output" = "" ]
}

@test "extract-metadata filters by cwd and keyword without content output" {
	write_codex_session

	run python3 "$SCRIPTS/extract-metadata.py" --cwd-filter demo-repo --keyword debug "$TEST_DIR/codex.jsonl"

	[ "$status" -eq 0 ]
	grep -qF '"platform": "codex"' <<<"$output"
	grep -qF '"match_count": 1' <<<"$output"
	grep -qF '"files_matched": 1' <<<"$output"
	! grep -qF 'sk-abcdefghijklmnopqrstuvwxyz123456' <<<"$output"
}

@test "extract-skeleton writes redacted scratch output" {
	write_codex_session
	out="$TEST_DIR/skeleton.txt"

	run python3 "$SCRIPTS/extract-skeleton.py" --output "$out" <"$TEST_DIR/codex.jsonl"

	[ "$status" -eq 0 ]
	grep -qF '"wrote":' <<<"$output"
	grep -qF '[REDACTED]' "$out"
	! grep -qF 'sk-abcdefghijklmnopqrstuvwxyz123456' "$out"
	! grep -qF 'supersecret1234567890' "$out"
}

@test "extract-errors writes redacted error output" {
	write_codex_session
	out="$TEST_DIR/errors.txt"

	run python3 "$SCRIPTS/extract-errors.py" --output "$out" <"$TEST_DIR/codex.jsonl"

	[ "$status" -eq 0 ]
	grep -qF '"errors_found": 1' <<<"$output"
	grep -qF '[REDACTED]' "$out"
	! grep -qF 'supersecret1234567890' "$out"
}
