#!/usr/bin/env bats

load 'test_helper/common'

setup() {
	VALIDATOR="$BATS_TEST_DIRNAME/../skills/kramme:code:plan-to-pr/scripts/validate-plan-state.py"
	TMP_DIR="$(mktemp -d)"
	REPO="$TMP_DIR/repo"
	init_test_git_repo "$REPO"
	printf '.context/\n' >"$REPO/.gitignore"
	git -C "$REPO" add .gitignore
	git -C "$REPO" commit -m "ignore workflow state" >/dev/null
	BASE_COMMIT="$(git -C "$REPO" rev-parse HEAD)"
}

teardown() {
	rm -rf "$TMP_DIR"
}

write_plan() {
	local path="$1"
	local label="$2"
	local status="$3"
	local scope_path="${4:-tracked.txt}"
	local blocked_by="${5:-None}"
	local parallel="${6:-None}"
	mkdir -p "$(dirname "$path")"
	cat >"$path" <<EOF
# PR Plan $label: Validate plan state

**File:** \`PR_PLAN_${label}_VALIDATE_PLAN_STATE.md\` **Status:** $status **Execution label:** \`$label\` **Scope contract:** exact files **Parallel group:** $parallel **Blocked by:** $blocked_by **Blocks:** None **Planned at:** commit \`$BASE_COMMIT\`, 2026-08-27 **Impact:** HIGH **Leverage:** HIGH

## Scope

### In Scope

- \`$scope_path\` - validate this exact file.

### Out of Scope

- Everything else.

## Dependencies and Sequencing

### Prerequisites (must land before this PR)

$blocked_by.

### Dependents (blocked until this PR lands)

None.

### Parallel Work

$parallel.

## Completion Criteria

- [ ] Validation passes.

## Test and Verification Plan

- Run the fixture suite.

## STOP Conditions

Stop on invalid state.
EOF
}

write_parallel_root_index() {
	cat >"$REPO/PR_PLAN_INDEX.md" <<EOF
# PR Plan Index

**Planned at:** commit \`$BASE_COMMIT\` **Scope contract:** exact files

## Plans

| Label | Status | File | Plan Name | Impact | Leverage | Scope | Sequencing | Summary |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| \`W01A\` | TODO | \`PR_PLAN_W01A_VALIDATE_PLAN_STATE.md\` | Validate first peer | HIGH | HIGH | 1 | parallel in W01 | Fixture. |
| \`W01B\` | TODO | \`PR_PLAN_W01B_VALIDATE_PLAN_STATE.md\` | Validate second peer | HIGH | HIGH | 1 | parallel in W01 | Fixture. |

## Recommended Implementation Order

1. \`W01A\` and \`W01B\` in parallel.

## Dependency Map

\`W01A\` <-> \`W01B\`
EOF
	cat >"$REPO/PR_PLAN_REJECTIONS.md" <<'EOF'
# PR Plan Rejections

No findings were rejected.
EOF
}

write_two_independent_root_index() {
	cat >"$REPO/PR_PLAN_INDEX.md" <<EOF
# PR Plan Index

**Planned at:** commit \`$BASE_COMMIT\` **Scope contract:** exact files

## Plans

| Label | Status | File | Plan Name | Impact | Leverage | Scope | Sequencing | Summary |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| \`W01A\` | TODO | \`PR_PLAN_W01A_VALIDATE_PLAN_STATE.md\` | Validate first plan | HIGH | HIGH | 1 | independent | Fixture. |
| \`W02A\` | TODO | \`PR_PLAN_W02A_VALIDATE_PLAN_STATE.md\` | Validate second plan | HIGH | HIGH | 1 | independent | Fixture. |

## Recommended Implementation Order

1. \`W01A\`.
2. \`W02A\`.

## Dependency Map

\`W01A\`: independent
\`W02A\`: independent
EOF
	cat >"$REPO/PR_PLAN_REJECTIONS.md" <<'EOF'
# PR Plan Rejections

No findings were rejected.
EOF
}

write_root_index() {
	local status="${1:-TODO}"
	cat >"$REPO/PR_PLAN_INDEX.md" <<EOF
# PR Plan Index

**Planned at:** commit \`$BASE_COMMIT\` **Scope contract:** exact files

## Plans

| Label | Status | File | Plan Name | Impact | Leverage | Scope | Sequencing | Summary |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| \`W01A\` | $status | \`PR_PLAN_W01A_VALIDATE_PLAN_STATE.md\` | Validate plan state | HIGH | HIGH | 1 | independent | Fixture. |

## Recommended Implementation Order

1. \`W01A\` — \`PR_PLAN_W01A_VALIDATE_PLAN_STATE.md\`.

## Dependency Map

\`W01A\`: independent
EOF
	cat >"$REPO/PR_PLAN_REJECTIONS.md" <<'EOF'
# PR Plan Rejections

No findings were rejected.
EOF
}

write_dependent_root_index() {
	local prerequisite_status="${1:-DONE}"
	local selected_status="${2:-TODO}"
	cat >"$REPO/PR_PLAN_INDEX.md" <<EOF
# PR Plan Index

**Planned at:** commit \`$BASE_COMMIT\` **Scope contract:** exact files

## Plans

| Label | Status | File | Plan Name | Impact | Leverage | Scope | Sequencing | Summary |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| \`W01A\` | $prerequisite_status | \`PR_PLAN_W01A_VALIDATE_PLAN_STATE.md\` | Validate prerequisite | HIGH | HIGH | 1 | independent | Fixture. |
| \`W02A\` | $selected_status | \`PR_PLAN_W02A_VALIDATE_PLAN_STATE.md\` | Validate dependent | HIGH | HIGH | 1 | after W01A | Fixture. |

## Recommended Implementation Order

1. \`W01A\` — \`PR_PLAN_W01A_VALIDATE_PLAN_STATE.md\`.
2. \`W02A\` — \`PR_PLAN_W02A_VALIDATE_PLAN_STATE.md\`.

## Dependency Map

\`W01A\` -> \`W02A\`
EOF
	cat >"$REPO/PR_PLAN_REJECTIONS.md" <<'EOF'
# PR Plan Rejections

No findings were rejected.
EOF
}

source_object_id() {
	git -C "$REPO" hash-object --no-filters -- "$1"
}

plan_set_id() {
	local basename="$1"
	local source_id="$2"
	printf 'standalone-attachment\0%s\0%s\n' "$basename" "$source_id" |
		git -C "$REPO" hash-object --stdin |
		sed 's/^/ps-/'
}

write_archive() {
	local source_plan="$1"
	local status="${2:-TODO}"
	local label="${3:-A01A}"
	local contract="independent plan"
	if [[ "$label" == W* ]]; then
		contract="detached generated plan"
	fi
	local source_id set_id archive
	source_id="$(source_object_id "$source_plan")"
	set_id="$(plan_set_id "PR_PLAN_${label}_VALIDATE_PLAN_STATE.md" "$source_id")"
	archive="$REPO/.context/code-plan-to-pr/$set_id/plans"
	mkdir -p "$archive"
	cp "$source_plan" "$archive/ATTACHMENT_SOURCE.md"
	cp "$source_plan" "$archive/PR_PLAN_${label}_VALIDATE_PLAN_STATE.md"
	if [ "$status" != "TODO" ]; then
		python3 - "$archive/PR_PLAN_${label}_VALIDATE_PLAN_STATE.md" "$status" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
path.write_text(path.read_text().replace("**Status:** TODO", f"**Status:** {sys.argv[2]}", 1))
PY
	fi
	cat >"$archive/PR_PLAN_INDEX.md" <<EOF
# PR Plan Index

**Input mode:** standalone attachment **Attachment contract:** $contract **Scope contract:** exact files **Source object:** \`$source_id\` **Source snapshot:** \`ATTACHMENT_SOURCE.md\` **Planned at:** commit \`$BASE_COMMIT\` **Plans generated:** 1

## Plans

| Label | Status | File | Plan Name | Impact | Leverage | Scope | Sequencing | Summary |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| \`$label\` | $status | \`PR_PLAN_${label}_VALIDATE_PLAN_STATE.md\` | Attached plan | HIGH | HIGH | 1 | none | Fixture. |

## Recommended Implementation Order

1. \`$label\` — \`PR_PLAN_${label}_VALIDATE_PLAN_STATE.md\`.

## Dependency Map

\`$label\`: none
EOF
	cat >"$archive/PR_PLAN_REJECTIONS.md" <<'EOF'
# PR Plan Rejections

**Input mode:** standalone attachment

No companion rejection data was supplied with this attached plan.
EOF
	printf '%s\n' "$archive"
}

append_readiness_evidence() {
	local plan="$1"
	local location="${2:-tracked.txt}"
	local decision="${3:-Pass when the parser fixture is present; fail otherwise.}"
	cat >>"$plan" <<EOF

### Prerequisite Readiness Evidence

#### W01A

- **Required base state:** The prerequisite parser contract is present.
- **Evidence locations:** \`$location\` contains the parser fixture.
- **Readiness decision:** $decision
EOF
}

json_get() {
	JSON_OUTPUT="$output" python3 - "$1" <<'PY'
import json
import os
import sys

value = json.loads(os.environ["JSON_OUTPUT"])
for part in sys.argv[1].split("."):
    value = value[int(part)] if part.isdigit() else value[part]
print(json.dumps(value) if isinstance(value, (dict, list, bool)) else value)
PY
}

assert_success() {
	[ "$status" -eq 0 ] || { echo "$output"; false; }
}

assert_error() {
	local expected="$1"
	[ "$status" -eq 2 ] || { echo "$output"; false; }
	[ "$(json_get error.code)" = "$expected" ] || { echo "$output"; false; }
}

tree_digest() {
	(
		cd "$REPO"
		find . -path ./.git -prune -o -type f -print0 |
			LC_ALL=C sort -z |
			xargs -0 shasum
	) | shasum | cut -d' ' -f1
}

@test "valid root plan set returns deterministic structured facts" {
	write_plan "$REPO/PR_PLAN_W01A_VALIDATE_PLAN_STATE.md" W01A TODO
	write_root_index

	run python3 "$VALIDATOR" --repo-root "$REPO" "$REPO/PR_PLAN_W01A_VALIDATE_PLAN_STATE.md"

	assert_success
	[ "$(json_get ok)" = "true" ]
	[ "$(json_get facts.plan_input_mode)" = "root" ]
	[ "$(json_get facts.scope_mode)" = "exact-files" ]
	[ "$(json_get facts.scope_paths.0)" = "tracked.txt" ]
	[ "$(json_get facts.drift_check_reason)" = "checked" ]
	[ "$(json_get facts.plan_impact)" = "HIGH" ]
	[ "$(json_get facts.plan_leverage)" = "HIGH" ]
	[ "$(json_get facts.sequencing_summary)" = "none" ]
	first_id="$(json_get facts.plan_set_id)"
	[[ "$first_id" == ps-* ]]

	run python3 "$VALIDATOR" --repo-root "$REPO" "$REPO/PR_PLAN_W01A_VALIDATE_PLAN_STATE.md"
	assert_success
	[ "$(json_get facts.plan_set_id)" = "$first_id" ]

	printf '\nA rejected finding changed.\n' >>"$REPO/PR_PLAN_REJECTIONS.md"
	run python3 "$VALIDATOR" --repo-root "$REPO" "$REPO/PR_PLAN_W01A_VALIDATE_PLAN_STATE.md"
	assert_success
	[ "$(json_get facts.plan_set_id)" != "$first_id" ]
}

@test "public strict and ship flags are returned as structured facts" {
	write_plan "$REPO/PR_PLAN_W01A_VALIDATE_PLAN_STATE.md" W01A TODO
	write_root_index

	run python3 "$VALIDATOR" --repo-root "$REPO" --strict --ship "$REPO/PR_PLAN_W01A_VALIDATE_PLAN_STATE.md"

	assert_success
	[ "$(json_get facts.strict_review)" = "true" ]
	[ "$(json_get facts.ship_mode)" = "true" ]
}

@test "complete plan set returns verified prerequisite landing records" {
	write_plan "$REPO/PR_PLAN_W01A_VALIDATE_PLAN_STATE.md" W01A DONE prerequisite.txt
	cat >>"$REPO/PR_PLAN_W01A_VALIDATE_PLAN_STATE.md" <<'EOF'

## Execution Result

- **Landed commit:** `1111111111111111111111111111111111111111`
EOF
	write_plan "$REPO/PR_PLAN_W02A_VALIDATE_PLAN_STATE.md" W02A TODO dependent.txt W01A
	write_dependent_root_index

	run python3 "$VALIDATOR" --repo-root "$REPO" "$REPO/PR_PLAN_W02A_VALIDATE_PLAN_STATE.md"

	assert_success
	[ "$(json_get facts.prerequisite_records.0.label)" = "W01A" ]
	[ "$(json_get facts.prerequisite_records.0.status)" = "DONE" ]
	[[ "$(json_get facts.prerequisite_records.0.execution_result)" == *"Landed commit"* ]]
}

@test "complete plan set rejects a DONE prerequisite without an execution result" {
	write_plan "$REPO/PR_PLAN_W01A_VALIDATE_PLAN_STATE.md" W01A DONE prerequisite.txt
	write_plan "$REPO/PR_PLAN_W02A_VALIDATE_PLAN_STATE.md" W02A TODO dependent.txt W01A
	write_dependent_root_index

	run python3 "$VALIDATOR" --repo-root "$REPO" "$REPO/PR_PLAN_W02A_VALIDATE_PLAN_STATE.md"

	assert_error PREREQUISITE_RESULT_MISSING
}

@test "complete plan set requires and returns the selected DONE result" {
	write_plan "$REPO/PR_PLAN_W01A_VALIDATE_PLAN_STATE.md" W01A DONE
	write_root_index DONE

	run python3 "$VALIDATOR" --repo-root "$REPO" "$REPO/PR_PLAN_W01A_VALIDATE_PLAN_STATE.md"
	assert_error TERMINAL_RESULT_MISSING

	cat >>"$REPO/PR_PLAN_W01A_VALIDATE_PLAN_STATE.md" <<'EOF'

## Execution Result

- **Landed commit:** `1111111111111111111111111111111111111111`
EOF
	run python3 "$VALIDATOR" --repo-root "$REPO" "$REPO/PR_PLAN_W01A_VALIDATE_PLAN_STATE.md"

	assert_success
	[[ "$(json_get facts.terminal_execution_result)" == *"Landed commit"* ]]
	[ "$(json_get facts.drift_check_reason)" = "terminal-retry" ]
}

@test "index sequencing must agree with plan dependencies" {
	write_plan "$REPO/PR_PLAN_W01A_VALIDATE_PLAN_STATE.md" W01A TODO tracked.txt W02A
	write_root_index
	python3 - "$REPO/PR_PLAN_INDEX.md" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
path.write_text(path.read_text().replace("| independent |", "| blocks W02A |", 1))
PY

	run python3 "$VALIDATOR" --repo-root "$REPO" "$REPO/PR_PLAN_W01A_VALIDATE_PLAN_STATE.md"

	assert_error INDEX_DEPENDENCY_MISMATCH
}

@test "canonical same-wave sequencing agrees with named parallel peers" {
	write_plan "$REPO/PR_PLAN_W01A_VALIDATE_PLAN_STATE.md" W01A TODO first.txt None W01B
	write_plan "$REPO/PR_PLAN_W01B_VALIDATE_PLAN_STATE.md" W01B TODO second.txt None W01A
	write_parallel_root_index

	run python3 "$VALIDATOR" --repo-root "$REPO" "$REPO/PR_PLAN_W01A_VALIDATE_PLAN_STATE.md"

	assert_success
	[ "$(json_get facts.parallel_peers.0)" = "W01B" ]
}

@test "every generated plan must agree with its index row" {
	write_plan "$REPO/PR_PLAN_W01A_VALIDATE_PLAN_STATE.md" W01A TODO first.txt
	write_plan "$REPO/PR_PLAN_W02A_VALIDATE_PLAN_STATE.md" W02A READY second.txt
	write_two_independent_root_index

	run python3 "$VALIDATOR" --repo-root "$REPO" "$REPO/PR_PLAN_W01A_VALIDATE_PLAN_STATE.md"

	assert_error INDEX_PLAN_MISMATCH
	[ "$(json_get error.details.filename)" = "PR_PLAN_W02A_VALIDATE_PLAN_STATE.md" ]
}

@test "complete plan prerequisites require DONE agreement in index and plan" {
	write_plan "$REPO/PR_PLAN_W01A_VALIDATE_PLAN_STATE.md" W01A DONE prerequisite.txt
	cat >>"$REPO/PR_PLAN_W01A_VALIDATE_PLAN_STATE.md" <<'EOF'

## Execution Result

- **Landed commit:** `1111111111111111111111111111111111111111`
EOF
	write_plan "$REPO/PR_PLAN_W02A_VALIDATE_PLAN_STATE.md" W02A TODO dependent.txt W01A
	write_dependent_root_index
	python3 - "$REPO/PR_PLAN_INDEX.md" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
path.write_text(path.read_text().replace("| `W01A` | DONE |", "| `W01A` | TODO |", 1))
PY
	run python3 "$VALIDATOR" --repo-root "$REPO" "$REPO/PR_PLAN_W02A_VALIDATE_PLAN_STATE.md"
	assert_error PREREQUISITE_NOT_DONE

	write_plan "$REPO/PR_PLAN_W01A_VALIDATE_PLAN_STATE.md" W01A TODO prerequisite.txt
	write_dependent_root_index
	run python3 "$VALIDATOR" --repo-root "$REPO" "$REPO/PR_PLAN_W02A_VALIDATE_PLAN_STATE.md"
	assert_error PREREQUISITE_PLAN_MISMATCH
}

@test "valid attachment is classified from its location and canonical declaration" {
	write_plan "$REPO/.context/attachments/client-id/pasted_text.txt" A01A READY

	run python3 "$VALIDATOR" --repo-root "$REPO" "$REPO/.context/attachments/client-id/pasted_text.txt"

	assert_success
	[ "$(json_get facts.plan_input_mode)" = "attachment" ]
	[ "$(json_get facts.selected_basename)" = "PR_PLAN_A01A_VALIDATE_PLAN_STATE.md" ]
	[ "$(json_get facts.standalone_attachment)" = "true" ]
	[ "$(json_get facts.plan_status)" = "READY" ]
	[ "$(json_get facts.attachment_contract)" = "independent plan" ]
}

@test "direct children of the attachments directory are supported" {
	write_plan "$REPO/.context/attachments/input.md" A01A TODO

	run python3 "$VALIDATOR" --repo-root "$REPO" "$REPO/.context/attachments/input.md"

	assert_success
	[ "$(json_get facts.plan_input_mode)" = "attachment" ]
}

@test "independent drifted and stale attachments reach refresh routing" {
	for plan_status in DRIFTED STALE; do
		plan="$REPO/.context/attachments/${plan_status}.md"
		write_plan "$plan" A01A "$plan_status"

		run python3 "$VALIDATOR" --repo-root "$REPO" "$plan"

		assert_success
		[ "$(json_get facts.plan_status)" = "$plan_status" ]
		[ "$(json_get facts.drift_check_reason)" = "lifecycle-recovery" ]
	done
}

@test "recovery lifecycle does not require planned-at ancestry" {
	plan="$REPO/.context/attachments/STALE.md"
	write_plan "$plan" A01A STALE
	other_commit="$(git -C "$REPO" commit-tree "$BASE_COMMIT^{tree}" -m "unrelated history")"
	python3 - "$plan" "$BASE_COMMIT" "$other_commit" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
path.write_text(path.read_text().replace(sys.argv[2], sys.argv[3], 1))
PY

	run python3 "$VALIDATOR" --repo-root "$REPO" "$plan"

	assert_success
	[ "$(json_get facts.drift_check_reason)" = "lifecycle-recovery" ]
}

@test "recovery lifecycle does not require prerequisites to be DONE" {
	write_plan "$REPO/PR_PLAN_W01A_VALIDATE_PLAN_STATE.md" W01A TODO prerequisite.txt
	write_plan "$REPO/PR_PLAN_W02A_VALIDATE_PLAN_STATE.md" W02A DRIFTED dependent.txt W01A
	write_dependent_root_index TODO DRIFTED

	run python3 "$VALIDATOR" --repo-root "$REPO" "$REPO/PR_PLAN_W02A_VALIDATE_PLAN_STATE.md"

	assert_success
	[ "$(json_get facts.drift_check_reason)" = "lifecycle-recovery" ]
	[ "$(json_get facts.prerequisite_records)" = "[]" ]
}

@test "attachment impact and leverage metadata are bounded and unique" {
	plan="$REPO/.context/attachments/input.md"
	write_plan "$plan" A01A TODO
	python3 - "$plan" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
path.write_text(path.read_text().replace(" **Impact:** HIGH", "", 1))
PY
	run python3 "$VALIDATOR" --repo-root "$REPO" "$plan"
	assert_error METADATA_MISSING
	[ "$(json_get error.details.field)" = "Impact" ]

	write_plan "$plan" A01A TODO
	python3 - "$plan" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
path.write_text(path.read_text().replace("**Leverage:** HIGH", "**Leverage:** EXTREME", 1))
PY
	run python3 "$VALIDATOR" --repo-root "$REPO" "$plan"
	assert_error METADATA_MISSING
	[ "$(json_get error.details.field)" = "Leverage" ]

	write_plan "$plan" A01A TODO
	python3 - "$plan" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
path.write_text(path.read_text().replace("**Impact:** HIGH", "**Impact:** HIGH **Impact:** LOW", 1))
PY
	run python3 "$VALIDATOR" --repo-root "$REPO" "$plan"
	assert_error METADATA_DUPLICATE
}

@test "dependency labels reject malformed and duplicate values" {
	plan="$REPO/.context/attachments/input.md"
	for malformed in W1A W01 W01AB X01A 'None; w01a' 'None W01A_extra' 'None WW01A' 'None W01-A'; do
		write_plan "$plan" W02A BLOCKED tracked.txt "$malformed"
		run python3 "$VALIDATOR" --repo-root "$REPO" "$plan"
		assert_error DEPENDENCY_LABEL_INVALID
	done

	write_plan "$plan" W02A BLOCKED tracked.txt "W01A W01A"
	run python3 "$VALIDATOR" --repo-root "$REPO" "$plan"
	assert_error DEPENDENCY_LABEL_DUPLICATE
}

@test "status values reject trailing malformed content" {
	plan="$REPO/.context/attachments/input.md"
	for malformed in TODO123 TODO-extra; do
		write_plan "$plan" A01A "$malformed"
		run python3 "$VALIDATOR" --repo-root "$REPO" "$plan"
		assert_error STATUS_INVALID
	done
}

@test "markdown-formatted unresolved requirements block validation" {
	plan="$REPO/.context/attachments/input.md"
	for marker in "- MISSING REQUIREMENT: choose the data semantics" "> CONFUSION: choose the API behavior" "    MISSING REQUIREMENT: choose the indented behavior"; do
		write_plan "$plan" A01A TODO
		printf '\n%s\n' "$marker" >>"$plan"
		run python3 "$VALIDATOR" --repo-root "$REPO" "$plan"
		assert_error PLAN_REQUIREMENT_UNRESOLVED
	done
}

@test "fenced headings do not satisfy required plan sections" {
	plan="$REPO/.context/attachments/input.md"
	write_plan "$plan" A01A TODO
	python3 - "$plan" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text().replace("## Completion Criteria", "## Removed Completion Criteria", 1)
text += "\n```markdown\n## Completion Criteria\n\n- [ ] Fenced examples are not plan structure.\n```\n"
path.write_text(text)
PY

	run python3 "$VALIDATOR" --repo-root "$REPO" "$plan"

	assert_error PLAN_SECTION_MISSING
}

