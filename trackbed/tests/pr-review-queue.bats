#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

load 'test_helper/common'

ME="riley-reviewer"
HEAD="1111111111111111111111111111111111111111"
OLD_HEAD="0000000000000000000000000000000000000000"

# jq helpers for building GitHub-shaped fixtures.
JQ_DEFS='
def check($name; $conclusion; $run):
  {name: $name, status: "COMPLETED", conclusion: $conclusion, startedAt: "2026-04-01T09:00:00Z",
   checkSuite: {workflowRun: {databaseId: $run}}};
def rollup($state; $checks):
  .commits.nodes[0].commit.statusCheckRollup = {state: $state, contexts: {nodes: $checks}};
def review($state; $oid; $comments):
  {state: $state, submittedAt: (if $state == "PENDING" then null else "2026-04-01T10:00:00Z" end),
   commit: {oid: $oid}, comments: {totalCount: $comments}};
def thread($resolved; $login; $review_state):
  {isResolved: $resolved, comments: {nodes: [{author: {login: $login}, pullRequestReview: {state: $review_state}}]}};
def workflow_run($id; $workflow; $event): {id: $id, workflow_id: $workflow, name: "CI", event: $event};
'

# An open PR that requests $ME personally and the platform team, with no
# reviews or threads and one green check.
BASE_PR='{
  number: $number,
  title: "WID-42: Cache widget lookups",
  isDraft: false, state: "OPEN", mergedAt: null, mergedBy: null,
  repository: {nameWithOwner: "acme/widgets", defaultBranchRef: {name: "main"}},
  author: {login: "ana-author"},
  baseRefName: "main", headRefOid: $head,
  additions: 120, deletions: 8, changedFiles: 5,
  mergeable: "MERGEABLE", mergeStateStatus: "BLOCKED", reviewDecision: "REVIEW_REQUIRED",
  reviewRequests: {nodes: [{requestedReviewer: {login: $me}}, {requestedReviewer: {slug: "platform"}}]},
  latestReviews: {nodes: []},
  myReviews: {nodes: []},
  reviewThreads: {nodes: []},
  commits: {nodes: [{commit: {committedDate: "2026-04-01T08:00:00Z", statusCheckRollup: null}}]}
} | rollup("SUCCESS"; [check("test"; "SUCCESS"; 7001)])'

setup() {
	SCRIPT="$BATS_TEST_DIRNAME/../skills/pr:review-queue/scripts/review-queue.sh"
	SKILL="$BATS_TEST_DIRNAME/../skills/pr:review-queue/SKILL.md"
	TMP_DIR="$(mktemp -d)"
	BIN_DIR="$TMP_DIR/bin"
	GH_FIXTURES="$TMP_DIR/fixtures"
	GH_LOG="$TMP_DIR/gh.log"
	mkdir -p "$BIN_DIR" "$GH_FIXTURES"
	: >"$GH_LOG"
	write_gh_stub
	export PATH="$BIN_DIR:$PATH" GH_FIXTURES GH_LOG
	printf '{"login":"%s"}\n' "$ME" >"$GH_FIXTURES/user.json"
}

teardown() {
	if [ -n "${TMP_DIR:-}" ] && [ -d "$TMP_DIR" ]; then
		rm -rf "$TMP_DIR"
	fi
}

# Serves fixtures from $GH_FIXTURES and logs one line per call to $GH_LOG. Like
# gh, it applies --jq only on success and prints strings raw; on an error it
# prints the raw error body to stdout and exits 1.
write_gh_stub() {
	cat >"$BIN_DIR/gh" <<'GH'
#!/bin/sh
set -eu
[ "${1-}" = api ] || {
  echo "unexpected gh call: $*" >&2
  exit 97
}
endpoint=$2
shift 2
q="" owner="" name="" number="" filter=""
while [ $# -gt 0 ]; do
  case "$1" in
    -f | -F)
      case "$2" in
        q=*) q=${2#q=} ;;
        owner=*) owner=${2#owner=} ;;
        name=*) name=${2#name=} ;;
        number=*) number=${2#number=} ;;
      esac
      shift 2
      ;;
    --jq)
      filter=$2
      shift 2
      ;;
    *) shift ;;
  esac
done

fail() {
  printf '%s\n' "$1"
  printf 'gh: %s\n' "$2" >&2
  exit 1
}

