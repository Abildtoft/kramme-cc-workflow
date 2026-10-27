#!/usr/bin/env bats

load 'test_helper/common'

write_metadata_gh_stub() {
	write_file "$1" <<'PY'
#!/usr/bin/env python3
import json
import os
from pathlib import Path
import sys

args = sys.argv[1:]
with Path(os.environ["GH_CALL_LOG"]).open("a") as log:
    log.write(json.dumps(args) + "\n")
assert os.environ.get("GH_PROMPT_DISABLED") == "1"
failure = os.environ.get("TEST_FAILURE", "")
if args[:2] == ["pr", "view"]:
    assert args[2:4] == ["42", "--json"]
    assert args[4:] in [
        ["number,url,title,body"],
        ["number,url,title,body,baseRefName,headRefName,baseRefOid,headRefOid,state"],
    ]
    if failure == "backup":
        sys.exit(1)
    print(os.environ["PR_JSON_DRIFT" if failure == "snapshot" else "PR_JSON_BASE"])
elif args[:1] == ["api"]:
    body_field = args[args.index("-F") + 1]
    assert body_field.startswith("body=@")
    body = Path(body_field[len("body=@"):]).read_text()
    with Path(os.environ["EDIT_LOG"]).open("a") as log:
        log.write(json.dumps({"argv": args, "body": body}) + "\n")
    if failure == "update":
        sys.exit("simulated PATCH failure")
else:
    sys.exit("unexpected gh invocation: " + repr(args))
PY
	chmod +x "$1"
}

assert_metadata_patch() {
	python3 - "$1" "$2" "$3" "${4-example.test}" <<'PY'
import json
from pathlib import Path
import sys

requests = [json.loads(line) for line in Path(sys.argv[1]).read_text().splitlines()]
assert len(requests) == 1, requests
assert requests[0]["argv"] == [
    "api", "--method", "PATCH", "repos/{owner}/{repo}/pulls/42",
    "--hostname", sys.argv[4],
    "-f", "title=fix: update description", "-F", "body=@" + sys.argv[2], "--silent",
], requests[0]
assert requests[0]["body"] == Path(sys.argv[3]).read_text(), requests[0]
PY
}

@test "generate-description prose guidance is covered by contracts" {
	run bash -c '
	    set -e
    cd "'"$BATS_TEST_DIRNAME"'/.."
    skill="skills/kramme:pr:generate-description"
    direct="$skill/references/direct-update.md"
    checklist="$skill/references/verification-checklist.md"

    test -f "$skill/SKILL.md"
    test -f "$skill/references/context-gathering.md"
    test -f "$skill/references/best-practices.md"
    test -f "$skill/assets/section-templates.md"
    test -f "$skill/references/verification-checklist.md"
    test -f "$skill/references/anti-patterns.md"
    test ! -e "$skill/references/red-flags.md"
    test -f "$skill/references/direct-update.md"

    if grep -qF "find . .github docs -maxdepth 2" "$skill/references/context-gathering.md"; then exit 1; fi
    grep -qF "github-pr-template-docs" "$skill/references/sources.yaml"
    grep -qF "The \"no Linear ID\" condition is the only non-blocking \`MISSING REQUIREMENT:\` marker." "$skill/SKILL.md"
    grep -qF "Treat every other \`MISSING REQUIREMENT:\` marker" "$skill/SKILL.md"
    grep -qF "including future marker types not yet listed here" "$skill/SKILL.md"
    grep -qF "almost ELI10" "$skill/SKILL.md"
    grep -qF "intelligent ten-year-old who does not know the codebase" "$skill/assets/section-templates.md"
    grep -qF "env GH_PROMPT_DISABLED=1 gh repo view" "$skill/references/context-gathering.md"
    grep -qF "GIT_TERMINAL_PROMPT=0 GCM_INTERACTIVE=Never" "$skill/references/context-gathering.md"
    grep -qF "NONINTERACTIVE_GIT_SSH_COMMAND=\"\${GIT_SSH_COMMAND:-\${GIT_SSH:-ssh}} -oBatchMode=yes\"" "$skill/references/context-gathering.md"
    grep -qF "GIT_SSH_COMMAND=\"\$NONINTERACTIVE_GIT_SSH_COMMAND\"" "$skill/references/context-gathering.md"
    grep -qF "credential or timeout failures must return control without asking for terminal input" "$skill/references/context-gathering.md"
    grep -qF "[--base-commit <oid>]" "$skill/SKILL.md"
    grep -qF "BASE_COMMIT_OVERRIDE=<oid>" "$skill/SKILL.md"
    grep -qF -- "--base-commit \"\$BASE_COMMIT_OVERRIDE\"" "$skill/references/base-branch-resolution.md"
    if grep -qF "DEFAULT_TEMPLATE_REF=\"\$BASE_REF\"" "$skill/references/context-gathering.md"; then exit 1; fi
    if grep -qF "### Automated verification" "$skill/assets/section-templates.md"; then exit 1; fi
    if grep -qF "add PR-specific signal beyond CI" "$skill/assets/section-templates.md"; then exit 1; fi
    if grep -rqF "red-flags.md" "$skill"; then exit 1; fi
    if grep -qF "Regeneration Triggers" "$skill/SKILL.md"; then exit 1; fi
    grep -qF "regenerate when an item labeled **Regenerate** fails" "$skill/SKILL.md"
    [ "$(grep -cF -- "- [ ] **Regenerate:**" "$checklist")" -eq 5 ]
    if grep -qF "use proper heading hierarchy" "$skill/SKILL.md"; then exit 1; fi
    if grep -qF "using tables for structured data" "$skill/SKILL.md"; then exit 1; fi
    grep -qF "mktemp -d \"/tmp/kramme-pr-description.XXXXXX\"" "$direct"
    grep -qF "Capture the single printed line as agent-tracked \`{update-dir}\`" "$direct"
    grep -qF "UPDATE_DIR=\"{update-dir}\"" "$direct"
    grep -qF "gh pr view \"\$PR_NUMBER\" --json number,url,title,body > \"\$PR_BACKUP\"" "$direct"
    grep -qF "Generated PR payload files are missing or indirect" "$direct"
    grep -qF "mandatory title/body JSON backup" "$checklist"
    grep -qF "same shell invocation as validation and cleanup" "$checklist"
    grep -qF "self-contained local-exclude and symlink-rejection procedure" "$checklist"
    if grep -qF "repo-root anchored backup, local git exclude update" "$checklist"; then exit 1; fi
    grep -qF "SAVE_NAMESPACE=\"\$REPO_ROOT/.kramme-cc-workflow\"" "$skill/SKILL.md"
    grep -qF "Could not update Git'\''s local exclude file; the description was not saved." "$skill/SKILL.md"
    if grep -qF "same idempotent check as step 1" "$skill/SKILL.md"; then exit 1; fi
    if grep -qF "\$REPO_ROOT/.kramme-cc-workflow/pr-description" "$direct"; then exit 1; fi
  '

	assert_required_contracts_registered \
		pr-generate-description-main-guidance \
		pr-generate-description-template-discovery \
		pr-generate-description-template-and-test-plan-rules \
		pr-generate-description-section-template-rules \
		pr-generate-description-output-cleanliness \
		pr-generate-description-antipattern-examples \
		pr-generate-description-cold-read-gate \
		pr-generate-description-direct-update-safety \
		pr-generate-description-save-and-checklist-contract \
		pr-generate-description-direct-update-checklist

	[ "$status" -eq 0 ] || { echo "$output"; false; }
}

