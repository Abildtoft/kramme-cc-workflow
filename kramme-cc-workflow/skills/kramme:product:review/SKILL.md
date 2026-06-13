---
name: kramme:product:review
description: (experimental) Whole-product review across flows and surfaces. Requires a live app URL or auto-detected local dev server. Evaluates navigation coherence, feature discoverability, onboarding, cross-flow consistency, dead ends, friction, and trust/safety. Produces PRODUCT_AUDIT_OVERVIEW.md, or replies inline with --inline. Not for branch-scoped PR review (use pr:product-review) or pre-implementation spec audit (use siw:product-audit).
argument-hint: "<url|auto> [--flows <flow1,flow2,...>] [--focus <dimension>] [--inline]"
disable-model-invocation: true
user-invocable: true
kramme-platforms: [claude-code, codex]
---

# Whole-Product Review

Perform a system-wide product experience review across flows and surfaces of a running application. Produces a structured review report organized by dimension and severity.

**Arguments:** "$ARGUMENTS"

## Workflow

### Step 1: Parse Arguments

Extract from `$ARGUMENTS`:

1. **URL** (required) — the target URL to review (e.g., `http://localhost:3000`, `https://staging.example.com`) or `auto` to discover a running local dev server
2. **Flags** (optional):
   - `--flows <flow1,flow2,...>` — comma-separated list of flow names to scope the review (e.g., `onboarding,settings,billing`)
   - `--focus <dimension>` — specific review dimension to emphasize (e.g., `discoverability`, `consistency`, `trust-safety`)
   - `--inline` — reply with the full report inline instead of writing `PRODUCT_AUDIT_OVERVIEW.md`. Note: inline runs do not update the overview file, so previous-review deduplication and "Resolved since last review" tracking (Step 3b) only accrue across file-mode runs.

Store parsed values:

- `TARGET_URL` — the URL to review
- `SCOPED_FLOWS` — list of flow names, or empty (review all discovered flows)
- `FOCUS_DIMENSION` — specific dimension to emphasize, or empty (all dimensions weighted equally)
- `INLINE_MODE` — boolean (default: false)

**Normalize `--focus` to a dimension label.** Map the supplied token to a dimension from `references/review-dimensions.md`:

| `--focus` token | Dimension label |
| --- | --- |
| `navigation`, `ia` | Navigation and IA Coherence |
| `discoverability` | Feature Discoverability |
| `onboarding` | Onboarding and First-Run |
| `consistency` | Cross-Flow Consistency |
| `dead-ends` | Dead Ends and Abandoned Transitions |
| `friction` | Repeated Friction Points |
| `trust-safety` | Trust and Safety Cues |
| `copy` | Copy and Expectation Management |

If the token is unrecognized, warn (`Warning: unknown --focus "<token>"; emphasizing it as free text and reviewing all dimensions.`) and proceed, passing the token through verbatim. Store the mapped label (or raw token) as `FOCUS_DIMENSION`.

If no URL is provided, **hard stop**:

```
Error: URL is required for product review.

Usage:
  /kramme:product:review http://localhost:3000
  /kramme:product:review auto
  /kramme:product:review http://localhost:4200 --flows onboarding,settings,billing
  /kramme:product:review http://localhost:3000 --focus discoverability
```

### Step 2: Validate Prerequisites

**If URL is `auto`:** Resolve it with the shared dev-server detector used by `kramme:browse`:

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/dev-server/detect-url.sh auto
```

- `http://...` or `https://...` — set `TARGET_URL` to that value and continue.
- `__MULTIPLE_URLS__` — list the candidate URLs and ask the user to pick one; if the runtime cannot ask, hard stop with the candidate list.
- `__NO_RUNNING_SERVER__` — hard stop with: `Error: No running dev server detected. Start the application first, then re-run.`

**Validate the URL format after auto-resolution.** If `TARGET_URL` does not begin with `http://` or `https://`, **hard stop**: `Error: TARGET_URL must be an http:// or https:// URL, or auto. Got: $TARGET_URL`. This rejects typos and keeps an unintended value from reaching the shell.

