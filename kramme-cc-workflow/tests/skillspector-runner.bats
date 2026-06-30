#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

setup() {
	SOURCE_SCRIPT="$BATS_TEST_DIRNAME/../scripts/run-skillspector.sh"
	TMP_DIR="$(mktemp -d)"
	REPO="$TMP_DIR/repo"
	BIN_DIR="$TMP_DIR/bin"
	REPORT_DIR="$TMP_DIR/reports"
	MOCK_SOURCE="$BATS_TEST_DIRNAME/test_helper/mocks/skillspector"
	mkdir -p "$REPO/kramme-cc-workflow/scripts" "$BIN_DIR" "$REPORT_DIR"
	cp "$BATS_TEST_DIRNAME/../Makefile" "$REPO/kramme-cc-workflow/Makefile"
	cp "$SOURCE_SCRIPT" "$REPO/kramme-cc-workflow/scripts/run-skillspector.sh"
	chmod +x "$REPO/kramme-cc-workflow/scripts/run-skillspector.sh"
	ln -s "$MOCK_SOURCE" "$BIN_DIR/skillspector"
	export PATH="$BIN_DIR:$PATH"
	export MOCK_SKILLSPECTOR_LOG="$TMP_DIR/skillspector.log"
	unset MOCK_SKILLSPECTOR_EXIT
	unset MOCK_SKILLSPECTOR_JSON
	unset MOCK_SKILLSPECTOR_WRITE_OUTPUT

	cd "$REPO"
	git init >/dev/null
	git config user.email "test@example.com"
	git config user.name "Test User"
	git config commit.gpgsign false
	write_skill "kramme:one"
	write_skill "kramme:two"
	printf 'base\n' >README.md
	git add .
	git commit -m "initial" >/dev/null
	git branch -M main
	git switch -c feature >/dev/null 2>&1
	SCRIPT="$REPO/kramme-cc-workflow/scripts/run-skillspector.sh"
}

teardown() {
	if [ -n "${TMP_DIR:-}" ] && [ -d "$TMP_DIR" ]; then
		rm -rf "$TMP_DIR"
	fi
}

write_skill() {
	local name="$1"
	local dir="$REPO/kramme-cc-workflow/skills/$name"
	mkdir -p "$dir/references"
	cat >"$dir/SKILL.md" <<EOF
---
name: $name
description: Test skill
disable-model-invocation: false
user-invocable: true
---
# $name
EOF
}

commit_file() {
	local file="$1"
	local content="$2"
	local message="$3"
	mkdir -p "$(dirname "$file")"
	printf '%s\n' "$content" >"$file"
	git add "$file"
	git commit -m "$message" >/dev/null
}

write_policy() {
	local file="$1"
	local body="$2"
	mkdir -p "$(dirname "$file")"
	printf '%s\n' "$body" >"$file"
}

count_invocations() {
	if [ ! -f "$MOCK_SKILLSPECTOR_LOG" ]; then
		printf '0\n'
		return
	fi
	wc -l <"$MOCK_SKILLSPECTOR_LOG" | tr -d ' '
}

@test "changed scan exits successfully when no skill directories changed" {
	commit_file "docs/notes.md" "notes" "change docs"

	run "$SCRIPT" --changed --base main --output-dir "$REPORT_DIR"

	[ "$status" -eq 0 ]
	[[ "$output" == *"No changed skill directories found against main"* ]]
	[ "$(count_invocations)" = "0" ]
}

@test "changed scan Make target does not require scanner when no skill directories changed" {
	run env PATH="/usr/bin:/bin" BASE_REF=HEAD make -C "$REPO/kramme-cc-workflow" --no-print-directory skill-security-changed

	[ "$status" -eq 0 ]
	[[ "$output" == *"No changed skill directories found against HEAD."* ]]
}

@test "changed scan maps resource changes to the owning skill directory" {
	commit_file "kramme-cc-workflow/skills/kramme:one/references/example.md" "example" "change skill resource"

	run "$SCRIPT" --changed --base main --output-dir "$REPORT_DIR"

	[ "$status" -eq 0 ]
	[ "$(count_invocations)" = "1" ]
	grep -q "kramme-cc-workflow/skills/kramme:one format=json" "$MOCK_SKILLSPECTOR_LOG"
}

