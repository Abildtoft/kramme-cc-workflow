---
name: kramme:pr:ux-review
description: Audit UI, UX, and product experience of PR and local changes using specialized agents for usability heuristics, product thinking, visual consistency, and accessibility.
argument-hint: "[app-url] [--categories a11y,ux,product,visual] [--threshold 0-100] [parallel]"
disable-model-invocation: true
user-invocable: true
---

# UX Audit for Pull Request and Local Changes

Audit the UI, UX, and product experience of a PR's changes, including local staged/unstaged/untracked work, using specialized agents.

**Arguments:** "$ARGUMENTS"

## Audit Workflow

### Step 1: Parse Arguments

1. If argument starts with `http` → store as `app_url` (enables visual mode for agents)
2. If `--categories` flag → parse comma-separated list. Valid values: `a11y`, `ux`, `product`, `visual`, `all`
3. If `--threshold N` → store as `custom_threshold` (0-100). Overrides each agent's default confidence threshold. Only findings with confidence >= N will be reported. Default thresholds if not specified: a11y = 90, ux/product/visual = 70.
4. If `parallel` → launch agents in parallel instead of sequentially
5. Default: all applicable categories, sequential, default thresholds

### Step 2: Load Project Review Conventions

Before selecting files or launching agents:

1. Read `CLAUDE.md` from repo root.
2. Discover `AGENTS.md` files in repo (`find . -name AGENTS.md`), then read relevant ones.
3. Extract explicit review constraints, especially:
   - UI stack (for example Tailwind)
   - component/design system requirements (for example Material Design 3)
   - accessibility requirements
   - platform scope (desktop/mobile/web)
4. Pass these conventions to every reviewer agent and tell them to prioritize documented conventions over generic best practices.

### Step 3: Identify UI-Relevant Changed Files

```bash
BASE_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
[ -z "$BASE_BRANCH" ] && BASE_BRANCH=$(git branch -r | grep -E 'origin/(main|master)$' | head -1 | sed 's@.*origin/@@')
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
No UI-relevant files detected in this PR or local working tree.

Changed files: {list file types}

No UI/UX changes detected to audit.
```

**Action:** Stop.

### Step 4: Check for Previous Audit

If `UX_REVIEW_OVERVIEW.md` exists in the project root:
- Parse previously addressed findings (file path, line number, issue description, action taken)
- Store for filtering in Step 9

### Step 5: Determine Which Agents to Launch

**Always launch (if UI files changed):**
- **kramme:ux-reviewer** — usability heuristics and interaction states
- **kramme:product-reviewer** — product thinking and user flow analysis
- **kramme:visual-reviewer** — visual consistency and responsive design

**Conditionally launch:**
- **kramme:a11y-auditor** — accessibility (WCAG 2.1 AA)

  Only launch if accessibility is a project requirement:

  1. Search `CLAUDE.md` and discovered `AGENTS.md` files for keywords: `accessibility`, `a11y`, `WCAG`, `aria`, `screen reader`
  2. Check `package.json` for a11y tooling: `eslint-plugin-jsx-a11y`, `axe-core`, `pa11y`, `@axe-core/*`
  3. Check for `.accessibilityrc`, a11y rules in ESLint/Biome config
  4. If **any signal found** → a11y is a requirement, launch the agent
  5. If **no signal found** → skip unless user explicitly passes `--categories a11y` or `--categories all`
  6. When skipped, include in output:
     ```
     Note: A11y audit skipped — no accessibility requirements detected in this project.
     Use `--categories a11y` to run it explicitly.
     ```

**Respect `--categories` filter:**
- If `--categories ux` → only launch kramme:ux-reviewer
- If `--categories a11y` → launch kramme:a11y-auditor regardless of detection
- If `--categories product,visual` → launch kramme:product-reviewer and kramme:visual-reviewer
- If `--categories all` → launch all 4 agents (a11y included regardless of detection)
- If no `--categories` flag → launch the 3 core agents + a11y only if detected

### Step 6: Detect Browser Automation (If URL Provided)

If `app_url` was provided:

1. Check for available browser MCP tools (in priority order):
   - `mcp__claude-in-chrome__*` tools
   - `mcp__chrome-devtools__*` tools
   - `mcp__playwright__*` tools
2. If found → pass `app_url` and browser MCP type to agents so they can take screenshots
3. If none found:
   ```
   Warning: No browser automation MCP detected. Using code-only analysis.

   For visual review, install one of:
     - Claude in Chrome extension (recommended)
     - Chrome DevTools MCP
     - Playwright MCP
   ```
   Continue in code-only mode.

### Step 7: Launch Agents

For each applicable agent, launch via the Task tool with:
- Project conventions extracted from `CLAUDE.md`/`AGENTS.md` (explicitly mention stack requirements like Tailwind or Material Design 3 when present)
- The list of UI-relevant changed files
- Committed PR diff: `git diff $(git merge-base origin/$BASE_BRANCH HEAD)...HEAD`
- Staged local diff: `git diff --cached`
- Unstaged local diff: `git diff`
- Untracked local files list: `git ls-files --others --exclude-standard` (agents should treat these as new files and review full file content)
- The `app_url` and browser MCP type (if visual mode)
- If `custom_threshold` was provided: instruct the agent to use this threshold instead of its default (e.g., "Only report findings with confidence >= {custom_threshold}")

