---
name: kramme:siw:reverse-engineer-spec
description: Reverse engineer an SIW specification from existing code. Analyzes a git branch diff, folder, or file set to produce a structured spec compatible with the SIW workflow. Use when code exists without documentation, onboarding to unfamiliar code, or bootstrapping SIW from an existing implementation.
argument-hint: "[branch | folder | file(s)] [--base main] [--model opus|sonnet|haiku]"
disable-model-invocation: true
user-invocable: true
---

# Reverse Engineer SIW Spec from Code

Analyze existing code to produce a structured SIW-compatible specification. Works backward from implementation to documentation, producing specs that plug directly into the SIW workflow (`/kramme:siw:discovery`, `/kramme:siw:spec-audit`, `/kramme:siw:phases-generate`, etc.).

## Workflow Boundaries

**This command ONLY generates a specification from existing code.**

- **DOES**: Analyze code, produce an SIW spec, optionally scaffold the full SIW directory
- **DOES NOT**: Implement features, create issues, or modify source code

## Process Overview

```
/kramme:siw:reverse-engineer-spec [branch | folder | file(s)] [--base main]
    ↓
[Phase 1: Resolve input & scope] -> branch diff / folder / files
    ↓
[Phase 2: Parallel deep exploration] -> 2-4 agents analyze file groups
    ↓
[Phase 3: Cross-check for gaps] -> catch missed files and details
    ↓
[Phase 4: Write SIW spec] -> structured spec + optional SIW scaffolding
    ↓
[Phase 5: Verify & report] -> completeness check + next steps
```

## Phase 1: Resolve Input & Scope

`$ARGUMENTS` contains any text the user provided after `/kramme:siw:reverse-engineer-spec`.

### 1.1 Parse Arguments and Flags

Parse `$ARGUMENTS` as shell-style arguments so quoted paths stay intact.

- If `--base <branch>` is present, set `base_branch` to the value and remove the flag pair from the argument list. Default: `main`.
- If `--model <model>` is present, set `agent_model` to the value and remove the flag pair. Default: `sonnet`. Validate immediately: if the value is not one of `opus`, `sonnet`, or `haiku`, stop with: "Invalid model `{value}`. Valid options: opus, sonnet, haiku."
- Treat remaining arguments as one of: explicit file paths, a folder path, or empty (branch diff mode).

### 1.2 Detect Input Type

Try each detection in order. Stop at the first match:

1. **No remaining arguments** → Branch diff mode (Case 1)
2. **All arguments exist as files on disk** → Explicit file paths (Case 3)
3. **Single argument is a directory** (`ls -d {path}` succeeds) → Folder path (Case 2)
4. **Single argument resolves as a git ref** (`git rev-parse --verify {arg}` succeeds) → Branch diff mode with `base_branch` set to the argument (Case 1)
5. **None of the above** → Stop with: "Could not interpret `{argument}` as file paths, a folder, or a branch name. Please check the input."

### Case 1: Branch Diff (default)

If no file/folder arguments, analyze the current branch against `base_branch`.

**Pre-validation (required before any git commands):**

1. Verify inside a git repository: `git rev-parse --is-inside-work-tree`
   - If this fails, stop: "Not inside a git repository. Use a folder or file path instead."
2. Verify `base_branch` exists: `git rev-parse --verify $base_branch`
   - If this fails, attempt auto-detection: `git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@'`
   - If auto-detection succeeds, use the detected branch and inform the user: "Branch `{base_branch}` not found. Using detected default branch `{detected}`."
   - If auto-detection also fails, stop: "Branch `{base_branch}` not found and could not auto-detect the default branch. Specify a base with `--base <branch>`."

**Analyze the diff:**

```bash
git merge-base $base_branch HEAD
git diff --stat $(git merge-base $base_branch HEAD)...HEAD
git diff --stat $(git merge-base $base_branch HEAD)...HEAD | tail -1
git log --oneline $(git merge-base $base_branch HEAD)..HEAD
```

If `merge-base` fails (e.g., no common ancestor), stop: "Could not find a common ancestor between `{base_branch}` and HEAD. Specify a different base with `--base <branch>`."

If the diff is empty (no changes vs base), stop and inform the user.

### Case 2: Folder Path

