---
name: kramme:pr:resolve-review
description: Resolve findings from code reviews by implementing fixes and documenting changes. Use --team to resolve independent findings in parallel by file area.
argument-hint: "[--team] [--auto] [--implement-only] [--granular] [--severity ...] [--source local|online] [review|url|instructions]"
disable-model-invocation: true
user-invocable: true
---

# Resolve Review Findings

**Not for:** resolving a single inline comment with no structured review, landing unrelated fixes that just happened to be mentioned by a reviewer, or making changes to a branch the user has not asked you to modify.

## Team Mode

If `$ARGUMENTS` contains both `--team` and `--implement-only`, stop and ask the user to choose one mode. `--implement-only` is a single-run code-fix engine for callers that own reply handling; team mode owns its own review summary and reply behavior.

If `$ARGUMENTS` contains `--team`, remove that flag, read `references/team-mode.md`, and follow that workflow instead of the standard workflow below. Pass the remaining arguments through as the team-mode arguments.

## Workflow

### Step 0: Parse arguments

Parse `$ARGUMENTS` for flags. After extracting all flags, the remainder is the **payload**.

**Flags:**

- `--source local|online` (aliases `--local`, `--online`) → `REVIEW_SOURCE`. Default `auto`. If both are selected, or `--source` is given an unknown value, ask the user to pick one and stop.
- `--auto` → `ANSWER_AND_RESOLVE=true`. Permits posting replies and resolving addressed threads on the PR (external reviews only).
- `--implement-only` → `IMPLEMENT_ONLY=true`. Pure code-fix engine mode for callers that own the reply/resolution phase (e.g. `kramme:pr:github-review-reply`): implement and validate fixes but make no GitHub writes, write no review file, and draft no replies (see Step 4). Mutually exclusive with `--auto` and `--team`; if a conflicting flag is given, ask the user to pick one and stop.
- `--team` → Team Mode (see top of file).
- `--granular` → `GRANULAR_COMMITS=true`. One commit per finding.
- `--severity <list>` → `SEVERITY_FILTER`. Comma-separated values from `critical`, `important`, `suggestion`. Findings outside the filter are skipped with **Action taken: Skipped — outside severity filter.**

**Payload classification:**

- URL → external review source. If `REVIEW_SOURCE=local`, ask the user to drop the URL or switch to `--source online`, then stop. Otherwise set `REVIEW_SOURCE=online` and fetch from the URL.
- Review-like prose (file references, code excerpts, structured findings) → the **review to resolve**.
- Plain direction (e.g. "focus on security issues", "only high priority") → **additional instructions**. Apply throughout when prioritizing findings, judging validity, and choosing how to implement fixes.

If the payload contains both review content and direction, treat the bulk as the review and the prefatory text as instructions.

If `IMPLEMENT_ONLY=true`, require an explicit caller-scoped findings payload. The payload must contain at least one finding and, for each finding:

- a stable source identifier (`source_id`, `thread_id`, `comment_id`, or equivalent)
- file path and line or broader scope
- reviewer comment, finding text, or equivalent issue body

Empty input, a PR URL by itself, metadata-only input, or plain direction without findings is invalid. Stop with:

```text
--implement-only requires a caller-scoped findings payload. Pass structured thread/finding data, or rerun without --implement-only to use normal review discovery.
```

Treat the supplied findings as the complete review set. Do not run Step 1 discovery, fetch online review comments, read local review files, or expand beyond the supplied findings, even if the payload includes PR metadata or a PR URL for context.

### Step 1: Find the review

If no review content was provided in Step 0:

**Local review files** (treated as **internal reviews**):

- `REVIEW_OVERVIEW.md` (from `/kramme:pr:code-review`)
- `UX_REVIEW_OVERVIEW.md` (from `/kramme:pr:ux-review`)
- `PRODUCT_REVIEW_OVERVIEW.md` (from `/kramme:pr:product-review`)
- `COPY_REVIEW_OVERVIEW.md` (from `/kramme:pr:copy-review`)

When parsing these files, accept the structured `- Location:` field, `**Location:**`, and legacy `**File:**` labels.

**Fetching from GitHub** (treated as **external reviews**):

