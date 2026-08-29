#!/usr/bin/env bats

@test "Linear select-next accepts a natural-language state and agent-readiness query" {
	run bash -c '
    set -e
    cd "'"$BATS_TEST_DIRNAME"'/.."
    skill="skills/kramme:linear:select-next/SKILL.md"

    test -f "$skill"
    grep -qF "name: kramme:linear:select-next" "$skill"
    grep -qF "[team or selection query]" "$skill"
    grep -qF "Accept either structured flags, a bare team name/key/ID, a free-form selection query, or a combination of them." "$skill"
    grep -qF "Please identify Linear issues that are in Backlog or To-do state that are ready for autonomous agent-driven implementation" "$skill"
    grep -qF "do not interpret the sentence as a team name" "$skill"
    grep -qF "enable agent-ready-only filtering" "$skill"
    grep -qF "Explicit flags override constraints inferred from free-form text." "$skill"
    grep -qF "when it begins with a selection request such as \`find\`, \`identify\`, \`list\`, \`show\`, \`recommend\`, or \`select\`" "$skill"
    grep -qF "otherwise ask one short clarification question" "$skill"
    grep -qF "Reject unknown flags" "$skill"
    grep -qF "Allow repeated \`--state\`; reject other repeated singleton flags." "$skill"
  '

	[ "$status" -eq 0 ] || { echo "$output"; false; }
}

@test "Linear select-next resolves explicit states without silently broadening them" {
	run bash -c '
    set -e
    cd "'"$BATS_TEST_DIRNAME"'/.."
    skill="skills/kramme:linear:select-next/SKILL.md"

    grep -qF "\`--state <name>\`: include only a named workflow state" "$skill"
    grep -qF "The flag is repeatable" "$skill"
    grep -qF "case-insensitively after removing spaces and hyphens" "$skill"
    grep -qF "Use exactly the resolved states as the candidate state set." "$skill"
    grep -qF "never silently broaden an explicit state filter" "$skill"
    grep -qF "does not make those issues eligible" "$skill"
    grep -qF "at least one record establishes each requested normalized state name" "$skill"
    grep -qF "MISSING REQUIREMENT: Linear status metadata is required to validate explicit state filters" "$skill"
    grep -qF "never guess that the requested state exists" "$skill"
  '

	[ "$status" -eq 0 ] || { echo "$output"; false; }
}

@test "Linear select-next treats autonomous agent-readiness as a hard eligibility gate" {
	run bash -c '
    set -e
    cd "'"$BATS_TEST_DIRNAME"'/.."
    skill="skills/kramme:linear:select-next/SKILL.md"
    rubric="skills/kramme:linear:select-next/references/scoring-rubric.md"

    test -f "$rubric"
    grep -qF "\`--agent-ready-only\`: return only issues" "$skill"
    grep -qF "Never classify an issue as agent-ready from title keywords alone." "$skill"
    grep -qF "Ordinary \`ready\` means work can begin; \`agent-ready\` is stricter" "$skill"
    grep -qF "If no issue passes, say so; do not weaken the filter." "$skill"
    grep -qF "| Problem is stated |" "$rubric"
    grep -qF "| Outcome is observable |" "$rubric"
    grep -qF "| Acceptance criteria are verifiable by running something |" "$rubric"
    grep -qF "| Scope is bounded |" "$rubric"
    grep -qF "| Decisions are made |" "$rubric"
    grep -qF "| Inputs are reachable |" "$rubric"
    grep -qF "| Dependencies are clear |" "$rubric"
    grep -qF "| Done is detectable |" "$rubric"
    grep -qF "every applicable checklist item has concrete evidence" "$skill"
    grep -qF "If required evidence is still unavailable, classify the issue as `needs-refinement`" "$skill"
    grep -qF "these classes are a hard eligibility gate rather than a score adjustment" "$rubric"
  '

	[ "$status" -eq 0 ] || { echo "$output"; false; }
}

