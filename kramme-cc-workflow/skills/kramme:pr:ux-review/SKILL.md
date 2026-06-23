---
name: kramme:pr:ux-review
description: Audit UI, UX, and product experience of PR and local changes using specialized agents for usability heuristics, product thinking, visual consistency, and accessibility. Supports inline report output with --inline. Use --team for multi-agent cross-validation.
argument-hint: "[app-url|auto] [--categories a11y,ux,product,visual] [--threshold 0-100] [--base <branch>] [--parallel] [--team] [--inline]"
disable-model-invocation: false
user-invocable: true
---

# UX Audit for Pull Request and Local Changes

Audit the UI, UX, and product experience of a PR's changes, including local staged/unstaged/untracked work, using specialized agents.

**Arguments:** "$ARGUMENTS"

## Team Mode

If `$ARGUMENTS` contains `--team`, remove that flag, read `references/team-mode.md`, and follow that workflow instead of the standard workflow below. Pass the remaining arguments through as the team-mode arguments.

## Audit Workflow

### Step 1: Parse Arguments

1. If argument starts with `http` or equals `auto` → store as `app_url` (enables visual mode for agents)
2. If `--categories` flag → parse comma-separated list. Valid values: `a11y`, `ux`, `product`, `visual`, `all`
3. If `--threshold N` → store as `custom_threshold` (0-100). Overrides each agent's default confidence threshold. Only findings with confidence >= N will be reported. Default thresholds if not specified: a11y = 90, ux/product/visual = 70.
4. If `--base <branch>` → store as `BASE_BRANCH_OVERRIDE`
5. If `--parallel` (or deprecated bare `parallel` for backward compatibility) → launch agents in parallel instead of sequentially
6. If `--team` → use Team Mode and remove it from the remaining arguments
7. If `--inline` → set `INLINE_MODE=true` and do not write `UX_REVIEW_OVERVIEW.md`
8. Default: all applicable categories, sequential, default thresholds

### Step 2: Load Project Review Conventions

Before selecting files or launching agents:

1. Read any repo-root project instruction files if present (`AGENTS.md`, `CLAUDE.md`, `.github/copilot-instructions.md`, markdown instruction files in repo-root `.claude/`, or equivalents).
2. Extract initial explicit review constraints from those repo-root instruction files and the UI code, especially:
   - UI stack (for example Tailwind)
   - component/design system requirements (for example Material Design 3)
   - accessibility requirements
   - platform scope (desktop/mobile/web)
3. Pass the merged conventions to every reviewer agent and tell them to prioritize documented conventions over generic best practices.

### Step 3: Resolve Base Branch and Identify UI-Relevant Changed Files

Use the shared plugin script to resolve the base branch and build the unified change scope (committed PR diff + staged + unstaged + untracked). It uses the same 3-tier strategy: explicit `--base`, PR target branch, then `origin/HEAD`/`origin/main`/`origin/master`. It runs in strict mode, so fetch failures stop the workflow with the script's stderr message.

```bash
COLLECT_ARGS=(--strict --format json)
[ -n "${BASE_BRANCH_OVERRIDE:-}" ] && COLLECT_ARGS+=(--base "$BASE_BRANCH_OVERRIDE")

RESOLVED=$(${CLAUDE_PLUGIN_ROOT}/scripts/collect-review-diff.sh "${COLLECT_ARGS[@]}") || {
  echo "Base/diff collection failed; see the message above and stop." >&2
  exit 1
}

parse_review_diff_json() {
  local field="$1"

  if ! command -v python3 >/dev/null 2>&1; then
    echo "python3 is required to parse collect-review-diff JSON output" >&2
    return 1
  fi

  REVIEW_DIFF_JSON="$RESOLVED" REVIEW_DIFF_FIELD="$field" python3 - <<'PY'
import json
import os
import sys

field = os.environ["REVIEW_DIFF_FIELD"]

try:
    data = json.loads(os.environ["REVIEW_DIFF_JSON"])
except (KeyError, json.JSONDecodeError) as exc:
    print(f"Invalid collect-review-diff JSON output: {exc}", file=sys.stderr)
    sys.exit(1)

if field == "changed_files":
    value = data.get(field)
    if not isinstance(value, list) or not all(isinstance(item, str) for item in value):
        print(f"collect-review-diff JSON field '{field}' must be a string list", file=sys.stderr)
        sys.exit(1)
    sys.stdout.write("\n".join(value))
    sys.exit(0)

value = data.get(field)
if not isinstance(value, str):
    print(f"collect-review-diff JSON field '{field}' must be a string", file=sys.stderr)
    sys.exit(1)
sys.stdout.write(value)
PY
}

BASE_REF=$(parse_review_diff_json base_ref) || exit 1
BASE_BRANCH=$(parse_review_diff_json base_branch) || exit 1
MERGE_BASE=$(parse_review_diff_json merge_base) || exit 1
CHANGED_FILES=$(parse_review_diff_json changed_files) || exit 1
```

The JSON parsing block sets `BASE_REF`, `BASE_BRANCH`, `MERGE_BASE`, and newline-delimited `CHANGED_FILES`. Use `CHANGED_FILES` for the file filtering below.

Filter for UI-relevant files:

- **Components**: `*.tsx`, `*.jsx`, `*.vue`, `*.svelte`, `*.component.ts`, `*.component.html`
- **Templates**: `*.html`, `*.hbs`, `*.ejs`, `*.pug`
- **Styles**: `*.css`, `*.scss`, `*.sass`, `*.less`, `*.styled.ts`, `*.module.css`
- **Views/Pages**: Files in `pages/`, `views/`, `screens/`, `routes/`, `app/` directories
- **Config**: Tailwind config, theme files, design token files
- **Assets**: SVG files, icon sets

