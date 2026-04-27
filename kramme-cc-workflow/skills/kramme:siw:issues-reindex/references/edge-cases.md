# Edge Cases

### No DONE issues
```
No DONE issues found. Nothing to delete.

Active issues:
- G-001: {title}
- G-002: {title}
- P1-001: {title}

No renumbering needed since there are no gaps in any group.
```
**Action:** Report and exit (no changes needed).

### All issues are DONE
```
All issues are DONE. This will clear all issues.

After restart, use /kramme:siw:issue-define to create new issues starting from G-001.
```
Use AskUserQuestion to confirm clearing all issues.

### No gaps in numbering
If DONE issues are at the end of each sequence, only deletion is needed (no renumbering):
```
DONE issues to delete:
- G-003: {title}
- P1-004: {title}

Active issues (no renumbering needed):
- G-001: {title}
- G-002: {title}
- P1-001: {title}
- P1-002: {title}
- P1-003: {title}
```

### Issue file missing
If an issue is in the overview but the file doesn't exist:
```
Warning: G-002 listed in overview but file not found.
Will remove from overview table.
```

### LOG.md not found
If siw/LOG.md doesn't exist, skip the LOG.md update step (Step 8) silently. For the spec capture check (Step 4), only check DONE issue files directly — skip LOG.md analysis.

### No issue references in LOG.md
If LOG.md exists but contains no issue reference patterns:
```
siw/LOG.md: No issue references found
```

### Mixed prefix groups
Each prefix group is handled independently. Issues never move between groups:
```
G-001 (DONE), G-002 (READY), G-003 (READY)  →  G-001, G-002 (renumbered within G-)
P1-001 (READY), P1-002 (DONE), P1-003 (READY)  →  P1-001, P1-002 (renumbered within P1-)
```

### References to deleted issues in LOG.md
Annotate references to deleted (DONE) issues with `(deleted: "{title}")` to disambiguate them from renumbered issues that now reuse the same number. Classify matches from original LOG.md text first (deleted mapping takes priority), then apply renumber replacements for non-deleted IDs. Escape title content before insertion (`\` → `\\`, `"` → `\"`, newlines → spaces).

### No spec file exists
Skip Step 4 (Verify Spec Capture) entirely with a note:
```
Note: No specification file found — skipping spec capture check.
```
Proceed directly to deletion. This is valid when operating without a permanent spec.

### DONE issue has only placeholder content
If a DONE issue file exists but contains only placeholder text (e.g., Decision section says `_To be filled_`, no Technical Notes), skip it silently during the spec capture check. Do not present empty items to the user.

### General issues only (scope selection)
When user selects "General issues only":
- Only process G- prefixed issues
- Leave all P1-, P2-, etc. issues completely unchanged
- Spec capture check (Step 4) only examines G-prefixed DONE issues and G-prefixed LOG.md references
- LOG.md updates only apply to G- references
- Report shows only general issues in results

```
Issues Restart Complete (General Issues Only)

Deleted (X DONE general issues):
- G-001: {title}

Renumbered (Y active general issues):
- G-002 -> G-001: {title}
- G-003 -> G-002: {title}

Unchanged (phase issues not included):
- P1-001, P1-002, P1-003
- P2-001, P2-002

Updated files:
- siw/OPEN_ISSUES_OVERVIEW.md (general section only)
- siw/LOG.md (N general issue references updated)
```