- Use the PR URL provided in arguments or chat if present; otherwise the current branch's PR.
- Commands: `gh pr view --json reviews,comments` and `gh api repos/{owner}/{repo}/pulls/{number}/comments`.

**By source mode:**

1. `REVIEW_SOURCE=local` — read local review files from the list above. If exactly one exists, use it. If multiple exist, ask which one to resolve. If none exist, ask the user to provide review content, switch to `--source online`, or run one of the PR review producers first.
2. `REVIEW_SOURCE=online` — fetch from GitHub.
3. `REVIEW_SOURCE=auto` — try local files first (if multiple exist, ask which to resolve). If none, scan chat for review content or a PR URL. If still nothing, fetch from GitHub.

If no review is found for the selected mode, ask the user to provide review content, provide a PR URL, or choose a different mode.

Then **list all findings** with location (`file:line` when applicable, otherwise a broader scope label such as `review-scope`) and content. For old `REVIEW_OVERVIEW.md` files without an explicit location field, fall back to inline `[location]` text when present.

For local review files that include the structured `/kramme:pr:code-review` finding schema, also parse `Finding ID`, `Location`, `Action class`, `Confidence`, `Owner`, and `Evidence` for each finding:

- `Action class: gated_auto` with a concrete `path/to/file:line` location is eligible for implementation.
- `Action class: manual` is not auto-implementable, even when it has a file location. Defer it with a manual follow-up recommendation unless the user supplied a separate explicit implementation payload that changes the scope.
- `Action class: advisory` is optional. Do not implement it from local auto-discovery unless the user explicitly asks to resolve suggestions or names that finding.
- `review-scope`, `PR description`, and other non-file locations are process-level findings. Defer them with a concrete manual recommendation.
- Legacy local findings without an action class keep the previous location/severity behavior, but do not infer `gated_auto` from a file location when an action class is present.
- For `UX_REVIEW_OVERVIEW.md`, accept legacy per-agent finding IDs (`PROD-NNN`, `VIS-NNN`, and `A11Y-NNN`) from older UX audit reports as source identifiers during the transition to artifact-scoped `UX-NNN` IDs.

### Step 2: Evaluate findings

For each finding, before implementing any fix:

#### 2a. Check for scope creep

First, determine the **PR's intended scope** by examining:

- The PR title and description
- The types of files changed (feature code, tests, configs, etc.)
- The commit messages on the branch
- Any linked issues or tickets

Then, for each finding, ask: **"Is this within the PR's scope?"**

**In scope** — Implement if valid:

- Bug/issue in code that this PR modified
- Missing error handling for new functionality
- Test coverage gaps for the PR's changes
- Documentation for new/changed behavior
- Security or correctness issues in the PR's code

**Out of scope** — Do NOT implement, document for later:

- Refactoring requests for code the PR didn't touch
- Suggestions to add features beyond the PR's goal
- "While you're here, also fix X" in unrelated files
- Style/naming changes in untouched code
- Performance optimizations unrelated to the PR's changes
- Requests to expand the PR's scope significantly
- Process/workflow findings that require reorganizing the branch or PR rather than changing code in place

**Gray area** — Use judgment:

- Small fixes in adjacent code that make the PR's changes cleaner
- Consistency improvements that affect a few lines near the PR's changes
- If unclear, **ask the user** whether to include or defer

#### 2b. Assess validity (for in-scope findings only)

For external reviews:

- **Assess validity** — Determine if you agree with the reviewer's comment
- **If you disagree** — Note your reasoning; you may still implement if it's a matter of preference, or skip if the suggestion would harm code quality
- **If you agree** — Proceed with the fix

For internal reviews (self-generated): Skip this substep and proceed directly to implementation.

#### 2c. Prioritize by severity

- **critical**: Security issues, data loss risks, broken functionality, blocking bugs
- **important**: Performance problems, maintainability concerns, missing error handling
- **suggestion**: Style preferences, naming suggestions, minor refactors

If `SEVERITY_FILTER` is set, skip any finding whose severity is not in the filter. Document skipped findings with **Action taken: Skipped — outside severity filter.**

