#!/usr/bin/env bats

setup() {
	cd "$BATS_TEST_DIRNAME/.."
	CLARIFY="skills/kramme:text:clarify"
	REPLY="skills/kramme:pr:github-review-reply/SKILL.md"
	GITHUB_REVIEW="skills/kramme:pr:github-review"
}

@test "humanize is merged into clarify and no skill names the removed command" {
	test ! -e "skills/kramme:text:humanize"
	! grep -rqF "text:humanize" skills shared || false
}

@test "clarify exposes humanize mode and keeps its default-mode contract" {
	grep -E '^argument-hint:' "$CLARIFY/SKILL.md" | grep -qF -- "--humanize"
	grep -E '^description:' "$CLARIFY/SKILL.md" | grep -qF -- "--humanize"
	! grep -E '^description:' "$CLARIFY/SKILL.md" | grep -qF "Not for removing AI-writing patterns" || false
	grep -qF 'references/humanize-mode.md' "$CLARIFY/SKILL.md"
	grep -qF '${CLAUDE_PLUGIN_ROOT}/shared/writing/references/plain-language-rubric.md' "$CLARIFY/SKILL.md"
	grep -qF 'references/ai-writing-patterns.md' "$CLARIFY/references/humanize-mode.md"
}

@test "humanize mode uses clarify's input contract instead of the slash stop" {
	grep -qF "Treat a nonexistent argument as a path only when the complete single-line value is path-shaped" "$CLARIFY/SKILL.md"
	grep -qF "This contract applies in both modes." "$CLARIFY/SKILL.md"
	local file
	for file in "$CLARIFY/SKILL.md" "$CLARIFY/references/humanize-mode.md"; do
		! grep -qF "Do not silently treat a missing path as raw text" "$file" || false
	done
}

@test "the copied Wikipedia catalog keeps its notice and provenance under clarify" {
	test -f "$CLARIFY/references/ai-writing-patterns.md"
	test -f "$CLARIFY/references/WIKIPEDIA-CONTENT-LICENSE.md"
	grep -qF "id: wikipedia-signs-of-ai-writing" "$CLARIFY/references/sources.yaml"
	grep -qF "usage: copied" "$CLARIFY/references/sources.yaml"
	grep -qF "notice: references/WIKIPEDIA-CONTENT-LICENSE.md" "$CLARIFY/references/sources.yaml"
	grep -qF "id: blader-humanizer" "$CLARIFY/references/sources.yaml"
	grep -qF 'kramme:text:clarify/references/ai-writing-patterns.md' ../THIRD_PARTY_NOTICES.md
}

@test "GitHub review sends its humanize passes through clarify's mode" {
	grep -qF '/kramme:text:clarify --humanize' "$GITHUB_REVIEW/references/comment-drafting.md"
	grep -qF '/kramme:text:clarify --humanize' "$GITHUB_REVIEW/references/clarity-check.md"
	grep -qF '## Step 10: Humanize the Draft Comments' "$GITHUB_REVIEW/SKILL.md"
}

@test "GitHub review reply humanizes replies only on request" {
	grep -E '^argument-hint:' "$REPLY" | grep -qF -- "--humanize"
	grep -qF 'kramme:text:clarify --humanize' "$REPLY"
	grep -qF 'HUMANIZE=false' "$REPLY"
	grep -qF 'If `--humanize` is present, set `HUMANIZE=true`.' "$REPLY"
	grep -qF 'Humanized: skipped' "$REPLY"
	grep -qF '`yes`, `no`, or `skipped`' "$REPLY"
}

@test "the Linear reviewer summary keeps clarify's default mode" {
	! grep -qF -- "--humanize" skills/kramme:linear:issue-to-pr/SKILL.md || false
}
