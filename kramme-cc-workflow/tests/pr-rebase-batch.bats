#!/usr/bin/env bats

load 'test_helper/common'

setup() {
	REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
	SCRIPT="$REPO_ROOT/skills/kramme:pr:rebase/scripts/batch-rebase.sh"
	REBASE_SKILL="$REPO_ROOT/skills/kramme:pr:rebase/SKILL.md"
	BATCH_REFERENCE="$REPO_ROOT/skills/kramme:pr:rebase/references/batch-mode.md"
	TMP_DIR="$(mktemp -d)"
	REMOTE="$TMP_DIR/remote.git"
	MAIN="$TMP_DIR/main"
	BIN_DIR="$TMP_DIR/bin"
	RESOLVER="$BIN_DIR/mock-stack-resolver"
	PLAN="$TMP_DIR/plan.tsv"
	RESULT="$TMP_DIR/result.tsv"
	mkdir -p "$BIN_DIR"
	write_mocks
	export PATH="$BIN_DIR:$PATH"
	export MOCK_PR_ROWS=""
	export MOCK_ALL_PR_ROWS=""
	export MOCK_GH_STATUS=0
	export MOCK_STACK_LOCAL_BRANCH=""
	export GH_LOG="$TMP_DIR/gh.log"

	init_test_git_repo "$MAIN" --origin "$REMOTE"
	git --git-dir="$REMOTE" symbolic-ref HEAD refs/heads/main
	cd "$MAIN"
}

teardown() {
	if [ -n "${TMP_DIR:-}" ] && [ -d "$TMP_DIR" ]; then
		rm -rf "$TMP_DIR"
	fi
}

write_mocks() {
	cat >"$BIN_DIR/gh" <<'GH'
#!/bin/sh
printf '%s\n' "$*" >>"$GH_LOG"
if [ "$1" = "repo" ] && [ "$2" = "view" ]; then
  printf 'owner/repo\n'
  exit 0
fi
if [ "$1" = "pr" ] && [ "$2" = "list" ]; then
  [ "${MOCK_GH_STATUS:-0}" -eq 0 ] || {
    printf 'mock gh failure\n' >&2
    exit "$MOCK_GH_STATUS"
  }
	  has_author=0
	  for arg in "$@"; do
	    [ "$arg" = "--author" ] && has_author=1
	  done
	  if [ "$has_author" -eq 1 ]; then
	    rows="${MOCK_PR_ROWS:-}"
	  else
	    rows="${MOCK_ALL_PR_ROWS:-${MOCK_PR_ROWS:-}}"
	  fi
	  [ -z "$rows" ] || printf '%b\n' "$rows"
  exit 0
fi
if [ "$1" = "pr" ] && [ "$2" = "view" ]; then
  number="$3"
  row=$(printf '%b\n' "${MOCK_PR_ROWS:-}" | awk -F '\t' -v number="$number" '$1 == number { print; exit }')
  [ -n "$row" ] || exit 1
  IFS='	' read -r _ head base cross <<EOF
$row
EOF
  printf '%s\t%s\t%s\t%s\tOPEN\n' "$number" "$head" "$base" "$cross"
  exit 0
fi
printf 'unexpected gh call: %s\n' "$*" >&2
exit 1
GH
	chmod +x "$BIN_DIR/gh"

	cat >"$RESOLVER" <<'RESOLVER'
#!/bin/sh
branch=$(git symbolic-ref --quiet --short HEAD) || exit 1
if [ -n "${MOCK_STACK_LOCAL_BRANCH:-}" ] && [ "$branch" = "$MOCK_STACK_LOCAL_BRANCH" ]; then
  printf 'STACK_MEMBERSHIP=local\n'
else
  printf 'STACK_MEMBERSHIP=none\n'
fi
RESOLVER
	chmod +x "$RESOLVER"
}

# Creates a branch from main, checks it out in its own worktree, commits one
# file there, and publishes it to origin.
add_pr_branch() {
	local name="$1"
	local file="${2:-$1.txt}"
	local worktree="$TMP_DIR/wt-$name"
	git -C "$MAIN" branch "$name" main
	git -C "$MAIN" worktree add "$worktree" "$name" >/dev/null 2>&1
	printf '%s\n' "$name" >"$worktree/$file"
	git -C "$worktree" add "$file"
	git -C "$worktree" commit -m "$name work" >/dev/null
	git -C "$worktree" push -u origin "$name" >/dev/null 2>&1
}

