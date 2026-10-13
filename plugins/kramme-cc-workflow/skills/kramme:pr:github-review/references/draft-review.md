# Creating one pending GitHub review with inline comments only

Use Section 1 after the draft comments are humanized so the skill can make an exact offer. Follow Sections 2–4 only after the user authorizes the write, either by passing `--draft-review` or by clearly accepting the offer. That authorization covers one write: creating an unsubmitted pending review containing only direct inline comments for the reviewed head. It does not authorize a top-level review body, replies, thread resolution, review submission, approval, or change requests.

## 1. Select the proposed comments

Build `DRAFT_REVIEW_COMMENTS` from every fresh actionable item that has a concrete head-side diff anchor and a `Draft comment` body after humanization:

- include Blocking, Important, Suggestions / Nits, and Questions for the Author;
- exclude Strengths, Already Raised, Pre-existing / Out of Scope, and anything marked `NOTICED BUT NOT TOUCHING`;
- exclude `review-scope`, file-only, ambiguous, or non-diff locations that GitHub cannot anchor;
- exclude replies to existing threads. The create-review endpoint cannot add those replies to the new pending review; keep them in the report's Open Conversation section for separate manual action.

For each included item, record `path`, integer `line`, `side: "RIGHT"`, and the exact humanized `body`. The report must name every proposed item omitted from the pending review and why. Never silently claim that all comments were included when any item was omitted.

Do not build or post a top-level review `body`. Keep the recommended verdict rationale, Strengths, and all other summary material in the local report only. If `DRAFT_REVIEW_COMMENTS` is empty, do not offer or create a pending review; use `DRAFT_REVIEW_STATUS="not created — no eligible inline comments"`.

## 2. Fail closed on stale or conflicting state

Re-read the current PR head immediately before the write:

```bash
if ! CURRENT_HEAD_OID=$(gh pr view "$PR_NUMBER" --repo "$PR_NWO" --json headRefOid -q .headRefOid); then
  echo "Could not re-read the PR head; no draft review was created. Check GitHub access and retry." >&2
  DRAFT_REVIEW_STATUS="not created — could not read PR head"
elif [ "$CURRENT_HEAD_OID" != "$HEAD_OID" ]; then
  echo "The PR head moved from $HEAD_OID to $CURRENT_HEAD_OID; no draft review was created. Re-run the review against the new head." >&2
  DRAFT_REVIEW_STATUS="not created — PR head moved"
fi
```

When the guard sets `DRAFT_REVIEW_STATUS`, skip the remaining creation steps and continue to the report. Preserve the completed findings even though the GitHub write was blocked.

Check whether this reviewer already owns a pending review:

```bash
if ! PENDING_REVIEWS_JSON=$(gh api --paginate --slurp \
  "repos/$PR_NWO/pulls/$PR_NUMBER/reviews"); then
  echo "Could not check for an existing pending review; no draft review was created. Check GitHub access and retry." >&2
  DRAFT_REVIEW_STATUS="not created — pending-review lookup failed"
elif ! PENDING_REVIEW_IDS=$(printf '%s' "$PENDING_REVIEWS_JSON" \
  | jq -r --arg self "$SELF" '.[][] | select(.user.login == $self and .state == "PENDING") | .id'); then
  echo "GitHub returned an invalid pending-review response; no draft review was created." >&2
  DRAFT_REVIEW_STATUS="not created — pending-review response invalid"
elif [ -n "$PENDING_REVIEW_IDS" ]; then
  echo "You already have a pending review on this PR (review ID(s): $PENDING_REVIEW_IDS). No second review was created. Open the existing draft in GitHub, or submit/delete it before re-running with --draft-review." >&2
  DRAFT_REVIEW_STATUS="not created — pending review already exists"
fi
```

When the guard sets `DRAFT_REVIEW_STATUS`, skip the remaining creation steps and continue to the report. Do not delete, replace, submit, or mutate an existing pending review.

## 3. Build and validate the payload

Create `.context/github-review-drafts/` under `ORIG_ROOT`, verify that exact directory is Git-ignored, then allocate one run-unique payload file inside it. Do not assume a Conductor or installation-local exclude exists in the consumer repository. If the directory is not ignored, ask for a safe ignored location or explicit permission to update the repository's ignore rules; the pending-review authorization does not authorize an ignore-rule change.

```bash
DRAFT_DIR="$ORIG_ROOT/.context/github-review-drafts"

if ! mkdir -p "$DRAFT_DIR"; then
  echo "Could not create the draft-review payload directory; no draft review was created." >&2
  DRAFT_REVIEW_STATUS="not created — payload directory creation failed"
elif git -C "$ORIG_ROOT" check-ignore -q -- .context/github-review-drafts/; then
  :
else
  CHECK_IGNORE_STATUS=$?
  if [ "$CHECK_IGNORE_STATUS" -eq 1 ]; then
    echo "MISSING REQUIREMENT: .context/github-review-drafts/ is not gitignored; no draft review was created." >&2
    DRAFT_REVIEW_STATUS="not created — payload directory is not gitignored"
  else
    echo "Could not validate whether .context/github-review-drafts/ is ignored (status $CHECK_IGNORE_STATUS); no draft review was created." >&2
    DRAFT_REVIEW_STATUS="not created — payload ignore check failed"
  fi
fi

if [ -z "${DRAFT_REVIEW_STATUS:-}" ] && ! DRAFT_PAYLOAD=$(mktemp "$DRAFT_DIR/pr-$PR_NUMBER.XXXXXX"); then
  echo "Could not allocate a unique draft-review payload; no draft review was created." >&2
  DRAFT_REVIEW_STATUS="not created — payload allocation failed"
fi
```

