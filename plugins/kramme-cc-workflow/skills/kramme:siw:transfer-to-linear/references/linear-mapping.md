# Linear Mapping Rules

Read this file from `Phase 3: Resolve Linear Context` (when matching existing records) and `Phase 4: Build Migration Plan` in `SKILL.md`.

This is a one-way migration. No machine-readable rerun marker is added to Linear records and no standalone rerun mapping is persisted (the human-readable `SIW ID` line in each issue's metadata block exists for readers, not for matching). Per-issue transfer markers support interrupted issue retries; project documents and milestones are matched by name/title whenever the target project already exists, to avoid duplicate planning artifacts.

## Duplicate Detection and Retry Matching

These rules are the single source of truth for matching planned records against existing Linear records. Other sections and `SKILL.md` reference them rather than restating them.

**Normalized match**: two titles or names match when they are equal exactly, or after normalizing case, spaces, and punctuation. Exactly one match → reuse the existing record (`skip-existing` for documents and issues, `update`/`reuse` for milestones). Multiple matches → `needs decision`. No match → `create`.

**Documents** (every run, when the target project already exists): match each planned document against existing project documents by normalized title. Also treat the ` ({filename})` suffix as optional during matching, so documents created before the filename-suffix convention still match.

**Milestones** (every run, when the project already exists): match each planned milestone against existing project milestones by normalized name.

**Issues**:

- A source issue with a populated `## Linear Transfer` marker is always `skip-existing`, on every run, using the recorded identifier/URL — no title query needed.
- Title fallback applies only when `--skip-existing` or `--retry` is set, and only to unmarked source issues whose normalized planned Linear title is unique among unmarked source issues. If multiple unmarked source issues share a normalized title, mark each `needs decision` even when exactly one Linear issue carries that title — otherwise a retry can collapse distinct SIW issues onto one Linear record. For a unique source title, apply the normalized-match rule against existing Linear issues, treating a trailing decision citation like `(D-052)` / `(OD-003)` as optional on either side — planned titles strip citations, but issues created by earlier runs may still carry them.

**Duplicate content preflight**:

Run this check for issue actions on every migration, before any Linear issue is created. It is a safety gate, not an idempotent sync mechanism.

1. Render each planned create issue body exactly as it would be sent to Linear after Markdown Reference Rewrite and after the `SIW Metadata` block is appended.
2. Build a substantive content fingerprint from that rendered body:
   - Drop generated identity/provenance sections and lines: `## SIW Metadata`, `## Linear Transfer`, `SIW ID`, `Source path`, transfer dates, and Linear issue/project URLs.
   - Preserve the issue's problem, context, scope, decision boundaries, acceptance criteria, validation, edge cases, technical notes, resolution, and dependency prose.
   - Normalize line endings, trailing spaces, repeated blank lines, list marker style, checkbox spacing, and repeated spaces outside fenced code. Keep fenced code content exact except for line endings and trailing spaces.
   - Treat an empty or placeholder-only fingerprint as non-actionable; the Skip Rules handle empty placeholder issues.
3. Compare fingerprints among all planned create issues. If two or more source issues share the same non-empty fingerprint, mark every issue in that group `needs decision` and remove those rows from the create count until the user resolves the duplication.
4. Compare each planned create fingerprint against readable existing Linear issue bodies in the resolved team/project. Existing bodies are fingerprinted with the same rules. If one or more existing Linear issues match, mark the source issue `needs decision`; do not silently `skip-existing` on content alone, because an exact body match does not prove the source issue was intentionally transferred.
5. Report duplicate groups in the migration plan with source issue IDs, planned titles, matching Linear issue identifiers/URLs when available, and whether the match was in-batch or against existing Linear content. If existing Linear issue bodies could not be read, report `existing Linear body check unavailable`; do not claim the content preflight fully passed.
6. Allowed resolutions are: merge or remove one of the local duplicate issues before re-running, map a source issue to an existing Linear issue as `skip-existing`, skip one source issue with a reason, or explicitly proceed with separate Linear issues. After any resolution, rebuild the plan and run the preflight again before creating issues.

## Project Mapping

Create or update one Linear project for the SIW project. A project requires at least one team.

**Name:**

- Use `--project` when supplied.
- Otherwise use the main spec title.

**Description:**

Keep the project description short. The full spec, supporting specs, selected contract specs, and decision log are migrated as Linear Documents (see Document Mapping), so the description only needs an orienting summary plus a notation legend. Migrated bodies are full of SIW notation that resolves to nothing inside Linear — the legend is what makes the project understandable to a Linear-only reader.

Write the Summary and Value sections for non-technical stakeholders: plain language, no SIW or implementation jargon, no file paths or ID notation. A manager or customer-facing colleague landing on the project page should understand what problem is being solved, why, and what the value is without opening any Document. Pull this from the spec's problem statement, goals, and success criteria — summarize outcomes, not architecture:

```markdown
## Summary

{1–3 sentences in plain language: what problem this project solves, for whom, and why it matters now}

## Value

{1–3 bullets: the concrete outcome when this ships — what users, the business, or the team gain}

## How to read this project

- `D-0xx` / `OD-0xx` citations refer to entries in the attached "{decision log document title}" Document.
- `{main-spec-filename} > Section` pointers refer to the attached "{main spec document title}" Document.
- `Pn-NNN` IDs are the original SIW issue IDs; every issue carries its own ID in its `SIW Metadata` block, so they resolve via project search.
- Mode `AUTO` means an agent can implement the issue autonomously; `HITL` means human-in-the-loop checkpoints are required.
- Source provenance paths under `siw/` identify migrated local artifacts only; they are not implementation references.

## SIW Context

- Migrated from local SIW markdown artifacts in `{siw-dir}`.
- Main spec, supporting specs, selected contract specs, and decision log are attached as Linear Documents.
```

Include only legend lines whose notation actually appears in the migrated content.

**State:**

Set project state only via a workspace-specific status ID (`statusId` is a UUID, not a literal like `"planned"`). Look up the matching project status when one is obvious; otherwise omit state rather than guessing.

## Document Mapping

Migrate planning documents so design and rationale survive after the local `siw/` directory is retired.

Create one Linear Document under the project for:

- The main spec.
- Each `supporting-specs/*.md` file.
- Each `contracts/*.md` file selected for migration, especially any contract markdown linked from an issue, spec, supporting spec, or other migrated document.
- Each non-selected main-spec candidate (a file that lost the main-spec tiebreak is still a source-of-truth document, not disposable).
- `LOG.md`. In a mature SIW project the log is the canonical decision register — issue bodies cite it heavily (`D-0xx`), and excluding it would orphan every citation once `siw/` is removed.

**Title:** the document's first `#` heading, falling back to the filename without extension, with the original filename appended in parentheses — e.g. `ChallengeCraft Decision Log (LOG.md)`. Stale path references in migrated bodies (like `siw/LOG.md`) then still ring a bell.

**Initial body:** create the Document with the file's markdown content preserved semantically. The rewrite passes below may update the body after Document URLs and issue identifiers are known. Linear normalizes markdown on save (bullet style, table dashes, bold spans, auto-linked bare domains), so verify round-trips by normalized content, not bytes.

If the Linear MCP cannot create Documents, fall back to embedding the main spec summary in the project description and record which supporting specs, selected contract specs, and other document sources could not be captured. In that case the migration is not "clean", so removal of `siw/` must not be prompted (see SKILL.md Phase 7).

Existing-document reuse follows Duplicate Detection and Retry Matching above.

## Markdown Reference Rewrite

Linear-bound content must not leave local SIW markdown paths as required implementation references after migration. Rewrite the content that will be written to Linear after the document reference map has URLs, then run a second issue-reference rewrite after Linear issue identifiers exist.

Build all rewrites from an allowlist of entities this migration created or explicitly reused:

- SIW issue ID -> Linear issue identifier and URL.
- Source document path and filename -> Linear Document title and URL.
- Register-code family -> owning Linear Document URL when the owning document was migrated.

Leave everything outside that allowlist verbatim except when reporting it as an unresolved required local reference. Do not linkify `README.md`, `AGENTS.md`, evidence paths under `siw/evidence/`, prototype `.html` files, Figma URLs, historical `POT-*` issues, or any path/code whose target was not created or reused by this transfer.

**Document reference map:**

Build and maintain one map entry per migrated document source:

- Source path relative to `siw-dir`, normalized as a POSIX path.
- Filename.
- First heading/title, falling back to filename without extension.
- Planned Linear Document title from Document Mapping.
- Planned action, plus a separate rewrite-only update action when an existing Document needs body rewrites.
- Created or reused Linear Document URL.

Include the main spec, every `supporting-specs/*.md`, every selected `contracts/*.md`, every non-selected main-spec candidate, and `LOG.md`. Existing documents matched by title fill the URL during planning. Newly created documents fill it during execution. If a map entry has no URL after the document phase, references to it are unresolved local-only references.

**Content to rewrite:**

- Issue descriptions before issue creation.
- Issue descriptions again after issue creation when they contain SIW issue IDs that can now resolve to Linear issue identifiers.
- Project description if generated or copied content references files.
- Milestone descriptions if generated or copied content references files.
- Migrated Document bodies when they link to other migrated SIW markdown files.
- Migrated Document bodies again after issue creation when they contain SIW issue IDs that should resolve to Linear issue identifiers.
- Current Linear issue or Document bodies before any rewrite-only update to a reused or `skip-existing` record.

Apply the same rewrite to reused or `skip-existing` Linear records only when the relevant read and update tools exist, and include that work as an explicit rewrite-only update in the migration plan before approval. For rewrite-only updates, fetch the current Linear body first and rewrite only matching SIW-local markdown references in that current body; never regenerate the body from the source SIW markdown or resync unrelated body edits, statuses, assignees, labels, or other Linear-owned fields. If the current body cannot be fetched, do not perform the rewrite-only update; report the remaining local reference and withhold the removal prompt when it is required implementation content.

**Reference detection:**

Detect Markdown links, plain inline paths, SIW issue IDs, and register-code families:

- Markdown links such as `[Effective scope model](../supporting-specs/01-configuration-data-api.md#effective-scope-model)`.
- Plain paths in prose or code spans such as `../contracts/05-ufa-query-and-rendering.md`, `siw/supporting-specs/02-api.md#endpoints`, `./LOG.md`, or `LOG.md#decision-log`.
- SIW issue IDs such as `P4-001` or `G-003`, including ranges like `P3-002..P3-007`.
- Register-code families such as `D-NNN`, `OD-NNN`, `VER-*`, and `Q-NN`.

Resolve relative targets from the file that contains the reference. Strip URL query strings, preserve the `#fragment` separately, normalize `.` / `..`, and match the path portion against the document reference map. Treat `siw/` prefixes as relative to `siw-dir`.

**Rewrite format:**

Do not depend on Linear section anchors. Linear Document URLs are stable; heading anchors are not guaranteed. When a reference includes a section fragment, link to the Document URL and keep the section name in visible text. Use filenames as visible labels for document links; SIW plans often use numbered filenames as their compact vocabulary, and full document titles bloat dense issue bodies and table cells.

- Markdown link to a migrated document section:
  - Input: `[details](../supporting-specs/01-configuration-data-api.md#effective-scope-model)`
  - Output: `[01-configuration-data-api.md > Effective Scope Model]({linear_document_url})`
- Plain path to a migrated document section:
  - Input: `../supporting-specs/01-configuration-data-api.md#effective-scope-model`
  - Output: `Linear Document: [01-configuration-data-api.md > Effective Scope Model]({linear_document_url})`
- Markdown link to a migrated document without a section:
  - Output visible text: the filename.
- Plain path to a migrated document without a section:
  - Input: `../contracts/05-ufa-query-and-rendering.md`
  - Output: `Linear Document: [05-ufa-query-and-rendering.md]({linear_document_url})`

Convert fragments to title case by replacing hyphens and underscores with spaces, unless the target document contains a heading whose normalized anchor matches the fragment; then use the exact heading text.

**Issue-to-issue references:**

- Rewrite a bare SIW issue reference such as `P4-001` to `{LINEAR-ID} (P4-001)`, for example `DEV-123 (P4-001)`.
- Preserve the legacy SIW ID because specs, issue files, and project vocabulary continue to use it.
- Rewrite only standalone issue references in prose or dependency fields.
- Do not rewrite IDs embedded in filenames, paths, URLs, markdown link destinations, inline code, fenced code, or source provenance lines such as `- Source path: siw/issues/ISSUE-P4-001.md`.
- Do not rewrite the issue's own canonical `- SIW ID: {id}` metadata line; that line remains the stable legacy identifier for search and audit.
- Prefer bare Linear identifiers over markdown links in prose because Linear renders them as issue chips. Use the URL only when a context cannot safely carry the bare identifier.
- Expand and rewrite issue ranges only when every member exists in the ledger. If any member is absent, leave the original range text and report the unresolved target.

**Register-code references:**

- Do not turn every `D-NNN`, `OD-NNN`, `VER-*`, or `Q-NN` occurrence into a link. Linear has no reliable constructible row-level anchors for migrated table rows, and repeated links make dense plans noisy.
- Keep the codes as searchable text. Add one compact pointer per relevant family in the issue or document body, such as `Register references: [LOG.md](...), [verification-matrix.md](...)`.
- Add the pointer near the SIW metadata block for issues, and near the top of migrated Documents when the document contains register-code families that resolve elsewhere.

For each body to rewrite, compute expected facts before saving: Linear identifier count, Document URL count, preserved SIW ID count, migrated source-path count after rewrite outside provenance/metadata blocks, register pointer count, and table cell counts. Phase 7 uses these facts to verify the saved Linear body after Linear's markdown normalization.

**Source provenance:**

Local source paths may remain only as provenance, never as the primary instruction path. Put source paths in metadata or context blocks such as `SIW Metadata` / `SIW Context`, not in Problem, Scope, Acceptance Criteria, Technical Notes, milestone implementation guidance, or project "how to work this" prose. Do not use phrases like "read `siw/supporting-specs/...`" in Linear-bound implementation content after rewrite.

**Unresolved references:**

If a markdown reference points outside the migrated document set, or points to a migrated source with no Linear Document URL, do not invent a target. Move or retain the local path only in source provenance metadata, not as an implementation instruction, and report it in the migration plan as an unresolved local markdown reference with:

- Referencing Linear-bound item (issue, project, milestone, or document).
- Source artifact containing the reference.
- Referenced local path and section fragment.
- Reason it could not be rewritten.
- Whether it appears in required implementation content or provenance-only content.

When an unresolved reference appears in required implementation content, the migration is not clean. Do not prompt for `siw/` removal while unresolved required local markdown references remain. If the unresolved reference targets an existing SIW markdown file that should be needed after migration, add it to the document source set and rerun planning instead of leaving it local-only.

## Milestone Mapping

Create or update Linear project milestones from SIW phase candidates.

**Name:**

- Use `Phase N: {title}` for numbered SIW phases.
- Use the explicit SIW milestone heading for non-phase milestones.
- Strip trailing decision citations like `(D-052)` from the name; the citation stays in the description where the project legend explains it.
- Keep names stable so name-based matching works on a reused project.

**Description:**

Write a short, succinct synthesis of the work the milestone contains: what this phase delivers, what state the project is in when it is done, and any validation gate it must pass. Use the phase goal, outcome, validation notes, and relevant success criteria as source material.

Do not restate or enumerate the milestone's issues — Linear already lists them under the milestone, so a description that mirrors the issue list adds nothing. Issue-level details belong in the Linear issues.

Never copy section `Parallelization:` lines or other ordering guidance verbatim — they carry raw SIW IDs (`P2-005→{P2-006, P2-007}`) that resolve to nothing in Linear. Include ordering guidance only when it changes how the milestone should be worked (a hard gate or a critical path), rewritten using issue titles, or updated after issue creation to use Linear identifiers (`{TEAM}-N` mentions auto-link in milestone descriptions).

**Target date:**

Set `targetDate` only when a concrete date exists in the SIW artifacts. Do not invent target dates from phase ordering.

**Duplicate detection:**

Existing-milestone matching follows Duplicate Detection and Retry Matching above (normalized name; one match → update/reuse, multiple → `needs decision`, none → create).

**Skip rules:**

Skip milestone creation when:

- The candidate has no issues and no meaningful description.
- The candidate is a General bucket or only contains `G-*` issues.

## Issue Title and Description

Use the SIW issue title directly as the Linear issue title, minus any trailing decision citation like `(D-052)` — the citation stays in the body, where the project legend explains it. Do not add a `[SIW:id]` prefix — SIW identity moves to the metadata block, not the title.

**Retry duplicate detection:**

Marker-based skips and the `--skip-existing` / `--retry` title fallback follow the issue rules in Duplicate Detection and Retry Matching above.

**Content duplicate safety gate:**

Before creating Linear issues, run the duplicate-content preflight above against the final rewritten issue descriptions. A content match blocks issue creation as `needs decision` until resolved, even when titles differ.

Preserve the SIW issue content in the description in this order when present:

1. Problem
2. Context
3. Scope
4. Decision Boundaries
5. Acceptance Criteria
6. Validation
7. Edge Cases
8. Technical Notes
9. Resolution

Before assembling the Linear description, remove the source issue's inline metadata line when it is superseded by the generated `## SIW Metadata` block. This includes lines containing fields such as `**Status:**`, `**Priority:**`, `**Size:**`, `**Mode:**`, and `**Related:**`.

When preserving a `Validation` section, drop only generic generated CI checklist items that duplicate normal CI or agent verification, such as "build green", "tests green", or generic `nx affected` checks. Keep manual verification, migration checks, evidence requirements, sign-off steps, gate checks, and domain-specific validation.

Append a compact metadata block. `SIW ID` is mandatory: migrated bodies keep textual cross-references like "Blocked by: P3-004", and the stamp is the only thing that makes them resolvable via project search after `siw/` is gone.

```markdown
## SIW Metadata

- SIW ID: {id}
- Source path: {source issue path}
- Status: {SIW status}
- Priority: {priority}
- Size: {size}
- Phase: {phase}
- Milestone: {milestone}
- Parallelization: {parallelization}
- Mode: {mode}
- Related: {related}
```

Assign each phase issue to the mapped Linear milestone for its SIW phase when a milestone exists. Create `G-*` issues without a milestone and preserve `Phase: General` plus an empty `Milestone` value in the metadata block.

## Status Mapping

Use the team's issue statuses and match by state `type` (`backlog`, `unstarted`, `started`, `completed`, `canceled`) or closest exact name. Compare SIW status values case-insensitively — legacy issue-file metadata may use `Ready` while the tracker/legend uses `READY`; treat them as the same value.

| SIW status | Preferred Linear state type |
| --- | --- |
| READY | `backlog` or `unstarted` |
| IN PROGRESS | `started` |
| IN REVIEW | `started` (a review state if the team has one) |
| DONE | `completed` |

If no confident state match exists, omit the state field and leave the SIW status in the metadata block.

## Priority Mapping

SIW issues use only `High`, `Medium`, and `Low` (or an empty value). Map to Linear's numeric priority:

| SIW priority | Linear priority |
| --- | --- |
| High | 2 |
| Medium, empty | 3 |
| Low | 4 |

SIW has no "Urgent" value, so nothing maps to Linear priority 1. Leave priority 0 (No priority) only when the SIW priority is genuinely absent and 3 would misrepresent it.

## Label Mapping

Use existing Linear labels only. Good candidates when they already exist:

- `SIW`
- `AUTO`
- `HITL`
- Size labels such as `XS`, `S`, `M`, `L`
- Phase labels such as `P1`, `P2`

Do not create labels automatically. If useful labels are missing, mention them in the plan and let the user decide whether to create them separately.

## Dependencies

Always record SIW dependencies as text:

- Keep the `Related: {ids}` line in the SIW metadata block. After the post-create issue reference rewrite pass, known SIW IDs should appear as `{LINEAR-ID} ({SIW-ID})`; unknown IDs stay as the original SIW ID. Do not rewrite the canonical `SIW ID` field for the issue itself.
- When an SIW issue states it depends on, blocks, or relates to another issue, reflect that in the issue body text using the same rewrite rule for known IDs.

**Native relations** (when Phase 1 capability discovery found relation parameters such as `blockedBy` / `blocks` / `relatedTo` on the issue write tool):

Plan a two-phase issue migration. Create all issues first, collecting the SIW-ID-to-Linear-ID map from the transfer ledger, then run a relation pass driven by each issue file's `Blocked by:` / `Blocks:` lines:

- Expand ranges like `P3-002..P3-007` into individual edges.
- Write each `Blocked by:` edge as `blockedBy` on the downstream issue (or as an inverted `blocks`, depending on which parameters the tool exposes). Deduplicate edges that appear on both sides.
- Relation parameters are append-only — re-running the pass cannot remove or corrupt existing relations, so it is retry-safe.
- Report edges that reference SIW IDs absent from the ledger (for example, dependencies on issues excluded by `--skip-done`) instead of failing.

When no relation parameters exist, text is the only record. For reference, relations can be added later via raw GraphQL (`issueRelationCreate`, requiring a separate Linear API key); that enum is `blocks` / `related` / `similar` / `duplicate` — there is no `blockedBy` (invert a `blocks` relation) and no `relatedTo` (use `related`).

## Markdown Fidelity

Linear normalizes markdown on save. The transfer should preserve meaning and structure rather than bytes.

- Preserve escaped table pipes (`\|`) during extraction, rewriting, and verification. Treat an unescaped `|` as a cell separator and an escaped `\|` as literal cell content.
- Before rewriting a table row, record its expected cell count. After rewriting, verify the count did not change. If a markdown link label or URL would contain `|`, do not place that link inside the table cell; use a table-safe filename label, a bare Linear URL, or leave the original text.
- Do not put markdown links inside inline code. Unwrap inline-code paths only when they resolve to migrated Documents or uploaded attachments.
- Accept harmless Linear save rewrites during verification, including wrapped URL destinations like `<https://...>`, normalized bullet markers, table divider normalization, auto-linked bare domains, and bold-span normalization.
- Prefer substring and count checks for expected Linear identifiers, Document URLs, section markers, and removed source paths. Do not rely on manual character counting or byte-for-byte round trips.

## Skip Rules

Plan `skip` instead of create when:

- The issue is `DONE` and `--skip-done` was passed.
- The issue has no body beyond an empty placeholder.

Always show skipped issues in the plan with the reason.
