#!/usr/bin/env bats

setup() {
  cd "$BATS_TEST_DIRNAME/.."
}

SKILL="skills/kramme:session:automate-repeats/SKILL.md"

@test "recurring friction signals are extracted alongside repeated workflows" {
  test -f "$SKILL"
  grep -qF "Group friction signals that recur while an existing component is already in use: the user having to clarify or re-steer the same point, failed commands and wrong tool or path assumptions, steps the user repeatedly skips or undoes as unnecessary, stale paths, commands, or versions, and context the agent had to be handed every run." "$SKILL"
  grep -qF "as corroborating evidence for a friction signal, never as a candidate on its own" "$SKILL"
}

@test "existing ownership is asked before a new component is considered" {
  grep -qF "Classify each candidate, asking whether an existing component already owns the work before considering a new one." "$SKILL"
  grep -qF "Recommend **IMPROVE EXISTING** when one existing skill or subagent clearly owns the behavior" \
    "$SKILL"
  grep -qF "and no existing component owns it" "$SKILL"
}

@test "ambiguous or absent ownership disqualifies IMPROVE EXISTING" {
  grep -qF "Name the single owning component; if two or more components could own the work, or none does, do not use this classification." "$SKILL"
}

@test "one-off failures cannot become improvement candidates" {
  grep -qF "Hold \`IMPROVE EXISTING\` to the same evidence bar. Never propose an improvement from a single session or a single model failure, however severe that one run looked." "$SKILL"
  grep -qF "at least 2 independent sessions or at least 3 clearly separate asks" "$SKILL"
  grep -qF "Count independent evidence by session, not just repeated messages inside one session." "$SKILL"
}

@test "improvement proposals are capped separately from new components" {
  grep -qF "Cap and rank the two classes separately: keep the default to 1-3 new skill or subagent candidates and 1-3 \`IMPROVE EXISTING\` proposals, ranking within each class by time saved and frequency." "$SKILL"
  grep -qF "Never drop a qualified improvement to make room for a new component." "$SKILL"
  grep -qF "instead of scaffolding or proposing them" "$SKILL"
}

@test "the owning component body is read before an improvement is recorded" {
  grep -qF "Before recording \`IMPROVE EXISTING\`, read the owning component's file body, not just the frontmatter collected in Step 4, so the contract defect and proposed change name real steps, boundaries, or fields." "$SKILL"
}

@test "work already handled without friction stays ignored" {
  grep -qF "work an existing skill or agent already handles without recurring friction" "$SKILL"
}

@test "improvement report carries all six evidence fields and a concrete change" {
  grep -qF "affected component name and path, independent evidence count, paraphrased symptom, likely contract defect, proposed change, and how to verify the change worked" "$SKILL"
  grep -qF "State the proposed change as a concrete contract edit to that component, not as a wish." "$SKILL"
  grep -qF "Name the step, boundary, or field to change and what it should say instead." "$SKILL"
}

@test "improvement proposals redact private session content" {
  grep -qF "Paraphrase every symptom and name only components, files, and paths. Never quote private session content, secrets, customer data, tokens, or raw tool payloads in a proposal." "$SKILL"
  grep -qF "Treat session logs as private." "$SKILL"
}

@test "no flag grants edit authority over an existing component" {
  grep -qF "and neither grants authority to edit an existing skill or subagent" "$SKILL"
  grep -qF "This report is the whole output for these candidates under every flag, including \`--create\` and \`--auto\`." "$SKILL"
  grep -qF "Do not edit the affected component, and tell the user that applying the improvement is a separate follow-up they must request explicitly." "$SKILL"
  grep -qF "This skill never edits, rewrites, or scaffolds over an existing skill or subagent" "$SKILL"
  grep -qF "\`IMPROVE EXISTING\` candidates are never scaffolded or applied here." "$SKILL"
}

@test "summary keeps improvement, creation, rejection, and unverified outcomes separate" {
  grep -qF "Close with an audit-style summary that keeps each outcome separate." "$SKILL"
  grep -qF -e "- \`IMPROVE EXISTING\`: proposed improvements to existing components" "$SKILL"
  grep -qF -e "- \`CREATED\`: paths for any new skills or agents." "$SKILL"
  grep -qF -e "- \`NOT CREATED\`: rejected repeated ideas and improvement proposals, with one-line reasons." "$SKILL"
  grep -qF -e "- \`UNVERIFIED\`: any session stores, counts, or assumptions that could not be checked." "$SKILL"
}

@test "description routes run-derived improvement without dropping automation triggers" {
  grep -qF "improve a skill from its runs" "$SKILL"
  grep -qF "find automation opportunities" "$SKILL"
  grep -qF "Not for summarizing one session, general retrospectives, or codebase refactoring." "$SKILL"
}

@test "run-evidence improvement framing is attributed" {
  grep -qF "posthog-writing-agent-skills" "skills/kramme:session:automate-repeats/references/sources.yaml"
  grep -qF "the PostHog agent-skills post for the run-evidence improvement framing" "$SKILL"
}

@test "effectiveness mode is eligibility aware and refuses false precision" {
  grep -qF 'Use `--effectiveness` when the user wants evidence about which skills are working from real runs.' "$SKILL"
  grep -qF "Decide which installed skills were eligible from each safe skeleton's user ask and the current skill contracts before reading detected usage." "$SKILL"
  grep -qF "**correct invocation** when eligible and invoked, **missed invocation** when eligible and not invoked, or **suspected false invocation** when invoked but not eligible" "$SKILL"
  grep -qF "Do not calculate a coverage score, weighted overall score, or letter grade." "$SKILL"
  grep -qF "zero use alone never justifies changing a skill" "$SKILL"
}

@test "effectiveness mode uses bounded machine-readable evidence" {
  grep -qF 'also require `extract-skill-usage.py`' "$SKILL"
  grep -qF 'Write `$SCRATCH/effectiveness.json`' "$SKILL"
  grep -qF 'Build `KNOWN_SKILL_ARGS` only from the trusted installed-skill inventory in Step 4.' "$SKILL"
  grep -qF "The extractor must never emit transcript text, tool payloads, commands, paths, reasoning, or unrecognized candidate values." "$SKILL"
  grep -qF 'reports `unknown_skill_events`' "$SKILL"
  grep -qF "A missing required extractor already stops the workflow in Step 1." "$SKILL"
  grep -qF "mark that session's invocation evidence \`UNVERIFIED\`; never fall back to reading raw transcripts" "$SKILL"
}

@test "improvement proposals pass a counterfactual gate" {
  grep -qF "Test causality before changing a contract: identify the missing, incorrect, or underspecified instruction" "$SKILL"
  grep -qF "classify the event as model variance or a failure outside instruction surfaces instead of duplicating guidance" "$SKILL"
  grep -qF "Edit the narrowest existing rule in place; add new prose only when no current rule owns the behavior." "$SKILL"
}

@test "skill-doctor inspirations are attributed individually" {
  SOURCES="skills/kramme:session:automate-repeats/references/sources.yaml"
  grep -qF "warp-skill-doctor-workflow" "$SOURCES"
  grep -qF "warp-skill-doctor-improvement-guidelines" "$SOURCES"
  grep -qF "warp-skill-doctor-efficiency-scorer" "$SOURCES"
  grep -qF "warp-skill-doctor-code-quality-scorer" "$SOURCES"
}
