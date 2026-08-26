#!/usr/bin/env bats

load 'test_helper/common'

extract_commit_and_include_block() {
	python3 - "$1" "$2" <<'PY'
import pathlib
import sys

source = pathlib.Path(sys.argv[1]).read_text()
section = source.split('#### If "Commit and include"', 1)[1]
block = section.split("```bash", 1)[1].split("```", 1)[0].strip()
pathlib.Path(sys.argv[2]).write_text(f"{block}\n")
PY
}

file_mode() {
	if [ "$(uname -s)" = "Darwin" ]; then
		stat -f '%Lp' "$1"
	else
		stat -c '%a' "$1"
	fi
}

@test "pr-create owns lease-protected remote publication" {
	run bash -c '
    set -e
    cd "'"$BATS_TEST_DIRNAME"'/.."
    create="skills/kramme:pr:create/SKILL.md"
    branch="skills/kramme:pr:create/references/branch-and-platform-handling.md"
    confirmation="skills/kramme:pr:create/references/confirmation-and-creation.md"
    recreate="skills/kramme:git:recreate-commits/SKILL.md"

    grep -qF "[--authorize-history-rewrite]" "$create"
    grep -qF "AUTHORIZE_HISTORY_REWRITE=true" "$create"
    grep -qF "Auto mode does not set this variable" "$create"
    grep -qF -- "args: \"--auto --base {base-source-ref} --base-commit {base-ref} --backup-ref {recreate-backup-ref} --no-push\"" "$create"
    grep -qF "pass \`--authorize-history-rewrite\` only when the user supplied that flag" "$create"
    ! grep -qF "args: \"--auto --no-push\"" "$create"
    grep -qF "Always pass \`--base {base-source-ref} --base-commit {base-ref} --backup-ref {recreate-backup-ref} --no-push\`" "$create"
    grep -qF "Do not push or change upstream configuration" "$branch"
    ! grep -qF "git push -u origin \$(git branch --show-current)" "$branch"
    grep -qF "Step 5 proved that \`{rollback-origin-ref}\` was absent" "$confirmation"
    grep -qF "If any actor creates the remote branch after Step 5, the lease fails" "$confirmation"
    grep -qF "no Pull Request could have existed for that branch at the moment this workflow created it" "$confirmation"
    grep -qF "Immediately before any push, repeat the fail-closed open-Pull-Request check" "$confirmation"
    grep -qF "If an open Pull Request appeared after Step 3.5" "$confirmation"
    grep -qF "does not prove that this invocation owns the Pull Request" "$confirmation"
    grep -qF -- "--force-with-lease=\"{rollback-origin-ref}:\"" "$confirmation"
    grep -qF -- "--force-with-lease=\"refs/heads/{feature-branch}:{observed-origin-oid}\"" "$confirmation"
    grep -qF -- "--no-follow-tags" "$confirmation"
    grep -qF -- "\"{origin-push-url}\" \"{entry-commit}:refs/heads/{feature-branch}\"" "$confirmation"
    ! grep -qF -- "-u origin \"HEAD:refs/heads/{feature-branch}\"" "$confirmation"
    grep -qF "GIT_TERMINAL_PROMPT=0 GCM_INTERACTIVE=Never" "$confirmation"
    grep -qF "authentication failure is a hard blocker, never a reason to wait for terminal input" "$confirmation"
    ! grep -qF -- "--force-with-lease=\"{rollback-origin-ref}:{rollback-origin-oid}\"" "$confirmation"
    grep -qF "The exact lease rejects every remote change after classification" "$confirmation"
    grep -qF "The immediately preceding strict-ancestor proof ensures this invocation cannot use the force capability to replace remote-only work" "$confirmation"
    grep -qF "Do not use plain \`--force\`, an absence lease for a pre-existing remote ref" "$confirmation"
    grep -qF "fresh mode'\''s sole remote update before Pull Request creation" "$confirmation"
    grep -qF "[--no-push] [--authorize-history-rewrite]" "$recreate"
    grep -qF "If \`--no-push\` was passed, do not run any push command" "$recreate"
    grep -qF "Automatic stack-wide rewriting additionally requires \`--authorize-history-rewrite\`" ../README.md
    grep -qF "A non-auto stacked invocation may instead use separate interactive confirmations" ../README.md
    grep -qF "## Step 4.5: Reject Stacked Branches" "$create"
    grep -qF "STACK_RESOLVED=\$(\"\${CLAUDE_PLUGIN_ROOT}/scripts/resolve-stack-membership.sh\")" "$create"
    grep -qF "if [ \"\$STACK_MEMBERSHIP\" != \"none\" ]; then" "$create"
    grep -qF "use kramme:pr:stack instead" "$create"
    grep -qF "Both locally tracked and server-side stacks stop here" "$create"
    grep -qF "any later stack detection is state drift" "$create"
    ! grep -qF "leaves any stacked rewrite to the nested skill" "$create"
    ! grep -qF "\`--auto\` alone is not authorization" "$recreate"
  '

	assert_required_contracts_registered \
		pr-create-history-rewrite-authorization \
		pr-create-deferred-upstream-contract \
		pr-create-absence-lease-contract \
		pr-create-origin-push-url-helper \
		pr-create-push-failure-rollback \
		pr-create-remote-absence-contract \
		recreate-commits-deferred-push-contract \
		recreate-commits-push-target-helper \
		recreate-commits-retry-safe-backup \
		resolve-base-pinned-commit-contract \
		verify-rewrite-state-helper

	[ "$status" -eq 0 ]
}

