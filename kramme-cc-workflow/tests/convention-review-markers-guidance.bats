#!/usr/bin/env bats

setup() {
  cd "$BATS_TEST_DIRNAME/.."
  SKILL="skills/kramme:pr:convention-review/SKILL.md"
  MINING="skills/kramme:pr:convention-review/references/baseline-mining.md"
}

@test "each convention review marker has one meaning" {
  grep -qF '`NOTICED BUT NOT TOUCHING` — a deliberate decision not to act, always stated with its reason.' "$MINING"
  grep -qF "for a protective construct the diff adds that the Lens B hard limits keep" "$MINING"
  grep -qF "For a finding the relevance validator could not confirm as caused by this change, the confidence stays as scored" "$MINING"
  grep -qF 'Treat `Likely Related` findings as relevance-unconfirmed: label them `UNVERIFIED`' "$SKILL"
}

@test "convention review reports what it deliberately left alone" {
  grep -qF -e '- **Noticed But Not Touching** — every `NOTICED BUT NOT TOUCHING` note' "$SKILL"
  grep -qF -e "- Noticed but not touching: X" "$SKILL"
  grep -qF "appear in the Noticed But Not Touching section with its reason" "$SKILL"
}
