---
name: kramme:code:migrate
description: "(experimental) Plan and execute framework or library version migrations with phased upgrades and verification gates. Classifies migrations as Advisory or Compulsory and phases them with the Strangler, Adapter, or Feature-Flag Migration pattern. Emits SIMPLICITY CHECK, NOTICED BUT NOT TOUCHING, UNVERIFIED, and ASK FIRST markers. Use when upgrading major framework versions (Angular, React, Node) or migrating between libraries. Pairs with kramme:code:deprecate for removing the old path once callers have moved."
argument-hint: "<target e.g. 'Angular 19', 'React 19', 'Node 22'> [--auto]"
disable-model-invocation: true
user-invocable: true
---

# Code Migration

Plan and execute framework/library version migrations with phased upgrades, codemod automation, and verification gates between each phase.

Parse `$ARGUMENTS` for `--auto` before Step 1.

- If present, set `AUTO_MODE=true` and remove the flag from the remaining input.
- `--auto` means: execute the full migration plan without pausing for review, skip phase-by-phase checkpoints, and abort on unresolved verification failures after the built-in retry budget is exhausted.

## Process Overview

```
/kramme:code:migrate "Angular 19" [--auto]
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

## Markers

Four markers anchor this skill's output. Emit them inline during the steps below; they turn assumptions into reviewable artifacts.

```
SIMPLICITY CHECK: <the smallest migration plan that reaches the target>
```

State the smallest coherent plan before adding phases or codemods. An over-engineered migration is its own risk — each extra phase is a place the plan can derail. Only expand past the simplest plan when a concrete breaking change forces it.

```
NOTICED BUT NOT TOUCHING: <what you saw>
Why skipping: <out-of-scope / unrelated / deferred>
```

Use during Step 3 impact analysis when grep turns up an adjacent smell (a dead import, a TODO that predates the migration, a lint disable). Log and move on. A migration that silently cleans up unrelated code is unreviewable and makes rollback harder.

```
UNVERIFIED: <assumption that has no source>
```

Flag anything you accepted without checking: "the codemod handles all call sites" (read the diff), "the guide says v18 is backward compatible" (which API specifically?), "peer dependencies will resolve" (run the install). Every `UNVERIFIED` must be either verified or explicitly left open with an owner before the migration PR is opened.

```
ASK FIRST: <which boundary you're about to cross>
Plan: <what you intend to do>
```

Use before any of: running a Compulsory migration on main, removing a public API, changing the deployment target (Node major, Python minor, CDK version), using `--auto` on a codebase with no test baseline. Surface the plan and wait for confirmation — these are the changes that cascade when wrong.

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

5. **Classify the migration type.** Every migration is one of:

   - **Advisory** — optional upgrade; the old version remains stable and supported. Signals: no open CVE against current, vendor not announcing EOL, no platform forcing function. Treat Advisory as "do it when there's a clear win" — bias toward deferring if the plan is heavy.
   - **Compulsory** — forced by security (active CVE), maintenance (published EOL date), or platform (hosting target bumps minimum runtime, peer dependency drops current). Treat Compulsory as "do it now, accept more risk" — bias toward the shortest-path plan even if it breaks incidental behavior.

   Detect via: `npm audit` / ecosystem equivalent, vendor EOL pages (Node, Python, framework release schedules), peer-dependency errors at install time. Ambiguous cases default to Advisory — then reclassify if a specific forcing function surfaces.

   If the migration is Compulsory, add `ASK FIRST: running a Compulsory migration` before proceeding on a shared branch.

   Report: `Classification: {Advisory|Compulsory} — {reason}`

---

## Step 2: Fetch Migration Guide

1. Read known migration sources from `references/migration-sources.md`.

2. Use `WebSearch` for the official migration guide:
   - Query: `{framework} {current} to {target} migration guide official`
   - Try official URL patterns from the reference file.

3. Extract from the guide:
   - **Breaking changes** — renamed/removed APIs, behavior changes
   - **Deprecated APIs** — what's being phased out
   - **New patterns** — recommended replacements
   - **Available codemods** — automated transformation tools
   - **Minimum requirements** — Node version, peer dependencies

4. Check for codemods from `references/codemod-registry.md`.

5. Read common patterns from `references/common-breaking-patterns.md`.

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

Read the template from `assets/migration-plan.md`.

Emit `SIMPLICITY CHECK: <smallest plan that reaches the target>` before expanding into phases.

### Pick a migration pattern

Pick exactly one named pattern for this plan and record it in the plan file's header:

- **Strangler** — incrementally replace behind a façade that routes to old or new depending on the path/feature/tenant. Use when the old code is load-bearing, callers are many, and the migration spans weeks or months. Phasing: write the façade in Phase 1; migrate callers over the course of Phases 2–N; delete the old path in Phase 6.
- **Adapter** — add a thin compatibility shim that exposes the new API's shape over the old implementation (or vice versa) during transition. Use when the API shape changed but callers are numerous and mechanical to port, or when a codemod needs an intermediate landing surface. Phasing: land the adapter in Phase 1; run codemods in Phase 2; remove the adapter in Phase 6.
- **Feature Flag Migration** — gate the new path behind a flag and flip users in batches. Use when the migration has runtime risk and you need per-cohort rollback. Phasing: wrap the new path in the flag in Phase 2; roll out incrementally in Phase 5; remove the flag in Phase 6.

Default pick if the situation doesn't clearly fit one: **Adapter** for library migrations (Angular 18→19, React 18→19), **Strangler** for architecture shifts (monolith→service, REST→GraphQL), **Feature Flag** for runtime-risky (new database client, new auth provider).

### Phased plan structure

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
|---|---|
| No migration guide found | Proceed with codebase analysis, warn about manual research |
| Target version doesn't exist | Abort: `Version {target} not found for {framework}` |
| Current version not detected | If `AUTO_MODE=true`, abort with a clear error. Otherwise AskUserQuestion for current version |
| Codemod fails | Capture error, skip to manual approach, log failure |
| Codemod produces invalid code | Revert affected files, fall back to manual |
| Verification gate fails 3 times | If `AUTO_MODE=true`, print errors and abort while keeping changes so far. Otherwise escalate to user with options |
| Conflicting peer dependencies | Report conflicts, suggest resolution order |
| Migration branch exists | If `AUTO_MODE=true`, abort with a clear error. Otherwise AskUserQuestion: use existing, create new, or abort |

---

## Pairs with

- `kramme:code:deprecate` — a migration *toward* a new framework or library usually implies a deprecation *of* the old. When the migration finishes and the old path still has references, hand off to `kramme:code:deprecate` for the removal-side workflow (5-question checklist, zombie-code gate, four-step removal).
- `kramme:code:source-driven` — confirm framework claims against official docs via Context7 or direct URLs. Use when the migration guide is ambiguous or the codemod's behavior is not documented.
- `kramme:verify:run` — the verification gate between phases.

---

## Common Rationalizations

Each of these is a version of "skip the markers or the plan". Correct response follows.

| Rationalization | Reality |
|---|---|
| "The old version still works." | If it's Compulsory (CVE, EOL, platform), "still works" expires on a date. |
| "The codemod caught everything." | `UNVERIFIED` until you read the diff. Codemods are pattern-matchers — they miss anything the pattern didn't cover. |
| "We can migrate later." | Advisory migrations get cheaper only if the ecosystem doesn't move further; usually later is more expensive, not less. |
| "The guide says backward compatible." | Backward compatible *for the documented surface* — Hyrum's Law says callers depend on observables beyond that surface. Emit `UNVERIFIED` and grep for the specific APIs. |
| "Phase 4 is just type errors, skip verification." | Type-error fixes routinely introduce behavior changes (coercions, narrowing loss). Run the gate. |
| "`--auto` is faster." | `--auto` on a Compulsory migration without a test baseline is `ASK FIRST` territory — skipping it trades human review for a half-verified migration PR. |

## Red Flags

If you see any of these in your own draft, stop and re-author:

- A phase in the plan has no verification gate (every phase must have one, even Phase 6).
- `--auto` used with no captured test baseline at Phase 0.
- Codemod output not reviewed before running the next phase's work on top of it.
- `NOTICED BUT NOT TOUCHING` observations silently fixed in the migration diff instead of logged.
- Migration plan has no rollback criterion — no "if verification fails at Phase N, revert to …" for the Strangler façade, the Adapter, or the feature flag.
- Compulsory migration running on a shared branch with no `ASK FIRST` surfacing.
- Peer-dependency conflict at install time dismissed as "resolve in lockfile" without a named resolution plan.
- `UNVERIFIED` markers still open when the final completion report is generated.
- "Phase skipped" in the completion report with no ticket filed to finish it.
- Public API removed in Phase 6 without a `kramme:code:deprecate` workflow having run in parallel.

## Verification

Before declaring the migration complete, self-check:

- [ ] Classification (Advisory / Compulsory) recorded in the plan file's header.
- [ ] Named pattern (Strangler / Adapter / Feature Flag) recorded in the plan file's header.
- [ ] `SIMPLICITY CHECK` emitted before Step 4 expanded into phases; the plan does not include phases the target does not force.
- [ ] Every phase has a verification gate; every gate passed or was explicitly escalated and resolved.
- [ ] Every `NOTICED BUT NOT TOUCHING` observation is logged (in the plan file, a ticket, or the commit body) — none silently fixed in the diff.
- [ ] Every `UNVERIFIED` assumption is either verified, or explicitly deferred with a named owner and follow-up.
- [ ] Every `ASK FIRST` situation was surfaced and confirmed before the code landed.
- [ ] Test pass rate at Phase 5 meets or exceeds the Phase 0 baseline.
- [ ] Compilation and lint clean at Phase 6; no migration-artifact comments, shims, or polyfills left behind unless the plan explicitly kept them.
- [ ] If the old path still has references, a `kramme:code:deprecate` workflow is scheduled — the migration is not silently leaving the old code orphaned.

If any box is unchecked, the migration is not done. Fix the gap or file a named follow-up before marking the PR ready.
