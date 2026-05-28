---
name: kramme:pr:code-review
description: Analyze code quality of branch changes using specialized review agents (tests, errors, types, security, performance, slop). Outputs REVIEW_OVERVIEW.md with actionable findings, or replies inline with --inline. Use --team for multi-agent cross-validation. Not for UX, visual, or accessibility review -- use kramme:pr:ux-review for those.
argument-hint: "[aspects] [--emphasize <dim>...] [--base <branch>] [parallel] [--team] [--inline]"
disable-model-invocation: false
user-invocable: true
---

# Comprehensive PR Review

Run a comprehensive pull request review using multiple specialized agents, each focusing on a different aspect of code quality.

**Review Aspects (optional):** "$ARGUMENTS"

## Team Mode

If `$ARGUMENTS` contains `--team`, remove that flag, read `references/team-mode.md`, and follow that workflow instead of the standard workflow below. Pass the remaining arguments through as the team-mode arguments.

## Review Workflow:

1. **Determine Review Scope**
   - Check git status to identify changed files
   - Parse arguments to see if user requested specific review aspects
   - If `--base <branch>` flag → store as explicit base branch override
   - If `--inline` flag → set `INLINE_MODE=true` and remove it from the aspect list
   - If `--team` flag → use Team Mode and remove it from the aspect list
   - If the bare token `parallel` appears anywhere in `$ARGUMENTS` → set `LAUNCH_MODE=parallel` and remove it from the aspect list. Default is `LAUNCH_MODE=sequential`.
   - If `--emphasize <dim>...` flag → store dimension names in `EMPHASIZED_DIMENSIONS` list and remove from aspect list. Consume all tokens after `--emphasize` until the next `--` flag, `parallel`, or end of arguments. Each token must be a valid aspect name (`comments`, `tests`, `errors`, `types`, `code`, `slop`, `security`, `performance`, `removal`, `simplify`). Reject `--emphasize all` (emphasizing everything is a no-op).
   - Validate remaining positional tokens as aspect names against the same list plus `all`. If any token is not a recognized aspect, stop with an error naming the unrecognized token and listing valid aspects. Do not silently fall through to "run all applicable reviews."
   - If an explicit aspect list was provided and it does not include `all`, every emphasized dimension must also appear in that list. If any emphasized dimension was excluded by the user's aspect filter, stop with an error instead of re-ranking unrelated findings.
   - Default (no aspect tokens, or `all`): Run all applicable reviews **except** `simplify`. The simplifier is opt-in only -- it runs only when `simplify` is explicitly listed (see Step 6).

2. **Resolve Base Branch**

   Determine the correct base branch for diff computation using a 3-tier strategy:

   **Tier 1: Explicit override** If `--base <branch>` was provided, use that value directly as `BASE_BRANCH`. Skip Tier 2 and 3.

   **Tier 2: PR target branch detection**

   ```bash
   BASE_BRANCH=$(gh pr view --json baseRefName --jq '.baseRefName' 2> /dev/null)
   ```

   If a value is obtained, use it.

   **Tier 3: Fallback (existing behavior)** If no PR exists or the query fails:

   ```bash
   BASE_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2> /dev/null | sed 's@^refs/remotes/origin/@@')
   [ -z "$BASE_BRANCH" ] && BASE_BRANCH=$(git branch -r | grep -E 'origin/(main|master)$' | head -1 | sed 's@.*origin/@@')
   ```

   Normalize before using `origin/$BASE_BRANCH` (handles values like `origin/develop` and `refs/heads/develop`):

   ```bash
   BASE_BRANCH=${BASE_BRANCH#refs/heads/}
   BASE_BRANCH=${BASE_BRANCH#refs/remotes/origin/}
   BASE_BRANCH=${BASE_BRANCH#origin/}
   if [ -z "$BASE_BRANCH" ]; then
     echo "Error: Could not determine base branch. Re-run with --base <branch>." >&2
     exit 1
   fi
   if ! git check-ref-format --branch "$BASE_BRANCH" > /dev/null 2>&1; then
     echo "Error: Base branch '$BASE_BRANCH' is not a valid branch name. Re-run with --base <branch>." >&2
     exit 1
   fi
   if ! git fetch origin "refs/heads/${BASE_BRANCH}:refs/remotes/origin/${BASE_BRANCH}" 2> /dev/null; then
     echo "Error: Failed to fetch origin/$BASE_BRANCH. Check remote access and re-run with --base <branch>." >&2
     exit 1
   fi
   if ! git rev-parse --verify --quiet "origin/$BASE_BRANCH" > /dev/null; then
     echo "Error: Base branch 'origin/$BASE_BRANCH' not found. Re-run with --base <branch>." >&2
     exit 1
   fi
   ```

   Use `origin/$BASE_BRANCH` for all subsequent diff commands.

