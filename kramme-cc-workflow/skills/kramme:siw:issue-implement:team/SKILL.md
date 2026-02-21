---
name: kramme:siw:issue-implement:team
description: Implement multiple SIW issues in parallel using multi-agent execution. Each agent gets a full context window and implements one issue. Best for phases with multiple independent issues.
argument-hint: "[issue-ids or 'phase N']"
disable-model-invocation: true
user-invocable: true
kramme-platforms: [claude-code, codex]
---

# Parallel SIW Implementation

Implement multiple SIW issues simultaneously using multi-agent execution. Each agent implements one issue with a full context window, following the `kramme:siw:issue-implement` workflow.

**Arguments:** "$ARGUMENTS"

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

1. Read `siw/OPEN_ISSUES_OVERVIEW.md` to understand all issues and their statuses
2. Read the main spec file (from `siw/` directory) for project context
3. Read `siw/LOG.md` for current progress and decisions

### Step 2: Identify Parallelizable Issues

**If specific issue IDs provided** (e.g., `G-001 P1-002`):
- Validate each issue exists and is in READY status
- Warn if any have unresolved blockers

**If "phase N" provided** (e.g., `phase 1`):
- Select all READY issues with prefix matching that phase (`P1-*` for phase 1)

**If no arguments:**
- Select all READY issues across all phases that have no unresolved blockers

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

Use AskUserQuestion:

```yaml
header: "Parallel Implementation Plan"
question: "Ready to implement X issues. Here's the plan:"
options:
  - label: "Start parallel implementation"
    description: |
      Batch 1 (parallel): [issue-ids] - X teammates
      Batch 2 (after batch 1): [issue-ids] - Y teammates
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

For each issue in Batch 1, spawn a teammate with:

1. **Issue content**: Full text of the issue file
2. **Spec context**: Relevant sections of the main spec and any supporting specs
3. **File ownership**: "You have exclusive write access to: [files]. Do NOT modify files outside this list without messaging the lead first."
4. **Workflow**: "Follow the `kramme:siw:issue-implement` workflow using the Autonomous Implementation approach:
   - Explore codebase for patterns
   - Create technical plan
   - Implement iteratively
   - Run `kramme:verify:run`
   - Document resolution in the issue file's `## Resolution` section (summary, changes, key decisions)
   - Set issue status to IN REVIEW or DONE based on confidence
   - Update `siw/OPEN_ISSUES_OVERVIEW.md`
   - Message the lead when complete"
5. **Plan approval**: Require plan approval before implementation begins. The lead reviews each teammate's technical plan and approves or rejects with feedback.

Create one task per issue: "Implement [issue-id]: [title]"

### Step 6: Monitor Progress

While teammates work:

1. **Review plans**: When a teammate submits their implementation plan, review it for:
   - Alignment with spec and issue requirements
   - No file conflicts with other teammates' plans
   - Appropriate patterns and conventions
   - Approve or reject with specific feedback

2. **Track completion**: Monitor TaskList for completed tasks

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

1. Update `siw/LOG.md` with Batch 1 completions
2. Check if Batch 2 issues are now unblocked (both SIW dependency and file ownership)
3. Assign Batch 2 issues to idle teammates or spawn new ones
4. Repeat monitoring until all batches complete

### Step 8: Final Verification

After all issues are implemented:

1. Run `kramme:verify:run` on the full scope to check for integration issues
2. If verification fails:
   - Identify which teammate's changes caused the failure
   - Either resume that teammate to fix, or fix directly
3. Update `siw/LOG.md` with session summary:

```markdown
## Current Progress

**Last Updated:** {date}
**Quick Summary:** Parallel implementation of X issues

### Project Status
- **Status:** In Progress | **Completed this session:** {issue-ids}

### Last Completed
- {issue-id}: {title} (Batch 1)
- {issue-id}: {title} (Batch 1)
- {issue-id}: {title} (Batch 2)

### Decisions Made
- [Any cross-cutting decisions discovered during parallel implementation]

### Next Steps
1. {next ready issue or phase}
```

4. Check for phase completion (same as `kramme:siw:issue-implement` Step 11.2)

### Step 9: Spec Sync

Review all decisions logged by teammates. If any need spec updates, follow `kramme:siw:issue-implement` Step 10 (Sync Decisions to Spec).

### Step 10: Cleanup

1. Shut down all implementation agents
2. Clean up the multi-agent session

## File Conflict Prevention

This skill uses a multi-layer approach:

1. **Pre-analysis**: Before spawning, the lead reads each issue's affected areas and builds a file ownership map
2. **Exclusive ownership**: Each agent gets an explicit list of files it can write to
3. **Batching**: Issues with file overlaps go into sequential batches
4. **Plan approval**: Lead reviews each teammate's plan to catch file conflicts early
5. **Runtime messaging**: Agents message the lead if they discover they need files outside their set
6. **Post-verification**: `kramme:verify:run` catches any integration issues after all implementations

## Usage

```
/kramme:siw:issue-implement:team
# Implement all READY issues with no blockers

/kramme:siw:issue-implement:team phase 1
# Implement all READY Phase 1 issues

/kramme:siw:issue-implement:team P1-001 P1-003 G-002
# Implement specific issues in parallel
```

## When to Use This vs `/kramme:siw:issue-implement`

Use **this skill** when:
- Multiple READY issues exist with no blocking dependencies
- Issues touch different files/modules
- You want to speed up a phase by parallelizing independent work

Use **`/kramme:siw:issue-implement`** when:
- Implementing a single issue
- Issues are tightly coupled and need sequential implementation
- You want lower token cost
