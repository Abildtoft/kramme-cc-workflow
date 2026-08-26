---
name: kramme:code:refactor-pass
description: "Perform a refactor pass focused on simplicity after recent changes, including AI-slop cleanup for unnecessary comments, defensive noise, weak typing, over-engineering, and style drift. Use for a narrow cleanup, simplification, dead-code removal, suspected AI-generated code, or an explicit request to redo mediocre recent work properly with --rewrite. Applies Chesterton's Fence, rejects changes that require modifying tests, and keeps the default mode slice-by-slice."
argument-hint: "[scope ... | --rewrite]"
disable-model-invocation: true
user-invocable: true
---

# Refactor Pass

Perform a simplification pass on recent changes: remove dead code, straighten logic, drop excessive parameters, remove AI-generated slop, and verify with build/tests after each change. Default mode always checks the resolved scope for both general simplifications and high-confidence AI-slop patterns. Work one simplification at a time. In rewrite mode, scrap a working-but-hacky implementation and reimplement it elegantly from what you learned. Preserve behavior exactly in either mode.

This skill edits files, so it runs only after explicit user invocation. In default mode, it commits each verified slice.

## Select mode

Parse `$ARGUMENTS` before selecting a mode. Accept no arguments, exactly one `--rewrite` token, or one or more positional scope tokens with no option-prefixed token. Treat accepted positional tokens as the explicit default-mode scope. If `--rewrite` is combined with scope tokens, or any other option token is present, STOP, name the unsupported input, and show the valid invocation shapes. Do not fall through to default mode.

- **Default mode:** use when no arguments were passed, or when positional scope tokens were passed for a refactor, cleanup, simplification, or dead-code removal. Follow the slice-by-slice simplification loop.
- **Rewrite mode:** use when the sole argument is `--rewrite`, or when no arguments were passed and the user explicitly asks to scrap, redo, or reimplement a working but hacky solution elegantly. Validate the current-session context, then follow the rewrite process instead of the default scope-resolution and simplification loop.

## Rewrite mode Step 0: Validate context

Before proceeding in rewrite mode, review the current conversation to confirm:

1. **Implementation work exists** — We've written or modified code in this session.
2. **The work is complete enough** — The fix/feature works (even if inelegantly).
3. **There's something to improve** — The implementation has identifiable inelegance.

**If any of these are missing, STOP and explain:**

- No implementation work? → "There's no implementation in this conversation to refactor. This command is for redoing existing work more elegantly."
- Work isn't complete? → "Let's finish the current implementation first, then we can evaluate whether it needs an elegant refactor."
- Nothing obviously inelegant? → "The current implementation looks reasonable. What specifically feels hacky or inelegant to you?"

Only proceed in rewrite mode if all three conditions are met.

## When to use

- After a feature or fix lands, before merging, to clean up accidental complexity.
- When the user asks for "a refactor pass", "cleanup", "simplification", or "dead-code removal" on recent work.
- When recent code may contain AI-generated slop such as obvious comments, defensive overkill, type workarounds, excessive logging, copy-paste artifacts, or style drift. Default mode checks these without a separate flag.
- When the user asks to scrap a working-but-mediocre fix and redo it properly; select rewrite mode.
- On a narrow scope — typically the diff of the current branch or a few files. Not for codebase-wide scans (use `kramme:code:refactor-opportunities` for that).

## When NOT to proceed

After selecting the mode, apply this gate before changing code.

In either mode, do not proceed if:

- **You don't understand it yet.** Simplifying code you don't fully understand is how subtle behavior gets deleted. Read the code and the tests first; when in doubt, leave it.
- **It's performance-critical and the alternatives are slower.** "Cleaner" is not a goal that overrides measured performance. Check benchmarks before simplifying hot paths.

In default mode, also do not proceed if:

- **Code is already clean.** Not every file needs a pass. If the recent changes read well, stop here.
- **It's about to be rewritten.** If the code will be replaced by other in-flight work, a refactor pass is wasted effort. Surface the overlap and stop.

In rewrite mode, also do not proceed if:

- **The solution is fine, just unfamiliar.** Unfamiliarity is not inelegance. Read the code a second time before deciding to scrap it.
- **Time pressure makes "good enough" acceptable.** A working fix before a deadline is not a candidate for a scrap-and-rewrite. Ship it; log a follow-up if the inelegance matters.
- **The inelegance is inherent to the problem domain.** Some problems are ugly. If the ugliness tracks the domain rather than the implementation, a rewrite will reproduce it in a different shape.

If any of these apply to the whole scope, stop and tell the user why. If they apply to specific sections, skip those sections.

## Resolve scope

Synced base/diff scope contract (keep aligned across base-aware and diff-aware skills): use the shared resolve-base.sh script for base refs; use the shared collect-review-diff.sh script for unified changed-file scope; canonical base priority is explicit --base, PR target branch, then origin/HEAD, origin/main, or origin/master, and canonical diff scope is committed PR diff from MERGE_BASE...HEAD plus staged, unstaged, and untracked paths.

Before picking simplifications, decide what "recent changes" means for this invocation:

1. If the user named files or a directory, use that.
2. Otherwise, collect the current branch's unified review scope with the shared plugin script:

   ```bash
   [ -x "${CLAUDE_PLUGIN_ROOT:-}/scripts/collect-review-diff.sh" ] || {
     echo "collect-review-diff.sh not found under CLAUDE_PLUGIN_ROOT; stop." >&2
     exit 1
   }
   RESOLVED=$("${CLAUDE_PLUGIN_ROOT}/scripts/collect-review-diff.sh" --strict --format json) || {
     echo "Base/diff collection failed; see the message above and stop." >&2
     exit 1
   }
   REVIEW_DIFF_FIELDS=$(mktemp "${TMPDIR:-/tmp}/refactor-pass-diff.XXXXXX") || {
     echo "Could not create temporary review-diff file; stop." >&2
     exit 1
   }
   "${CLAUDE_PLUGIN_ROOT}/scripts/collect-review-diff.sh" --decode-json \
     <<< "$RESOLVED" > "$REVIEW_DIFF_FIELDS" || {
     rm -f "$REVIEW_DIFF_FIELDS"
     echo "Base/diff decoding failed; see the message above and stop." >&2
     exit 1
   }
   if ! {
     IFS= read -r -d '' BASE_REF \
       && IFS= read -r -d '' BASE_BRANCH \
       && IFS= read -r -d '' MERGE_BASE \
       && IFS= read -r -d '' CHANGED_FILES
   } < "$REVIEW_DIFF_FIELDS"; then
     rm -f "$REVIEW_DIFF_FIELDS"
     echo "Decoded review-diff fields were incomplete; stop." >&2
     exit 1
   fi
   rm -f "$REVIEW_DIFF_FIELDS"
   ```

   Use `BASE_REF`, `MERGE_BASE`, and newline-delimited `CHANGED_FILES` as the default resolved scope. Do not independently guess or re-resolve the base.

3. If the resulting scope is empty (clean working tree, no diff against base), stop and ask the user what to scope to. Do not invent a scope.

Before recording either a default or explicit scope, read the skill-local `references/protected-workflow-artifacts.txt` registry, enumerate the scope's changed paths, and remove every matching path. These protected workflow artifacts are not cleanup candidates and must never enter the checkpoint path set. Leave them untouched, report each exclusion with `NOTICED BUT NOT TOUCHING`, and do not broaden this filter to arbitrary untracked files. Store the remaining newline-delimited paths as `REFACTOR_SCOPE_PATHS`; use that filtered set for discovery, checkpointing, and every simplification slice. If no paths remain, stop and report that the requested scope contains only protected workflow artifacts.

