---
name: kramme:linear:backlog-refine
description: "Requires Linear MCP. Grades a Linear team's open backlog for clarity, scope, agent-readiness, freshness, and resolution evidence, and reports startability separately; clusters related work; and proposes complete, cancel, merge, split, rewrite, ask, or keep. Read-only unless --apply is passed and each write batch is approved. Use for backlog grooming or pre-planning cleanup. Not for selecting, defining, or implementing an issue; use kramme:linear:select-next or kramme:linear:issue-define instead."
argument-hint: "[team] [--project <name>] [--label <name>] [--stale-days <n>] [--limit <n>] [--apply]"
disable-model-invocation: true
user-invocable: true
---

# Refine Linear Backlog

Grade a Linear team's backlog so that as many issues as possible reach a state where an autonomous agent (for example `kramme:linear:issue-to-pr`) can pick them up and deliver quality work without a human in the loop: a clear problem, a bounded scope, verifiable acceptance criteria, and no undecided questions. Issues that cannot reach that bar are still kept clear, correctly sized, and still worth doing for humans. The skill reads the backlog, scores each issue against `references/refinement-rubric.md`, clusters related issues, and proposes one action per issue. Nothing in Linear changes unless the user passed `--apply` and approves a batch.

## Boundaries

- **Do:** inspect backlog issues, grade clarity, scope, and agent-readiness, detect duplicates, oversized items, and stale issues, and produce a refinement plan with a concrete action per issue.
- **Do not:** implement issues, change assignees or priorities without an approved `--apply` batch, delete issues, or create issues from scratch.
- **Handoff:** for a `rewrite` that needs a full interview, point to `kramme:linear:issue-define {IDENTIFIER}`; for picking work after refinement, point to `kramme:linear:select-next`.

## Arguments

Parse `$ARGUMENTS` before Step 1.

- Bare text is the team name, key, or ID unless it follows a flag.
- `--project <name>`: filter to a project.
- `--label <name>`: filter to a label.
- `--stale-days <n>`: days without any update before an issue is flagged stale. Default 90.
- `--limit <n>`: cap collected backlog issues. Default 200, maximum 400.
- `--apply`: enable the write phase. Without it the skill is read-only and ends after the report.

Reject unknown flags and repeated flags with one short message naming the offending token.

## Workflow

1. **Check prerequisites.** If Linear MCP operations are unavailable, stop with `MISSING REQUIREMENT: Linear MCP is required to refine the backlog`.

   Tool names vary by harness. This skill names operations by Linear MCP capability (`list_issues`, `save_issue`, etc.); in Codex, use those bare capability names, and in environments that expose namespaced tool IDs, use the matching `mcp__linear__...` tool.

2. **Resolve the team.**
   - If a team argument was provided, resolve it with Linear MCP `get_team`.
   - If no team was provided, call Linear MCP `list_teams`. Use the only team if exactly one is available; otherwise ask one short plain-text question for the target team.
   - If the team cannot be resolved, stop and show the team value that failed.

3. **Resolve backlog states.**
   - Call Linear MCP `list_issue_statuses` for the team.
   - Treat an issue as backlog when its state type is `backlog`, or `unstarted` with a name that implies triage, backlog, or icebox rather than a committed queue.
   - Exclude started, completed, canceled, duplicate, and archived issues. Do not refine issues someone is already working on.
   - If status metadata is unavailable, fetch team issues and filter locally by state name with the same exclusions.

4. **Fetch the backlog.**
   - Call Linear MCP `list_issues` with the team, backlog state filters, optional `project`, optional `label`, ordered by least recently updated first so stale issues are collected before the cap is reached. Follow the cursor until the backlog is exhausted or `--limit` is reached.
   - Dedupe by issue identifier or UUID.
   - If the cap is reached before all pages are exhausted, say so in the report and suggest raising `--limit` or narrowing by project or label.
   - If no backlog issues match, report that and stop.