@test "check mode is read-only for model callers and gates updates behind direct confirmation" {
	run bash -c '
	    set -euo pipefail
    cd "'"$BATS_TEST_DIRNAME"'/.."
    skill="skills/kramme:pr:generate-description/SKILL.md"
    check="skills/kramme:pr:generate-description/references/check-mode.md"
    update="skills/kramme:pr:generate-description/references/direct-update.md"

    test -f "$check"
    test ! -e "skills/kramme:pr:verify-description"
    grep -qF "disable-model-invocation: false" "$skill"
    grep -qF "argument-hint: \"[--auto] [--no-update] [--check [--strict]] [--base <ref>] [--base-commit <oid>] [--linear-issue <ISSUE-ID>]\"" "$skill"
    grep -qF "Check mode accepts only \`--base <ref>\`, \`--strict\`, and \`--no-update\`." "$skill"
    grep -qF "reject \`--check\` combined with \`--auto\` (which would imply an unconfirmed update), \`--base-commit\`, or \`--linear-issue\`, and reject \`--strict\` without \`--check\`" "$skill"
    grep -qF "Every model-initiated invocation must include \`--no-update\`" "$skill"
    grep -qF "A model caller that needs a drift report passes \`--check --no-update\`" "$skill"
    grep -qF "Only a direct user invocation of \`--check\` may reach the confirmation prompt" "$skill"
    grep -qF "read \`references/check-mode.md\` and follow it instead of Phases 1 through 4" "$skill"
    if grep -qF -e "--fix" -e "FIX_MODE" "$skill" "$check" "$update"; then exit 1; fi

    grep -qF "A model caller always passes \`--check --no-update\`, so for model callers check mode stops after the report." "$check"
    grep -qF "**Skip this phase if \`OUTPUT_ONLY=true\`.**" "$check"
    grep -qF "never prompt, generate, or update" "$check"
    grep -qF -- "--auto --no-update --base {base-branch} --base-commit {base-commit}" "$check"
    grep -qF "Run \`/kramme:pr:generate-description --check\` yourself" "$check"
    grep -qF "Reuse only the accuracy-adjacent items of the generator" "$check"
    grep -qF "the first sentence of item 1 (from the first paragraph alone, a newcomer can say what changes and for whom) and item 7" "$check"
    grep -qF "Do not apply the style items (item 1" "$check"
    grep -qF "do not run the Part 2 cold read in check mode" "$check"
    grep -qF "(accuracy-adjacent clarity check, see Phase C3) | Suggestion | Strict only |" "$check"
    grep -qF "| Not flagged | Never; the accuracy-adjacent clarity check above is the only clarity finding check mode reports |" "$check"
    if grep -qF "items 1 through 8" "$check"; then exit 1; fi
    grep -qF "The diff is the source of truth; the description is the suspect." "$check"
    grep -qF "**CONFUSION** — diff evidence that contradicts the existing PR body or the commit log." "$check"
    grep -qF "**UNVERIFIED** — a claim in the existing PR body that the diff can neither confirm nor refute." "$check"
    grep -qF "A reviewer said the PR description is unclear or wrong" "$skill"
    grep -qF "On \`n\` or no response, stop after the report." "$check"
    grep -qF "**NEVER** generate or publish a replacement without this \`y\`" "$check"
    grep -qF "**Stop without editing the PR** if generation emits any blocking \`MISSING REQUIREMENT:\` marker" "$check"
    grep -qF "Update unavailable: the confirmed update requires the generated base to match the Pull Request target" "$check"
    grep -qF "Update unavailable: the confirmed update is unavailable for a <PR_STATE> Pull Request" "$check"
    if grep -qF "MISSING REQUIREMENT: the confirmed update" "$check"; then exit 1; fi
    if grep -qF "or \\\`/kramme:pr:generate-description\\\` first" "$check"; then exit 1; fi
    grep -qF "Run \\\`/kramme:pr:create\\\` first." "$check"
    grep -qF "**VERDICT_TAG:** ACCURATE | MINOR_DRIFT | MATERIAL_DRIFT | INACCURATE" "$check"
    grep -qF "\`## Review notes\`" "$check"
    grep -qF "legacy \`Potential concerns\`" "$check"
    grep -qF "PR_SNAPSHOT=\$(env GH_PROMPT_DISABLED=1 gh pr view" "$check"
    grep -qF "PR_MATCH_COUNT=\$(env GH_PROMPT_DISABLED=1 gh pr list" "$check"
    grep -qF "if [ \"\$PR_MATCH_COUNT\" = 0 ]; then" "$check"
    grep -qF "MISSING REQUIREMENT: no PR found for the current branch." "$check"
    grep -qF "[[ ! \"\$CURRENT_BRANCH\" =~ ^[A-Za-z0-9][A-Za-z0-9._/-]*\$ ]]" "$check"
    grep -qF "[[ ! \"\$BASE_REF\" =~ ^[A-Za-z0-9][A-Za-z0-9._/-]*\$ ]]" "$check"
    grep -qF "Current branch is not safe for later shell substitution." "$check"
    grep -qF "Resolved base ref is not safe for later shell substitution." "$check"
    grep -qF "Could not inspect a Pull Request for the current branch; preserve the gh diagnostic above." "$check"
    grep -qF "PR_SNAPSHOT_FINGERPRINT=" "$check"
    grep -qF "git hash-object --stdin" "$check"
    grep -qF "WORKTREE_MANIFEST=\$(\"\${CLAUDE_PLUGIN_ROOT}/scripts/review-tree-fingerprint.sh\")" "$check"
    grep -qF "Step 3 for a check-mode confirmed update" "$check"

    grep -qF "### Step 3 for a check-mode confirmed update" "$update"
    grep -qF "mktemp -d \"/tmp/kramme-pr-description.XXXXXX\"" "$update"
    grep -qF "Could not back up and revalidate PR #\$PR_NUMBER; no update was made." "$update"
    grep -qF "LATEST_PR_SNAPSHOT_FINGERPRINT\" != \"\$PR_SNAPSHOT_FINGERPRINT" "$update"
    grep -qF "PR_STATE\" != \"OPEN" "$update"
    grep -qF "LATEST_HEAD\" != \"\$CURRENT_HEAD" "$update"
    grep -qF "LATEST_BASE_COMMIT\" != \"\$BASE_COMMIT" "$update"
    grep -qF "LATEST_WORKTREE_FINGERPRINT\" != \"\$WORKTREE_FINGERPRINT" "$update"
    grep -qF "Generated PR payload storage is missing or indirect" "$update"
    grep -qF "gh api --method PATCH \"repos/{owner}/{repo}/pulls/\$PR_NUMBER\"" "$update"
    if grep -qF "\$REPO_ROOT/.kramme-cc-workflow/pr-description" "$update"; then exit 1; fi

    output_only_line=$(grep -nF "**Skip this phase if \`OUTPUT_ONLY=true\`.**" "$check" | cut -d: -f1)
    base_match_line=$(grep -nF "the confirmed update requires the generated base to match the Pull Request target" "$check" | cut -d: -f1)
    non_open_line=$(grep -nF "the confirmed update is unavailable for a <PR_STATE> Pull Request" "$check" | cut -d: -f1)
    confirmation_line=$(grep -nF "Found <N> finding(s). Generate a replacement title and body" "$check" | cut -d: -f1)
    decline_line=$(grep -nF "On \`n\` or no response, stop after the report." "$check" | cut -d: -f1)
    blocking_stop_line=$(grep -nF "**Stop without editing the PR** if generation emits any blocking" "$check" | cut -d: -f1)
    generation_line=$(grep -nF -- "--auto --no-update --base {base-branch} --base-commit {base-commit}" "$check" | cut -d: -f1)
    publish_line=$(grep -nF "run its \`Step 3 for a check-mode confirmed update\` block" "$check" | cut -d: -f1)
    no_pr_line=$(grep -nF "MISSING REQUIREMENT: no PR found for the current branch." "$check" | head -1 | cut -d: -f1)
    generic_pr_failure_line=$(grep -nF "Could not inspect a Pull Request for the current branch" "$check" | cut -d: -f1)
    [ "$output_only_line" -lt "$base_match_line" ]
    [ "$base_match_line" -lt "$confirmation_line" ]
    [ "$non_open_line" -lt "$confirmation_line" ]
    [ "$confirmation_line" -lt "$generation_line" ]
    [ "$confirmation_line" -lt "$decline_line" ]
    [ "$decline_line" -lt "$generation_line" ]
    [ "$generation_line" -lt "$blocking_stop_line" ]
    [ "$blocking_stop_line" -lt "$publish_line" ]
    [ "$generation_line" -lt "$publish_line" ]
    [ "$no_pr_line" -lt "$generic_pr_failure_line" ]

    check_step_line=$(grep -nF "### Step 3 for a check-mode confirmed update" "$update" | cut -d: -f1)
    storage_line=$(grep -nF "UPDATE_DIR=\$(mktemp -d" "$update" | cut -d: -f1)
    payload_line=$(grep -nF "Generated PR payload storage is missing or indirect" "$update" | cut -d: -f1)
    cleanup_line=$(awk -v s="$check_step_line" "NR > s && index(\$0, \"trap cleanup_pr_payload EXIT\") { print NR; exit }" "$update")
    backup_line=$(awk -v s="$check_step_line" "NR > s && index(\$0, \"if ! env GH_PROMPT_DISABLED=1 gh pr view\") { print NR; exit }" "$update")
    snapshot_line=$(grep -nF "LATEST_PR_SNAPSHOT_FINGERPRINT\" != \"\$PR_SNAPSHOT_FINGERPRINT" "$update" | cut -d: -f1)
    edit_line=$(awk -v s="$check_step_line" "NR > s && index(\$0, \"gh api --method PATCH\") { print NR; exit }" "$update")
    [ "$storage_line" -lt "$check_step_line" ]
    [ "$check_step_line" -lt "$payload_line" ]
    [ "$payload_line" -lt "$cleanup_line" ]
    [ "$cleanup_line" -lt "$backup_line" ]
    [ "$backup_line" -lt "$snapshot_line" ]
    [ "$snapshot_line" -lt "$edit_line" ]
  '

	assert_required_contracts_registered \
		pr-generate-description-subskill-contract \
		pr-generate-description-check-mode-update \
		pr-generate-description-check-mode-snapshot

	[ "$status" -eq 0 ] || { echo "$output"; false; }
}

