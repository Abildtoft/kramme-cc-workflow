---
name: kramme:pr:github-review
description: "Review a GitHub pull request where you are the assigned reviewer, not the author or assignee. Fetches the PR into an isolated git worktree (your branch untouched), runs code-quality agents plus UX/accessibility agents when the PR touches UI, and writes a reviewer-facing report with file:line-anchored findings, draft inline comments phrased as concise, humanized Socratic questions, and a recommended verdict. Supports ongoing reviews: maps existing author and reviewer comments, drafts replies to threads awaiting you (including replies to your own earlier comments), and skips findings already raised in the conversation. Read-only toward GitHub: never posts and never auto-approves — you submit the review yourself. Triggers on reviewing someone else's PR or a review-requested PR. Not for reviewing your own branch before shipping (use kramme:pr:code-review), responding to reviewers on your own PR (use kramme:pr:github-review-reply), or resolving review findings (use kramme:pr:resolve-review)."
argument-hint: "[pr-number|pr-url] [--base <ref>] [--categories a11y,ux,product,visual] [--code-only] [--fresh] [--include-bots] [--all-threads] [--inline] [--keep-worktree]"
disable-model-invocation: true
user-invocable: true
---

# Review a GitHub PR

Carry out a review of a GitHub pull request you have been asked to review. You are the reviewer, not the author or assignee. The skill fetches the PR into a throwaway git worktree, runs the appropriate review agents against the PR's real diff, and produces a reviewer-facing assessment you can transcribe into a GitHub review.

This skill is **read-only toward GitHub**: it never posts comments, never submits a review, and never approves on your behalf. It drafts a recommended verdict; you make the final call and post it yourself.

## Step 0: Parse Arguments

Parse `$ARGUMENTS` before any network or git call.

- First positional token that is a PR number (`123`, `#123`) or a GitHub PR URL → `PR_SELECTOR`. Otherwise leave `PR_SELECTOR` empty.
- `--base <ref>` → `BASE_OVERRIDE` (use when the PR targets a non-default base and detection is wrong).
- `--categories <list>` → `UI_CATEGORIES` (comma-separated subset of `a11y,ux,product,visual`), passed through to the UI review pass.
- `--code-only` → `CODE_ONLY=true`. Skip the UI review pass even when UI files changed.
- `--fresh` → `SKIP_THREADS=true`. Ignore the existing review conversation and produce a clean first-pass assessment only.
- `--include-bots` → `INCLUDE_BOTS=true`. Include bot/app comments when mapping the conversation (default: human only).
- `--all-threads` → `INCLUDE_RESOLVED=true`. Include already-resolved threads in the map (default: unresolved and awaiting-you threads only).
- `--inline` → `INLINE_MODE=true`. Return the report in chat instead of writing the artifact file.
- `--keep-worktree` → `KEEP_WORKTREE=true`. Leave the fetched worktree on disk for manual inspection and report its path.

Defaults: `CODE_ONLY=false`, `SKIP_THREADS=false`, `INCLUDE_BOTS=false`, `INCLUDE_RESOLVED=false`, `INLINE_MODE=false`, `KEEP_WORKTREE=false`.

## Step 1: Preflight

Confirm tooling before any GitHub call.

```bash
command -v gh > /dev/null || { echo "gh CLI required. Install from https://cli.github.com and run 'gh auth login'." >&2; exit 1; }
command -v jq > /dev/null || { echo "jq required. Install it first (e.g. 'brew install jq' or 'apt-get install jq')." >&2; exit 1; }
gh auth status > /dev/null 2>&1 || { echo "Authenticate first with 'gh auth login'." >&2; exit 1; }

ORIG_ROOT=$(git rev-parse --show-toplevel) || { echo "Run this from inside a git clone of the PR's repository." >&2; exit 1; }
LOCAL_NWO=$(gh repo view --json nameWithOwner -q .nameWithOwner 2> /dev/null)
SELF=$(gh api user -q .login)
```

`ORIG_ROOT` is the original checkout root. Capture it now; later steps change directory into the worktree and must return here to write the report and clean up.

## Step 2: Identify the PR

If `PR_SELECTOR` is empty, show the open PRs awaiting your review and let the user choose one. Do not guess.