If `$ARGUMENTS` is a directory:

```bash
# Scan for source files (exclude common generated/vendor directories)
find {folder} -maxdepth 4 -type f \
  \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" \
  -o -name "*.vue" -o -name "*.svelte" \
  -o -name "*.py" -o -name "*.go" -o -name "*.rs" -o -name "*.cs" \
  -o -name "*.java" -o -name "*.rb" -o -name "*.swift" -o -name "*.kt" \) \
  ! -path "*/node_modules/*" ! -path "*/dist/*" ! -path "*/build/*" \
  ! -path "*/.git/*" ! -path "*/vendor/*" ! -path "*/__pycache__/*" \
  2>/dev/null
```

If zero files are found, stop: "No source files found in `{folder}`. Verify the path is correct and contains supported file types (.ts, .tsx, .js, .jsx, .vue, .svelte, .py, .go, .rs, .cs, .java, .rb, .swift, .kt)."

### Case 3: Explicit File Paths

Using the shell-style parsed arguments from Section 1.1, verify each file exists. Skip non-existent files with a warning. If no files remain after filtering, stop: "None of the specified files exist. Verify the file paths and current directory."

### 1.3 Categorize Files

From the file list, categorize into groups:

- **Core implementation**: New modules, business logic, main feature code
- **Integration points**: Modified existing files, connectors, hooks, adapters
- **Tests**: Unit tests, integration tests, e2e tests (files matching `*.test.*`, `*.spec.*`, `*_test.*`, `test_*`, `tests/`, `__tests__/`)
- **Configuration**: Feature flags, env vars, types/interfaces, configs, package manifests
- **Incidental**: Formatting changes, import reordering, minor refactors

### 1.4 Confirm Scope

Use AskUserQuestion:

```yaml
header: "Reverse Engineer Scope"
question: "I found {n} files to analyze. Here's the breakdown:\n\n- Core implementation: {n} files\n- Integration points: {n} files\n- Tests: {n} files\n- Configuration: {n} files\n- Incidental: {n} files\n\nShould I proceed with this scope?"
options:
  - label: "Proceed"
    description: "Analyze all {n} files"
  - label: "Exclude incidental files"
    description: "Skip formatting and minor changes ({n} files)"
  - label: "Core + tests only"
    description: "Focus on new code and test files ({n} files)"
```

After applying the scope filter, validate that the remaining file count is greater than zero. If zero files remain, stop: "No files remain after applying the scope filter. Consider a broader scope."

## Phase 2: Parallel Deep Exploration

For each file group, launch an Explore agent using the Task tool (`subagent_type=Explore`, `model={agent_model}`).

**All agents run in parallel** — launch them in a single message with multiple Task tool calls.

### 2.1 Determine Agent Count

| File Count | Agents | Grouping |
|------------|--------|----------|
| <15 files | 2 | A: Core + Integration; B: Tests + Config |
| 15-40 files | 3 | A: Core implementation; B: Integration + Config; C: Tests |
| 40+ files | 4 | A: Core implementation; B: Integration points; C: Tests; D: Config + Infrastructure |

Skip any agent whose file group is empty. Note the absence in the generated spec (e.g., "No test files were found in this changeset").

### 2.2 Agent Prompts

Each agent receives its file list and a focused analysis prompt.

**Agent A: Core Implementation**

```
Analyze these files that form the core implementation of a feature.

Files: {file_list}

For each file, report:
1. **Purpose**: What this file does (1 sentence)
2. **Key exports**: Functions, classes, types exported
3. **Data flow**: What data comes in, what goes out
4. **Dependencies**: What this file imports/depends on
5. **Connections**: How it relates to other files in this group

After individual analysis, synthesize:
- **Problem being solved**: What user/business need does this code address?
- **Solution approach**: What architectural pattern or strategy is used?
- **Key abstractions**: What are the main concepts/entities?
- **Data model**: What are the core data structures?

{If branch diff mode, also provide:}
For files with diffs available, read the actual diff to understand what changed vs what existed before.
```

**Agent B: Integration Points**