@test "metadata update guidance uses REST across generation and stack workflows" {
	local skills="${BATS_TEST_DIRNAME}/../skills"
	local relative
	for relative in \
		kramme:pr:generate-description/references/direct-update.md \
		kramme:pr:generate-description/SKILL.md \
		kramme:pr:generate-description/references/verification-checklist.md \
		kramme:pr:stack/SKILL.md \
		kramme:pr:stack/references/cli-agent-rules.md \
		kramme:code:breakdown-findings/references/split-strategies.md; do
		if grep -nF 'gh pr edit' "$skills/$relative"; then
			false
		fi
	done
	for relative in \
		kramme:pr:generate-description/references/direct-update.md \
		kramme:pr:stack/SKILL.md \
		kramme:pr:stack/references/cli-agent-rules.md \
		kramme:code:breakdown-findings/references/split-strategies.md; do
		grep -qF 'gh api --method PATCH' "$skills/$relative"
		grep -qF -- '--hostname' "$skills/$relative"
	done
	grep -qF 'capture its number as `{pr-number}`' "$skills/kramme:pr:generate-description/SKILL.md"
	grep -qF "write the title and body to temporary files with the runtime's file writer" "$skills/kramme:pr:stack/SKILL.md"
	grep -qF -- '-F body=@<body-file> --silent' "$skills/kramme:pr:stack/SKILL.md"
}

