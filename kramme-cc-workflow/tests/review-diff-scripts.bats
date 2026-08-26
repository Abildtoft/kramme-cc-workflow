#!/usr/bin/env bats

load 'test_helper/common'

setup() {
	SCRIPT_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)/scripts"
	TMP_DIR="$(mktemp -d)"
	ORIGIN="$TMP_DIR/origin.git"
	WORK="$TMP_DIR/work"
	BIN_DIR="$TMP_DIR/bin"
	mkdir -p "$BIN_DIR"
	write_failing_gh
	export PATH="$BIN_DIR:$PATH"

	init_test_git_repo "$WORK" --origin "$ORIGIN"
	cd "$WORK"
	git remote set-head origin main >/dev/null 2>&1
	git switch -c feature >/dev/null 2>&1
}

teardown() {
	if [ -n "$TMP_DIR" ] && [ -d "$TMP_DIR" ]; then
		rm -rf "$TMP_DIR"
	fi
}

write_failing_gh() {
	cat >"$BIN_DIR/gh" <<'GH'
#!/bin/sh
exit 1
GH
	chmod +x "$BIN_DIR/gh"
}

@test "resolve-base resolves origin HEAD and merge base" {
	run "$SCRIPT_DIR/resolve-base.sh"

	[ "$status" -eq 0 ]
	[[ "$output" == *"BASE_BRANCH=main"* ]]
	[[ "$output" == *"BASE_REF=refs/remotes/origin/main"* ]]
	[[ "$output" == *"MERGE_BASE="* ]]
}

@test "resolve-base strict mode fails when fetch fails" {
	git fetch origin main >/dev/null 2>&1
	git remote set-url origin "$TMP_DIR/missing-origin.git"

	run "$SCRIPT_DIR/resolve-base.sh" --strict

	[ "$status" -eq 1 ]
	[[ "$output" == *"Failed to fetch origin/main"* ]]
}

@test "resolve-base can tolerate fetch failure when cached ref exists" {
	git fetch origin main >/dev/null 2>&1
	git remote set-url origin "$TMP_DIR/missing-origin.git"

	run "$SCRIPT_DIR/resolve-base.sh" --tolerate-fetch-failure

	[ "$status" -eq 0 ]
	[[ "$output" == *"BASE_BRANCH=main"* ]]
	[[ "$output" == *"Warning: failed to fetch origin/main"* ]]
}

@test "collect-review-diff includes committed staged unstaged and untracked files" {
	printf 'committed\n' >committed.txt
	git add committed.txt
	git commit -m "feature commit" >/dev/null

	printf 'staged\n' >staged.txt
	git add staged.txt

	printf 'base\nunstaged\n' >tracked.txt
	printf 'untracked\n' >untracked.txt

	run bash -c '
    set -e
    eval "$("'"$SCRIPT_DIR"'/collect-review-diff.sh")"
    printf "%s\n" "$CHANGED_FILES"
  '

	[ "$status" -eq 0 ]
	[ "$output" = $'committed.txt\nstaged.txt\ntracked.txt\nuntracked.txt' ]
}

@test "collect-review-diff keeps a caller-pinned base without refetching" {
	local pinned_base
	pinned_base="$(git rev-parse refs/remotes/origin/main)"
	printf 'committed\n' >committed.txt
	git add committed.txt
	git commit -m "feature commit" >/dev/null
	git remote set-url origin "$TMP_DIR/missing-origin.git"

	run "$SCRIPT_DIR/collect-review-diff.sh" --base main --base-commit "$pinned_base"

	[ "$status" -eq 0 ]
	eval "$output"
	[ "$BASE_REF" = "$pinned_base" ]
	[ "$BASE_BRANCH" = "main" ]
	[ "$CHANGED_FILES" = "committed.txt" ]
}

