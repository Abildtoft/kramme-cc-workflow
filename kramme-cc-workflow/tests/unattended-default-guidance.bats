#!/usr/bin/env bats

setup() {
	REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
	RECREATE="$REPO_ROOT/skills/kramme:git:recreate-commits/SKILL.md"
	CREATE="$REPO_ROOT/skills/kramme:pr:create/SKILL.md"
	FIX_CI="$REPO_ROOT/skills/kramme:pr:fix-ci/SKILL.md"
	DESCRIBE="$REPO_ROOT/skills/kramme:pr:generate-description/SKILL.md"
	REBASE="$REPO_ROOT/skills/kramme:pr:rebase/SKILL.md"
	SHIPPING_SKILLS=("$RECREATE" "$CREATE" "$FIX_CI" "$DESCRIBE" "$REBASE")
}

@test "shipping skills take --manual instead of --auto" {
	for skill in "${SHIPPING_SKILLS[@]}"; do
		grep -qE '^argument-hint: .*\[--manual\]' "$skill"
		! grep -qE '^argument-hint: .*--auto' "$skill"
		grep -qF 'Ignore a leftover `--auto`: auto mode is already the default.' "$skill"
		grep -qE '^Auto mode is the default|`AUTO_MODE=true`, `DRAFT_MODE=false`' "$skill"
	done
}

@test "auto mode is reserved for direct users and named delegations" {
	local direct='A direct user invocation means the user typed the slash command or `$` mention, or asked for this skill by name in this session.'
	local other='Every other invocation runs as `--manual`, whether or not it passes that flag, including one where the model picks this skill for a request that does not name it.'

	for skill in "$RECREATE" "$CREATE" "$FIX_CI"; do
		grep -qF "$direct" "$skill"
		grep -qF "$other" "$skill"
	done
	grep -qF 'Auto mode is reserved for a direct user invocation and for that guarded delegation.' "$RECREATE"
	grep -qF 'Auto mode is reserved for a direct user invocation and for those two parent delegations, which always pass `--require-generated-description`.' "$CREATE"
	grep -qF 'Auto mode is reserved for a direct user invocation and for that `kramme:pr:rebase` delegation.' "$FIX_CI"

	grep -qF "$direct" "$REBASE"
	grep -qF 'Every other invocation without `--force-push` runs as `--manual`, whether or not it passes that flag, including one where the model picks this skill for a request that does not name it.' "$REBASE"

	grep -qF 'or asked for this skill by name in this session, because that mode may mutate an existing Pull Request.' "$DESCRIBE"
	grep -qF 'Treat any other invocation that omits it as if it had passed `--no-update`, including one where the model picks this skill for a request that does not name it.' "$DESCRIBE"
}

@test "no component passes --auto to the shipping skills" {
	run grep -rnE 'kramme:(git:recreate-commits|pr:create|pr:fix-ci|pr:generate-description|pr:rebase) --auto' \
		"$REPO_ROOT/skills" "$REPO_ROOT/shared" "$REPO_ROOT/agents" "$REPO_ROOT/docs/shipping.md" "$REPO_ROOT/docs/review.md"
	[ "$status" -eq 1 ]
}

@test "pr:create forwards --manual to the rewrite but never to the description generator" {
	grep -qF 'Also pass `--manual` when `AUTO_MODE=false`' "$CREATE"
	grep -qF 'Always pass `--no-update --base {base-source-ref} --base-commit {base-ref}`, and never `--manual`' "$CREATE"
	grep -qF 'and `--manual` only when Step 0 set them:' "$CREATE"
	grep -qF 'Defaults: `AUTO_MODE=true`' "$CREATE"
	grep -qF -- '- `--manual` -> set `AUTO_MODE=false`' "$CREATE"
}

@test "recreate-commits still stops an auto-mode stack rewrite" {
	grep -qF 'If `IN_STACK=true` and neither `--manual` nor `--authorize-history-rewrite` was passed, stop before the reset and name both flags.' "$RECREATE"
	grep -qF 'auto mode never authorizes stack-wide mutation by itself' "$RECREATE"
	grep -qF 'A `--manual` stack invocation may instead obtain the explicit stack-wide confirmations below.' "$RECREATE"
}

