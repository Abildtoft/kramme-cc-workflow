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

@test "pr-create owns one absence-leased remote publication" {
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
    grep -qF "GIT_TERMINAL_PROMPT=0 GCM_INTERACTIVE=Never" "$confirmation"
    grep -qF "authentication failure is a hard blocker, never a reason to wait for terminal input" "$confirmation"
    ! grep -qF -- "--force-with-lease=\"{rollback-origin-ref}:{rollback-origin-oid}\"" "$confirmation"
    grep -qF "Do not use plain \`--force\`, an OID lease for a pre-existing remote ref" "$confirmation"
    grep -qF "workflow'\''s sole remote update before Pull Request creation" "$confirmation"
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

@test "existing remote branch stops before history rewriting" {
	run bash -c '
    set -e
    cd "'"$BATS_TEST_DIRNAME"'/.."
    create="skills/kramme:pr:create/SKILL.md"
    state="skills/kramme:pr:create/references/state-and-rollback.md"
    confirmation="skills/kramme:pr:create/references/confirmation-and-creation.md"

    grep -qF "The feature branch already exists on \`origin\`" "$create"
    grep -qF "continue only when it returns no matching ref" "$state"
    grep -qF "stop before branch creation or \`kramme:git:recreate-commits\`" "$state"
    grep -qF "Never check out or adopt that remote branch" "$state"
    grep -qF "cannot atomically prevent another actor from opening a Pull Request" "$state"
    grep -qF "Do not use plain \`--force\`, an OID lease for a pre-existing remote ref" "$confirmation"
    ! grep -qF "git fetch --no-tags origin \"{rollback-origin-ref}\"" "$state"
    ! grep -qF "git merge-base --is-ancestor \"{rollback-origin-oid}\" \"{original-commit}\"" "$state"
  '

	[ "$status" -eq 0 ]
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
    grep -qF "Neither \`--auto\` nor \`--authorize-history-rewrite\` may bypass the remote-absence requirement" "$state"
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
