#!/usr/bin/env bats

setup() {
  cd "$BATS_TEST_DIRNAME/.."
}

@test "find sibling bugs is a read-only branch recurrence analysis" {
  local skill="skills/kramme:debug:find-sibling-bugs/SKILL.md"

  test -f "$skill"
  grep -qF "Use the current branch as a worked bug report." "$skill"
  grep -qF "Keep the run read-only." "$skill"
  grep -qF "Do not edit source, write a report file, open issues, or implement fixes." "$skill"
  grep -qF "Reply in chat and do not create or update a report file." "$skill"
}

@test "find sibling bugs resolves complete branch and local scope" {
  local skill="skills/kramme:debug:find-sibling-bugs/SKILL.md"

  grep -qF 'argument-hint: "[--base <branch>] [--intent <text>]"' "$skill"
  grep -qF 'COLLECT_ARGS=(--strict --format nul --exclude-review-artifacts)' "$skill"
  grep -qF '"${CLAUDE_PLUGIN_ROOT}/scripts/collect-review-diff.sh" "${COLLECT_ARGS[@]}" \' "$skill"
  ! grep -qF '"${CLAUDE_PLUGIN_ROOT}/scripts/collect-review-diff.sh" --decode-json' "$skill"
  grep -qF "IFS= read -r -d '' MERGE_BASE" "$skill"
  grep -qF "IFS= read -r -d '' CHANGED_FILES" "$skill"
  grep -qF 'No changes detected against $BASE_REF. If this is wrong, re-run with --base <branch>.' "$skill"
}

@test "find sibling bugs treats stated intent as an inert final block" {
  local skill="skills/kramme:debug:find-sibling-bugs/SKILL.md"

  grep -qF 'Accept only `--base <branch>` and the optional sentinel `--intent <text>`:' "$skill"
  grep -qF 'Before the sentinel, `--base` may appear at most once and must be followed by a non-flag value.' "$skill"
  grep -qF '`--intent` may appear at most once.' "$skill"
  grep -qF 'treat every character after it as one non-empty inert `STATED_INTENT` block' "$skill"
  grep -qF 'Do not parse quoting inside the block or reinterpret later text as flags.' "$skill"
  grep -qF 'Reject duplicate flags, unknown flags, positional arguments before the sentinel, missing values, and an empty intent block.' "$skill"
  grep -qF 'Usage: /kramme:debug:find-sibling-bugs [--base <branch>] [--intent <text>]' "$skill"
}

@test "find sibling bugs derives a causal signature before searching" {
  local skill="skills/kramme:debug:find-sibling-bugs/SKILL.md"

  grep -qF "establish the branch's actual problem and causal signature before searching" "$skill"
  grep -qF "**Before/after delta:**" "$skill"
  grep -qF "**Fix invariant:**" "$skill"
  grep -qF "**Structural signature:**" "$skill"
  grep -qF "**Semantic signature:**" "$skill"
  grep -qF 'Classify the dominant pattern as `code`, `UX`, `UI`, or a combination.' "$skill"
}

@test "find sibling bugs validates mechanism rather than textual similarity" {
  local skill="skills/kramme:debug:find-sibling-bugs/SKILL.md"

  grep -qF "A repeated token, API name, CSS property, or component is not by itself a sibling bug." "$skill"
  grep -qF "Are the triggering preconditions possible here?" "$skill"
  grep -qF "Does the same failure mechanism remain, rather than only the same syntax?" "$skill"
  grep -qF "Is the fix invariant absent or bypassed?" "$skill"
  grep -qF "**Lookalike:**" "$skill"
}

@test "find sibling bugs searches code UX and UI peers" {
  local skill="skills/kramme:debug:find-sibling-bugs/SKILL.md"

  grep -qF "For code patterns, follow the same API, callers, types, data flow, state machine" "$skill"
  grep -qF "For UX patterns, inspect sibling flows" "$skill"
  grep -qF "For UI patterns, inspect the same component family" "$skill"
  grep -qF "Find peer callers, components, routes, flows, styles, or state transitions" "$skill"
}

@test "find sibling bugs reports evidence and honest coverage" {
  local skill="skills/kramme:debug:find-sibling-bugs/SKILL.md"
  local template="skills/kramme:debug:find-sibling-bugs/assets/report-template.md"

  test -f "$template"
  grep -qF 'Read the report shape from `assets/report-template.md`' "$skill"
  grep -qF "Every finding names a current path and line and distinguishes Confirmed from Probable evidence." "$skill"
  grep -qF "Coverage claims must match the work actually completed." "$skill"
  grep -qF "No validated sibling bugs found." "$skill"
  grep -qF "**Query families:**" "$template"
  grep -qF "cleared as lookalikes" "$template"
}

@test "find sibling bugs keeps independent fixes attached to their own siblings" {
  local skill="skills/kramme:debug:find-sibling-bugs/SKILL.md"
  local template="skills/kramme:debug:find-sibling-bugs/assets/report-template.md"

  grep -qF "repeat the template's complete worked-example section once per diagnosis" "$skill"
  grep -qF "Repeat this complete worked-example section once for each independent fix." "$template"
  grep -qF "## Worked Example EX-01" "$template"
  grep -qF "#### SIB-01" "$template"
  grep -qF "associated with this worked example" "$template"
}

@test "find sibling bugs does not overclaim history or expose secrets" {
  local skill="skills/kramme:debug:find-sibling-bugs/SKILL.md"

  grep -qF "Do not claim that a commit introduced the original problem unless history establishes that claim." "$skill"
  grep -qF "Never reproduce secrets found during the search. Cite only the path and line." "$skill"
  grep -qF "No secret value appears in the response." "$skill"
}
