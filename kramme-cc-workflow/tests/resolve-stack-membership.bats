#!/usr/bin/env bats

load 'test_helper/common'

setup() {
	REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
	SCRIPT="$REPO_ROOT/scripts/resolve-stack-membership.sh"
	TMP_DIR="$(mktemp -d)"
	WORK="$TMP_DIR/work"
	BIN_DIR="$TMP_DIR/bin"
	GH_LOG="$TMP_DIR/gh.log"
	mkdir -p "$BIN_DIR"
	write_mock_gh
	export PATH="$BIN_DIR:$PATH"
	export GH_LOG

	init_test_git_repo "$WORK"
	cd "$WORK"
	git switch -c feature >/dev/null 2>&1
	git remote add origin https://github.com/acme/demo.git

	export MOCK_EXTENSION_STATUS=0
	export MOCK_EXTENSION_VERSION=0.1.0
	export MOCK_STACK_VIEW_STATUS=2
	export MOCK_PR_LIST_STATUS=0
	export MOCK_PR_NUMBER=""
	export MOCK_REPO_VIEW_STATUS=0
	export MOCK_STACK_API_STATUS=0
	export MOCK_STACK_NUMBER=""
}

teardown() {
	if [ -n "${TMP_DIR:-}" ] && [ -d "$TMP_DIR" ]; then
		rm -rf "$TMP_DIR"
	fi
}

write_mock_gh() {
	cat >"$BIN_DIR/gh" <<'GH'
#!/bin/sh
{
  printf 'command'
  for argument in "$@"; do
    printf ' [%s]' "$argument"
  done
  printf '\n'
} >>"$GH_LOG"

if [ "$1" = "stack" ] && [ "$2" = "--version" ]; then
  [ "${MOCK_EXTENSION_STATUS:-0}" -eq 0 ] || exit "$MOCK_EXTENSION_STATUS"
  printf 'gh stack version %s\n' "${MOCK_EXTENSION_VERSION:-0.1.0}"
  exit 0
fi

if [ "$1" = "stack" ] && [ "$2" = "view" ] && [ "$3" = "--json" ]; then
  if [ -n "${MOCK_STACK_VIEW_STDOUT+set}" ] || [ -n "${MOCK_STACK_VIEW_STDERR+set}" ]; then
    [ -z "${MOCK_STACK_VIEW_STDOUT:-}" ] || printf '%s\n' "$MOCK_STACK_VIEW_STDOUT"
    [ -z "${MOCK_STACK_VIEW_STDERR:-}" ] || printf '%s\n' "$MOCK_STACK_VIEW_STDERR" >&2
  elif [ "${MOCK_STACK_VIEW_STATUS:-2}" -eq 0 ]; then
    printf '{"trunk":"main","currentBranch":"feature","branches":[{"name":"feature"}]}\n'
  else
    printf 'mock stack view failure\n' >&2
  fi
  exit "${MOCK_STACK_VIEW_STATUS:-2}"
fi

if [ "$1" = "pr" ] && [ "$2" = "list" ]; then
  [ "${MOCK_PR_LIST_STATUS:-0}" -eq 0 ] || {
    printf 'mock PR lookup failure\n' >&2
    exit "$MOCK_PR_LIST_STATUS"
  }
  printf '%s\n' "${MOCK_PR_NUMBER:-}"
  exit 0
fi

if [ "$1" = "repo" ] && [ "$2" = "view" ]; then
  [ "${MOCK_REPO_VIEW_STATUS:-0}" -eq 0 ] || exit "$MOCK_REPO_VIEW_STATUS"
  printf 'acme/demo\n'
  exit 0
fi

if [ "$1" = "api" ] && [ "$2" = "graphql" ]; then
  [ "${MOCK_STACK_API_STATUS:-0}" -eq 0 ] || {
    printf 'mock GraphQL failure\n' >&2
    exit "$MOCK_STACK_API_STATUS"
  }
  printf '%s\n' "${MOCK_STACK_NUMBER:-}"
  exit 0
fi

exit 97
GH
	chmod +x "$BIN_DIR/gh"
}

