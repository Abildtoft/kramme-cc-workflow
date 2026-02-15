---
name: kramme:pr:resolve-review:team
description: Resolve review findings in parallel using Agent Teams. Groups findings by file area and assigns to separate teammates for faster resolution. Best when review has 5+ findings across different areas.
disable-model-invocation: true
user-invocable: true
kramme-platforms: [claude-code]
---

# Team-Based Review Resolution

Resolve review findings in parallel using Agent Teams. Each teammate owns a non-overlapping set of files and implements fixes independently.

## Prerequisites

This skill requires Agent Teams to be enabled (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`). If teams are not available, print:

```
Agent Teams are not enabled. Run /kramme:pr:resolve-review instead, or enable teams:
  Add CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 to settings.json
```

Then stop.

## Workflow

### Step 1: Find and Parse Review (Lead)

Same as `/kramme:pr:resolve-review` Steps 0-1:

1. Check for arguments (review content, instructions, or URL)
2. Check for `REVIEW_OVERVIEW.md`
3. Check chat context
4. Fetch from current branch's PR if nothing else found
5. List all findings

### Step 2: Evaluate Findings (Lead)

Same as `/kramme:pr:resolve-review` Step 2:

1. **Scope check** -- Classify each finding as in-scope, out-of-scope, or gray area
2. **Validity assessment** -- For external reviews, assess whether you agree
3. **Severity prioritization** -- High > Medium > Low

### Step 3: Group Findings by File Area

Group in-scope findings so that no two groups touch the same files:

1. Extract file paths from all findings
2. Build a file-to-findings map
3. Group findings that share files into the same group
4. Ensure no file appears in more than one group

**Example grouping:**
```
Group A (auth/): 3 findings touching auth/login.ts, auth/session.ts
Group B (api/): 2 findings touching api/users.ts, api/handlers.ts
Group C (tests/): 2 findings touching tests/auth.test.ts, tests/api.test.ts
Sequential: 1 finding touching auth/login.ts AND api/users.ts (overlaps groups A and B)
```

If all findings touch the same files, there's no parallelism benefit. Print:

```
All findings touch overlapping files. Running /kramme:pr:resolve-review instead.
```

Then delegate to the standard skill.

### Step 4: Present Plan

Use AskUserQuestion to confirm the parallel plan:

```yaml
header: "Parallel Review Resolution"
question: "Found X in-scope findings across Y file groups. How should I proceed?"
options:
  - label: "Resolve in parallel"
    description: "Spawn Z teammates to fix non-overlapping groups simultaneously"
  - label: "Resolve sequentially"
    description: "Fix all findings in a single session (lower token cost)"
  - label: "Cancel"
    description: "Don't resolve any findings"
```

If "Resolve sequentially" is selected, delegate to `/kramme:pr:resolve-review`.

### Step 5: Spawn Resolver Team

Create a team named `resolve-review`.

Spawn one teammate per group (max 3 teammates). Each receives:
- Their assigned findings with full context
- **Exclusive file ownership list**: "You have exclusive write access to: [files]. Do NOT modify files outside this list. If you need to change a file outside your list, message the lead."
- The resolution guidelines from `/kramme:pr:resolve-review`

For each teammate, create a task: "Resolve X findings in [file area]"

### Step 6: Handle Sequential Findings

If any findings were identified as overlapping multiple groups in Step 3:
- Wait for parallel resolution to complete
- Assign these findings to a teammate that already owns one of the overlapping files, OR resolve them directly as the lead

### Step 7: Monitor and Coordinate

While teammates work:
- Monitor progress via TaskList
- If a teammate discovers it needs a file outside its ownership set:
  - Check if the other owner is done with that file
  - If yes: grant access
  - If no: queue the modification for after the other teammate finishes
- Relay any questions about PR scope or business logic

### Step 8: Verify and Summarize

After all teammates complete:

1. Run `kramme:verify:run` to check for integration issues
2. If verification fails, identify which teammate's changes caused the issue and either:
   - Ask the teammate to fix it (resume their session)
   - Fix it directly as the lead

3. Write `REVIEW_OVERVIEW.md` using the same format as `/kramme:pr:resolve-review` Step 4, with an additional note about parallel resolution:

```markdown
## Resolution Summary

Resolved X findings in parallel across Y teammates.

### Resolver Teams
- Resolver 1: Fixed X findings in [file area]
- Resolver 2: Fixed X findings in [file area]
- Sequential: Fixed X overlapping findings after parallel phase

[... standard REVIEW_OVERVIEW.md format ...]
```

### Step 9: Cleanup

1. Shut down all teammates
2. Clean up the team

## File Conflict Prevention

This skill uses **exclusive file ownership** to prevent conflicts:
- The lead pre-assigns files to each teammate before spawning
- No two teammates can write to the same file
- If a teammate needs a file it doesn't own, it messages the lead
- Findings that span multiple file groups are resolved sequentially after the parallel phase

## Usage

```
/kramme:pr:resolve-review:team
# Resolve findings from REVIEW_OVERVIEW.md in parallel

/kramme:pr:resolve-review:team focus on critical issues only
# Resolve with additional instructions
```

## When to Use This vs `/kramme:pr:resolve-review`

Use **this skill** when:
- 5+ findings across different file areas
- Findings are spread across distinct modules/directories
- You want faster resolution through parallelism

Use **`/kramme:pr:resolve-review`** when:
- Few findings or all in the same files
- Findings are interdependent
- You want lower token cost