@test "recreate-commits auto mode stays within the protected unstacked boundary" {
	run bash -c '
    set -e
    cd "'"$BATS_TEST_DIRNAME"'/.."
    recreate="skills/kramme:git:recreate-commits/SKILL.md"

    grep -qF "If \`IN_STACK=true\` and \`--auto\` was passed without \`--authorize-history-rewrite\`, stop before the reset" "$recreate"
    grep -qF "STACK_BRANCH_NAMES=\$(resolve_stack_branch_names)" "$recreate"
    grep -qF "require its output to equal \`STACK_BRANCH_NAMES\` byte-for-byte" "$recreate"
    grep -qF "enumerate every branch in \`STACK_BRANCHES\`" "$recreate"
    grep -qF "explicit confirmation authorizing both the reset and that restack" "$recreate"
    grep -qF "explicit confirmation authorizing that whole-stack push" "$recreate"
    grep -qF "A reset/restack confirmation does not also authorize publication" "$recreate"
    grep -qF -- "--base-branch \"\$BASE_BRANCH\"" "$recreate"
    grep -qF "[ \"\$(git symbolic-ref --quiet --short HEAD)\" = \"\$ORIGINAL_BRANCH\" ]" "$recreate"
    grep -qF "verify-rewrite-state.sh" "$recreate"
    grep -qF "The current branch changed after push-target resolution; stop before pushing." "$recreate"
    grep -qF "without the captured ref-specific \`--force-with-lease\`" "$recreate"
    grep -qF -- "--no-follow-tags" "$recreate"
    grep -qF -- "--force-with-lease=\"\${PUSH_REMOTE_REF}:\${PUSH_LEASE_OID}\"" "$recreate"
    grep -qF -- "-- \"\$PUSH_REMOTE_URL\" \"HEAD:\${PUSH_REMOTE_REF}\"" "$recreate"
    ! grep -qF "push with \`git push --force-with-lease\`" "$recreate"
    ! grep -qF "\`--auto\` alone is not authorization" "$recreate"
  '

	[ "$status" -eq 0 ]
}

@test "recreate-commits coarse mode selects first-pass granularity without widening authorization" {
	run bash -c '
    set -e
    cd "'"$BATS_TEST_DIRNAME"'/.."
    recreate="skills/kramme:git:recreate-commits/SKILL.md"

    grep -qF "[--auto] [--coarse|--granular]" "$recreate"
    grep -qF -- "\`--coarse\` — Force coarse decomposition: one commit per major grouping" "$recreate"
    grep -qF "Combine it with \`--auto\` to retain all other auto-mode behavior while pinning coarse granularity" "$recreate"
    grep -qF "does not authorize the history rewrite or publication by itself" "$recreate"
    grep -qF "If \`--coarse\` was combined with \`--granular\`, stop" "$recreate"
    grep -qF "\`--coarse\` selects **Coarse** granularity unconditionally and skips the granularity question" "$recreate"
    grep -qF "When \`--auto\` accompanies either fixed-granularity flag, that flag replaces automatic granularity selection and every other auto-mode behavior remains in effect" "$recreate"
    grep -qF "For **coarse** granularity, stop here — each grouping becomes one commit" "$recreate"
    grep -qF "Before resetting, unless \`--authorize-history-rewrite\` was passed or (\`--auto\` was passed and \`IN_STACK=false\`), obtain the applicable confirmation" "$recreate"
    grep -qF "Before pushing, unless \`--authorize-history-rewrite\` was passed or (\`--auto\` was passed and \`IN_STACK=false\`), obtain the applicable publication confirmation" "$recreate"
    grep -qF "[--auto] [--coarse\\|--granular]" ../README.md
  '

	[ "$status" -eq 0 ]
}