@test "exact scope rejects the linked-worktree gitfile boundary" {
	linked="$TMP_DIR/linked"
	git -C "$REPO" worktree add -b linked-boundary "$linked" >/dev/null
	write_plan "$linked/.context/attachments/input.md" A01A TODO .git

	run python3 "$VALIDATOR" --repo-root "$linked" "$linked/.context/attachments/input.md"

	assert_error SCOPE_PATH_INVALID
}

@test "ignored exact-file scope is rejected behaviorally" {
	printf 'ignored.txt\n' >>"$REPO/.gitignore"
	plan="$REPO/.context/attachments/input.md"
	write_plan "$plan" A01A TODO ignored.txt

	run python3 "$VALIDATOR" --repo-root "$REPO" "$plan"

	assert_error SCOPE_PATH_IGNORED
}

@test "containment scope does not apply exact-file ignored-path eligibility" {
	printf 'ignored-dir/\n' >>"$REPO/.gitignore"
	write_plan "$REPO/PR_PLAN_W01A_VALIDATE_PLAN_STATE.md" W01A TODO ignored-dir
	write_root_index
	python3 - "$REPO/PR_PLAN_W01A_VALIDATE_PLAN_STATE.md" "$REPO/PR_PLAN_INDEX.md" <<'PY'
from pathlib import Path
import sys

for name in sys.argv[1:]:
    path = Path(name)
    path.write_text(path.read_text().replace(" **Scope contract:** exact files", "", 1))
PY

	run python3 "$VALIDATOR" --repo-root "$REPO" "$REPO/PR_PLAN_W01A_VALIDATE_PLAN_STATE.md"

	assert_success
	[ "$(json_get facts.scope_mode)" = "containment" ]
}

