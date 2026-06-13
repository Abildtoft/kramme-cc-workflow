---
name: kramme:linear:select-next
description: "Requires Linear MCP. Selects the most valuable available issue to start from a Linear team by comparing assigned-to-me and unassigned issues, optional work-interest preferences, and parallel-ready candidates. Use when deciding what to pick up next. Not for creating, editing, implementing, or closing Linear issues."
argument-hint: "[team] [--interest <work preference>] [--mine|--unassigned|--both] [--project <name>] [--label <name>] [--limit <n>]"
disable-model-invocation: true
user-invocable: true
---

# Select Next Linear Issue

Choose the most valuable ready-to-start issue from a Linear team, optionally weighted by what type of work the user wants to do. The skill is read-only: it gathers Linear context, ranks candidates, explains the recommendation, and points to `kramme:linear:issue-implement` for follow-up.

## Boundaries

- **Do:** inspect available team issues, compare assigned-to-me and unassigned work, account for blockers/readiness/value, and identify independent issues that can run in parallel.
- **Do not:** create branches, change assignees, move statuses, add comments, create issues, or start implementation.
- **Handoff:** once the user picks an issue, suggest `kramme:linear:issue-implement {ISSUE-ID}`.

## Arguments

Parse `$ARGUMENTS` before Step 1.

- Bare text is the team name, key, or ID unless it follows a flag.
- `--mine`: include only issues assigned to the logged-in user.
- `--unassigned`: include only unassigned issues.
- `--both`: include assigned-to-me and unassigned issues. This is the default.
- `--project <name>`: filter to a project.
- `--label <name>`: filter to a label.
- `--limit <n>`: cap collected candidates per pool after priority-ordered pagination. Default 150, maximum 250.
- `--interest <description>`: describe the kind of work the user wants to do, such as `frontend polish`, `small bug fixes`, `backend architecture`, `high customer impact`, `low coordination`, or `docs and cleanup`. Treat this as a ranking preference, not a hard filter, unless the user explicitly says `only`.

If mutually exclusive assignee flags are combined, stop and ask the user to choose one pool. If `--interest` is omitted and the user provides extra unflagged text after a resolved team name, treat that extra text as `interest` only when the team can still be resolved unambiguously. Otherwise ask one short clarification question.

## Workflow

1. **Check prerequisites.** If Linear MCP operations are unavailable, stop with `MISSING REQUIREMENT: Linear MCP is required to select the next issue`.

   Tool names vary by harness. This skill names operations by Linear MCP capability (`get_user`, `list_issues`, etc.); in environments that expose namespaced tool IDs, use the matching `mcp__linear__...` tool.

2. **Resolve the user and team.**
   - Call Linear MCP `get_user` with `query: "me"` and store the logged-in user's name/id.
   - If a team argument was provided, resolve it with Linear MCP `get_team`.
   - If no team was provided, call Linear MCP `list_teams`. Use the only team if exactly one is available; otherwise ask one short plain-text question for the target team.
   - If the team cannot be resolved, stop and show the team value that failed.

3. **Resolve available states.**
   - Call Linear MCP `list_issue_statuses` for the selected team.
   - Treat issues as available when their state type or state name indicates backlog/unstarted/todo/ready work.
   - Exclude completed, canceled, duplicate, archived, and started-by-someone-else issues.
   - Include started issues only when assigned to the logged-in user and the state name does not imply blocked/waiting/review.
   - If status metadata is unavailable, fetch team issues and filter locally by state name using the same exclusions.

4. **Fetch candidate issues.**
   - Build the requested pools:
     - `mine`: `assignee: "me"`
     - `unassigned`: `assignee: null`
   - For each pool, collect candidates in priority order before recency: Urgent (`priority: 1`), High (`2`), Medium (`3`), Low (`4`), then None (`0`).
   - For each priority bucket, call Linear MCP `list_issues` with selected `team`, pool assignee filter, available `state` filters, optional `project`, optional `label`, priority, and a page `limit` no larger than the remaining pool cap. Follow the returned cursor until that bucket is exhausted or the pool cap is reached.
   - If the Linear tool cannot filter by state in one call, run the priority-paged query once per available state and merge results.
   - If the Linear tool cannot filter by priority, page through `list_issues` until the pool cap is reached, then sort locally by Linear priority before enrichment and report the weaker confidence if the pool cap was reached.
   - Dedupe by issue identifier or UUID.
   - If any pool hits the cap before all pages are exhausted, state that ranking is based on the highest-priority collected candidates and suggest increasing `--limit` or narrowing by project/label.