**Verify the application is reachable:**

```bash
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$TARGET_URL")
```

- `2xx` or `3xx` — proceed
- Connection refused — **hard stop**: `Error: Connection refused at $TARGET_URL. Start the application first, then re-run.`
- Timeout — **hard stop**: `Error: Request to $TARGET_URL timed out after 10 seconds. Is the server running?`
- `5xx` — **hard stop**: `Error: Server error ($HTTP_STATUS) at $TARGET_URL. Fix the server error before reviewing.`
- `4xx` — warn but proceed (page may require authentication or interaction to render)

**Check for live browser automation:**

A browser automation provider is required. Do not duplicate provider names or priority order here; load `kramme:browse` and follow its current detection contract for the active host runtime.

If none found, **hard stop**:

```
Error: No browser automation provider detected. Product review requires live browser inspection.

Install or enable one of the browser automation providers supported by kramme:browse, then re-run.
```

**Authentication note:** If the app returns a login page or redirect, warn the user:

```
Warning: The application at $TARGET_URL appears to require authentication.
Please log in manually in the browser first, then re-run the review.
```

### Step 3: Load Project Context

Read project context files to understand the product being reviewed:

1. Read applicable project instruction files if they exist: repo-root `AGENTS.md`, `CLAUDE.md`, `.github/copilot-instructions.md`, and markdown instruction files in repo-root `.claude/` when present, plus the closest relevant nested instruction files for the app surfaces under review (`AGENTS.md`, `CLAUDE.md`, `.github/copilot-instructions.md`, markdown instruction files in a nearby `.claude/` directory, or equivalents)

Extract product context:

- **Target users** — who is this product for?
- **UI stack** — what framework, component library, or design system is used?
- **Platform scope** — web only, mobile-responsive, desktop app?
- **Product domain** — what does the product do?
- **Strategy context** — if repo-root `STRATEGY.md` exists, target problem, approach, users, key metrics, active tracks, and non-goals
- **Recent pulse context** — if `docs/pulse-reports/` exists, the 1-3 most recent usage, quality, error, performance, customer-signal, and followup highlights

Store this context as `PROJECT_CONTEXT` for use in agent instructions.

If `STRATEGY.md` has `last_updated` frontmatter older than 90 days, mark relevant strategy facts as `STALE:` in `PROJECT_CONTEXT`. If no strategy or pulse artifacts exist, record `MISSING PRODUCT CONTEXT:` for the missing coverage without blocking the review.

### Step 3b: Check for Previous Review

If `PRODUCT_AUDIT_OVERVIEW.md` exists in the project root:

1. Read the file.
2. Parse for previously reported findings and their IDs (PROD-NNN).
3. Note which flows were previously reviewed and their findings.
4. Store as `PREVIOUS_FINDINGS` for deduplication in Step 7.

This avoids re-reporting the same issues on subsequent review runs. A finding is considered "previously reported" if it matches on:

- Same flow (flow name or URL)
- Same dimension
- Same underlying issue (semantic match on root cause)

Previously reported findings that no longer appear (the issue was fixed) should be noted as resolved in the new report.

### Step 4: Discover Application Structure

Run the `kramme:browse` skill using the current host runtime's skill-invocation mechanism to navigate to the root URL and take a snapshot:

```
/kramme:browse $TARGET_URL
```

Analyze the landing page and navigation structure:

- Identify top-level navigation items (sidebar, header nav, tabs)
- Identify key routes and their labels
- Note the overall layout pattern (sidebar nav, top nav, dashboard, etc.)

**If `--flows` was provided:** Map the provided flow names to discovered routes. If a flow name does not match any visible navigation item or route, note it as "not found in navigation" but still attempt to locate it by appending the flow name to the base URL (e.g., `$TARGET_URL/settings`).

**If `--flows` was not provided:** Select 5-8 key flows from the navigation. Prioritize:

1. Primary user-facing features (not admin/settings)
2. Flows that appear in top-level navigation
3. Features that represent core product value
4. Settings and account management

Store the list of flows to review as `REVIEW_FLOWS`, each with:

- `flow_name` — human-readable name
- `flow_url` — URL to navigate to
- `flow_context` — brief description from navigation label

### Step 5: Review Each Flow

Read `references/review-dimensions.md` to load the review dimensions.

For each flow in `REVIEW_FLOWS`:

**5a. Navigate and capture evidence**

Run the `kramme:browse` skill using the current host runtime's skill-invocation mechanism to navigate to the flow's URL with full capture:

```
/kramme:browse $FLOW_URL
```

This captures the page snapshot, screenshot, console messages, and network requests.

**Go one level deep where it is safe.** A single landing snapshot misses friction, dead ends, and multi-step onboarding. After the initial capture, follow the flow's primary non-destructive entry point one step (the main call-to-action, the next step of a wizard, opening a create/empty state) and capture again. Never trigger destructive or irreversible actions (delete, pay, send, deactivate) — record those as review observations instead. If a deeper step needs data or auth that is unavailable, note it as a coverage gap for this flow and stop descending.

**5b. Launch product reviewer agent**

Launch the `kramme:product-reviewer` agent using the current host runtime's subagent mechanism. If no subagent mechanism is available, perform the same review inline in the main thread with the following context:

```
You are reviewing the overall product experience of a live application, not a branch diff.

PROJECT CONTEXT:
$PROJECT_CONTEXT

CURRENT FLOW: $FLOW_NAME @ $FLOW_URL

REVIEW MODE: Whole-product audit (not PR review, not spec audit).
Evaluate THIS flow against the review dimensions below. Nothing here is
"pre-existing" — flag every issue you find in this flow regardless of when
it was introduced.

When PROJECT CONTEXT includes strategy or pulse context, evaluate whether
this flow supports or contradicts the active tracks, target users, key
metrics, non-goals, or recent pulse signals. Missing strategy or pulse
coverage is not a finding by itself; report it only as a coverage gap unless
the flow makes product-direction claims that cannot be evaluated.

You see only this one flow. Do not assert cross-flow inconsistencies you
cannot verify from this evidence alone. Instead, capture this flow's
observable patterns in the "Observed Patterns" block below so a later
cross-flow synthesis step can compare them across flows.

{If FOCUS_DIMENSION is set:}
FOCUS: Emphasize the "$FOCUS_DIMENSION" dimension in your analysis, but still check all dimensions.

REVIEW DIMENSIONS:
{Contents of references/review-dimensions.md}

EVIDENCE:
{Page snapshot, screenshot observations, console output, network summary from browse results}

Return findings in the standard PROD-NNN audit format, using
**Flow:** `$FLOW_NAME @ $FLOW_URL` as the location field.

Then append an "Observed Patterns" block (plain notes, not findings) covering:
- Terminology used for the key nouns and verbs on this flow
- Primary action label(s) and their exact wording
- Confirmation pattern (modal / inline / toast / none)
- Save and cancel behavior
- Loading, error, and empty-state patterns
- Navigation entry and exit points (where this flow links to and from)
```

**5c. Collect findings**

Collect all findings from the agent, prefixed with the flow name.

**Error handling per flow:**

- If navigation fails (connection error, timeout): Skip this flow. Log a finding:
  ```
  ### PROD-XXX: Flow unreachable — $FLOW_NAME
  **Severity:** Critical
  **Dimension:** Dead Ends and Abandoned Transitions
  **Flow:** `$FLOW_NAME @ $FLOW_URL`
  **Confidence:** 100
  **User Impact:** High
  **Issue:** Navigation to this flow failed. This may indicate a dead link, an auth-gated page, or a broken route.
  ```
- If the agent times out or fails: Skip this flow. Log a warning and continue to the next flow.
- Continue to the next flow regardless of individual flow failures.

### Step 6: Cross-Flow Synthesis

