# Fix Confidence Rubric Delegation

This file exists so existing `/kramme:siw:spec-audit` instructions can keep referring to `references/fix-confidence-rubric.md`.

Do not maintain a second copy of the scoring rules here. The canonical fix-confidence rubric is owned by `/kramme:siw:spec-audit:auto-fix` in:

```text
../../kramme:siw:spec-audit:auto-fix/references/classification-rubric.md
```

Use that rubric whenever this skill asks for fix-confidence scoring, recomputation, tier assignment, sub-score guardrails, or safety-cap checks. `references/post-processing-rules.md` still defines when the audit lead recomputes scores during finding consolidation; this file only delegates the scoring model.