@test "absence lease rejects a concurrently created remote branch" {
	run bash -c '
    set -e
    root="$1"
    remote="$root/remote.git"
    publisher="$root/publisher"
    contender="$root/contender"

    git init --bare "$remote" >/dev/null
    git init "$publisher" >/dev/null
    git -C "$publisher" config user.name "Test User"
    git -C "$publisher" config user.email "test@example.com"
    printf "base\n" >"$publisher/file.txt"
    git -C "$publisher" add file.txt
    git -C "$publisher" commit -m "base" >/dev/null
    git -C "$publisher" branch -M main
    git -C "$publisher" remote add origin "$remote"
    git -C "$publisher" push -u origin main >/dev/null
    git --git-dir="$remote" symbolic-ref HEAD refs/heads/main

    git clone "$remote" "$contender" >/dev/null
    git -C "$publisher" checkout -b feature >/dev/null
    printf "publisher\n" >>"$publisher/file.txt"
    git -C "$publisher" commit -am "publisher work" >/dev/null

    test -z "$(git -C "$publisher" ls-remote --heads origin refs/heads/feature)"
    git -C "$contender" checkout -b feature origin/main >/dev/null
    git -C "$contender" push origin HEAD:refs/heads/feature >/dev/null
    expected=$(git -C "$contender" rev-parse HEAD)

    if "${CONDUCTOR_REAL_GIT_PATH:-git}" -C "$publisher" push \
      --force-with-lease=refs/heads/feature: \
      origin HEAD:refs/heads/feature >/dev/null 2>&1; then
      exit 1
    fi

    actual=$(git -C "$publisher" ls-remote --heads origin refs/heads/feature | awk "{print \$1}")
    test "$actual" = "$expected"
  ' _ "$BATS_TEST_TMPDIR"

	[ "$status" -eq 0 ]
}

@test "OID lease publishes the immutable strict fast-forward without widening or retargeting" {
	remote="$BATS_TEST_TMPDIR/remote.git"
	publisher="$BATS_TEST_TMPDIR/publisher"
	resolver="$BATS_TEST_DIRNAME/../skills/kramme:pr:create/scripts/resolve-origin-push-url.sh"
	init_test_git_repo "$publisher" --origin "$remote" --file file.txt
	git --git-dir="$remote" symbolic-ref HEAD refs/heads/main

	git -C "$publisher" checkout -b feature >/dev/null
	printf "published\n" >>"$publisher/file.txt"
	git -C "$publisher" commit -am "published work" >/dev/null
	git -C "$publisher" push -u origin feature >/dev/null
	observed=$(git -C "$publisher" rev-parse HEAD)

	printf "local one\n" >>"$publisher/file.txt"
	git -C "$publisher" commit -am "local work one" >/dev/null
	printf "local two\n" >>"$publisher/file.txt"
	git -C "$publisher" commit -am "local work two" >/dev/null
	entry_commit=$(git -C "$publisher" rev-parse HEAD)
	upstream_remote=$(git -C "$publisher" config --get branch.feature.remote)
	upstream_merge=$(git -C "$publisher" config --get branch.feature.merge)

	git -C "$publisher" merge-base --is-ancestor "$observed" "$entry_commit"
	git -C "$publisher" tag -a release-candidate "$entry_commit" -m "release candidate"
	git -C "$publisher" config push.followTags true
	printf "late local change\n" >>"$publisher/file.txt"
	git -C "$publisher" commit -am "late local work" >/dev/null
	live_head=$(git -C "$publisher" rev-parse HEAD)
	[ "$live_head" != "$entry_commit" ]

	cd "$publisher"
	run "$resolver"
	[ "$status" -eq 0 ]
	eval "$output"
	[ "$ORIGIN_PUSH_URL" = "$remote" ]

	run "${CONDUCTOR_REAL_GIT_PATH:-git}" push \
		--no-follow-tags \
		--force-with-lease=refs/heads/feature:"$observed" \
		-- "$ORIGIN_PUSH_URL" "$entry_commit:refs/heads/feature"
	[ "$status" -eq 0 ]

	remote_head=$(git ls-remote --heads -- "$ORIGIN_PUSH_URL" refs/heads/feature | awk '{print $1}')
	[ "$remote_head" = "$entry_commit" ]
	[ "$(git rev-parse HEAD)" = "$live_head" ]
	[ "$(git config --get branch.feature.remote)" = "$upstream_remote" ]
	[ "$(git config --get branch.feature.merge)" = "$upstream_merge" ]
	! git --git-dir="$remote" show-ref --verify --quiet refs/tags/release-candidate
}

