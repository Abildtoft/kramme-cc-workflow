---
name: kramme:git:recreate-commits
description: Use when asked to recreate commits with narrative-quality history on the current branch.
disable-model-invocation: false
user-invocable: true
---

Reimplement the current branch with a clean, narrative-quality git commit history suitable for reviewer comprehension. By default, recreate commits on the current branch (not a new clean branch).

**Flags:**
- `--auto` — Skip the granularity question and automatically choose the best granularity based on diff size and complexity.
- `--granular` — Force atomic-level decomposition. Skips the granularity question. Use for very large PRs where 100+ commits are appropriate.
- `--base <branch>` — Use `<branch>` as the base instead of auto-detecting. Without this flag, the skill tries to detect the base from an existing GitHub or GitLab pull request, then falls back to `master`/`main`.
- `--after <commit>` — Only recreate commits after `<commit>`, keeping all earlier history intact. Accepts any valid git ref (SHA, short SHA, `HEAD~3`, etc.). The commit must exist and be an ancestor of `HEAD`. When set, the diff scope becomes `<commit>..HEAD` and the reset point becomes `<commit>` instead of the merge base.

## Steps

1. **Validate the source branch**
   - **Determine the base branch** using the first method that succeeds:
     1. **Explicit flag:** If `--base <branch>` was passed, store it as `BASE_REF` and use that ref.
     2. **PR metadata:** If no `--base` flag, try to detect the target branch from an existing pull request:
        - **GitHub:** `BASE_BRANCH=$(gh pr view --json baseRefName --jq '.baseRefName')`
        - **GitLab:** `BASE_BRANCH=$(glab mr view "$(git branch --show-current)" -F json | python3 -c 'import json,sys; print(json.load(sys.stdin)["target_branch"])')`
        - If GitLab branch lookup fails, find the pull request IID first with `PR_IID=$(glab mr list --source-branch "$(git branch --show-current)" -F json | python3 -c 'import json,sys; data=json.load(sys.stdin); print(data[0]["iid"] if data else "")')`, then run `BASE_BRANCH=$(glab mr view "$PR_IID" -F json | python3 -c 'import json,sys; print(json.load(sys.stdin)["target_branch"])')`.
        - If one of these commands succeeds and assigns a non-empty branch name, use it. If `gh`/`glab` is not installed, no PR exists, or the command fails, fall through silently to the next method.
     3. **Fallback:** If no pull request metadata is available, set `BASE_BRANCH` explicitly:
        ```bash
        BASE_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
        if [ -z "$BASE_BRANCH" ]; then
          BASE_BRANCH=$(git branch -r | grep -E 'origin/(main|master)$' | head -1 | sed 's@.*origin/@@')
        fi
        if [ -z "$BASE_BRANCH" ]; then
          echo "Could not determine base branch; expected origin/HEAD, origin/main, or origin/master" >&2
          exit 1
        fi
        ```
   - If `BASE_BRANCH` was detected from PR metadata or fallback, normalize it before building `origin/<base-branch>`:
     ```bash
     BASE_BRANCH=${BASE_BRANCH#refs/heads/}
     BASE_BRANCH=${BASE_BRANCH#refs/remotes/origin/}
     BASE_BRANCH=${BASE_BRANCH#origin/}
     if [ -z "$BASE_BRANCH" ]; then
       echo "Could not determine base branch" >&2
       exit 1
     fi
     if ! git check-ref-format --branch "$BASE_BRANCH" >/dev/null 2>&1; then
       echo "Base branch '$BASE_BRANCH' is not a valid branch name" >&2
       exit 1
     fi
     if ! git fetch origin "refs/heads/${BASE_BRANCH}:refs/remotes/origin/${BASE_BRANCH}"; then
       echo "Failed to fetch origin/$BASE_BRANCH" >&2
       exit 1
     fi
     if ! git rev-parse --verify --quiet "origin/$BASE_BRANCH" >/dev/null; then
       echo "Base branch 'origin/$BASE_BRANCH' not found" >&2
       exit 1
     fi
     BASE_REF="origin/$BASE_BRANCH"
     ```
   - If `BASE_REF` came from `--base`, resolve it before continuing:
     ```bash
     if ! git rev-parse --verify --quiet "$BASE_REF^{commit}" >/dev/null; then
       case "$BASE_REF" in
         refs/remotes/*/*)
           BASE_REMOTE=${BASE_REF#refs/remotes/}
           BASE_REMOTE=${BASE_REMOTE%%/*}
           BASE_BRANCH=${BASE_REF#refs/remotes/${BASE_REMOTE}/}
           ;;
         refs/heads/*)
           BASE_REMOTE=origin
           BASE_BRANCH=${BASE_REF#refs/heads/}
           ;;
         */*)
           BASE_REMOTE=${BASE_REF%%/*}
           BASE_BRANCH=${BASE_REF#*/}
           if ! git remote get-url "$BASE_REMOTE" >/dev/null 2>&1; then
             echo "Explicit base ref '$BASE_REF' does not resolve locally and does not name a configured remote" >&2
             exit 1
           fi
           ;;
         *)
           BASE_REMOTE=origin
           BASE_BRANCH=$BASE_REF
           ;;
       esac

       if ! git check-ref-format --branch "$BASE_BRANCH" >/dev/null 2>&1; then
         echo "Explicit base ref '$BASE_REF' is not a valid branch name or ref" >&2
         exit 1
       fi
       if ! git fetch "$BASE_REMOTE" "refs/heads/${BASE_BRANCH}:refs/remotes/${BASE_REMOTE}/${BASE_BRANCH}"; then
         echo "Failed to fetch ${BASE_REMOTE}/${BASE_BRANCH} for explicit base ref '$BASE_REF'" >&2
         exit 1
       fi
       BASE_REF="refs/remotes/${BASE_REMOTE}/${BASE_BRANCH}"
     fi
     ```
   - **Validate the resolved base ref** (regardless of how it was determined):
     - Verify `BASE_REF` resolves to a commit (`git rev-parse --verify --quiet "$BASE_REF^{commit}"`). Abort with a clear error if it does not.
     - Verify the current branch is not the selected base branch or ref.
     - Verify there is a merge base with `HEAD` (`git merge-base "$BASE_REF" HEAD >/dev/null`). Abort if the histories are unrelated.
   - **Validate `--after <commit>`** (if provided):
     - Resolve the commit ref: `AFTER_COMMIT=$(git rev-parse --verify "$AFTER_ARG^{commit}")`. Abort with a clear error if it does not resolve.
     - Verify it is an ancestor of `HEAD`: `git merge-base --is-ancestor "$AFTER_COMMIT" HEAD`. Abort if not.
   - If the current branch equals the base branch, stop and ask the user to switch to a feature branch first.
   - **Fetch and optionally update the local base branch** so it matches the remote when `BASE_REF` maps to `origin/<base-branch>` and a local branch exists:
     ```bash
     if [ -n "$BASE_BRANCH" ] && { [ "$BASE_REF" = "origin/$BASE_BRANCH" ] || [ "$BASE_REF" = "refs/remotes/origin/$BASE_BRANCH" ]; } && git show-ref --verify --quiet "refs/remotes/origin/${BASE_BRANCH}"; then
       git fetch origin "refs/heads/${BASE_BRANCH}:refs/remotes/origin/${BASE_BRANCH}"
       if git show-ref --verify --quiet "refs/heads/${BASE_BRANCH}"; then
         git checkout "${BASE_BRANCH}"
         git merge --ff-only "origin/${BASE_BRANCH}"
         git checkout -  # return to feature branch
       fi
     fi
     ```
     If the fast-forward merge fails (local base branch has diverged from remote), abort and ask the user to resolve manually before retrying.
   - Ensure the current branch has no merge conflicts, uncommitted changes, or other issues.
   - Confirm it is up to date with the selected base ref.