@test "generation-mode update uses a pinned REST target and fails closed before publication" {
	local update="${BATS_TEST_DIRNAME}/../skills/kramme:pr:generate-description/references/direct-update.md"
	local block="$BATS_TEST_TMPDIR/generated-update.sh"
	local fake_bin="$BATS_TEST_TMPDIR/bin"
	local update_dir="$BATS_TEST_TMPDIR/update"
	local title_file="$update_dir/new-title.txt"
	local body_file="$update_dir/new-body.md"
	local backup_file="$update_dir/pr-metadata.backup.json"
	local edit_log="$BATS_TEST_TMPDIR/edits.log"
	local gh_call_log="$BATS_TEST_TMPDIR/gh-calls.log"
	local expected_body="$BATS_TEST_TMPDIR/expected-body.md"
	local pr_json='{"number":42,"url":"https://example.test/pr/42","title":"old","body":""}'

	awk '
		/^3\. \*\*Back up every field/ { in_step = 1; next }
		in_step && $0 == "   ```bash" { capture = 1; next }
		capture && $0 == "   ```" { exit }
		capture { sub(/^   /, ""); print }
	' "$update" >"$block"
	[ -s "$block" ]

	mkdir -p "$update_dir"
	write_metadata_gh_stub "$fake_bin/gh"
	export PR_JSON_BASE="$pr_json"
	export EDIT_LOG="$edit_log"
	export GH_CALL_LOG="$gh_call_log"
	python3 - "$block" "$update_dir" "$title_file" "$body_file" "$backup_file" <<'PY'
from pathlib import Path
import sys

block = Path(sys.argv[1])
values = {
    "{update-dir}": sys.argv[2],
    "{pr-title-file}": sys.argv[3],
    "{pr-body-file}": sys.argv[4],
    "{pr-backup}": sys.argv[5],
    "{pr-number}": "${TEST_PR_NUMBER-42}",
}
text = block.read_text()
for placeholder, value in values.items():
    text = text.replace(placeholder, value)
block.write_text(text)
PY

	run_publication() {
		local failure="$1"
		printf '%s' 'fix: update description' >"$title_file"
		cp "$expected_body" "$body_file"
		rm -f "$backup_file"
		: >"$edit_log"
		: >"$gh_call_log"
		case "$failure" in
			missing-title) rm -f "$title_file" ;;
			missing-body) rm -f "$body_file" ;;
		esac
		run env PATH="$fake_bin:$PATH" GH_HOST=wrong-host.test TEST_FAILURE="$failure" TEST_PR_NUMBER="${2-42}" bash "$block"
	}

	write_file "$expected_body" <<'EOF'
# Updated body

Keep `code`, $(printf BODY_MUST_STAY_LITERAL), "quotes", and café.

EOF
	run_publication ""
	[ "$status" -eq 0 ] || { echo "$output"; false; }
	[ -z "$output" ]
	assert_metadata_patch "$edit_log" "$body_file" "$expected_body"
	[ "$(wc -l <"$gh_call_log")" -eq 2 ]
	[ "$(cat "$backup_file")" = "$pr_json" ]
	[ ! -e "$title_file" ]
	[ ! -e "$body_file" ]

	local failure
	for failure in backup missing-title missing-body; do
		run_publication "$failure"
		[ "$status" -ne 0 ] || { echo "unexpected success for $failure"; false; }
		[[ "$output" == *"no update was made"* ]]
		[ ! -s "$edit_log" ]
		[ ! -e "$backup_file" ]
		if [ "$failure" = backup ]; then
			[ ! -e "$title_file" ]
			[ ! -e "$body_file" ]
		else
			[ ! -s "$gh_call_log" ]
		fi
	done

	local number
	for number in '' invalid -1 0 01 042; do
		run_publication "" "$number"
		[ "$status" -ne 0 ] || { echo "unexpected success for PR number '$number'"; false; }
		[[ "$output" == *"no update was made"* ]]
		[ ! -s "$gh_call_log" ]
		[ ! -e "$title_file" ]
		[ ! -e "$body_file" ]
	done

	run_publication update
	[ "$status" -ne 0 ]
	assert_metadata_patch "$edit_log" "$body_file" "$expected_body"
	[ "$(cat "$backup_file")" = "$pr_json" ]
	[ ! -e "$title_file" ]
	[ ! -e "$body_file" ]

	local host
	for host in github.com github.enterprise.test; do
		export PR_JSON_BASE="${pr_json/example.test/$host}"
		run_publication ""
		[ "$status" -eq 0 ] || { echo "$output"; false; }
		assert_metadata_patch "$edit_log" "$body_file" "$expected_body" "$host"
	done

	local url
	for url in '' 'http://github.enterprise.test/pr/42' 'https:///pr/42'; do
		export PR_JSON_BASE
		PR_JSON_BASE=$(printf '%s' "$pr_json" | jq --arg url "$url" '.url = $url')
		run_publication ""
		[ "$status" -ne 0 ] || { echo "unexpected success for URL '$url'"; false; }
		[[ "$output" == *"Could not determine the backed-up PR hostname"* ]]
		[ ! -s "$edit_log" ]
		[ -s "$backup_file" ]
		[ ! -e "$title_file" ]
		[ ! -e "$body_file" ]
	done
}

