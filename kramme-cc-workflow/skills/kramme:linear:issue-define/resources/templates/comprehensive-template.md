# Comprehensive Issue Template

For features, improvements, and complex bugs. Used when `is_simple_bug = false`.

## Mode-Specific Behavior

**IMPROVE MODE:**
- Merge interview findings with existing issue content
- For unchanged sections, preserve the original text
- For modified sections, use the new content from the interview
- When presenting the draft, indicate what changed vs. original:
  - `[UNCHANGED]` for preserved sections
  - `[MODIFIED]` for updated sections
  - `[ADDED]` for new sections

**CREATE MODE:**
- Compose the issue from scratch using interview findings

Draft the issue following this template:

## Title Format

`[Action verb] [what] [where/context]`

**Examples:**
- "Add dark mode toggle to settings page"
- "Fix pagination in user list API"
- "Refactor authentication flow to use OAuth2"

## Description Template

**Note:** The template is ordered by importance for a Product Team audience. Problem and Value come first.

```markdown
## Problem
[What pain point or issue exists today]
[Who is affected and how often]
[What is the cost/impact of this problem]

## Value Proposition
[Why solving this matters]
[What benefit users/business will gain]
[How this aligns with product goals]

## Goal
[What success looks like - the desired outcome]
[Clear statement of the end state]

## Scope

### In Scope
- [Specific item 1]
- [Specific item 2]
- [Specific item 3]

### Out of Scope
- [Explicitly excluded item 1]
- [Explicitly excluded item 2]

## Acceptance Criteria
- [ ] [Testable criterion 1 - user-facing behavior]
- [ ] [Testable criterion 2 - user-facing behavior]
- [ ] [Testable criterion 3 - user-facing behavior]

## Edge Cases
- [Edge case 1]: [Expected behavior]
- [Edge case 2]: [Expected behavior]

---

## Technical Notes (For Engineering)

### Implementation Proposal
[High-level approach - what components/areas need changes]
[Architectural considerations if relevant]
[Keep this strategic, not detailed implementation steps]

### Affected Areas
- [Component/module 1]
- [Component/module 2]

### Patterns to Follow
[Reference existing patterns in the codebase]
[Only include code examples for specific bugs or concrete fixes]

### References
- [Related files: `path/to/file.ts`]

## Dependencies
- [Blocking issue or prerequisite, if any]
- [Related issues for context]

<!-- Only include this section if the issue has the "Dev Ask" label -->
## Original Dev Ask

> [Preserve the complete original issue description here exactly as it was submitted]
> [This section is automatically included for issues created via Linear Asks]
```

## Dev Ask Handling

- If `is_dev_ask` flag is true, always include the "Original Dev Ask" section at the bottom
- Quote the entire original description using markdown blockquote (`>`)
- Do not modify the original text - preserve it exactly
- This section comes after all other sections, including Dependencies

## Technical Notes Guidelines

- Keep implementation proposals **high-level** (what, not how)
- Only include code examples when:
  - Fixing a specific bug (show the problematic code)
  - Making a very concrete, well-defined fix
  - The code example clarifies something that words cannot
- For new features, describe the approach architecturally, not the implementation details
- Engineers will determine the detailed implementation