```bash
gh pr list --search "user-review-requested:@me" --state open \
  --json number,title,author,url,updatedAt \
  --template '{{range .}}#{{.number}}  {{.title}}  (@{{.author.login}})  {{.url}}{{"\n"}}{{end}}'
```

If the list is empty, report that no PRs are currently requesting your review and stop. Otherwise stop and wait for the user's choice — do not run the next block until `PR_SELECTOR` is set to the PR they name.

Fetch the PR context:

```bash
PR_JSON=$(gh pr view ${PR_SELECTOR:+"$PR_SELECTOR"} \
  --json number,url,title,author,baseRefName,headRefName,headRefOid,additions,deletions,changedFiles,reviewDecision) \
  || { echo "PR not found. Pass a PR number or URL." >&2; exit 1; }

PR_NUMBER=$(printf '%s' "$PR_JSON" | jq -r '.number')
PR_URL=$(printf '%s'    "$PR_JSON" | jq -r '.url')
PR_TITLE=$(printf '%s'  "$PR_JSON" | jq -r '.title')
AUTHOR=$(printf '%s'    "$PR_JSON" | jq -r '.author.login')
PR_BASE_BRANCH=$(printf '%s' "$PR_JSON" | jq -r '.baseRefName')
BASE_REF_ARG=${BASE_OVERRIDE:-$PR_BASE_BRANCH}
HEAD_REF=$(printf '%s'  "$PR_JSON" | jq -r '.headRefName')
HEAD_OID=$(printf '%s'  "$PR_JSON" | jq -r '.headRefOid')
ADDITIONS=$(printf '%s' "$PR_JSON" | jq -r '.additions')
DELETIONS=$(printf '%s' "$PR_JSON" | jq -r '.deletions')
CHANGED_COUNT=$(printf '%s' "$PR_JSON" | jq -r '.changedFiles')
REVIEW_DECISION=$(printf '%s' "$PR_JSON" | jq -r '.reviewDecision // "none"')
```

`ADDITIONS`, `DELETIONS`, `CHANGED_COUNT`, and `REVIEW_DECISION` populate the report header in Step 11.

Derive the PR's repository from the URL so a URL for another repository does not silently target the local checkout:

```bash
PR_NWO=$(printf '%s' "$PR_URL" | sed -E 's#^https://github.com/([^/]+/[^/]+)/pull/[0-9]+.*#\1#')
```

**Repository guard.** The PR head must be fetchable from the local `origin`. This works for forks too, because the base repository always exposes a `pull/<N>/head` ref. If `PR_NWO` differs from `LOCAL_NWO`, stop: this skill must run from a clone of the PR's base repository. Tell the user the PR belongs to `PR_NWO` but the current clone is `LOCAL_NWO`.

**Author guard.** If `AUTHOR` equals `SELF`, this PR is yours. Warn the user and ask whether to continue. Point them to `kramme:pr:code-review` for reviewing your own branch and `kramme:pr:github-review-reply` for responding to reviewers on your own PR. Only continue if the user confirms.

## Step 3: Fetch the PR Into an Isolated Worktree

Fetch the PR head, then add a detached worktree. Nothing in the user's current checkout changes. Step 4 resolves and fetches the base ref inside the worktree so `--base main`, `--base origin/main`, and `--base refs/remotes/origin/main` all follow the shared resolver contract.

```bash
git worktree prune  # sweep any orphaned registrations from a prior interrupted run
git fetch --quiet origin "pull/${PR_NUMBER}/head" || { echo "Could not fetch pull/${PR_NUMBER}/head from origin." >&2; exit 1; }

TMP_PARENT=$(mktemp -d "${TMPDIR:-/tmp}/kramme-review-pr-${PR_NUMBER}.XXXXXX")
WORKTREE_DIR="$TMP_PARENT/wt"
git worktree add --quiet --detach "$WORKTREE_DIR" FETCH_HEAD || { echo "Failed to create review worktree." >&2; rm -rf "$TMP_PARENT"; exit 1; }
cd "$WORKTREE_DIR"
```

The worktree is a working artifact. **Once it exists, any failure or stop before Step 8 must first run the Step 8 cleanup block** (return to `ORIG_ROOT`, remove the worktree, delete `TMP_PARENT`) so a partial run never leaks a registered worktree or temp directory. Step 8 removes it on the normal path unless `KEEP_WORKTREE=true`.