@test "rebase --force-push beats the dangerous default and both parents pass it" {
	grep -qF 'set `FORCE_PUSH_MODE=true` and `AUTO_MODE=false`' "$REBASE"
	grep -qF 'Never omit `--force-push`' "$REBASE"
	grep -qF 'If both `--manual` and `--force-push` are present, stop with a usage error' "$REBASE"
	! grep -qF 'wins because it is the broader dangerous mode' "$REBASE"

	grep -qF 'Invoke `$kramme:pr:rebase --force-push --base <BASE>` through the platform skill mechanism' "$FIX_CI"
	grep -qF 'invoke `kramme:pr:rebase` with `--force-push --base {base-branch}`' "$CREATE"
}

@test "rebase recovery guidance never points at the dangerous default" {
	grep -qF 'rerun with --manual after addressing the concern.' "$REBASE"
	! grep -qF 'rerun without --force-push' "$REBASE"
	grep -qF 'needs a single-branch `/kramme:pr:rebase --manual` in its own workspace.' \
		"$REPO_ROOT/skills/kramme:pr:rebase/references/batch-mode.md"
}

@test "rebase --fix-ci carries the rebase mode into fix-ci" {
	grep -qF -- '- When `AUTO_MODE=true`, invoke `$kramme:pr:fix-ci` with no additional flags' "$REBASE"
	grep -qF -- '- Otherwise, invoke `$kramme:pr:fix-ci --manual`.' "$REBASE"
	grep -qF "or the rebase caller's no-flag auto mode or \`--manual\`." "$FIX_CI"
}

@test "fix-ci --no-consolidate keeps shipping parents out of auto mode" {
	local contract="$REPO_ROOT/shared/implementation/references/pr-shipping-contract.md"

	grep -qF 'if `--no-consolidate` is present, set `NO_CONSOLIDATE=true` and `AUTO_MODE=false`' "$FIX_CI"
	grep -qF 'so the user decides whether to rebase a branch that is behind its base' "$FIX_CI"
	grep -qF 'It also turns off auto mode in that delegated skill' "$contract"
	grep -qF 'This contract does not authorize rewriting an existing remote branch, force-pushing an already-open Pull Request' "$contract"

	grep -qF -- '`{fix-ci-invocation}`: `kramme:pr:fix-ci --no-consolidate`.' \
		"$REPO_ROOT/skills/kramme:linear:issue-to-pr/references/shipping-contract.md"
	grep -qF '$kramme:pr:fix-ci --no-consolidate --scope-plan {validated-scope-plan}' \
		"$REPO_ROOT/skills/kramme:code:plan-to-pr/references/shipping-contract.md"
}

@test "modes with their own gates do not inherit auto mode" {
	grep -qF 'If `--check` is present, set `CHECK_MODE=true`, `AUTO_MODE=false`, and `NON_INTERACTIVE=false`' "$DESCRIBE"
	grep -qF '`--all-open` never uses it: batch mode keeps its own rules.' "$REBASE"
	grep -qF 'read `references/batch-mode.md` and follow it instead of Steps 1-7' "$REBASE"
	grep -qF 'When `--scope-plan` is present, reject `--fixup` and `--rebase`, require `--no-consolidate`' "$FIX_CI"
}

@test "generate-description updates a PR only in a direct auto-mode run" {
	grep -qF 'Initialize `AUTO_MODE=true` and `NON_INTERACTIVE=true`. If `--manual` is present, set both to false' "$DESCRIBE"
	grep -qF '**If `AUTO_MODE=true` and `OUTPUT_ONLY` is not true**, check whether a PR exists' "$DESCRIBE"
	grep -qF 'When directly invoked in auto mode, an existing PR is found' "$DESCRIBE"
	grep -qF 'present the result for copy-paste without updating a PR' "$DESCRIBE"
}

@test "the default flip is recorded and documented" {
	local adr="$REPO_ROOT/docs/decisions/2026-10-31-unattended-default-for-shipping-skills.md"

	grep -qF -- '- Status: ACCEPTED' "$adr"
	grep -qF '2026-10-31-unattended-default-for-shipping-skills.md' "$REPO_ROOT/docs/decisions/README.md"
	grep -qF '2026-10-31-unattended-default-for-shipping-skills.md' \
		"$REPO_ROOT/docs/decisions/2026-08-29-model-invocable-orchestration-children.md"
	grep -qF '## Unattended by Default' "$REPO_ROOT/docs/shipping.md"
	grep -qF 'docs/shipping.md#unattended-by-default' "$REPO_ROOT/../README.md"
}
