---
name: kramme:pr:verify-description
description: Compare an existing PR's title and body against the actual branch diff and report drift — false claims, missing major changes, stale scope, missing risk callouts. Use after pushing changes to a branch with an open PR, or before requesting review. Read-only by default; add --fix to delegate to kramme:pr:generate-description for an updated description. Complements kramme:pr:code-review (which checks description accuracy as one signal among many code-quality checks) by being a fast, focused, single-purpose check that runs in seconds.
argument-hint: "[--fix] [--base <ref>] [--strict]"
disable-model-invocation: false
user-invocable: true
---

# PR Description Verifier

## Parse Arguments

Parse `$ARGUMENTS` for flags:

- `--fix`: After reporting drift, ask the user once whether to delegate to `kramme:pr:generate-description --auto` to regenerate and update the PR body. Default is report-only.
- `--base <ref>`: Use `<ref>` as the base branch for diff computation instead of auto-detecting.
- `--strict`: Tighten the accuracy bar. Flag every bullet in the description that cannot be tied to a diff hunk. Default mode is loose — only contradictions, material omissions, and missing risk callouts surface.

Set `FIX_MODE=true` / `BASE_BRANCH_OVERRIDE=<ref>` / `STRICT_MODE=true` from the flags and remove each flag (and its value) from remaining arguments.

## When to Use This Skill

**Use this skill when:**

- You just pushed new commits to a branch that already has an open PR and want a quick sanity check that the description still matches the code.
- You're about to request review (or move the PR out of draft) and want to confirm the body is honest about scope, risks, and what's in the diff.
- A reviewer left a comment about the description being unclear or wrong and you want a structured drift report before rewriting.

**When NOT to use this skill:**

- The PR doesn't exist yet — use `kramme:pr:generate-description` to draft one instead.
- You want a full code review — use `kramme:pr:code-review` (it includes description accuracy as one of many checks).
- You just want to rewrite the description from scratch — use `kramme:pr:generate-description --auto` directly.

## Scope and Rubric

This skill is **single-purpose**: it answers "does the PR body honestly describe the current diff?" It does not review code quality, suggest implementation changes, or rewrite the description on its own.

Classify each potential drift point against the rubric below. Severity drives the verdict; mode controls which severities surface in the report.

| Drift type | Severity | Visible in loose mode |
| --- | --- | --- |
| Body contradicts diff (flag default flipped, "no migration" claim refuted, "no breaking changes" claim with a rename in the diff) | Critical | Yes |
| Undisclosed migration, breaking API rename, or new required env var | Critical | Yes |
| Undisclosed new endpoint, dependency, feature flag, or removed code path | Important | Yes |
| `Potential concerns: None` despite a migration, flag flip, partial coverage, or known follow-up | Important | Yes |
| Stale claim — body describes work that was removed or refactored away | Important | Yes |
| `Things I didn't touch` excludes adjacent work the diff did touch | Important | Yes |
| Title Conventional Commit type wrong for the dominant change (`fix:` for a feature addition) | Important | Yes |
| Title type defensible but not ideal for a mixed change (`refactor:` vs `feat:`) | Suggestion | Strict only |
| Per-area technical notes missing when 3+ areas changed | Suggestion | Strict only |
| Test Plan missing manual scenarios when reviewer-visible UI changed | Suggestion | Strict only |
| Body claim cannot be traced to a specific diff hunk | Suggestion | Strict only |
| Wording, tone, polish, bullet ordering, formatting | Not flagged | Never |
| Description shorter than the diff (concise but accurate) | Not flagged | Never |
| Missing Linear ID link | Side note in report header | Not a finding |

**Severity definitions** — apply to new drift types not enumerated above:

- **Critical** — a reviewer relying on the body would approve a PR that breaks production, ships a flag in the wrong default state, or merges undisclosed scope.
- **Important** — misleads about scope, test coverage, or risk in a way that affects review depth or release-note accuracy but won't immediately break production.
- **Suggestion** — minor inaccuracy a careful reviewer would catch from the diff itself.

## Workflow

### Phase 1: Branch and PR Detection

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

2. Confirm the current branch:

   ```bash
   git branch --show-current
   ```

3. Resolve the base branch with the shared plugin script. It uses the same 3-tier strategy: explicit `--base` override, PR target branch, then `origin/HEAD`/`origin/main`/`origin/master`. It runs in strict mode, so fetch failures stop the workflow with the script's stderr message instead of being silently swallowed:

   ```bash
   RESOLVE_ARGS=(--strict)
   [ -n "${BASE_BRANCH_OVERRIDE:-}" ] && RESOLVE_ARGS+=(--base "$BASE_BRANCH_OVERRIDE")

   RESOLVED=$("${CLAUDE_PLUGIN_ROOT}/scripts/resolve-base.sh" "${RESOLVE_ARGS[@]}") || {
     echo "Error: Could not resolve base branch; see the message above. Re-run with --base <ref>." >&2
     exit 1
   }
   eval "$RESOLVED"
   ```

   The script exports `BASE_REF`, `BASE_BRANCH`, and `MERGE_BASE` for the diff commands in Phase 2.

