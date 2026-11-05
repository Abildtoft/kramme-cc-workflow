#!/usr/bin/env bats

setup() {
  cd "$BATS_TEST_DIRNAME/.."
  REFERENCE="shared/findings/references/disputing-findings.md"
  REFERENCE_PATH='${CLAUDE_PLUGIN_ROOT}/shared/findings/references/disputing-findings.md'
  RESOLVE_AUDIT="skills/siw:resolve-audit/SKILL.md"
  RESOLVE_REVIEW="skills/pr:resolve-review/SKILL.md"
  APPLY_NOW="skills/siw:spec-audit/references/apply-now.md"
  SPEC_AUDIT="skills/siw:spec-audit"
}

@test "a dispute needs evidence the reviewer could have read" {
  grep -qF '**Contest:** the finding is wrong and you can cite evidence the reviewer could have read' "$REFERENCE"
  grep -qF '**Escalate:** the finding looks wrong only because of something no file records' "$REFERENCE"
  grep -qF '"This was intentional" is not evidence.' "$REFERENCE"
  grep -qF 'wanting a finding to be wrong is not evidence that it is' "$REFERENCE"
  grep -qF 'Do not contest a comprehension gap.' "$REFERENCE"
  grep -qF 'Do not add text only to satisfy a reviewer that lacked context.' "$REFERENCE"
  grep -qF 'Do not lower a severity to make a finding go away.' "$REFERENCE"
  grep -qF 'accept the finding, and record your evidence for the lower rating alongside it' "$REFERENCE"
  ! grep -qF 'contest it and say why' "$REFERENCE"
}

@test "resolve-audit checks a finding before offering options" {
  local check_line summary_line

  grep -qF "$REFERENCE_PATH" "$RESOLVE_AUDIT"
  check_line=$(grep -nF '### 4.0 Check the Finding' "$RESOLVE_AUDIT" | cut -d: -f1)
  summary_line=$(grep -nF '#### 4.1 Executive Summary' "$RESOLVE_AUDIT" | head -n 1 | cut -d: -f1)
  [ "$check_line" -lt "$summary_line" ]
  grep -qF 'Create no issue. Add `**Status:** [Contested] {the evidence}`' "$RESOLVE_AUDIT"
}

@test "resolve-audit asks before contesting, unless --auto was given" {
  grep -qF 'With `--auto`, contest it without asking, unless it is Critical or its `Severity Note` says `from Critical`.' "$RESOLVE_AUDIT"
  grep -qF 'so handle it as an escalated finding. Otherwise ask the question below.' "$RESOLVE_AUDIT"
  grep -qF 'label: "Yes, contest it"' "$RESOLVE_AUDIT"
  grep -qF 'label: "No, the finding stands"' "$RESOLVE_AUDIT"
  grep -qF 'a disputed finding takes the Step 4.0 question instead' "$RESOLVE_AUDIT"
}

@test "naming a contested finding reopens it" {
  grep -qF 'Naming the id reopens it at Step 4.0.' "$RESOLVE_AUDIT"
  grep -qF '**Accept:** remove any earlier `[Contested]` line' "$RESOLVE_AUDIT"
}

@test "a finding that ends at the check still completes its cycle" {
  grep -qF 'After creating the SIW issue for one finding, or ending its cycle at Step 4.0:' "$RESOLVE_AUDIT"
  grep -qF 'or ending it at Step 4.0.' "$RESOLVE_AUDIT"
  grep -qF 'complete the full Steps 4-5 cycle or end it at Step 4.0.' "$RESOLVE_AUDIT"
}

@test "resolve-audit never settles unrecorded knowledge on its own" {
  grep -qF 'With `--auto`, do not ask, annotate, or create an issue.' "$RESOLVE_AUDIT"
  grep -qF 'A finding escalated in Step 4.0 gets no issue; report it instead.' "$RESOLVE_AUDIT"
  grep -qF 'Escalated - needs your decision (finding ids + the unrecorded fact' "$RESOLVE_AUDIT"
  grep -qF 'under `## Decision Log` when `siw/LOG.md` has that heading' "$RESOLVE_AUDIT"
  grep -qF 'readers of the spec will not see the fact unless it is added to the spec' "$RESOLVE_AUDIT"
}