@test "collect-review-diff emits JSON for structured consumers" {
	printf 'committed\n' >committed.txt
	git add committed.txt
	git commit -m "feature commit" >/dev/null

	printf 'staged\n' >staged.txt
	git add staged.txt

	printf 'base\nunstaged\n' >tracked.txt
	printf 'untracked\n' >untracked.txt

	run "$SCRIPT_DIR/collect-review-diff.sh" --format json

	[ "$status" -eq 0 ]
	COLLECTED_JSON="$output" python3 - <<'PY'
import json
import os
import sys

data = json.loads(os.environ["COLLECTED_JSON"])
expected_changed_files = [
    "committed.txt",
    "staged.txt",
    "tracked.txt",
    "untracked.txt",
]
assert data["base_ref"] == "refs/remotes/origin/main", data
assert data["base_branch"] == "main", data
assert isinstance(data["merge_base"], str) and data["merge_base"], data
assert data["changed_files"] == expected_changed_files, data
PY
}

@test "collect-review-diff emits collected fields directly as NUL-delimited values" {
	local fields="$TMP_DIR/collected-fields"
	printf 'committed\n' >committed.txt
	git add committed.txt
	git commit -m "feature commit" >/dev/null

	printf 'staged\n' >staged.txt
	git add staged.txt

	printf 'base\nunstaged\n' >tracked.txt
	printf 'untracked\n' >untracked.txt

	run bash -c '"$1" --format nul >"$2"' \
		_ "$SCRIPT_DIR/collect-review-diff.sh" "$fields"

	[ "$status" -eq 0 ]
	run bash -c '
    if ! {
      IFS= read -r -d "" base_ref &&
        IFS= read -r -d "" base_branch &&
        IFS= read -r -d "" merge_base &&
        IFS= read -r -d "" changed_files
    } <"$1"; then
      exit 1
    fi
    [ "$base_ref" = "refs/remotes/origin/main" ]
    [ "$base_branch" = "main" ]
    [ -n "$merge_base" ]
    [ "$changed_files" = "$2" ]
  ' _ "$fields" $'committed.txt\nstaged.txt\ntracked.txt\nuntracked.txt'
	[ "$status" -eq 0 ]
}

@test "collect-review-diff NUL output preserves hostile values without evaluating them" {
	local fields="$TMP_DIR/hostile-collected-fields"
	local pwned="$WORK/nul-output-pwned"
	local hostile='$(touch${IFS}nul-output-pwned)'
	printf 'hostile\n' >"$hostile"

	run bash -c '"$1" --format nul >"$2"' \
		_ "$SCRIPT_DIR/collect-review-diff.sh" "$fields"

	[ "$status" -eq 0 ]
	[ ! -e "$pwned" ]
	FIELDS_FILE="$fields" HOSTILE_FILE="$hostile" python3 - <<'PY'
import os
from pathlib import Path

fields = Path(os.environ["FIELDS_FILE"]).read_bytes().split(b"\0")
assert fields[0] == b"refs/remotes/origin/main", fields
assert fields[1] == b"main", fields
assert fields[2], fields
assert fields[3] == os.environ["HOSTILE_FILE"].encode(), fields
assert fields[4:] == [b""], fields
PY
	[ ! -e "$pwned" ]
}

@test "collect-review-diff decodes validated JSON fields once without evaluating content" {
	local decoded="$TMP_DIR/decoded-fields"
	local pwned="$TMP_DIR/decoder-pwned"
	local fixture
	fixture=$(PWNED_FILE="$pwned" python3 - <<'PY'
import json
import os

print(json.dumps({
    "base_ref": "refs/remotes/origin/main",
    "base_branch": "main branch\n$(touch${IFS}" + os.environ["PWNED_FILE"] + ")",
    "merge_base": "abc 123",
    "changed_files": ["space name.txt", "nested/line\nbreak.txt", "$(false)"],
}, separators=(",", ":")))
PY
)

	run bash -c 'printf "%s" "$1" | "$2" --decode-json >"$3"' \
		_ "$fixture" "$SCRIPT_DIR/collect-review-diff.sh" "$decoded"

	[ "$status" -eq 0 ]
	run bash -c '
    if ! {
      IFS= read -r -d "" base_ref &&
        IFS= read -r -d "" base_branch &&
        IFS= read -r -d "" merge_base &&
        IFS= read -r -d "" changed_files
    } <"$1"; then
      exit 1
    fi
    [ "$base_ref" = "$2" ]
    [ "$base_branch" = "$3" ]
    [ "$merge_base" = "$4" ]
    [ "$changed_files" = "$5" ]
  ' _ "$decoded" \
		'refs/remotes/origin/main' \
		$'main branch\n$(touch${IFS}'"$pwned"')' \
		'abc 123' \
		$'space name.txt\nnested/line\nbreak.txt\n$(false)'
	[ "$status" -eq 0 ]
	DECODED_FILE="$decoded" PWNED_FILE="$pwned" python3 - <<'PY'
import os
from pathlib import Path

fields = Path(os.environ["DECODED_FILE"]).read_bytes().split(b"\0")
assert fields == [
    b"refs/remotes/origin/main",
    b"main branch\n$(touch${IFS}" + os.environ["PWNED_FILE"].encode() + b")",
    b"abc 123",
    b"space name.txt\nnested/line\nbreak.txt\n$(false)",
    b"",
], fields
assert not Path(os.environ["PWNED_FILE"]).exists()
PY
}

