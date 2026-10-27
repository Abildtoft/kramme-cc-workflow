# Clarity check for draft inline comments

Load this reference from Step 10a. The check tests whether each draft inline comment is understood correctly on the first read by its real audience: the PR author, looking at the anchored line on GitHub, possibly in their second language. It also checks that every factual claim in each comment is true. It does not look for new review issues, and it never writes to GitHub. A request for a clarity check is not authorization to create a pending review.

The check covers every drafted inline comment: each fresh actionable item with a `path:line` location and a `Draft comment` body. Draft replies to existing threads are out of scope. It may change bodies and anchors, and split comments, so Step 11 counts the eligible comments only after it finishes. The Step 12 payload and guards are unchanged.

The flow:

1. Freshness gate: confirm the PR head is still the reviewed head.
2. Reader's view: extract the lines GitHub shows above each comment, and confirm each anchor can take a comment.
3. Self-read and fact check, giving v2.
4. Two cold readers in parallel, one as the author and one as a teammate.
5. Triage and rewrite, giving v3.
6. Constrained humanize of the changed bodies.
7. Anchor re-check.
8. Confirmation read by one new reader, giving v4.
9. Record the outcome for Step 11.

After each stage, save its result as `references/resume.md` describes. When a resumed review re-enters the check, run the stage 1 gate first, then start at the first stage without a saved result. A reader whose output is saved is not rerun. A reader cut off before it returned is relaunched as a new reader with the saved filled prompt, and a confirmation read always uses a new reader. Readers never receive the run directory or any saved result, and every rule under Readers still applies.

## Readers

- Launch each reader through the host's agent-invocation mechanism, passing only its filled prompt from `references/clarity-check-prompts.md`: no conversation history, no report, and no review evidence. A reader who knows your intent tests nothing. On Codex, spawn it with `fork_turns="none"`, because a full-history fork would hand it the conversation.
- Launch readers on the session's model. `--subagent-model` and `KRAMME_REVIEW_SUBAGENT_LEVEL` select reviewer models and do not apply to readers.
- Run the stage 1 freshness gate again right before launching any reader.
- If the host cannot launch an agent without the conversation history, do not run the check. Set `CLARITY_CHECK_STATUS="not run — host cannot launch isolated readers"` and continue to Step 11. Never simulate a reader in your own context.
- If a reader stops on a rate limit such as HTTP 429, wait, then resume that same agent where the host supports it (on Claude Code, `SendMessage` with its agent ID) instead of starting a new reader. Resume a reader at most three times; then stop the check with `incomplete — <stage>: reader rate-limited`.

## 1. Freshness gate

```bash
if ! CURRENT_HEAD_OID=$(gh pr view "$PR_NUMBER" --repo "$PR_NWO" --json headRefOid -q .headRefOid); then
  echo "Clarity check stopped: could not re-read the PR head." >&2
elif [ "$CURRENT_HEAD_OID" != "$HEAD_OID" ]; then
  echo "Clarity check stopped: the PR head moved from $HEAD_OID to $CURRENT_HEAD_OID. Re-run the review against the new head." >&2
elif [ "$(git -C "$ORIG_ROOT" cat-file -t "$HEAD_OID" 2> /dev/null)" != "commit" ]; then
  echo "Clarity check stopped: the reviewed head $HEAD_OID is not in the local object store." >&2
else
  echo "PR head unchanged: $HEAD_OID"
fi
```

Run this gate now, again right before launching any reader, and once more in stage 9. When it stops the check at this stage, set `CLARITY_CHECK_STATUS` to `not run — <reason>` and continue to Step 11 with the drafts unchanged. When it stops a later stage, set `incomplete — <reason>`, keep the last verified version of each body, and continue to Step 11. A moved head makes every line number and claim stale; Step 12's head guards still block a pending review for the old head.

Read code only with `git -C "$ORIG_ROOT" show "$HEAD_OID:<path>"`. The review worktree is usually gone, and the local checkout can lag the PR head.

## 2. Build the reader's view

GitHub shows a comment directly under its anchored line. The author sees that line and the lines above it, never the lines below. For each comment, extract the anchor line and the seven lines above it, with the anchor marked `>`:

```bash
git -C "$ORIG_ROOT" show "$HEAD_OID:$path" | awk -v s=$((line - 7)) -v n="$line" \
  'NR >= s && NR <= n { printf "%5d%s %s\n", NR, (NR == n ? " >" : "  "), $0 }'
```

Then confirm that every anchor can take a comment, passing all anchors in one call:

```bash
"$ANCHOR_CHECK" "$ORIG_ROOT" "$PR_BASE_OID" "$HEAD_OID" path/a.ts:12 path/b.tsx:80
```

GitHub accepts a comment only on an added or context line of the PR diff. The script diffs from the merge base of the two commits to the head, as GitHub does, and prints `ok`, `NOT-IN-DIFF`, or `NO-LINE` with each `path:line` and the text of that line at the head. It accepts only full commit IDs, so a branch name or `HEAD` cannot silently check an older commit of the same branch. Move a failing anchor to the changed line where the fix belongs, or keep it and let Step 11 list it as an omission. If the script exits with status 2, read its message. Fix a malformed anchor and run it again. If a commit is missing or Git fails, continue without the anchor check and note `anchor check unavailable` in `CLARITY_CHECK_STATUS`.