5. **Enrich issues that need it.**
   - Call Linear MCP `get_issue` with `includeRelations: true` for every issue, so blockers, duplicates, parents, and sub-issues are visible.
   - Call Linear MCP `list_comments` when the issue is a candidate for `agent-ready`, or when a comment may show that the requested outcome shipped, one of the issue's explicitly permitted resolutions occurred, the work was superseded or abandoned, or the grade is borderline between `keep`, `complete`, and `cancel`.
   - Title and description are sufficient for preliminary triage only. Before assigning `agent-ready`, inspect required linked inputs or repository context to verify they are reachable, and check for unresolved blockers and decisions that supersede the description. Reuse evidence already fetched in this run; a clear description never exempts an issue from this promotion check.
   - When delivery evidence points to repository changes, a Pull Request, or acceptance coverage, inspect the referenced evidence rather than inferring completion from matching words or a closed relation.
   - Keep the full issue set; never drop an issue because enrichment failed. Record the failing operation and its error as the gap; a fetch failure is unknown evidence, not a specification gap, and never justifies a `rewrite`, `complete`, `cancel`, or `merge` proposal. Grade from what is available.
   - Record a source and a short evidence statement for each passing readiness item, and the gap for each failing or unknown item. Missing required evidence prevents promotion. Check that the proposed verification method is available and has an expected result; executing the implementation tests is not required during refinement.

6. **Grade each issue.** Read `references/refinement-rubric.md` and apply it. Produce for every issue:
   - `clarity`: `clear`, `vague`, or `empty`.
   - `scope`: `pr-sized`, `oversized`, or `unknown`.
   - `freshness`: `active` or `stale` (no update within `--stale-days`). Freshness never determines whether delivered work was completed or unwanted work was canceled.
   - `resolution-evidence`: `delivered` when the requested outcome is demonstrably delivered, `cancel-supported` when the work was superseded, abandoned, or has no remaining relevance, or `none`. Record the concrete evidence, not only the label.
   - `agent-readiness`: `agent-ready`, `needs-refinement`, or `human-only`, using the rubric's agent-readiness checklist. `agent-ready` means the specification passes every checklist item. A missing answer or input that would enable implementation is `needs-refinement`; use `human-only` when human judgment or access is itself the required work. Bounded investigations can qualify under the rubric.
   - For each `agent-ready` issue, report startability separately: `ready-to-start`, `awaiting-prerequisite` with identifiers, or `unknown` with the missing evidence. An unresolved prerequisite does not become resolved because its identifier appears in the description.
   - `duplicate-of`: the identifier of a clearly overlapping issue, or none.
   - For every issue that is not `agent-ready`, record the specific failing checklist items; they drive the `rewrite` and `ask` drafts.
   - Before assigning `delivered` to a parent, verify that its requested outcome or acceptance criteria are delivered and every required child is complete. A child does not block completion only when the parent explicitly identifies it as optional, a follow-up, or out of scope. If requiredness is ambiguous, do not propose `complete`; use `ask` or another nonterminal action.

7. **Cluster related issues.**
   - Group issues that share the same problem statement, affected area, or user outcome, using titles, descriptions, labels, project, and explicit `related`/`duplicate` relations.
   - Inside a cluster, pick the canonical issue: the clearest description, then the most recent activity, then the oldest identifier.
   - Label inferred overlap as an inference and name the evidence; only explicit Linear relations count as certain.