@test "detached blockers require structured repository readiness evidence" {
	plan="$REPO/.context/attachments/client-id/pasted_text.txt"
	write_plan "$plan" W02A BLOCKED tracked.txt W01A

	run python3 "$VALIDATOR" --repo-root "$REPO" "$plan"
	assert_error PREREQUISITE_EVIDENCE_MISSING

	cat >>"$plan" <<'EOF'

### Prerequisite Readiness Evidence

#### W01A

- **Required base state:** The prerequisite parser contract is present.
- **Evidence locations:** `tracked.txt` contains the parser fixture.
- **Readiness decision:** Pass when the parser fixture is present; fail otherwise.
EOF
	run python3 "$VALIDATOR" --repo-root "$REPO" "$plan"

	assert_success
	[ "$(json_get facts.prerequisite_evidence.0.label)" = "W01A" ]
	[ "$(json_get facts.prerequisite_evidence.0.evidence_paths.0)" = "tracked.txt" ]
}

@test "detached readiness evidence rejects duplicate entries and missing fields" {
	plan="$REPO/.context/attachments/input.md"
	write_plan "$plan" W02A BLOCKED tracked.txt W01A
	append_readiness_evidence "$plan"
	cat >>"$plan" <<'EOF'

#### W01A

- **Required base state:** Duplicate evidence must not be accepted.
- **Evidence locations:** `tracked.txt` contains the parser fixture.
- **Readiness decision:** Pass when the parser fixture is present; fail otherwise.
EOF
	run python3 "$VALIDATOR" --repo-root "$REPO" "$plan"
	assert_error PREREQUISITE_EVIDENCE_MISSING
	[ "$(json_get error.details.entries)" = "2" ]

	write_plan "$plan" W02A BLOCKED tracked.txt W01A
	cat >>"$plan" <<'EOF'

### Prerequisite Readiness Evidence

#### W01A

- **Required base state:** The prerequisite parser contract is present.
- **Evidence locations:** `tracked.txt` contains the parser fixture.
EOF
	run python3 "$VALIDATOR" --repo-root "$REPO" "$plan"
	assert_error PREREQUISITE_EVIDENCE_INVALID
	[ "$(json_get error.details.field)" = "Readiness decision" ]

	write_plan "$plan" W02A BLOCKED tracked.txt W01A
	cat >>"$plan" <<'EOF'

### Prerequisite Readiness Evidence

#### W01A

- **Required base state:** The prerequisite parser contract is present.
- **Evidence locations:** The tracked fixture contains the parser contract.
- **Readiness decision:** Pass when the parser fixture is present; fail otherwise.
EOF
	run python3 "$VALIDATOR" --repo-root "$REPO" "$plan"
	assert_error PREREQUISITE_EVIDENCE_INVALID
}

