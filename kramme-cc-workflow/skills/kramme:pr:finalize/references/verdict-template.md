# Verdict Display Template

Inline-only output (no artifact file). Substitute the bracketed placeholders with results from the orchestrated steps.

```markdown
## PR Readiness Assessment

**Verdict: READY / READY WITH CAVEATS / NOT READY**

### Verification

Status: PASS / FAIL / SKIPPED / COULD NOT RUN

### Code Review

Status: X critical, Y important, Z suggestions / SKIPPED / COULD NOT RUN

### Product Review

Status: X critical, Y important, Z suggestions / SKIPPED / COULD NOT RUN

### UX Review (if run)

Status: X critical, Y important, Z suggestions / SKIPPED (no UI changes) / COULD NOT RUN

### QA (if run)

Status: X blockers, Y major, Z minor / SKIPPED (no app URL) / COULD NOT RUN

### Residual Work Gate

Status: PASS / FAIL

- fixed_now: X
- deferred_with_owner: X
- accepted_risk: X
- blocked_by_missing_information: X
- not_relevant: X
- unclassified: X

Residual item dispositions:

1. [source]: description — disposition, owner, rationale, follow-up path, or accepted-risk note

Blocking residual items:

1. [source]: description — disposition, owner, rationale or missing decision

### Blockers (must fix)

1. [source]: description

### Recommended Fixes (should fix)

1. [source]: description

### Optional Polish

1. [source]: description

### Next Steps

{context-dependent recommendations}
```

## Next-Steps Guidance by Verdict

- **READY:** "PR is ready. Run `/kramme:pr:create` to create it, or `/kramme:pr:generate-description` to update the description."
- **READY WITH CAVEATS:** "Review the residual-work dispositions before creating the PR. Run `/kramme:pr:resolve-review` to address code-backed findings, or `/kramme:pr:create` to proceed with the listed deferred or accepted-risk items. Alternatively, re-run with `--fix` to auto-resolve eligible code-review critical and important findings (product-review, UX-review, QA, and manual residual items still need human follow-up)."
- **NOT READY:** "Fix blockers first. Run `/kramme:pr:finalize --fix` to auto-resolve eligible `gated_auto` code-review critical and important findings, or `/kramme:pr:resolve-review` to address them manually. Product-review, UX-review, QA, and process blockers still require manual follow-up."
- **After merge (any verdict):** "For user-facing changes, run `/kramme:launch:rollout` to execute a staged post-merge rollout with canary gates and rollback triggers."
