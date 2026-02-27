# Agent-Native Audit Report Template

Use this template when writing the AGENT_NATIVE_AUDIT.md output file. Replace all `{placeholders}`.

---

```markdown
# Agent-Native Audit Report

**Date:** {date}
**Project:** {project_name}
**Language(s):** {languages}
**Framework(s):** {frameworks}

## Scorecard

| Dimension | Score | Key Evidence |
|-----------|-------|-------------|
| Fully Typed | {N}/5 | {1-line summary} |
| Traversable | {N}/5 | {1-line summary} |
| Test Coverage | {N}/5 | {1-line summary} |
| Feedback Loops | {N}/5 | {1-line summary} |
| Self-Documenting | {N}/5 | {1-line summary} |
| **Overall** | **{N.N}/5** | **{assessment}** |

{If comparing with previous audit, include:}

## Score Changes

| Dimension | Previous | Current | Delta |
|-----------|----------|---------|-------|
| Fully Typed | {N}/5 | {N}/5 | {+/-N} |
| Traversable | {N}/5 | {N}/5 | {+/-N} |
| Test Coverage | {N}/5 | {N}/5 | {+/-N} |
| Feedback Loops | {N}/5 | {N}/5 | {+/-N} |
| Self-Documenting | {N}/5 | {N}/5 | {+/-N} |
| **Overall** | **{N.N}/5** | **{N.N}/5** | **{+/-N.N}** |

## Dimension Details

### Fully Typed: {N}/5

{2-3 sentence assessment}

**Evidence:**
- {bullet points}

**Findings:**

#### AN-{NNN}: {title}
- **Severity:** {Critical / Important / Suggestion}
- **Location:** {file path(s)}
- **Details:** {explanation}
- **Impact:** {how this affects agent effectiveness}

{Repeat for each finding}

---

### Traversable: {N}/5

{Same structure as above}

---

### Test Coverage: {N}/5

{Same structure as above}

---

### Feedback Loops: {N}/5

{Same structure as above}

---

### Self-Documenting: {N}/5

{Same structure as above}

---

## All Findings

| ID | Dimension | Severity | Title |
|----|-----------|----------|-------|
| AN-001 | {dimension} | {severity} | {title} |

| Severity | Count |
|----------|-------|
| Critical | {N} |
| Important | {N} |
| Suggestion | {N} |
| **Total** | **{N}** |

## Refactoring Plan

### Phase 1: Quick Wins

High-impact improvements that can be done quickly.

| # | Action | Dimension | Impact | Effort | Files/Areas |
|---|--------|-----------|--------|--------|-------------|
| 1 | {action} | {dimension} | High | Quick Win | {files} |

### Phase 2: Foundation

Core improvements that require moderate effort.

| # | Action | Dimension | Impact | Effort | Files/Areas |
|---|--------|-----------|--------|--------|-------------|
| 1 | {action} | {dimension} | High | Moderate | {files} |

### Phase 3: Polish

Refinements for maximum agent-nativeness.

| # | Action | Dimension | Impact | Effort | Files/Areas |
|---|--------|-----------|--------|--------|-------------|
| 1 | {action} | {dimension} | Medium | Significant | {files} |
```
