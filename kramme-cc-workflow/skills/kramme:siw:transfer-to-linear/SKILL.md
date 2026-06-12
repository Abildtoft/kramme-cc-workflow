---
name: kramme:siw:transfer-to-linear
description: One-way migration of a local SIW project into Linear. Creates one Linear project, migrates the main spec, supporting specs, and decision log as Linear Documents, creates milestones from SIW phases and issues from SIW issues (with native blocking relations when the Linear tooling supports them), writes minimal Linear transfer markers back to migrated source issues for retry safety, then prompts to retire the local siw/ files via /kramme:siw:remove. Linear becomes the source of truth; this is not a two-way sync. Use when moving a planned SIW initiative into Linear for good. Not for implementing issues, defining new SIW issues, or generating an issue breakdown.
argument-hint: "[siw-dir] [--project <name-or-id>] [--team <team>] [--dry-run] [--skip-done] [--skip-existing|--retry]"
disable-model-invocation: true
user-invocable: true
---

# Migrate SIW Project to Linear

Migrate an existing Structured Implementation Workflow project into Linear in one direction: create or update one Linear project, migrate the spec and supporting specs as Linear Documents, create milestones from SIW phases, create issues for local SIW issues, and finish by prompting the user to retire the local `siw/` directory. After a successful migration, **Linear is the single source of truth** and the local SIW artifacts are abandoned.

## Workflow Boundaries

**This command migrates tracking and planning artifacts into Linear, then hands off removal.**

- **DOES**: Read SIW markdown artifacts, create or update one Linear project, migrate the main spec, supporting specs, and decision log as Linear Documents under that project, create project milestones from SIW phases, create Linear issues for local SIW issues, record dependencies as text in issue descriptions and as native issue relations when the Linear tooling supports them, inventory non-markdown SIW artifacts that cannot be migrated, write Linear issue markers back to migrated source issue files, verify the writes, and prompt the user to run `/kramme:siw:remove`.
- **DOES NOT**: Implement code, define new SIW issues, generate an issue breakdown, delete `siw/` files itself, keep a two-way sync, or silently overwrite unrelated Linear work.

**Linear Migration Override**: Invoking this command is explicit instruction to create or update the Linear project, documents, milestones, and issues after the user approves the migration plan. Always present the plan before any write unless `--dry-run` is passed, in which case no Linear writes occur.

**One-way with retry markers**: This skill is still a one-shot migration, not an idempotent sync. To make interrupted runs recoverable, write a minimal `Linear Transfer` marker back to each SIW issue file immediately after its Linear issue is created. On every run, source issues that already carry a marker are skipped, and existing project documents and milestones are reused by normalized title whenever the target project already exists. `--skip-existing` (alias `--retry`) additionally matches unmarked source issues against existing Linear issues by exact title, and only when the source title is unique among unmarked source issues.

## Input Handling

`$ARGUMENTS` may contain:

- `siw-dir`: optional path to an SIW directory. Default: `siw`.
- `--project <name-or-id>`: use or update an existing Linear project if it matches; otherwise create with this name after approval.
- `--team <team>`: Linear team name, key, or UUID.
- `--dry-run`: build and print the migration plan without creating or updating Linear records and without prompting for removal.
- `--skip-done`: omit issues whose SIW status is DONE. Default is to migrate everything, including DONE issues.
- `--skip-existing`: additionally match unmarked source issues against existing Linear issues in the target team/project by exact normalized title, for source titles that are unique among unmarked source issues. Marker-based issue skips and document/milestone title reuse happen on every run and do not require this flag.
- `--retry`: alias for `--skip-existing`, intended for resuming after a partial issue-write failure.

If a positional argument is an existing directory, treat it as `siw-dir`. If it contains a path separator but does not exist, stop and report the missing path instead of reinterpreting it. Otherwise treat it as a project-name hint.

## Phase 1: Validate Prerequisites

1. Verify the SIW directory exists.
2. Verify at least one permanent spec file or `OPEN_ISSUES_OVERVIEW.md` exists under the SIW directory. If not found, stop and suggest `/kramme:siw:init`.
3. Verify Linear tools are available:
   - Read tools: list teams, list projects, list milestones, list issue labels, list issue statuses.
   - Write tools: project create/update, milestone create/update, and issue create/update. Document create is optional — the spec migration falls back to the project description when it is unavailable. Linear tool names and prefixes vary across hosts and catalogs — discover the available Linear tools at runtime rather than assuming exact names.
   - Discover capabilities, not just names: inspect the issue create/update tool schema for relation parameters (such as `blockedBy` / `blocks` / `relatedTo`) and check for attachment-upload tools. Relation support upgrades the dependency handling in Phases 4 and 6 from text-only to native relations; never assume support is absent just because an older catalog lacked it.
4. If the core Linear write tools (project, milestone, issue) are unavailable and `--dry-run` is not set, stop. If `--dry-run` is set, continue with an offline plan and mark all Linear metadata as `UNVERIFIED`.

## Phase 2: Extract SIW Artifacts

Read the artifact extraction rules from `references/artifact-extraction.md`.

Extract:

- Project identity, summary, scope, success criteria, work context, and phase structure from the main spec and supporting specs.
- The full text of the main spec, each `supporting-specs/*.md` file, each non-selected main-spec candidate, and `LOG.md`, to migrate as Linear Documents.
- Current project status, decisions, and completed/deferred work from `LOG.md`.
- Milestone candidates from phase sections, milestones, and explicit phase target dates.
- Issue list, sections, statuses, priorities, sizes, modes, related work, milestone assignment, source paths, and existing `Linear Transfer` markers from `OPEN_ISSUES_OVERVIEW.md` and `issues/ISSUE-*.md`.
- The dependency graph from each issue file's `Blocked by:` / `Blocks:` lines, with ranges like `P3-002..P3-007` expanded, for the relation pass in Phase 6.
- An inventory of non-markdown files under the SIW directory (for example `.pptx` storyboards or images). These cannot be migrated as Documents and must be surfaced in the plan and gate the removal prompt.

If `--skip-done` is set, drop DONE issues from the issue list before planning.

If no local issue files exist, migrate the Linear project and documents only, and ask whether to create a single planning issue from the spec. Do not invent a multi-issue breakdown; `/kramme:siw:generate-phases` is the workflow for that.

## Phase 3: Resolve Linear Context

1. Fetch Linear teams.
2. Resolve the target team:
   - Use `--team` when it matches exactly by name, key, or UUID.
   - If only one team exists, use it.
   - Otherwise ask the user which team should own the migration.
3. Fetch issue statuses for the chosen team.
4. Fetch active projects.
5. Resolve the target project:
   - If `--project` matches an existing project by ID, slug, or exact name, use it as the update target.
   - Otherwise derive a project name from the main spec title and prepare a create action.
6. Fetch milestones for the chosen project when the project already exists. If the project will be created, defer milestone lookup until after project creation and treat all phase milestones as planned creates.
7. Fetch labels. Use existing labels only. Do not create labels unless the user explicitly asks during the plan review.
8. If the target project already exists, fetch existing Linear Documents under it when the tool catalog supports it, for title-based reuse per the duplicate-detection rules in `references/linear-mapping.md`.
9. If `--skip-existing` or `--retry` is set, fetch candidate existing Linear issues for the resolved team and project when possible, for the issue title fallback defined in `references/linear-mapping.md`.

## Phase 4: Build Migration Plan

Read the Linear mapping rules from `references/linear-mapping.md`.

Build a plan with:

- Project action: `create`, `update`, or `reuse`.
- Document actions: `create` by default for each document source (main spec, each supporting spec, each non-selected main-spec candidate, and `LOG.md`). When the target project already exists and exactly one existing project document matches the planned normalized title, mark it `skip-existing` and carry its URL into the result summary. Mark `needs decision` when duplicate title matches make the target ambiguous.
- Milestone actions: `create`, `update`, `reuse`, `skip`, or `needs decision`, matched by normalized name per `references/linear-mapping.md`; there is no SIW marker.
- Issue actions: `create` by default. Mark `skip-existing` when the source issue already has a `Linear Transfer` marker (every run), or when the `--skip-existing` / `--retry` title fallback matched per `references/linear-mapping.md`. Mark `needs decision` when an issue appears in `OPEN_ISSUES_OVERVIEW.md` but its issue file is missing, or when title matching is ambiguous on either side.
- Metadata mappings for milestone, state, priority, labels, and project.
- Dependencies recorded as text in the issue description (the `Related` field and the SIW metadata block) on every run. When Phase 1 found relation parameters on the issue write tool, additionally plan a relation pass: after all issues are created, resolve each issue's `Blocked by:` / `Blocks:` edges through the SIW-ID-to-Linear-ID transfer ledger and write them as native relations per `references/linear-mapping.md`. Report the planned edge count and any edges that reference unknown SIW IDs.
- Non-markdown SIW artifacts listed as `cannot migrate — needs relocation`, naming each file. When Phase 1 found Linear attachment-upload tools, offer uploading them as issue or project attachments instead.

Whenever the plan contains `skip-existing` actions, include a "Skipped existing" section naming each skipped document or issue source item and the matched Linear record ID/URL, marker, or title-match reason.

## Phase 5: Review Plan

Present the migration plan before any write:

```text
SIW -> Linear Migration Plan
Project: {create/update/reuse} {project name}
Team: {team}
Documents: {create_count} create, {skip_existing_count} skip-existing, {decision_count} need decision  (main spec + supporting specs + decision log)
Milestones: {create_count} create, {update_count} update, {skip_count} skip, {decision_count} need decision
Issues: {create_count} create, {skip_existing_count} skip-existing, {skip_count} skip, {decision_count} need decision  (DONE: {included/skipped})
Relations: {edge_count} dependency edges (as blocked-by) {planned as native relations | recorded as text only — no relation support}
Non-markdown artifacts: {count} cannot migrate — needs relocation
After migration: prompt to run /kramme:siw:remove (no files deleted by this command)

{document list}
{milestone action table}
{issue action table}
{non-markdown artifact list}
```

If `--dry-run` is set, stop after printing the plan.