@test "OID lease rejects a remote change after fast-forward classification" {
	remote="$BATS_TEST_TMPDIR/remote.git"
	publisher="$BATS_TEST_TMPDIR/publisher"
	contender="$BATS_TEST_TMPDIR/contender"
	init_test_git_repo "$publisher" --origin "$remote" --file file.txt
	git --git-dir="$remote" symbolic-ref HEAD refs/heads/main

	git -C "$publisher" checkout -b feature >/dev/null
	printf "published\n" >>"$publisher/file.txt"
	git -C "$publisher" commit -am "published work" >/dev/null
	git -C "$publisher" push -u origin feature >/dev/null
	observed=$(git -C "$publisher" rev-parse HEAD)

	git clone "$remote" "$contender" >/dev/null
	git -C "$contender" config user.name "Other User"
	git -C "$contender" config user.email "other@example.com"
	git -C "$contender" config commit.gpgsign false
	git -C "$contender" checkout feature >/dev/null

	printf "local\n" >>"$publisher/file.txt"
	git -C "$publisher" commit -am "local work" >/dev/null
	entry_commit=$(git -C "$publisher" rev-parse HEAD)
	git -C "$publisher" merge-base --is-ancestor "$observed" "$entry_commit"

	printf "remote\n" >>"$contender/file.txt"
	git -C "$contender" commit -am "remote work" >/dev/null
	git -C "$contender" push origin HEAD:refs/heads/feature >/dev/null
	contender_head=$(git -C "$contender" rev-parse HEAD)

	run "${CONDUCTOR_REAL_GIT_PATH:-git}" -C "$publisher" push \
		--no-follow-tags \
		--force-with-lease=refs/heads/feature:"$observed" \
		-- "$remote" "$entry_commit:refs/heads/feature"
	[ "$status" -ne 0 ]

	remote_head=$(git -C "$publisher" ls-remote --heads -- "$remote" refs/heads/feature | awk '{print $1}')
	[ "$remote_head" = "$contender_head" ]
	[ "$remote_head" != "$entry_commit" ]
}

@test "origin push URL resolver rejects multiple publication endpoints" {
	remote="$BATS_TEST_TMPDIR/remote.git"
	mirror="$BATS_TEST_TMPDIR/mirror.git"
	publisher="$BATS_TEST_TMPDIR/publisher"
	resolver="$BATS_TEST_DIRNAME/../skills/kramme:pr:create/scripts/resolve-origin-push-url.sh"
	init_test_git_repo "$publisher" --origin "$remote" --file file.txt
	git clone --bare "$remote" "$mirror" >/dev/null
	git -C "$publisher" remote set-url --push origin "$remote"
	git -C "$publisher" remote set-url --add --push origin "$mirror"

	cd "$publisher"
	run "$resolver"

	[ "$status" -ne 0 ]
	[[ "$output" == *"must resolve to exactly one push URL"* ]]
}

@test "existing remote branch recovers at exact tip or safely fast-forwards from an ancestor" {
	run bash -c '
    set -e
    cd "'"$BATS_TEST_DIRNAME"'/.."
    create="skills/kramme:pr:create/SKILL.md"
    branch="skills/kramme:pr:create/references/branch-and-platform-handling.md"
    state="skills/kramme:pr:create/references/state-and-rollback.md"
    confirmation="skills/kramme:pr:create/references/confirmation-and-creation.md"

    grep -qF "REMOTE_RECOVERY_MODE=true" "$create"
    grep -qF "REMOTE_FAST_FORWARD_MODE=true" "$create"
    grep -qF "skip Steps 5 and 6" "$create"
    grep -qF "preserve the existing local commit history" "$create"
    grep -qF "capture its exact full OID as \`{observed-origin-oid}\`" "$branch"
    grep -qF "scripts/resolve-origin-push-url.sh" "$branch"
    grep -qF "git ls-remote --heads -- \"{origin-push-url}\"" "$branch"
    grep -qF "git fetch --no-tags --no-write-fetch-head -- \"{origin-push-url}\"" "$branch"
    grep -qF "git merge-base --is-ancestor \"{observed-origin-oid}\" \"{entry-commit}\"" "$branch"
    grep -qF "record \`{branch-action}=fast-forward-existing-remote\`" "$branch"
    grep -qF "report that the remote contains commits absent locally" "$branch"
    grep -qF "report genuine divergence" "$branch"
    grep -qF "Never merge, reset, rebase, or invoke history rewriting" "$branch"
    grep -qF "If uncommitted changes exist, stop" "$create"
    grep -qF "Never adopt a remote branch selected from a different entry checkout" "$branch"
    grep -qF "continue only when it returns no matching ref" "$state"
    grep -qF "stop before branch creation or \`kramme:git:recreate-commits\`" "$state"
    grep -qF "cannot atomically prevent another actor from opening a Pull Request" "$state"
    grep -qF "REMOTE_RECOVERY_MODE=true" "$confirmation"
    grep -qF "REMOTE_FAST_FORWARD_MODE=true" "$confirmation"
    grep -qF "Do not run \`git push\` in this mode" "$confirmation"
    grep -qF "Require the authoritative remote OID to remain exactly \`{observed-origin-oid}\`" "$confirmation"
    grep -qF "Require \`HEAD\` to remain exactly \`{entry-commit}\`" "$confirmation"
    grep -qF "require its OID to remain exactly \`{observed-origin-oid}\`" "$confirmation"
    grep -qF "The exact lease rejects every remote change after classification" "$confirmation"
    grep -qF -- "--head \"{feature-branch}\"" "$confirmation"
    grep -qF "prevents \`gh pr create\` from offering to push or fork" "$confirmation"
    grep -qF "Do not use plain \`--force\`, an absence lease for a pre-existing remote ref" "$confirmation"
    ! grep -qF "git fetch --no-tags origin \"{rollback-origin-ref}\"" "$state"
  '

	assert_required_contracts_registered \
		pr-create-existing-remote-orchestration \
		pr-create-clean-worktree-helper \
		pr-create-existing-remote-classification \
		pr-create-existing-remote-publication

	[ "$status" -eq 0 ]
}

