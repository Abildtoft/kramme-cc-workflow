---
name: kramme:pr:github-review-reply
description: Maps human GitHub PR review feedback, including inline review threads, review-summary comments, and general PR comments; facilitates needed code changes; drafts and humanizes action-based responses; and optionally posts replies or resolves addressed inline threads with gh. Use when reviewers left GitHub comments that need triage, implementation, or response. Not for fixing CI, generating internal review findings, or resolving local REVIEW_OVERVIEW.md findings.
argument-hint: "[--implement|--no-implement] [--post] [--resolve] [--inline] [--include-bots] [--all] [--only <login>] [pr-url|instructions]"
disable-model-invocation: true
user-invocable: true
---

# GitHub Review Reply Handler

Map human GitHub pull request review feedback, facilitate needed code changes, draft clear action-based replies, and optionally post replies or resolve addressed inline threads.

## Scope

Use this skill for online GitHub review feedback where the user wants review comments addressed and answered. Feedback includes inline review threads, pull-request review-summary comments, and general PR comments. The preferred flow is implementation-first: if a thread or comment needs a code change, make or delegate that change before drafting the reply so the reply describes completed work, not planned work.

If implementation is disabled or blocked, classify the item honestly and do not post a reply that implies the change has already happened.

## Step 0: Parse Arguments

Parse `$ARGUMENTS` before fetching data.

**Flags:**

- `--post` - after drafting, post approved replies to GitHub.
- `--resolve` - after posting, resolve inline threads that are fully addressed. If used without `--post`, ask for explicit confirmation before resolving existing addressed inline threads.
- `--implement` - implement code-change items before drafting replies.
- `--no-implement` - skip implementation and produce a reply plan only.
- `--inline` - reply in chat only; do not write `GITHUB_REVIEW_REPLY_PLAN.md`.
- `--include-bots` - include bot and app review comments. Default: human reviewers only.
- `--all` - include resolved inline threads, comments already answered by the branch author, and older summary/general comments. Default: unresolved and awaiting-author feedback only.
- `--only <login>` - include only feedback whose latest non-author human comment is from this login.

The remaining payload may be a PR URL, PR number, or additional instructions such as "only reply to Sarah" or "do not resolve design comments."

Defaults: `IMPLEMENT=plan-only`, `POST=false`, `RESOLVE=false`, `INLINE=false`, `INCLUDE_BOTS=false`, `INCLUDE_ALL=false`.

`IMPLEMENT=plan-only` is the default: map feedback and draft replies, but do not edit code. Implement needed code changes only when `--implement` is set or the request explicitly asks to address, handle, or fix the feedback (e.g. "address these comments", "fix Sarah's findings"). A bare invocation — just a PR URL, or no payload — never edits code. `--implement` forces implementation; `--no-implement` is the explicit form of the plan-only default.

## Step 1: Identify the PR

1. Confirm required tooling before any GitHub call. `gh` must be installed and authenticated, and `jq` must be available because every step below parses `gh` output with it:

   ```bash
   if ! command -v gh > /dev/null; then
     echo "gh CLI not installed. Install from https://cli.github.com and run \`gh auth login\`." >&2
     exit 1
   fi
   if ! command -v jq > /dev/null; then
     echo "jq not installed. Install it first (e.g. \`brew install jq\` or \`apt-get install jq\`)." >&2
     exit 1
   fi
   ```

2. If the payload contains a GitHub PR URL or number, set `PR_SELECTOR` to that value. Otherwise leave `PR_SELECTOR` empty so `gh pr view` uses the current branch.
3. Capture the PR context:

   ```bash
   PR_CONTEXT_JSON=$(gh pr view ${PR_SELECTOR:+"$PR_SELECTOR"} --json number,url,title,baseRefName,headRefName,reviewDecision,author)
   PR_NUMBER=$(printf '%s\n' "$PR_CONTEXT_JSON" | jq -r '.number // empty')
   PR_URL=$(printf '%s\n' "$PR_CONTEXT_JSON" | jq -r '.url // empty')
   BASE_BRANCH=$(printf '%s\n' "$PR_CONTEXT_JSON" | jq -r '.baseRefName // empty')
   PR_AUTHOR=$(printf '%s\n' "$PR_CONTEXT_JSON" | jq -r '.author.login // empty')
   ```

4. If no PR is found, or `PR_NUMBER`, `BASE_BRANCH`, `PR_URL`, or `PR_AUTHOR` is empty, ask the user for a PR URL and stop.
5. Capture repository and actor context. Derive `OWNER` and `REPO` from `PR_URL` so a URL for another repository does not accidentally target the current checkout's repository:

   ```bash
   REPO_NWO=$(printf '%s\n' "$PR_URL" | sed -E 's#^https://github.com/([^/]+/[^/]+)/pull/[0-9]+.*#\1#')
   if [ -z "$REPO_NWO" ] || [ "$REPO_NWO" = "$PR_URL" ]; then
     echo "Could not parse repository from PR URL: $PR_URL" >&2
     exit 1
   fi
   OWNER="${REPO_NWO%%/*}"
   REPO="${REPO_NWO#*/}"
   SELF=$(gh api user --jq .login)
   ```

