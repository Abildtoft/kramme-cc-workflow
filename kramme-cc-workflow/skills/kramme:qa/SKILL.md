---
name: kramme:qa
description: Structured QA testing with evidence capture. Runs smoke checks, diff-aware validation, or targeted route testing against a live app. Produces QA_REPORT.md with screenshots, repro steps, severity, and recommended fixes, or replies inline with --inline. Uses browser MCP when available and falls back to code-only analysis otherwise. Not for logging multiple bugs from a manual pass (use kramme:qa:intake) or tracing one bug's root cause (use kramme:debug:investigate).
argument-hint: "<url|auto> [quick|diff-aware|targeted <route>] [--base <branch>] [--regression] [--inline] [--legacy-console]"
disable-model-invocation: false
user-invocable: true
---

# Structured QA Testing with Evidence Capture

Run smoke checks, diff-aware validation, or targeted route testing against a live application. When browser MCP is available, capture screenshots, console output, and network activity; otherwise fall back to code-only analysis. Produce a QA report with findings, severity ratings, and recommended fixes.

**Arguments:** "$ARGUMENTS"

## Workflow

### Step 1: Parse Arguments

Extract from `$ARGUMENTS`:

1. **URL** (required) — the target URL to test (e.g., `http://localhost:3000`, `https://staging.example.com`) or `auto` to discover a running local dev server
2. **Mode** (optional, default: `quick`):
   - `quick` — landing page + 2-3 key routes
   - `diff-aware` — test routes affected by changed UI files
   - `targeted <route>` — test a specific route/page
3. **Flags**:
   - `--base <branch>` — explicit base branch for diff-aware mode
   - `--regression` — compare results against previous QA baseline (see Step 8)
   - `--inline` — reply with the QA report inline instead of writing `QA_REPORT.md` (still writes `QA_BASELINE.json`, which regression depends on; see Step 10)
   - `--legacy-console` — relax the clean-console standard for legacy apps with known noisy consoles (see Step 4)

Store parsed values:

- `TARGET_URL` — the base URL to test
- `TEST_MODE` — `quick`, `diff-aware`, or `targeted`
- `TARGET_ROUTE` — specific route for targeted mode (e.g., `/settings/profile`)
- `BASE_OVERRIDE` — explicit base branch if provided
- `REGRESSION_MODE` — boolean (default: false)
- `INLINE_MODE` — boolean (default: false)
- `LEGACY_CONSOLE_MODE` — boolean (default: false)

### Step 2: Validate Prerequisites

**URL is required.** If not provided, stop with:

```
Error: URL is required.

Usage: /kramme:qa <url|auto> [quick|diff-aware|targeted <route>] [--base <branch>]

Examples:
  /kramme:qa http://localhost:3000
  /kramme:qa auto
  /kramme:qa http://localhost:4200 diff-aware --base develop
  /kramme:qa http://localhost:3000 targeted /settings/profile
```

**If URL is `auto`:** Resolve it with the shared dev-server detector:

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/dev-server/detect-url.sh auto
```

- `http://...` or `https://...` — set `TARGET_URL` to that value and continue.
- `__MULTIPLE_URLS__` — list the candidate URLs and ask the user to pick one; if the runtime cannot ask, hard stop with the candidate list.
- `__NO_RUNNING_SERVER__` — hard stop with: `Error: No running dev server detected. Start your dev server first, then re-run the command.`

**Validate explicit or resolved URL format.** If `TARGET_URL` does not begin with `http://` or `https://`, stop with: `Error: TARGET_URL must be an http:// or https:// URL, or auto. Got: $TARGET_URL`.

**Verify app is reachable** with a curl health check:

```bash
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$TARGET_URL")
```

- `2xx` or `3xx` — proceed
- Connection refused — stop with:

  ```
  Error: Connection refused at $TARGET_URL. Is the server running?

  Start your dev server first, then re-run the command.
  ```

- Timeout — stop with:
  ```
  Error: Request to $TARGET_URL timed out after 5 seconds. Is the server running?
  ```
- `5xx` — stop with:
  ```
  Error: Server error ($HTTP_STATUS) at $TARGET_URL. Fix the server error before QA testing.
  ```
- `4xx` — warn but proceed (page may require interaction or authentication)

### Step 3: Determine Test Scope

**quick mode:**

Auto-detect routes from the project structure. Look for route definitions in:

- `pages/`, `app/` directories (Next.js, Nuxt, Remix file-based routing)
- `routes/`, `views/`, `screens/` directories
- Framework router config files (`router.ts`, `routes.ts`, `app-routing.module.ts`)
- `package.json` for framework hints (next, nuxt, remix, angular, vue-router, react-router)

