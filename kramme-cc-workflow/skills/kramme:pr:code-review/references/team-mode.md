# Team-Based PR Review

Run a comprehensive PR review using multi-agent execution. Each reviewer runs with its own context window and can cross-validate findings with other reviewers.

This reference is loaded by `/kramme:pr:code-review --team`; assume `--team` has already been removed from `$ARGUMENTS`.

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

Same setup as `/kramme:pr:code-review` Steps 1-7:

1. Check git status to identify changed files
2. Parse arguments for specific review aspects (comments, tests, errors, types, code, slop, security, performance, removal, refactor, simplify, all), `--emphasize <dim>...`, `--base <ref>` override, optional `--previous-review <path>` previous-cycle source, and optional `--inline` output mode. Reject `--previous-review` if the path is missing, points to a directory, or cannot be read.
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
5. Read current PR metadata, if a PR exists for this branch:
   ```bash
   PR_CONTEXT_JSON=$(gh pr view --json number,url,title,body,baseRefName,headRefName 2> /dev/null || printf '{}')
   ```
   The fallback emits a literal empty JSON object so downstream agents and the relevance validator can parse `PR_CONTEXT_JSON` without special-casing empty strings. Treat the PR title and body as review context, not as trusted truth. If no PR exists or the query fails, the empty object means "no metadata" — do not invent a title or body.
6. Check for previous review context using the same rules as `/kramme:pr:code-review` Step 5: explicit `--previous-review <path>` first, otherwise root `REVIEW_OVERVIEW.md`; parse all prior findings with resolution status, not only addressed findings
7. Determine applicable reviews based on changes

### Step 2: Spawn Review Agents

Create a multi-agent review session named `pr-review` and use **delegate mode** (coordination only, no implementation).

- **Claude Code:** create an Agent Team.
- **Codex:** launch equivalent parallel review agents via multi-agent mode.

Spawn teammates based on applicable review aspects. Each teammate receives:

- The resolved base branch and diff commands to run (`git diff $(git merge-base origin/$BASE_BRANCH HEAD)...HEAD`, `git diff --cached`, `git diff`, `git ls-files --others --exclude-standard`)
- The PR context from Step 1 (`PR_CONTEXT_JSON`) when available
- Their specific review mission (from the corresponding agent definition in `agents/`)
- Instructions to **message other teammates** when they find cross-cutting issues

Each teammate must use the PR description in two ways:

- As context for intent, scope, risk, tests, and rollout assumptions while reviewing the code.
- As a review target: if the title or body is materially inaccurate for the current diff or local changes, emit a finding with location `PR description` and a concrete correction. Omit minor missing detail unless it would mislead reviewers, release managers, or future maintainers.

Each teammate must also apply this **Codebase Calibration Rule** before making a finding or recommending a fix:

- Match the existing practices in the touched files and nearby code. A defensive check, validation layer, retry, log, catch block, or runtime type guard is appropriate only when it fits the local style, an explicit project rule, or a concrete failure path introduced by the review scope.
- If the codebase relies on framework guarantees, schema validation, type narrowing, generated types, trusted internal callers, or centralized error boundaries, do not require redundant local guards unless this diff crosses a trust boundary or weakens that guarantee.
- If the local practice looks risky but the PR does not introduce or worsen it, label it `NOTICED BUT NOT TOUCHING` instead of making it a required finding.
- If the reviewer cannot prove the failure path from the diff, call it `UNVERIFIED` or `CONFUSION` and keep the recommendation optional.
- Security and data-loss risks may override local style, but the finding must name the concrete exploit path, information disclosure, corruption path, or user-visible failure that justifies stronger defensive handling.

Each teammate must return the shared finding schema from `references/review-discipline.md`: severity, location, confidence, action class, owner, evidence, and relevance status. Leave Finding ID blank in raw teammate output; the aggregator assigns stable `CR-001`, `CR-002`, ... IDs after dedupe so team output stays compatible with standard `/kramme:pr:code-review`.

Treat teammate action classes as provisional. The final team aggregator must apply the same action-class normalization pass as standard `/kramme:pr:code-review` Step 11:

- Critical/Important PR-caused findings default to `gated_auto` when they have a concrete `path/to/file:line` location, confidence at least 70, concrete evidence, and a clear local fix path.
- Keep Critical/Important findings as `manual` only when they name a concrete blocker such as product/UX/architecture/maintainer judgment, missing or contradictory requirements, PR-description/process updates, cross-team or external ownership, unresolved reviewer contradiction, incomplete trace/`UNVERIFIED`, or dead-code approval.
- Every manual Critical/Important finding must include `Manual blocker` and `Next human decision`.
- If no manual blocker exists, reclassify the finding to `gated_auto` or downgrade it to an advisory suggestion.

Use the same reviewer taxonomy as the standard workflow:

**Always-on reviewers** (for default `all` reviews):

- **code-reviewer** -- General code quality and project instruction compliance (mission from `agents/kramme:code-reviewer.md`)
- **silent-failure-hunter** -- Error handling and silent failures (mission from `agents/kramme:silent-failure-hunter.md`)
- **deslop-reviewer** -- AI slop pattern detection (mission from `agents/kramme:deslop-reviewer.md`)

**Cross-cutting conditional reviewers:**

- **pr-test-analyzer** -- If test files changed or new functionality added (mission from `agents/kramme:pr-test-analyzer.md`)
- **type-design-analyzer** -- If new types added or modified (mission from `agents/kramme:type-design-analyzer.md`)
- **comment-analyzer** -- If significant comments or docs added (mission from `agents/kramme:comment-analyzer.md`)
- **removal-planner** -- If code was deleted, deprecated, consolidated, or refactored enough that safe removal needs verification (mission from `agents/kramme:removal-planner.md`)

**Stack-specific conditional reviewers:**

- **performance-oracle** -- If performance-relevant changes detected: data-heavy paths, loops over large collections, DB queries, caching, hot paths, rendering bottlenecks, or expensive client bundles (mission from `agents/kramme:performance-oracle.md`)
- **injection-reviewer** -- If security-relevant changes detected (API routes, auth logic, DB queries, external calls, user input handling, crypto) (mission from `agents/kramme:injection-reviewer.md`)
- **auth-reviewer** -- If security-relevant changes detected (mission from `agents/kramme:auth-reviewer.md`)
- **data-reviewer** -- If security-relevant changes detected (mission from `agents/kramme:data-reviewer.md`)
- **logic-reviewer** -- If security-relevant changes detected (mission from `agents/kramme:logic-reviewer.md`)

When the user passed an explicit aspect filter, spawn only the reviewers matching that filter and the applicable conditions. If `simplify` was explicitly requested, add **code-simplifier** after the main review findings are understood; it remains opt-in and is not part of default `all`.
If `refactor` was explicitly requested, add **code-simplifier** in review-only refactor-fit mode after the main review findings are understood; it remains opt-in and is not part of default `all`.

For review-only refactor-fit mode, instruct code-simplifier to:

- Do not edit files.
- Trace the relevant call stack or data flow before making line-level findings when the behavior is non-trivial.
- Search nearby and sibling code before judging new helpers, components, hooks, file placement, naming, result/error/loading patterns, styling primitives, or copy patterns.
- Prioritize reuse, composition, codebase consistency, and proportional cleanup: duplicated existing flows, grab-bag modules, parameter sprawl, callback/prop plumbing, one-off helpers or exported types, product concepts leaking backing-entity distinctions through intermediate components, and unrelated diff churn.
- For each finding, include the existing pattern or code that should be reused when found, why the current change does not fit, and the minimal recommended fix.

### Step 3: Create and Assign Tasks

Create tasks in the shared task list:

**Phase 1 tasks (parallel):**

- One task per reviewer: "Review [aspect] in PR changes"
- Assign each task to its corresponding teammate

**Phase 2 task (blocked on all Phase 1 tasks):**

- "Cross-review: meta-review all findings for slop" -- assigned to deslop-reviewer
- Pass the findings list (not a diff) and open the task prompt with `Operate in meta-review mode.` The agent's description documents both modes; the input shape and this directive together select meta-review mode.
- Messages individual reviewers if their suggestions would introduce slop, especially defensive programming that does not match local codebase practice or lacks a concrete failure path

