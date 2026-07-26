#!/bin/sh

set -eu

usage() {
  cat >&2 << 'EOF'
Usage:
  siw-issue-reservation.sh new-owner
  siw-issue-reservation.sh acquire <siw-dir> <owner-token> [max-attempts]
  siw-issue-reservation.sh reserve <siw-dir> <prefix> <owner-token> [max-attempts] [request-key]
  siw-issue-reservation.sh reserve-batch <siw-dir> <prefix> <owner-token> <max-attempts> <request-key>...
  siw-issue-reservation.sh reserve-exact <siw-dir> <issue-id> <owner-token>
  siw-issue-reservation.sh publish-receipt <siw-dir> <owner-token> [issue-id]...
  siw-issue-reservation.sh verify-receipt <siw-dir> <owner-token> [issue-id]...
  siw-issue-reservation.sh release <siw-dir> <issue-id> <owner-token>
  siw-issue-reservation.sh release-batch <siw-dir> <owner-token> <issue-id>...
  siw-issue-reservation.sh abandon <siw-dir> <issue-id> <owner-token>
  siw-issue-reservation.sh release-publication <siw-dir> <owner-token>
EOF
  exit 2
}

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

validate_owner() {
  case "$1" in
    '' | *[!A-Za-z0-9._:-]*) fail "owner token must use only letters, digits, '.', '_', ':', or '-'" ;;
  esac
}

validate_prefix() {
  case "$1" in
    G) return ;;
    P*) phase_number=${1#P} ;;
    *) fail "issue prefix must be G or P followed by a positive phase number" ;;
  esac
  case "$phase_number" in
    '' | *[!0-9]* | 0 | 0*) fail "issue prefix must be G or P followed by a positive phase number" ;;
  esac
}

is_valid_issue_id() {
  candidate_issue_prefix=${1%-*}
  candidate_issue_number=${1##*-}
  case "$candidate_issue_prefix" in
    G) ;;
    P*)
      candidate_phase_number=${candidate_issue_prefix#P}
      case "$candidate_phase_number" in
        '' | *[!0-9]* | 0 | 0*) return 1 ;;
      esac
      ;;
    *) return 1 ;;
  esac
  case "$candidate_issue_number" in
    '' | *[!0-9]* | ? | ??) return 1 ;;
  esac
}

validate_issue_id() {
  is_valid_issue_id "$1" || fail "issue ID must look like G-001 or P1-001"
  issue_prefix=${1%-*}
  issue_number=${1##*-}
}

validate_attempts() {
  case "$1" in
    '' | *[!0-9]* | 0) fail "max attempts must be a positive integer" ;;
  esac
}

validate_request_key() {
  case "$1" in
    '' | *[!A-Za-z0-9._:-]*) fail "request key must use only letters, digits, '.', '_', ':', or '-'" ;;
  esac
}

validate_hash() {
  hash_value=$1
  hash_label=$2
  case "$hash_value" in
    '' | *[!0-9a-f]*) fail "$hash_label must be a lowercase SHA-256 hash" ;;
  esac
  [ "${#hash_value}" -eq 64 ] || fail "$hash_label must be a lowercase SHA-256 hash"
}

hash_file() {
  hash_path=$1
  select_hash_backend
  case "$hash_backend" in
    sha256sum)
      hash_output=$("$hash_backend_command" "$hash_path") || fail "could not hash file: $hash_path"
      calculated_hash=${hash_output%% *}
      calculated_hash=${calculated_hash#\\}
      ;;
    shasum)
      hash_output=$("$hash_backend_command" -a 256 "$hash_path") || fail "could not hash file: $hash_path"
      calculated_hash=${hash_output%% *}
      calculated_hash=${calculated_hash#\\}
      ;;
    openssl)
      hash_output=$("$hash_backend_command" dgst -sha256 "$hash_path") || fail "could not hash file: $hash_path"
      calculated_hash=${hash_output##* }
      ;;
  esac
  validate_hash "$calculated_hash" "calculated hash"
}

select_hash_backend() {
  [ -z "${hash_backend:-}" ] || return 0
  if command -v sha256sum > /dev/null 2>&1; then
    hash_backend=sha256sum
  elif command -v shasum > /dev/null 2>&1; then
    hash_backend=shasum
  elif command -v openssl > /dev/null 2>&1; then
    hash_backend=openssl
  else
    fail "could not hash SIW publication state; install sha256sum, shasum, or openssl"
  fi
  hash_backend_command=$(command -v "$hash_backend")
}

hash_files() {
  hashes_output=$1
  shift
  [ "$#" -ge 1 ] || fail "could not hash an empty publication file set"
  select_hash_backend
  hash_batch_raw=$(umask 077 && mktemp "${TMPDIR:-/tmp}/siw-hash-output.XXXXXX") \
    || fail "could not prepare batched hash output"
  install_cleanup_traps
  case "$hash_backend" in
    sha256sum)
      "$hash_backend_command" "$@" > "$hash_batch_raw" || fail "could not hash SIW publication files"
      awk '{ hash_value = $1; sub(/^\\/, "", hash_value); print hash_value }' \
        "$hash_batch_raw" > "$hashes_output" || fail "could not normalize batched hashes"
      ;;
    shasum)
      "$hash_backend_command" -a 256 "$@" > "$hash_batch_raw" || fail "could not hash SIW publication files"
      awk '{ hash_value = $1; sub(/^\\/, "", hash_value); print hash_value }' \
        "$hash_batch_raw" > "$hashes_output" || fail "could not normalize batched hashes"
      ;;
    openssl)
      "$hash_backend_command" dgst -sha256 "$@" > "$hash_batch_raw" || fail "could not hash SIW publication files"
      awk '{ print $NF }' "$hash_batch_raw" > "$hashes_output" \
        || fail "could not normalize batched hashes"
      ;;
  esac
  unlink "$hash_batch_raw" || fail "could not remove temporary batched hash output"
  hash_batch_raw=
}

normalize_issue_id() {
  normalized_issue_id=${1#ISSUE-}
  validate_issue_id "$normalized_issue_id"
}

new_owner() {
  if command -v uuidgen > /dev/null 2>&1; then
    owner=$(uuidgen | tr '[:upper:]' '[:lower:]')
  elif [ -r /dev/urandom ] && command -v od > /dev/null 2>&1; then
    owner=$(LC_ALL=C od -An -N16 -tx1 /dev/urandom | tr -d ' \n')
  else
    fail "could not generate a unique owner token; install uuidgen or provide /dev/urandom and od"
  fi
  validate_owner "$owner"
  printf '%s\n' "$owner"
}

resolve_siw_dir() {
  requested_dir=$1
  [ -d "$requested_dir" ] || fail "SIW directory does not exist: $requested_dir"
  siw_dir=$(CDPATH='' cd "$requested_dir" && pwd -P)
  [ "${siw_dir##*/}" = siw ] || fail "SIW directory must be named 'siw': $requested_dir"
  [ -f "$siw_dir/OPEN_ISSUES_OVERVIEW.md" ] || fail "SIW overview does not exist: $siw_dir/OPEN_ISSUES_OVERVIEW.md"
}

read_claim() {
  claim_file=$1
  missing_policy=${2:-fail}
  case "$missing_policy" in
    fail | allow-missing) ;;
    *) fail "invalid ownership claim read policy: $missing_policy" ;;
  esac
  if [ ! -e "$claim_file" ] && [ ! -L "$claim_file" ]; then
    [ "$missing_policy" = allow-missing ] && return 1
    fail "ownership claim is not a regular file: $claim_file"
  fi
  [ ! -L "$claim_file" ] || fail "ownership claim must not be a symlink: $claim_file"
  if [ ! -f "$claim_file" ]; then
    if [ "$missing_policy" = allow-missing ] && [ ! -e "$claim_file" ] && [ ! -L "$claim_file" ]; then
      return 1
    fi
    fail "ownership claim is not a regular file: $claim_file"
  fi
  if ! claim_result=$(
    recorded_owner=
    recorded_request_key=
    extra_claim_data=
    has_extra_claim_record=
    exec 3< "$claim_file" || exit 1
    IFS= read -r recorded_owner <&3 || true
    IFS= read -r recorded_request_key <&3 || true
    if IFS= read -r extra_claim_data <&3 || [ -n "$extra_claim_data" ]; then
      has_extra_claim_record=1
    fi
    exec 3<&-
    printf '%s|%s|%s' "$recorded_owner" "$recorded_request_key" "$has_extra_claim_record"
  ) 2> /dev/null; then
    [ "$missing_policy" = allow-missing ] && return 1
    fail "could not read ownership claim: $claim_file"
  fi
  recorded_owner=${claim_result%%|*}
  claim_result=${claim_result#*|}
  recorded_request_key=${claim_result%%|*}
  has_extra_claim_record=${claim_result#*|}
  [ -n "$recorded_owner" ] || fail "ownership claim has an empty token: $claim_file"
  validate_owner "$recorded_owner"
  [ -z "$has_extra_claim_record" ] || fail "ownership claim has unexpected data: $claim_file"
  if [ -n "$recorded_request_key" ]; then
    validate_request_key "$recorded_request_key"
  fi
}

read_owner() {
  read_claim "$1"
}

require_owner() {
  claim_file=$1
  expected_owner=$2
  read_owner "$claim_file"
  [ "$recorded_owner" = "$expected_owner" ] || fail "reservation belongs to a different owner"
}

require_publication_owner() {
  claim_file=$1
  expected_owner=$2
  require_owner "$claim_file" "$expected_owner"
  publication_baseline_hash=
  case "$recorded_request_key" in
    state:*)
      publication_baseline_hash=${recorded_request_key#state:}
      validate_hash "$publication_baseline_hash" "publication baseline hash"
      ;;
    '') ;;
    *) fail "publication ownership claim has an invalid state record: $claim_file" ;;
  esac
}

