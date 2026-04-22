# Migration Plan: {framework} {current} → {target}

**Generated:** {date}
**Project:** {project_name}

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
- [ ] Capture test baseline: run full suite, record pass/fail counts
- [ ] Document starting state

**Verification:** Branch exists, baseline captured.

## Phase 1: Automated Migration — Codemods

**Effort:** {Quick/Moderate}

- [ ] Install codemod tools: {install commands}
- [ ] Run codemods:
  - {codemod 1}: `{command}`
  - {codemod 2}: `{command}`
- [ ] Review codemod output for correctness

**Verification:** Build compiles (type errors OK at this stage).

## Phase 2: Breaking Changes — Manual Fixes

**Effort:** {Moderate/Significant}

{For each breaking change group:}
### {Group Name}
- **Files:** {list}
- **Change:** {description}
- **Before:** `{old pattern}`
- **After:** `{new pattern}`

**Verification:** No remaining references to removed/renamed APIs.

## Phase 3: Configuration Updates

**Effort:** Quick

- [ ] Update framework config: {files}
- [ ] Update build tool config: {files}
- [ ] Update CI/CD pipeline: {files}
- [ ] Update runtime constraints: {.nvmrc, engines, etc.}

**Verification:** Configuration is valid.

## Phase 4: Fix Compilation and Type Errors

**Effort:** {Moderate}

- [ ] Run build, collect errors
- [ ] Fix type errors systematically
- [ ] Address new strict mode requirements

**Verification:** Clean build with no errors.

## Phase 5: Fix Tests

**Effort:** {Moderate/Significant}

- [ ] Run full test suite
- [ ] Fix migration-caused test failures
- [ ] Update test utilities and helpers if changed

**Verification:** Pass rate matches or exceeds baseline ({baseline_count} tests).

## Phase 6: Manual Verification and Cleanup

**Effort:** Quick

- [ ] Remove compatibility shims and polyfills
- [ ] Remove migration TODO comments
- [ ] Run linter with new rule set
- [ ] Verify key user flows manually

**Verification:** Clean lint, no migration artifacts remain.

## Final Verification

- [ ] Full build: `{build command}`
- [ ] Full test suite: `{test command}`
- [ ] Linting: `{lint command}`
- [ ] Manual smoke test of key flows
