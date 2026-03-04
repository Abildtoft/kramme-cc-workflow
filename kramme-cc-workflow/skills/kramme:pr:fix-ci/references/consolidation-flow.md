# Consolidation Phase (Step 10)

**Skip this step if:** `--fixup` mode was used, or `--no-consolidate` flag is set.

When all CI checks pass and no unaddressed feedback remains, offer to consolidate the `[FIX PIPELINE]` commits into the original branch commits.

## Step 10.1: Detect [FIX PIPELINE] Commits

Determine the base branch (reuse logic from fixup-flow.md Step 7b.1) and find pipeline fix commits:

```bash
# GitHub
BASE=$(gh pr view --json baseRefName --jq .baseRefName)

# GitLab
BASE=$(glab mr view --json target_branch --jq .target_branch)

BASE_REF="origin/$BASE"
git fetch origin $BASE

# Find [FIX PIPELINE] commits
FIX_COMMITS=$(git log $BASE_REF..HEAD --format="%H %s" | grep "\[FIX PIPELINE\]")
```

If no `[FIX PIPELINE]` commits exist, skip to success exit.

## Step 10.2: Prompt for Consolidation

Present the user with a summary and options:

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

**If user selects "Keep separate":**
```
Keeping [FIX PIPELINE] commits as separate commits.

Tip: When merging the PR, consider using "Squash and merge" to combine all commits.
Alternatively, run /kramme:git:recreate-commits to rewrite the branch later.
```
Exit successfully.

**If user selects "Automated":** Continue with Steps 10.3–10.5, then 10.7–10.8.

**If user selects "Interactive":** Skip to Step 10.6, then 10.7–10.8.

> **Note:** Interactive mode opens a text editor and requires a terminal environment. It won't work in non-interactive contexts like automated pipelines or some IDE integrations.

## Step 10.3: Map [FIX PIPELINE] Commits to Targets

For each `[FIX PIPELINE]` commit, determine which original commit it should be folded into:

```bash
# Get all commits on the branch
ALL_COMMITS=$(git log $BASE_REF..HEAD --format="%H %s" --reverse)

# Separate original commits from [FIX PIPELINE] commits
ORIGINAL_COMMITS=$(echo "$ALL_COMMITS" | grep -v "\[FIX PIPELINE\]")
FIX_COMMITS=$(echo "$ALL_COMMITS" | grep "\[FIX PIPELINE\]")

# For each [FIX PIPELINE] commit, find its target
for FIX_SHA in $(echo "$FIX_COMMITS" | cut -d' ' -f1); do
  # Get files changed in this [FIX PIPELINE] commit
  CHANGED_FILES=$(git diff-tree --no-commit-id --name-only -r $FIX_SHA)

  # Find the most recent original commit that touched any of these files
  TARGET=""
  for FILE in $CHANGED_FILES; do
    CANDIDATE=$(git log $BASE_REF..HEAD --format="%H" -- "$FILE" | \
      while read SHA; do
        if ! git log -1 --format="%s" $SHA | grep -q "\[FIX PIPELINE\]"; then
          echo $SHA
          break
        fi
      done)
    if [ -n "$CANDIDATE" ]; then
      TARGET=$CANDIDATE
      break
    fi
  done

  if [ -z "$TARGET" ]; then
    # Orphan: files only exist in [FIX PIPELINE] commits
    # These will be left as regular commits at the end
    echo "orphan:$FIX_SHA"
  else
    echo "$TARGET:$FIX_SHA"
  fi
done
```

Build a mapping: `{target_sha: [fix_sha1, fix_sha2, ...]}`

## Step 10.4: Generate Rebase Sequence

Create a rebase todo that:
1. Places each `[FIX PIPELINE]` commit immediately after its target
2. Marks `[FIX PIPELINE]` commits as `fixup` instead of `pick`
3. Leaves orphan commits at the end as regular `pick` commits

```bash
# Generate the rebase sequence
git log $BASE_REF..HEAD --format="%H %s" --reverse | while read SHA MSG; do
  if echo "$MSG" | grep -q "\[FIX PIPELINE\]"; then
    # This is a [FIX PIPELINE] commit - will be handled when we see its target
    continue
  fi

  # Print the original commit
  echo "pick $SHA $MSG"

  # Print any [FIX PIPELINE] commits that target this one
  for FIX_SHA in $(get_fixes_for_target $SHA); do
    FIX_MSG=$(git log -1 --format="%s" $FIX_SHA)
    echo "fixup $FIX_SHA $FIX_MSG"
  done
done

# Append orphan commits at the end (keep as regular commits)
for ORPHAN_SHA in $ORPHAN_COMMITS; do
  ORPHAN_MSG=$(git log -1 --format="%s" $ORPHAN_SHA | sed 's/\[FIX PIPELINE\] //')
  echo "pick $ORPHAN_SHA $ORPHAN_MSG"
done
```

## Step 10.5: Execute Rebase (Automated)

Save the generated sequence to a temp file and use it as the sequence editor:

```bash
# Write sequence to temp file
SEQUENCE_FILE=$(mktemp)
# ... write generated sequence to $SEQUENCE_FILE ...

# Run rebase with custom sequence
GIT_SEQUENCE_EDITOR="cat $SEQUENCE_FILE >" git rebase -i $BASE_REF

rm $SEQUENCE_FILE
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
   > - Resolve manually with interactive rebase
   > - Keep commits as-is and squash-merge the PR
   > - Run `/kramme:git:recreate-commits` for a complete rewrite

3. Exit without force push

## Step 10.6: Execute Rebase (Interactive)

For interactive mode, open the editor so the user can manually arrange commits:

```bash
git rebase -i $BASE_REF
```

The user can then:
- Move `[FIX PIPELINE]` commits next to their targets
- Change `pick` to `fixup` or `squash`
- Drop unwanted commits
- Reorder as needed

After the user saves and closes the editor, git will execute the rebase.

## Step 10.7: Force Push

After successful rebase:

```bash
git push --force-with-lease origin $(git branch --show-current)
```

## Step 10.8: Confirm Success

```
Successfully consolidated [FIX PIPELINE] commits!

Updated commit history:
  abc1234 Original feature implementation (now includes pipeline fixes)
  def5678 Add tests (now includes pipeline fixes)

The [FIX PIPELINE] changes have been absorbed into the original commits.
```