Select the landing page (`/`) plus 2-3 key routes that represent core functionality. Prefer routes that are:

- Top-level navigation items
- User-facing pages (not API routes or admin pages)
- Representative of different page types (list, detail, form)

If route detection fails, fall back to testing only the landing page (`/`).

**diff-aware mode:**

Read `references/diff-scope.md` to resolve `BASE_BRANCH` and identify changed files, then continue with UI-relevant filtering below.

Filter for UI-relevant files:

- **Components**: `*.tsx`, `*.jsx`, `*.vue`, `*.svelte`, `*.component.ts`, `*.component.html`
- **Templates**: `*.html`, `*.hbs`, `*.ejs`, `*.pug`
- **Styles**: `*.css`, `*.scss`, `*.sass`, `*.less`, `*.styled.ts`, `*.module.css`
- **Views/Pages**: Files in `pages/`, `views/`, `screens/`, `routes/`, `app/` directories
- **Config**: Tailwind config, theme files, design token files
- **Assets**: SVG files, icon sets

If no UI-relevant files found:

```
No UI-relevant changes detected in this PR or local working tree.

Changed files: {list file types}

No routes to test. Use `quick` mode to test the app without a diff scope.
```

**Action:** Stop.

Map changed UI files to routes/pages:

- File-based routing: derive route from file path (e.g., `pages/settings/profile.tsx` maps to `/settings/profile`)
- Config-based routing: search router config for imports/references to the changed files
- If mapping is ambiguous, include the likely route with a note

Create a branch-diff-to-journey matrix before building the test checklist. Read `references/diff-aware-journey-matrix.md` and populate one row per route/screen and meaningful user journey using the columns defined there.

Mark speculative route mappings as `UNVERIFIED` rather than silently treating them as known routes. If a journey would mutate shared data, send external notifications, change billing, delete records, or otherwise be destructive, ask the user before executing it; if the runtime cannot ask, mark the row `blocked`.

**targeted mode:**

Use the user-specified route directly. The test scope is `TARGET_URL + TARGET_ROUTE`.

### Step 3b: Detect Framework

First use the shared project-type detector:

```bash
DETECTED_PROJECT_TYPE=$(${CLAUDE_PLUGIN_ROOT}/scripts/dev-server/detect-project-type.sh 2> /dev/null)
```

If the output is a single type (for example `next`, `vite`, or `rails`) or a single monorepo hit (`next@apps/web`), store the type as `DETECTED_FRAMEWORK`.

If the shared detector returns `unknown` or `multiple`, check `package.json` (if it exists) for framework dependencies to load framework-specific QA hints:

```bash
cat package.json 2> /dev/null | grep -oE '"(next|nuxt|@angular/core|react|vue|svelte|@sveltejs/kit|rails)"' | head -1
```

Also check project structure:

- `next.config.*` → Next.js
- `angular.json` → Angular
- `nuxt.config.*` → Nuxt
- `svelte.config.*` → SvelteKit
- `config/routes.rb` or `Gemfile` with `rails` → Rails
- `wp-config.php` or `wp-content/` → WordPress

If a framework is detected, store as `DETECTED_FRAMEWORK` and read `references/framework-hints.md` for framework-specific checks to add to the test plan.

### Step 4: Build Test Plan

For each identified page/route, read the QA rubric from `references/qa-rubric.md` and use its route checklist, clean-console standard, accessibility ladder, and health categories.

For `diff-aware` mode, build the checklist from the journey matrix rows created in Step 3. Prioritize matrix rows whose changed files are closest to user-facing behavior, then rows covering edge states. Keep uncertain rows in the plan with `UNVERIFIED` assumptions so the final report shows what was and was not proven.

**If `DETECTED_FRAMEWORK` is set:** Add framework-specific checks from `references/framework-hints.md` to the test plan. For example, if Next.js is detected, add hydration error checks and `_next/data` monitoring.

### Step 5: Execute Tests via Browse

Before performing interaction checks in any mode, identify actions that could mutate shared data, submit forms, send external notifications, change billing, delete records, or otherwise be destructive/non-idempotent. Ask the user before executing those actions; if the runtime cannot ask, mark the interaction `blocked` and continue with read-only evidence.

For each route in the test plan, invoke `/kramme:browse` via the Skill tool:

```
skill: "kramme:browse", args: "<TARGET_URL><route> --screenshot --console --network"
```

This captures:

- Visual screenshot of the page
- Console messages (errors, warnings, info)
- Network request summary (failed requests, slow responses)

After navigation, perform basic interaction checks:

- Click primary action buttons (if identifiable from page structure)
- Verify navigation links work
- Check form submissions if forms are present

**If browse fails (no browser MCP available):**

