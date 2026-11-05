#!/usr/bin/env bash
#
# Plan and apply a guarded batch rebase of the current user's open Pull
# Requests whose head branches are checked out in clean local worktrees.
#
# plan prints a plan header, a validated push URL metadata line, and one
# tab-separated row per open PR:
#   pr branch base worktree head base_oid action reason
# action is "rebase" or "skip". apply revalidates and rebases each "rebase"
# row in order, aborts every conflicting rebase, pushes with a lease pinned to
# the planned head, and prints one row per plan row:
#   pr branch worktree result old_head new_head detail
# result is pushed, push-rejected, conflict, skipped, or error. Empty fields
# are written as "-". Exit codes: 0 every row was processed; 1 usage error or
# a failure before classification; 2 an aborted rebase did not restore its
# worktree, so later rows were not processed.

set -euo pipefail

PLAN_HEADER=$'#pr\tbranch\tbase\tworktree\thead\tbase_oid\taction\treason'
PLAN_PUSH_URL_PREFIX=$'#push-url\t'
RESULT_HEADER=$'#pr\tbranch\tworktree\tresult\told_head\tnew_head\tdetail'
ORIGIN_PUSH_URL=""
ORIGIN_REPO=""

usage() {
  echo "Usage: batch-rebase.sh plan --stack-resolver <path>" >&2
  echo "       batch-rebase.sh apply --plan <file> --stack-resolver <path>" >&2
}

die() {
  echo "$1" >&2
  exit 1
}

SUBCOMMAND="${1-}"
[ $# -gt 0 ] && shift
PLAN_FILE=""
STACK_RESOLVER=""
while [ $# -gt 0 ]; do
  case "$1" in
    --plan)
      if [ $# -lt 2 ] || [ -z "${2-}" ]; then
        die "--plan requires a value"
      fi
      PLAN_FILE="$2"
      shift 2
      ;;
    --stack-resolver)
      if [ $# -lt 2 ] || [ -z "${2-}" ]; then
        die "--stack-resolver requires a value"
      fi
      STACK_RESOLVER="$2"
      shift 2
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

case "$SUBCOMMAND" in
  plan) ;;
  apply) [ -n "$PLAN_FILE" ] || die "apply requires --plan <file>" ;;
  *)
    usage
    exit 1
    ;;
esac
[ -n "$STACK_RESOLVER" ] && [ -x "$STACK_RESOLVER" ] \
  || die "--stack-resolver must name an executable stack membership resolver"
# The resolver runs from inside each worktree, so make its path absolute.
STACK_RESOLVER="$(cd "$(dirname -- "$STACK_RESOLVER")" && pwd -P)/$(basename -- "$STACK_RESOLVER")"
git rev-parse --git-dir > /dev/null 2>&1 || die "Run batch-rebase.sh inside a Git repository."
# --no-update-refs needs Git 2.38; worktree list -z and --path-format are older.
if ! [[ "$(git version)" =~ ([0-9]+)\.([0-9]+) ]] \
  || ((BASH_REMATCH[1] < 2 || (BASH_REMATCH[1] == 2 && BASH_REMATCH[2] < 38))); then
  die "batch-rebase.sh requires Git 2.38 or newer."
fi

is_oid() {
  [[ "$1" =~ ^([0-9a-f]{40}|[0-9a-f]{64})$ ]]
}

valid_branch() {
  case "$1" in
    '' | -* | *'@{'*) return 1 ;;
  esac
  git check-ref-format --branch "$1" > /dev/null 2>&1
}

