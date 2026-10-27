# Agent-Native Audit Report Template

Use this template when writing the AGENT_NATIVE_AUDIT.md output file. Replace all `{placeholders}`.

In Compare mode, insert the **Score Changes** block (shown after the main template) immediately after the Scorecard section. Skip it in Replace mode.

---

```markdown
# Agent-Native Audit Report

**Date:** {date} **Project:** {project_name} **Language(s):** {languages} **Framework(s):** {frameworks}

## Report Provenance

- **Producer:** kramme:code:agent-readiness
- **Scope:** full repository
- **Scanned commit:** {full git rev-parse HEAD at scan start, or none (not a git repository)}
- **Working tree:** {clean / dirty (N paths) / none (not a git repository)}
- **Base branch:** none
- **Generated:** {YYYY-MM-DD}
- **Schema:** breakdown-ready-findings v1

## Scorecard

| Dimension        | Score       | Key Evidence     |
| ---------------- | ----------- | ---------------- |
| Fully Typed      | {N}/5       | {1-line summary} |
| Traversable      | {N}/5       | {1-line summary} |
| Test Coverage    | {N}/5       | {1-line summary} |
| Feedback Loops   | {N}/5       | {1-line summary} |
| Self-Documenting | {N}/5       | {1-line summary} |
| **Overall**      | **{N.N}/5** | **{assessment}** |

## Dimension Details

### Fully Typed: {N}/5

{2-3 sentence assessment}

**Evidence:**

- {bullet points}

**Findings:** (full detail in Breakdown-Ready Finding Data)

- AN-{NNN} ({severity}): {title}

{Repeat for each finding in this dimension, or "None."}

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

| ID     | Dimension   | Severity   | Title   |
| ------ | ----------- | ---------- | ------- |
| AN-001 | {dimension} | {severity} | {title} |

| Severity   | Count   |
| ---------- | ------- |
| Critical   | {N}     |
| Important  | {N}     |
| Suggestion | {N}     |
| **Total**  | **{N}** |

## Breakdown-Ready Finding Data

{One block per AN-NNN finding in ID order, or "None."}

### AN-001: {title}

- **Severity:** {critical / high / suggestion} (native: {Critical / Important / Suggestion})
- **Confidence:** {HIGH / MED / LOW}
- **Locations:** {path:line or path:start-end; …, or none — holistic}
- **Evidence:** {details: what the issue is, with concrete evidence}
- **Suggested fix:** {smallest concrete change}
- **Effort:** {S / M / L}
- **Category:** {dimension}
- **Impact:** {how this affects agent effectiveness}

## Refactoring Plan

### Phase 1: Quick Wins

High-impact improvements that can be done quickly.

| #   | Action   | Dimension   | Impact | Effort    | Files/Areas |
| --- | -------- | ----------- | ------ | --------- | ----------- |
| 1   | {action} | {dimension} | High   | Quick Win | {files}     |

### Phase 2: Foundation

Core improvements that require moderate effort.

| #   | Action   | Dimension   | Impact | Effort   | Files/Areas |
| --- | -------- | ----------- | ------ | -------- | ----------- |
| 1   | {action} | {dimension} | High   | Moderate | {files}     |

### Phase 3: Structural

Module-boundary and depth changes. Scope each one with `/kramme:code:refactor-opportunities` before starting.

| #   | Action   | Dimension   | Impact | Effort      | Files/Areas |
| --- | -------- | ----------- | ------ | ----------- | ----------- |
| 1   | {action} | {dimension} | High   | Significant | {files}     |

### Phase 4: Polish

Refinements for maximum agent-nativeness.

| #   | Action   | Dimension   | Impact | Effort   | Files/Areas |
| --- | -------- | ----------- | ------ | -------- | ----------- |
| 1   | {action} | {dimension} | Low    | Moderate | {files}     |
```

---

## Score Changes block (Compare mode only)

Insert this block immediately after the Scorecard section when comparing against a prior audit.

```markdown
## Score Changes

| Dimension        | Previous    | Current     | Delta        |
| ---------------- | ----------- | ----------- | ------------ |
| Fully Typed      | {N}/5       | {N}/5       | {+/-N}       |
| Traversable      | {N}/5       | {N}/5       | {+/-N}       |
| Test Coverage    | {N}/5       | {N}/5       | {+/-N}       |
| Feedback Loops   | {N}/5       | {N}/5       | {+/-N}       |
| Self-Documenting | {N}/5       | {N}/5       | {+/-N}       |
| **Overall**      | **{N.N}/5** | **{N.N}/5** | **{+/-N.N}** |
```
