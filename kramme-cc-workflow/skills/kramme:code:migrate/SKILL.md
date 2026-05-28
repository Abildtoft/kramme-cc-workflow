---
name: kramme:code:migrate
description: "(experimental) Plan and execute framework or library version migrations with phased upgrades and verification gates. Use when upgrading major framework versions (Angular, React, Node) or migrating between libraries."
argument-hint: "<target e.g. 'Angular 19', 'React 19', 'Node 22'> [--auto]"
disable-model-invocation: true
user-invocable: true
---

# Code Migration

Plan and execute framework/library version migrations with phased upgrades, codemod automation, and verification gates between each phase.

Use `kramme:code:source-driven` for the official-doc grounding discipline inside this workflow, and `kramme:code:deprecate` after the migration when the old path still needs an explicit announcement / migration / removal plan.

Skip for: patch or minor version bumps with no breaking changes, isolated single-package upgrades, runtime-only changes (e.g. bumping `.nvmrc` without language/API changes), and routine dependency updates — use `kramme:deps:audit` or `kramme:pr:create` directly instead.

Parse `$ARGUMENTS` for `--auto` before Step 1.

- If present, set `AUTO_MODE=true` and remove the flag from the remaining input.
- `--auto` means: execute the full migration plan without pausing for review, skip phase-by-phase checkpoints, and abort on unresolved verification failures after the built-in retry budget is exhausted.

## Process Overview

```
/kramme:code:migrate "Angular 19" [--auto]
    |
    v
[Step 0: Preflight] -> Check clean working tree, detect prior plan/branch
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
                        (skipped under --auto: executes full plan)
    |
    v
[Step 6: Execute Phase-by-Phase] -> Migrate → verify → checkpoint
                                    (per-phase pause skipped under --auto)
    |
    v
[Step 7: Completion Report] -> Summary + next steps
```

---

## Step 0: Preflight

1. **Working tree must be clean.** Run `git status --porcelain`.
   - If output is non-empty:
     - If `AUTO_MODE=true`, abort with: `Working tree is dirty. Commit or stash changes before running --auto migration. Files: {list}`.
     - Otherwise:

```
AskUserQuestion
header: Working Tree Not Clean
question: Uncommitted changes will be carried onto the migration branch, mixing pre-existing work with migration changes. How to proceed?
options:
  - Abort — let me commit or stash first
  - Stash and continue — run `git stash -u`, restore after
  - Continue anyway — I accept the mixed diff
```

2. **Detect prior migration state.** Check for an existing plan file matching `migration-plan-*.md` in the project root and an existing `migrate/*` branch.
   - If neither: continue to Step 1.
   - If a prior plan or branch exists:
     - If `AUTO_MODE=true`, abort with: `Prior migration artifacts detected ({plan-file} / {branch-name}). Auto mode will not overwrite. Remove artifacts or run without --auto to choose.`
     - Otherwise:

```
AskUserQuestion
header: Prior Migration Detected
question: Found existing migration artifacts ({plan-file} / {branch-name}). How to proceed?
options:
  - Resume — keep plan, switch to branch, ask which phase to start from
  - Restart — delete plan, abandon branch (confirm), start fresh
  - Abort — leave artifacts untouched, stop here
```

   - On **Resume**: load the existing plan, check out the branch, AskUserQuestion for the phase number to start from, then jump to Step 6 with that phase.
   - On **Restart**: confirm branch deletion explicitly before deleting; then continue to Step 1.

---

## Step 1: Parse Migration Target

1. Extract framework/library name and target version from `$ARGUMENTS`.
   - Examples: `Angular 19`, `React 19`, `Node 22`, `Next.js 15`, `TypeScript 5.5`
   - If empty or ambiguous and `AUTO_MODE=true`:
     - Abort with: `Auto mode requires an explicit migration target such as "Angular 19" or "Node 22".`
   - If empty or ambiguous and `AUTO_MODE` is false:

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
   - Downgrade:
     - If `AUTO_MODE=true`, abort with a warning instead of prompting.
     - Otherwise warn, AskUserQuestion to confirm.