Record `REFACTOR_SCOPE_PATHS` before starting the loop. Every simplification must fall inside it; observations outside it become `NOTICED BUT NOT TOUCHING` markers, not new work.

## Discover default-mode candidates

Default mode includes AI-slop review without a separate flag. Rewrite mode skips this discovery step because it replaces the current implementation from its recovered behavioral contract instead of applying individual cleanup findings.

Run initial read-only discovery before creating any checkpoint commit. Before the first simplification, and again after each verified slice, build one candidate queue:

1. Inspect the resolved scope for the general simplification candidates listed in the loop below.
2. Launch `kramme:deslop-reviewer` in code review mode against `REFACTOR_SCOPE_PATHS`. When the user supplied files or a directory, pass only the filtered paths under that scope. Otherwise pass `BASE_REF`, `MERGE_BASE`, and filtered `REFACTOR_SCOPE_PATHS`, and require the reviewer to inspect the committed `git diff "$MERGE_BASE"...HEAD`, staged diff, unstaged diff, and untracked paths without re-resolving the base.
3. Require the reviewer call to complete successfully with a parseable finding set. If the agent is unavailable, times out, or returns unusable output, stop and surface the discovery failure. Do not treat a failed reviewer call as an empty finding set or report the scope clean.
4. Discard reviewer findings outside the resolved scope or in generated files, vendored code, lockfiles, snapshots, or `*.d.ts` files. These exclusions apply to the AI-slop aspect; an explicitly scoped general refactor still follows the normal Fence and project rules.
5. Visual redesign findings are not behavior-preserving simplifications. Exclude AI-aesthetic UI findings that would change rendered palette, spacing, radius, shadows, hierarchy, or state presentation; emit `NOTICED BUT NOT TOUCHING` and suggest `kramme:pr:ux-review` instead.
6. Treat every reported slop finding as a candidate, not an instruction. The reviewer already suppresses findings below its reporting threshold; do not invent extra confidence bands or auto-apply a finding because of its score.
7. Deduplicate overlapping general and AI-slop candidates. Prefer the explanation that identifies the concrete unnecessary complexity and the smallest behavior-preserving change.

If the initial combined queue is empty, report that the scoped code is already clean and stop without verifying, checkpointing, editing, or committing. If a refreshed queue is empty after a verified slice, report that the pass is complete and stop. AI-slop findings enter the same one-slice loop, Fence, verification, commit, and recovery contract as every other candidate.

## Establish a commit baseline

Default mode commits each simplification, so uncommitted input needs a clean boundary once discovery has proved there is work to do. If `REFACTOR_SCOPE_PATHS` contains staged, unstaged, or untracked changes:

1. Run `kramme:verify:run` on the unchanged starting tree. If verification cannot run or fails, stop without committing or refactoring.
2. Before staging, record `CHECKPOINT_HEAD=$(git rev-parse HEAD)`, resolve the real index path with `CHECKPOINT_INDEX_PATH=$(git rev-parse --git-path index)`, record whether that file exists, and make a byte-for-byte backup of the actual index file outside the repository. Do not use a tree object as an index backup: tree objects omit index-only state such as intent-to-add and skip-worktree flags. Also inventory and snapshot the existence, contents, modes, and symlink targets of every tracked and untracked non-ignored worktree path, not only `REFACTOR_SCOPE_PATHS`; this is the verified checkpoint worktree state. The inventory must identify non-ignored paths a commit hook creates after the snapshot so recovery can restore their prior absence.
3. Create one clearly labeled recovery checkpoint commit containing the exact pre-existing changes in `REFACTOR_SCOPE_PATHS` and no cleanup. Limit both staging and commit selection to those paths so protected artifacts and staged or unstaged work outside the scope are not swept in. Run staging and commit as checked operations.
4. If staging or commit fails, restore the actual index file byte-for-byte (or restore its prior absence), then compare the complete tracked and untracked non-ignored worktree against the verified checkpoint snapshot. Restore every hook-caused delta, including out-of-scope content changes, deletions, and newly created non-ignored paths, while preserving the state that existed before the attempt. Require `HEAD` to still equal `CHECKPOINT_HEAD`, require the restored index to byte-match its backup, and require the complete worktree inventory and snapshot to match. If any restoration or equality check fails, stop and print the saved head, index backup path, worktree snapshot path, and exact manual recovery commands. Do not continue after a failed checkpoint commit.
5. After success, record the checkpoint hash and require its parent to equal `CHECKPOINT_HEAD`. Confirm that the committed path set contains only `REFACTOR_SCOPE_PATHS`, the committed contents and modes match the verified checkpoint snapshot, the complete tracked and untracked non-ignored worktree still matches the verified snapshot, and protected artifacts plus out-of-scope index state are unchanged. If a commit hook changes any worktree path from the verified snapshot, stop and surface the mutation rather than treating the checkpoint as verified. If the scoped checkpoint cannot be isolated without disturbing other state, stop and surface the conflict.