@test "detached readiness evidence rejects unsafe and workflow-owned sources" {
	plan="$REPO/.context/attachments/input.md"
	write_plan "$plan" W02A BLOCKED tracked.txt W01A
	append_readiness_evidence "$plan" ../outside.txt
	run python3 "$VALIDATOR" --repo-root "$REPO" "$plan"
	assert_error PREREQUISITE_EVIDENCE_PATH_INVALID

	write_plan "$plan" W02A BLOCKED tracked.txt W01A
	append_readiness_evidence "$plan" PR_PLAN_INDEX.md
	run python3 "$VALIDATOR" --repo-root "$REPO" "$plan"
	assert_error PREREQUISITE_EVIDENCE_INVALID
}

@test "valid normalized archive proves immutable source identity" {
	write_plan "$REPO/source.md" A01A TODO
	archive="$(write_archive "$REPO/source.md")"

	run python3 "$VALIDATOR" --repo-root "$REPO" "$archive/PR_PLAN_A01A_VALIDATE_PLAN_STATE.md"

	assert_success
	[ "$(json_get facts.plan_input_mode)" = "archived" ]
	[ "$(json_get facts.standalone_attachment)" = "true" ]
	[ "$(json_get facts.archive_source_verified)" = "true" ]
}

@test "normalized archive rejects mutable plan divergence" {
	write_plan "$REPO/source.md" A01A TODO
	archive="$(write_archive "$REPO/source.md")"
	python3 - "$archive/PR_PLAN_A01A_VALIDATE_PLAN_STATE.md" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
path.write_text(path.read_text().replace("- Everything else.", "- Everything except an altered boundary.", 1))
PY

	run python3 "$VALIDATOR" --repo-root "$REPO" "$archive/PR_PLAN_A01A_VALIDATE_PLAN_STATE.md"

	assert_error ARCHIVE_SOURCE_DIVERGED
}

