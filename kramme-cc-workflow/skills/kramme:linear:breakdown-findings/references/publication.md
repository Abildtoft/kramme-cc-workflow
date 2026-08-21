# Issue-definition delegation and batch publication

Use this reference during Phases 4, 6, and 7.

## Prepare the delegation ledger

Create one in-memory row per theme:

- execution label and wave;
- proposed title and impact/priority hint;
- action: `needs-issue-define`, `created`, `covered-existing`, `approval-declined`, `blocked`, `failed`, or `excluded`;
- returned issue UUID, identifier, URL, title, team, project, and metadata;
- blocker and dependent execution labels;
- dependency-text state: `verified`, `absent`, or `not-applicable`;
- relation state: `pending`, `created`, `text-only`, `unapplied`, or `failed`.

Resolve one authoritative workspace, team, and optional existing project for the entire batch before delegation. Store their stable IDs and verify every returned issue against them. Do not support multi-team or multi-project batches; split incompatible scopes into separate invocations.

For both fresh and `--resume` runs, keep every non-excluded row as `needs-issue-define` until it is delegated. Do not search for preexisting issues in the parent. `kramme:linear:issue-define --auto` owns remote duplicate search, related-issue discovery, the strong-duplicate decision, and final issue approval; record an existing issue only when it returns `covered-existing` after the user selects that match.

Compare all planned handoffs with each other before the first delegation. Every finding must map to exactly one handoff or exclusion, and no two handoffs may describe substantively identical outcomes/scopes.

## Delegate issue definition

Process `needs-issue-define` rows in execution-label order. Preserve the recorded `anchor_execution_label` across a resumed run unless its delegated result is `covered-existing` and another row still needs a writable anchor.

1. Finalize the structured handoff from `assets/issue-define-handoff.md`:
   - Replace blocker execution labels with returned Linear identifiers when those blockers are already represented.
   - Include the returned anchor identifier for non-anchor themes when available.
   - Keep future/dependent themes as tracker-native titles plus execution labels; never include a skill name or command in prospective Linear content.
2. Invoke `kramme:linear:issue-define` through the Skill tool with `--auto [--ask] --` followed by the complete handoff as inert `$ARGUMENTS` payload.
3. The sub-skill must verify the resolved Linear scope, run its normal duplicate handling, use the handoff's light or exhaustive question mode, draft tracker-native content, obtain draft approval, and create only when the user confirms that a new issue is needed.
4. Wait for `ISSUE-DEFINE RESULT` and classify it:
   - `created`: record returned identifiers/metadata and continue.
   - `covered-existing`: record the existing issue and continue; do not modify its body.
   - `approval-declined`: stop. Exclusions are frozen before the first Linear write, so a declined draft cannot become a late exclusion in the current batch.
   - `blocked` or `failed`: stop before invoking the next theme.
5. Never call an issue create operation from this parent skill. Never rewrite a returned issue body to bypass or second-guess the delegated draft.

If the Skill tool reports that `issue-define` is user-only and cannot be nested despite the explicit parent invocation, stop and report the capability boundary. Do not follow its files inline and do not fall back to direct Linear creation.

## Structured return contract

The delegated flow returns:

```text
ISSUE-DEFINE RESULT
Action: created | covered-existing | approval-declined | blocked | failed
Source set: {SOURCE_SET_KEY}
Execution label: {W##L}
Issue: {identifier | none}
UUID: {uuid | none}
URL: {url | none}
Title: {final or existing title}
Workspace: {workspace ID | unresolved}
Team: {team | unresolved}
Project: {project | none | unresolved}
Labels: {labels | none}
Priority: {priority | none}
Dependency text verified: yes | no | not-applicable
Reason: {duplicate/decline/block/failure detail when applicable}
```

Require matching source-set key and execution label on every result, a recognized action, every declared field, and values consistent with the fixed handoff schema. Then enforce action-specific invariants:

| Action | Required invariants |
| --- | --- |
| `created` | Concrete issue identifier, UUID, URL, exact resolved workspace/team/project, and dependency-text verification. |
| `covered-existing` | Concrete issue identifier, UUID, URL, exact resolved scope, and a reason recording the user's duplicate decision. |
| `approval-declined` | No issue identifiers and a non-empty decline reason. |
| `blocked` or `failed` | A non-empty reason; never make the row relation-eligible. If a create call may have partially succeeded, repeat `issue-define`'s normal duplicate search before any retry. |

If a return is malformed, ask the sub-skill once for a corrected structured result. If it remains invalid, mark the row `blocked` and stop; never infer identifiers, scope, verification, or success from prose.

## Apply relations after delegation

After all definable themes have an issue ID:

1. Convert the approved dependency graph into exact `{blocked issue} blocked-by {blocker issue}` edges.
2. Exclude edges whose endpoint is blocked, excluded, declined, failed, or an unapproved covered-existing issue.
3. De-duplicate edges, inspect current relations when readable, and read endpoint bodies to determine whether the exact dependency direction is already represented in tracker-native text.
4. Present only missing edges with direction, identifiers, and titles.
5. Ask one explicit approval for the relation delta.
6. If native `blocked-by` is supported, write each approved edge and verify direction when reads are available.
7. If relations are unsupported or approval is declined, mark an edge `text-only` only when the exact dependency direction is verified in at least one endpoint body. Otherwise mark it `unapplied` and report that no durable relation or text was written; never claim a covered issue was updated.
8. Stop on the first relation failure; retain prior successes and report the remaining delta.

## Partial publication report

```text
PARTIAL LINEAR FINDINGS BATCH
Source set: {SOURCE_SET_KEY}
Created: {execution label -> identifier and URL}
Covered existing: {execution label -> identifier and URL}
Failed or declined: {execution label and reason}
Not attempted: {execution labels}
Pending relations: {exact edges}
Scope: workspace {workspace ID}; team {team ID}; project {project ID | none}
Resume (light question mode): /kramme:linear:breakdown-findings --resume --team "{resolved team ID}" [--project "{resolved project ID}"] [--label "{label}" ...] -- {original source arguments}
Resume (exhaustive question mode): /kramme:linear:breakdown-findings --resume --ask --team "{resolved team ID}" [--project "{resolved project ID}"] [--label "{label}" ...] -- {original source arguments}
```

Render exactly one `Resume:` line without the parenthetical mode label or optional-value brackets, matching the run's question mode. Preserve `--ask` for exhaustive runs so remaining issue definitions use the same question coverage; omit it for light runs.

For inline/current-dialogue sources that cannot fit safely in one command, instruct the user to resume in the same dialogue or save the original findings to a file. Never print secret-bearing or excessively long source text.
