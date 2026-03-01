---
name: kramme:code:migrate
description: "(experimental) Plan and execute framework or library version migrations with phased upgrades and verification gates. Use when upgrading major framework versions (Angular, React, Node) or migrating between libraries."
argument-hint: "<target e.g. 'Angular 19', 'React 19', 'Node 22'>"
disable-model-invocation: true
user-invocable: true
---

# Code Migration

Plan and execute framework/library version migrations with phased upgrades, codemod automation, and verification gates between each phase.

## Process Overview

```
/kramme:code:migrate "Angular 19"
    |
    v
[Step 1: Parse Target] -> Framework + current/target versions
    |
    v
[Step 2: Fetch Migration Guide] -> Official docs, breaking changes, codemods
    |
    v
[Step 3: Codebase Impact Analysis] -> Grep for affected patterns
    |
    v
[Step 4: Generate Migration Plan] -> Phased plan with verification gates
    |
    v
[Step 5: User Review] -> Execute / phase-by-phase / plan only / SIW
    |
    v
[Step 6: Execute Phase-by-Phase] -> Migrate → verify → checkpoint
    |
    v
[Step 7: Completion Report] -> Summary + next steps
```

---

## Step 1: Parse Migration Target

1. Extract framework/library name and target version from `$ARGUMENTS`.
   - Examples: `Angular 19`, `React 19`, `Node 22`, `Next.js 15`, `TypeScript 5.5`
   - If empty or ambiguous:

```
AskUserQuestion
header: Migration Target
question: What framework/library and version do you want to migrate to?
options:
  - (freeform) e.g. "Angular 19", "React 19", "Node 22"
```

2. Detect the **current version** from project files:
   - `package.json` — `dependencies`, `devDependencies`, `engines`
   - `Cargo.toml` — `[dependencies]`
   - `pyproject.toml` / `requirements.txt`
   - `go.mod`
   - `*.csproj` — `<PackageReference>`, `<TargetFramework>`
   - `.nvmrc` / `.node-version` / `.tool-versions`

3. Validate direction:
   - Same version → report "Already on target version" and STOP.
   - Downgrade → warn, AskUserQuestion to confirm.

4. Report: `Current: {framework} {current} → Target: {framework} {target}`

---

## Step 2: Fetch Migration Guide

1. Read known migration sources from `resources/references/migration-sources.md`.

2. Use `WebSearch` for the official migration guide:
   - Query: `{framework} {current} to {target} migration guide official`
   - Try official URL patterns from the reference file.

3. Extract from the guide:
   - **Breaking changes** — renamed/removed APIs, behavior changes
   - **Deprecated APIs** — what's being phased out
   - **New patterns** — recommended replacements
   - **Available codemods** — automated transformation tools
   - **Minimum requirements** — Node version, peer dependencies

4. Check for codemods from `resources/references/codemod-registry.md`.

5. Read common patterns from `resources/references/common-breaking-patterns.md`.

6. If **no official guide found**: search community resources, warn user that manual research may be needed.

---

## Step 3: Codebase Impact Analysis

For each breaking change from Step 2:

1. **Grep** for affected patterns in the codebase.
2. **Count occurrences** and list affected files.
3. **Classify** each change:
   - **Automated** — codemod handles it entirely
   - **Semi-automated** — pattern-based find-and-replace with review
   - **Manual** — requires understanding context

For large codebases (50+ affected files), use the `Task` tool with `subagent_type: Explore` to parallelize analysis.

4. **Impact summary:**
```
Breaking changes applicable: {N} of {total from guide}
Files affected: {N}
  Automated (codemod): {N} changes across {N} files
  Semi-automated:      {N} changes across {N} files
  Manual:              {N} changes across {N} files
```

---

## Step 4: Generate Migration Plan

Read the template from `resources/templates/migration-plan.md`.

Create a phased plan:

**Phase 0: Pre-Migration** (Quick)
- Create migration branch from current HEAD
- Run `/kramme:deps:audit` if available
- Capture test baseline (pass/fail counts)
- Verification: branch exists, baseline captured

**Phase 1: Automated Migration — Codemods** (Quick to Moderate)
- List and run applicable codemods
- Review codemod output for correctness
- Verification: build compiles (type errors OK)

