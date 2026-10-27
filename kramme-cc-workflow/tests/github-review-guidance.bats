#!/usr/bin/env bats

setup() {
	PLUGIN_ROOT="$BATS_TEST_DIRNAME/.."
	SKILL="$PLUGIN_ROOT/skills/kramme:pr:github-review/SKILL.md"
	CONVERSATION_REFERENCE="$PLUGIN_ROOT/skills/kramme:pr:github-review/references/conversation-fetch.md"
	COMMENT_REFERENCE="$PLUGIN_ROOT/skills/kramme:pr:github-review/references/comment-drafting.md"
	DRAFT_REFERENCE="$PLUGIN_ROOT/skills/kramme:pr:github-review/references/draft-review.md"
	REPORT_TEMPLATE="$PLUGIN_ROOT/skills/kramme:pr:github-review/references/report-template.md"
	CLARITY_REFERENCE="$PLUGIN_ROOT/skills/kramme:pr:github-review/references/clarity-check.md"
	RESUME_REFERENCE="$PLUGIN_ROOT/skills/kramme:pr:github-review/references/resume.md"
	CLARITY_PROMPTS="$PLUGIN_ROOT/skills/kramme:pr:github-review/references/clarity-check-prompts.md"
	ANCHOR_SCRIPT="$PLUGIN_ROOT/skills/kramme:pr:github-review/scripts/check-comment-anchors.sh"
	SUBMIT_REFERENCE="$PLUGIN_ROOT/skills/kramme:pr:github-review/references/submit-review.md"
	SUBMIT_CHECK="$PLUGIN_ROOT/skills/kramme:pr:github-review/scripts/check-submit-confirmation.py"
	UI_REFERENCE="$PLUGIN_ROOT/skills/kramme:pr:github-review/references/ui-relevance.md"
	LINEAR_REFERENCE="$PLUGIN_ROOT/skills/kramme:pr:github-review/references/linear-review.md"
	LINEAR_AUDIT_REPORT_TEMPLATE="$PLUGIN_ROOT/skills/kramme:linear:review-pr/references/report-template.md"
	README="$PLUGIN_ROOT/../README.md"
}

@test "github review discovers linked issues from both PR lookup paths before inspection" {
	run python3 - "$SKILL" "$LINEAR_REFERENCE" <<'PY'
import pathlib
import sys

skill, reference = [pathlib.Path(path).read_text() for path in sys.argv[1:]]
lookups = [line for line in skill.splitlines() if "--json number,url,title," in line]
assert len(lookups) == 2, "current-branch and explicit PR lookups must both supply discovery context"
for line in lookups:
    fields = line.split("--json ")[1].rstrip(" \\\t)").split(",")
    assert {"body", "baseRefOid", "headRefOid", "headRefName"} <= set(fields)
discovery = skill.index("## Step 2a: Discover Linked Linear Issues")
assert skill.index("**Author guard.**") < discovery < skill.index("## Step 3:")
assert "Section 1 of `references/linear-review.md`" in skill[discovery:]
for term in ["PR_TITLE", "PR_BODY", "HEAD_REF", "case-insensitively", "deduplicate", "comment URL"]:
    assert term in reference, f"discovery must preserve {term}"
assert "independently of `--fresh`, `--include-bots`, and `--code-only`" in skill
assert "without requiring Linear MCP" in reference
PY
	[ "$status" -eq 0 ] || { echo "$output"; false; }
}

@test "Linear link discovery preserves paginated bot comments and reports lookup failure" {
	run python3 - "$LINEAR_REFERENCE" <<'PY'
import json
import os
import pathlib
import re
import subprocess
import sys

reference = pathlib.Path(sys.argv[1]).read_text()
block = re.findall(r"```bash\n(.*?)\n```", reference, re.S)[0]
pages = [[], [{"user": {"type": "Bot"}, "body": "[ENG-217](https://linear.app/acme/issue/ENG-217/export)"}]]
script = '''set -eu
gh() {
  test "$*" = "api --paginate --slurp repos/acme/repo/issues/42/comments" || exit 3
  printf '%s' "$COMMENTS_FIXTURE"
  return "$GH_RESULT"
}
''' + block + '''
printf '%s\\n%s\\n' "$LINEAR_DISCOVERY_STATUS" "$LINEAR_LINK_COMMENTS_JSON"
'''
for result in [0, 1]:
    env = dict(os.environ, PR_NWO="acme/repo", PR_NUMBER="42", GH_RESULT=str(result),
               COMMENTS_FIXTURE=json.dumps(pages), SKIP_THREADS="true", CODE_ONLY="true", INCLUDE_BOTS="false")
    probe = subprocess.run(["bash", "-c", script], env=env, text=True, capture_output=True)
    assert probe.returncode == 0, probe.stderr
    status, comments = probe.stdout.split("\n", 1)
    if result == 0:
        assert status == "complete"
        assert json.loads(comments) == pages, "link discovery must retain bot comments from later pages"
    else:
        assert status.startswith("partial"), "failed discovery cannot mean no linked issues"
        assert json.loads(comments) == []
PY
	[ "$status" -eq 0 ] || { echo "$output"; false; }
}

@test "github review audits each linked issue on the same snapshot and reconciles shared scope" {
	run python3 - "$SKILL" "$LINEAR_REFERENCE" "$LINEAR_AUDIT_REPORT_TEMPLATE" <<'PY'
import pathlib
import sys

skill, reference, audit_report = [pathlib.Path(path).read_text() for path in sys.argv[1:]]
review = skill[skill.index("## Step 6:"):skill.index("## Step 7:")]
assert '/kramme:linear:review-pr "$PR_URL" "<ISSUE-ID>"' in review
assert "separately for each in-scope issue" in review
assert "before Step 7" in review, "issue findings must participate in conversation deduplication"
for term in ["record the coverage gap rather than inventing a replacement audit", "never updates Linear", "Never run PR-head code",
             "head and base OIDs match `HEAD_OID` and `PR_BASE_OID`", "discard that result's findings",
             "`BASE_REF` commit to equal `PR_BASE_OID`", "another reviewed in-scope issue",
             "do not suppress contradictions", "ENG-217/LREQ-001", "`review-scope`"]:
    assert term in reference, f"linked-issue audit lost its {term} contract"
assert "read the sibling skill" not in skill and "read the sibling skill" not in reference
assert "**Reviewed head:**" in audit_report and "**Reviewed base:**" in audit_report, "child output must expose both snapshot OIDs for aggregation"
PY
	[ "$status" -eq 0 ] || { echo "$output"; false; }
}

