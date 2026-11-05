#!/usr/bin/env bash
#
# Print a JSON snapshot of the pull requests waiting on your review.
#
# Usage: review-queue.sh [--repo OWNER/NAME] [--since ISO-8601] [OWNER/NAME#NUMBER ...]
#   --repo   limit every search to one repository
#   --since  also include PRs you reviewed that changed since then, and PRs that
#            requested you and closed since then (merged without your review)
#   refs     PRs to re-query by number, such as every PR in the previous report
#
# Prints {checkedAt, me, prs: [...]} with one summarised object per PR, and
# warnings on stderr. Exits 2 on a usage error and nonzero when a search fails;
# an unreadable ref or an unlistable set of workflow runs only warns. Needs an
# authenticated gh and jq. Runs under the Bash 3.2 that macOS ships, so guard
# empty-array expansions under set -u and do not use mapfile.

set -euo pipefail

usage() {
  echo "Usage: review-queue.sh [--repo OWNER/NAME] [--since ISO-8601] [OWNER/NAME#NUMBER ...]"
}

usage_error() {
  echo "review-queue.sh: $1" >&2
  usage >&2
  exit 2
}

repo=""
since=""
refs=()
while [ $# -gt 0 ]; do
  case "$1" in
    --repo)
      [ $# -ge 2 ] || usage_error "--repo requires OWNER/NAME"
      repo=$2
      shift 2
      ;;
    --since)
      [ $# -ge 2 ] || usage_error "--since requires an ISO-8601 date or time"
      since=$2
      shift 2
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    -*) usage_error "unknown option: $1" ;;
    *)
      refs+=("$1")
      shift
      ;;
  esac
done

# Validate every value before it reaches a search query or a GraphQL variable.
slug_re='[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+'
repo_re="^$slug_re\$"
ref_re="^$slug_re#[0-9]+\$"
since_re='^[0-9]{4}-[0-9]{2}-[0-9]{2}(T[0-9]{2}:[0-9]{2}(:[0-9]{2})?(Z|[+-][0-9]{2}:[0-9]{2})?)?$'
if [ -n "$repo" ] && ! [[ $repo =~ $repo_re ]]; then
  usage_error "--repo must be OWNER/NAME, got: $repo"
fi
if [ -n "$since" ] && ! [[ $since =~ $since_re ]]; then
  usage_error "--since must be an ISO-8601 date or time, got: $since"
fi
for ref in ${refs[@]+"${refs[@]}"}; do
  [[ $ref =~ $ref_re ]] || usage_error "a PR must be OWNER/NAME#NUMBER, got: $ref"
done

FRAGMENT='
fragment PR on PullRequest {
  number title url isDraft state mergedAt mergedBy { login }
  repository { nameWithOwner defaultBranchRef { name } }
  author { login }
  baseRefName headRefOid additions deletions changedFiles
  mergeable mergeStateStatus reviewDecision
  reviewRequests(first: 20) { nodes { requestedReviewer { ... on User { login } ... on Team { slug } } } }
  latestReviews(first: 20) { nodes { author { login } state } }
  myReviews: reviews(author: $me, last: 20) { nodes { state submittedAt commit { oid } comments { totalCount } } }
  reviewThreads(first: 100) { nodes { isResolved comments(first: 1) { nodes { author { login } pullRequestReview { state } } } } }
  commits(last: 1) { nodes { commit { committedDate statusCheckRollup { state contexts(first: 100) { nodes {
    ... on CheckRun { name status conclusion startedAt checkSuite { workflowRun { databaseId } } }
    ... on StatusContext { context state createdAt }
  } } } } } }
}'
SEARCH_QUERY='query($q: String!, $me: String!) {
  search(query: $q, type: ISSUE, first: 100) { issueCount nodes { ...PR } }
}'
PR_QUERY='query($owner: String!, $name: String!, $number: Int!, $me: String!) {
  repository(owner: $owner, name: $name) { pullRequest(number: $number) { ...PR } }
}'

graphql() {
  gh api graphql -f query="$1 $FRAGMENT" -f me="$me" "${@:2}"
}

# Bash clears set -e inside command substitutions, so every function that runs
# inside one returns its failures explicitly.
search() {
  local out count
  out=$(graphql "$SEARCH_QUERY" -f q="$1") || return
  count=$(jq '.data.search.issueCount' <<< "$out") || return
  if [ "$count" -gt 100 ]; then
    echo "warning: only the first 100 of $count results for: $1" >&2
  fi
  jq '.data.search.nodes[]' <<< "$out"
}

