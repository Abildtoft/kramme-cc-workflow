# Classification and Prefix Guidance

Read this file from Phase 1 Step 3 and Step 4 in `SKILL.md`.

## Issue Type Classification

Auto-detect from context and suggest to the user. The user can override.

### Issue Types

- **Bug (Simple)**: Root cause is known or easily identified, fix is localized, no architectural decisions needed
- **Bug (Complex)**: Unknown root cause, affects multiple components, requires investigation
- **Feature**: New functionality
- **Improvement**: Enhance existing functionality

### Detection Heuristics

- Keywords like "bug", "fix", "broken", "doesn't work", "error" -> suggest Bug
- If user provides root cause and specific file(s) -> suggest Bug (Simple)
- If scope is unclear or multiple components are mentioned -> suggest Bug (Complex)
- Keywords like "add", "new", "implement", "create" -> suggest Feature
- Keywords like "improve", "refactor", "enhance", "optimize" -> suggest Improvement

### Classification Prompt

Present classification to user via `AskUserQuestion`:

- Show detected type with reasoning
- Allow override to any type
- Store `issue_type` for conditional behavior

For Bug (Simple), store `is_simple_bug = true`; this enables streamlined interview and the simple template.

## Phase Prefix Recommendation

Only run in CREATE MODE. Skip in IMPROVE MODE.

Goal: recommend a phase prefix (`P1-`, `P2-`, etc.) when the issue clearly fits an active, not completed, phase. If the issue does not suit a phase well, or the relevant phase is completed, recommend `G` (General).

### Inputs to Check

1. `siw/` spec file created by `/kramme:siw:init` for phase breakdown and tasks.
2. `siw/LOG.md` for phase completion notes such as "Phase 1 complete" or "Status: DONE".
3. `siw/OPEN_ISSUES_OVERVIEW.md` for existing phase sections and active work.

If multiple candidate spec files exist under `siw/`, ask the user which one is the main spec. Synced SIW spec-exclusion contract (keep aligned across SIW spec detectors): `LOG.md`, `OPEN_ISSUES_OVERVIEW.md`, `DISCOVERY_BRIEF.md`, `SPEC_STRENGTHENING_PLAN.md`, `AUDIT_*.md`, `PRODUCT_AUDIT.md`, `SIW_*.md`.

### Prefix Heuristics

- Map the issue description and any referenced tasks to the most relevant phase in the spec.
- If the phase is explicitly marked complete in the spec or log, do not recommend that phase.
- If the phase section header in `siw/OPEN_ISSUES_OVERVIEW.md` is marked with ` (DONE)`, treat the phase as completed.
- If `siw/OPEN_ISSUES_OVERVIEW.md` has a Phase N section and all issues in that phase are `DONE`, treat the phase as completed.
- If no phase info exists, mapping is unclear, or the issue does not suit a phase well, default to `G`.
- If the user explicitly supplied a prefix (`requested_prefix`), treat it as preferred, but warn if the phase appears completed and offer alternatives.

### Prefix Prompt

Use `AskUserQuestion`:

```yaml
header: "Choose Issue Prefix"
question: "Which prefix should we use? Recommendation: {recommended_prefix}- ({reason})."
options:
  - label: "Use {recommended_prefix}- (recommended)"
    description: "Matches the spec/tasks and the phase isn't completed"
  - label: "Use a different phase prefix"
    description: "Pick P1-, P2-, P3-, etc."
  - label: "Use G- (General)"
    description: "Standalone or doesn't fit a phase well"
```

If `{recommended_prefix}` is `G`, omit the separate "Use G-" option to avoid duplicates.

Store `issue_prefix` based on the selection without the trailing dash, for example `P1`, `P2`, or `G`.
