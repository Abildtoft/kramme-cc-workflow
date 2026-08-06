#!/usr/bin/env bats

load 'test_helper/common'

setup() {
  TMP_ROOT="$(mktemp -d)"
  ISSUE_DEFINE_RESERVATION_HELPER="$BATS_TEST_DIRNAME/../skills/kramme:siw:issue-define/scripts/siw-issue-reservation.sh"
  GENERATE_PHASES_RESERVATION_HELPER="$BATS_TEST_DIRNAME/../skills/kramme:siw:generate-phases/scripts/siw-issue-reservation.sh"
}

teardown() {
  rm -rf "$TMP_ROOT"
}

create_reserved_fixture_issue() {
  local helper="$1"
  local siw_dir="$2"
  local owner="$3"
  local title="$4"
  local result_file="$5"
  local issue_id

  SIW_RESERVATION_RETRY_DELAY=0 sh "$helper" acquire "$siw_dir" "$owner" 500
  issue_id="$(sh "$helper" reserve "$siw_dir" G "$owner" 100)"
  printf '# ISSUE-%s: %s\n' "$issue_id" "$title" >"$siw_dir/issues/ISSUE-$issue_id-$title.md"
  printf '| %s | %s | READY |\n' "$issue_id" "$title" >>"$siw_dir/OPEN_ISSUES_OVERVIEW.md"
  printf -- '- Created %s: %s\n' "$issue_id" "$title" >>"$siw_dir/LOG.md"
  sh "$helper" publish-receipt "$siw_dir" "$owner" "$issue_id"
  sh "$helper" release "$siw_dir" "$issue_id" "$owner"
  sh "$helper" release-publication "$siw_dir" "$owner"
  printf '%s\n' "$issue_id" >"$result_file"
}

@test "siw issue reservation generates unique owners and preserves a contended lock" {
  local hash_backend hash_backend_path hash_log issue_id mock_bin owner_a owner_b siw_dir
  siw_dir="$TMP_ROOT/siw"
  mkdir -p "$siw_dir/issues"
  printf '# Open Issues\n' >"$siw_dir/OPEN_ISSUES_OVERVIEW.md"
  printf '# Log\n' >"$siw_dir/LOG.md"

  owner_a="$(sh "$ISSUE_DEFINE_RESERVATION_HELPER" new-owner)"
  owner_b="$(sh "$GENERATE_PHASES_RESERVATION_HELPER" new-owner)"
  [ "$owner_a" != "$owner_b" ]
  [[ "$owner_a" =~ ^[a-z0-9-]+$ ]]
  [[ "$owner_b" =~ ^[a-z0-9-]+$ ]]

  sh "$ISSUE_DEFINE_RESERVATION_HELPER" acquire "$siw_dir" "$owner_a" 1
  issue_id="$(sh "$ISSUE_DEFINE_RESERVATION_HELPER" reserve "$siw_dir" G "$owner_a" 1)"

  hash_log="$TMP_ROOT/hash-calls"
  mock_bin="$TMP_ROOT/hash-bin"
  mkdir -p "$mock_bin"
  if command -v sha256sum >/dev/null 2>&1; then
    hash_backend=sha256sum
  elif command -v shasum >/dev/null 2>&1; then
    hash_backend=shasum
  else
    hash_backend=openssl
  fi
  hash_backend_path="$(command -v "$hash_backend")"
  write_file "$mock_bin/$hash_backend" <<EOF
#!/bin/sh
printf 'called\n' >>"$hash_log"
exec "$hash_backend_path" "\$@"
EOF
  chmod +x "$mock_bin/$hash_backend"

  run env PATH="$mock_bin:$PATH" SIW_RESERVATION_RETRY_DELAY=0 sh "$GENERATE_PHASES_RESERVATION_HELPER" acquire "$siw_dir" "$owner_b" 2
  [ "$status" -ne 0 ]
  [[ "$output" == *'publication is owned by another writer'* ]]
  [[ "$output" != *"$owner_a"* ]]
  [ ! -e "$hash_log" ]
  [ "$(sed -n '1p' "$siw_dir/.issue-publication.lock")" = "$owner_a" ]
  [ "$(cat "$siw_dir/.issue-id-reservations/ISSUE-$issue_id")" = "$owner_a" ]
  [ -f "$siw_dir/.issue-publication.lock" ]
  [ ! -L "$siw_dir/.issue-publication.lock" ]

  sh "$GENERATE_PHASES_RESERVATION_HELPER" acquire "$siw_dir" "$owner_a" 1
  sh "$GENERATE_PHASES_RESERVATION_HELPER" abandon "$siw_dir" "$issue_id" "$owner_a"
  sh "$GENERATE_PHASES_RESERVATION_HELPER" release-publication "$siw_dir" "$owner_a"
  [ ! -e "$siw_dir/.issue-publication.lock" ]
  set -- "$siw_dir"/.siw-owner-claim.*
  [ ! -e "$1" ]
  set -- "$siw_dir"/.issue-id-reservations/.siw-owner-claim.*
  [ ! -e "$1" ]
}

@test "siw issue reservation rejects incomplete ownerless publication state" {
  local siw_dir
  siw_dir="$TMP_ROOT/siw"
  mkdir -p "$siw_dir/issues" "$siw_dir/.issue-publication.lock"
  printf '# Open Issues\n' >"$siw_dir/OPEN_ISSUES_OVERVIEW.md"

  run env SIW_RESERVATION_RETRY_DELAY=0 sh "$ISSUE_DEFINE_RESERVATION_HELPER" acquire "$siw_dir" owner-a 1

  [ "$status" -ne 0 ]
  [[ "$output" == *'publication lock is not a regular ownership claim'* ]]
  [[ "$output" != *'owner-a'* ]]
  [ -d "$siw_dir/.issue-publication.lock" ]
}