@test "github review delegates only to read-only children that name it as a parent" {
	run python3 - "$SKILL" "$PLUGIN_ROOT/skills/kramme:pr:product-review/SKILL.md" "$PLUGIN_ROOT/skills/kramme:linear:review-pr/SKILL.md" <<'PY'
import pathlib
import re
import sys

skill, product, linear = [pathlib.Path(path).read_text() for path in sys.argv[1:]]
review = skill[skill.index("## Step 6:"):skill.index("## Step 7:")]
assert '/kramme:pr:code-review --base "$BASE_REF" --inline --no-diff-comments' in review
assert '/kramme:pr:product-review --base "$BASE_REF" --inline --no-diff-comments' in review
assert '/kramme:linear:review-pr "$PR_URL" "<ISSUE-ID>"' in review
assert "never reconstruct it by reading another skill's files" in review
contract = re.compile(r"(?ms)^### Model Invocation Contract\s*$(.*?)(?=^#{1,3} |\Z)")
for child in [product, linear]:
    frontmatter = child.split("---", 2)[1]
    assert "disable-model-invocation: false" in frontmatter
    section = contract.search(child).group(1)
    assert "`kramme:pr:github-review`" in section
    assert "No other parent workflow may delegate to this skill" in section
    assert set(re.findall(r"`(kramme:[^`\s]+)`", section)) == {"kramme:pr:github-review"}
product_section = contract.search(product).group(1)
assert '--base "$BASE_REF" --inline --no-diff-comments' in product_section
assert "never adds `--team`, an app URL, or `auto`" in product_section
assert "exactly two arguments" in contract.search(linear).group(1)
PY
	[ "$status" -eq 0 ] || { echo "$output"; false; }
}

@test "github review reply hands resolve-review only its guarded implement-only payload" {
	run python3 - "$PLUGIN_ROOT/skills/kramme:pr:github-review-reply/SKILL.md" "$PLUGIN_ROOT/skills/kramme:pr:resolve-review/SKILL.md" <<'PY'
import pathlib
import re
import sys

reply, resolver = [pathlib.Path(path).read_text() for path in sys.argv[1:]]
step5 = reply[reply.index("## Step 5:"):reply.index("## Step 6:")]
assert "Invoke `kramme:pr:resolve-review --implement-only` as the implementation engine" in step5
assert "Pass `--implement-only` as the only flag" in step5
assert "Do not pass the PR URL as the source argument and do not use `--source online`" in step5
assert "disable-model-invocation: false" in resolver.split("---", 2)[1]
section = re.search(r"(?ms)^### Model Invocation Contract\s*$(.*?)(?=^#{1,3} |\Z)", resolver).group(1)
for term in ["Step 5 passes exactly `--implement-only`", "`kramme:pr:review-convergence` batch remediation",
             "never in validation-only mode", "never add `--team`, `--granular`, `--source`, `--severity`, or a URL review source",
             "No other parent workflow is authorized by this model-invocation exception",
             "Under a parent delegation, never commit"]:
    assert term in section, f"resolve-review contract lost {term}"
assert set(re.findall(r"`(kramme:[^`\s]+)`", section)) == {"kramme:pr:github-review-reply", "kramme:pr:review-convergence"}
PY
	[ "$status" -eq 0 ] || { echo "$output"; false; }
}

