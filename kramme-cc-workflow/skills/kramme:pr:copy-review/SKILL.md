---
name: kramme:pr:copy-review
description: Review PR and local changes for unnecessary, redundant, or duplicative UI text — labels, descriptions, placeholders, tooltips, and instructions that the UI already communicates through its structure. Supports inline report output with --inline.
argument-hint: "[--base <branch>] [--threshold 0-100] [--inline]"
disable-model-invocation: false
user-invocable: true
---

# Copy Review for Pull Request and Local Changes

Review branch changes and local work for unnecessary UI text. Finds labels, descriptions, placeholders, tooltips, and instructions that duplicate what the UI already communicates through structure, icons, or interaction patterns.

**Arguments:** "$ARGUMENTS"

## Review Workflow

### Step 1: Parse Arguments

1. If `--base <branch>` flag provided, store as `BASE_BRANCH_OVERRIDE`
2. If `--threshold N` flag provided, store as `custom_threshold` (0-100). Only findings with confidence >= N will be reported. If not provided, set `custom_threshold=75`.
3. If `--inline` flag provided, set `INLINE_MODE=true`
4. If neither flag is present, use defaults

### Step 2: Load Project Review Conventions

1. Read any repo-root project instruction files if present (`AGENTS.md`, `CLAUDE.md`, `.github/copilot-instructions.md`, markdown instruction files in repo-root `.claude/`, or equivalents).
2. Extract initial UI stack, component library, design system, target audience, and content strategy conventions from those repo-root instruction files and the surrounding UI code.
3. Pass the merged conventions to the reviewer agent and instruct it to prioritize documented conventions over generic best practices.

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

Filter for UI-relevant files only:

- **Components**: `*.tsx`, `*.jsx`, `*.vue`, `*.svelte`, `*.component.ts`, `*.component.html`
- **Templates**: `*.html`, `*.hbs`, `*.ejs`, `*.pug`
- **Views/Pages**: Files in `pages/`, `views/`, `screens/`, `routes/`, `app/` directories
- **i18n/translations**: `*.json` files in `locales/`, `i18n/`, `translations/` directories

After identifying the changed UI files, discover any additional nested instruction files that apply to those files (for example `AGENTS.md`, `CLAUDE.md`, `.github/copilot-instructions.md`, markdown instruction files in a nearby `.claude/` directory, or tool-specific equivalents) and merge those constraints into the conventions from Step 2 before launching the reviewer agent.

If no UI-relevant files found, reply inline with the following message (regardless of `INLINE_MODE`) and stop. Do not create or update `COPY_REVIEW_OVERVIEW.md`.

```
No UI-relevant files detected in this PR or local working tree.

Changed files: {comma-separated list of file extensions or paths from the unified change scope}

No UI copy to review.
```

### Step 4: Check for Previous Review

If `COPY_REVIEW_OVERVIEW.md` exists in the project root:

- Parse previously addressed findings (file path, line number, issue description, action taken)
- Store for filtering in Step 7

### Step 5: Launch Copy Reviewer Agent

Launch **kramme:copy-reviewer** using the platform's agent-invocation primitive with:

- The resolved `BASE_BRANCH`, `BASE_REF`, and `MERGE_BASE` from Step 3
- Project conventions extracted from the discovered instruction files and established UI patterns
- The list of UI-relevant changed files
- Committed PR diff: `git diff "$MERGE_BASE"...HEAD`
- Staged local diff: `git diff --cached`
- Unstaged local diff: `git diff`
- Untracked local files list: `git ls-files --others --exclude-standard` (agent should treat these as new files and review full file content)
- Instruct the agent to apply the confidence threshold: "Only report findings with confidence >= {custom_threshold}"
- Focus instruction: **"Focus on text redundancy introduced by this diff. For each text element in changed code, evaluate whether the UI already communicates the same information through its structure, icons, or interaction patterns."**

### Step 6: Validate Relevance

After collecting findings from the copy reviewer:

- Launch **kramme:pr-relevance-validator** using the same agent-invocation primitive with all findings and the resolved `BASE_BRANCH`
- Cross-reference each finding against the full review scope (committed PR diff + staged/unstaged/untracked local changes)
- Filter pre-existing issues and out-of-scope problems
- Return only findings caused by this combined scope

If no separate agent runtime is available, perform the same copy review and relevance validation directly in the main thread. If an invoked copy reviewer or relevance validator is unavailable, times out, or returns output that cannot be parsed as findings, surface the failure to the user with the agent name and what was attempted, then stop without writing `COPY_REVIEW_OVERVIEW.md`. Do not fabricate findings or silently continue with an empty result.

### Step 7: Filter Previously Addressed Findings

If `COPY_REVIEW_OVERVIEW.md` was found in Step 4:

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

- **Critical Copy Issues** (must fix before merge) -- only validated findings
- **Important Copy Issues** (should fix) -- only validated findings
- **Copy Suggestions** (nice to have) -- only validated findings
- **Filtered** (pre-existing or out-of-scope) -- shown separately
- **Previously Addressed** -- shown separately
- **Copy Strengths** (what's well-done)

If `INLINE_MODE=true`:

- Reply with the full report inline using the report format from `assets/copy-review-report-format.md`
- Include all sections even if empty (with count of 0)
- Do **not** create or update `COPY_REVIEW_OVERVIEW.md`

Otherwise:

- Write to `COPY_REVIEW_OVERVIEW.md` in the project root using the report format from `assets/copy-review-report-format.md`
- Include all sections even if empty (with count of 0)
- Treat the file as a working artifact that should **not** be committed and can be cleaned up by `/kramme:workflow-artifacts:cleanup`

### Step 9: Provide Action Plan

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
/kramme:pr:copy-review
```

```
/kramme:pr:copy-review --base develop
```

```
/kramme:pr:copy-review --threshold 85
```

```
/kramme:pr:copy-review --inline
```
