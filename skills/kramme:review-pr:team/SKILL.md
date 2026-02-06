---
name: kramme:review-pr:team
description: Run comprehensive PR review using an Agent Team where specialized reviewers collaborate, cross-validate findings, and challenge each other. Higher quality than standard review but uses more tokens.
disable-model-invocation: true
user-invocable: true
kramme-platforms: [claude-code]
---

# Team-Based PR Review

Run a comprehensive PR review using Agent Teams. Each reviewer runs as a full teammate with its own context window, able to message other reviewers to cross-validate findings.

**Review Aspects (optional):** "$ARGUMENTS"

## Prerequisites

This skill requires Agent Teams to be enabled (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`). If teams are not available, print:

```
Agent Teams are not enabled. Run /kramme:review-pr instead, or enable teams:
  Add CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 to settings.json
```

Then stop.

## Workflow

### Step 1: Determine Review Scope

Same as `/kramme:review-pr` Steps 1-5:

1. Check git status to identify changed files
2. Parse arguments for specific review aspects (comments, tests, errors, types, code, slop, removal, simplify, all)
3. Run `git diff --name-only` to see modified files
4. Check for previous `REVIEW_OVERVIEW.md` and extract previously addressed findings
5. Determine applicable reviews based on changes

### Step 2: Spawn Review Team

Create a team named `pr-review` and use **delegate mode** (coordination only, no implementation).

Spawn teammates based on applicable review aspects. Each teammate receives:
- The git diff command to run (`git diff origin/$BASE_BRANCH...HEAD`)
- Their specific review mission (from the corresponding agent definition in `agents/`)
- Instructions to **message other teammates** when they find cross-cutting issues

**Always spawn:**
- **code-reviewer** -- General code quality and CLAUDE.md compliance (mission from `agents/kramme:code-reviewer.md`)
- **silent-failure-hunter** -- Error handling and silent failures (mission from `agents/kramme:silent-failure-hunter.md`)
- **deslop-reviewer** -- AI slop pattern detection (mission from `agents/kramme:deslop-reviewer.md`)

**Conditionally spawn:**
- **performance-oracle** -- If performance-relevant changes detected (mission from `agents/kramme:performance-oracle.md`)
- **pr-test-analyzer** -- If test files changed or new functionality added (mission from `agents/kramme:pr-test-analyzer.md`)
- **type-design-analyzer** -- If new types added or modified (mission from `agents/kramme:type-design-analyzer.md`)
- **comment-analyzer** -- If significant comments or docs added (mission from `agents/kramme:comment-analyzer.md`)

### Step 3: Create and Assign Tasks

Create tasks in the shared task list:

**Phase 1 tasks (parallel):**
- One task per reviewer: "Review [aspect] in PR changes"
- Assign each task to its corresponding teammate

**Phase 2 task (blocked on all Phase 1 tasks):**
- "Cross-review: meta-review all findings for slop" -- assigned to deslop-reviewer
- The deslop-reviewer reads all other teammates' findings and operates in meta-review mode
- Messages individual reviewers if their suggestions would introduce slop

**Phase 3 task (blocked on Phase 2):**
- "Validate finding relevance against PR diff" -- spawn a new **relevance-validator** teammate
- Mission from `agents/kramme:pr-relevance-validator.md`
- Cross-references all findings against the PR diff
- Filters pre-existing and out-of-scope issues

### Step 4: Monitor and Facilitate

While teammates work:
- Monitor task progress via TaskList
- Relay any questions teammates have about the codebase or PR context
- If a teammate gets stuck, provide additional context or redirect

### Step 5: Collect and Aggregate Results

After all tasks complete:

1. Gather findings from all teammates
2. Apply the deslop-reviewer's meta-review annotations
3. Apply the relevance-validator's filtering
4. Filter previously addressed findings (same logic as `/kramme:review-pr` Step 9)

### Step 6: Write REVIEW_OVERVIEW.md

Write the aggregated review to `REVIEW_OVERVIEW.md` using the same format as `/kramme:review-pr` Step 10-12:

```markdown
# PR Review Summary (Team Review)

## Team
- X reviewers participated
- Cross-review: deslop meta-review completed
- Relevance validation: X findings validated, X filtered

## Relevance Filter
- X findings validated as PR-caused
- X findings filtered (pre-existing or out-of-scope)
- X findings filtered (previously addressed in REVIEW_OVERVIEW.md)

## Critical Issues (X found)
- [reviewer-name]: Issue description [file:line]

## Important Issues (X found)
- [reviewer-name]: Issue description [file:line]

## Suggestions (X found)
- [reviewer-name]: Suggestion [file:line]

## Slop Warnings (X found)
- [reviewer-name]: Suggestion [file:line]
  Warning: Would introduce [slop-type] - [explanation]

## Cross-Review Notes
- [Any disputes or cross-validation results between reviewers]

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

**To automatically resolve findings, run:** `/kramme:resolve-review`
```

### Step 7: Cleanup

1. Shut down all teammates
2. Clean up the team

## Usage Examples

```
/kramme:review-pr:team
# Full team review with all applicable reviewers

/kramme:review-pr:team code errors tests
# Team review focused on specific aspects
```

## When to Use This vs `/kramme:review-pr`

Use **this skill** when:
- The PR is large or touches many areas
- You want reviewers to cross-validate each other's findings
- The PR has security-sensitive changes that benefit from multiple perspectives
- You want higher-quality findings with fewer false positives

Use **`/kramme:review-pr`** when:
- The PR is small or focused
- You want faster, lower-cost review
- You only need one or two review aspects
