---
name: kramme:siw:transfer-to-linear
description: One-way migration of a local SIW project into Linear. Creates one Linear project, migrates the main spec, supporting specs, selected contract specs, and decision log as Linear Documents, rewrites SIW-local markdown references to Linear Documents where possible, creates milestones from SIW phases and issues from SIW issues (with native blocking relations when supported), writes minimal Linear transfer markers back to migrated source issues for retry safety, then prompts to retire the local siw/ files via /kramme:siw:remove. Linear becomes the source of truth; this is not a two-way sync. Use when moving a planned SIW initiative into Linear for good. Not for implementing issues, defining new SIW issues, or generating an issue breakdown.
argument-hint: "[siw-dir] [--project <name-or-id>] [--team <team>] [--dry-run] [--skip-done] [--skip-existing|--retry]"
disable-model-invocation: true
user-invocable: true
---

# Migrate SIW Project to Linear

Migrate an existing Structured Implementation Workflow project into Linear in one direction: create or update one Linear project, migrate the spec, supporting specs, selected contract specs, and decision log as Linear Documents, create milestones from SIW phases, create issues for local SIW issues, rewrite SIW-local markdown references to Linear Documents, and finish by prompting the user to retire the local `siw/` directory. After a successful migration, **Linear is the single source of truth** and the local SIW artifacts are abandoned.

## Workflow Boundaries

**This command migrates tracking and planning artifacts into Linear, then hands off removal.**

- **DOES**: Read SIW markdown artifacts, create or update one Linear project, migrate the main spec, supporting specs, selected contract specs, and decision log as Linear Documents under that project, create project milestones from SIW phases, create Linear issues for local SIW issues, rewrite migrated SIW markdown references to Linear Documents where possible, record dependencies as text in issue descriptions and as native issue relations when the Linear tooling supports them, inventory non-markdown SIW artifacts that cannot be migrated, write Linear issue markers back to migrated source issue files, verify the writes, and prompt the user to run `/kramme:siw:remove`.
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
   - Read tools: list teams, list projects, list milestones, list issue labels, list issue statuses. Current issue and Document body reads are required before any rewrite-only update to an existing Linear record. Current issue body reads are also required for the existing-Linear side of the duplicate-content preflight when existing project issues are present; if body reads are unavailable, the plan must say that only in-batch content duplicates could be checked.
   - Write tools: project create/update, milestone create/update, and issue create/update. Document create is optional — the spec migration falls back to the project description when it is unavailable. Document update is optional, but required to rewrite links inside already-created or reused Document bodies after document URLs are known. Linear tool names and prefixes vary across hosts and catalogs — discover the available Linear tools at runtime rather than assuming exact names.
   - Discover capabilities, not just names: inspect the issue create/update tool schema for relation parameters (such as `blockedBy` / `blocks` / `relatedTo`) and check for attachment-upload tools. Relation support upgrades the dependency handling in Phases 4 and 6 from text-only to native relations; never assume support is absent just because an older catalog lacked it.
4. If Linear MCP tools are missing because the host is not connected or authenticated, report setup/auth hints before stopping. For Codex, the current MCP setup is `codex mcp add linear --url https://mcp.linear.app/mcp` followed by `codex mcp login linear`; older or generic clients can use `npx -y mcp-remote https://mcp.linear.app/mcp`. Do not run these setup commands inside the migration unless the user explicitly asks.
5. If the core Linear write tools (project, milestone, issue) are unavailable and `--dry-run` is not set, stop. If `--dry-run` is set, continue with an offline plan and mark all Linear metadata as `UNVERIFIED`.

## Phase 2: Extract SIW Artifacts

Read the artifact extraction rules from `references/artifact-extraction.md`.

Extract:

- Project identity, summary, scope, success criteria, work context, and phase structure from the main spec and supporting specs.
- The full text of the main spec, each `supporting-specs/*.md` file, each selected `contracts/*.md` file, each non-selected main-spec candidate, and `LOG.md`, to migrate as Linear Documents.
- Current project status, decisions, and completed/deferred work from `LOG.md`.
- Milestone candidates from phase sections, milestones, and explicit phase target dates.
- Issue list, sections, statuses, priorities, sizes, modes, related work, milestone assignment, source paths, and existing `Linear Transfer` markers from `OPEN_ISSUES_OVERVIEW.md` and `issues/ISSUE-*.md`.
- The dependency graph from each issue file's `Blocked by:` / `Blocks:` lines, with ranges like `P3-002..P3-007` expanded, for the relation pass in Phase 6.
- A reference inventory from issue and document bodies: SIW issue IDs (`Pn-NNN` / `G-NNN`), migrated markdown paths, register-code families (`D-*`, `OD-*`, `VER-*`, `Q-*`), inline-code paths that must be unwrapped before linking, and markdown table row cell counts. This feeds the Linear rewrite and verification passes.
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
9. Fetch candidate existing Linear issues for the resolved team and project when possible, including descriptions/bodies when the tool catalog exposes them, for the duplicate-content preflight defined in `references/linear-mapping.md`. If `--skip-existing` or `--retry` is set, also use these candidates for the issue title fallback defined there.

## Phase 4: Build Migration Plan

Read the Linear mapping rules from `references/linear-mapping.md`.

Build a plan with:

- Project action: `create`, `update`, or `reuse`.
- Document reference map: one row per document source with source path, filename, first heading/title, planned Linear Document title, action, rewrite action when applicable, and Linear Document URL when already known. Include the main spec, each supporting spec, each selected contract spec, each non-selected main-spec candidate, and `LOG.md`.
- Document actions: `create` by default for each document source (main spec, each supporting spec, each selected contract spec, each non-selected main-spec candidate, and `LOG.md`). When the target project already exists and exactly one existing project document matches the planned normalized title, mark it `skip-existing` and carry its URL into the document reference map and result summary. For skipped existing Documents, additionally plan a rewrite-only body update when required to replace SIW-local markdown references and the matched Linear Document body can be read and updated. Mark `needs decision` when duplicate title matches make the target ambiguous.
- Milestone actions: `create`, `update`, `reuse`, `skip`, or `needs decision`, matched by normalized name per `references/linear-mapping.md`; there is no SIW marker.
- Issue actions: `create` by default. Mark `skip-existing` when the source issue already has a `Linear Transfer` marker (every run), or when the `--skip-existing` / `--retry` title fallback matched per `references/linear-mapping.md`. For skipped existing issues, additionally plan a rewrite-only description update when required to replace SIW-local markdown references and the matched Linear issue body can be read and updated. Mark `needs decision` when an issue appears in `OPEN_ISSUES_OVERVIEW.md` but its issue file is missing, when title matching is ambiguous on either side, or when the duplicate-content preflight finds an unresolved content match.
- Duplicate-content preflight per `references/linear-mapping.md`: render the planned Linear issue description for every issue action that would create a Linear issue, compute substantive content fingerprints with every markdown reference rewrite that is resolvable during planning, and compare planned creates against each other plus readable existing Linear issues in the target team/project. Any duplicate-content group blocks the affected creates as `needs decision` until the user chooses a resolution. Report when existing Linear issue bodies could not be read, because then only in-batch duplicates were checked. The final Phase 6 preflight is authoritative because it runs after all Linear Document URLs are known and all rewritten issue descriptions are final.
- Cross-reference rewrite plan per `references/linear-mapping.md`: scan issue descriptions, project description, milestone descriptions, and migrated Document bodies for SIW-local markdown links, inline paths, SIW issue IDs, and register-code families. Rewrite only references whose targets are in the entities created or explicitly reused by this migration: migrated Document URLs, Linear issue identifiers, and register-owner Documents. Because new issue identifiers are not known until after issue creation, split this into a pre-create markdown/document/register rewrite and a post-create issue-reference rewrite. Report references outside the migrated entity set as unresolved local references.
- Metadata mappings for milestone, state, priority, labels, and project.
- Dependencies recorded as text in the issue description (the `Related` field and the SIW metadata block) on every run. When Phase 1 found relation parameters on the issue write tool, additionally plan a relation pass: after all issues are created, resolve each issue's `Blocked by:` / `Blocks:` edges through the SIW-ID-to-Linear-ID transfer ledger and write them as native relations per `references/linear-mapping.md`. Report the planned edge count and any edges that reference unknown SIW IDs.
- Rewrite verification facts: for each planned rewrite, record expected Linear identifier counts, Document URL counts, preserved SIW ID counts, migrated source paths removed from required implementation content, register pointer counts, absence of superseded inline metadata, and unchanged markdown table cell counts.
- Non-markdown SIW artifacts listed as `cannot migrate — needs relocation`, naming each file. When Phase 1 found Linear attachment-upload tools, offer uploading them as issue or project attachments instead.