```
Analyze these files that were modified to integrate a feature into an existing codebase.

Files: {file_list}

For each file, report:
1. **What changed**: Key modifications (not formatting/imports)
2. **Why (inferred)**: What the changes achieve
3. **API surface**: Any new/changed public APIs, routes, exports
4. **Breaking changes**: Anything that changes existing behavior

Synthesize:
- **Integration strategy**: How does the new code connect to existing code?
- **Touched boundaries**: What system boundaries were crossed?
- **Side effects**: Any changes to existing behavior?
```

**Agent C: Tests**

```
Analyze these test files to extract the product requirements they encode.

Files: {file_list}

For each test file, report:
1. **What it tests**: Module/component under test
2. **Key assertions**: What behaviors are validated
3. **Edge cases**: What boundary conditions are covered
4. **Missing coverage**: Obvious gaps (inferred from test structure)

Synthesize:
- **Product requirements**: What user-facing behaviors do these tests guarantee?
- **Acceptance criteria**: What conditions must hold for this feature to work?
- **Test coverage map**: Which components have tests, which don't?
```

**Agent D: Configuration & Infrastructure (if launched)**

```
Analyze these configuration and infrastructure files.

Files: {file_list}

For each file, report:
1. **Purpose**: What this config controls
2. **Key settings**: Important values and what they affect
3. **Feature flags**: Any gating mechanisms
4. **Environment concerns**: Different behavior per environment

Synthesize:
- **Rollout strategy**: How is this feature gated or rolled out?
- **Dependencies**: External services, packages, or tools required
- **Environment matrix**: What varies across environments?
```

### 2.3 Validate Agent Results

After all agents return, check each agent's output:

1. Is the output non-empty?
2. Does it contain the expected synthesis sections (e.g., "Problem being solved" for Agent A, "Integration strategy" for Agent B)?

If an agent failed, returned empty output, or returned an error message instead of analysis, inform the user: "Agent {role} failed to complete its analysis. {n} files were not analyzed by a dedicated agent." Then use AskUserQuestion:

```yaml
header: "Agent Failure"
question: "How should I proceed?"
options:
  - label: "Continue with reduced analysis"
    description: "Unanalyzed files will be read directly (shallower analysis)"
  - label: "Abort"
    description: "Cancel the reverse-engineering process"
```

If continuing with reduced analysis, note in the generated spec's Open Questions section that certain analysis areas may be incomplete.

## Phase 3: Cross-Check for Gaps

After agents return and results are validated, verify completeness.

### 3.1 File Coverage Check

Compare the set of files analyzed by agents against the full file list from Phase 1. Identify any files that were not covered.

### 3.2 Fill Gaps

For uncovered files, read the diffs or file contents directly. These often contain important details:
- Type declarations (new fields on models)
- Feature flag definitions
- Bug fixes discovered during development
- Compatibility shims in existing code

### 3.3 Commit Message Context

**Skip this section entirely if not in branch diff mode.**

Use commit messages for additional "why" context:

```bash
git log --format="%s%n%b" $(git merge-base $base_branch HEAD)..HEAD
```

Extract:
- Problem descriptions from commit messages
- Design rationale from commit bodies
- Issue references (Linear, GitHub, Jira patterns)

## Phase 4: Write SIW Spec

### 4.1 Check for Existing SIW Directory

**If `siw/` exists with spec files:**

Use AskUserQuestion:

```yaml
header: "Existing SIW Workflow Found"
question: "An SIW workflow already exists. How should I handle the reverse-engineered spec?"
options:
  - label: "Create new spec file"
    description: "Add a new spec alongside existing ones"
  - label: "Replace existing spec"
    description: "Overwrite the current spec with reverse-engineered content"
  - label: "Abort"
    description: "Cancel without writing"
```

**If `siw/` does not exist:**

Use AskUserQuestion:

```yaml
header: "SIW Scaffolding"
question: "No SIW workflow exists yet. Should I create the full SIW directory structure alongside the spec?"
options:
  - label: "Full SIW setup"
    description: "Create siw/ with spec, LOG.md, OPEN_ISSUES_OVERVIEW.md, and issues/ directory"
  - label: "Spec only"
    description: "Create just the spec file in siw/"
  - label: "Abort"
    description: "Cancel without writing"
```

### 4.2 Auto-detect Spec Filename

Use the same heuristics as `kramme:siw:init`:

- Keywords like "feature", "add", "implement", "new" → `FEATURE_SPECIFICATION.md`
- Keywords like "api", "endpoint", "service" → `API_DESIGN.md`
- Keywords like "doc", "documentation", "guide" → `DOCUMENTATION_SPEC.md`
- Keywords like "tutorial", "learn", "teach" → `TUTORIAL_PLAN.md`
- Keywords like "system", "architecture", "design" → `SYSTEM_DESIGN.md`
- Default fallback → `PROJECT_PLAN.md`

Base detection on the synthesized problem statement and solution approach from Phase 2 agents.

Confirm with user:

```yaml
header: "Specification Document"
question: "I'll create a specification document. Which name fits best?"
options:
  - label: "{detected_name}"
    description: "Recommended based on analysis"
  - label: "FEATURE_SPECIFICATION.md"
    description: "For feature implementations"
  - label: "API_DESIGN.md"
    description: "For API design work"
  - label: "PROJECT_PLAN.md"
    description: "For general projects"
  - label: "Custom name"
    description: "Enter your own filename"
```

If "Custom name" selected, use AskUserQuestion to get the filename. Validate: must be non-empty and end with `.md` (append if missing).

### 4.3 Write Spec Document

Write `siw/{spec_filename}` with this structure:

```markdown
# {Feature/Project Name}

## Overview

{Problem statement: what user/business pain this addresses, inferred from code and tests}

{Solution overview: high-level description of the approach and key design properties}

**Status:** Reverse-engineered from code
**Created:** {current date}
**Source:** {Branch `{branch}` vs `{base}` | Folder `{path}` | Files}

## Objectives

{Inferred from tests and code structure, formatted as checkbox list}
- [ ] {objective 1}
- [ ] {objective 2}

## Scope

### In Scope
{What the code actually implements}

### Out of Scope
{What the code explicitly does NOT handle, inferred from boundaries and missing test coverage}

## Success Criteria

{Inferred from test assertions and observable behavior, formatted as checkbox list}
- [ ] {criterion 1 — a verifiable condition that must hold}
- [ ] {criterion 2}

## Architecture

{If component relationships are clear from analysis, include an ASCII diagram showing data flow. Otherwise, use a bullet-point list of components and their dependencies.}

### Data Lifecycle
{Step-by-step flow from initial state through steady state}

## Technical Design

### Data Model
{Core data structures, types, schemas — from Agent A synthesis}

### API Contracts
{Endpoints, methods, request/response shapes — from Agent B synthesis}
{Skip if not applicable}

### Key Patterns
{Architectural patterns, algorithms, integration approaches}

### Feature Flags & Gating
{From Agent D synthesis, skip if none}

### Error Handling
{Error scenarios and fallback behavior observed in code}

## File Inventory

### New Files
| File | Purpose |
|------|---------|
| `{path}` | {one-line description} |

### Modified Files
| File | Changes |
|------|---------|
| `{path}` | {one-line description of key changes} |

## Testing Strategy

### Unit Tests
{From Agent C synthesis}

### Integration / E2E Tests
{From Agent C synthesis}

### Coverage Gaps
{Missing test coverage identified by Agent C}

## Tasks

Tasks will be tracked in individual issue files. See `siw/OPEN_ISSUES_OVERVIEW.md` for active work.

## Design Decisions

| Decision | Choice | Rationale (inferred) |
|----------|--------|----------------------|
| {area} | {what was chosen} | {why, from code patterns and commits} |

## Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| {risk} | {H/M/L} | {H/M/L} | {existing or suggested mitigation} |

## Open Questions

{Areas where intent is unclear from code alone — these are candidates for `/kramme:siw:discovery`}

- {question 1}
- {question 2}

## References

- Issues: `siw/OPEN_ISSUES_OVERVIEW.md`
- Progress: `siw/LOG.md`
{If branch diff mode:}
- Branch: `{branch}` (base: `{base_branch}`)
- Commits: {n} commits, {files_changed} files changed
```

### 4.4 Create SIW Scaffolding (if "Full SIW setup" selected)

Create SIW-compatible scaffolding matching the structure from `kramme:siw:init`.

#### 4.4.1 Create siw/LOG.md