5. **Enrich the shortlist.**
   - If there are no candidates, report that no available assigned/unassigned issues were found for the team and filters.
   - For each candidate up to the top 25 by Linear priority, due date, project metadata, blocker/unblock hints, customer-impact hints, and match against the `--interest` terms when present, call Linear MCP `get_issue` with `includeRelations: true`, `includeCustomerNeeds: true`, and `includeReleases: true` when supported.
   - For candidates that look high-value but ambiguous, call Linear MCP `list_comments` to check for clarifications, blockers, or recent decisions.
   - Keep the analysis read-only even if the best next action appears to be "assign this to me" or "ask for clarification".

6. **Score value and readiness.** Read `references/scoring-rubric.md` and apply it. Use the rubric to classify each issue as:
   - `ready`: clear enough and unblocked enough to begin.
   - `clarify-first`: valuable, but missing acceptance criteria, owner decision, design detail, or technical boundary.
   - `blocked`: blocked by another issue, external dependency, approval, or explicit blocked/waiting state/label.
   - `not-now`: low value, stale without evidence, duplicate-looking, or outside the current team/project focus.
   - If `--interest` was provided, add a `preference fit` assessment based on title, description, labels, project, customer needs, comments, and likely implementation area. Preference fit can break ties or surface a close alternative, but it must not outrank a materially higher-value ready issue unless the user explicitly asked for `only` that work type.

7. **Select the next issue.**
   - Prefer the highest-value `ready` issue.
   - If a `clarify-first` or `blocked` issue has materially higher value than all ready issues, mention it as the highest-value non-ready issue, but do not present it as the next issue to start.
   - Break close ties using: strong preference fit, assigned-to-me ownership, urgent/high priority, unblocks more work, clearer acceptance criteria, smaller coordination cost, older age only when otherwise ready.
   - If the selected issue does not match the user's stated interest well, explain why value/readiness outweighed preference and name the best matching ready alternative.

8. **Detect parallel candidates.**
   - Among ready issues, identify sets of 2-4 issues that can be worked in parallel.
   - Treat issues as parallel-friendly when they have no blocker/blocked-by relationship, touch different product areas or likely code areas, have independent acceptance criteria, and do not require the same migration, schema change, feature flag, or release gate.
   - Treat issues as sequential/coordinate when they share dependencies, project phase, owner decision, data model, API contract, broad refactor, or likely files.
   - If independence is inferred rather than explicit, label it as an inference and name the evidence.

9. **Report the recommendation.** Use this structure:

   ```text
   Recommended next issue: {IDENTIFIER} - {title}
   Why this one: {3-5 bullets on value, readiness, urgency, unblock impact}
   Preference fit: {strong|partial|weak|not provided} - {one-line evidence}
   Readiness: {ready|clarify-first|blocked} - {one-line reason}
   Handoff: /kramme:linear:issue-implement {IDENTIFIER}

   Parallel candidates:
   | Issue | Why independent | Caveat |
   | --- | --- | --- |
   | ... | ... | ... |

   Ranked shortlist:
   | Rank | Issue | Pool | Readiness | Preference fit | Why |
   | --- | --- | --- | --- | --- | --- |
   | ... | ... | ... | ... | ... | ... |

   High-value but not ready:
   | Issue | Status | What is needed |
   | --- | --- | --- |
   | ... | ... | ... |
   ```

   Omit empty sections except `Parallel candidates`; if there are no parallel-ready issues, say `None found from the fetched candidates`.

## Red Flags

- Recommending an issue only because it has the highest Linear priority while it is blocked or underspecified.
- Treating all unassigned issues as available without filtering out completed/canceled/started work.
- Presenting inferred parallelism as certain when issue descriptions do not reveal implementation overlap.
- Starting branch setup or implementation instead of handing off to `kramme:linear:issue-implement`.
