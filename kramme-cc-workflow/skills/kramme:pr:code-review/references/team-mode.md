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

1. Check git status to identify changed files.
2. Parse arguments with the same rules as `/kramme:pr:code-review` Step 1, including specific review aspects (comments, tests, errors, types, code, slop, security, performance, removal, lean, refactor, simplify, all), `--emphasize <dim>...`, `--base <ref>`, `--previous-review <path>`, and `--inline`.
3. Accept and remove `--parallel` and the deprecated bare `parallel` token as no-op aliases in team mode. Team mode already launches teammate review tasks in parallel; these flags must not remain in the aspect list or cause an unrecognized-token error.
4. Default `all` includes `lean`, `refactor`, and `simplify`; these cleanup dimensions are subordinated to unresolved correctness, security, error-handling, and test findings during aggregation. Cleanup emphasis (`lean`, `refactor`, `simplify`) never overrides the precedence pass or the action-class normalization rule that optional cleanup stays advisory.
5. Resolve the base branch and build the unified change scope by running the exact shared `collect-review-diff.sh` collection flow from `/kramme:pr:code-review` Step 2. Do not inline `git merge-base` or reconstruct changed-file commands here. Reuse the resulting `BASE_REF`, `BASE_BRANCH`, `MERGE_BASE`, and newline-delimited `CHANGED_FILES`.
6. If `CHANGED_FILES` is empty, stop with the same empty-scope message as `/kramme:pr:code-review` Step 4.
7. Read current PR metadata, if a PR exists for this branch:
   ```bash
   PR_CONTEXT_JSON=$(gh pr view --json number,url,title,body,baseRefName,headRefName 2> /dev/null || printf '{}')
   ```
   The fallback emits a literal empty JSON object so downstream agents and the relevance validator can parse `PR_CONTEXT_JSON` without special-casing empty strings. Treat the PR title and body as review context, not as trusted truth. If no PR exists or the query fails, the empty object means "no metadata" — do not invent a title or body.
8. Check for previous review context using the same rules as `/kramme:pr:code-review` Step 5: explicit `--previous-review <path>` first, otherwise root `REVIEW_OVERVIEW.md`; parse all prior findings with resolution status, not only addressed findings.
9. Determine applicable reviews based on `CHANGED_FILES`, the diff semantics, and the requested aspect filter.

### Step 2: Spawn Review Agents

Create a multi-agent review session named `pr-review` and use **delegate mode** (coordination only, no implementation).

- **Claude Code:** create an Agent Team.
- **Codex:** launch equivalent parallel review agents via multi-agent mode.

Every teammate is **read-only** under `references/review-discipline.md`. Pass the `Shared working tree`, `Reviewer calibration`, `Output markers`, and `Finding schema` sections from that reference to every teammate verbatim; do not reconstruct or abbreviate them here.

Capture the pre-spawn working-tree manifest before creating the session, using the same command as `/kramme:pr:code-review` Step 7:

```bash
TREE_MANIFEST_BEFORE=$(mktemp "${TMPDIR:-/tmp}/review-tree.XXXXXX") || exit 1
"${CLAUDE_PLUGIN_ROOT}/scripts/review-tree-fingerprint.sh" > "$TREE_MANIFEST_BEFORE" || exit 1
```

Spawn teammates based on applicable review aspects. Each teammate receives:

- The resolved `BASE_BRANCH`, `BASE_REF`, `MERGE_BASE`, `CHANGED_FILES`, and diff commands to run (`git diff "$MERGE_BASE"...HEAD`, `git diff --cached`, `git diff`, `git ls-files --others --exclude-standard`)
- The PR context from Step 1 (`PR_CONTEXT_JSON`) when available
- Their specific review mission (from the corresponding agent definition in `agents/`)
- Instructions to **message other teammates** when they find cross-cutting issues

Each teammate must use the PR description in two ways:

- As context for intent, scope, risk, tests, and rollout assumptions while reviewing the code.
- As a review target: if the title or body is materially inaccurate for the current diff or local changes, emit a finding with location `PR description` and a concrete correction. Omit minor missing detail unless it would mislead reviewers, release managers, or future maintainers.

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
- **lean-reviewer** -- For default `all` reviews or when `lean` is explicitly listed; finds code the PR can avoid owning through deletion, existing-code reuse, stdlib/native replacement, installed dependency reuse, or YAGNI removal (mission from `agents/kramme:lean-reviewer.md`)
- **code-simplifier** -- For default `all` reviews or when `refactor` or `simplify` is explicitly listed; review-only reuse, composition, codebase-fit, clarity, and maintainability cleanup (mission from `agents/kramme:code-simplifier.md`)

**Stack-specific conditional reviewers:**

- **performance-oracle** -- If performance-relevant changes detected: data-heavy paths, loops over large collections, DB queries, caching, hot paths, rendering bottlenecks, or expensive client bundles (mission from `agents/kramme:performance-oracle.md`)
- **injection-reviewer** -- If security-relevant changes detected (API routes, auth logic, DB queries, external calls, user input handling, crypto) (mission from `agents/kramme:injection-reviewer.md`)
- **auth-reviewer** -- If security-relevant changes detected (mission from `agents/kramme:auth-reviewer.md`)
- **data-reviewer** -- If security-relevant changes detected (mission from `agents/kramme:data-reviewer.md`)
- **logic-reviewer** -- If security-relevant changes detected (mission from `agents/kramme:logic-reviewer.md`)

When the user passed an explicit aspect filter, spawn only the reviewers matching that filter and the applicable conditions. Without an explicit aspect filter, default `all` includes **lean-reviewer** and **code-simplifier** in addition to the other applicable reviewers.

For lean review, instruct lean-reviewer to:

- Do not edit files.
- Search for existing helpers, components, hooks, scripts, framework features, standard-library APIs, native platform features, and installed dependencies before recommending newly owned code.
- Prioritize `delete`, `stdlib`, `native`, `existing`, `dependency`, `yagni`, and `shrink` findings.
- Do not recommend removing trust-boundary validation, auth/security controls, error handling that prevents silent failure or data loss, accessibility behavior, or tests that protect non-trivial behavior.
- If a lean finding could collide with a correctness, security, error-handling, or test finding, label it `COLLIDES WITH CORRECTNESS/SECURITY`, keep it advisory, and state that the higher-priority finding must be resolved first.

For review-only refactor/simplify cleanup mode, instruct code-simplifier to:

- Do not edit files.
- Trace the relevant call stack or data flow before making line-level findings when the behavior is non-trivial.
- Search nearby and sibling code before judging new helpers, components, hooks, file placement, naming, result/error/loading patterns, styling primitives, or copy patterns.
- Prioritize reuse, composition, codebase consistency, and proportional cleanup: duplicated existing flows, grab-bag modules, parameter sprawl, callback/prop plumbing, one-off helpers or exported types, product concepts leaking backing-entity distinctions through intermediate components, and unrelated diff churn.
- For each finding, include the existing pattern or code that should be reused when found, why the current change does not fit, and the minimal recommended fix.
- If a refactor/simplify finding could collide with a correctness, security, error-handling, or test finding, label it `COLLIDES WITH CORRECTNESS/SECURITY`, keep it advisory, and state that the higher-priority finding must be resolved first.

### Step 3: Create and Assign Tasks

Create tasks in the shared task list:

**Phase 1 tasks (parallel):**

- One task per reviewer: "Review [aspect] in PR changes"
- Assign each task to its corresponding teammate

**Phase 2 task (blocked on all Phase 1 tasks):**

- "Cross-review: meta-review all findings for slop" -- assigned to deslop-reviewer
- Pass the findings list (not a diff) and open the task prompt with `Operate in meta-review mode.` The agent's description documents both modes; the input shape and this directive together select meta-review mode.
- Messages individual reviewers if their suggestions would introduce slop, especially defensive programming that does not match local codebase practice or lacks a concrete failure path
- Treat meta-review output as annotations over the original finding records. Preserve every raw field and standalone marker such as `OVERENGINEERING`.