@test "contested findings are not processed again" {
  grep -qF -- '- The finding is marked `**Status:** [Contested]` and the arguments do not name its id.' "$RESOLVE_AUDIT"
  grep -qF -- '- Findings marked `**Status:** [Contested]`' "$RESOLVE_AUDIT"
  grep -qF -- '- Already marked `**Status:** [Contested]`' "$APPLY_NOW"
  grep -qF 'Contested (finding ids + the evidence)' "$RESOLVE_AUDIT"
  grep -qF 'skipping findings marked `**Status:** [Contested]`' "skills/discovery:interview/references/siw-mode.md"
  grep -qF 'without its findings marked `**Status:** [Contested]`' "shared/findings/references/findings-intake.md"
}

@test "a contested finding carried into a re-audit stays out of counts and issues" {
  local rules="$SPEC_AUDIT/references/post-processing-rules.md"
  local format="$SPEC_AUDIT/assets/spec-audit-report-format.md"

  grep -qF 'report it under `## Contested Findings`' "$SPEC_AUDIT/SKILL.md"
  grep -qF 'It does not count toward severity totals, dimension scores, preserved-critical caps, or the overall assessment.' "$rules"
  grep -qF 'Leave out every finding marked `**Status:** [Contested]`, whichever selection applies:' "$rules"
  grep -qF 'leaving out contested findings' "$SPEC_AUDIT/SKILL.md"
  grep -qF '## Contested Findings' "$format"
  grep -qF '**Contested:** {count} (not counted above; see Contested Findings)' "$format"
  grep -qF 'follows the Step 4.2 rule for contested findings' "$SPEC_AUDIT/references/product-mode.md"
  grep -qF 'or under `## Contested Findings` for one marked `**Status:** [Contested]`' "$SPEC_AUDIT/references/product-mode.md"
  grep -qF 'Count product findings, except contested ones,' "$SPEC_AUDIT/references/product-mode.md"
  grep -qF 'Keep the carried findings, except those marked `**Status:** [Contested]`,' "$SPEC_AUDIT/references/product-mode.md"
  grep -qF 'Unless contested, they count toward severity totals' "$rules"
}

@test "resolve-review disagreements cite evidence and unrecorded knowledge goes to a person" {
  grep -qF "$REFERENCE_PATH" "$RESOLVE_REVIEW"
  grep -qF 'return `disagreed` with the evidence as the `rationale`' "$RESOLVE_REVIEW"
  grep -qF 'return `blocked-implementation` with a `rationale` that starts `Needs author decision:`' "$RESOLVE_REVIEW"
  grep -qF 'A disagreement cites evidence the reviewer could have read' "skills/pr:resolve-review/references/resolution-output.md"
  grep -qF 'or, with a `rationale` that starts `Needs author decision:`, that it needs a fact only the author can settle' "$RESOLVE_REVIEW"
  grep -qF 'Under `--implement-only`, implement it, because the parent already accepted the change.' "$RESOLVE_REVIEW"
}

@test "github-review-reply stops on the status an escalation returns and asks" {
  local reply="skills/pr:github-review-reply/SKILL.md"

  grep -qF '`blocked-implementation` or `blocked-validation` → keep the item as `needs-code-change`, mark `Implementation status: blocked`, and stop before posting replies.' "$reply"
  grep -qF 'A `blocked-implementation` whose `rationale` starts `Needs author decision:` is a question rather than a failed fix.' "$reply"
  grep -qF 'Do not invoke resolve-review again: its checkpoint would stash those changes' "$reply"
  grep -qF 'Otherwise make the fix yourself with their answer, on top of the first run'"'"'s uncommitted changes.' "$reply"
}
