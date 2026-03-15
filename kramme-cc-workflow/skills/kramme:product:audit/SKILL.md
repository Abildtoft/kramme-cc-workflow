---
name: kramme:product:audit
description: (experimental) Whole-product review across flows and surfaces. Requires a live app URL. Evaluates navigation coherence, feature discoverability, onboarding, cross-flow consistency, dead ends, friction, and trust/safety. Produces PRODUCT_AUDIT_OVERVIEW.md. Not for branch-scoped PR review (use pr:product-review) or pre-implementation critique (use siw:product-review).
argument-hint: "<url> [--flows <flow1,flow2,...>] [--focus <dimension>]"
disable-model-invocation: true
user-invocable: true
---

# Whole-Product Audit

Perform a system-wide product experience review across flows and surfaces of a running application. Produces a structured audit report organized by dimension and severity.

**Arguments:** "$ARGUMENTS"

## Workflow

### Step 1: Parse Arguments

Extract from `$ARGUMENTS`:

1. **URL** (required) — the target URL to audit (e.g., `http://localhost:3000`, `https://staging.example.com`)
2. **Flags** (optional):
   - `--flows <flow1,flow2,...>` — comma-separated list of flow names to scope the audit (e.g., `onboarding,settings,billing`)
   - `--focus <dimension>` — specific audit dimension to emphasize (e.g., `discoverability`, `consistency`, `trust-safety`)

Store parsed values:
- `TARGET_URL` — the URL to audit
- `SCOPED_FLOWS` — list of flow names, or empty (audit all discovered flows)
- `FOCUS_DIMENSION` — specific dimension to emphasize, or empty (all dimensions weighted equally)

If no URL is provided, **hard stop**:

```
Error: URL is required for product audit.

Usage:
  /kramme:product:audit http://localhost:3000
  /kramme:product:audit http://localhost:4200 --flows onboarding,settings,billing
  /kramme:product:audit http://localhost:3000 --focus discoverability
```

### Step 2: Validate Prerequisites

**Verify the application is reachable:**

```bash
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$TARGET_URL")
```

- `2xx` or `3xx` — proceed
- Connection refused — **hard stop**: `Error: Connection refused at $TARGET_URL. Start the application first, then re-run.`
- Timeout — **hard stop**: `Error: Request to $TARGET_URL timed out after 10 seconds. Is the server running?`
- `5xx` — **hard stop**: `Error: Server error ($HTTP_STATUS) at $TARGET_URL. Fix the server error before auditing.`
- `4xx` — warn but proceed (page may require authentication or interaction to render)

**Check for browser MCP:**

A browser MCP is required (same detection as `/kramme:browse`). Check for available tools in priority order:

1. `mcp__claude-in-chrome__*` tools
2. `mcp__chrome-devtools__*` tools
3. `mcp__playwright__*` tools

If none found, **hard stop**:

```
Error: No browser automation MCP detected. Product audit requires live browser inspection.

Install one of:
  - Claude in Chrome extension (recommended)
  - Chrome DevTools MCP
  - Playwright MCP
```

**Authentication note:** If the app returns a login page or redirect, warn the user:

```
Warning: The application at $TARGET_URL appears to require authentication.
Please log in manually in the browser first, then re-run the audit.
```

### Step 3: Load Project Context

Read project context files to understand the product being audited:

1. Read `CLAUDE.md` in the repo root
2. Read `AGENTS.md` files if they exist (repo root and closest relevant directories)

Extract product context:
- **Target users** — who is this product for?
- **UI stack** — what framework, component library, or design system is used?
- **Platform scope** — web only, mobile-responsive, desktop app?
- **Product domain** — what does the product do?

Store this context as `PROJECT_CONTEXT` for use in agent instructions.

### Step 3b: Check for Previous Audit

If `PRODUCT_AUDIT_OVERVIEW.md` exists in the project root:

1. Read the file.
2. Parse for previously reported findings and their IDs (PROD-NNN).
3. Note which flows were previously audited and their findings.
4. Store as `PREVIOUS_FINDINGS` for deduplication in Step 6.

