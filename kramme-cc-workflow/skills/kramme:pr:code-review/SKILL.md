---
name: kramme:pr:code-review
description: Run a comprehensive pull request review using multiple specialized agents, each focusing on a different aspect of code quality.
disable-model-invocation: true
user-invocable: true
---

# Comprehensive PR Review

Run a comprehensive pull request review using multiple specialized agents, each focusing on a different aspect of code quality.

**Review Aspects (optional):** "$ARGUMENTS"

## Review Workflow:

1. **Determine Review Scope**
   - Check git status to identify changed files
   - Parse arguments to see if user requested specific review aspects
   - Default: Run all applicable reviews

2. **Available Review Aspects:**

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

3. **Identify Changed Files**
   - Run `git diff --name-only` to see modified files
   - Check if PR already exists: `gh pr view`
   - Identify file types and what reviews apply

4. **Check for Previous Review Responses**

   If `REVIEW_OVERVIEW.md` exists in the project root:
   - Parse the file to extract previously addressed findings
   - Extract for each finding: file path, line number, issue description, action taken
   - Store this context for filtering in Step 9

   Previously addressed findings have the format:
   - **File:** `path/to/file.ts:123`
   - **Issue/Finding:** [description]
   - **Action taken:** [what was done]

5. **Determine Applicable Reviews**

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

6. **Launch Review Agents**

   **Sequential approach** (one at a time):
   - Easier to understand and act on
   - Each report is complete before next
   - Good for interactive review

   **Parallel approach** (user can request):
   - Launch all agents simultaneously
   - Faster for comprehensive review
   - Results come back together

7. **Validate Relevance**

   After collecting findings from all agents:
   - Launch **kramme:pr-relevance-validator** with all findings
   - Validator cross-references each finding against the PR diff
   - Filters out pre-existing issues and out-of-scope problems
   - Returns only findings caused by this PR

8. **Slop Meta-Review**

   After relevance validation, review agent suggestions for slop:
   - Launch **kramme:deslop-reviewer** in meta-review mode
   - Pass all validated findings/suggestions from other agents
   - Flags suggestions that would introduce slop if implemented
   - Adds slop warnings to flagged suggestions (does not remove them)

9. **Filter Previously Addressed Findings**

   If `REVIEW_OVERVIEW.md` was found in Step 4:
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

10. **Aggregate Results**

   After validation, slop meta-review, and previous-response filtering, summarize:
   - **Critical Issues** (must fix before merge) - only validated findings
   - **Important Issues** (should fix) - only validated findings
   - **Suggestions** (nice to have) - only validated findings
   - **Slop Warnings** - suggestions flagged as potentially introducing slop
   - **Positive Observations** (what's good)
   - **Filtered Issues** (pre-existing or out-of-scope) - shown separately
   - **Previously Addressed** (findings matching REVIEW_OVERVIEW.md) - shown separately

11. **Write Findings to File**

   Write the aggregated review summary from Step 10 to `REVIEW_OVERVIEW.md` in the project root, using the format from the template below. Include all sections even if empty (with count of 0).

   This file is a working artifact — it should NOT be committed. It will be cleaned up by `/kramme:workflow-artifacts:cleanup`.

12. **Provide Action Plan**

   If Critical or Important issues were found, include a suggestion to run `/kramme:pr:resolve-review` to automatically address them.

   Organize findings:
   ```markdown
   # PR Review Summary

   ## Relevance Filter
   - X findings validated as PR-caused
   - X findings filtered (pre-existing or out-of-scope)
   - X findings filtered (previously addressed in REVIEW_OVERVIEW.md)

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
- Validates findings against PR diff
- Filters pre-existing issues
- Filters out-of-scope problems
- Ensures review focuses on PR changes

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
