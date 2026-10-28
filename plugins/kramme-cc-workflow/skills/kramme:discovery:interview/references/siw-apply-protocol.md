# SIW Apply Protocol

Use this only in SIW mode, when `apply_changes=true` passed the user-only check in `SKILL.md` or the user asks in this session to apply discovery output.

## Refinement Mode

1. Before changing any file, list every target document and section from the patch plan, plus `siw/SPEC_STRENGTHENING_PLAN.md` as the file to remove afterward, and ask by asking the user directly in chat (`Apply these edits` / `Stop, I'll review first`). Proceed only on explicit approval in this session; otherwise stop and leave the plan in place.
2. Edit the target document(s) using the validated `INTERVIEW RESULT:` and its artifact impact map, as synthesized in `siw/SPEC_STRENGTHENING_PLAN.md`.
3. Target documents may be SIW spec files or `siw/DISCOVERY_BRIEF.md`.
4. Preserve structure: add missing sections, do not scatter content.
5. Preserve any `MISSING REQUIREMENT:` markers for unresolved dimensions instead of filling those sections with guesses.
6. If a full SIW workflow exists, update `siw/LOG.md` Decision Log with:
   - Summary of discovery session
   - Key decisions and rationale
   - Remaining open questions
7. After the target documents and optional log updates are complete, remove `siw/SPEC_STRENGTHENING_PLAN.md` using a trash-first, verified deletion:
   - If `trash` is installed, run `trash siw/SPEC_STRENGTHENING_PLAN.md` without suppressing errors.
   - If `trash` is missing, warn that the file will be permanently deleted and ask for explicit confirmation before deleting exactly `siw/SPEC_STRENGTHENING_PLAN.md`; reject wildcards, directory paths, recursive flags, and force flags.
   - After deletion, verify `[ ! -e siw/SPEC_STRENGTHENING_PLAN.md ]`. Report a failure if the file still exists instead of claiming it was removed. This prevents future runs from treating the applied plan as unresolved state while keeping deletion recoverable when possible.

## Greenfield Mode

- Apply is not applicable: the brief is the output.
- Suggest `$kramme:siw:init siw/DISCOVERY_BRIEF.md` for full workflow setup.