cleanup_claim_temp() {
  if [ -n "${claim_temp:-}" ] && { [ -e "$claim_temp" ] || [ -L "$claim_temp" ]; }; then
    unlink "$claim_temp" 2> /dev/null || true
  fi
  claim_temp=
}

cleanup_state_temp() {
  if [ -n "${state_temp:-}" ] && { [ -e "$state_temp" ] || [ -L "$state_temp" ]; }; then
    unlink "$state_temp" 2> /dev/null || true
  fi
  state_temp=
}

cleanup_baseline_temps() {
  if [ -n "${baseline_temp:-}" ] && { [ -e "$baseline_temp" ] || [ -L "$baseline_temp" ]; }; then
    unlink "$baseline_temp" 2> /dev/null || true
  fi
  if [ -n "${baseline_state_temp:-}" ] && { [ -e "$baseline_state_temp" ] || [ -L "$baseline_state_temp" ]; }; then
    unlink "$baseline_state_temp" 2> /dev/null || true
  fi
  baseline_temp=
  baseline_state_temp=
}

cleanup_hash_temps() {
  if [ -n "${hash_batch_raw:-}" ] && { [ -e "$hash_batch_raw" ] || [ -L "$hash_batch_raw" ]; }; then
    unlink "$hash_batch_raw" 2> /dev/null || true
  fi
  if [ -n "${hashes_temp:-}" ] && { [ -e "$hashes_temp" ] || [ -L "$hashes_temp" ]; }; then
    unlink "$hashes_temp" 2> /dev/null || true
  fi
  hash_batch_raw=
  hashes_temp=
}

cleanup_changed_ids_temp() {
  if [ -n "${changed_ids_temp:-}" ] && { [ -e "$changed_ids_temp" ] || [ -L "$changed_ids_temp" ]; }; then
    unlink "$changed_ids_temp" 2> /dev/null || true
  fi
  changed_ids_temp=
}

cleanup_receipt_temp() {
  if [ -n "${receipt_temp:-}" ] && { [ -e "$receipt_temp" ] || [ -L "$receipt_temp" ]; }; then
    unlink "$receipt_temp" 2> /dev/null || true
  fi
  receipt_temp=
}

cleanup_operation_lock() {
  if [ -z "${operation_lock_held:-}" ]; then
    return
  fi
  if [ -f "$operation_claim" ] && [ ! -L "$operation_claim" ]; then
    current_operation_owner=
    current_operation_token=
    {
      IFS= read -r current_operation_owner || true
      IFS= read -r current_operation_token || true
    } < "$operation_claim"
    if [ "$current_operation_owner" = "$operation_owner" ] && [ "$current_operation_token" = "$operation_token" ]; then
      unlink "$operation_claim" 2> /dev/null || true
    fi
  fi
  operation_lock_held=
}

finish_operation_lock() {
  cleanup_operation_lock
  trap - 0 1 2 15
}

install_cleanup_traps() {
  trap 'cleanup_claim_temp; cleanup_state_temp; cleanup_baseline_temps; cleanup_hash_temps; cleanup_changed_ids_temp; cleanup_receipt_temp; cleanup_operation_lock' 0
  trap 'cleanup_claim_temp; cleanup_state_temp; cleanup_baseline_temps; cleanup_hash_temps; cleanup_changed_ids_temp; cleanup_receipt_temp; cleanup_operation_lock; exit 1' 1 2 15
}

finish_claim_temp() {
  cleanup_claim_temp
  if [ -n "${operation_lock_held:-}" ]; then
    install_cleanup_traps
  else
    trap - 0 1 2 15
  fi
}

create_owned_claim() {
  claim_file=$1
  claim_owner=$2
  claim_request_key=${3:-}
  claim_parent=${claim_file%/*}
  claim_temp=
  claim_error=

  if [ -d "$claim_file" ]; then
    claim_error="ownership claim path is a directory"
    return 1
  fi
  claim_temp=$(umask 077 && mktemp "$claim_parent/.siw-owner-claim.XXXXXX") || fail "could not prepare temporary ownership claim in $claim_parent"
  install_cleanup_traps
  if [ -n "$claim_request_key" ]; then
    printf '%s\n%s\n' "$claim_owner" "$claim_request_key" > "$claim_temp" || fail "could not prepare ownership claim: $claim_temp"
  else
    printf '%s\n' "$claim_owner" > "$claim_temp" || fail "could not prepare ownership claim: $claim_temp"
  fi

  link_attempt=1
  while [ "$link_attempt" -le 2 ]; do
    if claim_error=$(ln "$claim_temp" "$claim_file" 2>&1); then
      if [ -f "$claim_file" ] && [ ! -L "$claim_file" ]; then
        finish_claim_temp
        return 0
      fi
      nested_claim="$claim_file/${claim_temp##*/}"
      [ ! -f "$nested_claim" ] || unlink "$nested_claim" || true
      finish_claim_temp
      claim_error="ownership claim path changed type during creation"
      return 1
    fi
    if [ -e "$claim_file" ] || [ -L "$claim_file" ]; then
      finish_claim_temp
      return 1
    fi
    link_attempt=$((link_attempt + 1))
  done
  finish_claim_temp
  fail "could not create ownership claim after retry $claim_file: $claim_error"
}

acquire_operation_lock() {
  siw_dir=$1
  operation_owner=$2
  operation_claim="$siw_dir/.issue-reservation-operation.lock"
  operation_nonce=$(new_owner)
  operation_token="operation:$$:$operation_nonce"
  operation_attempt=1
  operation_max_attempts=${SIW_OPERATION_MAX_ATTEMPTS:-300}

  validate_attempts "$operation_max_attempts"
  while [ "$operation_attempt" -le "$operation_max_attempts" ]; do
    if create_owned_claim "$operation_claim" "$operation_owner" "$operation_token"; then
      operation_lock_held=1
      install_cleanup_traps
      return
    fi
    if [ -f "$operation_claim" ] && [ ! -L "$operation_claim" ]; then
      if ! read_claim "$operation_claim" allow-missing; then
        operation_attempt=$((operation_attempt + 1))
        continue
      fi
      case "$recorded_request_key" in
        operation:[0-9]*:*)
          operation_pid=${recorded_request_key#operation:}
          operation_pid=${operation_pid%%:*}
          ;;
        *) fail "reservation operation claim is malformed: $operation_claim" ;;
      esac
      case "$operation_pid" in
        '' | *[!0-9]*) fail "reservation operation claim is malformed: $operation_claim" ;;
      esac
      if [ "$operation_pid" = "$$" ] || ! kill -0 "$operation_pid" 2> /dev/null; then
        unlink "$operation_claim" 2> /dev/null || true
        operation_attempt=$((operation_attempt + 1))
        continue
      fi
    elif [ -e "$operation_claim" ] || [ -L "$operation_claim" ]; then
      fail "reservation operation claim is not a regular ownership claim: $operation_claim"
    fi
    operation_attempt=$((operation_attempt + 1))
    [ "$operation_attempt" -le "$operation_max_attempts" ] && sleep "${SIW_OPERATION_RETRY_DELAY:-0.01}"
  done
  fail "another reservation helper operation is still running; wait for it to finish before retrying"
}

remove_owned_claim() {
  claim_file=$1
  owner=$2
  require_owner "$claim_file" "$owner"
  unlink "$claim_file" || fail "could not remove ownership claim: $claim_file"
}

