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

write_test_hook() {
	local hook_name="$1"
	local hook_file="$2"

	{
		printf '%s\n' '#!/bin/bash'
		printf '%s\n' 'source "${CLAUDE_PLUGIN_ROOT}/hooks/lib/check-enabled.sh"'
		printf 'exit_if_hook_disabled "%s" ""\n' "$hook_name"
		printf '%s\n' 'cat > /dev/null'
		printf '%s\n' 'if [ -n "${BENCHMARK_TEST_BARRIER_DIR:-}" ] && [ ! -e "$BENCHMARK_TEST_BARRIER_DIR/released" ]; then'
		printf '  touch "$BENCHMARK_TEST_BARRIER_DIR/%s.ready"\n' "$hook_name"
		printf '%s\n' '  attempts=0'
		printf '%s\n' '  while [ ! -e "$BENCHMARK_TEST_BARRIER_DIR/released" ]; do'
		printf '%s\n' '    ready_count=0'
		printf '%s\n' '    for marker in "$BENCHMARK_TEST_BARRIER_DIR"/*.ready; do'
		printf '%s\n' '      [ -e "$marker" ] || continue'
		printf '%s\n' '      ready_count=$((ready_count + 1))'
		printf '%s\n' '    done'
		printf '%s\n' '    if [ "$ready_count" -eq 3 ]; then'
		printf '%s\n' '      touch "$BENCHMARK_TEST_BARRIER_DIR/released"'
		printf '%s\n' '      break'
		printf '%s\n' '    fi'
		printf '%s\n' '    attempts=$((attempts + 1))'
		printf '%s\n' '    if [ "$attempts" -ge 100 ]; then'
		printf '%s\n' '      echo "parallel hook barrier timed out" >&2'
		printf '%s\n' '      exit 1'
		printf '%s\n' '    fi'
		printf '%s\n' '    sleep 0.01'
		printf '%s\n' '  done'
		printf '%s\n' 'fi'
	} >"$BENCHMARK_ROOT/hooks/$hook_file"
	chmod +x "$BENCHMARK_ROOT/hooks/$hook_file"
}

@test "measures matching hooks as a parallel set" {
	local barrier_dir="$BATS_TEST_TMPDIR/parallel-hook-barrier"
	mkdir -p "$barrier_dir"

	write_test_hook "block-rm-rf" "block-rm-rf.sh"
	write_test_hook "confirm-review-responses" "confirm-review-responses.sh"
	write_test_hook "noninteractive-git" "noninteractive-git.sh"

	run env BENCHMARK_TEST_BARRIER_DIR="$barrier_dir" \
		"$BENCHMARK_ROOT/scripts/benchmark-hook-overhead.sh" \
		--iterations 1 \
		--warmups 0

	[ "$status" -eq 0 ]
	[[ "$output" == *"Enabled parallel set median:"* ]]
	[[ "$output" == *"Added gating overhead median (paired):"* ]]
	[ -e "$barrier_dir/block-rm-rf.ready" ]
	[ -e "$barrier_dir/confirm-review-responses.ready" ]
	[ -e "$barrier_dir/noninteractive-git.ready" ]
	[ -e "$barrier_dir/released" ]
}

@test "measures the auto-format cache-hit path" {
	local median_ms

	write_test_hook "block-rm-rf" "block-rm-rf.sh"
	write_test_hook "confirm-review-responses" "confirm-review-responses.sh"
	write_test_hook "noninteractive-git" "noninteractive-git.sh"
	mkdir -p "$BENCHMARK_ROOT/scripts/lib"
	cp "$HOOKS_DIR/auto-format.sh" "$BENCHMARK_ROOT/hooks/auto-format.sh"

	run "$BENCHMARK_ROOT/scripts/benchmark-hook-overhead.sh" \
		--iterations 1 \
		--warmups 0

	[ "$status" -eq 0 ]
	[[ "$output" == *"Auto-format cache-hit path:"* ]]

	median_ms=$(
		printf '%s\n' "$output" |
			sed -n 's/^  Median: \([0-9.]*\) ms$/\1/p' |
			tail -n 1
	)
	[ -n "$median_ms" ]
	[[ "$median_ms" =~ ^[0-9]+([.][0-9]+)?$ ]]
}
