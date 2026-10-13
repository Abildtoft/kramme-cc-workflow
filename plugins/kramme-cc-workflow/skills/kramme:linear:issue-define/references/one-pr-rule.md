# One-PR Rule

How to check whether an issue fits one PR, and how to split work that does not.

## Size Check

Run the check on the proposed scope and acceptance criteria. An issue fits one PR when one engineer can plausibly deliver it in a single reviewable PR: one problem, one coherent change, and acceptance criteria that do not branch into unrelated behaviors.

Treat the issue as oversized when any of these hold:

- Several independent outcomes that could ship and be verified separately.
- Changes across several unrelated areas or services that would be reviewed or deployed independently.
- Phased or sequenced language such as "first ... then ...", "phase 1/2", "follow-up PR", or "in a later PR".
- A migration, rollout, or backfill that must land in a separate PR before or after the main change.
- A checklist of more than roughly five unrelated tasks.
- The user or the draft already names more than one PR.

An existing issue whose sub-issues already cover the multi-PR work is not oversized; it is a parent. In improve mode, use the sub-issues listed in Phase 3 before judging.

When the check is unclear, state the uncertainty and recommend a split rather than a single issue.

## Resolving an Oversized Issue

Present the size finding with the structured question tool, name the signals that triggered it, and propose PR-sized slices in delivery order. Offer:

1. **Split into sub-issues** (recommended) — file a parent issue plus one sub-issue per proposed PR.
2. **Narrow to one PR** — keep only the slice that ships first and move the rest to Out of Scope. Do not describe the moved work as later PRs of this issue; the user can define it separately.
3. **Cancel** — print the drafted content and stop without writing.

Never offer to file the oversized issue as-is. If the user rejects every option, treat it as Cancel.

## Parent and Sub-issue Shape

**Parent issue** (new in create mode, the existing issue in improve mode):

- Keeps the product framing: Problem, Value Proposition, Why Now, Goal, overall Scope, and outcome-level Acceptance Criteria that hold once every sub-issue is done.
- Adds a `## Sub-issues` section listing each slice in delivery order with a one-line outcome. Before creation, use the draft titles; after creation, replace them with the returned identifiers.
- Is not itself implemented by a PR; it is resolved when its sub-issues are, so it is exempt from the size check.

**Each sub-issue:**

- Describes one PR: its own Problem or Goal in one or two sentences, In Scope and Out of Scope for that slice, and individually verifiable Acceptance Criteria.
- Must pass the size check on its own. Split further until every slice fits one PR.
- Is standalone: a reader can implement it from its own body plus a reference to the parent.
- Inherits the parent's team, project, and labels unless the user chooses otherwise.
- Records ordering in a Dependencies line in prose and as a native `blockedBy` relation on the dependent sub-issue.

Apply the durability rule, redaction, and writing guidelines to the parent and every sub-issue.

## Review

Present the parent and every sub-issue in full in one draft, with each sub-issue's metadata, the parent it will attach to, and its `blockedBy` relations. Ask once for approval of the whole set with the structured question tool (approve, refine, or cancel). On refine, re-run the size check on changed slices and show the complete revised set again.

## Write Order

After approval, using `save_issue`:

1. Create the parent without `id`, or in improve mode update the existing issue following the Phase 7 improve-mode rules. Record the parent identifier.
2. Create each sub-issue without `id`, in delivery order, with `parentId` set to the parent identifier and `blockedBy` set to the already-created siblings it depends on. Map each draft key to the returned identifier. This skill never sends `removeBlockedBy`, so double-check each direction before writing; a wrong edge must be fixed by hand in Linear.
3. Update the parent's `## Sub-issues` section with the returned identifiers, preferring `patch`.
4. Read back with `list_issues` using `parentId` and confirm every approved sub-issue is attached.

A failed write, or a read-back missing an approved sub-issue, is a failed split: stop, report the identifiers already created, the drafts not yet written, whether the parent's `## Sub-issues` section still shows draft titles, and the Linear error, and do not return the success result. Never blindly recreate a sub-issue on retry; list the parent's sub-issues first and write only what is missing.

Return the parent URL and every sub-issue URL in delivery order.
