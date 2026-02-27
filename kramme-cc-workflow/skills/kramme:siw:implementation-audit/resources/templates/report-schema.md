# Implementation Audit Report Schema

All sections below are mandatory. If a section has zero entries, include the section with `None`.

```markdown
# Audit Report: Implementation vs. Specification

**Date:** {current date}
**Spec Files Reviewed:** {list of spec files with paths}

## Summary

| Category | Count |
|----------|-------|
| Requirements checked | {total} |
| Divergences | {count} |
| Extensions | {count} |
| Verified alignments | {count} |
| Uncertain | {count} |
| Conflicts resolved | {count} |
| Conflicts unresolved | {count} |

## Divergences

### DIV-001: {Brief title}

**Requirement:** REQ-{id} from {source_file} > {source_section}
**Severity:** Critical | Major | Minor
**Spec citation:** {file > section > clause}
**Code citation:** {file:line[, file:line]}
**Runtime behavior:** {input/state -> observed behavior}
**Why divergent:** {exact mismatch explanation}

---

## Extensions

### EXT-001: {Brief title}

**Type:** ACCESS_BROADENING | BYPASS | UNDOCUMENTED_FLOW | DATA_EXPOSURE | LIFECYCLE_MISMATCH | OTHER
**Related requirement/section:** REQ-{id} or {section}
**Severity:** Critical | Major | Minor
**Spec citation:** {file > section > clause or "No matching requirement"}
**Code citation:** {file:line[, file:line]}
**Runtime behavior:** {input/state -> observed behavior}
**Why this is out-of-spec:** {boundary exceeded or undocumented behavior}

---

## Verified Alignments

| Requirement | Spec citation | Code citation | Runtime behavior |
|---|---|---|---|
| REQ-{id} | {citation} | {file:line} | {behavior statement} |

## Coverage Matrix

| Section ID | Source | Req Count | Strict (M/O/N) | Pass A Checked | Pass B Checked | Divergences | Extensions | Alignments | Evidence Refs | Status |
|---|---|---:|---:|---:|---:|---:|---:|---:|---|---|
| SEC-01 | {source} | {n} | {n} | {n} | {n} | {n} | {n} | {n} | {refs} | COMPLETE |

## Conflict Resolutions

| Conflict ID | Items in conflict | Resolution | Evidence used |
|---|---|---|---|
| C-001 | REQ-012 status mismatch | Chosen: BEHAVIOR_MISMATCH | {file:line + rationale} |

## Existing-Issue Cross-Reference

Only include rows for findings with direct code evidence.

| Finding | Evidence established | Existing issue(s) |
|---|---|---|
| DIV-001 | Yes | ISSUE-G-012 |
```
