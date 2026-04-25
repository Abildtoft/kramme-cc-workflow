# Simple Bug Template

For simple bugs (`is_simple_bug = true`), use this concise format.

## Title Format

`Fix [what's broken] when [trigger condition]`

**Examples:**
- "Fix dialog reopening after cancel when navigating between roles"
- "Fix null pointer in user search when query is empty"

## Description Template

```markdown
## Problem

[1-2 sentence description of the bug]

**Steps to reproduce:**
1. [Step 1]
2. [Step 2]
3. **Bug:** [What happens]

## Root Cause

[1-2 sentences explaining what's causing the bug]

## Fix

[1-2 sentences describing what needs to change]

**Affected area:** [module / behavior / contract — not file paths or line numbers]
```

## Notes

- If multiple areas are affected, list each on its own line with `**Affected area:**` prefix
- If root cause is unknown, reclassify to Bug (Complex), set `is_simple_bug = false`, and switch to the comprehensive interview/template
- Keep each section brief - this template is intentionally minimal
