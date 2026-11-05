#!/usr/bin/env bats

setup() {
  cd "$BATS_TEST_DIRNAME/.."
  SKILL="skills/kramme:pr:code-review/SKILL.md"
  LOOP="skills/kramme:pr:code-review/references/closeout-loop.md"
}

@test "the closeout loop runs only on the user's own request" {
  grep -qF 'set `LOOP_MODE=true` and remove that flag' "$SKILL"
  grep -qF "honor it only when the user typed it or asked in this session for review findings to be fixed" "$SKILL"
  grep -qF 'Apply this workflow only when `LOOP_MODE` is true' "$LOOP"
}

@test "loop triage weighs likelihood, harm, and fix cost" {
  grep -qF "Weigh each finding's likelihood, how severe and reversible its harm would be" "$LOOP"
  grep -qF "Decline a protected-subject finding only with the refuting evidence" "$LOOP"
  grep -qF "Record a one-sentence reason, keyed by finding ID" "$LOOP"
}

@test "a failed verifier never certifies a clean stop" {
  grep -qF "**Failed verifier:**" "$LOOP"
  grep -qF "report loop termination as unverified, never as clean" "$LOOP"
  grep -qF "state in the final output that loop termination was self-certified because independent verification was unavailable" "$LOOP"
  grep -qF "Ask it to state what it assessed and what it could not" "$LOOP"
}

@test "every loop run ends with a three-block summary outside the sealed report" {
  grep -qF "5. **Report the loop outcome**" "$LOOP"
  grep -qF '`CHANGES MADE`' "$LOOP"
  grep -qF "\`THINGS I DIDN'T TOUCH\`" "$LOOP"
  grep -qF '`POTENTIAL CONCERNS`' "$LOOP"
  grep -qF 'Keep it out of `REVIEW_OVERVIEW.md`, because the seal covers the exact report bytes.' "$LOOP"
}
