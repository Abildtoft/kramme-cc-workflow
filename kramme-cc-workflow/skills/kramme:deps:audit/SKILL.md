---
name: kramme:deps:audit
description: "(experimental) Audit project dependencies for outdated packages, security vulnerabilities, and staleness. Generates a prioritized upgrade plan with risk assessment."
argument-hint: "[--auto]"
disable-model-invocation: true
user-invocable: true
---

# Dependency Audit

Audit project dependencies for outdated packages, security vulnerabilities, and staleness. Groups related packages, assesses risk per update, and generates a prioritized upgrade plan.

Parse `$ARGUMENTS` for `--auto` before Step 1.

- If present, set `AUTO_MODE=true` and remove the flag from the remaining input.
- `--auto` means: audit all detected ecosystems, write `DEPENDENCY_AUDIT.md`, and stop in review-only mode without applying updates or creating SIW issues.

---

## Step 1: Detect Package Manager

Read the detection details from `references/package-manager-commands.md` and use it as the source of truth for lock-file mappings, manifest patterns, and monorepo markers.

If **multiple ecosystems** are detected:

- If `AUTO_MODE=true`, set `PACKAGE_MANAGER` to the list of all detected ecosystems and continue.
- Otherwise, ask the user which to audit. Present the detected ecosystems plus an "Audit all" option, then store the selection as `PACKAGE_MANAGER`.

---

## Step 2: Gather Dependency Data

For each ecosystem in `PACKAGE_MANAGER`, run the outdated and audit commands from `references/package-manager-commands.md`. For example, npm:

```bash
npm outdated --json
npm audit --json
```

**Error capture:** Do not suppress stderr. Capture both stdout and stderr so failures are visible. Distinguish three outcomes per command:

1. **Success** — exit 0, parse output.
2. **Tool missing** — command not found. Warn, skip that command, suggest the install command from the reference file.
3. **Command failed** — non-zero exit with output. Retry once. If the second attempt also fails, record the ecosystem as partial and surface the stderr verbatim in the Step 7 report so the user can diagnose network, registry, or auth issues.

Capture per package:

- From the **outdated** command: name, current version, latest version, update type (major/minor/patch), staleness (versions behind, last release date when available).
- From the **audit** command: vulnerabilities (severity, CVE ID, fixed-in version).

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

Read the scoring rubric from `references/risk-assessment-matrix.md`.

For each package group, assess:

1. **Breaking change likelihood:** Major = High, Minor = Low, Patch = Minimal.
2. **Codebase impact:** count files that import the package. Scope the search to source directories — exclude `node_modules/`, `dist/`, `build/`, `out/`, `vendor/`, `target/`, `.venv/`, and `bin/obj/` so file counts reflect first-party usage.
3. **Test coverage:** check if affected areas have existing tests.
4. **Assign risk level:** Low / Medium / High / Critical.

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

### Auto mode

If `AUTO_MODE=true`:

- Skip the prompt below.
- Default to **Review only — no changes**.
- Always write `DEPENDENCY_AUDIT.md` using the template at `assets/audit-report.md` (see "Writing the report" below).
- Continue to Step 7.

### Interactive mode

Otherwise, ask the user one combined question:

> How should I present the results, and what should I do next?

Present these options:

1. Terminal summary only, no changes
2. Write `DEPENDENCY_AUDIT.md`, no changes
3. Write `DEPENDENCY_AUDIT.md`, then apply Phase 2 (low-risk patches + minors) and run `/kramme:verify:run`
4. Write `DEPENDENCY_AUDIT.md`, then create a SIW workflow with one issue per Phase 4 campaign (via `/kramme:siw:init`)
5. Generate a visual HTML report via `/kramme:visual:diagram`, no changes

For option 4: `/kramme:siw:init` is user-invoked (the model cannot invoke it directly) — write the report, then present the exact `/kramme:siw:init` command for the user to run. If `/` invocation is unavailable on the platform, locate and Read that skill's `SKILL.md` from the installed skills directory and follow its steps inline.

### Writing the report

When the chosen action writes the report:

- Read the template from `assets/audit-report.md`.
- Populate one report file at `<project-root>/DEPENDENCY_AUDIT.md`.
- **Overwrite** any existing `DEPENDENCY_AUDIT.md` without prompting (the report is a snapshot, not append-only). Note the overwrite in the Step 7 summary.
- For multi-ecosystem audits, render one populated copy of every top-level template section per ecosystem under a `## Ecosystem: <name>` heading, in the order ecosystems are listed in `PACKAGE_MANAGER`. Keep the top-of-file `Summary` section as a single combined view across ecosystems.

### Applying Phase 2 (option 3)

Before running update commands:

1. List the exact packages and target versions to be updated in the chat.
2. Verify the working tree is clean (`git status --porcelain`). If it is dirty, stop and ask the user to commit or stash first.
3. Run the ecosystem update commands.
4. Run `/kramme:verify:run`. If verification fails, **stop**, report which packages were updated, and leave the lockfile changes in place for the user to inspect or revert.

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
Report: DEPENDENCY_AUDIT.md{if overwritten} (overwrote previous report){/if}
{/if}

{if partial_results}
Partial results — the following commands failed and were excluded:
  - {ecosystem}: {command} → {stderr first line}
{/if}
```

**STOP** — Do not continue beyond this point.

---

## Error Handling

| Scenario | Action |
| --- | --- |
| No package manager detected | Abort: `No supported package manager found in this directory.` |
| Audit tool not installed | Warn, skip vulnerability check, suggest install command from the reference file |
| Command failed (non-zero exit) | Retry once; if still failing, mark ecosystem as partial and surface stderr in Step 7 |
| No outdated packages | Report clean: `All dependencies are up to date.` |
| Monorepo with many workspaces | Audit root-level first, suggest per-workspace audit |
| Working tree dirty when applying Phase 2 | Stop and ask user to commit or stash before proceeding |
| `/kramme:verify:run` fails after applying Phase 2 | Stop, report which packages were updated, leave lockfile changes for the user |