**Sequential (default):** Launch agents one at a time. Easier to read and act on.

**Parallel (if user passes `parallel`):** Launch all agents simultaneously. Faster but results come back together.

### Step 8: Validate Relevance

After collecting findings from all agents:
- Launch **kramme:pr-relevance-validator** with all findings
- Cross-reference each finding against the full audit scope (PR diff + staged/unstaged/untracked local changes)
- Filter pre-existing issues and out-of-scope problems
- Return only findings caused by this combined scope

### Step 9: Filter Previously Addressed Findings

If `UX_REVIEW_OVERVIEW.md` was found in Step 4:
- Cross-reference validated findings against previously addressed findings
- **Only filter** if the finding is the same issue:
  - Same file
  - Similar line number (within ~10 lines)
  - Same underlying issue (semantic match)
- **Do NOT filter** if:
  - The issue is substantively different
  - Severity escalated
  - The finding identifies a problem with the previous fix
  - Previous action was "No action" or deferred
- When uncertain, keep the finding active
- Add filtered findings to "Previously Addressed" section

### Step 10: Aggregate Results

After validation and filtering, organize findings:

- **Critical UX Issues** (must fix before merge) — only validated findings
- **Important UX Issues** (should fix) — only validated findings
- **UX Suggestions** (nice to have) — only validated findings
- **UX Strengths** (what's well-done)
- **Filtered** (pre-existing or out-of-scope) — shown separately
- **Previously Addressed** — shown separately

### Step 11: Write Findings

Write to `UX_REVIEW_OVERVIEW.md` in the project root:

```markdown
# UX Audit Summary

**Mode:** {Code-only | Visual + Code}
**Agents Run:** {list of agents that ran}
**Categories:** {list of categories audited}

## Relevance Filter
- X findings validated as in-scope (PR/local)
- X findings filtered (pre-existing or out-of-scope)
- X findings filtered (previously addressed)

## Critical UX Issues (X found)

### {PREFIX}-NNN: {Brief title}

**Agent:** {kramme:ux-reviewer | kramme:product-reviewer | kramme:visual-reviewer | kramme:a11y-auditor}
**Category:** {specific category within agent's domain}
**File:** `path/to/file.tsx:42`
**Confidence:** {0-100}
**User Impact:** High

**Issue:** {Description}

**Recommendation:** {Specific fix}

---

## Important UX Issues (X found)

{Same format}

## UX Suggestions (X found)

{Same format}

## Filtered (Pre-existing/Out-of-scope)
<collapsed>
- [file:line]: Brief description - Reason filtered
</collapsed>

## Filtered (Previously Addressed)
<collapsed>
- [file:line]: Brief description
  Matched: UX_REVIEW_OVERVIEW.md - [action taken summary]
</collapsed>

## UX Strengths
- {What's well-done from a UX perspective}

## Recommended Action
1. Fix critical issues first
2. Address important issues
3. Consider suggestions
4. Re-run audit after fixes

**To resolve findings, run:** `/kramme:pr:resolve-review`
```

This file is a working artifact — it should NOT be committed. It will be cleaned up by `/kramme:workflow-artifacts:cleanup`.

### Step 12: Provide Action Plan

If Critical or Important issues found, suggest running `/kramme:pr:resolve-review` to address them.

## Usage Examples

**Full UX audit (code-only):**
```
/kramme:pr:ux-review
```

**UX audit with visual review:**
```
/kramme:pr:ux-review http://localhost:3000
```

**Specific categories:**
```
/kramme:pr:ux-review --categories ux,product
# Only usability and product review

/kramme:pr:ux-review --categories a11y
# Accessibility only (runs regardless of project detection)

/kramme:pr:ux-review --categories visual
# Visual consistency and responsive only
```

**Custom threshold (only report high-confidence findings):**
```
/kramme:pr:ux-review --threshold 90
# Only findings with confidence >= 90 are reported

/kramme:pr:ux-review --threshold 50
# Lower bar — more findings, including lower-confidence suggestions
```

**Parallel execution:**
```
/kramme:pr:ux-review parallel
# All applicable agents run simultaneously
```

**Combined:**
```
/kramme:pr:ux-review http://localhost:4200 --categories ux,visual --threshold 85 parallel
```

## Agent Descriptions

**kramme:a11y-auditor:**
- WCAG 2.1 AA compliance
- ARIA attributes and semantic HTML
- Color contrast and keyboard navigation
- Focus management and screen reader support
- Only runs when a11y is a project requirement

**kramme:ux-reviewer:**
- Nielsen's 10 usability heuristics
- Loading, error, empty, and success states
- Form validation UX
- Error prevention and recovery
- Feedback mechanisms

**kramme:product-reviewer:**
- Feature discoverability
- User flow completeness
- Edge cases from user perspective
- Progressive disclosure and IA
- Copy and content quality

**kramme:visual-reviewer:**
- Design token adherence
- Spacing, typography, and color consistency
- Component library conformance
- Responsive layout and breakpoints
- Mobile touch targets and content reflow
