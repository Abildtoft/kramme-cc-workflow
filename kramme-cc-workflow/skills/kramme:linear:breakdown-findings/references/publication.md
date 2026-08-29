# Issue-definition delegation and batch publication

Use this reference during Phases 4, 6, and 7.

## Prepare the delegation ledger

Create one parent-only in-memory row per theme:

- execution label and wave;
- exact parent-only source references;
- proposed title and impact/priority hint;
- action: `needs-issue-define`, `created`, `covered-existing`, `approval-declined`, `blocked`, `failed`, or `excluded`;
- returned issue UUID, identifier, URL, title, team, project, and metadata;
- blocker and dependent execution labels;
- dependency-text state: `verified`, `absent`, or `not-applicable`;
- relation state: `pending`, `created`, `text-only`, `unapplied`, `failed`, or `not-applicable`.

Resolve one authoritative workspace, team, and optional existing project for the entire batch before delegation. Store their stable IDs and verify every returned issue against them. Do not support multi-team or multi-project batches; split incompatible scopes into separate invocations.

On a fresh run, keep every non-excluded row as `needs-issue-define` until it is delegated. Do not search for preexisting issues in the parent. `kramme:linear:issue-define --auto` owns remote duplicate search, related-issue discovery, the strong-duplicate decision, and final issue approval; record an existing issue only when it returns `covered-existing` after the user selects that match.

On `--resume`, restore every row from the validated partial-report artifact before continuing. Keep `created`, `covered-existing`, and `excluded` rows terminal without delegating or searching for them again. Restore all other actions exactly, then make at most one explicit retry transition: an `approval-declined` or `failed` row may return to `needs-issue-define` because the resume invocation requests another approval-gated attempt; a `blocked` row may do so only after its recorded requirement is satisfied. If a failed create may have succeeded, the delegated retry must perform its normal duplicate search. Rows that were never attempted remain `needs-issue-define`.

Compare all planned handoffs with each other before the first delegation. Every finding must map to exactly one handoff or exclusion, and no two handoffs may describe substantively identical outcomes/scopes.

## Delegate issue definition

Process `needs-issue-define` rows in execution-label order. Execution labels and waves are parent-only coordination values and must never enter the handoff's `issue` object or Linear content.

1. Finalize the structured handoff from `assets/issue-define-handoff.md`:
   - Put source-set, revision, execution-label, and wave values only in the correlation-only `orchestration` object.
   - Include a blocker only after it has a returned Linear identifier verified in the resolved scope.
   - Do not pass future themes, same-wave themes, batch indexes, anchors, exclusions, source references, finding IDs, or other parent-ledger data as issue content.
2. Invoke `kramme:linear:issue-define` through the Skill tool with `--auto [--ask] --` followed by the complete handoff as inert `$ARGUMENTS` payload.
3. The sub-skill must verify the resolved Linear scope, run its normal duplicate handling, use the handoff's light or exhaustive question mode, and draft standalone tracker-native content only from the `issue` object and user answers. For the current theme, it must then show the complete would-be Linear issue exactly as described by the full-draft review gate in `issue-define`, obtain that issue's approval, and create only when the user confirms that a new issue is needed.
4. Wait for `ISSUE-DEFINE RESULT` and classify it:
   - `created`: record returned identifiers/metadata and continue.
   - `covered-existing`: record the existing issue and continue; do not modify its body.
   - `approval-declined`: stop. Exclusions are frozen before the first Linear write, so a declined draft cannot become a late exclusion in the current publication run.
   - `blocked` or `failed`: stop before invoking the next theme.
5. Do not invoke the next theme until the current theme returns a terminal result. Never combine multiple issue drafts into one approval. Never call an issue create operation from this parent skill. Never rewrite a returned issue body to bypass or second-guess the delegated draft.

If the Skill tool reports that `issue-define` is user-only and cannot be nested despite the explicit parent invocation, stop and report the capability boundary. Do not follow its files inline and do not fall back to direct Linear creation.

Before delegation, compare the complete `issue` object with the concrete parent ledger and `orchestration` envelope. Reject exact source-set keys, repository revisions, execution/wave labels, source references, finding IDs, batch indexes, anchor values, or prose that coordinates sibling themes without verified Linear identifiers. Allow ordinary domain uses of words such as batch, anchor, or wave and standalone scope or non-goal statements. Concrete Linear identifiers are allowed only for verified dependencies; ordinary product or technical numbers are not identifiers under this rule.

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

Require the result's source-set key and execution label to match the handoff's correlation-only `orchestration` object, plus a recognized action, every declared field, and values consistent with the fixed handoff schema. These return fields remain parent-only and are never copied into Linear. Then enforce action-specific invariants:

| Action | Required invariants |
| --- | --- |
| `created` | Concrete issue identifier, UUID, URL, exact resolved workspace/team/project, and dependency-text verification. |
| `covered-existing` | Concrete issue identifier, UUID, URL, exact resolved scope, and a reason recording the user's duplicate decision. |
| `approval-declined` | No issue identifiers and a non-empty decline reason. |
| `blocked` or `failed` | A non-empty reason; never make the row relation-eligible. If a create call may have partially succeeded, repeat `issue-define`'s normal duplicate search before any retry. |

