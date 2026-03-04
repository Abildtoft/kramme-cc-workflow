Audit Complete
==============

Spec Files: {list}
Requirements Checked: {total}
Coverage Matrix: COMPLETE
Conflicts: {resolved_count} resolved, 0 unresolved

Results:
  Divergences:         {N}
  Extensions:          {N}
  Verified alignments: {N}
  Uncertain:           {N}

Report: {report_path}

{If issues created:}
Issues Created: {N} (G-{start} through G-{end})
See siw/OPEN_ISSUES_OVERVIEW.md for the full list.

Next Steps:
  - Resolve findings one-by-one with executive summaries, alternatives, and issue creation: /kramme:siw:resolve-audit
  - Fix critical divergences/extensions first: /kramme:siw:issue-implement G-{first}
  - Re-run after fixes to verify compliance: /kramme:siw:implementation-audit
  - Clean up report when done: /kramme:workflow-artifacts:cleanup