@test "scan excludes source snapshots from scanner input" {
	commit_file "kramme-cc-workflow/skills/kramme:one/references/sources-snapshot/upstream.md" "upstream docs" "add source snapshot"

	run "$SCRIPT" --changed --base main --output-dir "$REPORT_DIR"

	[ "$status" -eq 0 ]
	[ "$(count_invocations)" = "1" ]
	grep -q "snapshot_exists=no" "$MOCK_SKILLSPECTOR_LOG"
	[ -f "$REPO/kramme-cc-workflow/skills/kramme:one/references/sources-snapshot/upstream.md" ]
}

@test "changed scan de-duplicates multiple changed files in one skill" {
	commit_file "kramme-cc-workflow/skills/kramme:one/references/one.md" "one" "change first resource"
	commit_file "kramme-cc-workflow/skills/kramme:one/references/two.md" "two" "change second resource"

	run "$SCRIPT" --changed --base main --output-dir "$REPORT_DIR"

	[ "$status" -eq 0 ]
	[ "$(count_invocations)" = "1" ]
}

@test "changed scan includes unstaged skill edits" {
	printf 'local edit\n' >>"kramme-cc-workflow/skills/kramme:one/SKILL.md"

	run "$SCRIPT" --changed --base main --output-dir "$REPORT_DIR"

	[ "$status" -eq 0 ]
	[ "$(count_invocations)" = "1" ]
	grep -q "kramme-cc-workflow/skills/kramme:one format=json" "$MOCK_SKILLSPECTOR_LOG"
}

@test "changed scan includes untracked skill files" {
	printf 'draft\n' >"kramme-cc-workflow/skills/kramme:two/references/draft.md"

	run "$SCRIPT" --changed --base main --output-dir "$REPORT_DIR"

	[ "$status" -eq 0 ]
	[ "$(count_invocations)" = "1" ]
	grep -q "kramme-cc-workflow/skills/kramme:two format=json" "$MOCK_SKILLSPECTOR_LOG"
}

@test "all scan uses static-only mode by default" {
	run "$SCRIPT" --all --output-dir "$REPORT_DIR"

	[ "$status" -eq 0 ]
	[ "$(count_invocations)" = "2" ]
	grep -q "no_llm=true" "$MOCK_SKILLSPECTOR_LOG"
}

@test "semantic scan omits static-only flag" {
	run "$SCRIPT" --all --semantic --output-dir "$REPORT_DIR"

	[ "$status" -eq 0 ]
	[ "$(count_invocations)" = "2" ]
	grep -q "no_llm=false" "$MOCK_SKILLSPECTOR_LOG"
}

@test "missing skillspector prints a clear setup error" {
	rm -f "$BIN_DIR/skillspector"

	run -127 env PATH="/usr/bin:/bin:/usr/sbin:/sbin" "$SCRIPT" --all --output-dir "$REPORT_DIR"

	[ "$status" -eq 127 ]
	[[ "$output" == *"SkillSpector scanner not found on PATH"* ]]
}

@test "scanner process failure exits non-zero" {
	export MOCK_SKILLSPECTOR_EXIT=2
	export MOCK_SKILLSPECTOR_WRITE_OUTPUT=0

	run "$SCRIPT" --all --output-dir "$REPORT_DIR"

	[ "$status" -eq 1 ]
	[[ "$output" == *"SkillSpector scan failed"* ]]
}

@test "high threshold fails when JSON report contains a high finding" {
	export MOCK_SKILLSPECTOR_JSON='{"risk_assessment":{"score":25,"severity":"HIGH"},"issues":[{"severity":"HIGH","rule_id":"E4"}]}'

	run "$SCRIPT" --all --fail-on high --output-dir "$REPORT_DIR"

	[ "$status" -eq 1 ]
	[[ "$output" == *"Findings meet --fail-on high threshold"* ]]
}

