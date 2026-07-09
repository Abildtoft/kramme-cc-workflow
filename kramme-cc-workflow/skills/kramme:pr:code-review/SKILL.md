---
name: kramme:pr:code-review
description: Analyze code quality of branch changes using specialized review agents (tests, errors, types, security, performance, slop, lean deletion, refactor fit, simplification). Outputs REVIEW_OVERVIEW.md with actionable findings, or replies inline with --inline. Use --team for multi-agent cross-validation. Not for UX, visual, or accessibility review -- use kramme:pr:ux-review for those.
argument-hint: "[aspects] [--emphasize <dim>...] [--base <branch>] [--previous-review <path>] [--parallel] [parallel] [--team] [--inline]"
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
   - If `--base <branch>` flag → store as `BASE_BRANCH_OVERRIDE`
   - If `--previous-review <path>` flag → store as `PREVIOUS_REVIEW_PATH` and remove it and its value from the aspect list. Reject the flag if the path is missing, points to a directory, or cannot be read. Do not silently fall back to `REVIEW_OVERVIEW.md` when an explicit previous-review path is invalid.
   - If `--inline` flag → set `INLINE_MODE=true` and remove it from the aspect list
   - If `--team` flag → use Team Mode and remove it from the aspect list
   - If `--parallel` appears anywhere in `$ARGUMENTS` → set `LAUNCH_MODE=parallel` and remove it from the aspect list. Default is `LAUNCH_MODE=sequential`.
   - If the bare token `parallel` appears anywhere in `$ARGUMENTS` → set `LAUNCH_MODE=parallel`, remove it from the aspect list, and treat it as a deprecated alias for `--parallel`.
   - If `--emphasize <dim>...` flag → store dimension names in `EMPHASIZED_DIMENSIONS` list and remove from aspect list. Consume all tokens after `--emphasize` until the next `--` flag, `--parallel`, `parallel`, or end of arguments. Each token must be a valid aspect name (`comments`, `tests`, `errors`, `types`, `code`, `slop`, `security`, `performance`, `removal`, `lean`, `refactor`, `simplify`). Reject `--emphasize all` (emphasizing everything is a no-op). Cleanup emphasis (`lean`, `refactor`, `simplify`) never overrides the precedence pass or the action-class normalization rule that optional cleanup stays advisory.
   - Validate remaining positional tokens as aspect names against the same list plus `all`. If any token is not a recognized aspect, stop with an error naming the unrecognized token and listing valid aspects. Do not silently fall through to "run all applicable reviews."
   - If an explicit aspect list was provided and it does not include `all`, every emphasized dimension must also appear in that list. If any emphasized dimension was excluded by the user's aspect filter, stop with an error instead of re-ranking unrelated findings.
   - Default (no aspect tokens, or `all`): Run all applicable reviews, including the cleanup dimensions `lean`, `refactor`, and `simplify`. These cleanup dimensions are lower-priority than unresolved correctness, security, error-handling, and test findings when recommendations collide; the precedence pass in Step 11 suppresses or demotes cleanup advice that would undermine an open higher-priority finding.

