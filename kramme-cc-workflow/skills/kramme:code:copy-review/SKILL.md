---
name: kramme:code:copy-review
description: Review unnecessary, redundant, or duplicative UI text across a codebase or the current branch diff. Defaults to a full-codebase audit on the base branch and automatically uses PR/local diff review on non-base branches; use --pr to force diff review. Supports scoped audits, confidence thresholds, and inline output.
argument-hint: "[--pr] [--base <branch>] [--threshold 0-100] [--inline] [--all | <scope-path>]"
disable-model-invocation: false
user-invocable: true
---

# Copy Review for Codebase Scope, Pull Request, or Local Changes

Audit the full codebase for unnecessary UI text when invoked on the resolved base branch. Automatically switch to PR/local diff review on a non-base branch, use `--pr` to force diff review, or pass `--all` or a scope path to force audit mode.

**Arguments:** "$ARGUMENTS"

**Shared rubric:** Read `references/copy-review-rubric.md` before filtering files or launching reviewers. It defines UI-relevant file rules, redundancy categories, confidence/severity rules, finding format, and exclusions.

## Review Workflow

### Step 1: Parse Arguments

1. If `--base <branch>` flag provided, store as `BASE_BRANCH_OVERRIDE`
2. If `--threshold N` flag provided, store as `custom_threshold` (0-100). Only findings with confidence >= N will be reported. If not provided, set `custom_threshold=75`.
3. If `--inline` flag provided, set `INLINE_MODE=true`
4. If `--pr` is provided, set `FORCE_PR_MODE=true`.
5. Reject invalid combinations before resolving the mode:
   - If `--pr` is combined with `--all` or a positional scope path, report that PR mode and audit scope cannot be combined, then stop.
   - If `--all` and a positional scope path are combined, or more than one positional scope path remains, report the conflicting scope arguments and stop.
   - If `--base` is combined with `--all` or a positional scope path, report that `--base` only applies to PR mode or automatic mode detection, then stop.
   - If an unknown option is provided, report it and stop.
6. Select explicit audit mode before branch detection:
   - If `--all` is provided, set `SCAN_MODE=true` and `TARGET_SCOPE` to the repo root.
   - If exactly one positional scope path is provided, set `SCAN_MODE=true` and store it as `TARGET_SCOPE`.
7. If no explicit audit scope was provided, resolve the base with the shared plugin script:

   ```bash
   RESOLVE_ARGS=(--strict)
   [ -n "${BASE_BRANCH_OVERRIDE:-}" ] && RESOLVE_ARGS+=(--base "$BASE_BRANCH_OVERRIDE")
   
   RESOLVED_BASE=$("${CLAUDE_PLUGIN_ROOT}/scripts/resolve-base.sh" "${RESOLVE_ARGS[@]}") || {
     echo "Base resolution failed; see the message above and stop." >&2
     exit 1
   }
   eval "$RESOLVED_BASE"
   CURRENT_BRANCH=$(git branch --show-current)
   ```

8. Select the automatic mode:
   - If `FORCE_PR_MODE=true`, set `SCAN_MODE=false` and skip the remaining automatic-detection rules.
   - Otherwise, if `CURRENT_BRANCH` is non-empty and equals `BASE_BRANCH`, set `SCAN_MODE=true` and `TARGET_SCOPE` to the repo root.
   - Otherwise, if `CURRENT_BRANCH` is non-empty and differs from `BASE_BRANCH`, set `SCAN_MODE=false`.
   - Otherwise HEAD is detached; compare `git rev-parse HEAD` with `git rev-parse "$BASE_REF"` and use full-codebase audit mode when they match or PR/local diff mode when they differ.
9. Always report the selected mode before scanning: `Copy review mode: codebase audit ({scope}).` or `Copy review mode: PR/local diff against {BASE_REF}.`

### Step 2: Load Rubric and Project Review Conventions

1. Read the local copy-review rubric at `references/copy-review-rubric.md`.
2. Read any repo-root project instruction files if present (`AGENTS.md`, `CLAUDE.md`, `.github/copilot-instructions.md`, markdown instruction files in repo-root `.claude/`, or equivalents).
3. Extract initial UI stack, component library, design system, target audience, and content strategy conventions from those repo-root instruction files and the surrounding UI code.
4. Pass the rubric and merged conventions to the reviewer agent, and instruct it to prioritize documented conventions over generic best practices.

