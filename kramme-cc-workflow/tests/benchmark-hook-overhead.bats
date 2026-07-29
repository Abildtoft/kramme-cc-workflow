#!/usr/bin/env bats

load 'test_helper/common'

setup() {
	BENCHMARK_ROOT="$BATS_TEST_TMPDIR/benchmark-plugin"
	mkdir -p "$BENCHMARK_ROOT/hooks/lib" "$BENCHMARK_ROOT/scripts"
	cp "$HOOKS_DIR/lib/check-enabled.sh" "$BENCHMARK_ROOT/hooks/lib/check-enabled.sh"
	cp \
		"$BATS_TEST_DIRNAME/../scripts/benchmark-hook-overhead.sh" \
		"$BENCHMARK_ROOT/scripts/benchmark-hook-overhead.sh"
}

write_delayed_hook() {
	local hook_name="$1"
	local hook_file="$2"

	{
		printf '%s\n' '#!/bin/bash'
		printf '%s\n' 'source "${CLAUDE_PLUGIN_ROOT}/hooks/lib/check-enabled.sh"'
		printf 'exit_if_hook_disabled "%s" ""\n' "$hook_name"
		printf '%s\n' 'cat > /dev/null'
		printf '%s\n' 'sleep 0.4'
	} >"$BENCHMARK_ROOT/hooks/$hook_file"
	chmod +x "$BENCHMARK_ROOT/hooks/$hook_file"
}

@test "measures matching hooks as a parallel set" {
	local enabled_ms

	write_delayed_hook "block-rm-rf" "block-rm-rf.sh"
	write_delayed_hook "confirm-review-responses" "confirm-review-responses.sh"
	write_delayed_hook "noninteractive-git" "noninteractive-git.sh"

	run "$BENCHMARK_ROOT/scripts/benchmark-hook-overhead.sh" \
		--iterations 1 \
		--warmups 0

	[ "$status" -eq 0 ]
	[[ "$output" == *"Enabled parallel set median:"* ]]
	[[ "$output" == *"Added gating overhead median (paired):"* ]]

	enabled_ms=$(
		printf '%s\n' "$output" |
			sed -n 's/^  Enabled parallel set median: \([0-9.]*\) ms$/\1/p' |
			head -n 1
	)
	[ -n "$enabled_ms" ]
	awk -v value="$enabled_ms" 'BEGIN { exit !(value < 850) }'
}
