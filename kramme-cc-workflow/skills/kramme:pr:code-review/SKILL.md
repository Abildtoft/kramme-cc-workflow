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

   **Tier 2: PR/MR target branch detection**
   Detect the hosting platform and query for the actual target branch:
   ```bash
   REMOTE_URL=$(git remote get-url origin 2>/dev/null)
   if printf '%s' "$REMOTE_URL" | grep -q 'github.com' && command -v gh >/dev/null 2>&1; then
     BASE_BRANCH=$(gh pr view --json baseRefName --jq '.baseRefName' 2>/dev/null)
   elif printf '%s' "$REMOTE_URL" | grep -qi 'gitlab' && command -v glab >/dev/null 2>&1; then
     BASE_BRANCH=$(glab mr view --json target_branch --jq '.target_branch' 2>/dev/null)
   elif command -v glab >/dev/null 2>&1; then
     BASE_BRANCH=$(glab mr view --json target_branch --jq '.target_branch' 2>/dev/null)
   fi
   ```

   **GitLab (MCP, if glab unavailable):**
   Use `mcp__gitlab__get_merge_request` and extract `target_branch`.

   If a value is obtained, use it.

   **Tier 3: Fallback (existing behavior)**
   If no PR/MR exists or the query fails:
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

4. **Identify Changed Files**
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

5. **Check for Previous Review Responses**

   If `REVIEW_OVERVIEW.md` exists in the project root:
   - Parse the file to extract previously addressed findings
   - Extract for each finding: file path, line number, issue description, action taken
   - Store this context for filtering in Step 10

   Previously addressed findings have the format:
   - **File:** `path/to/file.ts:123`
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

   Pass the resolved `BASE_BRANCH` from Step 2 to all agents so they use the correct diff scope.
   Instruct each agent to review the same unified scope:
   - Committed diff: `git diff $(git merge-base origin/$BASE_BRANCH HEAD)...HEAD`
   - Staged diff: `git diff --cached`
   - Unstaged diff: `git diff`
   - Untracked files: `git ls-files --others --exclude-standard`

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
   - Launch **kramme:pr-relevance-validator** with all findings and the resolved `BASE_BRANCH`
   - Validator cross-references each finding against the full review scope (committed PR diff + staged/unstaged/untracked local changes)
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
   - Cross-reference validated findings against previously addressed findings
   - **Only filter** if the finding is essentially the same issue:
     - Same file
     - Similar line number (within ~10 lines, accounting for code shifts)
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

   **Promotion/capping rules (per finding, based on source agent):**
   - Emphasized agent findings: Suggestion → promoted to Important. Critical and Important unchanged.
   - Non-emphasized agent findings: Important → capped to Suggestion. Critical unchanged (never hide critical issues). Suggestion unchanged.

   Track counts of promoted and capped findings for the report.

   Then summarize:
   - **Critical Issues** (must fix before merge) - only validated findings
   - **Important Issues** (should fix) - only validated findings
   - **Suggestions** (nice to have) - only validated findings
   - **Slop Warnings** - suggestions flagged as potentially introducing slop
   - **Positive Observations** (what's good)
   - **Filtered Issues** (pre-existing or out-of-scope) - shown separately
   - **Previously Addressed** (findings matching REVIEW_OVERVIEW.md) - shown separately

12. **Write Findings or Reply Inline**

   If `INLINE_MODE=true`:
   - Reply with the full aggregated review summary inline using the exact format below
   - Do **not** create or update `REVIEW_OVERVIEW.md`
   - Mention that `/kramme:pr:resolve-review` will need the user to save or paste the review content if they want to resolve it later without re-running the review

   Otherwise:
   - Write the aggregated review summary from Step 11 to `REVIEW_OVERVIEW.md` in the project root, using the format below
   - Include all sections even if empty (with count of 0)
   - Treat the file as a working artifact that should **not** be committed and can be cleaned up by `/kramme:workflow-artifacts:cleanup`

13. **Provide Action Plan**

   If Critical or Important issues were found, include a suggestion to run `/kramme:pr:resolve-review` to automatically address them.

   Organize findings:
   ```markdown
   # PR Review Summary

   ## Relevance Filter
   - X findings validated as PR-caused
   - X findings filtered (pre-existing or out-of-scope)
   - X findings filtered (previously addressed in REVIEW_OVERVIEW.md)

   ## Emphasis Applied (omit section if no emphasis)
   - Emphasized: security, errors
   - Findings promoted (Suggestion → Important): X
   - Findings capped (Important → Suggestion): X

   ## Critical Issues (X found)
   - [agent-name]: Issue description [file:line]

   ## Important Issues (X found)
   - [agent-name]: Issue description [file:line]

   ## Suggestions (X found)
   - [agent-name]: Suggestion [file:line]

   ## Slop Warnings (X found)
   - [agent-name]: Suggestion [file:line]
     Warning: Would introduce [slop-type] - [explanation]

   ## Filtered (Pre-existing/Out-of-scope)
   <collapsed>
   - [file:line]: Brief description - Reason filtered
   </collapsed>

   ## Filtered (Previously Addressed)
   <collapsed>
   - [file:line]: Brief description
     Matched: REVIEW_OVERVIEW.md - [action taken summary]
   </collapsed>

   ## Strengths
   - What's well-done in this PR

   ## Recommended Action
   1. Fix critical issues first
   2. Address important issues
   3. Consider suggestions
   4. Re-run review after fixes

   **To automatically resolve findings, run:** `/kramme:pr:resolve-review`
   ```

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
# Run all applicable agents, but elevate security findings and quiet others

/kramme:pr:code-review --emphasize security errors
# Elevate both security and error-handling findings

/kramme:pr:code-review tests errors --emphasize errors
# Run only test+error agents, elevate error findings

/kramme:pr:code-review comments --emphasize security
# Invalid: security is not in the active review set, so the command should stop with an error
```

**Custom base branch (for MRs targeting non-default branches):**
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
- Checks CLAUDE.md compliance
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
- Results are actionable with specific file:line references
- Agents use appropriate models for their complexity
- All agents available in `/agents` list
