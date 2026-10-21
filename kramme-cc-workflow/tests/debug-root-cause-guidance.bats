#!/usr/bin/env bats

setup() {
  cd "$BATS_TEST_DIRNAME/.."
  PROCEDURE="shared/debug/references/root-cause-investigation.md"
  TRIAGE="skills/kramme:debug:triage-to-issue/SKILL.md"
  INVESTIGATE="skills/kramme:debug:investigate/SKILL.md"
}

@test "triage and investigate load one plugin-level root-cause procedure" {
  for resource in references/root-cause-investigation.md references/bisect-guide.md references/investigation-patterns.md assets/investigation-log.md; do
    test -f "shared/debug/$resource"
    for skill in "$TRIAGE" "$INVESTIGATE"; do
      grep -qF "\${CLAUDE_PLUGIN_ROOT}/shared/debug/$resource" "$skill"
    done
  done
  for resource in references/bisect-guide.md references/investigation-patterns.md assets/investigation-log.md; do
    test ! -e "skills/kramme:debug:investigate/$resource"
  done
}

@test "shared root-cause procedure stops before any fix" {
  for text in '## 1. Reproduce' '## 2. Isolate' '## 3. Trace Root Cause' '## 4. Document Findings' '## 5. Assess Confidence' 'UNATTENDED' 'git bisect reset' 'never proposes, applies, or verifies a fix'; do
    grep -qF "$text" "$PROCEDURE"
  done
  for text in '[FIX]' 'Implement fix' 'AUTO_MODE'; do
    if grep -qF "$text" "$PROCEDURE"; then false; fi
  done
}

@test "bug triage runs the shared procedure report-only without invoking investigate" {
  if grep -qF 'via the Skill tool' "$TRIAGE"; then false; fi
  if grep -qF 'installed skills directory' "$TRIAGE"; then false; fi
  grep -qF 'do not invoke that skill or read its files' "$TRIAGE"
  grep -qF 'Triage never proposes, applies, or verifies a fix' "$TRIAGE"
  grep -qF 'id: addy-debugging-and-error-recovery' skills/kramme:debug:triage-to-issue/references/sources.yaml
}

@test "triage resolves Linear issue inputs before investigation even in unattended mode" {
  capture=$(sed -n '/^### Phase 1 — Capture$/,/^### Phase 2 — Detect sinks$/p' "$TRIAGE")
  investigation=$(sed -n '/^### Phase 3 — Investigation$/,/^### Phase 4 — TDD plan$/p' "$TRIAGE")
  for text in 'Linear issue reference' 'TEAM-123' 'mcp__linear__get_issue' 'Codex `get_issue`' 'description, steps to reproduce, and expected vs. actual behavior' 'unavailable or the fetch fails' 'ask the user to paste the issue content and wait' 'even with `--yes` or `--auto`' 'Store the resolved description as `BUG_DESCRIPTION`'; do
    [[ "$capture" == *"$text"* ]] || return 1
  done
  [[ "$investigation" == *'with `BUG_DESCRIPTION` from Phase 1'* ]]
}

@test "investigate keeps its fix workflow after the shared procedure" {
  grep -qF '`UNATTENDED` set to the value of `AUTO_MODE`' "$INVESTIGATE"
  grep -qF '## Step 6: Propose Fix' "$INVESTIGATE"
  grep -qF '## Step 7: Implement and Verify' "$INVESTIGATE"
  grep -qF '## Step 8: Summary' "$INVESTIGATE"
  shared_line=$(grep -nF '## Steps 2–5' "$INVESTIGATE" | cut -d: -f1)
  fix_line=$(grep -nF '## Step 6: Propose Fix' "$INVESTIGATE" | cut -d: -f1)
  [ "$shared_line" -lt "$fix_line" ]
}
