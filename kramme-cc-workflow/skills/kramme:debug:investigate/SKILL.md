---
name: kramme:debug:investigate
description: "Structured bug investigation workflow: reproduce, isolate, trace root cause, and fix. Use when debugging a bug, investigating an error, or tracking down a regression."
argument-hint: "[bug description, error message, or issue reference] [--auto]"
disable-model-invocation: true
user-invocable: true
---

# Bug Investigation

Structured debugging workflow: reproduce, isolate, trace root cause, and fix. Maintains an investigation log throughout with evidence and confidence assessment.

**IMPORTANT:** Follow all phases systematically. Do not skip to a fix without tracing the root cause first.

**Not for:** performance profiling, greenfield feature work, or changes whose cause is already known — go straight to the change in those cases.

Parse `$ARGUMENTS` before Step 1. If `--auto` is present, set `AUTO_MODE=true` and remove the flag from the bug description. `--auto` chooses conservative debugging defaults and continues without strategy prompts when evidence is sufficient. It does not bypass required bug input, low-confidence stops, reproduction gaps that make a fix speculative, or verification failure handling.

## Process Overview

```
/kramme:debug:investigate "TypeError: Cannot read property 'id' of undefined"
    |
    v
[Step 1: Parse Input] -> Bug description / error / Linear issue
    |
    v
[Step 2: Reproduce] -> Confirm bug exists, find trigger
    |
    v
[Step 3: Isolate] -> Narrow scope to files/functions
    |
    v
[Step 4: Trace Root Cause] -> Follow data flow, git bisect if regression
    |
    v
[Step 5: Document Findings] -> Structured investigation log
    |
    v
[Step 6: Propose Fix] -> Confidence assessment + user approval
    |
    v
[Step 7: Implement and Verify] -> Fix + regression test + verify
    |
    v
[Step 8: Summary] -> Root cause, fix, verification status
```

---

## Step 1: Parse Input

1. If `$ARGUMENTS` matches a **Linear issue pattern** (e.g., `TEAM-123`):
   - Fetch via the Linear MCP integration (e.g., `mcp__linear__get_issue`).
   - Extract: description, steps to reproduce, expected vs. actual behavior.
   - If Linear MCP unavailable: treat as plain text, ask user to paste issue content.

2. If `$ARGUMENTS` contains an **error message**: use as a grep search target.

3. If `$ARGUMENTS` is **free text**: use as bug description.

4. If `$ARGUMENTS` is **empty**: ask the user — "What bug should I investigate? Describe it, paste an error message, or provide a Linear issue ID." Wait for a response before continuing.

Store as `BUG_DESCRIPTION`.

---

## Step 2: Reproduce

1. **Search the codebase** for the error message or relevant symbols using Grep.

2. **Check for existing tests** that cover the affected area — run them.

3. If reproduction is found, log: `[REPRODUCE] Confirmed via {method}`

4. If **no reproduction path found**:

If `AUTO_MODE=true`, do not ask for reproduction steps. Continue with static investigation only, log `[REPRODUCE] unconfirmed via available local evidence`, and do not implement a fix later unless the root cause becomes High confidence and a regression test can be written from code evidence.

Otherwise:

Ask the user, using a structured-question capability when the harness provides one. If not, ask the same question in plain text with a numbered list and wait for the response:

```
Header: Reproduction
Question: How can this bug be reproduced?
Options:
1. Run specific test — I'll provide the test command
2. Steps to follow — I'll describe the reproduction steps
3. Cannot reproduce — the bug is intermittent or environment-specific
```

5. Log: `[REPRODUCE] {method} → {result: confirmed/unconfirmed}`

---

## Step 3: Isolate

1. From the error location (Step 2), **identify affected files**.

2. **Read surrounding code** to understand module boundaries and data flow.

3. **Grep for all callers and call sites** of the affected function/method.

4. **Classify the scope:**
   - Single function — bug is contained
   - Module interaction — bug arises from how modules communicate
   - Data flow — bug is in the data transformation pipeline

5. If **multiple candidate areas** found:

If `AUTO_MODE=true`, investigate all candidates and keep a short evidence note for each before narrowing. Otherwise:

Ask the user, using a structured-question capability when the harness provides one. If not, ask the same question in plain text with a numbered list and wait for the response:

```
Header: Multiple Candidate Areas
Question: The bug could originate in several areas. Where should I focus first?
Options:
1. "{area 1}: {evidence}"
2. "{area 2}: {evidence}"
3. "Investigate all candidates"
```

6. Log: `[ISOLATE] Scope narrowed to {files/functions}`

---

## Step 4: Trace Root Cause

1. **Read identified code paths** in full. Follow execution from trigger to error.

2. **Check for regression** — if the bug may have been introduced recently:

If `AUTO_MODE=true`, use git bisect only when both a known-good commit and an automated failing command are available without user input. Otherwise continue manual trace and note that bisect was skipped. If `AUTO_MODE` is false:

Ask the user, using a structured-question capability when the harness provides one. If not, ask the same question in plain text with a numbered list and wait for the response:

```
Header: Regression Investigation
Question: This looks like it may be a regression. Use git bisect to find the introducing commit?
Options:
1. Yes, run git bisect
2. No, continue manual trace
```

3. **If bisecting:**
   - Read the bisect guide from `references/bisect-guide.md`.
   - Identify known-good commit: ask user, or find recent tag/release.
   - If a failing test exists, automate: `git bisect run <test-command>`.
   - Otherwise, guide manual bisect steps.
   - **Always run `git bisect reset` when finished — and before any fallback or early exit — to restore the working tree.**

4. **Consult investigation patterns:**
   - Read common patterns from `references/investigation-patterns.md`.
   - Match symptoms to known patterns.
   - Apply recommended checks for the matching pattern.

5. **Trace data flow** from origin to error point. Track variable values through assignments and transformations.

6. Log: `[ROOT CAUSE] {description} at {file}:{line}`

---

## Step 5: Document Findings

Read the log template from `assets/investigation-log.md` and fill it in from the timeline logs (`[REPRODUCE]`, `[ISOLATE]`, `[ROOT CAUSE]`) and findings gathered so far. Capture evidence — code snippets, test output, bisect results — under the relevant sections.

Store the completed log for inclusion in the final summary.

---

## Step 6: Propose Fix

1. **Assess confidence:**
   - **High** — root cause is clear, fix is straightforward, side effects are minimal
   - **Medium** — root cause is likely correct, fix may have side effects
   - **Low** — root cause is uncertain, multiple possible explanations

2. If confidence is **Low**: present findings to user before proceeding. In `AUTO_MODE`, skip directly to Step 8 with `Fix Applied: No`.

3. If `AUTO_MODE=true` and confidence is High or Medium, choose **Implement fix + write regression test** only when reproduction was confirmed. If reproduction was unconfirmed, implement only when confidence is High and a deterministic regression test can be written from code evidence; otherwise skip directly to Step 8 with `Fix Applied: No`. When reproduction was confirmed but no local test framework or deterministic regression test path exists, implement the minimal fix and note `Regression Test: skipped - no deterministic local test path found`. If confidence is Low, report only.

Otherwise ask the user, using a structured-question capability when the harness provides one. If not, ask the same question in plain text with a numbered list and wait for the response:

```
Header: Fix Strategy
Question: Root cause identified with {confidence} confidence. How to proceed?
Options:
1. Implement fix + write regression test
2. Implement fix only, skip test
3. Report findings only, do not change code
```

If **Report only**: skip to Step 8.

---

## Step 7: Implement and Verify

### 7a. Apply the Fix

- Make the **minimal code change** that addresses the root cause.
- Avoid unrelated refactoring — fix only the bug.
- Log: `[FIX] Applied at {file}:{line}`

### 7b. Write Regression Test (if requested)

- Write a test that **fails without the fix** and **passes with it** (red-green).
- Place near existing tests for the affected module.
- Log: `[TEST] Regression test at {test_file}`

### 7c. Verify

- Run verification: reference `/kramme:verify:run` if available.
- Check: regression test passes, no existing tests broken, build succeeds.

### 7d. Iterate if Needed

- If verification fails: analyze and adjust the fix.
- **Maximum 3 iterations.** After 3 attempts, present failures to user.
- Log: `[VERIFY] Tests: {PASS/FAIL}, Build: {PASS/FAIL}`

---

## Step 8: Summary

```
Bug Investigation Complete
==========================

Bug: {BUG_DESCRIPTION}
Root Cause: {one-line summary}
Confidence: High / Medium / Low
Location: {file}:{line}

Fix Applied: Yes / No
  Files Modified: {list}
  Regression Test: {test file path}

Verification:
  Tests: PASS / FAIL
  Build: PASS / FAIL

Investigation Log:
  (include the completed log from Step 5)
```

**STOP** — Do not continue beyond this point. The investigation is complete.

---

## Error Handling

| Scenario | Action |
| --- | --- |
| Error message not found in codebase | Widen search: partial matches, case-insensitive, related symbols. Ask user for context. |
| Git bisect fails | Run `git bisect reset` to restore the tree, then fall back to manual trace using investigation patterns. |
| Fix verification fails after 3 iterations | Present failures, suggest manual investigation. |
| Linear MCP unavailable | Treat issue ref as text, ask user to paste content. |
| No test framework detected | Skip regression test. Note in summary. |
| Codebase too large for broad grep | Ask user to narrow scope to specific directories. |
