---
name: kramme:git:recreate-commits
description: Use when asked to recreate commits with narrative-quality history on the current branch. Not for merged branches or shared branches others have based work on — it rewrites history and force-pushes with --force-with-lease.
argument-hint: "[--auto|--granular] [--base <branch>] [--after <commit>] [--force-backup]"
disable-model-invocation: true
user-invocable: true
---

Reimplement the current branch with a clean, narrative-quality git commit history suitable for reviewer comprehension. By default, recreate commits on the current branch (not a new clean branch).

This rewrites history and requires a force-push to sync any remote. It is user-triggered only (it does not auto-invoke).

**When not to use:** Don't run this on a branch that is already merged, on a protected or shared base branch, or on a branch other contributors have based active work on without coordinating first — the recreation rewrites history and the remote can only be updated with a force-push.

**Flags:**

- `--auto` — Skip the granularity question and automatically choose the best granularity based on diff size and complexity.
- `--granular` — Force atomic-level decomposition. Skips the granularity question. Use for very large PRs where 100+ commits are appropriate.
- `--base <branch>` — Use `<branch>` as the base instead of auto-detecting. Without this flag, the skill tries to detect the base from an existing GitHub pull request, then from `origin/HEAD`, then from `origin/main` or `origin/master`.
- `--after <commit>` — Only recreate commits after `<commit>`, keeping all earlier history intact. Accepts any valid git ref (SHA, short SHA, `HEAD~3`, etc.). The commit must exist and be an ancestor of `HEAD`. When set, the diff scope becomes `<commit>..HEAD` and the reset point becomes `<commit>` instead of the merge base.
- `--force-backup` — Allow the resolution script to replace an existing `<branch>-recreate-backup` branch after you have inspected that backup and confirmed it is safe to move. Without this flag, an existing backup makes the script stop so retries cannot destroy the original recovery point.

## Steps

1. **Validate and resolve the base** — run the shared resolution script from the user's current repository. Do not `cd` into the plugin directory; the script intentionally inspects and mutates the current git repository in `--backup` mode. Pass through the skill's `--base`/`--after`/`--force-backup` values as `BASE_FLAG`/`AFTER_ARG`/`FORCE_BACKUP`. It determines the base ref, validates every precondition, fast-forwards a matching local base branch to its remote, and creates a recovery backup of the current tip **before anything destructive happens**:

   ```bash
   ARGS=()
   ARGS+=(--backup)
   [ -n "${BASE_FLAG:-}" ] && ARGS+=(--base "$BASE_FLAG")
   [ -n "${AFTER_ARG:-}" ] && ARGS+=(--after "$AFTER_ARG")
   [ "${FORCE_BACKUP:-0}" = "1" ] && ARGS+=(--force-backup)

   RESOLVED=$("${CLAUDE_PLUGIN_ROOT}/scripts/resolve-base.sh" "${ARGS[@]}") || {
     echo "Base resolution failed; see the message above and stop." >&2
     exit 1
   }
   eval "$RESOLVED"
   ```

   On success the script prints shell-quoted assignments that `eval` loads into the environment: `BASE_REF`, `BASE_BRANCH`, `MERGE_BASE`, `AFTER_COMMIT`, `RESET_POINT`, `ORIGINAL_TIP`, and `BACKUP_REF`. On any failure it writes the reason to stderr and exits non-zero — stop and surface that message; do not continue.

   The script enforces these preconditions, aborting on the first that fails: it is being run from the user's repository instead of the repository that contains the skill script, clean working tree, `HEAD` on a feature branch (not detached, not the base branch), `BASE_REF` resolves to a commit, a merge base exists with `HEAD`, `--after` (if given) resolves and is an ancestor of `HEAD`, a matching local base branch fast-forwards cleanly to its remote (it aborts rather than reconcile a diverged local base), and the recovery backup branch does not already exist unless `--force-backup` was explicitly passed.

   It records two values you rely on later: `ORIGINAL_TIP` (the pre-reset `HEAD`, the byte-identical target end state) and `BACKUP_REF` (a branch pointing at `ORIGINAL_TIP`). Recover the original branch at any time with `git reset --hard "$BACKUP_REF"`. If the backup already exists, inspect it before retrying; only pass `--force-backup` after confirming the previous recovery point can be replaced.

2. **Analyze the diff**
   - Study the full diff from `$RESET_POINT..HEAD` (this is `$AFTER_COMMIT..HEAD` when `--after` was given, otherwise `$MERGE_BASE..HEAD`).
   - Form a clear understanding of the final intended state.

3. **Prepare the branch**
   - By default, work on the current branch. Do NOT create a `{branch_name}-clean` branch unless explicitly requested.
   - If explicitly asked to use a clean branch, create `{branch_name}-clean` from `$RESET_POINT`.

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
   - Confirm with the user that you may rewrite the current branch's history before resetting. The original tip is preserved at `BACKUP_REF`, so this is recoverable, but the reset is destructive to the working tree.
   - Reset the branch to the reset point: `git reset --hard "$RESET_POINT"`. (`RESET_POINT` is `AFTER_COMMIT` when `--after` was given, otherwise the merge base.)
   - Rebuild the changes commit by commit. To guarantee a byte-identical end state, source the final content from `$ORIGINAL_TIP` rather than retyping it (retyping is how extra lines and drift creep in):
     - Whole-file commits: `git checkout "$ORIGINAL_TIP" -- <paths>`, then commit.
     - Sub-file (fine/atomic) commits: `git checkout -p "$ORIGINAL_TIP" -- <path>` (or `git restore -p --source "$ORIGINAL_TIP" <path>`) and stage only the hunks that belong to this commit.
   - Each commit must:
     - Introduce a single coherent idea.
     - Include a clear commit message and description.
     - Add comments when needed to explain intent.

