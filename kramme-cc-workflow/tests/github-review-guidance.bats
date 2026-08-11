#!/usr/bin/env bats

setup() {
	PLUGIN_ROOT="$BATS_TEST_DIRNAME/.."
	SKILL="$PLUGIN_ROOT/skills/kramme:pr:github-review/SKILL.md"
	CONVERSATION_REFERENCE="$PLUGIN_ROOT/skills/kramme:pr:github-review/references/conversation-fetch.md"
	DRAFT_REFERENCE="$PLUGIN_ROOT/skills/kramme:pr:github-review/references/draft-review.md"
	REPORT_TEMPLATE="$PLUGIN_ROOT/skills/kramme:pr:github-review/references/report-template.md"
	README="$PLUGIN_ROOT/../README.md"
}

@test "github review materializes the report before offering the pending-review write" {
	run bash -c '
    set -e
    grep -qF "[--draft-review]" "$1"
    grep -qF -- "--draft-review\` → \`CREATE_DRAFT_REVIEW=true" "$1"
    grep -qF "without asking again" "$1"
    grep -qF "Defaults: \`CREATE_DRAFT_REVIEW=false\`" "$1"
    grep -qF "## Step 11: Materialize the Markdown Report" "$1"
    grep -qF "## Step 12: Offer or Create a Pending Draft Review" "$1"
    grep -qF "the report must have been successfully written, or fully presented inline, before showing the pending-review offer or running any GitHub mutation" "$1"
    grep -qF "not created — awaiting authorization" "$1"
    grep -qF "not created — authorized; creation not attempted yet" "$1"
    grep -qF "clear the temporary pre-write sentinel with \`DRAFT_REVIEW_STATUS=\"\"\`" "$1"
    grep -qF "Draft comments are ready:" "$1"
    grep -qF "Stop and wait for the user'\''s answer" "$1"
    grep -qF "Silence or an ambiguous answer is not authorization" "$1"
    grep -qF "If the user declines" "$1"
    grep -qF "never authorizes submitting the review" "$1"
    grep -qF "Never call the submit-review endpoint" "$1"
    python3 - "$1" <<'PY'
import pathlib
import sys

text = pathlib.Path(sys.argv[1]).read_text()
materialize = text.index("## Step 11: Materialize the Markdown Report")
offer = text.index("## Step 12: Offer or Create a Pending Draft Review")
create = text.index("follow Sections 2–4")
if not materialize < offer < create:
    raise SystemExit("report materialization must precede the offer and GitHub creation flow")
PY
  ' _ "$SKILL"

	[ "$status" -eq 0 ] || { echo "$output"; false; }
}

@test "conversation fetch keeps its read-only boundary scoped to that operation" {
	run bash -c '
    grep -qF "All operations in this reference are reads" "$1"
    ! grep -qF "this skill never posts" "$1"
  ' _ "$CONVERSATION_REFERENCE"

	[ "$status" -eq 0 ] || { echo "$output"; false; }
}

@test "draft review includes all eligible comments and reports every omission" {
	run bash -c '
    set -e
    grep -qF "include Blocking, Important, Suggestions / Nits, and Questions for the Author" "$1"
    grep -qF "Use Section 1 after the draft comments are humanized" "$1"
    grep -qF "Follow Sections 2–4 only after the user authorizes the write" "$1"
    grep -qF "exclude replies to existing threads" "$1"
    grep -qF "must name every proposed item omitted" "$1"
    grep -qF "compare the validated snapshot'\''s comment count with the selected eligible count" "$1"
    grep -qF "They must match exactly" "$1"
    grep -qF "give each anchored question its own \`Draft comment\` body" "$2"
  ' _ "$DRAFT_REFERENCE" "$SKILL"

	[ "$status" -eq 0 ] || { echo "$output"; false; }
}

@test "draft review fails closed on head drift and existing pending state" {
	run bash -c '
	    set -e
	    grep -qF "if ! CURRENT_HEAD_OID=" "$1"
	    grep -qF "if [ \"\$CURRENT_HEAD_OID\" != \"\$HEAD_OID\" ]" "$1"
	    grep -qF "if ! PENDING_REVIEWS_JSON=" "$1"
	    grep -qF "pending-review lookup failed" "$1"
	    grep -qF ".state == \"PENDING\"" "$1"
	    grep -qF "No second review was created" "$1"
	    grep -qF "if ! PREWRITE_HEAD_OID=" "$1"
	    grep -qF "skip the remaining creation steps and continue to the report" "$1"
	    grep -qF "Do not delete, replace, submit, or mutate an existing pending review" "$1"
	  ' _ "$DRAFT_REFERENCE"

	[ "$status" -eq 0 ] || { echo "$output"; false; }
}

