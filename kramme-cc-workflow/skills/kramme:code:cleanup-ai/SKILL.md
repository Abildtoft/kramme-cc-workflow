---
name: kramme:code:cleanup-ai
description: Remove AI-generated code slop from a branch. Use when cleaning up AI-generated code, removing unnecessary comments, defensive checks, or type casts. Checks the branch diff against the resolved base and fixes style inconsistencies. Not for generated, vendored, lockfile, snapshot, or `*.d.ts` files.
argument-hint: "[base-branch] [--auto]"
disable-model-invocation: true
user-invocable: true
kramme-platforms: [claude-code]
---

# Remove AI Code Slop

This skill uses the `kramme:deslop-reviewer` agent to identify AI slop in the branch's diff against a base, then applies the agent's recommended fixes.

Parse `$ARGUMENTS` before the preconditions. If `--auto` is present, set `AUTO_MODE=true` and remove the flag before base-branch resolution. `--auto` applies medium-confidence cleanup findings automatically; it does not bypass dirty-worktree protection or behavior/API/test-expectation safeguards.

## Preconditions

Run `git status --porcelain`. If the working tree is dirty and `AUTO_MODE=true`, stop with `MISSING REQUIREMENT: working tree is dirty; rerun without --auto to decide whether to continue`. If the working tree is dirty and `AUTO_MODE` is false, confirm with the user before continuing — the skill's edits will land alongside theirs in `git diff` and will be hard to separate when reverting.

## Process

1. **Resolve the base branch** — try these sources in order; use the first non-empty value:
   - The argument passed to this skill.
   - `gh pr view --json baseRefName --jq '.baseRefName' 2>/dev/null`
   - `git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@'`

   Assign the result to `BASE_BRANCH` with any leading `origin/` stripped, then validate and fetch:

   ```bash
   git check-ref-format --branch "$BASE_BRANCH" && \
     git fetch origin "refs/heads/${BASE_BRANCH}:refs/remotes/origin/${BASE_BRANCH}" && \
     git rev-parse --verify --quiet "origin/$BASE_BRANCH"
   ```

   On failure, stop and ask the user to re-run with the base branch as the skill argument.

2. **Scan for slop**

   Launch `kramme:deslop-reviewer` in code review mode against `git diff origin/$BASE_BRANCH...HEAD`.

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
