Spec Audit Complete
===================

Spec Files: {list}

Quality Scores:
  Coherence:         {Strong/Adequate/Weak/Missing}
  Completeness:      {Strong/Adequate/Weak/Missing}
  Clarity:           {Strong/Adequate/Weak/Missing}
  Scope:             {Strong/Adequate/Weak/Missing}
  Actionability:     {Strong/Adequate/Weak/Missing}
  Testability:       {Strong/Adequate/Weak/Missing}
  Value Proposition: {Strong/Adequate/Weak/Missing}
  Technical Design:  {Strong/Adequate/Weak/Missing}

Findings:
  Critical: {N}
  Major:    {N}
  Minor:    {N}
  Total:    {N}

Overall: {Ready for implementation / Needs revision / Significant gaps}

Report: {report_path}

{If issues created:}
Issues Created: {N} (G-{start} through G-{end})
See siw/OPEN_ISSUES_OVERVIEW.md for the full list.

Next Steps:
  - Fix critical findings in the spec before starting implementation
  - Address major findings to reduce implementation risk
  - Resolve findings with executive summaries and issue creation: /kramme:siw:resolve-audit {report_path}
  - Re-run after spec revisions to verify quality: /kramme:siw:spec-audit
  - When spec is ready, begin implementation: /kramme:siw:generate-phases or /kramme:siw:issue-implement
  - Clean up report when done: /kramme:workflow-artifacts:cleanup