The per-flow reviews in Step 5 each saw only one flow, so cross-flow dimensions (system-wide IA, consistency, terminology drift, gaps between flows) cannot be judged from any single review. Run one synthesis pass over all flows together.

If fewer than two flows were reviewed successfully, skip this step (there is nothing to compare) and note in the report that cross-flow synthesis was not run.

Otherwise, build a digest from every reviewed flow — its `Observed Patterns` block plus a one-line evidence summary — and launch the `kramme:product-reviewer` agent using the current host runtime's subagent mechanism. If no subagent mechanism is available, perform the synthesis inline in the main thread with:

```
You are performing the CROSS-FLOW SYNTHESIS pass of a whole-product audit.
You are given digests of every reviewed flow. Find issues that are only
visible when flows are compared. Do NOT re-review any single flow.

PROJECT CONTEXT:
$PROJECT_CONTEXT

FLOW DIGESTS:
{For each flow: $FLOW_NAME @ $FLOW_URL, its Observed Patterns block, and a one-line evidence summary}

Evaluate ONLY these cross-flow dimensions:
- Navigation and IA Coherence (across the whole product)
- Cross-Flow Consistency (terminology, confirmation patterns, save/cancel, loading/error states)
- Dead Ends and Abandoned Transitions (flows that should connect but don't)
- Repeated Friction Points (the same friction in 2+ flows)
- Copy and Expectation Management (terminology drift across flows)
- Strategy and Pulse Alignment (whether flow patterns support or contradict active tracks, target users, metrics, non-goals, and recent pulse signals)

Return findings in the standard PROD-NNN audit format. Because these findings
span flows, replace the single Flow location field with a **Flows:** line
listing every flow involved, e.g.
**Flows:** `Settings @ /settings`, `Billing @ /billing`
Do not report issues contained within a single flow — those belong to the
per-flow reviews.
```

### Step 7: Aggregate Findings

Collect all findings from every per-flow review and from the cross-flow synthesis pass. Organize by severity, then by dimension:

**Critical** (broken flows, inaccessible features, data loss risk):

- Findings with severity Critical from any flow

**Important** (inconsistencies, missing states, poor discoverability):

- Findings with severity Important from any flow

**Suggestion** (polish, copy improvements, minor friction reduction):

- Findings with severity Suggestion from any flow

**Fold in the cross-flow synthesis findings (from Step 6).** During aggregation:

- Place the synthesis findings (inconsistencies, navigation gaps, terminology drift, cross-flow friction) under the appropriate severity sections and in the Cross-Flow Patterns section below.
- Deduplicate the same single-flow issue reported by multiple per-flow reviews (note frequency).
- Drop any synthesis finding that merely restates a single-flow finding already reported.

**Previous review deduplication (if `PREVIOUS_FINDINGS` exists from Step 3b):**

- Cross-reference each finding against previously reported findings
- If a finding matches a previous one (same flow, dimension, and root cause): mark as "Previously Reported" and move to a separate section
- If a previously reported finding no longer appears: mark as "Resolved since last review"
- New findings not in the previous review are reported normally

**Renumber findings before writing the report:**

- After deduplication, assign fresh IDs sequentially across the full aggregated report: `PROD-001`, `PROD-002`, `PROD-003`, ...
- Do not preserve per-flow scratch IDs from the individual reviewer runs
- Use the renumbered IDs everywhere in the final report so follow-up discussion and previous-review matching stay unambiguous

### Step 8: Write Review Report or Reply Inline

If `INLINE_MODE=true`:

- Reply with the full report inline using the structure below
- Do **not** create or update `PRODUCT_AUDIT_OVERVIEW.md`

Otherwise:

- Write `PRODUCT_AUDIT_OVERVIEW.md` at the project root
- Treat it as a working artifact that should **not** be committed and can be cleaned up by `/kramme:workflow-artifacts:cleanup`

**Report structure:**

