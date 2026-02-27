# ISSUE-G-{NNN}: Fix {finding title}

**Status:** Ready | **Priority:** {Critical→High, Major→Medium, Minor→Low} | **Phase:** General | **Related:** Audit Report

## Problem

Audit found implementation behavior that is out of specification (divergence or extension).

**Finding:** {DIV-XXX or EXT-XXX}
**Spec requirement/context:** {REQ-{id} or section}
**Source:** {source_file} > {source_section}

## Context

{What was found in the code vs. what the spec requires}
{file:line references}

## Scope

### In Scope
- {Specific fix needed}

### Out of Scope
- Refactoring unrelated code

## Acceptance Criteria

- [ ] Implementation matches the intended spec boundary
- [ ] {Specific testable criterion based on the finding}

---

## Technical Notes

### Affected Areas
- `{file path}` — {what needs to change}

### References
- Spec: `{spec_file}` > {section}
- Audit Report: `{report_path}` > `{DIV-NNN or EXT-NNN}`