6. Fetch the PR base branch if available so local code inspection has the same context as the reviewer:

   ```bash
   git fetch origin "refs/heads/${BASE_BRANCH}:refs/remotes/origin/${BASE_BRANCH}"
   ```

## Step 2: Fetch Review Feedback

Fetch inline review comments, GraphQL review thread metadata, review-summary comments, and general PR comments.

**REST comments** - use this for stable comment IDs, node IDs, paths, line numbers, diff hunks, URLs, and `in_reply_to_id`:

```bash
gh api --paginate "repos/$OWNER/$REPO/pulls/$PR_NUMBER/comments"
```

**Review summaries** - use this for summary-level review bodies and reviewer verdicts that are not anchored to a line:

```bash
gh api --paginate "repos/$OWNER/$REPO/pulls/$PR_NUMBER/reviews"
```

**General PR comments** - use this for top-level PR discussion that may contain review feedback outside the review API:

```bash
gh api --paginate "repos/$OWNER/$REPO/issues/$PR_NUMBER/comments"
```

**GraphQL threads** - use this for thread IDs and resolution state:

```bash
gh api graphql -f owner="$OWNER" -f name="$REPO" -F number="$PR_NUMBER" -f query='
query($owner: String!, $name: String!, $number: Int!, $cursor: String) {
  repository(owner: $owner, name: $name) {
    pullRequest(number: $number) {
      reviewThreads(first: 100, after: $cursor) {
        pageInfo { hasNextPage endCursor }
        nodes {
          id
          isResolved
          comments(first: 100) {
            nodes {
              id
              body
              url
              createdAt
              author { login __typename }
            }
          }
        }
      }
    }
  }
}'
```

If `hasNextPage=true`, repeat the query with the returned `endCursor` until all review threads are fetched.

If GraphQL fails but REST succeeds, resolution state is unknown for inline threads. If `--all` is not set, exclude inline threads from the default filtered set, continue with review-summary and general PR comments, and report that inline threads were skipped because the unresolved-thread filter could not be applied. If `--all` is set, include REST-only inline threads, mark them `Thread ID: unavailable` and `Resolution state: unknown`, and do not resolve threads automatically. Review-summary and general PR comments can still be mapped and answered, but they never have a review-thread ID and are never resolved.

## Step 3: Build the Review Map

Group feedback into actionable items.

1. Join REST comments to GraphQL comments by node ID (`REST.node_id` equals `GraphQL.id`).
2. Treat the first comment in a GraphQL thread as the root comment. For REST-only fallback, group by `in_reply_to_id` where present; root comments have no `in_reply_to_id`.
3. Treat each review summary with a non-empty body as a single `review-summary` item. Ignore empty approval/comment shells with no actionable body.
4. Treat each general PR comment as a single `general-comment` item.
5. Identify the latest non-author comment in each item, where author means `PR_AUTHOR`.
6. Drop items whose only human comments are from `SELF` or `PR_AUTHOR`. Keep items that contain reviewer feedback even when `SELF` or `PR_AUTHOR` also participated.
7. Unless `--include-bots` is set, exclude authors whose GraphQL `__typename` is `Bot` or whose REST user `type` is `Bot`.
8. Unless `--all` is set, exclude inline threads that are already resolved or whose latest non-author comment is older than a later reply from `PR_AUTHOR`; exclude review-summary and general-comment items when a later author reply clearly answers them. In REST-only fallback, Step 2 has already excluded inline threads unless `--all` was set, so still apply the author-reply filter to review-summary and general-comment items.
9. Apply `--only <login>` after all other filtering.

If no items remain after filtering, report that no unanswered human review feedback was found and stop.

## Step 4: Classify Each Item

For every remaining item, inspect the relevant code and branch diff before drafting a reply.

Use these commands as needed:

```bash
git diff "origin/$BASE_BRANCH"...HEAD -- "$PATH"
sed -n '<start>,<end>p' "$PATH"
```

Classify each item as exactly one:

- `already-addressed` - the requested code change is present in the current branch or the reviewer misunderstood code that is already correct.
- `needs-code-change` - the reviewer is right and the branch does not yet address it.
- `explanation-needed` - no code change is needed, but the reviewer deserves a concrete explanation.
- `disagree` - the suggested change would make the code worse, contradict requirements, or add out-of-scope churn.
- `question-for-reviewer` - the item cannot be answered without reviewer or product clarification.
- `duplicate` - another item covers the same issue.
- `out-of-scope` - the request is unrelated to the PR's intent.

