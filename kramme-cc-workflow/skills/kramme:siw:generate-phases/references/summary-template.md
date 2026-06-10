# Summary Template

Use this template in Phase 7 after creating issue files and updating `siw/OPEN_ISSUES_OVERVIEW.md`.

```
Phase Generation Complete
═════════════════════════

FILES CREATED:
  • siw/issues/ISSUE-*.md ({X} files)
    - General: {N} issues (G-001 to G-{N})
    - Phase 1: {N} issues (P1-001 to P1-{N})
    - Phase 2: {N} issues (P2-001 to P2-{N})
    ...
  • siw/OPEN_ISSUES_OVERVIEW.md (updated)

THINGS I DIDN'T TOUCH:
  • Any existing non-issue files under siw/ (LOG.md, spec files, supporting-specs/)
  • Source code — implementation is a separate workflow
  • {List any issues explicitly preserved during Append mode}

POTENTIAL CONCERNS:
  • {Any subagent-flagged risks that survived user approval}
  • {Any CONFUSION or MISSING REQUIREMENT markers from Phase 2 that were resolved by assumption — worth re-checking before implementation}
  • {If empty, state: "None"}

Suggested starting point:
  /kramme:siw:issue-implement ISSUE-{first-ready-issue}

Tips:
  • Work through phases sequentially (Phase 1 → Phase 2 → ...)
  • General tasks follow their recorded parallelization guidance; only `Safe to parallelize` work can truly be done anytime
  • Mark issues DONE in the overview as you complete them
```
