Spec Auto-Fix Complete
======================

Report: {report_path}
Spec files modified: {list of modified files, or "none" if dry-run}

Results:
  Fixed:                {N}
  Failed verification:  {N} (reclassified to requires-decision)
  Requires decision:    {M} (unchanged)
  Skipped:              {K} (already fixed or has SIW issue)

{If requires-decision findings remain:}
Next steps:
  - Review remaining findings: /kramme:siw:resolve-audit {report_path}
  - Or auto-resolve: /kramme:siw:resolve-audit {report_path} --auto
  - Re-audit after all fixes: /kramme:siw:spec-audit

{If no requires-decision findings remain:}
Next steps:
  - All findings resolved. Re-audit to verify: /kramme:siw:spec-audit
  - When spec is ready, begin implementation: /kramme:siw:generate-phases or /kramme:siw:issue-implement
