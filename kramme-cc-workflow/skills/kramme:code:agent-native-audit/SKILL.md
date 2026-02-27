---
name: kramme:code:agent-native-audit
description: "Audit a codebase for agent-nativeness — score how well-optimized it is for AI coding agents across 5 dimensions and generate a prioritized refactoring plan."
disable-model-invocation: true
user-invocable: true
---

# Agent-Native Audit

Audit a codebase for agent-nativeness — how well-optimized it is for AI coding agents (Claude Code, Codex, etc.) to work with effectively. Scores 5 dimensions and generates a prioritized refactoring plan.

**IMPORTANT:** This is a thorough codebase audit. Do not return early. Do not guess scores without evidence. Explore the codebase systematically and score based on what you find.

## Process Overview

```
/kramme:code:agent-native-audit
    |
    v
[Step 1: Detect Codebase Context] -> Language, framework, key signals
    |
    v
[Step 2: Launch Parallel Analysis] -> 3 Explore agents across 5 dimensions
    |
    v
[Step 3: Collect and Score Results] -> Per-dimension scores 1-5
    |
    v
[Step 4: Compute Overall Score] -> Weighted composite + assessment
    |
    v
[Step 5: Generate Refactoring Plan] -> Prioritized by impact and effort
    |
    v
[Step 6: Write Report] -> AGENT_NATIVE_AUDIT.md
    |
    v
[Step 7: Report Summary] -> Terminal output with scorecard
```

---

## Step 1: Detect Codebase Context

Gather codebase metadata before launching agents.

### 1.1 Detect Language and Framework

Run quick checks:

```bash
ls package.json tsconfig.json pyproject.toml Cargo.toml go.mod pom.xml build.gradle *.csproj 2>/dev/null
```

Identify primary language(s) by checking for config files:
- `tsconfig.json` / `package.json` with TypeScript deps → TypeScript
- `package.json` without TypeScript → JavaScript
- `pyproject.toml` / `setup.py` / `requirements.txt` → Python
- `go.mod` → Go
- `Cargo.toml` → Rust
- `pom.xml` / `build.gradle` → Java
- `*.csproj` / `*.sln` → C#/.NET

### 1.2 Detect Key Signals

Quick checks for files that inform the analysis:

```bash
# Agent instructions
ls CLAUDE.md .claude/ AGENTS.md 2>/dev/null

# Documentation
ls README.md docs/ 2>/dev/null

# CI/CD
ls .github/workflows/*.yml .gitlab-ci.yml Jenkinsfile .circleci/config.yml 2>/dev/null

# Linting and formatting
ls .eslintrc* eslint.config* .prettierrc* prettier.config* ruff.toml .editorconfig 2>/dev/null

# Testing
ls jest.config* vitest.config* pytest.ini pyproject.toml karma.conf* cypress.config* playwright.config* 2>/dev/null

# Hooks
ls .husky/ .pre-commit-config.yaml lefthook.yml 2>/dev/null

# Type checking strictness (TypeScript)
# If tsconfig.json exists, check for "strict": true
```

Store all detected signals as `codebase_signals`.

### 1.3 Present Context Summary

```
Agent-Native Audit Starting

Project: {directory name}
Language(s): {detected}
Framework(s): {detected}
Key signals: {list of detected files/configs}

Launching 3 dimension analysis agents...
```

---

## Step 2: Launch Parallel Dimension Analysis

Launch 3 Explore agents in parallel (single message, 3 Task tool calls).

### Agent Grouping

| Agent | Dimensions | Finding IDs |
|-------|-----------|-------------|
| **A: Type & Structure** | Fully Typed, Traversable | AN-001 through AN-099 |
| **B: Test & Feedback** | Test Coverage, Feedback Loops | AN-100 through AN-199 |
| **C: Documentation** | Self-Documenting | AN-200 through AN-299 |

### Agent Prompt Construction

For each agent:

1. Read the prompt template from `resources/prompts/dimension-agent.md`.
2. Read the dimension rubrics from `resources/references/dimension-rubrics.md`.
3. Populate the prompt template:
   - `{project_name}`: current directory name
   - `{languages}`: detected languages from Step 1
   - `{frameworks}`: detected frameworks from Step 1
   - `{codebase_signals}`: signals from Step 1.3
   - `{start_id}`: the start of the finding ID range for this agent (1, 100, or 200)
   - `{dimension_rubrics}`: the relevant dimension sections from the rubrics file

### Launch

Launch all 3 agents simultaneously using the Task tool with `subagent_type: Explore`.

Each agent prompt must include:
- The populated prompt template
- Only the rubric sections for its assigned dimensions
- The codebase signals for context

---

## Step 3: Collect and Score Results

After all 3 agents return:

### 3.1 Gather Results

From each agent, extract:
- Per-dimension scores (1-5)
- Evidence bullet points
- Findings (with IDs, severity, details)
- Improvement actions (with impact and effort)