@test "github review reports issue traceability and withholds approval for missing coverage" {
	run python3 - "$LINEAR_REFERENCE" "$REPORT_TEMPLATE" "$COMMENT_REFERENCE" "$README" <<'PY'
import pathlib
import sys

reference, report, comments, readme = [pathlib.Path(path).read_text() for path in sys.argv[1:]]
for term in ["## Linked Linear Issues", "Reviewed snapshot", "Linear requirement and citation",
             "Test evidence or gap", "Scope decisions", "Context and verification gaps"]:
    assert term in report, f"report must retain {term}"
assert "not covered — Linear MCP unavailable" in reference
assert "Missing runtime evidence alone does not prove an implementation defect" in reference
assert "Withhold `APPROVE`" in reference
assert "prevents `APPROVE`" in comments
assert "no changed-line anchor" in reference
assert "ineligible for pending inline comments" in report
assert "per-issue requirement evidence and coverage gaps" in readme
PY
	[ "$status" -eq 0 ] || { echo "$output"; false; }
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

@test "conversation states have deterministic non-overlapping precedence" {
	run python3 - "$CONVERSATION_REFERENCE" <<'PY'
import pathlib
import sys

text = pathlib.Path(sys.argv[1]).read_text()
required = [
    "applying these rules in order and stopping at the first match",
    "1. `resolved`",
    "2. `author-responded`",
    "3. `awaiting-you`",
    "4. `your-open`",
    "5. `peer-comment`",
    "6. `new-from-others`",
]
positions = [text.index(item) for item in required]
if positions != sorted(positions):
    raise SystemExit("conversation-state precedence is not deterministic")
PY

	[ "$status" -eq 0 ] || { echo "$output"; false; }
}

@test "github review progressively loads UI classification and cleans temporary parents" {
	run bash -c '
    set -e
    grep -qF "references/ui-relevance.md" "$1"
    grep -qF "references/comment-drafting.md" "$1"
    ! grep -qF "is_ui_relevant_path() {" "$1"
    ! grep -qF "Sound like a person, not a report" "$1"
    grep -qF "UI relevance path contract: \`ui-relevance-path-contract-v1\`" "$2"
    grep -qF "is_ui_relevant_path() {" "$2"
    grep -qF "rmdir \"\$TMP_PARENT\"" "$1"
    grep -qF "Temporary parent retained for inspection" "$1"
  ' _ "$SKILL" "$UI_REFERENCE"
	[ "$status" -eq 0 ] || { echo "$output"; false; }

	run bash -c '
    grep -qF "Sound like a person, not a report" "$1"
    grep -qF "give each anchored question its own \`Draft comment\` body" "$1"
    grep -qF "Send only the prose bodies" "$1"
  ' _ "$COMMENT_REFERENCE"

	[ "$status" -eq 0 ] || { echo "$output"; false; }
}

@test "github review draft comments name code outside their anchor" {
	run bash -c '
    set -e
    grep -qF "Make the comment stand on its own" "$1"
    grep -qF "name that code explicitly by file and symbol" "$1"
    grep -qF "Anchor where the fix belongs" "$1"
    grep -qF "run a cold-read check on each draft" "$1"
    grep -qF "explicit references to code outside the anchor" "$1"
    grep -qF "Identifiers and code references inside a body stay in that body" "$1"
    grep -qF "Do not send report metadata such as" "$1"
    ! grep -qF "Do not send file paths" "$1" || exit 1
    grep -qF "Name the code you actually read" "$1"
    grep -qF "  - Refers to: " "$2"
    grep -qF -- "- **Refers to** — " "$2"
    grep -qF "standalone-context rules" "$3"
  ' _ "$COMMENT_REFERENCE" "$REPORT_TEMPLATE" "$SKILL"

	[ "$status" -eq 0 ] || { echo "$output"; false; }
}

@test "github review draft comments state the problem before the ask" {
	run bash -c '
    set -e
    grep -qF "**Use the code'\''s and ticket'\''s words, not your own labels.**" "$1"
    grep -qF "**Context first, ask last.**" "$1"
    grep -qF "end with the ask as a question, in its own paragraph when more than one sentence comes before it" "$1"
    grep -qF "**Make the ask concrete.**" "$1"
    grep -qF "**Short sentences, one concern.**" "$1"
    grep -qF "Could the author tell what'\''s wrong before reaching the ask?" "$1"
    grep -qF "### Worked example" "$1"
    grep -qF "but no test checks that for a soft-deleted user" "$1"
    grep -qF "the problem stated before the ask" "$1"
    grep -qF "except a modest increase from splitting a sentence or moving the ask into its own paragraph" "$1"
    if grep -qF "Lead with a question" "$1"; then exit 1; fi
    if grep -qF "one to three sentences" "$1"; then exit 1; fi
    if grep -qF "no added length" "$1"; then exit 1; fi
    grep -qF "> <e.g. \"\`refreshSession()\` in \`auth/session.ts\` only runs on page load" "$2"
    grep -qF "> <e.g. \"\`applyDateRange()\` in \`src/reports/ReportFilters.tsx\` repeats this date-range check." "$2"
  ' _ "$COMMENT_REFERENCE" "$REPORT_TEMPLATE"

	[ "$status" -eq 0 ] || { echo "$output"; false; }
}

@test "github review draft comments claim only test results that ran" {
	run bash -c '
    set -e
    grep -qF "**Claim only what ran.**" "$1"
    grep -qF "make that change in a disposable checkout of \`HEAD_OID\`, run the affected specs, revert it, and word the claim to exactly what ran" "$1"
    grep -qF "only when it has no tracked changes and its \`HEAD\` is \`HEAD_OID\`" "$1"
    grep -qF "confirm \`git status\` shows no tracked changes" "$1"
    grep -qF "If neither can run the specs, do not claim the result" "$1"
  ' _ "$COMMENT_REFERENCE"

	[ "$status" -eq 0 ] || { echo "$output"; false; }
}

@test "github review description stays below the burndown threshold" {
	run python3 - "$SKILL" <<'PY'
import pathlib
import sys

line = pathlib.Path(sys.argv[1]).read_text().splitlines()[2]
prefix = 'description: "'
if not line.startswith(prefix) or not line.endswith('"'):
    raise SystemExit("expected a quoted one-line description")
description = line[len(prefix):-1]
if len(description) >= 500:
    raise SystemExit(f"description has {len(description)} characters; expected fewer than 500")
required = ["assigned reviewer", "GitHub PR", "inline comments", "pending review", "--draft-review", "kramme:pr:code-review", "kramme:pr:github-review-reply", "kramme:pr:resolve-review"]
missing = [term for term in required if term not in description]
if missing:
    raise SystemExit("description lost trigger terms: " + ", ".join(missing))
PY

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
    grep -qF "Do not add a top-level review \`body\` to the pending review" "$1"
    grep -qF "is empty, do not offer or create a pending review" "$1"
    grep -qF "give each anchored question its own \`Draft comment\` body" "$2"
  ' _ "$DRAFT_REFERENCE" "$COMMENT_REFERENCE"

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

@test "review worktree is created only at the verified PR head" {
	run python3 - "$SKILL" <<'PY'
import sys

text = open(sys.argv[1], encoding="utf-8").read()
fetch = text.index('git fetch --quiet origin "pull/${PR_NUMBER}/head"')
verify = text.index('FETCHED_OID=$(git rev-parse FETCH_HEAD)')
guard = text.index('if [ "$FETCHED_OID" != "$HEAD_OID" ]; then')
worktree = text.index('git worktree add --quiet --detach "$WORKTREE_DIR" "$HEAD_OID"')
if not fetch < verify < guard < worktree:
    sys.exit("head verification must sit between the fetch and the worktree creation")
if 'git worktree add --quiet --detach "$WORKTREE_DIR" FETCH_HEAD' in text:
    sys.exit("worktree must be created at the verified HEAD_OID, not FETCH_HEAD")
PY

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

payload = json.loads(payload_match.group(1).replace("<HEAD_OID>", "abc123").replace("<humanized draft comment>", "question"))
if "event" in payload:
    raise SystemExit("draft payload must omit event")
if "body" in payload:
    raise SystemExit("draft payload must omit the top-level review body")
if not payload.get("comments"):
    raise SystemExit("draft payload must contain at least one inline comment")

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
    '(has("body") | not)',
    '(.comments | (type == "array" and length > 0))',
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
if "--draft-review" not in readme or "creates one unsubmitted pending review containing only eligible inline comments" not in readme:
    raise SystemExit("public docs must describe the draft-review flow")
if "containing only eligible inline comments" not in readme:
    raise SystemExit("public docs must state that pending reviews contain only inline comments")
if "The skill does not post a review summary" not in report:
    raise SystemExit("report instructions must keep review summaries off GitHub")
if "with those comments and the summary" in skill:
    raise SystemExit("skill must not offer to post a GitHub review summary")
PY

	[ "$status" -eq 0 ] || { echo "$output"; false; }
}

@test "github review reply never replies to comments hidden as spam or abuse" {
	run bash -c '
    set -e
    grep -qF "Never draft or post a reply to a comment hidden as \`spam\` or \`abuse\`" "$1"
    grep -qF "even with \`--all\`" "$1"
    grep -qF "isMinimized" "$1"
    grep -qF "minimizedReason" "$1"
    grep -qF "| Hidden |" "$1"
  ' _ "$PLUGIN_ROOT/skills/kramme:pr:github-review-reply/SKILL.md"
	[ "$status" -eq 0 ]
}

@test "github review runs delegated reviewers in parallel unless --sequential" {
	run bash -c '
    set -e
    grep -qF "[--code-only] [--sequential] [--fresh]" "$1"
    grep -qF -- "- \`--sequential\` → \`PARALLEL_REVIEWERS=false\`" "$1"
    grep -qF -- "- \`--parallel\` → \`PARALLEL_REVIEWERS=true\`, the default." "$1"
    grep -qF "If both \`--sequential\` and \`--parallel\` are given, ask the user to pick one and stop." "$1"
    grep -qF "\`CODE_ONLY=false\`, \`PARALLEL_REVIEWERS=true\`," "$1"
    grep -qF "When \`PARALLEL_REVIEWERS=true\` (the default), append \`--parallel\` to both invocations" "$1"
    grep -qF "With \`--sequential\`, omit it" "$1"
    if grep -qF "[--parallel]" "$1"; then exit 1; fi
    grep -qF "[--code-only] [--sequential] [--fresh]" "$2"
    grep -qF "pass \`--sequential\` to run them one at a time" "$2"
  ' _ "$SKILL" "$README"
	[ "$status" -eq 0 ] || { echo "$output"; false; }
}

@test "github review reads the model policy only when an override or level is set" {
	run python3 - "$SKILL" <<'PY'
import pathlib
import sys

body = pathlib.Path(sys.argv[1]).read_text().split("---", 2)[2]
step0 = body[body.index("## Step 0: Parse Arguments"):body.index("```bash")]
for phrase in [
    "If `$ARGUMENTS` contains `--subagent-model`, or `printenv KRAMME_REVIEW_SUBAGENT_LEVEL` prints a non-empty value, first read and apply",
    "Otherwise do not read it:",
    "Keep `SUBAGENT_MODEL_OVERRIDE`, empty when the file was not read,",
]:
    assert phrase in step0, phrase
PY

	[ "$status" -eq 0 ] || { echo "$output"; false; }
}

@test "github review runs the clarity check after humanizing and before the eligibility count" {
	run python3 - "$SKILL" "$README" <<'PY'
import pathlib
import sys

skill, readme = [pathlib.Path(path).read_text() for path in sys.argv[1:]]
humanize = skill.index("## Step 10: Humanize the Draft Comments")
clarity = skill.index("## Step 10a: Check the Draft Comments With Cold Readers")
materialize = skill.index("## Step 11: Materialize the Markdown Report")
assert humanize < clarity < materialize, "the clarity check must run between humanizing and the eligibility count"
drafting = skill[skill.index("## Step 9: Draft the Review Comments"):humanize]
assert 'ANCHOR_CHECK="${CLAUDE_PLUGIN_ROOT}/skills/kramme:pr:github-review/scripts/check-comment-anchors.sh"' in drafting, \
    "the anchor check must be set before Step 10a so --no-clarity-check cannot leave it undefined for Step 11"
step = skill[clarity:materialize]
assert "ANCHOR_CHECK=" not in step
for term in [
    "references/clarity-check.md",
    "when `CLARITY_CHECK=on` and at least one is drafted",
    "when `CLARITY_CHECK=auto` and five or more are drafted",
    "`not run — --no-clarity-check`",
    "splitting a comment changes the eligible count",
    "it never writes to GitHub",
]:
    assert term in step, f"Step 10a lost {term}"
for term in [
    "[--draft-review] [--clarity-check|--no-clarity-check]",
    "- `--clarity-check` → `CLARITY_CHECK=on`",
    "- `--no-clarity-check` → `CLARITY_CHECK=off`",
    "If both clarity flags are given, ask the user to pick one and stop",
    "`CLARITY_CHECK=auto`",
]:
    assert term in skill, f"argument parsing lost {term}"
offer = skill[skill.index("## Step 12:"):skill.index("## Step 13:")]
assert "If the user asks for a clarity check, run Step 10a with `CLARITY_CHECK=on`, repeat Step 11" in offer
assert "a clarity-check request is not authorization" in offer
assert "skipped the clarity check only because fewer than five comments were drafted, add that a clarity check can run first" in offer
assert "the clarity-check status" in skill[skill.index("## Step 13:"):]
assert "[--clarity-check\\|--no-clarity-check]" in readme
assert "`--no-clarity-check` to skip it" in readme
PY
	[ "$status" -eq 0 ] || { echo "$output"; false; }
}

@test "clarity check readers are isolated, verified, and bounded" {
	run python3 - "$CLARITY_REFERENCE" "$CLARITY_PROMPTS" <<'PY'
import pathlib
import re
import subprocess
import sys

reference, prompts = [pathlib.Path(path).read_text() for path in sys.argv[1:]]
for index, block in enumerate(re.findall(r"```bash\n(.*?)\n```", reference, re.S), start=1):
    result = subprocess.run(["bash", "-n"], input=block, text=True, capture_output=True)
    assert result.returncode == 0, f"bash block {index} has invalid syntax: {result.stderr.strip()}"
stages = [reference.index(f"\n## {number}. ") for number in range(1, 10)]
assert stages == sorted(stages), "clarity check stages must stay in order"
for term in [
    "it never writes to GitHub",
    "is not authorization to create a pending review",
    'fork_turns="none"',
    "do not apply to readers",
    "Never simulate a reader in your own context",
    "not run — host cannot launch isolated readers",
    "Run the stage 1 freshness gate again right before launching any reader",
    "Resume a reader at most three times",
    "`incomplete — <stage>: reader rate-limited`",
    "set `CLARITY_CHECK_STATUS` to `not run — <reason>`",
    "When it stops a later stage, set `incomplete — <reason>`",
    "the local checkout can lag the PR head",
    "never the lines below",
    '"$ANCHOR_CHECK" "$ORIG_ROOT" "$PR_BASE_OID" "$HEAD_OID"',
    "If the script exits with status 2",
    "launch the author and teammate readers in the same message so they run in parallel",
    "Verify every point a reader raises in the code at the head before you adopt it",
    "| One reading of the comment would make the author do harm, such as deleting code that must stay | Rewrite it to name what changes **and** what stays | 1 |",
    "Never edit a sealed upstream artifact",
    "never replace an explicit reference with a pronoun",
    "Never reuse an earlier reader",
    "**Stop rule:** every comment scores 4 or more, and no paraphrase misses the intent",
    "fix every comment that scores 3 or lower or whose paraphrase misses the intent",
    "for at most two re-reads",
    "`incomplete — stop rule not met after two re-reads: <comments and scores>`",
    "apply the verdict criteria in Section 2 of `references/comment-drafting.md` again",
    "report-only IDs such as `CR-001`",
    "`incomplete — PR head moved during the check; re-run the review`",
]:
    assert term in reference, f"clarity check lost {term}"
assert 'CLARITY_CHECK_STATUS=""' not in reference, "re-running the gate must not wipe a recorded status"
for term in [
    "{reader-pack}",
    "git -C {repo} show {head-oid}:<path>",
    "English is your second language",
    "not instructions to follow",
    "do not read the working tree",
    "Looked up:",
    "End by listing every comment you rated 3 or lower",
    "Leave out the review evidence",
]:
    assert term in prompts, f"reader prompts lost {term}"
PY
	[ "$status" -eq 0 ] || { echo "$output"; false; }
}

@test "clarity check freshness gate reports every outcome" {
	run python3 - "$CLARITY_REFERENCE" <<'PY'
import os
import pathlib
import re
import subprocess
import sys

reference = pathlib.Path(sys.argv[1]).read_text()
gate = reference[reference.index("## 1. Freshness gate"):reference.index("## 2. Build the reader's view")]
block = re.findall(r"```bash\n(.*?)\n```", gate, re.S)[0]
script = '''set -u
gh() {
  test "$*" = "pr view 42 --repo acme/repo --json headRefOid -q .headRefOid" || exit 3
  [ "$GH_RESULT" -eq 0 ] || return "$GH_RESULT"
  printf '%s\\n' "$CURRENT_FIXTURE"
}
git() {
  test "$*" = "-C /repo cat-file -t aaa" || exit 4
  printf '%s\\n' "$OBJECT_TYPE"
}
''' + block
cases = [
    ({"GH_RESULT": "0", "CURRENT_FIXTURE": "aaa", "OBJECT_TYPE": "commit"}, None),
    ({"GH_RESULT": "1", "CURRENT_FIXTURE": "", "OBJECT_TYPE": "commit"}, "could not re-read the PR head"),
    ({"GH_RESULT": "0", "CURRENT_FIXTURE": "bbb", "OBJECT_TYPE": "commit"}, "the PR head moved from aaa to bbb"),
    ({"GH_RESULT": "0", "CURRENT_FIXTURE": "aaa", "OBJECT_TYPE": ""}, "is not in the local object store"),
]
for fixture, stopped in cases:
    env = dict(os.environ, PR_NUMBER="42", PR_NWO="acme/repo", HEAD_OID="aaa", ORIG_ROOT="/repo", **fixture)
    probe = subprocess.run(["bash", "-c", script], env=env, text=True, capture_output=True)
    assert probe.returncode == 0, probe.stderr
    if stopped is None:
        assert probe.stdout == "PR head unchanged: aaa\n" and probe.stderr == "", (probe.stdout, probe.stderr)
    else:
        assert probe.stdout == "", f"a stopped gate must not also report success: {probe.stdout}"
        assert probe.stderr.startswith("Clarity check stopped:") and stopped in probe.stderr, probe.stderr
PY
	[ "$status" -eq 0 ] || { echo "$output"; false; }
}

@test "comment anchor check accepts only diff lines at the reviewed head" {
	[ -x "$ANCHOR_SCRIPT" ]
	repo="$BATS_TEST_TMPDIR/anchors"
	cafe=$(printf 'caf\303\251.ts')
	git init -q "$repo"
	git -C "$repo" config user.email "test@example.com"
	git -C "$repo" config user.name "Test User"
	mkdir -p "$repo/src" "$repo/old" "$repo/new"
	seq -f 'line %g' 1 30 >"$repo/src/a.ts"
	seq -f 'name %g' 1 20 >"$repo/old/name.ts"
	seq -f 'space %g' 1 5 >"$repo/with space.ts"
	seq -f 'cafe %g' 1 5 >"$repo/$cafe"
	printf 'a();\n}\n\nc();\n{\nc();\nc();\nreturn x;\na();\n' >"$repo/algo.c"
	printf 'gone\n' >"$repo/gone.ts"
	git -C "$repo" add -A
	git -C "$repo" commit -qm base
	base=$(git -C "$repo" rev-parse HEAD)
	base_branch=$(git -C "$repo" symbolic-ref --short HEAD)

	git -C "$repo" checkout -q -b pr
	# An added line that starts with "++ " must not read as a file header.
	seq -f 'line %g' 1 30 | awk 'NR == 15 { $0 = "++ changed 15" } NR == 28 { $0 = "changed 28" } 1' >"$repo/src/a.ts"
	git -C "$repo" mv old/name.ts new/name.ts
	seq -f 'name %g' 1 20 | awk 'NR == 10 { $0 = "renamed 10" } 1' >"$repo/new/name.ts"
	seq -f 'space %g' 1 5 | awk 'NR == 3 { $0 = "space changed" } 1' >"$repo/with space.ts"
	seq -f 'cafe %g' 1 5 | awk 'NR == 3 { $0 = "cafe changed" } 1' >"$repo/$cafe"
	# Myers leaves head line 1 outside the hunk; histogram puts it inside.
	printf 'a();\n}\n\nc();\nc();\nc();\n{\na();\n' >"$repo/algo.c"
	git -C "$repo" rm -q gone.ts
	printf 'added 1\nadded 2\n' >"$repo/added.ts"
	git -C "$repo" add -A
	git -C "$repo" commit -qm head
	head=$(git -C "$repo" rev-parse HEAD)

	# The base branch moves on after the PR branched.
	git -C "$repo" checkout -q "$base_branch"
	seq -f 'line %g' 1 30 | awk 'NR == 5 { $0 = "base moved 5" } 1' >"$repo/src/a.ts"
	git -C "$repo" commit -qam "base moves on"
	base_tip=$(git -C "$repo" rev-parse HEAD)

	# Local diff settings must not change which lines count as diff lines.
	printf '#!/bin/sh\nprintf "shift\\nshift\\n"\ncat "$1"\n' >"$BATS_TEST_TMPDIR/shift-textconv"
	chmod +x "$BATS_TEST_TMPDIR/shift-textconv"
	printf '*.ts diff=shift\n' >"$repo/.git/info/attributes"
	git -C "$repo" config diff.shift.textconv "$BATS_TEST_TMPDIR/shift-textconv"
	git -C "$repo" config diff.algorithm histogram
	git -C "$repo" config diff.interHunkContext 20
	git -C "$repo" config diff.noprefix true
	git -C "$repo" config color.ui always
	export GIT_DIFF_OPTS=--unified=10

	run "$ANCHOR_SCRIPT" "$repo" "$base" "$head" src/a.ts:15 src/a.ts:12 src/a.ts:18 src/a.ts:28 \
		new/name.ts:10 added.ts:2 "with space.ts:3" "$cafe:3" algo.c:2
	[ "$status" -eq 0 ] || { echo "$output"; false; }
	[ "${lines[0]}" = "ok src/a.ts:15 ++ changed 15" ]
	[ "${lines[1]}" = "ok src/a.ts:12 line 12" ]
	[ "${lines[2]}" = "ok src/a.ts:18 line 18" ]
	[ "${lines[3]}" = "ok src/a.ts:28 changed 28" ]
	[ "${lines[4]}" = "ok new/name.ts:10 renamed 10" ]
	[ "${lines[5]}" = "ok added.ts:2 added 2" ]
	[ "${lines[6]}" = "ok with space.ts:3 space changed" ]
	[ "${lines[7]}" = "ok $cafe:3 cafe changed" ]
	[ "${lines[8]}" = "ok algo.c:2 }" ]

	run "$ANCHOR_SCRIPT" "$repo" "$base" "$head" src/a.ts:11 src/a.ts:19 new/name.ts:1 algo.c:1 gone.ts:1 src/a.ts:31
	[ "$status" -eq 1 ] || { echo "$output"; false; }
	[ "${lines[0]}" = "NOT-IN-DIFF src/a.ts:11 line 11" ]
	[ "${lines[1]}" = "NOT-IN-DIFF src/a.ts:19 line 19" ]
	[ "${lines[2]}" = "NOT-IN-DIFF new/name.ts:1 name 1" ]
	[ "${lines[3]}" = "NOT-IN-DIFF algo.c:1 a();" ]
	[ "${lines[4]}" = "NO-LINE gone.ts:1" ]
	[ "${lines[5]}" = "NO-LINE src/a.ts:31" ]

	# A base commit that moved on still yields the PR's own diff.
	run "$ANCHOR_SCRIPT" "$repo" "$base_tip" "$head" src/a.ts:5 src/a.ts:15
	[ "$status" -eq 1 ] || { echo "$output"; false; }
	[ "${lines[0]}" = "NOT-IN-DIFF src/a.ts:5 line 5" ]
	[ "${lines[1]}" = "ok src/a.ts:15 ++ changed 15" ]

	run "$ANCHOR_SCRIPT" "$repo" "$base" HEAD src/a.ts:15
	[ "$status" -eq 2 ]
	[[ "$output" == *"Expected a full commit object ID, got 'HEAD'."* ]]

	run "$ANCHOR_SCRIPT" "$repo" "$base" 0123456789abcdef0123456789abcdef01234567 src/a.ts:15
	[ "$status" -eq 2 ]
	[[ "$output" == *"Commit 0123456789abcdef0123456789abcdef01234567 is not available"* ]]

	run "$ANCHOR_SCRIPT" "$repo" "$base" "$head" src/a.ts
	[ "$status" -eq 2 ]
	[[ "$output" == *"Expected <path:line>"* ]]
}

@test "comment anchor check decodes Git-quoted filenames" {
	repo="$BATS_TEST_TMPDIR/quoted-anchors"
	git init -q "$repo"
	git -C "$repo" config user.email "test@example.com"
	git -C "$repo" config user.name "Test User"
	paths=(
		'with"quote.ts'
		'with\slash.ts'
		'with\ttab.ts'
		$'with\ttab.ts'
		$'with\nnewline.ts'
		$'with\rcarriage.ts'
		$'with\001octal.ts'
		$'with\a\b\v\fcontrols.ts'
		$'caf\303\251"quote.ts'
	)
	for path in "${paths[@]}"; do
		seq -f 'line %g' 1 12 >"$repo/$path"
	done
	git -C "$repo" add -A
	git -C "$repo" commit -qm base
	base=$(git -C "$repo" rev-parse HEAD)
	for path in "${paths[@]}"; do
		seq -f 'line %g' 1 12 | awk 'NR == 7 { $0 = "changed 7" } 1' >"$repo/$path"
	done
	git -C "$repo" add -A
	git -C "$repo" commit -qm head
	head=$(git -C "$repo" rev-parse HEAD)

	for path in "${paths[@]}"; do
		run "$ANCHOR_SCRIPT" "$repo" "$base" "$head" "$path:7" "$path:4" "$path:10"
		[ "$status" -eq 0 ] || { echo "$output"; false; }
		expected=$(printf 'ok %s:7 changed 7\nok %s:4 line 4\nok %s:10 line 10' "$path" "$path" "$path")
		[ "$output" = "$expected" ]

		run "$ANCHOR_SCRIPT" "$repo" "$base" "$head" "$path:1" "$path:13"
		[ "$status" -eq 1 ] || { echo "$output"; false; }
		expected=$(printf 'NOT-IN-DIFF %s:1 line 1\nNO-LINE %s:13' "$path" "$path")
		[ "$output" = "$expected" ]
	done
}

@test "github review reports the clarity check and keeps drafting rules for second-language readers" {
	run python3 - "$REPORT_TEMPLATE" "$COMMENT_REFERENCE" "$DRAFT_REFERENCE" <<'PY'
import pathlib
import sys

report, comments, draft = [pathlib.Path(path).read_text() for path in sys.argv[1:]]
draft_review = report[report.index("\n## Draft Review\n"):report.index("\n## Coverage Status")]
assert "- Clarity check: <exact CLARITY_CHECK_STATUS>" in draft_review
assert report.count("  - Clarity: <author>/<teammate>, then <final> | not checked\n  - Draft comment:") == 4, "every inline comment section needs a Clarity field"
assert "- **Clarity check** — " in report and "- **Clarity** — " in report
for term in [
    "GitHub shows no lines below the anchor",
    "Name the exact prop, string, or key the comment is about",
    "avoid idioms and phrasal verbs",
    "When the ask removes code, say what stays",
    "Split a comment that asks for changes in two files",
    "keep them in `Evidence`; naming the Linear issue a comment cites is fine",
    "never copy a body back from the skill's echo of its input",
]:
    assert term in comments, f"comment drafting lost {term}"
for term in [
    '`"$ANCHOR_CHECK" "$ORIG_ROOT" "$PR_BASE_OID" "$HEAD_OID" <path:line>...`',
    "GitHub rejects the whole create-review request when a single comment is outside the diff",
    "Exclude each `NOT-IN-DIFF` or `NO-LINE` anchor",
]:
    assert term in draft, f"draft review selection lost {term}"
PY
	[ "$status" -eq 0 ] || { echo "$output"; false; }
}

@test "submit confirmation checker accepts only a post action naming the PR and one event" {
	run python3 - "$SUBMIT_CHECK" <<'PY'
import subprocess
import sys

checker = sys.argv[1]
accepted = {
    "Post the prepared review to PR 8683 as request changes": "REQUEST_CHANGES",
    "post the prepared review to pull request #8683 as requesting changes.": "REQUEST_CHANGES",
    "Submit the prepared review to #8683 as a comment": "COMMENT",
    "Publish the prepared review to https://github.com/acme/repo/pull/8683 as approve": "APPROVE",
    "Publish the prepared review to https://github.com/Acme/repo/pull/8683 as approve": "APPROVE",
}
refused = [
    "",
    "review this PR",
    "Review PR 8683",
    "Review PR 8683 and post the review as request changes",
    "$kramme:pr:github-review 8683",
    "/kramme:pr:github-review https://github.com/acme/repo/pull/8683 --draft-review",
    "$kramme:pr:github-review 8683, then post the prepared review to PR 8683 as request changes",
    "yes",
    "Looks good, go ahead",
    "Request changes",
    "Post the prepared review to PR 8683",
    "Post the prepared review to PR 8683 as approve or request changes",
    "Post the prepared review to PR 8684 as request changes",
    "Post the prepared review to https://github.com/other/repo/pull/8683 as approve",
    "Post the prepared review to PR 8683 and PR 8684 as request changes",
    "Post the prepared review as request changes",
    "Should I post the prepared review to PR 8683 as request changes?",
    "Don't post the prepared review to PR 8683 as request changes",
    "Post the prepared review to PR 8683 as request changes if CI passes",
    "Wait, then post the prepared review to PR 8683 as request changes",
    "I cannot post the prepared review to PR 8683 as request changes",
    "I refuse to post the prepared review to PR 8683 as request changes",
    "I am refusing to post the prepared review to PR 8683 as request changes",
    "Don’t post the prepared review to PR 8683 as request changes",
]

def check(message):
    return subprocess.run(["python3", checker, "--pr", "8683", "--repo", "acme/repo"], input=message, text=True, capture_output=True)

for message, event in accepted.items():
    result = check(message)
    assert result.returncode == 0 and result.stdout == event + "\n", (message, result.stdout, result.stderr)
for message in refused:
    result = check(message)
    assert result.returncode == 1 and result.stdout == "", (message, result.stdout)
    assert "Post the prepared review to PR 8683 as request changes" in result.stderr, "refusals must show the phrase to send"
usage = subprocess.run(["python3", checker, "--pr", "main", "--repo", "acme/repo"], input="x", text=True, capture_output=True)
assert usage.returncode == 2
PY
	[ "$status" -eq 0 ] || { echo "$output"; false; }
}

@test "a review command makes no GitHub mutation until the user confirms the exact submission" {
	run python3 - "$SUBMIT_REFERENCE" "$SUBMIT_CHECK" <<'PY'
import json
import os
import pathlib
import re
import subprocess
import sys
import tempfile

reference, checker = pathlib.Path(sys.argv[1]).read_text(), sys.argv[2]
blocks = re.findall(r"```bash\n(.*?)\n```", reference, re.S)
assert len(blocks) == 3, "expected the check, request, and submit blocks"
procedure = "\n".join(blocks)
assert "<the user's confirmation message, verbatim>" not in procedure
assert 'python3 "$SUBMIT_CHECK" --pr "$PR_NUMBER" --repo "$PR_NWO" < "$CONFIRMATION_FILE"' in procedure
assert "<<" not in procedure

HEAD = "a" * 40
GH = r"""#!/usr/bin/env bash
input=""
if [ "$1" = "api" ] && [ "$2" = "-X" ]; then input=$(cat); fi
jq -cn --arg args "$*" --arg input "$input" '{args: $args, input: $input}' >> "$GH_LOG"
case "$*" in
  "pr view 8683 --repo acme/repo --json headRefOid -q .headRefOid") printf '%s\n' "$GH_HEAD" ;;
  "api --paginate --slurp repos/acme/repo/pulls/8683/reviews") printf '%s' "$GH_REVIEWS" ;;
  "api -X POST "*) printf '{"id": 91, "state": "%s", "html_url": "https://github.com/acme/repo/pull/8683#pullrequestreview-91"}' "$GH_STATE" ;;
  *) echo "unexpected gh call: $*" >&2; exit 9 ;;
esac
"""

def run(message, draft_status="not created — awaiting authorization", draft_id="", head=HEAD, reviews="[[]]", state="CHANGES_REQUESTED", submit_status="not submitted — awaiting confirmation"):
    with tempfile.TemporaryDirectory() as tmp:
        bin_dir = pathlib.Path(tmp, "bin")
        bin_dir.mkdir()
        gh = bin_dir / "gh"
        gh.write_text(GH)
        gh.chmod(0o755)
        log = pathlib.Path(tmp, "gh.log")
        log.touch()
        confirmation = pathlib.Path(tmp, "confirmation.txt")
        confirmation.write_text(message)
        confirmation.chmod(0o600)
        script = "set -u\n" + procedure + '\nprintf "%s" "$SUBMIT_STATUS"\n'
        env = dict(
            os.environ,
            PATH=f"{bin_dir}:{os.environ['PATH']}",
            GH_LOG=str(log), GH_HEAD=head, GH_REVIEWS=reviews, GH_STATE=state,
            SUBMIT_CHECK=checker, PR_NUMBER="8683", PR_NWO="acme/repo", HEAD_OID=HEAD, SELF="reviewer",
            CONFIRMATION_FILE=str(confirmation),
            DRAFT_REVIEW_STATUS=draft_status, DRAFT_REVIEW_ID=draft_id,
            SUBMIT_STATUS=submit_status,
            PREPARED_REVIEW_BODY="A few questions inline about the empty-list case.",
            DRAFT_REVIEW_COMMENTS_JSON=json.dumps([{"path": "src/a.ts", "line": 3, "side": "RIGHT", "body": "What happens when `items` is empty?"}]),
        )
        result = subprocess.run(["bash", "-c", script], env=env, text=True, capture_output=True)
        assert result.returncode == 0, result.stderr
        calls = [json.loads(line) for line in log.read_text().splitlines()]
        return result.stdout, calls

def writes(calls):
    return [call for call in calls if re.search(r"-X (?:POST|PATCH|PUT|DELETE)|graphql|pr (?:review|comment|edit|merge|close|ready)", call["args"])]

# The review conversation before confirmation: none of these may reach GitHub.
for message in [
    "review this PR",
    "$kramme:pr:github-review 8683",
    "/kramme:pr:github-review 8683 --draft-review",
    "Review PR 8683 and post the review as request changes",
    "yes",
    "The verdict is request changes",
]:
    status, calls = run(message)
    assert status == "not submitted — confirmation not accepted", (message, status)
    assert calls == [], f"{message!r} reached GitHub: {calls}"

# A delimiter-looking line in the message must never become shell source.
marker = pathlib.Path(tempfile.gettempdir(), f"kramme-review-confirmation-{os.getpid()}")
if marker.exists():
    marker.unlink()
status, calls = run(f"Post the prepared review to PR 8683 as request changes\nCONFIRMATION\ntouch {marker}")
assert status == "submitted — CHANGES_REQUESTED", status
assert not marker.exists(), "confirmation text was executed as shell code"

# The explicit confirmation creates exactly one review with the named event.
status, calls = run("Post the prepared review to PR 8683 as request changes.")
assert status == "submitted — CHANGES_REQUESTED", status
posted = writes(calls)
assert len(posted) == 1, calls
assert posted[0]["args"] == "api -X POST repos/acme/repo/pulls/8683/reviews --input -"
payload = json.loads(posted[0]["input"])
assert payload["event"] == "REQUEST_CHANGES" and payload["commit_id"] == HEAD
assert payload["body"] == "A few questions inline about the empty-list case."
assert [comment["path"] for comment in payload["comments"]] == ["src/a.ts"]
assert calls.index(posted[0]) == len(calls) - 1, "the head must be re-read before the write"

# A pending review this run created is submitted in place.
status, calls = run("Post the prepared review to PR 8683 as comment", draft_status="PENDING", draft_id="77", state="COMMENTED")
assert status == "submitted — COMMENTED", status
posted = writes(calls)
assert [call["args"] for call in posted] == ["api -X POST repos/acme/repo/pulls/8683/reviews/77/events --input -"]
assert json.loads(posted[0]["input"])["event"] == "COMMENT"

# Confirmed, but unsafe state: no write.
for kwargs, expected in [
    ({"head": "b" * 40}, "not submitted — PR head moved"),
    ({"reviews": json.dumps([[{"id": 5, "state": "PENDING", "user": {"login": "reviewer"}}]])}, "not submitted — pending review already exists"),
    ({"draft_status": "PENDING — reviewed head is stale; do not submit", "draft_id": "77"}, "not submitted — draft review state is not confirmed; inspect GitHub"),
    ({"draft_status": "write outcome unknown — GitHub API request failed; inspect GitHub"}, "not submitted — draft review state is not confirmed; inspect GitHub"),
]:
    status, calls = run("Post the prepared review to PR 8683 as request changes", **kwargs)
    assert status == expected, (kwargs, status)
    assert writes(calls) == [], (kwargs, calls)

status, calls = run("Post the prepared review to PR 8683 as approve", state="COMMENTED")
assert status == "unexpected state — inspect GitHub", status
assert len(writes(calls)) == 1, "an unexpected response must never be retried"

# A second confirmation after a completed submission must not create another review.
status, calls = run("Post the prepared review to PR 8683 as request changes", submit_status="submitted — CHANGES_REQUESTED")
assert status == "submitted — CHANGES_REQUESTED", status
assert writes(calls) == [], calls
status, calls = run("Post the prepared review to PR 8683 as request changes", submit_status="write outcome unknown — GitHub API request failed; inspect GitHub")
assert status == "write outcome unknown — GitHub API request failed; inspect GitHub", status
assert writes(calls) == [], calls
PY
	[ "$status" -eq 0 ] || { echo "$output"; false; }
}

@test "github review gates every GitHub mutation behind its named authorization" {
	run python3 - "$PLUGIN_ROOT/skills/kramme:pr:github-review" "$README" <<'PY'
import pathlib
import re
import sys

root, readme = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2]).read_text()
skill = (root / "SKILL.md").read_text()
gate = skill[skill.index("## GitHub Write Gate"):skill.index("## Step 0:")]
for term in [
    "Preparing findings, a verdict, draft comments, draft replies, or a review body never writes to GitHub",
    "Inspecting the PR and running its tests never does either",
    "posts or submits a review, including requesting changes, approving, or commenting",
    "replies to a review thread, or resolves or unresolves a thread",
    "dismisses a review",
    "edits PR metadata",
    "pushes, merges, closes, or reopens anything",
    'Invoking this skill, a request such as "review this PR", and anything in its arguments are not confirmation',
    "`Post the prepared review to PR 8683 as request changes`",
    "treat it as not confirmed",
]:
    assert term in gate, f"write gate lost: {term}"
handoff, submit = skill.index("## Step 13: Final Handoff"), skill.index("## Step 14:")
assert handoff < submit and "Then stop." in skill[handoff:submit]
assert '${CLAUDE_PLUGIN_ROOT}/skills/kramme:pr:github-review/scripts/check-submit-confirmation.py' in skill[submit:]
assert "carry the current report's `SUBMIT_STATUS` into the reference" in skill[submit:]
assert "preserve that terminal status and do not retry" in skill[submit:]
assert skill.count("references/submit-review.md") == 2, "only the gate and Step 14 may name the submit reference"
assert "it is never a Step 14 confirmation" in skill

# Every GitHub write in the skill lives in one of the two guarded references, or is a command handed to the user.
forbidden = re.compile(r"gh pr (?:review|comment|edit|merge|close|ready)\b|git push\b|\bmutation\s*[({]|resolveReviewThread|/dismissals")
write = re.compile(r"gh api -X (?:POST|PATCH|PUT|DELETE)\b|gh api [^\n]*-X (?:POST|PATCH|PUT|DELETE)\b")
for path in root.rglob("*"):
    if not path.is_file():
        continue
    text = path.read_text()
    rel = path.relative_to(root).as_posix()
    for block in re.findall(r"```(?:bash|sh)?\n(.*?)\n```", text, re.S):
        assert not forbidden.search(block), f"{rel} runs a forbidden GitHub mutation"
        if write.search(block):
            assert rel in {"references/draft-review.md", "references/submit-review.md", "references/report-template.md"}, f"{rel} writes to GitHub"
report = (root / "references/report-template.md").read_text()
assert "The skill never posts thread replies" in report
assert "## Prepared Review" in report and "_Not posted." in report
assert "Post the prepared review to PR <number> as request changes" in report
assert "Report-only by default" in skill.split("---", 2)[1]
assert "`pr:github-review` is report-only by default" in readme
PY
	[ "$status" -eq 0 ] || { echo "$output"; false; }
}

