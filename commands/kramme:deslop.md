---
name: kramme:deslop
description: Remove AI-generated code slop from a branch. Use when cleaning up AI-generated code, removing unnecessary comments, defensive checks, or type casts. Checks diff against main and fixes style inconsistencies.
---

# Remove AI Code Slop

This command uses the `kramme:deslop-reviewer` agent to identify AI slop, then fixes the identified issues.

## Process

1. **Scan for slop**
   - Launch `kramme:deslop-reviewer` in code review mode
   - Get the diff against main: `git diff main...HEAD`
   - Agent identifies slop patterns in changed files

2. **Review findings**
   - Present the slop findings to understand what will be changed
   - Findings include file:line references and explanations

3. **Fix identified slop**
   - For each slop finding, edit the file to remove the pattern:
     - Remove unnecessary comments
     - Remove excessive defensive checks/try-catch blocks
     - Replace `any` casts with proper types where possible
     - Align style with the rest of the file

4. **Report summary**
   - Provide a 1-3 sentence summary of what was changed
   - List files that were modified

## Slop Patterns (Quick Reference)

- **Unnecessary comments**: Comments describing obvious code or over-documenting
- **Defensive overkill**: Try-catch/null checks where not needed
- **Type workarounds**: `any` casts, `@ts-ignore` without justification
- **Style inconsistencies**: Different patterns than the rest of the file
- **Over-engineering**: Unnecessary abstractions for simple operations
