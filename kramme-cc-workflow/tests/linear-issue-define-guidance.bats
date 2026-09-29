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
		if grep -qF "AskUserQuestion" "$flow" "$rounds" "$dir/references/one-pr-rule.md"; then exit 1; fi
		grep -qF "structured question tool" "$flow"
		grep -qF "approve as drafted, refine first, or cancel without writing" "$flow"
	'
	[ "$status" -eq 0 ]
}

@test "sibling Linear skills no longer name removed create/update tools" {
	run bash -c '
		set -e
		cd "'"$BATS_TEST_DIRNAME"'/.."
		if grep -rlF "mcp__linear__create_issue" skills agents; then exit 1; fi
		if grep -rlF "mcp__linear__update_issue" skills agents; then exit 1; fi
	'
	[ "$status" -eq 0 ]
}

@test "issue-define holds every issue to one PR and splits larger work into sub-issues" {
	run bash -c '
		set -e
		cd "'"$BATS_TEST_DIRNAME"'/.."
		dir="skills/kramme:linear:issue-define"
		skill="$dir/SKILL.md"
		rule="$dir/references/one-pr-rule.md"
		auto="$dir/references/auto-create.md"
		flow="$dir/references/mode-and-review-flow.md"

		grep -qF "Every issue must fit one PR; larger work becomes a parent with one sub-issue per PR." "$skill"
		grep -qF "Every issue this skill writes must be resolvable by exactly one Pull Request." "$skill"
		grep -qF "Read \`references/one-pr-rule.md\` before the first size check." "$skill"
		grep -qF "the one-PR size check passes or the user chose a split or a narrower scope" "$skill"

		grep -qF "Never offer to file the oversized issue as-is." "$rule"
		grep -qF "with \`parentId\` set to the parent identifier" "$rule"
		grep -qF "Must pass the size check on its own." "$rule"
		grep -qF "Never blindly recreate a sub-issue on retry" "$rule"
		grep -qF "Ask once for approval of the whole set" "$rule"
		grep -qF "Read back with \`list_issues\` using \`parentId\`" "$rule"
		grep -qF "a read-back missing an approved sub-issue, is a failed split" "$rule"
		grep -qF "An approved split also covers creating its sub-issues." "$skill"

		grep -qF "never split a handoff into sub-issues" "$auto"
		grep -qF "return \`Action: blocked\` with \`Reason:\` naming the triggering signals" "$auto"
		grep -qF "run the one-PR size check in \`references/one-pr-rule.md\`" "$auto"
		grep -qF "\`list_issues\` using \`parentId\` set to the issue" "$flow"
	'
	[ "$status" -eq 0 ]
}