2. **Resolve Base Branch and Collect Review Diff**

   Use the shared plugin script to resolve the base branch and build the unified change scope (committed PR diff + staged + unstaged + untracked). It uses the same 3-tier strategy: explicit `--base`, PR target branch, then `origin/HEAD`/`origin/main`/`origin/master`. It runs in strict mode, so fetch failures stop the workflow with the script's stderr message.

   ```bash
   [ -x "${CLAUDE_PLUGIN_ROOT:-}/scripts/collect-review-diff.sh" ] || {
     echo "collect-review-diff.sh not found under CLAUDE_PLUGIN_ROOT — is the kramme-cc-workflow plugin installed?" >&2
     exit 1
   }
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

   The JSON parsing block sets `BASE_REF`, `BASE_BRANCH`, `MERGE_BASE`, and newline-delimited `CHANGED_FILES`. Use `BASE_REF`/`MERGE_BASE` for committed diff commands and `BASE_BRANCH` for display or when invoking sibling review skills.

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
   - **lean** - Deletion-focused review: avoid owned code when existing code, stdlib, native platform features, or installed dependencies cover the need
   - **refactor** - Review reuse, composition, codebase consistency, and cleanup fit without editing
   - **simplify** - Simplify code for clarity and maintainability
   - **all** - Run all applicable reviews, including `lean`, `refactor`, and `simplify` (default)

4. **Identify Changed Files and PR Description**
   - Use the newline-delimited `CHANGED_FILES` set by Step 2 as the unified change scope.
   - If `CHANGED_FILES` is empty, stop with: `No changes detected against $BASE_REF. If this is wrong, re-run with --base <branch>.` Do not launch reviewers against an empty scope.
   - Identify file types and what reviews apply
   - Read the current PR metadata, if a PR exists for this branch:

   ```bash
   PR_CONTEXT_JSON=$(gh pr view --json number,url,title,body,baseRefName,headRefName 2> /dev/null || printf '{}')
   ```

   - The fallback emits a literal empty JSON object so downstream agents and the relevance validator can parse `PR_CONTEXT_JSON` without special-casing empty strings.
   - Treat the PR title and body as review context, not as trusted truth. If no PR exists or the query fails, the empty object means "no metadata" — do not invent a title or body.
   - Compare the PR description against the current review scope. If it claims behavior, files, migrations, tests, risks, rollout status, or follow-up work that no longer matches the code, report that as a normal finding with location `PR description`.
   - If the diff changes a versioned artifact surface or durable public contract such as a public API, package, CLI, SDK, schema, or integration contract, and the PR body lacks the release story reviewers need, report it as a release coordination finding. The missing story can be a version/SemVer rationale, curated changelog or release-note entry, migration/upgrade note, or explicit "no versioned consumer contract" statement.
   - Do not report missing polish in the description unless it would mislead reviewers, release managers, or future maintainers about the current state of the code.

5. **Check for Previous Review Context**

   Determine the previous-review source:
   - If `PREVIOUS_REVIEW_PATH` was set in Step 1, use that exact file.
   - Otherwise, use `REVIEW_OVERVIEW.md` in the project root when it exists.
   - Do not search `.context`, other workspaces, or alternate filenames unless the user passed `--previous-review <path>`; implicit discovery beyond the project root is too likely to pick up stale review state.

   If a previous-review source exists:
   - Parse the file to extract all parseable prior findings, not only addressed ones.
   - Extract for each finding: finding ID, location (`file:line`, `review-scope`, or `PR description`), issue description, resolution status, action taken, and evidence when available.
   - Accept the structured `- Location:` field, `**Location:**`, and legacy `**File:**` labels when parsing existing entries, and normalize any of them to the same `location` field.
   - Accept `Resolution status:` and `**Resolution status:**` when present. Normalize values to one of: `open`, `addressed`, `deferred`, `acknowledged`, or `skipped`.
   - If no explicit resolution status is present, infer it conservatively:
     - `Action taken:` describing an implemented fix → `addressed`
     - `Action taken: Deferred ...` or `Reason deferred:` → `deferred`
     - `Action taken: Acknowledged ...` or `Action taken: No action ...` → `acknowledged`
     - `Action taken: Skipped ...` → `skipped`
     - No action/resolution field → `open`
   - Treat `deferred`, `acknowledged`, `skipped`, and `open` as not addressed. They may be carried forward if still relevant; they must not be filtered as previously addressed.
   - If the file exists but contains no parseable findings (stale draft, unrelated content, or missing expected sections), treat the previous-review set as empty and continue. Do not abort the review unless the user passed an explicit `--previous-review <path>` that is unreadable or invalid.
   - Store previous-review source path, parseable count, addressed count, open/deferred/acknowledged/skipped count, and unparseable count for the final `Previous Review Context` report section.

   Parseable previous findings have the preferred format:
   - `- Finding ID: CR-001`
   - `- Location: path/to/file.ts:123`, `review-scope`, or `PR description`
   - Legacy compatibility: `**Location:** path/to/file.ts:123` and `**File:** path/to/file.ts:123` should be treated the same as the structured `Location` field
   - `- Resolution status: open|addressed|deferred|acknowledged|skipped`
   - **Issue/Finding:** [description]
   - **Action taken:** [what was done]

6. **Determine Applicable Reviews**

   Select reviewers with this taxonomy. The taxonomy applies to default `all` reviews; explicit aspect filters still narrow the active set to the requested dimensions.

   **Always-on reviewers** (run for default `all` because they catch broad regressions across stack types):
   - `kramme:code-reviewer` — general quality, project instruction compliance, and PR-description drift
   - `kramme:silent-failure-hunter` — swallowed errors, weak propagation, and misleading fallback behavior
   - `kramme:deslop-reviewer` — AI slop patterns, unnecessary defensive noise, and weak type workarounds

   **Cross-cutting conditional reviewers** (activate when the changed files or diff semantics match):
   - `kramme:pr-test-analyzer` — if test files changed, new behavior was added, or coverage claims appear in the PR description
   - `kramme:comment-analyzer` — if comments, docstrings, docs, or explanation-heavy inline text changed
   - `kramme:type-design-analyzer` — if types, schemas, interfaces, data models, or invariants changed
   - `kramme:removal-planner` — if code was deleted, deprecated, consolidated, or refactored enough that safe removal needs verification
   - `kramme:lean-reviewer` — for default `all` reviews or when `lean` is explicitly listed. It finds code the PR can avoid owning: deletions, existing-helper reuse, stdlib/native replacements, avoidable dependencies, and YAGNI abstractions.
   - `kramme:code-simplifier` — for default `all` reviews or when `refactor` or `simplify` is explicitly listed. Record the active dimension as `refactor`, `simplify`, or both based on the requested tokens; for default `all`, record both. Use `refactor` for review-only reuse/composition/codebase-fit findings; use `simplify` for broader clarity and maintainability simplification suggestions.

   **Stack-specific conditional reviewers** (activate only when the touched stack has the relevant risk surface):
   - `kramme:performance-oracle` — data-heavy paths, loops over large collections, DB queries, caching, hot paths, rendering bottlenecks, or expensive client bundles
   - Security reviewer bundle — API routes, auth logic, authorization checks, DB queries, external calls, user input handling, crypto, secrets, session state, or business-rule enforcement. Launch `kramme:injection-reviewer`, `kramme:auth-reviewer`, `kramme:data-reviewer`, and `kramme:logic-reviewer` together.

   Build `ACTIVE_REVIEW_DIMENSIONS` from the agents that will actually run after aspect filtering and applicability checks. If any emphasized dimension has no active agent in this set, stop with an error telling the user which emphasized dimensions are inactive. Do not cap unrelated findings when the emphasized review never ran.

7. **Launch Review Agents**

   Pass the resolved `BASE_BRANCH`, `BASE_REF`, `MERGE_BASE`, and PR context from Steps 2 and 4 to all agents so they use the correct diff scope and understand the stated intent of the change. Instruct each agent to review the same unified scope:
   - Committed diff: `git diff "$MERGE_BASE"...HEAD`
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

   If any of `code`, `refactor`, or `simplify` is active, read `references/fowler-smell-baseline.md` once and pass it only to the corresponding `kramme:code-reviewer` and/or `kramme:code-simplifier` reviewers as advisory vocabulary after documented repo standards, the Codebase Calibration Rule, and concrete diff evidence. Each smell finding must name the smell, cite the changed location, explain why it matters in this diff, and recommend the smallest local fix; do not report smells as hard violations, duplicate tooling-enforced issues, or promote optional cleanup unless it creates concrete blocking impact under the action-class rules.

   If `lean` activated `kramme:lean-reviewer`, instruct it to operate as a deletion-focused reviewer:
   - Do not edit files.
   - Search for existing helpers, components, hooks, scripts, framework features, standard-library APIs, native platform features, and installed dependencies before recommending newly owned code.
   - Prioritize `delete`, `stdlib`, `native`, `existing`, `dependency`, `yagni`, and `shrink` findings.
   - Do not recommend removing trust-boundary validation, auth/security controls, error handling that prevents silent failure or data loss, accessibility behavior, or tests that protect non-trivial behavior.
   - If a lean finding could collide with a correctness, security, error-handling, or test finding, label it `COLLIDES WITH CORRECTNESS/SECURITY`, keep it advisory, and state that the higher-priority finding must be resolved first.

   If `refactor` or `simplify` activated `kramme:code-simplifier`, instruct it to operate as a review-only cleanup reviewer:
   - Do not edit files.
   - Trace the relevant call stack or data flow before making line-level findings when the behavior is non-trivial.
   - Search nearby and sibling code before judging new helpers, components, hooks, file placement, naming, result/error/loading patterns, styling primitives, or copy patterns.
   - Use the smell baseline as a shared vocabulary for refactor/simplify findings, but only when it sharpens a concrete changed-code concern instead of expanding the review into a broad cleanup mandate.
   - Prioritize reuse, composition, codebase consistency, and proportional cleanup: duplicated existing flows, grab-bag modules, parameter sprawl, callback/prop plumbing, one-off helpers or exported types, product concepts leaking backing-entity distinctions through intermediate components, and unrelated diff churn.
   - For each finding, include the existing pattern or code that should be reused when found, why the current change does not fit, and the minimal recommended fix.
   - If a refactor/simplify finding could collide with a correctness, security, error-handling, or test finding, label it `COLLIDES WITH CORRECTNESS/SECURITY`, keep it advisory, and state that the higher-priority finding must be resolved first.

   Instruct every reviewer to return these fields for each finding:
   - **Finding ID:** leave blank for raw reviewer output; the aggregator assigns stable `CR-001`, `CR-002`, ... IDs after dedupe
   - **Severity:** Critical, Important, Suggestion, or FYI using the severity prefix grammar in `references/review-discipline.md`
   - **Location:** concrete `path/to/file:line`, `review-scope`, or `PR description`
   - **Confidence:** `{0-100}`. During the transition, if a reviewer returns `high`, `medium`, or `low`, map it before aggregation as `high=90`, `medium=60`, `low=30`. Remove this mapping shim once all bundled review agents emit numeric 0-100 confidence natively.
   - **Action class:** `gated_auto`, `manual`, or `advisory` from `references/review-discipline.md`; Critical/Important findings may use only `gated_auto` or `manual`, while Suggestions/FYI use `advisory`. Treat the raw reviewer action class as provisional: the aggregator performs the final action-class normalization in Step 11.
   - **Owner:** resolver, author, maintainer, reviewer, or unknown
   - **Evidence:** concrete location, trace, reproduction, failing expectation, or reason the finding is marked `UNVERIFIED`
   - **Relevance status:** PR-caused, pre-existing/out-of-scope, previously addressed, or unresolved pending validation

   Launch the agents resolved in Step 6 using `LAUNCH_MODE` from Step 1:
   - `LAUNCH_MODE=sequential` (default): launch one agent, wait for its report, then launch the next. Use this for interactive review where each report should be readable before the next runs.
   - `LAUNCH_MODE=parallel`: launch all applicable agents simultaneously and collect results together. Use this when the user passed `--parallel` or the deprecated bare `parallel` alias.

   **Agent failure handling.** If a selected reviewer agent is unavailable, times out, or returns output that cannot be parsed as findings, record the failed agent name, review dimension, and what was attempted. Continue only if at least one selected reviewer succeeded, and include a degraded-coverage banner in the final report: `Coverage degraded: <agent names> failed; findings below exclude <dimensions>.` If all selected reviewers fail, or if the relevance validator fails, stop without writing `REVIEW_OVERVIEW.md`. Do not fabricate findings or present a partial review as complete. If the slop meta-review fails after primary reviewers succeeded, continue with a degraded-coverage banner that names the failed meta-review and notes that slop warnings may be incomplete.

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

10. **Apply Previous Review Context**

If a previous-review source was found in Step 5:

- Cross-reference the full validated finding set against previous findings.
- **Filter as previously addressed** only when the previous finding has `Resolution status: addressed` and the current finding is essentially the same issue:
  - Same file
  - Same enclosing function, component, or block (do not rely on raw line distance; refactors and formatters shift line numbers)
  - Same underlying issue (semantic match on root cause)
  - For `review-scope` findings: both findings use location `review-scope`
  - For PR description findings: both findings use location `PR description`
- **Carry forward as active** when a previous finding with `Resolution status: open`, `deferred`, `acknowledged`, or `skipped` still applies to the current diff:
  - Preserve the previous finding ID when the root cause is the same.
  - Refresh the location, severity, confidence, owner, and evidence from the current review when the current run has better data.
  - Keep the previous status visible by setting `Resolution status: open` in the active finding and adding evidence that it was carried forward from the previous-review source.
- For previous non-addressed findings that do not match any current reviewer finding, perform a lightweight revalidation against the current review scope:
  - If the finding's file or scope is no longer present or the old root cause cannot be found, do not carry it forward.
  - If the root cause is still present in changed code, carry it forward as an active finding with the previous ID and evidence that it was revalidated from the previous-review source.
  - If revalidation is uncertain, do not fabricate a finding; mention the uncertainty in `Previous Review Context` instead of treating it as resolved.
- **Do NOT filter** (keep as active finding) if:
  - The issue description is substantively different (different root cause)
  - The severity escalated (was suggestion, now critical)
  - The finding identifies a problem with the fix itself
  - The previous action was "No action", a deferral, an acknowledgement, a skip, or is missing
- When uncertain, err on the side of keeping the finding active.
- Add filtered findings to `Filtered (Previously Addressed)`.
- Add still-relevant non-addressed matches to active issue sections, not to `Filtered (Previously Addressed)`.
- Track carried-forward and not-carried-forward counts for `Previous Review Context`.

11. **Aggregate Results**

After validation, slop meta-review, and previous-review processing, dedupe and merge findings before applying emphasis:

- Merge only findings that name the same concrete location or review scope and the same root cause.
- Keep the highest severity across merged duplicates, combine evidence, and preserve all source agents.
- Promote confidence only when independent reviewers identify the same issue with the same location/root cause. Two weak findings about similar symptoms are not enough.
- Do not merge contradictory findings. Record contradictions as open questions with action class `manual`; if the contradiction blocks approval, place it in Critical or Important based on impact.
- Findings labeled `UNVERIFIED` can be retained, but they must keep confidence below 60 and use `manual` or `advisory` unless the concrete risk is separately proven.
- Drop or separate findings that only share a broad theme but require different fixes.

Then apply the **correctness/security precedence pass** before emphasis:

- Treat findings from `kramme:lean-reviewer` and cleanup-mode `kramme:code-simplifier` as cleanup-dimension findings (`lean`, `refactor`, `simplify`).
- Treat unresolved Critical or Important findings from `kramme:code-reviewer`, `kramme:silent-failure-hunter`, `kramme:pr-test-analyzer`, `kramme:type-design-analyzer`, `kramme:injection-reviewer`, `kramme:auth-reviewer`, `kramme:data-reviewer`, and `kramme:logic-reviewer` as higher-priority correctness/security findings when they are still active after previous-review processing.
- A cleanup finding collides when its recommended deletion, replacement, abstraction removal, simplification, or reuse would remove or weaken validation, auth, authorization, injection protection, data protection, error propagation, test coverage, type invariants, or the concrete fix path of an unresolved correctness/security finding.
- If a cleanup finding collides with an unresolved correctness/security finding:
  - Do not promote it through `--emphasize`.
  - Do not classify it as Critical or Important.
  - Do not assign `gated_auto`.
  - Either drop it as redundant/no longer safe, or keep it only as an advisory Suggestion with evidence: `Blocked by the matching correctness/security finding; revisit after that finding is resolved.` After final IDs are assigned, reference the blocking `CR-XXX` in the cleanup finding's evidence.
  - Preserve the correctness/security finding unchanged, and append the cleanup collision as supporting context only when it helps the resolver avoid the unsafe cleanup path.
- If the cleanup recommendation remains valid after the higher-priority fix is applied, keep it as an advisory Suggestion with the dependency named. If it would only be valid by choosing a different correctness/security fix, record a `CONFUSION` manual finding instead of silently choosing the cleanup path.

After validation, slop meta-review, and previous-review processing, apply emphasis adjustments if `EMPHASIZED_DIMENSIONS` is non-empty. Only use findings from agents that actually ran in Step 7 when deciding what is emphasized vs non-emphasized.

**Dimension-to-agent mapping:** `security` → injection-reviewer, auth-reviewer, data-reviewer, logic-reviewer | `errors` → silent-failure-hunter | `tests` → pr-test-analyzer | `comments` → comment-analyzer | `types` → type-design-analyzer | `code` → code-reviewer | `slop` → deslop-reviewer | `performance` → performance-oracle | `removal` → removal-planner | `lean` → lean-reviewer | `refactor` → code-simplifier in review-only refactor-fit mode | `simplify` → code-simplifier

**Promotion rules (per finding, based on source agent):**

- Emphasized agent findings: Suggestion → promoted to Important. Critical and Important unchanged.
- Non-emphasized agent findings: Keep their original severities. Do not demote validated findings just because they were not emphasized.
- Cleanup-dimension findings (`lean`, `refactor`, `simplify`) may be promoted only provisionally. The action-class normalization pass below wins: if the cleanup finding is optional, stylistic, low-confidence, or lacks concrete merge-blocking impact, move it back to Suggestions with action class `advisory`.

Track the count of promoted findings for the report.

After emphasis adjustments, run an **action-class normalization pass**. The goal is to make `/kramme:pr:resolve-review` receive every finding it can safely fix, while keeping genuinely human-dependent work explicit.

- Treat raw reviewer action classes as provisional. The aggregator owns the final `Action class`, `Owner`, and any manual-follow-up fields in the report.
- For every PR-caused Critical or Important finding, default to `gated_auto` with owner `resolver` when all of these are true:
  - `Location` is a concrete `path/to/file:line`
  - `Confidence` is at least 70
  - The evidence names a concrete failing expectation, trace, or local code path
  - The fix direction is unambiguous and local to changed or nearby code
  - The finding does not match a manual blocker
- Keep a Critical or Important finding as `manual` only when a blocker applies under the **manual blocker tests** in `references/review-discipline.md` (maintainer judgment with named competing options, uninferable missing/contradictory requirement, non-code state, cross-team/external ownership, unresolved contradiction, resource-blocked incomplete trace/`UNVERIFIED`, or dead-code approval). `manual` is the exception, not the safe default.
- Apply that section's tiebreaker: a finding that plausibly fits both classes becomes `gated_auto`, but a finding matching a named blocker never fits both — dead-code findings always stay `manual` until the ask is answered.
- Every manual Critical or Important finding must include:
  - `Manual blocker: <one of the blocker categories above>`
  - `Next human decision: <the specific decision, approval, access, or clarification needed>`
- If a manual Critical or Important finding has a concrete file location, confidence at least 70, and no named manual blocker, reclassify it to `gated_auto`.
- If a finding is optional, stylistic, low-confidence, or a cleanup idea without blocking impact, put it in Suggestions with action class `advisory` instead of Critical/Important with `manual`.
- Before finalizing, if more than half of the Critical/Important findings are `manual`, re-test each one against the blocker list above. A manual-heavy report usually means blockers were named loosely, not that the PR needs that much human intervention.

Assign stable `Finding ID` values to every active finding after dedupe, filtering, and emphasis are complete:

- Use `CR-001`, `CR-002`, etc. in final report order, starting with Critical, then Important, then Suggestions.
- Preserve an existing ID if a finding is carried forward from the previous-review source and still describes the same root cause.
- Include the ID in the final report so follow-up workflows can pass exact findings to `/kramme:pr:resolve-review`.
- Set `Resolution status: open` on every active finding emitted by this review. Only `/kramme:pr:resolve-review` or a human follow-up should change that status to `addressed`, `deferred`, `acknowledged`, or `skipped`.
- After IDs are assigned, revisit any kept cleanup-collision Suggestions and replace their provisional blocker text with the final blocking `CR-XXX` ID. Do not promote or reclassify cleanup findings during this ID reconciliation.

Then summarize:

- **Auto-resolution Readiness** - count eligible `gated_auto` Critical/Important findings and manual Critical/Important findings, grouped by manual blocker reason
- **Critical Issues** (must fix before merge) - only validated findings
- **Important Issues** (should fix) - only validated findings
- **Suggestions** (nice to have) - only validated findings
- **Slop Warnings** - suggestions flagged as potentially introducing slop
- **Positive Observations** (what's good)
- **Filtered Issues** (pre-existing or out-of-scope) - shown separately
- **Previously Addressed** (findings matching the previous-review source) - shown separately
- **Previous Review Context** - source path and parse/carry-forward/filter counts, shown even when no previous-review source was found

Every active finding must include its finding ID, location, confidence, action class, owner, resolution status, and evidence in the final report:

- `gated_auto` — code-backed Critical/Important finding with a concrete file/line, a clear fix, and enough confidence for `/kramme:pr:resolve-review` to attempt it.
- `manual` — requires a named human decision, product/process judgment, PR-description update, cross-team ownership, external access, unresolved trace, or explicit approval before a fix is safe. Every manual Critical/Important finding must include `Manual blocker` and `Next human decision`. When a finding plausibly fits both `gated_auto` and `manual`, use `gated_auto`.
- `advisory` — optional suggestion, FYI, low-confidence observation, or quality improvement that should not block merge. Do not use this class for Critical or Important findings.

PR description findings should use the same severity rules as code findings. A materially false claim that would mislead merge approval, release notes, rollback planning, or QA is Important or Critical depending on impact. Minor missing detail is at most a Suggestion and should usually be omitted.

For diffs that change a versioned artifact surface or durable public contract, a missing version/changelog/migration story is a release coordination finding, not a code fix. Use action class `manual`, location `PR description` or `review-scope`, and name the next human decision: intended SemVer level, changelog/release-note wording, migration guidance, or confirmation that there is no versioned consumer contract.

The recommended fix for a `PR description` finding is always to update the title/body to match the diff. The diff is the source of truth; the description is the suspect (PR descriptions drift, get written ahead of the final code, or are copied from earlier iterations). If a reviewer believes the code itself is wrong because it does not match the description's stated intent, raise that as a separate code-level finding with a `file:line` location.

**Severity prefix grammar and dead-code ask shape** — label every finding within each bucket using the severity prefix grammar, and emit removal-planner findings using the verbatim dead-code ask shape; both are defined in `references/review-discipline.md`. The section headers (`## Critical Issues`, `## Important Issues`, `## Suggestions`) remain — the prefix is the finer-grained label inside each section.

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

