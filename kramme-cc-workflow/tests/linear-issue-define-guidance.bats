#!/usr/bin/env bats

@test "issue-define uses save_issue for every Linear write and wires relations" {
	run bash -c '
		set -e
		cd "'"$BATS_TEST_DIRNAME"'/.."
		dir="skills/kramme:linear:issue-define"
		skill="$dir/SKILL.md"
		auto="$dir/references/auto-create.md"
		flow="$dir/references/mode-and-review-flow.md"
		rounds="$dir/references/interview-rounds.md"

		grep -qF "mcp__linear__save_issue" "$skill"
		grep -qF "mcp__linear__save_issue" "$auto"
		grep -qF "mcp__linear__save_issue" "$flow"
		! grep -rqF "mcp__linear__create_issue" "$dir"
		! grep -rqF "mcp__linear__update_issue" "$dir"

		grep -qF "omit \`id\` to create, pass \`id\` to update" "$skill"
		grep -qF "Relation fields are append-only" "$skill"
		grep -qF "\`relatedTo\`, \`blockedBy\`, \`blocks\` from \`relations\`" "$flow"
		grep -qF "Prefer \`patch\` over \`description\`" "$flow"
		grep -qF "fall back to sending the full \`description\`" "$flow"
		grep -qF "\`blockedBy\` field" "$auto"

		grep -qF "scoped to the team" "$skill"
		grep -qF "Should this go into a cycle?" "$rounds"
		grep -qF "Should it be assigned now?" "$rounds"

		grep -qF "\`--ask\` requires \`--auto\` and, when present, set \`ask_all_relevant = true\`" "$skill"
		grep -qF "never fall back to create mode" "$skill"

		grep -qF "Use the \`AskUserQuestion\` tool for every interview question, classification prompt, duplicate decision, and draft approval." "$skill"
		grep -qF "If the host does not expose \`AskUserQuestion\`, ask directly in chat and preserve the same question-coverage ledger." "$skill"
		count=$(grep -c AskUserQuestion "$skill")
		test "$count" -eq 1
		! grep -qF "AskUserQuestion" "$flow" "$rounds"
		grep -qF "structured question tool" "$flow"
		grep -qF "approve as drafted, refine first, or cancel without writing" "$flow"
	'
	[ "$status" -eq 0 ]
}

@test "sibling Linear skills no longer name removed create/update tools" {
	run bash -c '
		set -e
		cd "'"$BATS_TEST_DIRNAME"'/.."
		! grep -rlF "mcp__linear__create_issue" skills agents
		! grep -rlF "mcp__linear__update_issue" skills agents
	'
	[ "$status" -eq 0 ]
}