```markdown
# Product Review Overview

**Application:** $TARGET_URL **Date:** {current date} **Flows reviewed:** {list of flow names} **Focus:** {FOCUS_DIMENSION or "All dimensions"}

## Executive Summary

{3-5 sentence high-level assessment of the product's overall experience quality. Highlight the most significant patterns — both strengths and weaknesses. State the overall product maturity level: early/developing/mature/polished.}

## Review Scope

| Flow        | URL        | Status                      |
| ----------- | ---------- | --------------------------- |
| {flow_name} | {flow_url} | Reviewed / Skipped (reason) |

## Critical Findings

{All Critical findings, organized by dimension. Each finding in PROD-NNN format.}

{If no critical findings: "No critical findings identified."}

## Important Findings

{All Important findings, organized by dimension. Each finding in PROD-NNN format.}

{If no important findings: "No important findings identified."}

## Suggestions

{All Suggestion findings, organized by dimension. Each finding in PROD-NNN format.}

{If no suggestions: "No suggestions identified."}

## Cross-Flow Patterns

{Patterns observed across multiple flows:}

- **Recurring issues:** {issues that appear in 2+ flows}
- **Inconsistencies:** {where flows behave differently for similar actions}
- **Navigation gaps:** {flows that should connect but don't}
- **Terminology:** {inconsistent terms across flows}

## Strategy and Pulse Alignment

{How the reviewed flows support, conflict with, or lack evidence against STRATEGY.md and recent pulse reports. Include MISSING PRODUCT CONTEXT or STALE markers when applicable.}

## Previously Reported (from prior review)

{If PREVIOUS_FINDINGS exists:} {Findings that match a previous review run — same flow, dimension, and root cause. Listed with their original PROD-NNN ID and current status.}

{If no previous review: omit this section entirely.}

## Resolved Since Last Review

{If PREVIOUS_FINDINGS exists:} {Findings from the previous review that are no longer present — the issues have been fixed.}

{If no previous review: omit this section entirely.}

## Strengths

{What the product does well from a product experience perspective. Bulleted list of 3-5 specific strengths observed during the review.}

## Recommended Actions

{Ordered list of recommendations, most impactful first. Group by effort level: quick wins, medium effort, larger initiatives.}

### Quick Wins

1. {Specific, actionable recommendation}

### Medium Effort

1. {Specific, actionable recommendation}

### Larger Initiatives

1. {Specific, actionable recommendation}
```

After writing the report, confirm completion:

```
Product review complete. Report output: {inline reply | PRODUCT_AUDIT_OVERVIEW.md}.

Reviewed {N} flows at $TARGET_URL.
Found: {X} critical, {Y} important, {Z} suggestions.

Key patterns:
- {Top 1-3 cross-flow patterns or most significant findings}
```

## Error Handling Summary

| Error | Behavior |
| --- | --- |
| No URL provided | Hard stop with usage instructions |
| `auto` finds no running server | Hard stop with instructions to start app |
| URL not `http(s)://` and not `auto` | Hard stop with format error |
| Unknown `--focus` token | Warn, emphasize as free text, review all dimensions |
| No browser automation provider detected | Hard stop with installation guidance |
| App not running (connection refused) | Hard stop with instructions to start app |
| App timeout | Hard stop with diagnostic |
| App returns 5xx | Hard stop with server error diagnostic |
| App returns 4xx | Warn and proceed (may need auth) |
| Authentication required | Warn user to authenticate manually first |
| Deeper interaction blocked (auth/data) | Note coverage gap for the flow, stop descending |
| Individual flow navigation fails | Skip flow, log as Critical finding, continue |
| Agent timeout on a flow | Skip flow, log warning, continue |
| Fewer than 2 flows reviewed | Skip cross-flow synthesis, note in report |
| All flows fail | Report with only infrastructure findings |

## Usage Examples

**Review a local development server:**

```
/kramme:product:review http://localhost:3000
/kramme:product:review auto
```

**Scope to specific flows and focus a dimension:**

```
/kramme:product:review http://localhost:4200 --flows checkout,payment --focus trust-safety
```

**Reply inline instead of writing a report file:**

```
/kramme:product:review https://staging.myapp.com --inline
```