@test "github review resumes an interrupted run from saved step results" {
	run python3 - "$SKILL" "$RESUME_REFERENCE" "$CLARITY_REFERENCE" <<'PY'
import pathlib
import re
import sys

skill, resume, clarity = [pathlib.Path(path).read_text() for path in sys.argv[1:]]
assert "${CLAUDE_PLUGIN_ROOT}/shared/agents/references/resumable-fanout.md" in skill
entry = skill.index("## Step 2b: Resume an Interrupted Run")
assert skill.index("## Step 2a:") < entry < skill.index("## Step 3:"), "resume must be decided before the worktree exists"
assert "references/resume.md" in skill[entry:skill.index("## Step 3:")]
for step, following in [("## Step 6:", "## Step 7:"), ("## Step 7:", "## Step 8:"), ("## Step 9:", "## Step 10:"),
                        ("## Step 10:", "## Step 10a:"), ("## Step 10a:", "## Step 11:")]:
    body = skill[skill.index(step):skill.index(following)]
    assert re.search(r"Save (this step's result|each pass's result|each completed stage)", body), f"{step} must save its result"
assert "retire its directory per `references/resume.md`" in skill[skill.index("## Step 13:"):]
assert ".context/pr-github-review/<run-id>/" in skill[skill.index("## Artifact Lifecycle"):]

for phrase in ["git -C \"$ORIG_ROOT\" check-ignore -q -- .context/pr-github-review/", "resume is off for this run",
               "`head` (`HEAD_OID`)", "`base` (`PR_BASE_OID`)", "`base_ref` (`BASE_REF_ARG`)",
               "`skip_threads` (the normalized `--fresh` behavior)", "`pr_context` (a SHA-256 of canonical `{title,body}` JSON)",
               "`linked_issues` (the sorted issue IDs discovered in Step 2a)", "SUBAGENT_MODEL_LEVEL", "active orchestrator model identity",
               "Leave out `--draft-review`, `--inline`, `--keep-worktree`, `--sequential`, and `--parallel`",
               "ensure the head object exists locally", "git cat-file -e \"$HEAD_OID^{commit}\"", "git fetch --quiet origin \"pull/${PR_NUMBER}/head\"",
               "The title/body hash and linked-issue IDs prevent a resume from reusing passes after those inputs change.",
               "Step 7 always runs on resume", "a saved `conversation` result is audit evidence only, never a reusable result",
               "A moved PR head changes `head`, which makes the old run stale.",
               "`clarity-v2`", "`clarity-author`, `clarity-teammate`", "`clarity-v3`", "`clarity-confirm-<n>`", "`clarity-outcome`",
               "never pass the run directory or any result file to a clarity reader",
               "detached at `HEAD_OID`", "in a new worktree it starts fresh",
               "existing-pending-review guard keeps a resumed run from creating a second pending review",
               "consider only runs for the same `repo` and `pr`",
               "After Step 13, set the manifest `status` to `complete`", "Never use `rm -rf`.",
               "`Agents reused: <M> (run <run-id>)`", "`--fresh` is a separate normalized run input (`skip_threads=true`)"]:
    assert phrase in resume, f"resume reference must state: {phrase}"

assert resume.index('git cat-file -e "$HEAD_OID^{commit}"') < resume.index("Build the key JSON"), "head fetch must precede key computation"

for phrase in ["run the stage 1 gate first, then start at the first stage without a saved result",
               "relaunched as a new reader with the saved filled prompt",
               "a confirmation read always uses a new reader",
               "Readers never receive the run directory or any saved result"]:
    assert phrase in clarity, f"clarity check must state: {phrase}"
PY
	[ "$status" -eq 0 ] || { echo "$output"; false; }
}