@test "Linear select-next remains read-only" {
	run bash -c '
    set -e
    cd "'"$BATS_TEST_DIRNAME"'/.."
    skill="skills/kramme:linear:select-next/SKILL.md"

    grep -qF "disable-model-invocation: true" "$skill"
    grep -qF "user-invocable: true" "$skill"
    grep -qF "MISSING REQUIREMENT: Linear MCP is required to select the next issue" "$skill"
    grep -qF "Keep the analysis read-only" "$skill"
    grep -qF "create branches, change assignees, move statuses" "$skill"
    grep -qF "kramme:linear:issue-implement" "$skill"
  '

	[ "$status" -eq 0 ] || { echo "$output"; false; }
}

@test "Linear select-next actively searches for good parallel candidates" {
	run bash -c '
    set -e
    cd "'"$BATS_TEST_DIRNAME"'/.."
    skill="skills/kramme:linear:select-next/SKILL.md"

    grep -qF "recommends one issue and actively searches for 2-4 additional good issues that can be implemented in parallel" "$skill"
    grep -qF "until the best recommendation has four good parallel candidates or every candidate collected in Step 4 has been enriched and assessed" "$skill"
    grep -qF "Reaching the collection cap bounds the candidate set but is not by itself a reason to stop enriching it." "$skill"
    grep -qF "independent of both the recommendation and every other issue in the proposed parallel set" "$skill"
    grep -qF "Finding a defensible parallel set is part of the required result." "$skill"
    grep -qF "do not use low-value filler merely to reach four" "$skill"
    grep -qF "Never present uncertain or dependent issues as good parallel candidates." "$skill"
  '

	[ "$status" -eq 0 ] || { echo "$output"; false; }
}

@test "Linear select-next summarizes every reported issue in plain language" {
	run bash -c '
    set -e
    cd "'"$BATS_TEST_DIRNAME"'/.."
    skill="skills/kramme:linear:select-next/SKILL.md"

    grep -qF "Use one or two concise sentences that explain the problem to solve or the outcome that will change and why it matters." "$skill"
    grep -qF "Prefer familiar words and direct phrasing." "$skill"
    grep -qF "Plain-language summary: {one or two concise sentences explaining the problem or outcome and why it matters}" "$skill"
    grep -qF "| Issue | Plain-language summary | Why independent | Caveat |" "$skill"
    grep -qF "Every issue shown anywhere in the report must include its plain-language summary." "$skill"
    grep -qF "internal jargon, unexplained acronyms, implementation details, or a restatement of its title" "$skill"
  '

  [ "$status" -eq 0 ] || { echo "$output"; false; }
}

@test "Linear select-next parses a leading team deterministically and reports agent-readiness only on request" {
	run bash -c '
    set -e
    cd "'"$BATS_TEST_DIRNAME"'/.."
    skill="skills/kramme:linear:select-next/SKILL.md"

    grep -qF "match the longest exact leading substring against available Linear team names, keys, and IDs" "$skill"
    grep -qF "If one matches, consume it as the team and parse the remainder as the query" "$skill"
    grep -qF "Do not invent quoting or delimiter syntax." "$skill"
    grep -qF "Otherwise do not perform or report the stricter autonomous classification." "$skill"
    grep -qF "Omit the Agent-readiness field and columns when autonomous readiness was not requested." "$skill"
  '

	[ "$status" -eq 0 ] || { echo "$output"; false; }
}

@test "Linear workflows share one autonomous readiness contract" {
	run python3 - "$BATS_TEST_DIRNAME/../scripts/synced-contracts.yaml" "$BATS_TEST_DIRNAME/../.." <<'PY'
import json
import pathlib
import re
import sys

registry_path, repo_root = map(pathlib.Path, sys.argv[1:])
registry = json.loads(registry_path.read_text())
contract = next(
    item for item in registry["text_contracts"]
    if item["name"] == "linear-agent-readiness-rubric"
)
assert len(contract["paths"]) == 2
blocks = []
for relative_path in contract["paths"]:
    text = (repo_root / relative_path).read_text()
    match = re.search(contract["extract_regex"], text)
    assert match is not None, relative_path
    blocks.append(match.group(1))
assert blocks[0] == blocks[1]
PY

	[ "$status" -eq 0 ] || { echo "$output"; false; }
}