@test "siw issue reservation serializes concurrent creators with unique complete tracking views" {
  local siw_dir round left_pid right_pid issue_id matches
  siw_dir="$TMP_ROOT/siw"
  mkdir -p "$siw_dir/issues" "$TMP_ROOT/results"
  cat >"$siw_dir/OPEN_ISSUES_OVERVIEW.md" <<'EOF'
# Open Issues
| # | Title | Status |
| --- | --- | --- |
| G-001 | Existing overview issue | READY |
EOF
  cat >"$siw_dir/issues/ISSUE-G-003-existing-disk-gap.md" <<'EOF'
# ISSUE-G-003: Existing disk issue
EOF
  printf '# Log\n' >"$siw_dir/LOG.md"

  for round in $(seq 1 12); do
    create_reserved_fixture_issue "$ISSUE_DEFINE_RESERVATION_HELPER" "$siw_dir" "define-$round" "define-$round" "$TMP_ROOT/results/define-$round" &
    left_pid=$!
    create_reserved_fixture_issue "$GENERATE_PHASES_RESERVATION_HELPER" "$siw_dir" "phases-$round" "phases-$round" "$TMP_ROOT/results/phases-$round" &
    right_pid=$!
    wait "$left_pid"
    wait "$right_pid"
  done

  cat "$TMP_ROOT"/results/* | sort >"$TMP_ROOT/created-ids"
  [ "$(wc -l <"$TMP_ROOT/created-ids" | tr -d ' ')" -eq 24 ]
  [ "$(sort -u "$TMP_ROOT/created-ids" | wc -l | tr -d ' ')" -eq 24 ]
  [ "$(head -n 1 "$TMP_ROOT/created-ids")" = "G-004" ]
  [ "$(tail -n 1 "$TMP_ROOT/created-ids")" = "G-027" ]
  [ ! -e "$siw_dir/issues/ISSUE-G-002-gap-must-remain.md" ]
  [ "$(grep -c '^| G-' "$siw_dir/OPEN_ISSUES_OVERVIEW.md")" -eq 25 ]
  [ "$(grep -c '^- Created G-' "$siw_dir/LOG.md")" -eq 24 ]

  while IFS= read -r issue_id; do
    set -- "$siw_dir"/issues/ISSUE-"$issue_id"-*.md
    [ -e "$1" ]
    matches="$(grep -c "^| $issue_id |" "$siw_dir/OPEN_ISSUES_OVERVIEW.md")"
    [ "$matches" -eq 1 ]
    matches="$(grep -c "^- Created $issue_id:" "$siw_dir/LOG.md")"
    [ "$matches" -eq 1 ]
  done <"$TMP_ROOT/created-ids"

  [ ! -e "$siw_dir/.issue-publication.lock" ]
  set -- "$siw_dir"/.issue-id-reservations/ISSUE-*
  [ ! -e "$1" ]
}

@test "siw issue reservation cleanup is owner-safe and recovers interrupted creation" {
  local siw_dir issue_id
  siw_dir="$TMP_ROOT/siw"
  mkdir -p "$siw_dir/issues"
  printf '# Open Issues\n\n_Use /kramme:siw:issue-define to create first issue (G-001)_\n' >"$siw_dir/OPEN_ISSUES_OVERVIEW.md"
  printf '# Log\n' >"$siw_dir/LOG.md"

  sh "$ISSUE_DEFINE_RESERVATION_HELPER" acquire "$siw_dir" owner-a 1
  run sh "$ISSUE_DEFINE_RESERVATION_HELPER" reserve "$siw_dir" P12x owner-a 5
  [ "$status" -ne 0 ]
  [[ "$output" == *'issue prefix must be G or P followed by a positive phase number'* ]]
  issue_id="$(sh "$ISSUE_DEFINE_RESERVATION_HELPER" reserve "$siw_dir" G owner-a 5)"
  [ "$issue_id" = G-001 ]

  run sh "$GENERATE_PHASES_RESERVATION_HELPER" abandon "$siw_dir" "$issue_id" owner-b
  [ "$status" -ne 0 ]
  [[ "$output" == *'reservation belongs to a different owner'* ]]
  run sh "$GENERATE_PHASES_RESERVATION_HELPER" release-publication "$siw_dir" owner-a
  [ "$status" -ne 0 ]
  [[ "$output" == *'release or abandon owned issue reservations'* ]]

  sh "$ISSUE_DEFINE_RESERVATION_HELPER" abandon "$siw_dir" "$issue_id" owner-a
  issue_id="$(sh "$ISSUE_DEFINE_RESERVATION_HELPER" reserve-exact "$siw_dir" G-010 owner-a)"
  [ "$issue_id" = G-010 ]
  sh "$ISSUE_DEFINE_RESERVATION_HELPER" abandon "$siw_dir" "$issue_id" owner-a
  sh "$ISSUE_DEFINE_RESERVATION_HELPER" release-publication "$siw_dir" owner-a
  [ ! -e "$siw_dir/.issue-publication.lock" ]

  sh "$GENERATE_PHASES_RESERVATION_HELPER" acquire "$siw_dir" owner-b 1
  issue_id="$(sh "$GENERATE_PHASES_RESERVATION_HELPER" reserve "$siw_dir" G owner-b 5)"
  [ "$issue_id" = G-001 ]
  printf '# ISSUE-%s: recovered\n' "$issue_id" >"$siw_dir/issues/ISSUE-$issue_id-recovered.md"

  run sh "$GENERATE_PHASES_RESERVATION_HELPER" abandon "$siw_dir" "$issue_id" owner-b
  [ "$status" -ne 0 ]
  [[ "$output" == *'cannot abandon G-001 after its issue file exists'* ]]
  printf '| %s | recovered | READY |\n' "$issue_id" >>"$siw_dir/OPEN_ISSUES_OVERVIEW.md"
  printf -- '- Created %s: recovered\n' "$issue_id" >>"$siw_dir/LOG.md"
  sh "$GENERATE_PHASES_RESERVATION_HELPER" publish-receipt "$siw_dir" owner-b "$issue_id"
  sh "$GENERATE_PHASES_RESERVATION_HELPER" verify-receipt "$siw_dir" owner-b "$issue_id"
  sh "$GENERATE_PHASES_RESERVATION_HELPER" release "$siw_dir" "$issue_id" owner-b
  sh "$GENERATE_PHASES_RESERVATION_HELPER" release-publication "$siw_dir" owner-b

  [ "$(grep -c '^| G-001 |' "$siw_dir/OPEN_ISSUES_OVERVIEW.md")" -eq 1 ]
  [ "$(grep -c '^- Created G-001:' "$siw_dir/LOG.md")" -eq 1 ]
  [ ! -e "$siw_dir/.issue-publication.lock" ]
}

@test "siw issue reservation advances past higher live reservations" {
  local siw_dir first_id next_id
  siw_dir="$TMP_ROOT/siw"
  mkdir -p "$siw_dir/issues"
  printf '# Open Issues\n| G-003 | existing | READY |\n' >"$siw_dir/OPEN_ISSUES_OVERVIEW.md"
  printf '# ISSUE-G-005: existing\n' >"$siw_dir/issues/ISSUE-G-005-existing.md"

  sh "$ISSUE_DEFINE_RESERVATION_HELPER" acquire "$siw_dir" owner-a 1
  first_id="$(sh "$ISSUE_DEFINE_RESERVATION_HELPER" reserve-exact "$siw_dir" G-010 owner-a)"
  next_id="$(sh "$GENERATE_PHASES_RESERVATION_HELPER" reserve "$siw_dir" G owner-a 1)"

  [ "$first_id" = G-010 ]
  [ "$next_id" = G-011 ]
  sh "$ISSUE_DEFINE_RESERVATION_HELPER" abandon "$siw_dir" "$first_id" owner-a
  sh "$ISSUE_DEFINE_RESERVATION_HELPER" abandon "$siw_dir" "$next_id" owner-a
  sh "$ISSUE_DEFINE_RESERVATION_HELPER" release-publication "$siw_dir" owner-a
}

@test "siw replacement reservations unwind after a pre-deletion collision" {
  local siw_dir reservation_root
  siw_dir="$TMP_ROOT/siw"
  reservation_root="$siw_dir/.issue-id-reservations"
  mkdir -p "$siw_dir/issues" "$reservation_root"
  printf '# Open Issues\n' >"$siw_dir/OPEN_ISSUES_OVERVIEW.md"
  printf '# Log\n' >"$siw_dir/LOG.md"
  printf '# ISSUE-G-001: existing\n' >"$siw_dir/issues/ISSUE-G-001-existing.md"
  printf '# ISSUE-G-002: existing\n' >"$siw_dir/issues/ISSUE-G-002-existing.md"
  printf 'owner-stale\n' >"$reservation_root/ISSUE-G-002"

  sh "$GENERATE_PHASES_RESERVATION_HELPER" acquire "$siw_dir" owner-a 1
  [ "$(sh "$GENERATE_PHASES_RESERVATION_HELPER" reserve-exact "$siw_dir" G-001 owner-a)" = G-001 ]

  run sh "$GENERATE_PHASES_RESERVATION_HELPER" reserve-exact "$siw_dir" G-002 owner-a
  [ "$status" -ne 0 ]
  [[ "$output" == *'exact issue ID is already reserved: G-002'* ]]
  run sh "$GENERATE_PHASES_RESERVATION_HELPER" abandon "$siw_dir" G-001 owner-a
  [ "$status" -ne 0 ]
  [[ "$output" == *'cannot abandon G-001 after its issue file exists'* ]]

  sh "$GENERATE_PHASES_RESERVATION_HELPER" release "$siw_dir" G-001 owner-a
  sh "$GENERATE_PHASES_RESERVATION_HELPER" release-publication "$siw_dir" owner-a

  [ ! -e "$siw_dir/.issue-publication.lock" ]
  [ ! -e "$reservation_root/ISSUE-G-001" ]
  [ "$(cat "$reservation_root/ISSUE-G-002")" = owner-stale ]
  [ -e "$siw_dir/issues/ISSUE-G-001-existing.md" ]
  [ -e "$siw_dir/issues/ISSUE-G-002-existing.md" ]
}

@test "siw issue reservation fails closed on malformed and redirected marker state" {
  local siw_dir reservation_dir reservation_root
  siw_dir="$TMP_ROOT/siw"
  reservation_root="$siw_dir/.issue-id-reservations"
  reservation_dir="$reservation_root/ISSUE-G-001"
  mkdir -p "$siw_dir/issues" "$reservation_dir" "$TMP_ROOT/external-reservations"
  printf '# Open Issues\n' >"$siw_dir/OPEN_ISSUES_OVERVIEW.md"
  printf '# Log\n' >"$siw_dir/LOG.md"

  run sh "$ISSUE_DEFINE_RESERVATION_HELPER" acquire "$siw_dir" owner-a 1
  [ "$status" -ne 0 ]
  [[ "$output" == *'ownership claim is not a regular file'* ]]
  run sh "$ISSUE_DEFINE_RESERVATION_HELPER" release-publication "$siw_dir" owner-a
  [ "$status" -ne 0 ]
  [[ "$output" == *'ownership claim is not a regular file'* ]]
  [ -f "$siw_dir/.issue-publication.lock" ]

  rmdir "$reservation_dir"
  : >"$reservation_root/ISSUE-G-999"
  run sh "$ISSUE_DEFINE_RESERVATION_HELPER" release-publication "$siw_dir" owner-a
  [ "$status" -ne 0 ]
  [[ "$output" == *'ownership claim has an empty token'* ]]
  [ -f "$siw_dir/.issue-publication.lock" ]

  unlink "$reservation_root/ISSUE-G-999"
  ln -s "$TMP_ROOT/missing-reservation" "$reservation_root/ISSUE-G-998"
  run sh "$ISSUE_DEFINE_RESERVATION_HELPER" release-publication "$siw_dir" owner-a
  [ "$status" -ne 0 ]
  [[ "$output" == *'ownership claim must not be a symlink'* ]]
  [ -f "$siw_dir/.issue-publication.lock" ]

  unlink "$reservation_root/ISSUE-G-998"
  rmdir "$reservation_root"
  ln -s "$TMP_ROOT/external-reservations" "$reservation_root"
  run sh "$ISSUE_DEFINE_RESERVATION_HELPER" reserve "$siw_dir" G owner-a 1
  [ "$status" -ne 0 ]
  [[ "$output" == *'reservation root must not be a symlink'* ]]
  [ -z "$(find "$TMP_ROOT/external-reservations" -mindepth 1 -print -quit)" ]
}

@test "siw issue reservation fails closed when allocation cannot enumerate reservations" {
  local reservation_root siw_dir
  siw_dir="$TMP_ROOT/siw"
  reservation_root="$siw_dir/.issue-id-reservations"
  mkdir -p "$siw_dir/issues" "$reservation_root"
  printf '# Open Issues\n' >"$siw_dir/OPEN_ISSUES_OVERVIEW.md"
  printf '# Log\n' >"$siw_dir/LOG.md"
  printf 'owner-a\nsame-key\n' >"$reservation_root/ISSUE-G-010"

  sh "$ISSUE_DEFINE_RESERVATION_HELPER" acquire "$siw_dir" owner-a 1
  chmod 300 "$reservation_root"
  run sh "$ISSUE_DEFINE_RESERVATION_HELPER" reserve "$siw_dir" G owner-a 1 same-key
  chmod 700 "$reservation_root"

  [ "$status" -ne 0 ]
  [[ "$output" == *'could not enumerate directory'* ]]
  [ ! -e "$reservation_root/ISSUE-G-001" ]
  [ "$(cat "$reservation_root/ISSUE-G-010")" = $'owner-a\nsame-key' ]

  sh "$ISSUE_DEFINE_RESERVATION_HELPER" abandon "$siw_dir" G-010 owner-a
  sh "$ISSUE_DEFINE_RESERVATION_HELPER" release-publication "$siw_dir" owner-a
}

@test "siw issue reservation rejects non-regular and duplicate issue paths" {
  local first_issue_path issue_id issue_link reservation_claim second_issue_path siw_dir
  siw_dir="$TMP_ROOT/siw"
  mkdir -p "$siw_dir/issues"
  printf '# Open Issues\n' >"$siw_dir/OPEN_ISSUES_OVERVIEW.md"
  printf '# Log\n' >"$siw_dir/LOG.md"
  issue_link="$siw_dir/issues/ISSUE-G-001-dangling.md"
  ln -s "$TMP_ROOT/missing-issue" "$issue_link"

  run sh "$ISSUE_DEFINE_RESERVATION_HELPER" acquire "$siw_dir" owner-a 1
  [ "$status" -ne 0 ]
  [[ "$output" == *'issue path is not a regular file'* ]]
  [ ! -e "$siw_dir/.issue-publication.lock" ]

  unlink "$issue_link"
  sh "$ISSUE_DEFINE_RESERVATION_HELPER" acquire "$siw_dir" owner-a 1
  issue_id="$(sh "$ISSUE_DEFINE_RESERVATION_HELPER" reserve-exact "$siw_dir" G-001 owner-a)"
  reservation_claim="$siw_dir/.issue-id-reservations/ISSUE-$issue_id"
  ln -s "$TMP_ROOT/missing-issue" "$issue_link"
  run sh "$ISSUE_DEFINE_RESERVATION_HELPER" reserve "$siw_dir" G owner-a 1 issue-create
  [ "$status" -ne 0 ]
  [[ "$output" == *'issue path is not a regular file'* ]]
  [ ! -e "$siw_dir/.issue-id-reservations/ISSUE-G-002" ]

  run sh "$ISSUE_DEFINE_RESERVATION_HELPER" abandon "$siw_dir" "$issue_id" owner-a
  [ "$status" -ne 0 ]
  [[ "$output" == *'issue path is not a regular file'* ]]
  [ -f "$reservation_claim" ]

  unlink "$issue_link"
  first_issue_path="$siw_dir/issues/ISSUE-G-001-first.md"
  second_issue_path="$siw_dir/issues/ISSUE-G-001-second.md"
  printf '# ISSUE-G-001: first\n' >"$first_issue_path"
  printf '# ISSUE-G-001: second\n' >"$second_issue_path"
  run sh "$ISSUE_DEFINE_RESERVATION_HELPER" reserve "$siw_dir" G owner-a 1 duplicate-check
  [ "$status" -ne 0 ]
  [[ "$output" == *'multiple issue files exist for G-001'* ]]
  [ ! -e "$siw_dir/.issue-id-reservations/ISSUE-G-002" ]
  run sh "$ISSUE_DEFINE_RESERVATION_HELPER" release "$siw_dir" "$issue_id" owner-a
  [ "$status" -ne 0 ]
  [[ "$output" == *'multiple issue files exist for G-001'* ]]
  [ -f "$reservation_claim" ]

  unlink "$first_issue_path"
  unlink "$second_issue_path"
  sh "$ISSUE_DEFINE_RESERVATION_HELPER" abandon "$siw_dir" "$issue_id" owner-a
  sh "$ISSUE_DEFINE_RESERVATION_HELPER" release-publication "$siw_dir" owner-a
}

@test "siw issue reservation fails closed when state directories cannot be enumerated" {
  local issue_id reservation_root siw_dir
  siw_dir="$TMP_ROOT/reservation-permissions/siw"
  reservation_root="$siw_dir/.issue-id-reservations"
  mkdir -p "$siw_dir/issues"
  printf '# Open Issues\n' >"$siw_dir/OPEN_ISSUES_OVERVIEW.md"
  printf '# Log\n' >"$siw_dir/LOG.md"

  sh "$ISSUE_DEFINE_RESERVATION_HELPER" acquire "$siw_dir" owner-a 1
  issue_id="$(sh "$ISSUE_DEFINE_RESERVATION_HELPER" reserve "$siw_dir" G owner-a 1)"
  chmod 400 "$reservation_root"
  run sh "$ISSUE_DEFINE_RESERVATION_HELPER" release-publication "$siw_dir" owner-a
  chmod 700 "$reservation_root"
  [ "$status" -ne 0 ]
  [[ "$output" == *'could not enumerate directory'* ]]
  [ -f "$siw_dir/.issue-publication.lock" ]
  [ -f "$reservation_root/ISSUE-$issue_id" ]
  sh "$ISSUE_DEFINE_RESERVATION_HELPER" abandon "$siw_dir" "$issue_id" owner-a
  sh "$ISSUE_DEFINE_RESERVATION_HELPER" release-publication "$siw_dir" owner-a

  siw_dir="$TMP_ROOT/issue-permissions/siw"
  reservation_root="$siw_dir/.issue-id-reservations"
  mkdir -p "$siw_dir/issues"
  printf '# Open Issues\n' >"$siw_dir/OPEN_ISSUES_OVERVIEW.md"
  printf '# Log\n' >"$siw_dir/LOG.md"
  printf '# ISSUE-G-001: existing\n' >"$siw_dir/issues/ISSUE-G-001-existing.md"

  sh "$GENERATE_PHASES_RESERVATION_HELPER" acquire "$siw_dir" owner-b 1
  chmod 300 "$siw_dir/issues"
  run sh "$GENERATE_PHASES_RESERVATION_HELPER" reserve "$siw_dir" G owner-b 1
  chmod 700 "$siw_dir/issues"
  [ "$status" -ne 0 ]
  [[ "$output" == *'could not enumerate directory'* ]]
  set -- "$reservation_root"/ISSUE-*
  [ ! -e "$1" ]
  sh "$GENERATE_PHASES_RESERVATION_HELPER" release-publication "$siw_dir" owner-b
}

@test "siw issue reservation removes complete ownership claims atomically" {
  local siw_dir issue_id reservation_claim
  siw_dir="$TMP_ROOT/siw"
  mkdir -p "$siw_dir/issues"
  printf '# Open Issues\n' >"$siw_dir/OPEN_ISSUES_OVERVIEW.md"
  printf '# Log\n' >"$siw_dir/LOG.md"

  sh "$ISSUE_DEFINE_RESERVATION_HELPER" acquire "$siw_dir" owner-a 1
  issue_id="$(sh "$ISSUE_DEFINE_RESERVATION_HELPER" reserve "$siw_dir" G owner-a 1)"
  reservation_claim="$siw_dir/.issue-id-reservations/ISSUE-$issue_id"
  [ -f "$reservation_claim" ]
  [ "$(cat "$reservation_claim")" = owner-a ]
  printf '# ISSUE-%s: test\n' "$issue_id" >"$siw_dir/issues/ISSUE-$issue_id-test.md"
  printf '| %s | test | READY |\n' "$issue_id" >>"$siw_dir/OPEN_ISSUES_OVERVIEW.md"
  printf -- '- Created %s: test\n' "$issue_id" >>"$siw_dir/LOG.md"
  sh "$ISSUE_DEFINE_RESERVATION_HELPER" publish-receipt "$siw_dir" owner-a "$issue_id"
  sh "$ISSUE_DEFINE_RESERVATION_HELPER" verify-receipt "$siw_dir" owner-a "$issue_id"

  sh "$ISSUE_DEFINE_RESERVATION_HELPER" release "$siw_dir" "$issue_id" owner-a
  [ ! -e "$reservation_claim" ]
  sh "$ISSUE_DEFINE_RESERVATION_HELPER" release-publication "$siw_dir" owner-a
  [ ! -e "$siw_dir/.issue-publication.lock" ]
}

@test "siw publication receipt preserves ownership across every crash point and retries idempotently" {
  local first_receipt_copy issue_id receipt_file reservation_claim siw_dir
  siw_dir="$TMP_ROOT/siw"
  receipt_file="$siw_dir/.issue-publication.receipt"
  first_receipt_copy="$TMP_ROOT/first-publication-receipt"
  mkdir -p "$siw_dir/issues"
  printf '# Open Issues\n' >"$siw_dir/OPEN_ISSUES_OVERVIEW.md"
  printf '# Log\n' >"$siw_dir/LOG.md"

  sh "$ISSUE_DEFINE_RESERVATION_HELPER" acquire "$siw_dir" owner-a 1
  issue_id="$(sh "$ISSUE_DEFINE_RESERVATION_HELPER" reserve "$siw_dir" G owner-a 1 receipt-crash)"
  reservation_claim="$siw_dir/.issue-id-reservations/ISSUE-$issue_id"

  printf '# ISSUE-%s: receipt crash\n' "$issue_id" >"$siw_dir/issues/ISSUE-$issue_id-receipt-crash.md"
  run sh "$ISSUE_DEFINE_RESERVATION_HELPER" publish-receipt "$siw_dir" owner-a "$issue_id"
  [ "$status" -ne 0 ]
  [[ "$output" == *"overview does not reference $issue_id"* ]]
  run sh "$ISSUE_DEFINE_RESERVATION_HELPER" release "$siw_dir" "$issue_id" owner-a
  [ "$status" -ne 0 ]
  [ -f "$reservation_claim" ]
  [ -f "$siw_dir/.issue-publication.lock" ]

  printf '| %s | receipt crash | READY |\n' "$issue_id" >>"$siw_dir/OPEN_ISSUES_OVERVIEW.md"
  run sh "$ISSUE_DEFINE_RESERVATION_HELPER" publish-receipt "$siw_dir" owner-a "$issue_id"
  [ "$status" -ne 0 ]
  [[ "$output" == *"log does not reference $issue_id"* ]]
  run sh "$ISSUE_DEFINE_RESERVATION_HELPER" release "$siw_dir" "$issue_id" owner-a
  [ "$status" -ne 0 ]
  [ -f "$reservation_claim" ]
  [ -f "$siw_dir/.issue-publication.lock" ]

  printf -- '- Created %s: receipt crash\n' "$issue_id" >>"$siw_dir/LOG.md"
  run sh "$ISSUE_DEFINE_RESERVATION_HELPER" release "$siw_dir" "$issue_id" owner-a
  [ "$status" -ne 0 ]
  [[ "$output" == *'publication receipt is required'* ]]
  [ -f "$reservation_claim" ]
  [ -f "$siw_dir/.issue-publication.lock" ]

  sh "$ISSUE_DEFINE_RESERVATION_HELPER" publish-receipt "$siw_dir" owner-a "$issue_id"
  [ -f "$receipt_file" ]
  [ -f "$reservation_claim" ]
  [ -f "$siw_dir/.issue-publication.lock" ]
  cp "$receipt_file" "$first_receipt_copy"

  sh "$ISSUE_DEFINE_RESERVATION_HELPER" acquire "$siw_dir" owner-a 1
  cmp -s "$receipt_file" "$first_receipt_copy"
  sh "$GENERATE_PHASES_RESERVATION_HELPER" publish-receipt "$siw_dir" owner-a "$issue_id"
  cmp -s "$receipt_file" "$first_receipt_copy"
  sh "$GENERATE_PHASES_RESERVATION_HELPER" verify-receipt "$siw_dir" owner-a "$issue_id"
  sh "$GENERATE_PHASES_RESERVATION_HELPER" release "$siw_dir" "$issue_id" owner-a
  sh "$GENERATE_PHASES_RESERVATION_HELPER" release "$siw_dir" "$issue_id" owner-a
  unlink "$siw_dir/.issue-publication.lock"
  run sh "$GENERATE_PHASES_RESERVATION_HELPER" release-publication "$siw_dir" owner-b
  [ "$status" -ne 0 ]
  [[ "$output" == *'publication receipt belongs to a different owner'* ]]
  [ -f "$receipt_file" ]
  sh "$GENERATE_PHASES_RESERVATION_HELPER" release-publication "$siw_dir" owner-a
  sh "$GENERATE_PHASES_RESERVATION_HELPER" release-publication "$siw_dir" owner-a

  cp "$first_receipt_copy" "$receipt_file"
  sh "$ISSUE_DEFINE_RESERVATION_HELPER" acquire "$siw_dir" owner-b 1
  [ ! -e "$receipt_file" ]
  cp "$first_receipt_copy" "$receipt_file"
  sh "$GENERATE_PHASES_RESERVATION_HELPER" acquire "$siw_dir" owner-b 1
  [ ! -e "$receipt_file" ]
  sh "$GENERATE_PHASES_RESERVATION_HELPER" release-publication "$siw_dir" owner-b
  sh "$GENERATE_PHASES_RESERVATION_HELPER" release-publication "$siw_dir" owner-b

  [ ! -e "$receipt_file" ]
  [ ! -e "$reservation_claim" ]
  [ ! -e "$siw_dir/.issue-publication.lock" ]
}

@test "siw legacy publication locks remain receipt-gated and support explicit zero-ID recovery" {
  local issue_path siw_dir
  siw_dir="$TMP_ROOT/siw"
  mkdir -p "$siw_dir/issues"
  issue_path="$siw_dir/issues/ISSUE-G-001-legacy.md"
  printf '# ISSUE-G-001: original\n' >"$issue_path"
  printf '# Open Issues\n| G-001 | original | READY |\n' >"$siw_dir/OPEN_ISSUES_OVERVIEW.md"
  printf '# Log\n- Created G-001: original\n' >"$siw_dir/LOG.md"
  printf 'owner-a\n' >"$siw_dir/.issue-publication.lock"
  printf '# ISSUE-G-001: partial legacy edit\n' >"$issue_path"

  sh "$ISSUE_DEFINE_RESERVATION_HELPER" acquire "$siw_dir" owner-a 1
  [ "$(sed -n '1p' "$siw_dir/.issue-publication.lock")" = owner-a ]
  [ -z "$(sed -n '2p' "$siw_dir/.issue-publication.lock")" ]

  run sh "$GENERATE_PHASES_RESERVATION_HELPER" release-publication "$siw_dir" owner-a
  [ "$status" -ne 0 ]
  [[ "$output" == *'publication receipt is required before ownership can be released'* ]]
  [ -f "$siw_dir/.issue-publication.lock" ]

  printf '# ISSUE-G-001: original\n' >"$issue_path"
  run sh "$GENERATE_PHASES_RESERVATION_HELPER" release-publication "$siw_dir" owner-a
  [ "$status" -ne 0 ]
  [[ "$output" == *'publication receipt is required before ownership can be released'* ]]

  sh "$ISSUE_DEFINE_RESERVATION_HELPER" publish-receipt "$siw_dir" owner-a
  sh "$GENERATE_PHASES_RESERVATION_HELPER" verify-receipt "$siw_dir" owner-a
  sh "$GENERATE_PHASES_RESERVATION_HELPER" release-publication "$siw_dir" owner-a
  [ ! -e "$siw_dir/.issue-publication.lock" ]
  [ ! -e "$siw_dir/.issue-publication.receipt" ]

  sh "$ISSUE_DEFINE_RESERVATION_HELPER" acquire "$siw_dir" owner-b 1
  run sh "$GENERATE_PHASES_RESERVATION_HELPER" publish-receipt "$siw_dir" owner-b
  [ "$status" -ne 0 ]
  [[ "$output" == *'publish-receipt requires at least one issue ID for non-legacy publication'* ]]
  sh "$GENERATE_PHASES_RESERVATION_HELPER" release-publication "$siw_dir" owner-b
}

@test "siw batch release validates every reservation before removing claims" {
  local first_claim issue_id issue_ids second_claim siw_dir third_claim
  siw_dir="$TMP_ROOT/siw"
  issue_ids="G-001 G-002 G-003"
  first_claim="$siw_dir/.issue-id-reservations/ISSUE-G-001"
  second_claim="$siw_dir/.issue-id-reservations/ISSUE-G-002"
  third_claim="$siw_dir/.issue-id-reservations/ISSUE-G-003"
  mkdir -p "$siw_dir/issues"
  printf '# Open Issues\n' >"$siw_dir/OPEN_ISSUES_OVERVIEW.md"
  printf '# Log\n' >"$siw_dir/LOG.md"

  sh "$ISSUE_DEFINE_RESERVATION_HELPER" acquire "$siw_dir" owner-a 1
  for issue_id in $issue_ids; do
    sh "$ISSUE_DEFINE_RESERVATION_HELPER" reserve-exact "$siw_dir" "$issue_id" owner-a
    printf '# ISSUE-%s: batch\n' "$issue_id" >"$siw_dir/issues/ISSUE-$issue_id-batch.md"
    printf '| %s | batch | READY |\n' "$issue_id" >>"$siw_dir/OPEN_ISSUES_OVERVIEW.md"
    printf -- '- Created %s: batch\n' "$issue_id" >>"$siw_dir/LOG.md"
  done
  sh "$ISSUE_DEFINE_RESERVATION_HELPER" publish-receipt "$siw_dir" owner-a $issue_ids

  printf 'owner-b\nexact-G-002\n' >"$second_claim"
  run sh "$GENERATE_PHASES_RESERVATION_HELPER" release-batch "$siw_dir" owner-a $issue_ids
  [ "$status" -ne 0 ]
  [[ "$output" == *'reservation belongs to a different owner'* ]]
  [ -f "$first_claim" ]
  [ -f "$second_claim" ]
  [ -f "$third_claim" ]

  printf 'owner-a\nexact-G-002\n' >"$second_claim"
  run sh "$GENERATE_PHASES_RESERVATION_HELPER" release-batch "$siw_dir" owner-a G-001 ISSUE-G-001
  [ "$status" -ne 0 ]
  [[ "$output" == *'release contains duplicate issue ID: G-001'* ]]
  [ -f "$first_claim" ]
  [ -f "$second_claim" ]
  [ -f "$third_claim" ]

  sh "$GENERATE_PHASES_RESERVATION_HELPER" release-batch "$siw_dir" owner-a $issue_ids
  [ ! -e "$first_claim" ]
  [ ! -e "$second_claim" ]
  [ ! -e "$third_claim" ]
  sh "$GENERATE_PHASES_RESERVATION_HELPER" release-batch "$siw_dir" owner-a $issue_ids
  sh "$GENERATE_PHASES_RESERVATION_HELPER" release-publication "$siw_dir" owner-a
}

@test "siw publication receipt rejects stale and malformed state without releasing ownership" {
  local issue_id receipt_file reservation_claim siw_dir
  siw_dir="$TMP_ROOT/siw"
  receipt_file="$siw_dir/.issue-publication.receipt"
  mkdir -p "$siw_dir/issues"
  printf '# Open Issues\n' >"$siw_dir/OPEN_ISSUES_OVERVIEW.md"
  printf '# Log\n' >"$siw_dir/LOG.md"

  sh "$ISSUE_DEFINE_RESERVATION_HELPER" acquire "$siw_dir" owner-a 1
  issue_id="$(sh "$ISSUE_DEFINE_RESERVATION_HELPER" reserve "$siw_dir" G owner-a 1 receipt-stale)"
  reservation_claim="$siw_dir/.issue-id-reservations/ISSUE-$issue_id"
  printf '# ISSUE-%s: receipt stale\n' "$issue_id" >"$siw_dir/issues/ISSUE-$issue_id-receipt-stale.md"
  printf '| %s | receipt stale | READY |\n' "$issue_id" >>"$siw_dir/OPEN_ISSUES_OVERVIEW.md"
  printf -- '- Created %s: receipt stale\n' "$issue_id" >>"$siw_dir/LOG.md"
  sh "$ISSUE_DEFINE_RESERVATION_HELPER" publish-receipt "$siw_dir" owner-a "$issue_id"

  printf -- '- Updated %s: later partial edit\n' "$issue_id" >>"$siw_dir/LOG.md"
  run sh "$ISSUE_DEFINE_RESERVATION_HELPER" verify-receipt "$siw_dir" owner-a "$issue_id"
  [ "$status" -ne 0 ]
  [[ "$output" == *'publication receipt does not match the current log'* ]]
  run sh "$ISSUE_DEFINE_RESERVATION_HELPER" release "$siw_dir" "$issue_id" owner-a
  [ "$status" -ne 0 ]
  [ -f "$receipt_file" ]
  [ -f "$reservation_claim" ]
  [ -f "$siw_dir/.issue-publication.lock" ]

  sh "$ISSUE_DEFINE_RESERVATION_HELPER" publish-receipt "$siw_dir" owner-a "$issue_id"
  printf 'malformed\n' >"$receipt_file"
  run sh "$ISSUE_DEFINE_RESERVATION_HELPER" verify-receipt "$siw_dir" owner-a "$issue_id"
  [ "$status" -ne 0 ]
  [[ "$output" == *'publication receipt has an invalid version record'* ]]
  run sh "$ISSUE_DEFINE_RESERVATION_HELPER" release "$siw_dir" "$issue_id" owner-a
  [ "$status" -ne 0 ]
  [ -f "$reservation_claim" ]
  [ -f "$siw_dir/.issue-publication.lock" ]

  sh "$ISSUE_DEFINE_RESERVATION_HELPER" publish-receipt "$siw_dir" owner-a "$issue_id"
  printf 'unterminated' >>"$receipt_file"
  run sh "$ISSUE_DEFINE_RESERVATION_HELPER" verify-receipt "$siw_dir" owner-a "$issue_id"
  [ "$status" -ne 0 ]
  [[ "$output" == *'publication receipt has an invalid issue record'* ]]
  [ -f "$reservation_claim" ]
  [ -f "$siw_dir/.issue-publication.lock" ]

  sh "$ISSUE_DEFINE_RESERVATION_HELPER" publish-receipt "$siw_dir" owner-a "$issue_id"
  sh "$ISSUE_DEFINE_RESERVATION_HELPER" verify-receipt "$siw_dir" owner-a "$issue_id"
  sh "$ISSUE_DEFINE_RESERVATION_HELPER" release "$siw_dir" "$issue_id" owner-a
  sh "$ISSUE_DEFINE_RESERVATION_HELPER" release-publication "$siw_dir" owner-a
}

@test "siw publication receipt gates update-only publication release without a reservation" {
  local issue_id siw_dir
  siw_dir="$TMP_ROOT/siw"
  issue_id=G-001
  mkdir -p "$siw_dir/issues"
  printf '# ISSUE-%s: original\n' "$issue_id" >"$siw_dir/issues/ISSUE-$issue_id-update-only.md"
  printf '# Open Issues\n| %s | original | READY |\n' "$issue_id" >"$siw_dir/OPEN_ISSUES_OVERVIEW.md"
  printf '# Log\n- Created %s: original\n' "$issue_id" >"$siw_dir/LOG.md"

  sh "$ISSUE_DEFINE_RESERVATION_HELPER" acquire "$siw_dir" owner-a 1
  printf '# ISSUE-%s: improved\n' "$issue_id" >"$siw_dir/issues/ISSUE-$issue_id-update-only.md"
  printf '# Open Issues\n| %s | improved | READY |\n' "$issue_id" >"$siw_dir/OPEN_ISSUES_OVERVIEW.md"
  printf '# Log\n- Updated %s: title\n' "$issue_id" >"$siw_dir/LOG.md"

  run sh "$ISSUE_DEFINE_RESERVATION_HELPER" release-publication "$siw_dir" owner-a
  [ "$status" -ne 0 ]
  [[ "$output" == *'publication receipt is required because SIW state changed'* ]]
  [ -f "$siw_dir/.issue-publication.lock" ]

  sh "$ISSUE_DEFINE_RESERVATION_HELPER" publish-receipt "$siw_dir" owner-a "$issue_id"
  sh "$GENERATE_PHASES_RESERVATION_HELPER" verify-receipt "$siw_dir" owner-a "$issue_id"
  sh "$GENERATE_PHASES_RESERVATION_HELPER" release-publication "$siw_dir" owner-a
  [ ! -e "$siw_dir/.issue-publication.lock" ]
  [ ! -e "$siw_dir/.issue-publication.receipt" ]
}

@test "siw legacy zero-ID recovery cannot release owned reservations after partial edits" {
  local reservation_claim siw_dir
  siw_dir="$TMP_ROOT/siw"
  reservation_claim="$siw_dir/.issue-id-reservations/ISSUE-G-001"
  mkdir -p "$siw_dir/issues" "$siw_dir/.issue-id-reservations"
  printf '# Open Issues\nPartial edit mentions G-001\n' >"$siw_dir/OPEN_ISSUES_OVERVIEW.md"
  printf '# Log\n' >"$siw_dir/LOG.md"
  printf 'owner-a\n' >"$siw_dir/.issue-publication.lock"
  printf 'owner-a\nlegacy-request\n' >"$reservation_claim"

  run sh "$ISSUE_DEFINE_RESERVATION_HELPER" publish-receipt "$siw_dir" owner-a
  [ "$status" -ne 0 ]
  [[ "$output" == *'publication receipt omits owned reservation: G-001'* ]]
  run sh "$ISSUE_DEFINE_RESERVATION_HELPER" abandon "$siw_dir" G-001 owner-a
  [ "$status" -ne 0 ]
  [[ "$output" == *'cannot abandon a legacy reservation without a trustworthy publication baseline'* ]]
  run sh "$ISSUE_DEFINE_RESERVATION_HELPER" release-publication "$siw_dir" owner-a
  [ "$status" -ne 0 ]
  [ -f "$reservation_claim" ]
  [ -f "$siw_dir/.issue-publication.lock" ]

  printf '# ISSUE-G-001: recovered\n' >"$siw_dir/issues/ISSUE-G-001-recovered.md"
  printf '# Open Issues\n| G-001 | recovered | READY |\n' >"$siw_dir/OPEN_ISSUES_OVERVIEW.md"
  printf '# Log\n- Created G-001: recovered\n' >"$siw_dir/LOG.md"
  sh "$ISSUE_DEFINE_RESERVATION_HELPER" publish-receipt "$siw_dir" owner-a G-001
  sh "$ISSUE_DEFINE_RESERVATION_HELPER" release "$siw_dir" G-001 owner-a
  sh "$ISSUE_DEFINE_RESERVATION_HELPER" release-publication "$siw_dir" owner-a
}

@test "siw publication receipt requires canonical issue heading overview row and log entry" {
  local issue_id issue_path siw_dir
  siw_dir="$TMP_ROOT/siw"
  mkdir -p "$siw_dir/issues"
  printf '# Open Issues\n' >"$siw_dir/OPEN_ISSUES_OVERVIEW.md"
  printf '# Log\n' >"$siw_dir/LOG.md"
  sh "$ISSUE_DEFINE_RESERVATION_HELPER" acquire "$siw_dir" owner-a 1
  issue_id="$(sh "$ISSUE_DEFINE_RESERVATION_HELPER" reserve "$siw_dir" G owner-a 1 exact-views)"
  issue_path="$siw_dir/issues/ISSUE-$issue_id-exact-views.md"
  printf '# Wrong heading\n\nA later paragraph says # ISSUE-%s: exact views\n' "$issue_id" >"$issue_path"
  printf 'A paragraph mentions %s but is not a tracker row.\n' "$issue_id" >>"$siw_dir/OPEN_ISSUES_OVERVIEW.md"
  printf 'A paragraph mentions %s but is not a publication entry.\n' "$issue_id" >>"$siw_dir/LOG.md"

  run sh "$ISSUE_DEFINE_RESERVATION_HELPER" publish-receipt "$siw_dir" owner-a "$issue_id"
  [ "$status" -ne 0 ]
  [[ "$output" == *"issue file heading does not identify $issue_id"* ]]
  printf '# ISSUE-%s: exact views\n' "$issue_id" >"$issue_path"
  run sh "$ISSUE_DEFINE_RESERVATION_HELPER" publish-receipt "$siw_dir" owner-a "$issue_id"
  [ "$status" -ne 0 ]
  [[ "$output" == *"overview does not reference $issue_id in an issue row"* ]]
  printf '# Open Issues\n| %s | exact views | READY |\n' "$issue_id" >"$siw_dir/OPEN_ISSUES_OVERVIEW.md"
  run sh "$ISSUE_DEFINE_RESERVATION_HELPER" publish-receipt "$siw_dir" owner-a "$issue_id"
  [ "$status" -ne 0 ]
  [[ "$output" == *"log does not reference $issue_id in a publication entry"* ]]

  printf '# Log\n- Created %s: exact views\n' "$issue_id" >"$siw_dir/LOG.md"
  sh "$ISSUE_DEFINE_RESERVATION_HELPER" publish-receipt "$siw_dir" owner-a "$issue_id"
  sh "$ISSUE_DEFINE_RESERVATION_HELPER" release "$siw_dir" "$issue_id" owner-a
  sh "$ISSUE_DEFINE_RESERVATION_HELPER" release-publication "$siw_dir" owner-a
}

@test "siw publication receipt rejects an issue reserved by another owner" {
  local reservation_claim siw_dir
  siw_dir="$TMP_ROOT/siw"
  reservation_claim="$siw_dir/.issue-id-reservations/ISSUE-G-001"
  mkdir -p "$siw_dir/issues" "$siw_dir/.issue-id-reservations"
  printf '# Open Issues\n' >"$siw_dir/OPEN_ISSUES_OVERVIEW.md"
  printf '# Log\n' >"$siw_dir/LOG.md"
  sh "$ISSUE_DEFINE_RESERVATION_HELPER" acquire "$siw_dir" owner-a 1
  printf 'owner-b\nforeign-request\n' >"$reservation_claim"
  printf '# ISSUE-G-001: foreign reservation\n' >"$siw_dir/issues/ISSUE-G-001-foreign-reservation.md"
  printf '| G-001 | foreign reservation | READY |\n' >>"$siw_dir/OPEN_ISSUES_OVERVIEW.md"
  printf -- '- Created G-001: foreign reservation\n' >>"$siw_dir/LOG.md"

  run sh "$ISSUE_DEFINE_RESERVATION_HELPER" publish-receipt "$siw_dir" owner-a G-001
  [ "$status" -ne 0 ]
  [[ "$output" == *'publication receipt issue ID is reserved by a different owner: G-001'* ]]
  [ -f "$reservation_claim" ]
  [ -f "$siw_dir/.issue-publication.lock" ]
}

@test "siw publication receipt lists every issue changed since acquisition" {
  local siw_dir
  siw_dir="$TMP_ROOT/siw"
  mkdir -p "$siw_dir/issues"
  printf '# ISSUE-G-001: original one\n' >"$siw_dir/issues/ISSUE-G-001-one.md"
  printf '# ISSUE-G-002: original two\n' >"$siw_dir/issues/ISSUE-G-002-two.md"
  printf '# Open Issues\n| G-001 | original one | READY |\n| G-002 | original two | READY |\n' >"$siw_dir/OPEN_ISSUES_OVERVIEW.md"
  printf '# Log\n- Created G-001: original one\n- Created G-002: original two\n' >"$siw_dir/LOG.md"
  sh "$ISSUE_DEFINE_RESERVATION_HELPER" acquire "$siw_dir" owner-a 1

  printf '# ISSUE-G-001: changed one\n' >"$siw_dir/issues/ISSUE-G-001-one.md"
  printf '# Open Issues\n| G-001 | changed one | READY |\n| G-002 | original two | READY |\n' >"$siw_dir/OPEN_ISSUES_OVERVIEW.md"
  printf '# Log\n- Created G-001: original one\n- Created G-002: original two\n- Updated G-001: title\n' >"$siw_dir/LOG.md"
  run sh "$ISSUE_DEFINE_RESERVATION_HELPER" publish-receipt "$siw_dir" owner-a G-002
  [ "$status" -ne 0 ]
  [[ "$output" == *'publication receipt omits changed issue ID: G-001'* ]]
  [ ! -e "$siw_dir/.issue-publication.receipt" ]

  sh "$ISSUE_DEFINE_RESERVATION_HELPER" publish-receipt "$siw_dir" owner-a G-001
  sh "$ISSUE_DEFINE_RESERVATION_HELPER" release-publication "$siw_dir" owner-a
}

@test "siw publication receipt requires a new log entry for tracker-visible updates" {
  local issue_path siw_dir
  siw_dir="$TMP_ROOT/siw"
  issue_path="$siw_dir/issues/ISSUE-G-001-fresh-log.md"
  mkdir -p "$siw_dir/issues"
  printf '# ISSUE-G-001: original\n' >"$issue_path"
  printf '# Open Issues\n| G-001 | original | READY |\n' >"$siw_dir/OPEN_ISSUES_OVERVIEW.md"
  printf '# Log\n- Created G-001: original\n' >"$siw_dir/LOG.md"

  sh "$ISSUE_DEFINE_RESERVATION_HELPER" acquire "$siw_dir" owner-a 1
  printf '# ISSUE-G-001: changed\n' >"$issue_path"
  printf '# Open Issues\n| G-001 | changed | READY |\n' >"$siw_dir/OPEN_ISSUES_OVERVIEW.md"

  run sh "$ISSUE_DEFINE_RESERVATION_HELPER" publish-receipt "$siw_dir" owner-a G-001
  [ "$status" -ne 0 ]
  [[ "$output" == *'overview issue row changed without a new log publication entry: G-001'* ]]
  [ ! -e "$siw_dir/.issue-publication.receipt" ]
  [ -f "$siw_dir/.issue-publication.lock" ]

  printf -- '- Updated G-001: title\n' >>"$siw_dir/LOG.md"
  sh "$ISSUE_DEFINE_RESERVATION_HELPER" publish-receipt "$siw_dir" owner-a G-001
  sh "$ISSUE_DEFINE_RESERVATION_HELPER" release-publication "$siw_dir" owner-a

  sh "$ISSUE_DEFINE_RESERVATION_HELPER" acquire "$siw_dir" owner-b 1
  printf '\nBody-only detail changed.\n' >>"$issue_path"
  sh "$ISSUE_DEFINE_RESERVATION_HELPER" publish-receipt "$siw_dir" owner-b G-001
  sh "$ISSUE_DEFINE_RESERVATION_HELPER" release-publication "$siw_dir" owner-b
}

@test "siw publication rejects unrelated overview and log mutations beside canonical updates" {
  local issue_path siw_dir
  siw_dir="$TMP_ROOT/siw"
  issue_path="$siw_dir/issues/ISSUE-G-001-attribution.md"
  mkdir -p "$siw_dir/issues"
  printf '# ISSUE-G-001: original\n' >"$issue_path"
  printf '# Open Issues\nProtected overview text.\n| G-001 | original | READY |\n' >"$siw_dir/OPEN_ISSUES_OVERVIEW.md"
  printf '# Log\nProtected log text.\n- Created G-001: original\n' >"$siw_dir/LOG.md"

  sh "$ISSUE_DEFINE_RESERVATION_HELPER" acquire "$siw_dir" owner-a 1
  printf '# ISSUE-G-001: changed\n' >"$issue_path"
  printf '# Open Issues\nProtected overview text.\n| G-001 | changed | READY |\nUnrelated overview mutation.\n' >"$siw_dir/OPEN_ISSUES_OVERVIEW.md"
  printf '# Log\nProtected log text.\n- Created G-001: original\n- Updated G-001: title\n' >"$siw_dir/LOG.md"

  run sh "$ISSUE_DEFINE_RESERVATION_HELPER" publish-receipt "$siw_dir" owner-a G-001
  [ "$status" -ne 0 ]
  [[ "$output" == *'overview changed without a canonical issue-row change'* ]]
  [ ! -e "$siw_dir/.issue-publication.receipt" ]

  printf '# Open Issues\nProtected overview text.\n| G-001 | changed | READY |\n' >"$siw_dir/OPEN_ISSUES_OVERVIEW.md"
  printf '# Log\nProtected log text.\n- Created G-001: original\n- Updated G-001: title\nUnrelated log mutation.\n' >"$siw_dir/LOG.md"
  run sh "$ISSUE_DEFINE_RESERVATION_HELPER" publish-receipt "$siw_dir" owner-a G-001
  [ "$status" -ne 0 ]
  [[ "$output" == *'log changed without a recognized publication entry'* ]]
  [ ! -e "$siw_dir/.issue-publication.receipt" ]

  printf '# Log\nProtected log text.\n- Created G-001: original\n- Updated G-001: title\n' >"$siw_dir/LOG.md"
  sh "$ISSUE_DEFINE_RESERVATION_HELPER" publish-receipt "$siw_dir" owner-a G-001
  sh "$ISSUE_DEFINE_RESERVATION_HELPER" release-publication "$siw_dir" owner-a
}

@test "siw publication permits canonical tracker scaffolding for a new phase" {
  local siw_dir
  siw_dir="$TMP_ROOT/siw"
  mkdir -p "$siw_dir/issues"
  printf '# Open Issues Overview\n\n## General\n\n**Parallelization:** Safe to parallelize\n\n| # | Title | Status | Size | Priority | Mode | Related |\n| --- | --- | --- | --- | --- | --- | --- |\n| _None_ | No issues | | | | | |\n' >"$siw_dir/OPEN_ISSUES_OVERVIEW.md"
  printf '# Log\n' >"$siw_dir/LOG.md"

  sh "$GENERATE_PHASES_RESERVATION_HELPER" acquire "$siw_dir" owner-a 1
  sh "$GENERATE_PHASES_RESERVATION_HELPER" reserve-exact "$siw_dir" P1-001 owner-a
  printf '# ISSUE-P1-001: first phase issue\n' >"$siw_dir/issues/ISSUE-P1-001-first.md"
  printf '\n## Phase 1: First goal\n\n**Parallelization:** Must be sequential\n\n| # | Title | Status | Size | Priority | Mode | Related |\n| --- | --- | --- | --- | --- | --- | --- |\n| P1-001 | first phase issue | READY | S | High | AUTO | |\n' >>"$siw_dir/OPEN_ISSUES_OVERVIEW.md"
  printf '\n## Current Progress\n\n- Created P1-001: first phase issue\n' >>"$siw_dir/LOG.md"

  sh "$GENERATE_PHASES_RESERVATION_HELPER" publish-receipt "$siw_dir" owner-a P1-001
  sh "$GENERATE_PHASES_RESERVATION_HELPER" release "$siw_dir" P1-001 owner-a
  sh "$GENERATE_PHASES_RESERVATION_HELPER" release-publication "$siw_dir" owner-a
}

@test "siw replacement receipts cover canonical IDs removed from every current view" {
  local siw_dir
  siw_dir="$TMP_ROOT/siw"
  mkdir -p "$siw_dir/issues"
  printf '# ISSUE-G-001: old one\n' >"$siw_dir/issues/ISSUE-G-001-old-one.md"
  printf '# ISSUE-G-002: old two\n' >"$siw_dir/issues/ISSUE-G-002-old-two.md"
  printf '# Open Issues\n| G-001 | old one | READY |\n| G-002 | old two | READY |\n' >"$siw_dir/OPEN_ISSUES_OVERVIEW.md"
  printf '# Log\n- Created G-001: old one\n- Created G-002: old two\n' >"$siw_dir/LOG.md"

  sh "$GENERATE_PHASES_RESERVATION_HELPER" acquire "$siw_dir" owner-a 1
  sh "$GENERATE_PHASES_RESERVATION_HELPER" reserve-exact "$siw_dir" P1-001 owner-a
  unlink "$siw_dir/issues/ISSUE-G-001-old-one.md"
  unlink "$siw_dir/issues/ISSUE-G-002-old-two.md"
  printf '# ISSUE-P1-001: replacement\n' >"$siw_dir/issues/ISSUE-P1-001-replacement.md"
  printf '# Open Issues\n| P1-001 | replacement | READY |\n' >"$siw_dir/OPEN_ISSUES_OVERVIEW.md"
  printf '# Log\n- Created P1-001: replacement\n' >"$siw_dir/LOG.md"

  run sh "$GENERATE_PHASES_RESERVATION_HELPER" publish-receipt "$siw_dir" owner-a P1-001
  [ "$status" -ne 0 ]
  [[ "$output" == *'publication receipt omits changed issue ID:'* ]]
  [ ! -e "$siw_dir/.issue-publication.receipt" ]

  sh "$GENERATE_PHASES_RESERVATION_HELPER" publish-receipt "$siw_dir" owner-a P1-001 G-001 G-002
  sh "$GENERATE_PHASES_RESERVATION_HELPER" release-batch "$siw_dir" owner-a P1-001
  sh "$GENERATE_PHASES_RESERVATION_HELPER" release-publication "$siw_dir" owner-a
  [ ! -e "$siw_dir/.issue-publication.lock" ]
  [ ! -e "$siw_dir/.issue-publication.receipt" ]
  [ ! -e "$siw_dir/.issue-publication.baseline" ]
}

@test "siw publication attributes only a General parallelization summary update to its changed issue" {
  local issue_path siw_dir
  siw_dir="$TMP_ROOT/siw"
  issue_path="$siw_dir/issues/ISSUE-G-001-parallelization.md"
  mkdir -p "$siw_dir/issues"
  printf '# ISSUE-G-001: parallelization\n\n**Parallelization:** Safe to parallelize\n' >"$issue_path"
  printf '# Open Issues\n\n## General\n\n**Parallelization:** Safe to parallelize\n\n| G-001 | parallelization | READY |\n' >"$siw_dir/OPEN_ISSUES_OVERVIEW.md"
  printf '# Log\n\n## Current Progress\n\n- Created G-001: parallelization\n' >"$siw_dir/LOG.md"

  sh "$ISSUE_DEFINE_RESERVATION_HELPER" acquire "$siw_dir" owner-a 1
  printf '# ISSUE-G-001: parallelization\n\n**Parallelization:** Must be sequential\n' >"$issue_path"
  printf '# Open Issues\n\n## General\n\n**Parallelization:** Must be sequential\n\n| G-001 | parallelization | READY |\n' >"$siw_dir/OPEN_ISSUES_OVERVIEW.md"
  printf '# Log\n\n## Current Progress\n\n- Created G-001: parallelization\n- Updated G-001: parallelization\n' >"$siw_dir/LOG.md"
  sh "$ISSUE_DEFINE_RESERVATION_HELPER" publish-receipt "$siw_dir" owner-a G-001
  sh "$ISSUE_DEFINE_RESERVATION_HELPER" release-publication "$siw_dir" owner-a

  sh "$ISSUE_DEFINE_RESERVATION_HELPER" acquire "$siw_dir" owner-b 1
  printf '\nUnrelated overview edit.\n' >>"$siw_dir/OPEN_ISSUES_OVERVIEW.md"
  run sh "$ISSUE_DEFINE_RESERVATION_HELPER" publish-receipt "$siw_dir" owner-b G-001
  [ "$status" -ne 0 ]
  [[ "$output" == *'overview changed without a canonical issue-row change'* ]]
  [ ! -e "$siw_dir/.issue-publication.receipt" ]
  [ -f "$siw_dir/.issue-publication.lock" ]
}

@test "siw 200-issue publication batches digest processes" {
  local hash_backend hash_backend_path hash_log issue_id issue_ids issue_number mock_bin siw_dir
  siw_dir="$TMP_ROOT/siw"
  hash_log="$TMP_ROOT/hash-calls"
  mock_bin="$TMP_ROOT/hash-bin"
  mkdir -p "$siw_dir/issues" "$mock_bin"
  printf '# Open Issues\n' >"$siw_dir/OPEN_ISSUES_OVERVIEW.md"
  printf '# Log\n' >"$siw_dir/LOG.md"
  if command -v sha256sum >/dev/null 2>&1; then
    hash_backend=sha256sum
  elif command -v shasum >/dev/null 2>&1; then
    hash_backend=shasum
  else
    hash_backend=openssl
  fi
  hash_backend_path="$(command -v "$hash_backend")"
  write_file "$mock_bin/$hash_backend" <<EOF
#!/bin/sh
printf 'called\n' >>"$hash_log"
exec "$hash_backend_path" "\$@"
EOF
  chmod +x "$mock_bin/$hash_backend"

  env PATH="$mock_bin:$PATH" sh "$GENERATE_PHASES_RESERVATION_HELPER" acquire "$siw_dir" owner-a 1
  set --
  for issue_number in $(seq 1 200); do
    set -- "$@" "draft-$issue_number"
  done
  run sh "$GENERATE_PHASES_RESERVATION_HELPER" reserve-batch "$siw_dir" G owner-a 300 "$@"
  [ "$status" -eq 0 ]
  issue_ids="$(printf '%s\n' "$output" | awk '{ print $2 }')"
  for issue_id in $issue_ids; do
    printf '# ISSUE-%s: generated\n' "$issue_id" >"$siw_dir/issues/ISSUE-$issue_id-generated.md"
    printf '| %s | generated | READY |\n' "$issue_id" >>"$siw_dir/OPEN_ISSUES_OVERVIEW.md"
    printf -- '- Created %s: generated\n' "$issue_id" >>"$siw_dir/LOG.md"
  done

  env PATH="$mock_bin:$PATH" sh "$GENERATE_PHASES_RESERVATION_HELPER" publish-receipt "$siw_dir" owner-a $issue_ids
  env PATH="$mock_bin:$PATH" sh "$GENERATE_PHASES_RESERVATION_HELPER" release-batch "$siw_dir" owner-a $issue_ids
  env PATH="$mock_bin:$PATH" sh "$GENERATE_PHASES_RESERVATION_HELPER" release-publication "$siw_dir" owner-a

  [ "$(wc -l <"$hash_log" | tr -d ' ')" -le 16 ]
  [ ! -e "$siw_dir/.issue-publication.lock" ]
  [ ! -e "$siw_dir/.issue-publication.baseline" ]
}

@test "siw issue reservation rejects malformed claims before allocation" {
  local siw_dir reservation_root
  siw_dir="$TMP_ROOT/siw"
  reservation_root="$siw_dir/.issue-id-reservations"
  mkdir -p "$siw_dir/issues"
  printf '# Open Issues\n' >"$siw_dir/OPEN_ISSUES_OVERVIEW.md"

  : >"$siw_dir/.issue-publication.lock"
  run env SIW_RESERVATION_RETRY_DELAY=0 sh "$ISSUE_DEFINE_RESERVATION_HELPER" acquire "$siw_dir" owner-a 1
  [ "$status" -ne 0 ]
  [[ "$output" == *'ownership claim has an empty token'* ]]
  [[ "$output" != *'owned by another writer'* ]]

  printf 'owner-a\n' >"$siw_dir/.issue-publication.lock"
  mkdir -p "$reservation_root/ISSUE-G-999"
  run sh "$ISSUE_DEFINE_RESERVATION_HELPER" reserve "$siw_dir" G owner-a 1 malformed-check
  [ "$status" -ne 0 ]
  [[ "$output" == *'ownership claim is not a regular file'* ]]
  set -- "$reservation_root"/ISSUE-G-*
  [ "$#" -eq 1 ]
  [ "$1" = "$reservation_root/ISSUE-G-999" ]
}

@test "siw issue reservation neutralizes CDPATH and normalizes exact IDs" {
  local alternate_root siw_dir work_dir
  work_dir="$TMP_ROOT/work"
  siw_dir="$work_dir/siw"
  alternate_root="$TMP_ROOT/alternate"
  mkdir -p "$siw_dir/issues" "$alternate_root/siw/issues"
  printf '# Local Open Issues\n' >"$siw_dir/OPEN_ISSUES_OVERVIEW.md"
  printf '# Alternate Open Issues\n' >"$alternate_root/siw/OPEN_ISSUES_OVERVIEW.md"
  printf '# Log\n' >"$siw_dir/LOG.md"

  run env CDPATH="$alternate_root" sh -c 'cd "$1" && sh "$2" acquire siw owner-a 1' sh "$work_dir" "$ISSUE_DEFINE_RESERVATION_HELPER"
  [ "$status" -eq 0 ]
  [ -f "$siw_dir/.issue-publication.lock" ]
  [ ! -e "$alternate_root/siw/.issue-publication.lock" ]

  run sh "$ISSUE_DEFINE_RESERVATION_HELPER" reserve-exact "$siw_dir" ISSUE-G-001 owner-a
  [ "$status" -eq 0 ]
  [ "$output" = G-001 ]
  run sh "$ISSUE_DEFINE_RESERVATION_HELPER" reserve-exact "$siw_dir" G-001 owner-a
  [ "$status" -eq 0 ]
  [ "$output" = G-001 ]

  printf '# ISSUE-G-001: test\n' >"$siw_dir/issues/ISSUE-G-001-test.md"
  printf '| G-001 | test | READY |\n' >>"$siw_dir/OPEN_ISSUES_OVERVIEW.md"
  printf -- '- Created G-001: test\n' >>"$siw_dir/LOG.md"
  sh "$ISSUE_DEFINE_RESERVATION_HELPER" publish-receipt "$siw_dir" owner-a G-001
  sh "$ISSUE_DEFINE_RESERVATION_HELPER" release "$siw_dir" ISSUE-G-001 owner-a
  sh "$ISSUE_DEFINE_RESERVATION_HELPER" release "$siw_dir" G-001 owner-a
  sh "$ISSUE_DEFINE_RESERVATION_HELPER" release-publication "$siw_dir" owner-a
  sh "$ISSUE_DEFINE_RESERVATION_HELPER" release-publication "$siw_dir" owner-a
}

@test "siw issue reservation request keys recover single and batch results" {
  local first_id retry_id siw_dir
  siw_dir="$TMP_ROOT/siw"
  mkdir -p "$siw_dir/issues"
  printf '# Open Issues\n' >"$siw_dir/OPEN_ISSUES_OVERVIEW.md"

  sh "$ISSUE_DEFINE_RESERVATION_HELPER" acquire "$siw_dir" owner-a 1
  first_id="$(sh "$ISSUE_DEFINE_RESERVATION_HELPER" reserve "$siw_dir" G owner-a 5 issue-create)"
  retry_id="$(sh "$ISSUE_DEFINE_RESERVATION_HELPER" reserve "$siw_dir" G owner-a 5 issue-create)"
  [ "$first_id" = G-001 ]
  [ "$retry_id" = "$first_id" ]

  run sh "$GENERATE_PHASES_RESERVATION_HELPER" reserve-batch "$siw_dir" P1 owner-a 5 draft-P1-001 draft-P1-002
  [ "$status" -eq 0 ]
  [ "$output" = $'draft-P1-001 P1-001\ndraft-P1-002 P1-002' ]
  run sh "$GENERATE_PHASES_RESERVATION_HELPER" reserve-batch "$siw_dir" P1 owner-a 5 draft-P1-001 draft-P1-002
  [ "$status" -eq 0 ]
  [ "$output" = $'draft-P1-001 P1-001\ndraft-P1-002 P1-002' ]

  [ "$(find "$siw_dir/.issue-id-reservations" -name 'ISSUE-*' -type f | wc -l | tr -d ' ')" -eq 3 ]
  ! grep -q 'sed ' "$ISSUE_DEFINE_RESERVATION_HELPER"
  sh "$ISSUE_DEFINE_RESERVATION_HELPER" abandon "$siw_dir" G-001 owner-a
  sh "$ISSUE_DEFINE_RESERVATION_HELPER" abandon "$siw_dir" P1-001 owner-a
  sh "$ISSUE_DEFINE_RESERVATION_HELPER" abandon "$siw_dir" P1-002 owner-a
  sh "$ISSUE_DEFINE_RESERVATION_HELPER" release-publication "$siw_dir" owner-a
}

@test "siw issue reservation ignores stale noncanonical temporary claims" {
  local siw_dir
  siw_dir="$TMP_ROOT/siw"
  mkdir -p "$siw_dir/issues"
  printf '# Open Issues\n' >"$siw_dir/OPEN_ISSUES_OVERVIEW.md"
  printf 'interrupted-owner\n' >"$siw_dir/.siw-owner-claim.12345"

  sh "$ISSUE_DEFINE_RESERVATION_HELPER" acquire "$siw_dir" owner-a 1
  [ "$(sed -n '1p' "$siw_dir/.issue-publication.lock")" = owner-a ]
  [ -f "$siw_dir/.siw-owner-claim.12345" ]
  sh "$ISSUE_DEFINE_RESERVATION_HELPER" acquire "$siw_dir" owner-a 1
  sh "$ISSUE_DEFINE_RESERVATION_HELPER" release-publication "$siw_dir" owner-a
}

@test "siw issue reservation cleans catchable interruptions and recovers post-link kills" {
  local helper_pid siw_dir stale_temp
  siw_dir="$TMP_ROOT/siw"
  mkdir -p "$siw_dir/issues" "$TMP_ROOT/term-bin" "$TMP_ROOT/kill-bin"
  printf '# Open Issues\n' >"$siw_dir/OPEN_ISSUES_OVERVIEW.md"

  cat >"$TMP_ROOT/term-bin/ln" <<'EOF'
#!/bin/sh
operation_token=$(sed -n '2p' "$1")
case "$operation_token" in
  operation:[0-9]*:*) helper_pid=${operation_token#operation:} ;;
  *) exit 1 ;;
esac
helper_pid=${helper_pid%%:*}
case "$helper_pid" in
  '' | *[!0-9]*) exit 1 ;;
esac
kill -TERM "$helper_pid"
exit 1
EOF
  chmod +x "$TMP_ROOT/term-bin/ln"
  run env PATH="$TMP_ROOT/term-bin:$PATH" sh "$ISSUE_DEFINE_RESERVATION_HELPER" acquire "$siw_dir" owner-a 1
  [ "$status" -ne 0 ]
  set -- "$siw_dir"/.siw-owner-claim.*
  [ ! -e "$1" ]
  [ ! -e "$siw_dir/.issue-publication.lock" ]

  cat >"$TMP_ROOT/kill-bin/ln" <<'EOF'
#!/bin/sh
/bin/ln "$@" || exit
operation_token=$(sed -n '2p' "$1")
case "$operation_token" in
  operation:[0-9]*:*) helper_pid=${operation_token#operation:} ;;
  *) exit 1 ;;
esac
helper_pid=${helper_pid%%:*}
case "$helper_pid" in
  '' | *[!0-9]*) exit 1 ;;
esac
kill -KILL "$helper_pid"
EOF
  chmod +x "$TMP_ROOT/kill-bin/ln"
  run env PATH="$TMP_ROOT/kill-bin:$PATH" sh "$ISSUE_DEFINE_RESERVATION_HELPER" acquire "$siw_dir" owner-a 1
  [ "$status" -ne 0 ]
  [ ! -e "$siw_dir/.issue-publication.lock" ]
  [ "$(sed -n '1p' "$siw_dir/.issue-reservation-operation.lock")" = owner-a ]
  set -- "$siw_dir"/.siw-owner-claim.*
  [ -f "$1" ]
  stale_temp=$1

  sh "$ISSUE_DEFINE_RESERVATION_HELPER" acquire "$siw_dir" owner-a 1
  [ "$(sed -n '1p' "$siw_dir/.issue-publication.lock")" = owner-a ]
  [ ! -e "$siw_dir/.issue-reservation-operation.lock" ]
  unlink "$stale_temp"
  sh "$ISSUE_DEFINE_RESERVATION_HELPER" release-publication "$siw_dir" owner-a
}

@test "siw issue reservation validates claims before acquisition returns" {
  local reservation_root siw_dir
  siw_dir="$TMP_ROOT/siw"
  reservation_root="$siw_dir/.issue-id-reservations"
  mkdir -p "$siw_dir/issues" "$reservation_root/ISSUE-G-999"
  printf '# Open Issues\n' >"$siw_dir/OPEN_ISSUES_OVERVIEW.md"

  run sh "$ISSUE_DEFINE_RESERVATION_HELPER" acquire "$siw_dir" owner-a 1
  [ "$status" -ne 0 ]
  [[ "$output" == *'ownership claim is not a regular file'* ]]
  [ "$(sed -n '1p' "$siw_dir/.issue-publication.lock")" = owner-a ]

  run sh "$ISSUE_DEFINE_RESERVATION_HELPER" acquire "$siw_dir" owner-a 1
  [ "$status" -ne 0 ]
  [[ "$output" == *'ownership claim is not a regular file'* ]]

  rmdir "$reservation_root/ISSUE-G-999"
  sh "$ISSUE_DEFINE_RESERVATION_HELPER" release-publication "$siw_dir" owner-a
}

@test "siw issue reservation rejects hidden trailing claim records" {
  local reservation_root siw_dir
  siw_dir="$TMP_ROOT/siw"
  reservation_root="$siw_dir/.issue-id-reservations"
  mkdir -p "$siw_dir/issues"
  printf '# Open Issues\n' >"$siw_dir/OPEN_ISSUES_OVERVIEW.md"
  printf 'owner-a\n\n\nhidden\n' >"$siw_dir/.issue-publication.lock"

  run sh "$ISSUE_DEFINE_RESERVATION_HELPER" acquire "$siw_dir" owner-a 1
  [ "$status" -ne 0 ]
  [[ "$output" == *'ownership claim has unexpected data'* ]]

  printf 'owner-a\n' >"$siw_dir/.issue-publication.lock"
  mkdir -p "$reservation_root"
  printf 'owner-a\nrequest-key\n\nhidden\n' >"$reservation_root/ISSUE-G-001"
  run sh "$ISSUE_DEFINE_RESERVATION_HELPER" acquire "$siw_dir" owner-a 1
  [ "$status" -ne 0 ]
  [[ "$output" == *'ownership claim has unexpected data'* ]]
}

@test "siw issue reservation serializes overlapping reordered batch retries" {
  local key_a_left key_a_right key_b_left key_b_right left_pid reservation_root right_pid siw_dir
  siw_dir="$TMP_ROOT/siw"
  reservation_root="$siw_dir/.issue-id-reservations"
  mkdir -p "$siw_dir/issues"
  printf '# Open Issues\n' >"$siw_dir/OPEN_ISSUES_OVERVIEW.md"
  sh "$ISSUE_DEFINE_RESERVATION_HELPER" acquire "$siw_dir" owner-a 1

  env SIW_OPERATION_MAX_ATTEMPTS=500 SIW_OPERATION_RETRY_DELAY=0.01 \
    sh "$ISSUE_DEFINE_RESERVATION_HELPER" reserve-batch "$siw_dir" G owner-a 5 key-a key-b >"$TMP_ROOT/left-result" &
  left_pid=$!
  env SIW_OPERATION_MAX_ATTEMPTS=500 SIW_OPERATION_RETRY_DELAY=0.01 \
    sh "$ISSUE_DEFINE_RESERVATION_HELPER" reserve-batch "$siw_dir" G owner-a 5 key-b key-a >"$TMP_ROOT/right-result" &
  right_pid=$!
  wait "$left_pid"
  wait "$right_pid"

  key_a_left="$(awk '$1 == "key-a" { print $2 }' "$TMP_ROOT/left-result")"
  key_a_right="$(awk '$1 == "key-a" { print $2 }' "$TMP_ROOT/right-result")"
  key_b_left="$(awk '$1 == "key-b" { print $2 }' "$TMP_ROOT/left-result")"
  key_b_right="$(awk '$1 == "key-b" { print $2 }' "$TMP_ROOT/right-result")"
  [ "$key_a_left" = "$key_a_right" ]
  [ "$key_b_left" = "$key_b_right" ]
  [ "$key_a_left" != "$key_b_left" ]
  [ "$(find "$reservation_root" -name 'ISSUE-*' -type f | wc -l | tr -d ' ')" -eq 2 ]

  sh "$ISSUE_DEFINE_RESERVATION_HELPER" abandon "$siw_dir" "$key_a_left" owner-a
  sh "$ISSUE_DEFINE_RESERVATION_HELPER" abandon "$siw_dir" "$key_b_left" owner-a
  sh "$ISSUE_DEFINE_RESERVATION_HELPER" release-publication "$siw_dir" owner-a
}

@test "siw publication release cannot overtake an authorized reservation" {
  local release_pid reserve_pid siw_dir
  siw_dir="$TMP_ROOT/siw"
  mkdir -p "$siw_dir/issues" "$TMP_ROOT/release-bin" "$TMP_ROOT/release-barrier"
  printf '# Open Issues\n' >"$siw_dir/OPEN_ISSUES_OVERVIEW.md"
  sh "$ISSUE_DEFINE_RESERVATION_HELPER" acquire "$siw_dir" owner-a 1

  cat >"$TMP_ROOT/release-bin/unlink" <<'EOF'
#!/bin/sh
case "$1" in
  */.issue-publication.lock)
    : >"$SIW_RELEASE_BARRIER/ready"
    while [ ! -e "$SIW_RELEASE_BARRIER/go" ]; do sleep 0.01; done
    ;;