2. **Analyze the diff**
   - If `--after` was provided, study the diff from `AFTER_COMMIT..HEAD`. Otherwise, study all changes between the current branch and `BASE_REF` from their merge base.
   - Form a clear understanding of the final intended state.

3. **Prepare the branch**
   - By default, work on the current branch. Do NOT create a `{branch_name}-clean` branch unless explicitly requested.
   - If explicitly asked to use a clean branch, create `{branch_name}-clean` from `AFTER_COMMIT` (if `--after` was provided) or from the merge base with `BASE_REF`.

4. **Plan the commit storyline**

   **Assess diff size and determine granularity.** After analyzing the diff, assess whether the PR is large (many files changed, significant lines added/removed, multiple distinct features or areas touched).

   If `--granular` was passed, use **Atomic** granularity unconditionally — do not ask the user. If `--auto` was passed (without `--granular`), choose the most appropriate granularity yourself based on diff size and complexity — do not ask the user. Otherwise, if the diff is large, ask the user which granularity level they want before planning:

   - **Coarse** — One commit per major grouping (~5-15 commits)
   - **Medium (recommended)** — Break each major grouping into several commits (~15-30 commits)
   - **Fine** — Recursively break down until each commit is a significant, self-standing change (~30-60+ commits)
   - **Atomic** — Deepest possible decomposition. Each commit introduces exactly one logical addition: a single function, type, config entry, import block, or test case. There is no upper bound on commit count — 100, 200, or 300+ commits are all acceptable if the diff warrants it.

   For normal-sized PRs (without `--auto`), skip this question and plan as usual.

   **Use recursive decomposition to plan commits:**

   1. **First pass:** Identify the major groupings of work (e.g., "add auth middleware", "implement user API", "add tests"). For **coarse** granularity, stop here — each grouping becomes one commit.
   2. **Second pass:** Break each major grouping into sub-steps (e.g., "add auth middleware" becomes: add dependencies, implement token validation, add middleware registration, add config). For **medium** granularity, stop here.
   3. **Third pass (fine only):** Selectively break sub-steps further, but only where a piece is a significant, self-standing addition (e.g., a substantial new function or module). Do not split trivial one-liner changes or tightly coupled changes that belong together.
   4. **Fourth pass (atomic only):** Continue decomposing every sub-step until each commit adds exactly one function, one type definition, one config block, one import group, or one test case. Do NOT self-limit or cap the commit count. If the diff is large enough to warrant 150, 200, or 300+ commits, produce that many. The goal is tutorial-granularity: a reviewer should be able to read each commit in under 30 seconds. The only reason to stop splitting is when a change is truly indivisible (e.g., a single-line fix, or two lines that are syntactically dependent).

   Flatten the tree into a linear commit sequence that tells a coherent narrative — each step should reflect a logical stage of development, as if writing a tutorial.