@test "legacy independent archive exposes verified migration routing" {
	write_plan "$REPO/source.md" A01A TODO
	archive="$(write_archive "$REPO/source.md")"
	python3 - "$archive/PR_PLAN_INDEX.md" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
path.write_text(path.read_text().replace(" **Attachment contract:** independent plan", "", 1))
PY
	before="$(tree_digest)"

	run python3 "$VALIDATOR" --repo-root "$REPO" "$archive/PR_PLAN_A01A_VALIDATE_PLAN_STATE.md"

	assert_error ARCHIVE_MIGRATION_REQUIRED
	[ "$(json_get error.details.verified)" = "true" ]
	[ "$(json_get error.details.index_path)" = "${archive#"$REPO/"}/PR_PLAN_INDEX.md" ]
	[ "$(tree_digest)" = "$before" ]
}

@test "detached in-progress archive exposes bounded recovery without drift failure" {
	write_plan "$REPO/source.md" W01A TODO
	archive="$(write_archive "$REPO/source.md" IN_PROGRESS W01A)"
	plan="$archive/PR_PLAN_W01A_VALIDATE_PLAN_STATE.md"

	run python3 "$VALIDATOR" --repo-root "$REPO" "$plan"
	assert_success
	branch="$(json_get facts.plan_branch)"
	git -C "$REPO" switch -c "$branch" >/dev/null
	printf 'interrupted implementation\n' >"$REPO/tracked.txt"
	git -C "$REPO" add tracked.txt
	git -C "$REPO" commit -m "implement interrupted fixture" >/dev/null

	run python3 "$VALIDATOR" --repo-root "$REPO" "$plan"

	assert_success
	[ "$(json_get facts.detached_recovery_required)" = "true" ]
	[ "$(json_get facts.drift_check_reason)" = "detached-recovery" ]
	[ "$(json_get facts.drift_check_skipped)" = "true" ]
}

@test "detached implementation staging takes precedence over recovery classification" {
	write_plan "$REPO/source.md" W01A TODO
	archive="$(write_archive "$REPO/source.md" IN_PROGRESS W01A)"
	plan="$archive/PR_PLAN_W01A_VALIDATE_PLAN_STATE.md"
	printf 'implementation drift\n' >"$REPO/tracked.txt"

	run python3 "$VALIDATOR" --repo-root "$REPO" --allow-worktree-drift "$plan"

	assert_success
	[ "$(json_get facts.detached_recovery_required)" = "true" ]
	[ "$(json_get facts.drift_check_reason)" = "implementation-drift-bypass" ]
	[ "$(json_get facts.drift_check_skipped)" = "true" ]
}