**Phase 2: Breaking Changes — Manual Fixes** (Moderate to Significant)
- Group by area (imports, APIs, types, config)
- Apply fixes in dependency order (shared code first)
- Verification: no references to removed/renamed APIs

**Phase 3: Configuration Updates** (Quick)
- Update framework and build tool config files
- Update CI/CD pipeline if needed
- Update runtime version constraints
- Verification: configuration is valid

**Phase 4: Fix Compilation and Type Errors** (Moderate)
- Run build, collect errors, fix systematically
- Verification: clean build

**Phase 5: Fix Tests** (Moderate to Significant)
- Run full test suite, fix broken tests
- Distinguish migration-caused vs. pre-existing failures
- Verification: pass rate matches or exceeds baseline

**Phase 6: Cleanup** (Quick)
- Remove compatibility shims and polyfills
- Remove migration TODOs
- Run linter with new rule set
- Verification: clean lint, no migration artifacts

Write plan to `migration-plan-{framework}-{target}.md` in project root.

---

## Step 5: User Review

```
AskUserQuestion
header: Migration Plan Ready
question: How would you like to proceed?
options:
  - Execute full plan — all phases with verification gates
  - Phase by phase — pause after each phase for review
  - Plan only — save plan, don't execute
  - Create SIW workflow — init SIW with phases as issues
```

- **Plan only:** report plan file location and STOP.
- **Create SIW:** reference `/kramme:siw:init` with the plan content, then STOP.
- **Execute / Phase by phase:** continue to Step 6.

---

## Step 6: Execute Phase-by-Phase

For each phase:

1. **Announce:**
   ```
   ── Phase {N}: {Name} ──────────────────────
   Effort: {estimate}
   ```

2. **Execute** migration steps (codemods, code changes, config updates).

3. **Run verification gate** — reference `/kramme:verify:run` for comprehensive checks.

4. **If verification fails:** attempt fix (max 3 iterations), then escalate:

```
AskUserQuestion
header: Verification Failed — Phase {N}
question: Phase {N} verification failed after 3 attempts. How to proceed?
options:
  - Show errors — display full output
  - Skip phase — mark incomplete, continue
  - Abort — stop, keep changes so far
  - Retry — another round of fixes
```

5. **Phase-by-phase mode:** pause after each successful phase:

```
AskUserQuestion
header: Phase {N} Complete
question: Continue to Phase {N+1}?
options:
  - Continue to Phase {N+1}
  - Review changes — show git diff
  - Abort — stop here
```

---

## Step 7: Completion Report

```
Migration Complete

Framework: {framework} {current} → {target}
Branch: {branch_name}

Phases Completed: {N}/{total}
  Phase 0: Pre-migration          {DONE/SKIPPED/FAILED}
  Phase 1: Codemods               {DONE/SKIPPED/FAILED} ({N} files)
  Phase 2: Breaking changes       {DONE/SKIPPED/FAILED} ({N} files)
  Phase 3: Configuration          {DONE/SKIPPED/FAILED}
  Phase 4: Type fixes             {DONE/SKIPPED/FAILED}
  Phase 5: Test fixes             {DONE/SKIPPED/FAILED} ({N}/{total})
  Phase 6: Cleanup                {DONE/SKIPPED/FAILED}

Verification:
  Build: {PASS/FAIL}
  Lint:  {PASS/FAIL}
  Tests: {PASS/FAIL} ({passed}/{total})

Manual Steps Remaining:
  - {list if any}

Next Steps:
  - /kramme:verify:run for full verification
  - /kramme:pr:create to submit migration PR
```

**STOP** — Do not continue unless the user gives further instructions.

---

## Error Handling

| Scenario | Action |
|---|---|
| No migration guide found | Proceed with codebase analysis, warn about manual research |
| Target version doesn't exist | Abort: `Version {target} not found for {framework}` |
| Current version not detected | AskUserQuestion for current version |
| Codemod fails | Capture error, skip to manual approach, log failure |
| Codemod produces invalid code | Revert affected files, fall back to manual |
| Verification gate fails 3 times | Escalate to user with options |
| Conflicting peer dependencies | Report conflicts, suggest resolution order |
| Migration branch exists | AskUserQuestion: use existing, create new, or abort |
