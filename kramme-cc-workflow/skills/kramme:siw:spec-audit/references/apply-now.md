# Apply Now Delegation

Use this when `/kramme:siw:spec-audit` reaches Step 6 and either:

- `APPLY_MODE=true` from `--apply` / `--apply-now`
- the user chooses **Apply now** from the Step 6 prompt

This file is a compatibility entry point. It does not define a separate eligibility rubric, apply loop, report annotation format, or summary table update. The canonical owner for all direct spec updates is `/kramme:siw:spec-audit:auto-fix`.

## Delegation Contract

Run the auto-fix procedure against the active audit report:

```text
/kramme:siw:spec-audit:auto-fix {report_path}
```

If `AUTO_MODE=true`, use the auto-fix procedure's non-interactive approval path and allow dirty spec files because they are the active audit targets owned by this apply run:

```text
/kramme:siw:spec-audit:auto-fix {report_path} --auto --allow-dirty
```

If the user chose **Apply now** from the Step 6 prompt, treat the auto-fix approval gate as already satisfied and continue with the canonical apply procedure.

## Boundaries

- Do not create files under `siw/issues/`.
- Do not update `siw/OPEN_ISSUES_OVERVIEW.md`.
- Do not run the issue-creation flow after this delegation completes.
- Use the auto-fix skill's canonical marker and report annotations for new writes: `**Status:** [Auto-fixed]`, `**Fix applied:** ...`, and the `Auto-fixed` summary row.
- Preserve the auto-fix skill's optional `siw/LOG.md` progress update when a log already exists.
- Treat `**Status:** [Applied directly]` as a legacy read marker only. New runs must not write it.

## Summary

End Step 6 with the summary produced by `/kramme:siw:spec-audit:auto-fix`, including its SIW log status, then report `Issues Created: 0` if the surrounding `/kramme:siw:spec-audit` summary needs an issue count.