load_assignments() {
	local assignments
	assignments=$(printf '%s\n' "$output" | grep -E '^(STACK_MEMBERSHIP|STACK_CLI_AVAILABLE|STACK_PR_NUMBER|STACK_NUMBER)=' || true)
	eval "$assignments"
}

@test "reports local membership when gh-stack tracks the current branch" {
	export MOCK_STACK_VIEW_STATUS=0

	run "$SCRIPT"

	[ "$status" -eq 0 ]
	load_assignments
	[ "$STACK_MEMBERSHIP" = "local" ]
	[ "$STACK_CLI_AVAILABLE" = "1" ]
	[ "$STACK_PR_NUMBER" = "" ]
	[ "$STACK_NUMBER" = "" ]
	! grep -q 'command \[pr\] \[list\]' "$GH_LOG"
}

@test "treats a zero-exit stack view without stack JSON as untracked" {
	export MOCK_STACK_VIEW_STATUS=0
	export MOCK_STACK_VIEW_STDOUT=""
	export MOCK_STACK_VIEW_STDERR='✗ current branch "feature" is not part of a stack'
	export MOCK_PR_NUMBER=17

	run "$SCRIPT"

	[ "$status" -eq 0 ]
	load_assignments
	[ "$STACK_MEMBERSHIP" = "none" ]
	[ "$STACK_PR_NUMBER" = "17" ]
	[[ "$output" != *"is not part of a stack"* ]]
	grep -q 'command \[api\] \[graphql\]' "$GH_LOG"
}

@test "consults the remote stack when a zero-exit stack view prints plain text" {
	export MOCK_STACK_VIEW_STATUS=0
	export MOCK_STACK_VIEW_STDOUT='current branch "feature" is not part of a stack'
	export MOCK_PR_NUMBER=17
	export MOCK_STACK_NUMBER=41

	run "$SCRIPT"

	[ "$status" -eq 0 ]
	load_assignments
	[ "$STACK_MEMBERSHIP" = "remote" ]
	[ "$STACK_NUMBER" = "41" ]
}

@test "reports local membership when stack JSON follows leading whitespace" {
	export MOCK_STACK_VIEW_STATUS=0
	export MOCK_STACK_VIEW_STDOUT='
  {"trunk":"main","currentBranch":"feature","branches":[{"name":"feature"}]}'

	run "$SCRIPT"

	[ "$status" -eq 0 ]
	load_assignments
	[ "$STACK_MEMBERSHIP" = "local" ]
	! grep -q 'command \[pr\] \[list\]' "$GH_LOG"
}

@test "fails closed when a zero-exit stack view prints malformed JSON" {
	export MOCK_STACK_VIEW_STATUS=0
	export MOCK_STACK_VIEW_STDOUT='{not-json'

	run "$SCRIPT"

	[ "$status" -eq 1 ]
	[[ "$output" == *"gh stack view returned invalid stack JSON"* ]]
	! grep -q 'command \[pr\] \[list\]' "$GH_LOG"
}

@test "fails closed when a zero-exit stack view prints the wrong JSON shape" {
	export MOCK_STACK_VIEW_STATUS=0
	export MOCK_STACK_VIEW_STDOUT='[]'

	run "$SCRIPT"

	[ "$status" -eq 1 ]
	[[ "$output" == *"gh stack view returned invalid stack JSON"* ]]
	! grep -q 'command \[pr\] \[list\]' "$GH_LOG"
}

@test "reports no membership only after a definitive remote lookup" {
	export MOCK_PR_NUMBER=17

	run "$SCRIPT"

	[ "$status" -eq 0 ]
	load_assignments
	[ "$STACK_MEMBERSHIP" = "none" ]
	[ "$STACK_CLI_AVAILABLE" = "1" ]
	[ "$STACK_PR_NUMBER" = "17" ]
	[ "$STACK_NUMBER" = "" ]
	grep -q 'command \[api\] \[graphql\]' "$GH_LOG"
}

@test "detects server-side membership when local tracking and extension are absent" {
	export MOCK_EXTENSION_STATUS=1
	export MOCK_PR_NUMBER=17
	export MOCK_STACK_NUMBER=41

	run "$SCRIPT"

	[ "$status" -eq 0 ]
	load_assignments
	[ "$STACK_MEMBERSHIP" = "remote" ]
	[ "$STACK_CLI_AVAILABLE" = "0" ]
	[ "$STACK_PR_NUMBER" = "17" ]
	[ "$STACK_NUMBER" = "41" ]
}

