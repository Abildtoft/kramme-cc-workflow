# Consolidation Phase (Step 11)

**Skip this step if:** `--fixup` mode was used, or `--no-consolidate` flag is set.

When all CI checks pass and no unaddressed feedback remains, offer to consolidate the `[FIX PIPELINE]` commits into the original branch commits.

If `AUTO_MODE=true`, do not offer "Keep separate". Before any automated rebase, confirm one of these is true:

- The branch is not shared.
- The user explicitly confirmed collaborators are coordinated for a history rewrite.

If neither can be confirmed safely, stop with `MISSING REQUIREMENT: automated consolidation rewrites history; confirm collaborator coordination or rerun with --no-consolidate`. Do not rebase, force-push, or silently preserve separate fix commits.

## Step 11.1: Detect [FIX PIPELINE] Commits

Determine the base branch (reuse logic from fixup-flow.md Step 8b.1) and find pipeline fix commits:

```bash
BASE=$(gh pr view --json baseRefName --jq .baseRefName)

BASE_REF="origin/$BASE"
git fetch origin "$BASE"

# Find [FIX PIPELINE] commits
FIX_COMMITS=$(git log "$BASE_REF..HEAD" --format="%H %s" | grep "\[FIX PIPELINE\]")
```

If no `[FIX PIPELINE]` commits exist, skip to success exit.

## Step 11.2: Choose Consolidation Mode

If `AUTO_MODE=true`, apply the pre-rebase safety gate above, then select **Automated** and continue with Steps 11.3-11.5, then 11.7-11.8. Do not prompt and do not keep `[FIX PIPELINE]` commits separate as an automatic fallback.

Otherwise, present the user with a summary and options:


```
CI checks passed! Found N [FIX PIPELINE] commits:

  abc1234 [FIX PIPELINE] Fix lint errors in user-service.ts
  def5678 [FIX PIPELINE] Add missing test assertion
  ghi9012 [FIX PIPELINE] Update dependency version

How would you like to handle these commits?

Options:
  1. Automated - Consolidate automatically (rewrites history, requires force push)
  2. Interactive - Open rebase editor to manually arrange commits (requires terminal)
  3. Keep separate - Leave as-is (can squash-merge the PR later)
```

If the branch is shared, only offer options 1 or 2 after the user explicitly confirms collaborators are coordinated for a history rewrite. Otherwise steer them to option 3.

**If user selects "Keep separate":**

```
Keeping [FIX PIPELINE] commits as separate commits.

Tip: When merging the PR, consider using "Squash and merge" to combine all commits.
Alternatively, run /kramme:git:recreate-commits to rewrite the branch later.
```

Exit successfully.

**If user selects "Automated":** Continue with Steps 11.3–11.5, then 11.7–11.8.

**If user selects "Interactive":** Skip to Step 11.6, then 11.7–11.8.

> **Note:** Interactive mode opens a text editor and requires a terminal environment. It won't work in non-interactive contexts like automated pipelines or some IDE integrations.

## Step 11.3: Map [FIX PIPELINE] Commits to Targets

For each `[FIX PIPELINE]` commit, determine which original commit it should be folded into. Implement this as a short helper script in your scratch dir and store the result as a mapping `target_sha -> [fix_sha, ...]` plus a separate orphan list.

Algorithm:

1. List all branch commits in order:
   ```bash
   git log "$BASE_REF..HEAD" --format="%H %s" --reverse
   ```
   Split into `ORIGINAL_COMMITS` (subject does **not** start with `[FIX PIPELINE]`) and `FIX_COMMITS` (subject does).
2. For each `FIX_SHA` in `FIX_COMMITS`:
   1. Get the files it changed:
      ```bash
      git diff-tree --no-commit-id --name-only -r "$FIX_SHA"
      ```
   2. For each of those files, walk `git log "$BASE_REF..HEAD" --format=%H -- "$FILE"` from newest to oldest and stop at the first SHA whose subject does NOT start with `[FIX PIPELINE]`. That SHA is the candidate target.
   3. Use the first candidate found across the files as the target. If no candidate exists (the fix only touches files no original commit touched), mark `FIX_SHA` as an orphan.
3. Persist the mapping and orphan list for Step 11.4 (e.g., as two JSON files in your scratch dir).

## Step 11.4: Generate Rebase Sequence

Using the mapping and orphan list from Step 11.3, produce a rebase todo file with these rules:

1. For each original commit in branch order, write `pick <sha> <subject>`.
2. Immediately after each original commit, write `fixup <fix_sha> <fix_subject>` for every `[FIX PIPELINE]` commit mapped to it.
3. At the end, write `pick <orphan_sha> <orphan_subject>` for each orphan (strip the `[FIX PIPELINE] ` prefix from the subject so the final history reads cleanly).

Write the result to a temp file you control (`$(mktemp)`) and pass it to Step 11.5.

## Step 11.5: Execute Rebase (Automated)

Save the generated sequence to a temp file and use it as the sequence editor:

```bash
# Write sequence to temp file
SEQUENCE_FILE=$(mktemp)
# ... write generated sequence to $SEQUENCE_FILE ...

# Run rebase with custom sequence
GIT_SEQUENCE_EDITOR="cat \"$SEQUENCE_FILE\" >" git rebase -i "$BASE_REF"

rm "$SEQUENCE_FILE"
```

**If rebase fails (conflicts):**

1. Abort the rebase:

   ```bash
   git rebase --abort
   ```

2. Inform user:

   > "Consolidation failed due to conflicts. Your `[FIX PIPELINE]` commits are preserved on the branch."
   >
   > "Options:"
   >
   > - Resolve manually with interactive rebase
   > - Keep commits as-is and squash-merge the PR
   > - Run `/kramme:git:recreate-commits` for a complete rewrite

3. Exit without force push

## Step 11.6: Execute Rebase (Interactive)

For interactive mode, open the editor so the user can manually arrange commits:

```bash
git rebase -i "$BASE_REF"
```

The user can then:

- Move `[FIX PIPELINE]` commits next to their targets
- Change `pick` to `fixup` or `squash`
- Drop unwanted commits
- Reorder as needed

After the user saves and closes the editor, git will execute the rebase.

## Step 11.7: Force Push

After successful rebase, confirm one of these is true before pushing:

- The branch is not shared.
- The user explicitly confirmed collaborators are coordinated for a history rewrite.

If neither is true, stop here. Keep the rebased result local and tell the user not to push it yet. In interactive/default mode, recommend either coordinating first or resetting back to the pre-consolidation state and choosing "Keep separate". In `AUTO_MODE`, stop with `MISSING REQUIREMENT` instead of recommending "Keep separate".

If one of those conditions is true:

```bash
git push --force-with-lease origin "$(git branch --show-current)"
```

## Step 11.8: Confirm Success

```
Successfully consolidated [FIX PIPELINE] commits!

Updated commit history:
  abc1234 Original feature implementation (now includes pipeline fixes)
  def5678 Add tests (now includes pipeline fixes)

The [FIX PIPELINE] changes have been absorbed into the original commits.
```