prepare_reservation_root() {
  reservation_root=$1
  [ ! -L "$reservation_root" ] || fail "reservation root must not be a symlink: $reservation_root"
  if [ -e "$reservation_root" ]; then
    [ -d "$reservation_root" ] || fail "reservation root is not a directory: $reservation_root"
    return
  fi
  if ! mkdir_error=$(mkdir "$reservation_root" 2>&1); then
    [ -d "$reservation_root" ] && return
    fail "could not create reservation root $reservation_root: $mkdir_error"
  fi
}

require_enumerable_directory() {
  directory=$1
  [ -d "$directory" ] || fail "directory does not exist: $directory"
  [ -x "$directory" ] || fail "could not enumerate directory: $directory"
  ls -A "$directory" > /dev/null 2>&1 || fail "could not enumerate directory: $directory"
}

require_no_owned_reservations() {
  siw_dir=$1
  owner=$2
  reservation_root="$siw_dir/.issue-id-reservations"
  if [ ! -e "$reservation_root" ] && [ ! -L "$reservation_root" ]; then
    return
  fi
  [ ! -L "$reservation_root" ] || fail "reservation root must not be a symlink: $reservation_root"
  require_enumerable_directory "$reservation_root"
  for reservation_dir in "$reservation_root"/ISSUE-*; do
    if [ ! -e "$reservation_dir" ] && [ ! -L "$reservation_dir" ]; then
      continue
    fi
    read_owner "$reservation_dir"
    [ "$recorded_owner" != "$owner" ] || fail "release or abandon owned issue reservations before releasing publication: ${reservation_dir##*/}"
  done
}

validate_reservation_state() {
  siw_dir=$1
  reservation_root="$siw_dir/.issue-id-reservations"
  if [ ! -e "$reservation_root" ] && [ ! -L "$reservation_root" ]; then
    return
  fi
  [ ! -L "$reservation_root" ] || fail "reservation root must not be a symlink: $reservation_root"
  [ -d "$reservation_root" ] || fail "reservation root is not a directory: $reservation_root"
  require_enumerable_directory "$reservation_root"
  scan_reservation_claims "$reservation_root" ''
}

locate_issue_file() {
  siw_dir=$1
  issue_id=$2
  require_enumerable_directory "$siw_dir/issues"
  issue_file=
  for issue_path in "$siw_dir"/issues/ISSUE-"$issue_id"-*.md; do
    if [ ! -e "$issue_path" ] && [ ! -L "$issue_path" ]; then
      continue
    fi
    [ -f "$issue_path" ] && [ ! -L "$issue_path" ] || fail "issue path is not a regular file: $issue_path"
    [ -z "$issue_file" ] || fail "multiple issue files exist for $issue_id"
    issue_file=$issue_path
  done
}

