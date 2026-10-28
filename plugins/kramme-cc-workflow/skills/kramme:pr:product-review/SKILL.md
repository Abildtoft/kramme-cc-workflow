---
name: kramme:pr:product-review
description: Assess product value, UX heuristics, visual consistency, and accessibility of local changes with specialist agents. Use when asked or delegated by kramme:pr:github-review with --inline.
argument-hint: "[--subagent-model <model>] [app-url|auto] [--categories a11y,ux,product,visual] [--threshold 0-100] [--base <branch>] [--parallel] [--team] [--inline] [--no-diff-comments]"
disable-model-invocation: false
user-invocable: true
---

# Product Review for Pull Request and Local Changes

Review the product, UX, and UI experience of a PR's changes, including local staged/unstaged/untracked work, using specialized agents.

### Model Invocation Contract

- Invoke automatically only when the user explicitly asks in this session for a product, UX, visual, or accessibility review, or when an active `kramme:pr:github-review` invocation delegates its UI review pass. For a user request, apply the user's options as a direct invocation would.
- The `kramme:pr:github-review` delegation passes `--base "$BASE_REF" --inline --no-diff-comments` plus the user's `--categories`, `--subagent-model`, and `--parallel` choices when supplied. A delegating caller never adds `--team`, an app URL, or `auto`, and never drops `--inline` or `--no-diff-comments`.
- No other parent workflow may delegate to this skill. Every reviewer stays read-only; model invocation never edits source, posts to GitHub, or chooses dispositions.

**Arguments:** "$ARGUMENTS"

Before selecting a workflow, read and apply `${CODEX_HOME:-$HOME/.codex}/plugins/cache/kramme-cc-workflow/kramme-cc-workflow/0.90.0/shared/pr-review/references/model-selection.md`. It parses and removes `--subagent-model <model>` before category parsing or Team Mode routing. Its model selection applies to every review subagent in standard, parallel, and Team Mode, including relevance validation.

If `$ARGUMENTS` contains `--no-diff-comments`, set `DIFF_COMMENTS=false` and remove that flag. Otherwise set `DIFF_COMMENTS=true`. Preserve this value for Team Mode and standard review output.

Before aggregation, when `DIFF_COMMENTS=true`, `CONDUCTOR_WORKSPACE_ID` is set, and `mcp__conductor__DiffComment` is already present in the current tool set, read and follow `references/conductor-diff-comments.md` while building the canonical finding set. Preserve its projection identities through ordinal ID assignment for the post-audit projection, including in Team Mode. Detect tools by presence; never call one merely to probe availability.

## Team Mode

If `$ARGUMENTS` contains `--team`, remove that flag, read `references/team-mode.md`, and follow that workflow instead of the standard workflow below. Pass the remaining arguments through as the team-mode arguments. After its final aggregated audit succeeds, run `Post Conductor Diff Comments` below and then stop.

## Audit Workflow

### Step 1: Parse Arguments

1. If argument starts with `http` or equals `auto` → store as `app_url` (enables visual mode for agents)
2. If `--categories` flag → parse comma-separated list. Valid values: `a11y`, `ux`, `product`, `visual`, `all`
3. If `--threshold N` → store as `custom_threshold` (0-100). Replaces the per-category default report thresholds. Only findings with confidence >= N will be reported. Default thresholds if not specified: a11y = 90, ux/product/visual = 70.
4. If `--base <branch>` → store as `BASE_BRANCH_OVERRIDE`
5. If `--parallel` (or deprecated bare `parallel` for backward compatibility) → launch agents in parallel instead of sequentially
6. If `--team` → use Team Mode and remove it from the remaining arguments
7. If `--inline` → set `INLINE_MODE=true` and do not write `PRODUCT_REVIEW_OVERVIEW.md`
8. Default: all applicable categories, sequential, default thresholds

### Step 2: Load Project Review Conventions

Before selecting files or launching agents:

1. Read any repo-root project instruction files if present (`AGENTS.md`, `CLAUDE.md`, `.github/copilot-instructions.md`, markdown instruction files in repo-root `.claude/`, or equivalents).
2. Extract initial explicit review constraints from those repo-root instruction files and the UI code, especially:
   - UI stack (for example Tailwind)
   - component/design system requirements (for example Material Design 3)
   - accessibility requirements
   - platform scope (desktop/mobile/web)
