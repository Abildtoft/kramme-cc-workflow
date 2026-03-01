---
name: kramme:debug:investigate
description: "(experimental) Structured bug investigation workflow: reproduce, isolate, trace root cause, and fix. Use when debugging a bug, investigating an error, or tracking down a regression."
argument-hint: "[bug description, error message, or issue reference]"
disable-model-invocation: true
user-invocable: true
---

# Bug Investigation

Structured debugging workflow: reproduce, isolate, trace root cause, and fix. Maintains an investigation log throughout with evidence and confidence assessment.

**IMPORTANT:** Follow all phases systematically. Do not skip to a fix without tracing the root cause first.

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
   - Fetch via `mcp__linear__get_issue`.
   - Extract: description, steps to reproduce, expected vs. actual behavior.
   - If Linear MCP unavailable: treat as plain text, ask user to paste issue content.

2. If `$ARGUMENTS` contains an **error message**: use as a grep search target.

3. If `$ARGUMENTS` is **free text**: use as bug description.

4. If `$ARGUMENTS` is **empty**:

```
AskUserQuestion
header: Bug Description
question: What bug should I investigate?
options:
  - (freeform) Describe the bug, paste an error message, or provide a Linear issue ID
```

Store as `BUG_DESCRIPTION`.

---

## Step 2: Reproduce

1. **Search the codebase** for the error message or relevant symbols using Grep.

2. **Check for existing tests** that cover the affected area — run them.

3. If reproduction is found, log: `[REPRODUCE] Confirmed via {method}`

4. If **no reproduction path found**:

```
AskUserQuestion
header: Reproduction
question: How can this bug be reproduced?
options:
  - Run specific test — I'll provide the test command
  - Steps to follow — I'll describe the reproduction steps
  - Cannot reproduce — the bug is intermittent or environment-specific
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

```
AskUserQuestion
header: Multiple Candidate Areas
question: The bug could originate in several areas. Where should I focus first?
options:
  - "{area 1}: {evidence}"
  - "{area 2}: {evidence}"
  - "Investigate all candidates"
```

6. Log: `[ISOLATE] Scope narrowed to {files/functions}`

---

## Step 4: Trace Root Cause

1. **Read identified code paths** in full. Follow execution from trigger to error.

2. **Check for regression** — if the bug may have been introduced recently:

```
AskUserQuestion
header: Regression Investigation
question: This looks like it may be a regression. Use git bisect to find the introducing commit?
options:
  - Yes, run git bisect
  - No, continue manual trace
```

3. **If bisecting:**
   - Read the bisect guide from `resources/references/bisect-guide.md`.
   - Identify known-good commit: ask user, or find recent tag/release.
   - If a failing test exists, automate: `git bisect run <test-command>`.
   - Otherwise, guide manual bisect steps.

4. **Consult investigation patterns:**
   - Read common patterns from `resources/references/investigation-patterns.md`.
   - Match symptoms to known patterns.
   - Apply recommended checks for the matching pattern.

5. **Trace data flow** from origin to error point. Track variable values through assignments and transformations.

6. Log: `[ROOT CAUSE] {description} at {file}:{line}`

---

## Step 5: Document Findings

Read the investigation log template from `resources/templates/investigation-log.md`.

Compile the investigation log:

```markdown
## Investigation: {BUG_DESCRIPTION}

### Timeline
1. [REPRODUCE] {method} → {result}
2. [ISOLATE] Scope: {files/functions}
3. [TRACE] {method used}
4. [ROOT CAUSE] {description} at {file}:{line}

### Root Cause Analysis
- **What:** {what goes wrong}
- **Where:** {file}:{line}
- **Why:** {explanation of the mechanism}
- **When introduced:** {commit if bisected, else "unknown"}

### Evidence
{code snippets, test output, bisect results}
```

Store the log for inclusion in the final summary.

---

## Step 6: Propose Fix

1. **Assess confidence:**
   - **High** — root cause is clear, fix is straightforward, side effects are minimal
   - **Medium** — root cause is likely correct, fix may have side effects
   - **Low** — root cause is uncertain, multiple possible explanations

2. If confidence is **Low**: present findings to user before proceeding.

3. Ask the user:

```
AskUserQuestion
header: Fix Strategy
question: "Root cause identified with {confidence} confidence. How to proceed?"
options:
  - Implement fix + write regression test
  - Implement fix only, skip test
  - Report findings only, do not change code
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
|---|---|
| Error message not found in codebase | Widen search: partial matches, case-insensitive, related symbols. Ask user for context. |
| Git bisect fails | Fall back to manual trace using investigation patterns. |
| Fix verification fails after 3 iterations | Present failures, suggest manual investigation. |
| Linear MCP unavailable | Treat issue ref as text, ask user to paste content. |
| No test framework detected | Skip regression test. Note in summary. |
| Codebase too large for broad grep | Ask user to narrow scope to specific directories. |