case "$endpoint" in
  user)
    echo user >>"$GH_LOG"
    file=$GH_FIXTURES/user.json
    ;;
  graphql)
    if [ -n "$q" ]; then
      printf 'search %s\n' "$q" >>"$GH_LOG"
      case "$q" in
        *reviewed-by:@me*) kind=reviewed ;;
        *is:closed*) kind=closed ;;
        *) kind=open ;;
      esac
      [ ! -f "$GH_FIXTURES/search-$kind.error" ] || fail "$(cat "$GH_FIXTURES/search-$kind.error")" "search failed"
      file=$GH_FIXTURES/search-$kind.json
      [ -f "$file" ] || {
        printf '%s\n' '{"data":{"search":{"issueCount":0,"nodes":[]}}}'
        exit 0
      }
    else
      printf 'pr %s/%s#%s\n' "$owner" "$name" "$number" >>"$GH_LOG"
      file=$GH_FIXTURES/pr-$owner-$name-$number.json
      [ -f "$file" ] || fail '{"data":{"repository":{"pullRequest":null}},"errors":[{"type":"NOT_FOUND","message":"Could not resolve to a PullRequest."}]}' "Could not resolve to a PullRequest."
    fi
    ;;
  repos/*/actions/runs*)
    printf 'runs %s\n' "$endpoint" >>"$GH_LOG"
    sha=${endpoint#*head_sha=}
    file=$GH_FIXTURES/runs-${sha%%&*}.json
    [ -f "$file" ] || fail '{"message":"Not Found","status":"404"}' "Not Found (HTTP 404)"
    ;;
  *)
    echo "unexpected gh api endpoint: $endpoint" >&2
    exit 97
    ;;
esac

if [ -n "$filter" ]; then
  jq -r "$filter" "$file"
else
  cat "$file"
fi
GH
	chmod +x "$BIN_DIR/gh"
}

# Prints PR <number> from BASE_PR after applying the jq filter $2, which can use
# $me, $head, $old_head, and the JQ_DEFS helpers.
pr_node() {
	local number=$1 filter=${2:-.}
	jq -n --arg me "$ME" --arg head "$HEAD" --arg old_head "$OLD_HEAD" --argjson number "$number" \
		"$JQ_DEFS $BASE_PR | $filter"' | .url = "https://github.com/\(.repository.nameWithOwner)/pull/\(.number)"'
}

# Serves the PR nodes given after <kind> as the open, reviewed, or closed search.
serve_search() {
	local kind=$1
	shift
	printf '%s\n' "$@" | jq -s '{data: {search: {issueCount: length, nodes: .}}}' >"$GH_FIXTURES/search-$kind.json"
}

# Serves a PR node for the ref OWNER/NAME#N.
serve_pr() {
	local ref=$1 slug=${1%%#*}
	jq '{data: {repository: {pullRequest: .}}}' <<<"$2" >"$GH_FIXTURES/pr-${slug%%/*}-${slug#*/}-${ref##*#}.json"
}

# Serves the workflow runs for head SHA $1 from the jq array expression $2.
serve_runs() {
	jq -n "$JQ_DEFS {workflow_runs: $2} | .total_count = (.workflow_runs | length)" >"$GH_FIXTURES/runs-$1.json"
}

# Runs the script through /bin/bash, which is Bash 3.2 on macOS.
run_queue() {
	run --separate-stderr /bin/bash "$SCRIPT" "$@"
}

# Asserts that the script's stderr contains $1. Unlike a mid-test [[ ]], a plain
# command fails the test even when Bats runs under Bash 3.2.
assert_stderr_contains() {
	grep -Fq -- "$1" <<<"$stderr" || {
		printf 'expected stderr to contain %s, got: %s\n' "$1" "$stderr" >&2
		return 1
	}
}

# Asserts that the jq filter $1, applied to the script's stdout, prints $2.
assert_json() {
	local actual
	actual=$(jq -c -r "$1" <<<"$output")
	if [ "$actual" != "$2" ]; then
		printf 'expected %s to print %s, got %s\n' "$1" "$2" "$actual" >&2
		return 1
	fi
}

@test "searches only for PRs that request you personally" {
	serve_search open "$(pr_node 101)"

	run_queue

	[ "$status" -eq 0 ]
	diff -u - "$GH_LOG" <<'EOF'
user
search is:pr is:open archived:false user-review-requested:@me
EOF
	assert_json '.me' "$ME"
	assert_json '.checkedAt | test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$")' true
	assert_json '.prs | length' 1
	assert_json '.prs[0] | [.pr, .issue, .author, .size, .base, .defaultBranch]' \
		'["acme/widgets#101","WID-42","ana-author","+120/-8 in 5 files","main","main"]'
	assert_json '.prs[0] | [.requestedOfMe, .requestedTeams, .myLastReview, .myPendingComments, .ci]' \
		'[true,["platform"],null,0,"green"]'
}

