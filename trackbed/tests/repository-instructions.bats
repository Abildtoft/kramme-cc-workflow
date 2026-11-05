#!/usr/bin/env bats

@test "CLAUDE.md delegates exclusively to the canonical AGENTS.md instructions" {
	project_root="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
	expected="$BATS_TEST_TMPDIR/CLAUDE.md"
	printf '%s\n' '@AGENTS.md' >"$expected"

	run cmp -s "$expected" "$project_root/CLAUDE.md"

	[ "$status" -eq 0 ]
}
