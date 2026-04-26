---
name: kramme:pr:finalize
description: (experimental) Final PR readiness orchestration. Coordinates verify:run, pr:code-review, pr:product-review, pr:ux-review, qa, and pr:generate-description. Produces a ready/not-ready/ready-with-caveats verdict. Not for creating PRs, fixing CI, or merging code.
argument-hint: "[--auto] [--fix] [--skip <skill,...>] [--app-url <url>] [--base <branch>]"
disable-model-invocation: true
user-invocable: true
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
5. If `--base <branch>` → store as explicit base branch override.
6. All flags are optional. Default: run all applicable steps, no app URL, auto-detect base.

`--auto` means:
- skip the execution-plan confirmation
- run all applicable steps unless explicitly skipped
- if QA is applicable, run `diff-aware`
- if description generation is applicable, run it automatically without prompting

`--fix` means:
- after the initial verdict, if code-backed critical or important findings exist, automatically run `kramme:pr:resolve-review` to address them
- re-run verification after fixes to produce an updated verdict
- does NOT fix suggestions — only critical and important findings
- does NOT resolve process-only blockers; those remain manual follow-up

### Step 2: Pre-Validation

#### 2.1 Verify Git Repository

```bash
git rev-parse --is-inside-work-tree 2>/dev/null
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

Determine the correct base branch using a 3-tier strategy:

**Tier 1: Explicit override**
If `--base <branch>` was provided in Step 1, use that value directly as `BASE_BRANCH`. Skip Tier 2 and 3.

**Tier 2: PR/MR target branch detection**
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
- GitLab MCP alternative if `glab` is unavailable: use `mcp__gitlab__get_merge_request` and extract `target_branch`

**Tier 3: Fallback**
```bash
BASE_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
[ -z "$BASE_BRANCH" ] && BASE_BRANCH=$(git branch -r | grep -E 'origin/(main|master)$' | head -1 | sed 's@.*origin/@@')
```

Normalize before using `origin/$BASE_BRANCH`:
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

#### 2.4 Verify Changes Exist

```bash
BASE_REF=$(git merge-base origin/$BASE_BRANCH HEAD)
CHANGE_COUNT=$({
  git diff --name-only "$BASE_REF"...HEAD
  git diff --name-only --cached
  git diff --name-only
  git ls-files --others --exclude-standard
} | sed '/^$/d' | sort -u | wc -l)
```

If `$CHANGE_COUNT` is 0:
```
No changes detected compared to origin/{BASE_BRANCH}.

Nothing to finalize. Make changes first, then run /kramme:pr:finalize again.
```
**Action:** Stop.

### Step 3: Determine Scope

#### 3.1 Identify Changed Files

Build a unified change scope (committed + staged + unstaged + untracked):
```bash
BASE_REF=$(git merge-base origin/$BASE_BRANCH HEAD)
{
  git diff --name-only "$BASE_REF"...HEAD      # committed PR diff
  git diff --name-only --cached                # staged local changes
  git diff --name-only                         # unstaged local changes
  git ls-files --others --exclude-standard     # untracked local files
} | sed '/^$/d' | sort -u
```

Store as `CHANGED_FILES` and count as `FILE_COUNT`.

#### 3.2 Determine UI Relevance

Read `references/ui-relevance-heuristics.md` for the full pattern list. Check each changed file against:

**Extension patterns:**
- Components: `*.tsx`, `*.jsx`, `*.vue`, `*.svelte`, `*.component.ts`, `*.component.html`
- Templates: `*.html`, `*.hbs`, `*.ejs`, `*.pug`
- Styles: `*.css`, `*.scss`, `*.sass`, `*.less`, `*.styled.ts`, `*.styled.js`, `*.module.css`, `*.module.scss`
- Configuration: `tailwind.config.*`, `theme.*`, files under `design-tokens/`

**Directory patterns:**
- `pages/`, `views/`, `screens/`, `routes/`, `app/`
- `components/`, `widgets/`, `layouts/`, `templates/`
- `styles/`, `css/`
- `public/`, `static/`, `assets/` (only SVG or image files)

Set `HAS_UI_CHANGES=true` if ANY changed file matches. Otherwise `HAS_UI_CHANGES=false`.

### Step 4: Present Execution Plan

Display the plan before running:

```
PR Finalize Plan

Branch: {CURRENT_BRANCH} -> {BASE_BRANCH}
Changed files: {FILE_COUNT}
UI changes detected: {yes/no}

Steps to run:
  1. verify:run            [always]
  2. pr:code-review        [always]
  3. pr:product-review     [always]
  4. pr:ux-review          [if UI changes detected]
  5. qa                    [if UI changes + app URL provided]
  6. pr:resolve-review     [if --fix and critical/important findings]
  7. re-verify             [if --fix applied fixes]
  8. pr:generate-description [if no blockers]