@test "--since adds searches for PRs you reviewed and PRs closed since then" {
	serve_search open "$(pr_node 101)"
	serve_search reviewed "$(pr_node 102 '.reviewRequests.nodes = [] | .myReviews.nodes = [review("APPROVED"; $head; 0)]')"
	serve_search closed "$(pr_node 103 '.state = "MERGED" | .mergedAt = "2026-04-02T12:00:00Z"
		| .mergedBy = {login: "mo-merger"} | rollup("FAILURE"; [check("test"; "FAILURE"; 7002)])')"

	run_queue --repo acme/widgets --since 2026-04-01T09:30:00Z

	[ "$status" -eq 0 ]
	diff -u - "$GH_LOG" <<'EOF'
user
search is:pr is:open archived:false user-review-requested:@me repo:acme/widgets
search is:pr reviewed-by:@me -author:@me updated:>=2026-04-01T09:30:00Z repo:acme/widgets
search is:pr is:closed user-review-requested:@me closed:>=2026-04-01T09:30:00Z repo:acme/widgets
EOF
	assert_json '[.prs[].pr]' '["acme/widgets#101","acme/widgets#102","acme/widgets#103"]'
	assert_json '.prs[1] | [.requestedOfMe, .myLastReview.state, .myLastReview.onHead]' '[false,"APPROVED",true]'
	assert_json '.prs[2] | [.state, .mergedBy, .requestedOfMe, .myLastReview]' '["MERGED","mo-merger",true,null]'
}

@test "re-queries refs by number and de-duplicates the combined results by URL" {
	serve_search open "$(pr_node 101)"
	serve_pr acme/widgets#101 "$(pr_node 101)"
	serve_pr acme/gadgets#7 "$(pr_node 7 '.repository.nameWithOwner = "acme/gadgets" | .title = "Tidy gadget logs"')"

	run_queue acme/widgets#101 acme/gadgets#7

	[ "$status" -eq 0 ]
	grep -qx 'pr acme/widgets#101' "$GH_LOG"
	grep -qx 'pr acme/gadgets#7' "$GH_LOG"
	assert_json '[.prs[].pr]' '["acme/gadgets#7","acme/widgets#101"]'
	assert_json '.prs[0].issue' null
}

@test "an unreadable ref warns and leaves the rest of the report intact" {
	serve_search open "$(pr_node 101)"

	run_queue acme/widgets#999

	[ "$status" -eq 0 ]
	assert_stderr_contains "warning: cannot read acme/widgets#999"
	assert_json '[.prs[].pr]' '["acme/widgets#101"]'
}

@test "a failed search fails the run instead of printing a partial queue" {
	serve_search open "$(pr_node 101)"
	printf '%s\n' '{"errors":[{"message":"API rate limit exceeded"}]}' >"$GH_FIXTURES/search-reviewed.error"

	run_queue --since 2026-04-01

	[ "$status" -ne 0 ]
	[ -z "$output" ]
}

@test "drops checks from runs that a newer run of the same workflow and event replaced" {
	serve_search open "$(pr_node 101 'rollup("FAILURE";
		[check("test"; "CANCELLED"; 7001), check("test"; "SUCCESS"; 7002), check("lint"; "SUCCESS"; 7003)])')"
	serve_runs "$HEAD" '[workflow_run(7003; 12; "pull_request"),
		workflow_run(7002; 11; "pull_request"), workflow_run(7001; 11; "pull_request")]'

	run_queue

	[ "$status" -eq 0 ]
	grep -qx "runs repos/acme/widgets/actions/runs?head_sha=$HEAD&per_page=100" "$GH_LOG"
	assert_json '.prs[0] | [.ci, .supersededChecks, .cancelled, .failing]' '["green",1,[],[]]'
}

@test "keeps checks from other workflows and events, even when they share a workflow name" {
	serve_search open "$(pr_node 101 'rollup("FAILURE"; [check("build"; "FAILURE"; 7000),
		check("lint"; "FAILURE"; 7001), check("test"; "CANCELLED"; 7002), check("test"; "SUCCESS"; 7003)])')"
	serve_runs "$HEAD" '[workflow_run(7003; 11; "pull_request"), workflow_run(7002; 11; "pull_request"),
		workflow_run(7001; 12; "pull_request"), workflow_run(7000; 11; "push")]'

	run_queue

	[ "$status" -eq 0 ]
	assert_json '.prs[0] | [.ci, .supersededChecks, .cancelled]' '["failing",1,[]]'
	assert_json '.prs[0].failing' '[{"name":"build","run":7000},{"name":"lint","run":7001}]'
}

