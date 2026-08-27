---
name: kramme:pr:ux-review
description: Audit UI, UX, and product experience of PR and local changes using specialized agents for usability heuristics, product thinking, visual consistency, and accessibility. Supports inline report output with --inline. Use --team for multi-agent cross-validation.
argument-hint: "[app-url|auto] [--categories a11y,ux,product,visual] [--threshold 0-100] [--base <branch>] [--parallel] [--team] [--inline] [--no-diff-comments]"
disable-model-invocation: true
user-invocable: true
---

# UX Audit for Pull Request and Local Changes

Audit the UI, UX, and product experience of a PR's changes, including local staged/unstaged/untracked work, using specialized agents.

**Arguments:** "$ARGUMENTS"

If `$ARGUMENTS` contains `--no-diff-comments`, set `DIFF_COMMENTS=false` and remove that flag. Otherwise set `DIFF_COMMENTS=true`. Preserve this value for Team Mode and standard review output.

Before aggregation, when `DIFF_COMMENTS=true`, `CONDUCTOR_WORKSPACE_ID` is set, and `mcp__conductor__DiffComment` is already present in the current tool set, read and follow `references/conductor-diff-comments.md` while building the canonical finding set. Preserve its projection identities through ordinal ID assignment for the post-audit projection, including in Team Mode. Detect tools by presence; never call one merely to probe availability.

## Team Mode

If `$ARGUMENTS` contains `--team`, remove that flag, read `references/team-mode.md`, and follow that workflow instead of the standard workflow below. Pass the remaining arguments through as the team-mode arguments. After its final aggregated audit succeeds, run `Post Conductor Diff Comments` below and then stop.

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
COLLECT_ARGS=(--strict --format nul)
[ -n "${BASE_BRANCH_OVERRIDE:-}" ] && COLLECT_ARGS+=(--base "$BASE_BRANCH_OVERRIDE")

REVIEW_DIFF_FIELDS=$(mktemp "${TMPDIR:-/tmp}/review-diff.XXXXXX") || {
  echo "Could not create temporary review-diff file; stop." >&2
  exit 1
}
"${CLAUDE_PLUGIN_ROOT}/scripts/collect-review-diff.sh" "${COLLECT_ARGS[@]}" \
  > "$REVIEW_DIFF_FIELDS" || {
  rm -f "$REVIEW_DIFF_FIELDS"
  echo "Base/diff collection failed; see the message above and stop." >&2
  exit 1
}
if ! {
  IFS= read -r -d '' BASE_REF \
    && IFS= read -r -d '' BASE_BRANCH \
    && IFS= read -r -d '' MERGE_BASE \
    && IFS= read -r -d '' CHANGED_FILES
} < "$REVIEW_DIFF_FIELDS"; then
  rm -f "$REVIEW_DIFF_FIELDS"
  echo "Decoded review-diff fields were incomplete; stop." >&2
  exit 1
