---
name: kramme:git:recreate-commits
description: Recreate commits with narrative-quality history when the user asks or kramme:pr:create delegates its guarded rewrite phase. Not for merged or shared branches — it rewrites history and uses --force-with-lease unless remote synchronization is disabled.
argument-hint: "[--auto] [--coarse|--granular] [--base <branch>] [--base-commit <oid>] [--backup-ref <branch>] [--after <commit>] [--force-backup] [--require-unstacked] [--no-push] [--authorize-history-rewrite]"
disable-model-invocation: false
user-invocable: true
---

Reimplement the current branch with a clean, narrative-quality git commit history suitable for reviewer comprehension. By default, recreate commits on the current branch (not a new clean branch).

This rewrites history and requires a force-push to sync any existing remote history unless `--no-push` delegates that synchronization to `kramme:pr:create`. It is model-invocable so that the directly invoked parent can compose it without copying its behavior.

### Model Invocation Contract

- Invoke automatically only when the user clearly requested commit recreation or an active `kramme:pr:create` invocation explicitly delegates this phase. Do not infer authorization merely because a branch appears ready for cleanup or Pull Request creation.
- The guarded `kramme:pr:create` delegation must pass `--require-unstacked --no-push`, its pinned base commit, and its retry-safe backup ref. No other parent workflow is authorized by the model-invocation exception.
- Outside that exact `kramme:pr:create` delegation, never invent `--auto` or `--authorize-history-rewrite`. Without those caller-supplied flags, retain every documented confirmation before reset, restack, or publication.
- The model must never invent `--force-backup`. It may pass `--backup-ref` automatically only with the exact retry-safe value supplied by `kramme:pr:create`; outside that delegation, the user must have supplied the exact `--backup-ref` value. These flags can create or repoint a local branch before the reset confirmation, so a general request to recreate commits is not authorization to originate them.
- Model invocation changes routing only. It does not relax backup creation, branch and stack validation, final-tree identity, or lease-protected publication.

**When not to use:** Don't run this on a branch that is already merged, on a protected or shared base branch, or on a branch other contributors have based active work on without coordinating first — the recreation rewrites history and the remote can only be updated with a force-push.

**Flags:**

- `--auto` — Skip the granularity question, automatically choose the best granularity based on diff size and complexity unless `--coarse` or `--granular` pins it, and authorize one backup-protected unstacked history rewrite. Unless `--no-push` is also set, it authorizes that branch's lease-protected force-push too. A stacked rewrite additionally requires `--authorize-history-rewrite`; `--auto` never authorizes stack-wide mutation by itself. Neither flag bypasses backup creation, branch validation, final-tree identity, or force-with-lease.
- `--coarse` — Force coarse decomposition: one commit per major grouping (typically 5–15 commits). Skips the granularity question but does not authorize the history rewrite or publication by itself. Combine it with `--auto` to retain all other auto-mode behavior while pinning coarse granularity. Do not combine it with `--granular`.
- `--granular` — Force atomic-level decomposition. Skips the granularity question. Use for very large PRs where 100+ commits are appropriate.
- `--base <branch>` — Use `<branch>` as the base instead of auto-detecting. Without this flag, the skill tries to detect the base from an existing GitHub pull request, then from `origin/HEAD`, then from `origin/main` or `origin/master`.
- `--base-commit <oid>` — Pin diff and reset-point calculation to a caller-validated full commit OID while retaining the branch metadata from `--base`. Use this when a parent workflow must keep one base snapshot across multiple delegated skills.
- `--after <commit>` — Only recreate commits after `<commit>`, keeping all earlier history intact. Accepts any valid git ref (SHA, short SHA, `HEAD~3`, etc.). The commit must exist and be an ancestor of `HEAD`. When set, the diff scope becomes `<commit>..HEAD` and the reset point becomes `<commit>` instead of the merge base.
- `--backup-ref <branch>` — Use a caller-selected conservative recovery branch name. This requires backup mode and is primarily for parent workflows that need retry-safe per-input-tip backup names.
- `--force-backup` — Allow the resolution script to replace an existing `<branch>-recreate-backup` branch after you have inspected that backup and confirmed it is safe to move. An exact-tip backup is reused idempotently without this flag; a backup at any different tip makes the script stop so retries cannot destroy the original recovery point.
- `--require-unstacked` — Require the branch to remain outside every local or server-side stack when membership is resolved immediately before rewrite authorization. Set `REQUIRE_UNSTACKED=true` when present and stop before reset if membership is anything other than `none`. `kramme:pr:create` always passes this flag to preserve its earlier unstacked-only authorization across delegation.
- `--no-push` — Rewrite and verify the local branch but do not mutate its remote. Report that synchronization is delegated to the caller. `kramme:pr:create` always uses this mode so description generation and confirmation finish before the only remote update.
- `--authorize-history-rewrite` — Explicit authorization to skip the reset confirmation and, unless `--no-push` is also set, the publication confirmation. It is optional for an unstacked auto invocation but required in addition to `--auto` before auto mode may rewrite or publish a stack. It never bypasses backup creation, branch validation, final-tree identity, or force-with-lease.