@test "fails closed when gh-stack predates safe rewrite handling" {
	export MOCK_EXTENSION_VERSION=0.0.8

	run "$SCRIPT"

	[ "$status" -eq 1 ]
	[[ "$output" == *"gh-stack v0.0.8 is unsupported"* ]]
	[[ "$output" == *"gh extension upgrade stack"* ]]
	! grep -q 'command \[stack\] \[view\]' "$GH_LOG"
	! grep -q 'command \[pr\] \[list\]' "$GH_LOG"
}

@test "fails closed when the gh-stack version cannot be parsed" {
	export MOCK_EXTENSION_VERSION=development

	run "$SCRIPT"

	[ "$status" -eq 1 ]
	[[ "$output" == *"Could not parse the installed gh-stack version"* ]]
	! grep -q 'command \[stack\] \[view\]' "$GH_LOG"
}

@test "fails closed on an unexpected gh-stack error" {
	export MOCK_STACK_VIEW_STATUS=4

	run "$SCRIPT"

	[ "$status" -eq 4 ]
	[[ "$output" == *"mock stack view failure"* ]]
	[[ "$output" == *"stack membership is unknown"* ]]
	! grep -q 'command \[pr\] \[list\]' "$GH_LOG"
}

@test "fails closed when the GraphQL stack query fails" {
	export MOCK_PR_NUMBER=17
	export MOCK_STACK_API_STATUS=1

	run "$SCRIPT"

	[ "$status" -eq 1 ]
	[[ "$output" == *"Could not query GitHub stack metadata for PR #17"* ]]
}

@test "passes a metacharacter branch to gh as one inert argument" {
	local branch='topic-$(touch${IFS}$PWNED_FILE)'
	export PWNED_FILE="$TMP_DIR/pwned"
	git switch -c "$branch" >/dev/null 2>&1

	run "$SCRIPT"

	[ "$status" -eq 0 ]
	load_assignments
	[ "$STACK_MEMBERSHIP" = "none" ]
	grep -F "[$branch]" "$GH_LOG"
	[ ! -e "$PWNED_FILE" ]
}

@test "returns none without consulting gh for a non-GitHub remote" {
	git remote set-url origin https://example.com/acme/demo.git
	export MOCK_EXTENSION_STATUS=97

	run "$SCRIPT"

	[ "$status" -eq 0 ]
	load_assignments
	[ "$STACK_MEMBERSHIP" = "none" ]
	[ ! -s "$GH_LOG" ]
}

@test "checks local stack membership when a non-origin remote points to GitHub" {
	git remote set-url origin https://example.com/acme/demo.git
	git remote add upstream git@github.com:acme/demo.git
	export MOCK_STACK_VIEW_STATUS=0

	run "$SCRIPT"

	[ "$status" -eq 0 ]
	load_assignments
	[ "$STACK_MEMBERSHIP" = "local" ]
	grep -q 'command \[stack\] \[view\]' "$GH_LOG"
}

@test "stack skills use the shared fail-closed membership resolver" {
	local consumer
	for consumer in \
		"$REPO_ROOT/skills/kramme:git:fixup/SKILL.md" \
		"$REPO_ROOT/skills/kramme:git:recreate-commits/SKILL.md" \
		"$REPO_ROOT/skills/kramme:pr:fix-ci/SKILL.md" \
		"$REPO_ROOT/skills/kramme:pr:rebase/SKILL.md" \
		"$REPO_ROOT/skills/kramme:pr:stack/SKILL.md"; do
		grep -F 'resolve-stack-membership.sh' "$consumer"
	done

	! grep -R -E 'gh stack view --json.*&& IN_STACK=true' \
		"$REPO_ROOT/skills/kramme:git:fixup" \
		"$REPO_ROOT/skills/kramme:git:recreate-commits" \
		"$REPO_ROOT/skills/kramme:pr:fix-ci" \
		"$REPO_ROOT/skills/kramme:pr:rebase"
}