advance_main() {
	printf 'base advanced\n' >"$MAIN/tracked.txt"
	git -C "$MAIN" commit -am "advance base" >/dev/null
	git -C "$MAIN" push origin main >/dev/null 2>&1
}

pr_rows() {
	MOCK_PR_ROWS="$(printf '%s\\n' "$@")"
	MOCK_ALL_PR_ROWS="$MOCK_PR_ROWS"
	export MOCK_PR_ROWS
	export MOCK_ALL_PR_ROWS
}

plan_field() {
	awk -F '\t' -v branch="$1" -v column="$2" '$2 == branch { print $column }' "$PLAN"
}

result_field() {
	awk -F '\t' -v branch="$1" -v column="$2" '$2 == branch { print $column }' "$RESULT"
}

remote_head() {
	git --git-dir="$REMOTE" rev-parse "refs/heads/$1"
}

run_plan() {
	"$SCRIPT" plan --stack-resolver "$RESOLVER" >"$PLAN"
}

run_apply() {
	"$SCRIPT" apply --plan "$PLAN" --stack-resolver "$RESOLVER" >"$RESULT" 2>"$TMP_DIR/apply.err"
}

@test "rebases and pushes a clean branch that is behind its base" {
	add_pr_branch feature
	advance_main
	pr_rows $'11\tfeature\tmain\tfalse'
	local old_head
	old_head=$(git -C "$TMP_DIR/wt-feature" rev-parse HEAD)

	run_plan
	[ "$(head -n 1 "$PLAN")" = $'#pr\tbranch\tbase\tworktree\thead\tbase_oid\taction\treason' ]
	[ "$(plan_field feature 7)" = "rebase" ]
	[ "$(plan_field feature 5)" = "$old_head" ]
	[ "$(plan_field feature 6)" = "$(remote_head main)" ]

	run_apply
	local new_head
	new_head=$(git -C "$TMP_DIR/wt-feature" rev-parse HEAD)
	[ "$(result_field feature 4)" = "pushed" ]
	[ "$(result_field feature 5)" = "$old_head" ]
	[ "$(result_field feature 6)" = "$new_head" ]
	[ "$new_head" != "$old_head" ]
	[ "$(remote_head feature)" = "$new_head" ]
	git -C "$TMP_DIR/wt-feature" merge-base --is-ancestor "$(remote_head main)" "$new_head"
	grep -F 'pr list --repo owner/repo --author @me --state open' "$GH_LOG"
	! grep -F "$REMOTE" "$GH_LOG"
}

@test "counts untracked files as dirty even when status hides them" {
	add_pr_branch hidden
	advance_main
	git -C "$MAIN" config status.showUntrackedFiles no
	printf 'notes\n' >"$TMP_DIR/wt-hidden/untracked-notes.txt"
	pr_rows $'18\thidden\tmain\tfalse'

	run_plan
	[ "$(plan_field hidden 8)" = "dirty worktree" ]
}

@test "counts assume-unchanged tracked edits as dirty" {
	add_pr_branch hidden-tracked tracked.txt
	advance_main
	git -C "$TMP_DIR/wt-hidden-tracked" update-index --assume-unchanged tracked.txt
	printf 'hidden tracked edit\n' >"$TMP_DIR/wt-hidden-tracked/tracked.txt"
	pr_rows $'26\thidden-tracked\tmain\tfalse'

	run_plan
	[ "$(plan_field hidden-tracked 8)" = "dirty worktree" ]
}

@test "counts materialized skip-worktree edits as dirty" {
	add_pr_branch hidden-skip tracked.txt
	advance_main
	git -C "$TMP_DIR/wt-hidden-skip" update-index --skip-worktree tracked.txt
	printf 'hidden skip-worktree edit\n' >"$TMP_DIR/wt-hidden-skip/tracked.txt"
	pr_rows $'29\thidden-skip\tmain\tfalse'

	run_plan
	[ "$(plan_field hidden-skip 8)" = "dirty worktree" ]
}

