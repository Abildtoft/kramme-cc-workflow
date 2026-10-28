# Root-Cause Investigation

This procedure is shared by `kramme:debug:investigate` (its Steps 2–5) and `kramme:debug:triage-to-issue` (its Phase 3). It reproduces, isolates, and traces one bug and records evidence. It never edits code, writes tests, or proposes or applies a fix; the calling skill owns anything after the hand-back.

## Caller Inputs

- `BUG_DESCRIPTION`: the caller's parsed bug description, error message, or issue content.
- `UNATTENDED`: `true` means never stop for a question and apply each gate's stated unattended default; `false` means ask with a structured-question capability when the harness provides one, otherwise in plain text with a numbered list, and wait.

Supporting files: `${CODEX_HOME:-$HOME/.codex}/plugins/cache/kramme-cc-workflow/kramme-cc-workflow/0.90.0/shared/debug/references/bisect-guide.md`, `${CODEX_HOME:-$HOME/.codex}/plugins/cache/kramme-cc-workflow/kramme-cc-workflow/0.90.0/shared/debug/references/investigation-patterns.md`, and `${CODEX_HOME:-$HOME/.codex}/plugins/cache/kramme-cc-workflow/kramme-cc-workflow/0.90.0/shared/debug/assets/investigation-log.md`.

## 1. Reproduce

1. **Search the codebase** for the error message or relevant symbols using Grep.

2. **Check for existing tests** that cover the affected area — run them.

3. If reproduction is found, log: `[REPRODUCE] Confirmed via {method}`

4. If **no reproduction path found**:

If `UNATTENDED=true`, do not ask for reproduction steps. Continue with static investigation only, log `[REPRODUCE] unconfirmed via available local evidence`, and report reproduction as unconfirmed to the caller.

Otherwise:

Ask the user, using a structured-question capability when the harness provides one. If not, ask the same question in plain text with a numbered list and wait for the response:

Ask the user directly in chat:
Question label: Reproduction
Question: How can this bug be reproduced?
5. Log: `[REPRODUCE] {method} → {result: confirmed/unconfirmed}`

## 2. Isolate

1. From the error location (Step 2), **identify affected files**.

2. **Read surrounding code** to understand module boundaries and data flow.

3. **Grep for all callers and call sites** of the affected function/method.

4. **Classify the scope:**
   - Single function — bug is contained
   - Module interaction — bug arises from how modules communicate
   - Data flow — bug is in the data transformation pipeline

5. If **multiple candidate areas** found:

If `UNATTENDED=true`, investigate all candidates and keep a short evidence note for each before narrowing. Otherwise:

Ask the user, using a structured-question capability when the harness provides one. If not, ask the same question in plain text with a numbered list and wait for the response:

Ask the user directly in chat:
Question label: Multiple Candidate Areas
Question: The bug could originate in several areas. Where should I focus first?
6. Log: `[ISOLATE] Scope narrowed to {files/functions}`

## 3. Trace Root Cause

1. **Read identified code paths** in full. Follow execution from trigger to error.

2. **Check for regression** — if the bug may have been introduced recently:

If `UNATTENDED=true`, use git bisect only when both a known-good commit and an automated failing command are available without user input. Otherwise continue manual trace and note that bisect was skipped. If `UNATTENDED` is false:

Ask the user, using a structured-question capability when the harness provides one. If not, ask the same question in plain text with a numbered list and wait for the response:

Ask the user directly in chat:
Question label: Regression Investigation
Question: This looks like it may be a regression. Use git bisect to find the introducing commit?
3. **If bisecting:**
   - Read the bisect guide from `${CODEX_HOME:-$HOME/.codex}/plugins/cache/kramme-cc-workflow/kramme-cc-workflow/0.90.0/shared/debug/references/bisect-guide.md`.
   - Identify known-good commit: ask user, or find recent tag/release.
   - If a failing test exists, automate: `git bisect run <test-command>`.
   - Otherwise, guide manual bisect steps.
   - **Always run `git bisect reset` when finished — and before any fallback or early exit — to restore the working tree.**

4. **Consult investigation patterns:**
   - Read common patterns from `${CODEX_HOME:-$HOME/.codex}/plugins/cache/kramme-cc-workflow/kramme-cc-workflow/0.90.0/shared/debug/references/investigation-patterns.md`.
   - Match symptoms to known patterns.
   - Apply recommended checks for the matching pattern.

5. **Trace data flow** from origin to error point. Track variable values through assignments and transformations.

6. Log: `[ROOT CAUSE] {description} at {file}:{line}`

## 4. Document Findings

Read the log template from `${CODEX_HOME:-$HOME/.codex}/plugins/cache/kramme-cc-workflow/kramme-cc-workflow/0.90.0/shared/debug/assets/investigation-log.md` and fill it in from the timeline logs (`[REPRODUCE]`, `[ISOLATE]`, `[ROOT CAUSE]`) and findings gathered so far. Capture evidence — code snippets, test output, bisect results — under the relevant sections.

Store the completed log for inclusion in the final summary.

A report-only caller records `Applied: no` under Fix and `not run` under Verification.

## 5. Assess Confidence

- **High** — root cause is clear, fix is straightforward, side effects are minimal
- **Medium** — root cause is likely correct, fix may have side effects
- **Low** — root cause is uncertain, multiple possible explanations

## Hand Back to the Caller

Return:

- The timeline markers.
- The completed log, including its Root Cause Analysis block and evidence.
- The High / Medium / Low confidence rating.
- Whether reproduction was confirmed.
- Out-of-scope observations recorded as `NOTICED BUT NOT TOUCHING`.

Stop here. This procedure never proposes, applies, or verifies a fix.
