---
name: kramme:pr:ux-review:team
description: Run UX audit using an Agent Team where specialized reviewers (usability, product, visual, accessibility) collaborate, cross-validate findings, and challenge each other. Higher quality than standard UX review but uses more tokens.
argument-hint: "[app-url] [--categories a11y,ux,product,visual] [--threshold 0-100]"
disable-model-invocation: true
user-invocable: true
kramme-platforms: [claude-code]
---

# Team-Based UX Audit

Run a UX audit using Agent Teams. Each reviewer runs as a full teammate with its own context window, able to message other reviewers to cross-validate findings.

**Arguments:** "$ARGUMENTS"

## Prerequisites

This skill requires Agent Teams to be enabled (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`). If teams are not available, print:

```
Agent Teams are not enabled. Run /kramme:pr:ux-review instead, or enable teams:
  Add CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 to settings.json
```

Then stop.

## Workflow

### Step 1: Determine Review Scope

Same as `/kramme:pr:ux-review` Steps 1-6:

1. Parse arguments: `app_url` (starts with `http`), `--categories` filter, `--threshold N`
   - No `parallel` argument — team version is inherently parallel
2. Load project review conventions from `CLAUDE.md` and discovered `AGENTS.md` files
3. Identify UI-relevant changed files via git diff (committed, staged, unstaged, untracked)
4. Check for previous `UX_REVIEW_OVERVIEW.md` and extract previously addressed findings
5. Determine which agents to launch (same logic: always ux/product/visual, conditionally a11y)
6. Detect browser automation capability if `app_url` provided

If no UI-relevant files found, stop with the same message as the base skill.

### Step 2: Spawn UX Review Team

Create a team named `pr-ux-review` and use **delegate mode** (coordination only, no implementation).

Spawn teammates based on applicable review categories. Each teammate receives:
- The git diff commands to run (`git diff $(git merge-base origin/$BASE_BRANCH HEAD)...HEAD`, `git diff --cached`, `git diff`)
- Untracked files list: `git ls-files --others --exclude-standard`
- The list of UI-relevant changed files
- Project conventions extracted from `CLAUDE.md`/`AGENTS.md` (explicitly mention stack requirements like Tailwind or Material Design 3 when present)
- If `app_url` provided: the URL and browser MCP type
- If `custom_threshold` provided: instruct the agent to use this threshold
- Instructions to **message other teammates** when they find cross-cutting UX issues

**Always spawn:**
- **ux-reviewer** -- Usability heuristics and interaction states (mission from `agents/kramme:ux-reviewer.md`)
- **product-reviewer** -- Product thinking and user flow analysis (mission from `agents/kramme:product-reviewer.md`)
- **visual-reviewer** -- Visual consistency and responsive design (mission from `agents/kramme:visual-reviewer.md`)

**Conditionally spawn:**
- **a11y-auditor** -- Accessibility (WCAG 2.1 AA) (mission from `agents/kramme:a11y-auditor.md`)

  Only spawn if accessibility is a project requirement:

  1. Search `CLAUDE.md` and discovered `AGENTS.md` files for keywords: `accessibility`, `a11y`, `WCAG`, `aria`, `screen reader`
  2. Check `package.json` for a11y tooling: `eslint-plugin-jsx-a11y`, `axe-core`, `pa11y`, `@axe-core/*`
  3. Check for `.accessibilityrc`, a11y rules in ESLint/Biome config
  4. If **any signal found** -> a11y is a requirement, spawn the teammate
  5. If **no signal found** -> skip unless user explicitly passes `--categories a11y` or `--categories all`
  6. When skipped, include in output:
     ```
     Note: A11y audit skipped -- no accessibility requirements detected in this project.
     Use `--categories a11y` to run it explicitly.
     ```

**Respect `--categories` filter:**
- If `--categories ux` -> only spawn ux-reviewer
- If `--categories a11y` -> spawn a11y-auditor regardless of detection
- If `--categories product,visual` -> spawn product-reviewer and visual-reviewer
- If `--categories all` -> spawn all 4 teammates (a11y included regardless of detection)
- If no `--categories` flag -> spawn the 3 core teammates + a11y only if detected

### Step 3: Create and Assign Tasks

Create tasks in the shared task list:

**Phase 1 tasks (parallel):**
- One task per reviewer: "Audit [category] in PR changes"
- Assign each task to its corresponding teammate

**Phase 2 task (blocked on all Phase 1 tasks):**
- "Validate finding relevance against PR diff" -- spawn a new **relevance-validator** teammate
- Mission from `agents/kramme:pr-relevance-validator.md`
- Cross-references all findings against the full audit scope (PR diff + staged/unstaged/untracked local changes)
- Filters pre-existing and out-of-scope issues

### Step 4: Monitor and Facilitate

While teammates work:
- Monitor task progress via TaskList
- Relay any questions teammates have about the codebase or PR context
- If a teammate gets stuck, provide additional context or redirect

### Step 5: Collect and Aggregate Results

After all tasks complete:

1. Gather findings from all teammates
2. Apply the relevance-validator's filtering
3. Filter previously addressed findings (same logic as `/kramme:pr:ux-review` Step 9)

### Step 6: Write UX_REVIEW_OVERVIEW.md

Write the aggregated audit to `UX_REVIEW_OVERVIEW.md` using the same format as `/kramme:pr:ux-review` Step 11, with team metadata:

```markdown
# UX Audit Summary (Team Review)

**Mode:** {Code-only | Visual + Code}
**Agents Run:** {list of agents that ran}
**Categories:** {list of categories audited}

## Team
- X reviewers participated
- Relevance validation: X findings validated, X filtered

## Relevance Filter
- X findings validated as in-scope (PR/local)
- X findings filtered (pre-existing or out-of-scope)
- X findings filtered (previously addressed)

## Critical UX Issues (X found)

### {PREFIX}-NNN: {Brief title}

**Agent:** {kramme:ux-reviewer | kramme:product-reviewer | kramme:visual-reviewer | kramme:a11y-auditor}
**Category:** {specific category within agent's domain}
**File:** `path/to/file.tsx:42`
**Confidence:** {0-100}
**User Impact:** High

**Issue:** {Description}

**Recommendation:** {Specific fix}

---

## Important UX Issues (X found)

{Same format}

## UX Suggestions (X found)

{Same format}

## Cross-Review Notes
- [Any disputes or cross-validation results between reviewers]

## Filtered (Pre-existing/Out-of-scope)
<collapsed>
- [file:line]: Brief description - Reason filtered
</collapsed>

## Filtered (Previously Addressed)
<collapsed>
- [file:line]: Brief description
  Matched: UX_REVIEW_OVERVIEW.md - [action taken summary]
</collapsed>

## UX Strengths
- {What's well-done from a UX perspective}

## Recommended Action
1. Fix critical issues first
2. Address important issues
3. Consider suggestions
4. Re-run audit after fixes

**To resolve findings, run:** `/kramme:pr:resolve-review`
```

This file is a working artifact -- it should NOT be committed. It will be cleaned up by `/kramme:workflow-artifacts:cleanup`.

### Step 7: Cleanup

1. Shut down all teammates
2. Clean up the team

## Usage Examples

```
/kramme:pr:ux-review:team
# Full team UX audit with all applicable reviewers

/kramme:pr:ux-review:team http://localhost:3000
# Team UX audit with visual review

/kramme:pr:ux-review:team --categories ux,product
# Team audit focused on specific categories

/kramme:pr:ux-review:team --categories a11y
# Accessibility only (runs regardless of project detection)

/kramme:pr:ux-review:team http://localhost:4200 --categories ux,visual --threshold 85
# Combined: visual mode, specific categories, custom threshold
```

## When to Use This vs `/kramme:pr:ux-review`

Use **this skill** when:
- The PR is large or touches many UI areas
- You want reviewers to cross-validate each other's UX findings
- You want higher-quality findings with fewer false positives
- The PR has both UX and accessibility concerns benefiting from multiple perspectives

Use **`/kramme:pr:ux-review`** when:
- The PR is small or focused
- You want faster, lower-cost review
- You only need one or two review categories