@test "does not pass credential-bearing origin URLs to gh" {
	add_pr_branch credentialed
	advance_main
	git remote set-url origin 'https://user:token@example.com/owner/repo.git'
	git remote set-url --push origin "$REMOTE"
	pr_rows $'25\tcredentialed\tmain\tfalse'

	run_plan
	! grep -F 'token@example.com' "$GH_LOG"
	grep -F 'pr list --repo owner/repo --author @me --state open' "$GH_LOG"
}

@test "rejects control characters in the frozen push URL" {
	add_pr_branch control-url
	control_url=$(printf 'file://%s\033[2J' "$REMOTE")
	git remote set-url --push origin "$control_url"
	pr_rows $'27\tcontrol-url\tmain\tfalse'

	run "$SCRIPT" plan --stack-resolver "$RESOLVER"
	[ "$status" -eq 1 ]
	[[ "$output" == *"control characters"* ]]
	[ ! -s "$GH_LOG" ]
}

@test "reports a worktree stopped mid-rebase as an operation in progress" {
	add_pr_branch paused tracked.txt
	advance_main
	git -C "$TMP_DIR/wt-paused" rebase main >/dev/null 2>&1 || true
	pr_rows $'19\tpaused\tmain\tfalse'

	run_plan
	[ "$(plan_field paused 8)" = "operation in progress" ]
	git -C "$TMP_DIR/wt-paused" rebase --abort
}

@test "skips a row whose rebase fails before starting without calling it a conflict" {
	add_pr_branch hooked
	advance_main
	pr_rows $'20\thooked\tmain\tfalse'
	local old_head
	old_head=$(git -C "$TMP_DIR/wt-hooked" rev-parse HEAD)

	run_plan
	printf '#!/bin/sh\nexit 1\n' >"$(git -C "$MAIN" rev-parse --path-format=absolute --git-common-dir)/hooks/pre-rebase"
	chmod +x "$(git -C "$MAIN" rev-parse --path-format=absolute --git-common-dir)/hooks/pre-rebase"

	run_apply
	[ "$(result_field hooked 4)" = "skipped" ]
	[[ "$(result_field hooked 7)" == "rebase failed before starting"* ]]
	[ "$(git -C "$TMP_DIR/wt-hooked" rev-parse HEAD)" = "$old_head" ]
	[ "$(remote_head hooked)" = "$old_head" ]
}

@test "skips a dirty worktree and leaves it untouched" {
	add_pr_branch dirty
	advance_main
	printf 'uncommitted\n' >>"$TMP_DIR/wt-dirty/dirty.txt"
	pr_rows $'12\tdirty\tmain\tfalse'
	local old_head
	old_head=$(git -C "$TMP_DIR/wt-dirty" rev-parse HEAD)

	run_plan
	[ "$(plan_field dirty 7)" = "skip" ]
	[ "$(plan_field dirty 8)" = "dirty worktree" ]

	run_apply
	[ "$(result_field dirty 4)" = "skipped" ]
	[ "$(git -C "$TMP_DIR/wt-dirty" rev-parse HEAD)" = "$old_head" ]
	[ "$(remote_head dirty)" = "$old_head" ]
	grep -qx 'uncommitted' "$TMP_DIR/wt-dirty/dirty.txt"
	[ -z "$(git stash list)" ]
}

@test "aborts a conflicting rebase and leaves the branch and origin unchanged" {
	add_pr_branch clash tracked.txt
	advance_main
	pr_rows $'13\tclash\tmain\tfalse'
	local old_head
	old_head=$(git -C "$TMP_DIR/wt-clash" rev-parse HEAD)

	run_plan
	[ "$(plan_field clash 7)" = "rebase" ]

	run_apply
	[ "$(result_field clash 4)" = "conflict" ]
	[ "$(git -C "$TMP_DIR/wt-clash" rev-parse HEAD)" = "$old_head" ]
	[ "$(git -C "$TMP_DIR/wt-clash" symbolic-ref --short HEAD)" = "clash" ]
	[ ! -e "$(git -C "$TMP_DIR/wt-clash" rev-parse --path-format=absolute --git-path rebase-merge)" ]
	[ ! -e "$(git -C "$TMP_DIR/wt-clash" rev-parse --path-format=absolute --git-path rebase-apply)" ]
	[ -z "$(git -C "$TMP_DIR/wt-clash" status --porcelain)" ]
	[ "$(remote_head clash)" = "$old_head" ]
}