Degrade to code-only analysis using `references/code-only-fallback.md`. Preserve its source-selection rules and warning text.

### Step 6: Capture Evidence

For each tested page/route, collect:

- **Screenshot** — visual state from browse (describes what the screenshot shows)
- **Console errors/warnings** — grouped by severity (errors first, then warnings)
- **Failed network requests** — classify per the triage ladder below
- **Interaction results** — outcome of any interactions performed

**Network triage ladder** (apply to every failed or anomalous request):

Read `references/network-triage.md` and classify every failed or anomalous request using its ladder.

Store evidence per route for inclusion in the QA report.

### Step 7: Assess Findings

Read `references/finding-severity.md` and rate each issue found using its severity definitions and assessment questions.

### Step 7b: Compute Health Score

Read `references/health-score-rubric.md` and compute a weighted health score (0-100).

1. Assign each finding to one category: Console, Network, Visual, Functional, Data, Interaction, Content, or Accessibility
2. Apply the rubric's per-severity deductions and category weights
3. Compute the weighted average using the rubric formula

**Clean-console rule:** if any console error is present and `LEGACY_CONSOLE_MODE` is false, the Console category receives an automatic Blocker deduction in addition to per-finding deductions. Warnings follow the rule set in Step 4 (Minor/Major by default, Info under `--legacy-console`).

Store as `HEALTH_SCORE` and `HEALTH_LABEL` (Excellent/Good/Fair/Poor/Critical).

### Step 8: Regression Comparison (conditional)

**Skip if** `REGRESSION_MODE` is false.

This runs **before** the report is written (Step 9) so the comparison can be included in it.

Check if `QA_BASELINE.json` exists from a previous run:

- If not found: warn `"No previous baseline found. Skipping regression comparison. This run's results will be saved as the new baseline."` and continue to Step 9.
- If found: load and compare:

**Comparison logic:**

1. **Score delta:** `current_score - baseline_score` (positive = improvement, negative = regression)
2. **Fixed issues:** findings in the baseline that are NOT in the current run (matched by title + route)
3. **New issues:** findings in the current run that are NOT in the baseline
4. **Persistent issues:** findings present in both runs

Prepare a `## Regression` section for the QA report using `assets/regression-section-template.md`. Step 9 renders that section when a regression comparison ran.

### Step 9: Write QA Report or Reply Inline

Use the template from `assets/qa-report-template.md`.

Populate all sections:

- Fill in mode, URL, date, browser MCP type
- List all tested routes with descriptions
- Include the journey matrix for `diff-aware` runs, with route/screen, journey, state, expected behavior, evidence, result, and follow-up
- Document each finding with severity, repro steps, expected vs actual, and recommended fix
- Include the `## Regression` section prepared in Step 8 when a regression comparison ran
- Calculate summary counts per severity level
- Provide overall recommendation (ready / not ready / ready with caveats)

**Numbering convention:** Findings are numbered `QA-001`, `QA-002`, etc.

QA does not auto-fix or auto-commit findings in the default flow. Record recommended fixes and follow-up issue references, then leave implementation to the user or a separate fix workflow.

If `INLINE_MODE=true`:

- Reply with the full populated QA report inline
- Do **not** create or update `QA_REPORT.md`

Otherwise:

- Write `QA_REPORT.md` at the project root
- Treat it as a working artifact that should **not** be committed and can be cleaned up by `/kramme:workflow-artifacts:cleanup`

### Step 10: Save Baseline

After regression comparison (or if skipped), save a machine-readable baseline for future runs. This runs regardless of `INLINE_MODE` — `--inline` suppresses only `QA_REPORT.md`, not the baseline, so regression comparisons keep working across runs.

Write `QA_BASELINE.json` at the project root using the shape in `assets/qa-baseline-schema.md`.

This file is a working artifact. It will be cleaned up by `/kramme:workflow-artifacts:cleanup`.

### Step 11: Output Summary

After writing the report, display the inline summary using `assets/qa-summary-template.md`.

## Conventions — output markers and verification

Before producing the QA report, read `references/addy-conventions.md` and apply:

- The 7-marker output vocabulary (`STACK DETECTED`, `UNVERIFIED`, `NOTICED BUT NOT TOUCHING`, `CHANGES MADE / THINGS I DIDN'T TOUCH / POTENTIAL CONCERNS`, `CONFUSION`, `MISSING REQUIREMENT`, `PLAN`) to section headers, summary callouts, and inline flags.
- The `Common Rationalizations` / `Red Flags — STOP` / `Verification` epilogue as a pre-handoff checklist against this run.

## Error Handling Summary

For the full error handling table, read `references/usage-and-errors.md` when needed.

## Usage Examples

For invocation examples, read `references/usage-and-errors.md` when needed.