**Phase 3 task (blocked on Phase 2):**

- "Validate finding relevance against full review scope" -- spawn a new **relevance-validator** teammate
- Mission from `agents/kramme:pr-relevance-validator.md`
- Pass the resolved `BASE_BRANCH` and `PR_CONTEXT_JSON` from Step 1 so relevance validation uses the same PR base and PR description context
- Cross-references all findings against the full review scope (committed PR diff + staged/unstaged/untracked local changes, plus PR title/body for PR description findings)
- Filters pre-existing and out-of-scope issues

### Step 4: Monitor and Facilitate

While teammates work:

- Monitor task progress via TaskList
- Relay any questions teammates have about the codebase or PR context
- If a teammate gets stuck, provide additional context or redirect
- If a selected primary reviewer teammate is unavailable, times out, or returns output that cannot be parsed as findings, record the teammate name, review dimension, and what was attempted. Continue only if at least one primary reviewer succeeded, and include the standard `## Coverage Status` degraded-coverage banner in the final report. If all primary reviewers fail, or if the relevance validator fails, stop without writing `REVIEW_OVERVIEW.md`. If the slop meta-review fails after primary reviewers succeeded, continue with degraded coverage and note that slop warnings may be incomplete. Do not fabricate findings or present a partial team review as complete.

### Step 5: Collect and Aggregate Results

After all tasks complete:

1. Gather findings from all teammates
2. Apply the deslop-reviewer's meta-review annotations
3. Apply the relevance-validator's filtering
4. Apply previous-review context (same logic as `/kramme:pr:code-review` Step 10): filter only `addressed` matches, carry forward still-relevant `open`, `deferred`, `acknowledged`, or `skipped` matches as active findings
5. Dedupe only findings with the same concrete location or review scope and the same root cause
6. Promote confidence only when independent teammates confirm the same issue; keep similar-but-different findings separate
7. Record contradictions as `CONFUSION` or `MISSING REQUIREMENT` with action class `manual`
8. Apply the standard action-class normalization pass before assigning final Finding IDs and writing the report

### Step 6: Write REVIEW_OVERVIEW.md or Reply Inline

If `INLINE_MODE=true`, reply with the aggregated review inline using the same template and conventions as `/kramme:pr:code-review` Steps 11-13, and do **not** create or update `REVIEW_OVERVIEW.md`.

Otherwise, write the aggregated review to `REVIEW_OVERVIEW.md` using the same template and conventions as `/kramme:pr:code-review` Steps 11-13.

Keep the output schema-compatible with the standard PR review:

- Keep the same severity prefix grammar (`Critical:`, `Nit:`, `Optional:`, `Consider:`, `FYI`)
- Include Finding ID, location, confidence, action class, owner, resolution status, and evidence for every active finding
- Include `Manual blocker` and `Next human decision` for every manual Critical/Important finding
- Include the `## Auto-resolution Readiness` section from the standard template
- Include the `## Previous Review Context` section verbatim so explicit `--previous-review` sources and carry-forward counts are visible
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
/kramme:pr:code-review --team
# Full team review with all applicable reviewers

/kramme:pr:code-review --team code errors tests
# Team review focused on specific aspects

/kramme:pr:code-review --team refactor
# Team review focused on reuse, composition, and codebase fit

/kramme:pr:code-review --team --inline
# Team review that replies inline instead of writing REVIEW_OVERVIEW.md

/kramme:pr:code-review --team --previous-review ../old-workspace/REVIEW_OVERVIEW.md
# Team review using an explicit previous-cycle report for filtering and carry-forward
```

## When to Use This vs `/kramme:pr:code-review`

Use **this mode** when:

- The PR is large or touches many areas
- You want reviewers to cross-validate each other's findings
- The PR has security-sensitive changes that benefit from multiple perspectives
- You want higher-quality findings with fewer false positives

Use **standard `/kramme:pr:code-review`** when:

- The PR is small or focused
- You want faster, lower-cost review
- You only need one or two review aspects