esac
exec /bin/unlink "$@"
EOF
  chmod +x "$TMP_ROOT/release-bin/unlink"

  env PATH="$TMP_ROOT/release-bin:$PATH" SIW_RELEASE_BARRIER="$TMP_ROOT/release-barrier" \
    sh "$ISSUE_DEFINE_RESERVATION_HELPER" release-publication "$siw_dir" owner-a >"$TMP_ROOT/release-output" 2>&1 &
  release_pid=$!
  while [ ! -e "$TMP_ROOT/release-barrier/ready" ]; do sleep 0.01; done

  env SIW_OPERATION_MAX_ATTEMPTS=500 SIW_OPERATION_RETRY_DELAY=0.01 \
    sh "$ISSUE_DEFINE_RESERVATION_HELPER" reserve "$siw_dir" G owner-a 2 same-key >"$TMP_ROOT/reserve-output" 2>&1 &
  reserve_pid=$!
  sleep 0.05
  kill -0 "$reserve_pid"
  : >"$TMP_ROOT/release-barrier/go"
  wait "$release_pid"
  if wait "$reserve_pid"; then
    false
  fi

  [ ! -e "$siw_dir/.issue-publication.lock" ]
  [ ! -e "$siw_dir/.issue-reservation-operation.lock" ]
  set -- "$siw_dir"/.issue-id-reservations/ISSUE-*
  [ ! -e "$1" ]
}