@test "pr-create clean-worktree verifier overrides hidden-untracked configuration" {
	verifier="$BATS_TEST_DIRNAME/../skills/kramme:pr:create/scripts/verify-clean-worktree.sh"
	repo="$BATS_TEST_TMPDIR/repo"

	git init "$repo"
	git -C "$repo" config user.name "Test User"
	git -C "$repo" config user.email "test@example.com"
	printf 'tracked\n' > "$repo/tracked.txt"
	git -C "$repo" add tracked.txt
	git -C "$repo" commit -m "initial"
	git -C "$repo" config status.showUntrackedFiles no
	printf 'hidden\n' > "$repo/untracked.txt"

	run bash -c 'cd "$1" && "$2"' _ "$repo" "$verifier"
	[ "$status" -ne 0 ]
	[[ "$output" == *"Working tree has uncommitted or untracked changes"* ]]
}

@test "pr-create clean-worktree verifier rejects modified assume-unchanged content" {
	verifier="$BATS_TEST_DIRNAME/../skills/kramme:pr:create/scripts/verify-clean-worktree.sh"
	repo="$BATS_TEST_TMPDIR/repo"

	git init "$repo"
	git -C "$repo" config user.name "Test User"
	git -C "$repo" config user.email "test@example.com"
	printf 'tracked\n' > "$repo/tracked.txt"
	git -C "$repo" add tracked.txt
	git -C "$repo" commit -m "initial"
	git -C "$repo" update-index --assume-unchanged tracked.txt
	printf 'modified\n' > "$repo/tracked.txt"

	run bash -c 'cd "$1" && "$2"' _ "$repo" "$verifier"
	[ "$status" -ne 0 ]
	[[ "$output" == *"Assume-unchanged tracked content differs from the index"* ]]
}

@test "pr-create clean-worktree verifier fails closed when status inspection fails" {
	verifier="$BATS_TEST_DIRNAME/../skills/kramme:pr:create/scripts/verify-clean-worktree.sh"
	repo="$BATS_TEST_TMPDIR/repo"
	fake_bin="$BATS_TEST_TMPDIR/fake-bin"
	real_git=$(command -v git)

	git init "$repo"
	mkdir -p "$fake_bin"
	printf '#!/bin/sh\nif [ "${1:-}" = status ]; then exit 73; fi\nexec "%s" "$@"\n' "$real_git" > "$fake_bin/git"
	chmod +x "$fake_bin/git"

	run bash -c 'cd "$1" && PATH="$2:$PATH" "$3"' _ "$repo" "$fake_bin" "$verifier"
	[ "$status" -ne 0 ]
	[[ "$output" == *"Could not inspect the working tree"* ]]
}

