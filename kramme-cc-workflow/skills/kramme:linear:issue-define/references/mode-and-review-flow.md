# Mode and Review Flow

Use this reference for detailed Phase 3 mode handling and Phase 7 review/create mechanics in `kramme:linear:issue-define`.

## Phase 3: Existing Issue Handling

This phase differs based on mode.

### Improve Mode

The target issue was already fetched in Phase 1. Now present it to the user:

1. **Present Current Issue**
   - Show the issue title, description, labels, and metadata.
   - Format clearly for review.
   - If this is a Dev Ask issue with a "Dev Ask" label, tell the user: "This issue was created through Linear Asks. The original request will be preserved in an 'Original Dev Ask' section at the bottom of the refined issue."

2. **Resume from prior session triage**

   The fetched issue body may contain AI-authored content from a prior session of this skill, such as an `## Original Dev Ask` block or a prior `## Problem` / `## Value` / `## Scope` set.

   Before launching the interview:
   - Scan the description for the canonical comprehensive-template section headings.
   - For each section already populated with substantive prior-session content, not placeholder text or one-line stubs, record which interview round it covered:
     - `## Problem` / `## Value` -> Round 1 (Problem & Value)
     - `## Scope` / `## Out of Scope` -> Round 2 (Scope & Boundaries)
     - `## Technical Notes` / `## Affected Areas` -> Round 3 (Technical Context)
     - `## Acceptance Criteria` / `## Edge Cases` -> Round 4 (Acceptance Criteria)
     - existing `labels` / `priority` / `project` -> Round 5 (Metadata)
   - Store the parsed sections as `prior_session_context`, keyed by round.

   In Phase 5, the interview must:
   - Skip rounds whose corresponding section is already populated with substantive prior-session content, unless the user selected that area as an improvement target in Step 3 below.
   - When skipping, show the user a one-line summary like `Round 2 (Scope & Boundaries): carrying forward from prior session - say "revisit" to re-open` so the user can re-open any round on demand.
   - Do not re-ask resolved questions. Treat ambiguity in prior content as a reason to surface that section for refinement, not as a reason to start the round from scratch.

3. **Identify Improvement Areas**
   - Ask what aspects to improve with the structured question tool, multi-select:
     - Problem statement clarity
     - Value proposition
     - Scope definition
     - Acceptance criteria
     - Technical context
     - Metadata (labels, priority, etc.)
     - All of the above (full refinement)
   - Store selected areas for focused interview in Phase 5.
   - Selected areas always take precedence over prior-session skips. If the user says "improve scope", run Round 2 even when prior content exists.

4. **Search for Related Issues**
   - Use `list_issues` with `query` keywords from the existing issue, scoped to its team.
   - Identify issues to link as related or blockers. Store new ones in `relations` for Phase 7; relations the issue already has are skipped, never re-sent or removed.

**Output:** Improvement areas selected, related issues identified, prior-session context recorded.

### Create Mode

Before creating a new issue, check for existing Linear issues that may already cover this topic:

1. **Search for Duplicates**
   - Use `list_issues` with `query` containing keywords from the description, scoped to the team resolved in Phase 2. Widen to other teams only when the user says the work may live elsewhere.
   - Also check `.out-of-scope/` in the project root: list filenames; read any whose slug plausibly matches the description; surface matches alongside Linear duplicate findings in the same structured question in step 3. Use option labels: "proceed with new issue" and "this matches a prior rejection - stop". Skip silently if the directory is absent. See `/kramme:docs:track-rejected-enhancements` for the storage skill.

2. **Identify Related Issues**
   - Look for issues that partially overlap with the proposed scope (`relatedTo`).
   - Find issues that must land first (`blockedBy`) or that wait on this work (`blocks`).
   - Record each as `relations` with its direction for Phase 7. The user confirms the list in Round 5 before anything is written.

3. **Present Findings to User**
   - If `auto_create = true` and a strong duplicate is found, show the issue and ask whether to stop, create anyway, or rerun without `--auto` to improve the existing issue. If the user wants to improve, stop; do not switch into improve mode during the same invocation. When `breakdown_handoff = true`, first verify the duplicate belongs to the handoff's exact workspace/team/project scope. If the user then chooses it, return `Action: covered-existing` with concrete identifiers, the recorded decision reason, and dependency-text verification using the structured result contract in `references/auto-create.md`.
   - If `auto_create = false` and potential duplicates are found, show them to the user with the structured question tool:
     - Option to proceed with new issue if it is not truly a duplicate.
     - Option to improve an existing issue instead -> switch to improve mode.
     - Option to link as related issue (added to `relations` as `relatedTo`).
     - Option to file this as a duplicate anyway, for example to record a narrower reproduction — then store the existing issue as `duplicate_of` so Phase 7 sets `duplicateOf`.
   - If related issues are found, note them for both `relations` and the Dependencies section.