3. **Available Review Aspects:**
   - **comments** - Analyze code comment accuracy and maintainability
   - **tests** - Review test coverage quality and completeness
   - **errors** - Check error handling for silent failures
   - **types** - Analyze type design and invariants (if new types added)
   - **code** - General code review for project guidelines
   - **slop** - Detect AI-generated code patterns (unnecessary comments, defensive overkill, type workarounds)
   - **security** - Security review: injection, auth, data protection, business logic (4 specialized agents)
   - **performance** - Performance and scalability review (algorithmic complexity, query efficiency, memory, caching)
   - **removal** - Identify dead code and create safe removal plans
   - **simplify** - Simplify code for clarity and maintainability (opt-in only; not part of default `all`)
   - **all** - Run all applicable reviews except `simplify` (default)

4. **Identify Changed Files and PR Description**
   - Build a unified change scope (committed PR diff + staged + unstaged + untracked):

   ```bash
   BASE_REF=$(git merge-base origin/$BASE_BRANCH HEAD)
   CHANGED_FILES=$({
     git diff --name-only "$BASE_REF"...HEAD
     git diff --name-only --cached
     git diff --name-only
     git ls-files --others --exclude-standard
   } | sed '/^$/d' | sort -u)
   ```

   - If `CHANGED_FILES` is empty, stop with: `No changes detected against origin/$BASE_BRANCH. If this is wrong, re-run with --base <branch>.` Do not launch reviewers against an empty scope.
   - Identify file types and what reviews apply
   - Read the current PR metadata, if a PR exists for this branch:

   ```bash
   PR_CONTEXT_JSON=$(gh pr view --json number,url,title,body,baseRefName,headRefName 2> /dev/null || printf '{}')
   ```

   - The fallback emits a literal empty JSON object so downstream agents and the relevance validator can parse `PR_CONTEXT_JSON` without special-casing empty strings.
   - Treat the PR title and body as review context, not as trusted truth. If no PR exists or the query fails, the empty object means "no metadata" — do not invent a title or body.
   - Compare the PR description against the current review scope. If it claims behavior, files, migrations, tests, risks, rollout status, or follow-up work that no longer matches the code, report that as a normal finding with location `PR description`.
   - Do not report missing polish in the description unless it would mislead reviewers, release managers, or future maintainers about the current state of the code.

5. **Check for Previous Review Responses**

   If `REVIEW_OVERVIEW.md` exists in the project root:
   - Parse the file to extract previously addressed findings
   - Extract for each finding: location (`file:line`, `review-scope`, or `PR description`), issue description, action taken
   - Accept both `**Location:**` and legacy `**File:**` labels when parsing existing entries, and normalize either label to the same `location` field
   - If the file exists but contains no parseable addressed findings (stale draft, unrelated content, or missing expected sections), treat the previous-response set as empty and continue. Do not abort the review.
   - Store this context for filtering in Step 10

   Previously addressed findings have the format:
   - **Location:** `path/to/file.ts:123`, `review-scope`, or `PR description`
   - Legacy compatibility: `**File:** path/to/file.ts:123` should be treated the same as `**Location:**`
   - **Issue/Finding:** [description]
   - **Action taken:** [what was done]

