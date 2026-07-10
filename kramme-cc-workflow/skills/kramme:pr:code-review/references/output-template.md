# Output template: REVIEW_OVERVIEW.md

Use this structure verbatim when writing `REVIEW_OVERVIEW.md` (or the inline reply with `--inline`). Include every required section even if empty — emit `(0 found)` rather than omitting the section. The only conditional sections are `## Coverage Status`, which appears only when coverage is degraded, `## Emphasis Applied`, which appears only when emphasis was requested, and `## Dead Code`, which appears only when there are dead-code findings to summarize.

```markdown
# PR Review Summary

## Relevance Filter

- X findings validated as PR-caused
- X findings filtered (pre-existing or out-of-scope)
- X findings filtered (previously addressed in previous-review source)
- X findings carried forward from a previous review

## Previous Review Context

- Source: `REVIEW_OVERVIEW.md` | `path/from/--previous-review` | none
- Parseable previous findings: X
- Previously addressed filtered: X
- Open/deferred/acknowledged/skipped carried forward: X
- Open/deferred/acknowledged/skipped not carried forward: X
- Ignored or unparseable previous entries: X

## Auto-resolution Readiness

- X Critical/Important findings eligible for `/kramme:pr:resolve-review` (`Action class: gated_auto`)
- X Critical/Important findings require manual follow-up (`Action class: manual`)
- Manual blockers: product/UX/architecture/maintainer decision X; missing/contradictory requirement X; PR-description/process update X; cross-team/external ownership X; unresolved contradiction X; incomplete trace/UNVERIFIED X; dead-code approval X

## Coverage Status (omit when complete)

Coverage degraded: {agent names} failed; findings below exclude {dimensions}.

## Emphasis Applied (omit section if no emphasis)

- Emphasized: security, errors
- Findings promoted (Suggestion → Important): X

## Critical Issues (X found)

- **Critical:** [agent-name]: Issue description [location]
  - Finding ID: CR-001
  - Location: `path/to/file.ts:123` | `review-scope` | `PR description`
  - Confidence: 0-100
  - Action class: gated_auto | manual
  - Owner: resolver | author | maintainer | reviewer | unknown
  - Resolution status: open
  - Evidence: concrete trace, reproduction, failed expectation, or UNVERIFIED reason
  - Manual blocker: product/UX/architecture/maintainer decision | missing/contradictory requirement | PR-description/process update | cross-team/external ownership | unresolved contradiction | incomplete trace/UNVERIFIED | dead-code approval (omit when gated_auto)
  - Next human decision: concrete decision, approval, clarification, access grant, or verification needed (omit when gated_auto)

## Important Issues (X found)

- [agent-name]: Issue description [location]
  - Finding ID: CR-002
  - Location: `path/to/file.ts:123` | `review-scope` | `PR description`
  - Confidence: 0-100
  - Action class: gated_auto | manual
  - Owner: resolver | author | maintainer | reviewer | unknown
  - Resolution status: open
  - Evidence: concrete trace, reproduction, failed expectation, or UNVERIFIED reason
  - Manual blocker: product/UX/architecture/maintainer decision | missing/contradictory requirement | PR-description/process update | cross-team/external ownership | unresolved contradiction | incomplete trace/UNVERIFIED | dead-code approval (omit when gated_auto)
  - Next human decision: concrete decision, approval, clarification, access grant, or verification needed (omit when gated_auto)

## Suggestions (X found)

- **Nit:** [agent-name]: Suggestion [location]
  - Finding ID: CR-003
  - Location: `path/to/file.ts:123` | `review-scope` | `PR description`
  - Confidence: 0-100
  - Action class: advisory
  - Owner: author | maintainer | reviewer | unknown
  - Resolution status: open
  - Evidence: concrete context or UNVERIFIED reason
- **Consider:** [agent-name]: Suggestion [location]
  - Finding ID: CR-004
  - Location: `path/to/file.ts:123` | `review-scope` | `PR description`
  - Confidence: 0-100
  - Action class: advisory
  - Owner: author | maintainer | reviewer | unknown
  - Resolution status: open
  - Evidence: concrete context or UNVERIFIED reason

## Slop Warnings (X found)

- [agent-name]: Suggestion [location] Warning: Would introduce [slop-type] - [explanation]

## Dead Code (omit section if none flagged)

- Summarize the dead-code findings already listed in the severity buckets above
- If the report needs a roll-up, repeat the exact ask shape and keep the same severities in the main findings sections

## Filtered (Pre-existing/Out-of-scope)

<collapsed>
- NOTICED BUT NOT TOUCHING: [location]: Brief description - Reason filtered
</collapsed>

## Filtered (Previously Addressed)

<collapsed>
- [location]: Brief description
  Matched: previous-review source - [action taken summary]
</collapsed>

## Strengths

- **FYI** What's well-done in this PR

## Approval Standard

Approve if the change definitely improves overall code health.

## Recommended Action

1. Fix critical issues first
2. Address important issues
3. Consider suggestions
4. Re-run review after fixes

**To automatically resolve eligible `gated_auto` code-backed findings, run:** `/kramme:pr:resolve-review`
```

