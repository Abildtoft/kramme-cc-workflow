# Linear Mapping Rules

Read this file from `Phase 3: Resolve Linear Context` (when matching existing records) and `Phase 4: Build Migration Plan` in `SKILL.md`.

This is a one-way migration. No SIW marker is added to Linear records and no standalone rerun mapping is persisted. Per-issue transfer markers support interrupted issue retries; project documents and milestones are matched by name/title whenever the target project already exists, to avoid duplicate planning artifacts.

## Duplicate Detection and Retry Matching

These rules are the single source of truth for matching planned records against existing Linear records. Other sections and `SKILL.md` reference them rather than restating them.

**Normalized match**: two titles or names match when they are equal exactly, or after normalizing case, spaces, and punctuation. Exactly one match → reuse the existing record (`skip-existing` for documents and issues, `update`/`reuse` for milestones). Multiple matches → `needs decision`. No match → `create`.

**Documents** (every run, when the target project already exists): match each planned document against existing project documents by normalized title.

**Milestones** (every run, when the project already exists): match each planned milestone against existing project milestones by normalized name.

**Issues**:

- A source issue with a populated `## Linear Transfer` marker is always `skip-existing`, on every run, using the recorded identifier/URL — no title query needed.
- Title fallback applies only when `--skip-existing` or `--retry` is set, and only to unmarked source issues whose normalized planned Linear title is unique among unmarked source issues. If multiple unmarked source issues share a normalized title, mark each `needs decision` even when exactly one Linear issue carries that title — otherwise a retry can collapse distinct SIW issues onto one Linear record. For a unique source title, apply the normalized-match rule against existing Linear issues.

## Project Mapping

Create or update one Linear project for the SIW project. A project requires at least one team.

**Name:**

- Use `--project` when supplied.
- Otherwise use the main spec title.

**Description:**

Keep the project description short. The full spec and supporting specs are migrated as Linear Documents (see Document Mapping), so the description only needs an orienting summary:

```markdown
## Summary

{overview/problem summary, 1–3 sentences}

## SIW Context

- Migrated from local SIW markdown artifacts in `{siw-dir}`.
- Main spec and supporting specs are attached as Linear Documents.
```

**State:**

Set project state only via a workspace-specific status ID (`statusId` is a UUID, not a literal like `"planned"`). Look up the matching project status when one is obvious; otherwise omit state rather than guessing.

## Document Mapping

Migrate planning documents so design and rationale survive after the local `siw/` directory is retired.

Create one Linear Document under the project for:

- The main spec.
- Each `supporting-specs/*.md` file.

**Title:** the document's first `#` heading, falling back to the filename without extension.

**Body:** the file's markdown content, preserved as-is.

If the Linear MCP cannot create Documents, fall back to embedding the main spec summary in the project description and record which supporting specs could not be captured. In that case the migration is not "clean", so removal of `siw/` must not be prompted (see SKILL.md Phase 7).

Existing-document reuse follows Duplicate Detection and Retry Matching above.

## Milestone Mapping

Create or update Linear project milestones from SIW phase candidates.

**Name:**

- Use `Phase N: {title}` for numbered SIW phases.
- Use the explicit SIW milestone heading for non-phase milestones.
- Keep names stable so name-based matching works on a reused project.

**Description:**

Use the phase goal, outcome, validation notes, and relevant success criteria when available. Keep descriptions concise; issue-level details belong in the Linear issues.

**Target date:**

Set `targetDate` only when a concrete date exists in the SIW artifacts. Do not invent target dates from phase ordering.

**Duplicate detection:**

Existing-milestone matching follows Duplicate Detection and Retry Matching above (normalized name; one match → update/reuse, multiple → `needs decision`, none → create).

**Skip rules:**

Skip milestone creation when:

- The candidate has no issues and no meaningful description.
- The candidate is a General bucket or only contains `G-*` issues.

## Issue Title and Description

Use the SIW issue title directly as the Linear issue title. Do not add a `[SIW:id]` prefix — SIW identity is intentionally abandoned after migration.

**Retry duplicate detection:**

Marker-based skips and the `--skip-existing` / `--retry` title fallback follow the issue rules in Duplicate Detection and Retry Matching above.

Preserve the SIW issue content in the description in this order when present:

1. Problem
2. Context
3. Scope
4. Decision Boundaries
5. Acceptance Criteria
6. Edge Cases
7. Technical Notes
8. Resolution

Append a compact metadata block:

```markdown
## SIW Metadata

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

The Linear MCP server exposes no issue-relation tool, so this migration does not create live Linear relations. Record SIW dependencies as text only:

- Keep the `Related: {ids}` line in the SIW metadata block.
- When an SIW issue states it depends on, blocks, or relates to another issue, reflect that in the issue body text.

For reference, if relations are ever added later via raw GraphQL (`issueRelationCreate`, requiring a separate Linear API key), the relation enum is `blocks` / `related` / `similar` / `duplicate` — there is no `blockedBy` (invert a `blocks` relation) and no `relatedTo` (use `related`).

## Skip Rules

Plan `skip` instead of create when:

- The issue is `DONE` and `--skip-done` was passed.
- The issue has no body beyond an empty placeholder.

Always show skipped issues in the plan with the reason.
