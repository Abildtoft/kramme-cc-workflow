---
name: kramme:pr:product-review
description: Deep product review of branch and local changes. Evaluates user-value alignment, flow completeness, missing states, copy/defaults, permission behavior, adjacent-flow regressions, and prioritization quality. Infers likely user goals and non-goals when rationale is missing. Not for UX heuristics, accessibility, or visual consistency -- use pr:ux-review for those. Supports inline report output with --inline.
argument-hint: "[--base <branch>] [--threshold 0-100] [--inline]"
disable-model-invocation: false
user-invocable: true
kramme-platforms: [claude-code, codex]
---

# Product Review for Pull Request and Local Changes

Deep product review of branch changes and local work. Evaluates user-value alignment, flow completeness, missing states, copy/defaults, permission behavior, and adjacent-flow regressions.

**Arguments:** "$ARGUMENTS"

## Review Workflow

### Step 1: Parse Arguments

1. If `--base <branch>` flag provided, store as `BASE_BRANCH_OVERRIDE`
2. If `--threshold N` flag provided, store as `custom_threshold` (0-100). Only findings with confidence >= N will be reported. Default: 70
3. If `--inline` flag provided, set `INLINE_MODE=true`
4. If neither flag is present, use defaults

### Step 2: Load Project Review Conventions

Before launching agents:

1. Read any repo-root project instruction files if present (`AGENTS.md`, `CLAUDE.md`, `.github/copilot-instructions.md`, markdown instruction files in repo-root `.claude/`, or equivalents).
2. Extract baseline product and UI constraints from those repo-root instruction files, nearby product docs, and the code, especially:
   - Product domain and target users
   - UI stack and component/design system requirements
   - Platform scope (desktop/mobile/web)
   - Feature flags, permission models, or role-based access rules
3. Infer likely jobs-to-be-done, business goals, and obvious non-goals from the available docs when they are not stated explicitly.
4. Pass the merged conventions and inferred constraints to the reviewer agent and instruct it to prioritize documented conventions over generic best practices.

### Step 3: Resolve Base Branch and Identify Changed Files

Use the shared plugin script to resolve the base branch and build the unified change scope (committed PR diff + staged + unstaged + untracked). It uses the same 3-tier strategy: explicit `--base`, PR target branch, then `origin/HEAD`/`origin/main`/`origin/master`. It runs in strict mode, so fetch failures stop the workflow with the script's stderr message.