The checkpoint is a recovery boundary, not a simplification slice. Never fold the first cleanup into it. After the checkpoint, every AI-slop or general simplification must still receive its own verified commit.

## Markers

This skill emits two markers. Use these exact formats so a calling agent can parse them.

`SIMPLICITY CHECK` — the minimum change you intend to make for the current slice:

```
SIMPLICITY CHECK: <one-line summary of the minimum change>
```

If the change ends up larger than that minimum, add a second line naming the concrete requirement that forced the expansion.

`NOTICED BUT NOT TOUCHING` — anything adjacent you saw while editing but are intentionally leaving alone:

```
NOTICED BUT NOT TOUCHING: <what you saw>
Why skipping: out-of-scope for this simplification
```

Log; do not silently resolve. A future pass can address it as its own slice.

## Pre-flight: Chesterton's Fence

Before removing or substantially changing any piece of code, verify you understand why it exists. Answer all five:

1. **Responsibility** — What does it do? (Trace inputs → outputs, including side effects.)
2. **Callers** — Who depends on it? (Grep for usages; check exported symbols.)
3. **Edge cases** — What hidden inputs does it handle? (Null, empty, error paths, rare type variants.)
4. **Tests** — What behaviors does it lock in? (Read the tests that cover it.)
5. **Git blame** — Why was it added? (`git log -L` or `git blame` on the lines. A named bug in the commit message is load-bearing context.)

If you can't answer all five, you haven't earned the right to remove it. Either read more, or emit `NOTICED BUT NOT TOUCHING` and move on.

## The Simplification Loop

Each simplification is one pass through this loop. **One simplification at a time** — verify after each. Do not batch.

Before the first slice, require a green unchanged baseline. When `## Establish a commit baseline` ran, reuse its successful `kramme:verify:run` result after the post-checkpoint worktree equality check passes; do not run the same battery twice. Otherwise run `kramme:verify:run` now. If the unchanged baseline fails, stop and handle or record that failure separately; do not mix a pre-existing failure with simplification work.

### 1. Pick one simplification

From the refreshed combined candidate queue, pick exactly one target. Candidates include:

- Dead code or dead paths.
- Twisted logic that can be straightened.
- Excessive parameters, flags that select behavior, options objects that are always the same shape.
- Premature optimization that adds indirection for no measured gain.
- Unnecessary abstraction layers — wrappers that forward with no logic.
- Obvious comments or docstrings that restate self-explanatory code.
- Defensive checks that caller, type, test, and history evidence prove redundant.
- Weak type workarounds, excessive logging, copy-paste residue, or style drift relative to the surrounding file.

Prefer clarity over line count. Keep a single-use helper when its name carries intent, and rename only to restore a demonstrated surrounding convention rather than personal taste.

### 2. Emit a SIMPLICITY CHECK

State the minimum change that accomplishes the simplification (see Markers).

