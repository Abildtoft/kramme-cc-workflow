# Spec Audit Complete

Spec Files: {list}

Quality Scores: Coherence: {Strong/Adequate/Weak/Missing} Completeness: {Strong/Adequate/Weak/Missing} Clarity: {Strong/Adequate/Weak/Missing} Scope: {Strong/Adequate/Weak/Missing} Actionability: {Strong/Adequate/Weak/Missing} Testability: {Strong/Adequate/Weak/Missing} Rationale Documentation: {Strong/Adequate/Weak/Missing} Technical Design: {Strong/Adequate/Weak/Missing} {If product mode ran:} Product: {Strong/Adequate/Weak/Missing} ({N} PROD findings) {If product mode was skipped:} Product: {PRODUCT_SKIP_REASON}

Findings: Critical: {N} Major: {N} Minor: {N} Total: {N} {If preserved critical caps exist:} Preserved Critical Caps: {N} (reported as Minor due to Work Context but still decision-required)

Overall: {Ready for implementation / Needs revision / Significant gaps}

Report: {report_path} {If a prior report was replaced in auto mode:} Replaced previous audit dated {previous_date}. {If product findings were carried forward:} Carried {N} PROD findings from the product pass dated {date}.

{If direct apply ran:} Applied Now: {N} finding(s) updated spec files directly. Issues Created: 0. {If issues created:} Issues Created: {N} (G-{start} through G-{end}) See siw/OPEN_ISSUES_OVERVIEW.md for the full list.

Next Steps:

- Fix critical findings in the spec before starting implementation {If preserved critical caps exist:}
- Resolve preserved-critical findings reported as Minor with `Severity Note` before starting implementation or running auto-fix
- Address major findings to reduce implementation risk
- Auto-fix mechanical findings (cross-refs, terminology, formatting): $kramme:siw:spec-audit --apply {report_path}
- Resolve remaining findings, including PROD-NNN product findings that are never auto-fixed, with executive summaries and issue creation: $kramme:siw:resolve-audit {report_path}
- Or let the model choose each resolution automatically: $kramme:siw:resolve-audit {report_path} --auto
- Re-run after spec revisions to verify quality: $kramme:siw:spec-audit {add --product if product mode ran}
- When spec is ready, define the issue set with $kramme:siw:generate-phases, then run $kramme:siw:transfer-to-linear
- Clean up report when done: $kramme:workflow:cleanup-artifacts