resolve_push_url() {
  local output push_url url_after_scheme url_authority url_scheme url_userinfo
  local -a push_urls=()
  if ! output=$(git remote get-url --push --all -- origin 2> /dev/null); then
    die "Remote 'origin' must have one readable push URL before batch rebasing."
  fi
  while IFS= read -r push_url; do
    [ -n "$push_url" ] || continue
    push_urls+=("$push_url")
  done <<< "$output"
  [ "${#push_urls[@]}" -eq 1 ] \
    || die "Remote 'origin' must resolve to exactly one push URL before batch rebasing."
  ORIGIN_PUSH_URL=${push_urls[0]}
  case "$ORIGIN_PUSH_URL" in
    *://*)
      url_after_scheme=${ORIGIN_PUSH_URL#*://}
      url_authority=${url_after_scheme%%/*}
      url_scheme=${ORIGIN_PUSH_URL%%://*}
      url_userinfo=""
      case "$url_authority" in *@*) url_userinfo=${url_authority%@*} ;; esac
      case "$url_scheme" in
        [Hh][Tt][Tt][Pp] | [Hh][Tt][Tt][Pp][Ss] | [Ss][Ss][Hh] | [Gg][Ii][Tt] | [Ff][Ii][Ll][Ee] | \
        [Ff][Tt][Pp] | [Ff][Tt][Pp][Ss] | [Gg][Ii][Tt]+[Ss][Ss][Hh] | [Ss][Ss][Hh]+[Gg][Ii][Tt]) ;;
        *) die "Remote 'origin' push URL uses an unsupported transport before batch rebasing." ;;
      esac
      case "$url_scheme" in
        [Hh][Tt][Tt][Pp] | [Hh][Tt][Tt][Pp][Ss])
          [ -z "$url_userinfo" ] \
            || die "Remote 'origin' push URL must not contain inline HTTP credentials before batch rebasing."
          ;;
      esac
      if [[ "$url_userinfo" == *:* ]] || [[ "$url_after_scheme" == *\?* ]] || [[ "$url_after_scheme" == *\#* ]]; then
        die "Remote 'origin' push URL contains credential-bearing data before batch rebasing."
      fi
      ;;
    *::*) die "Remote 'origin' push URL must not use executable remote-helper syntax before batch rebasing." ;;
  esac
  [ -n "$ORIGIN_PUSH_URL" ] || die "Remote 'origin' push URL is empty before batch rebasing."
  [[ "$ORIGIN_PUSH_URL" != *[[:cntrl:]]* ]] \
    || die "The origin push URL contains control characters and cannot be represented safely in the plan."
}

resolve_origin_repo() {
  command -v gh > /dev/null 2>&1 || die "batch-rebase.sh requires the gh CLI."
  ORIGIN_REPO=$(gh repo view --json nameWithOwner --jq '.nameWithOwner') \
    || die "Could not resolve the GitHub repository with gh; nothing was planned."
  case "$ORIGIN_REPO" in
    '' | *$'\t'* | *$'\n'* | */*/* | */ | /*) die "gh returned an invalid repository name; nothing was planned." ;;
    */*) ;;
    *) die "gh returned an invalid repository name; nothing was planned." ;;
  esac
}

# Prints a plan field, or "-" when it is empty or contains control bytes.
or_dash() {
  [[ -n "$1" && "$1" != *[[:cntrl:]]* ]] && printf '%s' "$1" || printf '%s' -
}

# Worktrees of this repository as parallel arrays. WT_UNAVAILABLE is 1 when
# Git marks a worktree bare, detached, locked, or prunable, or when its path
# cannot be written to the tab-separated plan, and 2 when a rebase in progress
# detached it from the branch it records.
load_worktrees() {
  local listing field path="" branch="" unavailable=0
  WT_PATHS=()
  WT_BRANCHES=()
  WT_UNAVAILABLE=()
  listing=$(mktemp "${TMPDIR:-/tmp}/batch-rebase-worktrees.XXXXXX") \
    || die "Could not create a temporary file for the worktree list."
  if ! git worktree list --porcelain -z > "$listing"; then
    rm -f "$listing"
    die "Could not list Git worktrees; nothing was planned."
  fi
  while IFS= read -r -d '' field || [ -n "$field" ]; do
    case "$field" in
      'worktree '*)
        path=${field#worktree }
        branch=""
        unavailable=0
        ;;
      'branch refs/heads/'*) branch=${field#branch refs/heads/} ;;
      bare | detached | locked | 'locked '* | prunable | 'prunable '*) unavailable=1 ;;
      '')
        add_worktree "$path" "$branch" "$unavailable"
        path=""
        ;;
    esac
  done < "$listing"
  rm -f "$listing"
  add_worktree "$path" "$branch" "$unavailable"
}