@test "matching accepted finding is excluded from threshold failure" {
	local policy_file="$REPO/kramme-cc-workflow/config/skillspector-accepted-findings.json"
	export MOCK_SKILLSPECTOR_JSON='{"issues":[{"severity":"HIGH","id":"E4","location":{"file":"SKILL.md","start_line":1}}]}'
	write_policy "$policy_file" '{
  "accepted_findings": [
    {
      "path": "kramme-cc-workflow/skills/kramme:one/SKILL.md",
      "rule_id": "E4",
      "reason": "Reviewed false positive in test fixture.",
      "owner": "Security",
      "accepted_at": "2026-06-13",
      "expires_at": "2999-01-01"
    }
  ]
}'
	printf 'local edit\n' >>"kramme-cc-workflow/skills/kramme:one/SKILL.md"

	run "$SCRIPT" --changed --base main --fail-on high --output-dir "$REPORT_DIR"

	[ "$status" -eq 0 ]
	[[ "$output" == *"Accepted findings:"*"/kramme-cc-workflow/config/skillspector-accepted-findings.json"* ]]
	[[ "$output" == *"Findings: total=1 accepted=1 enforceable=0"* ]]
	[[ "$output" != *"Findings meet --fail-on high threshold"* ]]
}

@test "same rule on a different path is not accepted" {
	local policy_file="$TMP_DIR/accepted-findings.json"
	export MOCK_SKILLSPECTOR_JSON='{"issues":[{"severity":"HIGH","id":"E4","location":{"file":"SKILL.md","start_line":1}}]}'
	write_policy "$policy_file" '{
  "accepted_findings": [
    {
      "path": "kramme-cc-workflow/skills/kramme:two/SKILL.md",
      "rule_id": "E4",
      "reason": "Reviewed finding for the second skill only.",
      "owner": "Security",
      "accepted_at": "2026-06-13",
      "expires_at": "2999-01-01"
    }
  ]
}'
	printf 'local edit\n' >>"kramme-cc-workflow/skills/kramme:one/SKILL.md"

	run "$SCRIPT" --changed --base main --fail-on high --accepted-findings "$policy_file" --output-dir "$REPORT_DIR"

	[ "$status" -eq 1 ]
	[[ "$output" == *"Findings: total=1 accepted=0 enforceable=1"* ]]
	[[ "$output" == *"Findings meet --fail-on high threshold"* ]]
}

@test "different rule on the same path is not accepted" {
	local policy_file="$TMP_DIR/accepted-findings.json"
	export MOCK_SKILLSPECTOR_JSON='{"issues":[{"severity":"HIGH","id":"E4","location":{"file":"SKILL.md","start_line":1}}]}'
	write_policy "$policy_file" '{
  "accepted_findings": [
    {
      "path": "kramme-cc-workflow/skills/kramme:one/SKILL.md",
      "rule_id": "E5",
      "reason": "Reviewed a different rule only.",
      "owner": "Security",
      "accepted_at": "2026-06-13",
      "expires_at": "2999-01-01"
    }
  ]
}'
	printf 'local edit\n' >>"kramme-cc-workflow/skills/kramme:one/SKILL.md"

	run "$SCRIPT" --changed --base main --fail-on high --accepted-findings "$policy_file" --output-dir "$REPORT_DIR"

	[ "$status" -eq 1 ]
	[[ "$output" == *"Findings: total=1 accepted=0 enforceable=1"* ]]
	[[ "$output" == *"Findings meet --fail-on high threshold"* ]]
}

@test "accepted finding policy requires review metadata" {
	local policy_file="$TMP_DIR/accepted-findings.json"
	write_policy "$policy_file" '{
  "accepted_findings": [
    {
      "path": "kramme-cc-workflow/skills/kramme:one/SKILL.md",
      "rule_id": "E4",
      "reason": "Missing required owner and expiry metadata.",
      "accepted_at": "2026-06-13"
    }
  ]
}'

	run "$SCRIPT" --all --accepted-findings "$policy_file" --output-dir "$REPORT_DIR"

	[ "$status" -eq 1 ]
	[[ "$output" == *"Accepted-findings policy is invalid"* ]]
	[[ "$output" == *"accepted_findings[0].owner is required"* ]]
	[[ "$output" == *"accepted_findings[0] requires expires_at or review_after"* ]]
	[ "$(count_invocations)" = "0" ]
}