8. **Propose one action per issue.** Choose from:
   - `complete`: the requested outcome or acceptance criteria are demonstrably delivered, including when one of multiple explicitly permitted resolutions shipped. For a parent, its own requested outcome or acceptance criteria and every required child must be complete. Explicitly optional, follow-up, or out-of-scope children do not block this action. State the evidence.
   - `cancel`: the work was superseded, abandoned, or is no longer relevant, including a stale issue with evidence that it has no remaining value. State the reason. Age alone is never enough. Two grading errors to avoid:
     - Canceling delivered work, including a parent whose requested outcome is delivered and whose only unfinished child is explicitly optional, a follow-up, or out of scope.
     - Proposing `cancel` just because an issue is old while it carries priority, a customer need, or blocks other work.
   - `merge`: duplicate of a canonical issue. Propose moving any unique detail into the canonical issue and marking this one as a duplicate.
   - `split`: oversized. Propose 2-5 PR-sized child issues with full descriptions following the rubric's child brief contract. Give each child a stable draft key so dependencies between proposed children can be named before Linear identifiers exist. Each child must have its own verifiable outcome; state any prerequisites explicitly. The original becomes the parent.
   - `rewrite`: keep the issue but draft a clearer title and description whose goal is to make the issue `agent-ready`. Use the codebase to close gaps when it can: read the affected area to confirm the behavior, name the modules involved, and turn implied expectations into verifiable acceptance criteria. Include the draft in the report and state which checklist items it closes; hand off to `kramme:linear:issue-define` when the rewrite needs information only the user has. Never invent acceptance criteria or product decisions the issue never implied in order to reach `agent-ready`; missing decisions are an `ask`, not a guess.
   - `ask`: value or relevance cannot be judged from Linear, or the issue is `needs-refinement` and the missing information (a decision, a design, an expected behavior) exists only with a person; name the single question whose answer would make the issue `agent-ready` and the person who can answer it when the issue records an owner.
   - `keep`: clear, PR-sized, and still relevant. No change.

   Apply those rules in the listed first-match order: delivered work is `complete`, cancellation-supported work is `cancel`, then duplicates are `merge`, followed by `split`, `rewrite`, `ask`, and `keep` according to the rubric. Never route an issue with `resolution-evidence = delivered` to `cancel`.

   Follow the rubric's drafting rules for every `rewrite` and `split`: lead with the problem and outcome, give acceptance criteria an agent can verify by running something, state explicit non-goals and decisions already made, and avoid file paths, line numbers, and internal helper names.

9. **Validate drafts and report the plan.** Re-grade the exact final description of every rewrite and split child against every readiness item, retaining the evidence and any open gaps. Unsupported assumptions and unanswered questions never count as closed gaps. Compute projected readiness only from drafts that pass this final check; a proposed action alone is not evidence of readiness.

   Count retained implementation issues once, replace split parents with their children, and exclude completed, canceled, merged-away, and tracking-only parent issues from projected readiness. Show the identifiers or draft keys behind each count, distinguish existing issues from new children, and keep awaiting-prerequisite and unknown startability separate from ready-to-start. Label projections as conditional on applying the drafts and persisting their relations; do not assume prerequisites will complete. Use this structure:

   ```text
   Backlog refinement: {team} ({n} issues graded, {m} need action)
   Agent-ready now (verified specifications): {a} | projected after applying validated drafts: {b} | human-only: {c}
   Startability now: ready-to-start {r} | awaiting-prerequisite {w} | unknown {u}
   Projected startability: ready-to-start {pr} | awaiting-prerequisite {pw} | unknown {pu}
   Count basis: {existing identifiers and proposed child keys, with exclusions}

   Summary:
   | Action | Count |
   | --- | --- |
   | complete | ... |
   | cancel | ... |
   | merge | ... |
   | split | ... |
   | rewrite | ... |
   | ask | ... |
   | keep | ... |

   Proposed actions:
   | Issue | Action | Clarity | Scope | Freshness | Resolution evidence | Agent-readiness | Startability | Why |
   | --- | --- | --- | --- | --- | --- | --- | --- | --- |
   | ... | ... | ... | ... | ... | ... | ... | ... | ... |

   Drafts:
   {for each rewrite: issue, proposed title, proposed description, checklist items closed, items still open}
   {for each split: parent issue, child draft keys, titles, full descriptions, dependency mapping, final readiness and startability per child}
   {for each merge: duplicate -> canonical, unique detail to carry over}

   Readiness evidence:
   {for each current or projected agent-ready issue: checklist item, source, evidence; for others: failing or unknown items}

   Open questions:
   {for each ask: issue, question, who can answer, what becomes agent-ready once answered}

   Next: {"rerun with --apply to apply approved batches" | "handoff lines"}
   ```

   Omit the `keep` rows from `Proposed actions` when more than 20 issues were graded; list their identifiers in one line instead. Omit empty sections. Leave `Startability` as `n/a` for any issue that is not `agent-ready`; only `agent-ready` rows contribute to the startability counts, which sum to the agent-ready count rather than the graded count. For picking autonomous implementation work, hand off to `kramme:linear:select-next {team} --agent-ready-only`; only issues that are also ready to start are candidates. Selection rechecks live evidence rather than trusting this report.