@test "skips a branch that already contains its base" {
	advance_main
	add_pr_branch current
	pr_rows $'14\tcurrent\tmain\tfalse'

	run_plan
	[ "$(plan_field current 7)" = "skip" ]
	[ "$(plan_field current 8)" = "already contains base" ]
}

@test "skips a branch whose local head differs from origin" {
	add_pr_branch ahead
	advance_main
	printf 'unpushed\n' >>"$TMP_DIR/wt-ahead/ahead.txt"
	git -C "$TMP_DIR/wt-ahead" commit -am "unpushed work" >/dev/null
	pr_rows $'15\tahead\tmain\tfalse'
	local local_head published_head
	local_head=$(git -C "$TMP_DIR/wt-ahead" rev-parse HEAD)
	published_head=$(remote_head ahead)

	run_plan
	[ "$(plan_field ahead 8)" = "local and origin differ" ]

	run_apply
	[ "$(git -C "$TMP_DIR/wt-ahead" rev-parse HEAD)" = "$local_head" ]
	[ "$(remote_head ahead)" = "$published_head" ]
}

@test "skips a row whose origin head moved after planning" {
	add_pr_branch raced
	advance_main
	pr_rows $'16\traced\tmain\tfalse'
	local old_head contender contender_head
	old_head=$(git -C "$TMP_DIR/wt-raced" rev-parse HEAD)

	run_plan
	[ "$(plan_field raced 7)" = "rebase" ]

	contender="$TMP_DIR/contender"
	git clone "$REMOTE" "$contender" >/dev/null 2>&1
	git -C "$contender" config user.email "other@example.com"
	git -C "$contender" config user.name "Other User"
	git -C "$contender" config commit.gpgsign false
	git -C "$contender" checkout raced >/dev/null 2>&1
	printf 'remote work\n' >>"$contender/raced.txt"
	git -C "$contender" commit -am "remote work" >/dev/null
	git -C "$contender" push origin raced >/dev/null 2>&1
	contender_head=$(git -C "$contender" rev-parse HEAD)

	run_apply
	[ "$(result_field raced 4)" = "skipped" ]
	[ "$(result_field raced 7)" = "origin changed since plan" ]
	[ "$(remote_head raced)" = "$contender_head" ]
	[ "$(git -C "$TMP_DIR/wt-raced" rev-parse HEAD)" = "$old_head" ]
}

@test "skips a row whose base moved after planning" {
	add_pr_branch stale
	advance_main
	pr_rows $'24\tstale\tmain\tfalse'

	run_plan
	printf 'base advanced again\n' >"$MAIN/tracked.txt"
	git -C "$MAIN" commit -am "advance base again" >/dev/null
	git -C "$MAIN" push origin main >/dev/null 2>&1

	run_apply
	[ "$(result_field stale 4)" = "skipped" ]
	[ "$(result_field stale 7)" = "base changed since plan" ]
}

@test "skips a row whose Pull Request target changed after planning" {
	add_pr_branch retargeted
	advance_main
	pr_rows $'36\tretargeted\tmain\tfalse'

	run_plan
	export MOCK_PR_ROWS=$'36\tretargeted\trelease\tfalse'

	run_apply
	[ "$(result_field retargeted 4)" = "skipped" ]
	[ "$(result_field retargeted 7)" = "Pull Request metadata changed since plan" ]
	[ "$(git -C "$TMP_DIR/wt-retargeted" rev-parse HEAD)" = "$(remote_head retargeted)" ]
}