@test "a failed workflow-run lookup warns and counts every check" {
	serve_search open "$(pr_node 101 'rollup("FAILURE"; [check("test"; "CANCELLED"; 7001), check("test"; "SUCCESS"; 7002)])')"

	run_queue

	[ "$status" -eq 0 ]
	assert_stderr_contains "warning: cannot list workflow runs for acme/widgets@$HEAD"
	assert_json '.prs[0] | [.ci, .supersededChecks, .cancelled]' '["cancelled",0,["test"]]'
}

@test "reports ci none without a run lookup when the head commit has no checks" {
	serve_search open "$(pr_node 101 '.commits.nodes[0].commit.statusCheckRollup = null | .mergeStateStatus = "DIRTY"')"

	run_queue

	[ "$status" -eq 0 ]
	assert_json '.prs[0] | [.ci, .failing, .running]' '["none",[],[]]'
	[ -z "$(grep '^runs ' "$GH_LOG")" ]
}

@test "counts your unsubmitted pending review and leaves its threads out of your open threads" {
	serve_search open "$(pr_node 101 '
		.myReviews.nodes = [review("COMMENTED"; $head; 1), review("PENDING"; $head; 3)]
		| .reviewThreads.nodes = [
			thread(false; $me; "COMMENTED"),
			thread(false; $me; "PENDING"),
			thread(true; $me; "COMMENTED"),
			thread(false; "ana-author"; "COMMENTED")
		]')"

	run_queue

	[ "$status" -eq 0 ]
	assert_json '.prs[0] | [.myPendingComments, .myOpenThreads, .otherOpenThreads, .myLastReview.state]' \
		'[3,1,1,"COMMENTED"]'
}

@test "flags an approval that a later push made stale" {
	serve_search open \
		"$(pr_node 101 '.myReviews.nodes = [review("APPROVED"; $old_head; 0)]
			| .latestReviews.nodes = [{author: {login: $me}, state: "APPROVED"}, {author: {login: "sam-second"}, state: "APPROVED"}]')" \
		"$(pr_node 102 '.myReviews.nodes = [review("APPROVED"; $head; 0)] | .reviewRequests.nodes = []')"

	run_queue

	[ "$status" -eq 0 ]
	assert_json '.prs[0] | [.requestedOfMe, .myLastReview.state, .myLastReview.onHead, .otherReviews]' \
		'[true,"APPROVED",false,["sam-second: APPROVED"]]'
	assert_json '.prs[1] | [.requestedOfMe, .myLastReview.onHead]' '[false,true]'
}

@test "stays portable to the Bash 3.2 that macOS ships" {
	# Every test runs the script through /bin/bash, so on macOS the whole suite
	# exercises Bash 3.2. These checks also hold the line where /bin/bash is newer.
	if [ "$(uname -s)" = Darwin ]; then
		/bin/bash -c '[ "${BASH_VERSINFO[0]}" -eq 3 ]'
	fi
	local code
	code=$(grep -v '^[[:space:]]*#' "$SCRIPT")
	[ -z "$(grep -wE 'mapfile|readarray' <<<"$code")" ]
	# Under set -u, Bash before 4.4 rejects an empty "${name[@]}", so every array
	# expansion must use the guarded ${name[@]+"${name[@]}"} form.
	[ -z "$(sed -E 's/\$\{[A-Za-z_]+\[@\]\+"\$\{[A-Za-z_]+\[@\]\}"\}//g' <<<"$code" | grep -E '\$\{[A-Za-z_]+\[@\]')" ]
}

@test "rejects malformed arguments before calling GitHub" {
	run_queue --since yesterday
	[ "$status" -eq 2 ]
	assert_stderr_contains "--since must be an ISO-8601 date or time"

	run_queue --repo
	[ "$status" -eq 2 ]

	run_queue --repo widgets
	[ "$status" -eq 2 ]

	run_queue widgets#7
	[ "$status" -eq 2 ]

	run_queue --teams
	[ "$status" -eq 2 ]

	[ ! -s "$GH_LOG" ]
}

@test "SKILL.md runs the bundled script and stays read-only" {
	grep -Fq 'bash "${CLAUDE_PLUGIN_ROOT}/skills/pr:review-queue/scripts/review-queue.sh"' "$SKILL"
	grep -Fq 'Never submit, approve, or dismiss a review, comment, resolve a thread, re-run a job, update a branch, or merge.' "$SKILL"
	grep -Fq -- '--since <previous checkedAt>' "$SKILL"
	grep -Fq '"Asked to review" means `user-review-requested:@me`.' "$SKILL"
}
