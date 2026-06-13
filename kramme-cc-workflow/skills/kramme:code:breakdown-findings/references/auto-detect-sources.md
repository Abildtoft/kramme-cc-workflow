# Auto-detect candidates for findings sources

When the skill is invoked with no `$ARGUMENTS`, check these paths in order (relative to the project root). If exactly one path exists, use it. If multiple paths exist, list every match in this order and ask the user which one to use.

1. `REVIEW_OVERVIEW.md`
2. `REFACTOR_OPPORTUNITIES_OVERVIEW.md`
3. `UX_REVIEW_OVERVIEW.md`
4. `PRODUCT_REVIEW_OVERVIEW.md`
5. `COPY_REVIEW_OVERVIEW.md`
6. `AGENT_NATIVE_AUDIT.md`
7. `PRODUCT_AUDIT_OVERVIEW.md`
8. `QA_REPORT.md`
9. `AUDIT_IMPLEMENTATION_REPORT.md`
10. `AUDIT_SPEC_REPORT.md`
11. `PRODUCT_AUDIT.md`
12. `siw/AUDIT_IMPLEMENTATION_REPORT.md`
13. `siw/AUDIT_SPEC_REPORT.md`
14. `siw/PRODUCT_AUDIT.md`

User-supplied paths are accepted regardless of filename — this list only controls auto-detection.