## Step 4: Resolve Base and Collect Scope

From inside the worktree, build the unified change scope with the shared plugin script. Because the worktree is a clean checkout of the PR head, the scope is exactly the PR's committed diff against its base.

```bash
RESOLVED=$("${CLAUDE_PLUGIN_ROOT}/scripts/collect-review-diff.sh" --base "$BASE_REF_ARG" --strict) || {
  echo "Base/diff collection failed; see the message above." >&2
  cd "$ORIG_ROOT"; git worktree remove --force "$WORKTREE_DIR" 2> /dev/null; rm -rf "$TMP_PARENT" 2> /dev/null
  exit 1
}
eval "$RESOLVED"
```

The script exports `BASE_REF`, `BASE_BRANCH`, `MERGE_BASE`, and newline-delimited `CHANGED_FILES`. If `CHANGED_FILES` is empty, the PR has no diff against its base: note there are no code changes to review (no fresh findings), skip Steps 5–6, but still run Step 7 to surface the existing conversation unless `--fresh` is set, then clean up.

## Step 5: Classify Scope

Decide whether to run the UI review pass. If `CODE_ONLY=true`, skip this and set `RUN_UI=false`.

```bash
UI_REGEX='\.(tsx|jsx|vue|svelte|css|scss|sass|less|styl|html?|astro|mdx)$|/(components?|ui|pages|views|screens|styles|layouts)/'
if [ "${CODE_ONLY:-false}" != "true" ] && printf '%s\n' "$CHANGED_FILES" | grep -Eiq "$UI_REGEX"; then
  RUN_UI=true
else
  RUN_UI=false
fi
```

## Step 6: Run the Reviews