### Step 3: PR/Local Diff Mode — Resolve Base Branch and Identify UI-Relevant Changed Files

When `SCAN_MODE=false`, run this section. When `SCAN_MODE=true`, skip to Step 6.

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

The shared JSON decoder sets `BASE_REF`, `BASE_BRANCH`, `MERGE_BASE`, and newline-delimited `CHANGED_FILES`. Use `CHANGED_FILES` for the file filtering below.

Filter changed paths using the UI-relevant file rules in `references/copy-review-rubric.md`.

After identifying the changed UI files, discover any additional nested instruction files that apply to those files (for example `AGENTS.md`, `CLAUDE.md`, `.github/copilot-instructions.md`, markdown instruction files in a nearby `.claude/` directory, or tool-specific equivalents) and merge those constraints into the conventions from Step 2 before launching the reviewer agent.

If no UI-relevant files found, reply inline with the following message (regardless of `INLINE_MODE`) and stop. Do not create or update `COPY_REVIEW_OVERVIEW.md`.

```
No UI-relevant files detected in this PR or local working tree.

Changed files: {comma-separated list of file extensions or paths from the unified change scope}

No UI copy to review.
```

### Step 4: Check for Previous Review

In diff review mode, if `COPY_REVIEW_OVERVIEW.md` exists in the project root:

- Parse previously addressed findings (file path, line number, issue description, action taken)
- Store for filtering in Step 8

In codebase scan mode, do not use an existing overview to filter audit findings. The new report represents the latest requested scan and replaces the prior overview unless `INLINE_MODE=true`.

### Step 5: PR/Local Diff Mode — Launch Copy Reviewer Agent

When `SCAN_MODE=false`, launch **kramme:copy-reviewer** using the platform's agent-invocation primitive with:

- The loaded rubric from `references/copy-review-rubric.md`
- The resolved `BASE_BRANCH`, `BASE_REF`, and `MERGE_BASE` from Step 3
- Project conventions extracted from the discovered instruction files and established UI patterns
- The list of UI-relevant changed files
- Committed PR diff: `git diff "$MERGE_BASE"...HEAD`
- Staged local diff: `git diff --cached`
- Unstaged local diff: `git diff`
- Untracked local files list: `git ls-files --others --exclude-standard` (agent should treat these as new files and review full file content)
- Instruct the agent to apply the confidence threshold: "Only report findings with confidence >= {custom_threshold}"
- Focus instruction: **"Focus on text redundancy introduced by this diff. Apply the shared copy-review rubric to each text element in changed code."**

### Step 6: Codebase Scan Mode

When `SCAN_MODE=true`, run this section instead of Steps 3 and 5.

#### Orient and Select Files

1. Use `TARGET_SCOPE` exactly as selected in Step 1: the repo root for `--all` or automatic base-branch audit mode, otherwise the requested positional scope path.
2. Read `package.json` and relevant build configuration to understand the UI stack and directory layout.
3. Discover instruction files that apply within `TARGET_SCOPE` and merge their project conventions and target-audience guidance with the conventions from Step 2.
4. Enumerate files inside `TARGET_SCOPE` and filter them using the UI-relevant file rules in `references/copy-review-rubric.md`. Skip `node_modules`, `dist`, build artifacts, generated files, lock files, and vendored code.
5. Count the resulting files and report `Codebase scan scope: {scope}; UI-relevant files: {count}.` before proceeding.
6. If the count is zero, reply inline with `No UI-relevant files in scope: {scope}.` and stop without creating or updating `COPY_REVIEW_OVERVIEW.md`.

#### Launch Audit Reviewers

Launch **kramme:copy-reviewer** in audit mode using the platform's agent-invocation primitive with:

- The loaded rubric from `references/copy-review-rubric.md`
- The list of UI-relevant files in scope
- Project conventions from the discovered instruction files and established UI patterns
- The confidence instruction: "Only report findings with confidence >= {custom_threshold}"
- Instruction: **"You are in audit mode. Scan all provided files for copy redundancy. Flag all issues regardless of when they were introduced."**

