#!/usr/bin/env bats

@test "pr-create validates gh before mutation and uses body-file creation" {
	run bash -c '
    set -e
    cd "'"$BATS_TEST_DIRNAME"'/.."
    create="skills/kramme:pr:create/SKILL.md"
    preflight="skills/kramme:pr:create/references/pre-validation-checks.md"
    confirmation="skills/kramme:pr:create/references/confirmation-and-creation.md"

    grep -qF "MISSING REQUIREMENT: gh CLI not installed" "$preflight"
    grep -qF "ORIGIN_URL=\$(git remote get-url origin" "$preflight"
    grep -qF "git@*:*)" "$preflight"
    grep -qF "GH_HOST=\${ORIGIN_URL#git@}" "$preflight"
    grep -qF "GH_HOST=\${GH_HOST%%:*}" "$preflight"
    grep -qF "GH_HOST=\${GH_HOST##*@}" "$preflight"
    grep -qF "gh auth status --active --hostname \"\$GH_HOST\"" "$preflight"
    grep -qF "gh auth login --hostname \$GH_HOST" "$preflight"
    grep -qF "Do not invoke \`kramme:git:recreate-commits\`" "$preflight"
    grep -qF "Always pass \`--auto --no-update --base {base-branch}\`" "$create"
    grep -qF "execute Step 9.0" "$create"
    grep -qF "If the generator emits a blocking \`MISSING REQUIREMENT:\` marker" "$create"
    grep -qF "do **not** proceed to Step 8 or create the PR" "$create"
    grep -qF "The non-blocking \"no Linear ID\" marker" "$create"

    grep -qF "PR_TITLE_FILE=\$(mktemp \"\${TMPDIR:-/tmp}/pr-title.XXXXXX\")" "$confirmation"
    grep -qF "PR_BODY_FILE=\$(mktemp \"\${TMPDIR:-/tmp}/pr-body.XXXXXX\")" "$confirmation"
    ! grep -qF "pr-title.XXXXXX.txt" "$confirmation"
    ! grep -qF "pr-body.XXXXXX.md" "$confirmation"
    grep -qF -- "--title \"\$(cat \"{pr-title-file}\")\"" "$confirmation"
    grep -qF -- "--body-file \"{pr-body-file}\"" "$confirmation"
    grep -qF "PR_CREATE_STATUS=\$?" "$confirmation"
    ! grep -q -- "--body \"\$(cat <<" "$confirmation"
    grep -qF "Before showing manual creation instructions, execute Step 9.0" "$confirmation"
    grep -qF "Do not run Step 10 here" "$confirmation"
  '

	[ "$status" -eq 0 ]
}

@test "pr-create handles uncommitted work explicitly and restores temporary state" {
	run bash -c '
    set -e
    cd "'"$BATS_TEST_DIRNAME"'/.."
    state="skills/kramme:pr:create/references/state-and-rollback.md"

    grep -qF "do **not** silently stash, commit, or ignore them" "$state"
    grep -qF "Commit and include" "$state"
    grep -qF "Exclude from PR" "$state"
    grep -qF "excluded-and-stashed" "$state"
    grep -qF "if ! git stash push --include-untracked -m \"\$STASH_MESSAGE\"; then" "$state"
    grep -qF "Failed to stash excluded uncommitted changes" "$state"
    grep -qF "printf '"'"'STASH_MESSAGE=%s\\n'"'"' \"\$STASH_MESSAGE\"" "$state"
    grep -qF "printf '"'"'POST_STASH_COMMIT_COUNT=%s\\n'"'"'" "$state"
    grep -qF "Capture the value after \`STASH_MESSAGE=\`" "$state"
    grep -qF "Do not infer either value from unlabeled \`git stash push\` output" "$state"
    grep -qF "The command block exits before printing either labeled value if the stash fails" "$state"
    grep -qF "if ! git commit -m \"Include uncommitted changes for PR creation\"; then" "$state"
    grep -qF "Failed to create temporary include commit" "$state"
    grep -qF "The command block exits before printing a hash if the temporary commit fails" "$state"
    grep -qF "if git cherry-pick --no-commit {include-commit}; then" "$state"
    grep -qF "CHERRY_PICK_STATUS=\$?" "$state"
    grep -qF "git cherry-pick --no-commit {include-commit}" "$state"
    grep -qF "git stash pop \"\$STASH_REF\"" "$state"
    grep -qF "grep -F \"{stash-message}\"" "$state"
    grep -qF "No PR changes remain after excluding uncommitted work" "$state"
    grep -qF "before any post-push PR creation failure output" "$state"
  '

	[ "$status" -eq 0 ]
}

@test "finalize delegates direct PR updates to generate-description auto mode" {
	run bash -c '
    set -e
    cd "'"$BATS_TEST_DIRNAME"'/.."
    finalize="skills/kramme:pr:finalize/SKILL.md"
    generator="skills/kramme:pr:generate-description/SKILL.md"

    grep -qF "skill: \"kramme:pr:generate-description\", args: \"--auto --base {BASE_BRANCH}\"" "$finalize"
    grep -qF "handles backup creation and \`--body-file\` application" "$finalize"
    ! grep -qF "apply the generated description to the PR" "$finalize"
    grep -qF "### Sub-Skill Invocation Contract" "$generator"
    grep -qF "it must pass \`--auto\`" "$generator"
    grep -qF "must also pass \`--no-update\`" "$generator"
    grep -qF "OUTPUT_ONLY=true" "$generator"
  '

	[ "$status" -eq 0 ]
}