If eligible `gated_auto` Critical or Important code-backed issues were found, include a suggestion to run `/kramme:pr:resolve-review` to automatically address them. Manual findings must remain human follow-up in the report, with manual blockers and next decisions named. Advisory findings stay optional in the report; `/kramme:pr:resolve-review` applies its own safe-advisory test when deciding whether to pick one up. The template in `references/output-template.md` already includes the **Auto-resolution Readiness**, **Recommended Action**, and **Approval Standard** sections; do not omit them.

Before posting (whether to `REVIEW_OVERVIEW.md` or inline), run the pre-posting verification checklist in `references/review-discipline.md` (severity prefixes, dead-code ask shape, Approval Standard line, `NOTICED BUT NOT TOUCHING` labels on out-of-scope notes, emphasized-dimension coverage, `UNVERIFIED` labels on untraced findings).

## Usage Examples

For command examples covering default, aspect-filtered, parallel, emphasized, custom-base, and inline modes, read `references/usage-examples.md`. Keep argument behavior governed by Step 1 and do not treat examples as additional accepted syntax.

## Review discipline

`references/review-discipline.md` holds the reviewer-craft conventions used by every spawned reviewer and by the orchestrator's final-check pass: the output markers (`UNVERIFIED`, `NOTICED BUT NOT TOUCHING`, `CONFUSION`, `MISSING REQUIREMENT`), the common rationalizations to watch for, the red-flag stop list, and the pre-posting verification checklist.

- **Step 7** must pass the output-marker convention to each spawned reviewer so findings come back labeled consistently.
- **Step 13** must run the verification checklist before posting the aggregated report.