### 3.2 Validate Completeness

For each of the 5 dimensions:
- Verify a score was returned (1-5 range)
- Verify evidence was provided
- If an agent returned incomplete results for a dimension, note it as "Incomplete — re-run recommended"

### 3.3 Renumber Findings

Renumber all findings sequentially (AN-001, AN-002, ...) sorted by:
1. Severity: Critical first, then Important, then Suggestion
2. Within same severity: by dimension order (Typed → Traversable → Tests → Feedback → Docs)

---

## Step 4: Compute Overall Score

### 4.1 Calculate Composite

Equal-weight average of all 5 dimension scores:

```
overall = (typed + traversable + test_coverage + feedback_loops + self_documenting) / 5
```

Round to 1 decimal place.

### 4.2 Determine Assessment

| Overall Score | Assessment |
|--------------|------------|
| 4.5 – 5.0 | **Agent-Native** — Optimized for AI coding agents |
| 3.5 – 4.4 | **Agent-Ready** — Solid foundation, minor improvements possible |
| 2.5 – 3.4 | **Agent-Compatible** — Works but agents hit friction regularly |
| 1.5 – 2.4 | **Agent-Resistant** — Significant barriers to effective agent use |
| 1.0 – 1.4 | **Agent-Hostile** — Fundamental changes needed |

---

## Step 5: Generate Refactoring Plan

### 5.1 Prioritize Actions

Collect all improvement actions from all agents. Sort by:
1. **Impact** (descending): High → Medium → Low
2. **Effort** (ascending): Quick Win → Moderate → Significant

### 5.2 Assign to Phases

| Phase | Criteria | Description |
|-------|----------|-------------|
| **Phase 1: Quick Wins** | High impact + Quick Win effort, OR Medium impact + Quick Win effort | Do these first — fast improvements with immediate value |
| **Phase 2: Foundation** | High impact + Moderate effort, OR Medium impact + Moderate effort | Core improvements requiring real work |
| **Phase 3: Polish** | Everything else (Significant effort, Low impact items) | Refinements for maximum agent-nativeness |

### 5.3 Deduplicate

If multiple agents suggest similar actions (e.g., both Agent A and Agent B mention adding `.editorconfig`), merge into a single action.

---

## Step 6: Write Report

### 6.1 Check for Existing Report

Check if `AGENT_NATIVE_AUDIT.md` exists in the project root.

If it exists, ask the user:

```
A previous Agent-Native Audit report exists.

How should I proceed?
1. Replace — overwrite with new results
2. Compare — write new report and show score changes vs previous
3. Abort — keep existing report
```

If **Compare**: parse the previous report's scorecard table to extract dimension scores. Include a "Score Changes" section in the new report showing deltas.

If **Abort**: stop and inform the user.

### 6.2 Write Report File

Read the report template from `resources/templates/audit-report.md`.

Populate and write `AGENT_NATIVE_AUDIT.md` in the project root with:
- Scorecard summary table
- Score changes (if compare mode)
- Dimension details with evidence, findings, and improvement actions
- All findings summary table with severity counts
- Refactoring plan with 3 phases

```
Report written to: AGENT_NATIVE_AUDIT.md
```

---

## Step 7: Report Summary

Display a terminal summary:

```
Agent-Native Audit Complete
============================

Project: {project_name}
Language(s): {languages}

Scores:
  Fully Typed:      {N}/5 {bar}
  Traversable:      {N}/5 {bar}
  Test Coverage:    {N}/5 {bar}
  Feedback Loops:   {N}/5 {bar}
  Self-Documenting: {N}/5 {bar}
  ─────────────────────────
  Overall:          {N.N}/5 — {assessment}

Findings:
  Critical:   {N}
  Important:  {N}
  Suggestion: {N}
  Total:      {N}

Refactoring Plan:
  Phase 1 (Quick Wins):  {N} actions
  Phase 2 (Foundation):  {N} actions
  Phase 3 (Polish):      {N} actions

Report: AGENT_NATIVE_AUDIT.md

Next Steps:
  - Start with Phase 1 quick wins for immediate improvement
  - Address critical findings first
  - Re-run after improvements to track progress
```

Where `{bar}` is a simple visual indicator using the score:
- 5/5: `[==========]`
- 4/5: `[========--]`
- 3/5: `[======----]`
- 2/5: `[====------]`
- 1/5: `[==--------]`

**STOP.** Do not proceed beyond the summary. Wait for the user's next instruction.

---

## Error Handling

- **No source files found:** If the project root has no recognizable source code, abort with a message suggesting the user run from a project directory.
- **Agent returns incomplete results:** Note affected dimensions as "Incomplete — re-run recommended" in the report, score based on available evidence.
- **Monorepo detection:** If the project has multiple packages (nx, lerna, turborepo), note that the audit covers root-level configuration and suggest per-package audits for deeper analysis.