@test "reports a rejected push with the pre-rebase head and keeps the local rebase" {
	add_pr_branch guarded
	advance_main
	pr_rows $'17\tguarded\tmain\tfalse'
	local old_head
	old_head=$(git -C "$TMP_DIR/wt-guarded" rev-parse HEAD)

	run_plan
	printf '#!/bin/sh\nexit 1\n' >"$REMOTE/hooks/pre-receive"
	chmod +x "$REMOTE/hooks/pre-receive"

	run_apply
	[ "$(result_field guarded 4)" = "push-rejected" ]
	[ "$(result_field guarded 5)" = "$old_head" ]
	[ "$(result_field guarded 6)" = "$(git -C "$TMP_DIR/wt-guarded" rev-parse HEAD)" ]
	[[ "$(result_field guarded 7)" == *"pre-rebase head is $old_head"* ]]
	[ "$(remote_head guarded)" = "$old_head" ]
}

@test "skips a branch whose base is another listed PR head" {
	add_pr_branch lower
	git -C "$MAIN" branch upper lower
	git -C "$MAIN" worktree add "$TMP_DIR/wt-upper" upper >/dev/null 2>&1
	git -C "$TMP_DIR/wt-upper" push -u origin upper >/dev/null 2>&1
	advance_main
	pr_rows $'21\tlower\tmain\tfalse' $'22\tupper\tlower\tfalse'

	run_plan
	[ "$(plan_field upper 8)" = "stacked on PR #21" ]
	[ "$(plan_field lower 7)" = "rebase" ]
}

@test "skips a branch stacked on another author's open PR" {
	git -C "$MAIN" branch teammate-base main
	git -C "$MAIN" worktree add "$TMP_DIR/wt-teammate-base" teammate-base >/dev/null 2>&1
	printf 'parent\n' >"$TMP_DIR/wt-teammate-base/parent.txt"
	git -C "$TMP_DIR/wt-teammate-base" add parent.txt
	git -C "$TMP_DIR/wt-teammate-base" commit -m "parent work" >/dev/null
	git -C "$TMP_DIR/wt-teammate-base" push -u origin teammate-base >/dev/null 2>&1
	git -C "$MAIN" branch child teammate-base
	git -C "$MAIN" worktree add "$TMP_DIR/wt-child" child >/dev/null 2>&1
	git -C "$TMP_DIR/wt-child" push -u origin child >/dev/null 2>&1
	pr_rows $'28\tchild\tteammate-base\tfalse'
	export MOCK_ALL_PR_ROWS=$'99\tteammate-base\tmain\tfalse'

	run_plan
	[ "$(plan_field child 8)" = "stacked on PR #99" ]
}

@test "skips a branch the stack resolver reports as a local stack member" {
	add_pr_branch stacked
	advance_main
	export MOCK_STACK_LOCAL_BRANCH=stacked
	pr_rows $'23\tstacked\tmain\tfalse'

	run_plan
	[ "$(plan_field stacked 8)" = "stack member" ]
}

@test "skips branches without a worktree, fork heads, and protected branches" {
	git -C "$MAIN" branch remote-only main
	git -C "$MAIN" push origin remote-only >/dev/null 2>&1
	git -C "$MAIN" branch develop main
	git -C "$MAIN" worktree add "$TMP_DIR/wt-develop" develop >/dev/null 2>&1
	pr_rows $'31\tremote-only\tmain\tfalse' $'32\tfork-topic\tmain\ttrue' $'33\tdevelop\tmain\tfalse'

	run_plan
	[ "$(plan_field remote-only 8)" = "not checked out in a local worktree" ]
	[ "$(plan_field fork-topic 8)" = "fork head" ]
	[ "$(plan_field develop 8)" = "protected branch" ]
	[ "$(grep -c $'\trebase\t' "$PLAN")" -eq 0 ]
}

@test "skips agent isolation worktrees" {
	git -C "$MAIN" branch agent-topic main
	git -C "$MAIN" worktree add "$TMP_DIR/.claude/worktrees/agent-1" agent-topic >/dev/null 2>&1
	pr_rows $'34\tagent-topic\tmain\tfalse'

	run_plan
	[ "$(plan_field agent-topic 8)" = "agent isolation worktree" ]
}

@test "plan exits 1 with no rows when gh fails" {
	add_pr_branch feature
	export MOCK_GH_STATUS=4

	run bash -c '"$1" plan --stack-resolver "$2" 2>/dev/null' _ "$SCRIPT" "$RESOLVER"

	[ "$status" -eq 1 ]
	[ -z "$output" ]
}