@test "check-mode confirmed update publication fails closed for every captured drift" {
	local update="${BATS_TEST_DIRNAME}/../skills/kramme:pr:generate-description/references/direct-update.md"
	local block="$BATS_TEST_TMPDIR/confirmed-update.sh"
	local fake_bin="$BATS_TEST_TMPDIR/bin"
	local plugin_root="$BATS_TEST_TMPDIR/plugin"
	local update_dir="$BATS_TEST_TMPDIR/update"
	local title_file="$update_dir/new-title.txt"
	local body_file="$update_dir/new-body.md"
	local backup_file="$update_dir/pr-metadata.backup.json"
	local edit_log="$BATS_TEST_TMPDIR/edits.log"
	local gh_call_log="$BATS_TEST_TMPDIR/gh-calls.log"
	local expected_body="$BATS_TEST_TMPDIR/expected-body.md"
	local current_head="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
	local base_commit="bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
	local base_ref="refs/remotes/origin/main"
	local pr_json snapshot_fingerprint worktree_fingerprint

	awk '
		$0 == "### Step 3 for a check-mode confirmed update" { in_step = 1; next }
		in_step && $0 == "```bash" { capture = 1; next }
		capture && $0 == "```" { exit }
		capture { print }
	' "$update" >"$block"
	[ -s "$block" ]

	mkdir -p "$fake_bin" "$plugin_root/scripts" "$update_dir"
	export REAL_GIT
	REAL_GIT=$(command -v git)
	export TEST_HEAD="$current_head"
	export TEST_BASE_COMMIT="$base_commit"
	export TEST_BASE_REF="$base_ref"
	export TEST_BRANCH="feature"
	export EDIT_LOG="$edit_log"
	export GH_CALL_LOG="$gh_call_log"
	export WORKTREE_MANIFEST="tree-stable"
	pr_json='{"number":42,"url":"https://example.test/pr/42","title":"old","body":"old body","baseRefName":"main","headRefName":"feature","baseRefOid":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb","headRefOid":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","state":"OPEN"}'
	export PR_JSON_BASE="$pr_json"
	export PR_JSON_DRIFT='{"number":42,"url":"https://example.test/pr/42","title":"changed","body":"old body","baseRefName":"main","headRefName":"feature","baseRefOid":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb","headRefOid":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","state":"OPEN"}'
	snapshot_fingerprint=$(printf '%s' "$pr_json" | "$REAL_GIT" hash-object --stdin)
	worktree_fingerprint=$(printf '%s' "$WORKTREE_MANIFEST" | "$REAL_GIT" hash-object --stdin)

	write_file "$fake_bin/git" <<'EOF'
#!/usr/bin/env bash
set -eu
case "$1" in
hash-object)
  exec "$REAL_GIT" "$@"
  ;;
rev-parse)
  if [ "${2:-}" = "--verify" ] && [ "${3:-}" = "HEAD" ]; then
    if [ "${TEST_FAILURE:-}" = "head" ]; then
      printf '%s\n' 'cccccccccccccccccccccccccccccccccccccccc'
    else
      printf '%s\n' "$TEST_HEAD"
    fi
  elif [ "${2:-}" = "$TEST_BASE_REF^{commit}" ]; then
    if [ "${TEST_FAILURE:-}" = "base" ]; then
      printf '%s\n' 'dddddddddddddddddddddddddddddddddddddddd'
    else
      printf '%s\n' "$TEST_BASE_COMMIT"
    fi
  else
    printf 'unexpected git rev-parse invocation: %s\n' "$*" >&2
    exit 2
  fi
  ;;
branch)
  [ "${2:-}" = "--show-current" ] || exit 2
  printf '%s\n' "$TEST_BRANCH"
  ;;
*)
  printf 'unexpected git invocation: %s\n' "$*" >&2
  exit 2
  ;;
esac
EOF

	write_metadata_gh_stub "$fake_bin/gh"

	write_file "$plugin_root/scripts/review-tree-fingerprint.sh" <<'EOF'
#!/usr/bin/env bash
set -eu
if [ "${TEST_FAILURE:-}" = "worktree" ]; then
  printf '%s\n' 'tree-drift'
else
  printf '%s\n' "$WORKTREE_MANIFEST"
fi
EOF
	chmod +x "$fake_bin/git" "$fake_bin/gh" "$plugin_root/scripts/review-tree-fingerprint.sh"

	python3 - "$block" \
		"$update_dir" "$title_file" "$body_file" "$backup_file" \
		"$current_head" "$base_ref" "$base_commit" \
		"$snapshot_fingerprint" "$worktree_fingerprint" <<'PY'
from pathlib import Path
import sys