Run all review commands **with the worktree as the working directory** (you are already `cd`'d there). If you delegate via slash command, the sibling skill resolves git state against the PR head only while the session's working directory is the worktree — keep it there until the worktree is removed in Step 8. If slash invocation is unavailable, read the sibling skill's `SKILL.md` from the installed skills directory and follow it, running every git command inside the worktree.

1. **Code quality — always.** Delegate to `/kramme:pr:code-review --base "$BASE_REF" --inline`. `--inline` keeps the findings in chat instead of writing `REVIEW_OVERVIEW.md` into the throwaway worktree. Capture the structured findings (severity, location, confidence, evidence).

2. **UI/UX/visual/accessibility/product — when `RUN_UI=true`.** Delegate to `/kramme:pr:ux-review --base "$BASE_REF" --inline`, appending `--categories <UI_CATEGORIES>` when the user supplied that flag. There is normally no running app for someone else's PR, so the UI pass runs as static, diff-based analysis. Capture its findings.

Do not auto-run the heavier `kramme:pr:product-review` or `kramme:pr:copy-review`. Mention them in the final report as optional deeper passes the user can request.

**Coverage handling.** If a delegated review fails or reports degraded coverage, record which dimensions were not covered and surface that in the report. Do not present a partial review as complete. Continue as long as at least the code review succeeded.

## Step 7: Map the Existing Review Conversation

If `SKIP_THREADS=true`, skip this step entirely and continue to cleanup.

Do this step **while you are still inside the worktree** — the PR head checkout is what makes per-thread verification possible, and the next step removes it. Read `references/conversation-fetch.md` and follow it to pull the PR's existing review activity: inline review threads, general comments, and prior review verdicts. Build a thread map, filter it (human-only and unresolved by default, widened by `--include-bots` and `--all-threads`), and classify each thread from the reviewer's seat as `awaiting-you`, `author-responded`, `peer-comment`, `your-open`, `new-from-others`, or `resolved`.

**Re-check every anchored thread against the live tree.** For each thread tied to a `path:line`, read the actual file at that location in the worktree (e.g. `git show HEAD:<path>`, or open the file directly) and judge whether the concern still holds in the current code — do not infer it only from whether a fresh finding overlaps. Record a per-thread verification:

- `addressed` — the current code resolves the concern (for example, the guard the author says they added is present at that line).
- `still-open` — the concern still holds; capture the specific line or behavior that shows it.
- `cant-tell` — the thread is not anchored to a line (a general comment), or the current code is genuinely ambiguous. Say so rather than guessing.

Threads whose anchor is outdated (the line moved or the hunk changed) are exactly why this is a live read and not a line-number lookup — find the concern's current location in the file and verify there.

Also record the matching fresh finding's location (`path:line`, or none). The verification and the cross-reference drive the next step: drafting informed replies and suppressing fresh findings the conversation already raises.

If there is no prior activity (or `--fresh` was set), this is a clean first-pass review and the report's conversation sections are simply empty.

## Step 8: Clean Up the Worktree

Build the conversation map in Step 7 first — once the worktree is gone, per-thread verification is no longer possible. Return to the original checkout before removing the worktree (you cannot remove the worktree you are standing in).

```bash
cd "$ORIG_ROOT"
if [ "${KEEP_WORKTREE:-false}" = "true" ]; then
  echo "Worktree kept at: $WORKTREE_DIR"
else
  git worktree remove --force "$WORKTREE_DIR" 2> /dev/null
  rm -rf "$TMP_PARENT" 2> /dev/null
  git worktree prune
fi
```

If `--keep-worktree` was passed, report the path so the user can inspect or remove it later.

## Step 9: Draft the Review Comments

Read the report format from `references/report-template.md`. Sort the captured findings into **Blocking**, **Important**, **Suggestions / Nits**, **Questions for the author**, and **Strengths**. Anchor each actionable finding to a concrete `path:line` so it maps to a GitHub inline comment. Drop or label findings the diff cannot prove, using `UNVERIFIED` (plausible but not traced) and `NOTICED BUT NOT TOUCHING` (pre-existing, not introduced by this PR).

**Dedupe against the conversation.** Using the cross-reference from Step 7, do not draft a fresh comment for a finding the conversation already raises (by you, the author, or another reviewer). Move it to the report's "Already raised" list noting who raised it and the thread state, rather than posting a duplicate. If your fresh finding materially extends what the thread says (new evidence, higher severity), keep it as a reply on that thread instead of a new top-level comment.

For every actionable finding, capture two separate things: the **evidence** (the full trace, reproduction, or reasoning — kept in the report for your own reference) and a **draft comment** (the lean, human-voiced text you would actually paste into a GitHub thread). The comment is the product of this skill — the wording matters as much as the finding. Apply these rules to every comment:

- **Sound like a person, not a report.** Write the way a thoughtful colleague types into a review thread — plain, natural, a little informal. No finding-style structure, no severity labels, no bullet lists inside the comment. If it reads like generated output, rewrite it.
- **Lead with a question, not a verdict.** Prefer a Socratic question that lets the author check the concern themselves — "What happens if `items` is empty here?", "Is there a reason the retry isn't bounded?", "Would pulling this into `parseRow` make the intent clearer?" — over assertions like "This is wrong" or "You must change this".
- **Keep the evidence in the report, not the comment.** The trace, reproduction, and full reasoning belong in the finding's `Evidence` field so you have them when you decide. The comment carries only what the author needs to investigate or act — usually just the question and the specific line. Don't paste the whole rationale into the thread.
- **Calibrate confidence to evidence.** State a plainly-traced failure directly, but never as a scolding. For anything `UNVERIFIED`, phrase it as a question or "I might be missing something, but …" — never as established fact.
- **Be brief.** A sentence or two. No preamble, no restating what the code obviously does, no thanks-padding, no AI-attribution or meta-process text.
- **One point per comment.** Don't bundle unrelated concerns into one thread.
- **Keep what makes it actionable.** Concrete identifiers (function, file, variable) and the suggested direction stay in; the supporting evidence does not have to.
- **Severity sets urgency, not tone.** A Blocking comment is still a clear question or concise statement, not a demand.

`Strengths` is genuine praise worth saying in the summary, not padding. `Questions for the author` are open questions you genuinely could not resolve from the diff.

### Replies to the existing conversation

For each thread from Step 7 that needs your input, draft a **reply** using the same voice rules above (human voice, Socratic, concise, calibrated, evidence kept in the report). Ground the reply in the live-tree verification from Step 7, lead with your decision, then keep it short:

- `awaiting-you` / `author-responded` — say where you land, based on what you actually read in the current code. If verification is `addressed`, acknowledge it briefly, name what you saw (e.g. the guard now on that line), and note you'd resolve the thread. If `still-open`, say what's still there as a question, not a re-assertion. If `cant-tell` or the author asked you something, answer plainly or ask the one thing that would settle it.
- `peer-comment` — draft a reply only if you genuinely want to add to it; otherwise surface it for awareness with no draft.
- `your-open` — no reply (it's still waiting on them); surface it so you remember it's outstanding.
- `new-from-others` — surface for awareness; reply only if it asks something of you.

Do not draft a "will do" or acknowledgement reply for every thread — you are the reviewer, not the author. Only draft replies that move the review forward.

**Recommended verdict** (the human confirms and posts; this skill never approves):

- `REQUEST CHANGES` — one or more Blocking findings, or unresolved Blocking-level threads you opened.
- `COMMENT` — no Blocking findings, but Important findings, open questions, or threads awaiting you remain.
- `APPROVE` — no Blocking or Important findings, no unresolved concerns you raised, and the change clearly improves overall code health.

When the PR is an ongoing review, weigh the conversation into the verdict: if your earlier concerns verified as `addressed` against the live tree in Step 7, recommend updating your standing decision (note your prior verdict from Step 7). If threads you opened are still unresolved, that holds the verdict at `REQUEST CHANGES` or `COMMENT`. State the verdict as a recommendation with a one-line rationale, followed by the reminder that the user makes the final call and posts the review themselves.

## Step 10: Humanize the Draft Comments

Run the draft comment **and reply** bodies through `/kramme:text:humanize` to strip AI-isms before the report is written. This is best-effort: if the skill is unavailable, skip it, mark `Humanized: no` on each item, and continue.

When humanize is available:

- Send only the comment and reply bodies in a single batched call, separated by a stable delimiter that carries each item's index. Do **not** send file paths, line numbers, code snippets, finding IDs, reviewer quotes, or evidence — only the prose the author will read.
- Map the humanized results back to items by index. If the returned count does not match the input, or a mapping is ambiguous, keep the original body for that item rather than risk mis-mapping.
- Re-apply the humanized text, preserving the human voice, the Socratic question framing, the calibrated (non-overconfident) wording, factual claims and `UNVERIFIED` hedges, and necessary technical identifiers. If humanize makes an item more assertive, more verbose, more formal, or turns a question into a claim, keep the original wording and make the smallest manual edit needed to remove the AI-sounding phrasing.
- Mark each humanized item `Humanized: yes`.

## Step 11: Output

If `INLINE_MODE=true`, return the full report in chat and do not write a file.

Otherwise write the report to `GITHUB_PR_REVIEW_OVERVIEW.md` at `ORIG_ROOT` (never inside the worktree, which is gone by now). Include the PR number and title in the header so an overwritten file is unambiguous. Treat the file as a working artifact that should not be committed.

End by telling the user: the recommended verdict, the count of findings per severity, the count of threads awaiting your reply, the report path (or that it was returned inline), and that posting is manual — the report's **Manual posting** appendix lists the `gh` commands if they prefer the terminal over the GitHub UI.

## Artifact Lifecycle

- **Produces:** `GITHUB_PR_REVIEW_OVERVIEW.md` at the project root (or an inline reply with `--inline`). A fixed name, overwritten on each run; the header records which PR it covers.
- **Consumed by:** you, when posting the review to GitHub — via the GitHub UI or the report's optional `gh` appendix.
- **Refreshed by:** re-running this skill on the same or a different PR (overwrites the file).
- **Retired by:** `/kramme:workflow-artifacts:cleanup`, or manual deletion.
- **Temporary worktree:** created under a `mktemp` directory during the run and removed in Step 8 unless `--keep-worktree` is set.

## Examples

```text
/kramme:pr:github-review 482
/kramme:pr:github-review https://github.com/acme/app/pull/482
/kramme:pr:github-review               # no arg → lists PRs requesting your review, then asks
/kramme:pr:github-review 482 --code-only
/kramme:pr:github-review 482 --categories a11y,visual
/kramme:pr:github-review 482 --inline --keep-worktree
/kramme:pr:github-review 482 --base release/3.2
/kramme:pr:github-review 482           # ongoing review → also maps existing threads and drafts replies
/kramme:pr:github-review 482 --all-threads --include-bots
/kramme:pr:github-review 482 --fresh   # ignore the conversation; clean first-pass assessment only
```
