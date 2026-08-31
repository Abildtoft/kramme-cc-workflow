# Output template: GITHUB_PR_REVIEW_OVERVIEW.md

Use this structure verbatim when writing `GITHUB_PR_REVIEW_OVERVIEW.md` (or the inline reply with `--inline`). Include every required section even if empty — emit `(0 found)` rather than omitting it. The only conditional section is `## Coverage Status` (only when a dimension failed or was skipped). Always include `## Draft Review` and `## Manual posting` so the reviewer can see exactly what changed on GitHub and what remains to do. The skill materializes this report before it offers or attempts a pending-review write, then refreshes the report after the user declines or an authorized attempt finishes.

The report is written for the reviewer to act on. Findings are framed for the PR author, in reviewer voice.

````markdown
# GitHub PR Review — <title> (#<number>)

- PR: <url>
- Author: @<author>
- Branch: <head-ref> → <base-branch>
- Reviewed head: <head-oid (short)>
- Files changed: <n> (+<additions> / -<deletions>)
- Dimensions run: code<, ux/visual/a11y/product> | code only
- Current GitHub review decision: <reviewDecision or "none">
- Your last review: <APPROVED | CHANGES_REQUESTED | COMMENTED | none>
- Conversation: <N open threads, M awaiting you> | none yet (first pass)
- Draft review: <exact DRAFT_REVIEW_STATUS; include review ID/counts when available>

## Recommended Verdict: REQUEST CHANGES | COMMENT | APPROVE

<one or two sentences of rationale tied to the findings below>

_You make the final call. A pending draft, when requested, remains unsubmitted until you choose a verdict in GitHub._

## Draft Review

- Status: <exact DRAFT_REVIEW_STATUS>
- Review: <review URL and ID | —>
- Proposed inline comments: <N eligible>
- Included in pending review: <N when creation is confirmed | 0 for confirmed no-write | unknown (<N> attempted) for unknown/unexpected outcomes>
- Omitted: <N — list each proposed-item identifier and reason, using `path:line` when available, or "none">
- Payload: <run-unique `.context/github-review-drafts/pr-<number>.<suffix>` | —>
- Next action: <authorize or decline pending-review creation | continue the already-authorized guarded creation flow | inspect/edit the pending review in GitHub, then submit it manually | create the declined draft later by re-running with `--draft-review` | resolve the stated no-write blocker and retry | inspect GitHub without retrying after an unknown/unexpected write outcome>

## Coverage Status (omit when complete)

<dimension> not covered: <reason — e.g. ux-review agent failed, app not running, --code-only>.

## Open Conversation (X threads, Y awaiting you)

_Existing threads on this PR. Reply where it moves the review forward; the rest are surfaced for awareness. Omit this section on a clean first pass with no activity._

- @<latest-commenter> on `path/to/file.ts:123` — **<awaiting-you | author-responded | peer-comment | your-open | new-from-others>**
  - Thread: <url>
  - Root comment ID: <id, for the reply command>
  - Latest: @<who>: "<short quote or paraphrase>"
  - Verified (live tree): addressed | still-open | cant-tell — <what you saw in the current code>
  - Cross-ref: <`path:line` of the related fresh finding, or "—">
  - Humanized: yes|no
  - Draft reply:
    > <human-voiced reply leading with your decision, grounded in what you read — e.g. "Looks like the empty-list case is handled now with the guard on line 88 — happy to resolve this." — or "(surfaced for awareness — no reply needed)">

## Blocking (must fix before merge) (X found)

- **Blocking:** <what is wrong and why it blocks merge>
  - Location: `path/to/file.ts:123`
  - Evidence: <traced behavior, failing path, or UNVERIFIED reason>
  - Humanized: yes|no
  - Draft comment:
    > <concise, calibrated, Socratic — e.g. "If `rows` comes back empty, does this still resolve, or does the `.then` chain hang? Couldn't trace it from the diff.">

## Important (should fix) (X found)

- **Important:** <what should change>
  - Location: `path/to/file.ts:123`
  - Evidence: <concrete reason>
  - Humanized: yes|no
  - Draft comment:
    > <e.g. "Is there a reason the token isn't refreshed before this call? Looks like it could be expired by the time we reach here.">

## Suggestions / Nits (X found)

- **Nit:** <optional improvement>
  - Location: `path/to/file.ts:123`
  - Humanized: yes|no
  - Draft comment:
    > <e.g. "Would pulling this into a named helper make the intent clearer? Up to you.">

## Questions for the Author (X found)

- **Question:** <what needs the author's intent before you can judge it>
  - Location: `path/to/file.ts:123`
  - Humanized: yes|no
  - Draft comment:
    > <e.g. "Is this meant to preserve the previous fallback behavior, or should a missing value fail here now?">

## Strengths (X found)

