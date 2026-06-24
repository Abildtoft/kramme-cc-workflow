# Close Summary Template

Print a closing summary built from what actually happened. Include only lines that apply -- do not emit the `(if ...)` annotations themselves.

Sections to include:

- **Documentation generated:** every file written under `{docs_path}/` (always at least `README.md` and `decisions.md`; `architecture.md` when generated).
- **Removed:** each path verified absent in Step 7.2 (skip lines for files that never existed).
- **Failed to remove:** each target that still exists after Step 7.2, with the captured error. Omit the section if all targets were removed.
- **Preserved:** each path that survived (`siw/{spec_filename}`, `siw/supporting-specs/`, `siw/contracts/`, `siw/SPEC_STRENGTHENING_PLAN.md`, `{docs_path}/spec/`). Omit the section if nothing was preserved.
- **Recovery note:** if `trash` was used in Step 7.2, add: `Files moved to Trash and can be restored if needed.`
- A final line: `The documentation in {docs_path}/ is self-contained and can be read without any SIW context.`

Example shape (with placeholders for the dynamic content):

```text
SIW Project Closed

Documentation generated:
  {docs_path}/README.md              - Project summary
  {docs_path}/decisions.md           - {N} design decisions
  {docs_path}/architecture.md        - Technical design

Removed:
  siw/LOG.md
  siw/OPEN_ISSUES_OVERVIEW.md
  siw/issues/ ({count} issue files)
  siw/qa-intake/ ({count} intake summaries)

Preserved:
  {docs_path}/spec/

Files moved to Trash and can be restored if needed.

The documentation in {docs_path}/ is self-contained and
can be read without any SIW context.
```