block = Path(sys.argv[1])
values = {
    "{update-dir}": sys.argv[2],
    "{pr-title-file}": sys.argv[3],
    "{pr-body-file}": sys.argv[4],
    "{pr-backup}": sys.argv[5],
    "{pr-number}": "${TEST_PR_NUMBER-42}",
    "{pr-state}": "OPEN",
    "{current-branch}": "feature",
    "{current-head}": sys.argv[6],
    "{base-ref}": sys.argv[7],
    "{base-commit}": sys.argv[8],
    "{pr-snapshot-fingerprint}": "${TEST_PR_SNAPSHOT_FINGERPRINT-" + sys.argv[9] + "}",
    "{worktree-fingerprint}": sys.argv[10],
}
text = block.read_text()
for placeholder, value in values.items():
    text = text.replace(placeholder, value)
block.write_text(text)
PY

	run_publication() {
		local failure="$1"
		printf '%s' 'fix: update description' >"$title_file"
		cp "$expected_body" "$body_file"
		rm -f "$backup_file"
		: >"$edit_log"
		: >"$gh_call_log"
		case "$failure" in
			missing-title) rm -f "$title_file" ;;
			missing-body) rm -f "$body_file" ;;
		esac
		run env \
			PATH="$fake_bin:$PATH" \
			GH_HOST=wrong-host.test \
			CLAUDE_PLUGIN_ROOT="$plugin_root" \
			TEST_FAILURE="$failure" \
			TEST_PR_NUMBER="${2-42}" \
			TEST_PR_SNAPSHOT_FINGERPRINT="$(printf '%s' "$PR_JSON_BASE" | "$REAL_GIT" hash-object --stdin)" \
			bash "$block"
	}

	write_file "$expected_body" <<'EOF'
# Updated body

Keep `code`, $(printf BODY_MUST_STAY_LITERAL), "quotes", and café.

EOF
	run_publication ""
	[ "$status" -eq 0 ] || { echo "$output"; false; }
	[ -z "$output" ]
	assert_metadata_patch "$edit_log" "$body_file" "$expected_body"
	[ "$(wc -l <"$gh_call_log")" -eq 2 ]
	[ "$(cat "$backup_file")" = "$pr_json" ]
	[ ! -e "$title_file" ]
	[ ! -e "$body_file" ]

	local failure
	for failure in backup snapshot head base worktree missing-title missing-body; do
		run_publication "$failure"
		[ "$status" -ne 0 ] || { echo "unexpected success for $failure"; false; }
		[ ! -s "$edit_log" ]
		if [ "$failure" = backup ]; then
			[ ! -e "$backup_file" ]
			[ ! -e "$title_file" ]
			[ ! -e "$body_file" ]
		fi
	done

	local number
	for number in '' invalid -1 0 01 042; do
		run_publication "" "$number"
		[ "$status" -ne 0 ] || { echo "unexpected success for PR number '$number'"; false; }
		[[ "$output" == *"no update was made"* ]]
		[ ! -s "$gh_call_log" ]
		[ ! -e "$title_file" ]
		[ ! -e "$body_file" ]
	done

	run_publication update
	[ "$status" -ne 0 ]
	assert_metadata_patch "$edit_log" "$body_file" "$expected_body"
	[ "$(cat "$backup_file")" = "$pr_json" ]
	[ ! -e "$title_file" ]
	[ ! -e "$body_file" ]

	local host
	for host in github.com github.enterprise.test; do
		export PR_JSON_BASE="${pr_json/example.test/$host}"
		run_publication ""
		[ "$status" -eq 0 ] || { echo "$output"; false; }
		assert_metadata_patch "$edit_log" "$body_file" "$expected_body" "$host"
	done

	local url
	for url in '' 'http://github.enterprise.test/pr/42' 'https:///pr/42'; do
		export PR_JSON_BASE
		PR_JSON_BASE=$(printf '%s' "$pr_json" | jq --arg url "$url" '.url = $url')
		run_publication ""
		[ "$status" -ne 0 ] || { echo "unexpected success for URL '$url'"; false; }
		[[ "$output" == *"Could not determine the backed-up PR hostname"* ]]
		[ ! -s "$edit_log" ]
		[ -s "$backup_file" ]
		[ ! -e "$title_file" ]
		[ ! -e "$body_file" ]
	done
}

