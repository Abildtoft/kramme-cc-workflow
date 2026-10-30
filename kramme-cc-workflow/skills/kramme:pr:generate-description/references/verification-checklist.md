# Verification Checklist

Run this before presenting copy-paste output, before the REST update, and before saving to file. Part 1 of `references/readability-pass.md` also edits the draft against every section except Output routing and Cold read.

An item labeled **Regenerate** means the draft is wrong at its root: when it fails, regenerate the description from the gathered context instead of patching it. Fix any other failure in place.

## Title

- [ ] Follows `<type>(<scope>): <description>` with a valid type (`feat`, `fix`, `refactor`, `docs`, `test`, `chore`, `perf`, `style`, `build`, `ci`, `revert`).
- [ ] Under 72 characters total. Imperative mood (`add`, not `added`). No trailing period.

## Summary and sections

- [ ] GitHub PR template lookup completed against the repository default branch; if a template exists, the body follows its heading order, required prompts, and checklists without duplicating default sections.
- [ ] **Regenerate:** The Summary says what changes in plain words, with concrete nouns rather than "various changes" or "multiple improvements", then why in user or business terms, and adds the pointer sentence when the PR breaks something, needs rollout steps, or departs from the linked issue.
- [ ] When a Linear (or GitHub) issue exists, it is linked with the correct magic word (`Fixes`, `Closes`, `Resolves`, `Related to`, `Refs`, `References`). When none exists, the body has no issue line.
- [ ] Each default section carries information for this PR: `## Changes` only for two or more separately reviewable changes, `## Breaking changes` only when something breaks, `## How it works` only for an approach that isn't obvious, `## Rollout` only when deploying takes more than a merge, and `## Review notes` only when something non-obvious remains.
- [ ] `## Changes` bullets start with an imperative verb and use no vague verbs (`update`, `improve`) without an object.
- [ ] **Regenerate:** A migration, feature-flag default change, or breaking change in the diff appears in `## Breaking changes`, `## Rollout`, or `## Review notes`.
- [ ] Partial coverage and rollout risk appear in `## Rollout` or `## Review notes`.

## Readability

Judge each item as the reader named in the fixed reader contract in Part 1 of `references/readability-pass.md`.

1. **Plain opening.** From the first paragraph alone, a newcomer can say what changes and for whom. It names no files, classes, or internal identifiers; a user-facing command or setting name is fine.
2. **Said once.** No fact appears twice at the same level of detail. Keep it where it belongs and delete the copy. No section points to another ("as noted under...") instead of stating its own fact. The Summary naming an outcome that `## Changes` breaks down, and the Test plan naming the behavior it exercises, are not repeats.
3. **Every heading earns its place.** Each default section says something no other section says, and none says only "None", "N/A", or "Not applicable". A repository template's required prompts are exempt and always get an answer.
4. **One job per line.** Each `## Changes` bullet is one sentence about one change or, in a batch PR, one theme. Flag any sentence or bullet over about 30 words that makes two claims, and any sentence that names three or more internal identifiers such as files, classes, or functions. Fix it by splitting it or by moving the reason to `## How it works`. A sentence that introduces a short list after a colon is fine when each item is a few words. A concrete example the reader can try, such as a command or a request, is not an identifier: keep it where it makes the point clearer.
5. **Terms.** Each term this PR introduces, or uses in a special sense, is explained at first use or replaced with plain words. Internal names from specs, plans, or the conversation get the same treatment. An established project term, such as a product or module name the team uses daily, stays as it is, except in the opening paragraph, where it gets a few words of explanation.
6. **Facts, not self-report.** No "I made sure", "carefully", or lists of areas nobody expected to change. Scope boundaries read as facts about the code ("The multi-platform picker is unchanged").
7. **Claims can be tested.** The behavior changes and risks a reviewer can't confirm from the diff have a Test plan scenario, or a stated reason they can't be checked by hand. Each scenario says what to do and what to expect.
8. **Sized to the change.** Compare the body with the Length check in `references/best-practices.md`. If it runs well past its range, or `## Changes` has more than about eight bullets, or the Test plan more than about six scenarios, group the changes by theme and combine or sample the scenarios before anything else.
9. **Keep-list audit.** Run this last, and again after the cold read. For each keep-list item that applies, find the sentence that states it. If an edit removed the only such sentence, put it back.

