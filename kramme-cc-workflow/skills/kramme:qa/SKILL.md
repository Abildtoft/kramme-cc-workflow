---
name: kramme:qa
description: Structured QA testing with evidence capture. Runs smoke checks, diff-aware validation, or targeted route testing against a live app. Produces QA_REPORT.md with screenshots, repro steps, severity, and recommended fixes, or replies inline with --inline. Uses browser MCP when available and falls back to code-only analysis otherwise.
argument-hint: "<url> [quick|diff-aware|targeted <route>] [--base <branch>] [--regression] [--inline]"
disable-model-invocation: false
user-invocable: true
---

# Structured QA Testing with Evidence Capture

Run smoke checks, diff-aware validation, or targeted route testing against a live application. When browser MCP is available, capture screenshots, console output, and network activity; otherwise fall back to code-only analysis. Produce a QA report with findings, severity ratings, and recommended fixes.

**Arguments:** "$ARGUMENTS"

## Workflow

### Step 1: Parse Arguments

Extract from `$ARGUMENTS`:

1. **URL** (required) — the target URL to test (e.g., `http://localhost:3000`, `https://staging.example.com`)
2. **Mode** (optional, default: `quick`):
   - `quick` — landing page + 2-3 key routes
   - `diff-aware` — test routes affected by changed UI files
   - `targeted <route>` — test a specific route/page
3. **Flags**:
   - `--base <branch>` — explicit base branch for diff-aware mode
   - `--regression` — compare results against previous QA baseline (see Step 10)
   - `--inline` — reply with the QA report inline instead of writing `QA_REPORT.md`

Store parsed values:
- `TARGET_URL` — the base URL to test
- `TEST_MODE` — `quick`, `diff-aware`, or `targeted`
- `TARGET_ROUTE` — specific route for targeted mode (e.g., `/settings/profile`)
- `BASE_OVERRIDE` — explicit base branch if provided
- `REGRESSION_MODE` — boolean (default: false)
- `INLINE_MODE` — boolean (default: false)

### Step 2: Validate Prerequisites

**URL is required.** If not provided, stop with:
```
Error: URL is required.

Usage: /kramme:qa <url> [quick|diff-aware|targeted <route>] [--base <branch>]

Examples:
  /kramme:qa http://localhost:3000
  /kramme:qa http://localhost:4200 diff-aware --base develop
  /kramme:qa http://localhost:3000 targeted /settings/profile
```

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

Resolve the base branch using a 3-tier strategy:

**Tier 1: Explicit override**
If `--base <branch>` was provided, use that value directly as `BASE_BRANCH`. Skip Tier 2 and 3.

**Tier 2: PR/MR target branch detection**
```bash
REMOTE_URL=$(git remote get-url origin 2>/dev/null)
if printf '%s' "$REMOTE_URL" | grep -q 'github.com' && command -v gh >/dev/null 2>&1; then
  BASE_BRANCH=$(gh pr view --json baseRefName --jq '.baseRefName' 2>/dev/null)
elif printf '%s' "$REMOTE_URL" | grep -qi 'gitlab' && command -v glab >/dev/null 2>&1; then
  BASE_BRANCH=$(glab mr view --json target_branch --jq '.target_branch' 2>/dev/null)
elif command -v glab >/dev/null 2>&1; then
  BASE_BRANCH=$(glab mr view --json target_branch --jq '.target_branch' 2>/dev/null)
fi
```

**Tier 3: Fallback**
```bash
BASE_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
[ -z "$BASE_BRANCH" ] && BASE_BRANCH=$(git branch -r | grep -E 'origin/(main|master)$' | head -1 | sed 's@.*origin/@@')
```

Normalize before using `origin/$BASE_BRANCH`:
```bash
BASE_BRANCH=${BASE_BRANCH#refs/heads/}
BASE_BRANCH=${BASE_BRANCH#refs/remotes/origin/}
BASE_BRANCH=${BASE_BRANCH#origin/}
if [ -z "$BASE_BRANCH" ]; then
  echo "Error: Could not determine base branch. Re-run with --base <branch>." >&2
  exit 1
fi
if ! git check-ref-format --branch "$BASE_BRANCH" >/dev/null 2>&1; then
  echo "Error: Base branch '$BASE_BRANCH' is not a valid branch name. Re-run with --base <branch>." >&2
  exit 1
fi
if ! git fetch origin "refs/heads/${BASE_BRANCH}:refs/remotes/origin/${BASE_BRANCH}" 2>/dev/null; then
  echo "Error: Failed to fetch origin/$BASE_BRANCH. Check remote access and re-run with --base <branch>." >&2
  exit 1
fi
if ! git rev-parse --verify --quiet "origin/$BASE_BRANCH" >/dev/null; then
  echo "Error: Base branch 'origin/$BASE_BRANCH' not found. Re-run with --base <branch>." >&2
  exit 1
fi
```

