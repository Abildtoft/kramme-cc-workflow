# ISSUE-G-{NNN}: Spec: {finding title}

**Status:** Ready | **Priority:** {Critical→High, Major→Medium, Minor→Low; if `Severity Note` says `from Critical` use High, if it says `from Major` use Medium} | **Size:** {XS|S|M|L} | **Phase:** General | **Parallelization:** {Safe to parallelize | Must be sequential | Needs coordination} | **Related:** Spec Audit Report

## Problem

Spec audit found a {dimension} issue in the specification.

**Spec finding (SPEC-{id}):** {finding title}
**Source:** {source_file} > {source_section}
{If present} **Severity Note:** {copied from audit report}

## Context

{Details from the finding — what's wrong with the spec}
{Impact if not addressed}

## Scope

### In Scope
- {Specific spec revision needed}

### Out of Scope
- Code implementation changes
- Refactoring unrelated spec sections

## Acceptance Criteria

- [ ] Spec section addresses the finding
- [ ] {Specific criterion based on the recommendation}
- [ ] Follow-up spec audit no longer reports SPEC-{id}

---

## Technical Notes

### Recommendation
{Recommendation from the finding}

### References
- Spec: `{spec_file}` > {section}
- Audit Report: `{report_path}` > SPEC-{id}
