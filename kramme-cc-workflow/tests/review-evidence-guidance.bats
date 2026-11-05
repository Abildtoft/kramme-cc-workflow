#!/usr/bin/env bats

setup() {
  cd "$BATS_TEST_DIRNAME/.."
  SKILL="skills/kramme:pr:code-review/SKILL.md"
  DISCIPLINE="skills/kramme:pr:code-review/references/review-discipline.md"
  TEMPLATE="skills/kramme:pr:code-review/references/output-template.md"
  TEAM="skills/kramme:pr:code-review/references/team-mode.md"
  SMELLS="skills/kramme:pr:code-review/references/fowler-smell-baseline.md"
  VALIDATOR="agents/kramme:pr-relevance-validator.md"
}

absent() {
  ! grep -qF -e "$1" "$2"
}

@test "confidence rises on evidence, not reviewer agreement" {
  grep -qF "Raise confidence only on new evidence" "$DISCIPLINE"
  grep -qF "Agreement alone is not evidence" "$DISCIPLINE"
  absent "Promote confidence only when independent reviewers agree" "$DISCIPLINE"
  grep -qF "agreement between reviewers alone does not raise confidence" "$TEMPLATE"
  absent "independently confirmed by another reviewer on the same root cause" "$TEMPLATE"
  grep -qF "agreement alone does not raise a finding's confidence" "$TEAM"
}

@test "contradictions are settled from the cited code before escalating" {
  grep -qF "re-read the code each side cites before escalating" "$DISCIPLINE"
  grep -qF "how many reviewers took each side is not evidence" "$DISCIPLINE"
}

@test "confident findings quote their trigger and disproved findings are dropped" {
  grep -qF "A finding at 60 or higher must open its Evidence with the exact triggering source line or lines" "$DISCIPLINE"
  grep -qF "an empty text search alone does not prove absence" "$DISCIPLINE"
  grep -qF "If they show the reported failure cannot happen, drop the finding" "$DISCIPLINE"
  grep -qF "returns an explicit zero-findings result" "$DISCIPLINE"
}

@test "protected-subject findings leave the report only with refuting evidence" {
  grep -qF "### Protected-subject findings" "$DISCIPLINE"
  grep -qF "It may leave the active report only with checkable refuting evidence" "$DISCIPLINE"
  grep -qF 'keep the finding at its severity as `manual` with the `incomplete trace/UNVERIFIED` blocker' "$DISCIPLINE"
  grep -qF 'so neither the manual-heavy re-test nor reclassification to `gated_auto` removes it' "$DISCIPLINE"
  grep -qF 'A protected-subject finding disputed without the refuting evidence that `Protected-subject findings` below requires also meets this test.' "$DISCIPLINE"
  grep -qF 'only when the validator cites the refuting `MERGE_BASE` line' "$SKILL"
  grep -qF 'a `Pre-existing` or `Out-of-scope` classification must cite the base line' "$VALIDATOR"
}

@test "relevance keeps defects the change reaches and reads only cited hunks" {
  grep -qF "stays in scope when the change makes it reachable" "$SKILL"
  grep -qF "Distance alone never decides" "$VALIDATOR"
  absent "Allow a tolerance of ~5 lines" "$VALIDATOR"
  grep -qF 'git show "$BASE_REF:path/to/file"' "$VALIDATOR"
  grep -qF "read hunks only for the files the findings cite" "$VALIDATOR"
  grep -qF "### Reading the review scope" "$DISCIPLINE"
  grep -qF 'Pass the resolved `BASE_BRANCH`, `BASE_REF`, `MERGE_BASE`, `CHANGED_FILES`, and PR context' "$SKILL"
}

@test "the reviewer roster covers checks that pass while broken and feature gates" {
  grep -qF "verification changes that can pass while what they guard is broken" "$SKILL"
  grep -qF "### 5. Check Verification That Can Pass While Broken" agents/kramme:silent-failure-hunter.md
  grep -qF "feature-flag or entitlement gates that decide whether functionality is reachable" "$SKILL"
  grep -qF "**Feature and entitlement gates**" agents/kramme:security-reviewer.md
  grep -qF "unless the diff changes that flag's default or where its guard runs" agents/kramme:security-reviewer.md
}

@test "team mode passes the smell baseline and the baseline narrows its exemptions" {
  grep -qF 'the full text of `references/fowler-smell-baseline.md` for the code-reviewer and cleanup-reviewer teammates' "$TEAM"
  grep -qF "use the smell baseline only when it sharpens a concrete changed-code concern" "$TEAM"
  grep -qF "an existing local pattern alone does not justify it" "$SMELLS"
  grep -qF "length alone is never the reason" "$SMELLS"
}

@test "acknowledged or skipped findings stay settled without new evidence" {
  grep -qF '**Treat as settled** a previous finding with `Resolution status: acknowledged` or `skipped`' "$SKILL"
  grep -qF 'as `manual` with the maintainer-decision blocker' "$SKILL"
  grep -qF "Acknowledged/skipped findings settled, not re-raised: X" "$TEMPLATE"
  grep -qF 'keep settled `acknowledged` or `skipped` matches out of the active findings' "$TEAM"
}
