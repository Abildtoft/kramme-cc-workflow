# Parallel SIW Implementation

Implement multiple SIW issues simultaneously using multi-agent execution. Each agent implements one issue with a full context window, following the `kramme:siw:issue-implement` workflow.

This reference is loaded by `/kramme:siw:issue-implement --team`; assume `--team` has already been removed from `$ARGUMENTS`.

**Arguments:** "$ARGUMENTS"

Parse `$ARGUMENTS` for `--auto` before Step 1.

- If present, set `AUTO_MODE=true` and remove the flag from the remaining input.
- `--auto` means: skip the plan confirmation in Step 4 and start the proposed parallel implementation plan immediately.

## Prerequisites

This skill requires multi-agent execution.

- **Claude Code:** Agent Teams must be enabled (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`).
- **Codex:** run in a Codex runtime with `multi_agent` enabled.

If multi-agent execution is not available, print:

```
Multi-agent execution is not enabled. Use /kramme:siw:issue-implement to implement issues one at a time.
Claude Code: add CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 to settings.json.
Codex: use a runtime with `multi_agent` enabled (for example, Conductor Codex runtime).
```

Then stop.

## Workflow

### Step 1: Read SIW State

1. Read `siw/OPEN_ISSUES_OVERVIEW.md` to understand all issues and their statuses.
2. Read the main spec file for project context. The main spec is the project-named uppercase markdown file at the top of `siw/` (for example `siw/FEATURE_SPECIFICATION.md`, `siw/API_DESIGN.md`, `siw/PROJECT_PLAN.md`) — the filename is chosen at `kramme:siw:init` time. Synced SIW spec-exclusion contract (keep aligned across SIW spec detectors): `LOG.md`, `OPEN_ISSUES_OVERVIEW.md`, `DISCOVERY_BRIEF.md`, `SPEC_STRENGTHENING_PLAN.md`, `AUDIT_*.md`, `PRODUCT_AUDIT.md`, `SIW_*.md`.

   Synced SIW main-spec ambiguity contract (keep aligned across SIW spec detectors): when multiple spec candidates remain after deterministic heading/filename matching, auto mode stops with MISSING REQUIREMENT and interactive mode asks the user which file is the main spec.

   If multiple candidates remain after filtering, build a deterministic match set from candidates whose filename or first `#` heading matches the project title in `siw/LOG.md` (case-insensitive, hyphen/underscore-insensitive). If exactly one candidate matches, use it. If zero or multiple candidates remain after matching and `AUTO_MODE=true`, stop with `MISSING REQUIREMENT: multiple spec candidates found; rerun without --auto to choose the main spec before starting team mode`. If zero or multiple candidates remain after matching and `AUTO_MODE` is false, ask the user which file is the main spec before continuing.

3. Read `siw/LOG.md` for current progress and decisions.
4. Capture each issue's `Mode` from the overview table when present, then confirm it from the issue file status line when reading candidates. Treat missing Mode as `HITL — mode missing; requires human triage`.

### Step 2: Identify Parallelizable Issues

**If specific issue IDs provided** (e.g., `G-001 P1-002`):

- Validate each issue exists and is in READY status
- Warn if any have unresolved blockers
- If any requested issue is `HITL`, keep it out of the automatic batch until the user explicitly confirms that the required human decision/review/access has already been handled. `--auto` does not count as that confirmation.

**If "phase N" provided** (e.g., `phase 1`):

- Select all READY issues with prefix matching that phase (`P1-*` for phase 1)
- Exclude HITL issues from the proposed automatic batch and list them separately as human-gated work.

**If no arguments:**

- Select all READY AUTO issues across all phases that have no unresolved blockers
- Exclude HITL issues from the proposed automatic batch and list them separately as human-gated work.

**HITL guardrail:**

- Do not spawn implementation agents for HITL issues by default.
- If all candidate issues are HITL, stop and ask the user to resolve the human requirement first or run `/kramme:siw:issue-implement` for a single issue with the needed context.
- If `AUTO_MODE=true`, skip HITL issues automatically and report them as not started; if skipping leaves no AUTO candidates, stop without spawning agents.
- If interactive mode includes HITL candidates, Step 4 must present them separately with their one-line reasons and require explicit user confirmation before any HITL issue enters a batch.

### Step 3: Analyze File Ownership

For each candidate issue:

1. Read the issue file from `siw/issues/`
2. Extract "Affected Areas", "Files to Modify", or "Scope" sections
3. Build a file-to-issue map

**Identify conflicts:**

- Issues that touch overlapping files cannot run in parallel
- Group non-overlapping issues into parallelizable batches

**Batching strategy:**

- **Batch 1**: Maximum set of issues with no file overlaps
- **Batch 2**: Issues that were blocked by Batch 1 file conflicts, OR issues whose SIW blockers are resolved by Batch 1 completions
- Continue until all issues are batched

### Step 4: Present Plan

If `AUTO_MODE=true`, skip this AskUserQuestion and proceed with **Start parallel implementation**.

Otherwise use AskUserQuestion:

```yaml
header: "Parallel Implementation Plan"
question: "Ready to implement X issues. Here's the plan:"
options:
  - label: "Start parallel implementation"
    description: |
      Batch 1 (parallel): [issue-ids] - X teammates
      Batch 2 (after batch 1): [issue-ids] - Y teammates
      Human-gated HITL issues not started: [issue-ids with reasons]
      Potential conflicts: [details if any]
  - label: "Adjust plan"
    description: "Let me modify which issues to include"
  - label: "Cancel"
    description: "Don't implement anything"
```

### Step 5: Spawn Implementation Agents

Create a multi-agent implementation session named `siw-implement`.

- **Claude Code:** create an Agent Team.
- **Codex:** launch equivalent parallel implementation agents via multi-agent mode.

Immediately before assigning any issue to a teammate — whether spawning a new teammate or reusing an idle one — the lead must claim that issue by publishing its `IN PROGRESS` transition **serially, one issue at a time**:

1. Re-read the issue file, `siw/OPEN_ISSUES_OVERVIEW.md`, and `siw/LOG.md`.
2. Update the issue file status, overview row, and current log to `IN PROGRESS` as one issue-state change. In the log's `### Project Status`, maintain an `**Issue States:**` field that lists every issue assigned in this team session and its tracker-visible status (for example, `P1-001 — IN PROGRESS; P1-002 — IN PROGRESS`). Update only the claimed issue's entry; preserve claims, completions, decisions, and other accurate progress already published for this batch.
3. Re-read all three files and verify that the issue is `IN PROGRESS` everywhere. Do not assign the issue to its teammate until the status agrees across all three files.

For each issue in Batch 1, spawn a teammate with:

**Precondition:** Every issue in the batch is `AUTO`, or the user explicitly confirmed inclusion of that specific HITL issue after seeing its reason in Step 4.

1. **Issue content**: Full text of the issue file
2. **Spec context**: Relevant sections of the main spec and any supporting specs
3. **File ownership**: "You have exclusive write access to: [implementation files]. Do NOT modify files outside this list without messaging the lead first. The issue file, `siw/OPEN_ISSUES_OVERVIEW.md`, and `siw/LOG.md` are tracking state owned exclusively by the lead; treat all three as read-only."
4. **Workflow**: "Follow the `kramme:siw:issue-implement` workflow using the Autonomous Implementation approach:
   - Explore codebase for patterns
   - Create technical plan
   - Implement iteratively
   - Run `kramme:verify:run`
   - Prepare the complete content for the issue file's `## Resolution` section (summary, changes, key decisions), but do not write it
   - Recommend IN REVIEW or DONE based on confidence, but do not change the issue status
   - The lead already published the IN PROGRESS transition; do not rerun the standard workflow's IN PROGRESS Status Update Procedure
   - Do not run the standard workflow's Sync Decisions to Spec step; report every decision in the completion handoff so the lead can serialize spec synchronization before publishing the final status
   - Do not update the issue file, `siw/OPEN_ISSUES_OVERVIEW.md`, or `siw/LOG.md`; the lead serializes all three tracking-file updates
   - Return a completion handoff to the lead with every field in this exact schema:
     - `Issue ID`: canonical SIW ID
     - `Issue file`: path to the lead-owned issue file
     - `Final status`: recommended IN REVIEW or DONE
     - `Resolution`: complete Markdown content for the issue file's `## Resolution` section
     - `Log event`: one-line meaningful completion event for `Last Completed`
     - `Decisions`: decisions requiring spec or log synchronization, or `None`
     - `Verification`: commands run and their outcomes
   - Message the lead when complete; the work is not published until the lead accepts the handoff"
5. **Plan approval**: Require plan approval before implementation begins. The lead reviews each teammate's technical plan and approves or rejects with feedback.

Create one task per issue: "Implement [issue-id]: [title]"

### Step 6: Monitor Progress

While teammates work:

1. **Review plans**: When a teammate submits their implementation plan, review it for:
   - Alignment with spec and issue requirements
   - No file conflicts with other teammates' plans
   - Appropriate patterns and conventions
   - Approve or reject with specific feedback

2. **Track completion**: Monitor TaskList for completed tasks. A completed task must include every completion-handoff field from Step 5. If a field is absent, is invalid for the assigned issue, or contradicts the verification results, reject the handoff and resume the teammate to correct it; do not infer missing tracking-state content.

3. **Handle file conflicts**: If a teammate discovers it needs a file outside its ownership:
   - Check if the owning teammate is done with that file
   - If yes: grant access
   - If no: queue the request, or suggest the teammate implement a different approach that stays within its files

4. **Handle blockers**: If a teammate gets stuck:
   - Provide additional context about the codebase
   - Suggest alternative approaches
   - In worst case, reassign the issue to a different teammate

### Step 7: Proceed to Next Batch

When all Batch 1 tasks complete:

1. Collect and validate every completion handoff. Do not publish an incomplete handoff.
2. Review the `Decisions` in every accepted handoff before publishing any final status. If a decision needs a spec update, follow `kramme:siw:issue-implement` Step 10 (Sync Decisions to Spec) now, using the handoff as the decision source. Do not publish an affected issue as `DONE` until its required spec synchronization completes or the user explicitly chooses to skip that update.
3. As the sole shared-state writer, publish accepted handoffs **serially, one at a time**. For each handoff:
   1. Immediately before writing, re-read the issue file, `siw/OPEN_ISSUES_OVERVIEW.md`, and `siw/LOG.md`; never publish from the shared-state snapshot captured at session or batch start.
   2. Confirm the handoff belongs to the assigned issue and that the issue is still `IN PROGRESS` across all three tracking files. Resolve any stale or unexpected state before publishing it.
   3. Write the handoff's `Resolution` and `Final status` to the issue file, update that issue's overview row, update only that issue's `Issue States` entry in the log, and merge its `Log event` and `Decisions` into the current log as one issue-state change without discarding entries published for earlier handoffs. The lead is the only agent permitted to write any of the three tracking files.
   4. Re-read all three files and verify the issue status agrees across them and that the log retains every completion and decision published so far. Stop and repair the stale view before accepting or publishing another handoff.
4. After all Batch 1 handoffs are published, update the remaining Batch 1 summary fields in `siw/LOG.md` without replacing the per-issue events just verified.
5. Check if Batch 2 issues are now unblocked (both SIW dependency and file ownership).
6. For each Batch 2 issue, run the Step 5 claim procedure, then assign it to an idle teammate or spawn a new one. Never reuse an idle teammate before that issue is `IN PROGRESS` across all three tracking files.
7. Repeat monitoring, pre-publication spec synchronization, and serialized publication until all batches complete.

### Step 8: Final Verification

After all issues are implemented:

1. Run `kramme:verify:run` on the full scope to check for integration issues
2. If verification fails:
   - Identify which teammate's changes caused the failure
   - Either resume that teammate to fix, or fix directly
3. Merge the session summary into the current `siw/LOG.md` progress block. Preserve the exact `Log event` and non-`None` `Decisions` entries from every accepted handoff; do not rebuild those sections from issue titles or restrict them to cross-cutting decisions:

```markdown
## Current Progress

**Last Updated:** {date} **Quick Summary:** Parallel implementation of X issues

### Project Status

- **Status:** IN PROGRESS | **Issue States:** {issue-id — final status; ...} | **Completed this session:** {issue-ids}

### Last Completed

- {accepted Log event for issue in Batch 1}
- {accepted Log event for issue in Batch 1}
- {accepted Log event for issue in Batch 2}

### Decisions Made

- {every non-None decision from accepted handoffs, plus any session-level decision}

### Next Steps

1. {next ready issue or phase}
```

4. Check for phase completion (same as `kramme:siw:issue-implement` Step 11.2)

### Step 9: Spec Sync

Confirm that every decision reported in teammate completion handoffs was handled by the pre-publication spec-sync gate in Step 7. If final verification introduced a new decision, follow `kramme:siw:issue-implement` Step 10 (Sync Decisions to Spec) before cleanup and repair any affected issue status rather than leaving it `DONE` with stale specifications.

### Step 10: Cleanup

1. Shut down all implementation agents
2. Clean up the multi-agent session

## File Conflict Prevention

This skill uses a multi-layer approach:

1. **Pre-analysis**: Before spawning, the lead reads each issue's affected areas and builds a file ownership map
2. **Exclusive ownership**: Each agent gets an explicit list of implementation files it can write to; all three SIW tracking files are always lead-owned and excluded
3. **Batching**: Issues with file overlaps go into sequential batches
4. **Plan approval**: Lead reviews each teammate's plan to catch file conflicts early
5. **Runtime messaging**: Agents message the lead if they discover they need files outside their set
6. **Single-writer publication**: The lead validates handoffs, re-reads current shared state, and publishes one completion at a time
7. **Post-verification**: `kramme:verify:run` catches any integration issues after all implementations

## Usage

```
/kramme:siw:issue-implement --team
# Implement all READY issues with no blockers

/kramme:siw:issue-implement --team phase 1
# Implement all READY Phase 1 issues

/kramme:siw:issue-implement --team P1-001 P1-003 G-002
# Implement specific issues in parallel
```

## When to Use This vs `/kramme:siw:issue-implement`

Use **this mode** when:

- Multiple READY issues exist with no blocking dependencies
- Issues touch different files/modules
- You want to speed up a phase by parallelizing independent work

Use **standard `/kramme:siw:issue-implement`** when:

- Implementing a single issue
- Issues are tightly coupled and need sequential implementation
- You want lower token cost