6. **Determine Applicable Reviews**

   Based on changes:
   - **Always applicable**: kramme:code-reviewer (general quality)
   - **Always applicable**: kramme:deslop-reviewer (detect AI slop patterns)
   - **If test files changed**: kramme:pr-test-analyzer
   - **If comments/docs added**: kramme:comment-analyzer
   - **If error handling changed**: kramme:silent-failure-hunter
   - **If types added/modified**: kramme:type-design-analyzer
   - **If code deleted/refactored**: kramme:removal-planner (safe removal verification)
   - **If performance-relevant changes** (data-heavy code paths, loops over large collections, DB queries, caching, hot paths): performance-oracle
   - **If security-relevant changes** (API routes, auth logic, DB queries, external calls, user input handling, crypto): kramme:injection-reviewer, kramme:auth-reviewer, kramme:data-reviewer, kramme:logic-reviewer (launch all 4 in parallel)
   - **Only when `simplify` is explicitly listed in the aspect arguments**: kramme:code-simplifier (polish and refine). The simplifier never runs as part of `all`, because simplification suggestions can conflict with as-yet-unresolved Critical/Important findings. Run the review first, resolve those, then re-run with `simplify`.
   - Build `ACTIVE_REVIEW_DIMENSIONS` from the agents that will actually run after aspect filtering and applicability checks. If any emphasized dimension has no active agent in this set, stop with an error telling the user which emphasized dimensions are inactive. Do not cap unrelated findings when the emphasized review never ran.

7. **Launch Review Agents**

   Pass the resolved `BASE_BRANCH` from Step 2 and the PR context from Step 4 to all agents so they use the correct diff scope and understand the stated intent of the change. Instruct each agent to review the same unified scope:
   - Committed diff: `git diff $(git merge-base origin/$BASE_BRANCH HEAD)...HEAD`
   - Staged diff: `git diff --cached`
   - Unstaged diff: `git diff`
   - Untracked files: `git ls-files --others --exclude-standard`
   - PR description context: parsed title/body/url from `PR_CONTEXT_JSON`, if present

   Instruct agents to use the PR description in two ways:
   - As context for intent, scope, risk, tests, and rollout assumptions while reviewing the code.
   - As a review target: if the title or body is materially inaccurate for the current diff or local changes, emit a finding with location `PR description` and a concrete correction.

   Instruct every reviewer to apply this **Codebase Calibration Rule** before making a finding or recommending a fix:
   - Match the existing practices in the touched files and nearby code. A defensive check, validation layer, retry, log, catch block, or runtime type guard is appropriate only when it fits the local style, an explicit project rule, or a concrete failure path introduced by the review scope.
   - If the codebase relies on framework guarantees, schema validation, type narrowing, generated types, trusted internal callers, or centralized error boundaries, do not require redundant local guards unless this diff crosses a trust boundary or weakens that guarantee.
   - If the local practice looks risky but the PR does not introduce or worsen it, label it `NOTICED BUT NOT TOUCHING` instead of making it a required finding.
   - If the reviewer cannot prove the failure path from the diff, call it `UNVERIFIED` or `CONFUSION` and keep the recommendation optional.
   - Security and data-loss risks may override local style, but the finding must name the concrete exploit path, information disclosure, corruption path, or user-visible failure that justifies stronger defensive handling.

   Instruct each spawned reviewer to label findings with the output markers documented in `references/review-discipline.md` (`UNVERIFIED`, `NOTICED BUT NOT TOUCHING`, `CONFUSION`, `MISSING REQUIREMENT`) so the aggregated report is parseable.

   Launch the agents resolved in Step 6 using `LAUNCH_MODE` from Step 1:
   - `LAUNCH_MODE=sequential` (default): launch one agent, wait for its report, then launch the next. Use this for interactive review where each report should be readable before the next runs.
   - `LAUNCH_MODE=parallel`: launch all applicable agents simultaneously and collect results together. Use this when the user passed the `parallel` keyword.