@test "changed scan validates accepted finding policy before no-skill early exit" {
	local policy_file="$TMP_DIR/accepted-findings.json"
	write_policy "$policy_file" 'not json'

	run "$SCRIPT" --changed --base main --accepted-findings "$policy_file" --output-dir "$REPORT_DIR"

	[ "$status" -eq 1 ]
	[[ "$output" == *"Accepted-findings policy is not valid JSON"* ]]
	[ "$(count_invocations)" = "0" ]
}

@test "expired accepted finding fails in blocking mode" {
	local policy_file="$TMP_DIR/accepted-findings.json"
	write_policy "$policy_file" '{
  "accepted_findings": [
    {
      "path": "kramme-cc-workflow/skills/kramme:one/SKILL.md",
      "rule_id": "E4",
      "reason": "Expired test exception.",
      "owner": "Security",
      "accepted_at": "2026-06-13",
      "expires_at": "2000-01-01"
    }
  ]
}'

	run "$SCRIPT" --all --fail-on high --accepted-findings "$policy_file" --output-dir "$REPORT_DIR"

	[ "$status" -eq 1 ]
	[[ "$output" == *"Accepted-findings policy contains expired entries"* ]]
	[[ "$output" == *"expired accepted finding: kramme-cc-workflow/skills/kramme:one/SKILL.md E4 expired on 2000-01-01"* ]]
	[ "$(count_invocations)" = "0" ]
}

@test "expired accepted finding warns in advisory mode and does not accept" {
	local policy_file="$TMP_DIR/accepted-findings.json"
	export MOCK_SKILLSPECTOR_JSON='{"issues":[{"severity":"HIGH","rule_id":"E4","path":"kramme-cc-workflow/skills/kramme:one/SKILL.md"}]}'
	write_policy "$policy_file" '{
  "accepted_findings": [
    {
      "path": "kramme-cc-workflow/skills/kramme:one/SKILL.md",
      "rule_id": "E4",
      "reason": "Expired test exception.",
      "owner": "Security",
      "accepted_at": "2026-06-13",
      "expires_at": "2000-01-01"
    }
  ]
}'

	run "$SCRIPT" --all --accepted-findings "$policy_file" --output-dir "$REPORT_DIR"

	[ "$status" -eq 0 ]
	[[ "$output" == *"WARNING: expired accepted finding: kramme-cc-workflow/skills/kramme:one/SKILL.md E4 expired on 2000-01-01"* ]]
	[[ "$output" == *"Findings: total=1 accepted=0 enforceable=1"* ]]
}

@test "review_after due accepted finding warns in advisory mode and does not accept" {
	local policy_file="$TMP_DIR/accepted-findings.json"
	export MOCK_SKILLSPECTOR_JSON='{"issues":[{"severity":"HIGH","rule_id":"E4","path":"kramme-cc-workflow/skills/kramme:one/SKILL.md"}]}'
	write_policy "$policy_file" '{
  "accepted_findings": [
    {
      "path": "kramme-cc-workflow/skills/kramme:one/SKILL.md",
      "rule_id": "E4",
      "reason": "Review due test exception.",
      "owner": "Security",
      "accepted_at": "2026-06-13",
      "review_after": "2000-01-01"
    }
  ]
}'

	run "$SCRIPT" --all --accepted-findings "$policy_file" --output-dir "$REPORT_DIR"

	[ "$status" -eq 0 ]
	[[ "$output" == *"WARNING: expired accepted finding: kramme-cc-workflow/skills/kramme:one/SKILL.md E4 expired on 2000-01-01"* ]]
	[[ "$output" == *"Findings: total=1 accepted=0 enforceable=1"* ]]
}

@test "primary markdown format writes markdown and json reports" {
	run "$SCRIPT" --all --format markdown --output-dir "$REPORT_DIR"

	[ "$status" -eq 0 ]
	[ -f "$REPORT_DIR/kramme_one.json" ]
	[ -f "$REPORT_DIR/kramme_one.md" ]
	grep -q "format=json" "$MOCK_SKILLSPECTOR_LOG"
	grep -q "format=markdown" "$MOCK_SKILLSPECTOR_LOG"
}
