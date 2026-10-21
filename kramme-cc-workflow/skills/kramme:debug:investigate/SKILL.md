---
name: kramme:debug:investigate
description: "Structured bug investigation workflow: reproduce, isolate, trace root cause, and fix. Use when debugging a bug, investigating an error, or tracking down a regression."
argument-hint: "[bug description, error message, or issue reference] [--auto]"
disable-model-invocation: true
user-invocable: true
---

# Bug Investigation

Structured debugging workflow: reproduce, isolate, trace root cause, and fix. Maintains an investigation log throughout with evidence and confidence assessment.

Trace the root cause before proposing a fix; a fix without a traced cause usually treats a symptom.

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
   - Fetch via Linear MCP `get_issue` (Claude Code `mcp__linear__get_issue`; Codex `get_issue`).
   - Extract: description, steps to reproduce, expected vs. actual behavior.
   - If Linear MCP unavailable: treat as plain text, ask user to paste issue content.

2. If `$ARGUMENTS` contains an **error message**: use as a grep search target.

3. If `$ARGUMENTS` is **free text**: use as bug description.

4. If `$ARGUMENTS` is **empty**: ask the user — "What bug should I investigate? Describe it, paste an error message, or provide a Linear issue ID." Wait for a response before continuing.

Store as `BUG_DESCRIPTION`.

---

## Steps 2–5: Reproduce, Isolate, Trace, and Document

Read `${CLAUDE_PLUGIN_ROOT}/shared/debug/references/root-cause-investigation.md` and follow it with `BUG_DESCRIPTION` from Step 1 and `UNATTENDED` set to the value of `AUTO_MODE`. Its Reproduce, Isolate, Trace Root Cause, and Document Findings sections are Steps 2–5 of this workflow, and its Assess Confidence section supplies the rating Step 6 uses. The procedure uses the bisect guide at `${CLAUDE_PLUGIN_ROOT}/shared/debug/references/bisect-guide.md`, the pattern catalog at `${CLAUDE_PLUGIN_ROOT}/shared/debug/references/investigation-patterns.md`, and the log template at `${CLAUDE_PLUGIN_ROOT}/shared/debug/assets/investigation-log.md`. Keep its timeline markers, completed log, confidence rating, and reproduction status for Steps 6–8. The procedure never edits code; fixing starts in Step 6.

---

## Step 6: Propose Fix

1. **Use the confidence rating** (High / Medium / Low) from the shared procedure's Assess Confidence section.

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

CHANGES MADE
- Fix Applied: Yes / No
- Files Modified: {list, or "none"}
- Regression Test: {test file path, or "none"}
- Verification: Tests PASS / FAIL, Build PASS / FAIL

THINGS I DIDN'T TOUCH
- {NOTICED BUT NOT TOUCHING entries — out-of-scope issues spotted during investigation, or "none"}

POTENTIAL CONCERNS
- {unverified assumptions, unconfirmed reproduction, skipped regression test, or Low/Medium confidence caveats, or "none"}

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
