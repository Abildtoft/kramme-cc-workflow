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
- `--auto` means: execute the full migration plan without pausing for routine review, skip phase-by-phase checkpoints, and abort on unresolved verification failures after the built-in retry budget is exhausted. It does **not** override any `ASK FIRST` gate.
- Initialize `ASK_FIRST_ACTIVE=false` before Step 1. Set it to `true` whenever an `ASK FIRST` condition fires, and only clear it after the user explicitly approves continuing.

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

Use before any of: running a Compulsory migration on main, removing a public API, changing the deployment target (Node major, Python minor, CDK version), using `--auto` on a codebase with no reliable automated verification baseline. Surface the plan and wait for confirmation — these are the changes that cascade when wrong.

When an `ASK FIRST` condition is triggered, surface the plan and **STOP**. `AUTO_MODE` skips routine checkpoints only after the gate has been cleared by the user.

Track this with the explicit `ASK_FIRST_ACTIVE` flag above. Set it to `true` the moment any gate below fires, and only let `AUTO_MODE` skip checkpoints when that flag has been cleared by the user.

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

   If the migration is Compulsory and the current branch is shared/main, emit `ASK FIRST: running a Compulsory migration` and STOP until the user confirms or the work moves to a non-shared branch.

   Report: `Classification: {Advisory|Compulsory} — {reason}`

6. **Check parse-time `ASK FIRST` boundaries.**

   If the requested target changes the deployment target itself — for example a Node major, Python minor, CDK version, or other runtime/platform baseline the app deploys on — emit:

   ```
   ASK FIRST: changing deployment target
   Plan: migrate {current} -> {target}, update the deployment/runtime baseline, and verify downstream environments before merge.
   ```

   Set `ASK_FIRST_ACTIVE=true` and STOP until the user confirms. Do not let `AUTO_MODE` bypass this gate.

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

- **Strangler** — incrementally replace behind a façade that routes to old or new depending on the path/feature/tenant. Use when the old code is load-bearing, callers are many, and the migration spans weeks or months. Phasing: write the façade in Phase 1; use Phases 2–4 to get the repo back to a clean baseline; migrate callers/cohorts in Phase 5; delete the old path in Phase 6.
- **Adapter** — add a thin compatibility shim that exposes the new API's shape over the old implementation (or vice versa) during transition. Use when the API shape changed but callers are numerous and mechanical to port, or when a codemod needs an intermediate landing surface. Phasing: land the adapter in Phase 1; use Phases 2–4 to get callers and tests onto the new baseline; drain callers off the adapter in Phase 5; remove the adapter in Phase 6.
- **Feature Flag Migration** — gate the new path behind a flag and flip users in batches. Use when the migration has runtime risk and you need per-cohort rollback. Phasing: land the new path plus flag scaffolding in Phase 1; use Phases 2–4 to reach a clean baseline; roll out incrementally in Phase 5; remove the flag in Phase 6.

Default pick if the situation doesn't clearly fit one: **Adapter** for library migrations (Angular 18→19, React 18→19), **Strangler** for architecture shifts (monolith→service, REST→GraphQL), **Feature Flag** for runtime-risky (new database client, new auth provider).

### Phased plan structure

Create a phased plan:

- Record these header fields in the plan file before Phase 0:
  - `Classification: {Advisory|Compulsory}`
  - `Pattern: {Strangler|Adapter|Feature Flag}`
  - `Rollback criterion: <the signal that forces rollback>`
  - `Rollback path: <the exact mechanism used to revert safely>`
- For every phase, add `Rollback on failure: <exact action>` beneath the verification gate. Name the concrete lever: revert the codemod commit, pin the previous runtime, force the façade back to old, disable the feature flag, or restore the adapter-only path. "Rollback if broken" is not specific enough.
- Pattern-specific obligations are mandatory, not decorative:
  - **Adapter**: Phase 1 lands the adapter, Phase 5 drains callers off it in batches, and Phase 6 removes it only after zero callers remain.
  - **Strangler**: Phase 1 lands the façade defaulting to the old path, Phase 5 migrates slices/cohorts to the new path, and Phase 6 removes the old path only after the rollback window clears.
  - **Feature Flag**: Phase 1 lands the new path plus flag scaffolding with a default-off state, Phase 5 performs the staged rollout with telemetry checkpoints, and Phase 6 removes the flag and old path only after the steady-state window clears.

**Phase 0: Pre-Migration** (Quick)
- Create migration branch from current HEAD
- Run `/kramme:deps:audit` if available
- Capture a verification baseline: run the primary automated suite and record pass/fail counts, or if no reliable automated suite exists, record the manual/targeted verification checklist to rerun in Phase 4
- Verification: branch exists, baseline captured

**Phase 1: Replacement Path Setup** (Quick to Moderate)
- Ship the new implementation and the pattern scaffold it requires (adapter, façade, or feature-flag plumbing)
- List and run applicable codemods
- Review codemod output for correctness
- Verification: the new path compiles, the scaffold is in place, and the rollback lever still routes to the old behavior

**Phase 2: Breaking Changes and Configuration** (Moderate to Significant)
- Group by area (imports, APIs, types, config)
- Apply fixes in dependency order (shared code first)
- Update framework and build tool config files
- Update CI/CD pipeline if needed
- Update runtime version constraints
- Verification: no references to removed/renamed APIs remain and configuration is valid

**Phase 3: Fix Compilation and Type Errors** (Moderate)
- Run build, collect errors, fix systematically
- Verification: clean build