Whenever the plan contains `skip-existing` actions, include a "Skipped existing" section naming each skipped document or issue source item and the matched Linear record ID/URL, marker, or title-match reason.

## Phase 5: Review Plan

Present the migration plan before any write:

```text
SIW -> Linear Migration Plan
Project: {create/update/reuse} {project name}
Team: {team}
Documents: {create_count} create, {skip_existing_count} skip-existing, {rewrite_only_update_count} rewrite-only update, {decision_count} need decision  (main spec + supporting specs + selected contract specs + decision log)
Milestones: {create_count} create, {update_count} update, {skip_count} skip, {decision_count} need decision
Issues: {create_count} create, {skip_existing_count} skip-existing, {rewrite_only_update_count} rewrite-only update, {skip_count} skip, {decision_count} need decision  (DONE: {included/skipped})
Duplicate content: {group_count} duplicate groups, {blocked_create_count} creates blocked, {existing_body_check: checked existing Linear bodies | existing Linear body check unavailable}
Cross-references: {issue_ref_count} issue refs, {document_ref_count} document refs, {register_family_count} register families, {unresolved_count} unresolved local-only
Relations: {edge_count} dependency edges (as blocked-by) {planned as native relations | recorded as text only — no relation support}
Non-markdown artifacts: {count} cannot migrate — needs relocation
After migration: {prompt to run /kramme:siw:remove | withhold removal prompt until unresolved required references/non-markdown artifacts are handled} (no files deleted by this command)

{document list}
{document reference map}
{unresolved local markdown reference list}
{milestone action table}
{issue action table}
{duplicate content group list}
{non-markdown artifact list}
```

If `--dry-run` is set, stop after printing the plan.

If the plan contains `needs decision` items, ask the user how to resolve each one before proceeding. Then ask for final approval to execute the migration. If the user does not approve, stop without writing.

## Phase 6: Execute Migration

Execute in this order:

1. Create or update the Linear project (a project requires at least one team). If the final project description references migrated files, use a minimal provisional description now and defer the final rewritten description until after document URLs are known.
2. Create planned Linear Documents under the project and skip `skip-existing` document creates, carrying each created or reused document URL into the document reference map and result summary. If a skipped existing Document needs markdown reference rewrites, keep its rewrite-only body update as a separate planned update action. If document creation is unavailable, fall back to embedding the main spec summary in the project description and record which supporting specs, contract specs, and other document sources could not become Documents.
3. Run the pre-create rewrite pass per `references/linear-mapping.md` after the document reference map has URLs: issue descriptions, project description when it references files, milestone descriptions when they reference files, migrated Document bodies that link to other migrated SIW markdown files, and register-code family pointers. Defer SIW issue ID rewrites that require Linear issue identifiers until after issue creation. Update the project description with the rewritten final text when it was deferred, and update rewritten Document bodies when the Linear tool catalog supports current-body reads plus updates. If document body rewrites require updating already-created Documents and no document read or update tool exists, report those references as unresolved local-only and withhold the removal prompt.
4. Create or update all planned project milestones with rewritten descriptions.
5. Run the final duplicate-content preflight immediately before issue creation, using the final rewritten descriptions that will be sent to Linear. Re-fetch readable existing issue bodies for the target team/project when possible so changes since planning are caught. If any unresolved duplicate-content group is found, stop before creating any issue, report the matching source issues and/or Linear issues, ask the user how to resolve them, and withhold the removal prompt.
6. Create all planned issues with rewritten descriptions, assigning each to its mapped milestone when available and applying any mapped existing labels. `G-*` issues get no milestone. Record dependencies as text in every issue body regardless of relation support.
   - Skip `skip-existing` issue creates and carry the matched Linear ID/URL into the result summary. If the rewrite plan requires a description-only update for a skipped existing issue, apply only the markdown reference rewrite; if the update cannot be performed, report the remaining required local reference and withhold the removal prompt.
   - After each successful issue create, immediately append or update this section in the source SIW issue file:

     ```markdown
     ## Linear Transfer

     - Linear issue: {identifier} {url}
     - Linear project: {project URL}
     - Transferred: {YYYY-MM-DD}
     ```

   - Maintain an in-memory transfer ledger with one row per source issue: source item, SIW ID, title, Linear ID/URL, and status `CREATED`, `CREATED_NO_MARKER`, `SKIPPED_EXISTING`, or `PENDING`.

7. Post-create issue reference rewrite pass: after all issues exist, use the transfer ledger to update planned issue descriptions, milestone ordering text, and migrated Document bodies that contain SIW issue IDs. Rewrite known IDs to Linear identifiers while preserving the original SIW ID; leave IDs outside the ledger verbatim and report them as unresolved. For `skip-existing` records, perform this update only when the Phase 4 plan included it as an explicit rewrite-only update.
8. Relation pass (only when the plan includes one): after all issues exist, resolve each planned `Blocked by:` / `Blocks:` edge from SIW IDs to Linear IDs via the transfer ledger and write the native relations. Relation parameters are append-only, so re-running the pass is safe. Report any edges left unresolved.
9. If the plan deferred milestone ordering text until after issue creation, update those milestone descriptions now per `references/linear-mapping.md` > Milestone Mapping, using the Linear identifiers from the transfer ledger and preserving the markdown reference rewrites.
10. Capture each Linear project, document, milestone, and issue identifier and URL for the result summary.

For each write, use only the current migration plan. Do not widen scope to unrelated Linear projects or issues discovered during execution.

If a Linear call hits a rate limit signal (`RATELIMITED`, HTTP 429, or exposed `X-RateLimit-*` exhaustion), do not retry in a tight loop. Back off until the reported reset time when available, otherwise use bounded exponential backoff with jitter, then resume from the transfer ledger and source markers. If repeated rate limits continue, reduce page sizes or batch size and report the remaining pending actions.

## Phase 7: Verify and Prompt Removal

1. Verify the migration: every planned write returned a Linear identifier and URL, the document reference map has URLs for every migrated document, every planned rewrite-only update was applied or reported as unresolved, the final duplicate-content preflight passed with zero unresolved groups, the transfer ledger contains no `PENDING` or `CREATED_NO_MARKER` rows, each created issue's source file carries its `Linear Transfer` marker, every planned relation edge was written, and no Linear-bound project description, milestone description, issue body, or Document body in the rewrite plan still requires local SIW markdown paths to understand or implement the work. For rewritten issues and Documents, read back with retry/backoff because Linear can return stale content immediately after a write; if expected counts mismatch, re-save the planned body once and read again before marking the item unresolved.
2. Verify rewrite fidelity using deterministic facts, not visual/manual inspection: expected Linear identifier counts, expected Document URL counts, preserved SIW ID counts, no superseded inline metadata line, no migrated source paths remaining in required implementation content outside provenance/metadata blocks, `## SIW Metadata` present on issues, and unchanged markdown table cell counts. When spot-checking migrated Document content, compare normalized content, not bytes — Linear normalizes markdown on save (bullet style, table dashes, bold spans, auto-linked bare domains, and URL angle brackets), so a content-identical document is a pass even when it is not byte-identical.
3. Report:
   - Linear project URL.
   - Counts of created/updated milestones, documents, and issues, plus any skipped or unresolved items.
   - Counts of rewritten markdown references and every unresolved local markdown reference that remains as source provenance only.