3. Unless `--categories` excludes `product`, read `references/product-lens.md` and also gather the product conventions it lists.
4. Pass the merged conventions to every reviewer agent and tell them to prioritize documented conventions over generic best practices.

### Step 3: Resolve Base Branch and Identify UI-Relevant Changed Files

Use the shared plugin script to resolve the base branch and build the unified change scope (committed PR diff + staged + unstaged + untracked). It resolves in this order: explicit `--base`, the stack base of a gh-stack layer that has no open Pull Request or needs a restack, PR target branch, repository `kramme.baseBranch`, `CONDUCTOR_DEFAULT_BRANCH`, then `origin/HEAD`/`origin/main`/`origin/master`. It runs in strict mode, so fetch failures stop the workflow with the script's stderr message.

```bash
COLLECT_ARGS=(--strict --format nul --stack-context)
[ -n "${BASE_BRANCH_OVERRIDE:-}" ] && COLLECT_ARGS+=(--base "$BASE_BRANCH_OVERRIDE")

REVIEW_DIFF_FIELDS=$(mktemp "${TMPDIR:-/tmp}/review-diff.XXXXXX") || {
  echo "Could not create temporary review-diff file; stop." >&2
  exit 1
}
"${CODEX_HOME:-$HOME/.codex}/plugins/cache/kramme-cc-workflow/kramme-cc-workflow/0.90.0/scripts/collect-review-diff.sh" "${COLLECT_ARGS[@]}" \
  > "$REVIEW_DIFF_FIELDS" || {
  rm -f "$REVIEW_DIFF_FIELDS"
  echo "Base/diff collection failed; see the message above and stop." >&2
  exit 1
}
if ! {
  IFS= read -r -d '' BASE_REF \
    && IFS= read -r -d '' BASE_BRANCH \
    && IFS= read -r -d '' MERGE_BASE \
    && IFS= read -r -d '' CHANGED_FILES \
    && IFS= read -r -d '' STACK_CONTEXT
} < "$REVIEW_DIFF_FIELDS"; then
  rm -f "$REVIEW_DIFF_FIELDS"
  echo "Decoded review-diff fields were incomplete; stop." >&2
  exit 1
fi
rm -f "$REVIEW_DIFF_FIELDS"
```

The shared NUL output sets `BASE_REF`, `BASE_BRANCH`, `MERGE_BASE`, newline-delimited `CHANGED_FILES`, and the `STACK_CONTEXT` JSON document without evaluating collected values. Use `CHANGED_FILES` for the file filtering below. When the `STACK_CONTEXT` state is `stacked` or `unknown`, read `${CODEX_HOME:-$HOME/.codex}/plugins/cache/kramme-cc-workflow/kramme-cc-workflow/0.90.0/shared/pr-review/references/stacked-pr-review.md` and apply its orchestrator rules in Steps 7, 8, and 11.

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

The `ux`, `visual`, and `a11y` categories audit the UI-relevant files only. The `product` category audits every file in `CHANGED_FILES`, because permission rules, defaults, and flow logic also change outside UI paths.

After identifying the files in scope, discover any additional nested instruction files that apply to those files (for example `AGENTS.md`, `CLAUDE.md`, `.github/copilot-instructions.md`, markdown instruction files in a nearby `.claude/` directory, or tool-specific equivalents) and merge those constraints into the conventions from Step 2 before launching reviewer agents.

If `CHANGED_FILES` is empty:

```
No changes detected in this branch or local working tree.
Nothing to review.
```

**Action:** Stop.

If no UI-relevant files are found, the `ux`, `visual`, and `a11y` categories have nothing to audit: continue with the product reviewer alone and record this line in the report's `## Coverage Status`:

```
UX, visual, and accessibility review not run: no UI-relevant files matched (changed file types: {types}).
```

If `--categories` also excludes `product`, stop instead:

```
No UI-relevant files detected in this PR or local working tree.

Changed files: {list file types}

No UI/UX changes detected to audit.
```

**Action:** Stop.

### Step 4: Check for Previous Audit