5. **Reimplement the work**
   - If `--after` was provided, reset the branch to `AFTER_COMMIT`. Otherwise, reset the branch to the merge base with `BASE_REF`.
   - Recreate the changes, committing step by step according to your plan.
   - Each commit must:
     - Introduce a single coherent idea.
     - Include a clear commit message and description.
     - Add comments or inline GitHub comments when needed to explain intent.

6. **Verify correctness**
   - Confirm that the final state of the branch exactly matches the final intended state (same as before the reset).
   - Use `--no-verify` only when necessary (e.g., to bypass known issues). Individual commits do not need to pass tests, but this should be rare.

There may be cases where you will need to push commits with --no-verify in order to avoid known issues. It is not necessary that every commit pass tests or checks, though this should be the exception if you're doing your job correctly. It is essential that the end state of the branch be identical to the original end state before the reset.

7. **Emit end-of-run change summary**

   After the final commit lands and the branch matches the original end state, print a Change Summary block to the conversation (not to a commit). This is a required final emission — the skill is not done until it appears:

   ```
   CHANGES MADE:
   - <verb-led list of the new commit storyline, e.g. "split auth middleware into 4 steps">

   THINGS I DIDN'T TOUCH:
   - <anything noticed while rewriting that was deliberately left in its original shape; "None" if nothing>

   POTENTIAL CONCERNS:
   - <risk items for the user: force-push needed, --no-verify usage, commits that individually don't build; "None" if nothing>
   ```

   Label casing must match exactly: `CHANGES MADE`, `THINGS I DIDN'T TOUCH`, `POTENTIAL CONCERNS`. All three blocks must be present even if one is "None".

