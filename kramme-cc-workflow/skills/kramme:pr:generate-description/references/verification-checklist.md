# Verification Checklist

Run this before presenting copy-paste output, before `gh pr edit`, and before saving to file.

## Title

- [ ] Follows `<type>(<scope>): <description>` with a valid type (`feat`, `fix`, `refactor`, `docs`, `test`, `chore`, `perf`, `style`, `build`, `ci`, `revert`).
- [ ] Under 72 characters total. Imperative mood (`add`, not `added`). No trailing period.

## Summary and Change Summary block

- [ ] GitHub PR template lookup completed against the repository default branch; if a template exists, the body follows its heading order, required prompts, and checklists without duplicating default sections.
- [ ] Summary restates the _why_ in business terms, not just the _what_.
- [ ] Linear (or GitHub) issue linked with the correct magic word (`Fixes`, `Closes`, `Resolves`, `Related to`, `Refs`, `References`).
- [ ] `### Changes made` lists distinct verb-led bullets - no vague verbs (`update`, `improve`) without an object.
- [ ] `### Things I didn't touch` reflects adjacent work considered and deliberately deferred (or `None` after consideration).
- [ ] `### Potential concerns` flags migrations, feature-flag defaults, partial coverage, and rollout risk (or `None`).

## Technical Details and Test Plan

- [ ] Implementation approach explains key decisions. Divergences from the Linear issue have a clear rationale.
- [ ] The GitHub UI Duplication Guard from Phase 3.1.5 was applied.
- [ ] File names appear only when they identify a non-obvious entry point, migration, generated artifact, or cross-area coupling.
- [ ] Test Plan contains only reviewer/QA scenarios or manual validation notes. Automated testing instructions, command checklists, and missing test targets are omitted from the PR body.
- [ ] Breaking changes section is present (`None` is a valid value after consideration).
- [ ] Screenshots/Videos section is included - populated when `--visual` produced embeddable remote assets, local-only table when copy-paste output can reference captured files, placeholder when capture failed or direct-update mode only has local files.

## Boundary, tone, and operational hygiene

- [ ] Objective tone - no superlatives, no advocacy, no invented statistics.
- [ ] No references to spec files (`siw/SPEC.md`, `LOG.md`, etc.) or conversation history. Linear is the only external source the body may cite.
- [ ] No AI-attribution badges, "Generated with Claude Code", or `Co-Authored-By: Claude` lines.
- [ ] No placeholder `[TODO]` / `[Fill this in]` strings (except the documented Screenshots placeholder).
- [ ] Markdown headings, code blocks, and lists are well-formed.

## Output routing

- [ ] `DIRECT_UPDATE=true`: no blocking missing requirements are present, then ran the Phase 4 sequence in order: repo-root anchored backup, local git exclude update, title/body files written outside shell interpolation, `gh pr edit --title "$(cat ...)" --body-file ...`. The success message includes the backup line only when the backup file is non-empty.
- [ ] `DIRECT_UPDATE=false`: presented copy-paste output; only asked about saving when `NON_INTERACTIVE=false`.
- [ ] Any `MISSING REQUIREMENT`, `UNVERIFIED`, `CONFUSION`, or `NOTICED BUT NOT TOUCHING` markers are emitted in the run output, not embedded in the PR body.
- [ ] Workflow artifact setup did not modify tracked files solely to ignore generated PR-description files.

## Final conciseness pass

- [ ] Removed repeated phrasing or duplicated facts across Summary, Change Summary, Technical Details, Test Plan, and Breaking Changes.
- [ ] Shortened paragraphs and bullets that do not add reviewer value while preserving the why, risks, scope boundaries, and test instructions.