Do not claim a fix is complete unless the code or diff proves it. If the evidence is ambiguous, classify as `question-for-reviewer` or `needs-code-change`.

## Step 5: Implement Needed Code Changes

If any item is classified as `needs-code-change` and `IMPLEMENT` resolved to implement (via `--implement` or an explicit request to address the feedback), resolve the code changes before drafting replies. Under the plan-only default, skip this entire step.

1. Print a short implementation queue:

   ```text
   Implementing <N> review-requested code changes before drafting replies.
   ```

2. Use `kramme:pr:resolve-review --implement-only` as the implementation engine, passing a structured review payload that contains only the items classified as `needs-code-change`. Do not pass the PR URL as the source argument and do not use `--source online` for this handoff, because that would allow resolve-review to fetch and process comments outside this skill's filtered item set. Include the PR number/title as metadata, plus each selected item's `source_id`, item kind (`inline-thread`, `review-summary`, or `general-comment`), thread ID when present, root comment ID when present, reviewer, file/line when present, diff hunk when present, and comment body. `--implement-only` requires that caller-scoped findings payload, makes no GitHub writes, writes no `REVIEW_OVERVIEW.md`, and drafts no replies — this skill owns the reply and resolution phase. resolve-review still runs its own scope-creep and validity checks as a safety net, so it may decline or defer some of the set.

3. Proceed without another prompt; this step is only reached when implementation was already requested (Step 5 opening). Do not re-confirm before editing files.

4. After implementation returns, read `.context/resolve-review/implement-only-summary.json` and reconcile each item against the relevant files and diffs:
   - `implemented` → reclassify as `already-addressed`; record `Implementation status: implemented` and `Action executed: <specific change>`.
   - `already-addressed` → keep or reclassify as `already-addressed`; record `Implementation status: not needed` and carry the action/evidence into the draft reply.
   - `skipped-out-of-scope` → reclassify as `out-of-scope`, carrying resolve-review's rationale into the draft reply.
   - `skipped-invalid` or `disagreed` → reclassify as `disagree`, carrying resolve-review's rationale into the draft reply.
   - `blocked-implementation` or `blocked-validation` → keep the item as `needs-code-change`, mark `Implementation status: blocked`, and stop before posting replies.
   - Record the validation commands and outcomes resolve-review reported.

   Always verify each claim against the actual diff; never trust the summary's status alone.

5. If implementation fails or validation fails, stop before posting replies. Keep or write the plan with `Implementation status: blocked`, include the failure, and do not draft a completion claim.

6. If a change is out of scope or needs product/reviewer clarification, keep the original classification and do not force an implementation.

If implementation is skipped (the plan-only default or `--no-implement`), mark code-change items as `Implementation status: not attempted`. Do not post acknowledgement-only replies for these items unless the user explicitly asks for that.

## Step 6: Draft and Humanize Replies

Draft one reply per item unless the item should be skipped.

**Reply rules:**

- Keep replies concise and specific.
- Address the reviewer by content, not by exaggerated thanks.
- State the decision first: changed, no change, question, or deferred.
- Mention concrete evidence only when useful: function names, files, behavior, or tests.
- Do not include AI attribution or meta-process details.
- For implemented items, describe the executed action and validation result.
- Do not post a "will fix" reply for every `needs-code-change` item. If implementation was skipped or blocked, mark the item as not ready to post unless the user explicitly asks for an acknowledgement reply.
- For review-summary and general-comment items, draft a top-level PR comment response unless a more specific inline thread is the right place to answer. These items cannot be resolved as review threads.

After the first draft pass, humanize the draft reply bodies before writing the plan or posting anything. Humanization is best-effort: if `kramme:text:humanize` is unavailable, skip it, mark `Humanized: no` on each affected item, and continue.

When humanize is available, send all draft reply bodies in a single batched call, separated by a stable delimiter that carries each reply's index. Send only the reply bodies — not reviewer quotes, code snippets, file paths, IDs, command examples, or plan metadata. Map the humanized results back to items by index; for any reply whose mapping is ambiguous, or if the returned count does not match the input, keep the original body for that item rather than risk posting mis-mapped text.

Apply the humanized output back into each `Draft reply:` field, preserving:

- factual claims and verification limits
- reviewer-specific context
- technical identifiers that are needed for clarity
- the one-reply-per-item mapping
- the classification and resolve decision

If the humanizer changes meaning, adds unsupported warmth, removes necessary technical detail, or weakens a disagreement, keep the original wording for that part and make the smallest manual edit needed to remove AI-sounding phrasing.

**Resolve rules:**