@test "pr-create guidance contracts are registered and files are wired" {
	run bash -c '
    set -e
    cd "'"$BATS_TEST_DIRNAME"'/.."
    create="skills/kramme:pr:create/SKILL.md"
    preflight="skills/kramme:pr:create/references/pre-validation-checks.md"
    branch="skills/kramme:pr:create/references/branch-and-platform-handling.md"
    confirmation="skills/kramme:pr:create/references/confirmation-and-creation.md"

    test -f "$create"
    test -f "$preflight"
    test -f "$branch"
    test -f "$confirmation"
    test -x "skills/kramme:pr:create/scripts/validate-branch-name.sh"
    test -x "skills/kramme:pr:create/scripts/verify-clean-worktree.sh"

    grep -qF "references/pre-validation-checks.md" "$create"
    grep -qF "references/branch-and-platform-handling.md" "$create"
    grep -qF "references/state-and-rollback.md" "$create"
    grep -qF "references/confirmation-and-creation.md" "$create"
    grep -qF "## Step 3.5: Reject an Existing Pull Request" "$create"
    grep -qF "Inspect the agent-tracked value directly" "$create"
    grep -qF "Require the whole string to match \`[A-Za-z0-9][A-Za-z0-9._/-]*\`" "$create"
    grep -qF "git check-ref-format --branch \"{feature-branch}\"" "$create"
    grep -qF "env GH_PROMPT_DISABLED=1 gh pr list --head \"{feature-branch}\" --state open" "$create"
    grep -qF "errors are blockers, not evidence that no Pull Request exists" "$create"
    grep -qF "scripts/validate-branch-name.sh" "$branch"
    grep -qF "capture it as pinned \`{base-ref}\`" "$branch"
    grep -qF "pass \`{base-source-ref}\`, \`{base-ref}\`, and \`{base-branch}\` unchanged to both downstream skills" "$branch"
    grep -qF "git status --porcelain --untracked-files=all" "$create"
    grep -qF "scripts/verify-clean-worktree.sh" "$create"
    grep -qF "scripts/verify-clean-worktree.sh" "$confirmation"
    grep -qF "headRefOid" "$confirmation"
    grep -qF "equal \`{publication-head}\` exactly" "$confirmation"

    branch_validation_line=$(grep -nF "Inspect the agent-tracked value directly" "$create" | cut -d: -f1)
    git_validation_line=$(grep -nF "git check-ref-format --branch \"{feature-branch}\"" "$create" | cut -d: -f1)
    existing_pr_query_line=$(grep -nF "env GH_PROMPT_DISABLED=1 gh pr list --head \"{feature-branch}\" --state open" "$create" | cut -d: -f1)
    [ "$branch_validation_line" -lt "$git_validation_line" ]
    [ "$git_validation_line" -lt "$existing_pr_query_line" ]

    ! grep -qF "pr-title.XXXXXX.txt" "$confirmation"
    ! grep -qF "pr-body.XXXXXX.md" "$confirmation"
    ! grep -q -- "--body \"\$(cat <<" "$confirmation"
  '

	assert_required_contracts_registered \
		pr-create-gh-prevalidation \
		pr-create-existing-pr-preflight \
		pr-create-ref-trust-boundary \
		pr-create-branch-validator-script \
		pr-create-description-generation-contract \
		pr-create-linear-id-normalization \
		pr-create-branch-linear-state \
		pr-create-body-file-contract \
		pr-create-edit-loop-linear-normalization

	[ "$status" -eq 0 ]
}

@test "pr-create restores the original index when the include commit fails" {
	state="$BATS_TEST_DIRNAME/../skills/kramme:pr:create/references/state-and-rollback.md"
	block="$BATS_TEST_TMPDIR/commit-and-include.sh"
	repo="$BATS_TEST_TMPDIR/repo"
	extract_commit_and_include_block "$state" "$block"

	git init --shared=group "$repo"
	cd "$repo"
	git config user.name "Test User"
	git config user.email "test@example.com"
	printf 'initial\n' > tracked.txt
	git add tracked.txt
	git commit -m "Initial commit"
	printf '#!/bin/sh\nexit 1\n' > .git/hooks/pre-commit
	chmod +x .git/hooks/pre-commit

	printf 'staged\n' > staged.txt
	git add staged.txt
	printf 'unstaged\n' >> tracked.txt
	printf 'untracked\n' > untracked.txt
	index_path=$(git rev-parse --git-path index)
	chmod 0664 "$index_path"

	before_head=$(git rev-parse HEAD)
	before_index=$(git hash-object "$index_path")
	before_mode=$(file_mode "$index_path")
	before_cached=$(git diff --cached --binary)
	before_unstaged=$(git diff --binary)
	before_status=$(git status --porcelain)

	run bash "$block"
	[ "$status" -ne 0 ]
	[[ "$output" == *"restored the original Git index"* ]]
	[ "$(git rev-parse HEAD)" = "$before_head" ]
	[ "$(git hash-object "$index_path")" = "$before_index" ]
	[ "$(file_mode "$index_path")" = "$before_mode" ]
	[ "$(git diff --cached --binary)" = "$before_cached" ]
	[ "$(git diff --binary)" = "$before_unstaged" ]
	[ "$(git status --porcelain)" = "$before_status" ]
}