Auto-fix: {yes/no}
Skipped: {any --skip items, or "none"}
```

If `AUTO_MODE=true`, skip this prompt and execute the plan as displayed.

Otherwise use AskUserQuestion to confirm:
```yaml
header: "PR Finalize Plan"
question: "Proceed with this plan?"
options:
  - label: "Run all"
    description: "Execute all applicable steps as shown"
  - label: "Skip QA"
    description: "Run everything except QA testing"
  - label: "Customize"
    description: "Let me choose which steps to run"
  - label: "Abort"
    description: "Cancel without running anything"
multiSelect: false
```

**If "Abort":** Stop immediately.

**If "Skip QA":** Add `qa` to `SKIP_LIST`.

**If "Customize":** Use AskUserQuestion with multiSelect to let user pick steps:
```yaml
header: "Select steps"
question: "Which steps should run?"
options:
  - label: "verify:run"
  - label: "pr:code-review"
  - label: "pr:product-review"
  - label: "pr:ux-review"
  - label: "qa"
  - label: "pr:generate-description"
multiSelect: true
```

### Step 5: Execute Verification

**Skip if** `verify` is in `SKIP_LIST`.

Invoke via Skill tool:
```
skill: "kramme:verify:run"
```

Capture the result. Record pass/fail status.

**If verification fails:** Record as blocker. **CONTINUE** with remaining steps — do not abort.

**If skill errors out:** Record as `COULD NOT RUN: {error message}`. Continue.

### Step 6: Execute Code Review

**Skip if** `code-review` is in `SKIP_LIST`.

Invoke via Skill tool:
```
skill: "kramme:pr:code-review", args: "--base {BASE_BRANCH}"
```

After completion, parse `REVIEW_OVERVIEW.md` in the project root:
- Count findings by severity: critical, important, suggestion
- Inspect each critical/important code-review finding's location:
  - `review-scope` (or any broader non-file scope label) = process-level blocker, manual follow-up
  - `path/to/file:line` = code-backed finding, eligible for `/kramme:pr:resolve-review`
- Keep separate tallies for code-backed vs process-level critical/important code-review findings
- Critical findings = blockers

**If skill errors out:** Record as `COULD NOT RUN: {error message}`. Continue.

### Step 7: Execute Product Review

**Skip if** `product-review` is in `SKIP_LIST`.

Invoke via Skill tool:
```
skill: "kramme:pr:product-review", args: "--base {BASE_BRANCH}"
```

After completion, parse `PRODUCT_REVIEW_OVERVIEW.md` in the project root:
- Count findings by severity: critical, important, suggestion
- Critical findings = blockers

**If skill errors out:** Record as `COULD NOT RUN: {error message}`. Continue.

### Step 8: Execute UX Review (Conditional)

**Skip if** ANY of:
- `ux-review` is in `SKIP_LIST`
- `HAS_UI_CHANGES` is false

Invoke via Skill tool:
```
skill: "kramme:pr:ux-review", args: "--base {BASE_BRANCH}"
```

After completion, parse `UX_REVIEW_OVERVIEW.md` in the project root:
- Count findings by severity: critical, important, suggestion
- Critical findings = blockers

**If skill errors out:** Record as `COULD NOT RUN: {error message}`. Continue.

### Step 9: Execute QA (Conditional)

**Skip if** ANY of:
- `qa` is in `SKIP_LIST`
- `HAS_UI_CHANGES` is false
- `APP_URL` was not provided

If `AUTO_MODE=true`, skip this prompt and run diff-aware QA:
```yaml
skill: "kramme:qa", args: "{APP_URL} diff-aware --base {BASE_BRANCH}"
```

Otherwise confirm with user:
```yaml
header: "QA Testing"
question: "Run QA testing against {APP_URL}? A browser MCP enables live checks; otherwise QA falls back to code-only analysis."
options:
  - label: "Run QA quick"
    description: "Quick smoke test of changed UI areas"
  - label: "Run QA diff-aware"
    description: "Thorough test focused on changed files and their impact"
  - label: "Skip QA"
    description: "Skip QA testing for now"