@test "implementation drift bypass remains internal to archived staging" {
	plan="$REPO/.context/attachments/input.md"
	write_plan "$plan" A01A TODO
	printf 'implementation drift\n' >"$REPO/tracked.txt"

	run python3 "$VALIDATOR" --repo-root "$REPO" --allow-worktree-drift "$plan"

	assert_error ARGUMENT_INVALID
}

@test "valid complete generated archive preserves its established set identity" {
	write_plan "$REPO/PR_PLAN_W01A_VALIDATE_PLAN_STATE.md" W01A TODO
	write_root_index
	run python3 "$VALIDATOR" --repo-root "$REPO" "$REPO/PR_PLAN_W01A_VALIDATE_PLAN_STATE.md"
	assert_success
	set_id="$(json_get facts.plan_set_id)"
	archive="$REPO/.context/code-plan-to-pr/$set_id/plans"
	mkdir -p "$archive"
	mv "$REPO/PR_PLAN_W01A_VALIDATE_PLAN_STATE.md" "$REPO/PR_PLAN_INDEX.md" \
		"$REPO/PR_PLAN_REJECTIONS.md" "$archive/"

	run python3 "$VALIDATOR" --repo-root "$REPO" "$archive/PR_PLAN_W01A_VALIDATE_PLAN_STATE.md"

	assert_success
	[ "$(json_get facts.plan_input_mode)" = "archived" ]
	[ "$(json_get facts.plan_set_id)" = "$set_id" ]
	[ "$(json_get facts.standalone_attachment)" = "false" ]
	[ "$(json_get facts.archive_source_verified)" = "false" ]
}

@test "root and archived generated sets reject partial scope contracts" {
	write_plan "$REPO/PR_PLAN_W01A_VALIDATE_PLAN_STATE.md" W01A TODO
	write_root_index
	python3 - "$REPO/PR_PLAN_INDEX.md" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
path.write_text(path.read_text().replace(" **Scope contract:** exact files", "", 1))
PY

	run python3 "$VALIDATOR" --repo-root "$REPO" "$REPO/PR_PLAN_W01A_VALIDATE_PLAN_STATE.md"
	assert_error SCOPE_CONTRACT_INVALID

	write_root_index
	run python3 "$VALIDATOR" --repo-root "$REPO" "$REPO/PR_PLAN_W01A_VALIDATE_PLAN_STATE.md"
	assert_success
	set_id="$(json_get facts.plan_set_id)"
	archive="$REPO/.context/code-plan-to-pr/$set_id/plans"
	mkdir -p "$archive"
	mv "$REPO/PR_PLAN_W01A_VALIDATE_PLAN_STATE.md" "$REPO/PR_PLAN_INDEX.md" \
		"$REPO/PR_PLAN_REJECTIONS.md" "$archive/"
	python3 - "$archive/PR_PLAN_INDEX.md" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
path.write_text(path.read_text().replace(" **Scope contract:** exact files", "", 1))
PY

	run python3 "$VALIDATOR" --repo-root "$REPO" "$archive/PR_PLAN_W01A_VALIDATE_PLAN_STATE.md"
	assert_error SCOPE_CONTRACT_INVALID
}

@test "complete generated archives require the retained rejection record" {
	write_plan "$REPO/PR_PLAN_W01A_VALIDATE_PLAN_STATE.md" W01A TODO
	write_root_index
	run python3 "$VALIDATOR" --repo-root "$REPO" "$REPO/PR_PLAN_W01A_VALIDATE_PLAN_STATE.md"
	assert_success
	set_id="$(json_get facts.plan_set_id)"
	archive="$REPO/.context/code-plan-to-pr/$set_id/plans"
	mkdir -p "$archive"
	mv "$REPO/PR_PLAN_W01A_VALIDATE_PLAN_STATE.md" "$REPO/PR_PLAN_INDEX.md" "$archive/"

	run python3 "$VALIDATOR" --repo-root "$REPO" "$archive/PR_PLAN_W01A_VALIDATE_PLAN_STATE.md"

	assert_error ARCHIVE_REJECTIONS_MISSING
}

@test "root plan sets require a rejection record before archive identity" {
	write_plan "$REPO/PR_PLAN_W01A_VALIDATE_PLAN_STATE.md" W01A TODO
	write_root_index
	rm "$REPO/PR_PLAN_REJECTIONS.md"

	run python3 "$VALIDATOR" --repo-root "$REPO" "$REPO/PR_PLAN_W01A_VALIDATE_PLAN_STATE.md"

	assert_error ROOT_REJECTIONS_MISSING
	[ ! -d "$REPO/.context/code-plan-to-pr" ]
}

@test "rejection-record standalone evidence cannot downgrade to a generated archive" {
	write_plan "$REPO/PR_PLAN_W01A_VALIDATE_PLAN_STATE.md" W01A TODO
	write_root_index
	run python3 "$VALIDATOR" --repo-root "$REPO" "$REPO/PR_PLAN_W01A_VALIDATE_PLAN_STATE.md"
	assert_success
	set_id="$(json_get facts.plan_set_id)"
	archive="$REPO/.context/code-plan-to-pr/$set_id/plans"
	mkdir -p "$archive"
	mv "$REPO/PR_PLAN_W01A_VALIDATE_PLAN_STATE.md" "$REPO/PR_PLAN_INDEX.md" \
		"$REPO/PR_PLAN_REJECTIONS.md" "$archive/"
	cat >>"$archive/PR_PLAN_REJECTIONS.md" <<'EOF'

**Input mode:** standalone attachment
EOF

	run python3 "$VALIDATOR" --repo-root "$REPO" "$archive/PR_PLAN_W01A_VALIDATE_PLAN_STATE.md"

	assert_error ARCHIVE_INPUT_MARKER_INVALID
}

@test "dangling standalone source evidence cannot downgrade to a generated archive" {
	write_plan "$REPO/PR_PLAN_W01A_VALIDATE_PLAN_STATE.md" W01A TODO
	write_root_index
	run python3 "$VALIDATOR" --repo-root "$REPO" "$REPO/PR_PLAN_W01A_VALIDATE_PLAN_STATE.md"
	assert_success
	set_id="$(json_get facts.plan_set_id)"
	archive="$REPO/.context/code-plan-to-pr/$set_id/plans"
	mkdir -p "$archive"
	mv "$REPO/PR_PLAN_W01A_VALIDATE_PLAN_STATE.md" "$REPO/PR_PLAN_INDEX.md" \
		"$REPO/PR_PLAN_REJECTIONS.md" "$archive/"
	ln -s missing-source.md "$archive/ATTACHMENT_SOURCE.md"

	run python3 "$VALIDATOR" --repo-root "$REPO" "$archive/PR_PLAN_W01A_VALIDATE_PLAN_STATE.md"

	assert_error ARCHIVE_INPUT_MARKER_INVALID
}

