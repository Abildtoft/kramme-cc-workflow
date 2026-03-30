# Discovery Brief Import

Use this procedure when Phase 1.5 receives exactly one path ending in `DISCOVERY_BRIEF.md`.

## Extract These Sections

Read the brief title plus these sections when present:

- `The Real Problem`
- `Why Now`
- `Who's Affected`
- `What You Actually Want`
- `Objectives`
- `Success Looks Like`
- `What You Don't Want`
- `Scope & Boundaries`
- `Priorities & Tradeoffs`
- `Constraints`
- `Key Decisions Made`
- `Decision Boundaries`
- `Open Questions`
- `Risks`
- `Confidence Breakdown`
- `Where Stated and Actual Wants Diverged`

## Split `Scope & Boundaries`

Parse the `Scope & Boundaries` section into:

- `In Scope`
- `Out of Scope`
- `Deferred`

Preserve the original bullets or paragraphs under each subsection.

## Map Into `discovered_content`

- Core:
  - Overview = `What You Actually Want` (fallback: title + `The Real Problem`)
  - Problem Statement = `The Real Problem`
  - Stakeholders = `Who's Affected`
  - Why Now = `Why Now`
- Delivery:
  - Objectives = `Objectives`
  - Success Criteria = `Success Looks Like`
  - Scope = `In Scope`, `Out of Scope`, `Deferred`
  - Non-Goals = `What You Don't Want`
- Decisions:
  - Priority Tradeoffs = `Priorities & Tradeoffs`
  - Design Decisions = `Key Decisions Made`
  - Decision Boundaries = `Decision Boundaries`
- Risks:
  - Constraints = `Constraints`
  - Risks = `Risks`
  - Open Questions = `Open Questions`
- Traceability:
  - Confidence Breakdown = `Confidence Breakdown`
  - Stated vs Actual Divergence = `Where Stated and Actual Wants Diverged`