multiSelect: false
```

**If "Skip QA":** Record as skipped. Continue.

**If "Run QA quick":**
```
skill: "kramme:qa", args: "{APP_URL} quick"
```

**If "Run QA diff-aware":**
```
skill: "kramme:qa", args: "{APP_URL} diff-aware --base {BASE_BRANCH}"
```

Parse QA results for blockers, major issues, and minor issues.

**If skill errors out:** Record as `COULD NOT RUN: {error message}`. Continue.

### Step 10: Assess Readiness

Aggregate all results into a verdict:

**READY:**
- Verification passed (or skipped)
- No critical findings from any review
- No QA blockers
- No skills recorded as `COULD NOT RUN`

**READY WITH CAVEATS:**
- Verification passed (or skipped)
- No critical findings from any review
- No QA blockers
- BUT one or more of: important findings exist, suggestions exist, a skill could not run

**NOT READY:**
- Verification failed, OR
- Critical findings exist in any review, OR
- QA blockers found

### Step 10.5: Auto-Fix (Conditional)

**Skip if** `FIX_MODE` is not true, OR the verdict is **READY**.

If `FIX_MODE=true` and one or more code-backed critical or important code-review findings exist:

1. Run `kramme:pr:resolve-review` to address findings:
   ```
   skill: "kramme:pr:resolve-review", args: "--source local --severity critical,important"
   ```

2. After resolve-review completes, re-run verification:
   ```
   skill: "kramme:verify:run"
   ```

3. Re-assess the verdict using the same logic as Step 10, incorporating the updated state.

4. Update the verdict and findings counts to reflect what was fixed.

If no code-backed critical/important code-review findings remain and the remaining blocker is process-level only, do **not** run `resolve-review`; keep the verdict and tell the user the follow-up is manual.

If resolve-review fails or introduces new issues, keep the original verdict and note the failure.

### Step 11: Display Verdict

Display the assessment inline (no artifact file):

```markdown
## PR Readiness Assessment

**Verdict: READY / READY WITH CAVEATS / NOT READY**

### Verification
Status: PASS / FAIL / SKIPPED / COULD NOT RUN

### Code Review
Status: X critical, Y important, Z suggestions / SKIPPED / COULD NOT RUN

### Product Review
Status: X critical, Y important, Z suggestions / SKIPPED / COULD NOT RUN

### UX Review (if run)
Status: X critical, Y important, Z suggestions / SKIPPED (no UI changes) / COULD NOT RUN

### QA (if run)
Status: X blockers, Y major, Z minor / SKIPPED (no app URL) / COULD NOT RUN

### Blockers (must fix)
1. [source]: description

### Recommended Fixes (should fix)
1. [source]: description

### Optional Polish
1. [source]: description

### Next Steps
{context-dependent recommendations}
```

**Next Steps guidance by verdict:**

- **READY:** "PR is ready. Run `/kramme:pr:create` to create it, or `/kramme:pr:generate-description` to update the description."
- **READY WITH CAVEATS:** "Consider addressing recommended fixes before creating the PR. Run `/kramme:pr:resolve-review` to address findings, or `/kramme:pr:create` to proceed. Alternatively, re-run with `--fix` to auto-resolve critical and important findings."
- **NOT READY:** "Fix blockers first. Run `/kramme:pr:finalize --fix` to auto-resolve code-backed critical and important findings, or `/kramme:pr:resolve-review` to address them manually. Process blockers still require manual follow-up."
- **After merge (any verdict):** "For user-facing changes, run `/kramme:launch:rollout` to execute a staged post-merge rollout with canary gates and rollback triggers."

### Step 12: Optionally Generate Description

**Skip if** `generate-description` is in `SKIP_LIST`.

If verdict is **READY** or **READY WITH CAVEATS** and `AUTO_MODE=true`, run:
```yaml
skill: "kramme:pr:generate-description", args: "--auto --base {BASE_BRANCH}"
```

Otherwise ask:
```yaml
header: "PR Description"
question: "Generate or update PR description now?"
options:
  - label: "Generate and update"
    description: "Generate description and update the existing PR (if one exists)"
  - label: "Generate for review"
    description: "Generate description for review before applying"
  - label: "Skip"
    description: "Skip description generation"
multiSelect: false
```

**If "Skip":** Done.

**If "Generate and update" or "Generate for review":**
```
skill: "kramme:pr:generate-description", args: "--base {BASE_BRANCH}"
```

If "Generate and update" was selected and a PR already exists, apply the generated description to the PR.

**If skill errors out:** Report error but do not fail the overall assessment.

## Explicit Non-Goals

pr:finalize does NOT:
- Create the PR itself (use `/kramme:pr:create`)
- Fix CI failures (use `/kramme:pr:fix-ci`)
- Merge code
- Replace detailed review commands — each sub-skill produces its own detailed report
- Silently mutate the branch — without `--fix`, no commits, rebases, or file modifications occur. With `--fix`, resolve-review may create commits (with a rollback checkpoint)

## Error Handling

- **Individual skill failure:** Record as `COULD NOT RUN` with the error message. Continue with remaining steps. Include in final verdict as a caveat.
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
