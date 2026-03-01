---
name: kramme:deps:audit
description: "(experimental) Audit project dependencies for outdated packages, security vulnerabilities, and staleness. Generates a prioritized upgrade plan with risk assessment."
disable-model-invocation: true
user-invocable: true
---

# Dependency Audit

Audit project dependencies for outdated packages, security vulnerabilities, and staleness. Groups related packages, assesses risk per update, and generates a prioritized upgrade plan.

## Process Overview

```
/kramme:deps:audit
    |
    v
[Step 1: Detect Package Manager] -> npm/yarn/pnpm/pip/cargo/go/dotnet
    |
    v
[Step 2: Gather Dependency Data] -> outdated + vulnerabilities
    |
    v
[Step 3: Group and Classify] -> By org/scope, update type, severity
    |
    v
[Step 4: Risk Assessment] -> Breaking likelihood, codebase impact
    |
    v
[Step 5: Generate Upgrade Plan] -> Phased by priority
    |
    v
[Step 6: User Review] -> Output format + next action
    |
    v
[Step 7: Report] -> Summary with counts and phases
```

---

## Step 1: Detect Package Manager

Read the detection details from `resources/references/package-manager-commands.md`.

1. Check for lock files and manifests:
   - `package-lock.json` → npm
   - `yarn.lock` → yarn
   - `pnpm-lock.yaml` → pnpm
   - `requirements.txt` / `Pipfile` / `pyproject.toml` → pip/pipenv/poetry
   - `Cargo.lock` → cargo
   - `go.sum` → go
   - `*.csproj` / `*.sln` → dotnet

2. For monorepos, check: `nx.json`, `lerna.json`, `turbo.json`, `pnpm-workspace.yaml`.

3. If **multiple ecosystems** detected:

```
AskUserQuestion
header: Multiple Package Managers
question: I found multiple ecosystems. Which should I audit?
options:
  - "{ecosystem 1} — {manifest file}"
  - "{ecosystem 2} — {manifest file}"
  - "Audit all ecosystems"
```

Store as `PACKAGE_MANAGER`.

---

## Step 2: Gather Dependency Data

Run ecosystem-specific commands (from the reference file):

**npm/yarn/pnpm:**
```bash
npm outdated --json 2>/dev/null
npm audit --json 2>/dev/null
```

**pip:**
```bash
pip list --outdated --format=json 2>/dev/null
pip-audit --json 2>/dev/null  # if installed
```

**cargo:**
```bash
cargo outdated 2>/dev/null    # if installed
cargo audit 2>/dev/null       # if installed
```

**go:**
```bash
go list -m -u all 2>/dev/null
govulncheck ./... 2>/dev/null # if installed
```

**dotnet:**
```bash
dotnet list package --outdated 2>/dev/null
dotnet list package --vulnerable 2>/dev/null
```

Capture per package: name, current version, latest version, update type (major/minor/patch), vulnerabilities (severity, CVE ID).

If an audit tool is not installed, warn and skip the vulnerability check. Suggest the install command.

---

## Step 3: Group and Classify

1. **Group related packages** by org or scope:
   - `@angular/core`, `@angular/cli`, `@angular/common` → Angular group
   - `eslint`, `eslint-plugin-*`, `@typescript-eslint/*` → ESLint group
   - `@ngrx/store`, `@ngrx/effects` → NgRx group

2. **Classify each update:**
   - **Security** — has a known CVE (Critical/High/Medium/Low)
   - **Major** — major version bump (likely breaking changes)
   - **Minor** — minor version bump (new features, should be safe)
   - **Patch** — patch version bump (bug fixes)

3. **Calculate staleness:** how many versions behind, time since current version.

---

## Step 4: Risk Assessment

Read the scoring rubric from `resources/references/risk-assessment-matrix.md`.

For each package group, assess:

1. **Breaking change likelihood:**
   - Major = High, Minor = Low, Patch = Minimal

2. **Codebase impact:** grep for imports of the package to estimate how many files use it.

3. **Test coverage:** check if affected areas have existing tests.

4. **Assign risk level:** Low / Medium / High / Critical

---

## Step 5: Generate Upgrade Plan

Priority ordering:

1. **Phase 1 — Immediate:** Security vulnerabilities (Critical and High severity)
2. **Phase 2 — Quick Wins:** Patch updates + low-risk minor updates
3. **Phase 3 — Planned:** Remaining minor updates (grouped by related packages)
4. **Phase 4 — Major Upgrades:** Major version bumps (one campaign per group)

Each entry includes: packages, current → target versions, risk level, recommended testing.

---

## Step 6: User Review

```
AskUserQuestion
header: Output Format
question: How should I present the audit results?
options:
  - Terminal summary only
  - Write DEPENDENCY_AUDIT.md report
  - Generate visual HTML report (via /kramme:visual:diagram)
```

```
AskUserQuestion
header: Next Action
question: What should I do with the results?
options:
  - Review only — no changes
  - Apply Phase 2 patches — low-risk updates
  - Create SIW workflow — for major upgrade campaigns
```

If **Write report**: read the template from `resources/templates/audit-report.md`, populate, and write `DEPENDENCY_AUDIT.md` in the project root.

If **Apply patches**: run the appropriate update commands for Phase 2 packages, then run `/kramme:verify:run`.

If **Create SIW**: reference `/kramme:siw:init` with one issue per major upgrade campaign.

---

## Step 7: Report

```
Dependency Audit Complete

Package Manager: {PACKAGE_MANAGER}
Total Dependencies: {N} ({direct} direct, {transitive} transitive)

Security Vulnerabilities:
  Critical: {N}
  High:     {N}
  Medium:   {N}
  Low:      {N}

Outdated Packages:
  Major: {N} packages ({groups} groups)
  Minor: {N} packages
  Patch: {N} packages

Upgrade Plan:
  Phase 1 (Immediate):  {N} security fixes
  Phase 2 (Quick Wins): {N} patch + minor updates
  Phase 3 (Planned):    {N} grouped minor updates
  Phase 4 (Major):      {N} major upgrades ({campaigns} campaigns)

{if report_written}
Report: DEPENDENCY_AUDIT.md
{/if}
```

**STOP** — Do not continue beyond this point.

---

## Error Handling

| Scenario | Action |
|---|---|
| No package manager detected | Abort: `No supported package manager found in this directory.` |
| Audit tool not installed | Warn, skip vulnerability check, suggest install command |
| No outdated packages | Report clean: `All dependencies are up to date.` |
| Network error during audit | Retry once, then report partial results |
| Monorepo with many workspaces | Audit root-level first, suggest per-workspace audit |
