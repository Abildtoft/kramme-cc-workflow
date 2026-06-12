---
name: kramme:verify:before-completion
description: Use when about to claim work is complete, fixed, or passing, before committing or creating PRs - requires running verification commands and confirming output before making any success claims; evidence before assertions always
user-invocable: false
disable-model-invocation: false
---

# Verification Before Completion

## Overview

Claiming work is complete without verification is dishonesty, not efficiency.

**Core principle:** Evidence before claims, always.

**Violating the letter of this rule is violating the spirit of this rule.**

This skill runs your project's own verification commands (tests, build, lint) and gates claims on their output. To discover and run the project's checks, use `kramme:verify:run`. It produces no artifact and changes no code, except the optional regression red-green check below, which temporarily reverts a fix.

## The Iron Law

```
NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE
```

If you haven't run the verification command in this message, you cannot claim it passes.

## The Gate Function

```
BEFORE claiming any status or expressing satisfaction:

1. IDENTIFY: What command proves this claim?
2. RUN: Execute the FULL command (fresh, complete)
3. READ: Full output, check exit code, count failures
4. VERIFY: Does output confirm the claim?
   - If NO: State actual status with evidence
   - If YES: State claim WITH evidence
5. ONLY THEN: Make the claim

Skip any step = lying, not verifying
```

If no command can prove the claim — no test/build/lint exists, or it cannot run in this environment — say so explicitly: name what you changed and what you could not verify. "Cannot verify X here" is an honest status; "X passes" without evidence is not.

## Common Failures

| Claim | Requires | Not Sufficient |
| --- | --- | --- |
| Tests pass | Test command output: 0 failures | Previous run, "should pass" |
| Linter clean | Linter output: 0 errors | Partial check, extrapolation |
| Build succeeds | Build command: exit 0 | Linter passing, logs look good |
| Bug fixed | Test original symptom: passes | Code changed, assumed fixed |
| Regression test works | Red-green cycle verified | Test passes once |
| Agent completed | VCS diff shows changes | Agent reports "success" |
| Requirements met | Line-by-line checklist | Tests passing |

## When To Apply — Red Flags That Mean STOP

Run the gate before ANY of these:

- A success/completion claim or expression of satisfaction ("Great!", "Perfect!", "Done!")
- Any positive statement about work state, or hedging like "should", "probably", "seems to"
- Committing, pushing, creating a PR, completing a task, or moving to the next one
- Trusting an agent's success report, or relying on a partial check
- Thinking "just this once" or "I'm tired and want this over"

The rule covers exact phrases, paraphrases, synonyms, and **ANY wording implying success without fresh verification**. Different words do not exempt you.

## Rationalization Prevention

| Excuse                                  | Reality                |
| --------------------------------------- | ---------------------- |
| "Should work now"                       | RUN the verification   |
| "I'm confident"                         | Confidence ≠ evidence  |
| "Just this once"                        | No exceptions          |
| "Linter passed"                         | Linter ≠ compiler      |
| "Agent said success"                    | Verify independently   |
| "I'm tired"                             | Exhaustion ≠ excuse    |
| "Partial check is enough"               | Partial proves nothing |
| "Different words so rule doesn't apply" | Spirit over letter     |

## Key Patterns

**Tests:**

```
✅ [Run test command] [See: 34/34 pass] "All tests pass"
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
- Honesty is a core value; a claim without evidence is a lie, not a shortcut
