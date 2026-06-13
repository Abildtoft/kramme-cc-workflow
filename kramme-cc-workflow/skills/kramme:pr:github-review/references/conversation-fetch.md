# Fetching and mapping an ongoing review conversation

How to pull the existing comments on a PR and classify them from the **reviewer's seat** (you are reviewing someone else's PR, not authoring it). All operations are reads — this skill never posts. `gh` and `jq` were confirmed in Preflight.

Set the repository and actor context from values already resolved earlier:

```bash
OWNER="${PR_NWO%%/*}"
REPO="${PR_NWO#*/}"
# SELF (your login) and AUTHOR (the PR author's login) are already set.
```

## 1. Fetch the data

**Inline review comments (REST)** — stable IDs, node IDs, `path`, `line`/`original_line`, `diff_hunk`, `in_reply_to_id`, `user.login`, `user.type`, `html_url`:

```bash
gh api --paginate "repos/$OWNER/$REPO/pulls/$PR_NUMBER/comments"
```

**Review threads (GraphQL)** — thread IDs, resolution state, and per-comment authors. Match to REST comments by node ID (`REST.node_id` == `GraphQL.id`):

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
          isOutdated
          comments(first: 100) {
            nodes { id url body createdAt author { login __typename } }
          }
        }
      }
    }
  }
}'
```

Repeat with the returned `endCursor` while `hasNextPage` is true.

**General PR comments (REST)** — top-level discussion not anchored to a line:

```bash
gh api --paginate "repos/$OWNER/$REPO/issues/$PR_NUMBER/comments"
```

**Prior reviews (REST)** — summary-level review verdicts, including your own standing decision:

```bash
gh api --paginate "repos/$OWNER/$REPO/pulls/$PR_NUMBER/reviews"
```

**GraphQL fallback.** If GraphQL fails but REST succeeds, resolution state is unknown. Continue REST-only: group inline comments by `in_reply_to_id` (root comments have none), mark each thread `Resolution: unknown`, and never assume a thread is resolved. If `--all-threads` was not set, say plainly that the unresolved-only filter cannot be applied without GraphQL and include all threads.

## 2. Group into threads

1. Join REST inline comments to GraphQL threads by node ID. The first comment in a GraphQL thread is the root; for REST-only fallback, a root has no `in_reply_to_id` and replies point to it.
2. Treat each general PR comment as its own single-comment item.
3. For each thread, record: root author, latest comment author, latest comment timestamp, file/line, resolution state, and the thread URL.

## 3. Filter

- Unless `--include-bots`, drop comments whose GraphQL `__typename` is `Bot` or REST `user.type` is `Bot`.
- Unless `--all-threads`, drop threads that are resolved. Keep unresolved threads and any thread whose latest comment is **not** from you.
- Never drop a thread you started (`root author == SELF`) that has replies — those are the ones most likely to need your response.

## 4. Classify each thread from the reviewer's seat

Assign exactly one state:

- `awaiting-you` — a thread you started, or one directed at you, whose latest comment is from the author or another reviewer. You owe a response.
- `author-responded` — the author replied to your comment (often "done" / "fixed" / a question). Verify by reading the current file at that location in the worktree (e.g. `git show HEAD:<path>`), not by inferring from finding overlap: if the code now resolves the concern the fix landed, otherwise it is still open.
- `peer-comment` — another reviewer raised something you did not. Surface it; use it to suppress duplicate fresh findings. No reply unless you want to add to it.
- `your-open` — your prior comment with no reply yet. Still outstanding; surface it but do not redraft it.
- `new-from-others` — a general comment or new thread from the author/reviewers since you last engaged. Surface for awareness; dedupe fresh findings against it.
- `resolved` — only present when `--all-threads` is set. Surface for context; no action.

For every anchored thread, read the current file at its location in the worktree and record a live verification — `addressed`, `still-open`, or `cant-tell` (unanchored or genuinely ambiguous). The worktree is the PR head, so this reflects the code as it stands now, including after the author's latest pushes; an outdated anchor means find the concern's current location and verify there rather than trusting the stored line number. Also cross-reference each thread against the captured fresh findings by file + line + root cause and record the matching finding's location (`path:line`, or `—`). Together these let the report (a) draft an informed reply grounded in the real code and (b) suppress the fresh finding as already-raised.
