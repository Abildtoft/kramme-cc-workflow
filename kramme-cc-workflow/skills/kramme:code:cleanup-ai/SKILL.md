---
name: kramme:code:cleanup-ai
description: Remove AI-generated code slop from a branch. Use when cleaning up AI-generated code, removing unnecessary comments, defensive checks, or type casts. Checks the branch diff against the resolved base and fixes style inconsistencies. Not for generated, vendored, lockfile, snapshot, or `*.d.ts` files.
argument-hint: "[base-branch] [--auto]"
disable-model-invocation: true
user-invocable: true
kramme-platforms: [claude-code, codex]
---

# Remove AI Code Slop

This skill uses the `kramme:deslop-reviewer` agent to identify AI slop in the branch's diff against a base, then applies the agent's recommended fixes.

Sibling: this is the AI-slop-specific pass via `kramme:deslop-reviewer`; for a general simplification pass on the same post-feature branch, use `kramme:code:refactor-pass`.

Parse `$ARGUMENTS` before the preconditions. If `--auto` is present, set `AUTO_MODE=true` and remove the flag before base-branch resolution. If one non-option argument remains, set `BASE_BRANCH_OVERRIDE` to that value. `--auto` applies medium-confidence cleanup findings automatically; it does not bypass dirty-worktree protection or behavior/API/test-expectation safeguards.

## Preconditions

Run `git status --porcelain`. If the working tree is dirty and `AUTO_MODE=true`, stop with `MISSING REQUIREMENT: working tree is dirty; rerun without --auto to decide whether to continue`. If the working tree is dirty and `AUTO_MODE` is false, confirm with the user before continuing — the skill's edits will land alongside theirs in `git diff` and will be hard to separate when reverting.

## Process

Synced base/diff scope contract (keep aligned across base-aware and diff-aware skills): use scripts/resolve-base.sh for base refs; use scripts/collect-review-diff.sh for unified changed-file scope; canonical base priority is explicit --base, PR target branch, then origin/HEAD, origin/main, or origin/master, and canonical diff scope is committed PR diff from MERGE_BASE...HEAD plus staged, unstaged, and untracked paths.

1. **Resolve the base branch** — use the shared plugin script. The optional positional base argument becomes `BASE_BRANCH_OVERRIDE`; otherwise let the script resolve the PR target branch and remote default fallback chain.

   ```bash
   RESOLVE_ARGS=(--strict)
   [ -n "${BASE_BRANCH_OVERRIDE:-}" ] && RESOLVE_ARGS+=(--base "$BASE_BRANCH_OVERRIDE")

   RESOLVED=$("${CLAUDE_PLUGIN_ROOT}/scripts/resolve-base.sh" "${RESOLVE_ARGS[@]}") || {
     echo "Base resolution failed; see the message above and stop. Re-run with a base branch argument if the target branch is ambiguous." >&2
     exit 1
   }
   eval "$RESOLVED"
   ```

   The script exports `BASE_REF`, `BASE_BRANCH`, and `MERGE_BASE`.

2. **Scan for slop**

   If `git diff "$MERGE_BASE"...HEAD` is empty, report "no branch changes to review" and stop.

   Launch `kramme:deslop-reviewer` in code review mode against `git diff "$MERGE_BASE"...HEAD`.

3. **Filter the findings**

   Discard any finding whose file is generated, vendored, a lockfile, a snapshot, or `*.d.ts` before deciding what to fix.

4. **Apply fixes by confidence**

   The agent scores findings 0–100. Apply the agent's specific recommendation per finding — do not pattern-match generically:
   - **≥76**: auto-apply.
   - **51–75**: summarize the finding to the user and apply on confirmation. If `AUTO_MODE=true`, apply automatically and count it separately as medium-confidence auto-applied.
   - **<51**: skip; list in the final report.

   Leave a finding unchanged when applying it would alter test expectations, public APIs, or behavior the agent itself flagged as possibly intentional.

5. **Report**

   1–3 sentences: which files were edited, plus counts for applied / confirmed / skipped / filtered.