@test "validator rejects a final symlink without following it" {
	write_plan "$REPO/.context/attachments/client-id/real.md" A01A TODO
	ln -s real.md "$REPO/.context/attachments/client-id/link.md"

	run python3 "$VALIDATOR" --repo-root "$REPO" "$REPO/.context/attachments/client-id/link.md"

	assert_error INPUT_SYMLINK
}

@test "validator rejects parent symlinks in attachment containment" {
	mkdir -p "$REPO/.context/real-attachments/client-id"
	write_plan "$REPO/.context/real-attachments/client-id/input.md" A01A TODO
	ln -s real-attachments "$REPO/.context/attachments"

	run python3 "$VALIDATOR" --repo-root "$REPO" "$REPO/.context/attachments/client-id/input.md"

	assert_error INPUT_PARENT_SYMLINK
}

@test "validator rejects traversal in exact-file scope" {
	write_plan "$REPO/.context/attachments/client-id/input.md" A01A TODO ../outside.txt

	run python3 "$VALIDATOR" --repo-root "$REPO" "$REPO/.context/attachments/client-id/input.md"

	assert_error SCOPE_PATH_INVALID
}

@test "validator rejects malformed duplicate metadata" {
	write_plan "$REPO/.context/attachments/client-id/input.md" A01A TODO
	python3 - "$REPO/.context/attachments/client-id/input.md" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
path.write_text(path.read_text().replace("**Status:** TODO", "**Status:** TODO **Status:** READY", 1))
PY

	run python3 "$VALIDATOR" --repo-root "$REPO" "$REPO/.context/attachments/client-id/input.md"

	assert_error METADATA_DUPLICATE
}

@test "validator rejects lifecycle state on direct attachment intake" {
	write_plan "$REPO/.context/attachments/client-id/input.md" A01A TODO
	cat >>"$REPO/.context/attachments/client-id/input.md" <<'EOF'

## Workflow State

- **Stage:** IMPLEMENTED
EOF

	run python3 "$VALIDATOR" --repo-root "$REPO" "$REPO/.context/attachments/client-id/input.md"

	assert_error ATTACHMENT_LIFECYCLE_PRESENT
}

@test "validator reports an archived status-only mismatch for skill-owned repair" {
	write_plan "$REPO/source.md" A01A TODO
	archive="$(write_archive "$REPO/source.md" READY)"
	python3 - "$archive/PR_PLAN_INDEX.md" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
path.write_text(path.read_text().replace("| `A01A` | READY |", "| `A01A` | TODO |", 1))
PY

	run python3 "$VALIDATOR" --repo-root "$REPO" "$archive/PR_PLAN_A01A_VALIDATE_PLAN_STATE.md"

	assert_error STATUS_REPAIR_REQUIRED
	[ "$(json_get error.details.verified)" = "true" ]
	[ "$(json_get error.details.plan_status)" = "READY" ]
	[ "$(json_get error.details.index_status)" = "TODO" ]
}

@test "status repair is withheld until archive source binding passes" {
	write_plan "$REPO/source.md" A01A TODO
	archive="$(write_archive "$REPO/source.md" READY)"
	python3 - "$archive/PR_PLAN_INDEX.md" "$archive/PR_PLAN_A01A_VALIDATE_PLAN_STATE.md" <<'PY'
from pathlib import Path
import sys

index = Path(sys.argv[1])
index.write_text(index.read_text().replace("| `A01A` | READY |", "| `A01A` | TODO |", 1))
plan = Path(sys.argv[2])
plan.write_text(plan.read_text().replace("- Everything else.", "- Counterfeit archive boundary.", 1))
PY

	run python3 "$VALIDATOR" --repo-root "$REPO" "$archive/PR_PLAN_A01A_VALIDATE_PLAN_STATE.md"

	assert_error ARCHIVE_SOURCE_DIVERGED
}

