# Review only what changed since your last review

Load this reference from Step 4a. It decides whether this run reviews the whole Pull Request, only the commits that changed since your last review, or no code at all because nothing in this Pull Request changed. The helper reads your reviews from GitHub and may fetch your last reviewed commit by object ID. It writes nothing to GitHub.

Your last review is the newest review you submitted that looked at code: an approval, a change request, a dismissed review, or a comment review with a summary body. GitHub records every single comment and thread reply as a comment review with no body, so those never count. A commit is unchanged when its whitespace-preserving patch matches a commit in the version of this Pull Request you last reviewed, which is how a rebase or restack is told apart from new work. Removed or replaced reviewed patches require a full review.

## 1. Compare with your last review

Run this from the worktree. A restack rewrites every commit above the trunk, so the comparison needs the branch the stack merges into; for an unstacked Pull Request that is its own base.

```bash
TRUNK_REF="$BASE_REF"
TRUNK=$(printf '%s' "$STACK_CONTEXT" | jq -r 'select(.state == "stacked") | .trunk // empty')
DELTA_JSON='{"scope":"full","reason":"the stack trunk could not be resolved","last_review":null,"commits":[]}'
if [ -z "$TRUNK" ] || TRUNK_JSON=$("$RESOLVE_BASE" --base "$TRUNK" --strict --format json); then
  if [ -n "$TRUNK" ]; then
    TRUNK_REF=$(printf '%s' "$TRUNK_JSON" | jq -r '.base_ref')
  fi
  DELTA_JSON=$(python3 "$REVIEW_DELTA" --repo "$PR_NWO" --pr "$PR_NUMBER" --self "$SELF" \
    --head "$HEAD_OID" --base "$MERGE_BASE" --trunk "$TRUNK_REF") \
    || DELTA_JSON='{"scope":"full","reason":"the re-review helper failed","last_review":null,"commits":[]}'
fi
REVIEW_SCOPE=$(printf '%s' "$DELTA_JSON" | jq -r '.scope')
```

The helper prints one JSON document with `scope`, a one-sentence `reason`, `last_review` (`id`, `state`, `submitted_at`, `commit`), `review_base`, `commits` (this Pull Request's commits, oldest first, each `changed` or `unchanged`), `dropped` (commits from your last reviewed version whose patch is gone), and `lower_layers_changed`. Every failure falls back to `full`, never to a smaller scope.

## 2. Apply the scope

| `scope` | This run reviews |
| --- | --- |
| `first` or `full` | The whole Pull Request. Keep `REVIEW_BASE="$BASE_REF"` and `CHANGED_FILES`. |
| `delta` | Only the commits after `review_base`. Set `REVIEW_BASE` to it and collect the changed files below. |
| `unchanged` | No code. Steps 5–6 skip the code and UI passes. The Linear pass and the Step 7 conversation map still run. |

For `delta`, collect the delta's changed files with the shared collector so Step 5 classifies only them. Run it in a subshell, so `BASE_REF` and `MERGE_BASE` keep the whole Pull Request's scope for the Linear pass:

```bash
if [ "$REVIEW_SCOPE" = delta ]; then
  REVIEW_BASE=$(printf '%s' "$DELTA_JSON" | jq -r '.review_base')
  if DELTA_FILES=$(RESOLVED=$("$COLLECT_REVIEW_DIFF" --base "$REVIEW_BASE" --strict) \
    && eval "$RESOLVED" && printf '%s' "$CHANGED_FILES") && [ -n "$DELTA_FILES" ]; then
    CHANGED_FILES="$DELTA_FILES"
  else
    REVIEW_SCOPE=full
    REVIEW_BASE="$BASE_REF"
  fi
fi
```

A full commit object ID as `--base` pins that commit without fetching, so the delegated reviews in Step 6 cover exactly the commits after it.

## 3. Report the scope

Fill the report's `Review scope` line:

- `first`: `whole PR (first review)`
- `full`: `whole PR (<reason>)`, or `whole PR (--full)` and `whole PR (--fresh)` when Step 4a did not run for that flag
- `delta`: `changes since your last review at <short commit>: <changed> of <total> commits`
- `unchanged`: `no code changed since your last review at <short commit> (<reason>)`

When `last_review` is set, fill `## Since Your Last Review` from `DELTA_JSON`: the review's state, date, and commit; the scope and its reason; each commit with its status; any dropped commits; and these notes when they apply:

- For `delta` and `unchanged`: commits whose patch matches your last review count as already reviewed. That includes commits a restack re-applied unchanged, and a commit that was the top of the layer below at your last review and has since moved into this Pull Request.
- When `lower_layers_changed` is true: the code below this Pull Request changed since your last review. Unchanged commits here were not reviewed again against it; re-run with `--full` if those changes could affect this Pull Request.
- Always: `--full` reviews the whole Pull Request.