@test "stack command examples preserve operand and placeholder boundaries" {
	local stack_skill="$REPO_ROOT/skills/kramme:pr:stack/SKILL.md"
	local strategies="$REPO_ROOT/skills/kramme:pr:plan-split/references/strategies.md"

	grep -F 'git check-ref-format --branch "$branch"' "$stack_skill"
	grep -F 'gh stack init "${STACK_BRANCHES[@]}"' "$stack_skill"
	grep -F 'gh stack link "${STACK_ITEMS[@]}"' "$stack_skill"
	grep -F 'gh stack init --base "$BASE_BRANCH" stack-1-schema' "$strategies"
	grep -F 'git checkout "$REFERENCE_BRANCH" -- db/migrations/' "$strategies"
	! grep -E '< (base|reference)-branch >' "$strategies"
}

@test "history rewrite flows restack before their stack-wide push" {
	local flow
	for flow in \
		"$REPO_ROOT/skills/kramme:pr:fix-ci/SKILL.md" \
		"$REPO_ROOT/skills/kramme:pr:fix-ci/references/fixup-flow.md" \
		"$REPO_ROOT/skills/kramme:pr:fix-ci/references/consolidation-flow.md"; do
		local rebase_line
		local push_line
		rebase_line=$(grep -n 'gh stack rebase --upstack --no-trunk' "$flow" | tail -1 | cut -d: -f1)
		push_line=$(grep -n '^[[:space:]]*gh stack push' "$flow" | tail -1 | cut -d: -f1)
		[ -n "$rebase_line" ]
		[ -n "$push_line" ]
		[ "$rebase_line" -lt "$push_line" ]
	done
}

@test "fixup restacks locally without publishing the stack" {
	local fixup="$REPO_ROOT/skills/kramme:git:fixup/SKILL.md"
	local report_step
	report_step=$(sed -n '/### Step 7: Report Results/,/## Error Handling/p' "$fixup")

	grep -F 'gh stack rebase --upstack --no-trunk' <<<"$report_step"
	! grep -E '^[[:space:]]*gh stack push' <<<"$report_step"
	grep -F 'Do not run `gh stack push` automatically' <<<"$report_step"
}

@test "recreate-commits restacks before no-push and local-only exits" {
	local recreate="$REPO_ROOT/skills/kramme:git:recreate-commits/SKILL.md"
	local restack_line
	local no_push_line
	local local_only_line
	restack_line=$(grep -n 'the rewrite has orphaned every branch' "$recreate" | tail -1 | cut -d: -f1)
	no_push_line=$(grep -n 'If `--no-push` was passed' "$recreate" | tail -1 | cut -d: -f1)
	local_only_line=$(grep -n 'the recreation is local-only' "$recreate" | tail -1 | cut -d: -f1)

	[ "$restack_line" -lt "$no_push_line" ]
	[ "$restack_line" -lt "$local_only_line" ]
}

@test "merge and conflict guidance match gh-stack semantics" {
	local stack_skill="$REPO_ROOT/skills/kramme:pr:stack/SKILL.md"
	local rules="$REPO_ROOT/skills/kramme:pr:stack/references/cli-agent-rules.md"

	grep -F 'highest PR the user intends to land' "$stack_skill"
	grep -F 'use the top PR to land the entire stack' "$stack_skill"
	grep -F 'gh stack merge "$TARGET_PR_NUMBER" "${MERGE_ARGS[@]}"' "$stack_skill"
	! grep -F 'Merging from the CLI is not supported' "$stack_skill" "$rules"
	grep -F 'After `gh stack sync`, all branches were restored' "$stack_skill"
	grep -F 'After `gh stack rebase`, a rebase session remains active' "$stack_skill"
	grep -F '`sync` restores all branches' "$rules"
	grep -F '`rebase` leaves its session active' "$rules"
}

@test "rebase verification keeps the revision range in one shell argument" {
	local rebase_skill="$REPO_ROOT/skills/kramme:pr:rebase/SKILL.md"

	grep -F 'git log --oneline "origin/$BASE_BRANCH..HEAD"' "$rebase_skill"
	! grep -F 'git log --oneline origin/ < base-branch > ..HEAD' "$rebase_skill"
}