@test "pr-create preserves the index backup when restoration fails" {
	state="$BATS_TEST_DIRNAME/../skills/kramme:pr:create/references/state-and-rollback.md"
	block="$BATS_TEST_TMPDIR/commit-and-include.sh"
	repo="$BATS_TEST_TMPDIR/repo"
	fake_bin="$BATS_TEST_TMPDIR/fake-bin"
	extract_commit_and_include_block "$state" "$block"

	git init "$repo"
	cd "$repo"
	git config user.name "Test User"
	git config user.email "test@example.com"
	printf 'initial\n' > tracked.txt
	git add tracked.txt
	git commit -m "Initial commit"
	printf '#!/bin/sh\nexit 1\n' > .git/hooks/pre-commit
	chmod +x .git/hooks/pre-commit

	printf 'staged\n' > staged.txt
	git add staged.txt
	printf 'unstaged\n' >> tracked.txt
	index_path=$(git rev-parse --git-path index)
	before_head=$(git rev-parse HEAD)
	before_index=$(git hash-object "$index_path")

	mkdir -p "$fake_bin"
	printf '#!/bin/sh\nexit 73\n' > "$fake_bin/mv"
	chmod +x "$fake_bin/mv"

	run env PATH="$fake_bin:$PATH" bash "$block"
	[ "$status" -ne 0 ]
	[[ "$output" == *"Failed to restore the original Git index. Backup remains at "* ]]
	[[ "$output" != *"restored the original Git index"* ]]
	backup_path=${output##*Backup remains at }
	backup_path=${backup_path%.}
	[ -f "$backup_path" ]
	[ "$(git hash-object "$backup_path")" = "$before_index" ]
	[ "$(git rev-parse HEAD)" = "$before_head" ]
}

@test "pr-create state and rollback guidance keeps required sections" {
	run bash -c '
    set -e
    cd "'"$BATS_TEST_DIRNAME"'/.."
    state="skills/kramme:pr:create/references/state-and-rollback.md"

    test -f "$state"
    grep -q "^## Step 5: State Preservation" "$state"
    grep -q "^## Step 9.0: Restore Excluded Uncommitted Changes" "$state"
    grep -q "^## Step 10: Abort and Rollback" "$state"
    grep -qF "{rollback-origin-ref}" "$state"
    grep -qF "{rollback-origin-oid}" "$state"
    grep -qF "git ls-remote --heads origin \"{rollback-origin-ref}\"" "$state"
    grep -qF "continue only when it returns no matching ref" "$state"
    grep -qF "Neither \`--auto\` nor \`--authorize-history-rewrite\` may bypass this fresh-mode remote-absence requirement" "$state"
    grep -qF "never force-push, delete, or recreate the remote ref during automatic rollback" "$state"
    grep -qF "Remote state: {unchanged at captured OID/absence | diverged" "$state"
    grep -qF "Remote restoration is claimed only when the read-only comparison reports \`unchanged\`" "$state"
    ! grep -qF "Your work has been restored to the pre-skill branch state." "$state"
  '

	assert_required_contracts_registered \
		pr-create-remote-absence-contract \
		pr-create-state-restoration-contract

	[ "$status" -eq 0 ]
}

@test "pr-create auto mode includes uncommitted work and authorizes the protected reset without prompting" {
	run bash -c '
    set -e
    cd "'"$BATS_TEST_DIRNAME"'/.."
    create="skills/kramme:pr:create/SKILL.md"
    state="skills/kramme:pr:create/references/state-and-rollback.md"

    grep -qF "include all uncommitted changes by selecting **Commit and include**" "$create"
    grep -qF "\`--auto\` -> set \`AUTO_MODE=true\` and \`REQUIRE_GENERATED_DESCRIPTION=true\`" "$create"
    grep -qF "Auto mode authorizes the nested unstacked rewrite but does not synthesize the separate stack-wide authorization capability" "$create"
    grep -qF "\`--auto\` is fully non-interactive" "$create"
    grep -qF "Step 5 uncommitted-work decision when \`AUTO_MODE=false\`" "$create"
    grep -qF "If uncommitted changes are present and \`AUTO_MODE=true\`, do not prompt." "$state"
    grep -qF "Select **Commit and include** and execute that path below." "$state"
    grep -qF "If uncommitted changes are present and \`AUTO_MODE=false\`" "$state"
  '

	[ "$status" -eq 0 ]
}

@test "pr-create auto mode is fail-closed and fully non-interactive" {
	run bash -c '
    set -e
    cd "'"$BATS_TEST_DIRNAME"'/.."
    create="skills/kramme:pr:create/SKILL.md"
    branch="skills/kramme:pr:create/references/branch-and-platform-handling.md"
    state="skills/kramme:pr:create/references/state-and-rollback.md"
    confirmation="skills/kramme:pr:create/references/confirmation-and-creation.md"

    grep -qF "\`--auto\` is fully non-interactive" "$create"
    grep -qF "never ask the user a question, wait for free-form user input, or allow Git/GitHub credential prompts" "$create"
    grep -qF "MISSING REQUIREMENT: generated PR title/body unavailable; placeholder publication is forbidden" "$create"
    grep -qF "Never create a Pull Request containing placeholder fallback text." "$create"
    grep -qF "Every other \`MISSING REQUIREMENT:\` marker is blocking" "$create"
    grep -qF "any future requirement the generator marks as missing" "$create"
    ! grep -qF "**Fallback description**" "$create"
    ! grep -qF "**Fallback title**" "$create"

    grep -qF "Do not ask for initials" "$branch"
    grep -qF "feature/{issue-id-lowercase}-{sanitized-title}" "$branch"
    grep -qF "If \`AUTO_MODE=true\`, select the first non-empty candidate" "$branch"
    grep -qF "report a hard blocker without prompting" "$branch"
    grep -qF "If \`AUTO_MODE=false\`, ask the user to choose from the generated candidates or provide a branch name" "$branch"
    grep -qF "env GIT_TERMINAL_PROMPT=0 GCM_INTERACTIVE=Never" "$branch"
    grep -qF "NONINTERACTIVE_GIT_SSH_COMMAND=\"\${GIT_SSH_COMMAND:-\${GIT_SSH:-ssh}} -oBatchMode=yes\"" "$branch"
    grep -qF "GIT_SSH_COMMAND=\"\$NONINTERACTIVE_GIT_SSH_COMMAND\"" "$branch"
    grep -qF "env GIT_TERMINAL_PROMPT=0 GCM_INTERACTIVE=Never" "$state"

    grep -qF "env GH_PROMPT_DISABLED=1 gh pr list" "$confirmation"
    grep -qF "env GIT_TERMINAL_PROMPT=0 GCM_INTERACTIVE=Never" "$confirmation"
    grep -qF "NONINTERACTIVE_GIT_SSH_COMMAND=\"\${GIT_SSH_COMMAND:-\${GIT_SSH:-ssh}} -oBatchMode=yes\"" "$confirmation"
    grep -qF "GIT_SSH_COMMAND=\"\$NONINTERACTIVE_GIT_SSH_COMMAND\"" "$confirmation"
    grep -qF "env GH_PROMPT_DISABLED=1 gh pr create" "$confirmation"
    grep -qF "shell tool'\''s bounded timeout" "$confirmation"
    grep -qF "If the push command exits non-zero, its remote outcome is ambiguous" "$confirmation"
    grep -qF "never continue to \`gh pr create\` after a non-zero push status" "$confirmation"
    ! grep -qF "The generated description is saved." "$confirmation"
  '

	[ "$status" -eq 0 ]
}

@test "branch validator rejects shell-active names that Git itself accepts" {
	validator="$BATS_TEST_DIRNAME/../skills/kramme:pr:create/scripts/validate-branch-name.sh"
	cd "$BATS_TEST_TMPDIR"

	for hostile in \
		'feature/x;touch-pwned' \
		'feature/x$(touch-pwned)' \
		'feature/x`touch-pwned`' \
		'feature/x&touch-pwned'; do
		git check-ref-format --branch "$hostile"
		run "$validator" "$hostile"
		[ "$status" -ne 0 ]
	done

	[ ! -e touch-pwned ]
	run "$validator" "feature/abc-123_safe"
	[ "$status" -eq 0 ]
	[ "$output" = "feature/abc-123_safe" ]
}

@test "new feature branch starts at immutable entry commit and rollback restores entry checkout" {
	branch_guidance="$BATS_TEST_DIRNAME/../skills/kramme:pr:create/references/branch-and-platform-handling.md"
	state_guidance="$BATS_TEST_DIRNAME/../skills/kramme:pr:create/references/state-and-rollback.md"
	repo="$BATS_TEST_TMPDIR/repo"
	grep -qF 'git diff --name-only "{base-ref}"...HEAD' "$branch_guidance"
	grep -qF "stop without deleting any ref" "$state_guidance"
	grep -qF "{feature-branch}-recreate-backup-{recreate-input-tip}" "$state_guidance"
	! grep -qF "If branch creation fails, inspect whether Git created the ref" "$state_guidance"

	git init "$repo"
	git -C "$repo" config user.name "Test User"
	git -C "$repo" config user.email "test@example.com"
	printf 'base\n' >"$repo/file.txt"
	git -C "$repo" add file.txt
	git -C "$repo" commit -m "base"
	git -C "$repo" branch -M main
	printf 'local\n' >>"$repo/file.txt"
	git -C "$repo" commit -am "local entry work"

	entry_commit=$(git -C "$repo" rev-parse HEAD)
	git -C "$repo" checkout -b feature/preserved "$entry_commit"
	original_commit=$(git -C "$repo" rev-parse HEAD)
	[ "$original_commit" = "$entry_commit" ]
	[ "$(git -C "$repo" show HEAD:file.txt)" = $'base\nlocal' ]

	printf 'rewritten\n' >"$repo/file.txt"
	git -C "$repo" commit -am "simulated rewrite"
	git -C "$repo" reset --hard "$original_commit"
	git -C "$repo" checkout main
	git -C "$repo" branch -d feature/preserved

	[ "$(git -C "$repo" branch --show-current)" = "main" ]
	[ "$(git -C "$repo" rev-parse HEAD)" = "$entry_commit" ]
	! git -C "$repo" show-ref --verify --quiet refs/heads/feature/preserved
}