6. **Verify correctness**
   - Confirm the final tree matches the original exactly: `git diff "$ORIGINAL_TIP" HEAD` must be empty. If it is non-empty, the recreation is wrong — fix it before continuing (recover with `git reset --hard "$BACKUP_REF"` if you need to start over).
   - `git commit --no-verify` (skips commit-time hooks such as linters and formatters) is allowed only when necessary to get past a known-failing intermediate state. Individual commits need not pass tests, but this should be the exception, not the rule. Note this is distinct from `git push --no-verify`, which skips pre-push hooks (see the push step).

   It is essential that the end state of the branch be byte-identical to the original end state (`$ORIGINAL_TIP`); intermediate commits not building is tolerable, a wrong end state is not.

7. **Sync the remote** (only when needed, and only with confirmation)
   - If the branch has no remote tracking ref and no pull request, skip this step — the recreation is local-only.
   - Otherwise the rewritten history has diverged from the remote and a force-push is required. Before pushing:
     - Confirm with the user, and warn explicitly if others may have based active work on this branch.
     - Push with `git push --force-with-lease` (never plain `--force`), so a concurrent remote update aborts the push instead of silently overwriting it.
   - Record the force-push in `POTENTIAL CONCERNS`.

8. **Emit end-of-run change summary**

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
2. If you open or update a pull request, write a plain-English, imperative title and a body that summarizes the storyline — what changed and why, grouped by the commit narrative.
3. In the pull request body, include a link to the original (pre-recreation) branch or its `BACKUP_REF` so reviewers can compare.

Never add AI attribution to any commit subject or body. Do not include generated-with banners (e.g. `🤖 Generated with ...`) or `Co-Authored-By:` trailers that name an AI assistant.

## Output markers

Use these uppercase markers when reasoning about the recreation plan and reporting progress. One marker per line, no decoration:

- **STACK DETECTED** — base branch and scope detected at the start of the run. `STACK DETECTED: origin/main, diff scope HEAD~12..HEAD, medium granularity selected`.
- **UNVERIFIED** — claims about the final state that haven't been confirmed by `git diff`. `UNVERIFIED: the test suite passes at each commit — only the final state was diffed`.
- **NOTICED BUT NOT TOUCHING** — adjacent cleanups that could have slipped in but didn't. `NOTICED BUT NOT TOUCHING: a stale comment in an untouched file — outside the recreation scope`.
- **CHANGES MADE / THINGS I DIDN'T TOUCH / POTENTIAL CONCERNS** — required end-of-run summary (see Step 8).
- **CONFUSION** — signals in the original history that don't match the final state. `CONFUSION: can't tell if the Phase 2 rename was intentional or accidental — folded into the rename commit`.
- **MISSING REQUIREMENT** — input needed before reimplementation can proceed. `MISSING REQUIREMENT: granularity not specified and --auto not passed — asking the user before planning`.
- **PLAN** — commit storyline announced before executing. `PLAN: 12 commits across 3 groupings — auth middleware, user API, tests`.

## Common Rationalizations

Lies you'll tell yourself mid-recreation. Each has a correct response:

- _"This sub-step is trivial — I'll fold it into the next commit."_ → Then it becomes invisible to the reviewer. If it's a distinct idea, it's a distinct commit.
- _"The middle commits don't build — I'll `--no-verify` through it."_ → Allowed as the exception, not the rule. Surface it in `POTENTIAL CONCERNS` or restructure so builds pass.
- _"I'll squash the noisy fix-up commits into the bigger one."_ → Fine only if the fix-up isn't its own idea. If it's "I forgot to handle null", it's its own commit.
- _"I can skip the final diff check — I've been careful."_ → The only guarantee the recreated branch matches the original is the diff check. Run it.

## Red Flags — STOP

Pause and reshape the storyline if any of these are true:

- The final tree diff against the original end state is non-empty.
- More than one commit would need the same summary sentence.
- Force-pushing without `--force-with-lease`, or without first confirming with the user.
- Any commit message contains AI attribution or `Co-Authored-By: Claude`.
- The recreated branch has more lines than the original (you introduced code during the rewrite).

## Verification

Before declaring the recreation done, self-check:

- [ ] `git diff "$ORIGINAL_TIP" HEAD` is empty — end state matches exactly.
- [ ] Each commit introduces a single coherent idea with a plain-English subject line.
- [ ] `--no-verify` usage, if any, is called out in `POTENTIAL CONCERNS`.
- [ ] No AI attribution in any commit subject or body.
- [ ] The `CHANGES MADE / THINGS I DIDN'T TOUCH / POTENTIAL CONCERNS` block was emitted.