If the plan contains `needs decision` items, ask the user how to resolve each one before proceeding. Then ask for final approval to execute the migration. If the user does not approve, stop without writing.

## Phase 6: Execute Migration

Execute in this order:

1. Create or update the Linear project (a project requires at least one team).
2. Create planned Linear Documents under the project and skip `skip-existing` document actions, carrying the matched document URL into the result summary. If document creation is unavailable, fall back to embedding the main spec summary in the project description and record which supporting specs could not become Documents.
3. Create or update all planned project milestones.
4. Create all planned issues, assigning each to its mapped milestone when available and applying any mapped existing labels. `G-*` issues get no milestone. Record dependencies as text in every issue body regardless of relation support.
   - Skip `skip-existing` issue actions and carry the matched Linear ID/URL into the result summary.
   - After each successful issue create, immediately append or update this section in the source SIW issue file:

     ```markdown
     ## Linear Transfer

     - Linear issue: {identifier} {url}
     - Linear project: {project URL}
     - Transferred: {YYYY-MM-DD}
     ```

   - Maintain an in-memory transfer ledger with one row per source issue: source item, SIW ID, title, Linear ID/URL, and status `CREATED`, `CREATED_NO_MARKER`, `SKIPPED_EXISTING`, or `PENDING`.

5. Relation pass (only when the plan includes one): after all issues exist, resolve each planned `Blocked by:` / `Blocks:` edge from SIW IDs to Linear IDs via the transfer ledger and write the native relations. Relation parameters are append-only, so re-running the pass is safe. Report any edges left unresolved.
6. If the plan deferred milestone ordering text until after issue creation, update those milestone descriptions now per `references/linear-mapping.md` > Milestone Mapping, using the Linear identifiers from the transfer ledger.
7. Capture each Linear project, document, milestone, and issue identifier and URL for the result summary.

For each write, use only the current migration plan. Do not widen scope to unrelated Linear projects or issues discovered during execution.

## Phase 7: Verify and Prompt Removal

1. Verify the migration: every planned write returned a Linear identifier and URL, the transfer ledger contains no `PENDING` or `CREATED_NO_MARKER` rows, each created issue's source file carries its `Linear Transfer` marker, and every planned relation edge was written. When spot-checking migrated Document content, compare normalized content, not bytes — Linear normalizes markdown on save (bullet style, table dashes, bold spans, auto-linked bare domains), so a content-identical document is a pass even when it is not byte-identical.
2. Report:
   - Linear project URL.
   - Counts of created/updated milestones, documents, and issues, plus any skipped or unresolved items.
3. Removal prompt:
   - If the migration completed cleanly (no errored writes, no unresolved in-scope issues, and the design docs are captured as Documents or via the description fallback) and the SIW directory contains no unrelocated non-markdown artifacts, prompt: `Migration complete and verified. Run /kramme:siw:remove to retire the local siw/ directory.`
   - If anything errored, was skipped due to failure, any supporting spec could not be captured in Linear, or any non-markdown artifact has not been relocated or uploaded, **do not** prompt removal. Name exactly what is still local-only so the user does not delete uncaptured work.

End the workflow here. Do not delete files and do not start implementation. A relevant follow-up for a newly created Linear issue is `/kramme:linear:issue-implement {issue-id}`.

## Error Handling

- **Missing SIW artifacts**: stop and name the missing directory or file.
- **Linear MCP unavailable**: stop unless `--dry-run` is set.
- **No team can be resolved**: ask once; if still unresolved, stop.
- **Document creation unavailable**: fall back to embedding spec content in the project description, warn that supporting specs could not become standalone Documents, and withhold the removal prompt.
- **Milestone write failure**: stop before writing dependent issues unless the user explicitly chooses to continue without milestone assignment; withhold the removal prompt.
- **Marker write-back failure**: if appending the `## Linear Transfer` section to a source file fails after a successful Linear issue create, set that ledger row to `CREATED_NO_MARKER`, continue with the remaining issues, include the row in the retry ledger, and withhold the removal prompt.
- **OAuth token expiry mid-run**: long migrations can outlive the Linear OAuth token. If a write fails with an authorization error partway through, ask the user to re-authorize, then resume — markers already written keep completed issues skip-safe.
- **Relation write failure**: issues and their text dependencies are already complete, so do not roll anything back. Report the unwritten edges and note that re-running the relation pass is safe (relation parameters are append-only).
- **Issue write failure**: stop after reporting the failed action, withhold the removal prompt, and print a machine-usable retry ledger in this exact fenced shape:

  ```text
  LINEAR_TRANSFER_RETRY
  Command: /kramme:siw:transfer-to-linear {siw-dir} --project {project} --team {team} --retry

  | Source item | Title | Linear ID | Status |
  | --- | --- | --- | --- |
  | {issue-file} | {title} | {LIN-123 or PENDING} | {CREATED|CREATED_NO_MARKER|SKIPPED_EXISTING|PENDING} |
  ```

  The retry path follows the duplicate-detection rules in `references/linear-mapping.md`. Rows that the rules mark `needs decision` may be disambiguated by this retry ledger or another user-provided source-item mapping.