fi
rm -f "$REVIEW_DIFF_FIELDS"
```

The shared NUL output sets `BASE_REF`, `BASE_BRANCH`, `MERGE_BASE`, and newline-delimited `CHANGED_FILES` without evaluating collected values. Use `CHANGED_FILES` for the file filtering below.

Read `references/ui-relevance-heuristics.md`, then filter for UI-relevant files using this contract marker: UI relevance path contract: `ui-relevance-path-contract-v1`.

A file is UI-relevant when it matches any of these categories:

- **Components**: `*.tsx`, `*.jsx`, `*.vue`, `*.svelte`, `*.astro`, `*.mdx`, `*.component.ts`, `*.component.html`
- **Templates**: `*.html`, `*.htm`, `*.hbs`, `*.ejs`, `*.pug`
- **Styles**: `*.css`, `*.scss`, `*.sass`, `*.less`, `*.styl`, `*.styled.ts`, `*.styled.js`, `*.module.css`, `*.module.scss`
- **Configuration**: `tailwind.config.*`, `theme.*`, files under `design-tokens/`
- **View and route directories**: files under `pages/`, `views/`, `screens/`, `routes/`, or `app/`
- **UI component directories**: files under `component/`, `components/`, `ui/`, `widgets/`, `layouts/`, or `templates/`
- **Style directories**: files under `styles/` or `css/`
- **Static asset directories**: image or SVG files under `public/`, `static/`, or `assets/` (`*.svg`, `*.png`, `*.jpg`, `*.jpeg`, `*.gif`, `*.webp`, `*.avif`, `*.ico`)

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

If `app_url` was provided and `CONDUCTOR_IS_LOCAL` is `0`, emit `Warning: Conductor cloud workspace detected (no browser MCP); continuing in code-only mode. Confirm with /kramme:setup.`, clear `app_url`, and continue directly to Step 7 without detecting browser automation.

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

Read `references/shared-working-tree.md` and instruct every reviewer that it is **read-only**. Every reviewer in this audit reads the same working tree, which usually holds uncommitted work, so a file one reviewer edits becomes false evidence for the others and produces fabricated findings that cite real files and real lines. No reviewer may create, edit, delete, move, or rename files, mutate git state, or run a command that rewrites files as a side effect, including formatters, `--fix` linters, codemods, dependency installs, and test runners that update snapshots or golden files. In visual mode, browser evidence stays read-only: never save a screenshot, recording, or trace into the repository working tree. Recommended code changes belong in the finding text; applying them is `/kramme:pr:resolve-review`'s job.

Capture the pre-launch working-tree manifest before any reviewer starts:

```bash
TREE_MANIFEST_BEFORE=$(mktemp "${TMPDIR:-/tmp}/review-tree.XXXXXX") || {
  echo "Could not create temporary tree-manifest file; stop." >&2
  exit 1
}
"${CLAUDE_PLUGIN_ROOT}/scripts/review-tree-fingerprint.sh" > "$TREE_MANIFEST_BEFORE" || {
  rm -f "$TREE_MANIFEST_BEFORE"
  echo "Working-tree manifest capture failed; see the message above and stop." >&2
  exit 1
}
```

**Sequential (default):** Launch agents one at a time. Easier to read and act on.

**Parallel (if user passes `--parallel`):** Launch all agents simultaneously. Faster but results come back together. Parallel reviewers share one working tree; the read-only mandate above is what keeps their evidence independent.

**Working-tree integrity check.** After every reviewer has returned, before relevance validation, re-capture the manifest and compare:

```bash
TREE_MANIFEST_AFTER=$(mktemp "${TMPDIR:-/tmp}/review-tree.XXXXXX") || {
  echo "Could not create temporary tree-manifest file; stop." >&2
  exit 1
}
"${CLAUDE_PLUGIN_ROOT}/scripts/review-tree-fingerprint.sh" > "$TREE_MANIFEST_AFTER" || {
  rm -f "$TREE_MANIFEST_BEFORE" "$TREE_MANIFEST_AFTER"
  echo "Working-tree manifest re-capture failed; see the message above and stop." >&2
  exit 1
}
diff "$TREE_MANIFEST_BEFORE" "$TREE_MANIFEST_AFTER"
```

An empty `diff` means the tree is intact; continue. Any difference means a reviewer mutated the shared tree: collect the differing paths as `MUTATED_PATHS` and apply the mutation handling in `references/shared-working-tree.md` — re-verify every finding citing a mutated path against the text now on disk, drop the ones that no longer reproduce, report the paths in `## Coverage Status`, and never revert or clean them. If `MUTATED_PATHS` covers most of the UI-relevant scope, stop without writing `UX_REVIEW_OVERVIEW.md` and report the mutation instead.

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

### Post Conductor Diff Comments (When Available)

After the canonical audit succeeds, when `CONDUCTOR_WORKSPACE_ID` is set, handle the optional projection for Team Mode, inline output, and file output. If `DIFF_COMMENTS=true` and `mcp__conductor__DiffComment` is already present in the current tool set, apply `references/conductor-diff-comments.md` using the identities preserved during aggregation. Otherwise report `Diff comments posted: 0 (skipped 0 already present)` and `Diff comment projection: skipped — disabled by --no-diff-comments` or `Diff comment projection: skipped — DiffComment unavailable`, as applicable.

### Step 12: Provide Action Plan

If Critical or Important issues found, suggest running `/kramme:pr:resolve-review` to address them.
