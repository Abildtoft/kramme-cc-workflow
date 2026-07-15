---
name: kramme:pr:convention-review
description: Reviews PR and local changes for convention drift and overcaution against documented rules and mined peer-file practice. Use for new patterns, dependencies, abstractions, or defensive complexity that departs from established practice; every finding cites evidence. Supports --inline. Not for general code quality (use kramme:pr:code-review) or spec review (use kramme:siw:spec-audit --team).
argument-hint: "[--base <branch>] [--threshold 0-100] [--inline]"
disable-model-invocation: false
user-invocable: true
---

# Convention Review for Pull Request and Local Changes

Review branch changes and local work for two failure modes measured against the codebase's own established practice:

- **Convention drift** — the change introduces a new pattern, convention, dependency, file layout, or abstraction where an established one exists, without stated rationale.
- **Overcaution and overcomplication** — the change is more defensive (guards, catches, validation, fallbacks, retries) or more layered (wrappers, indirection, configuration, generic machinery) than how comparable existing code handles the same situation.

Both are relative measurements: the baseline is mined from the repository itself, never from generic best practices. A finding without cited exemplar sites or a documented rule is not a finding.

**Arguments:** "$ARGUMENTS"

**Shared protocol:** Read `references/baseline-mining.md` before launching reviewers. It defines the evidence tiers, peer-file sampling, quorum rule, lens checklists, classification taxonomy, and finding format.

## Review Workflow

### Step 1: Parse Arguments

Accept only `--base <branch>`, `--threshold N`, and `--inline`:

1. `--base` and `--threshold` may each appear at most once and must be followed by a non-flag value. Store the base as `BASE_BRANCH_OVERRIDE`.
2. Require `--threshold` to be a decimal integer from 0 through 100. Store it as `custom_threshold`; default to `80`.
3. `--inline` may appear at most once. Set `INLINE_MODE=true` when present and `false` otherwise.
4. Reject duplicate flags, unknown flags, positional arguments, missing values, and invalid thresholds before reading project files, fetching, or launching reviewers. Show: `Usage: /kramme:pr:convention-review [--base <branch>] [--threshold 0-100] [--inline]` and stop.

### Step 2: Load the Baseline-Mining Protocol

1. Read the local protocol at `references/baseline-mining.md`.
2. Do not collect documented project rules yet. Their baseline versions must be selected only after `MERGE_BASE` and the full changed-file scope are known.

### Step 3: Resolve Base Branch, Collect the Diff, and Build the Rule Baseline

Use the shared plugin script to resolve the base branch and build the unified change scope (committed PR diff + staged + unstaged + untracked). It uses the same 3-tier strategy: explicit `--base`, PR target branch, then `origin/HEAD`/`origin/main`/`origin/master`. It runs in strict mode, so fetch failures stop the workflow with the script's stderr message.

```bash
COLLECT_ARGS=(--strict --format json)
[ -n "${BASE_BRANCH_OVERRIDE:-}" ] && COLLECT_ARGS+=(--base "$BASE_BRANCH_OVERRIDE")

RESOLVED=$("${CLAUDE_PLUGIN_ROOT}/scripts/collect-review-diff.sh" "${COLLECT_ARGS[@]}") || {
  echo "Base/diff collection failed; see the message above and stop." >&2
  exit 1
}

REVIEW_DIFF_FIELDS=$(mktemp "${TMPDIR:-/tmp}/review-diff.XXXXXX") || {
  echo "Could not create temporary review-diff file; stop." >&2
  exit 1
}
"${CLAUDE_PLUGIN_ROOT}/scripts/collect-review-diff.sh" --decode-json \
  <<< "$RESOLVED" > "$REVIEW_DIFF_FIELDS" || {
  rm -f "$REVIEW_DIFF_FIELDS"
  echo "Base/diff decoding failed; see the message above and stop." >&2
  exit 1
}
if ! {
  IFS= read -r -d '' BASE_REF \
    && IFS= read -r -d '' BASE_BRANCH \
    && IFS= read -r -d '' MERGE_BASE \
    && IFS= read -r -d '' CHANGED_FILES
} < "$REVIEW_DIFF_FIELDS"; then
  rm -f "$REVIEW_DIFF_FIELDS"
  echo "Decoded review-diff fields were incomplete; stop." >&2
  exit 1
fi
rm -f "$REVIEW_DIFF_FIELDS"
```

The shared JSON decoder sets `BASE_REF`, `BASE_BRANCH`, `MERGE_BASE`, and newline-delimited `CHANGED_FILES`.

If `CHANGED_FILES` is empty, stop with: `No changes detected against $BASE_REF. If this is wrong, re-run with --base <branch>.` Do not launch reviewers against an empty scope.