calculate_publication_state() {
  publication_siw_dir=$1
  overview_path="$publication_siw_dir/OPEN_ISSUES_OVERVIEW.md"
  log_path="$publication_siw_dir/LOG.md"
  issues_path="$publication_siw_dir/issues"
  cleanup_state_temp
  cleanup_hash_temps
  state_temp=$(umask 077 && mktemp "$publication_siw_dir/.siw-publication-state.XXXXXX") \
    || fail "could not prepare SIW publication state in $publication_siw_dir"
  hashes_temp=$(umask 077 && mktemp "${TMPDIR:-/tmp}/siw-publication-hashes.XXXXXX") \
    || fail "could not prepare batched publication hashes"
  install_cleanup_traps

  [ -f "$overview_path" ] && [ ! -L "$overview_path" ] \
    || fail "SIW overview must be a non-symlink regular file: $overview_path"
  set -- "$overview_path"

  if [ ! -e "$log_path" ] && [ ! -L "$log_path" ]; then
    publication_log_missing=1
  else
    [ -f "$log_path" ] && [ ! -L "$log_path" ] \
      || fail "SIW log must be a non-symlink regular file: $log_path"
    publication_log_missing=
    set -- "$@" "$log_path"
  fi

  if [ -e "$issues_path" ] || [ -L "$issues_path" ]; then
    [ -d "$issues_path" ] && [ ! -L "$issues_path" ] \
      || fail "SIW issues path must be a non-symlink directory: $issues_path"
    require_enumerable_directory "$issues_path"
    for issue_path in "$issues_path"/ISSUE-*.md; do
      if [ ! -e "$issue_path" ] && [ ! -L "$issue_path" ]; then
        continue
      fi
      [ -f "$issue_path" ] && [ ! -L "$issue_path" ] \
        || fail "issue path is not a regular file: $issue_path"
      case "${issue_path##*/}" in
        *'
'*) fail "issue filenames must not contain newlines: $issue_path" ;;
      esac
      set -- "$@" "$issue_path"
    done
  fi

  hash_files "$hashes_temp" "$@"
  if ! exec 3< "$hashes_temp"; then
    fail "could not read batched publication hashes"
  fi
  IFS= read -r overview_hash <&3 || fail "missing overview hash from batched publication state"
  validate_hash "$overview_hash" "calculated overview hash"
  printf 'overview %s\n' "$overview_hash" > "$state_temp" \
    || fail "could not write temporary SIW publication state: $state_temp"
  if [ -n "$publication_log_missing" ]; then
    printf 'log missing\n' >> "$state_temp" \
      || fail "could not write temporary SIW publication state: $state_temp"
  else
    IFS= read -r log_hash <&3 || fail "missing log hash from batched publication state"
    validate_hash "$log_hash" "calculated log hash"
    printf 'log %s\n' "$log_hash" >> "$state_temp" \
      || fail "could not write temporary SIW publication state: $state_temp"
  fi

  publication_issue_ids=
  if [ -e "$issues_path" ] || [ -L "$issues_path" ]; then
    for issue_path in "$issues_path"/ISSUE-*.md; do
      if [ ! -e "$issue_path" ] && [ ! -L "$issue_path" ]; then
        continue
      fi
      IFS= read -r issue_hash <&3 || fail "missing issue hash from batched publication state"
      validate_hash "$issue_hash" "calculated issue hash"
      issue_name=${issue_path##*/}
      issue_stem=${issue_name#ISSUE-}
      issue_stem=${issue_stem%.md}
      candidate_prefix=${issue_stem%%-*}
      candidate_rest=${issue_stem#*-}
      candidate_number=${candidate_rest%%-*}
      candidate_title=${candidate_rest#*-}
      candidate_id="$candidate_prefix-$candidate_number"
      if [ "$candidate_rest" = "$issue_stem" ] || [ "$candidate_title" = "$candidate_rest" ] \
        || [ -z "$candidate_title" ] || ! is_valid_issue_id "$candidate_id"; then
        printf 'other-issue %s %s\n' "$issue_hash" "$issue_name" >> "$state_temp" \
          || fail "could not write temporary SIW publication state: $state_temp"
        continue
      fi
      case " $publication_issue_ids " in
        *" $candidate_id "*) fail "multiple issue files exist for $candidate_id" ;;
      esac
      publication_issue_ids="$publication_issue_ids $candidate_id"
      issue_heading=
      IFS= read -r issue_heading < "$issue_path" || true
      case "$issue_heading" in
        "# ISSUE-$candidate_id: "*) heading_valid=1 ;;
        *) heading_valid=0 ;;
      esac
      printf 'issue %s %s %s %s\n' "$candidate_id" "$heading_valid" "$issue_hash" "$issue_name" >> "$state_temp" \
        || fail "could not write temporary SIW publication state: $state_temp"
    done
  fi
  extra_hash=
  if IFS= read -r extra_hash <&3 || [ -n "$extra_hash" ]; then
    fail "unexpected extra hash in batched publication state"
  fi
  exec 3<&-
  cleanup_hash_temps

  awk '
    {
      line = $0
      if (line ~ /^##[[:space:]]+General([[:space:]]|$)/) {
        in_general = 1
      } else if (line ~ /^##[[:space:]]+/) {
        in_general = 0
      }
      if (in_general && line ~ /^[[:space:]]*\*\*Parallelization:\*\*/) {
        print "overview-general-parallelization\t" line
      }
    }
    /^[[:space:]]*\|/ {
      row = $0
      token = $0
      sub(/^[[:space:]]*\|[[:space:]]*/, "", token)
      sub(/[[:space:]]*\|.*/, "", token)
      sub(/^ISSUE-/, "", token)
      if (token ~ /^(G|P[1-9][0-9]*)-[0-9][0-9][0-9]+$/) {
        print "overview-issue " token "\t" row
      }
    }
  ' "$overview_path" >> "$state_temp" \
    || fail "could not index SIW overview issue rows"

  if [ -z "$publication_log_missing" ]; then
    awk '
      /^##[[:space:]]+Current Progress([[:space:]]|$)/ { in_progress = 1; next }
      /^##[[:space:]]+/ { in_progress = 0 }
      {
        line = $0
        accepted = (line ~ /^[[:space:]]*-[[:space:]]+(Created|Updated)[[:space:]]+/)
        if (in_progress && line ~ /^[[:space:]]*-[[:space:]]+/) accepted = 1
        if (!accepted) next
        rest = line
        while (match(rest, /(ISSUE-)?(G|P[1-9][0-9]*)-[0-9][0-9][0-9]+/)) {
          token = substr(rest, RSTART, RLENGTH)
          sub(/^ISSUE-/, "", token)
          print "log-issue " token "\t" line
          rest = substr(rest, RSTART + RLENGTH)
        }
      }
    ' "$log_path" >> "$state_temp" \
      || fail "could not index SIW log issue entries"
  fi

  hash_file "$state_temp"
  publication_state_hash=$calculated_hash
}

write_publication_baseline() {
  baseline_siw_dir=$1
  baseline_owner=$2
  baseline_hash=$3
  baseline_file="$baseline_siw_dir/.issue-publication.baseline"
  baseline_temp=$(umask 077 && mktemp "$baseline_siw_dir/.siw-publication-baseline.XXXXXX") \
    || fail "could not prepare publication baseline in $baseline_siw_dir"
  install_cleanup_traps
  {
    printf 'version 1\n'
    printf 'owner %s\n' "$baseline_owner"
    printf 'state %s\n' "$baseline_hash"
    while IFS= read -r baseline_line || [ -n "$baseline_line" ]; do
      printf '%s\n' "$baseline_line"
    done < "$state_temp"
  } > "$baseline_temp" || fail "could not prepare publication baseline: $baseline_temp"
  mv "$baseline_temp" "$baseline_file" || fail "could not publish baseline: $baseline_file"
  baseline_temp=
}

read_publication_baseline() {
  baseline_file=$1
  [ -f "$baseline_file" ] && [ ! -L "$baseline_file" ] \
    || fail "publication baseline is not a regular file: $baseline_file"
  cleanup_baseline_temps
  baseline_state_temp=$(umask 077 && mktemp "${TMPDIR:-/tmp}/siw-publication-baseline-state.XXXXXX") \
    || fail "could not prepare publication baseline validation"
  install_cleanup_traps
  if ! exec 3< "$baseline_file"; then
    fail "could not read publication baseline: $baseline_file"
  fi
  IFS=' ' read -r baseline_record baseline_value baseline_extra <&3 || true
  [ "$baseline_record" = version ] && [ "$baseline_value" = 1 ] && [ -z "$baseline_extra" ] \
    || fail "publication baseline has an invalid version record"
  IFS=' ' read -r baseline_record baseline_value baseline_extra <&3 || true
  [ "$baseline_record" = owner ] && [ -n "$baseline_value" ] && [ -z "$baseline_extra" ] \
    || fail "publication baseline has an invalid owner record"
  validate_owner "$baseline_value"
  publication_baseline_owner=$baseline_value
  IFS=' ' read -r baseline_record baseline_value baseline_extra <&3 || true
  [ "$baseline_record" = state ] && [ -z "$baseline_extra" ] \
    || fail "publication baseline has an invalid state record"
  validate_hash "$baseline_value" "publication baseline state hash"
  publication_baseline_state_hash=$baseline_value
  while IFS= read -r baseline_line <&3 || [ -n "$baseline_line" ]; do
    printf '%s\n' "$baseline_line" >> "$baseline_state_temp" \
      || fail "could not copy publication baseline state"
  done
  exec 3<&-
  hash_file "$baseline_state_temp"
  [ "$calculated_hash" = "$publication_baseline_state_hash" ] \
    || fail "publication baseline state is corrupted"
}

ensure_publication_baseline() {
  baseline_siw_dir=$1
  baseline_owner=$2
  baseline_file="$baseline_siw_dir/.issue-publication.baseline"
  if [ -e "$baseline_file" ] || [ -L "$baseline_file" ]; then
    read_publication_baseline "$baseline_file"
    if [ "$publication_baseline_owner" = "$baseline_owner" ] \
      && [ "$publication_baseline_state_hash" = "$publication_baseline_hash" ]; then
      return
    fi
    unlink "$baseline_file" || fail "could not remove stale publication baseline: $baseline_file"
    cleanup_baseline_temps
  fi
  [ "$publication_state_hash" = "$publication_baseline_hash" ] \
    || fail "publication baseline is missing after SIW state changed; preserve ownership for manual recovery"
  write_publication_baseline "$baseline_siw_dir" "$baseline_owner" "$publication_baseline_hash"
  read_publication_baseline "$baseline_file"
}

remove_owned_publication_baseline() {
  baseline_siw_dir=$1
  expected_owner=$2
  baseline_file="$baseline_siw_dir/.issue-publication.baseline"
  if [ ! -e "$baseline_file" ] && [ ! -L "$baseline_file" ]; then
    return
  fi
  read_publication_baseline "$baseline_file"
  [ "$publication_baseline_owner" = "$expected_owner" ] \
    || fail "publication baseline belongs to a different owner"
  cleanup_baseline_temps
  unlink "$baseline_file" || fail "could not remove publication baseline: $baseline_file"
}

clear_stale_publication_baseline() {
  baseline_file="$1/.issue-publication.baseline"
  if [ ! -e "$baseline_file" ] && [ ! -L "$baseline_file" ]; then
    return
  fi
  [ -f "$baseline_file" ] && [ ! -L "$baseline_file" ] \
    || fail "publication baseline is not a regular file: $baseline_file"
  unlink "$baseline_file" || fail "could not remove stale publication baseline: $baseline_file"
}

clear_stale_publication_receipt() {
  receipt_file="$1/.issue-publication.receipt"
  if [ ! -e "$receipt_file" ] && [ ! -L "$receipt_file" ]; then
    return
  fi
  [ -f "$receipt_file" ] && [ ! -L "$receipt_file" ] \
    || fail "publication receipt is not a regular file: $receipt_file"
  unlink "$receipt_file" || fail "could not remove stale publication receipt: $receipt_file"
}

read_publication_receipt_owner() {
  receipt_file=$1
  [ -f "$receipt_file" ] && [ ! -L "$receipt_file" ] \
    || fail "publication receipt is not a regular file: $receipt_file"
  if ! exec 3< "$receipt_file"; then
    fail "could not read publication receipt: $receipt_file"
  fi
  receipt_record=
  receipt_value=
  receipt_extra=
  IFS=' ' read -r receipt_record receipt_value receipt_extra <&3 || true
  [ "$receipt_record" = version ] \
    && { [ "$receipt_value" = 1 ] || [ "$receipt_value" = 2 ]; } \
    && [ -z "$receipt_extra" ] \
    || fail "publication receipt has an invalid version record"
  IFS=' ' read -r receipt_record receipt_value receipt_extra <&3 || true
  exec 3<&-
  [ "$receipt_record" = owner ] && [ -n "$receipt_value" ] && [ -z "$receipt_extra" ] \
    || fail "publication receipt has an invalid owner record"
  validate_owner "$receipt_value"
  publication_receipt_owner=$receipt_value
}

clear_foreign_publication_receipt() {
  receipt_file="$1/.issue-publication.receipt"
  expected_owner=$2
  if [ ! -e "$receipt_file" ] && [ ! -L "$receipt_file" ]; then
    return
  fi
  read_publication_receipt_owner "$receipt_file"
  if [ "$publication_receipt_owner" = "$expected_owner" ]; then
    return
  fi
  unlink "$receipt_file" || fail "could not remove stale publication receipt: $receipt_file"
}

remove_owned_publication_receipt() {
  receipt_file="$1/.issue-publication.receipt"
  expected_owner=$2
  if [ ! -e "$receipt_file" ] && [ ! -L "$receipt_file" ]; then
    return
  fi
  read_publication_receipt_owner "$receipt_file"
  [ "$publication_receipt_owner" = "$expected_owner" ] \
    || fail "publication receipt belongs to a different owner"
  unlink "$receipt_file" || fail "could not remove publication receipt: $receipt_file"
}

acquire_publication() {
  siw_dir=$1
  owner=$2
  max_attempts=$3
  lock_claim="$siw_dir/.issue-publication.lock"
  attempt=1
  last_claim_error=

  [ ! -L "$lock_claim" ] || fail "publication lock must not be a symlink: $lock_claim"
  while [ "$attempt" -le "$max_attempts" ]; do
    publication_lock_present=
    if [ -f "$lock_claim" ] && [ ! -L "$lock_claim" ]; then
      read_claim "$lock_claim"
      publication_baseline_hash=
      case "$recorded_request_key" in
        state:*)
          publication_baseline_hash=${recorded_request_key#state:}
          validate_hash "$publication_baseline_hash" "publication baseline hash"
          ;;
        '') ;;
        *) fail "publication ownership claim has an invalid state record: $lock_claim" ;;
      esac
      if [ "$recorded_owner" = "$owner" ]; then
        clear_foreign_publication_receipt "$siw_dir" "$owner"
        if [ -n "$publication_baseline_hash" ]; then
          calculate_publication_state "$siw_dir"
          ensure_publication_baseline "$siw_dir" "$owner"
        else
          clear_stale_publication_baseline "$siw_dir"
        fi
        validate_reservation_state "$siw_dir"
        return 0
      fi
      publication_lock_present=1
      last_claim_error="publication lock already exists"
    fi
    if [ -z "$publication_lock_present" ]; then
      calculate_publication_state "$siw_dir"
      if create_owned_claim "$lock_claim" "$owner" "state:$publication_state_hash"; then
        clear_stale_publication_receipt "$siw_dir"
        clear_stale_publication_baseline "$siw_dir"
        publication_baseline_hash=$publication_state_hash
        write_publication_baseline "$siw_dir" "$owner" "$publication_baseline_hash"
        validate_reservation_state "$siw_dir"
        return 0
      fi
      last_claim_error=$claim_error
      if [ -f "$lock_claim" ] && [ ! -L "$lock_claim" ]; then
        read_claim "$lock_claim"
        publication_baseline_hash=
        case "$recorded_request_key" in
          state:*)
            publication_baseline_hash=${recorded_request_key#state:}
            validate_hash "$publication_baseline_hash" "publication baseline hash"
            ;;
          '') ;;
          *) fail "publication ownership claim has an invalid state record: $lock_claim" ;;
        esac
        if [ "$recorded_owner" = "$owner" ]; then
          clear_foreign_publication_receipt "$siw_dir" "$owner"
          if [ -n "$publication_baseline_hash" ]; then
            calculate_publication_state "$siw_dir"
            ensure_publication_baseline "$siw_dir" "$owner"
          else
            clear_stale_publication_baseline "$siw_dir"
          fi
          validate_reservation_state "$siw_dir"
          return 0
        fi
      fi
    fi
    attempt=$((attempt + 1))
    if [ "$attempt" -le "$max_attempts" ]; then
      finish_operation_lock
      sleep "${SIW_RESERVATION_RETRY_DELAY:-1}"
      sleep "${SIW_OPERATION_RETRY_DELAY:-0.01}"
      acquire_operation_lock "$siw_dir" "$owner"
    fi
  done

  if [ -f "$lock_claim" ] && [ ! -L "$lock_claim" ]; then
    read_claim "$lock_claim"
    publication_baseline_hash=
    case "$recorded_request_key" in
      state:*)
        publication_baseline_hash=${recorded_request_key#state:}
        validate_hash "$publication_baseline_hash" "publication baseline hash"
        ;;
      '') ;;
      *) fail "publication ownership claim has an invalid state record: $lock_claim" ;;
    esac
    fail "publication is owned by another writer; preserve the lock for owner-guided recovery"
  fi
  if [ -e "$lock_claim" ] || [ -L "$lock_claim" ]; then
    fail "publication lock is not a regular ownership claim; preserve it for owner-guided recovery"
  fi
  fail "could not create publication lock $lock_claim: $last_claim_error"
}

