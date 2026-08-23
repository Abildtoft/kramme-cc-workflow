#!/usr/bin/env bats

@test "Linear backlog refine is read-only unless --apply is approved per batch" {
	run bash -c '
    set -e
    cd "'"$BATS_TEST_DIRNAME"'/.."
    skill="skills/kramme:linear:backlog-refine/SKILL.md"
    rubric="skills/kramme:linear:backlog-refine/references/refinement-rubric.md"

    test -f "$skill"
    test -f "$rubric"
    grep -qF "name: kramme:linear:backlog-refine" "$skill"
    grep -qF "disable-model-invocation: true" "$skill"
    grep -qF "user-invocable: true" "$skill"
    grep -qF "MISSING REQUIREMENT: Linear MCP is required to refine the backlog" "$skill"
    grep -qF "Nothing in Linear changes unless the user passed \`--apply\` and approves a batch." "$skill"
    grep -qF "Apply a batch only after an explicit yes" "$skill"
    grep -qF "re-fetch the issue and abort that write when its state, title, or description changed since grading" "$skill"
    grep -qF "Never use a hard archive or delete operation." "$skill"
    grep -qF "Do not refine issues someone is already working on." "$skill"
    grep -qF "references/refinement-rubric.md" "$skill"
    grep -qF "kramme:linear:issue-define" "$skill"
    grep -qF "kramme:linear:select-next" "$skill"
  '

	[ "$status" -eq 0 ] || { echo "$output"; false; }
}

@test "Linear backlog refine rubric guards archive and split decisions" {
	run bash -c '
    set -e
    cd "'"$BATS_TEST_DIRNAME"'/.."
    skill="skills/kramme:linear:backlog-refine/SKILL.md"
    rubric="skills/kramme:linear:backlog-refine/references/refinement-rubric.md"

    grep -qF "staleness alone is not enough when the issue carries priority, customer need, or a blocking relation" "$skill"
    grep -qF "Do not guess; the action is \`rewrite\` or \`ask\`, never \`split\`." "$rubric"
    grep -qF "Shared labels, the same project, or overlapping keywords alone make issues \`related\`, not duplicates." "$rubric"
    grep -qF "do not include file paths, line numbers, or internal helper or class names" "$rubric"
    grep -qF "Split children must each be independently shippable" "$rubric"
  '

	[ "$status" -eq 0 ] || { echo "$output"; false; }
}

@test "Linear backlog refine targets agent-ready issues without inventing decisions" {
	run bash -c '
    set -e
    cd "'"$BATS_TEST_DIRNAME"'/.."
    skill="skills/kramme:linear:backlog-refine/SKILL.md"
    rubric="skills/kramme:linear:backlog-refine/references/refinement-rubric.md"

    grep -qF "an autonomous agent (for example \`kramme:linear:issue-to-pr\`) can pick them up and deliver quality work" "$skill"
    grep -qF "\`agent-readiness\`: \`agent-ready\`, \`needs-refinement\`, or \`human-only\`" "$skill"
    grep -qF "Agent-ready now: {a} | agent-ready after proposed actions: {b} | human-only: {c}" "$skill"
    grep -qF "missing decisions are an \`ask\`, not a guess" "$skill"
    grep -qF "## Agent-Readiness" "$rubric"
    grep -qF "Acceptance criteria are verifiable by running something" "$rubric"
    grep -qF "Decisions are made" "$rubric"
    grep -qF "Done is detectable" "$rubric"
    grep -qF "do not force them toward \`agent-ready\`" "$rubric"
    grep -qF "Never invent decisions, criteria, or product intent" "$rubric"
  '

	[ "$status" -eq 0 ] || { echo "$output"; false; }
}
