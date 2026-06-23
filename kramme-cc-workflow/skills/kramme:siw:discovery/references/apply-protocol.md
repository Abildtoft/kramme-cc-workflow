# Apply Protocol

Use this only when `apply_changes=true` or the user asks to apply discovery output.

## Refinement Mode

1. Edit the target document(s) using decisions from Step 4.
2. Target documents may be SIW spec files or `siw/DISCOVERY_BRIEF.md`.
3. Preserve structure: add missing sections, do not scatter content.
4. Preserve any `MISSING REQUIREMENT:` markers for unresolved dimensions instead of filling those sections with guesses.
5. If a full SIW workflow exists, update `siw/LOG.md` Decision Log with:
   - Summary of discovery session
   - Key decisions and rationale
   - Remaining open questions
6. After the target documents and optional log updates are complete, remove `siw/SPEC_STRENGTHENING_PLAN.md` using a trash-first, verified deletion:
   - If `trash` is installed, run `trash siw/SPEC_STRENGTHENING_PLAN.md` without suppressing errors.
   - If `trash` is missing, warn that the file will be permanently deleted and ask for explicit confirmation before deleting exactly `siw/SPEC_STRENGTHENING_PLAN.md`; reject wildcards, directory paths, recursive flags, and force flags.
   - After deletion, verify `[ ! -e siw/SPEC_STRENGTHENING_PLAN.md ]`. Report a failure if the file still exists instead of claiming it was removed. This prevents future runs from treating the applied plan as unresolved state while keeping deletion recoverable when possible.

## Greenfield Mode

- Apply is not applicable: the brief is the output.
- Suggest `/kramme:siw:init siw/DISCOVERY_BRIEF.md` for full workflow setup.
