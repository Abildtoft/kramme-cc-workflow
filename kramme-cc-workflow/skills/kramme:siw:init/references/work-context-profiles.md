# Work Context Profiles

Work Context is an optional metadata section in SIW specs that tells downstream tools what type of work this is and which quality dimensions matter most. It lives in the spec as a `## Work Context` table, set during init and editable anytime.

## Profile Definitions

| Profile | Work Type | Default Maturity | Priority Dimensions | Deprioritized Dimensions |
|---------|-----------|-----------------|--------------------|-----------------------|
| Production Feature | Production | Full Lifecycle | All 8 active | None |
| Prototype / Spike | Prototype | Early Exploration | Actionability, Technical Design | Value Proposition, Completeness, Testability |
| Internal Tool | Internal Tool | Varies | Actionability, Clarity | Value Proposition |
| Tech Debt / Refactor | Refactor | Maintenance | Technical Design, Testability | Value Proposition, Scope |
| Documentation / Process | Documentation | Varies | Clarity, Completeness | Technical Design |

### Profile Notes (default content for the Notes field)

- **Production Feature**: _(empty)_
- **Prototype / Spike**: "Focus on proving the concept works. Commercial viability to be assessed later."
- **Internal Tool**: "Built for internal team use. User research and market fit are not relevant."
- **Tech Debt / Refactor**: "Focus on safe transformation. Scope is defined by what needs changing."
- **Documentation / Process**: "Focus on clear, complete documentation. Technical implementation details are secondary."

## Section Format

The Work Context section appears in the spec after `## Overview` and before `## Objectives` (or `## Linked Specifications` for slim specs):

```markdown
## Work Context

| Attribute | Value |
|-----------|-------|
| **Work Type** | {work_type} |
| **Maturity** | {maturity} |
| **Priority Dimensions** | {comma-separated list} |
| **Deprioritized** | {comma-separated list or "None"} |
| **Notes** | {freeform context or empty} |
```

## Parsing Instructions

Downstream tools that consume Work Context should:

1. Look for a `## Work Context` heading in the spec file(s)
2. Parse the markdown table for attribute values (match on bold attribute names)
3. If the section is **not found**, default to Production Feature profile (all dimensions active, full rigor)
4. If the section is found but malformed, warn and fall back to Production Feature defaults
5. The Notes field is informational — it does not change tool behavior

## Downstream Behavior Rules

### spec-audit

- For **deprioritized dimensions**: assess severity normally, then cap the final report severity at Minor during aggregation. Preserve the original severity in finding metadata and annotate capped report entries with: `**Severity Note:** [Deprioritized — capped at Minor from {original_severity}]`
- For **priority dimensions**: apply strict evaluation — flag even small issues
- For **normal dimensions** (neither priority nor deprioritized): evaluate as usual
- Add a "Work Context Applied" section at the top of `AUDIT_SPEC_REPORT.md` showing detected profile and severity adjustments
- Pass Work Context to each Explore agent prompt so findings are tagged during analysis

### product-review

- **Prototype / Spike** and **Refactor** work types: offer to skip product review entirely (suggest spec-audit instead). If user proceeds, run with full rigor.
- **Internal Tool**: adjust agent prompt — skip "Target User Clarity" market segmentation and "Problem/Solution Fit" competitive analysis. Internal tools are justified by team need.
- **Documentation / Process**: focus on Scope Correctness and Success Criteria Quality. Cap User State Modeling and Critical Moments Coverage findings at Minor.
- **Production Feature**: no adjustments.
- Add a "Work Context" note at the top of the report.

### discovery

- When building the quality gap map, order gaps using Work Context priority:
  1. Critical gaps in priority dimensions (always first)
  2. Major gaps in priority dimensions
  3. Critical gaps in normal dimensions
  4. Major gaps in normal dimensions
  5. Critical gaps in deprioritized dimensions (include only if Critical)
  6. Skip Major/Minor gaps in deprioritized dimensions unless all other gaps are resolved
- Select the top 3-5 gaps from this ordered list for interview focus
- Skip deprioritized dimensions in interview unless a Critical-severity gap exists

### generate-phases

Phase count and task sizing by profile:

- **Production Feature**: 3-5 phases (default). Each phase results in demoable, tested software.
- **Prototype / Spike**: 2-3 phases. Larger, more exploratory phases. Phase 1 proves the core concept. Acceptance criteria focus on "does it work" over "is it production-ready." Skip polish and documentation phases.
- **Internal Tool**: 3-4 phases. Prioritize getting to a working tool fast. Phase 1 is the happy-path core workflow.
- **Tech Debt / Refactor**: 2-4 phases ordered by risk. Phase 1 tackles the highest-risk transformation with rollback capability. Include explicit rollback verification in phase acceptance criteria.
- **Documentation / Process**: Phases map to document sections or workflow stages. Each phase produces a reviewable deliverable.

Pass Work Context to the review subagent so it can validate phase count and task sizing appropriateness.

## Auto-detection Heuristics

During init, suggest a profile based on `project_description` keywords:

| Keywords | Suggested Profile |
|----------|-------------------|
| prototype, spike, experiment, proof of concept, POC, try out, explore, exploratory | Prototype / Spike |
| internal, developer tool, devtool, tooling, script, automation | Internal Tool |
| refactor, tech debt, migration, cleanup, upgrade, modernize | Tech Debt / Refactor |
| doc, documentation, process, runbook, playbook, guide | Documentation / Process |
| _(default)_ | Production Feature |