4. **ALWAYS** confirm a PR exists for the current branch and is in an open state:

   ```bash
   gh pr view --json number,url,title,body,baseRefName,headRefName,state
   ```

   If no PR exists, stop with:

   ```
   MISSING REQUIREMENT: no PR found for the current branch.
   Run `/kramme:pr:create` or `/kramme:pr:generate-description` first.
   ```

   If `state` is not `OPEN` (i.e. `MERGED` or `CLOSED`), warn but continue — verifying a merged PR's drift is occasionally useful (e.g. when preparing a follow-up). Prepend a `PR state: <STATE> (verification on non-open PR)` line to the report header so the user notices.

   Capture `PR_NUMBER`, `PR_URL`, `PR_TITLE`, `PR_BODY`, `PR_STATE` for downstream phases.

### Phase 2: Diff and Commit Gathering

1. Get the branch diff against the base:

   ```bash
   git diff origin/$BASE_BRANCH...HEAD
   git diff origin/$BASE_BRANCH...HEAD --stat
   git log origin/$BASE_BRANCH..HEAD --format="%h %s%n%b%n"
   ```

2. Include local uncommitted work in the diff scope (the PR body should match what *will* be on the branch after the next push):

   ```bash
   git status --porcelain
   git diff HEAD       # staged + unstaged
   ```

   If local changes exist, **ALWAYS** note this in the report header (`Local uncommitted changes included in scope: <N> files`). If they're substantial and the user is verifying "after pushing", warn them that the comparison includes work not yet on the remote.

3. Categorize changed files for the rubric:

   - Migrations / schema changes
   - New or removed endpoints / routes
   - New or removed dependencies (package.json, requirements.txt, go.mod, etc.)
   - Feature-flag definitions or default flips
   - Public API surface changes (exported symbols renamed, removed, or new)
   - Env var additions
   - Test additions / removals
   - Documentation changes

### Phase 3: Drift Analysis

Walk the description body section-by-section and the diff in parallel. Classify each potential drift point against the rubric in `## Scope and Rubric` above. For each finding, record:

- **Location** — section of the PR body (e.g. `## Summary`, `### Potential concerns`, `Title`) or `PR description` if global.
- **Type** — the drift type from the rubric (e.g. `Contradiction`, `Material omission`, `Stale claim`, `Missing risk callout`, `Scope misrepresentation`, `Title drift`).
- **Severity** — from the rubric column.
- **Evidence** — what the body says vs. what the diff shows (cite file paths and a hunk summary, not full diffs).
- **Recommended fix** — concrete text edit or "regenerate via `kramme:pr:generate-description --auto`".

In loose mode, suppress any finding whose rubric row says "Strict only" or "Never". In `--strict` mode, surface those too.

### Phase 4: Report

Present an inline report (do not write a separate file). Use this structure:

```markdown
# PR Description Verification — #<PR_NUMBER>

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

- **[Type]** *(Location)* — <one-sentence summary>
  - Body says: "<quoted or paraphrased>"
  - Diff shows: <evidence with file paths>
  - Fix: <concrete recommendation>

### Important

(same structure)

### Suggestions

(only emitted in --strict mode)

## Not flagged (loose-mode skips)

- <one line per skipped potential issue with a brief reason, e.g. "Wording in summary is dry but accurate">
- <rank by closest-to-flagging; if list grows past ~8 entries, truncate the tail with "+<N> more low-signal skips">

## Next steps

- <if no findings: "Description matches the diff. Safe to request review.">
- <if findings: numbered list of fix options, ending with "Run `/kramme:pr:verify-description --fix` to regenerate via kramme:pr:generate-description --auto">
```

**ALWAYS** include both the `VERDICT_TAG:` line (for tooling) and the prose verdict line. Map findings to verdict like this:

| Highest finding severity | VERDICT_TAG | Prose verdict |
| --- | --- | --- |
| No findings | `ACCURATE` | `Accurate` |
| Only Suggestions | `MINOR_DRIFT` | `Minor drift` |
| Important (no Critical) | `MATERIAL_DRIFT` | `Material drift` |
| Any Critical | `INACCURATE` | `Inaccurate — do not merge as-is` |

### Phase 5: Optional Fix Delegation

**Skip this phase if `FIX_MODE` is not set.**

If `FIX_MODE=true` and at least one Important or Critical finding was reported, ask the user once:

```
Found <N> finding(s). Regenerate the PR description by running
`/kramme:pr:generate-description --auto`? [y/N]
```

