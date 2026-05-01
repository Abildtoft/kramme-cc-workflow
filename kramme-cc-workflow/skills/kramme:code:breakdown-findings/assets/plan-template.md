# PR Plan {{execution-label}}: {{theme-name}} ({{parallel in W## / blocked by W##L / blocks W##L}})

**File:** `PR_PLAN_{{EXECUTION_LABEL}}_{{SLUG}}.md`
**Execution label:** `{{W##L}}`
**Parallel group:** {{Wave W##; name sibling labels that can run in parallel, or "None - only plan in wave."}}
**Blocked by:** {{Execution labels and content of prerequisite plans, or "None."}}
**Blocks:** {{Execution labels and content of dependent plans, or "None."}}
**Date:** {{date}}
**Source findings:** {{count}} findings clustered into this theme
**Estimated scope:** {{small / medium / large}} PR

---

## Problem Statement

{{Restate the full problem. Do not reference any earlier report, summary, or finding number. An engineer reading only this document must understand the issue completely.}}

## Why These Belong Together

{{Explain the shared root cause, affected area, or implementation dependency that groups these findings into one PR.}}

## Goals

{{Bulleted list of specific, measurable outcomes this PR achieves.}}

## Non-Goals

{{Bulleted list of things this PR explicitly does NOT do. Prevents scope creep and clarifies boundaries.}}

## Affected Files and Systems

| File / Module | Role | Change Type |
|---------------|------|-------------|
| {{path}} | {{what it does}} | {{modify / create / delete}} |

## Current Behavior

{{Describe what happens today. Include concrete examples, code paths, or error messages. Be specific enough that someone can reproduce or observe the behavior.}}

## Intended End State

{{Describe the target behavior after this PR lands. Contrast with current behavior where helpful.}}

## Dependencies and Sequencing

### Prerequisites (must land before this PR)

{{List exact blocker execution labels plus the work that must be completed before this PR can start — e.g., "`W01A` must define and export shared error types." State "None." if independent.}}

### Dependents (blocked until this PR lands)

{{List exact dependent execution labels plus the work this PR unblocks — e.g., "`W02A` cannot adopt typed errors until the shared error types exist." State "None." if nothing depends on this.}}

### Parallel Work

{{List same-wave execution labels that can run in parallel and why they do not depend on this plan. State "None." if there are no same-wave peers.}}

### External Dependencies

{{Library upgrades, API changes, infrastructure changes, or state "None."}}

## Risks

{{Bulleted list of what could go wrong: migration risks, backwards compatibility, performance, data integrity. For each risk, note the mitigation strategy.}}

## Open Questions

{{Numbered list of questions that must be answered before implementation begins. For each question, note who should answer it and what the default assumption is if no answer is available.}}

## Implementation Plan

{{Numbered step-by-step instructions. Each step should be:
- Small enough to verify independently
- Specific about which files to change and how
- Ordered by dependency (do A before B if B depends on A)}}

## Test and Verification Plan

{{How to verify the PR works:
- Automated tests to add or modify when code or executable behavior changes
- Manual verification steps for user-visible or workflow changes
- Re-run the relevant audit/review/QA flow when this plan comes from a generated report
- Docs/build validation, screenshots, or artifact checks when the work is non-code
- Performance benchmarks or edge cases to test, if applicable}}

## Completion Criteria

- [ ] {{Specific condition that must be true for the PR to be mergeable}}
- [ ] {{Additional criteria specific to this theme, including any verification checks appropriate for the type of change}}
