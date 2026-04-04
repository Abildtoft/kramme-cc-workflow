Spec Auto-Fix Complete
======================

Report: {report_path}
Threshold: {CONFIDENCE_THRESHOLD}/100
Spec files modified: {list of modified files, or "none" if dry-run}

Results:
  Fixed:                {N} (avg confidence: {avg_score})
  Failed verification:  {N} (reclassified to requires-decision)
  Below threshold:      {M} (requires decision)
  Safety-capped:        {S} (always requires decision)
  Skipped:              {K} (already fixed or has SIW issue)

{If CONFIDENCE_THRESHOLD != 80:}
Note: Using custom threshold {CONFIDENCE_THRESHOLD}. Default is 80.
  - To see what default would fix: /kramme:siw:spec-audit:auto-fix --dry-run
  - To restore conservative mode: /kramme:siw:spec-audit:auto-fix --threshold 90

{If requires-decision findings remain:}
Next steps:
  - Review remaining findings: /kramme:siw:resolve-audit {report_path}
  - Or auto-resolve: /kramme:siw:resolve-audit {report_path} --auto
  - Re-audit after all fixes: /kramme:siw:spec-audit

{If no requires-decision findings remain:}
Next steps:
  - All findings resolved. Re-audit to verify: /kramme:siw:spec-audit
  - When spec is ready, begin implementation: /kramme:siw:generate-phases or /kramme:siw:issue-implement
