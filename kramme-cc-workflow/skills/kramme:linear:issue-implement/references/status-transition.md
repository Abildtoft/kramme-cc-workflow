# Authorized Linear Status Transition

Follow this reference only when `SET_IN_PROGRESS=true`. It is the only Linear write this skill performs. Complete it during Step 1.4, before Step 2 branch setup and before any other repository or planning action, so a failed transition never leaves a created branch or partial implementation behind.

## 1. Establish the authorization source

`--set-in-progress` is explicit authorization to move `{ISSUE_ID}` to its team's resolved `started` workflow status. It authorizes exactly that status change: never edit the title, description, labels, assignee, project, estimate, or any other mutable field, and never transition a different issue.

Classify the invocation by the presence of a parent-owned status handoff, never by `AUTO_MODE`. A direct `--auto --set-in-progress` run is still a direct invocation.

**Direct invocation** (no parent handoff, with or without `--auto`): this skill owns the confirmation in section 4.

**Delegated invocation** (`kramme:linear:issue-to-pr` passing `--auto --set-in-progress` with its handoff): require the complete parent-owned status handoff before continuing:

- `{issue-update-id}` — the stable ID the host's update operation accepts.
- The team identifier and `{issue-branch}` captured by the parent preflight.
- `{confirmed-state-id}` and `{confirmed-state-type}` shown at the parent's confirmation gate.
- `{target-status-id}` and `{target-status-name}` resolved by the parent.

Reject direct, incomplete, mismatched, or duplicate use of the handoff. If any element is missing or contradicts the issue fetched in Step 1, stop without writing to Linear and report the exact mismatch; this handoff is not a way to transition an issue the parent never gated.

In direct invocation, prove the worktree can still reach branch setup before writing, because a delegating parent's clean-tree preflight does not stand behind this run. Inspect `git status --porcelain`; when it reports any path, complete the dirty-worktree handling in `references/branch-setup.md` first, which stops with its `MISSING REQUIREMENT` message under `AUTO_MODE=true` and otherwise asks the user to stash, commit, discard, or abort. Only continue to the write once that handling leaves a worktree Step 2 can act on, so a moved issue is never left without its branch.

## 2. Resolve the current state, immutable ID first

Resolve `{confirmed-state-name}`, `{confirmed-state-id}`, and `{confirmed-state-type}` from the Step 1 issue response metadata. If the response lacks the ID or type, call the Linear MCP `list_issue_statuses` operation for the issue's team and match the current state by immutable ID; only when no ID is available may an exact case-insensitive name match be used, and it must be unique. Stop if the current state or its ID or type remains missing or ambiguous.

The only state type that bypasses the section 4 confirmation is exactly `backlog`. Do not treat `unstarted` as backlog, even when its display name is Todo or Ready.

In delegated mode, require the resolved values to equal the handoff's `{confirmed-state-id}` and `{confirmed-state-type}`. A changed state means the parent's authorization no longer applies: stop and report both states rather than re-asking, because this child does not own that authorization.

## 3. Resolve the target `started` status

Call `list_issue_statuses` for the issue's team when section 2 did not already need it. Among statuses whose type is `started`, prefer the case-insensitive exact name `In Progress`; otherwise continue only when there is exactly one status whose type is `started`. Capture its name as `{target-status-name}` and its immutable ID as `{target-status-id}`. If there is no unique target, stop and report the candidate status names instead of guessing.

In delegated mode, require the resolved `{target-status-id}` to equal the handoff value.

## 4. Confirm a non-backlog transition

In delegated mode, skip this section: the parent already held this confirmation and section 1 validated its handoff. Never ask a second time for the same transition.

In direct mode, if `{confirmed-state-type}` is anything other than `backlog`, ask one explicit confirmation that includes the issue identifier, current state name and type, target status name, and this exact question: `Proceed with implementation and move the issue to {target-status-name}?` This gate also applies when the issue is already `started`, `completed`, or `canceled`. Without an explicit confirmation, stop without changing Linear or the branch.

`AUTO_MODE=true` does not remove this confirmation. A direct `--auto --set-in-progress` invocation still asks, because no parent gate stands behind it.

## 5. Close the confirmation race, then write

Immediately before the Linear write, close the confirmation race:

- Re-fetch `{ISSUE_ID}`, resolve its current state with the same immutable-ID-first procedure from section 2, and require the same `{issue-update-id}`, team identifier, `branchName`, state ID, and state type shown at the gate or supplied by the handoff.
- If any compared value changed, stop without writing; never apply a confirmation to a newer issue state. In direct mode, restart this reference from section 2. In delegated mode, stop and report the change as a transition failure: the parent treats a delegated failure as a workflow failure, so the user re-runs the parent, whose fresh read-only preflight and state gate then re-resolve the issue.
- If the freshly verified issue is already in `{target-status-id}`, treat the transition as satisfied and do not issue a redundant write.
- Otherwise use the available Linear issue-update operation (`save_issue` with `id`; Claude Code `mcp__linear__save_issue`) to update only its status: pass `id: {issue-update-id}` and `state: {target-status-id}` and no other mutable field. Do not resend or rewrite title, description, labels, assignee, project, or other fields.

## 6. Verify the written state

After a successful write, read the issue back, resolve its status with the same immutable-ID-first procedure from section 2, and require the resolved status ID to equal `{target-status-id}` and its type to be `started`.

If the write or verification fails, stop before branch setup and report both `{confirmed-state-name}` and `{target-status-name}`, the update error or read-back mismatch, and whether Linear may have accepted an unverified write. Do not retry the write against an unverified state, and do not continue to branch setup, planning, or implementation on a failed transition.

## 7. Record the outcome

Capture `{transition-outcome}` for Step 8's success output and for the delegating parent's report:

- `{confirmed-state-name} -> {target-status-name} (verified before implementation)` after a verified write.
- `already {target-status-name} (no write needed)` when section 5 found the issue already in the target status.

Step 1.4 binds `{transition-outcome}` for the skipped `SET_IN_PROGRESS=false` path, where this reference is never read.