- Resolve after posting only when the item is an inline thread, status is `already-addressed`, and the reply explains the completed fix or existing behavior.
- Do not resolve `disagree`, `question-for-reviewer`, or `out-of-scope` items. Let the reviewer decide.
- Do not resolve REST-only fallback threads because the GraphQL thread ID is unavailable.
- Do not resolve review-summary or general-comment items; GitHub does not expose them as review threads.
- Do not resolve any inline thread whose latest human comment asks a direct question that the draft does not answer.

## Step 7: Write the Plan

Unless `--inline` is set, create or update `GITHUB_REVIEW_REPLY_PLAN.md` in the project root with this structure:

```markdown
# GitHub Review Reply Plan

PR: <title> (#<number>) URL: <url>

## Summary

- Human review feedback items found: <count>
- Inline threads: <count>
- Review-summary comments: <count>
- General PR comments: <count>
- Ready to reply: <count>
- Needs code changes: <count>
- Code changes implemented: <count>
- Safe to resolve after reply: <count>
- Skipped: <count and reason summary>

## Feedback

### Item 1: @<reviewer> `<path>:<line or review-summary|general-comment>`

**Kind:** `inline-thread|review-summary|general-comment` **Thread ID:** `<graphql-thread-id or unavailable|n/a>` **Root comment ID:** `<rest-root-comment-id or n/a>` **Comment ID:** `<review id or issue comment id, when applicable>` **Status:** `<classification>` **Implementation status:** `not needed|implemented|not attempted|blocked` **Action executed:** <specific change, or "none"> **Reply target:** `inline-reply|top-level-comment|none` **Resolve after posting:** `yes|no` **Reviewer comment:** <short quote or paraphrase> **Assessment:** <why this classification is correct> **Evidence checked:** <files, diff, tests, or "not verified"> **Humanized:** `yes|no` **Draft reply:**

> <reply>

**Post status:** `not posted`
```

If `--inline` is set, return the same structure in chat and do not create the file.

Treat `GITHUB_REVIEW_REPLY_PLAN.md` and the reply payload files under `.context/github-review-replies/` (Step 9) as working artifacts that should **not** be committed and can be cleaned up by `/kramme:workflow-artifacts:cleanup`.

## Step 8: Confirm Before GitHub Writes

If neither `--post` nor `--resolve` is set, stop after writing or returning the plan.

Before any GitHub write, show:

```text
Posting <N> replies/comments and resolving <M> inline review threads on <PR URL>.
```

Then ask for explicit confirmation unless the user's current message clearly requested posting now and the flags include `--post`. For REST-only fallback, always ask for explicit confirmation before posting because resolution state is unknown; `--post` alone does not waive this confirmation.

Do not post replies for items classified as `needs-code-change` or with `Implementation status: blocked|not attempted` unless the user explicitly asks to post acknowledgement replies.

## Step 9: Post Replies

For each approved inline-thread reply, write the body to a temporary JSON file under `.context/github-review-replies/` and post it with the root REST review comment ID:

```bash
gh api -X POST "repos/$OWNER/$REPO/pulls/$PR_NUMBER/comments/$ROOT_COMMENT_ID/replies" --input .context/github-review-replies/reply-THREAD.json
```

The JSON file must be:

```json
{ "body": "<draft reply>" }
```

If a reply post fails, stop posting further replies, preserve the plan file, and report the failed item and GitHub error.

For each approved review-summary or general-comment response, write the body to a temporary JSON file under `.context/github-review-replies/` and post it as a top-level PR comment:

```bash
gh api -X POST "repos/$OWNER/$REPO/issues/$PR_NUMBER/comments" --input .context/github-review-replies/reply-ITEM.json
```

Use the same JSON shape:

```json
{ "body": "<draft reply>" }
```

If posting a top-level comment fails, stop posting further replies/comments, preserve the plan file, and report the failed item and GitHub error.

## Step 10: Resolve Threads

Only resolve inline threads approved by Step 6 and successfully posted in Step 9, unless the user explicitly requested resolving already-replied addressed inline threads. Review-summary and general-comment items are not resolvable.

Resolve with GraphQL:

```bash
gh api graphql -f threadId="$THREAD_ID" -f query='
mutation($threadId: ID!) {
  resolveReviewThread(input: {threadId: $threadId}) {
    thread { id isResolved }
  }
}'
```

After each successful resolve, update the plan's `Post status:` to `posted and resolved`. If a resolve fails after the reply posted, leave the reply in place, mark `Post status: posted, resolve failed`, and report the GitHub error.

## Step 11: Final Output

End with:

- PR URL
- number of inline replies and top-level comments posted
- number of inline threads resolved
- number of code-change items implemented
- number of items still needing code changes or clarification
- path to `GITHUB_REVIEW_REPLY_PLAN.md`, unless `--inline` was used

If any items remain `needs-code-change`, include this next step:

```text
/kramme:pr:github-review-reply --implement <PR URL>
```