#### 2d. Apply action-class eligibility

When a finding came from a structured local review and includes an action class, apply the action-class gate before implementation:

- Implement only `gated_auto` findings with concrete file locations.
- Defer `manual` findings with **Action taken: Deferred — manual follow-up required.** Include the owner and evidence when available.
- Acknowledge `advisory` findings with **Action taken: Acknowledged — advisory.** unless the user explicitly asked to resolve suggestions or named that finding.
- Never treat `manual`, `advisory`, `review-scope`, or `PR description` findings as implementation candidates just because they are critical or important.

#### 2e. Dismiss nitpicks with judgment

Not every finding deserves a code change. Dismiss findings that meet ALL of these criteria:

- Severity is **suggestion**
- The suggestion is subjective (style, naming preference, alternative approach that isn't clearly better)
- Implementing it would churn code without measurable improvement

For dismissed findings, document them in the output with **Action taken: Acknowledged — no change.** and a one-line rationale. For external reviews with `ANSWER_AND_RESOLVE=true`, post a polite reply explaining why no change was made, but do NOT mark the thread as resolved (let the reviewer decide).

### Step 2.5: Create rollback checkpoint

If no findings remain after scope, severity, and action-class filtering, skip this step and Step 3, and write a summary-only output in Step 4 (no checkpoint, no fixes, no validation, no stash).

Otherwise create a retry-safe checkpoint before editing. If `.context/resolve-review/checkpoint-*.env` already exists from an unfinished run, inspect the newest checkpoint first. If it references an existing stash object, restore it or ask the user how to proceed before creating another checkpoint; do not create nested checkpoints.

Record the current HEAD and stash any uncommitted work so fix commits land on a clean tree. Store the exact checkpoint metadata under `.context/resolve-review/`:

```bash
mkdir -p .context/resolve-review
CHECKPOINT_FILE=".context/resolve-review/checkpoint-$(date +%Y%m%d%H%M%S).env"
CHECKPOINT_SHA=$(git rev-parse HEAD)
CHECKPOINT_STASH_REF=
CHECKPOINT_STASH_SHA=
if ! git diff --quiet HEAD || [ -n "$(git ls-files --others --exclude-standard)" ]; then
  git stash push -u -m "pre-resolve-review checkpoint $CHECKPOINT_SHA"
  CHECKPOINT_STASH_REF=$(git stash list --format='%gd %s' | awk -v sha="$CHECKPOINT_SHA" '$0 ~ sha { print $1; exit }')
  CHECKPOINT_STASH_SHA=$(git rev-parse "$CHECKPOINT_STASH_REF")
fi
{
  printf 'CHECKPOINT_SHA=%s\n' "$CHECKPOINT_SHA"
  printf 'CHECKPOINT_STASH_REF=%s\n' "$CHECKPOINT_STASH_REF"
  printf 'CHECKPOINT_STASH_SHA=%s\n' "$CHECKPOINT_STASH_SHA"
} > "$CHECKPOINT_FILE"
```

If fixes later fail verification (Step 4), offer to roll back:

```bash
. "$CHECKPOINT_FILE"
git reset --hard "$CHECKPOINT_SHA"
if [ -n "$CHECKPOINT_STASH_SHA" ]; then
  CHECKPOINT_STASH_REF=$(git stash list --format='%gd %H' | awk -v sha="$CHECKPOINT_STASH_SHA" '$2 == sha { print $1; exit }')
  if git stash apply --index "$CHECKPOINT_STASH_SHA"; then
    [ -n "$CHECKPOINT_STASH_REF" ] && git stash drop "$CHECKPOINT_STASH_REF"
  fi
fi
```

Either way, Step 4 restores the exact stash object recorded in `CHECKPOINT_FILE` so the user's pre-existing uncommitted work is restored. Do not use a generic `git stash pop`; it may apply the wrong stash after an interrupted or retried run.

### Step 3: Implement fixes

Work through each finding in priority order, applying the guidelines below.

If a finding is process-level and not implementable as an in-place code change, defer it with a concrete manual recommendation instead of attempting a partial code edit.

**If `GRANULAR_COMMITS=true`:** After implementing each finding, create a dedicated commit for it before moving to the next finding:

```bash
git add -A
git commit -m "review: <brief description of the fix>"
```

Each commit should be self-contained and pass linting/formatting on its own. If a finding requires changes across multiple files, include all of them in the same commit. If two findings touch the same lines and cannot be separated cleanly, combine them into a single commit and note both finding numbers in the message.

### Step 4: Validate and summarize

- **Validate** — Run `kramme:verify:run` and fix any new lint/format/test issues it reports. If validation fails after multiple attempts and `CHECKPOINT_SHA` exists, offer to roll back (see Step 2.5).
- **Implement-only mode** (`IMPLEMENT_ONLY=true`) — Make no GitHub writes, write no review file, and draft no replies. Still run the scope-creep and validity checks (Step 2) and the validation above. Instead of the file output below, write `.context/resolve-review/implement-only-summary.json` atomically (write a temporary file, then rename it into place) and return a short chat summary naming that path. Use this schema:

  ```json
  {
    "schema_version": 1,
    "mode": "implement-only",
    "pr": {
      "number": 123,
      "title": "Optional PR title",
      "url": "Optional PR URL"
    },
    "validation": {
      "status": "passed|failed|not-run",
      "commands": [
        {
          "command": "test command",
          "status": "passed|failed|not-run",
          "summary": "short result"
        }
      ]
    },
    "findings": [
      {
        "source_id": "stable caller-provided finding/comment/thread id",
        "thread_id": "optional GitHub review thread id",
        "comment_id": "optional root comment id",
        "location": "path/to/file.ts:123",
        "status": "implemented|already-addressed|skipped-out-of-scope|skipped-invalid|disagreed|blocked-implementation|blocked-validation",
        "action": "specific code change, or none",
        "rationale": "one-line rationale; required for every non-implemented status",
        "files_changed": ["path/to/file.ts"]
      }
    ]
  }
  ```

  `blocked-implementation` means the fix could not be completed. `blocked-validation` means a fix was attempted but validation failed. Then skip the Reply behavior and Generate summary bullets below.
- **Reply behavior**:
  - `REVIEW_SOURCE=local` or `ANSWER_AND_RESOLVE` unset: do not post replies or resolve threads on GitHub.
  - `ANSWER_AND_RESOLVE=true` on an external review: print `Posting N replies and resolving M threads on PR #X` before any `gh` write so the user can interrupt. Then post a reply for each addressed comment and resolve those threads. For disagreements or out-of-scope findings, post a rationale reply but do not resolve the thread.
- **Generate summary** — Write resolutions back to the source review file (see Output format below). If the source was `UX_REVIEW_OVERVIEW.md`, `PRODUCT_REVIEW_OVERVIEW.md`, or `COPY_REVIEW_OVERVIEW.md`, update that file in place. If the source was `REVIEW_OVERVIEW.md` or an external/chat review, write to `REVIEW_OVERVIEW.md`.
- **Restore the checkpoint** — If a stash was created in Step 2.5, apply and drop the exact recorded stash now so the user's pre-existing uncommitted work is restored:

  ```bash
  . "$CHECKPOINT_FILE"
  CHECKPOINT_RESTORE_STATUS=not-needed
  if [ -n "$CHECKPOINT_STASH_SHA" ]; then
    CHECKPOINT_STASH_REF=$(git stash list --format='%gd %H' | awk -v sha="$CHECKPOINT_STASH_SHA" '$2 == sha { print $1; exit }')
    if git stash apply --index "$CHECKPOINT_STASH_SHA"; then
      [ -n "$CHECKPOINT_STASH_REF" ] && git stash drop "$CHECKPOINT_STASH_REF"
      CHECKPOINT_RESTORE_STATUS=restored
    else
      CHECKPOINT_RESTORE_STATUS=conflicted
    fi
  fi
  ```

  If `git stash apply` reports conflicts, leave the stash in place, keep `CHECKPOINT_FILE`, and tell the user to resolve manually with `git stash apply --index "$CHECKPOINT_STASH_SHA"`. After conflicts are resolved, re-resolve the matching stash ref with `git stash list --format='%gd %H'` and drop that ref.

- **Clean up the consumed checkpoint** — After validation, summary writing, and stash restoration have completed successfully, delete the checkpoint created for this run:

  ```bash
  if [ "${CHECKPOINT_RESTORE_STATUS:-not-needed}" != "conflicted" ]; then
    [ -n "${CHECKPOINT_FILE:-}" ] && rm -f "$CHECKPOINT_FILE"
  fi
  ```

  Keep the checkpoint only when validation failed, rollback is still being considered, or stash restoration ended in conflicts.

## Guidelines

### General principles

- **Write clear, maintainable code** — prioritize readability and simplicity; prefer straightforward solutions over clever ones, but do not be lazy.
- **Add comments where needed** — if a fix involves non-obvious logic or trade-offs, include concise comments explaining the reasoning.
- **Ask questions if unsure** — if any aspect of the fix or the related business logic is unclear, seek clarification before proceeding.
- **Follow project conventions** — ensure fixes align with the best practices outlined in the target project's AGENTS.md (when present).
- **Stay focused** — limit changes to what's necessary for the fix; avoid unrelated refactors or improvements.

### For each fix

- **Understand the root cause** — before making changes, ensure you fully grasp why the issue exists.
- **Be comprehensive within scope** — don't just patch the specific lines mentioned; briefly investigate and apply the same fix pattern wherever the same issue exists in the code touched by this branch.
- **Update tests** — add or adjust appropriate tests to cover any new logic or edge cases.

### When handling errors or external data

- **Consider graceful degradation** — where it makes sense, prefer non-fatal error paths that preserve partial success. However, if failing hard is the safer or more appropriate choice, do that instead and explain why in succinct code comments.
- **Be defensive at boundaries** — when parsing responses from third-party services, external APIs, or user input, normalize/fallback rather than assuming a single format. However, don't over-engineer defensiveness against internal code — trust our own contracts unless there's evidence they're being violated.

## Output format

Write resolutions to the appropriate file in the project root:

- If the source review was `UX_REVIEW_OVERVIEW.md` → update `UX_REVIEW_OVERVIEW.md` in place
- If the source review was `PRODUCT_REVIEW_OVERVIEW.md` → update `PRODUCT_REVIEW_OVERVIEW.md` in place
- If the source review was `COPY_REVIEW_OVERVIEW.md` → update `COPY_REVIEW_OVERVIEW.md` in place
- Otherwise → create or update `REVIEW_OVERVIEW.md`

Updates are **in place**: for each addressed finding, replace its `Action taken:` (and any other resolution fields) inside the existing entry. Findings present in the source but not addressed in this run (severity-filtered, out-of-scope) stay verbatim — never delete entries. If the source did not exist (review came from chat or `gh`), create a fresh `REVIEW_OVERVIEW.md` containing every processed finding.

### For external reviews

Use this format for each comment:

#### Comment #N: [Brief description]

**Location:** `path/to/file.ts:123` or `review-scope`

**Reviewer's comment:**

> [Quote the original review comment]

**Assessment:** Agree / Agree With Modifications / Disagree

**Rationale:** [Why you agree or disagree with this feedback]

**Action taken:** [Description of the fix implemented, or "No action" with explanation]

**Draft reply:**

> [Suggested response to post to the reviewer]

---

### For internal reviews

Use this simplified format for each finding:

#### Finding #N: [Brief description]

**Location:** `path/to/file.ts:123` or `review-scope`

**Issue:** [Description of the issue]

**Action taken:** [Description of the fix implemented]

---

### Out-of-scope section

If any findings were identified as scope creep, document them:

#### Deferred: [Brief description]

**Location:** `path/to/file.ts:123` or `review-scope`

**Finding:**

> [Quote the original finding/comment]

**Reason deferred:** [Why this is out of scope for this PR]

**Recommendation:** [Suggested follow-up: create a separate PR, open an issue, discuss with team, etc.]

---

### Summary section

At the end, include:

- Summary of changes made
- Count of findings: N addressed, M deferred as out-of-scope
- Note any breaking changes to API contracts or config behavior
- Flag areas that need manual verification due to potential edge cases or risk
