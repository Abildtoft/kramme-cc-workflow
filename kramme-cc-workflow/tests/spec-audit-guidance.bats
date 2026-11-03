#!/usr/bin/env bats

setup() {
  cd "$BATS_TEST_DIRNAME/.."
  SKILL="skills/kramme:siw:spec-audit/SKILL.md"
  DIMENSIONS="skills/kramme:siw:spec-audit/references/dimension-instructions.md"
  CLAIMS_PROMPT="skills/kramme:siw:spec-audit/references/claims-check-prompt.md"
  AUDIT_PROMPT="skills/kramme:siw:spec-audit/references/audit-agent-prompt.md"
  TEAM="skills/kramme:siw:spec-audit/references/team-mode.md"
  AGENT="agents/kramme:codebase-pattern-reviewer.md"
}

@test "the claims check tests what exists today, not whether code implements the spec" {
  grep -qF 'This is not an implementation audit' "$AGENT"
  grep -qF 'Do not perform an implementation audit.' "$AGENT"
  grep -qF '**Contradicts the code**: the spec describes current behavior the code does not have. Report as **Critical**.' "$AGENT"
  grep -qF 'Report this once as **Major**, not once per path.' "$AGENT"
  grep -qF 'Anything the plan proposes to create is not a finding' "$AGENT"
  grep -qF '### CLAIM-NNN:' "$AGENT"
}

@test "standard mode runs only the claims part, and only when the spec names existing code" {
  grep -qF '| Current-State References |' "$SKILL"
  grep -qF 'record `skipped (spec names no existing code)`' "$SKILL"
  grep -qF 'Run only the Current-State Claims check from your instructions and skip the pattern review.' "$CLAIMS_PROMPT"
  grep -qF '**Dimension**: Technical Design' "$CLAIMS_PROMPT"
  grep -qF '**Source**: Current-State Claims' "$CLAIMS_PROMPT"
  grep -qF '{fix-confidence rubric path}' "$CLAIMS_PROMPT"
}

@test "claims the reviewer could not verify stay visible in the report" {
  grep -qF 'including any claims the reviewer could not verify' "$SKILL"
  grep -qF 'checked, {N} unverified: {the claims}' "skills/kramme:siw:spec-audit/assets/spec-audit-report-format.md"
  grep -qF 'Current-state claims you could not verify' "$AGENT"
}

@test "team mode widens the pattern reviewer to both checks" {
  grep -qF 'whether what it says' "$TEAM"
  grep -qF 'Current-State Claims for a `CLAIM-NNN` finding' "$TEAM"
  grep -qF 'Keep current-state claim findings.' "$TEAM"
}

@test "actionability flags design decisions left to the implementer" {
  grep -qF '**Decisions left to the implementer.**' "$DIMENSIONS"
  grep -qF 'Mechanical choices with one defensible answer, such as a file name, are not findings.' "$DIMENSIONS"
}

@test "a re-audit checks what earlier fixes added without reopening settled decisions" {
  grep -qF '**Defensive accretion.**' "$DIMENSIONS"
  grep -qF 'Do not reopen a decision the spec records as settled.' "$DIMENSIONS"
  grep -qF '## Previously Resolved Findings' "$AUDIT_PROMPT"
  grep -qF 'fill the group that audits Scope with its Previously Resolved Findings block' "$SKILL"
  grep -qF 'add the Previously Resolved Findings block' "$TEAM"
}

@test "only findings that were really addressed count as previously resolved" {
  grep -qF 'carrying an `Existing issue:` note for an issue that is `DONE` in `siw/OPEN_ISSUES_OVERVIEW.md`' "$SKILL"
  grep -qF 'If a listed gap still exists, report it as usual.' "$AUDIT_PROMPT"
  ! grep -qF 'Do not re-raise the findings themselves' "$AUDIT_PROMPT"
}

@test "team mode waits for the comprehension reply" {
  grep -qF 'Start the cross-reviewer only after the reply is back or the read has failed.' "$TEAM"
  grep -qF '{Collected findings from all 4 dimension auditors, the codebase pattern reviewer, and the comprehension read}' "$TEAM"
  grep -qF '1. Collect all findings from dimension auditors, the codebase pattern reviewer, the comprehension read, and the cross-reviewer' "$TEAM"
}

@test "a contested finding stays settled across re-audits until its evidence changes" {
  grep -qF 'A finding that matches one marked `**Status:** [Contested]` in the previous report stays settled unless the spec text or the cited evidence has changed' "$SKILL"
}
