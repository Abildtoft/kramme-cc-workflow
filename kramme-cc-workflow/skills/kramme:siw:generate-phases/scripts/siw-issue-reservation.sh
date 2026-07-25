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

validate_issue_id() {
  issue_prefix=${1%-*}
  issue_number=${1##*-}
  validate_prefix "$issue_prefix"
  case "$issue_number" in
    '' | *[!0-9]* | ? | ??) fail "issue ID must look like G-001 or P1-001" ;;
  esac
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
  if command -v sha256sum > /dev/null 2>&1; then
    hash_output=$(sha256sum "$hash_path") || fail "could not hash file: $hash_path"
    calculated_hash=${hash_output%% *}
  elif command -v shasum > /dev/null 2>&1; then
    hash_output=$(shasum -a 256 "$hash_path") || fail "could not hash file: $hash_path"
    calculated_hash=${hash_output%% *}
  elif command -v openssl > /dev/null 2>&1; then
    hash_output=$(openssl dgst -sha256 "$hash_path") || fail "could not hash file: $hash_path"
    calculated_hash=${hash_output##* }
  else
    fail "could not hash SIW publication state; install sha256sum, shasum, or openssl"
  fi
  validate_hash "$calculated_hash" "calculated hash"
}

hash_data() {
  hash_input=$1
  if command -v sha256sum > /dev/null 2>&1; then
    hash_output=$(printf '%s' "$hash_input" | sha256sum) || fail "could not hash publication identity"
    calculated_hash=${hash_output%% *}
  elif command -v shasum > /dev/null 2>&1; then
    hash_output=$(printf '%s' "$hash_input" | shasum -a 256) || fail "could not hash publication identity"
    calculated_hash=${hash_output%% *}
  elif command -v openssl > /dev/null 2>&1; then
    hash_output=$(printf '%s' "$hash_input" | openssl dgst -sha256) || fail "could not hash publication identity"
    calculated_hash=${hash_output##* }
  else
    fail "could not hash SIW publication state; install sha256sum, shasum, or openssl"
  fi
  validate_hash "$calculated_hash" "calculated hash"
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
  trap 'cleanup_claim_temp; cleanup_state_temp; cleanup_receipt_temp; cleanup_operation_lock' 0
  trap 'cleanup_claim_temp; cleanup_state_temp; cleanup_receipt_temp; cleanup_operation_lock; exit 1' 1 2 15
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
  state_temp=$(umask 077 && mktemp "$publication_siw_dir/.siw-publication-state.XXXXXX") \
    || fail "could not prepare SIW publication state in $publication_siw_dir"
  install_cleanup_traps

  [ -f "$overview_path" ] && [ ! -L "$overview_path" ] \
    || fail "SIW overview must be a non-symlink regular file: $overview_path"
  hash_file "$overview_path"
  printf 'overview %s\n' "$calculated_hash" > "$state_temp" \
    || fail "could not write temporary SIW publication state: $state_temp"

  if [ ! -e "$log_path" ] && [ ! -L "$log_path" ]; then
    printf 'log missing\n' >> "$state_temp" \
      || fail "could not write temporary SIW publication state: $state_temp"
  else
    [ -f "$log_path" ] && [ ! -L "$log_path" ] \
      || fail "SIW log must be a non-symlink regular file: $log_path"
    hash_file "$log_path"
    printf 'log %s\n' "$calculated_hash" >> "$state_temp" \
      || fail "could not write temporary SIW publication state: $state_temp"
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
      issue_name=${issue_path##*/}
      hash_data "issues/$issue_name"
      issue_identity_hash=$calculated_hash
      hash_file "$issue_path"
      printf 'issue %s %s\n' "$issue_identity_hash" "$calculated_hash" >> "$state_temp" \
        || fail "could not write temporary SIW publication state: $state_temp"
    done
  fi

  hash_file "$state_temp"
  publication_state_hash=$calculated_hash
  cleanup_state_temp
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
  [ "$receipt_record" = version ] && [ "$receipt_value" = 1 ] && [ -z "$receipt_extra" ] \
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
    calculate_publication_state "$siw_dir"
    if create_owned_claim "$lock_claim" "$owner" "state:$publication_state_hash"; then
      clear_stale_publication_receipt "$siw_dir"
      validate_reservation_state "$siw_dir"
      return 0
    fi
    last_claim_error=$claim_error
    if [ -f "$lock_claim" ] && [ ! -L "$lock_claim" ]; then
      read_claim "$lock_claim"
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
        validate_reservation_state "$siw_dir"
        return 0
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

require_issue_reference() {
  reference_file=$1
  reference_issue_id=$2
  reference_label=$3
  if ! LC_ALL=C grep -Eq "(^|[^A-Za-z0-9])(ISSUE-)?$reference_issue_id([^A-Za-z0-9]|$)" "$reference_file"; then
    fail "$reference_label does not reference $reference_issue_id"
  fi
}

publish_receipt() {
  siw_dir=$1
  owner=$2
  shift 2
  require_publication_owner "$siw_dir/.issue-publication.lock" "$owner"
  if [ "$#" -eq 0 ] && [ -n "$publication_baseline_hash" ]; then
    fail "publish-receipt requires at least one issue ID for non-legacy publication"
  fi

  overview_path="$siw_dir/OPEN_ISSUES_OVERVIEW.md"
  log_path="$siw_dir/LOG.md"
  [ -f "$overview_path" ] && [ ! -L "$overview_path" ] \
    || fail "SIW overview must be a non-symlink regular file: $overview_path"
  [ -f "$log_path" ] && [ ! -L "$log_path" ] \
    || fail "SIW log must be a non-symlink regular file: $log_path"
  hash_file "$overview_path"
  receipt_overview_hash=$calculated_hash
  hash_file "$log_path"
  receipt_log_hash=$calculated_hash
  calculate_publication_state "$siw_dir"
  receipt_state_hash=$publication_state_hash

  receipt_file="$siw_dir/.issue-publication.receipt"
  if [ -e "$receipt_file" ] || [ -L "$receipt_file" ]; then
    [ -f "$receipt_file" ] && [ ! -L "$receipt_file" ] \
      || fail "publication receipt is not a regular file: $receipt_file"
  fi
  receipt_temp=$(umask 077 && mktemp "$siw_dir/.siw-publication-receipt.XXXXXX") \
    || fail "could not prepare publication receipt in $siw_dir"
  install_cleanup_traps
  {
    printf 'version 1\n'
    printf 'owner %s\n' "$owner"
    printf 'state %s\n' "$receipt_state_hash"
    printf 'overview %s\n' "$receipt_overview_hash"
    printf 'log %s\n' "$receipt_log_hash"
  } > "$receipt_temp" || fail "could not prepare publication receipt: $receipt_temp"

  receipt_issue_ids=
  for requested_issue_id in "$@"; do
    normalize_issue_id "$requested_issue_id"
    receipt_issue_id=$normalized_issue_id
    case " $receipt_issue_ids " in
      *" $receipt_issue_id "*) fail "publication receipt contains duplicate issue ID: $receipt_issue_id" ;;
    esac
    receipt_issue_ids="$receipt_issue_ids $receipt_issue_id"
    locate_issue_file "$siw_dir" "$receipt_issue_id"
    [ -n "$issue_file" ] || fail "cannot publish receipt before the issue file exists: $receipt_issue_id"
    require_issue_reference "$overview_path" "$receipt_issue_id" "overview"
    require_issue_reference "$log_path" "$receipt_issue_id" "log"
    issue_name=${issue_file##*/}
    hash_data "issues/$issue_name"
    receipt_identity_hash=$calculated_hash
    hash_file "$issue_file"
    printf 'issue %s %s %s\n' "$receipt_issue_id" "$receipt_identity_hash" "$calculated_hash" >> "$receipt_temp" \
      || fail "could not prepare publication receipt: $receipt_temp"
  done

  mv "$receipt_temp" "$receipt_file" || fail "could not publish receipt: $receipt_file"
  receipt_temp=
  verify_publication_receipt "$siw_dir" "$owner" "$@"
}

verify_publication_receipt() {
  siw_dir=$1
  owner=$2
  shift 2
  require_publication_owner "$siw_dir/.issue-publication.lock" "$owner"
  receipt_file="$siw_dir/.issue-publication.receipt"
  [ -f "$receipt_file" ] && [ ! -L "$receipt_file" ] \
    || fail "publication receipt is required before ownership can be released"

  if ! exec 3< "$receipt_file"; then
    fail "could not read publication receipt: $receipt_file"
  fi
  receipt_record=
  receipt_value=
  receipt_extra=
  IFS=' ' read -r receipt_record receipt_value receipt_extra <&3 || true
  [ "$receipt_record" = version ] && [ "$receipt_value" = 1 ] && [ -z "$receipt_extra" ] \
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

  overview_path="$siw_dir/OPEN_ISSUES_OVERVIEW.md"
  log_path="$siw_dir/LOG.md"
  [ -f "$overview_path" ] && [ ! -L "$overview_path" ] \
    || fail "SIW overview must be a non-symlink regular file: $overview_path"
  [ -f "$log_path" ] && [ ! -L "$log_path" ] \
    || fail "SIW log must be a non-symlink regular file: $log_path"
  hash_file "$overview_path"
  [ "$calculated_hash" = "$receipt_overview_hash" ] \
    || fail "publication receipt does not match the current overview"
  hash_file "$log_path"
  [ "$calculated_hash" = "$receipt_log_hash" ] \
    || fail "publication receipt does not match the current log"

  verified_receipt_issue_ids=
  receipt_issue_count=0
  while
    receipt_record=
    receipt_issue_id=
    receipt_identity_hash=
    receipt_content_hash=
    receipt_extra=
    IFS=' ' read -r receipt_record receipt_issue_id receipt_identity_hash receipt_content_hash receipt_extra <&3 \
      || [ -n "$receipt_record$receipt_issue_id$receipt_identity_hash$receipt_content_hash$receipt_extra" ]
  do
    [ "$receipt_record" = issue ] && [ -n "$receipt_issue_id" ] \
      && [ -n "$receipt_identity_hash" ] && [ -n "$receipt_content_hash" ] \
      && [ -z "$receipt_extra" ] || fail "publication receipt has an invalid issue record"
    validate_issue_id "$receipt_issue_id"
    validate_hash "$receipt_identity_hash" "publication receipt issue identity hash"
    validate_hash "$receipt_content_hash" "publication receipt issue content hash"
    case " $verified_receipt_issue_ids " in
      *" $receipt_issue_id "*) fail "publication receipt contains duplicate issue ID: $receipt_issue_id" ;;
    esac
    verified_receipt_issue_ids="$verified_receipt_issue_ids $receipt_issue_id"
    receipt_issue_count=$((receipt_issue_count + 1))
    locate_issue_file "$siw_dir" "$receipt_issue_id"
    [ -n "$issue_file" ] || fail "publication receipt issue file is missing: $receipt_issue_id"
    require_issue_reference "$overview_path" "$receipt_issue_id" "overview"
    require_issue_reference "$log_path" "$receipt_issue_id" "log"
    issue_name=${issue_file##*/}
    hash_data "issues/$issue_name"
    [ "$calculated_hash" = "$receipt_identity_hash" ] \
      || fail "publication receipt does not match the current issue identity: $receipt_issue_id"
    hash_file "$issue_file"
    [ "$calculated_hash" = "$receipt_content_hash" ] \
      || fail "publication receipt does not match the current issue file: $receipt_issue_id"
  done
  exec 3<&-
  if [ "$receipt_issue_count" -eq 0 ] && [ -n "$publication_baseline_hash" ]; then
    fail "publication receipt must contain at least one issue record for non-legacy publication"
  fi

  calculate_publication_state "$siw_dir"
  [ "$publication_state_hash" = "$receipt_state_hash" ] \
    || fail "publication receipt does not match the current SIW issue state"

  for requested_issue_id in "$@"; do
    normalize_issue_id "$requested_issue_id"
    case " $verified_receipt_issue_ids " in
      *" $normalized_issue_id "*) ;;
      *) fail "publication receipt does not include issue ID: $normalized_issue_id" ;;
    esac
  done
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
      exit 0
    fi
    require_publication_owner "$lock_claim" "$owner"
    require_no_owned_reservations "$siw_dir" "$owner"
    require_publication_evidence "$siw_dir" "$owner"
    remove_owned_claim "$lock_claim" "$owner"
    remove_owned_publication_receipt "$siw_dir" "$owner"
    ;;
  *) usage ;;
esac
