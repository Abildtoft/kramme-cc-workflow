---
name: kramme:pr:code-review:team
description: Run comprehensive PR review using multi-agent execution where specialized reviewers collaborate, cross-validate findings, and challenge each other. Higher quality than standard review but uses more tokens. Supports inline report output with --inline.
argument-hint: "[aspects] [--base <ref>] [--inline]"
disable-model-invocation: true
user-invocable: true
kramme-platforms: [claude-code, codex]
---

# Team-Based PR Review

Run a comprehensive PR review using multi-agent execution. Each reviewer runs with its own context window and can cross-validate findings with other reviewers.

**Review Aspects (optional):** "$ARGUMENTS"

## Prerequisites

This skill requires multi-agent execution.

- **Claude Code:** Agent Teams must be enabled (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`).
- **Codex:** run in a Codex runtime with `multi_agent` enabled.

If multi-agent execution is not available, print:

```
Multi-agent execution is not enabled. Run /kramme:pr:code-review instead.
Claude Code: add CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 to settings.json.
Codex: use a runtime with `multi_agent` enabled (for example, Conductor Codex runtime).
```

Then stop.

## Workflow

### Step 1: Determine Review Scope

Same as `/kramme:pr:code-review` Steps 1-6:

1. Check git status to identify changed files
2. Parse arguments for specific review aspects (comments, tests, errors, types, code, slop, security, removal, simplify, all), `--base <ref>` override, and optional `--inline` output mode
3. Resolve base branch using 3-tier strategy (explicit `--base` → PR target branch → default branch fallback). See `/kramme:pr:code-review` Step 2 for full logic.
4. Build a unified change scope (committed PR diff + staged + unstaged + untracked):
   ```bash
   BASE_REF=$(git merge-base origin/$BASE_BRANCH HEAD)
   {
     git diff --name-only "$BASE_REF"...HEAD
     git diff --name-only --cached
     git diff --name-only
     git ls-files --others --exclude-standard
   } | sed '/^$/d' | sort -u
   ```
5. Check for previous `REVIEW_OVERVIEW.md` and extract previously addressed findings
6. Determine applicable reviews based on changes

### Step 2: Spawn Review Agents

Create a multi-agent review session named `pr-review` and use **delegate mode** (coordination only, no implementation).

- **Claude Code:** create an Agent Team.
- **Codex:** launch equivalent parallel review agents via multi-agent mode.

Spawn teammates based on applicable review aspects. Each teammate receives:
- The resolved base branch and diff commands to run (`git diff $(git merge-base origin/$BASE_BRANCH HEAD)...HEAD`, `git diff --cached`, `git diff`, `git ls-files --others --exclude-standard`)
- Their specific review mission (from the corresponding agent definition in `agents/`)
- Instructions to **message other teammates** when they find cross-cutting issues

**Always spawn:**
- **code-reviewer** -- General code quality and project instruction compliance (mission from `agents/kramme:code-reviewer.md`)
- **silent-failure-hunter** -- Error handling and silent failures (mission from `agents/kramme:silent-failure-hunter.md`)
- **deslop-reviewer** -- AI slop pattern detection (mission from `agents/kramme:deslop-reviewer.md`)

**Conditionally spawn:**
- **performance-oracle** -- If performance-relevant changes detected (mission from `agents/kramme:performance-oracle.md`)
- **pr-test-analyzer** -- If test files changed or new functionality added (mission from `agents/kramme:pr-test-analyzer.md`)
- **type-design-analyzer** -- If new types added or modified (mission from `agents/kramme:type-design-analyzer.md`)
- **comment-analyzer** -- If significant comments or docs added (mission from `agents/kramme:comment-analyzer.md`)
- **injection-reviewer** -- If security-relevant changes detected (API routes, auth logic, DB queries, external calls, user input handling, crypto) (mission from `agents/kramme:injection-reviewer.md`)
- **auth-reviewer** -- If security-relevant changes detected (mission from `agents/kramme:auth-reviewer.md`)
- **data-reviewer** -- If security-relevant changes detected (mission from `agents/kramme:data-reviewer.md`)
- **logic-reviewer** -- If security-relevant changes detected (mission from `agents/kramme:logic-reviewer.md`)

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
- "Validate finding relevance against full review scope" -- spawn a new **relevance-validator** teammate
- Mission from `agents/kramme:pr-relevance-validator.md`
- Pass the resolved `BASE_BRANCH` from Step 1 so relevance validation uses the same PR base
- Cross-references all findings against the full review scope (committed PR diff + staged/unstaged/untracked local changes)
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
4. Filter previously addressed findings (same logic as `/kramme:pr:code-review` Step 10)

### Step 6: Write REVIEW_OVERVIEW.md or Reply Inline

If `INLINE_MODE=true`, reply with the aggregated review inline using the same template and conventions as `/kramme:pr:code-review` Steps 11-13, and do **not** create or update `REVIEW_OVERVIEW.md`.

Otherwise, write the aggregated review to `REVIEW_OVERVIEW.md` using the same template and conventions as `/kramme:pr:code-review` Steps 11-13.

Keep the output schema-compatible with the standard PR review:
- Keep the same severity prefix grammar (`Critical:`, `Nit:`, `Optional:`, `Consider:`, `FYI`)
- Use `NOTICED BUT NOT TOUCHING` for pre-existing or out-of-scope notes
- Include the `## Approval Standard` section verbatim

Fold team-specific context into the existing schema instead of inventing a separate report shape:
- Add reviewer count, cross-review completion, and dispute notes as `**FYI**` bullets in `## Strengths`
- When a finding came from a specific reviewer, use that reviewer name in place of `[agent-name]` inside the shared template

### Step 7: Cleanup

1. Shut down all review agents
2. Clean up the multi-agent session

## Usage Examples

```
/kramme:pr:code-review:team
# Full team review with all applicable reviewers

/kramme:pr:code-review:team code errors tests
# Team review focused on specific aspects

/kramme:pr:code-review:team --inline
# Team review that replies inline instead of writing REVIEW_OVERVIEW.md
```

## When to Use This vs `/kramme:pr:code-review`

Use **this skill** when:
- The PR is large or touches many areas
- You want reviewers to cross-validate each other's findings
- The PR has security-sensitive changes that benefit from multiple perspectives
- You want higher-quality findings with fewer false positives

Use **`/kramme:pr:code-review`** when:
- The PR is small or focused
- You want faster, lower-cost review
- You only need one or two review aspects