When this guard sets `DRAFT_REVIEW_STATUS`, skip serialization and the remaining creation steps, then continue to the report. Otherwise serialize the exact payload to `DRAFT_PAYLOAD`. Use a structured JSON writer or `jq`; never interpolate comment bodies into handwritten shell JSON. `mktemp` gives concurrent same-PR runs separate files and creates the retained payload with restrictive permissions.

The payload shape is:

```json
{
  "commit_id": "<HEAD_OID>",
  "comments": [
    {
      "path": "src/example.ts",
      "line": 42,
      "side": "RIGHT",
      "body": "<humanized draft comment>"
    }
  ]
}
```

The payload must omit both the top-level `body` and `event`, and the `comments` array must contain at least one eligible inline comment. An absent event is what makes the review pending. Validate before posting:

```bash
if ! DRAFT_PAYLOAD_JSON=$(jq -ce --arg head "$HEAD_OID" '
  select(
    type == "object" and
    (has("event") | not) and
    (has("body") | not) and
    .commit_id == $head and
    (.comments | (type == "array" and length > 0)) and
    all(.comments[];
      (.path | type == "string" and length > 0) and
      (.line | type == "number" and floor == . and . > 0) and
      .side == "RIGHT" and
      (.body | type == "string" and length > 0)
    )
  )
' "$DRAFT_PAYLOAD"); then
  DRAFT_REVIEW_STATUS="not created — payload validation failed"
fi
```

`DRAFT_PAYLOAD_JSON` is the exact validated snapshot used for the write; do not reopen the retained file during the POST. If validation fails, retain the payload, skip the GitHub write, and continue to the report. Before posting, compare the validated snapshot's comment count with the selected eligible count. They must match exactly. A mismatch gets the same fail-closed treatment and must be stated in the report.

## 4. Create, but never submit, the review

Re-read the head once more after payload validation, directly before the POST. This closes the interval spent checking pending reviews and building the payload; never create a review for a head that moved during that work.

```bash
if ! PREWRITE_HEAD_OID=$(gh pr view "$PR_NUMBER" --repo "$PR_NWO" --json headRefOid -q .headRefOid); then
  echo "Could not perform the final PR-head check; no draft review was created. Check GitHub access and retry." >&2
  DRAFT_REVIEW_STATUS="not created — final PR-head check failed"
elif [ "$PREWRITE_HEAD_OID" != "$HEAD_OID" ]; then
  echo "The PR head moved from $HEAD_OID to $PREWRITE_HEAD_OID; no draft review was created. Re-run the review against the new head." >&2
  DRAFT_REVIEW_STATUS="not created — PR head moved"
elif ! DRAFT_RESPONSE=$(printf '%s' "$DRAFT_PAYLOAD_JSON" \
  | gh api -X POST "repos/$PR_NWO/pulls/$PR_NUMBER/reviews" --input -); then
  DRAFT_REVIEW_STATUS="write outcome unknown — GitHub API request failed; inspect GitHub"
fi
```

If either final head guard sets `DRAFT_REVIEW_STATUS`, skip the POST and continue to the report. If the API request fails, retain the payload, skip response parsing, and continue with the outcome-unknown status: the server may have accepted the write before the client observed the failure. Do not retry until the reviewer inspects GitHub for an existing pending review. Otherwise validate the response:

```bash
DRAFT_REVIEW_STATE=$(printf '%s' "$DRAFT_RESPONSE" | jq -r '.state')
DRAFT_REVIEW_ID=$(printf '%s' "$DRAFT_RESPONSE" | jq -r '.id')
DRAFT_REVIEW_URL=$(printf '%s' "$DRAFT_RESPONSE" | jq -r '.html_url // empty')

if [ "$DRAFT_REVIEW_STATE" != "PENDING" ]; then
  echo "GitHub returned unexpected review state '$DRAFT_REVIEW_STATE' for review $DRAFT_REVIEW_ID. Do not perform another write; inspect the PR in GitHub." >&2
  DRAFT_REVIEW_STATUS="unexpected state — inspect GitHub"
elif ! POSTWRITE_HEAD_OID=$(gh pr view "$PR_NUMBER" --repo "$PR_NWO" --json headRefOid -q .headRefOid); then
  echo "Pending review $DRAFT_REVIEW_ID was created, but the PR head could not be re-read. Inspect the review and current head before submitting." >&2
  DRAFT_REVIEW_STATUS="PENDING — current head could not be verified; inspect GitHub"
elif [ "$POSTWRITE_HEAD_OID" != "$HEAD_OID" ]; then
  echo "Pending review $DRAFT_REVIEW_ID targets $HEAD_OID, but the PR head is now $POSTWRITE_HEAD_OID. Do not submit this stale review; inspect GitHub and re-run against the new head." >&2
  DRAFT_REVIEW_STATUS="PENDING — reviewed head is stale; do not submit"
else
  DRAFT_REVIEW_STATUS="PENDING"
fi
```

Do not call `POST /repos/{owner}/{repo}/pulls/{pull_number}/reviews/{review_id}/events`. That endpoint submits the pending review and is always outside this skill's authority.

Report the review ID, URL, retained run-unique payload path, and omitted-item count. Report an exact included comment count only when the response proves a pending review was created; report `0` for confirmed no-write outcomes and `unknown (<N> attempted)` for outcome-unknown or unexpected-state outcomes. Tell the user to inspect and edit the pending review's inline comments in GitHub before choosing Approve, Comment, or Request changes. If the post-write head check marked the review stale or unverifiable, tell the user not to submit it.