## Steps

1. **Validate and resolve the base** — run the shared resolution script from the user's current repository. Do not `cd` into the plugin directory; the script intentionally inspects and mutates the current git repository in `--backup` mode. Pass through the skill's `--base`/`--base-commit`/`--backup-ref`/`--after`/`--force-backup` values as `BASE_FLAG`/`BASE_COMMIT_FLAG`/`BACKUP_REF_FLAG`/`AFTER_ARG`/`FORCE_BACKUP`. It determines the base ref, validates every precondition, fast-forwards a matching local base branch to its remote when the base is not pinned, and creates a recovery backup of the current tip **before anything destructive happens**:

   ```bash
   ARGS=()
   ARGS+=(--backup)
   [ -n "${BASE_FLAG:-}" ] && ARGS+=(--base "$BASE_FLAG")
   [ -n "${BASE_COMMIT_FLAG:-}" ] && ARGS+=(--base-commit "$BASE_COMMIT_FLAG")
   [ -n "${BACKUP_REF_FLAG:-}" ] && ARGS+=(--backup-ref "$BACKUP_REF_FLAG")
   [ -n "${AFTER_ARG:-}" ] && ARGS+=(--after "$AFTER_ARG")
   [ "${FORCE_BACKUP:-0}" = "1" ] && ARGS+=(--force-backup)
   RESOLVED=$("${CLAUDE_PLUGIN_ROOT}/scripts/resolve-base.sh" "${ARGS[@]}") || {
     echo "Base resolution failed; see the message above and stop." >&2
     exit 1
   }
   eval "$RESOLVED"
   [ "$(git symbolic-ref --quiet --short HEAD)" = "$ORIGINAL_BRANCH" ] || {
     echo "The current branch changed after base resolution; stop before rewriting history." >&2
     exit 1
   }
   ```

   On success the script prints shell-quoted assignments that `eval` loads into the environment: `BASE_REF`, `BASE_BRANCH`, `MERGE_BASE`, `AFTER_COMMIT`, `RESET_POINT`, `ORIGINAL_BRANCH`, `ORIGINAL_TIP`, and `BACKUP_REF`. On any failure it writes the reason to stderr and exits non-zero — stop and surface that message; do not continue.

   The script enforces these preconditions, aborting on the first that fails: it is being run from the user's repository instead of the repository that contains the skill script, clean working tree including untracked files, `HEAD` on a feature branch (not detached, not the base branch), `BASE_REF` resolves to a commit, a merge base exists with `HEAD`, `--after` (if given) resolves and is an ancestor of `HEAD`, a matching local base branch fast-forwards cleanly to its remote (it aborts rather than reconcile a diverged local base), and any existing recovery backup either points exactly at the current original tip or was explicitly approved for replacement with `--force-backup`.

   It records three values you rely on later: `ORIGINAL_BRANCH` (the branch validated before backup creation), `ORIGINAL_TIP` (the pre-reset `HEAD`, the byte-identical target end state), and `BACKUP_REF` (a branch pointing at `ORIGINAL_TIP`). Recover the original branch at any time with `git reset --hard "$BACKUP_REF"`. A backup already at `ORIGINAL_TIP` is reused for retry safety. If it points elsewhere, inspect it before retrying; only pass `--force-backup` after confirming the previous recovery point can be replaced.

   Before resetting the branch, resolve local and server-side GitHub stack membership:

   ```bash
   STACK_RESOLVED=$("${CLAUDE_PLUGIN_ROOT}/scripts/resolve-stack-membership.sh") || {
     echo "Stack membership could not be determined; stop before rewriting history." >&2
     exit 1
   }
   eval "$STACK_RESOLVED"
   ```

   If `REQUIRE_UNSTACKED=true`, require `STACK_MEMBERSHIP=none` immediately after this resolution. Any local or server-side membership is state drift from the parent workflow's validated boundary: stop before the reset, even when `--auto` or `--authorize-history-rewrite` was passed. Do not reinterpret an unstacked-only parent authorization as approval to rewrite or restack multiple branches.

   Set `IN_STACK=true` only for `STACK_MEMBERSHIP=local`; set it false for `none`. If membership is `remote`, stop before the reset: the PR is stacked on GitHub but not tracked locally. Install the extension if needed, run `gh stack checkout "$STACK_PR_NUMBER"` from a clean working tree, then retry. Authentication, API, parsing, and unexpected CLI failures also stop rather than falling through to the single-branch flow.

   If `IN_STACK=true` and `--auto` was passed without `--authorize-history-rewrite`, stop before the reset. Auto mode alone authorizes only the current unstacked branch; the additional flag is the explicit approval for restacking and publishing every affected branch. A non-auto stack invocation may instead obtain the explicit stack-wide confirmations below.

   When `IN_STACK=true`, freeze and validate the full local stack boundary for every later confirmation:

   ```bash
   command -v jq > /dev/null 2>&1 || {
     echo "jq is required to enumerate the stacked branches before a history rewrite." >&2
     exit 1
   }
   resolve_stack_branch_names() {
     local stack_view_json
     stack_view_json=$(gh stack view --json) || return 1
     printf '%s\n' "$stack_view_json" | jq -er '
       .branches
       | if type != "array"
           or length == 0
           or any(.[]; ((.name | type) != "string") or ((.name | length) == 0))
         then error("invalid stack branch inventory")
         else .[].name
         end
     '
   }
   STACK_BRANCH_NAMES=$(resolve_stack_branch_names) || {
     echo "gh stack view returned an invalid branch inventory; stop before rewriting history." >&2
     exit 1
   }
   STACK_BRANCHES=()
   ORIGINAL_BRANCH_IN_STACK=0
   while IFS= read -r branch; do
     git check-ref-format --branch "$branch" > /dev/null 2>&1 || {
       echo "gh stack view returned an invalid branch name; stop before rewriting history." >&2
       exit 1
     }
     STACK_BRANCHES+=("$branch")
     [ "$branch" != "$ORIGINAL_BRANCH" ] || ORIGINAL_BRANCH_IN_STACK=1
   done <<< "$STACK_BRANCH_NAMES"
   if [ "${#STACK_BRANCHES[@]}" -eq 0 ] || [ "$ORIGINAL_BRANCH_IN_STACK" -ne 1 ]; then
     echo "The validated current branch is missing from the local stack inventory; stop before rewriting history." >&2
     exit 1
   fi
   ```

   Preserve `STACK_BRANCH_NAMES` and `STACK_BRANCHES` exactly as resolved; never replace or shorten the authorization boundary. Immediately before either stack-wide confirmation, before resetting, before restacking, and before pushing, call `resolve_stack_branch_names` and require its output to equal `STACK_BRANCH_NAMES` byte-for-byte. If the inventory cannot be re-read or differs, stop and require a fresh run so newly added, removed, or renamed branches cannot inherit stale authorization. `gh stack rebase --upstack --no-trunk` may rewrite branches above the current branch, and `gh stack push` targets the locally tracked stack.

   For an unstacked invocation that may sync a remote (no `--no-push`), resolve and freeze the single-branch push boundary before resetting:

   ```bash
   PUSH_RESOLVED=$("${CLAUDE_PLUGIN_ROOT}/skills/kramme:git:recreate-commits/scripts/resolve-push-target.sh" \
     --original-tip "$ORIGINAL_TIP" \
     --base-branch "$BASE_BRANCH") || {
     echo "Push-target resolution failed; stop before rewriting history." >&2
     exit 1
   }
   eval "$PUSH_RESOLVED"
   if [ -z "$PUSH_LEASE_OID" ] && [ -n "$STACK_PR_NUMBER" ]; then
     echo "The current Pull Request branch has no remote-tracking upstream; set one explicitly before rewriting history." >&2
     exit 1
   fi
   ```

   An empty `PUSH_LEASE_OID` with no Pull Request means the branch is local-only. Otherwise the helper requires the configured upstream branch name to match the current local branch, rejects the base branch and push refspecs that rename the destination, resolves Git's effective push remote (including `branch.<name>.pushRemote` and `remote.pushDefault`), freezes exactly one push URL and remote ref, captures the effective destination's exact pre-reset OID, and stops if that destination contains commits absent from `ORIGINAL_TIP`. Do not replace this with an argumentless `git push`, a remote name with multiple push URLs, or a later tracking-ref lookup: repository configuration can widen the push to unrelated refs or repositories, and a tracking ref can move after the safety decision.

