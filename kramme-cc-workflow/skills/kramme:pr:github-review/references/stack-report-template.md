# Output template: GITHUB_STACK_REVIEW_OVERVIEW.md

Use this structure when writing `GITHUB_STACK_REVIEW_OVERVIEW.md` (or the inline reply with `--inline`). Include every section; write `None.` when one is empty. Findings are framed for the stack's author, in reviewer voice, and each names the layer whose own review should raise it.

```markdown
# GitHub Stack Review — <size> layers on `<trunk>` (from #<number>)

- Stack: <stack context summary>
- Trunk: `<trunk>` at <trunk_tip (short)>; the stack branched at <stack_base (short)>
- Reviewed heads, bottom to top: #<number> <head (short)>, …
- Lines added: <production> production, <tests> tests, <database> database, <generated> generated, <other> other
- GitHub writes: none

## Stack Map

| # | PR | Title | Production | Tests | Database | Generated + other | Review | Checks | Restack |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | #<number> | <title> | +<added> / -<deleted> | +<added> | +<added> | +<added> | <review decision or none> | <checks> | <yes \| no> |

## Review Plan

1. **Foundations first:** <layers extended by later layers, with what they set up>
2. **Where the production code is:** <the largest production and database layers>
3. **Ready to merge:** <the bottom layers that are approved, not drafts, passing, and need no restack | none yet>
4. **Per-layer reviews, bottom-up:** `/kramme:pr:github-review <number>` for each layer; a rerun after a restack covers only what changed

## Stack Findings

### Blocking (<n>)

- **<one-line finding>** — owner: #<number> (layer <position>) | stack-wide
  - Evidence: <paths, positions, line counts, what the code at the top of the stack does>
  - Raise it in: the review of #<number>

### Important (<n>)

### Suggestions (<n>)

## Shared Files

| File | Layers | Lines at the top | Created in the stack | Lines rewritten later |
| --- | --- | --- | --- | --- |
| `<path>` | <positions> | <end_lines or deleted> | <yes \| no> | <churn or —> |

## Database Changes

- By layer: <position: files, in order | none>
- Trunk drift: <database files the trunk gained since the stack branched | none>
- Numbering: <collisions and out-of-order files | none>
- Safe to stop at each layer: <yes, or each layer whose change is unsafe alone and why>

## Coverage

- Read at the top of the stack: <shared files read in full>
- Database files read: <files | none>
- Orientation: <descriptions read; parent or product requirements issue read | not linked | Linear MCP unavailable>
- Not read: <generated and other files; shared files beyond the ones read>
```