@test "draft payload omits event and verifies GitHub returned pending" {
	run python3 - "$DRAFT_REFERENCE" <<'PY'
import json
import pathlib
import re
import subprocess
import sys

text = pathlib.Path(sys.argv[1]).read_text()
for index, block in enumerate(re.findall(r"```bash\n(.*?)\n```", text, re.S), start=1):
    result = subprocess.run(["bash", "-n"], input=block, text=True, capture_output=True)
    if result.returncode:
        raise SystemExit(f"bash block {index} has invalid syntax: {result.stderr.strip()}")

payload_match = re.search(r"The payload shape is:\n\n```json\n(.*?)\n```", text, re.S)
if not payload_match:
    raise SystemExit("missing draft payload example")

payload = json.loads(payload_match.group(1).replace("<HEAD_OID>", "abc123").replace("<DRAFT_REVIEW_BODY>", "summary").replace("<humanized draft comment>", "question"))
if "event" in payload:
    raise SystemExit("draft payload must omit event")

create_blocks = [
    block
    for block in re.findall(r"```bash\n(.*?)\n```", text, re.S)
    if "DRAFT_RESPONSE=" in block
]
if len(create_blocks) != 1:
    raise SystemExit(f"expected one create-review command block, found {len(create_blocks)}")
create_block = create_blocks[0]
if '"repos/$PR_NWO/pulls/$PR_NUMBER/reviews"' not in create_block:
    raise SystemExit("create-review command must use the canonical PR_NWO route")
if (
    'printf \'%s\' "$DRAFT_PAYLOAD_JSON"' not in create_block
    or "| gh api" not in create_block
    or "--input -" not in create_block
):
    raise SystemExit("create-review command must post the validated in-memory snapshot")
if re.search(r"(?:^|\s)(?:-f|--field|--raw-field)\s+event=", create_block):
    raise SystemExit("create-review command must not add an event field")
if re.search(r"/reviews/[^\s]+/events", create_block):
    raise SystemExit("create-review command must not submit the pending review")
if create_block.index("PREWRITE_HEAD_OID") > create_block.index("DRAFT_RESPONSE="):
    raise SystemExit("final head check must happen immediately before review creation")

required = [
    '(has("event") | not)',
    'git -C "$ORIG_ROOT" check-ignore -q -- .context/github-review-drafts/',
    'DRAFT_PAYLOAD=$(mktemp "$DRAFT_DIR/pr-$PR_NUMBER.XXXXXX")',
    'DRAFT_PAYLOAD_JSON=$(jq -ce',
    '"repos/$PR_NWO/pulls/$PR_NUMBER/reviews"',
    'if [ "$DRAFT_REVIEW_STATE" != "PENDING" ]',
    'POSTWRITE_HEAD_OID=$(gh pr view',
    'DRAFT_REVIEW_STATUS="PENDING — reviewed head is stale; do not submit"',
    'DRAFT_REVIEW_STATUS="PENDING"',
    'DRAFT_REVIEW_STATUS="write outcome unknown — GitHub API request failed; inspect GitHub"',
    'Do not call `POST /repos/{owner}/{repo}/pulls/{pull_number}/reviews/{review_id}/events`',
]
missing = [item for item in required if item not in text]
if missing:
    raise SystemExit("missing pending-review safeguards: " + ", ".join(missing))
PY

	[ "$status" -eq 0 ] || { echo "$output"; false; }
}

@test "report and public docs make the draft handoff explicit" {
	run python3 - "$REPORT_TEMPLATE" "$README" "$SKILL" <<'PY'
import pathlib
import sys

report = pathlib.Path(sys.argv[1]).read_text()
readme = pathlib.Path(sys.argv[2]).read_text()
skill = pathlib.Path(sys.argv[3]).read_text()

required_report = [
    "## Draft Review",
    "Included in pending review",
    "unknown (<N> attempted)",
    "each proposed-item identifier",
    "Status: <exact DRAFT_REVIEW_STATUS>",
    "If this run created a pending review",
    "do not retry with a raw API command",
]
missing = [item for item in required_report if item not in report]
if missing:
    raise SystemExit("missing report safeguards: " + ", ".join(missing))
if 'pulls/<number>/reviews" --input' in report:
    raise SystemExit("report must not offer an unguarded create-review fallback")
if "GitHub was not changed only for statuses that confirm no write occurred" not in skill:
    raise SystemExit("skill must distinguish confirmed no-write outcomes")
if "write outcome unknown" not in skill:
    raise SystemExit("skill must report unknown write outcomes")
if "--draft-review" not in readme or "Writes the Markdown report before offering to create one unsubmitted pending GitHub review" not in readme:
    raise SystemExit("public docs must describe the draft-review flow")
PY

	[ "$status" -eq 0 ] || { echo "$output"; false; }
}
