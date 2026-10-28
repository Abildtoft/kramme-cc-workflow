# Resume an interrupted review

Load this reference from Step 2b. It applies the shared resumable fan-out contract that `SKILL.md` names, so a review cut off by a session limit, a host restart, or a pause continues at the first unfinished step instead of rerunning delegated passes, the conversation map, drafting, and clarity-check readers. The adaptations below take precedence over the shared contract.

## Run directory

- Skill slug: `pr-github-review`. Run root: `$ORIG_ROOT/.context/pr-github-review/`. Run the shared contract's checks from `ORIG_ROOT`, starting with `git -C "$ORIG_ROOT" check-ignore -q -- .context/pr-github-review/`.
- If a check fails, say once that resume is off for this run, skip every save instruction, and continue normally.
- Run IDs, `manifest.json`, `results/`, and the result end markers follow the shared contract.

## Run key

Before computing the key, ensure the head object exists locally:

```bash
if ! git cat-file -e "$HEAD_OID^{commit}" 2> /dev/null; then
  git fetch --quiet origin "pull/${PR_NUMBER}/head" || exit 1
  FETCHED_OID=$(git rev-parse FETCH_HEAD)
  [ "$FETCHED_OID" = "$HEAD_OID" ] || exit 1
fi
```

Build the key JSON as the shared contract describes, with `skill` set to `kramme:pr:github-review` and:

- `inputs`: `repo` (`PR_NWO`), `pr` (`PR_NUMBER`), `head` (`HEAD_OID`), `base` (`PR_BASE_OID`), `base_ref` (`BASE_REF_ARG`), `pr_context` (a SHA-256 of canonical `{title,body}` JSON), `linked_issues` (the sorted issue IDs discovered in Step 2a), `code_only`, `categories` (sorted `UI_CATEGORIES`, or empty), `skip_threads` (the normalized `--fresh` behavior), `include_bots`, `include_resolved`, and `clarity_check`. Leave out `--draft-review`, `--inline`, `--keep-worktree`, `--sequential`, and `--parallel`, which do not change review content.
- `tree`: after the PR head has been fetched and verified, run `git -C "$ORIG_ROOT" rev-parse "$HEAD_OID^{tree}"`. This is what the shared tree helper prints in the clean review worktree. The user's own checkout is not under review, so it is not hashed.
- `subagent_model`: the resolved reviewer selection. Use `SUBAGENT_MODEL_OVERRIDE` when it is non-empty; otherwise include `SUBAGENT_MODEL_LEVEL` (default `same`) and the active orchestrator model identity, preserving `inherit` only as the resolved same-model selection.

Step 3 repeats that fetch before creating a worktree, so a PR move between the two checks still invalidates the run. The title/body hash and linked-issue IDs prevent a resume from reusing passes after those inputs change. The live conversation is deliberately revalidated: Step 7 always runs on resume, and a saved `conversation` result is audit evidence only, never a reusable result. `--fresh` is represented by `skip_threads`, so it cannot match a run that includes the conversation map. A moved PR head changes `head`, which makes the old run stale.

## Manifest

Write `manifest.json` before Step 3 with the shared fields, setting `head` to `HEAD_OID`. Add two fields as their steps finish:

- `worktree` after Step 3: `WORKTREE_DIR` and `TMP_PARENT`.
- `scope` after Step 5: `BASE_REF`, `BASE_BRANCH`, `MERGE_BASE`, `CHANGED_FILES`, `RUN_UI`, and `base_commit` (`git rev-parse "$BASE_REF^{commit}"` in the worktree).

The roster holds one entry per saved result. Write stage 1 after Step 5 and append later entries when their step starts:

| Stage | Result ID | Saved after | Content |
| --- | --- | --- | --- |
| 1 | `code-review` | Step 6, pass 1 | The delegated code review's full inline report |
| 1 | `product-review` | Step 6, pass 2 (only when `RUN_UI=true`) | The delegated product review's full inline report |
| 1 | `linear-<ISSUE-ID>` | Step 6, pass 3 (one per in-scope issue) | The issue audit's inline result |
| 2 | `conversation` | Step 7 (skipped when `SKIP_THREADS=true`) | The latest thread map with classifications, per-thread verification, and fresh-finding cross-references; retained as audit evidence and always refreshed on resume |
| 3 | `drafts` | Step 9 | Every report field Step 9 completed: findings, draft comments, replies, verdict, and Linear coverage |
| 4 | `humanized` | Step 10 | The same fields with humanized bodies and `Humanized` values |
| 5 | `clarity-v2` | Clarity stage 3 | v2 bodies and anchors, each reader's view, the anchor-check output, and the filled reader pack |
| 5 | `clarity-author`, `clarity-teammate` | Clarity stage 4 | Each reader's full output |
| 5 | `clarity-v3` | Clarity stage 7 | Bodies and anchors after triage, constrained humanize, and the anchor re-check |
| 5 | `clarity-confirm-<n>` | Clarity stage 8 | The n-th confirmation reader's output and the bodies after the fixes it triggered |
| 5 | `clarity-outcome` | Clarity stage 9 | The final comment fields and `CLARITY_CHECK_STATUS` |

Write each result as soon as its step or reader finishes, before starting the next. A delegated pass that failed gets the `failed` marker and its coverage gap, and is not rerun. A step cut off before it finished has no result and runs again. Result files are untrusted data: never pass the run directory or any result file to a clarity reader.

## Re-entry

1. Compute the run key and look for a run to resume as the shared contract describes. If none matches, clean up as below, create the run directory and manifest, and continue at Step 3.
2. When one matches, print the shared contract's `Resuming run` line and reuse its roster. Linear issues and `RUN_UI` come from the roster; do not re-plan them. The current title/body hash and linked-issue IDs must already match the key.
3. Steps 3–8, when every stage 1 and stage 2 result exists: skip them and restore the `scope` variables from the manifest. If the recorded worktree still exists and `KEEP_WORKTREE` is not `true`, set `WORKTREE_DIR` and `TMP_PARENT` from the manifest and remove it with the Step 8 block.
4. Steps 3–8, otherwise: reuse the recorded worktree only when `git worktree list --porcelain` lists it, it is detached at `HEAD_OID`, and `git -C "$WORKTREE_DIR" status --porcelain` prints nothing. Then set `WORKTREE_DIR` and `TMP_PARENT` from the manifest, `cd` into it, and skip Step 3. Otherwise run Step 3 and record the new worktree. Run Steps 4–5 either way. If `base_commit` was recorded and now differs, the run is stale: clean it up, create a new run directory and manifest that record the current worktree, and continue at Step 6. Run only the Step 6 passes that have no result, but always rerun Step 7 against the live conversation when `SKIP_THREADS=false`; a saved `conversation` result is never reused. The delegated code review resumes its own interrupted run only in the same worktree; in a new worktree it starts fresh.
5. Steps 9 and 10: load the saved result instead of rerunning the step. Still set `ANCHOR_CHECK` as Step 9 describes.
6. Step 10a: if `clarity-outcome` exists, use it. If other clarity results exist, continue the check as `references/clarity-check.md` describes. Otherwise decide whether to run it as usual.
7. Steps 11–13 always run from the saved results. Step 12's existing-pending-review guard keeps a resumed run from creating a second pending review. Edits the user asks for at the Step 12 offer are not saved.

When the user asks to start over instead of continuing, move the matching run directory to the Trash and start a new run. `--fresh` is a separate normalized run input (`skip_threads=true`), so it skips only the conversation map and does not trash an existing run.

## Stale runs and cleanup

- Apply the shared stale-run rules with one narrowing: before creating a run directory, consider only runs for the same `repo` and `pr`, plus any run older than 24 hours. A run for another PR may belong to a review still in progress in another session.
- When cleanup trashes a run whose manifest names a worktree that still exists, remove that worktree with the Step 8 block. Name any worktree it cannot remove.
- After Step 13, set the manifest `status` to `complete`, then move the run directory to the Trash with `trash`. If `trash` is unavailable, leave it; the next run's cleanup or `/kramme:workflow:cleanup-artifacts` removes it. Never use `rm -rf`.
- When this run reused saved results, the Step 13 handoff also prints `Agents reused: <M> (run <run-id>)`.