This avoids re-reporting the same issues on subsequent audit runs. A finding is considered "previously reported" if it matches on:
- Same flow (flow name or URL)
- Same dimension
- Same underlying issue (semantic match on root cause)

Previously reported findings that no longer appear (the issue was fixed) should be noted as resolved in the new report.

### Step 4: Discover Application Structure

Invoke `/kramme:browse` via the Skill tool to navigate to the root URL and take a snapshot:

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

Store the list of flows to audit as `AUDIT_FLOWS`, each with:
- `flow_name` — human-readable name
- `flow_url` — URL to navigate to
- `flow_context` — brief description from navigation label

### Step 5: Audit Each Flow

Read `references/audit-dimensions.md` to load the audit dimensions.

For each flow in `AUDIT_FLOWS`:

**5a. Navigate and capture evidence**

Invoke `/kramme:browse` via the Skill tool to navigate to the flow's URL with full capture:

```
/kramme:browse $FLOW_URL
```

This captures the page snapshot, screenshot, console messages, and network requests.

**5b. Launch product reviewer agent**

Launch the `kramme:product-reviewer` agent via the Task tool with the following context:

```
You are auditing the overall product experience, not a branch diff.
This is a system-wide product audit of a live application.

PROJECT CONTEXT:
$PROJECT_CONTEXT

CURRENT FLOW: $FLOW_NAME ($FLOW_URL)

AUDIT MODE: Whole-product audit (not PR review, not spec review).
Evaluate this flow against the audit dimensions below.
Focus on system-wide patterns and cross-flow consistency.
Do NOT limit findings to a diff — evaluate the live product as-is.

{If FOCUS_DIMENSION is set:}
FOCUS: Emphasize the "$FOCUS_DIMENSION" dimension in your analysis, but still check all dimensions.

AUDIT DIMENSIONS:
{Contents of references/audit-dimensions.md}

EVIDENCE:
{Page snapshot, screenshot observations, console output, network summary from browse results}

Evaluate this flow and return findings in the standard PROD-NNN format.
For each finding, include the flow name and URL instead of file:line references.
Use **Flow:** `$FLOW_NAME ($FLOW_URL)` instead of **File:** in findings.
```

**5c. Collect findings**

Collect all findings from the agent, prefixed with the flow name.

**Error handling per flow:**
- If navigation fails (connection error, timeout): Skip this flow. Log a finding:
  ```
  ### PROD-XXX: Flow unreachable — $FLOW_NAME
  **Severity:** Critical
  **Dimension:** Dead Ends and Abandoned Transitions
  **Flow:** `$FLOW_NAME ($FLOW_URL)`
  **Issue:** Navigation to this flow failed. This may indicate a dead link, an auth-gated page, or a broken route.
  ```
- If the agent times out or fails: Skip this flow. Log a warning and continue to the next flow.
- Continue to the next flow regardless of individual flow failures.

### Step 6: Aggregate Findings

Collect all findings from all flows. Organize by severity, then by dimension:

**Critical** (broken flows, inaccessible features, data loss risk):
- Findings with severity Critical from any flow

**Important** (inconsistencies, missing states, poor discoverability):
- Findings with severity Important from any flow

**Suggestion** (polish, copy improvements, minor friction reduction):
- Findings with severity Suggestion from any flow