```bash
COLLECT_ARGS=(--strict --format json)
[ -n "${BASE_BRANCH_OVERRIDE:-}" ] && COLLECT_ARGS+=(--base "$BASE_BRANCH_OVERRIDE")

RESOLVED=$("${CLAUDE_PLUGIN_ROOT}/scripts/collect-review-diff.sh" "${COLLECT_ARGS[@]}") || {
  echo "Base/diff collection failed; see the message above and stop." >&2
  exit 1
}

REVIEW_DIFF_FIELDS=$(mktemp "${TMPDIR:-/tmp}/review-diff.XXXXXX") || {
  echo "Could not create temporary review-diff file; stop." >&2
  exit 1
}
"${CLAUDE_PLUGIN_ROOT}/scripts/collect-review-diff.sh" --decode-json \
  <<< "$RESOLVED" > "$REVIEW_DIFF_FIELDS" || {
  rm -f "$REVIEW_DIFF_FIELDS"
  echo "Base/diff decoding failed; see the message above and stop." >&2
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

The shared JSON decoder sets `BASE_REF`, `BASE_BRANCH`, `MERGE_BASE`, and newline-delimited `CHANGED_FILES`. All changed files in `CHANGED_FILES` are relevant for product review -- no file-type filtering.

After identifying the changed files, discover any additional nested instruction files that apply to those files (for example `AGENTS.md`, `CLAUDE.md`, `.github/copilot-instructions.md`, markdown instruction files in a nearby `.claude/` directory, or tool-specific equivalents) and merge those constraints into the conventions from Step 2 before launching the reviewer agent.

If no changed files at all:

```
No changes detected in this branch or local working tree.
Nothing to review.
```

**Action:** Stop.

### Step 4: Check for Previous Review

If `PRODUCT_REVIEW_OVERVIEW.md` exists in the project root:

- Parse previously addressed findings (file path, line number, issue description, action taken)
- Store for filtering in Step 7

Previously addressed findings have the format:

- **File:** `path/to/file.ts:123`
- **Issue/Finding:** [description]
- **Action taken:** [what was done]

If the file exists but contains no parseable entries in this format (e.g., it was hand-edited, partially written, or follows an older schema), skip the previously-addressed filtering in Step 7 and continue with all findings active. Do not stop the workflow.

### Step 5: Launch Product Reviewer Agent

Launch **kramme:product-reviewer** via the Task tool with:

- The resolved `BASE_BRANCH`, `BASE_REF`, and `MERGE_BASE` from Step 3
- Project conventions extracted from the instruction files gathered above and nearby product docs
- All changed files (full list, no filtering)
- Committed PR diff: `git diff "$MERGE_BASE"...HEAD`
- Staged local diff: `git diff --cached`
- Unstaged local diff: `git diff`
- Untracked local files list: `git ls-files --others --exclude-standard` (agent should treat these as new files and review full file content)
- Threshold instruction: always pass an explicit threshold to the agent. Use `custom_threshold` if provided in Step 1, otherwise pass 70 (e.g., "Only report findings with confidence >= {threshold}"). Do not rely on the agent's internal default.
- Explicit instruction: **"You are in PR mode. Focus on changes introduced by this diff. Evaluate: user-value alignment, flow completeness, missing states (loading, error, empty, edge), copy quality and defaults, permission/role behavior, adjacent-flow regressions, whether the change makes a clear product call, and whether obvious non-goals or deprioritized cases are missing. If rationale is absent, infer the likely user job and business reason from the code and docs, state the assumption, and review against it instead of stopping."**

### Step 6: Validate Relevance

After collecting findings from the product reviewer:

- Launch **kramme:pr-relevance-validator** with all findings and the resolved `BASE_BRANCH`
- Cross-reference each finding against the full review scope (committed PR diff + staged/unstaged/untracked local changes)
- Filter pre-existing issues and out-of-scope problems
- Return only findings caused by this combined scope

**Agent failure handling.** If the product reviewer or relevance validator is unavailable, times out, or returns output that cannot be parsed as findings, surface the failure to the user with the agent name and what was attempted, then stop without writing `PRODUCT_REVIEW_OVERVIEW.md`. Do not fabricate findings or silently continue with an empty result.

### Step 7: Filter Previously Addressed Findings

If `PRODUCT_REVIEW_OVERVIEW.md` was found in Step 4:

- Cross-reference validated findings against previously addressed findings
- **Only filter** if the finding is essentially the same issue:
  - Same file
  - Same enclosing function, component, or block (do not rely on raw line distance; refactors and formatters shift line numbers)
  - Same underlying issue (semantic match on root cause)
- **Do NOT filter** (keep as active finding) if:
  - The issue description is substantively different (different root cause)
  - The severity escalated (was suggestion, now critical)
  - The finding identifies a problem with the previous fix
  - The previous action was "No action" or a deferral
- When uncertain, err on the side of keeping the finding active
- Add filtered findings to "Previously Addressed" section

### Step 8: Aggregate and Write Results

After validation and filtering, organize findings into severity tiers:

- **Critical Product Issues** (must fix before merge) -- only validated findings
- **Important Product Issues** (should fix) -- only validated findings
- **Product Suggestions** (nice to have) -- only validated findings
- **Open Questions** (need product owner input)
- **Assumptions Used** (only when the reviewer had to infer target user, value, or non-goals from incomplete context)
- **Filtered** (pre-existing or out-of-scope) -- shown separately
- **Previously Addressed** -- shown separately
- **Product Strengths** (what's well-done)

If `INLINE_MODE=true`:

- Reply with the full report inline using the report format from `assets/product-review-report-format.md`
- Include all sections even if empty (with count of 0)
- Do **not** create or update `PRODUCT_REVIEW_OVERVIEW.md`

Otherwise:

- Write to `PRODUCT_REVIEW_OVERVIEW.md` in the project root using the report format from `assets/product-review-report-format.md`
- Include all sections even if empty (with count of 0)
- Treat the file as a working artifact that should **not** be committed and can be cleaned up by `/kramme:workflow-artifacts:cleanup`

### Step 9: Provide Action Plan

Emit the terminal output below. When there are Critical or Important findings, the embedded resolve commands serve as the action plan; when there are none, omit the "To resolve findings" block.

```
# Product Review Complete

## Relevance Filter
- X findings validated as in-scope
- X findings filtered (pre-existing or out-of-scope)
- X findings filtered (previously addressed)

## Results
- Critical: X
- Important: X
- Suggestions: X
- Open Questions: X

Report output: {inline reply | PRODUCT_REVIEW_OVERVIEW.md}

To resolve findings:
- If file output was used: `/kramme:pr:resolve-review`
- If inline output was used: `/kramme:pr:resolve-review <paste inline report>`
```

## Usage Examples

```
/kramme:pr:product-review
```

```
/kramme:pr:product-review --base develop
```

```
/kramme:pr:product-review --threshold 85
```

```
/kramme:pr:product-review --inline
```
