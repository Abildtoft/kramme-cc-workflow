---
name: kramme:pr:finalize
description: (experimental) Final PR readiness orchestration. Coordinates verify:run, pr:code-review, pr:product-review, pr:ux-review, qa, and pr:generate-description. Produces a ready/not-ready/ready-with-caveats verdict. Not for creating PRs, fixing CI, or merging code.
argument-hint: "[--auto] [--fix] [--skip <skill,...>] [--app-url <url>] [--base <branch>]"
disable-model-invocation: true
user-invocable: true
kramme-platforms: [claude-code, codex]
---

# PR Finalize — Readiness Orchestration

Coordinate all pre-merge quality checks and produce a single readiness verdict. This skill runs verification, code review, product review, UX review, QA, and description generation in sequence, aggregating results into an actionable assessment.

**Arguments:** "$ARGUMENTS"

## Workflow

### Step 1: Parse Arguments

1. If `--auto` → set `AUTO_MODE=true`.
2. If `--fix` → set `FIX_MODE=true`.
3. If `--skip <skill,...>` → parse comma-separated list of skill short names to skip. Valid values: `verify`, `code-review`, `product-review`, `ux-review`, `qa`, `generate-description`. Store as `SKIP_LIST`.
4. If `--app-url <url>` → store as `APP_URL` (enables QA testing against a running app).
5. If `--base <branch>` → store as `BASE_BRANCH_OVERRIDE`.
6. All flags are optional. Default: run all applicable steps, no app URL, auto-detect base.

`--auto` means:

- skip the execution-plan confirmation
- run all applicable steps unless explicitly skipped
- if QA is applicable, run `diff-aware`
- if description generation is applicable, run it automatically without prompting

`--fix` means:

- after the initial verdict, if eligible `gated_auto` code-backed critical or important findings exist, hand only that bounded payload to `kramme:pr:resolve-review` in its gated implement-only path
- re-run verification after fixes to produce an updated verdict
- does NOT fix suggestions, manual findings, advisory findings, or process-only blockers — only eligible `gated_auto` code-backed critical/important findings
- does NOT resolve process-only blockers; those remain manual follow-up
- does NOT bypass the resolver's rollback checkpoint, verification, or human-input safety gates

### Step 2: Pre-Validation

#### 2.1 Verify Git Repository

```bash
git rev-parse --is-inside-work-tree 2> /dev/null
```

If not a git repo → abort with error.

#### 2.2 Verify Feature Branch

```bash
CURRENT_BRANCH=$(git branch --show-current)
```

If `$CURRENT_BRANCH` is `main` or `master`:

```
Error: Cannot finalize from the main/master branch.

Switch to a feature branch first:
  git checkout <feature-branch>

Then run /kramme:pr:finalize again.
```

**Action:** Stop.

#### 2.3 Resolve Base Branch

Read `references/base-branch-resolution.md` and follow it to compute `BASE_BRANCH`.

#### 2.4 Verify Changes Exist

```bash
CHANGE_COUNT=$({
  git diff --name-only "$MERGE_BASE"...HEAD
  git diff --name-only --cached
  git diff --name-only
  git ls-files --others --exclude-standard
} | sed '/^$/d' | sort -u | wc -l)
```

If `$CHANGE_COUNT` is 0:

```
No changes detected compared to {BASE_REF}.

Nothing to finalize. Make changes first, then run /kramme:pr:finalize again.
```

**Action:** Stop.

### Step 3: Determine Scope

#### 3.1 Identify Changed Files

Reuse the `MERGE_BASE` computed in Step 2.3. Build a unified change scope (committed + staged + unstaged + untracked):

```bash
{
  git diff --name-only "$MERGE_BASE"...HEAD  # committed PR diff
  git diff --name-only --cached            # staged local changes
  git diff --name-only                     # unstaged local changes
  git ls-files --others --exclude-standard # untracked local files
} | sed '/^$/d' | sort -u
```

Store as `CHANGED_FILES` and count as `FILE_COUNT`.

#### 3.2 Determine UI Relevance

Read `references/ui-relevance-heuristics.md` and apply its extension and directory patterns to each entry in `CHANGED_FILES`.

Set `HAS_UI_CHANGES=true` if ANY changed file matches. Otherwise `HAS_UI_CHANGES=false`.

### Step 4: Present Execution Plan

Read `references/execution-plan-prompts.md`, display the populated plan, and apply its confirmation/customization flow. If `AUTO_MODE=true`, skip only this plan confirmation; still honor every downstream safety gate, missing-requirement stop, and sub-skill confirmation for destructive or high-impact operations.