2. **Analyze the diff**
   - Study the full diff from `$RESET_POINT..HEAD` (this is `$AFTER_COMMIT..HEAD` when `--after` was given, otherwise `$MERGE_BASE..HEAD`).
   - Form a clear understanding of the final intended state.

3. **Prepare the branch**
   - By default, work on the current branch. Do NOT create a `{branch_name}-clean` branch unless explicitly requested.
   - If explicitly asked to use a clean branch, create `{branch_name}-clean` from `$RESET_POINT`.

### Conductor workspaces

Synced Conductor workspace boundary contract (keep aligned across git-mutating workflow skills): when `CONDUCTOR_WORKSPACE_PATH` is set: stay on the current branch absent explicit approval; use another Conductor workspace—not raw worktrees or throwaway branches—for isolation. Never remove, reset, or re-point a Conductor workspace path; archive workspaces through Conductor. Conductor changes defaults, not permissions or safety gates.

4. **Plan the commit storyline**

   **Assess diff size and determine granularity.** After analyzing the diff, assess whether the PR is large (many files changed, significant lines added/removed, multiple distinct features or areas touched).

   If `--coarse` was combined with `--granular`, stop and ask the caller to choose one fixed granularity. `--coarse` selects **Coarse** granularity unconditionally and skips the granularity question. `--granular` selects **Atomic** granularity unconditionally and skips the granularity question. When `--auto` accompanies either fixed-granularity flag, that flag replaces automatic granularity selection and every other auto-mode behavior remains in effect. `--auto` without a fixed-granularity flag selects the most appropriate granularity based on diff size and complexity and skips the question. Otherwise, if the diff is large, ask the user which granularity level they want before planning:
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
   - Before resetting, unless `--authorize-history-rewrite` was passed or (`--auto` was passed and `IN_STACK=false`), obtain the applicable confirmation. The original tip is preserved at `BACKUP_REF`, so the reset is recoverable, but destructive to the working tree. Auto or explicit authorization skips only this prompt within the boundary described above, not the backup or validation requirements.
     - If `IN_STACK=false`, confirm that the user authorizes rewriting `ORIGINAL_BRANCH`.
     - If `IN_STACK=true`, enumerate every branch in `STACK_BRANCHES`, explain that `ORIGINAL_BRANCH` will be reset and branches above it may be rewritten by the local upstack restack, then require explicit confirmation authorizing both the reset and that restack. A generic confirmation mentioning only the current branch is insufficient.
   - Immediately before resetting, revalidate the branch, original tip, ordinary untracked work, and ignored paths that overlap the reset point:

     ```bash
     LATEST_STACK_RESOLVED=$("${CLAUDE_PLUGIN_ROOT}/scripts/resolve-stack-membership.sh") || {
       echo "Stack membership could not be revalidated; stop before rewriting history." >&2
       exit 1
     }
     if ! (
       eval "$LATEST_STACK_RESOLVED"
       [ "$STACK_MEMBERSHIP" = none ]
     ); then
       echo "The branch joined a local or server-side stack after initial validation; stop before rewriting history." >&2
       exit 1
     fi
     "${CLAUDE_PLUGIN_ROOT}/scripts/verify-rewrite-state.sh" \
       --expected-branch "$ORIGINAL_BRANCH" \
       --expected-tip "$ORIGINAL_TIP" \
       --reset-point "$RESET_POINT"
     ```

     Run the stack-revalidation block above only when the parsed agent state has `REQUIRE_UNSTACKED=true`; omit it for ordinary direct invocations that may intentionally rewrite a local stack. Do not wrap it in a shell-local `REQUIRE_UNSTACKED` conditional: argument parsing and this destructive boundary run in separate shell invocations.

     Any failure stops the workflow. Do not rely only on the earlier backup-time or stack-membership validation: diff analysis and commit planning create a real window in which the checkout or authorization boundary can change.

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