@test "siw publication state keeps hashes paired when the issue set changes mid-batch" {
  local baseline_file expected_hash_1 expected_hash_3 hash_backend hash_backend_path issue_path_1 issue_path_2 issue_path_3 mock_bin siw_dir
  siw_dir="$TMP_ROOT/siw"
  baseline_file="$siw_dir/.issue-publication.baseline"
  issue_path_1="$siw_dir/issues/ISSUE-G-001-alpha.md"
  issue_path_2="$siw_dir/issues/ISSUE-G-002-injected.md"
  issue_path_3="$siw_dir/issues/ISSUE-G-003-gamma.md"
  mock_bin="$TMP_ROOT/hash-inject-bin"
  mkdir -p "$siw_dir/issues" "$mock_bin"
  printf '# ISSUE-G-001: alpha\nAlpha body.\n' >"$issue_path_1"
  printf '# ISSUE-G-003: gamma\nGamma body, a different length than alpha.\n' >"$issue_path_3"
  printf '# Open Issues\n| G-001 | alpha | READY |\n| G-003 | gamma | READY |\n' >"$siw_dir/OPEN_ISSUES_OVERVIEW.md"
  printf '# Log\n- Created G-001: alpha\n- Created G-003: gamma\n' >"$siw_dir/LOG.md"

  if command -v sha256sum >/dev/null 2>&1; then
    hash_backend=sha256sum
    expected_hash_1="$(sha256sum "$issue_path_1" | awk '{ print $1 }')"
    expected_hash_3="$(sha256sum "$issue_path_3" | awk '{ print $1 }')"
  elif command -v shasum >/dev/null 2>&1; then
    hash_backend=shasum
    expected_hash_1="$(shasum -a 256 "$issue_path_1" | awk '{ print $1 }')"
    expected_hash_3="$(shasum -a 256 "$issue_path_3" | awk '{ print $1 }')"
  else
    hash_backend=openssl
    expected_hash_1="$(openssl dgst -sha256 "$issue_path_1" | awk '{ print $NF }')"
    expected_hash_3="$(openssl dgst -sha256 "$issue_path_3" | awk '{ print $NF }')"
  fi
  [ "$expected_hash_1" != "$expected_hash_3" ]
  hash_backend_path="$(command -v "$hash_backend")"
  write_file "$mock_bin/$hash_backend" <<EOF
#!/bin/sh
"$hash_backend_path" "\$@"
hash_status=\$?
printf '# ISSUE-G-002: injected\n' >"$issue_path_2"
exit "\$hash_status"
EOF
  chmod +x "$mock_bin/$hash_backend"

  env PATH="$mock_bin:$PATH" sh "$ISSUE_DEFINE_RESERVATION_HELPER" acquire "$siw_dir" owner-a 1

  [ "$(awk '$1 == "issue" && $2 == "G-001" { print $4 }' "$baseline_file")" = "$expected_hash_1" ]
  [ "$(awk '$1 == "issue" && $2 == "G-003" { print $4 }' "$baseline_file")" = "$expected_hash_3" ]
  [ -z "$(awk '$1 == "issue" && $2 == "G-002" { print $0 }' "$baseline_file")" ]

  rm "$issue_path_2"
  sh "$ISSUE_DEFINE_RESERVATION_HELPER" release-publication "$siw_dir" owner-a
}