- <what this PR does well — retained in this local report, not posted as a GitHub review body>

## Already Raised in the Conversation (X found)

_Fresh findings suppressed because the conversation already covers them — listed so you don't re-post duplicates._

- `path/to/file.ts:123` — <finding> — already raised by @<who> (<thread state>); see <thread url>. Not re-posted.

## Pre-existing / Out of Scope (X found)

- NOTICED BUT NOT TOUCHING: `path/to/file.ts:123` — <issue> (not introduced by this PR)

## Manual posting

If this run created a pending review, open the review URL above, inspect or edit every inline comment, then use GitHub's **Finish your review** flow to choose Approve, Comment, or Request changes. The skill does not post a review summary and never performs the submission step.

If the pending-review offer was declined or a confirmed no-write blocker was resolved, the clearest later path is to re-run the skill with `--draft-review`. It will repeat the head, pending-review, ignored-payload, and payload-validation guards before creating one unsubmitted pending review.

For `write outcome unknown`, `unexpected state`, an existing pending review, or a stale/unverifiable created review, do not retry with a raw API command. Inspect GitHub first. Submit or delete an existing draft there as appropriate, then re-run the guarded workflow against the current head if another review is still needed.

To reply to an existing review thread, post to its root comment (the comment ID is in the Open Conversation entries):

```bash
gh api -X POST "repos/<owner>/<repo>/pulls/<number>/comments/<root-comment-id>/replies" \
  -f body='<your reply>'
```

## Optional deeper passes

- `/kramme:pr:product-review` — deeper product-value and flow-completeness review.
- `/kramme:code:copy-review --pr` — UI text redundancy review for the Pull Request diff.
````

## Section notes

- **Evidence** — written for you, the reviewer, not for the author. Capture the full trace, reproduction, or reasoning here so you can decide with it in front of you. It deliberately does **not** all go into the draft comment.
- **Draft comment** — the part the author actually reads, and the value this report adds over a plain findings list. Follow the comment-craft rules in the skill's draft step (human voice, lead with a Socratic question, calibrated, brief, evidence kept in `Evidence`, not the comment). Include it for Questions so every proposed inline comment can be carried into a pending review; skip it only for Strengths.
- **Humanized** — `yes` once the draft has passed through `kramme:text:humanize`, `no` if the humanizer was unavailable or the original wording was kept to protect the human voice, question framing, calibration, or technical accuracy.
- **Location** — always a concrete `path:line` from the PR diff so the comment can be anchored. Use the line in the PR's head version. If a finding is PR-wide, say `review-scope` and explain in the body.
- **Open Conversation** — only for ongoing reviews; omit on a clean first pass. List threads in priority order: `awaiting-you` and `author-responded` first (these need your input), then `peer-comment` / `new-from-others` / `your-open` (awareness). The root comment ID for each thread feeds the reply command in Manual posting.
- **Verified (live tree)** — the result of reading the current file at the thread's location in the worktree, not an inference from finding overlap: `addressed`, `still-open`, or `cant-tell`. Name what you actually saw (the guard now present, the unchanged branch, etc.). This is what lets a reply say "looks handled now" with confidence.
- **Draft reply** — same voice as a draft comment, grounded in the live verification and leading with your decision (addressed → say what you saw; still-open → the open question; or a direct answer). Don't draft acknowledgement-only replies — use "(surfaced for awareness — no reply needed)" when none moves the review forward.
- **Draft Review** — distinguish eligible proposed comments from comments actually included. Before the offer or write, use `not created — awaiting authorization` or `not created — authorized; creation not attempted yet`, with zero included comments and no payload. Existing-thread replies and non-diff anchors cannot be bundled into the pending review and must be listed as omissions rather than silently dropped; identify them by thread, scope, or another concrete descriptor when no `path:line` exists. `PENDING` means the skill created the review but did not submit it. Exact included counts require a confirmed pending-review response; ambiguous outcomes report the attempted count separately.
- **Already Raised in the Conversation** — fresh findings you suppressed because someone already raised them. Naming who raised it and linking the thread keeps you from re-posting and shows the concern is tracked. If your finding materially extends the existing thread, draft it as a reply under Open Conversation instead of listing it here.
- **Verdict** — see the skill's draft step for the REQUEST CHANGES / COMMENT / APPROVE criteria and how an ongoing review's conversation weighs in. Always a recommendation — never posted automatically.
- **Strengths** — a review with zero positive observations is usually miscalibrated. Keep strengths in this local report only; never turn them into a top-level GitHub review body. If the PR genuinely has nothing to praise, say so explicitly rather than omitting the section.
- **Markers** — keep `UNVERIFIED` on findings you could not trace from the diff, and `NOTICED BUT NOT TOUCHING` on issues that pre-date this PR, so the author can separate "you introduced this" from "this was already here."
