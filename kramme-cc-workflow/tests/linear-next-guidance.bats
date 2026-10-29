#!/usr/bin/env bats

@test "Linear next accepts a natural-language state and agent-readiness query" {
	run bash -c '
    set -e
    cd "'"$BATS_TEST_DIRNAME"'/.."
    skill="skills/kramme:linear:next/SKILL.md"

    test -f "$skill"
    grep -qF "name: kramme:linear:next" "$skill"
    grep -qF "[team or selection query]" "$skill"
    grep -qF "Accept either structured flags, a bare team name/key/ID, a free-form selection query, or a combination of them." "$skill"
    grep -qF "Please identify Linear issues that are in Backlog or To-do state that are ready for autonomous agent-driven implementation" "$skill"
    grep -qF "do not interpret the sentence as a team name" "$skill"
    grep -qF "enable agent-ready filtering" "$skill"
    grep -qF "Explicit flags override constraints inferred from free-form text." "$skill"
    grep -qF "when it begins with a selection request such as \`find\`, \`identify\`, \`list\`, \`show\`, \`recommend\`, or \`select\`" "$skill"
    grep -qF "otherwise ask one short clarification question" "$skill"
    grep -qF "Reject unknown flags" "$skill"
    grep -qF "Allow repeated \`--state\`; reject other repeated singleton flags." "$skill"
  '

	[ "$status" -eq 0 ] || { echo "$output"; false; }
}