@test "siw acquire cleans up temporary state after a mid-hash interruption" {
  local hash_backend hash_backend_path siw_dir
  siw_dir="$TMP_ROOT/siw"
  mkdir -p "$siw_dir/issues" "$TMP_ROOT/hash-term-bin"
  printf '# Open Issues\n' >"$siw_dir/OPEN_ISSUES_OVERVIEW.md"
  printf '# Log\n' >"$siw_dir/LOG.md"
  printf '# ISSUE-G-001: existing\n' >"$siw_dir/issues/ISSUE-G-001-existing.md"

  if command -v sha256sum >/dev/null 2>&1; then
    hash_backend=sha256sum
  elif command -v shasum >/dev/null 2>&1; then
    hash_backend=shasum
  else
    hash_backend=openssl
  fi
  hash_backend_path="$(command -v "$hash_backend")"
  write_file "$TMP_ROOT/hash-term-bin/$hash_backend" <<EOF
#!/bin/sh
kill -TERM \$PPID
exec "$hash_backend_path" "\$@"
EOF
  chmod +x "$TMP_ROOT/hash-term-bin/$hash_backend"

  run env PATH="$TMP_ROOT/hash-term-bin:$PATH" sh "$ISSUE_DEFINE_RESERVATION_HELPER" acquire "$siw_dir" owner-a 1
  [ "$status" -ne 0 ]
  [ ! -e "$siw_dir/.issue-publication.lock" ]
  [ ! -e "$siw_dir/.issue-publication.baseline" ]
  set -- "$siw_dir"/.siw-publication-state.*
  [ ! -e "$1" ]
}