overview_high_watermark() {
  overview=$1
  prefix=$2
  [ -f "$overview" ] || {
    echo 0
    return
  }
  awk -F '|' -v prefix="$prefix" '
    /^[[:space:]]*\|/ {
      token = $2
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", token)
      sub(/^ISSUE-/, "", token)
      if (token ~ ("^" prefix "-[0-9][0-9][0-9]+$")) {
        sub(("^" prefix "-"), "", token)
        value = token + 0
        if (value > high) high = value
      }
    }
    END { print high + 0 }
  ' "$overview"
}

path_high_watermark() {
  pattern_dir=$1
  prefix=$2
  suffix=$3
  high=0
  seen_issue_numbers=
  require_enumerable_directory "$pattern_dir"
  for path in "$pattern_dir"/ISSUE-"$prefix"-*"$suffix"; do
    if [ ! -e "$path" ] && [ ! -L "$path" ]; then
      continue
    fi
    [ -f "$path" ] && [ ! -L "$path" ] || fail "issue path is not a regular file: $path"
    name=${path##*/}
    number=${name#ISSUE-"$prefix"-}
    if [ -n "$suffix" ]; then
      number=${number%"$suffix"}
    fi
    number=${number%%-*}
    case "$number" in
      '' | *[!0-9]*) continue ;;
    esac
    value=$number
    while [ "${value#0}" != "$value" ]; do
      value=${value#0}
    done
    [ -n "$value" ] || value=0
    case " $seen_issue_numbers " in
      *" $value "*) fail "multiple issue files exist for $prefix-$(printf '%03d' "$value")" ;;
    esac
    seen_issue_numbers="$seen_issue_numbers $value"
    [ "$value" -gt "$high" ] && high=$value
  done
  echo "$high"
}

scan_reservation_claims() {
  reservation_root=$1
  requested_prefix=$2
  reservation_high=0
  reservation_request_mappings=

  require_enumerable_directory "$reservation_root"
  for reservation_claim in "$reservation_root"/ISSUE-*; do
    if [ ! -e "$reservation_claim" ] && [ ! -L "$reservation_claim" ]; then
      continue
    fi
    reservation_name=${reservation_claim##*/}
    reservation_issue_id=${reservation_name#ISSUE-}
    validate_issue_id "$reservation_issue_id"
    read_claim "$reservation_claim"

    if [ "$issue_prefix" = "$requested_prefix" ]; then
      value=$issue_number
      while [ "${value#0}" != "$value" ]; do
        value=${value#0}
      done
      [ -n "$value" ] || value=0
      [ "$value" -gt "$reservation_high" ] && reservation_high=$value
      if [ -n "$recorded_request_key" ]; then
        reservation_request_mappings="$reservation_request_mappings $recorded_owner|$recorded_request_key|$reservation_issue_id"
      fi
    fi
  done
}

find_request_reservation() {
  requested_owner=$1
  requested_key=$2
  reserved_issue_id=
  for reservation_mapping in $reservation_request_mappings; do
    mapping_owner=${reservation_mapping%%|*}
    mapping_rest=${reservation_mapping#*|}
    mapping_key=${mapping_rest%%|*}
    if [ "$mapping_owner" = "$requested_owner" ] && [ "$mapping_key" = "$requested_key" ]; then
      reserved_issue_id=${mapping_rest#*|}
      return
    fi
  done
}

reserve_requested_ids() {
  siw_dir=$1
  prefix=$2
  owner=$3
  max_attempts=$4
  output_mode=$5
  shift 5
  lock_claim="$siw_dir/.issue-publication.lock"
  reservation_root="$siw_dir/.issue-id-reservations"

  require_publication_owner "$lock_claim" "$owner"
  mkdir -p "$siw_dir/issues"
  prepare_reservation_root "$reservation_root"
  scan_reservation_claims "$reservation_root" "$prefix"

  overview_high=$(overview_high_watermark "$siw_dir/OPEN_ISSUES_OVERVIEW.md" "$prefix")
  issue_high=$(path_high_watermark "$siw_dir/issues" "$prefix" '.md')
  high=$overview_high
  [ "$issue_high" -gt "$high" ] && high=$issue_high
  [ "$reservation_high" -gt "$high" ] && high=$reservation_high
  candidate=$((high + 1))

  for request_key in "$@"; do
    if [ -n "$request_key" ]; then
      validate_request_key "$request_key"
      find_request_reservation "$owner" "$request_key"
      if [ -n "$reserved_issue_id" ]; then
        if [ "$output_mode" = pairs ]; then
          printf '%s %s\n' "$request_key" "$reserved_issue_id"
        else
          printf '%s\n' "$reserved_issue_id"
        fi
        continue
      fi
    fi

    attempt=1
    while [ "$attempt" -le "$max_attempts" ]; do
      number=$(printf '%03d' "$candidate")
      issue_id="$prefix-$number"
      reservation_claim="$reservation_root/ISSUE-$issue_id"
      if create_owned_claim "$reservation_claim" "$owner" "$request_key"; then
        [ -z "$request_key" ] || reservation_request_mappings="$reservation_request_mappings $owner|$request_key|$issue_id"
        if [ "$output_mode" = pairs ]; then
          printf '%s %s\n' "$request_key" "$issue_id"
        else
          printf '%s\n' "$issue_id"
        fi
        candidate=$((candidate + 1))
        break
      fi
      if [ ! -e "$reservation_claim" ] && [ ! -L "$reservation_claim" ]; then
        fail "could not create reservation $reservation_claim: $claim_error"
      fi
      if [ -n "$request_key" ] && [ -f "$reservation_claim" ] && [ ! -L "$reservation_claim" ]; then
        read_claim "$reservation_claim"
        if [ "$recorded_owner" = "$owner" ] && [ "$recorded_request_key" = "$request_key" ]; then
          reservation_request_mappings="$reservation_request_mappings $owner|$request_key|$issue_id"
          if [ "$output_mode" = pairs ]; then
            printf '%s %s\n' "$request_key" "$issue_id"
          else
            printf '%s\n' "$issue_id"
          fi
          candidate=$((candidate + 1))
          break
        fi
      fi
      candidate=$((candidate + 1))
      attempt=$((attempt + 1))
    done
    [ "$attempt" -le "$max_attempts" ] || fail "could not reserve an issue ID after $max_attempts attempts"
  done
}

reserve_id() {
  siw_dir=$1
  prefix=$2
  owner=$3
  max_attempts=$4
  request_key=${5:-}
  reserve_requested_ids "$siw_dir" "$prefix" "$owner" "$max_attempts" ids "$request_key"
}

reserve_exact_id() {
  siw_dir=$1
  issue_id=$2
  owner=$3
  lock_claim="$siw_dir/.issue-publication.lock"
  reservation_root="$siw_dir/.issue-id-reservations"
  reservation_dir="$reservation_root/ISSUE-$issue_id"

  require_publication_owner "$lock_claim" "$owner"
  mkdir -p "$siw_dir/issues"
  prepare_reservation_root "$reservation_root"
  scan_reservation_claims "$reservation_root" "$issue_prefix"
  if ! create_owned_claim "$reservation_dir" "$owner" "exact-$issue_id"; then
    if [ -e "$reservation_dir" ] || [ -L "$reservation_dir" ]; then
      read_claim "$reservation_dir"
      if [ "$recorded_owner" = "$owner" ]; then
        echo "$issue_id"
        return 0
      fi
      fail "exact issue ID is already reserved: $issue_id"
    fi
    fail "could not create reservation $reservation_dir: $claim_error"
  fi
  echo "$issue_id"
}

normalize_receipt_issue_ids() {
  receipt_issue_ids=
  for requested_issue_id in "$@"; do
    normalize_issue_id "$requested_issue_id"
    case " $receipt_issue_ids " in
      *" $normalized_issue_id "*) fail "publication receipt contains duplicate issue ID: $normalized_issue_id" ;;
    esac
    receipt_issue_ids="$receipt_issue_ids $normalized_issue_id"
  done
}

require_receipt_reservation_coverage() {
  coverage_siw_dir=$1
  coverage_owner=$2
  coverage_issue_ids=$3
  reservation_root="$coverage_siw_dir/.issue-id-reservations"
  if [ ! -e "$reservation_root" ] && [ ! -L "$reservation_root" ]; then
    return
  fi
  [ ! -L "$reservation_root" ] || fail "reservation root must not be a symlink: $reservation_root"
  require_enumerable_directory "$reservation_root"
  for reservation_claim in "$reservation_root"/ISSUE-*; do
    if [ ! -e "$reservation_claim" ] && [ ! -L "$reservation_claim" ]; then
      continue
    fi
    reservation_issue_id=${reservation_claim##*/ISSUE-}
    validate_issue_id "$reservation_issue_id"
    read_claim "$reservation_claim"
    case " $coverage_issue_ids " in
      *" $reservation_issue_id "*)
        [ "$recorded_owner" = "$coverage_owner" ] \
          || fail "publication receipt issue ID is reserved by a different owner: $reservation_issue_id"
        ;;
      *)
        [ "$recorded_owner" != "$coverage_owner" ] \
          || fail "publication receipt omits owned reservation: $reservation_issue_id"
        ;;
    esac
  done
}

validate_receipt_views() {
  view_state_file=$1
  view_issue_ids=$2
  view_baseline_file=${3:-}
  [ -n "$view_baseline_file" ] || view_baseline_file=/dev/null
  if ! view_error=$(awk -v requested="$view_issue_ids" -v baseline_file="$view_baseline_file" '
    BEGIN {
      count = split(requested, values, /[[:space:]]+/)
      for (idx = 1; idx <= count; idx++) {
        if (values[idx] != "") {
          ids[++id_count] = values[idx]
          wanted[values[idx]] = 1
        }
      }
    }
    FILENAME == baseline_file {
      if ($1 == "issue" && wanted[$2]) {
        baseline_issue_count[$2]++
        if ($3 == "1") baseline_heading_valid[$2]++
      } else if ($1 == "overview-issue" && wanted[$2]) {
        baseline_overview_count[$2]++
      } else if ($1 == "log-issue" && wanted[$2]) {
        baseline_log_count[$2]++
      }
      next
    }
    $1 == "issue" && wanted[$2] {
      issue_count[$2]++
      if ($3 == "1") heading_valid[$2]++
    }
    $1 == "overview-issue" && wanted[$2] { overview_count[$2]++ }
    $1 == "log-issue" && wanted[$2] { log_count[$2]++ }
    END {
      for (idx = 1; idx <= id_count; idx++) {
        id = ids[idx]
        if (issue_count[id] == 0) {
          removed_from_current_views = overview_count[id] == 0
          canonical_in_baseline = baseline_issue_count[id] == 1 \
            && baseline_heading_valid[id] == 1 \
            && baseline_overview_count[id] == 1 \
            && baseline_log_count[id] > 0
          if (removed_from_current_views && canonical_in_baseline) {
            continue
          }
          print "cannot publish receipt before the issue file exists: " id
          exit 1
        }
        if (issue_count[id] != 1) {
          print "multiple issue files exist for " id
          exit 1
        }
        if (heading_valid[id] != 1) {
          print "issue file heading does not identify " id
          exit 1
        }
        if (overview_count[id] == 0) {
          print "overview does not reference " id " in an issue row"
          exit 1
        }
        if (overview_count[id] != 1) {
          print "overview contains multiple issue rows for " id
          exit 1
        }
        if (log_count[id] == 0) {
          print "log does not reference " id " in a publication entry"
          exit 1
        }
      }
    }
  ' "$view_baseline_file" "$view_state_file"); then
    fail "$view_error"
  fi
}

derive_changed_issue_ids() {
  baseline_manifest=$1
  current_manifest=$2
  cleanup_changed_ids_temp
  changed_ids_temp=$(umask 077 && mktemp "${TMPDIR:-/tmp}/siw-publication-changed-ids.XXXXXX") \
    || fail "could not prepare changed issue validation"
  install_cleanup_traps
  awk '
    function remember(side, kind, id, line, key) {
      key = kind SUBSEP id
      all_ids[id] = 1
      if (side == "baseline") baseline[key] = baseline[key] line "\n"
      else current[key] = current[key] line "\n"
    }
    function consume(side, line, kind, id, key) {
      kind = $1
      if (kind == "overview" || kind == "log") {
        if (side == "baseline") raw_baseline[kind] = $2
        else raw_current[kind] = $2
      } else if (kind == "overview-general-parallelization") {
        if (side == "baseline") baseline_general_parallelization = baseline_general_parallelization line "\n"
        else current_general_parallelization = current_general_parallelization line "\n"
      } else if (kind == "issue" || kind == "overview-issue" || kind == "log-issue") {
        remember(side, kind, $2, line)
      } else if (kind == "other-issue") {
        key = line
        all_other[key] = 1
        if (side == "baseline") baseline_other[key] = 1
        else current_other[key] = 1
      }
    }
    FNR == NR { consume("baseline", $0); next }
    { consume("current", $0) }
    END {
      for (id in all_ids) {
        issue_key = "issue" SUBSEP id
        overview_key = "overview-issue" SUBSEP id
        log_key = "log-issue" SUBSEP id
        if (baseline[issue_key] != current[issue_key]) changed[id] = 1
        if (baseline[overview_key] != current[overview_key]) {
          changed[id] = 1
          overview_attributed = 1
        }
        if (baseline[log_key] != current[log_key]) {
          changed[id] = 1
          log_attributed = 1
        }
      }
      if (baseline_general_parallelization != current_general_parallelization) {
        for (id in all_ids) {
          issue_key = "issue" SUBSEP id
          if (id ~ /^G-/ && baseline[issue_key] != current[issue_key]) {
            general_parallelization_attributed = 1
          }
        }
        if (general_parallelization_attributed) overview_attributed = 1
      }
      for (key in all_other) {
        if (baseline_other[key] != current_other[key]) other_changed = 1
      }
      for (id in changed) print id
      if (raw_baseline["overview"] != raw_current["overview"] && !overview_attributed) {
        print "__UNATTRIBUTED_OVERVIEW__"
      }
      if (raw_baseline["log"] != raw_current["log"] && !log_attributed) {
        print "__UNATTRIBUTED_LOG__"
      }
      if (other_changed) print "__UNATTRIBUTED_ISSUE__"
    }
  ' "$baseline_manifest" "$current_manifest" > "$changed_ids_temp" \
    || fail "could not compare publication baseline with current state"
}

require_changed_ids_in_receipt() {
  changed_receipt_issue_ids=$1
  derive_changed_issue_ids "$baseline_state_temp" "$state_temp"
  while IFS= read -r changed_issue_id || [ -n "$changed_issue_id" ]; do
    case "$changed_issue_id" in
      __UNATTRIBUTED_OVERVIEW__)
        fail "overview changed without a canonical issue-row change"
        ;;
      __UNATTRIBUTED_LOG__)
        fail "log changed without a recognized publication entry"
        ;;
      __UNATTRIBUTED_ISSUE__)
        fail "a noncanonical issue file changed during publication"
        ;;
    esac
    case " $changed_receipt_issue_ids " in
      *" $changed_issue_id "*) ;;
      *) fail "publication receipt omits changed issue ID: $changed_issue_id" ;;
    esac
  done < "$changed_ids_temp"
}