@test "collect-review-diff decoder rejects malformed and missing JSON fields" {
	run bash -c 'printf "%s" "$1" | "$2" --decode-json' \
		_ '{not-json' "$SCRIPT_DIR/collect-review-diff.sh"
	[ "$status" -eq 1 ]
	[[ "$output" == *"Invalid collect-review-diff JSON output"* ]]

	run bash -c 'printf "%s" "$1" | "$2" --decode-json' \
		_ '{"base_ref":"origin/main","base_branch":"main","changed_files":[]}' \
		"$SCRIPT_DIR/collect-review-diff.sh"
	[ "$status" -eq 1 ]
	[[ "$output" == *"field 'merge_base' must be a string"* ]]
}

@test "collect-review-diff decoder rejects wrong field types" {
	run bash -c 'printf "%s" "$1" | "$2" --decode-json' \
		_ '{"base_ref":[],"base_branch":"main","merge_base":"abc","changed_files":[]}' \
		"$SCRIPT_DIR/collect-review-diff.sh"
	[ "$status" -eq 1 ]
	[[ "$output" == *"field 'base_ref' must be a string"* ]]

	run bash -c 'printf "%s" "$1" | "$2" --decode-json' \
		_ '{"base_ref":"origin/main","base_branch":"main","merge_base":"abc","changed_files":["ok",7]}' \
		"$SCRIPT_DIR/collect-review-diff.sh"
	[ "$status" -eq 1 ]
	[[ "$output" == *"field 'changed_files' must be a string list"* ]]

	run bash -c 'printf "%s" "$1" | "$2" --decode-json' \
		_ '{"base_ref":"origin/main","base_branch":"main\u0000evil","merge_base":"abc","changed_files":[]}' \
		"$SCRIPT_DIR/collect-review-diff.sh"
	[ "$status" -eq 1 ]
	[[ "$output" == *"field 'base_branch' must not contain NUL"* ]]
}

@test "collect-review-diff propagates resolver failure" {
	git remote set-url origin "$TMP_DIR/missing-origin.git"

	run "$SCRIPT_DIR/collect-review-diff.sh" --strict --format json

	[ "$status" -eq 1 ]
	[[ "$output" == *"Base resolution failed; see the message above and stop."* ]]
}

@test "collect-review-diff NUL output propagates resolver failure without partial fields" {
	local fields="$TMP_DIR/failed-collected-fields"
	git remote set-url origin "$TMP_DIR/missing-origin.git"

	run bash -c '"$1" --strict --format nul >"$2"' \
		_ "$SCRIPT_DIR/collect-review-diff.sh" "$fields"

	[ "$status" -eq 1 ]
	[[ "$output" == *"Base resolution failed; see the message above and stop."* ]]
	[ ! -s "$fields" ]
}