@test "plan stops explicitly when the open PR inventory reaches its cap" {
	local rows=""
	local i
	for i in $(seq 1 1000); do
		rows+="$i\\tbranch-$i\\tmain\\tfalse\\n"
	done
	export MOCK_PR_ROWS="$rows"

	run "$SCRIPT" plan --stack-resolver "$RESOLVER"

	[ "$status" -eq 1 ]
	[[ "$output" == *"batch limit was reached"* ]]
}

@test "plan rejects multiple configured push URLs before listing PRs" {
	local second_remote="$TMP_DIR/second.git"
	git init --bare "$second_remote" >/dev/null
	git remote set-url --push origin "$REMOTE"
	git remote set-url --add --push origin "$second_remote"

	run "$SCRIPT" plan --stack-resolver "$RESOLVER"

	[ "$status" -eq 1 ]
	[[ "$output" == *"exactly one push URL"* ]]
}

@test "apply rejects a changed push URL before mutating any worktree" {
	add_pr_branch drifted
	advance_main
	pr_rows $'35\tdrifted\tmain\tfalse'
	run_plan
	local second_remote="$TMP_DIR/second.git"
	git init --bare "$second_remote" >/dev/null
	git remote set-url --push origin "$second_remote"
	local old_head
	old_head=$(git -C "$TMP_DIR/wt-drifted" rev-parse HEAD)

	run "$SCRIPT" apply --plan "$PLAN" --stack-resolver "$RESOLVER"

	[ "$status" -eq 1 ]
	[[ "$output" == *"push URL changed since the plan was created"* ]]
	[ "$(git -C "$TMP_DIR/wt-drifted" rev-parse HEAD)" = "$old_head" ]
}

@test "apply refuses a plan without the batch plan header" {
	printf '11\tfeature\tmain\t/tmp\tx\ty\trebase\t-\n' >"$PLAN"

	run "$SCRIPT" apply --plan "$PLAN" --stack-resolver "$RESOLVER"

	[ "$status" -eq 1 ]
	[[ "$output" == *"batch plan header"* ]]
}

@test "skill routes --all-open to the direct-user-only batch reference" {
	grep -F 'argument-hint: "[--auto] [--force-push] [--fix-ci] [--base <branch>] [--all-open]"' "$REBASE_SKILL"
	grep -F 'A model caller never passes `--all-open`; batch mode is direct-user-only.' "$REBASE_SKILL"
	grep -F 'Stop with a usage error when `--auto`, `--fix-ci`, or `--base` accompanies it.' "$REBASE_SKILL"
	grep -F 'read `references/batch-mode.md` and follow it instead of Steps 1-7' "$REBASE_SKILL"
	grep -F '`{batch-script}` = `${CLAUDE_PLUGIN_ROOT}/skills/kramme:pr:rebase/scripts/batch-rebase.sh`' "$REBASE_SKILL"
	grep -F '`{stack-resolver}` = `${CLAUDE_PLUGIN_ROOT}/scripts/resolve-stack-membership.sh`' "$REBASE_SKILL"
	! grep -F -- '--all-open' <(sed -n '/^description:/p' "$REBASE_SKILL")
}

@test "batch reference confirms once and never resolves conflicts or stashes" {
	grep -F 'Batch mode never resolves conflicts.' "$BATCH_REFERENCE"
	grep -F 'Batch mode never stashes' "$BATCH_REFERENCE"
	grep -F 'never switches, creates, removes, resets, or re-points a worktree' "$BATCH_REFERENCE"
	grep -F 'Unless `FORCE_PUSH_MODE=true`, use `AskUserQuestion` once:' "$BATCH_REFERENCE"
	grep -F '"Rebase and force-push N branches?"' "$BATCH_REFERENCE"
	grep -F '"{batch-script}" plan --stack-resolver "{stack-resolver}"' "$BATCH_REFERENCE"
	grep -F '"{batch-script}" apply --plan "$PLAN_FILE" --stack-resolver "{stack-resolver}"' "$BATCH_REFERENCE"
	grep -F 'rm -f "$PLAN_FILE"' "$BATCH_REFERENCE"
}
