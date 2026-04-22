# Migration Plan: {framework} {current} → {target}

**Generated:** {date}
**Project:** {project_name}
**Classification:** {Advisory|Compulsory}
**Pattern:** {Strangler|Adapter|Feature Flag}
**Rollback criterion:** {signal that forces rollback}
**Rollback path:** {exact revert lever}
**Verification baseline:** {Automated pass/fail counts | Manual/targeted checklist}

## Impact Summary

| Metric | Count |
|---|---|
| Breaking changes applicable | {N} of {total} |
| Files affected | {N} |
| Automated (codemod) | {N} |
| Semi-automated | {N} |
| Manual | {N} |
| Estimated total effort | {Quick/Moderate/Significant} |

## Phase 0: Pre-Migration

**Effort:** Quick

- [ ] Create migration branch: `git checkout -b migrate/{framework}-{target}`
- [ ] Run dependency audit (`/kramme:deps:audit` if available)
- [ ] Capture verification baseline: run the primary automated suite and record pass/fail counts, or if no reliable automated suite exists, write the manual/targeted checklist to rerun in Phase 4
- [ ] Document starting state

**Verification:** Branch exists, baseline captured.
**Rollback on failure:** {restore previous branch / stop before codemods land}

## Phase 1: Replacement Path Setup

**Effort:** {Quick/Moderate}

- [ ] Ship the new implementation and the pattern scaffold it requires:
  - Adapter: add the compatibility shim callers land on first
  - Strangler: add the facade/router defaulting to the old path
  - Feature Flag: wire the flag default OFF and define rollout cohorts plus metrics
- [ ] Install codemod tools: {install commands}
- [ ] Run codemods if applicable:
  - {codemod 1}: `{command}`
  - {codemod 2}: `{command}`
- [ ] Review scaffold and codemod output for correctness

**Verification:** New path compiles, the scaffold is in place, and the rollback lever still routes to the old behavior.
**Rollback on failure:** {revert the scaffold/codemod commit or restore the pre-migration tree}

## Phase 2: Breaking Changes and Configuration

**Effort:** {Moderate/Significant}

{For each breaking change group:}
### {Group Name}
- **Files:** {list}
- **Change:** {description}
- **Before:** `{old pattern}`
- **After:** `{new pattern}`

Additional updates:
- [ ] Update framework config: {files}
- [ ] Update build tool config: {files}
- [ ] Update CI/CD pipeline: {files}
- [ ] Update runtime constraints: {.nvmrc, engines, etc.}

**Verification:** No remaining references to removed/renamed APIs and configuration is valid.
**Rollback on failure:** {revert the breaking-change patch set or restore the prior adapter/façade path}

## Phase 3: Fix Compilation and Type Errors

**Effort:** {Moderate}

- [ ] Run build, collect errors
- [ ] Fix type errors systematically
- [ ] Address new strict mode requirements

**Verification:** Clean build with no errors.
**Rollback on failure:** {revert the type-fix patch set and return to the last compiling baseline}

## Phase 4: Recover Verification Baseline

**Effort:** {Moderate/Significant}

- [ ] Run the automated suite, or rerun the manual/targeted checklist captured in Phase 0
- [ ] Fix migration-caused verification failures
- [ ] Update test utilities and helpers if changed

**Verification:** Automated pass rate matches or exceeds baseline ({baseline_count} tests), or the manual/targeted checklist passes with outcomes recorded.
**Rollback on failure:** {re-enable the prior path / revert failing verification-fix patches}

## Phase 5: Incremental Caller Migration / Rollout

**Effort:** {Moderate/Significant}

- [ ] Move callers/traffic in batches using the chosen pattern:
  - Adapter: migrate callers until the compatibility path has zero consumers
  - Strangler: ramp slices/cohorts behind the facade
  - Feature Flag: roll out the flag in explicit stages (for example 1% -> 5% -> 25% -> 50% -> 100%)
- [ ] Record the steady-state signal for each batch: {zero callers | traffic percentage | equivalent}
- [ ] Check the rollback criterion after every batch and stop immediately if it triggers

**Verification:** Target steady state reached, rollback criterion stayed clear, and rollout/migration evidence is recorded.
**Rollback on failure:** {disable the flag / route the facade back to old / pin callers to the adapter-only path}

## Phase 6: Rollback Window and Final Cleanup

**Effort:** Quick

- [ ] Hold the new path at steady state for the rollback window: {window description}
- [ ] Remove compatibility shims, facades, feature flags, and polyfills only after that window clears
- [ ] Remove migration TODO comments
- [ ] Run linter with new rule set
- [ ] Verify key user flows manually

**Verification:** `/kramme:verify:run` passes; the rollback window elapsed without incident; clean lint, typecheck, build, all available automated tests, and no migration artifacts remain.
**Rollback on failure:** {restore the last fully verified pre-cleanup state or re-enable the previous path}

## Final Verification

- [ ] Full build: `{build command}`
- [ ] Automated tests or manual/targeted verification rerun: `{test command or checklist reference}`
- [ ] Linting: `{lint command}`
- [ ] Manual smoke test of key flows
