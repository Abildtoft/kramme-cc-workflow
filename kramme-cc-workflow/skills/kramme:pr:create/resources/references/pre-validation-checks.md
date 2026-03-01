# Pre-Validation Checks

**ALWAYS perform these checks before proceeding. Abort on any failure.**

## 1.1 Git Repository Check

```bash
git rev-parse --is-inside-work-tree 2>/dev/null
```

**If this fails:**
```
Error: Not inside a git repository.

Navigate to a git project directory and run /kramme:pr:create again.
```
**Action:** Abort immediately.

## 1.2 Merge Conflict Check

```bash
git ls-files -u
```

**If output is non-empty (conflicts exist):**
```
Error: Merge conflict detected.

Conflicted files:
  - [list files from output]

Please resolve these conflicts before creating a PR:
  1. Edit the conflicted files to resolve markers (<<<<<<<, =======, >>>>>>>)
  2. Stage resolved files: git add <resolved-files>
  3. Complete the merge: git commit

Then run /kramme:pr:create again.
```
**Action:** Abort.

## 1.3 Rebase/Merge In Progress Check

Check for these paths:
- `.git/rebase-merge/`
- `.git/rebase-apply/`
- `.git/MERGE_HEAD`

**If any exist:**
```
Error: [Rebase/Merge] operation in progress.

To continue: git [rebase/merge] --continue
To abort: git [rebase/merge] --abort

Resolve the in-progress operation, then run /kramme:pr:create again.
```
**Action:** Abort.

## 1.4 Remote Configuration Check

```bash
git remote get-url origin 2>/dev/null
```

**If no remote configured:**
```
Error: No remote 'origin' configured.

Add a remote first:
  git remote add origin <repository-url>

Then run /kramme:pr:create again.
```
**Action:** Abort.