- On `y`: invoke the `kramme:pr:generate-description` skill with `--auto` (it will detect the existing PR and update it directly). Then re-run Phase 1-4 of this skill to verify the regenerated body actually resolves the findings — if any Critical or Important finding persists, report it and stop.
- On `n` or no response: stop. Print the report and exit.
- If `FIX_MODE=true` but the verdict was `Accurate`, do not prompt — just confirm "Nothing to fix."
- If `kramme:pr:generate-description` is not available in this environment, report the drift findings only, note `MISSING REQUIREMENT: kramme:pr:generate-description not installed; --fix unavailable`, and stop. Do not attempt to rewrite the PR body manually.

**NEVER** invoke `kramme:pr:generate-description` automatically without the y/N confirmation, even in `FIX_MODE`. The user opted into fixing, not into a silent rewrite.

## Output Markers

Use these uppercase markers in the report (and in conversation output around it) so the user can audit decisions:

- **UNVERIFIED** — a description claim you could not confirm or refute from the diff alone. `UNVERIFIED: body says "matches behavior on staging" — cannot validate from diff`.
- **CONFUSION** — diff evidence that contradicts the body or the commit log. `CONFUSION: body says "flag defaults OFF" but flag definition sets default=true`.
- **NOTICED BUT NOT TOUCHING** — drift you spotted but deliberately did not flag in loose mode (move to a `Not flagged` line in the report). `NOTICED BUT NOT TOUCHING: title says "fix" but change is small enough that "fix" is defensible`.
- **MISSING REQUIREMENT** — context the user must supply before verification can complete. `MISSING REQUIREMENT: no open PR for current branch`.

## Common Rationalizations

Watch for these — each one means a finding is about to be wrongly suppressed:

- *"The diff is small, the description doesn't need to cover everything."* → Size doesn't excuse contradictions. A two-line diff that flips a default still needs that line in the body.
- *"The reviewer can see the migration in the file tree."* → The body's `Potential concerns` block is the contract; visible-in-diff does not equal disclosed.
- *"The title says `fix` but it's basically a fix."* → Conventional Commit type drives changelogs and release notes. If the dominant change is a feature, the title is wrong regardless of how the author thinks of it.
- *"`Things I didn't touch: None` is fine — the author probably considered it."* → Only fine when nothing adjacent was changed. If the diff touches adjacent files, the block needs an entry.
- *"The author will rewrite the description before merge anyway."* → Maybe — but the point of this skill is to remove that step or to make it explicit now, not to assume future cleanup.

## Red Flags — STOP

Pause and re-examine the diff if any of these are true while drafting the report:

- You're about to return `Accurate` but the diff contains a migration, feature-flag default, or breaking change.
- You're tempted to soften a Critical finding to Important because "the author probably knows".
- The report has more `Not flagged` entries than `Findings` — that usually means the bar is set too low; reconsider whether several of the skipped items are actually material.
- You're about to invoke `kramme:pr:generate-description --auto` without explicit user confirmation.
- The diff is empty or near-empty (only whitespace, comments, or formatting) — there's nothing to verify against; return `Accurate` and stop.

## Verification

Before presenting the report, self-check:

- [ ] `gh` CLI was confirmed installed and authenticated; missing-tool exit was clean (`MISSING REQUIREMENT`), not an opaque stderr dump.
- [ ] PR existence was confirmed; if none, the skill exited with a `MISSING REQUIREMENT` message rather than improvising.
- [ ] Non-open PR state was surfaced in the report header rather than ignored.
- [ ] Base branch was detected and `origin/$BASE_BRANCH` was fetched successfully.
- [ ] Diff scope explicitly includes local uncommitted changes if any exist, and the report header says so.
- [ ] Every finding has a Location, Type, Severity, Evidence (with file paths), and Recommended fix.
- [ ] Severity assignments follow the rubric in `## Scope and Rubric` — Critical is reserved for merge-blocking misinformation.
- [ ] Loose-mode reports contain only Important and Critical findings; Suggestions appear only under `--strict`.
- [ ] Both `VERDICT_TAG:` and the prose verdict are present and match the highest finding severity.
- [ ] `--fix` flow asked for y/N confirmation before delegating to `kramme:pr:generate-description`, and stopped cleanly if the sibling skill is unavailable.
- [ ] Report was emitted inline; no file was written.
- [ ] No code review findings (style, types, security, performance) appear in the report — that's `kramme:pr:code-review`'s job.

## Notes

- This skill is read-only by default. The only side effect is the optional `--fix` delegation, which itself requires explicit user confirmation.
- The diff is the source of truth; the description is the suspect. When the body and the diff disagree, the recommended fix is always to update the body, not the code.
- Suggestions are intentionally suppressed in loose mode to keep the signal-to-noise ratio high. Reviewers rerunning this skill should not be drowning in nits.
- This skill complements `kramme:pr:code-review`, which checks description accuracy as one signal among many. Use this skill when you only need the description check and want it fast; use `pr:code-review` when you want a full quality pass.
