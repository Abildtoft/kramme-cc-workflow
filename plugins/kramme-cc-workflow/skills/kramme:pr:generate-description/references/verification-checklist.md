# Verification Checklist

Run this before presenting copy-paste output, before `gh pr edit`, and before saving to file.

## Title

- [ ] Follows `<type>(<scope>): <description>` with a valid type (`feat`, `fix`, `refactor`, `docs`, `test`, `chore`, `perf`, `style`, `build`, `ci`, `revert`).
- [ ] Under 72 characters total. Imperative mood (`add`, not `added`). No trailing period.

## Summary and sections

- [ ] GitHub PR template lookup completed against the repository default branch; if a template exists, the body follows its heading order, required prompts, and checklists without duplicating default sections.
- [ ] The Summary says what changes in plain words, then why in user or business terms, and adds the pointer sentence when the PR breaks something, needs rollout steps, or departs from the linked issue.
- [ ] When a Linear (or GitHub) issue exists, it is linked with the correct magic word (`Fixes`, `Closes`, `Resolves`, `Related to`, `Refs`, `References`). When none exists, the body has no issue line.
- [ ] Each default section carries information for this PR: `## Changes` only for two or more separately reviewable changes, `## Breaking changes` only when something breaks, `## How it works` only for an approach that isn't obvious, `## Rollout` only when deploying takes more than a merge, and `## Review notes` only when something non-obvious remains. No default section says only "None" or "Not applicable".
- [ ] `## Changes` bullets describe one change each, or one theme each in a batch PR, start with an imperative verb, and use no vague verbs (`update`, `improve`) without an object.
- [ ] Migrations, feature-flag defaults, partial coverage, and rollout risk appear in `## Breaking changes`, `## Rollout`, or `## Review notes`.

## How it works and Test Plan

- [ ] `## How it works` explains key decisions and rejected alternatives. Divergences from the Linear issue have a clear rationale.
- [ ] The GitHub UI Duplication Guard from Phase 3.1.5 was applied.
- [ ] File names appear only when they identify a non-obvious entry point, migration, generated artifact, or cross-area coupling.
- [ ] Test Plan contains only reviewer/QA scenarios or manual validation notes, written as "Do X. Expect Y.", covering the behavior changes and risks a reviewer can't confirm from the diff. Automated testing instructions, command checklists, and missing test targets are omitted from the PR body.
- [ ] Local setup or infrastructure failures such as missing `node_modules`, failed package installs, unavailable Postgres, absent Docker services, and port conflicts are omitted from the PR body; CI owns automated verification status.
- [ ] `## Screenshots / Videos` appears only for UI-facing changes, with a one-line comment naming what to capture, and the run output reminds the author to add it.

## Boundary, tone, and operational hygiene

- [ ] Objective tone - no superlatives, no advocacy, no invented statistics.
- [ ] No references to spec files (`siw/SPEC.md`, `LOG.md`, etc.) or conversation history. Linear is the only external source the body may cite.
- [ ] No AI-attribution badges, "Generated with Claude Code", or `Co-Authored-By: Claude` lines.
- [ ] No placeholder `[TODO]` / `[Fill this in]` strings (except the one-line Screenshots comment on UI-facing changes).
- [ ] Markdown headings, code blocks, and lists are well-formed.

## Output routing

- [ ] `DIRECT_UPDATE=true`: no blocking missing requirements are present, then completed `references/direct-update.md` in order: captured one validated private `/tmp` directory as agent state, wrote title/body through the runtime's native writer, revalidated regular non-symlink payloads, created the mandatory title/body JSON backup, and ran `gh pr edit` in the same shell invocation as validation and cleanup. The success message always includes the retained metadata-backup path.
- [ ] `DIRECT_UPDATE=false`: presented copy-paste output; only asked about saving when `NON_INTERACTIVE=false`.
- [ ] Check-mode confirmed update (checked at publication, after the `y` and step 3 in `references/check-mode.md` Phase C5, not before generation finishes): the user answered `y`, no blocking missing requirement is present, and `references/direct-update.md` ran steps 1 and 2 followed by `Step 3 for a check-mode confirmed update`, which revalidated the PR snapshot, state, branch, head, base, and local work before `gh pr edit`.
- [ ] A user-confirmed save used the self-contained local-exclude and symlink-rejection procedure in `SKILL.md`; it did not depend on the private direct-update flow.
- [ ] Any `MISSING REQUIREMENT`, `UNVERIFIED`, `CONFUSION`, or `NOTICED BUT NOT TOUCHING` markers are emitted in the run output, not embedded in the PR body.
- [ ] Workflow artifact setup did not modify tracked files solely to ignore generated PR-description files.

## Readability pass

- [ ] The readability pass ran, and its keep-list audit ran after the last edit: every keep-list item that applies is still stated.
- [ ] The body is sized to the change: `## Changes` has about eight bullets at most and the Test plan about six scenarios at most, or the body groups by theme, samples the scenarios, and says what it leaves to the commits.
- [ ] Removed repeated phrasing or duplicated facts across sections; no section points to another instead of stating its own fact.
- [ ] The cold read ran once in a fresh agent and its findings were applied, or the run output says why it was skipped.
- [ ] The cold-read result, its open questions, and the screenshot reminder are in the run output, not in the PR body.