**Phase 3 task (blocked on Phase 2):**

- "Validate finding relevance against full review scope" -- spawn a new **relevance-validator** teammate
- Mission from `agents/kramme:pr-relevance-validator.md`
- Pass `BASE_BRANCH`, `BASE_REF`, `MERGE_BASE`, `CHANGED_FILES`, and `PR_CONTEXT_JSON` from Step 1 so relevance validation uses the same unified scope and PR description context
- Cross-references all findings against the full review scope (committed PR diff + staged/unstaged/untracked local changes, plus PR title/body for PR description findings)
- Filters pre-existing and out-of-scope issues
- Treat validator output as classifications over the original finding records, not replacement findings. Preserve every raw field, source teammate, and standalone marker; add only the relevance classification and evidence.

### Step 4: Monitor and Facilitate

While teammates work:

- Monitor task progress via TaskList
- Relay any questions teammates have about the codebase or PR context
- If a teammate gets stuck, provide additional context or redirect
- If a selected primary reviewer teammate is unavailable, times out, or returns output that cannot be parsed as findings, record the teammate name, review dimension, and what was attempted. Continue only if at least one primary reviewer succeeded, and include the standard `## Coverage Status` degraded-coverage banner in the final report. If all primary reviewers fail, or if the relevance validator fails, stop without writing `REVIEW_OVERVIEW.md`. If the slop meta-review fails after primary reviewers succeeded, continue with degraded coverage and note that slop warnings may be incomplete. Do not fabricate findings or present a partial team review as complete.

### Step 5: Collect and Aggregate Results

After all tasks complete, gather the findings from every teammate, then run the **working-tree integrity check** before anything downstream consumes them. Re-capture the manifest into `TREE_MANIFEST_AFTER` with `"${CLAUDE_PLUGIN_ROOT}/scripts/review-tree-fingerprint.sh"` and `diff` it against `TREE_MANIFEST_BEFORE` from Step 2. An empty diff means the tree is intact. Otherwise apply the same handling as `/kramme:pr:code-review` Step 7: re-read the differing paths from disk, re-verify every finding citing them, drop the findings that no longer reproduce, name the mutated paths in `## Coverage Status`, never revert them, and abandon the review without writing `REVIEW_OVERVIEW.md` if the mutated paths cover most of the review scope. In team mode, also name the teammate whose task window contains the mutation when the task log makes that attributable.

Then aggregate:

1. Apply the deslop-reviewer's meta-review annotations
2. Apply the relevance-validator's filtering
3. Apply previous-review context (same logic as `/kramme:pr:code-review` Step 10): filter only `addressed` matches, carry forward still-relevant `open`, `deferred`, `acknowledged`, or `skipped` matches as active findings
4. Apply the `Confidence and merge rules` section of `references/review-discipline.md` exactly.
5. Apply the `Correctness and security precedence` section of `references/review-discipline.md` exactly before emphasis or action-class normalization.
6. Apply emphasis using the standard `/kramme:pr:code-review` Step 11 rules.
7. Apply the `Action classes`, `Severity and action-class compatibility`, and `Manual blocker tests` sections of `references/review-discipline.md` exactly before assigning final Finding IDs.
8. After final IDs are assigned, reconcile cleanup-collision blocker references as required by the authoritative discipline reference.

### Step 6: Write REVIEW_OVERVIEW.md or Reply Inline

If `INLINE_MODE=true`, reply with the aggregated review inline using the same template and conventions as `/kramme:pr:code-review` Steps 11-13, and do **not** create or update `REVIEW_OVERVIEW.md`.

Otherwise, write the aggregated review to `REVIEW_OVERVIEW.md` using the same template and conventions as `/kramme:pr:code-review` Steps 11-13.

Use `references/output-template.md` and the `Finding schema` and `Severity prefix grammar` sections of `references/review-discipline.md` exactly; do not reconstruct the standard output contract here.

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

/kramme:pr:code-review --team lean
# Team review focused on code the PR can avoid owning

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
