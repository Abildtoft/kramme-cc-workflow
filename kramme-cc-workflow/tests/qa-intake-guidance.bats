#!/usr/bin/env bats

setup() {
  cd "$BATS_TEST_DIRNAME/.."
  SKILL="skills/kramme:qa:intake/SKILL.md"
}

@test "qa intake keeps its clarification and breakdown approval boundaries" {
  grep -qF "Ask **at most 2-3 short clarifying questions**" "$SKILL"
  grep -qF "If you find yourself wanting a fourth question, stop." "$SKILL"
  grep -qF 'Emit `PLAN` with the proposed split' "$SKILL"
  grep -qF "wait for the user's go-ahead before creating any ticket" "$SKILL"
}

@test "qa intake requires complete two-way breakdown links" {
  local breakdown

  breakdown="$(sed -n '/^### 3c\. Assess scope/,/^## Durability Rule$/p' "$SKILL")"

  grep -qF 'without a parent issue/container, without final child links on the parent, or without `Parent issue/report` lines on every child' <<<"$breakdown"
  grep -qF "update the parent created for this breakdown so its final body lists the child ticket IDs or URLs" <<<"$breakdown"
  grep -qF '**Parent issue/report:** <parent-ticket-id-or-QA-INTAKE-NNN>' <<<"$breakdown"
}

@test "qa intake requires a writable sink and intentional continuation" {
  grep -qF 'MISSING REQUIREMENT: no writable ticket sink' "$SKILL"
  grep -qF "After filing 10 tickets in one session, pause before continuing" "$SKILL"
  grep -qF "confirm the user still intends to keep filing" "$SKILL"
}

@test "qa intake preserves ticket mutation and partial-write boundaries" {
  local verification

  verification="$(sed -n '/^## Verification$/,$p' "$SKILL")"

  grep -qF "modify pre-existing tickets" "$SKILL"
  grep -qF "update only the just-created parent issue to add child links" "$SKILL"
  grep -qF "surface the partial state in the completion summary" "$SKILL"
  grep -qF "the only permitted correction is the already-authorized child-link finalization" <<<"$verification"
  grep -qF "surface every other mismatch as partial state with recovery guidance" <<<"$verification"
}
