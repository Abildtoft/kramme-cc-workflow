# Output template: REVIEW_OVERVIEW.md

Use this structure verbatim when writing `REVIEW_OVERVIEW.md` (or the inline reply with `--inline`). Include every required section even if empty — emit `(0 found)` rather than omitting the section. The only conditional sections are `## Emphasis Applied`, which appears only when emphasis was requested, and `## Dead Code`, which appears only when there are dead-code findings to summarize.

```markdown
# PR Review Summary

## Relevance Filter

- X findings validated as PR-caused
- X findings filtered (pre-existing or out-of-scope)
- X findings filtered (previously addressed in REVIEW_OVERVIEW.md)

## Emphasis Applied (omit section if no emphasis)

- Emphasized: security, errors
- Findings promoted (Suggestion → Important): X

## Critical Issues (X found)

- **Critical:** [agent-name]: Issue description [location]
  - Finding ID: CR-001
  - Location: `path/to/file.ts:123` | `review-scope` | `PR description`
  - Confidence: high | medium | low
  - Action class: gated_auto | manual
  - Owner: resolver | author | maintainer | reviewer | unknown
  - Evidence: concrete trace, reproduction, failed expectation, or UNVERIFIED reason

## Important Issues (X found)

- [agent-name]: Issue description [location]
  - Finding ID: CR-002
  - Location: `path/to/file.ts:123` | `review-scope` | `PR description`
  - Confidence: high | medium | low
  - Action class: gated_auto | manual
  - Owner: resolver | author | maintainer | reviewer | unknown
  - Evidence: concrete trace, reproduction, failed expectation, or UNVERIFIED reason

## Suggestions (X found)

- **Nit:** [agent-name]: Suggestion [location]
  - Finding ID: CR-003
  - Location: `path/to/file.ts:123` | `review-scope` | `PR description`
  - Confidence: high | medium | low
  - Action class: advisory
  - Owner: author | maintainer | reviewer | unknown
  - Evidence: concrete context or UNVERIFIED reason
- **Consider:** [agent-name]: Suggestion [location]
  - Finding ID: CR-004
  - Location: `path/to/file.ts:123` | `review-scope` | `PR description`
  - Confidence: high | medium | low
  - Action class: advisory
  - Owner: author | maintainer | reviewer | unknown
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
  Matched: REVIEW_OVERVIEW.md - [action taken summary]
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
- **Confidence** — use `high` only when the behavior was traced, reproduced, or independently confirmed by another reviewer on the same root cause. Use `low` with the `UNVERIFIED` marker for plausible but untraced findings.
- **Action class** — use `gated_auto` only for code-backed Critical/Important findings with a concrete location and fix path. Use `manual` for Critical/Important product/process decisions, PR-description updates, missing requirements, contradictions, or unresolved context. Use `advisory` only for Suggestions and FYI observations.
- **Owner** — name the next actor, not the original source of the finding. Use `resolver` only when `/kramme:pr:resolve-review` can act safely.
- **Evidence** — cite the concrete trace, reproduction, failed expectation, or why the finding remains `UNVERIFIED`.
- **Dead Code** — keep dead-code findings in the severity bucket that matches their impact, and use the ask shape verbatim. Example: `[agent-name]: DEAD CODE IDENTIFIED: [location, location, ...]. Safe to remove these?` Never rewrite as "delete these files" or "remove unused imports."
- **Emphasis** — emphasis may promote matching suggestions, but other validated findings keep their original severities.
- **Approval Standard** — always include; it's the exit-criteria statement, not boilerplate.
- **FYI** in Strengths — a review with zero positive observations is usually miscalibrated. If the PR genuinely has nothing to praise, say so explicitly rather than omitting the section.