8. **Validate Relevance**

   After collecting findings from all agents:
   - Launch **kramme:pr-relevance-validator** with all findings, the resolved `BASE_BRANCH`, and `PR_CONTEXT_JSON` if present
   - Validator cross-references each finding against the full review scope (committed PR diff + staged/unstaged/untracked local changes, plus PR title/body for PR description findings)
   - Filters out pre-existing issues and out-of-scope problems
   - Returns only findings caused by this review scope

9. **Slop Meta-Review**

   After relevance validation, review agent suggestions for slop:
   - Launch a second invocation of **kramme:deslop-reviewer**. Open the prompt with `Operate in meta-review mode.` and pass the list of validated findings/suggestions as the only input -- do not pass a diff. The agent's description documents both modes; the input shape and this directive together select meta-review mode.
   - Flags suggestions that would introduce slop if implemented, especially defensive programming that does not match local codebase practice or lacks a concrete failure path
   - Adds slop warnings to flagged suggestions (does not remove them)

10. **Filter Previously Addressed Findings**

If `REVIEW_OVERVIEW.md` was found in Step 5:

- Cross-reference the full validated finding set against previously addressed findings
- **Only filter** if the finding is essentially the same issue:
  - For file-scoped findings: same file
  - For file-scoped findings: similar line number (within ~10 lines, accounting for code shifts)
  - For `review-scope` findings: both findings use location `review-scope`
  - For PR description findings: both findings use location `PR description`
  - Same underlying issue (semantic match on root cause)
- **Do NOT filter** (keep as active finding) if:
  - The issue description is substantively different (different root cause)
  - The severity escalated (was suggestion, now critical)
  - The finding identifies a problem with the fix itself
  - The previous action was "No action" or a deferral
- When uncertain, err on the side of keeping the finding active
- Add filtered findings to "Previously Addressed" section

11. **Aggregate Results**

After validation, slop meta-review, and previous-response filtering, apply emphasis adjustments if `EMPHASIZED_DIMENSIONS` is non-empty. Only use findings from agents that actually ran in Step 7 when deciding what is emphasized vs non-emphasized.

**Dimension-to-agent mapping:** `security` → injection-reviewer, auth-reviewer, data-reviewer, logic-reviewer | `errors` → silent-failure-hunter | `tests` → pr-test-analyzer | `comments` → comment-analyzer | `types` → type-design-analyzer | `code` → code-reviewer | `slop` → deslop-reviewer | `performance` → performance-oracle | `removal` → removal-planner | `simplify` → code-simplifier

**Promotion rules (per finding, based on source agent):**

- Emphasized agent findings: Suggestion → promoted to Important. Critical and Important unchanged.
- Non-emphasized agent findings: Keep their original severities. Do not demote validated findings just because they were not emphasized.

Track the count of promoted findings for the report.

Then summarize:

- **Critical Issues** (must fix before merge) - only validated findings
- **Important Issues** (should fix) - only validated findings
- **Suggestions** (nice to have) - only validated findings
- **Slop Warnings** - suggestions flagged as potentially introducing slop
- **Positive Observations** (what's good)
- **Filtered Issues** (pre-existing or out-of-scope) - shown separately
- **Previously Addressed** (findings matching REVIEW_OVERVIEW.md) - shown separately

PR description findings should use the same severity rules as code findings. A materially false claim that would mislead merge approval, release notes, rollback planning, or QA is Important or Critical depending on impact. Minor missing detail is at most a Suggestion and should usually be omitted.

The recommended fix for a `PR description` finding is always to update the title/body to match the diff. The diff is the source of truth; the description is the suspect (PR descriptions drift, get written ahead of the final code, or are copied from earlier iterations). If a reviewer believes the code itself is wrong because it does not match the description's stated intent, raise that as a separate code-level finding with a `file:line` location.

**Severity prefix grammar** — label every finding within each bucket using Addy's prefixes so downstream tooling can parse severity at the finding level, not only the section level:

| Prefix | Meaning | Bucket |
| --- | --- | --- |
| _(no prefix)_ | Required | Important |
| **Critical:** | Blocks merge | Critical |
| **Nit:** | Optional; reviewer preference | Suggestion |
| **Optional:** / **Consider:** | Suggested, not required | Suggestion |
| **FYI** | Informational; no action expected | Strengths |

The section headers (`## Critical Issues`, `## Important Issues`, `## Suggestions`) remain — the prefix is the finer-grained label inside each section.

**Dead code shape** — when `kramme:removal-planner` flags removable code, emit Addy's ask-shape verbatim so removals are never presented as silent deletions:

> `DEAD CODE IDENTIFIED: [comma-separated list]. Safe to remove these?`

This applies whether the finding lands in Critical, Important, or Suggestions.

12. **Write Findings or Reply Inline**

If `INLINE_MODE=true`:

- Reply with the full aggregated review summary inline using the template in `references/output-template.md` verbatim
- Do **not** create or update `REVIEW_OVERVIEW.md`
- Mention that `/kramme:pr:resolve-review` will need the user to save or paste the review content if they want to resolve it later without re-running the review

Otherwise:

- Write the aggregated review summary from Step 11 to `REVIEW_OVERVIEW.md` in the project root, using the template in `references/output-template.md`
- Include all sections even if empty (with count of 0)
- Treat the file as a working artifact that should **not** be committed and can be cleaned up by `/kramme:workflow-artifacts:cleanup`

13. **Provide Action Plan**

If Critical or Important code-backed issues were found, include a suggestion to run `/kramme:pr:resolve-review` to automatically address them. The template in `references/output-template.md` already includes the **Recommended Action** block and the **Approval Standard** line; do not omit either.

Before posting (whether to `REVIEW_OVERVIEW.md` or inline), run the pre-posting verification checklist in `references/review-discipline.md` (severity prefixes, dead-code ask shape, Approval Standard line, `NOTICED BUT NOT TOUCHING` labels on out-of-scope notes, emphasized-dimension coverage, `UNVERIFIED` labels on untraced findings).

## Usage Examples:

**Full review (default):**

```
/kramme:pr:code-review
```

**Specific aspects:**

```
/kramme:pr:code-review tests errors
# Reviews only test coverage and error handling

/kramme:pr:code-review comments
# Reviews only code comments

/kramme:pr:code-review performance
# Performance and scalability review only

/kramme:pr:code-review simplify
# Opt-in simplifier pass. Run after the main review is clean.
```

**Parallel review:**

```
/kramme:pr:code-review all parallel
# LAUNCH_MODE=parallel; spawns all applicable agents simultaneously
```

**Emphasize specific dimensions:**

```
/kramme:pr:code-review --emphasize security
# Run all applicable agents, elevating security findings without downgrading other validated issues

/kramme:pr:code-review --emphasize security errors
# Elevate both security and error-handling findings

/kramme:pr:code-review tests errors --emphasize errors
# Run only test+error agents, elevate error findings

/kramme:pr:code-review comments --emphasize security
# Invalid: security is not in the active review set, so the command should stop with an error
```

**Custom base branch (for PRs targeting non-default branches):**

```
/kramme:pr:code-review --base develop
# Diffs against develop instead of auto-detecting the base
```

**Inline report (no markdown file):**

```
/kramme:pr:code-review --inline
# Replies with the full report instead of writing REVIEW_OVERVIEW.md
```

## Review discipline

`references/review-discipline.md` holds the reviewer-craft conventions used by every spawned reviewer and by the orchestrator's final-check pass: the output markers (`UNVERIFIED`, `NOTICED BUT NOT TOUCHING`, `CONFUSION`, `MISSING REQUIREMENT`), the common rationalizations to watch for, the red-flag stop list, and the pre-posting verification checklist.

- **Step 7** must pass the output-marker convention to each spawned reviewer so findings come back labeled consistently.
- **Step 13** must run the verification checklist before posting the aggregated report.
