# Team-Based Review Resolution

Resolve review findings in parallel using multi-agent execution. Each agent owns a non-overlapping set of files and implements fixes independently.

This reference is loaded by `/kramme:pr:resolve-review --team`; assume `--team` has already been removed from `$ARGUMENTS`.

Parse `$ARGUMENTS` for `--auto` before Step 1.

- If present, set `AUTO_MODE=true` and remove the flag from the remaining input.
- `--auto` means the lead skips the plan confirmation in Step 4, proceeds directly with the parallel plan whenever the grouping shows real parallelism, and posts/resolves addressed external review comments after the fixes land.

## Prerequisites

This skill requires multi-agent execution.

- **Claude Code:** Agent Teams must be enabled (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`).
- **Codex:** run in a Codex runtime with `multi_agent` enabled.

If multi-agent execution is not available, print:

```
Multi-agent execution is not enabled. Run /kramme:pr:resolve-review instead.
Claude Code: add CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 to settings.json.
Codex: use a runtime with `multi_agent` enabled (for example, Conductor Codex runtime).
```

Then stop.

## Workflow

### Step 1: Find and Parse Review (Lead)

Same as `/kramme:pr:resolve-review` Steps 0-1:

1. Check for arguments, including source flags, severity filters, granular commits, review content, instructions, or URL
2. Check for `REVIEW_OVERVIEW.md`, `UX_REVIEW_OVERVIEW.md`, and `PRODUCT_REVIEW_OVERVIEW.md`
3. Check chat context
4. Fetch from current branch's PR if nothing else found
5. List all findings

### Step 2: Evaluate Findings (Lead)

Same as `/kramme:pr:resolve-review` Step 2:

1. **Scope check** -- Classify each finding as in-scope, out-of-scope, or gray area
2. **Validity assessment** -- For external reviews, assess whether you agree
3. **Severity prioritization** -- critical > important > suggestion

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

If `AUTO_MODE=true`, skip this prompt and proceed with **Resolve in parallel**.

Otherwise ask the user to confirm the parallel plan with three options:

- **Resolve in parallel** — Spawn Z agents to fix non-overlapping groups simultaneously.
- **Resolve sequentially** — Fix all findings in a single session (lower token cost). Delegate to `/kramme:pr:resolve-review`.
- **Cancel** — Don't resolve any findings.

Frame the question as: "Found X in-scope findings across Y file groups. How should I proceed?"

### Step 5: Spawn Resolver Agents

Create a multi-agent resolution session named `resolve-review`.

- **Claude Code:** create an Agent Team.
- **Codex:** launch equivalent parallel resolver agents via multi-agent mode.

Spawn one agent per group (max 3 agents). Each receives:

- Their assigned findings with full context
- **Exclusive file ownership list**: "You have exclusive write access to: [files]. Do NOT modify files outside this list. If you need to change a file outside your list, message the lead."
- The resolution guidelines from `/kramme:pr:resolve-review`

For each agent, create a task: "Resolve X findings in [file area]"

### Step 6: Handle Sequential Findings

If any findings were identified as overlapping multiple groups in Step 3:

- Wait for parallel resolution to complete
- Assign these findings to an agent that already owns one of the overlapping files, OR resolve them directly as the lead

### Step 7: Monitor and Coordinate

While agents work:

- Monitor each agent's progress
- If an agent discovers it needs a file outside its ownership set:
  - Check if the other owner is done with that file
  - If yes: grant access
  - If no: queue the modification for after the other agent finishes
- Relay any questions about PR scope or business logic

### Step 8: Verify and Summarize

After all agents complete:

1. Run `kramme:verify:run` to check for integration issues
2. If verification fails, identify which agent's changes caused the issue and either:
   - Ask the responsible agent to fix it (resume its session)
   - Fix it directly as the lead

3. Apply the same reply behavior as `/kramme:pr:resolve-review` Step 4:
   - `REVIEW_SOURCE=local`, or neither `AUTO_MODE` nor `ANSWER_AND_RESOLVE` is set: do not post replies or resolve threads on GitHub.
   - `AUTO_MODE=true` or `ANSWER_AND_RESOLVE=true` on an external review: print the summary line (`Posting N replies and resolving M threads on PR #X`), then post a reply for each addressed comment and resolve those threads. For disagreements or out-of-scope findings, post a rationale reply but do not resolve the thread.

4. Write resolutions to the appropriate file (if the source was `UX_REVIEW_OVERVIEW.md` or `PRODUCT_REVIEW_OVERVIEW.md`, update that file in place; otherwise write to `REVIEW_OVERVIEW.md`), using the same format as `/kramme:pr:resolve-review` Step 4 and Output format (in-place updates, never delete entries), with an additional note about parallel resolution:

```markdown
## Resolution Summary

Resolved X findings in parallel across Y agents.

### Resolver Teams

- Resolver 1: Fixed X findings in [file area]
- Resolver 2: Fixed X findings in [file area]
- Sequential: Fixed X overlapping findings after parallel phase

[... standard REVIEW_OVERVIEW.md format ...]
```

### Step 9: Cleanup

1. Shut down all resolver agents
2. Clean up the multi-agent session

## File Conflict Prevention

This skill uses **exclusive file ownership** to prevent conflicts:

- The lead pre-assigns files to each agent before spawning
- No two agents can write to the same file
- If an agent needs a file it doesn't own, it messages the lead
- Findings that span multiple file groups are resolved sequentially after the parallel phase

## Usage

```
/kramme:pr:resolve-review --team
# Resolve findings from REVIEW_OVERVIEW.md in parallel

/kramme:pr:resolve-review --team focus on critical issues only
# Resolve with additional instructions
```

## When to Use This vs `/kramme:pr:resolve-review`

Use **this mode** when:

- 5+ findings across different file areas
- Findings are spread across distinct modules/directories
- You want faster resolution through parallelism

Use **standard `/kramme:pr:resolve-review`** when:

- Few findings or all in the same files
- Findings are interdependent
- You want lower token cost