### Step 5: Execute Verification

**Skip if** `verify` is in `SKIP_LIST`.

Invoke via Skill tool:

```
skill: "kramme:verify:run"
```

Capture the result. Record pass/fail status.

**If verification fails:** Record as blocker. **CONTINUE** with remaining steps — do not abort.

See [Error Handling](#error-handling) for skill-error treatment.

### Step 6: Execute Code Review

**Skip if** `code-review` is in `SKIP_LIST`.

Delete any stale overview file so a failed run cannot be misread:

```bash
rm -f REVIEW_OVERVIEW.md
```

Note: deleting the overview also discards the producer's previously-addressed-findings memory, so findings dismissed in earlier runs may re-appear on finalize re-runs — stale-file avoidance wins this tradeoff.

Invoke via Skill tool (never pass `--inline` — this skill requires the file output):

```
skill: "kramme:pr:code-review", args: "--base {BASE_BRANCH}"
```

After completion, if `REVIEW_OVERVIEW.md` does not exist in the project root, treat as `COULD NOT RUN: overview file not produced`. Otherwise parse it:

Read `references/review-result-parsing.md` and apply its code-review parsing rules, including `ELIGIBLE_REVIEW_FIXES` construction and blocker classification.

See [Error Handling](#error-handling) for skill-error treatment.

### Step 7: Execute Product Review

**Skip if** `product-review` is in `SKIP_LIST`.

```bash
rm -f PRODUCT_REVIEW_OVERVIEW.md
```

Same tradeoff as Step 6: this discards the previously-addressed-findings memory, so previously dismissed findings may re-appear on re-runs.

Invoke via Skill tool (do not pass `--inline`):

```
skill: "kramme:pr:product-review", args: "--base {BASE_BRANCH}"
```

After completion, if `PRODUCT_REVIEW_OVERVIEW.md` does not exist, treat as `COULD NOT RUN: overview file not produced`. Otherwise parse it:

Read `references/review-result-parsing.md` and apply its product-review overview parsing rules.

See [Error Handling](#error-handling) for skill-error treatment.

### Step 8: Execute UX Review (Conditional)

**Skip if** ANY of:

- `ux-review` is in `SKIP_LIST`
- `HAS_UI_CHANGES` is false

```bash
rm -f UX_REVIEW_OVERVIEW.md
```

Same tradeoff as Step 6: this discards the previously-addressed-findings memory, so previously dismissed findings may re-appear on re-runs.

Invoke via Skill tool (do not pass `--inline`). When product review also ran (Step 7 was not skipped), pass `--categories ux,visual,a11y` so the `kramme:product-reviewer` agent — which ux-review otherwise always launches — does not review the same diff twice and get its findings double-counted in Step 10:

```
skill: "kramme:pr:ux-review", args: "--base {BASE_BRANCH} --categories ux,visual,a11y"
```

If product review was skipped (`product-review` in `SKIP_LIST` or `COULD NOT RUN`), invoke without `--categories` so ux-review keeps its full default coverage:

```
skill: "kramme:pr:ux-review", args: "--base {BASE_BRANCH}"
```

After completion, if `UX_REVIEW_OVERVIEW.md` does not exist, treat as `COULD NOT RUN: overview file not produced`. Otherwise parse it:

- Count findings by severity: critical, important, suggestion
- Critical findings = blockers

See [Error Handling](#error-handling) for skill-error treatment.

### Step 9: Execute QA (Conditional)

**Skip if** ANY of:

- `qa` is in `SKIP_LIST`
- `HAS_UI_CHANGES` is false
- `APP_URL` was not provided

Read `references/qa-and-description-prompts.md` and follow its QA prompt/invocation flow. Parse QA results for blockers, major issues, and minor issues.

See [Error Handling](#error-handling) for skill-error treatment.

### Step 10: Assess Readiness

Aggregate all results into a verdict. Explicitly skipped steps (`--skip` or conditional skip) are not caveats; failures and `COULD NOT RUN` are.

Before choosing the verdict, read `references/residual-work.md` and run the residual-work gate.

**READY:**

- Verification passed (or skipped)
- No critical findings from any review
- No QA blockers
- No skills recorded as `COULD NOT RUN`
- All residual work is `fixed_now` or `not_relevant`

**READY WITH CAVEATS:**

- Verification passed (or skipped)
- No critical findings from any review
- No QA blockers
- No residual item is `blocked_by_missing_information` or unclassified
- BUT one or more of: important findings exist, suggestions exist, a non-blocking skill could not run, or residual work is classified as `deferred_with_owner` or `accepted_risk`

**NOT READY:**

- Verification failed, OR
- Critical findings exist in any review, OR
- QA blockers found, OR
- Any residual work is unclassified or `blocked_by_missing_information`

### Step 11: Auto-Fix (Conditional)

**Skip if** `FIX_MODE` is not true, OR the verdict is **READY**.

If `FIX_MODE=true` and one or more eligible `gated_auto` code-backed critical or important code-review findings exist:

1. Build a caller-scoped findings payload from `ELIGIBLE_REVIEW_FIXES`. Include only findings whose action class is `gated_auto` and whose location is `path/to/file:line`. Do not include `manual`, `advisory`, `review-scope`, `PR description`, or legacy entries without an explicit auto-resolvable marker.

2. Run `kramme:pr:resolve-review` in implement-only mode with that payload:

   ```
   skill: "kramme:pr:resolve-review", args: "--implement-only --severity critical,important {ELIGIBLE_REVIEW_FIXES_PAYLOAD}"
   ```

   Do **not** use `--source local` for this handoff. Local-source mode re-reads the entire `REVIEW_OVERVIEW.md` and would allow manual or advisory critical/important findings into the auto-fix path.

3. After resolve-review completes, read `.context/resolve-review/implement-only-summary.json` if present and use it to classify each eligible finding as fixed, deferred, or blocked.

4. Re-run verification:

   ```
   skill: "kramme:verify:run"
   ```

5. Re-assess the verdict using the same logic as Step 10, incorporating the updated state.

6. Update the verdict, findings counts, and residual-work dispositions to reflect what was fixed.

If no eligible `gated_auto` code-backed critical/important code-review findings remain and the remaining blocker is process-level only, do **not** run `resolve-review`; keep the verdict and tell the user the follow-up is manual.

If resolve-review fails or introduces new issues, keep the original verdict and note the failure.

### Step 12: Display Verdict

Render the verdict inline (no artifact file) using the template and per-verdict next-steps guidance in `references/verdict-template.md`. Substitute counts and status from Steps 5–10.

### Step 13: Optionally Generate Description

**Skip if** `generate-description` is in `SKIP_LIST`.

Read `references/qa-and-description-prompts.md` and follow its PR description prompt/invocation flow. If the skill errors out, report the error but do not fail the overall assessment.

Direct update path marker: `skill: "kramme:pr:generate-description", args: "--auto --base {BASE_BRANCH}"`; the sub-skill handles backup creation and `--body-file` application.

## Explicit Non-Goals

pr:finalize does NOT:

- Create the PR itself (use `/kramme:pr:create`)
- Fix CI failures (use `/kramme:pr:fix-ci`)
- Merge code
- Replace detailed review commands — each sub-skill produces its own detailed report
- Silently mutate the branch — without `--fix`, no commits, rebases, or file modifications occur. With `--fix`, resolve-review may create commits (with a rollback checkpoint)

Side effects to be aware of:

- Step 13 may overwrite an open PR's description when "Generate and update" is selected (or when `--auto` is set and a PR exists). Use `--skip generate-description` to opt out.

## Error Handling

- **Individual skill failure:** When a sub-skill errors out or returns a non-zero result, record as `COULD NOT RUN: {error message}`, continue with remaining steps, and include the entry as a caveat in the final verdict.
- **Expected overview file missing:** When a review sub-skill completes but its overview file (`REVIEW_OVERVIEW.md`, `PRODUCT_REVIEW_OVERVIEW.md`, `UX_REVIEW_OVERVIEW.md`) is not present, treat as `COULD NOT RUN: overview file not produced` rather than zero findings.
- **User aborts:** Stop immediately. Report what completed so far and what was skipped.
- **No changes detected:** Stop early with clear message (Step 2.4).
- **On main/master branch:** Stop with error (Step 2.2).
- **Base branch not found:** Stop with error and suggest `--base <branch>` (Step 2.3).

## Usage Examples

```
/kramme:pr:finalize                                           # all applicable steps
/kramme:pr:finalize --app-url http://localhost:3000            # with QA testing
/kramme:pr:finalize --skip qa,ux-review                       # skip specific steps
/kramme:pr:finalize --app-url http://localhost:4200 --base develop  # custom base + app URL
/kramme:pr:finalize --fix                                     # auto-fix critical/important findings
/kramme:pr:finalize --auto --fix                              # full automation + auto-fix
/kramme:pr:finalize --skip verify,qa                          # skip verification and QA
```
