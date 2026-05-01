---
name: kramme:pr:code-review
description: Analyze code quality of branch changes using specialized review agents (tests, errors, types, security, slop). Outputs REVIEW_OVERVIEW.md with actionable findings, or replies inline with --inline.
argument-hint: "[aspects] [--emphasize <dim>...] [--base <branch>] [parallel] [--inline]"
disable-model-invocation: false
user-invocable: true
---

# Comprehensive PR Review

Run a comprehensive pull request review using multiple specialized agents, each focusing on a different aspect of code quality.

**Review Aspects (optional):** "$ARGUMENTS"

## Review Workflow:

1. **Determine Review Scope**
   - Check git status to identify changed files
   - Parse arguments to see if user requested specific review aspects
   - If `--base <branch>` flag → store as explicit base branch override
   - If `--inline` flag → set `INLINE_MODE=true` and remove it from the aspect list
   - If `--emphasize <dim>...` flag → store dimension names in `EMPHASIZED_DIMENSIONS` list and remove from aspect list. Consume all tokens after `--emphasize` until the next `--` flag, `parallel`, or end of arguments. Each token must be a valid aspect name (`comments`, `tests`, `errors`, `types`, `code`, `slop`, `security`, `removal`, `simplify`). Reject `--emphasize all` (emphasizing everything is a no-op).
   - If an explicit aspect list was provided and it does not include `all`, every emphasized dimension must also appear in that list. If any emphasized dimension was excluded by the user's aspect filter, stop with an error instead of re-ranking unrelated findings.
   - Default: Run all applicable reviews

2. **Resolve Base Branch**

   Determine the correct base branch for diff computation using a 3-tier strategy:

   **Tier 1: Explicit override**
   If `--base <branch>` was provided, use that value directly as `BASE_BRANCH`. Skip Tier 2 and 3.

   **Tier 2: PR target branch detection**
   ```bash
   BASE_BRANCH=$(gh pr view --json baseRefName --jq '.baseRefName' 2>/dev/null)
   ```

   If a value is obtained, use it.

   **Tier 3: Fallback (existing behavior)**
   If no PR exists or the query fails:
   ```bash
   BASE_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
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
   if ! git check-ref-format --branch "$BASE_BRANCH" >/dev/null 2>&1; then
     echo "Error: Base branch '$BASE_BRANCH' is not a valid branch name. Re-run with --base <branch>." >&2
     exit 1
   fi
   if ! git fetch origin "refs/heads/${BASE_BRANCH}:refs/remotes/origin/${BASE_BRANCH}" 2>/dev/null; then
     echo "Error: Failed to fetch origin/$BASE_BRANCH. Check remote access and re-run with --base <branch>." >&2
     exit 1
   fi
   if ! git rev-parse --verify --quiet "origin/$BASE_BRANCH" >/dev/null; then
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
   - **removal** - Identify dead code and create safe removal plans
   - **simplify** - Simplify code for clarity and maintainability
   - **all** - Run all applicable reviews (default)

4. **Identify Changed Files and PR Description**
   - Build a unified change scope (committed PR diff + staged + unstaged + untracked):
   ```bash
   BASE_REF=$(git merge-base origin/$BASE_BRANCH HEAD)
   {
     git diff --name-only "$BASE_REF"...HEAD
     git diff --name-only --cached
     git diff --name-only
     git ls-files --others --exclude-standard
   } | sed '/^$/d' | sort -u
   ```
   - Identify file types and what reviews apply
   - Read the current PR metadata, if a PR exists for this branch:
   ```bash
   PR_CONTEXT_JSON=$(gh pr view --json number,url,title,body,baseRefName,headRefName 2>/dev/null || true)
   ```
   - Treat the PR title and body as review context, not as trusted truth. If no PR exists or the query fails, proceed with an empty PR context and do not invent one.
   - Compare the PR description against the current review scope. If it claims behavior, files, migrations, tests, risks, rollout status, or follow-up work that no longer matches the code, report that as a normal finding with location `PR description`.
   - Do not report missing polish in the description unless it would mislead reviewers, release managers, or future maintainers about the current state of the code.

5. **Check for Previous Review Responses**

   If `REVIEW_OVERVIEW.md` exists in the project root:
   - Parse the file to extract previously addressed findings
   - Extract for each finding: location (`file:line`, `review-scope`, or `PR description`), issue description, action taken
   - Accept both `**Location:**` and legacy `**File:**` labels when parsing existing entries, and normalize either label to the same `location` field
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
   - **If security-relevant changes** (API routes, auth logic, DB queries, external calls, user input handling, crypto): kramme:injection-reviewer, kramme:auth-reviewer, kramme:data-reviewer, kramme:logic-reviewer (launch all 4 in parallel)
   - **After passing review**: kramme:code-simplifier (polish and refine)
   - Build `ACTIVE_REVIEW_DIMENSIONS` from the agents that will actually run after aspect filtering and applicability checks. If any emphasized dimension has no active agent in this set, stop with an error telling the user which emphasized dimensions are inactive. Do not cap unrelated findings when the emphasized review never ran.

7. **Launch Review Agents**

   Pass the resolved `BASE_BRANCH` from Step 2 and the PR context from Step 4 to all agents so they use the correct diff scope and understand the stated intent of the change.
   Instruct each agent to review the same unified scope:
   - Committed diff: `git diff $(git merge-base origin/$BASE_BRANCH HEAD)...HEAD`
   - Staged diff: `git diff --cached`
   - Unstaged diff: `git diff`
   - Untracked files: `git ls-files --others --exclude-standard`
   - PR description context: parsed title/body/url from `PR_CONTEXT_JSON`, if present

   Instruct agents to use the PR description in two ways:
   - As context for intent, scope, risk, tests, and rollout assumptions while reviewing the code.
   - As a review target: if the title or body is materially inaccurate for the current diff or local changes, emit a finding with location `PR description` and a concrete correction.

   **Sequential approach** (one at a time):
   - Easier to understand and act on
   - Each report is complete before next
   - Good for interactive review

   **Parallel approach** (user can request):
   - Launch all agents simultaneously
   - Faster for comprehensive review
   - Results come back together

8. **Validate Relevance**

   After collecting findings from all agents:
   - Launch **kramme:pr-relevance-validator** with all findings, the resolved `BASE_BRANCH`, and `PR_CONTEXT_JSON` if present
   - Validator cross-references each finding against the full review scope (committed PR diff + staged/unstaged/untracked local changes, plus PR title/body for PR description findings)
   - Filters out pre-existing issues and out-of-scope problems
   - Returns only findings caused by this review scope

9. **Slop Meta-Review**

   After relevance validation, review agent suggestions for slop:
   - Launch **kramme:deslop-reviewer** in meta-review mode
   - Pass all validated findings/suggestions from other agents
   - Flags suggestions that would introduce slop if implemented
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

   **Dimension-to-agent mapping:**
   `security` → injection-reviewer, auth-reviewer, data-reviewer, logic-reviewer | `errors` → silent-failure-hunter | `tests` → pr-test-analyzer | `comments` → comment-analyzer | `types` → type-design-analyzer | `code` → code-reviewer | `slop` → deslop-reviewer | `removal` → removal-planner | `simplify` → code-simplifier

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

   **Severity prefix grammar** — label every finding within each bucket using Addy's prefixes so downstream tooling can parse severity at the finding level, not only the section level:

   | Prefix | Meaning | Bucket |
   |---|---|---|
   | *(no prefix)* | Required | Important |
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

/kramme:pr:code-review simplify
# Simplifies code after passing review
```

