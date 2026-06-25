# Execution Plan Prompts

Use this during Step 4 after scope and UI relevance have been computed.

## Display Plan

```text
PR Finalize Plan

Branch: {CURRENT_BRANCH} -> {BASE_BRANCH}
Changed files: {FILE_COUNT}
UI changes detected: {yes/no}

Steps to run:
  1. verify:run              [always]
  2. pr:code-review          [always]
  3. pr:product-review       [always]
  4. pr:ux-review            [if UI changes detected]
  5. qa                      [if UI changes + app URL provided]
  6. pr:resolve-review       [if --fix and critical/important findings]
  7. re-verify               [if --fix applied fixes]
  8. pr:generate-description [if no blockers]

Auto-fix: {yes/no}
Skipped: {any --skip items, or "none"}
```

## Confirm Plan

If `AUTO_MODE=true`, skip this prompt and execute the plan as displayed.

Otherwise use AskUserQuestion:

```yaml
header: "PR Finalize Plan"
question: "Proceed with this plan?"
options:
  - label: "Run all"
    description: "Execute all applicable steps as shown"
  - label: "Skip QA"
    description: "Run everything except QA testing"
  - label: "Customize"
    description: "Let me choose which steps to run"
  - label: "Abort"
    description: "Cancel without running anything"
multiSelect: false
```

- If "Abort": stop immediately.
- If "Skip QA": add `qa` to `SKIP_LIST`.
- If "Customize": use AskUserQuestion with multiSelect to let the user pick steps:

```yaml
header: "Select steps"
question: "Which steps should run?"
options:
  - label: "verify:run"
  - label: "pr:code-review"
  - label: "pr:product-review"
  - label: "pr:ux-review"
  - label: "qa"
  - label: "pr:generate-description"
multiSelect: true
```