### 3. Apply the change

Apply only that one change. Keep the diff small. If the diff grows past a few files or a few dozen lines, you are probably doing more than one thing — split the slice.

Record the exact newline-delimited paths changed by this simplification as `SLICE_PATHS`. Require a non-empty set wholly contained in `REFACTOR_SCOPE_PATHS`, with no protected or out-of-scope path. Use this same path set for verification, staging, commit selection, and post-commit validation.

If you notice something adjacent that also wants fixing, do not fix it — emit a `NOTICED BUT NOT TOUCHING` marker and continue.

### 4. Verify and commit

Run the project's verification battery via `kramme:verify:run` — build, typecheck, lint, and existing tests must all pass. **Tests must pass unmodified.** If a test fails, you changed behavior: revert the slice (`git restore` the touched files) and either re-plan or reclassify it as a behavior change handled outside this skill.

If `kramme:verify:run` cannot run (no test/lint/build configured, tool errors, etc.), stop and surface the gap. Do not declare the slice verified.

When verification passes, record `SLICE_BASELINE=$(git rev-parse HEAD)`, make a byte-for-byte backup of the actual index file using the same presence-aware procedure as the checkpoint, and inventory and snapshot the existence, verified contents, modes, and symlink targets of every tracked and untracked non-ignored worktree path, not only `SLICE_PATHS`. The inventory must identify non-ignored paths a commit hook creates after the snapshot. Limit both staging and commit selection to `SLICE_PATHS`; never use a blanket staging or commit operation that can consume pre-existing index entries.

If staging or commit fails, restore the actual index file byte-for-byte, compare the complete tracked and untracked non-ignored worktree against the verified snapshot, and restore every hook-caused delta, including out-of-scope changes and newly created non-ignored paths, while preserving the state that existed before the attempt. Require `HEAD` to still equal `SLICE_BASELINE`, require the index to byte-match its backup, and require the complete worktree inventory and snapshot to match before describing the remaining edit as verified. Stop with the recovery details and do not refresh discovery against an uncreated baseline.

After success, require the new commit's parent to equal `SLICE_BASELINE`, require its committed path set to equal `SLICE_PATHS`, and require the committed contents and modes to match the verified snapshot. Confirm that the complete tracked and untracked non-ignored worktree still matches the verified snapshot and that protected artifacts plus out-of-scope index state are unchanged. If a commit hook changes any worktree path from the verified snapshot, stop and surface the mutation. Only then does the committed state become the baseline for the next iteration.

### 5. Refresh and move to the next simplification

Return to default-mode candidate discovery with the new committed baseline, then start step 1 with the refreshed queue. Revalidate every remaining finding against current lines and discard anything the prior slice resolved or invalidated. Do not accumulate simplifications into one large diff.

## The Rewrite Process

Follow this process only in rewrite mode, after Step 0 and the shared "When NOT to proceed" gate.

### The core insight

First implementations often solve the problem but in a hacky way. Having solved the problem once, you now understand it deeply enough to implement it properly from scratch.

**Do not preserve the mediocre code.** The whole point is to start fresh.

### 1. Extract what you learned

Apply the shared Chesterton's Fence pre-flight to every non-trivial piece of the mediocre version before touching code. For the fifth criterion, check both git history and the current session: identify whether any piece was added in response to a bug discovered during this implementation.

Then articulate:

- What was the actual problem, rather than what you initially thought it was?
- What constraints did you discover?
- What edge cases matter?
- What dependencies or interactions exist?

If you cannot answer the five pre-flight questions for a piece, you haven't earned the right to scrap it. Read more first.

### 2. Identify the inelegance

Be specific about what is wrong with the current solution: unnecessary complexity, the wrong abstraction level, inappropriate coupling, duplicated logic, or difficulty understanding and maintaining it. Do not rewrite for taste alone.

### 3. Design the elegant solution