7. **Restack locally, then sync the remote** (remote sync only when enabled, with confirmation or explicit authorization)
   - If `IN_STACK=true`, the rewrite has orphaned every branch stacked above it. Restack the local chain immediately after final-tree verification and **before** any `--no-push` or local-only early exit:

     ```bash
     gh stack rebase --upstack --no-trunk # rebase the branches above onto the rewritten history
     ```

     A restack failure stops the workflow. Do not push a partially restacked stack.

   - If `--no-push` was passed, do not run any push command. The local restack above still applies. Report remote synchronization as delegated in `POTENTIAL CONCERNS`, then continue to the final summary.
   - If the unstacked branch resolved no `PUSH_LEASE_OID` and has no Pull Request, skip this step — the recreation is local-only.
   - Otherwise the rewritten history has diverged from the remote and a force-push is required. Before pushing:
     - Before pushing, unless `--authorize-history-rewrite` was passed or (`--auto` was passed and `IN_STACK=false`), obtain the applicable publication confirmation and warn explicitly if others may have based active work on any listed branch. For an unstacked branch, confirm the single validated push target. For a stack, enumerate every branch in the frozen `STACK_BRANCHES` list, state that `gh stack push` performs an atomic whole-stack force-with-lease publication, and require explicit confirmation authorizing that whole-stack push. A reset/restack confirmation does not also authorize publication. Auto or explicit authorization skips the prompt only within the same unstacked/stacked boundary as the reset, not the warning or safety checks.
     - For an unstacked branch, require the checkout to remain on `PUSH_SOURCE_BRANCH`, then push exactly one validated remote ref with the captured lease:

       ```bash
       [ "$(git symbolic-ref --quiet --short HEAD)" = "$PUSH_SOURCE_BRANCH" ] || {
         echo "The current branch changed after push-target resolution; stop before pushing." >&2
         exit 1
       }
       git push \
         --no-follow-tags \
         --force-with-lease="${PUSH_REMOTE_REF}:${PUSH_LEASE_OID}" \
         -- "$PUSH_REMOTE_URL" "HEAD:${PUSH_REMOTE_REF}"
       ```

       Never use an argumentless `git push --force-with-lease`: configured push refspecs or `push.default=matching` can select unrelated branches, a named remote can expand to multiple push URLs, `push.followTags` can publish annotated tags, and a default lease can accept fetched upstream commits that the local recovery backup does not contain.

   - If `IN_STACK=true`, push the already-restacked whole stack instead of a single branch:

     ```bash
     gh stack push # all stack branches, --force-with-lease --atomic
     ```

   - Record the force-push (and any stack restack) in `POTENTIAL CONCERNS`.

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
- Force-pushing without the captured ref-specific `--force-with-lease`, `--no-follow-tags`, the frozen single push URL, an explicit single-branch refspec, or authorization appropriate to the unstacked or stacked boundary.
- The branch is part of a GitHub stack and a single-branch force-push is about to run without restacking the branches above (`gh stack rebase --upstack --no-trunk` + `gh stack push`).
- Any commit message contains AI attribution or `Co-Authored-By: Claude`.
- The recreated branch has more lines than the original (you introduced code during the rewrite).

## Verification

Before declaring the recreation done, self-check:

- [ ] `git diff "$ORIGINAL_TIP" HEAD` is empty — end state matches exactly.
- [ ] Untracked files were rejected before backup creation and reset.
- [ ] The branch, original tip, worktree, and ignored reset-point collisions were rechecked immediately before reset.
- [ ] Any unstacked remote sync uses the captured effective push-destination OID, frozen push URL, explicit remote ref, `--no-follow-tags`, and single-branch refspec.
- [ ] Each commit introduces a single coherent idea with a plain-English subject line.
- [ ] `--no-verify` usage, if any, is called out in `POTENTIAL CONCERNS`.
- [ ] No AI attribution in any commit subject or body.
- [ ] The `CHANGES MADE / THINGS I DIDN'T TOUCH / POTENTIAL CONCERNS` block was emitted.