@test "Linear next defaults to unstarted work and resolves explicit states without broadening them" {
	run bash -c '
    set -e
    cd "'"$BATS_TEST_DIRNAME"'/.."
    skill="skills/kramme:linear:next/SKILL.md"

    grep -qF "When no states were requested, use only states with type \`backlog\` or \`unstarted\`." "$skill"
    grep -qF "State type takes precedence over the name" "$skill"
    grep -qF "Exclude all started issues by default, including those assigned to the logged-in user." "$skill"
    grep -qF "Include started issues only when their state was explicitly requested" "$skill"
    grep -qF "Exclude completed, canceled, duplicate, archived, blocked, waiting, review, and started-by-someone-else issues." "$skill"
    grep -qF "blocked, waiting, or review state does not make those issues eligible" "$skill"
    grep -qF "Without explicit states, apply the default type/name eligibility rules locally" "$skill"
    grep -qF "omit issues whose state cannot be established" "$skill"
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

@test "Linear next treats autonomous agent-readiness as a hard eligibility gate" {
	run bash -c '
    set -e
    cd "'"$BATS_TEST_DIRNAME"'/.."
    skill="skills/kramme:linear:next/SKILL.md"
    rubric="skills/kramme:linear:next/references/scoring-rubric.md"

    test -f "$rubric"
    grep -qF "\`--agent-ready\`: return only issues" "$skill"
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

@test "Linear next keeps its own workspace read-only" {
	run bash -c '
    set -e
    cd "'"$BATS_TEST_DIRNAME"'/.."
    skill="skills/kramme:linear:next/SKILL.md"

    grep -qF "disable-model-invocation: true" "$skill"
    grep -qF "user-invocable: true" "$skill"
    grep -qF "MISSING REQUIREMENT: Linear MCP is required to select the next issue" "$skill"
    grep -qF "Keep the analysis read-only" "$skill"
    grep -qF "create branches, change assignees, move statuses, add comments, create issues, or start implementation in this workspace." "$skill"
    grep -qF "only Step 10 may start work, and only by creating new Conductor cloud workspaces for issues the user confirms in this run." "$skill"
    grep -qF "kramme:linear:issue-implement" "$skill"
  '

	[ "$status" -eq 0 ] || { echo "$output"; false; }
}

@test "Linear next actively searches for good parallel candidates" {
	run bash -c '
    set -e
    cd "'"$BATS_TEST_DIRNAME"'/.."
    skill="skills/kramme:linear:next/SKILL.md"

    grep -qF "recommends the best one, and actively searches for 2-4 additional good issues that can be implemented in parallel with it" "$skill"
    grep -qF "and the best recommendation has four good parallel candidates, or every candidate collected in Step 4 has been enriched and assessed" "$skill"
    grep -qF "Reaching the collection cap bounds the candidate set but is not by itself a reason to stop enriching it." "$skill"
    grep -qF "independent of both the recommendation and every other issue in the proposed parallel set" "$skill"
    grep -qF "Finding up to \`--count\` ready issues and a defensible parallel set is part of the required result." "$skill"
    grep -qF "do not use low-value filler merely to reach four" "$skill"
    grep -qF "Never present uncertain or dependent issues as good parallel candidates." "$skill"
  '

	[ "$status" -eq 0 ] || { echo "$output"; false; }
}

@test "Linear next tries to find ten ready issues by default" {
	run bash -c '
    set -e
    cd "'"$BATS_TEST_DIRNAME"'/.."
    skill="skills/kramme:linear:next/SKILL.md"

    grep -qF "[--count <n>]" "$skill"
    grep -qF "\`--count <n>\`: number of ready issues to try to find and rank. Default 10, maximum 25." "$skill"
    grep -qF "The skill tries to find 10 ready issues by default" "$skill"
    grep -qF "Map a requested number of issues, such as \`find 5 issues\`, to \`--count\`." "$skill"
    grep -qF "a \`--count\` outside 1-25" "$skill"
    grep -qF "Continue through further batches until \`--count\` issues pass every readiness and hard-filter requirement" "$skill"
    grep -qF "keep the top \`--count\` as the ranked shortlist, starting with the recommendation" "$skill"
    grep -qF "state how many were found against the requested count" "$skill"
    grep -qF "Never pad the ranked shortlist with issues that fail readiness or a hard filter." "$skill"
    grep -qF "Ranked shortlist ({found} of {count} ready issues):" "$skill"
  '

	[ "$status" -eq 0 ] || { echo "$output"; false; }
}

@test "Linear next estimates UI/UX work for every shortlisted issue" {
	run bash -c '
    set -e
    cd "'"$BATS_TEST_DIRNAME"'/.."
    skill="skills/kramme:linear:next/SKILL.md"
    rubric="skills/kramme:linear:next/references/scoring-rubric.md"

    grep -qF "| Rank | Issue | Plain-language summary | State | Pool | UI/UX work |" "$skill"
    grep -qF "Estimate \`UI/UX work\` as \`None\`, \`Low\`, \`Medium\` or \`High\` for every issue in the ranked shortlist" "$skill"
    grep -qF "## UI/UX Work" "$rubric"
    grep -qF "| \`None\` | No user-facing change" "$rubric"
    grep -qF "| \`Low\` |" "$rubric"
    grep -qF "| \`Medium\` |" "$rubric"
    grep -qF "| \`High\` |" "$rubric"
    grep -qF "Do not judge from labels or title keywords alone." "$rubric"
    grep -qF "The estimate describes the work; it does not change value, readiness or rank." "$rubric"
  '

	[ "$status" -eq 0 ] || { echo "$output"; false; }
}

@test "Linear next offers Conductor cloud workspaces only in cloud and only on an explicit yes" {
	run bash -c '
    set -e
    cd "'"$BATS_TEST_DIRNAME"'/.."
    skill="skills/kramme:linear:next/SKILL.md"
    launch="skills/kramme:linear:next/references/cloud-launch.md"

    test -f "$launch"
    test -f "skills/kramme:linear:next/scripts/cloud-launch.py"
    grep -qF "10. **Offer to start the work in Conductor cloud.**" "$skill"
    grep -qF "scripts/cloud-launch.py\" detect" "$skill"
    grep -qF "A cloud workspace is one where \`CONDUCTOR_IS_LOCAL\` is \`0\`." "$skill"
    grep -qF "On \`not_cloud\`, end without mentioning Conductor." "$skill"
    grep -qF "On \`ok\`, read \`references/cloud-launch.md\` and follow it." "$skill"
    grep -qF "Nothing here runs without the user'"'"'s explicit yes in this run." "$launch"
    grep -qF "Offer an issue only when it is \`agent-ready\` with startability \`ready-to-start\`" "$launch"
    grep -qF "whose first message runs \`kramme:linear:issue-to-pr {ISSUE-ID} --ship\`" "$launch"
    grep -qF "Name every offered issue whose state type is not \`backlog\`" "$launch"
    grep -qF "asks once in that workspace before moving such an issue to its started status" "$launch"
    grep -qF "whether those issues should use a different model than the None and Low ones" "$launch"
    grep -qF "Treat anything other than a clear yes with a selection as no, and start nothing." "$launch"
    grep -qF "Accept only the \`claude\` and \`codex\` agents" "$launch"
    grep -qF "Never run \`launch\` again for the same issues in this run." "$launch"
  '

	[ "$status" -eq 0 ] || { echo "$output"; false; }
}

@test "Linear next summarizes every reported issue in plain language" {
	run bash -c '
    set -e
    cd "'"$BATS_TEST_DIRNAME"'/.."
    skill="skills/kramme:linear:next/SKILL.md"

    grep -qF "Use one or two concise sentences that explain the problem to solve or the outcome that will change and why it matters." "$skill"
    grep -qF "Prefer familiar words and direct phrasing." "$skill"
    grep -qF "Plain-language summary: {one or two concise sentences explaining the problem or outcome and why it matters}" "$skill"
    grep -qF "| Issue | Plain-language summary | Why independent | Caveat |" "$skill"
    grep -qF "Every issue shown anywhere in the report must include its plain-language summary." "$skill"
    grep -qF "internal jargon, unexplained acronyms, implementation details, or a restatement of its title" "$skill"
  '

  [ "$status" -eq 0 ] || { echo "$output"; false; }
}

@test "Linear next parses a leading team deterministically and reports agent-readiness only on request" {
	run bash -c '
    set -e
    cd "'"$BATS_TEST_DIRNAME"'/.."
    skill="skills/kramme:linear:next/SKILL.md"

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