**Phase 4: Recover Verification Baseline** (Moderate to Significant)
- Run the automated suite, or rerun the manual/targeted verification checklist captured in Phase 0
- Fix migration-caused failures and distinguish them from pre-existing failures
- Verification: automated pass rate matches or exceeds baseline, or the manual/targeted checklist passes with outcomes recorded

**Phase 5: Incremental Caller Migration / Rollout** (Moderate to Significant)
- Adapter: migrate callers in batches until zero callers depend on the compatibility path
- Strangler: ramp slices/cohorts to the new path with verification at each step
- Feature Flag: roll out the flag in explicit batches and check the rollback criterion at each checkpoint
- Record the steady-state signal reached in this phase (zero old callers, 100% new-path traffic, or equivalent)
- Verification: the target steady state is reached, the rollback criterion did not trigger, and the evidence is recorded in the plan

**Phase 6: Rollback Window and Final Cleanup** (Quick)
- Hold the new path at steady state for the rollback window appropriate to the pattern and surface
- Remove compatibility shims, façades, feature flags, and polyfills only after that window clears
- Remove migration TODOs
- Run linter with new rule set
- Verification: `/kramme:verify:run` passes; the rollback window elapsed without incident; clean lint, typecheck, build, all available automated tests, and no migration artifacts

Write plan to `migration-plan-{framework}-{target}.md` in project root.

---

## Step 5: User Review

Before deciding whether `AUTO_MODE` can skip this prompt, confirm that Phase 0 can capture a reliable automated verification baseline:

- Detect the primary test command from project config, lockfiles, task runners, and existing test files.
- If no automated suite exists, or the repo cannot produce pass/fail counts without ad hoc manual work, emit:

```
ASK FIRST: auto migration with no test baseline
Plan: proceed with an auto migration despite the lack of a reliable automated Phase 0 baseline, and rely on a manual/targeted verification checklist instead.
```

Set `ASK_FIRST_ACTIVE=true` and STOP until the user confirms. Do not continue to Step 6 in `AUTO_MODE` while this gate is open.

After the user confirms, Phase 0 must record that manual/targeted checklist in the plan file, and Phase 4 must rerun it and record the observed outcomes instead of comparing pass/fail counts.

If `AUTO_MODE=true` and `ASK_FIRST_ACTIVE=false`, skip this prompt and choose **Execute full plan — all phases with verification gates**.

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

3. **Run the verification gate for this phase** — use the phase-specific exit criterion from Step 4, not the final full-suite gate by default.
   - Phases 0-3: run only the targeted checks needed for that phase's exit criterion.
   - Phase 4: run the relevant automated suites and compare the pass rate against the baseline, or rerun the manual/targeted checklist captured in Phase 0 and record the outcomes.
   - Phase 5: verify the pattern-specific steady-state signal plus the rollback criterion for the current batch or cohort.
   - Phase 6: run `/kramme:verify:run` as the final comprehensive gate after the rollback window and cleanup work.

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
  Phase 1: Replacement setup      {DONE/SKIPPED/FAILED} ({N} files)
  Phase 2: Breaking/config        {DONE/SKIPPED/FAILED} ({N} files)
  Phase 3: Build/type fixes       {DONE/SKIPPED/FAILED}
  Phase 4: Baseline recovery      {DONE/SKIPPED/FAILED} ({summary})
  Phase 5: Rollout/migration      {DONE/SKIPPED/FAILED} ({summary})
  Phase 6: Window + cleanup       {DONE/SKIPPED/FAILED}

Verification:
  Build:                 {PASS/FAIL}
  Lint:                  {PASS/FAIL}
  Automated tests:       {PASS/FAIL/N/A} ({passed}/{total} or "no automated suite")
  Manual verification:   {PASS/FAIL/N/A}

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
| `ASK FIRST` gate triggered | Surface the plan and stop; do not continue until the user confirms |

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
| "Phase 3 is just type errors, skip verification." | Type-error fixes routinely introduce behavior changes (coercions, narrowing loss). Run the gate. |
| "`--auto` is faster." | `--auto` without a reliable automated baseline is `ASK FIRST` territory — after approval you still need a named manual/targeted checklist, not vibes. |

## Red Flags

If you see any of these in your own draft, stop and re-author:

- A phase in the plan has no verification gate (every phase must have one, even Phase 6).
- `--auto` used with neither an automated pass/fail baseline nor an approved manual/targeted checklist captured at Phase 0.
- Codemod output not reviewed before running the next phase's work on top of it.
- `NOTICED BUT NOT TOUCHING` observations silently fixed in the migration diff instead of logged.
- Migration plan picks Strangler, Adapter, or Feature Flag but never includes an explicit caller-migration / rollout phase with a recorded steady-state signal.
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
- [ ] Phase 4 results meet the Phase 0 baseline: automated pass rate matches/exceeds counts, or the approved manual/targeted checklist was rerun and recorded.
- [ ] Phase 5 records the steady-state signal that proves callers/traffic actually moved, and the rollback criterion remained clear throughout.
- [ ] Compilation and lint clean at Phase 6; the rollback window cleared before cleanup; no migration-artifact comments, shims, façades, flags, or polyfills remain unless the plan explicitly kept them.
- [ ] If the old path still has references, a `kramme:code:deprecate` workflow is scheduled — the migration is not silently leaving the old code orphaned.

If any box is unchecked, the migration is not done. Fix the gap or file a named follow-up before marking the PR ready.