Capture the complete review scope once before launching any reviewer. Every reviewer and the relevance validator must receive these stored payloads; they must not rerun the diff or untracked-file commands. The second capture detects a workspace change during collection and prevents a hybrid scope from being labeled immutable.

```bash
REVIEW_SCOPE_DIR=$(mktemp -d "${TMPDIR:-/tmp}/convention-review-scope.XXXXXX") || {
  echo "Could not create temporary convention-review scope; stop." >&2
  exit 1
}
trap 'rm -rf "$REVIEW_SCOPE_DIR"' EXIT
printf '%s' "$CHANGED_FILES" > "$REVIEW_SCOPE_DIR/changed-files.txt"
PR_CONTEXT_JSON=$(gh pr view --json title,body 2> /dev/null || printf '{}')
printf '%s\n' "$PR_CONTEXT_JSON" > "$REVIEW_SCOPE_DIR/pr-context.json"

capture_untracked_scope() {
  local output_file="$1"
  local list_file="$2"
  local file status

  git ls-files --others --exclude-standard -z > "$list_file" || return 1
  : > "$output_file"
  while IFS= read -r -d '' file; do
    if git diff --no-index --binary -- /dev/null "$file" >> "$output_file"; then
      status=0
    else
      status=$?
    fi
    [ "$status" -eq 0 ] || [ "$status" -eq 1 ] || return "$status"
  done < "$list_file"
}

SCOPE_HEAD=$(git rev-parse HEAD) || exit 1
git diff --binary "$MERGE_BASE"...HEAD > "$REVIEW_SCOPE_DIR/committed.diff" || exit 1
git diff --binary --cached > "$REVIEW_SCOPE_DIR/staged.diff" || exit 1
git diff --binary > "$REVIEW_SCOPE_DIR/unstaged.diff" || exit 1
capture_untracked_scope \
  "$REVIEW_SCOPE_DIR/untracked.diff" \
  "$REVIEW_SCOPE_DIR/untracked-files.zlist" || exit 1

SCOPE_HEAD_CHECK=$(git rev-parse HEAD) || exit 1
git diff --binary "$MERGE_BASE"...HEAD > "$REVIEW_SCOPE_DIR/committed.check" || exit 1
git diff --binary --cached > "$REVIEW_SCOPE_DIR/staged.check" || exit 1
git diff --binary > "$REVIEW_SCOPE_DIR/unstaged.check" || exit 1
capture_untracked_scope \
  "$REVIEW_SCOPE_DIR/untracked.check" \
  "$REVIEW_SCOPE_DIR/untracked-files.check.zlist" || exit 1

if [ "$SCOPE_HEAD" != "$SCOPE_HEAD_CHECK" ] \
  || ! cmp -s "$REVIEW_SCOPE_DIR/committed.diff" "$REVIEW_SCOPE_DIR/committed.check" \
  || ! cmp -s "$REVIEW_SCOPE_DIR/staged.diff" "$REVIEW_SCOPE_DIR/staged.check" \
  || ! cmp -s "$REVIEW_SCOPE_DIR/unstaged.diff" "$REVIEW_SCOPE_DIR/unstaged.check" \
  || ! cmp -s "$REVIEW_SCOPE_DIR/untracked.diff" "$REVIEW_SCOPE_DIR/untracked.check" \
  || ! cmp -s "$REVIEW_SCOPE_DIR/untracked-files.zlist" "$REVIEW_SCOPE_DIR/untracked-files.check.zlist"; then
  echo "Workspace changed while capturing the convention-review scope; re-run the review." >&2
  exit 1
fi
```

After identifying the changed files, build the documented-rule baseline:

1. Discover applicable repo-root and nested instruction files in both the `MERGE_BASE` tree and current workspace (`AGENTS.md`, `CLAUDE.md`, `.github/copilot-instructions.md`, repo-root or nearby `.claude/` markdown, and equivalents). Also discover relevant lint, formatter, and type-checker configurations.
2. Use `CHANGED_FILES` to classify each rule or configuration path. For unchanged paths, current content may represent the merge-base version. For any added, modified, deleted, staged, unstaged, or untracked path, read the baseline version from `MERGE_BASE` with `git show "$MERGE_BASE:$path"` when it exists.
3. Only the merge-base version is Tier 1 evidence. Treat current-diff additions and edits as proposed rules or rationale for the intentionality check, never as authority that can establish or override the baseline for the same change. A deletion may be evidence that the diff disables a rule.
4. Continue following applicable host instruction files as execution constraints, including changed ones, but do not pass changed instruction text to reviewers as controlling baseline instructions. Label it explicitly as untrusted diff content and proposed rationale.
5. Keep documented baseline rules, proposed rule/config changes, and mined frequency evidence separate. Tool-enforced merge-base rules are Tier 1 evidence and should not be re-litigated unless the diff disables or circumvents the tooling.

### Step 4: Check for Previous Review