4. Report: `Current: {framework} {current} → Target: {framework} {target}`

---

## Step 2: Fetch Migration Guide

Run the DETECT / FETCH / IMPLEMENT / CITE workflow from `kramme:code:source-driven` here. Treat that skill as the source of truth for how to ground, fetch, and cite documentation. This step adds only the migration-specific scope: which sources to check and what migration details to extract.

1. Read known migration sources from `references/migration-sources.md` to identify the official migration-guide URLs, changelogs, and framework-specific upgrade hubs for the target stack.

2. Use the `kramme:code:source-driven` fetch discipline to retrieve the official migration guide and any adjacent official changelog / breaking-change references for `{framework} {current} -> {target}`.
   - Prefer the exact official URLs or URL patterns from `references/migration-sources.md`.
   - Record the deep links you relied on.
   - If an important migration claim cannot be backed by an official source, emit `UNVERIFIED` instead of guessing.

3. Extract from the guide:
   - **Breaking changes** — renamed/removed APIs, behavior changes
   - **Deprecated APIs** — what's being phased out
   - **New patterns** — recommended replacements
   - **Available codemods** — automated transformation tools
   - **Minimum requirements** — Node version, peer dependencies

4. Check for codemods from `references/codemod-registry.md`.

5. Read common patterns from `references/common-breaking-patterns.md`.

6. If **no official guide found**: mark that gap explicitly, then search community resources as a fallback and warn the user that manual verification may be needed before implementation.

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

Read the template from `assets/migration-plan.md`.

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

Write plan to `migration-plan-{slug}.md` in the project root, where `{slug}` is `{framework}-{target}` normalized as:

- lowercase
- non-alphanumeric runs collapsed to a single `-`
- leading/trailing `-` trimmed
- truncated to 60 characters

Examples: `Angular 19` → `angular-19`, `Next.js 15` → `next-js-15`, `Node 22` → `node-22`. Reject the input and abort if the slug is empty after normalization.

Refuse to write outside the project root. If a file already exists at the target path, the Step 0 preflight should have handled it — if it slips through, AskUserQuestion (overwrite / abort), or abort under `AUTO_MODE`.

---

## Step 5: User Review

If `AUTO_MODE=true`, skip this prompt and choose **Execute full plan — all phases with verification gates**.

Otherwise:

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

- **Plan only:** print the plan file path and STOP.
- **Create SIW:** print `Run /kramme:siw:init {plan-path}` for the user, do not invoke it automatically, then STOP.
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

3. **Run verification gate** — invoke `/kramme:verify:run` via the Skill tool for comprehensive checks, or fall back to the project's build/lint/test commands if the skill is unavailable.

4. **If verification fails:** attempt fix (max 3 iterations), then escalate:

If `AUTO_MODE=true`, skip the prompt below after the 3 failed attempts, print the errors, and abort while keeping changes made so far.

Otherwise:

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

Skip this checkpoint entirely when `AUTO_MODE=true`.

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
| --- | --- |
| No migration guide found | Proceed with codebase analysis, warn about manual research |
| Target version doesn't exist | Abort: `Version {target} not found for {framework}` |
| Current version not detected | If `AUTO_MODE=true`, abort with a clear error. Otherwise AskUserQuestion for current version |
| Codemod fails | Capture error, skip to manual approach, log failure |
| Codemod produces invalid code | Revert affected files, fall back to manual |
| Verification gate fails 3 times | If `AUTO_MODE=true`, print errors and abort while keeping changes so far. Otherwise escalate to user with options |
| Conflicting peer dependencies | Report conflicts, suggest resolution order |
| Migration branch exists | If `AUTO_MODE=true`, abort with a clear error. Otherwise AskUserQuestion: use existing, create new, or abort |