@test "collect-review-diff parses JSON resolver output without eval" {
	local fake_scripts="$TMP_DIR/fake-scripts"
	local pwned="$TMP_DIR/collect-pwned"
	local merge_base
	merge_base="$(git merge-base refs/remotes/origin/main HEAD)"
	mkdir -p "$fake_scripts/lib"
	cp "$SCRIPT_DIR/collect-review-diff.sh" "$fake_scripts/collect-review-diff.sh"
	cp "$SCRIPT_DIR/lib/shell-helpers.sh" "$fake_scripts/lib/shell-helpers.sh"
	cat >"$fake_scripts/resolve-base.sh" <<'SH'
#!/usr/bin/env bash
if [ "${1-}" != "--format" ] || [ "${2-}" != "json" ]; then
  echo "expected JSON format request" >&2
  exit 2
fi
python3 - <<'PY'
import json
import os

print(json.dumps({
    "base_ref": "refs/remotes/origin/main",
    "base_branch": "main$(touch${IFS}$PWNED_FILE)",
    "merge_base": os.environ["MERGE_BASE_FOR_TEST"],
    "after_commit": "",
    "reset_point": "",
    "original_tip": "",
    "backup_ref": "",
}, separators=(",", ":")))
PY
SH
	chmod +x "$fake_scripts/resolve-base.sh"
	export MERGE_BASE_FOR_TEST="$merge_base"
	export PWNED_FILE="$pwned"

	run "$fake_scripts/collect-review-diff.sh" --format json

	[ "$status" -eq 0 ]
	COLLECTED_JSON="$output" python3 - <<'PY'
import json
import os

data = json.loads(os.environ["COLLECTED_JSON"])
assert data["base_ref"] == "refs/remotes/origin/main", data
assert "touch" in data["base_branch"], data
PY
	[ ! -e "$pwned" ]
}

@test "collect-review-diff excludes canonical review artifacts only when asked" {
	local expected
	printf 'committed\n' >committed.txt
	git add committed.txt
	git commit -m "feature commit" >/dev/null

	printf 'report\n' >REVIEW_OVERVIEW.md
	printf 'plan\n' >PR_PLAN_W03A_EXAMPLE.md
	printf 'baseline\n' >QA_BASELINE.json
	printf 'source\n' >REVIEW_OVERVIEW_helper.md
	mkdir -p docs
	printf 'nested\n' >docs/REVIEW_OVERVIEW.md

	run "$SCRIPT_DIR/collect-review-diff.sh"
	[ "$status" -eq 0 ]
	eval "$output"
	expected="$(printf '%s\n' committed.txt docs/REVIEW_OVERVIEW.md \
		PR_PLAN_W03A_EXAMPLE.md QA_BASELINE.json REVIEW_OVERVIEW.md \
		REVIEW_OVERVIEW_helper.md | sort)"
	[ "$CHANGED_FILES" = "$expected" ]

	run "$SCRIPT_DIR/collect-review-diff.sh" --exclude-review-artifacts
	[ "$status" -eq 0 ]
	eval "$output"
	# Exact entries and glob entries drop; a near-miss name and a same-named
	# file nested below the root stay in scope as ordinary changed content.
	expected="$(printf '%s\n' committed.txt docs/REVIEW_OVERVIEW.md \
		REVIEW_OVERVIEW_helper.md | sort)"
	[ "$CHANGED_FILES" = "$expected" ]
}

@test "collect-review-diff filtering does not evaluate hostile file names" {
	printf 'committed\n' >committed.txt
	git add committed.txt
	git commit -m "feature commit" >/dev/null
	printf 'report\n' >REVIEW_OVERVIEW.md
	printf 'hostile\n' >'$(touch${IFS}filter-pwned).md'

	run "$SCRIPT_DIR/collect-review-diff.sh" --exclude-review-artifacts --format json

	[ "$status" -eq 0 ]
	[ ! -e filter-pwned ]
	COLLECTED_JSON="$output" python3 - <<'PY'
import json
import os

data = json.loads(os.environ["COLLECTED_JSON"])
assert data["changed_files"] == [
    "$(touch${IFS}filter-pwned).md",
    "committed.txt",
], data
PY
}

@test "collect-review-diff accepts an absent or untracked local review artifact" {
	printf 'committed\n' >committed.txt
	git add committed.txt
	git commit -m "feature commit" >/dev/null

	run "$SCRIPT_DIR/collect-review-diff.sh" \
		--require-local-artifact OVERENGINEERING_REVIEW_OVERVIEW.md
	[ "$status" -eq 0 ]
	eval "$output"
	[ "$CHANGED_FILES" = "committed.txt" ]

	printf 'previous review\n' >OVERENGINEERING_REVIEW_OVERVIEW.md

	run "$SCRIPT_DIR/collect-review-diff.sh" --exclude-review-artifacts \
		--require-local-artifact OVERENGINEERING_REVIEW_OVERVIEW.md
	[ "$status" -eq 0 ]
	eval "$output"
	[ "$CHANGED_FILES" = "committed.txt" ]
}