## How it works and Test Plan

- [ ] `## How it works` explains key decisions and rejected alternatives. Divergences from the Linear issue have a clear rationale.
- [ ] **Regenerate:** The GitHub UI Duplication Guard from Phase 3.1.5 was applied: the body has no "Key Files", "Files Changed", or similar section that mostly repeats the GitHub file list, and no "Changes by Area" section whose bullets could be reconstructed from GitHub's file tree.
- [ ] File names appear only when they identify a non-obvious entry point, migration, generated artifact, or cross-area coupling.
- [ ] Test Plan contains only reviewer/QA scenarios or manual validation notes, written as "Do X. Expect Y.". Automated testing instructions, command checklists, CI-owned checks such as format, lint, typecheck, build, or the standard unit-test suite, and missing test targets are omitted from the PR body.
- [ ] Local setup or infrastructure failures such as missing `node_modules`, failed package installs, unavailable Postgres, absent Docker services, and port conflicts are omitted from the PR body; CI owns automated verification status.
- [ ] `## Screenshots / Videos` appears only for UI-facing changes, with a one-line comment naming what to capture, and the run output reminds the author to add it.

## Boundary, tone, and operational hygiene

- [ ] Objective tone - no superlatives, no advocacy, no invented statistics.
- [ ] **Regenerate:** No references to spec files (`siw/SPEC.md`, `siw/LOG.md`, etc.) or conversation history; reviewers can't see them. Linear is the only external source the body may cite.
- [ ] **Regenerate:** No AI-attribution badges, "Generated with Claude Code", or `Co-Authored-By: Claude` lines.
- [ ] No placeholder `[TODO]` / `[Fill this in]` strings (except the one-line Screenshots comment on UI-facing changes).
- [ ] Markdown headings, code blocks, and lists are well-formed.

## Output routing

- [ ] `DIRECT_UPDATE=true`: no blocking missing requirements are present, then completed `references/direct-update.md` in order: captured one validated private `/tmp` directory as agent state, wrote title/body through the runtime's native writer, revalidated regular non-symlink payloads, created the mandatory title/body JSON backup, and ran `gh api --method PATCH` with `--hostname` from that backup's PR URL in the same shell invocation as validation and cleanup. The success message always includes the retained metadata-backup path.
- [ ] `DIRECT_UPDATE=false`: presented copy-paste output; only asked about saving when `NON_INTERACTIVE=false`.
- [ ] Check-mode confirmed update (checked at publication, after the `y` and step 3 in `references/check-mode.md` Phase C5, not before generation finishes): the user answered `y`, no blocking missing requirement is present, and `references/direct-update.md` ran steps 1 and 2 followed by `Step 3 for a check-mode confirmed update`, which revalidated the PR snapshot, state, branch, head, base, and local work before the REST update.
- [ ] A user-confirmed save used the self-contained local-exclude and symlink-rejection procedure in `SKILL.md`; it did not depend on the private direct-update flow.
- [ ] Any `MISSING REQUIREMENT`, `UNVERIFIED`, `CONFUSION`, or `NOTICED BUT NOT TOUCHING` markers are emitted in the run output, not embedded in the PR body.
- [ ] Workflow artifact setup did not modify tracked files solely to ignore generated PR-description files.

## Cold read

- [ ] The cold read ran once in a fresh agent and its findings were applied, or `When to Skip the Cold Read` in `references/readability-pass.md` allowed the skip. Running non-interactively is not by itself a reason to skip.
- [ ] The run output, outside the PR body, has exactly one line starting `Cold read:`, either the outcome or `Cold read: skipped (<reason>)`, followed by at most three open questions.
