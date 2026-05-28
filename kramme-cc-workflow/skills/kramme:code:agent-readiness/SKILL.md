---
name: kramme:code:agent-readiness
description: "Audit a codebase for agent-nativeness — score how well-optimized it is for AI coding agents across 5 dimensions and generate a prioritized refactoring plan."
argument-hint: "[--auto]"
disable-model-invocation: true
user-invocable: true
kramme-platforms: [claude-code]
---

# Agent-Native Audit

Audit a codebase for agent-nativeness — how well-optimized it is for AI coding agents (Claude Code, Codex, etc.) to work with effectively. Scores 5 dimensions and generates a prioritized refactoring plan.

**Not for:**

- Per-feature or per-PR audits — use `kramme:pr:code-review` or `kramme:code:refactor-opportunities` instead.
- Replacing a refactor-opportunity scan — this scores agent-nativeness, not general code quality.
- Per-package audits inside a monorepo — this skill audits root-level configuration. Run per-package separately if needed.

**What it touches:** writes one report file (`AGENT_NATIVE_AUDIT.md`) at the project root. Read-only otherwise.

Parse `$ARGUMENTS` for `--auto` before Step 1.

- If present, set `AUTO_MODE=true` and remove the flag from the remaining input.
- `--auto` means: if a previous report exists, write a fresh report and include a score comparison instead of prompting the user.

**IMPORTANT:** This is a thorough codebase audit. Do not return early. Do not guess scores without evidence. Explore the codebase systematically and score based on what you find.

## Context Pointer Signals

Treat Context Pointers as first-class agent-readiness evidence. A Context Pointer is an intentional link or code affordance that lets an agent move from a compact surface to the relevant deeper context without loading everything.

Examples:

- Agent instructions that point to focused docs, scripts, workflows, or source entry points with a clear "when to read/use this" cue
- README/docs navigation that routes setup, architecture, testing, and deployment questions to specific files
- Module-level `README.md`, `index.*`, route maps, registries, public exports, schemas, or shared helpers that act as reliable entry points
- Code comments that link unusual decisions to ADRs, issue specs, or design docs

Good pointers are scoped, accurate, and explain why the target matters. Link dumps, stale references, and giant catch-all docs are weak or negative evidence.

## Process Overview

```text
/kramme:code:agent-readiness [--auto]
    |
    v
[Step 1: Detect Codebase Context] -> Language, framework, key signals
    |
    v
[Step 2: Launch Parallel Analysis] -> 3 agents covering 5 dimensions
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

This step assumes `ripgrep` (`rg`) is available. If `rg` is missing, substitute `grep -rEn` in the search command below.

### 1.1 Detect Language and Framework

Run quick checks:

```bash
for file in package.json tsconfig.json pyproject.toml setup.py requirements.txt Cargo.toml go.mod pom.xml build.gradle build.gradle.kts; do
  if [ -e "$file" ]; then
    echo "$file"
  fi
done
find . -maxdepth 1 -type f \( -name "*.csproj" -o -name "*.sln" \)
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
# Docs, agent instructions, and CI configs
for item in AGENTS.md CLAUDE.md .github/copilot-instructions.md README.md docs CONTRIBUTING.md CHANGELOG.md Jenkinsfile .circleci/config.yml .husky .pre-commit-config.yaml lefthook.yml; do
  if [ -e "$item" ]; then
    echo "$item"
  fi
done
if [ -d .claude ]; then
  find .claude -maxdepth 1 -type f -name "*.md"
fi
if [ -d .github/workflows ]; then
  find .github/workflows -maxdepth 1 -type f \( -name "*.yml" -o -name "*.yaml" \)
fi

# Linting, formatting, and test runner configs (root level)
find . -maxdepth 1 -type f \( \
  -name ".eslintrc*" -o -name "eslint.config*" \
  -o -name ".prettierrc*" -o -name "prettier.config*" \
  -o -name "ruff.toml" -o -name ".editorconfig" \
  -o -name "jest.config*" -o -name "vitest.config*" \
  -o -name "pytest.ini" -o -name "karma.conf*" \
  -o -name "cypress.config*" -o -name "playwright.config*" \)

# Context pointer signals: scan instruction and doc files for routing language
rg -ni "\[[^]]+\]\([^)]+\)|\b(see|read|follow|refer to|ADR|runbook|schema|entry point)\b" AGENTS.md CLAUDE.md README.md CONTRIBUTING.md docs 2> /dev/null | head -100