# gh skips --jq and prints the raw error body when a call fails, so capture the
# output and print it only on success.
read_ref() {
  local ref=$1 slug node
  slug=${ref%%#*}
  if node=$(graphql "$PR_QUERY" -f owner="${slug%%/*}" -f name="${slug#*/}" \
    -F number="${ref##*#}" --jq '.data.repository.pullRequest'); then
    printf '%s\n' "$node"
  else
    echo "warning: cannot read $ref" >&2
  fi
}

# A cancelled duplicate run leaves its checks on the head commit, so the rollup
# reads FAILURE although the run that replaced it passed. Print the IDs of runs
# that a newer run of the same workflow and event on the same head replaced.
superseded_runs() {
  local slug=$1 sha=$2 ids
  if ids=$(gh api "repos/$slug/actions/runs?head_sha=$sha&per_page=100" \
    --jq '[.workflow_runs | group_by([.workflow_id, .event])[] | sort_by(.id) | .[:-1][] | .id]'); then
    jq -n --arg key "$slug@$sha" --argjson ids "$ids" '{key: $key, value: $ids}'
  else
    echo "warning: cannot list workflow runs for $slug@$sha" >&2
  fi
}

# A failed search fails the run; an unreadable ref only warns.
collect_prs() {
  search "is:pr is:open archived:false user-review-requested:@me$scope" || return
  if [ -n "$since" ]; then
    search "is:pr reviewed-by:@me -author:@me updated:>=$since$scope" || return
    search "is:pr is:closed user-review-requested:@me closed:>=$since$scope" || return
  fi
  for ref in ${refs[@]+"${refs[@]}"}; do
    read_ref "$ref"
  done
}

# Take the time first, so passing it as the next --since misses nothing.
checked_at=$(date -u +%FT%TZ)
me=$(gh api user --jq .login)
scope=${repo:+ repo:$repo}
prs=$(collect_prs | jq -s 'unique_by(.url)')

superseded=$(jq -r '.[]
    | select(.state == "OPEN" and (.commits.nodes[0].commit.statusCheckRollup.state // "SUCCESS") != "SUCCESS")
    | "\(.repository.nameWithOwner) \(.headRefOid)"' <<< "$prs" \
  | while read -r slug sha; do
    superseded_runs "$slug" "$sha"
  done | jq -s 'from_entries')

SUMMARY='
def result: .conclusion // .state;
def failed: result | IN("FAILURE", "ERROR", "TIMED_OUT", "STARTUP_FAILURE", "ACTION_REQUIRED");
def running: (.status // "COMPLETED") != "COMPLETED" or ((.state // "") | IN("PENDING", "EXPECTED"));
{checkedAt: $checkedAt, me: $me, prs: (sort_by(.repository.nameWithOwner, .number) | map(
  .commits.nodes[0].commit as $c
  | ($c.statusCheckRollup.contexts.nodes // []) as $all
  | ($superseded["\(.repository.nameWithOwner)@\(.headRefOid)"] // []) as $old
  | [$all[] | select((.checkSuite.workflowRun.databaseId // -1) | IN($old[]) | not)] as $checks
  | ([.myReviews.nodes[] | select(.state != "PENDING")] | last) as $mine
  | {
      pr: "\(.repository.nameWithOwner)#\(.number)", url, title,
      issue: ([.title | scan("\\b[A-Z][A-Z0-9]+-[0-9]+\\b")] | first),
      author: .author.login, state, mergedAt, mergedBy: .mergedBy.login, draft: .isDraft,
      size: "+\(.additions)/-\(.deletions) in \(.changedFiles) files",
      base: .baseRefName, defaultBranch: .repository.defaultBranchRef.name,
      head: .headRefOid, lastCommitAt: $c.committedDate,
      requestedOfMe: any(.reviewRequests.nodes[]; .requestedReviewer.login == $me),
      requestedTeams: [.reviewRequests.nodes[].requestedReviewer.slug // empty],
      myPendingComments: ([.myReviews.nodes[] | select(.state == "PENDING") | .comments.totalCount] | add // 0),
      myLastReview: (if $mine then {state: $mine.state, at: $mine.submittedAt, onHead: ($mine.commit.oid == .headRefOid)} else null end),
      myOpenThreads: [.reviewThreads.nodes[] | select((.isResolved | not)
        and .comments.nodes[0].author.login == $me
        and .comments.nodes[0].pullRequestReview.state != "PENDING")] | length,
      otherOpenThreads: [.reviewThreads.nodes[] | select((.isResolved | not) and .comments.nodes[0].author.login != $me)] | length,
      otherReviews: [.latestReviews.nodes[] | select(.author.login != $me) | "\(.author.login): \(.state)"],
      reviewDecision, mergeable, mergeStateStatus,
      ci: (if ($checks | length) == 0 then "none"
           elif any($checks[]; failed) then "failing"
           elif any($checks[]; running) then "running"
           elif any($checks[]; result == "CANCELLED") then "cancelled"
           else "green" end),
      failing: [$checks[] | select(failed) | {name: (.name // .context), run: .checkSuite.workflowRun.databaseId}] | unique,
      running: [$checks[] | select(running) | {name: (.name // .context), since: (.startedAt // .createdAt)}] | unique,
      cancelled: [$checks[] | select(result == "CANCELLED") | .name] | unique,
      supersededChecks: (($all | length) - ($checks | length))
    }
))}'

jq --arg me "$me" --arg checkedAt "$checked_at" --argjson superseded "$superseded" "$SUMMARY" <<< "$prs"