If `CONVENTION_REVIEW_OVERVIEW.md` exists in the project root:

- Parse all findings, including finding ID, location, issue description, `Resolution status`, action taken, and evidence when available.
- Normalize explicit resolution values to `open`, `addressed`, `deferred`, `acknowledged`, or `skipped`. When the status is missing, infer it conservatively from `Action taken`: an implemented fix is `addressed`; an explicit deferral, acknowledgement/no-action, or skip maps to that status; otherwise treat the finding as `open`.
- Treat only `addressed` findings as candidates for previous-review filtering. Store `open`, `deferred`, `acknowledged`, and `skipped` findings for carry-forward revalidation in Step 8.
- Track parseable, addressed, non-addressed, and unparseable counts for the final Previous Review Context section.

### Step 5: Cluster Changed Files and Launch the Reviewer

Group `CHANGED_FILES` into review clusters:

- 10 or fewer changed files: one cluster, one reviewer instance.
- More than 10: cluster by top-level directory (merging small directories), at most 4 clusters, one reviewer instance per cluster. Peer sampling is directory-local work, so clustering by directory keeps each instance's baseline coherent.

Launch **kramme:convention-drift-reviewer** (one instance per cluster) using the platform's agent-invocation primitive with:

- The loaded protocol from `references/baseline-mining.md` (state that it wins over the agent's built-in compact protocol)
- The merge-base documented rules, tool configs, and separately labeled proposed rule/config changes collected in Step 3
- The resolved `BASE_BRANCH`, `BASE_REF`, and `MERGE_BASE` from Step 3
- The cluster's changed file list
- Committed PR diff: the exact stored contents of `$REVIEW_SCOPE_DIR/committed.diff`
- Staged local diff: the exact stored contents of `$REVIEW_SCOPE_DIR/staged.diff`
- Unstaged local diff: the exact stored contents of `$REVIEW_SCOPE_DIR/unstaged.diff`
- Untracked local files and contents: the exact stored `$REVIEW_SCOPE_DIR/untracked-files.zlist` and `$REVIEW_SCOPE_DIR/untracked.diff` payloads
- PR metadata when available: the exact stored contents of `$REVIEW_SCOPE_DIR/pr-context.json` — the reviewer uses it for the intentionality check, not as trusted truth
- Threshold instruction: "Only report findings with confidence >= {custom_threshold}"
- Focus instruction: **"Operate in convention review mode. Mine the baseline per the provided protocol before judging. Review only drift and overcaution introduced by this diff scope; label pre-existing drift NOTICED BUT NOT TOUCHING."**

Do not let reviewer instances fetch, resolve the base, recompute diffs, or reread untracked files. The stored payload is the immutable review scope.

### Step 6: Refutation Pass

Collect all Critical and Important findings from the reviewer instances. If there are any:

- Launch a second **kramme:convention-drift-reviewer** instance. Open the prompt with `Operate in refute mode.` Pass the Critical/Important findings as the only candidate findings, together with `MERGE_BASE`, the trusted rule baseline, proposed rule/config changes labeled as untrusted diff content, and the changed-file exclusions. Do not pass the full diff.
- Apply the verdicts: drop `REFUTED` findings (record them for the report's refuted count), downgrade `SPLIT-PRACTICE` findings to Suggestions with a "codebase practice is split" note, keep `CONFIRMED` findings unchanged.

Suggestions skip refutation, but they keep the protocol's evidence requirements.

### Step 7: Validate Relevance

After the refutation pass:

- Launch **kramme:pr-relevance-validator** using the same agent-invocation primitive with all remaining findings and the immutable scope captured in Step 3: `BASE_REF`, `MERGE_BASE`, `CHANGED_FILES`, plus the exact stored committed, staged, unstaged, untracked, and PR-context payloads under `$REVIEW_SCOPE_DIR`.
- Instruct the validator to use that scope as authoritative and not fetch, resolve the base branch again, or recompute the merge base.
- Cross-reference each finding against the complete supplied scope.
- Keep `Validated` findings. Filter `Pre-existing` and `Out-of-scope` findings into their corresponding report categories. Treat `Likely Related` findings as relevance-unconfirmed: label them `UNVERIFIED`, keep them out of active findings, and show them under Filtered with the validator's reason.
- Return only findings confirmed to be caused by this combined scope as active findings.

If no separate agent runtime is available, perform the convention review, refutation pass, and relevance validation directly in the main thread. If an invoked reviewer or validator is unavailable, times out, or returns output that cannot be parsed as findings, surface the failure to the user with the agent name and what was attempted, then stop without writing `CONVENTION_REVIEW_OVERVIEW.md`. Do not fabricate findings or silently continue with an empty result.

### Step 8: Filter Previously Addressed Findings

If `CONVENTION_REVIEW_OVERVIEW.md` was found in Step 4:

- Cross-reference validated findings against every parseable previous finding.
- **Filter as previously addressed only** when the previous finding has `Resolution status: addressed` and is essentially the same issue:
  - Same file
  - Same enclosing function, component, or block (do not rely on raw line distance; refactors and formatters shift line numbers)
  - Same underlying issue (semantic match on root cause)
- **Carry forward as active** when a previous `open`, `deferred`, `acknowledged`, or `skipped` finding still applies:
  - Preserve its existing finding ID when the root cause is unchanged.
  - Refresh its location, severity, confidence, and evidence when the current review has better data.
  - Emit it with `Resolution status: open` and note that it was carried forward from the previous review.
- For non-addressed previous findings with no current reviewer match, revalidate the old root cause against the immutable scope. Carry it forward when it is still present; omit it when the changed file or root cause is gone. If uncertain, record that uncertainty in Previous Review Context instead of treating the finding as resolved.
- **Do NOT filter** when:
  - The issue description is substantively different (different root cause)
  - The severity escalated (was suggestion, now critical)
  - The finding identifies a problem with the previous fix
  - The previous status is `open`, `deferred`, `acknowledged`, or `skipped`
- When uncertain, err on the side of keeping the finding active
- Add filtered findings to "Previously Addressed" section
- Track addressed-filtered, non-addressed-carried-forward, and non-addressed-not-carried-forward counts.

### Step 9: Aggregate and Write Results

Merge findings from all reviewer instances, dedupe findings that name the same location and root cause, and assign stable IDs `CONV-001`, `CONV-002`, ... in report order. Preserve the ID of a carried-forward finding with the same root cause. Set `Resolution status: open` on every active finding. Organize into:

- **Critical Convention Issues** (must fix before merge) — only validated, refutation-confirmed findings
- **Important Convention Issues** (should fix) — only validated, refutation-confirmed findings
- **Convention Suggestions** (nice to have) — including split-practice downgrades
- **Split Practice Observations** — areas where the codebase has no dominant convention; recommend picking one explicitly, but do not block on it
- **Filtered** (pre-existing, out-of-scope, or relevance-unconfirmed) — shown separately
- **Previously Addressed** — shown separately
- **Previous Review Context** — source path plus parse, carry-forward, not-carried-forward, and addressed-filter counts
- **Refuted** — count and one-line summaries of findings the refutation pass dropped
- **Conventions Followed** (what the change gets right, with the strongest exemplar evidence)

Use the finding format from `references/baseline-mining.md` for every active finding, including location, lens, confidence, established-practice exemplars, and minimal fix.

If `INLINE_MODE=true`:

- Reply with the full report inline
- Include all sections even if empty (with count of 0)
- Do **not** create or update `CONVENTION_REVIEW_OVERVIEW.md`

Otherwise:

- Write the report to `CONVENTION_REVIEW_OVERVIEW.md` in the project root
- Include all sections even if empty (with count of 0)
- Treat the file as a working artifact that should **not** be committed and can be cleaned up by `/kramme:workflow-artifacts:cleanup`

### Step 10: Provide Action Plan

If Critical or Important findings were found:

- When `INLINE_MODE=false`, suggest running `/kramme:pr:resolve-review`; auto/local discovery will find `CONVENTION_REVIEW_OVERVIEW.md` and ask which overview to resolve if multiple local review files exist.
- When `INLINE_MODE=true`, suggest re-running with the inline report content passed as the argument: `/kramme:pr:resolve-review <paste report>` — or invoke it in the same session so chat context contains the report.

Organize the findings summary in the terminal output:

```
# Convention Review Complete

## Baseline
- {N} documented rule sources read
- {N} peer files sampled across {N} clusters

## Refutation and Relevance
- X findings confirmed, X refuted, X downgraded to split-practice
- X findings filtered (pre-existing, out-of-scope, or relevance-unconfirmed)
- X findings filtered (previously addressed)
- X non-addressed findings carried forward, X not carried forward

## Results
- Critical: X
- Important: X
- Suggestions: X
- Split practice observations: X

Report output: {inline reply | CONVENTION_REVIEW_OVERVIEW.md}

To resolve findings: `/kramme:pr:resolve-review`
```

## Verification

Before posting the report, self-check:

- Does every active finding cite 2–3 exemplars or a documented rule path?
- Did every Critical/Important finding survive the refutation pass?
- Is every pre-existing inconsistency labeled `NOTICED BUT NOT TOUCHING` instead of appearing as a finding?
- Are split-practice areas reported as observations, not violations?
- Do finding IDs, locations, and `Resolution status: open` fields follow the format `/kramme:pr:resolve-review` can parse?

If any answer is no, fix the report before posting.

After the report is posted or written successfully, remove `$REVIEW_SCOPE_DIR`; the EXIT trap remains the failure-path cleanup.