@test "generate-description sizes sections to the change and runs a readability pass" {
	run bash -c '
    set -euo pipefail
    cd "'"$BATS_TEST_DIRNAME"'/.."
    skill="skills/kramme:pr:generate-description"
    templates="$skill/assets/section-templates.md"
    examples="$skill/references/pr-examples.md"
    checklist="$skill/references/verification-checklist.md"
    practices="$skill/references/best-practices.md"
    pass="$skill/references/readability-pass.md"
    prompt="$skill/references/cold-read-prompt.md"
    rubric="shared/writing/references/plain-language-rubric.md"

    if grep -nE "Things I didn.t touch|### Changes made|### Potential concerns|## Technical Details|Reviewer landmarks|Area Notes" "$templates" "$examples" "$checklist" "$practices"; then exit 1; fi
    if grep -nxE "(None|Not applicable|N/A)\.?" "$templates" "$examples"; then exit 1; fi
    if grep -nF "is a valid value" "$checklist"; then exit 1; fi

    previous=0
    for heading in "## Summary" "## Changes" "## Breaking changes" "## How it works" "## Rollout" "## Review notes" "## Test plan" "## Screenshots / Videos"; do
      line=$(grep -nxF "$heading" "$templates" | head -n 1 | cut -d: -f1)
      [ -n "$line" ]
      [ "$line" -gt "$previous" ]
      previous=$line
    done

    grep -qF "Include a placeholder section for visual aids only when the diff changes something a reviewer can see" "$skill/SKILL.md"
    grep -qF "\`## Screenshots / Videos\` appears only for UI-facing changes" "$checklist"
    if grep -rnF "<!-- Consider including: -->" "$skill"; then exit 1; fi
    if grep -rnF --exclude=anti-patterns.md "<!-- Add screenshots or videos here" "$skill"; then exit 1; fi

    test -f "$rubric"
    test ! -e "skills/kramme:text:clarify/references/plain-language-rubric.md"
    grep -qF "Read \`\${CLAUDE_PLUGIN_ROOT}/$rubric\` and \`references/readability-pass.md\`" "$skill/SKILL.md"
    grep -qF "\${CLAUDE_PLUGIN_ROOT}/$rubric" "skills/kramme:text:clarify/SKILL.md"
    for source_id in fofr-govuk-style-skill govuk-identify-user-needs govuk-clear-language govuk-a-to-z-style-guide; do
      grep -qF "id: $source_id" "$skill/references/sources.yaml"
    done

    test -f "$pass"
    test -f "$prompt"
    grep -qF "fork_turns=\"none\"" "$pass"
    grep -qF "Never simulate the cold read in your own context" "$pass"
    grep -qF "Cold read: skipped" "$pass"
    grep -qF "Keep-list audit" "$pass"
    grep -qF "{pr-title}" "$prompt"
    grep -qF "{pr-body}" "$prompt"
    grep -qF "STILL NEED TO KNOW" "$prompt"
    if grep -nF "git diff" "$prompt"; then exit 1; fi
    grep -qF "NEVER** delete the only statement of a keep-list item" "$practices"
    grep -qF "WRONG: Over-Trimmed Description" "$skill/references/anti-patterns.md"

    grep -qF "Keep the list to about eight bullets" "$templates"
    grep -qF "Most test plans need two to six scenarios" "$templates"
    grep -qF "or \`## Changes\` has more than about eight bullets, or the Test plan more than about six scenarios" "$checklist"
    grep -qF "A body past about 900 words is rarely read in full" "$practices"
    grep -qF "WRONG: Every Small Change Listed" "$skill/references/anti-patterns.md"
    grep -qF "## Example 4: Batch of Small Changes" "$examples"

    pass_line=$(grep -nF "### Phase 3.5: Readability Pass" "$skill/SKILL.md" | cut -d: -f1)
    rubric_line=$(grep -nF "\${CLAUDE_PLUGIN_ROOT}/$rubric" "$skill/SKILL.md" | cut -d: -f1)
    gate_line=$(grep -nF "Decide with \`When to Skip the Cold Read\`" "$skill/SKILL.md" | cut -d: -f1)
    checklist_line=$(grep -nF "Run the consolidated checklist in \`references/verification-checklist.md\`." "$skill/SKILL.md" | cut -d: -f1)
    output_line=$(grep -nF "### Phase 4: Output Formatting" "$skill/SKILL.md" | cut -d: -f1)
    update_line=$(grep -nF "Read \`references/direct-update.md\` and follow it." "$skill/SKILL.md" | cut -d: -f1)
    [ "$pass_line" -lt "$rubric_line" ]
    [ "$rubric_line" -lt "$gate_line" ]
    [ "$gate_line" -lt "$checklist_line" ]
    [ "$checklist_line" -lt "$output_line" ]
    [ "$output_line" -lt "$update_line" ]
    if grep -nF "### Phase 5" "$skill/SKILL.md"; then exit 1; fi

    if grep -nF "comprehensive description" "skills/kramme:pr:create/SKILL.md"; then exit 1; fi
  '

	[ "$status" -eq 0 ] || { echo "$output"; false; }
}

