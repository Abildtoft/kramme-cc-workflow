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

## Important Issues (X found)
- [agent-name]: Issue description [location]

## Suggestions (X found)
- **Nit:** [agent-name]: Suggestion [location]
- **Consider:** [agent-name]: Suggestion [location]

## Slop Warnings (X found)
- [agent-name]: Suggestion [location]
  Warning: Would introduce [slop-type] - [explanation]

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

**To automatically resolve code-backed findings, run:** `/kramme:pr:resolve-review`
```

## Section notes

- **Location** — use `path/to/file.ts:123` when the finding maps to a specific line. Use `review-scope` for PR-wide findings.
- **Critical:** prefix mirrors the section; the redundancy is intentional so a finding is still parseable when lifted out of its section (e.g., pasted into an inline comment).
- **Dead Code** — keep dead-code findings in the severity bucket that matches their impact, and use the ask shape verbatim. Example: `[agent-name]: DEAD CODE IDENTIFIED: [location, location, ...]. Safe to remove these?` Never rewrite as "delete these files" or "remove unused imports."
- **Emphasis** — emphasis may promote matching suggestions, but other validated findings keep their original severities.
- **Approval Standard** — always include; it's the exit-criteria statement, not boilerplate.
- **FYI** in Strengths — a review with zero positive observations is usually miscalibrated. If the PR genuinely has nothing to praise, say so explicitly rather than omitting the section.