```markdown
# LOG.md

## Current Progress

**Last Updated:** {current date}
**Quick Summary:** Spec reverse-engineered from {source description}

### Project Status

- **Status:** Planning | **Current Phase:** Specification | **Overall Progress:** 0 tasks

### Last Completed

- Reverse-engineered specification from existing code

### Next Steps

1. Run `/kramme:siw:discovery` to fill open questions
2. Run `/kramme:siw:spec-audit` to validate spec quality
3. Run `/kramme:siw:phases-generate` to create issues
4. **Blockers:** None

---

## Decision Log

_Decisions will be documented here as they are made._

---

## Rejected Alternatives Summary

| Alternative | For | Why Rejected | Decision # |
|------------|-----|--------------|------------|
| _None yet_ | | | |

---

## Guiding Principles

1. {To be defined during implementation}

## References

- Spec: `siw/{spec_filename}`
- Issues: `siw/OPEN_ISSUES_OVERVIEW.md`
```

#### 4.4.2 Create siw/OPEN_ISSUES_OVERVIEW.md

```markdown
# Open Issues Overview

## General

| # | Title | Status | Priority | Related |
|---|-------|--------|----------|---------|
| _None_ | _Use `/kramme:siw:issue-define` to create first issue (G-001)_ | | | |

**Status Legend:** READY | IN PROGRESS | IN REVIEW | DONE

**Issue Naming:** `G-XXX` for general issues, `P1-XXX`, `P2-XXX` for phase-specific issues.

**Details:** See `siw/issues/ISSUE-{prefix}-XXX-*.md` files.
```

#### 4.4.3 Create siw/issues/ directory

```bash
mkdir -p siw/issues
touch siw/issues/.gitkeep
```

## Phase 5: Verify Completeness & Report

### 5.1 Verify File Coverage

Check that every file from Phase 1 appears in the spec's File Inventory (Section: New Files or Modified Files). If any are missing, add them to the appropriate table.

### 5.2 Verify Test References

Check that every test file from Phase 1 is referenced in the Testing Strategy section.

### 5.3 Report Summary

Display:

```
Reverse-Engineered SIW Specification
─────────────────────────────────────

Source:     {Branch `branch` vs `base` | Folder `path` | N files}
Files:      {n} analyzed ({n} core, {n} integration, {n} tests, {n} config)
Commits:    {n} (branch diff mode only)

Created:
  siw/{spec_filename}            - Reverse-engineered specification
  {If full setup:}
  siw/LOG.md                     - Progress and decisions (temporary)
  siw/OPEN_ISSUES_OVERVIEW.md    - Issue tracking (temporary)
  siw/issues/                    - Individual issue files (temporary)

Open Questions: {n} areas where code intent is unclear

Next Steps:
  1. Review the spec for accuracy — reverse-engineering infers intent, verify it
  2. Run /kramme:siw:discovery to fill open questions through interview
  3. Run /kramme:siw:spec-audit to validate spec quality
  4. Run /kramme:siw:phases-generate to create issues for remaining work
```

**STOP HERE.** Wait for the user's next instruction.

## Important Guidelines

1. **Infer the "why"** — Code shows "what" but not always "why". Use test assertions, comments, commit messages, and the shape of changes to infer product motivation.
2. **Parallel agents are essential** — A branch with 50+ files takes too long to analyze sequentially. 3-4 parallel agents cut analysis time significantly.
3. **Cross-check is critical** — Agents inevitably miss some files. The Phase 3 cross-check catches small but important changes (type declarations, bug fixes, compatibility shims).
4. **Don't over-document incidentals** — Formatting changes, import reordering, and trailing commas can be mentioned in a single line rather than getting their own subsection.
5. **Use tables liberally** — File inventories, feature flags, risks — tables are scannable and compact.
6. **Flag uncertainty** — When intent is unclear from code alone, add it to Open Questions rather than guessing. That's what `/kramme:siw:discovery` is for.
7. **SIW compatibility** — The output spec must work with existing SIW tools. Follow the same section naming and structure conventions as `kramme:siw:init`.
8. **Agent output quality** — Agents may return shallow or generic analysis for complex files. If an agent's synthesis lacks specifics (e.g., vague "Problem being solved" without concrete details), supplement it by reading the key files directly during the Phase 3 cross-check rather than using the low-quality output verbatim.
