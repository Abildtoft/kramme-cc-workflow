# Spec Auto-Fix Complete

Report: {report_path} Threshold: {CONFIDENCE_THRESHOLD}/100 Spec files modified: {list of modified files, or "none" if dry-run} SIW log: {updated | skipped — no siw/LOG.md | not updated (missing Current Progress section) | not applicable}

Results: Fixed: {N} (avg confidence: {avg_score}) Failed verification: {N} (reclassified to requires-decision) Below threshold: {M} (requires decision) Guardrail-blocked: {G} (requires decision despite score) Safety-capped: {S} (always requires decision) Skipped: {K} (already fixed or has SIW issue) Product findings left for decisions: {P} (PROD-NNN; never auto-fixed)

{If CONFIDENCE_THRESHOLD != 80:} Note: Using custom threshold {CONFIDENCE_THRESHOLD}. Default is 80.

- To see what default would fix: $kramme:siw:spec-audit --apply {report_path} --dry-run
- To restore conservative mode: $kramme:siw:spec-audit --apply {report_path} --threshold 90

{If requires-decision findings or open PROD findings remain:} Next steps:

- Review remaining findings: $kramme:siw:resolve-audit {report_path}
- Or auto-resolve: $kramme:siw:resolve-audit {report_path} --auto
- Re-audit after all fixes: $kramme:siw:spec-audit {add --product if the report contains PROD-NNN findings}

{If no requires-decision findings and zero open PROD findings remain:} Next steps:

- All findings resolved. Re-audit to verify: $kramme:siw:spec-audit {add --product if the report contains PROD-NNN findings}
- When spec is ready, define the issue set with $kramme:siw:generate-phases, then run $kramme:siw:transfer-to-linear
