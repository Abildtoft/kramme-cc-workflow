#!/usr/bin/env bats

setup() {
  cd "$BATS_TEST_DIRNAME/.."
  CODE_REVIEW="skills/pr:code-review"
  CONVENTION_REVIEW="skills/pr:convention-review"
  GUIDES='`CONTRIBUTING.md` and `CODING_STANDARDS.md` at the repository root, in `.github/`, or in `docs/`'
}

@test "convention review reads coding-standards guides as merge-base documented rules" {
  grep -qF "plus the coding-standards guides $GUIDES" "$CONVENTION_REVIEW/SKILL.md"
  grep -qF "coding-standards guides ($GUIDES)" "$CONVENTION_REVIEW/references/baseline-mining.md"
  grep -qF "Only the merge-base version is Tier 1 evidence." "$CONVENTION_REVIEW/SKILL.md"
}

@test "code review passes coding-standards guides to every reviewer in both workflows" {
  grep -qF "Also find the coding-standards guides $GUIDES, and pass every reviewer the paths that exist" "$CODE_REVIEW/SKILL.md"
  grep -qF 'read its `MERGE_BASE` version with `git show "$MERGE_BASE:$path"` as the standard' "$CODE_REVIEW/SKILL.md"
  grep -qF 'The coding-standards guides found under standard workflow Step 7 (`CONTRIBUTING.md`, `CODING_STANDARDS.md`)' "$CODE_REVIEW/references/team-mode.md"
  grep -qF "suppress the smell and cite the file that permits it" "$CODE_REVIEW/references/fowler-smell-baseline.md"
}

@test "code review reads REVIEW.md policy at the merge base and accounts for it" {
  grep -qF 'Also find review policy files named `REVIEW.md` at the repository root and in every ancestor directory of a changed file.' "$CODE_REVIEW/SKILL.md"
  grep -qF 'Read each one as it exists at `MERGE_BASE`, never from the branch under review' "$CODE_REVIEW/SKILL.md"
  grep -qF "A policy never removes a finding silently" "$CODE_REVIEW/SKILL.md"
  grep -qF -e '- Review policy: {none | `REVIEW.md` paths read at `MERGE_BASE`}' "$CODE_REVIEW/references/output-template.md"
  grep -qF 'The checks and evidence requirements of the `REVIEW.md` policy files' "$CODE_REVIEW/references/team-mode.md"
  grep -qF 'A changed `REVIEW.md` is reported as not applied.' docs/review.md
}