**Parallel review:**
```
/kramme:pr:code-review all parallel
# Launches all agents in parallel
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

## Agent Descriptions:

**kramme:comment-analyzer**:
- Verifies comment accuracy vs code
- Identifies comment rot
- Checks documentation completeness

**kramme:pr-test-analyzer**:
- Reviews behavioral test coverage
- Identifies critical gaps
- Evaluates test quality

**kramme:silent-failure-hunter**:
- Finds silent failures
- Reviews catch blocks
- Checks error logging

**kramme:type-design-analyzer**:
- Analyzes type encapsulation
- Reviews invariant expression
- Rates type design quality

**kramme:code-reviewer**:
- Checks project instruction compliance
- Detects bugs and issues
- Reviews general code quality

**kramme:deslop-reviewer**:
- Detects AI-generated code patterns
- Flags unnecessary comments, defensive overkill, type workarounds
- Meta-reviews other agents' suggestions for slop potential

**kramme:code-simplifier**:
- Simplifies complex code
- Improves clarity and readability
- Applies project standards
- Preserves functionality

**kramme:pr-relevance-validator**:
- Validates findings against full review scope (committed + local)
- Filters pre-existing issues
- Filters out-of-scope problems
- Ensures review focuses on in-scope changes

**kramme:removal-planner**:
- Identifies dead code and unused dependencies
- Verifies safe removal with reference searches
- Creates structured removal plans
- Distinguishes safe vs deferred removals

**kramme:injection-reviewer**:
- SQL, command, template, header injection
- XSS and output escaping
- Input sanitization verification

**kramme:auth-reviewer**:
- Authentication and authorization checks
- IDOR and privilege escalation
- CSRF protection and session management

**kramme:data-reviewer**:
- Cryptographic misuse and secret exposure
- Information disclosure in errors and logs
- DoS vectors and resource exhaustion

**kramme:logic-reviewer**:
- Business logic flaws and edge cases
- Race conditions and TOCTOU bugs
- Numeric overflow and state machine violations

## Tips:

- **Run early**: Before creating PR, not after
- **Focus on changes**: Agents analyze git diff by default
- **Address critical first**: Fix high-priority issues before lower priority
- **Re-run after fixes**: Verify issues are resolved
- **Use specific reviews**: Target specific aspects when you know the concern

## Workflow Integration:

**Before committing:**
```
1. Write code
2. Run: /kramme:pr:code-review code errors
3. Fix any critical issues
4. Commit
```

**Before creating PR:**
```
1. Stage all changes
2. Run: /kramme:pr:code-review all
3. Address all critical and important issues
4. Run specific reviews again to verify
5. Create PR
```

**After PR feedback:**
```
1. Make requested changes
2. Run targeted reviews based on feedback
3. Verify issues are resolved
4. Push updates
```

## Notes:

- Agents run autonomously and return detailed reports
- Each agent focuses on its specialty for deep analysis
- Results are actionable with specific locations (usually `file:line`, sometimes `review-scope` or `PR description`)
- Agents use appropriate models for their complexity
- All agents available in `/agents` list

## Review speed norm

One business day is the **maximum** time a PR should sit waiting on review, not the target. If the review slips past a day, the diff stales, the author context-switches, and the eventual review skews toward nitpicks because the reviewer is working against the PR instead of with the author.

## Output markers

Use these markers so the user (and downstream tooling) can skim status at a glance. They are a **plugin-wide convention** for Addy-ported skills. Use them verbatim (uppercase, no decoration), one marker per line.

- **UNVERIFIED** — a finding asserted but not directly confirmed against the code. `UNVERIFIED: agent flagged a race on cache invalidation; I didn't trace all callsites`.
- **NOTICED BUT NOT TOUCHING** — a pre-existing issue or out-of-scope observation surfaced during review. `NOTICED BUT NOT TOUCHING: the whole retry helper swallows errors, but that's outside this PR`.
- **CONFUSION** — the reviewer can't decide whether something is a bug without more context. `CONFUSION: the nullable return from getUser() is new here; is None a valid result or a missing check?`
- **MISSING REQUIREMENT** — spec or intent is ambiguous; a product decision is needed before the review can complete. `MISSING REQUIREMENT: no guidance on how to handle the duplicate-email case — ask before approving`.