verify_publication_receipt_against_state() {
  siw_dir=$1
  owner=$2
  requested_receipt_issue_ids=$3
  receipt_file="$siw_dir/.issue-publication.receipt"
  [ -f "$receipt_file" ] && [ ! -L "$receipt_file" ] \
    || fail "publication receipt is required before ownership can be released"
  if ! exec 3< "$receipt_file"; then
    fail "could not read publication receipt: $receipt_file"
  fi
  IFS=' ' read -r receipt_record receipt_value receipt_extra <&3 || true
  [ "$receipt_record" = version ] && [ "$receipt_value" = 2 ] && [ -z "$receipt_extra" ] \
    || fail "publication receipt has an invalid version record"
  IFS=' ' read -r receipt_record receipt_value receipt_extra <&3 || true
  [ "$receipt_record" = owner ] && [ -n "$receipt_value" ] && [ -z "$receipt_extra" ] \
    || fail "publication receipt has an invalid owner record"
  validate_owner "$receipt_value"
  [ "$receipt_value" = "$owner" ] || fail "publication receipt belongs to a different owner"
  IFS=' ' read -r receipt_record receipt_value receipt_extra <&3 || true
  [ "$receipt_record" = state ] && [ -z "$receipt_extra" ] \
    || fail "publication receipt has an invalid state record"
  validate_hash "$receipt_value" "publication receipt state hash"
  receipt_state_hash=$receipt_value
  IFS=' ' read -r receipt_record receipt_value receipt_extra <&3 || true
  [ "$receipt_record" = overview ] && [ -z "$receipt_extra" ] \
    || fail "publication receipt has an invalid overview record"
  validate_hash "$receipt_value" "publication receipt overview hash"
  receipt_overview_hash=$receipt_value
  IFS=' ' read -r receipt_record receipt_value receipt_extra <&3 || true
  [ "$receipt_record" = log ] && [ -z "$receipt_extra" ] \
    || fail "publication receipt has an invalid log record"
  validate_hash "$receipt_value" "publication receipt log hash"
  receipt_log_hash=$receipt_value

  verified_receipt_issue_ids=
  receipt_issue_count=0
  while
    receipt_record=
    receipt_issue_id=
    receipt_extra=
    IFS=' ' read -r receipt_record receipt_issue_id receipt_extra <&3 \
      || [ -n "$receipt_record$receipt_issue_id$receipt_extra" ]
  do
    [ "$receipt_record" = issue ] && [ -n "$receipt_issue_id" ] && [ -z "$receipt_extra" ] \
      || fail "publication receipt has an invalid issue record"
    validate_issue_id "$receipt_issue_id"
    case " $verified_receipt_issue_ids " in
      *" $receipt_issue_id "*) fail "publication receipt contains duplicate issue ID: $receipt_issue_id" ;;
    esac
    verified_receipt_issue_ids="$verified_receipt_issue_ids $receipt_issue_id"
    receipt_issue_count=$((receipt_issue_count + 1))
  done
  exec 3<&-

  [ "$overview_hash" = "$receipt_overview_hash" ] \
    || fail "publication receipt does not match the current overview"
  [ "$log_hash" = "$receipt_log_hash" ] \
    || fail "publication receipt does not match the current log"
  [ "$publication_state_hash" = "$receipt_state_hash" ] \
    || fail "publication receipt does not match the current SIW issue state"
  if [ "$receipt_issue_count" -eq 0 ] && [ -n "$publication_baseline_hash" ]; then
    fail "publication receipt must contain at least one issue record for non-legacy publication"
  fi
  for requested_issue_id in $requested_receipt_issue_ids; do
    case " $verified_receipt_issue_ids " in
      *" $requested_issue_id "*) ;;
      *) fail "publication receipt does not include issue ID: $requested_issue_id" ;;
    esac
  done
  require_receipt_reservation_coverage "$siw_dir" "$owner" "$verified_receipt_issue_ids"
  if [ -n "$publication_baseline_hash" ]; then
    ensure_publication_baseline "$siw_dir" "$owner"
  fi
  validate_receipt_views "$state_temp" "$verified_receipt_issue_ids" "${baseline_state_temp:-}"
  if [ -n "$publication_baseline_hash" ]; then
    require_changed_ids_in_receipt "$verified_receipt_issue_ids"
  fi
}