4. Removal prompt:
   - If the migration completed cleanly (no errored writes, no unresolved in-scope issues, no unresolved required local markdown references, and the design docs are captured as Documents or via the description fallback) and the SIW directory contains no unrelocated non-markdown artifacts, prompt: `Migration complete and verified. Run /kramme:siw:remove to retire the local siw/ directory.`
   - If anything errored, was skipped due to failure, any supporting spec or selected contract spec could not be captured in Linear, any required markdown reference still points only to a local SIW path, or any non-markdown artifact has not been relocated or uploaded, **do not** prompt removal. Name exactly what is still local-only so the user does not delete uncaptured work.

End the workflow here. Do not delete files and do not start implementation. A relevant follow-up for a newly created Linear issue is `/kramme:linear:issue-implement {issue-id}`.

## Error Handling

- **Missing SIW artifacts**: stop and name the missing directory or file.
- **Linear MCP unavailable**: stop unless `--dry-run` is set.
- **No team can be resolved**: ask once; if still unresolved, stop.
- **Document creation unavailable**: fall back to embedding spec content in the project description, warn that supporting specs, selected contract specs, and other document sources could not become standalone Documents, and withhold the removal prompt.
- **Milestone write failure**: stop before writing dependent issues unless the user explicitly chooses to continue without milestone assignment; withhold the removal prompt.
- **Marker write-back failure**: if appending the `## Linear Transfer` section to a source file fails after a successful Linear issue create, set that ledger row to `CREATED_NO_MARKER`, continue with the remaining issues, include the row in the retry ledger, and withhold the removal prompt.
- **OAuth token expiry mid-run**: long migrations can outlive the Linear OAuth token. If a write fails with an authorization error partway through, ask the user to re-authorize, then resume — markers already written keep completed issues skip-safe.
- **Rate limit mid-run**: if Linear reports `RATELIMITED`, HTTP 429, or exhausted rate-limit headers, pause with backoff as described in Phase 6 and resume from the retry-safe ledger. Do not duplicate project, milestone, document, or issue writes while waiting.
- **Relation write failure**: issues and their text dependencies are already complete, so do not roll anything back. Report the unwritten edges and note that re-running the relation pass is safe (relation parameters are append-only).
- **Duplicate-content match before issue creation**: stop before creating any issue in the affected batch. Report each duplicate group with source issue IDs, planned titles, matching Linear issue identifiers/URLs when present, and the matching fingerprint reason. Ask the user whether to merge local issues, map a source issue to an existing Linear issue as `skip-existing`, skip one of the local issues, or explicitly proceed with separate issues. Do not continue until the migration plan reflects the chosen resolution.
- **Issue write failure**: stop after reporting the failed action, withhold the removal prompt, and print a machine-usable retry ledger in this exact fenced shape:

  ```text
  LINEAR_TRANSFER_RETRY
  Command: /kramme:siw:transfer-to-linear {siw-dir} --project {project} --team {team} --retry

  | Source item | Title | Linear ID | Status |
  | --- | --- | --- | --- |
  | {issue-file} | {title} | {LIN-123 or PENDING} | {CREATED|CREATED_NO_MARKER|SKIPPED_EXISTING|PENDING} |
  ```

  The retry path follows the duplicate-detection rules in `references/linear-mapping.md`. Rows that the rules mark `needs decision` may be disambiguated by this retry ledger or another user-provided source-item mapping.
