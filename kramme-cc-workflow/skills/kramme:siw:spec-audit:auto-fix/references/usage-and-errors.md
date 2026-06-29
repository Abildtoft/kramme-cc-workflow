# Auto-Fix Usage Examples and Error Handling

Load this reference only when showing examples or handling one of the failure cases below.

## Usage Examples

```bash
# Default (balanced — fixes mechanical + high-confidence findings)
/kramme:siw:spec-audit:auto-fix

# Stricter pass (higher confidence bar)
/kramme:siw:spec-audit:auto-fix --threshold 90

# Most permissive allowed threshold
/kramme:siw:spec-audit:auto-fix --threshold 60

# Preview what the lowest threshold would fix
/kramme:siw:spec-audit:auto-fix --dry-run --threshold 60

# Auto-apply all auto-fixable findings without asking
/kramme:siw:spec-audit:auto-fix --auto

# Auto-apply with lower threshold
/kramme:siw:spec-audit:auto-fix --auto --threshold 70
```

## Error Handling

### Report Format Unexpected

If the report does not contain `### SPEC-NNN:` headings, stop:

```text
Could not parse findings from {report_path}.
Expected format: ### SPEC-NNN: {title}

The report may be from an incompatible version. Re-run /kramme:siw:spec-audit.
```

### Spec File Missing

If a spec file referenced in the report no longer exists:

- Warn: `Spec file not found: {path} — skipping {N} findings for this file`
- Skip all findings referencing that file
- Continue with remaining findings

### Edit Conflict

If the Edit tool fails because `old_string` was not found or the spec was modified since the audit:

- Warn: `Edit failed for SPEC-{NNN}: text has changed since audit`
- Skip this finding and reclassify it as `REQUIRES_DECISION`
- Continue with remaining findings

### All Fixes Fail

If every auto-fixable fix fails verification:

```text
All {N} auto-fixable fixes failed verification.
The spec may have changed significantly since the audit.

Recommended: Re-run /kramme:siw:spec-audit to get a fresh report.
```