Identify changed UI files:
```bash
BASE_REF=$(git merge-base origin/$BASE_BRANCH HEAD)
{
  git diff --name-only "$BASE_REF"...HEAD      # committed PR diff
  git diff --name-only --cached                # staged local changes
  git diff --name-only                         # unstaged local changes
  git ls-files --others --exclude-standard     # untracked local files
} | sed '/^$/d' | sort -u
```

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

**targeted mode:**

Use the user-specified route directly. The test scope is `TARGET_URL + TARGET_ROUTE`.

### Step 3b: Detect Framework

Check `package.json` (if it exists) for framework dependencies to load framework-specific QA hints:

```bash
cat package.json 2>/dev/null | grep -oE '"(next|nuxt|@angular/core|react|vue|svelte|@sveltejs/kit|rails)"' | head -1
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

For each identified page/route, read the QA rubric from `references/qa-rubric.md`.

Create a test checklist for each route:

1. **Page loads without errors** — no blank page, no stuck spinner, no crash
2. **Console is clean** — no JavaScript errors, no unhandled promise rejections
3. **Network requests succeed** — no 4xx/5xx responses from API calls
4. **Key interactions work** — buttons respond, forms submit, navigation works
5. **Visual state is reasonable** — no overflow, no broken images, readable text
6. **Edge states** — empty states handled, error states if triggerable

Prioritize test items by severity impact. Blockers first, then major, then minor.

**If `DETECTED_FRAMEWORK` is set:** Add framework-specific checks from `references/framework-hints.md` to the test plan. For example, if Next.js is detected, add hydration error checks and `_next/data` monitoring.

### Step 5: Execute Tests via Browse

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

Degrade to code-only analysis:
1. Read the changed files identified in Step 3
2. Analyze code for potential issues:
   - Missing error boundaries or error handling
   - Missing loading states
   - Hardcoded strings or missing i18n
   - Unhandled null/undefined access
   - Missing form validation
   - Accessibility issues visible in markup
3. Report all findings as "code-only mode" with a clear warning:
   ```
   Warning: No browser MCP detected. Running in code-only mode.
   Findings are based on static code analysis only — no live testing performed.

   For full QA with screenshots and live testing, install a browser MCP:
     - Claude in Chrome extension (recommended)
     - Chrome DevTools MCP
     - Playwright MCP
   ```

### Step 6: Capture Evidence

For each tested page/route, collect:

- **Screenshot** — visual state from browse (describes what the screenshot shows)
- **Console errors/warnings** — grouped by severity (errors first, then warnings)
- **Failed network requests** — any 4xx/5xx responses or failed requests
- **Interaction results** — outcome of any interactions performed

Store evidence per route for inclusion in the QA report.

### Step 7: Assess Findings

Rate each issue found using severity levels:

- **Blocker**: Page crash, data loss, broken core flow, JavaScript error that prevents rendering, critical API failure that blocks functionality
- **Major**: Significant functionality broken, console errors on page load, form submission fails, navigation dead-ends, key feature not working
- **Minor**: Visual glitch, warning in console, slow response (> 3 seconds), minor layout issue, non-critical feature broken
- **Info**: Observation without clear user impact, optimization opportunity, deprecation warning, minor inconsistency

When assessing, consider:
- Does the issue affect the critical user path?
- Is the issue visible to users or only in developer tools?
- Does the issue block a workflow or is it cosmetic?
- Is this a regression (diff-aware mode) or pre-existing?

### Step 7b: Compute Health Score

Read `references/health-score-rubric.md` and compute a weighted health score (0-100).

1. Assign each finding to one category: Console, Network, Visual, Functional, Data, Interaction, or Content
2. For each category, start at 100 and deduct per finding: Blocker -25, Major -15, Minor -8, Info -3 (minimum 0)
3. Compute the weighted average using the rubric weights

Store as `HEALTH_SCORE` and `HEALTH_LABEL` (Excellent/Good/Fair/Poor/Critical).

### Step 8: Write QA Report or Reply Inline

Use the template from `assets/qa-report-template.md`.

Populate all sections:
- Fill in mode, URL, date, browser MCP type
- List all tested routes with descriptions
- Document each finding with severity, repro steps, expected vs actual, and recommended fix
- Calculate summary counts per severity level
- Provide overall recommendation (ready / not ready / ready with caveats)

**Numbering convention:** Findings are numbered `QA-001`, `QA-002`, etc.

If `INLINE_MODE=true`:
- Reply with the full populated QA report inline
- Do **not** create or update `QA_REPORT.md`

Otherwise:
- Write `QA_REPORT.md` at the project root
- Treat it as a working artifact that should **not** be committed and can be cleaned up by `/kramme:workflow-artifacts:cleanup`

### Step 8b: Regression Comparison (conditional)

**Skip if** `REGRESSION_MODE` is false.

Check if `QA_BASELINE.json` exists from a previous run:
- If not found: warn `"No previous baseline found. Skipping regression comparison. This run's results will be saved as the new baseline."` and continue to Step 9.
- If found: load and compare:

**Comparison logic:**
1. **Score delta:** `current_score - baseline_score` (positive = improvement, negative = regression)
2. **Fixed issues:** findings in the baseline that are NOT in the current run (matched by title + route)
3. **New issues:** findings in the current run that are NOT in the baseline
4. **Persistent issues:** findings present in both runs

Add a `## Regression` section to the QA report:

```markdown
## Regression (vs. baseline from {baseline_date})

**Score delta:** {current_score} vs. {baseline_score} ({+N / -N})

### Fixed ({N})
- QA-{NNN}: {title} (was {severity})

### New ({N})
- QA-{NNN}: {title} ({severity})

### Persistent ({N})
- QA-{NNN}: {title} ({severity})
```

### Step 9: Save Baseline

After regression comparison (or if skipped), save a machine-readable baseline for future runs:

Write `QA_BASELINE.json` at the project root:
```json
{
  "date": "{ISO 8601 timestamp}",
  "url": "{TARGET_URL}",
  "mode": "{TEST_MODE}",
  "framework": "{DETECTED_FRAMEWORK or null}",
  "browserMcp": "{BROWSER_MCP or 'code-only'}",
  "healthScore": {HEALTH_SCORE},
  "healthLabel": "{HEALTH_LABEL}",
  "routesTested": {N},
  "findings": [
    {
      "id": "QA-001",
      "title": "{title}",
      "severity": "{Blocker|Major|Minor|Info}",
      "category": "{Console|Network|Visual|Functional|Data|Interaction|Content}",
      "route": "{URL path}"
    }
  ],
  "severityCounts": {
    "blocker": {N},
    "major": {N},
    "minor": {N},
    "info": {N}
  }
}
```

This file is a working artifact. It will be cleaned up by `/kramme:workflow-artifacts:cleanup`.

### Step 10: Output Summary

After writing the report, display an inline summary:

```
## QA Summary: $TARGET_URL

**Mode:** {quick | diff-aware | targeted}
**Routes Tested:** {N}
**Browser:** {claude-in-chrome | chrome-devtools | playwright | code-only}
**Framework:** {DETECTED_FRAMEWORK or "not detected"}
**Health Score:** {HEALTH_SCORE}/100 ({HEALTH_LABEL})

### Verdict: {READY | NOT READY | READY WITH CAVEATS}

{If NOT READY: list blockers with brief description}
{If READY WITH CAVEATS: list major issues with brief description}
{If READY: confirm no blockers or major issues found}

- Blockers: {N}
- Major: {N}
- Minor: {N}
- Info: {N}

{If REGRESSION_MODE and baseline found:}
### Regression vs. {baseline_date}
Score: {baseline_score} -> {current_score} ({+N / -N})
Fixed: {N} | New: {N} | Persistent: {N}

Report output: {inline reply | QA_REPORT.md}
{If blockers found: "Fix blockers and re-run: /kramme:qa <url>"}
```

## Error Handling Summary

| Error | Behavior |
|-------|----------|
| No URL provided | Hard stop with usage instructions |
| URL unreachable (connection refused) | Hard stop with diagnostic |
| URL unreachable (timeout) | Hard stop with diagnostic |
| URL returns 5xx | Hard stop with server error diagnostic |
| URL returns 4xx | Warn and proceed |
| No browser MCP | Degrade to code-only analysis |
| Browse fails on a route | Log error, continue with remaining routes |
| No UI changes (diff-aware) | Report and stop |
| Base branch not found | Hard stop, suggest --base flag |
| Route detection fails (quick) | Fall back to landing page only |

## Usage Examples

**Quick smoke test (default mode):**
```
/kramme:qa http://localhost:3000
/kramme:qa http://localhost:3000 quick
```

**Diff-aware testing (test routes affected by changes):**
```
/kramme:qa http://localhost:4200 diff-aware --base develop
/kramme:qa http://localhost:3000 diff-aware
```

**Targeted route testing:**
```
/kramme:qa http://localhost:3000 targeted /settings/profile
/kramme:qa http://localhost:4200 targeted /dashboard
```

**Staging environment:**
```
/kramme:qa https://staging.myapp.com
/kramme:qa https://staging.myapp.com diff-aware --base main
```

**Regression comparison (compare against previous run):**
```
/kramme:qa http://localhost:3000 --regression
/kramme:qa http://localhost:4200 diff-aware --regression
```

**Inline report (no markdown file):**
```
/kramme:qa http://localhost:3000 --inline
/kramme:qa http://localhost:4200 diff-aware --inline
```