---

## Common rationalizations

Watch for these excuses — they signal the review is slipping into low-value territory.

| Excuse | Reality |
|---|---|
| "It's just a nit, skip it." | Nits compound across reviews; ship the `Nit:` prefix and let the author decide, or the diff drifts on every PR. |
| "This doesn't block merge, so it's fine." | "Doesn't block" is not "good." Approve only if the change definitely improves overall code health. |
| "AI wrote it, and the tests pass." | AI-generated code needs more scrutiny, not less — it's confident even when wrong. Read the diff as if a new hire wrote it under deadline. |
| "We can clean this up in a follow-up." | Follow-ups are negotiable; the diff on screen is not. Land the cleanup or mark it `Critical:` now. |
| "I'll re-review when they push again." | Re-review is a checkpoint, not a finding delivery mechanism. Surface every finding on the first pass or they rot across round-trips. |

---

## Red Flags — STOP

If any of these are true, pause and re-scope the review before posting it:

- Every finding you're about to post is marked **Critical:** — the bucket has lost meaning; re-triage.
- The review is older than the PR (you've been reviewing longer than the author spent writing).
- You're rewriting the PR in your head instead of reviewing the diff in front of you.
- You're flagging style issues the project doesn't enforce anywhere else.
- You're approving because the CI is green, not because the change definitely improves overall code health.
- A dead-code finding is phrased as an instruction (`"delete X"`) instead of the ask shape (`DEAD CODE IDENTIFIED: X. Safe to remove these?`).
- You have no `FYI` in the Strengths section — a review with zero positive observations is usually miscalibrated, not comprehensive.

---

## Verification

Before posting the review, confirm:

- [ ] Every finding has a severity prefix (`Critical:`, `Nit:`, `Optional:`, `Consider:`, `FYI`, or no prefix for Required).
- [ ] Dead-code findings use the verbatim ask shape `DEAD CODE IDENTIFIED: [list]. Safe to remove these?`
- [ ] The Approval Standard line appears: *"Approve if the change definitely improves overall code health."*
- [ ] Pre-existing or out-of-scope observations are labeled `NOTICED BUT NOT TOUCHING`.
- [ ] Every emphasized dimension in `--emphasize` actually produced findings in this review (or you noted that it didn't).
- [ ] No finding is presented as certain when the reviewer didn't trace it — those are labeled `UNVERIFIED`.
