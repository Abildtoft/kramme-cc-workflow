#!/usr/bin/env bats

setup() {
  cd "$BATS_TEST_DIRNAME/.."
}

SKILL="skills/kramme:code:audit-agent-config/SKILL.md"

@test "audit stays read-only and repo-scoped" {
  test -f "$SKILL"
  grep -qF "This skill is strictly read-only: it never edits, deletes, or reorders configuration, and it never audits configuration that lives outside the repository." "$SKILL"
  grep -qF "that is a separate follow-up they must request explicitly" "$SKILL"
  grep -qF "Never read or report on these, even when a repo file references them." "$SKILL"
  grep -qF "Note that the reference exists, but do not open or judge the global target." "$SKILL"
}

@test "inventory covers all configuration surfaces and reports empty ones" {
  grep -qF "record surfaces that came up empty so coverage is explicit" "$SKILL"
  grep -qF "| Project instructions |" "$SKILL"
  grep -qF "| Skills and commands |" "$SKILL"
  grep -qF "| Subagents |" "$SKILL"
  grep -qF "| Hooks |" "$SKILL"
  grep -qF "| MCP servers |" "$SKILL"
  grep -qF "| Permissions and settings |" "$SKILL"
  grep -qF "| Repo-persisted memory |" "$SKILL"
  grep -qF "| Other agent runtimes |" "$SKILL"
  grep -qF "treat this table as a starting set, not a complete list" "$SKILL"
  grep -qF "audit the source that generates them" "$SKILL"
}

@test "symlinked config is audited once and itemization completes before conflicts" {
  grep -qF "Resolve symlinks before itemizing and audit each real file exactly once" "$SKILL"
  grep -qF "instead of auditing it twice or reporting the pair as a redundancy" "$SKILL"
  grep -qF "Complete the itemization of every surface before starting Step 3" "$SKILL"
}

@test "verdicts weight context cost and use history and usage evidence" {
  grep -qF "Weight scrutiny by context cost: always-on items ship into every session" "$SKILL"
  grep -qF 'git log -1 --format=%cs -- <file>' "$SKILL"
  grep -qF "zero recorded use is supporting evidence of irrelevance — never sufficient on its own" "$SKILL"
  grep -qF "prefix items from always-on surfaces with \`[always-on]\` and list them first" "$SKILL"
}

@test "optional scope path narrows the audit without loosening rules" {
  grep -qF 'argument-hint: "[scope-path]"' "$SKILL"
  grep -qF "restrict the audit to configuration surfaces at or under that path" "$SKILL"
  grep -qF "keep every other rule unchanged" "$SKILL"
  grep -qF "never widen a scoped audit or follow the path outside the repo" "$SKILL"
}

@test "verdicts require verified evidence for all four defect classes" {
  grep -qF "**Redundant**" "$SKILL"
  grep -qF "**Outdated**" "$SKILL"
  grep -qF "**Conflicting**" "$SKILL"
  grep -qF "**Irrelevant**" "$SKILL"
  grep -qF "Verify with an existence check (glob, file read, or \`--help\` on a referenced command) before flagging." "$SKILL"
  grep -qF "Verify with a repository-wide search for the tool or pattern before flagging." "$SKILL"
  grep -qF "never REMOVE or IMPROVE on suspicion" "$SKILL"
}

@test "IMPROVE is reserved for salvageable items and names the fix" {
  grep -qF "An item whose purpose is still valid but whose current form has a confirmed defect is IMPROVE" "$SKILL"
  grep -qF "The sentence must state the defect and the concrete fix." "$SKILL"
  grep -qF "if any part is worth keeping, the verdict is IMPROVE, not REMOVE" "$SKILL"
}

@test "report is an inline KEEP / IMPROVE / REMOVE list with one sentence per item" {
  grep -qF "Output the results directly in the reply (no report file)" "$SKILL"
  grep -qF "## KEEP" "$SKILL"
  grep -qF "## IMPROVE" "$SKILL"
  grep -qF "## REMOVE" "$SKILL"
  grep -qF "Exactly one sentence per item." "$SKILL"
  grep -qF "no files were changed, and removals or improvements can be applied as a follow-up on request" "$SKILL"
}
