---
name: kramme:verify:before-completion
description: Use when about to claim work is complete, fixed, or passing, before committing or creating PRs - requires verification evidence for the current working tree before any success claim, reusing a green run only when the tree is unchanged; evidence before assertions always
disable-model-invocation: false
user-invocable: false
---

# Verification Before Completion

## Overview

Claiming work is complete without fresh verification evidence leaves the claim unsupported.

**Core principle:** Evidence before claims, always.

This skill runs your project's own verification commands (tests, build, lint) and gates claims on their output. To discover and run the project's checks, use `kramme:verify:run`. It produces no artifact and changes no code, except the optional regression red-green check below, which temporarily reverts a fix.

## The Iron Law

```
NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE
```

Fresh means the evidence covers the exact working tree the claim is about. A command run in this message qualifies. A green run from earlier in this session also qualifies when the tree has not changed since; see [Reusing a Green Run](#reusing-a-green-run). Anything else cannot support a claim that it passes.

## The Gate Function

```
BEFORE claiming any status or expressing satisfaction:

1. IDENTIFY: What command proves this claim?
2. RUN: Execute the FULL command (fresh, complete), or confirm a green
   run on this exact tree still covers it
3. READ: Full output, check exit code, count failures
4. VERIFY: Does output confirm the claim?
   - If NO: State actual status with evidence
   - If YES: State claim WITH evidence
5. ONLY THEN: Make the claim

Skip any step = the claim remains unverified
```

If no command can prove the claim — no test/build/lint exists, or it cannot run in this environment — say so explicitly: name what you changed and what you could not verify. "Cannot verify X here" is an honest status; "X passes" without evidence is not.

For claims about user experience (UX: clear, reliable task completion), developer experience (DX: understanding, maintenance, testing, and debugging), or agent experience (AX: context discovery, predictable execution, recovery, and verification), identify evidence appropriate to the affected workflow. Check established behavior and contracts outside the intended change with relevant regression coverage, and verify intentional changes against the new expectations. Report material tradeoffs and verification limits; passing checks do not prove that nothing can break. Unchanged or inapplicable dimensions need no invented improvement or extra work outside scope.

## Common Failures

| Claim | Requires | Not Sufficient |
| --- | --- | --- |
| Tests pass | Test command output: 0 failures, on this tree | Run on an earlier or unknown tree, "should pass" |
| Linter clean | Linter output: 0 errors | Partial check, extrapolation |
| Build succeeds | Build command: exit 0 | Linter passing, logs look good |
| Bug fixed | Test original symptom: passes | Code changed, assumed fixed |
| Regression test works | Red-green cycle verified | Test passes once |
| Agent completed | VCS diff shows changes | Agent reports "success" |
| Requirements met | Line-by-line checklist | Tests passing |

## Reusing a Green Run

Record the working-tree ID with every green run; `kramme:verify:run` reports it as `Verified tree`. For any other command, capture it with `"${CODEX_HOME:-$HOME/.codex}/plugins/cache/kramme-cc-workflow/kramme-cc-workflow/0.87.0/scripts/worktree-tree-id.sh"` immediately before the run. Before reusing that run, capture the ID again. Reuse the run instead of repeating it only when:

- both IDs are non-empty and equal, which still holds after committing, amending, or recreating commits over the same content;
- the recorded `BASE_REF` and `MERGE_BASE` are unchanged whenever the run used base-scoped or affected checks;
- it covered every check the claim needs; and
- no ignored input the checks read has changed since, such as installed dependencies, generated code, or local env files.

For base-scoped checks, record the resolved `BASE_REF` and `MERGE_BASE` before execution and resolve them again using the same configuration and `resolve-base.sh` procedure as `kramme:verify:run` before reuse. Compare `BASE_REF`'s resolved commit OID, not just its ref name; unavailable or changed base evidence invalidates reuse. Otherwise run again. Quote the reused run's result, tree ID, and applicable base evidence in the claim.

## Choosing the Tier

Match the checks to the claim, following the project's documented cadence when it has one:

- **While iterating**: a fast loop or focused check covering the change backs a claim about that change.
- **Before the first push or Pull Request**: run the project's full sweep once, for example `kramme:verify:run --full`.
- **After a failure**: use `kramme:verify:run`'s Narrowed Retry by the Caller procedure after fixing it: rerun recorded failed commands, invoke `--fast`, and rerun any passing check whose inputs or dependent behavior changed. Report carried checks with their original tree and independence proof; partial coverage cannot support a full-verification claim.
- **After the branch is pushed**: CI can supply the full sweep when its successful jobs on that commit demonstrably cover every required check. Cite those job results; skipped jobs or status-only checks do not prove coverage. Run the missing checks locally when CI is absent or coverage is incomplete or unknown.

Never run two overlapping full sweeps on the same tree.

## When To Apply

Run the gate before any of these:

- A success/completion claim or expression of satisfaction ("Great!", "Perfect!", "Done!")
- Any positive statement about work state, or hedging like "should", "probably", "seems to"
- Committing, pushing, creating a PR, completing a task, or moving to the next one
- Trusting an agent's success report, or relying on a partial check

The gate applies to any wording that implies success, not only these phrases.

## Key Patterns

**Tests:**

```
✅ [Run test command] [See: 34/34 pass] "All tests pass"
✅ [Tree ID unchanged since the 34/34 run] "All tests pass (run on tree <id>)"
❌ "Should pass now" / "Looks correct"
```

**Regression tests (TDD Red-Green):**

```
✅ Write → Run (pass) → Revert fix via VCS (git stash push -- <files changed by the fix>) → Run (MUST FAIL) → Restore (git stash pop) → Run (pass)
❌ "I've written a regression test" (without red-green verification)
```

Scope the stash to the files the fix changed so unrelated working-tree changes stay untouched. If `git stash pop` conflicts, resolve the conflict preserving the fix — or abort and tell the user the tree needs manual attention.

**Build:**

```
✅ [Run build] [See: exit 0] "Build passes"
❌ "Linter passed" (linter doesn't check compilation)
```

**Requirements:**

```
✅ Re-read plan → Create checklist → Verify each → Report gaps or completion
❌ "Tests pass, phase complete"
```

**Agent delegation:**

```
✅ Agent reports success → Check VCS diff → Verify changes → Report actual state
❌ Trust agent report
```

## Why This Matters

False completion claims have concrete costs:

- Trust breaks — once a claim proves false, every later claim is doubted
- Broken code ships — undefined functions and unhandled cases that crash in use
- Incomplete features ship — requirements silently missed
- Rework — time lost to redirect-and-redo after a false "done"
- Evidence is a core requirement; a claim without it remains unproven