**Cross-flow patterns to identify during aggregation:**
- Same issue appearing in multiple flows (deduplicate, note frequency)
- Inconsistencies between flows (different patterns for same action)
- Navigation gaps (flows that don't connect to each other)
- Terminology mismatches across flows

**Previous audit deduplication (if `PREVIOUS_FINDINGS` exists from Step 3b):**
- Cross-reference each finding against previously reported findings
- If a finding matches a previous one (same flow, dimension, and root cause): mark as "Previously Reported" and move to a separate section
- If a previously reported finding no longer appears: mark as "Resolved since last audit"
- New findings not in the previous audit are reported normally

**Renumber findings before writing the report:**
- After deduplication, assign fresh IDs sequentially across the full aggregated report: `PROD-001`, `PROD-002`, `PROD-003`, ...
- Do not preserve per-flow scratch IDs from the individual reviewer runs
- Use the renumbered IDs everywhere in the final report so follow-up discussion and previous-audit matching stay unambiguous

### Step 7: Write Audit Report

Write `PRODUCT_AUDIT_OVERVIEW.md` at the project root.

This is a working artifact, not committed. Cleaned up by `/kramme:workflow-artifacts:cleanup`.

**Report structure:**

```markdown
# Product Audit Overview

**Application:** $TARGET_URL
**Date:** {current date}
**Flows audited:** {list of flow names}
**Focus:** {FOCUS_DIMENSION or "All dimensions"}

## Executive Summary

{3-5 sentence high-level assessment of the product's overall experience quality.
Highlight the most significant patterns — both strengths and weaknesses.
State the overall product maturity level: early/developing/mature/polished.}

## Audit Scope

| Flow | URL | Status |
|------|-----|--------|
| {flow_name} | {flow_url} | Audited / Skipped (reason) |

## Critical Findings

{All Critical findings, organized by dimension.
Each finding in PROD-NNN format.}

{If no critical findings: "No critical findings identified."}

## Important Findings

{All Important findings, organized by dimension.
Each finding in PROD-NNN format.}

{If no important findings: "No important findings identified."}

## Suggestions

{All Suggestion findings, organized by dimension.
Each finding in PROD-NNN format.}

{If no suggestions: "No suggestions identified."}

## Cross-Flow Patterns

{Patterns observed across multiple flows:}
- **Recurring issues:** {issues that appear in 2+ flows}
- **Inconsistencies:** {where flows behave differently for similar actions}
- **Navigation gaps:** {flows that should connect but don't}
- **Terminology:** {inconsistent terms across flows}

## Previously Reported (from prior audit)

{If PREVIOUS_FINDINGS exists:}
{Findings that match a previous audit run — same flow, dimension, and root cause.
Listed with their original PROD-NNN ID and current status.}

{If no previous audit: omit this section entirely.}

## Resolved Since Last Audit

{If PREVIOUS_FINDINGS exists:}
{Findings from the previous audit that are no longer present — the issues have been fixed.}

{If no previous audit: omit this section entirely.}

## Strengths

{What the product does well from a product experience perspective.
Bulleted list of 3-5 specific strengths observed during the audit.}

## Recommended Actions

{Ordered list of recommendations, most impactful first.
Group by effort level: quick wins, medium effort, larger initiatives.}

### Quick Wins
1. {Specific, actionable recommendation}

### Medium Effort
1. {Specific, actionable recommendation}

### Larger Initiatives
1. {Specific, actionable recommendation}
```

After writing the report, confirm completion:

```
Product audit complete. Report written to PRODUCT_AUDIT_OVERVIEW.md.

Audited {N} flows at $TARGET_URL.
Found: {X} critical, {Y} important, {Z} suggestions.

Key patterns:
- {Top 1-3 cross-flow patterns or most significant findings}
```

## Error Handling Summary

| Error | Behavior |
|-------|----------|
| No URL provided | Hard stop with usage instructions |
| No browser MCP detected | Hard stop with installation guidance |
| App not running (connection refused) | Hard stop with instructions to start app |
| App timeout | Hard stop with diagnostic |
| App returns 5xx | Hard stop with server error diagnostic |
| App returns 4xx | Warn and proceed (may need auth) |
| Authentication required | Warn user to authenticate manually first |
| Individual flow navigation fails | Skip flow, log as Critical finding, continue |
| Agent timeout on a flow | Skip flow, log warning, continue |
| All flows fail | Report with only infrastructure findings |

## Usage Examples

**Audit a local development server:**
```
/kramme:product:audit http://localhost:3000
```

**Scope to specific flows:**
```
/kramme:product:audit http://localhost:4200 --flows onboarding,settings,billing
```

**Focus on a specific dimension:**
```
/kramme:product:audit http://localhost:3000 --focus discoverability
```

**Audit a staging environment:**
```
/kramme:product:audit https://staging.myapp.com --flows dashboard,projects,team
```

**Combine flow scoping and dimension focus:**
```
/kramme:product:audit http://localhost:3000 --flows checkout,payment --focus trust-safety
```