publish_receipt() {
  siw_dir=$1
  owner=$2
  shift 2
  require_publication_owner "$siw_dir/.issue-publication.lock" "$owner"
  normalize_receipt_issue_ids "$@"
  if [ -z "$receipt_issue_ids" ] && [ -n "$publication_baseline_hash" ]; then
    fail "publish-receipt requires at least one issue ID for non-legacy publication"
  fi
  calculate_publication_state "$siw_dir"
  [ -z "$publication_log_missing" ] \
    || fail "SIW log must exist before a publication receipt can be written"
  if [ -n "$publication_baseline_hash" ]; then
    ensure_publication_baseline "$siw_dir" "$owner"
  fi
  require_receipt_reservation_coverage "$siw_dir" "$owner" "$receipt_issue_ids"
  validate_receipt_views "$state_temp" "$receipt_issue_ids" "${baseline_state_temp:-}"
  if [ -n "$publication_baseline_hash" ]; then
    require_changed_ids_in_receipt "$receipt_issue_ids"
  fi

  receipt_file="$siw_dir/.issue-publication.receipt"
  if [ -e "$receipt_file" ] || [ -L "$receipt_file" ]; then
    [ -f "$receipt_file" ] && [ ! -L "$receipt_file" ] \
      || fail "publication receipt is not a regular file: $receipt_file"
  fi
  receipt_temp=$(umask 077 && mktemp "$siw_dir/.siw-publication-receipt.XXXXXX") \
    || fail "could not prepare publication receipt in $siw_dir"
  install_cleanup_traps
  {
    printf 'version 2\n'
    printf 'owner %s\n' "$owner"
    printf 'state %s\n' "$publication_state_hash"
    printf 'overview %s\n' "$overview_hash"
    printf 'log %s\n' "$log_hash"
    for receipt_issue_id in $receipt_issue_ids; do
      printf 'issue %s\n' "$receipt_issue_id"
    done
  } > "$receipt_temp" || fail "could not prepare publication receipt: $receipt_temp"
  mv "$receipt_temp" "$receipt_file" || fail "could not publish receipt: $receipt_file"
  receipt_temp=
  verify_publication_receipt_against_state "$siw_dir" "$owner" "$receipt_issue_ids"
}