@test "collect-review-diff rejects branch-controlled previous-review state" {
	local artifact=OVERENGINEERING_REVIEW_OVERVIEW.md
	local trust_message="must be an untracked local workflow artifact"

	printf 'staged report\n' >"$artifact"
	git add "$artifact"
	run "$SCRIPT_DIR/collect-review-diff.sh" --require-local-artifact "$artifact"
	[ "$status" -eq 1 ]
	[[ "$output" == *"$artifact $trust_message"* ]]

	git commit -m "commit review report" >/dev/null
	run "$SCRIPT_DIR/collect-review-diff.sh" --require-local-artifact "$artifact"
	[ "$status" -eq 1 ]
	[[ "$output" == *"$trust_message"* ]]

	git rm -q "$artifact"
	git commit -m "remove review report" >/dev/null
	ln -s /etc/passwd "$artifact"
	run "$SCRIPT_DIR/collect-review-diff.sh" --require-local-artifact "$artifact"
	[ "$status" -eq 1 ]
	[[ "$output" == *"$trust_message"* ]]

	rm "$artifact"
	mkdir "$artifact"
	run "$SCRIPT_DIR/collect-review-diff.sh" --require-local-artifact "$artifact"
	[ "$status" -eq 1 ]
	[[ "$output" == *"$trust_message"* ]]
}

@test "collect-review-diff fails closed without the canonical artifact list" {
	local fake_scripts="$TMP_DIR/no-hooks/scripts"
	mkdir -p "$fake_scripts/lib"
	cp "$SCRIPT_DIR/collect-review-diff.sh" "$fake_scripts/collect-review-diff.sh"
	cp "$SCRIPT_DIR/lib/shell-helpers.sh" "$fake_scripts/lib/shell-helpers.sh"

	run "$fake_scripts/collect-review-diff.sh" --exclude-review-artifacts

	[ "$status" -eq 1 ]
	[[ "$output" == *"Review artifact list not found"* ]]
	[[ "$output" == *"refusing to filter review scope without it"* ]]
}

@test "collect-review-diff rejects review-preparation options in decoder mode" {
	run bash -c 'printf "%s" "$1" | "$2" --decode-json --exclude-review-artifacts' \
		_ '{}' "$SCRIPT_DIR/collect-review-diff.sh"
	[ "$status" -eq 1 ]
	[[ "$output" == *"--decode-json cannot be combined with collection options"* ]]

	run bash -c 'printf "%s" "$1" | "$2" --decode-json --format nul' \
		_ '{}' "$SCRIPT_DIR/collect-review-diff.sh"
	[ "$status" -eq 1 ]
	[[ "$output" == *"--decode-json cannot be combined with collection options"* ]]

	run bash -c 'printf "%s" "$1" | "$2" --decode-json --require-local-artifact "$3"' \
		_ '{}' "$SCRIPT_DIR/collect-review-diff.sh" OVERENGINEERING_REVIEW_OVERVIEW.md
	[ "$status" -eq 1 ]
	[[ "$output" == *"--decode-json cannot be combined with collection options"* ]]

	run "$SCRIPT_DIR/collect-review-diff.sh" --require-local-artifact
	[ "$status" -eq 1 ]
	[[ "$output" == *"--require-local-artifact requires a value"* ]]
}

@test "resolve-base backup mode creates recovery branch" {
	printf 'committed\n' >committed.txt
	git add committed.txt
	git commit -m "feature commit" >/dev/null
	feature_tip=$(git rev-parse HEAD)

	run "$SCRIPT_DIR/resolve-base.sh" --backup

	[ "$status" -eq 0 ]
	[[ "$output" == *"BACKUP_REF=feature-recreate-backup"* ]]
	[ "$(git rev-parse feature-recreate-backup)" = "$feature_tip" ]
}

@test "shared scripts parse as bash" {
	run bash -n "$SCRIPT_DIR/resolve-base.sh"
	[ "$status" -eq 0 ]

	run bash -n "$SCRIPT_DIR/collect-review-diff.sh"
	[ "$status" -eq 0 ]
}