Every "this", "here", "it", or "the field" in a body must point at something in the view. If it doesn't, move the anchor to the line the comment is about, or name the thing. For example, a comment anchored on `throw new ArgumentException(` said "this message", but the string was two lines below the anchor. The anchor moved to the string's line.

## 3. Self-read and fact check (v2)

Reread each body against its view and apply every rule in Section 1 of `references/comment-drafting.md` again. Then re-verify each factual claim in the code at `HEAD_OID` and cite the `path:line` that supports it in `Evidence`. Fix or drop a claim the code does not support. The result is v2.

## 4. Two cold readers in parallel

Build one reader pack from v2, as `references/clarity-check-prompts.md` describes, and launch the author and teammate readers in the same message so they run in parallel.

| Persona | Who they are | What they catch |
| --- | --- | --- |
| Author | Wrote the code and has not seen your notes. English is their second language. May read code at the head. | Factual errors against code they own; fixes that are incomplete or would not work |
| Teammate | Knows the repository but not this PR, and reads the thread a day later. Records every lookup. | Comments that don't stand alone, ambiguous references, jargon, two-file comments |

The paraphrase is the main signal; scores are subjective. A paraphrase that differs from the ask you intended proves the comment can be misread.

## 5. Triage and rewrite (v3)

Verify every point a reader raises in the code at the head before you adopt it. Readers can be wrong too. Then act on the signals in this order:

| Reader signal | Action | Priority |
| --- | --- | --- |
| One reading of the comment would make the author do harm, such as deleting code that must stay | Rewrite it to name what changes **and** what stays | 1 |
| A claim looks wrong | Check the code; fix or drop the claim; record the correction in `Evidence` | 2 |
| The proposed fix is incomplete, for example one test case cannot guard two implementations | Widen the ask precisely | 2 |
| The reader needed code outside the view | Name the file, symbol, and line, or move the anchor | 3 |
| Two files or two concerns in one comment | Split it, and anchor each part where its fix belongs | 3 |
| A promised side benefit is debatable | Remove it | 3 |
| Idiom, long clause, or phrasal verb | Rephrase | 4 |

Give each part of a split comment its own `Location`, `Refers to`, and `Evidence`. Hedge a claim about framework behavior that you cannot confirm in the repository's own source or with a run. For example, if you have not seen a test run show that React logs "Invalid hook call" and then throws a `TypeError`, say only that every test in the file breaks.

Record corrected facts in this skill's report. Never edit a sealed upstream artifact, such as the delegated code review's report, because changing its bytes breaks its seal check. The result is v3.

## 6. Constrained humanize

Send only the bodies changed since Step 10 to `/kramme:text:clarify --humanize` in one indexed batch, following Section 3 of `references/comment-drafting.md`, with these stricter constraints:

- keep identifiers and code spans exact, as well as the question framing, the claims, and the stated consequence;
- add no length;
- never replace an explicit reference with a pronoun.

Map the results back by index. Reject any output that drops a clarifying detail or is longer than the body you sent.

## 7. Anchor re-check

Run `"$ANCHOR_CHECK"` again on the final set of anchors, and compare each printed line with what its comment is about. Moved and new anchors matter most.

## 8. Confirmation read (v4)

Build a new pack from the current bodies and anchors, and run one **new** reader with the confirmation prompt. Never reuse an earlier reader, because it has seen the old wording.

- **Stop rule:** every comment scores 4 or more, and no paraphrase misses the intent.
- Otherwise fix every comment that scores 3 or lower or whose paraphrase misses the intent, plus any cheap fixes for the 4s, and verify any new claim the fixes introduce. Humanize the changed bodies as in stage 6, and check moved anchors as in stage 7.
- Then have another new reader re-read only the comments you changed. Repeat until the stop rule holds, for at most two re-reads. If it still fails, keep the best version of each failing comment and set `CLARITY_CHECK_STATUS` to `incomplete — stop rule not met after two re-reads: <comments and scores>`.

## 9. Record the outcome

Update each comment's `Draft comment`, `Location`, `Refers to`, `Evidence`, `Humanized`, and `Clarity` fields. If a corrected fact disproves or weakens a finding, drop it or move it to the section that now fits, name that change in `CLARITY_CHECK_STATUS`, and apply the verdict criteria in Section 2 of `references/comment-drafting.md` again.

When the stop rule holds, set `CLARITY_CHECK_STATUS` to one line naming the readers that ran, the final scores, and the facts corrected, for example `complete — author and teammate on v2, confirmation on v3; 13 of 14 at 4–5, one 3 fixed and re-read; 3 claims corrected`. Otherwise keep the `incomplete — ...` status that the failing stage set.

Before you continue to Step 11, check that:

- each comment has exactly one `Draft comment` body, and each part of a split comment has its own;
- each `Humanized` value matches what happened to its final body;
- no body contains escape characters such as `\!`, or report-only IDs such as `CR-001` or `ENG-217/LREQ-001`;
- the stage 1 gate still passes. If it stops, set `CLARITY_CHECK_STATUS` to `incomplete — PR head moved during the check; re-run the review`, or to the reason it printed.