## Section notes

- **Location** — emit the structured `Location` field for every active finding. Use `path/to/file.ts:123` when the finding maps to a specific line. Use `review-scope` for PR-wide findings. Use `PR description` when the finding is about an inaccurate PR title or body. Keep the inline `[location]` text only as a human-readable duplicate for legacy readers.
- **Critical:** prefix mirrors the section; the redundancy is intentional so a finding is still parseable when lifted out of its section (e.g., pasted into an inline comment).
- **Finding ID** — assign stable IDs in report order (`CR-001`, `CR-002`, ...). Keep the ID with the finding if it moves between severity buckets so callers can hand off the exact item to `/kramme:pr:resolve-review`.
- **Confidence** — use a 0-100 score. Use 90+ only when the behavior was traced, reproduced, or independently confirmed by another reviewer on the same root cause. Use scores below 60 with the `UNVERIFIED` marker for plausible but untraced findings. During the transition, map reviewer tiers before writing the report as `high=80`, `medium=60`, `low=30`.
- **Action class** — Critical/Important PR-caused findings default to `gated_auto` when they have a concrete `path/to/file:line` location, confidence at least 70, concrete evidence, and a clear local fix path. Use `manual` only when a named manual blocker prevents safe automatic resolution; when a finding plausibly fits both classes, use `gated_auto`. Use `advisory` only for Suggestions and FYI observations.
- **Owner** — name the next actor, not the original source of the finding. Use `resolver` only when `/kramme:pr:resolve-review` can act safely.
- **Resolution status** — `/kramme:pr:code-review` emits `open` for every active finding. `/kramme:pr:resolve-review` or human follow-up may later update it to `addressed`, `deferred`, `acknowledged`, or `skipped`. Previous-review parsing relies on this field when present and falls back to `Action taken` for legacy reports.
- **Evidence** — cite the concrete trace, reproduction, failed expectation, or why the finding remains `UNVERIFIED`.
- **Manual blocker / Next human decision** — required for every manual Critical/Important finding and omitted for `gated_auto` findings. If no manual blocker exists, reclassify the finding as `gated_auto` or downgrade it to an advisory suggestion.
- **Auto-resolution Readiness** — count only Critical/Important findings. Suggestions and FYI items are not counted here; `/kramme:pr:resolve-review` applies its own safe-advisory test when deciding whether to pick one up. If there are no manual blockers, write `Manual blockers: none`.
- **Previous Review Context** — always include this section. Use `Source: none` and zero counts when no previous-review source was found. When `--previous-review <path>` was used, display that path so cross-workspace handoffs are auditable.
- **Dead Code** — keep dead-code findings in the severity bucket that matches their impact, and use the ask shape verbatim. Example: `[agent-name]: DEAD CODE IDENTIFIED: [location, location, ...]. Safe to remove these?` Never rewrite as "delete these files" or "remove unused imports."
- **Emphasis** — emphasis may promote matching suggestions, but other validated findings keep their original severities. Cleanup-dimension promotions are provisional; optional cleanup without concrete merge-blocking impact returns to Suggestions during action-class normalization.
- **Cleanup collisions** — `lean`, `refactor`, and `simplify` findings that collide with unresolved correctness/security findings stay advisory or are suppressed. When kept, evidence should name the blocking `CR-XXX` after final IDs are assigned.
- **Approval Standard** — always include; it's the exit-criteria statement, not boilerplate.
- **FYI** in Strengths — a review with zero positive observations is usually miscalibrated. If the PR genuinely has nothing to praise, say so explicitly rather than omitting the section.