If the scope exceeds 50 files, split it into batches. When the agent-invocation primitive supports parallelism, launch the batches in parallel; otherwise scan the batches sequentially.

Collect findings from all batches, deduplicate findings with the same file, line, and underlying issue, and group them by rubric category to identify systemic patterns. Promote findings that appear in three or more locations to at least Important severity. Continue through the shared validation, filtering, and reporting steps below.

### Step 7: Validate Relevance

After collecting findings from the copy reviewer:

If no separate agent runtime is available, perform the same copy review and relevance validation directly in the main thread. If an invoked copy reviewer or relevance validator is unavailable, times out, or returns output that cannot be parsed as findings, surface the failure to the user with the agent name and what was attempted, then stop without writing `COPY_REVIEW_OVERVIEW.md`. Do not fabricate findings or silently continue with an empty result.

When `SCAN_MODE=true`, skip the PR relevance validator: every finding grounded in a file inside the requested audit scope is in scope regardless of when it was introduced. Continue to Step 8.

When `SCAN_MODE=false`:

- Launch **kramme:pr-relevance-validator** using the same agent-invocation primitive with all findings and the resolved `BASE_BRANCH`
- Cross-reference each finding against the full review scope (committed PR diff + staged/unstaged/untracked local changes)
- Filter pre-existing issues and out-of-scope problems
- Return only findings caused by this combined scope

### Step 8: Filter Previously Addressed Findings

In diff review mode, if `COPY_REVIEW_OVERVIEW.md` was found in Step 4:

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

In codebase scan mode, do not filter findings as previously addressed; an audit intentionally reports all issues in the requested scope.

### Step 9: Aggregate and Write Results

After validation and filtering, organize findings into severity tiers:

- **Critical Copy Issues** (must fix before merge) -- only validated findings
- **Important Copy Issues** (should fix) -- only validated findings
- **Copy Suggestions** (nice to have) -- only validated findings
- **Filtered** (pre-existing or out-of-scope) -- shown separately
- **Previously Addressed** -- shown separately
- **Copy Strengths** (what's well-done)

For codebase scan mode, also group findings by rubric category, summarize systemic patterns, and order recommended actions by impact and effort.

If `INLINE_MODE=true`:

- Reply with the full report inline using the report format from `assets/copy-review-report-format.md`.
- In codebase scan mode, replace the report's base-branch metadata with the requested scope and file count, and include a "Patterns & Themes" section.
- Include all sections even if empty (with count of 0)
- Do **not** create or update `COPY_REVIEW_OVERVIEW.md`

Otherwise:

- Write to `COPY_REVIEW_OVERVIEW.md` in the project root using the report format from `assets/copy-review-report-format.md`.
- In codebase scan mode, replace the report's base-branch metadata with the requested scope and file count, include a "Patterns & Themes" section, and overwrite any prior overview because the file represents the latest scan.
- Include all sections even if empty (with count of 0)
- Treat the file as a working artifact that should **not** be committed and can be cleaned up by `/kramme:workflow-artifacts:cleanup`

### Step 10: Provide Action Plan

If Critical or Important findings were found:

- When `INLINE_MODE=false`, suggest running `/kramme:pr:resolve-review`; auto/local discovery will find `COPY_REVIEW_OVERVIEW.md` and ask which overview to resolve if multiple local review files exist.
- When `INLINE_MODE=true`, suggest re-running with the inline report content passed as the argument: `/kramme:pr:resolve-review <paste report>` — or invoke it in the same session so chat context contains the report.

Organize findings summary in the terminal output:

```
# Copy Review Complete

## Relevance Filter
- X findings validated as in-scope
- X findings filtered (pre-existing or out-of-scope)
- X findings filtered (previously addressed)

## Results
- Critical: X
- Important: X
- Suggestions: X

Report output: {inline reply | COPY_REVIEW_OVERVIEW.md}

To resolve findings: `/kramme:pr:resolve-review`
```

## Usage Examples

```
/kramme:code:copy-review
```

```
/kramme:code:copy-review --pr
```

```
/kramme:code:copy-review --base develop
```

```
/kramme:code:copy-review --threshold 85 --inline
```

```
/kramme:code:copy-review --all
```

```
/kramme:code:copy-review src/components
```