# Code-level entry points (registries, routes, schemas, barrels)
find . -maxdepth 3 \
  \( -type d \( -name ".git" -o -name ".context" -o -name "node_modules" -o -name "dist" -o -name "build" -o -name ".next" -o -name ".nuxt" -o -name "coverage" -o -name ".venv" -o -name "venv" -o -name "target" \) -prune \) -o \
  -type f \( -name "README.md" -o -name "index.*" -o -name "*registry*" -o -name "*routes*" -o -name "*schema*" \) -print

# Type checking strictness (TypeScript): if tsconfig.json exists, check for "strict": true.
# Python equivalent: pyproject.toml [tool.mypy] strict / [tool.pyright].
# pyproject.toml may also configure test runners — note both purposes when present.
```

Store all detected signals as `codebase_signals`.

### 1.3 Present Context Summary

```
Agent-Native Audit Starting

Project: {directory name}
Language(s): {detected}
Framework(s): {detected}
Key signals: {list of detected files/configs}

Launching 3 agents covering 5 dimensions...
```

---

## Step 2: Launch Parallel Dimension Analysis

Launch 3 Explore agents in parallel (single message, 3 Task tool calls).

### Agent Grouping

| Agent | Dimensions |
| --- | --- |
| **A: Type & Structure** | Fully Typed, Traversable |
| **B: Test & Feedback** | Test Coverage, Feedback Loops |
| **C: Documentation** | Self-Documenting |

Sub-agents emit findings without IDs. The orchestrator assigns sequential `AN-NNN` identifiers in Step 3.3 after sorting, so cross-references inside a single agent's output should use the finding title rather than a placeholder ID.

### Agent Prompt Construction

For each agent:

1. Read the prompt template from `references/dimension-agent.md`.
2. Read the dimension rubrics from `references/dimension-rubrics.md`.
3. Populate the prompt template:
   - `{project_name}`: current directory name
   - `{languages}`: detected languages from Step 1
   - `{frameworks}`: detected frameworks from Step 1
   - `{codebase_signals}`: signals from Step 1.3
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
- Context Pointer examples and gaps where relevant
- Findings (with IDs, severity, details)
- Improvement actions (with impact and effort)

### 3.2 Validate Completeness

For each of the 5 dimensions:

- Verify a score was returned (1-5 range)
- Verify evidence was provided
- If an agent returned incomplete results for a dimension, note it as "Incomplete — re-run recommended"

### 3.3 Assign Finding IDs

Sort all collected findings, then assign sequential IDs (AN-001, AN-002, ...). Sort by:

1. Severity: Critical first, then Important, then Suggestion
2. Within same severity: by dimension order (Typed → Traversable → Tests → Feedback → Docs)

If a sub-agent referenced a finding by title elsewhere in its output (in an improvement action, for example), update the reference to the assigned ID.

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
| --- | --- |
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
| --- | --- | --- |
| **Phase 1: Quick Wins** | Any action with Quick Win effort | Do these first — fast improvements regardless of impact |
| **Phase 2: Foundation** | High or Medium impact + Moderate effort | Core improvements requiring real work |
| **Phase 3: Polish** | Everything else (Significant effort, or Low impact + Moderate effort) | Refinements for maximum agent-nativeness |

### 5.3 Deduplicate

If multiple agents suggest similar actions (e.g., both Agent A and Agent B mention adding `.editorconfig`), merge into a single action.

---

## Step 6: Write Report

### 6.1 Check for Existing Report

Check if `AGENT_NATIVE_AUDIT.md` exists in the project root.

If it exists and `AUTO_MODE=true`, proceed in **Compare** mode automatically.

If it exists and `AUTO_MODE` is false, ask the user:

```
A previous Agent-Native Audit report exists.

How should I proceed?
1. Replace — overwrite with new results
2. Compare — write new report and show score changes vs previous
3. Abort — keep existing report
```

If **Compare**: parse the previous report's scorecard table to extract dimension scores. Include a "Score Changes" section in the new report showing deltas. If parsing fails (the existing file has an unexpected format or is not a prior audit report), fall back to **Replace** mode and note the parse failure in the Step 7 terminal summary.

If **Abort**: stop and inform the user.

### 6.2 Write Report File

Read the report template from `assets/audit-report.md`.

Populate and write `AGENT_NATIVE_AUDIT.md` in the project root with:

- Scorecard summary table
- Score changes (if compare mode)
- Dimension details with evidence, findings, and improvement actions
- Context Pointer evidence folded into Traversable and Self-Documenting details
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