## Misc

1. Never add yourself as an author or contributor on any branch or commit.
2. Write your pull request following the same instructions as in the pr.md command file.
3. In your pull request, include a link to the original branch.

Your commit should never include lines like:

```md
🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

or

```md
Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>
```

Or else I'll get in trouble with my boss.

## Output markers

Use these uppercase markers when reasoning about the recreation plan and reporting progress. One marker per line, no decoration:

- **STACK DETECTED** — base branch and scope detected at the start of the run. `STACK DETECTED: origin/main, diff scope HEAD~12..HEAD, medium granularity selected`.
- **UNVERIFIED** — claims about the final state that haven't been confirmed by `git diff`. `UNVERIFIED: the test suite passes at each commit — only the final state was diffed`.
- **NOTICED BUT NOT TOUCHING** — adjacent cleanups that could have slipped in but didn't. `NOTICED BUT NOT TOUCHING: a stale comment in an untouched file — outside the recreation scope`.
- **CHANGES MADE / THINGS I DIDN'T TOUCH / POTENTIAL CONCERNS** — required end-of-run summary (see Step 7).
- **CONFUSION** — signals in the original history that don't match the final state. `CONFUSION: can't tell if the Phase 2 rename was intentional or accidental — folded into the rename commit`.
- **MISSING REQUIREMENT** — input needed before reimplementation can proceed. `MISSING REQUIREMENT: granularity not specified and --auto not passed — asking the user before planning`.
- **PLAN** — commit storyline announced before executing. `PLAN: 12 commits across 3 groupings — auth middleware, user API, tests`.

## Common Rationalizations

Lies you'll tell yourself mid-recreation. Each has a correct response:

- *"This sub-step is trivial — I'll fold it into the next commit."* → Then it becomes invisible to the reviewer. If it's a distinct idea, it's a distinct commit.
- *"The middle commits don't build — I'll `--no-verify` through it."* → Allowed as the exception, not the rule. Surface it in `POTENTIAL CONCERNS` or restructure so builds pass.
- *"I'll squash the noisy fix-up commits into the bigger one."* → Fine only if the fix-up isn't its own idea. If it's "I forgot to handle null", it's its own commit.
- *"I can skip the final diff check — I've been careful."* → The only guarantee the recreated branch matches the original is the diff check. Run it.

## Red Flags — STOP

Pause and reshape the storyline if any of these are true:

- The final tree diff against the original end state is non-empty.
- More than one commit would need the same summary sentence.
- Force-pushing without having first warned the user (if the branch is shared).
- Any commit message contains AI attribution or `Co-Authored-By: Claude`.
- The recreated branch has more lines than the original (you introduced code during the rewrite).

## Verification

Before declaring the recreation done, self-check:

- [ ] `git diff <original-tip>..HEAD` is empty — end state matches exactly.
- [ ] Each commit introduces a single coherent idea with a plain-English subject line.
- [ ] `--no-verify` usage, if any, is called out in `POTENTIAL CONCERNS`.
- [ ] No AI attribution in any commit subject or body.
- [ ] The `CHANGES MADE / THINGS I DIDN'T TOUCH / POTENTIAL CONCERNS` block was emitted.