add_worktree() {
  local branch="$2" unavailable="$3" marker head_name
  [ -n "$1" ] || return 0
  case "$1" in *[[:cntrl:]]*) unavailable=1 ;; esac
  if [ -z "$branch" ] && [ -d "$1" ]; then
    for marker in rebase-merge/head-name rebase-apply/head-name; do
      head_name=$(git -C "$1" rev-parse --path-format=absolute --git-path "$marker" 2> /dev/null) || continue
      [ -f "$head_name" ] || continue
      head_name=$(cat "$head_name")
      case "$head_name" in
        refs/heads/*)
          branch=${head_name#refs/heads/}
          unavailable=2
          ;;
      esac
    done
  fi
  WT_PATHS+=("$1")
  WT_BRANCHES+=("$branch")
  WT_UNAVAILABLE+=("$unavailable")
}

# Sets FOUND_PATH and FOUND_UNAVAILABLE for the worktree that has the branch
# checked out; returns 1 when no worktree does.
find_worktree() {
  local index
  for ((index = 0; index < ${#WT_BRANCHES[@]}; index++)); do
    if [ "${WT_BRANCHES[$index]}" = "$1" ]; then
      FOUND_PATH=${WT_PATHS[$index]}
      FOUND_UNAVAILABLE=${WT_UNAVAILABLE[$index]}
      return 0
    fi
  done
  return 1
}

load_protected() {
  local configured origin_head
  PROTECTED=(main master develop)
  configured=$(git config --get kramme.baseBranch || true)
  [ -z "$configured" ] || PROTECTED+=("$configured")
  [ -z "${CONDUCTOR_DEFAULT_BRANCH:-}" ] || PROTECTED+=("$CONDUCTOR_DEFAULT_BRANCH")
  origin_head=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD || true)
  [ -z "$origin_head" ] || PROTECTED+=("${origin_head#origin/}")
}

is_protected() {
  local name
  for name in "${PROTECTED[@]}"; do
    [ "$name" = "$1" ] && return 0
  done
  return 1
}

# True when any named marker exists in the worktree's Git directory. Fails
# closed: a marker that cannot be located counts as present.
markers_present() {
  local worktree="$1" marker path
  shift
  for marker in "$@"; do
    path=$(git -C "$worktree" rev-parse --path-format=absolute --git-path "$marker" 2> /dev/null) || return 0
    [ -e "$path" ] && return 0
  done
  return 1
}

operation_in_progress() {
  markers_present "$1" rebase-merge rebase-apply MERGE_HEAD CHERRY_PICK_HEAD REVERT_HEAD BISECT_LOG
}

rebase_in_progress() {
  markers_present "$1" rebase-merge rebase-apply
}

# Prints the skip reason for an agent isolation worktree or a protected
# branch, or nothing. Needs no network access.
location_reason() {
  case "$2" in
    */.claude/worktrees/*) echo "agent isolation worktree" ;;
    *) if is_protected "$1"; then echo "protected branch"; fi ;;
  esac
}

# Prints every change, including untracked files and submodule changes that
# status configuration would otherwise hide.
clean_status() {
  git -C "$1" status --porcelain --untracked-files=all --ignore-submodules=none 2> /dev/null
}

# Returns 0 for clean hidden tracked paths, 1 when content differs, and 2
# when the hidden-path inventory cannot be inspected. Git status hides
# assume-unchanged and materialized skip-worktree edits, so compare those paths
# through a temporary index with the hiding flags cleared.
hidden_tracked_status() {
  local worktree="$1" tracked_file hidden_file index_path temp_index entry flag path hidden_status
  local -a hidden_paths=()
  tracked_file=$(mktemp "${TMPDIR:-/tmp}/batch-rebase-tracked.XXXXXX") || return 2
  hidden_file=$(mktemp "${TMPDIR:-/tmp}/batch-rebase-hidden.XXXXXX") || {
    rm -f "$tracked_file"
    return 2
  }
  temp_index=""
  cleanup_hidden() {
    rm -f "$tracked_file" "$hidden_file"
    [ -z "$temp_index" ] || rm -f "$temp_index"
  }
  if ! git -C "$worktree" ls-files -v -z > "$tracked_file"; then
    cleanup_hidden
    return 2
  fi
  while IFS= read -r -d '' entry; do
    flag=${entry:0:1}
    path=${entry:2}
    case "$flag" in
      h) printf '%s\0' "$path" >> "$hidden_file" ;;
      S | s)
        if [ -e "$worktree/$path" ] || [ -L "$worktree/$path" ]; then
          printf '%s\0' "$path" >> "$hidden_file"
        fi
        ;;
    esac
  done < "$tracked_file"
  if [ ! -s "$hidden_file" ]; then
    cleanup_hidden
    return 0
  fi
  index_path=$(git -C "$worktree" rev-parse --path-format=absolute --git-path index 2> /dev/null) || {
    cleanup_hidden
    return 2
  }
  temp_index=$(mktemp "$(dirname "$index_path")/batch-rebase-index.XXXXXX") || {
    cleanup_hidden
    return 2
  }
  if ! cp -- "$index_path" "$temp_index" \
    || ! GIT_INDEX_FILE="$temp_index" git -C "$worktree" update-index --no-assume-unchanged -z --stdin < "$hidden_file" \
    || ! GIT_INDEX_FILE="$temp_index" git -C "$worktree" update-index --no-skip-worktree -z --stdin < "$hidden_file"; then
    cleanup_hidden
    return 2
  fi
  while IFS= read -r -d '' path; do
    hidden_paths+=("$path")
  done < "$hidden_file"
  set +e
  GIT_INDEX_FILE="$temp_index" git -C "$worktree" diff-files --quiet --no-ext-diff \
    --ignore-submodules=none -- "${hidden_paths[@]}"
  hidden_status=$?
  set -e
  cleanup_hidden
  case "$hidden_status" in
    0) return 0 ;;
    1) return 1 ;;
    *) return 2 ;;
  esac
}

# Prints the skip reason for worktree state shared by plan and apply, or
# nothing when the worktree is checked out on the branch, clean, and unstacked.
worktree_reason() {
  local branch="$1" worktree="$2" status membership output
  if [ ! -d "$worktree" ] \
    || [ "$(git -C "$worktree" symbolic-ref --quiet --short HEAD 2> /dev/null)" != "$branch" ]; then
    echo "worktree unavailable"
    return
  fi
  if operation_in_progress "$worktree"; then
    echo "operation in progress"
    return
  fi
  if ! status=$(clean_status "$worktree"); then
    echo "worktree unavailable"
    return
  fi
  if [ -n "$status" ]; then
    echo "dirty worktree"
    return
  fi
  if hidden_tracked_status "$worktree"; then
    :
  else
    case "$?" in
      1) echo "dirty worktree" ;;
      *) echo "worktree unavailable" ;;
    esac
    return
  fi
  if ! output=$(cd "$worktree" && "$STACK_RESOLVER"); then
    echo "stack membership unknown"
    return
  fi
  membership=$(printf '%s\n' "$output" | sed -n 's/^STACK_MEMBERSHIP=//p')
  case "$membership" in
    none) ;;
    local | remote) echo "stack member" ;;
    *) echo "stack membership unknown" ;;
  esac
}

run_plan() {
  local pr_rows all_pr_rows number head base cross index other reason worktree
  local all_number all_head all_base all_cross
  local base_oid local_head remote_head remote_listing oid ref
  local pr_limit=1000
  local -a numbers=() heads=() bases=() crosses=() reasons=() worktrees=()
  local -a all_numbers=() all_heads=() all_crosses=()
  local -a fetched=() patterns=() remote_refs=() remote_oids=() output=()

  resolve_origin_repo
  # Query the repository identified by gh; fetches and pushes below use the
  # one validated endpoint captured in ORIGIN_PUSH_URL.
  pr_rows=$(gh pr list --repo "$ORIGIN_REPO" --author "@me" --state open --limit "$pr_limit" \
    --json number,headRefName,baseRefName,isCrossRepository \
    --jq '.[] | [.number, .headRefName, .baseRefName, .isCrossRepository] | @tsv') \
    || die "Could not list open Pull Requests with gh; nothing was planned."
  while IFS=$'\t' read -r number head base cross; do
    [ -n "$number" ] || continue
    [[ "$number" =~ ^[0-9]+$ ]] || die "gh returned an unexpected Pull Request row; nothing was planned."
    numbers+=("$number")
    heads+=("$head")
    bases+=("$base")
    crosses+=("$cross")
  done <<< "$pr_rows"
  if [ "${#numbers[@]}" -ge "$pr_limit" ]; then
    die "gh returned at least $pr_limit open Pull Requests; the batch limit was reached, so nothing was planned."
  fi
  all_pr_rows=$(gh pr list --repo "$ORIGIN_REPO" --state open --limit "$pr_limit" \
    --json number,headRefName,baseRefName,isCrossRepository \
    --jq '.[] | [.number, .headRefName, .baseRefName, .isCrossRepository] | @tsv') \
    || die "Could not inventory open Pull Request heads with gh; nothing was planned."
  while IFS=$'\t' read -r all_number all_head all_base all_cross; do
    [ -n "$all_number" ] || continue
    [ -n "$all_base" ] || die "gh returned an unexpected Pull Request head row; nothing was planned."
    [[ "$all_number" =~ ^[0-9]+$ ]] || die "gh returned an unexpected Pull Request head row; nothing was planned."
    all_numbers+=("$all_number")
    all_heads+=("$all_head")
    all_crosses+=("$all_cross")
  done <<< "$all_pr_rows"
  if [ "${#all_numbers[@]}" -ge "$pr_limit" ]; then
    die "gh returned at least $pr_limit open Pull Request heads; the batch limit was reached, so nothing was planned."
  fi
  load_worktrees
  load_protected

  # Local classification that needs no network access.
  for ((index = 0; index < ${#numbers[@]}; index++)); do
    head=${heads[$index]}
    base=${bases[$index]}
    reason=""
    worktree=""
    if [ "${crosses[$index]}" != "false" ]; then
      reason="fork head"
    elif ! valid_branch "$head" || ! valid_branch "$base"; then
      reason="invalid branch name"
    else
      for ((other = 0; other < ${#all_numbers[@]}; other++)); do
        if [ "${all_crosses[$other]}" = "false" ] \
          && [ "${all_heads[$other]}" = "$base" ]; then
          reason="stacked on PR #${all_numbers[$other]}"
          break
        fi
      done
    fi
    if [ -z "$reason" ]; then
      if ! find_worktree "$head"; then
        reason="not checked out in a local worktree"
      else
        worktree=$FOUND_PATH
        if [ "$FOUND_UNAVAILABLE" -eq 1 ]; then
          reason="worktree unavailable"
        else
          reason=$(location_reason "$head" "$worktree")
          [ -n "$reason" ] || [ "$FOUND_UNAVAILABLE" -eq 0 ] || reason="operation in progress"
        fi
      fi
    fi
    reasons+=("$reason")
    worktrees+=("$worktree")
  done

  # Fetch each candidate base once and read every candidate head in one call.
  for ((index = 0; index < ${#numbers[@]}; index++)); do
    [ -z "${reasons[$index]}" ] || continue
    base=${bases[$index]}
    patterns+=("refs/heads/${heads[$index]}")
    case " ${fetched[*]-} " in *" $base "*) continue ;; esac
    git fetch --quiet --no-tags -- "$ORIGIN_PUSH_URL" "+refs/heads/$base:refs/remotes/origin/$base" >&2 \
      || die "Could not fetch origin/$base; nothing was planned."
    fetched+=("$base")
  done
  if [ "${#patterns[@]}" -gt 0 ]; then
    remote_listing=$(git ls-remote --heads -- "$ORIGIN_PUSH_URL" "${patterns[@]}") \
      || die "Could not read Pull Request heads from origin; nothing was planned."
    while IFS=$'\t' read -r oid ref; do
      [ -n "$oid" ] || continue
      remote_oids+=("$oid")
      remote_refs+=("$ref")
    done <<< "$remote_listing"
  fi

  # Rows are buffered so that a failure prints no partial plan.
  for ((index = 0; index < ${#numbers[@]}; index++)); do
    head=${heads[$index]}
    base=${bases[$index]}
    worktree=${worktrees[$index]}
    reason=${reasons[$index]}
    local_head=""
    base_oid=""
    if [ -z "$reason" ]; then
      reason=$(worktree_reason "$head" "$worktree")
    fi
    if [ -z "$reason" ]; then
      local_head=$(git -C "$worktree" rev-parse --verify HEAD) \
        || die "Could not read HEAD in $worktree; nothing was planned."
      base_oid=$(git rev-parse --verify "refs/remotes/origin/$base^{commit}") \
        || die "Could not resolve origin/$base; nothing was planned."
      remote_head=""
      for ((other = 0; other < ${#remote_refs[@]}; other++)); do
        [ "${remote_refs[$other]}" = "refs/heads/$head" ] && remote_head=${remote_oids[$other]}
      done
      if [ -z "$remote_head" ]; then
        reason="head missing on origin"
      elif [ "$remote_head" != "$local_head" ]; then
        reason="local and origin differ"
      elif git merge-base --is-ancestor "$base_oid" "$local_head" \
        && [ "$(git rev-list --count --merges "$base_oid..$local_head")" -eq 0 ]; then
        reason="already contains base"
      fi
    fi
    if [ -z "$reason" ]; then
      output+=("$(printf '%s\t%s\t%s\t%s\t%s\t%s\trebase\t-' \
        "${numbers[$index]}" "$head" "$base" "$worktree" "$local_head" "$base_oid")")
    else
      output+=("$(printf '%s\t%s\t%s\t%s\t%s\t%s\tskip\t%s' "${numbers[$index]}" \
        "$(or_dash "$head")" "$(or_dash "$base")" "$(or_dash "$worktree")" \
        "$(or_dash "$local_head")" "$(or_dash "$base_oid")" "$reason")")
    fi
  done
  printf '%s\n' "$PLAN_HEADER"
  printf '%s%s\n' "$PLAN_PUSH_URL_PREFIX" "$ORIGIN_PUSH_URL"
  for ((index = 0; index < ${#output[@]}; index++)); do
    printf '%s\n' "${output[$index]}"
  done
}

# Prints the reason a planned row may no longer be rebased, or nothing.
revalidate() {
  local pr="$1" branch="$2" worktree="$3" head="$4" base_oid="$5" base="$6"
  local reason remote_head remote_base metadata metadata_pr metadata_head metadata_base metadata_cross metadata_state
  if ! valid_branch "$branch" || ! valid_branch "$base" || ! is_oid "$head" || ! is_oid "$base_oid" \
    || ! git cat-file -e "$base_oid^{commit}" 2> /dev/null; then
    echo "invalid plan row"
    return
  fi
  if ! metadata=$(gh pr view "$pr" --repo "$ORIGIN_REPO" \
    --json number,headRefName,baseRefName,isCrossRepository,state \
    --jq '[.number, .headRefName, .baseRefName, .isCrossRepository, .state] | @tsv'); then
    echo "Pull Request metadata unavailable since plan"
    return
  fi
  IFS=$'\t' read -r metadata_pr metadata_head metadata_base metadata_cross metadata_state <<< "$metadata"
  if [ "$metadata_pr" != "$pr" ] || [ "$metadata_head" != "$branch" ] \
    || [ "$metadata_base" != "$base" ] || [ "$metadata_cross" != "false" ] \
    || [ "$metadata_state" != "OPEN" ]; then
    echo "Pull Request metadata changed since plan"
    return
  fi
  if ! find_worktree "$branch" || [ "$FOUND_PATH" != "$worktree" ] \
    || [ "$FOUND_UNAVAILABLE" -eq 1 ]; then
    echo "worktree changed since plan"
    return
  fi
  if [ "$FOUND_UNAVAILABLE" -eq 2 ]; then
    echo "operation in progress"
    return
  fi
  reason=$(location_reason "$branch" "$worktree")
  [ -n "$reason" ] || reason=$(worktree_reason "$branch" "$worktree")
  if [ -n "$reason" ]; then
    echo "$reason"
    return
  fi
  if [ "$(git -C "$worktree" rev-parse --verify HEAD)" != "$head" ]; then
    echo "head changed since plan"
    return
  fi
  if ! remote_head=$(git ls-remote --heads -- "$ORIGIN_PUSH_URL" "refs/heads/$branch" \
    | awk -v ref="refs/heads/$branch" '$2 == ref { print $1 }'); then
    echo "origin unreadable"
    return
  fi
  [ "$remote_head" = "$head" ] || echo "origin changed since plan"
  if [ "$remote_head" != "$head" ]; then
    return
  fi
  if ! remote_base=$(git ls-remote --heads -- "$ORIGIN_PUSH_URL" "refs/heads/$base" \
    | awk -v ref="refs/heads/$base" '$2 == ref { print $1 }'); then
    echo "origin unreadable"
    return
  fi
  [ "$remote_base" = "$base_oid" ] || echo "base changed since plan"
}

# True when the worktree is back on the branch at the planned head, with no
# operation in progress and no changes.
restored() {
  local branch="$1" worktree="$2" head="$3" status
  [ "$(git -C "$worktree" symbolic-ref --quiet --short HEAD 2> /dev/null)" = "$branch" ] || return 1
  [ "$(git -C "$worktree" rev-parse --verify HEAD 2> /dev/null)" = "$head" ] || return 1
  ! operation_in_progress "$worktree" || return 1
  status=$(clean_status "$worktree") || return 1
  [ -z "$status" ]
}

# Prints one result row for the plan row run_apply is processing.
emit_result() {
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$pr" "$branch" "$worktree" "$1" "$head" "$2" "$3"
}

run_apply() {
  local line pr branch base worktree head base_oid action reason index halted=0
  local new_head detail started
  local -a rows=()

  [ -f "$PLAN_FILE" ] || die "Plan file not found: $PLAN_FILE"
  IFS= read -r line < "$PLAN_FILE" || die "Plan file is empty: $PLAN_FILE"
  [ "$line" = "$PLAN_HEADER" ] || die "Plan file does not start with the batch plan header."
  IFS= read -r line < <(sed -n '2p' "$PLAN_FILE") || die "Plan file is missing its push URL."
  case "$line" in
    "$PLAN_PUSH_URL_PREFIX"*)
      [ "${line#"$PLAN_PUSH_URL_PREFIX"}" = "$ORIGIN_PUSH_URL" ] \
        || die "The origin push URL changed since the plan was created; nothing was applied."
      ;;
    *) die "Plan file is missing its push URL." ;;
  esac
  # Validate every row before mutating anything.
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in '#'* | '') continue ;; esac
    IFS=$'\t' read -r pr branch base worktree head base_oid action reason <<< "$line"
    [[ "$pr" =~ ^[0-9]+$ ]] && { [ "$action" = "rebase" ] || [ "$action" = "skip" ]; } \
      && [ -n "$reason" ] || die "Malformed plan row; nothing was applied: $line"
    rows+=("$line")
  done < "$PLAN_FILE"
  resolve_origin_repo
  load_worktrees
  load_protected

  printf '%s\n' "$RESULT_HEADER"
  for ((index = 0; index < ${#rows[@]}; index++)); do
    IFS=$'\t' read -r pr branch base worktree head base_oid action reason <<< "${rows[$index]}"
    if [ "$action" = "skip" ]; then
      emit_result skipped - "$reason"
      continue
    fi
    if [ "$halted" -eq 1 ]; then
      emit_result skipped - "not processed after an earlier error"
      continue
    fi
    detail=$(revalidate "$pr" "$branch" "$worktree" "$head" "$base_oid" "$base")
    if [ -n "$detail" ]; then
      emit_result skipped - "$detail"
      continue
    fi
    if ! GIT_EDITOR=true git -C "$worktree" rebase --no-autostash --no-update-refs "$base_oid" >&2; then
      started=0
      if rebase_in_progress "$worktree"; then
        started=1
        git -C "$worktree" rebase --abort >&2 || true
      fi
      if ! restored "$branch" "$worktree" "$head"; then
        emit_result error - "abort did not restore the planned head; inspect this worktree"
        halted=1
      elif [ "$started" -eq 1 ]; then
        emit_result conflict - "rebase stopped and was aborted; branch unchanged"
      else
        emit_result skipped - "rebase failed before starting; branch unchanged (see git output)"
      fi
      continue
    fi
    new_head=$(git -C "$worktree" rev-parse --verify HEAD)
    if git -C "$worktree" push --no-follow-tags --recurse-submodules=no \
      --force-with-lease="refs/heads/$branch:$head" -- "$ORIGIN_PUSH_URL" \
      "refs/heads/$branch:refs/heads/$branch" >&2; then
      emit_result pushed "$new_head" -
    else
      emit_result push-rejected "$new_head" "local branch rebased; pre-rebase head is $head"
    fi
  done
  [ "$halted" -eq 0 ] || exit 2
}

if [ "$SUBCOMMAND" = "plan" ]; then
  resolve_push_url
  run_plan
else
  resolve_push_url
  run_apply
fi
