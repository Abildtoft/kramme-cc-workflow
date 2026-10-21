# Auto-detect candidates for findings sources

When the skill is invoked with no `$ARGUMENTS`, check these paths in order (relative to the project root). Use every matching findings-mode report as one source set, preserving this order. If the user wants only one report, they should pass that report path explicitly.

Do not combine a pre-clustered handoff with any other source. If a matching path contains a pre-clustered handoff, the main workflow must ask the user to pass that handoff alone or provide a merged handoff.

1. `REVIEW_OVERVIEW.md`
2. `REFACTOR_OPPORTUNITIES_OVERVIEW.md`
3. `PRODUCT_REVIEW_OVERVIEW.md`
4. `COPY_REVIEW_OVERVIEW.md`
5. `AGENT_NATIVE_AUDIT.md`
6. `CODEBASE_WEAKNESS_REPORT.md`
7. `PRODUCT_AUDIT_OVERVIEW.md`
8. `QA_REPORT.md`
9. `AUDIT_SPEC_REPORT.md`
10. `siw/AUDIT_SPEC_REPORT.md`

User-supplied paths are accepted regardless of filename — this list only controls auto-detection.