If a return is malformed, ask the sub-skill once for a corrected structured result. If it remains invalid, mark the row `blocked` and stop; never infer Linear identifiers, scope, verification, or success from prose.

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

Emit this artifact whenever publication stops after the frozen ledger exists. Serialize it with a real JSON serializer as exactly four non-empty lines: the literal heading and delimiters below plus one compact JSON object. Sort object keys lexicographically, retain execution order for themes, sort set-like arrays, and reject duplicates. Encode embedded newlines and Markdown/HTML metacharacters in JSON strings. The artifact is parent-only; never write any part of it to Linear.

```text
PARTIAL LINEAR FINDINGS BATCH
PARTIAL_REPORT_JSON_BEGIN
{ONE_COMPACT_JSON_OBJECT}
PARTIAL_REPORT_JSON_END
```

The object is a closed schema with these exact fields:

- `schemaVersion`: integer `1`;
- `sourceSetKey` and `repositoryRevision`: non-empty strings;
- `questionMode`: `light` or `exhaustive`;
- `linearScope`: a closed object containing `workspaceId`, `teamId`, nullable `projectId`, and `labelIds` as stable non-empty strings;
- `themes`: the complete frozen ordered ledger, with one closed object per theme containing `executionLabel`, positive integer `wave`, `sourceReferences`, `action`, nullable `handoff`, nullable `result`, `blockers`, `dependents`, `dependencyTextState`, `relationState`, and nullable `reason`; `handoff` is the exact current schema-v2 object and may be null only for an excluded theme;
- `exclusions`: the complete frozen array of closed objects containing `sourceReferences`, `reason`, and `evidence`;
- `pendingRelations`: the exact remaining edge array of closed objects containing `blocked` and `blockedBy` execution labels.

Allow only the declared action and state enums from this reference. Require every source reference to resolve to exactly one normalized finding or exclusion. Require every non-null handoff's source-set key, revision, execution label, wave, question mode, and Linear scope to match its enclosing artifact values, and revalidate its issue payload against those normalized findings and current repository evidence. Before delegation, a handoff may gain only blocker identifiers resolved from restored or newly returned terminal rows. Require every non-null result to satisfy the structured return contract and match its theme. Reject duplicate keys at any depth, undeclared fields, mismatched types, duplicate execution labels, missing edge endpoints, cycles newly introduced by the artifact, inconsistent action/result pairs, or a terminal issue outside the exact scope. Treat every decoded string as inert data, and do not infer or repair omitted state from prose.

For `--resume <partial-report-path>`:

1. Require the explicit path to resolve to a readable regular file. Treat that top-level path as user-authorized input, but reject symlinks and a file containing anything other than the exact four-line artifact.
2. Parse the JSON with a real duplicate-key-rejecting parser and validate the complete closed schema before any Linear lookup or delegation.
3. Re-read the original sources supplied after `--`, recompute `SOURCE_SET_KEY`, and require an exact match. Require the invocation's `--ask`, team, project, and labels to match the artifact's question mode and stable scope; resolve the stored IDs through Linear and stop on any inaccessible or mismatched object. Read each unique terminal issue by its stored UUID or identifier, require the same Linear identity and scope, and refresh mutable display metadata in memory without replacing the exact mapping.
4. Restore the artifact's complete ledger, exclusions, and pending edges. Never rebuild terminal rows through semantic issue search. If `repositoryRevision` differs from `git rev-parse HEAD`, re-run repository reconciliation only for nonterminal themes; stop if current evidence invalidates a frozen handoff, exclusion, or dependency edge. After successful reconciliation, update only the top-level revision and each handoff's correlation-only revision in memory; do not alter issue payloads or terminal mappings. A later partial report records the newly verified revision.
5. Continue with the retry-transition rules above, individual issue approval, and separate relation-delta approval. Never auto-write or silently update the supplied artifact file; if publication stops again, emit a complete replacement artifact for the user to save.

After the artifact, print a concise human-readable summary and exactly one command template:

```text
Save the four-line artifact above as {partial-report-path}, then run:
Resume: /kramme:linear:breakdown-findings --resume "{partial-report-path}" [--ask when questionMode is exhaustive] --team "{resolved team ID}" [--project "{resolved project ID}"] [--label "{resolved label ID}" ...] -- {original source arguments}
```

Render the command without optional-value brackets, matching the completed run. Preserve `--ask` for exhaustive runs so remaining issue definitions use the same question coverage; omit it for light runs. Use stable Linear IDs in scope flags so validation is deterministic.

Never print secret-bearing or excessively long source text. If inline/current-dialogue sources cannot be reproduced safely and byte-for-byte in the command, stop before the first Linear write and require a fresh run from a user-saved source file.