After identifying the changed UI files, discover any additional nested instruction files that apply to those files (for example `AGENTS.md`, `CLAUDE.md`, `.github/copilot-instructions.md`, markdown instruction files in a nearby `.claude/` directory, or tool-specific equivalents) and merge those constraints into the conventions from Step 2 before launching reviewer agents.

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
- Accept legacy per-agent finding IDs (`PROD-NNN`, `VIS-NNN`, and `A11Y-NNN`) from older UX audit reports as previously addressed identifiers; new UX audit reports use artifact-scoped `UX-NNN` IDs. Remove this legacy-ID acceptance once existing `UX_REVIEW_OVERVIEW.md` artifacts contain only `UX-NNN` IDs (i.e., once reports generated before the `UX-NNN` switch are no longer in circulation).
- Store for filtering in Step 9

### Step 5: Determine Which Agents to Launch

**Always launch (if UI files changed):**

- **kramme:ux-reviewer** — usability heuristics and interaction states
- **kramme:product-reviewer** — product thinking and user flow analysis
- **kramme:visual-reviewer** — visual consistency and responsive design

**Conditionally launch:**

- **kramme:a11y-auditor** — accessibility (WCAG 2.1 AA)

  Only launch if accessibility is a project requirement:
  1. Search the project instruction files gathered in Steps 2-3 for keywords: `accessibility`, `a11y`, `WCAG`, `aria`, `screen reader`
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

0. If `app_url` is `auto`, resolve it with the shared dev-server detector before checking browser automation:

   ```bash
   if ${CLAUDE_PLUGIN_ROOT}/scripts/dev-server/detect-url.sh auto; then
     :
   else
     printf '%s\n' "__DETECTOR_UNAVAILABLE__"
   fi
   ```

   - `http://...` or `https://...` — replace `app_url` with the resolved URL.
   - `__MULTIPLE_URLS__` — list candidates and ask the user to choose one; if non-interactive, clear `app_url`, warn, and continue in code-only mode.
   - `__NO_RUNNING_SERVER__` — clear `app_url`, warn, and continue in code-only mode.
   - `__DETECTOR_UNAVAILABLE__` — ask the user for the dev-server URL; if non-interactive, clear `app_url`, warn that the shared detector is unavailable, and continue in code-only mode.

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

For each applicable agent, launch the reviewer using the platform's agent-invocation primitive with:

- The resolved `BASE_BRANCH`, `BASE_REF`, and `MERGE_BASE` from Step 3, so agents use the correct diff scope
- Project conventions extracted from the project instruction files (explicitly mention stack requirements like Tailwind or Material Design 3 when present)
- The list of UI-relevant changed files
- Committed PR diff: `git diff "$MERGE_BASE"...HEAD` (using the base resolved in Step 3)
- Staged local diff: `git diff --cached`
- Unstaged local diff: `git diff`
- Untracked local files list: `git ls-files --others --exclude-standard` (agents should treat these as new files and review full file content)
- The `app_url` and browser MCP type (if visual mode)
- If `custom_threshold` was provided: instruct the agent to use this threshold instead of its default (e.g., "Only report findings with confidence >= {custom_threshold}")

**Sequential (default):** Launch agents one at a time. Easier to read and act on.

**Parallel (if user passes `--parallel`):** Launch all agents simultaneously. Faster but results come back together.

**Mode field:** If `app_url` was provided, set `Mode` to `Visual + Code` in the output template; otherwise `Code-only`.

**Agent failure handling.** If a selected reviewer agent is unavailable, times out, or returns output that cannot be parsed as findings, record the failed agent name and what was attempted. Continue only if at least one selected reviewer succeeded, and include a degraded-coverage banner in the final report: `Coverage degraded: <agent names> failed; findings below exclude <categories>.` If all selected reviewers fail, or if the relevance validator fails, stop without writing `UX_REVIEW_OVERVIEW.md`. Do not fabricate findings or present a partial audit as complete.

### Step 8: Validate Relevance

After collecting findings from all agents:

- Launch **kramme:pr-relevance-validator** with all findings and the resolved `BASE_BRANCH`
- Cross-reference each finding against the full audit scope (PR diff + staged/unstaged/untracked local changes)
- Filter pre-existing issues and out-of-scope problems
- Return only findings caused by this combined scope

### Step 9: Filter Previously Addressed Findings

If `UX_REVIEW_OVERVIEW.md` was found in Step 4:

- Cross-reference validated findings against previously addressed findings
- **Only filter** if the finding is the same issue:
  - Same file
  - Same enclosing function, component, or block (do not rely on raw line distance; refactors and formatters shift line numbers)
  - Same underlying issue (semantic match on root cause)
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

### Step 11: Write Findings or Reply Inline

If `INLINE_MODE=true`:

- Reply with the full audit inline using the report format from `assets/ux-review-report-format.md`
- Do **not** create or update `UX_REVIEW_OVERVIEW.md`

Otherwise, write to `UX_REVIEW_OVERVIEW.md` in the project root using the report format from `assets/ux-review-report-format.md`. Include all sections even if empty (with count of 0).

When file output is used, `UX_REVIEW_OVERVIEW.md` is a working artifact — it should NOT be committed. It is intended to be cleaned up by `/kramme:workflow-artifacts:cleanup` when that skill is installed.

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
/kramme:pr:ux-review --parallel
# All applicable agents run simultaneously
```

**Combined:**

```
/kramme:pr:ux-review http://localhost:4200 --categories ux,visual --threshold 85 --parallel
```

**Inline report (no markdown file):**

```
/kramme:pr:ux-review --inline
/kramme:pr:ux-review http://localhost:3000 --categories ux,visual --inline
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