verify_publication_receipt() {
  siw_dir=$1
  owner=$2
  shift 2
  require_publication_owner "$siw_dir/.issue-publication.lock" "$owner"
  normalize_receipt_issue_ids "$@"
  calculate_publication_state "$siw_dir"
  [ -z "$publication_log_missing" ] \
    || fail "publication receipt does not match the current log"
  verify_publication_receipt_against_state "$siw_dir" "$owner" "$receipt_issue_ids"
}

require_publication_evidence() {
  siw_dir=$1
  owner=$2
  shift 2
  receipt_file="$siw_dir/.issue-publication.receipt"
  if [ -e "$receipt_file" ] || [ -L "$receipt_file" ]; then
    verify_publication_receipt "$siw_dir" "$owner" "$@"
    return
  fi
  require_publication_owner "$siw_dir/.issue-publication.lock" "$owner"
  [ -n "$publication_baseline_hash" ] \
    || fail "publication receipt is required before ownership can be released"
  calculate_publication_state "$siw_dir"
  ensure_publication_baseline "$siw_dir" "$owner"
  [ "$publication_state_hash" = "$publication_baseline_hash" ] \
    || fail "publication receipt is required because SIW state changed"
}

release_reserved_ids() {
  release_siw_dir=$1
  release_owner=$2
  shift 2
  [ "$#" -ge 1 ] || fail "release-batch requires at least one issue ID"
  require_publication_owner "$release_siw_dir/.issue-publication.lock" "$release_owner"

  release_issue_ids=
  release_claim_count=0
  for requested_issue_id in "$@"; do
    normalize_issue_id "$requested_issue_id"
    release_issue_id=$normalized_issue_id
    case " $release_issue_ids " in
      *" $release_issue_id "*) fail "release contains duplicate issue ID: $release_issue_id" ;;
    esac
    release_issue_ids="$release_issue_ids $release_issue_id"
    locate_issue_file "$release_siw_dir" "$release_issue_id"
    [ -n "$issue_file" ] \
      || fail "cannot release $release_issue_id before its issue file exists; use abandon only before publication"
    reservation_claim="$release_siw_dir/.issue-id-reservations/ISSUE-$release_issue_id"
    if [ ! -e "$reservation_claim" ] && [ ! -L "$reservation_claim" ]; then
      continue
    fi
    [ -f "$reservation_claim" ] && [ ! -L "$reservation_claim" ] \
      || fail "reservation is not a regular ownership claim: $release_issue_id"
    require_owner "$reservation_claim" "$release_owner"
    release_claim_count=$((release_claim_count + 1))
  done

  [ "$release_claim_count" -gt 0 ] || return 0
  require_publication_evidence "$release_siw_dir" "$release_owner" "$@"
  for release_issue_id in $release_issue_ids; do
    reservation_claim="$release_siw_dir/.issue-id-reservations/ISSUE-$release_issue_id"
    if [ ! -e "$reservation_claim" ] && [ ! -L "$reservation_claim" ]; then
      continue
    fi
    remove_owned_claim "$reservation_claim" "$release_owner"
  done
}

[ "$#" -ge 1 ] || usage
command=$1
shift

case "$command" in
  new-owner)
    [ "$#" -eq 0 ] || usage
    new_owner
    ;;
  acquire)
    [ "$#" -ge 2 ] && [ "$#" -le 3 ] || usage
    resolve_siw_dir "$1"
    owner=$2
    max_attempts=${3:-30}
    validate_owner "$owner"
    validate_attempts "$max_attempts"
    acquire_operation_lock "$siw_dir" "$owner"
    acquire_publication "$siw_dir" "$owner" "$max_attempts"
    ;;
  reserve)
    [ "$#" -ge 3 ] && [ "$#" -le 5 ] || usage
    resolve_siw_dir "$1"
    prefix=$2
    owner=$3
    max_attempts=${4:-100}
    validate_prefix "$prefix"
    validate_owner "$owner"
    validate_attempts "$max_attempts"
    request_key=${5:-}
    [ -z "$request_key" ] || validate_request_key "$request_key"
    acquire_operation_lock "$siw_dir" "$owner"
    reserve_id "$siw_dir" "$prefix" "$owner" "$max_attempts" "$request_key"
    ;;
  reserve-batch)
    [ "$#" -ge 5 ] || usage
    resolve_siw_dir "$1"
    prefix=$2
    owner=$3
    max_attempts=$4
    shift 4
    validate_prefix "$prefix"
    validate_owner "$owner"
    validate_attempts "$max_attempts"
    for request_key in "$@"; do
      validate_request_key "$request_key"
    done
    acquire_operation_lock "$siw_dir" "$owner"
    reserve_requested_ids "$siw_dir" "$prefix" "$owner" "$max_attempts" pairs "$@"
    ;;
  reserve-exact)
    [ "$#" -eq 3 ] || usage
    resolve_siw_dir "$1"
    normalize_issue_id "$2"
    issue_id=$normalized_issue_id
    owner=$3
    validate_owner "$owner"
    acquire_operation_lock "$siw_dir" "$owner"
    reserve_exact_id "$siw_dir" "$issue_id" "$owner"
    ;;
  publish-receipt)
    [ "$#" -ge 2 ] || usage
    resolve_siw_dir "$1"
    owner=$2
    validate_owner "$owner"
    shift 2
    acquire_operation_lock "$siw_dir" "$owner"
    publish_receipt "$siw_dir" "$owner" "$@"
    ;;
  verify-receipt)
    [ "$#" -ge 2 ] || usage
    resolve_siw_dir "$1"
    owner=$2
    validate_owner "$owner"
    shift 2
    acquire_operation_lock "$siw_dir" "$owner"
    verify_publication_receipt "$siw_dir" "$owner" "$@"
    ;;
  release)
    [ "$#" -eq 3 ] || usage
    resolve_siw_dir "$1"
    normalize_issue_id "$2"
    issue_id=$normalized_issue_id
    owner=$3
    validate_owner "$owner"
    acquire_operation_lock "$siw_dir" "$owner"
    release_reserved_ids "$siw_dir" "$owner" "$issue_id"
    ;;
  release-batch)
    [ "$#" -ge 3 ] || usage
    resolve_siw_dir "$1"
    owner=$2
    validate_owner "$owner"
    shift 2
    acquire_operation_lock "$siw_dir" "$owner"
    release_reserved_ids "$siw_dir" "$owner" "$@"
    ;;
  abandon)
    [ "$#" -eq 3 ] || usage
    resolve_siw_dir "$1"
    normalize_issue_id "$2"
    issue_id=$normalized_issue_id
    owner=$3
    validate_owner "$owner"
    acquire_operation_lock "$siw_dir" "$owner"
    require_publication_owner "$siw_dir/.issue-publication.lock" "$owner"
    locate_issue_file "$siw_dir" "$issue_id"
    [ -z "$issue_file" ] \
      || fail "cannot abandon $issue_id after its issue file exists; recover all three SIW views first"
    [ -n "$publication_baseline_hash" ] \
      || fail "cannot abandon a legacy reservation without a trustworthy publication baseline"
    calculate_publication_state "$siw_dir"
    ensure_publication_baseline "$siw_dir" "$owner"
    [ "$publication_state_hash" = "$publication_baseline_hash" ] \
      || fail "cannot abandon $issue_id after SIW state changed; recover all three SIW views first"
    reservation_claim="$siw_dir/.issue-id-reservations/ISSUE-$issue_id"
    if [ ! -e "$reservation_claim" ] && [ ! -L "$reservation_claim" ]; then
      exit 0
    fi
    [ -f "$reservation_claim" ] && [ ! -L "$reservation_claim" ] || fail "reservation is not a regular ownership claim: $issue_id"
    remove_owned_claim "$reservation_claim" "$owner"
    ;;
  release-publication)
    [ "$#" -eq 2 ] || usage
    resolve_siw_dir "$1"
    owner=$2
    validate_owner "$owner"
    acquire_operation_lock "$siw_dir" "$owner"
    lock_claim="$siw_dir/.issue-publication.lock"
    if [ ! -e "$lock_claim" ] && [ ! -L "$lock_claim" ]; then
      remove_owned_publication_receipt "$siw_dir" "$owner"
      remove_owned_publication_baseline "$siw_dir" "$owner"
      exit 0
    fi
    require_publication_owner "$lock_claim" "$owner"
    require_no_owned_reservations "$siw_dir" "$owner"
    require_publication_evidence "$siw_dir" "$owner"
    remove_owned_claim "$lock_claim" "$owner"
    remove_owned_publication_receipt "$siw_dir" "$owner"
    remove_owned_publication_baseline "$siw_dir" "$owner"
    ;;
  *) usage ;;
esac