@test "validator proves a complete archived checkpoint without changing files" {
	write_plan "$REPO/source.md" A01A TODO
	archive="$(write_archive "$REPO/source.md" IN_PROGRESS)"
	set_id="$(basename "$(dirname "$archive")")"
	short_id="${set_id#ps-}"
	short_id="${short_id:0:16}"
	branch="plan/${short_id}-a01a-validate-plan-state"
	git -C "$REPO" switch -c "$branch" >/dev/null
	printf 'implemented\n' >"$REPO/tracked.txt"
	git -C "$REPO" add tracked.txt
	git -C "$REPO" commit -m "implement fixture" >/dev/null
	head="$(git -C "$REPO" rev-parse HEAD)"
	tree="$(git -C "$REPO" rev-parse HEAD^{tree})"
	git -C "$REPO" switch main >/dev/null
	cat >>"$archive/PR_PLAN_A01A_VALIDATE_PLAN_STATE.md" <<EOF

## Workflow State

- **Stage:** IMPLEMENTED
- **Plan set:** \`$set_id\`
- **Plan:** \`PR_PLAN_A01A_VALIDATE_PLAN_STATE.md\`
- **Branch:** \`$branch\`
- **Base commit:** \`$BASE_COMMIT\`
- **Checkpoint head:** \`$head\`
- **Checkpoint tree:** \`$tree\`
- **Scope paths:** \`tracked.txt\`
EOF
	before="$(tree_digest)"

	run python3 "$VALIDATOR" --repo-root "$REPO" "$archive/PR_PLAN_A01A_VALIDATE_PLAN_STATE.md"

	assert_success
	[ "$(json_get facts.completion_resume)" = "true" ]
	[ "$(json_get facts.checkpoint.verified)" = "true" ]
	[ "$(json_get facts.drift_check_reason)" = "checkpoint-resume" ]
	[ "$(tree_digest)" = "$before" ]
}

@test "exact-file checkpoints reject extra committed paths" {
	write_plan "$REPO/source.md" A01A TODO
	archive="$(write_archive "$REPO/source.md" IN_PROGRESS)"
	set_id="$(basename "$(dirname "$archive")")"
	short_id="${set_id#ps-}"
	short_id="${short_id:0:16}"
	branch="plan/${short_id}-a01a-validate-plan-state"
	git -C "$REPO" switch -c "$branch" >/dev/null
	printf 'implemented\n' >"$REPO/tracked.txt"
	printf 'out of scope\n' >"$REPO/extra.txt"
	git -C "$REPO" add tracked.txt extra.txt
	git -C "$REPO" commit -m "implement extra fixture" >/dev/null
	head="$(git -C "$REPO" rev-parse HEAD)"
	tree="$(git -C "$REPO" rev-parse HEAD^{tree})"
	git -C "$REPO" switch main >/dev/null
	cat >>"$archive/PR_PLAN_A01A_VALIDATE_PLAN_STATE.md" <<EOF

## Workflow State

- **Stage:** IMPLEMENTED
- **Plan set:** \`$set_id\`
- **Plan:** \`PR_PLAN_A01A_VALIDATE_PLAN_STATE.md\`
- **Branch:** \`$branch\`
- **Base commit:** \`$BASE_COMMIT\`
- **Checkpoint head:** \`$head\`
- **Checkpoint tree:** \`$tree\`
- **Scope paths:** \`tracked.txt\`
EOF

	run python3 "$VALIDATOR" --repo-root "$REPO" "$archive/PR_PLAN_A01A_VALIDATE_PLAN_STATE.md"

	assert_error CHECKPOINT_COMMITTED_SCOPE_MISMATCH
}

@test "validator accepts descendant commits for a containment checkpoint" {
	write_plan "$REPO/PR_PLAN_W01A_VALIDATE_PLAN_STATE.md" W01A TODO src
	write_root_index
	python3 - "$REPO/PR_PLAN_W01A_VALIDATE_PLAN_STATE.md" "$REPO/PR_PLAN_INDEX.md" <<'PY'
from pathlib import Path
import sys

for name in sys.argv[1:]:
    path = Path(name)
    path.write_text(path.read_text().replace(" **Scope contract:** exact files", "", 1))
PY
	run python3 "$VALIDATOR" --repo-root "$REPO" "$REPO/PR_PLAN_W01A_VALIDATE_PLAN_STATE.md"
	assert_success
	set_id="$(json_get facts.plan_set_id)"
	branch="$(json_get facts.plan_branch)"
	archive="$REPO/.context/code-plan-to-pr/$set_id/plans"
	mkdir -p "$archive"
	mv "$REPO/PR_PLAN_W01A_VALIDATE_PLAN_STATE.md" "$REPO/PR_PLAN_INDEX.md" \
		"$REPO/PR_PLAN_REJECTIONS.md" "$archive/"
	python3 - "$archive/PR_PLAN_W01A_VALIDATE_PLAN_STATE.md" "$archive/PR_PLAN_INDEX.md" <<'PY'
from pathlib import Path
import sys

for name in sys.argv[1:]:
    path = Path(name)
    path.write_text(path.read_text().replace("TODO", "IN_PROGRESS", 1))
PY
	git -C "$REPO" switch -c "$branch" >/dev/null
	mkdir -p "$REPO/src"
	printf 'implemented\n' >"$REPO/src/a.py"
	git -C "$REPO" add src/a.py
	git -C "$REPO" commit -m "implement containment fixture" >/dev/null
	head="$(git -C "$REPO" rev-parse HEAD)"
	tree="$(git -C "$REPO" rev-parse HEAD^{tree})"
	git -C "$REPO" switch main >/dev/null
	cat >>"$archive/PR_PLAN_W01A_VALIDATE_PLAN_STATE.md" <<EOF

## Workflow State

- **Stage:** IMPLEMENTED
- **Plan set:** \`$set_id\`
- **Plan:** \`PR_PLAN_W01A_VALIDATE_PLAN_STATE.md\`
- **Branch:** \`$branch\`
- **Base commit:** \`$BASE_COMMIT\`
- **Checkpoint head:** \`$head\`
- **Checkpoint tree:** \`$tree\`
- **Scope paths:** \`src\`
EOF

	run python3 "$VALIDATOR" --repo-root "$REPO" "$archive/PR_PLAN_W01A_VALIDATE_PLAN_STATE.md"

	assert_success
	[ "$(json_get facts.scope_mode)" = "containment" ]
	[ "$(json_get facts.completion_resume)" = "true" ]
}

@test "validator rejects a partial checkpoint with a stable diagnostic" {
	write_plan "$REPO/source.md" A01A TODO
	archive="$(write_archive "$REPO/source.md" IN_PROGRESS)"
	cat >>"$archive/PR_PLAN_A01A_VALIDATE_PLAN_STATE.md" <<'EOF'

## Workflow State

- **Stage:** IMPLEMENTED
- **Plan set:** `ps-deadbeef`
EOF

	run python3 "$VALIDATOR" --repo-root "$REPO" "$archive/PR_PLAN_A01A_VALIDATE_PLAN_STATE.md"

	assert_error CHECKPOINT_PARTIAL
}

@test "validator routes terminal DONE state to the retained terminal proof" {
	write_plan "$REPO/source.md" A01A TODO
	archive="$(write_archive "$REPO/source.md" DONE)"
	cat >>"$archive/PR_PLAN_A01A_VALIDATE_PLAN_STATE.md" <<'EOF'

## Workflow State

- **Stage:** COMPLETE

## Execution Result

- **Completion commit:** `0000000000000000000000000000000000000000`
EOF

	run python3 "$VALIDATOR" --repo-root "$REPO" "$archive/PR_PLAN_A01A_VALIDATE_PLAN_STATE.md"

	assert_success
	[ "$(json_get facts.terminal_retry_required)" = "true" ]
	[ "$(json_get facts.completion_resume)" = "false" ]
	[ "$(json_get facts.drift_check_reason)" = "terminal-retry" ]
	[[ "$(json_get facts.terminal_execution_result)" == *"Completion commit"* ]]
}

@test "validator rejects an execution result on an active standalone archive" {
	write_plan "$REPO/source.md" A01A TODO
	archive="$(write_archive "$REPO/source.md")"
	cat >>"$archive/PR_PLAN_A01A_VALIDATE_PLAN_STATE.md" <<'EOF'

## Execution Result

- **Completion commit:** `0000000000000000000000000000000000000000`
EOF

	run python3 "$VALIDATOR" --repo-root "$REPO" "$archive/PR_PLAN_A01A_VALIDATE_PLAN_STATE.md"

	assert_error ARCHIVE_LIFECYCLE_INVALID
}

@test "validator rejects committed and uncommitted planning drift separately" {
	write_plan "$REPO/.context/attachments/client-id/input.md" A01A TODO
	printf 'committed drift\n' >"$REPO/tracked.txt"
	git -C "$REPO" add tracked.txt
	git -C "$REPO" commit -m "drift" >/dev/null

	run python3 "$VALIDATOR" --repo-root "$REPO" "$REPO/.context/attachments/client-id/input.md"
	assert_error COMMITTED_DRIFT

	git -C "$REPO" reset --hard "$BASE_COMMIT" >/dev/null
	printf 'local drift\n' >"$REPO/tracked.txt"
	run python3 "$VALIDATOR" --repo-root "$REPO" "$REPO/.context/attachments/client-id/input.md"
	assert_error WORKTREE_DRIFT
}