@test "generate-description gates the cold read and merges its checks into one checklist" {
	run bash -c '
    set -euo pipefail
    cd "'"$BATS_TEST_DIRNAME"'/.."
    skill="skills/kramme:pr:generate-description"
    checklist="$skill/references/verification-checklist.md"
    pass="$skill/references/readability-pass.md"
    contract="exactly one line starting \`Cold read:\`"

    [ "$(grep -cxF "## When to Skip the Cold Read" "$pass")" -eq 1 ]
    skip_line=$(grep -nxF "## When to Skip the Cold Read" "$pass" | cut -d: -f1)
    part1_line=$(grep -nxF "## Part 1: Edit for the Reader" "$pass" | cut -d: -f1)
    part2_line=$(grep -nxF "## Part 2: Cold Read" "$pass" | cut -d: -f1)
    [ "$part1_line" -lt "$skip_line" ]
    [ "$skip_line" -lt "$part2_line" ]
    grep -qF "at most 3 changed files and at most 150 changed lines (insertions plus deletions)" "$pass"
    grep -qF "The draft has no \`## Breaking changes\` or \`## Rollout\` section." "$pass"
    grep -qF "no database migration, no feature-flag default change, and no change to a versioned artifact surface or durable public contract" "$pass"
    grep -qF "No blocking \`MISSING REQUIREMENT:\` marker was emitted." "$pass"
    grep -qF "If any condition fails, run Part 2." "$pass"
    grep -qF "Cold read: skipped (small diff: 2 files, 40 lines)" "$pass"
    grep -qF "Also skip when the host can'"'"'t launch an agent without the conversation history" "$pass"

    grep -qF "Every run, whether the cold read ran or was skipped, puts $contract" "$pass"
    grep -qF "Cold read: no changes" "$pass"
    grep -qF "at most three open questions" "$pass"
    grep -qF "record $contract for the run output" "$skill/SKILL.md"
    grep -qF "carries $contract" "$skill/SKILL.md"
    grep -qF "has $contract" "$checklist"

    grep -qF "check the draft against every section of \`references/verification-checklist.md\` except Output routing and Cold read" "$pass"
    if grep -nE "^[1-9]\\. \\*\\*" "$pass"; then exit 1; fi
    [ "$(grep -cE "^[1-9]\\. \\*\\*" "$checklist")" -eq 9 ]
    previous=0
    for item in "1. **Plain opening.**" "2. **Said once.**" "3. **Every heading earns its place.**" "4. **One job per line.**" "5. **Terms.**" "6. **Facts, not self-report.**" "7. **Claims can be tested.**" "8. **Sized to the change.**" "9. **Keep-list audit.**"; do
      line=$(grep -nF -- "$item" "$checklist" | cut -d: -f1)
      [ -n "$line" ]
      [ "$line" -gt "$previous" ]
      previous=$line
    done

    previous=0
    for heading in "## Title" "## Summary and sections" "## Readability" "## How it works and Test Plan" "## Boundary, tone, and operational hygiene" "## Output routing" "## Cold read"; do
      line=$(grep -nxF "$heading" "$checklist" | cut -d: -f1)
      [ -n "$line" ]
      [ "$line" -gt "$previous" ]
      previous=$line
    done
    if grep -qxF "## Readability pass" "$checklist"; then exit 1; fi
    if grep -qF "Removed repeated phrasing or duplicated facts" "$checklist"; then exit 1; fi

    grep -qF "**Regenerate:** The Summary says what changes in plain words, with concrete nouns" "$checklist"
    grep -qF "**Regenerate:** A migration, feature-flag default change, or breaking change in the diff appears" "$checklist"
    grep -qF "**Regenerate:** The GitHub UI Duplication Guard from Phase 3.1.5 was applied" "$checklist"
    grep -qF "\"Changes by Area\" section" "$checklist"
    grep -qF "**Regenerate:** No references to spec files" "$checklist"
    grep -qF "**Regenerate:** No AI-attribution badges" "$checklist"
    [ "$(grep -cF "Not applicable" "$checklist")" -eq 1 ]

    grep -qF "the Readability items in \`references/verification-checklist.md\`, using the fixed reader contract in Part 1 of \`references/readability-pass.md\`" "$skill/references/check-mode.md"
    grep -qF "Readability item 2 of \`references/verification-checklist.md\`" "$pass"
  '

	[ "$status" -eq 0 ] || { echo "$output"; false; }
}

@test "generate-description base guidance uses canonical resolver contract" {
	run bash -c '
    set -euo pipefail
    cd "'"$BATS_TEST_DIRNAME"'/.."
    base_ref="skills/kramme:pr:generate-description/references/base-branch-resolution.md"

    grep -qF "Synced base/diff scope contract" "$base_ref"
    grep -qF "shared resolve-base.sh script" "$base_ref"
    grep -qF "BASE_REF" "$base_ref"
    grep -qF "BASE_BRANCH" "$base_ref"
    grep -qF "MERGE_BASE" "$base_ref"
    if grep -qF "git symbolic-ref refs/remotes/origin/HEAD" "$base_ref"; then exit 1; fi
    if grep -qF "gh pr view --json baseRefName" "$base_ref"; then exit 1; fi
  '

	[ "$status" -eq 0 ]
}

@test "generate-description PR template discovery reads default branch tree" {
	run bash -c '
    set -euo pipefail
    discover_templates() {
      DEFAULT_TEMPLATE_REF="$1"
      {
        for template_path in pull_request_template.md pull_request_template.txt .github/pull_request_template.md .github/pull_request_template.txt docs/pull_request_template.md docs/pull_request_template.txt; do
          git cat-file -e "$DEFAULT_TEMPLATE_REF:$template_path" 2> /dev/null && printf "%s\n" "$template_path"
        done
        for dir in PULL_REQUEST_TEMPLATE .github/PULL_REQUEST_TEMPLATE docs/PULL_REQUEST_TEMPLATE; do
          git ls-tree -r --name-only "$DEFAULT_TEMPLATE_REF" "$dir" 2> /dev/null |
            awk -v dir="$dir/" '"'"'index($0, dir) == 1 { name = substr($0, length(dir) + 1); if (name !~ /\// && tolower(name) ~ /\.(md|txt)$/) print $0 }'"'"'
        done
      } | sort -u
    }

    tmp=$(mktemp -d)
    trap "rm -rf \"$tmp\"" EXIT
    cd "$tmp"
    git init -q -b main
    git config user.email test@example.com
    git config user.name Test
    git commit --allow-empty -q -m init
    git branch release
    [ -z "$(discover_templates main)" ]

    mkdir -p .github/PULL_REQUEST_TEMPLATE
    printf "Default\n" > .github/pull_request_template.md
    printf "Release\n" > .github/PULL_REQUEST_TEMPLATE/release.md
    git add .
    git commit -q -m templates
    git switch -q -c feature
    mkdir -p docs
    printf "Unmerged\n" > docs/pull_request_template.md
    pinned_base="$(git rev-parse release)"
    [ "$pinned_base" != "$(git rev-parse main)" ]
    [ -z "$(discover_templates "$pinned_base")" ]
    output="$(discover_templates main)"
    if grep -nE "for (path|cdpath|fpath|manpath) in" "'"$BATS_TEST_DIRNAME"'/../skills/kramme:pr:generate-description/references/context-gathering.md"; then exit 1; fi
    printf "%s\n" "$output" | grep -qF ".github/pull_request_template.md"
    printf "%s\n" "$output" | grep -qF ".github/PULL_REQUEST_TEMPLATE/release.md"
    ! printf "%s\n" "$output" | grep -qF "docs/pull_request_template.md"
  '

	[ "$status" -eq 0 ]
}

@test "PR creation and description generation no longer capture or attach visual evidence" {
	run bash -c '
    set -e
    cd "'"$BATS_TEST_DIRNAME"'/.."
    create="skills/kramme:pr:create"
    generator="skills/kramme:pr:generate-description"

    test ! -e "skills/kramme:visual:demo-reel"
    test ! -e "$create/scripts/prepare-demo-attachments.py"
    test ! -e "$generator/references/visual-capture.md"
    if grep -rqF "kramme:visual:demo-reel" "$create" "$generator"; then exit 1; fi
    if grep -rqE -- "--visual|--for-pr-create|--start-if-easy" "$create" "$generator"; then exit 1; fi
    if grep -rqF -- "--attach" "$create"; then exit 1; fi
    grep -qF "Include a placeholder section for visual aids" "$generator/SKILL.md"
    grep -qF "Add screenshots or videos if applicable" "$create/references/confirmation-and-creation.md"
  '

	[ "$status" -eq 0 ] || { echo "$output"; false; }
}