If `PRODUCT_REVIEW_OVERVIEW.md` exists in the project root:

- Parse previously addressed findings (file path, line number, issue description, action taken)
- Store for filtering in Step 9

New reports number every finding `PROD-001`, `PROD-002`, ... in report order, regardless of source agent.

### Step 5: Determine Which Agents to Launch

**Launch unless `--categories` excludes `product`:**

- **kramme:product-reviewer** — product thinking and user flow analysis, over every changed file

**Launch when UI files changed:**

- **kramme:ux-reviewer** — usability heuristics and interaction states
- **kramme:visual-reviewer** — visual consistency and responsive design

**Conditionally launch when UI files changed:**

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
- If no `--categories` flag → launch every agent the groups above select

After applying the filter, drop `ux`, `visual`, and `a11y` when Step 3 found no UI-relevant files.

### Step 6: Detect Browser Automation (If URL Provided)

If `app_url` was provided and `CONDUCTOR_IS_LOCAL` is `0`, emit `Warning: Conductor cloud workspace detected (no browser MCP); continuing in code-only mode. Confirm with $kramme:setup.`, clear `app_url`, and continue directly to Step 7 without detecting browser automation.

If `app_url` was provided:

0. If `app_url` is `auto`, resolve it with the shared dev-server detector before checking browser automation:

   ```bash
   if ${CODEX_HOME:-$HOME/.codex}/plugins/cache/kramme-cc-workflow/kramme-cc-workflow/0.90.0/scripts/dev-server/detect-url.sh auto; then
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
- The reviewer's file scope from Step 3: the UI-relevant changed files, or every changed file for the product reviewer
- For the product reviewer, the reviewer brief from `references/product-lens.md`, verbatim
- Committed PR diff: `git diff "$MERGE_BASE"...HEAD` (using the base resolved in Step 3)
- Staged local diff: `git diff --cached`
- Unstaged local diff: `git diff`
- Untracked local files list: `git ls-files --others --exclude-standard` (agents should treat these as new files and review full file content)
- The `app_url` and browser MCP type (if visual mode)
- When `STACK_CONTEXT` reports `stacked`: the stack context JSON and the `Reviewer rules` section of the stacked Pull Request reference
- No report threshold: each agent reports every finding with its confidence, and Step 8 applies the threshold

Read `references/shared-working-tree.md` and instruct every reviewer that it is **read-only**. Every reviewer in this audit reads the same working tree, which usually holds uncommitted work, so a file one reviewer edits becomes false evidence for the others and produces fabricated findings that cite real files and real lines. No reviewer may create, edit, delete, move, or rename files, mutate git state, or run a command that rewrites files as a side effect, including formatters, `--fix` linters, codemods, dependency installs, and test runners that update snapshots or golden files. In visual mode, browser evidence stays read-only: never save a screenshot, recording, or trace into the repository working tree. Recommended code changes belong in the finding text; applying them is `$kramme:pr:resolve-review`'s job.

Capture the pre-launch working-tree manifest before any reviewer starts:

```bash
TREE_MANIFEST_BEFORE=$(mktemp "${TMPDIR:-/tmp}/review-tree.XXXXXX") || {
  echo "Could not create temporary tree-manifest file; stop." >&2
  exit 1
}
"${CODEX_HOME:-$HOME/.codex}/plugins/cache/kramme-cc-workflow/kramme-cc-workflow/0.90.0/scripts/review-tree-fingerprint.sh" > "$TREE_MANIFEST_BEFORE" || {
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
"${CODEX_HOME:-$HOME/.codex}/plugins/cache/kramme-cc-workflow/kramme-cc-workflow/0.90.0/scripts/review-tree-fingerprint.sh" > "$TREE_MANIFEST_AFTER" || {
  rm -f "$TREE_MANIFEST_BEFORE" "$TREE_MANIFEST_AFTER"
  echo "Working-tree manifest re-capture failed; see the message above and stop." >&2
  exit 1
}
diff "$TREE_MANIFEST_BEFORE" "$TREE_MANIFEST_AFTER"
```

Parse both manifests using the record contract in `references/shared-working-tree.md`. Compare the `@head` metadata records before deriving `MUTATED_PATHS`. If the commits differ, discard the complete finding batch, stop without writing `PRODUCT_REVIEW_OVERVIEW.md`, and require a fresh scope capture and audit; do not attribute an unknown concurrent commit or branch switch to a reviewer. Only when the commits match may you compare the remaining path records. An empty path-record `diff` means the tree is intact; continue. Any path-record difference means a reviewer mutated the shared tree: collect those differing paths as `MUTATED_PATHS` and apply the mutation handling in `references/shared-working-tree.md` — re-verify every finding citing a mutated path against the text now on disk, drop the ones that no longer reproduce, report the paths in `## Coverage Status`, and never revert or clean them. If `MUTATED_PATHS` covers most of the audited scope, stop without writing `PRODUCT_REVIEW_OVERVIEW.md` and report the mutation instead.

**Mode field:** If `app_url` was provided, set `Mode` to `Visual + Code` in the output template; otherwise `Code-only`.

**Agent failure handling.** If a selected reviewer agent is unavailable, times out, or returns output that cannot be parsed as findings, record the failed agent name and what was attempted. Continue only if at least one selected reviewer succeeded, and include a degraded-coverage banner in the final report: `Coverage degraded: <agent names> failed; findings below exclude <categories>.` If all selected reviewers fail, or if the relevance validator fails, stop without writing `PRODUCT_REVIEW_OVERVIEW.md`. Do not fabricate findings or present a partial audit as complete.

### Step 8: Validate Relevance

After collecting findings from all agents:

- Drop findings whose confidence is below `custom_threshold`, or below the category default when no threshold was given (a11y 90; ux, product, and visual 70)
- Launch **kramme:pr-relevance-validator** with the remaining findings, the resolved `BASE_BRANCH`, `BASE_REF`, and `MERGE_BASE`, and `STACK_CONTEXT` when it reports `stacked`
- Cross-reference each finding against the full audit scope (PR diff + staged/unstaged/untracked local changes)
- Filter pre-existing issues and out-of-scope problems
- Return only findings caused by this combined scope

### Step 9: Filter Previously Addressed Findings

If `PRODUCT_REVIEW_OVERVIEW.md` was found in Step 4:

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

- **Critical Product Issues** (must fix before merge) — only validated findings
- **Important Product Issues** (should fix) — only validated findings
- **Product Suggestions** (nice to have) — only validated findings
- **Open Questions** (need product owner input) and **Assumptions Used** (what the product reviewer inferred from incomplete context) — only when the product reviewer ran
- **Product Strengths** (what's well-done)
- **Filtered** (pre-existing or out-of-scope) — shown separately
- **Previously Addressed** — shown separately

### Step 11: Write Findings or Reply Inline

If `INLINE_MODE=true`:

- Reply with the full audit inline using the report format from `assets/product-review-report-format.md`
- Do **not** create or update `PRODUCT_REVIEW_OVERVIEW.md`

Otherwise, write to `PRODUCT_REVIEW_OVERVIEW.md` in the project root using the report format from `assets/product-review-report-format.md`. Include every section even if empty (with count of 0), except those the format marks as omittable.

In both modes, add the stacked Pull Request reference's `Stack:` line under the report title when the stack context is `stacked` or `unknown`.

When file output is used, `PRODUCT_REVIEW_OVERVIEW.md` is a working artifact — it should NOT be committed. It is intended to be cleaned up by `$kramme:workflow:cleanup-artifacts` when that skill is installed.

### Post Conductor Diff Comments (When Available)

After the canonical audit succeeds, when `CONDUCTOR_WORKSPACE_ID` is set, handle the optional projection for Team Mode, inline output, and file output. If `DIFF_COMMENTS=true` and `mcp__conductor__DiffComment` is already present in the current tool set, apply `references/conductor-diff-comments.md` using the identities preserved during aggregation. Otherwise report `Diff comments posted: 0 (skipped 0 already present)` and `Diff comment projection: skipped — disabled by --no-diff-comments` or `Diff comment projection: skipped — DiffComment unavailable`, as applicable.

### Step 12: Provide Action Plan

If Critical or Important issues found, suggest running `$kramme:pr:resolve-review` to address them.
