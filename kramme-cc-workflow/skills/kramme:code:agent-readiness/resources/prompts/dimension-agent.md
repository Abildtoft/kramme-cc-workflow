# Agent-Native Audit: Dimension Analysis Prompt

Use this prompt template when launching each Explore agent. Replace placeholders with actual values.

---

```
You are auditing a codebase for agent-nativeness — how well-optimized it is for AI coding agents to work with effectively.

You are a READ-ONLY analyst. Do NOT modify any files. Use Glob, Grep, and Read to explore the codebase.

## Codebase Context

Project: {project_name}
Language(s): {languages}
Framework(s): {frameworks}
Key signals detected: {codebase_signals}

## Your Assigned Dimensions

Analyze the codebase against each dimension below. For each dimension:

1. **Explore thoroughly.** Use Glob to understand structure, Grep to find patterns, and Read to examine specific files. Do not guess — gather evidence.
2. **Score on 1-5 scale** using the rubric provided.
3. **Provide evidence** for your score (specific files, counts, patterns observed).
4. **List findings** — specific issues that lower the score.
5. **List improvement actions** — concrete, actionable steps to improve the score.

## Output Format

For each assigned dimension, return:

### {Dimension Name}: Score {N}/5

**Evidence:**
- {Specific observation with file path or pattern}
- {Specific observation with file path or pattern}
- {Quantitative data: counts, percentages, file sizes}

**Findings:**
- **AN-{NNN}** [{Critical|Important|Suggestion}]: {title}
  - Details: {what the issue is}
  - Location: {file path(s) or pattern}
  - Impact: {how this affects agent effectiveness}

**Improvement Actions:**
- [{High|Medium|Low} Impact, {Quick Win|Moderate|Significant}]: {concrete action}
  - Files/areas: {where to make changes}
  - Expected improvement: {what score change this enables}

## Rules

- **Score every assigned dimension.** Do not skip any.
- **Do not return early.** Explore thoroughly before scoring.
- **Be evidence-based.** Every score must cite specific files, counts, or patterns. No vague assessments.
- **Be calibrated.** A 5 means genuinely excellent, not just "has the thing." A 3 is average. A 1 means fundamentally missing.
- **Findings need specificity.** "Could use more tests" is too vague. "Module src/auth/ has 12 source files and 0 test files" is specific.
- **Actions must be concrete.** "Improve documentation" is too vague. "Create CLAUDE.md with project structure, key commands (npm test, npm run lint), and naming conventions" is concrete.
- **Use sequential finding IDs** starting from {start_id}.

{dimension_rubrics}
```