10. **Apply approved changes (`--apply` only).**
    - Resolve the team's state whose type is `completed` and the state whose type is `canceled` before presenting terminal batches. If either needed state cannot be resolved unambiguously, do not apply that action; report the missing state. A `complete` action may use only the completed state, and a `cancel` action may use only the canceled state.
    - Group proposed changes into batches by action type in this order: `merge`, `complete`, `cancel`, `rewrite`, and `split`. `keep` and `ask` never write.
    - When a canonical issue also has its own proposed action, apply its incoming `merge` actions first. After a merge changes the canonical issue, re-fetch and re-grade it, replace its grading snapshot, and present its recomputed action in a new batch for fresh confirmation. Do not carry an earlier approval for that issue forward or treat the intentional merge change as a concurrent edit.
    - Present one batch at a time and ask for explicit confirmation with the exact issues listed. Apply a batch only after an explicit yes; a partial answer such as "all except X" is a confirmation for the remaining issues only.
    - Writes per action, using Linear MCP `save_issue` (Claude Code `mcp__linear__save_issue`; Codex `save_issue`):
      - `complete`: immediately before changing state, re-fetch the issue with relations and re-fetch the comments. Re-verify the cited delivery evidence, the issue's acceptance criteria, and the status of every required child; repeat any cited repository or Pull Request check. If the evidence is missing, changed, incomplete, or ambiguous, skip the issue. Otherwise add a comment summarizing the verified completion evidence, then move the issue to the team's completed state.
      - `cancel`: add a comment stating the supersession, abandonment, or no-remaining-value reason, then move the issue to the team's canceled state. Never move an issue with verified delivery evidence to the canceled state.
      - `rewrite`: update only `title` and `description` on the existing issue.
      - `split`: use the approved full child descriptions. Create each child with `parentId` set to the original and the team, project, and labels inherited. Map draft keys to returned Linear identifiers, then persist every approved prerequisite as a `blockedBy` relation on the dependent child using `save_issue`'s `blockedBy` field, including dependencies on existing issues. Relation fields are append-only and this workflow never removes a relation, so a wrong-direction edge is permanent. If relation writes are unsupported, create no relation, keep the prerequisite as tracker-native description text, and report the relation as unapplied. Replace draft keys in descriptions with those identifiers. Do not report a split as fully applied until all children and dependency relations have been read back successfully and each read-back confirms the dependent child is the blocked side; if creation or linking fails, report the created identifiers and missing work, retain the drafts, and never blindly recreate a child on retry. Update the parent's description with a one-line tracking note only after the split is fully applied.
      - `merge`: append the duplicate's unique detail to the canonical issue's description, then move the duplicate to the team's `duplicate` or `canceled` state and add a comment naming the canonical issue. Never delete.
    - Before each write, re-fetch the issue and abort that write when its state, title, or description changed since grading; report the skipped issue and continue with the rest of the batch.
    - After each batch, read back every touched issue and report `applied`, `partially applied`, `skipped (changed since grading)`, or `failed ({error})` per issue. A failed write keeps the proposed draft in the report so nothing is lost.
    - For split children, use each successful read-back as the snapshot for the next dependent write; expected writes in this batch must not mask unrelated concurrent changes. Before reporting confirmed readiness, re-grade persisted descriptions, relations, relevant comments, and required inputs using the same promotion check. Keep projected gains separate from confirmed results; failed or skipped writes and incomplete dependency links never count as confirmed gains.
    - The workflow does not perform a Linear archive operation. Reports and confirmations must name the actual `complete`, `cancel`, or `merge` state transition.
    - Stop after the last batch. Do not start implementing any issue.
