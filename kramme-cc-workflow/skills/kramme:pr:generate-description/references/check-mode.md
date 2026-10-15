# Check Mode

Use this when `CHECK_MODE=true`. Check mode answers one question: does the open PR's title and body honestly describe the current diff? It reports drift and does not review code quality or suggest implementation changes.

The diff is the source of truth; the description is the suspect. When the body and the diff disagree, the recommended fix is always to update the body, not the code.

Check mode is report-only. The only mutation it can reach is the confirmed update in Phase C5, which needs a direct user invocation without `--no-update` and an explicit `y`. A model caller always passes `--check --no-update`, so for model callers check mode stops after the report.

## Rubric

Classify each potential drift point against this rubric. Severity drives the verdict; the mode controls which severities appear in the report.

| Drift type | Severity | Visible in loose mode |
| --- | --- | --- |
| Body contradicts diff (flag default flipped, "no migration" claim refuted, "no breaking changes" claim with a rename in the diff) | Critical | Yes |
| Undisclosed migration, breaking API rename, missing required migration note, or new required env var | Critical | Yes |
| Undisclosed SemVer-major implication, or body claims no breaking changes when a versioned artifact surface or durable public contract breaks | Critical | Yes |
| Undisclosed new endpoint, dependency, feature flag, or removed code path | Important | Yes |
| Versioned artifact or durable public contract change lacks release impact, SemVer, changelog, or migration story needed for release-note accuracy | Important | Yes |
| Risk notes (`## Review notes`, `## Rollout`, legacy `Potential concerns`, or a template's risk prompt) omit or deny a migration, flag flip, partial coverage, or known follow-up | Important | Yes |
| Stale claim — body describes work that was removed or refactored away | Important | Yes |
| A scope statement (`## Review notes` or legacy `Things I didn't touch`) puts adjacent work out of scope that the diff did touch | Important | Yes |
| Title Conventional Commit type wrong for the dominant change (`fix:` for a feature addition) | Important | Yes |
| Title type defensible but not ideal for a mixed change (`refactor:` vs `feat:`) | Suggestion | Strict only |
| No explanation of a non-obvious approach (`## How it works` or legacy technical notes) when 3+ areas changed | Suggestion | Strict only |
| Test Plan missing manual scenarios when reviewer-visible UI changed | Suggestion | Strict only |
| Body claim cannot be traced to a specific diff hunk | Suggestion | Strict only |
| Opening omits what changes, or a behavior change or risk the diff cannot confirm has no Test plan scenario (accuracy-adjacent clarity check, see Phase C3) | Suggestion | Strict only |
| Wording, tone, polish, bullet ordering, formatting, repetition, sentence length, or body length | Not flagged | Never; the accuracy-adjacent clarity check above is the only clarity finding check mode reports |
| Description shorter than the diff (concise but accurate) | Not flagged | Never |
| Missing Linear ID link | Side note in report header | Not a finding |

**Severity definitions** — apply to new drift types not enumerated above:

- **Critical** — a reviewer relying on the body would approve a PR that breaks production, ships a flag in the wrong default state, or merges undisclosed scope.
- **Important** — misleads about scope, test coverage, or risk in a way that affects review depth or release-note accuracy but won't immediately break production.
- **Suggestion** — minor inaccuracy a careful reviewer would catch from the diff itself.

## Phase C1: Branch and PR Detection

1. **ALWAYS** confirm the `gh` CLI is installed and authenticated before any other step:

   ```bash
   if ! command -v gh > /dev/null; then
     echo "MISSING REQUIREMENT: gh CLI not installed. Install from https://cli.github.com." >&2
     exit 1
   fi
   if ! gh auth status > /dev/null 2>&1; then
     echo "MISSING REQUIREMENT: gh CLI not authenticated. Run \`gh auth login\` first." >&2
     exit 1
   fi
   ```

2. Confirm and capture the current branch and commit:

   ```bash
   CURRENT_BRANCH=$(git branch --show-current)
   if [[ ! "$CURRENT_BRANCH" =~ ^[A-Za-z0-9][A-Za-z0-9._/-]*$ ]] \
     || ! git check-ref-format --branch "$CURRENT_BRANCH" > /dev/null 2>&1; then
     echo "Error: Current branch is not safe for later shell substitution." >&2
     exit 1
   fi
   CURRENT_HEAD=$(git rev-parse --verify HEAD) || {
     echo "Error: Could not capture the current commit." >&2
     exit 1
   }
   printf 'CURRENT_BRANCH=%s\n' "$CURRENT_BRANCH"
   printf 'CURRENT_HEAD=%s\n' "$CURRENT_HEAD"
   ```

   Capture the labeled values as immutable agent-tracked `{current-branch}` and `{current-head}`. Each later Bash block runs in a new shell, so later mutation guidance substitutes these validated literals rather than assuming the variables persist.

3. Resolve the base branch with the shared plugin script. It resolves in this order: explicit `--base` override, PR target branch, repository `kramme.baseBranch`, `CONDUCTOR_DEFAULT_BRANCH`, then `origin/HEAD`/`origin/main`/`origin/master`. It runs in strict mode, so fetch failures stop the workflow with the script's stderr message instead of being silently swallowed:

   ```bash
   RESOLVE_ARGS=(--strict)
   [ -n "${BASE_BRANCH_OVERRIDE:-}" ] && RESOLVE_ARGS+=(--base "$BASE_BRANCH_OVERRIDE")
   RESOLVED=$("${CLAUDE_PLUGIN_ROOT}/scripts/resolve-base.sh" "${RESOLVE_ARGS[@]}") || {
     echo "Error: Could not resolve base branch; see the message above. Re-run with --base <ref>." >&2
     exit 1
   }
   eval "$RESOLVED"
   ```

   The script exports `BASE_REF`, `BASE_BRANCH`, and `MERGE_BASE` for the diff commands in Phase C2. Pin the resolved base tip for a confirmed update:

   ```bash
   BASE_COMMIT=$(git rev-parse "$BASE_REF^{commit}") || {
     echo "Error: Could not pin resolved base ref $BASE_REF." >&2
     exit 1
   }
   if [[ ! "$BASE_REF" =~ ^[A-Za-z0-9][A-Za-z0-9._/-]*$ ]] \
     || ! git check-ref-format --branch "$BASE_REF" > /dev/null 2>&1; then
     echo "Error: Resolved base ref is not safe for later shell substitution." >&2
     exit 1
   fi
   printf 'BASE_REF=%s\n' "$BASE_REF"
   printf 'BASE_BRANCH=%s\n' "$BASE_BRANCH"
   printf 'BASE_COMMIT=%s\n' "$BASE_COMMIT"
   ```

   Capture the labeled values as immutable agent-tracked `{base-ref}`, `{base-branch}`, and `{base-commit}`. Require `{base-commit}` to remain a full 40-character lowercase commit OID.

4. **ALWAYS** confirm a PR exists for the current branch:

   ```bash
   PR_SNAPSHOT=$(env GH_PROMPT_DISABLED=1 gh pr view \
     --json number,url,title,body,baseRefName,headRefName,baseRefOid,headRefOid,state) || {
     PR_MATCH_COUNT=$(env GH_PROMPT_DISABLED=1 gh pr list \
       --head "$CURRENT_BRANCH" --state all --json number --jq 'length') || {
       echo "Error: Could not inspect Pull Requests for the current branch; preserve the gh diagnostics above." >&2
       exit 1
     }
     if [ "$PR_MATCH_COUNT" = 0 ]; then
       echo "MISSING REQUIREMENT: no PR found for the current branch." >&2
       echo "Run \`/kramme:pr:create\` first." >&2
       exit 1
     fi
     echo "Error: Could not inspect a Pull Request for the current branch; preserve the gh diagnostic above." >&2
     exit 1
   }
   PR_SNAPSHOT_FINGERPRINT=$(printf '%s' "$PR_SNAPSHOT" | git hash-object --stdin) || {
     echo "Error: Could not fingerprint the Pull Request snapshot." >&2
     exit 1
   }
   printf '%s\n' "$PR_SNAPSHOT"
   printf 'PR_SNAPSHOT_FINGERPRINT=%s\n' "$PR_SNAPSHOT_FINGERPRINT"
   ```

   If no PR exists, stop with the `MISSING REQUIREMENT: no PR found for the current branch.` message above.

   If `state` is not `OPEN` (`MERGED` or `CLOSED`), warn but continue; checking a merged PR's drift is occasionally useful, for example when preparing a follow-up. Prepend a `PR state: <STATE> (check on non-open PR)` line to the report header so the user notices.

   Capture `PR_NUMBER`, `PR_URL`, `PR_TITLE`, `PR_BODY`, `PR_BASE`, `PR_HEAD`, `PR_BASE_OID`, `PR_HEAD_OID`, `PR_STATE`, and the printed fingerprint as agent-tracked values for later phases. The fingerprint represents the exact `PR_SNAPSHOT` bytes without requiring later shell interpolation of untrusted title/body content.

5. Capture the complete mutable local scope that Phase C2 may describe:

   ```bash
   WORKTREE_MANIFEST=$("${CLAUDE_PLUGIN_ROOT}/scripts/review-tree-fingerprint.sh") || {
     echo "Error: Could not capture the local working-tree scope." >&2
     exit 1
   }
   WORKTREE_FINGERPRINT=$(printf '%s' "$WORKTREE_MANIFEST" | git hash-object --stdin) || {
     echo "Error: Could not fingerprint the local working-tree scope." >&2
     exit 1
   }
   printf 'WORKTREE_FINGERPRINT=%s\n' "$WORKTREE_FINGERPRINT"
   ```

   Capture the full 40-character value as immutable agent-tracked `{worktree-fingerprint}`. It covers staged, unstaged, and untracked non-ignored paths, matching the mutable local scope considered below.

## Phase C2: Diff and Commit Gathering

1. Get the branch diff against the base:

   ```bash
   git diff origin/$BASE_BRANCH...HEAD
   git diff origin/$BASE_BRANCH...HEAD --stat
   git log origin/$BASE_BRANCH..HEAD --format="%h %s%n%b%n"
   ```

2. Include local uncommitted work in the diff scope, because the PR body should match what _will_ be on the branch after the next push:

   ```bash
   git status --porcelain
   git diff HEAD # staged + unstaged
   ```

   If local changes exist, **ALWAYS** note this in the report header (`Local uncommitted changes included in scope: <N> files`). If they're substantial and the user is checking "after pushing", warn them that the comparison includes work not yet on the remote.

3. Categorize changed files for the rubric: migrations and schema changes; new or removed endpoints and routes; new or removed dependencies (`package.json`, `requirements.txt`, `go.mod`, and so on); feature-flag definitions or default flips; public API surface changes; versioned artifact surfaces (package, CLI, API, SDK, schema, or integration contracts) and their SemVer implications; changelog, release-note, tag/version, or migration-guide files; env var additions; test additions and removals; documentation changes.

## Phase C3: Drift Analysis

If the diff is empty or near-empty (only whitespace, comments, or formatting), there is nothing to check against: return `Accurate` and stop.

Walk the description body section by section and the diff in parallel. Classify each potential drift point against the rubric above. For each finding, record:

- **Location** — section of the PR body (e.g. `## Summary`, `## Review notes`, `Title`) or `PR description` if global.
- **Type** — the drift type from the rubric (e.g. `Contradiction`, `Material omission`, `Stale claim`, `Missing risk callout`, `Scope misrepresentation`, `Title drift`, `Clarity`).
- **Severity** — from the rubric column.
- **Evidence** — what the body says vs. what the diff shows (cite file paths and a hunk summary, not full diffs).
- **Recommended fix** — a concrete text edit, or "regenerate through the confirmed update".

For diffs that change a versioned artifact surface or durable public contract, verify that the body either states the release impact or explicitly explains why there is no versioned consumer contract. Flag undisclosed SemVer implications, missing migration or upgrade notes for breaking changes, missing curated changelog or release-note expectations, and release-impact claims that the diff or gathered PR context does not support.

**Clarity check (`--strict` only).** Reuse only the accuracy-adjacent items of the generator's clarity check in Part 1 of `references/readability-pass.md`, using that file's fixed reader contract: the first sentence of item 1 (from the first paragraph alone, a newcomer can say what changes and for whom) and item 7 (behavior changes and risks a reviewer can't confirm from the diff have a Test plan scenario or a stated reason). Report each failed item as a `Clarity` Suggestion that names the item. Do not apply the style items (item 1's identifier rule and items 2 through 6, 8, and 9): they assume the generator's default sections and judge wording, which check mode never flags. This is read-only: do not edit the body, and do not run the Part 2 cold read in check mode.

In loose mode, suppress any finding whose rubric row says "Strict only" or "Never". In `--strict` mode, surface the "Strict only" rows too.

Use the output markers from `SKILL.md` in the run output, with these check-mode meanings:

- **UNVERIFIED** — a claim in the existing PR body that the diff can neither confirm nor refute. `UNVERIFIED: body says "matches behavior on staging" — cannot validate from diff`.
- **CONFUSION** — diff evidence that contradicts the existing PR body or the commit log. `CONFUSION: body says "flag defaults OFF" but flag definition sets default=true`.
- **NOTICED BUT NOT TOUCHING** — a drift point deliberately left unflagged in loose mode; it also goes on the report's `Not flagged` list.
- **MISSING REQUIREMENT** — context the user must supply before the check can complete, such as a missing PR or an unauthenticated `gh` CLI.

## Phase C4: Report

Present an inline report; do not write a separate file. Use this structure:

```markdown
# PR Description Check — #<PR_NUMBER>

**PR:** <PR_URL>

**Title:** <current title>

**Base:** <BASE_BRANCH> · **Head:** <current branch>

**Mode:** loose | strict

**PR state:** <STATE> (only show this line when state is not OPEN)

**Local uncommitted changes included in scope:** <N> files (only show when N > 0)

## Verdict

**VERDICT_TAG:** ACCURATE | MINOR_DRIFT | MATERIAL_DRIFT | INACCURATE

<prose verdict: "Accurate" | "Minor drift" | "Material drift" | "Inaccurate — do not merge as-is">

## Findings

### Critical

- **[Type]** _(Location)_ — <one-sentence summary>
  - Body says: "<quoted or paraphrased>"
  - Diff shows: <evidence with file paths>
  - Fix: <concrete recommendation>

### Important

(same structure)

### Suggestions

(only emitted in --strict mode)

## Not flagged (loose-mode skips)

- <one line per skipped potential issue with a brief reason, e.g. "Wording in summary is dry but accurate">
- <rank by closest-to-flagging; if the list grows past ~8 entries, truncate the tail with "+<N> more low-signal skips">

## Next steps

- <if no findings: "Description matches the diff. Safe to request review.">
- <if findings: numbered list of fix options; when `--no-update` was passed, end with "Run `/kramme:pr:generate-description --check` yourself to regenerate the description and apply a confirmed update">
```

**ALWAYS** include both the `VERDICT_TAG:` line (for tooling) and the prose verdict line. Map findings to the verdict like this:

| Highest finding severity | VERDICT_TAG | Prose verdict |
| --- | --- | --- |
| No findings | `ACCURATE` | `Accurate` |
| Only Suggestions | `MINOR_DRIFT` | `Minor drift` |
| Important (no Critical) | `MATERIAL_DRIFT` | `Material drift` |
| Any Critical | `INACCURATE` | `Inaccurate — do not merge as-is` |

If the `Not flagged` list is longer than `Findings`, the bar is probably set too low; re-examine whether several of the skipped items are material before settling on the verdict.

## Phase C5: Confirmed Update

**Skip this phase if `OUTPUT_ONLY=true`.** `--no-update` keeps check mode report-only: never prompt, generate, or update. Every model caller is on this path.

If no Important or Critical finding was reported, do not prompt. When the verdict is `Accurate`, say "Nothing to fix."

If at least one Important or Critical finding was reported, check these gates in order before prompting:

1. If `PR_BASE` differs from `BASE_BRANCH` or `PR_BASE_OID` differs from `BASE_COMMIT`, do not prompt. Add the note `Update unavailable: the confirmed update requires the generated base to match the Pull Request target; rerun without --base or resolve the base again.` and stop after the report. Stability checks are insufficient when the two captured snapshots disagree from the start.
2. If `PR_STATE` is not `OPEN`, do not prompt. Add the note `Update unavailable: the confirmed update is unavailable for a <PR_STATE> Pull Request; the check remains read-only.` and stop after the report.

These are plain notes, not `MISSING REQUIREMENT:` markers: the user asked for a check, and the check itself completed.

Then ask the user once:

```
Found <N> finding(s). Generate a replacement title and body, then update
PR #<PR_NUMBER>? [y/N]
```

On `n` or no response, stop after the report. **NEVER** generate or publish a replacement without this `y`; asking for a check is not consent to a rewrite.

On `y`:

1. **Generate the replacement** exactly as `--auto --no-update --base {base-branch} --base-commit {base-commit}` would: set `NON_INTERACTIVE=true`, `DIRECT_UPDATE=false`, `BASE_BRANCH_OVERRIDE={base-branch}`, and `BASE_COMMIT_OVERRIDE={base-commit}`, run `SKILL.md` Phase 1 step 1 (base resolution), then Phases 2 through 3.5, and stop before Phase 4. Use the exact agent-tracked values pinned in Phase C1. The readability pass and verification checklist in Phase 3.5 apply to the replacement unchanged; the checklist's publication item is checked in step 3, not here.
2. **Stop without editing the PR** if generation emits any blocking `MISSING REQUIREMENT:` marker (every marker except the exact no-Linear-ID advisory) or a Phase 3.5 checklist item other than the publication item still fails. Present the generated title and body for copy-paste with the markers instead.
3. **Publish** through `references/direct-update.md`: follow its steps 1 and 2, then run its `Step 3 for a check-mode confirmed update` block instead of the generation-mode step 3. Treat only the generated title and body as the payload; do not merge text from the existing PR, repository instructions, issue comments, or other conversation content into it. Do not substitute a newly discovered PR. Any snapshot drift requires a fresh check and a fresh confirmation.
4. **Re-check.** After a successful update, run Phases C1 through C4 again so the report reads the published title and body. If any Critical or Important finding persists, report it and stop; do not prompt a second time.