4. **Decision Point**
   - If user confirms this is a duplicate, stop and direct to the existing issue.
   - If `auto_create = false` and user wants to improve an existing issue, fetch that issue with `get_issue`, switch to improve mode, and restart from Phase 3.
   - If `auto_create = true` and user confirms a new issue is needed, continue to auto create mode below.
   - If `auto_create = false` and user confirms a new issue is needed, continue to Phase 4.
   - Store any related issues for later linking.

**Output:** List of related issues to reference, confirmation to proceed.

### Auto Create Mode

If `auto_create = true` and mode is create:

1. Complete Phase 2 team resolution and Phase 3 duplicate handling first.
2. If duplicate handling confirms a new issue is needed, return `auto_create_confirmed = true` to the main Phase 3 flow.
3. If duplicate handling stops or defers, follow that recorded user decision instead.
4. Do not continue into Phase 4 from this reference; the main `SKILL.md` Phase 3 handoff runs the auto-create workflow. It stops a direct invocation or returns the structured result to a breakdown caller.

## Phase 7: Review & Create/Update

### 1. Present Draft

**Improve mode:**

- Show the updated issue with change indicators.
- Highlight what changed vs. original content.
- Show before/after for significant modifications.

**Create mode:**

- Show the complete issue: title, description, and metadata.
- Format clearly for review.

### 2. Approve or Refine

- Ask with the structured question tool: approve as drafted, refine first, or cancel without writing.
- On refine, collect the changes in plain chat, apply them, re-present the draft, and ask again.
- On cancel, print the full draft so nothing is lost, then stop.

### 3. Create or Update Issue

Both modes use `save_issue` (Claude Code `mcp__linear__save_issue`; Codex `save_issue`). Relation fields (`relatedTo`, `blockedBy`, `blocks`) are append-only; `labels` replaces the full set, so always send the complete intended label list.

**Create mode** — call `save_issue` without `id`:

- `title`, `description` (full markdown body), `team`.
- `labels`, `project`, `priority`, `cycle`, `assignee` when selected in Round 5.
- `relatedTo`, `blockedBy`, `blocks` from `relations`; `parentId` when the user named a parent; `duplicateOf` when `duplicate_of` is set.

**Improve mode** — call `save_issue` with `id`:

- Prefer `patch` over `description` when the interview changed only some sections and the existing body still contains the canonical section headings. Build one `patch` array in document order: `replace` for a rewritten section (anchor on the existing section text), `insert_after` the preceding heading's content for a new section, `append` for the Original Dev Ask block when it must be added. Every anchor must match exactly once; if it cannot, fall back to sending the full `description`. Patching keeps comments-in-body, images, and edits the user made in Linear since the fetch.
- Send the full `description` when the body has no recognisable section headings, the user chose "All of the above", or the structure is being replaced wholesale. Include the Original Dev Ask section at the bottom when `is_dev_ask` is true.
- `title` only if changed. `labels` only if changed (the complete new set). `priority`, `project`, `cycle`, `assignee` only if changed.
- `relatedTo`, `blockedBy`, `blocks` for new relations only.

**If the create or update call fails:**

- Output the full drafted issue markdown, including title, description, relations, and intended metadata, so the interview work is not lost.
- Report the error Linear returned.
- Offer to retry. Do not silently abandon the draft or proceed to the next step.

### 4. Return Result

**Improve mode:**

- Provide the updated issue URL.
- Summarize what was changed.

**Create mode:**

- Provide the created issue URL.
- Confirm successful creation.

### 5. Workflow Complete - Stop

The `linear:issue-define` workflow is complete once the issue URL is returned.

- Do not proceed to code implementation.
- Do not start working on the issue.
- Do not invoke other commands automatically.

**Next steps for the user:**

- Review the created/updated issue in Linear.
- If ready to implement, invoke `/kramme:linear:issue-implement {issue-id}`.
- If changes are needed, run `/kramme:linear:issue-define {issue-id}` again to refine.

Stop here and wait for the user's next instruction.