Think before coding. Emit the exact `SIMPLICITY CHECK` marker at design time:

```
SIMPLICITY CHECK: <one-line summary of the simplest elegant form that handles all discovered cases>
```

Then answer:

- What's the simplest approach that handles all the cases Chesterton's Fence surfaced?
- What abstraction, if any, makes this clearer? Default to none; abstractions are earned.
- How would you explain this solution to someone else?

If the design expands beyond the `SIMPLICITY CHECK`, write a second line naming the concrete requirement that forced the expansion. If there is no forcing requirement, stay at the simpler form.

### 4. Scrap and reimplement

1. **Create a recovery point** — Before reverting, preserve the mediocre fix so you can return to it if the rewrite turns out worse. Commit it on a throwaway branch (`git switch -c rewrite-baseline && git commit -am "baseline: pre-rewrite"`) or stash with a labeled message (`git stash push -u -m "pre-rewrite baseline"`). State the exact recovery command before continuing.
2. **Save the expected behavior** — Note the files touched and the behavior to verify against, including the edge cases surfaced by Chesterton's Fence. This is the spec the rewrite must satisfy.
3. **Revert the changes** — Return the working tree to the state before the mediocre fix.
4. **Implement the elegant solution** — Write it fresh, properly.
5. **Verify equivalence** — Delegate to `kramme:verify:run` for the project's verification battery. Every applicable configured build, typecheck, lint, and test gate must pass. If a test fails, the rewrite changed behavior — restore the recovery point or reclassify it as a behavior change. Apply the catch-all in Verification to every other failed or unavailable required gate.

"Existing tests" includes any tests written or modified during the current session. The rewrite must satisfy them unchanged. **Reject any rewrite that requires modifying tests to pass.**

Do not combine a rewrite with consistency renames. They are two changes: handle the rename as a separate slice, often in a separate PR.

If you notice adjacent work outside the saved rewrite scope, emit the exact `NOTICED BUT NOT TOUCHING` marker and leave it alone.

## Integration with other skills

- **Verification**: Step 4 delegates to `kramme:verify:run`.
- **Sibling — slice discipline**: `kramme:code:incremental` applies the same one-thing-at-a-time rule to feature work. Refactor passes obey the same six rules; this skill is the refactor-flavored loop.
- **Default aspect — AI slop**: default mode uses `kramme:deslop-reviewer` to seed the same verified simplification queue; AI provenance changes discovery, not mutation, verification, commit, or recovery behavior.
- **Alternative — scrap and rewrite**: if the recent code is inelegant enough that simplification would touch more than ~50% of it, stop the default loop and use this skill's `--rewrite` mode. A mediocre implementation is sometimes best scrapped rather than patched.
- **Broader scan**: if the simplification opportunities extend beyond the recent diff, stop and suggest `kramme:code:refactor-opportunities` for a codebase-wide scan.

## Verification

The default-mode loop owns baseline health, the Fence, scope, one-slice changes, unmodified tests, and recovery. Before declaring the pass complete, confirm:

- The final diff is simpler and clearer than the input. Length alone is not decisive; any longer result needs a stated clarity gain.
- Every observation outside the original scope has a `NOTICED BUT NOT TOUCHING` marker; none were silently fixed.

For rewrite mode, confirm the end state rather than repeating each process gate:

- [ ] The recovery point remains available until the rewrite is accepted.
- [ ] The rewrite's behavior matches the saved-state notes, including edge cases.
- [ ] `kramme:verify:run` passed every applicable gate without modifying existing tests.
- [ ] No bug found during the rewrite was silently folded in — any bug fix is a separate slice.
- [ ] The rewrite is clearer than the original; otherwise restore the baseline.

If any applicable verification box remains unchecked, finish the gap. If the gap cannot be closed within a behavior-preserving rewrite, or `kramme:verify:run` cannot execute a required gate, restore the recovery point and surface the failure. Do not leave a failed rewrite as the current result.
